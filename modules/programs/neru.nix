{ pkgs, ... }:
let
  neru = pkgs.callPackage ../../pkgs/neru/package.nix { };
  neruConfig = pkgs.writeText "neru-linux-config.toml" ''
    [systray]
    enabled = false
  '';
in
{
  environment.systemPackages = [ neru ];

  # Neru is still upstream-macOS-first. On Linux this keeps the daemon alive
  # under systemd so IPC and manual testing work, but most features remain stubs.
  systemd.user.services.neru = {
    description = "Neru keyboard navigation daemon";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f /tmp/neru.sock";
      ExecStart = "${neru}/bin/neru launch --config ${neruConfig}";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -f /tmp/neru.sock";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
