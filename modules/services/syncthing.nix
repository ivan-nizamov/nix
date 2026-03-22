{ ... }:
{
  services.syncthing = {
    enable = true;
    user = "iva";
    dataDir = "/home/iva";
    configDir = "/home/iva/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;

    settings = {
      options = {
        urAccepted = -1;
        relaysEnabled = true;
        localAnnounceEnabled = true;
      };

      devices = {
        a53 = {
          id = "2WGUA6E-OJLUMYK-7NJLC4C-42JON6A-FOLZZQX-VT4JEGC-AA3CGJ7-BPNFZQX";
        };
      };

      folders = {
        "openclaw-workspace" = {
          path = "/home/iva/.openclaw/workspace";
          id = "openclaw-workspace";
          label = "OpenClaw Workspace";
          devices = [ "a53" ];
        };
        sync = {
          path = "/home/iva/Sync";
          id = "sync";
          label = "Sync";
          devices = [ "a53" ];
        };
      };
    };
  };
}
