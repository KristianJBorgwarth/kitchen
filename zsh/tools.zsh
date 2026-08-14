# Third-party tool initialization

# zoxide
eval "$(zoxide init zsh)"

# oh-my-posh
export OMP_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-posh"
eval "$(oh-my-posh init zsh --config "$HOME/kitchen/assets/omp/monochrome.omp.json")"

# nvm 
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
