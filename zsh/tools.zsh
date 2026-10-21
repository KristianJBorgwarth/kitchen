# Third-party tool initialization

# completion: zsh's own system, so completing knows git branches, pacman/systemctl/docker
# options and so on, not just file names. First, since zoxide and fzf-tab hook into it
autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
# case-insensitive, colored like ls; fzf-tab draws the menu itself
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no

# zoxide
eval "$(zoxide init zsh)"

# oh-my-posh
export OMP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-posh"
eval "$(oh-my-posh init zsh --config "$HOME/kitchen/assets/omp/kitchen.omp.json")"

# fnm (fast node manager, drop-in replacement for nvm)
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
    export PATH="$FNM_PATH:$PATH"
    eval "$(fnm env --use-on-cd --shell zsh)"
fi

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf-tab: completions in an fzf picker; completing cd/z previews the folder. After
# compinit and fzf, before the plugins below that wrap widgets
FZF_TAB="$HOME/source/fzf-tab/fzf-tab.plugin.zsh"
if [ -f "$FZF_TAB" ]; then
    source "$FZF_TAB"
    zstyle ':fzf-tab:complete:(cd|__zoxide_z):*' fzf-preview 'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
fi

# zsh-autosuggestions
ZSH_AUTOSUGGESTIONS="$HOME/source/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$ZSH_AUTOSUGGESTIONS" ] && source "$ZSH_AUTOSUGGESTIONS"

# zsh keybindings (after fzf and fzf-tab, which both rebind Tab themselves): Tab takes the
# suggestion, Ctrl+F completes
if (( $+widgets[fzf-tab-complete] )); then
    bindkey '^F' fzf-tab-complete
else
    bindkey '^F' complete-word
fi
bindkey '^I' autosuggest-accept

# zsh-syntax-highlighting: commands green when they exist, red when they don't, as you type.
# Last: it has to wrap every widget defined above
ZSH_SYNTAX_HIGHLIGHTING="$HOME/source/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[ -f "$ZSH_SYNTAX_HIGHLIGHTING" ] && source "$ZSH_SYNTAX_HIGHLIGHTING"
