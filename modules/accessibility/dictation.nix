{ config, inputs, lib, pkgs, ... }:
let
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  voxtypePackage = unstablePkgs.voxtype;
  voxtypeModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
  voxtypePath = lib.makeBinPath [
    pkgs.dotool
    pkgs.wl-clipboard
    pkgs.wtype
    pkgs.ydotool
  ];
  userHome = config.users.users.iva.home;
in
{
  environment.systemPackages = [ voxtypePackage ];

  environment.etc."voxtype/iva.toml".text = ''
    engine = "whisper"
    state_file = "auto"

    [audio]
    device = "default"
    max_duration_secs = 20
    sample_rate = 16000

    [hotkey]
    enabled = true
    key = "Insert"

    [output]
    mode = "paste"
    paste_keys = "ctrl+shift+v"
    pre_type_delay_ms = 400
    restore_clipboard = false

    [output.notification]
    on_recording_start = false
    on_recording_stop = false
    on_transcription = false

    [whisper]
    language = "en"
    model = "${voxtypeModel}"
    mode = "local"
    threads = 4
    translate = false
  '';

  systemd.tmpfiles.rules = [
    "d ${userHome}/.config/voxtype 0755 iva users - -"
    "L+ ${userHome}/.config/voxtype/config.toml - - - - /etc/voxtype/iva.toml"
  ];

  systemd.user.services.voxtype = {
    description = "VoxType push-to-talk voice-to-text daemon";
    after = [ "graphical-session.target" "sound.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "default.target" "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${voxtypePackage}/bin/voxtype daemon";
      Restart = "always";
      RestartSec = "5s";
      Environment = [
        "YDOTOOL_SOCKET=/run/ydotoold/socket"
        "PATH=${voxtypePath}:/run/current-system/sw/bin"
      ];
    };
  };
}
