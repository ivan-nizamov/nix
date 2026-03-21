{ config, inputs, lib, pkgs, ... }:
let
  eitypePythonPackage = pkgs.python313Packages.buildPythonPackage rec {
    pname = "eitype";
    version = "0.2.0";
    format = "wheel";

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/59/96/a3480adccc998ff4a86a53711765af0874edc0ab27f61982000df7a71f1c/eitype-0.2.0-cp313-cp313-manylinux_2_28_x86_64.whl";
      hash = "sha256-A68B6NUPW6lY7SgtHi3raqV99xcxN3aAdAnT2l7XM2I=";
    };

    pythonImportsCheck = [ "eitype" ];
  };

  eitypePython = pkgs.python313.withPackages (_: [
    eitypePythonPackage
  ]);

  eitypeCli = pkgs.writeText "eitype-cli.py" ''
    import argparse
    import os
    import sys
    from pathlib import Path

    from eitype import EiType, EiTypeConfig


    def token_path() -> Path:
        cache_home = os.environ.get("XDG_CACHE_HOME")
        if cache_home:
            return Path(cache_home) / "eitype" / "restore_token"
        return Path.home() / ".cache" / "eitype" / "restore_token"


    def load_token() -> str | None:
        path = token_path()
        try:
            token = path.read_text(encoding="utf-8").strip()
        except FileNotFoundError:
            return None
        return token or None


    def save_token(token: str | None) -> None:
        if not token:
            return
        path = token_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(token, encoding="utf-8")


    def build_config(args: argparse.Namespace) -> EiTypeConfig:
        return EiTypeConfig(
            layout=args.layout,
            variant=args.variant,
            model=args.model,
            options=args.options,
            layout_index=args.layout_index,
            delay_ms=args.delay,
        )


    def connect(args: argparse.Namespace, config: EiTypeConfig):
        socket_path = args.socket or os.environ.get("LIBEI_SOCKET")
        if socket_path:
            return EiType.connect_socket(socket_path, config)

        restore_token = None if args.reset_token else load_token()
        typer, new_token = EiType.connect_portal_with_token(restore_token, config)
        save_token(new_token)
        return typer


    def main() -> int:
        parser = argparse.ArgumentParser(prog="eitype")
        parser.add_argument("-d", "--delay", type=int, default=0)
        parser.add_argument("-l", "--layout")
        parser.add_argument("--variant")
        parser.add_argument("--model")
        parser.add_argument("--options")
        parser.add_argument("--layout-index", type=int)
        parser.add_argument("-s", "--socket")
        parser.add_argument("--reset-token", action="store_true")
        parser.add_argument("-k", "--key", action="append", default=[])
        parser.add_argument("-M", "--modifier", action="append", default=[])
        parser.add_argument("-P", "--press-modifier", action="append", default=[])
        parser.add_argument("-v", "--verbose", action="count", default=0)
        parser.add_argument("text", nargs="*")
        args = parser.parse_args()

        if not args.key and not args.press_modifier and not args.text:
            parser.print_help()
            return 0

        config = build_config(args)
        typer = connect(args, config)

        try:
            for modifier in args.press_modifier:
                typer.press_modifier(modifier)

            if args.modifier:
                for modifier in args.modifier:
                    typer.hold_modifier(modifier)

            for key in args.key:
                typer.press_key(key)

            for text in args.text:
                typer.type_text(text)
        finally:
            try:
                typer.release_modifiers()
            except Exception:
                pass
            typer.close()

        return 0


    if __name__ == "__main__":
        sys.exit(main())
  '';

  eitypePackage = (pkgs.writeShellScriptBin "eitype" ''
    exec ${eitypePython}/bin/python ${eitypeCli} "$@"
  '').overrideAttrs (_: {
    meta = with lib; {
      description = "Type text on Wayland using the Emulated Input protocol";
      homepage = "https://github.com/Adam-D-Lewis/eitype";
      license = licenses.asl20;
      platforms = platforms.linux;
      mainProgram = "eitype";
    };
  });
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
