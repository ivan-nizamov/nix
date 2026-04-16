{ inputs, lib, pkgs, ... }:
let
  user = "iva";
  userHome = "/home/iva";
  stateDir = "${userHome}/.openclaw";
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  openclaw = llmAgentsPkgs.openclaw;
  openclawBin = lib.getExe openclaw;
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
            model = "Alibaba-NLP/gte-modernbert-base@e7f32e3c00f91d699e8c43b53106206bcc72bb22";
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
            enabled = true;
            provider = "duckduckgo";
          };
        };
      };
      messages = {
        ackReactionScope = "group-mentions";
      };
      commands = {
        native = "auto";
        nativeSkills = "auto";
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
      channels = {
        telegram = {
          enabled = true;
          dmPolicy = "pairing";
          botToken = "8741182257:AAFouGomF9j5BJVw3DqBYWoROGO-nu35gyM";
          allowFrom = [ "5180423459" ];
          groupPolicy = "allowlist";
          groupAllowFrom = [ "5180423459" ];
          groups = {
            "-1003536453089" = {
              requireMention = false;
              allowFrom = [ "5180423459" ];
            };
          };
          streaming = {
            mode = "partial";
          };
          execApprovals = {
            enabled = true;
            approvers = [ "5180423459" ];
            target = "dm";
          };
        };
      };
      gateway = {
        port = 18789;
        mode = "local";
        bind = "loopback";
        auth = {
          mode = "token";
          token = "51dad458a046f3bf55da8bf17fedb9089ddc63bf6949becc";
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
          telegram = {
            enabled = true;
          };
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
{
  systemd.tmpfiles.rules = [
    "r ${userHome}/.config/systemd/user/openclaw-gateway.service"
    "r ${userHome}/.config/systemd/user/default.target.wants/openclaw-gateway.service"
  ];

  systemd.services.openclaw-gateway = {
    description = "OpenClaw Gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      StartLimitIntervalSec = "10min";
      StartLimitBurst = 5;
      OnFailure = [ "service-failure-report@%n.service" ];
    };

    serviceConfig = {
      User = user;
      WorkingDirectory = userHome;
      ExecStart = "${openclawBin} gateway run --port 18789";
      Restart = "always";
      RestartSec = "15s";
      TimeoutStopSec = 30;
      TimeoutStartSec = 30;
      SuccessExitStatus = [ "0" "143" ];
      KillMode = "control-group";
      Environment = [
        "HOME=${userHome}"
        "TMPDIR=/tmp"
        "PATH=${openclawPath}"
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
