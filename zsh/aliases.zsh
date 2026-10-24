# Aliases

# general
alias zhr='source ~/.zshrc'
alias pacu='sudo pacman -Syu'
alias ubu='sudo apt update && sudo apt upgrade'
alias lg='lazygit'

#git aliases
alias ga='git add .'
alias gp='git push'
alias gsm='git switch master'

#utility
alias get_monitors='hyprctl monitors'

# misc
alias ff='fastfetch'

# ls is eza, cat is bat, tree is eza's tree view
alias ls='eza --icons=always --group-directories-first'
alias ll='eza -l --git --icons=always --group-directories-first'
alias la='eza -la --git --icons=always --group-directories-first'
alias lt='eza --tree --level=2 --icons=always'
alias tree='eza --tree --icons=always'

# Ubuntu ships bat as batcat
command -v bat >/dev/null || alias bat='batcat'
alias cat='bat'
