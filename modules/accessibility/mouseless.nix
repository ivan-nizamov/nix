{ config, lib, pkgs, ... }:
let
  userName = "iva";
  userHome = config.users.users.${userName}.home;
  configPath = "/etc/mouseless/config.yaml";
  mouselessPackage = pkgs.stdenvNoCC.mkDerivation {
    pname = "mouseless";
    version = "0.3.0";

    src = pkgs.fetchurl {
      url = "https://github.com/jbensmann/mouseless/releases/download/v0.3.0/mouseless_linux_amd64.tar.gz";
      hash = "sha256-3I202brc6gKjOTNABldU0k64NQ9F13S+dOwO2nykxuA=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      tar -xzf $src
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 mouseless $out/bin/mouseless
      runHook postInstall
    '';

    meta = {
      description = "Replacement for the mouse in Linux";
      homepage = "https://github.com/jbensmann/mouseless";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "mouseless";
    };
  };
in
{
  boot.kernelModules = [ "uinput" ];

  environment.systemPackages = [
    mouselessPackage
  ];

  environment.etc."mouseless/config.yaml".source = ./mouseless-config.yaml;

  systemd.tmpfiles.rules = [
    "d ${userHome}/.config/mouseless 0755 ${userName} users - -"
    "L+ ${userHome}/.config/mouseless/config.yaml - - - - ${configPath}"
  ];

  systemd.user.services.mouseless = {
    description = "Keyboard-driven mouse control";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${lib.getExe mouselessPackage} --config ${configPath}";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
