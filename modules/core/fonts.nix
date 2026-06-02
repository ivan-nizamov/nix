{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.inter
    pkgs.inter-nerdfont
    pkgs.nerd-fonts.symbols-only
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter Nerd Font" ];
    serif = [ "Inter Nerd Font" ];
    monospace = [ "Inter Nerd Font" ];
  };
}
