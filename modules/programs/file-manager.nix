{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.nautilus ];

  services.gvfs.enable = true;
  services.udisks2.enable = true;

  xdg.mime = {
    enable = true;
    defaultApplications."inode/directory" = "org.gnome.Nautilus.desktop";
  };
}
