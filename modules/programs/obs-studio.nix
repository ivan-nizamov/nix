{ pkgs, ... }:
let
  obsStudio = pkgs.obs-studio.override {
    cudaSupport = true;
  };
in
{
  programs.obs-studio = {
    enable = true;
    package = obsStudio;
  };
}
