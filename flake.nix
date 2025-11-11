{
  description = "…";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zen-browser, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {
        laptop = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit zen-browser;
          };
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
