{ config, lib, pkgs, ... }:
let
  hostName = "mainframe.tail506f5b.ts.net";
  listenPort = 8080;
  collaboraPort = 9980;
  whiteboardPort = 3002;
  internalNextcloudUrl = "http://127.0.0.1:${toString listenPort}";
  officeFonts = with pkgs; [
    caladea
    carlito
    dejavu_fonts
    liberation_ttf
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];
  adminPassFile = "/var/lib/nextcloud-secrets/admin-pass";
  smtpPassFile = "/var/lib/nextcloud-secrets/smtp-pass";
  whiteboardSecretFile = "/var/lib/nextcloud-secrets/whiteboard-server.env";
  officeTemplateMarker = "/var/lib/nextcloud/.richdocuments-ms-office-templates-v1";
in
{
  fonts.packages = officeFonts;

  system.activationScripts.nextcloudSecrets = ''
    install -d -m 0700 -o root -g root /var/lib/nextcloud-secrets
    if [ ! -s ${adminPassFile} ]; then
      umask 077
      ${lib.getExe pkgs.openssl} rand -base64 32 > ${adminPassFile}
    fi
    chown root:root ${adminPassFile}
    chmod 0400 ${adminPassFile}

    if [ ! -s ${whiteboardSecretFile} ]; then
      umask 077
      printf 'JWT_SECRET_KEY=%s\n' "$(${lib.getExe pkgs.openssl} rand -hex 32)" > ${whiteboardSecretFile}
    fi
    chown root:root ${whiteboardSecretFile}
    chmod 0400 ${whiteboardSecretFile}
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
        collectives
        contacts
        deck
        files_automatedtagging
        forms
        mail
        music
        notes
        polls
        richdocuments
        spreed
        tables
        tasks
        whiteboard
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
        "^~ /whiteboard/" = {
          proxyPass = "http://127.0.0.1:${toString whiteboardPort}/";
          proxyWebsockets = true;
        };
      };
    };
  };

  services.nextcloud-whiteboard-server = {
    enable = true;
    settings = {
      CHROME_EXECUTABLE_PATH = "${lib.getExe pkgs.helium}";
      NEXTCLOUD_URL = "https://${hostName}";
      PORT = toString whiteboardPort;
      STORAGE_STRATEGY = "lru";
      TLS = "false";
    };
    secrets = [ whiteboardSecretFile ];
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
      net.post_allow.host = [
        "127\\.0\\.0\\.1"
        "::1"
      ];
      ssl.enable = false;
      ssl.termination = true;
      storage.wopi.host = [ hostName ];
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
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments canonical_webroot --value "https://${hostName}"
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments doc_format --type string --value ooxml
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments theme --type string --value collabora
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments uiDefaults-UIMode --type string --value notebookbar
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments preview_generation --type boolean --value true
      ${lib.getExe config.services.nextcloud.occ} config:app:set richdocuments open_local_editor --type string --value yes
      ${lib.getExe config.services.nextcloud.occ} richdocuments:activate-config || true

      if [ ! -e ${officeTemplateMarker} ]; then
        ${lib.getExe config.services.nextcloud.occ} richdocuments:update-empty-templates
        touch ${officeTemplateMarker}
      fi
    '';
  };

  systemd.services.nextcloud-whiteboard-config = {
    description = "Configure Nextcloud Whiteboard";
    after = [
      "nextcloud-setup.service"
      "nextcloud-whiteboard-server.service"
    ];
    wants = [
      "nextcloud-setup.service"
      "nextcloud-whiteboard-server.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      Group = "nextcloud";
      LoadCredential = [
        "mail_smtppassword:${smtpPassFile}"
        "whiteboard-server.env:${whiteboardSecretFile}"
      ];
    };
    script = ''
      set -a
      . "$CREDENTIALS_DIRECTORY/whiteboard-server.env"
      set +a

      ${lib.getExe config.services.nextcloud.occ} config:app:set whiteboard collabBackendUrl --value "https://${hostName}/whiteboard"
      ${lib.getExe config.services.nextcloud.occ} config:app:set whiteboard jwt_secret_key --value "$JWT_SECRET_KEY"
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
