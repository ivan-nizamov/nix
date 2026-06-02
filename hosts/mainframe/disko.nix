{
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            bios = {
              size = "1M";
              type = "EF02";
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                extraArgs = [
                  "-E"
                  "nodiscard"
                ];
                mountpoint = "/";
              };
            };
          };
        };
      };

      nextcloud-data = {
        type = "disk";
        device = "/dev/vdb";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                extraArgs = [
                  "-E"
                  "nodiscard"
                ];
                mountpoint = "/var/lib/nextcloud";
                mountOptions = [
                  "defaults"
                  "nofail"
                ];
              };
            };
          };
        };
      };
    };
  };
}
