{ ... }:
{
  programs.zsh = {
    enable = true;
    shellAliases = {
      c = "codex --dangerously-bypass-approvals-and-sandbox";
    };
  };
}
