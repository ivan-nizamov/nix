{ pkgs, ... }:
let
  micCommand = name: value:
    pkgs.writeShellScriptBin "mic-${name}" ''
      set -eu

      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"

      ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ ${value}
      status=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

      case "$status" in
        *'[MUTED]'*) message='Microphone muted' ;;
        *) message='Microphone unmuted' ;;
      esac

      printf '%s\n' "$message"
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        ${pkgs.libnotify}/bin/notify-send -a mic-${name} 'Microphone' "$message" || true
      fi
    '';
  micToggle = micCommand "toggle" "toggle";
  micUnmute = micCommand "unmute" "0";
in
{
  environment.systemPackages = with pkgs; [
    easyeffects
    micToggle
    micUnmute
  ];

  services.triggerhappy = {
    enable = true;
    user = "iva";
    bindings = [
      {
        keys = [ "MICMUTE" ];
        cmd = "${micToggle}/bin/mic-toggle";
      }
    ];
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
