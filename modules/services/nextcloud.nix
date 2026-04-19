{ lib, pkgs, ... }:
let
  hostName = "mainframe.local";
  adminUser = "iva";
  adminPassFile = "/home/iva/.config/nextcloud-admin-pass";
in
{
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
      domain = true;
    };
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = hostName;
    https = false;
    notify_push = {
      enable = true;
      bendDomainToLocalhost = true;
    };
    database.createLocally = true;

    extraApps = {
      inherit (pkgs.nextcloud33Packages.apps)
        deck
        spreed
        ;
    };

    config = {
      adminuser = adminUser;
      adminpassFile = adminPassFile;
      dbtype = "pgsql";
    };

    settings = {
      trusted_domains = [
        "localhost"
        "127.0.0.1"
        "::1"
        "mainframe"
      ];
      overwriteprotocol = "http";
      "overwrite.cli.url" = "http://${hostName}";
      default_phone_region = "RO";
    };

    # The module defaults are sized for a larger shared server.
    poolSettings = {
      "pm" = "dynamic";
      "pm.max_children" = 24;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 4;
      "pm.max_requests" = 200;
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  system.activationScripts.nextcloudBootstrapAdminPassword.text =
    let
      install = lib.getExe' pkgs.coreutils "install";
      mktemp = lib.getExe' pkgs.coreutils "mktemp";
      rm = lib.getExe' pkgs.coreutils "rm";
      tr = lib.getExe' pkgs.coreutils "tr";
      openssl = lib.getExe' pkgs.openssl "openssl";
    in
    ''
      admin_pass_file=${lib.escapeShellArg adminPassFile}

      if [ ! -s "$admin_pass_file" ]; then
        tmp_file="$(${mktemp})"
        ${openssl} rand -base64 24 | ${tr} -d '\n' > "$tmp_file"
        printf '\n' >> "$tmp_file"
        ${install} -D -o ${adminUser} -g users -m 0600 "$tmp_file" "$admin_pass_file"
        ${rm} -f "$tmp_file"
      fi
    '';
}
