{ pkgs, ... }:

let
  openclawWorkspace = "/home/iva/.openclaw/workspace";
  openclawWorkspaceIgnore = pkgs.writeText "openclaw-workspace-stignore" ''
    (?d)/memory/**/*.sync-conflict-*
    (?d)/memory/My vault/.obsidian/graph.json
    (?d)/memory/My vault/.obsidian/workspace.json
    (?d)/memory/My vault/.obsidian/workspace-mobile.json
    !/memory
    !/memory/**
    *
  '';
in
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
          path = openclawWorkspace;
          id = "openclaw-workspace";
          label = "OpenClaw Memory";
          type = "sendreceive";
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

  system.activationScripts.openclawWorkspaceSyncthingIgnore = ''
    ${pkgs.coreutils}/bin/install -d -o iva -g users -m 0755 ${openclawWorkspace}
    ${pkgs.coreutils}/bin/install -o iva -g users -m 0644 ${openclawWorkspaceIgnore} ${openclawWorkspace}/.stignore
  '';
}
