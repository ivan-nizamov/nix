{
  description = "NixOS configuration for thinkpad and mainframe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-06cb-009a-fingerprint-sensor = {
      url = "github:ahbnr/nixos-06cb-009a-fingerprint-sensor?ref=25.05";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    {
      nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
          inherit (inputs) nixos-hardware;
        };
        modules = [
          ({ ... }: {
            nixpkgs.overlays = [ inputs.helium.overlays.default ];
          })
          inputs.nixos-06cb-009a-fingerprint-sensor.nixosModules."06cb-009a-fingerprint-sensor"
          ./hosts/thinkpad
        ];
      };

      nixosConfigurations.mainframe = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
        };
        modules = [
          ({ ... }: {
            nixpkgs.overlays = [ inputs.helium.overlays.default ];
          })
          ./hosts/mainframe
        ];
      };
    };
}
