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
      hosts = {
        laptop = ./hosts/laptop/configuration.nix;
        desktop = ./hosts/desktop/configuration.nix;
      };
      mkHost = configPath:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit zen-browser;
          };
          modules = [ configPath ];
        };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs (_: configPath: mkHost configPath) hosts;
    };
}
