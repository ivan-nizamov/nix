{
  # Secret Service provider for storing tokens/credentials in desktop sessions.
  services.gnome.gnome-keyring.enable = true;

  # Unlock keyring on login via PAM. Enable the common ones; unused entries are harmless.
  security.pam.services = {
    login.enableGnomeKeyring = true;
    gdm.enableGnomeKeyring = true;
    sddm.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
  };
}
