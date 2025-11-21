{
  description = "NixOS Configuration for Laptop and Desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, ... }@inputs:
    let
      system = "x86_64-linux";
      # Renamed 'hosts' to 'hostConfigs' to avoid confusion with the mapping in nixosConfigurations
      hostConfigs = {
        laptop = {
          nixos = ./hosts/laptop/configuration.nix;
          home = ./hosts/laptop/gnome.nix;
        };
        desktop = {
          nixos = ./hosts/desktop/configuration.nix;
          home = ./hosts/desktop/gnome.nix;
        };
      };

      mkHost = hostName: config: # Takes hostName and the config object { nixos, home }
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; inherit zen-browser; }; # Used `inputs` as suggested in prompt for flexibility
          modules = [
            config.nixos
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.iva = import config.home;
            }
          ];
        };
    in {
      # Map over hostConfigs to create nixosConfigurations
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hostConfigs;
    };
}
