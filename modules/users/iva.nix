{ pkgs, ... }:
{
  users.users.iva = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "ydotool" "plugdev" "dialout" ];
    linger = true;
    shell = pkgs.zsh;
  };
}
