{ config, inputs, lib, pkgs, ... }:
let
  voxtypePackage = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./patches/voxtype-clipboard-restore-no-newline.patch
    ];
  });
  voxtypeModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
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
  imports = [
    inputs.voxtype.nixosModules.default
  ];

  programs.voxtype = {
    enable = true;
    package = voxtypePackage;
  };

  environment.etc."voxtype/iva.toml".text = ''
    engine = "whisper"

    [audio]
    device = "default"
    max_duration_secs = 60
    sample_rate = 16000

    [hotkey]
    enabled = true
    key = "Insert"
    modifiers = ["LEFTCTRL"]

    [output]
    mode = "paste"
    paste_keys = "shift+insert"
    restore_clipboard = true
    restore_clipboard_delay_ms = 250

    [output.notification]
    on_recording_start = false
    on_recording_stop = false
    on_transcription = false

    [whisper]
    language = ["en", "ru", "fr", "ro"]
    model = "${voxtypeModel}"
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
