{ inputs, pkgs, ... }:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  context-mode = pkgs.callPackage ../../pkgs/context-mode { };
in
{
  environment.systemPackages = [
    context-mode
    llmAgentsPkgs.codex
    llmAgentsPkgs.codex-acp
    llmAgentsPkgs.gemini-cli
    llmAgentsPkgs.kilocode-cli
    llmAgentsPkgs.openclaw
    llmAgentsPkgs.opencode
    llmAgentsPkgs.pi
    pkgs.nodejs
  ];

  systemd.tmpfiles.rules = [
    "d /home/iva/.pi/extensions 0755 iva users - -"
    "L+ /home/iva/.pi/extensions/context-mode - - - - ${context-mode}/lib/node_modules/context-mode"
  ];
}
