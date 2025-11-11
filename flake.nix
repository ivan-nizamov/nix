{
  description = "…";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/laptop/configuration.nix
            ./hosts/laptop/hardware-configuration.nix
          ];
        };
      };

      # Stow config for dotfiles
      homeConfigurations = {
        dotfiles = nixpkgs.lib.mkHomeConfiguration {
          name = "dotfiles";
          home.file = {
            ".config/Code/User/settings.json" = {
              source = ./dotfiles/vscode/.config/Code/User/settings.json;
            };
          };
        };
      };
    };
}
