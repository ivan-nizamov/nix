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

      folders = {
        "openclaw-workspace" = {
          path = "/home/iva/.openclaw/workspace";
          id = "openclaw-workspace";
          label = "OpenClaw Workspace";
        };
      };
    };
  };
}
