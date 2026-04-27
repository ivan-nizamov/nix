{ config, lib, pkgs, ... }:
let
  hostName = "mainframe.tail506f5b.ts.net";
  listenPort = 8080;
  adminPassFile = "/var/lib/nextcloud-secrets/admin-pass";
in
{
  system.activationScripts.nextcloudAdminPassword = ''
    install -d -m 0700 -o root -g root /var/lib/nextcloud-secrets
    if [ ! -s ${adminPassFile} ]; then
      umask 077
      ${lib.getExe pkgs.openssl} rand -base64 32 > ${adminPassFile}
    fi
    chown root:root ${adminPassFile}
    chmod 0400 ${adminPassFile}
  '';

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    inherit hostName;
    https = true;
    maxUploadSize = "10G";
    autoUpdateApps.enable = true;
    configureRedis = true;
    database.createLocally = true;

    config = {
      dbtype = "pgsql";
      adminuser = "iva";
      adminpassFile = adminPassFile;
    };

    extraApps = with pkgs.nextcloud32Packages.apps; {
      inherit
        calendar
        contacts
        deck
        mail
        notes
        polls
        spreed
        tasks
        ;
    };

    settings = {
      default_phone_region = "RO";
      log_type = "systemd";
      maintenance_window_start = 2;
      overwriteprotocol = "https";
      trusted_proxies = [
        "127.0.0.1"
        "::1"
      ];
    };
  };

  services.nginx = {
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${hostName}.listen = [
      {
        addr = "127.0.0.1";
        port = listenPort;
      }
    ];
  };

  systemd.services.nextcloud-funnel = {
    description = "Public Tailscale Funnel for Nextcloud";
    after = [
      "network-online.target"
      "nginx.service"
      "tailscaled.service"
      "tailscaled-set.service"
    ];
    wants = [
      "network-online.target"
      "nginx.service"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ config.services.tailscale.package ];
    script = ''
      tailscale funnel --bg --https=443 http://127.0.0.1:${toString listenPort} || {
        echo "nextcloud-funnel: run 'sudo tailscale funnel --bg --https=443 http://127.0.0.1:${toString listenPort}' and approve Funnel if prompted" >&2
        exit 0
      }
    '';
  };
}
