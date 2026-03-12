{ pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" ];
    linger = true;
    shell = pkgs.zsh;
  };
}
