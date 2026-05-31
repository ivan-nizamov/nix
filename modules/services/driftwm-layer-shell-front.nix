{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  driftwmPackage = inputs.driftwm.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../pkgs/driftwm-layer-shell-front.patch ];
  });

  driftwm = pkgs.symlinkJoin {
    name = "${driftwmPackage.name}-layer-shell-front-session";
    paths = [ driftwmPackage ];
    passthru.providedSessions = [ "driftwm" ];
    postBuild = ''
      service_file="$out/share/systemd/user/driftwm.service"
      desktop_file="$out/share/wayland-sessions/driftwm.desktop"

      rm "$service_file" "$desktop_file"
      install -Dm0644 ${driftwmPackage}/share/systemd/user/driftwm.service "$service_file"
      install -Dm0644 ${driftwmPackage}/share/wayland-sessions/driftwm.desktop "$desktop_file"

      substituteInPlace "$service_file" \
        --replace-fail 'ExecStart=driftwm' "ExecStart=$out/bin/driftwm"
      substituteInPlace "$desktop_file" \
        --replace-fail 'Exec=driftwm-session' "Exec=$out/bin/driftwm-session"
    '';
  };
in
{
  environment.systemPackages = [ driftwm ];

  services.displayManager.sessionPackages = lib.mkForce [ driftwm ];

  systemd.user.services.driftwm = {
    description = "driftwm, a trackpad-first infinite canvas Wayland compositor";
    bindsTo = [ "graphical-session.target" ];
    before = [
      "graphical-session.target"
      "xdg-desktop-autostart.target"
    ];
    wants = [
      "graphical-session-pre.target"
      "xdg-desktop-autostart.target"
    ];
    after = [ "graphical-session-pre.target" ];

    serviceConfig = {
      Slice = "session.slice";
      Type = "notify";
      NotifyAccess = "main";
      ExecStart = "${driftwm}/bin/driftwm";
    };
  };
}
