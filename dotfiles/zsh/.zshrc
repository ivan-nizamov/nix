# ~/.zshrc (managed via GNU Stow)

# prompt theming
eval "$(starship init zsh)"

# smarter cd
eval "$(zoxide init zsh)"

# convenient NixOS rebuild alias
alias nrs='sudo nixos-rebuild switch --flake ~/nix#laptop'
alias gad='git add .'
alias gcm='git commit -m'
alias f='fuck'  # pay-respects
alias nrs='sudo nixos-rebuild --flake .#$(hostname) switch'
alias nrt='sudo nixos-rebuild --flake .#$(hostname) test'
alias nrb='sudo nixos-rebuild --flake .#$(hostname) boot'
