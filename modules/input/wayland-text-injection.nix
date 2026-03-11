{ ... }:
{
  programs.ydotool.enable = true;

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';

  system.activationScripts.uinputPermissions = ''
    if [ -e /dev/uinput ]; then
      chgrp input /dev/uinput
      chmod 0660 /dev/uinput
    fi
  '';
}
