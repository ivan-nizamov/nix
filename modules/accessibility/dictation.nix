{ config, inputs, lib, pkgs, ... }:
let
  eitypePackage = pkgs.python313Packages.buildPythonApplication rec {
    pname = "eitype";
    version = "0.2.0";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/59/96/a3480adccc998ff4a86a53711765af0874edc0ab27f61982000df7a71f1c/eitype-0.2.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      hash = "sha256-A68B6NUPW6lY7SgtHi3raqV99xcxN3aAdAnT2l7XM2I=";
    };

    pythonImportsCheck = [ "eitype" ];

    meta = with lib; {
      description = "Type text on Wayland using the Emulated Input protocol";
      homepage = "https://github.com/Adam-D-Lewis/eitype";
      license = licenses.asl20;
      platforms = platforms.linux;
      mainProgram = "eitype";
    };
  };
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
    eitypePackage
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

  environment.systemPackages = [
    eitypePackage
  ];

  environment.etc."voxtype/iva.toml".text = ''
    engine = "whisper"

    [audio]
    device = "default"
    max_duration_secs = 60
    sample_rate = 16000

    [hotkey]
    enabled = true
    key = "Insert"

    [output]
    mode = "type"
    driver_order = ["eitype", "dotool", "clipboard"]
    pre_type_delay_ms = 400

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
