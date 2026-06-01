{ pkgs, ... }:
let
  sessionEnv = ''
    export HOME="''${HOME:-/home/iva}"
    export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
    user_id=$(${pkgs.coreutils}/bin/id -u)
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$user_id}"
    export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

    ${pkgs.coreutils}/bin/mkdir -p "$XDG_CACHE_HOME"

    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
        [ -S "$socket" ] || continue
        export WAYLAND_DISPLAY=$(${pkgs.coreutils}/bin/basename "$socket")
        break
      done
    fi
  '';

  notify = app: title: body: ''
    ${pkgs.libnotify}/bin/notify-send \
      -a ${app} \
      -h string:x-canonical-private-synchronous:${app} \
      ${title} ${body} || true
  '';

  volumeCommand = name: action:
    pkgs.writeShellScriptBin name ''
      set -eu

      ${sessionEnv}

      ${action}
      status=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
      ${notify name "'Volume'" "\"$status\""}
      printf '%s\n' "$status"
    '';

  volumeUp = volumeCommand "volume-up" ''
    ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    ${pkgs.wireplumber}/bin/wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
  '';
  volumeDown = volumeCommand "volume-down" ''
    ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  '';
  volumeToggle = volumeCommand "volume-toggle" ''
    ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  '';

  brightnessCommand = name: action:
    pkgs.writeShellScriptBin name ''
      set -eu

      ${sessionEnv}

      ${pkgs.brillo}/bin/brillo ${action}
      level=$(${pkgs.brillo}/bin/brillo -G)
      percent=$(${pkgs.coreutils}/bin/printf '%.0f' "$level")
      ${pkgs.libnotify}/bin/notify-send \
        -a brightness \
        -h string:x-canonical-private-synchronous:brightness \
        -h int:value:"$percent" \
        'Brightness' "Brightness: $percent%" || true
      printf 'Brightness: %s%%\n' "$percent"
    '';

  brightnessUp = brightnessCommand "brightness-up" "-A 5";
  brightnessDown = brightnessCommand "brightness-down" "-U 5";

  screenshotRegion = pkgs.writeShellScriptBin "screenshot-region" ''
    set -eu

    ${sessionEnv}

    dir="$HOME/Pictures/Screenshots"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    file="$dir/$(${pkgs.coreutils}/bin/date +%Y-%m-%d-%H%M%S).png"

    geometry=$(${pkgs.slurp}/bin/slurp) || exit 0
    ${pkgs.grim}/bin/grim -g "$geometry" "$file"
    ${pkgs.wl-clipboard}/bin/wl-copy --type image/png < "$file" || true

    ${notify "screenshot-region" "'Screenshot'" "\"Saved and copied to clipboard\""}
    printf '%s\n' "$file"
  '';
in
{
  environment.systemPackages = [
    brightnessDown
    brightnessUp
    pkgs.brillo
    pkgs.brightnessctl
    screenshotRegion
    volumeDown
    volumeToggle
    volumeUp
    pkgs.wl-clipboard
  ];

  hardware.brillo.enable = true;

  users.users.iva.extraGroups = [ "video" ];

  services.triggerhappy = {
    enable = true;
    user = "iva";
    bindings = [
      {
        keys = [ "VOLUMEDOWN" ];
        cmd = "${volumeDown}/bin/volume-down";
      }
      {
        keys = [ "VOLUMEUP" ];
        cmd = "${volumeUp}/bin/volume-up";
      }
      {
        keys = [ "MUTE" ];
        cmd = "${volumeToggle}/bin/volume-toggle";
      }
      {
        keys = [ "BRIGHTNESSDOWN" ];
        cmd = "${brightnessDown}/bin/brightness-down";
      }
      {
        keys = [ "BRIGHTNESSUP" ];
        cmd = "${brightnessUp}/bin/brightness-up";
      }
      {
        keys = [ "SYSRQ" ];
        cmd = "${screenshotRegion}/bin/screenshot-region";
      }
    ];
  };
}
