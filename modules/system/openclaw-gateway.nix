{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.services.openclaw-gateway;

  settingsPort = cfg.settings.gateway.port or cfg.port;

  effectiveSettings =
    # Provide a default port if the user doesn't specify one.
    lib.recursiveUpdate {gateway.port = cfg.port;} cfg.settings;

  configJson = builtins.toJSON effectiveSettings;
  configFile = pkgs.writeText "openclaw.json" configJson;
in {
  options.services.openclaw-gateway = {
    enable = lib.mkEnableOption "OpenClaw gateway (system service)";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.nix-openclaw.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "Package providing the `openclaw` binary.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "iva";
      description = "User account to run the gateway under.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "users";
      description = "Primary group for the service user.";
    };

    homeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}";
      description = "Home directory for the service user (used for HOME/working dir).";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.homeDir}/.openclaw";
      description = "State directory for OpenClaw (config, logs, sessions).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Gateway port (also written into the config if unset there).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the gateway port in the firewall.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "OpenClaw config (serialized to JSON and passed via OPENCLAW_CONFIG_PATH).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = settingsPort == cfg.port;
        message = "services.openclaw-gateway.settings.gateway.port must match services.openclaw-gateway.port";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.openclaw-gateway = {
      description = "OpenClaw gateway";
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        Restart = "always";
        RestartSec = "1s";
        Environment = [
          "HOME=${cfg.homeDir}"
          "OPENCLAW_CONFIG_PATH=${configFile}"
          "OPENCLAW_STATE_DIR=${cfg.stateDir}"
          "OPENCLAW_NIX_MODE=1"
        ];
        ExecStart = "${cfg.package}/bin/openclaw gateway --port ${toString cfg.port}";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];
  };
}
