{ pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;
  };

  environment.sessionVariables.OBS_USE_EGL = "1";
}
