{ ... }:
{
  services.udev.extraRules = ''
    ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", GROUP="plugdev", MODE="0660", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';
}
