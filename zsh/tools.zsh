# Third-party tool initialization

# zoxide
eval "$(zoxide init zsh)"

# oh-my-posh
export OMP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-posh"
eval "$(oh-my-posh init zsh --config "$HOME/kitchen/assets/omp/monochrome.omp.json")"

# fnm (fast node manager, drop-in replacement for nvm)
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
    export PATH="$FNM_PATH:$PATH"
    eval "$(fnm env --use-on-cd --shell zsh)"
fi

# zsh-autosuggestions
ZSH_AUTOSUGGESTIONS="$HOME/source/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$ZSH_AUTOSUGGESTIONS" ] && source "$ZSH_AUTOSUGGESTIONS"
