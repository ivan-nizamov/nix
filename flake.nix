{
  description = "NixOS configuration for mainframe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    voxtype.url = "github:peteonrails/voxtype?ref=v0.6.3";
  };

  outputs = inputs@{ nixpkgs, ... }: {
    nixosConfigurations.mainframe = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
      };
      modules = [
        ./hosts/mainframe
      ];
    };
  };
}
