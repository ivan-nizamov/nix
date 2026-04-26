{ pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKpHMUJk8uBJ1sMaSnj2jT1mSU2r10KS5FtApuVkEvHO"
    ];
    shell = pkgs.zsh;
  };
}
