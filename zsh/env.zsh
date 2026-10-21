# Environment variables / exports
export PATH="$HOME/.local/bin:$HOME/opt/go/bin:$HOME/go/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
export PATH="$PATH:$HOME/.dotnet/tools"
export EDITOR=nvim
export VISUAL=nvim

# bat colors code with the terminal's own 16 colors, so it follows the ghostty theme
export BAT_THEME=ansi
# fzf's Ctrl+T file picker previews the file with bat (batcat on Ubuntu)
export FZF_CTRL_T_OPTS="--preview '(bat || batcat) --color=always --style=numbers --line-range=:200 {} 2>/dev/null'"
