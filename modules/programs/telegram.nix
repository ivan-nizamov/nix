{ pkgs, ... }:
let
  telegramLauncher = pkgs.writeShellScriptBin "telegram" ''
    export QT_QPA_PLATFORM=xcb
    exec Telegram "$@"
  '';
in
{
  environment.systemPackages = [ telegramLauncher ];
}
