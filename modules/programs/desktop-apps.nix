{ self, pkgs, ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "yandex-browser-26.3.1.1088-1"
  ];

  environment.systemPackages = [
    pkgs.brave
    self.packages.${pkgs.stdenv.hostPlatform.system}.happ
  ];
}
