{
  description = "NixOS configuration for thinkpad and mainframe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    llm-agents.url = "github:numtide/llm-agents.nix";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
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
          ./hosts/thinkpad
        ];
      };

      nixosConfigurations.mainframe = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs self;
        };
        modules = [
          ./hosts/mainframe
        ];
      };
    };
}
