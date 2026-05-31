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
  services.displayManager.sessionPackages = lib.mkForce [ driftwm ];
}
