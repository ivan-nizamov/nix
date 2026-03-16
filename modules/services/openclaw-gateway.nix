{ inputs, lib, pkgs, ... }:
let
  user = "iva";
  userHome = "/home/iva";
  stateDir = "${userHome}/.openclaw";
  openclaw = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
  openclawBin = lib.getExe openclaw;
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
        web = {
          search = {
            enabled = true;
            provider = "brave";
            apiKey = "756284";
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
          groupPolicy = "allowlist";
          streaming = "partial";
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
              expectedVersion = "any";
              permissionMode = "approve-all";
              nonInteractivePermissions = "fail";
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
