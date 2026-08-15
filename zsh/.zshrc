# sources every *.zsh module next to this file.
zsh_config_dir="$(dirname "$(readlink -f "${(%):-%N}")")"

for file in "$zsh_config_dir"/*.zsh; do
    source "$file"
done
unset zsh_config_dir file
