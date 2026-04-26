{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  boot.extraModulePackages = [ ];
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/" = {
    device = "/dev/sda3";
    fsType = "xfs";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
