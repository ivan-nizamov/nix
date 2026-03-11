{ ... }:
{
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.max-jobs = 1;
  nix.settings.cores = 2;
  nix.settings.trusted-users = [ "root" "iva" ];
  nix.settings.extra-substituters = [
    "https://cache.garnix.io"
    "https://cache.numtide.com"
  ];
  nix.settings.extra-trusted-public-keys = [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
  nixpkgs.config.allowUnfree = true;
}
