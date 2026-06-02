{ lib, pkgs, ... }:
let
  authorizedKeys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC6c02OUO91PVjekgVQwrdthUCJAo4ARfH1Nr5ktRcoG9j4dNEw6NUJiwbPr6VpMDNgAn4MVdVnR6U+lV25nM25Dd2tV/fnb0NXhMexp/pAEsGgY+4LEVOgL+DFWPD5mtjRtFrDtlLlUYnZyByLVh9h/ISH+neNN53X1qSa7W6yt++g3CUg7wjrWVuGIUiN5lYj+5VdEdJT31Vmyu6avzmQmjK04zmHACo7sUPsgVh6KXC9nE14Kx0cVJ0zzxeBG6YJZrXXjTwHGKpxu6IK5tdkImM+qnq+yCFFVfRgwt7IcxRDxfXs1sMaCGOi/4doP5zB109Scf6Ax9n8zGROc7MwJe7Ab29Yih1OOvgkb40G7WjoR3gfO6pIL01ZxkfEGsrdkD6RntD5P3XYfE4nvHOq9P3phI7mUvpT/xieo/6oF7b1qAbXw1zobr9+c7w0j8/CXiDYrEKbOGv4ASzffk72i/4VyAC5rlZ8Ay0yrudt0uZ7O4q6OPJyv3uKHXXX6i39EmTwd+rk32f5/kDCwcwn+tpp2n9e+um+q496Sc4BA5Eo7ndlSN4smVQUn/uRL3JdfTVKua83U3X9503dOhOHhlSja5eJr/qrDiApLH20cK84JcnZSaizXrdHAFFL45vbBtrG52BELB5Cp/kkdD0H3c8fpqQlWXW8AMZFfdl5zQ=="
  ];
in
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/core/locale.nix
    ../../modules/core/memory.nix
    ../../modules/core/nix-settings.nix
    ../../modules/users/iva.nix
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "mainframe";
  networking.useDHCP = false;
  networking.networkmanager.enable = lib.mkForce false;

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.iva.openssh.authorizedKeys.keys = authorizedKeys;

  services.openssh.enable = true;
  services.openssh.openFirewall = false;
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
    allowedUDPPorts = [ ];
  };

  services.qemuGuest.enable = true;

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    tmux
    vim
    wget
  ];

  system.stateVersion = "26.05";
}
