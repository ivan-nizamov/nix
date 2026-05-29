{ config, lib, pkgs, ... }:
let
  publicHost = config.networking.hostName == "mainframe";
  hostName =
    if publicHost then
      "mainframe.tail506f5b.ts.net"
    else
      "localhost";
  listenPort = 8080;
  collaboraPort = 9980;
  whiteboardPort = 3002;
  externalHost =
    if publicHost then
      hostName
    else
      "${hostName}:${toString listenPort}";
  externalUrl =
    if publicHost then
      "https://${hostName}"
    else
      "http://${externalHost}";
  internalNextcloudUrl = "http://127.0.0.1:${toString listenPort}";
  collaboraWopiUrl =
    if publicHost then
      externalUrl
    else
      internalNextcloudUrl;
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

  system.activationScripts.nextcloudLocalConfig = lib.mkIf (!publicHost) ''
    config=/var/lib/nextcloud/config/config.php
    if [ -s "$config" ]; then
      ${lib.getExe pkgs.php} -r '
        $configFile = "/var/lib/nextcloud/config/config.php";
        include $configFile;
        foreach ([
          "mail_domain",
          "mail_from_address",
          "mail_smtpauth",
          "mail_smtphost",
          "mail_smtpmode",
          "mail_smtpname",
          "mail_smtppassword",
          "mail_smtpport",
          "mail_smtpsecure",
        ] as $key) {
          unset($CONFIG[$key]);
        }
        file_put_contents($configFile, "<?php\n\$CONFIG = " . var_export($CONFIG, true) . ";\n");
      '
      chown nextcloud:nextcloud "$config"
      chmod 0640 "$config"
    fi
  '';

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    inherit hostName;
    https = publicHost;
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
      nextcloudUrl = externalUrl;
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
      maintenance_window_start = 2;
      "overwrite.cli.url" = externalUrl;
      overwriteprotocol = if publicHost then "https" else "http";
      serverid = 0;
      trusted_domains = lib.optionals (!publicHost) [ "127.0.0.1" ];
      trusted_proxies = [
        "127.0.0.1"
        "::1"
      ];
    } // lib.optionalAttrs (!publicHost) {
      overwritehost = "${hostName}:${toString listenPort}";
    } // lib.optionalAttrs publicHost {
      mail_domain = "gmail.com";
      mail_from_address = "ivan.nizamov";
      mail_smtpauth = true;
      mail_smtphost = "smtp.gmail.com";
      mail_smtpmode = "smtp";
      mail_smtpname = "ivan.nizamov@gmail.com";
      mail_smtpport = 465;
      mail_smtpsecure = "ssl";
    };

    secrets = lib.optionalAttrs publicHost {
      mail_smtppassword = smtpPassFile;
    };
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
      NEXTCLOUD_URL = externalUrl;
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
        host = externalUrl;
      }
    ];
    settings = {
      server_name = externalHost;
      net.post_allow.host = [
        "127\\.0\\.0\\.1"
        "::1"
      ];
      ssl.enable = false;
      ssl.termination = publicHost;
      storage.wopi.host = [
        hostName
        externalHost
        "127\\.0\\.0\\.1"
      ];
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
      occ() {
        ${lib.getExe config.services.nextcloud.occ} --no-interaction "$@"
      }

      occ config:app:set richdocuments wopi_url --value "${collaboraWopiUrl}"
      occ config:app:set richdocuments public_wopi_url --value "${externalUrl}"
      occ config:app:set richdocuments canonical_webroot --value "${externalUrl}"
      occ config:app:set richdocuments doc_format --type string --value ooxml
      occ config:app:set richdocuments theme --type string --value collabora
      occ config:app:set richdocuments uiDefaults-UIMode --type string --value notebookbar
      occ config:app:set richdocuments preview_generation --type boolean --value true
      occ config:app:set richdocuments open_local_editor --type string --value yes
      ${lib.optionalString (!publicHost) ''
        occ config:app:delete richdocuments wopi_allowlist || true
      ''}
      occ richdocuments:activate-config ${
        lib.optionalString (!publicHost) "--callback-url \"${internalNextcloudUrl}\""
      } || true

      if [ ! -e ${officeTemplateMarker} ]; then
        occ richdocuments:update-empty-templates
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
      LoadCredential = [ "whiteboard-server.env:${whiteboardSecretFile}" ];
    };
    script = ''
      set -a
      . "$CREDENTIALS_DIRECTORY/whiteboard-server.env"
      set +a

      ${lib.getExe config.services.nextcloud.occ} config:app:set whiteboard collabBackendUrl --value "${externalUrl}/whiteboard"
      ${lib.getExe config.services.nextcloud.occ} config:app:set whiteboard jwt_secret_key --value "$JWT_SECRET_KEY"
    '';
  };

  systemd.services.nextcloud-funnel = lib.mkIf publicHost {
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
