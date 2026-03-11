{ inputs, pkgs, ... }:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    llmAgentsPkgs.codex
    llmAgentsPkgs.gemini-cli
    llmAgentsPkgs.kilocode-cli
    llmAgentsPkgs.openclaw
    llmAgentsPkgs.opencode
  ];
}
