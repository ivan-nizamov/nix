{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.inter
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.symbols-only
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" ];
    serif = [ "Inter" ];
    monospace = [ "FiraCode Nerd Font" ];
  };
}
