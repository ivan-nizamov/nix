{
  description = "NixOS configuration for mainframe";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.mainframe = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/mainframe
      ];
    };
  };
}
