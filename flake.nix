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
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ayugram-desktop = {
      url = "github:ndfined-crp/ayugram-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, nixos-hardware, winapps, ... }@inputs:
    let
      system = "x86_64-linux";
      # Renamed 'hosts' to 'hostConfigs' to avoid confusion with the mapping in nixosConfigurations
      hostConfigs = {
        laptop = {
          nixos = ./hosts/laptop/configuration.nix;
          home = ./hosts/laptop/gnome.nix;
        };
        legion = {
          nixos = ./hosts/legion/configuration.nix;
          home = ./hosts/legion/gnome.nix;
          modules = [ nixos-hardware.nixosModules.lenovo-legion-15ach6h ];
        };
      };

      mkHost = hostName: config: # Takes hostName and the config object { nixos, home }
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; inherit zen-browser; inherit system; inherit winapps; }; # Used `inputs` as suggested in prompt for flexibility
          modules = [
            config.nixos
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.iva = import config.home;
            }
          ] ++ (config.modules or []) ++ [ # Add winapps module
            ({ pkgs, system ? pkgs.system, ... }: {
              nix.settings = {
                substituters = [ "https://winapps.cachix.org/" ];
                trusted-public-keys =
                  [ "winapps.cachix.org-1:HI82jWrXZsQRar/PChgIx1unmuEsiQMQq+zt05CD36g=" ];
              };

              environment.systemPackages = [
                winapps.packages."${system}".winapps
                winapps.packages."${system}".winapps-launcher # optional tray launcher
              ];
            })
          ];
        };
    in {
      # Map over hostConfigs to create nixosConfigurations
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hostConfigs;
    };
}
