# ~/.zshrc (managed via GNU Stow)

# prompt theming
eval "$(starship init zsh)"

# smarter cd
eval "$(zoxide init zsh)"


# convenient NixOS rebuild aliases (select by hostname, works anywhere)
alias gad='git add .'
alias gcm='git commit -m'
alias glog='git log --all --decorate --oneline --graph'
alias f='fuck'  # pay-respects
alias nrs='sudo nixos-rebuild --flake .#$(hostname -s) switch'
alias nrt='sudo nixos-rebuild --flake .#$(hostname -s) test'
alias nrb='sudo nixos-rebuild --flake .#$(hostname -s) boot'
alias gem='nix-shell -p nodejs_22 git --run "npx @google/gemini-cli@latest"'
alias claude='nix-shell -p nodejs_22 git --run "npx @anthropic-ai/claude-code@latest"'
