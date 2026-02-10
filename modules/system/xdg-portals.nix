{pkgs, ...}: {
  # Wayland desktop integration (file picker, open-url, screen sharing, etc.).
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  environment.sessionVariables.GTK_USE_PORTAL = "1";
}
