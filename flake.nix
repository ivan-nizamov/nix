{
  description = "NixOS configuration for thinkpad";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    llm-agents.url = "github:numtide/llm-agents.nix";
    helium = {
      url = "github:schembriaiden/helium-browser-nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    driftwm.url = "github:malbiruk/driftwm";
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
          ./hosts/thinkpad
        ];
      };

    };
}
