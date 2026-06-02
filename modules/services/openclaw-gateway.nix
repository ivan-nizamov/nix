{ config, inputs, lib, pkgs, ... }:
let
  cfg = config.local.openclaw.embeddings;
  openclawEnabled = config.local.openclaw.enable;
  user = "iva";
  userHome = "/home/iva";
  stateDir = "${userHome}/.openclaw";
  enableTelegram = false;
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  baseOpenclaw = llmAgentsPkgs.openclaw;
  openclaw = pkgs.runCommand "openclaw-${baseOpenclaw.version}-metadata-patched" { } ''
    mkdir -p $out
    ${pkgs.xorg.lndir}/bin/lndir -silent ${baseOpenclaw} $out
    rm -rf $out/lib/openclaw/dist $out/lib/openclaw/dist-runtime $out/lib/openclaw/skills
    cp -r ${baseOpenclaw}/lib/openclaw/dist $out/lib/openclaw/dist
    cp -r ${baseOpenclaw}/lib/openclaw/dist-runtime $out/lib/openclaw/dist-runtime
    cp -r ${baseOpenclaw}/lib/openclaw/skills $out/lib/openclaw/skills
    chmod -R u+w $out/lib/openclaw/dist $out/lib/openclaw/dist-runtime $out/lib/openclaw/skills
    ln -s ${baseOpenclaw}/lib/openclaw/node_modules $out/lib/openclaw/dist/node_modules
    telegram_dev_deps=$(cat <<'EOF'
  "devDependencies": {
    "@openclaw/plugin-sdk": "workspace:*"
  },
EOF
)
    substituteInPlace $out/lib/openclaw/dist/extensions/telegram/package.json \
      --replace-fail "$telegram_dev_deps" ""

    telegram_fetch_patch_count=0
    for file in $out/lib/openclaw/dist/fetch-*.js $out/lib/openclaw/dist/extensions/telegram/fetch-*.js; do
      [ -e "$file" ] || continue
      if grep -q 'function resolveTelegramTransport(proxyFetch, options) {' "$file"; then
        substituteInPlace "$file" \
          --replace-fail 'function resolveTelegramTransport(proxyFetch, options) {' \
          'function resolveTelegramTransport(proxyFetch, options) {
	if (isTruthyEnvValue(process$1.env.OPENCLAW_TELEGRAM_USE_GLOBAL_FETCH)) {
		const globalFetch = globalThis.fetch.bind(globalThis);
		return {
			fetch: globalFetch,
			sourceFetch: globalFetch,
			dispatcherAttempts: [{ dispatcherPolicy: { mode: "global-fetch" } }],
			close: async () => {}
		};
	}'
        telegram_fetch_patch_count=$((telegram_fetch_patch_count + 1))
      fi
    done
    if [ "$telegram_fetch_patch_count" -eq 0 ]; then
      echo "failed to patch Telegram fetch transport" >&2
      exit 1
    fi

    rm $out/bin/openclaw
    cp ${baseOpenclaw}/bin/openclaw $out/bin/openclaw
    chmod u+w $out/bin/openclaw
    substituteInPlace $out/bin/openclaw \
      --replace-fail '${baseOpenclaw}/lib/openclaw/dist/entry.js' \
      "$out/lib/openclaw/dist/entry.js"

    for file in $out/lib/openclaw/dist/get-reply-*.js; do
      if grep -q 'group_subject: normalizePromptMetadataString(ctx.GroupSubject),' "$file"; then
        substituteInPlace "$file" \
          --replace-fail 'group_subject: normalizePromptMetadataString(ctx.GroupSubject),' \
          '/* group_subject omitted: redundant with conversation_label */'
      fi
    done

    for file in $out/lib/openclaw/dist/bundled-runtime-root-*.js; do
      substituteInPlace "$file" \
        --replace-fail 'const mirrorDistRoot = path.join(params.installRoot, "dist");' \
        'const mirrorDistRoot = path.join(params.installRoot, path.basename(sourceDistRoot));'
    done

    for file in $out/lib/openclaw/dist/loader-*.js; do
      # dist-runtime plugin loads should not replace an existing writable dist
      # mirror. The mirror keeps dist/extensions writable for plugins while
      # symlinking top-level runtime modules back into the immutable package.
      if grep -q 'safeRealpathOrResolve(targetCanonicalDistRoot) === safeRealpathOrResolve(sourceCanonicalDistRoot)' "$file"; then
        substituteInPlace "$file" \
          --replace-fail 'if (!(fs.existsSync(targetCanonicalDistRoot) && safeRealpathOrResolve(targetCanonicalDistRoot) === safeRealpathOrResolve(sourceCanonicalDistRoot))) {' \
          'if (!fs.existsSync(targetCanonicalDistRoot)) {'
      fi
      if grep -q 'fs.symlinkSync(sourceCanonicalDistRoot, targetCanonicalDistRoot, "junction");' "$file"; then
        substituteInPlace "$file" \
          --replace-fail 'fs.symlinkSync(sourceCanonicalDistRoot, targetCanonicalDistRoot, "junction");' \
          'fs.mkdirSync(targetCanonicalDistRoot, {
					recursive: true,
					mode: 493
				});
				const sourceCanonicalExtensionsRoot = path.join(sourceCanonicalDistRoot, "extensions");
				const targetCanonicalExtensionsRoot = path.join(targetCanonicalDistRoot, "extensions");
				fs.mkdirSync(targetCanonicalExtensionsRoot, {
					recursive: true,
					mode: 493
				});
				for (const entry of fs.readdirSync(sourceCanonicalDistRoot, { withFileTypes: true })) {
					if (entry.name === "extensions") continue;
					const sourceCanonicalPath = path.join(sourceCanonicalDistRoot, entry.name);
					const targetCanonicalPath = path.join(targetCanonicalDistRoot, entry.name);
					if (fs.existsSync(targetCanonicalPath)) continue;
					fs.symlinkSync(sourceCanonicalPath, targetCanonicalPath, entry.isDirectory() ? "junction" : "file");
				}
				if (fs.existsSync(sourceCanonicalExtensionsRoot)) {
					for (const entry of fs.readdirSync(sourceCanonicalExtensionsRoot, { withFileTypes: true })) {
						const sourceCanonicalExtensionPath = path.join(sourceCanonicalExtensionsRoot, entry.name);
						const targetCanonicalExtensionPath = path.join(targetCanonicalExtensionsRoot, entry.name);
						if (fs.existsSync(targetCanonicalExtensionPath)) continue;
						if (entry.name === "node_modules" && entry.isDirectory()) {
							copyBundledPluginRuntimeRoot(sourceCanonicalExtensionPath, targetCanonicalExtensionPath);
							continue;
						}
						fs.symlinkSync(sourceCanonicalExtensionPath, targetCanonicalExtensionPath, entry.isDirectory() ? "junction" : "file");
					}
				}'
      fi

      # Keep the top-level dist/node_modules symlink and the SDK package under
      # dist/extensions/node_modules, but avoid copying a full dependency tree.
      ${pkgs.perl}/bin/perl -0pi -e '
        s@if\s*\(\s*entry\.name\s*===\s*[\x22\x27]node_modules[\x22\x27]\s*\)\s*continue;@if (entry.name === "node_modules" && !entry.isSymbolicLink() && path.basename(sourceRoot) !== "extensions") continue;@g
      ' "$file"
    done
  '';
  openclawBin = "${openclaw}/bin/openclaw";
  codexAcpBin = lib.getExe llmAgentsPkgs.codex-acp;
  codexAcpWrapper = pkgs.writeShellScriptBin "openclaw-codex-acp" ''
    exec ${codexAcpBin} \
      -c 'approval_policy="never"' \
      -c 'sandbox_mode="danger-full-access"' \
      "$@"
  '';
  acpxVersion = "0.3.1";
  acpxPackage = pkgs.buildNpmPackage {
    pname = "acpx";
    version = acpxVersion;
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/acpx/-/acpx-${acpxVersion}.tgz";
      hash = "sha256-6WNw7N/DMmZJHMOaSPpXCpCGT0a9VygLNzsBWKRmhpo=";
    };
    npmDepsHash = "sha256-i2bpDwABCLEjCAbJaaxOZap+pSCECSP8ibYhbLHGR1Q=";
    postPatch = ''
      cp ${./acpx-package-lock.json} package-lock.json
    '';
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/acpx $out/bin
      cp -r . $out/lib/node_modules/acpx/
      chmod +x $out/lib/node_modules/acpx/dist/cli.js
      ln -s $out/lib/node_modules/acpx/dist/cli.js $out/bin/acpx
      runHook postInstall
    '';
  };
  acpxCli = "${acpxPackage}/bin/acpx";
  acpxWrapper = pkgs.writeShellScriptBin "openclaw-acpx" ''
    set -euo pipefail

    acpx_cli="${acpxCli}"

    argv=("$@")
    has_agent_override=0
    expect_value=0
    positional_index=-1
    index=0

    for arg in "''${argv[@]}"; do
      if [ "$expect_value" -eq 1 ]; then
        expect_value=0
      elif [ "$arg" = "--agent" ] || [ "$arg" = "--cwd" ] || [ "$arg" = "--auth-policy" ] || [ "$arg" = "--approve-all" ] || [ "$arg" = "--approve-reads" ] || [ "$arg" = "--deny-all" ] || [ "$arg" = "--non-interactive-permissions" ] || [ "$arg" = "--format" ] || [ "$arg" = "--model" ] || [ "$arg" = "--allowed-tools" ] || [ "$arg" = "--max-turns" ] || [ "$arg" = "--timeout" ] || [ "$arg" = "--ttl" ] || [ "$arg" = "-c" ] || [ "$arg" = "--config" ]; then
        if [ "$arg" = "--agent" ]; then
          has_agent_override=1
        fi
        case "$arg" in
          --approve-all|--approve-reads|--deny-all|--json-strict|--verbose)
            ;;
          *)
            expect_value=1
            ;;
        esac
      elif [ ''${arg#-} != "$arg" ]; then
        :
      else
        positional_index=$index
        break
      fi
      index=$((index + 1))
    done

    if [ "$has_agent_override" -eq 0 ] && [ "$positional_index" -ge 0 ] && [ "''${argv[$positional_index]}" = "codex" ]; then
      rewritten=()
      index=0
      for arg in "''${argv[@]}"; do
        if [ "$index" -ne "$positional_index" ]; then
          rewritten+=("$arg")
        fi
        index=$((index + 1))
      done
      exec ${pkgs.nodejs}/bin/node "$acpx_cli" --agent ${lib.getExe codexAcpWrapper} "''${rewritten[@]}"
    fi

    exec ${pkgs.nodejs}/bin/node "$acpx_cli" "''${argv[@]}"
  '';
  openclawPath = lib.concatStringsSep ":" [
    (lib.makeBinPath [ pkgs.nodejs ])
    "/run/current-system/sw/bin"
    "${userHome}/.local/bin"
    "${userHome}/.npm-global/bin"
    "${userHome}/bin"
    "${userHome}/.volta/bin"
    "${userHome}/.asdf/shims"
    "${userHome}/.bun/bin"
    "${userHome}/.nvm/current/bin"
    "${userHome}/.fnm/current/bin"
    "${userHome}/.local/share/pnpm"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  waitForEmbeddings = pkgs.writeShellScript "openclaw-wait-for-embeddings" ''
    set -eu

    deadline=$((SECONDS + 300))

    while [ "$SECONDS" -lt "$deadline" ]; do
      if ${pkgs.systemd}/bin/systemctl is-active --quiet openclaw-embeddings.service \
        && ${pkgs.coreutils}/bin/timeout 2 ${pkgs.bash}/bin/bash -c '</dev/tcp/127.0.0.1/7997' 2>/dev/null; then
        exit 0
      fi

      ${pkgs.coreutils}/bin/sleep 2
    done

    ${pkgs.systemd}/bin/systemctl --no-pager --full status openclaw-embeddings.service || true
    exit 1
  '';
  configFile = pkgs.writeText "openclaw-gateway.json" (
    builtins.toJSON {
      wizard = {
        lastRunAt = "2026-03-12T08:09:41.919Z";
        lastRunVersion = "2026.3.8";
        lastRunCommand = "onboard";
        lastRunMode = "local";
      };
      auth = {
        profiles = {
          "openai-codex:default" = {
            provider = "openai-codex";
            mode = "oauth";
          };
          "openai-codex:teamzerogravity100@gmail.com" = {
            provider = "openai-codex";
            mode = "oauth";
            email = "teamzerogravity100@gmail.com";
          };
        };
        order = {
          openai-codex = [ "openai-codex:teamzerogravity100@gmail.com" ];
        };
      };
      agents = {
        defaults = {
          model = {
            primary = "openai-codex/gpt-5.4";
          };
          thinkingDefault = "high";
          workspace = "/home/iva/.openclaw/workspace";
          compaction = {
            mode = "safeguard";
          };
          maxConcurrent = 4;
          subagents = {
            maxConcurrent = 8;
          };
          memorySearch = {
            enabled = true;
            provider = "openai";
            fallback = "none";
            model = "${cfg.modelId}@${cfg.modelRevision}";
            remote = {
              baseUrl = "http://127.0.0.1:7997/";
              apiKey = "openclaw-local-infinity";
            };
          };
        };
      };
      tools = {
        profile = "coding";
        sessions = {
          visibility = "all";
        };
        agentToAgent = {
          enabled = true;
        };
        web = {
          search = {
            enabled = false;
          };
        };
      };
      messages = {
        ackReactionScope = "group-mentions";
        groupChat = {
          visibleReplies = "automatic";
        };
      };
      commands = {
        native = "auto";
        nativeSkills = false;
        restart = true;
        ownerDisplay = "raw";
      };
      session = {
        dmScope = "per-channel-peer";
      };
      hooks = {
        internal = {
          enabled = true;
          entries = {
            "boot-md" = { enabled = true; };
            "bootstrap-extra-files" = { enabled = true; };
            "command-logger" = { enabled = true; };
            "session-memory" = { enabled = true; };
          };
        };
      };
      channels = { };
      gateway = {
        port = 18789;
        mode = "local";
        bind = "loopback";
        auth = {
          mode = "token";
          token = "openclaw-local-gateway";
        };
        tailscale = {
          mode = "off";
          resetOnExit = false;
        };
        nodes = {
          denyCommands = [
            "camera.snap"
            "camera.clip"
            "screen.record"
            "contacts.add"
            "calendar.add"
            "reminders.add"
            "sms.send"
          ];
        };
      };
      plugins = {
        entries = {
          acpx = {
            enabled = true;
            config = {
              permissionMode = "approve-all";
              nonInteractivePermissions = "fail";
              agents = {
                codex = {
                  command = lib.getExe acpxWrapper;
                };
              };
            };
          };
        };
      };
      acp = {
        enabled = true;
        backend = "acpx";
        defaultAgent = "codex";
        allowedAgents = [ "pi" "claude" "codex" "opencode" "gemini" "kimi" ];
      };
      meta = {
        lastTouchedVersion = "2026.3.8";
        lastTouchedAt = "2026-03-12T08:09:41.947Z";
      };
    }
  );
in
lib.mkIf openclawEnabled {
  systemd.tmpfiles.rules = [
    "r ${userHome}/.config/systemd/user/openclaw-gateway.service"
    "r ${userHome}/.config/systemd/user/default.target.wants/openclaw-gateway.service"
  ];

  systemd.services.openclaw-gateway = {
    description = "OpenClaw Gateway";
    after = [
      "network-online.target"
      "openclaw-embeddings.service"
    ];
    wants = [
      "network-online.target"
      "openclaw-embeddings.service"
    ];
    requires = [ "openclaw-embeddings.service" ];
    bindsTo = [ "openclaw-embeddings.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      StartLimitIntervalSec = "0";
      OnFailure = [ "service-failure-report@%n.service" ];
    };

    serviceConfig = {
      User = user;
      WorkingDirectory = userHome;
      ExecStartPre = waitForEmbeddings;
      ExecStart = "${openclawBin} gateway run --port 18789";
      Restart = "always";
      RestartSec = "30s";
      TimeoutStopSec = 30;
      TimeoutStartSec = "6min";
      SuccessExitStatus = [ "0" "143" ];
      KillMode = "control-group";
      Environment = [
        "HOME=${userHome}"
        "TMPDIR=/tmp"
        "NODE_OPTIONS=--dns-result-order=verbatim"
        "PATH=${openclawPath}"
        "NODE_PATH=${openclaw}/lib/openclaw/node_modules"
        "OPENCLAW_TELEGRAM_USE_GLOBAL_FETCH=1"
        "OPENCLAW_TELEGRAM_ENABLE_AUTO_SELECT_FAMILY=1"
        "OPENCLAW_TELEGRAM_DNS_RESULT_ORDER=verbatim"
        "OPENCLAW_STATE_DIR=${stateDir}"
        "OPENCLAW_CONFIG_PATH=${configFile}"
        "OPENCLAW_GATEWAY_PORT=18789"
        "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
        "OPENCLAW_SERVICE_MARKER=openclaw"
        "OPENCLAW_SERVICE_KIND=gateway"
      ];
    };
  };

  systemd.services.openclaw-gateway-resume = {
    description = "Restart OpenClaw Gateway after resume";
    after = [ "post-resume.target" ];
    wantedBy = [ "post-resume.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl try-restart openclaw-gateway.service";
    };
  };
}
