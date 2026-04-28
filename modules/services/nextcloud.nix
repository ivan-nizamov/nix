{ config, lib, pkgs, ... }:
let
  hostName = "mainframe.tail506f5b.ts.net";
  listenPort = 8080;
  collaboraPort = 9980;
  internalNextcloudUrl = "http://127.0.0.1:${toString listenPort}";
  adminPassFile = "/var/lib/nextcloud-secrets/admin-pass";
  smtpPassFile = "/var/lib/nextcloud-secrets/smtp-pass";
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
    package = pkgs.nextcloud33;
    inherit hostName;
    https = true;
    maxUploadSize = "10G";
    autoUpdateApps.enable = true;
    configureRedis = true;
    database.createLocally = true;

    phpOptions."opcache.interned_strings_buffer" = "16";

    config = {
      dbtype = "pgsql";
      adminuser = "iva";
      adminpassFile = adminPassFile;
    };

    notify_push = {
      enable = true;
      nextcloudUrl = "https://${hostName}";
    };

    extraApps = with pkgs.nextcloud33Packages.apps; {
      inherit
        calendar
        contacts
        mail
        notes
        polls
        richdocuments
        spreed
        tasks
        ;
    };

    settings = {
      default_phone_region = "RO";
      log_type = "file";
      mail_domain = "gmail.com";
      mail_from_address = "ivan.nizamov";
      mail_smtpauth = true;
      mail_smtphost = "smtp.gmail.com";
      mail_smtpmode = "smtp";
      mail_smtpname = "ivan.nizamov@gmail.com";
      mail_smtpport = 465;
      mail_smtpsecure = "ssl";
      maintenance_window_start = 2;
      overwriteprotocol = "https";
      serverid = 0;
      trusted_proxies = [
        "127.0.0.1"
        "::1"
      ];
    };

    secrets.mail_smtppassword = smtpPassFile;
  };

  services.nginx = {
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${hostName} = {
      listen = [
        {
          addr = "127.0.0.1";
          port = listenPort;
        }
      ];
      locations = {
        "^~ /browser/".proxyPass = "http://127.0.0.1:${toString collaboraPort}";
        "^~ /hosting/".proxyPass = "http://127.0.0.1:${toString collaboraPort}";
        "^~ /cool/" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
          proxyWebsockets = true;
        };
        "^~ /lool/" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.collabora-online = {
    enable = true;
    port = collaboraPort;
    aliasGroups = [
      {
        host = "https://${hostName}";
      }
    ];
    settings = {
      server_name = hostName;
      ssl.enable = false;
      ssl.termination = true;
    };
  };

  # Keep the public push endpoint in Nextcloud, but make notify_push health
  # checks bypass Tailscale Funnel because Funnel rewrites forwarded headers.
  systemd.services.nextcloud-notify_push.environment.NEXTCLOUD_URL =
    lib.mkForce internalNextcloudUrl;
  systemd.services.nextcloud-notify_push_setup.environment.NEXTCLOUD_URL =
    internalNextcloudUrl;

  systemd.services.nextcloud-office-config = {
    description = "Configure Nextcloud Office";
    after = [
      "coolwsd.service"
      "nextcloud-setup.service"
    ];
    wants = [
      "coolwsd.service"
      "nextcloud-setup.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      Group = "nextcloud";
      LoadCredential = config.systemd.services.nextcloud-cron.serviceConfig.LoadCredential;
    };
    script = ''
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments wopi_url --value "https://${hostName}"
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments public_wopi_url --value "https://${hostName}"
      ${lib.getExe config.services.nextcloud.occ} richdocuments:activate-config || true
    '';
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
