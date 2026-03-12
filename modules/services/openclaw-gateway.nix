{ inputs, lib, pkgs, ... }:
let
  user = "iva";
  userHome = "/home/iva";
  openclaw = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.openclaw;
  openclawBin = lib.getExe openclaw;
  openclawPath = lib.concatStringsSep ":" [
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
