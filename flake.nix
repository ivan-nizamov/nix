{
  description = "NixOS Configuration for Laptop and Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    ayugram-desktop = {
      url = "github:ndfined-crp/ayugram-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yandex-browser = {
      url = "github:miuirussia/yandex-browser.nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    zen-browser,
    nixos-hardware,
    yandex-browser,
    opencode,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    # Renamed 'hosts' to 'hostConfigs' to avoid confusion with the mapping in nixosConfigurations
    hostConfigs = {
      laptop = {
        nixos = ./hosts/laptop/configuration.nix;
        home = ./hosts/laptop/gnome.nix;
      };
      mainframe = {
        nixos = ./hosts/mainframe/configuration.nix;
        home = ./hosts/mainframe/gnome.nix;
        modules = [];
      };
    };

    mkHost = hostName: {
      nixos,
      home,
      modules ? [],
      pkgsInput ? nixpkgs,
    }:
      pkgsInput.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          inherit zen-browser;
          inherit system;
          inherit nixpkgs-stable;
          inherit yandex-browser;
        };
        modules =
          [
            nixos
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs;
                inherit zen-browser;
                inherit system;
                inherit nixpkgs-stable;
                inherit yandex-browser;
              };
              home-manager.users.iva = import home;
            }
          ]
          ++ modules;
      };
  in {
    # Map over hostConfigs to create nixosConfigurations
    nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hostConfigs;

    formatter.${system} = nixpkgs.legacyPackages.${system}.writeShellScriptBin "fmt" ''
      set -euo pipefail
      exec ${nixpkgs.legacyPackages.${system}.alejandra}/bin/alejandra .
    '';
  };
}
