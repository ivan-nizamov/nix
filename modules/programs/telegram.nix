{ pkgs, ... }:
let
  telegramLauncher = pkgs.writeShellScriptBin "telegram" ''
    exec Telegram "$@"
  '';
in
{
  environment.systemPackages = [ telegramLauncher ];
}
