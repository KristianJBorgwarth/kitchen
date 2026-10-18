#!/bin/bash
# sway_config.sh — prints the sway config with `include` lines expanded in place
# (relative to the including file, globs allowed), the way sway reads it.
dir="${XDG_CONFIG_HOME:-$HOME/.config}/sway"
main="$dir/config"
[ -f "$main" ] || main=/etc/sway/config

expand() {
    local file="$1" base line pattern f
    base=$(dirname "$file")
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line =~ ^[[:space:]]*include[[:space:]]+(.+)$ ]]; then
            pattern="${BASH_REMATCH[1]}"
            pattern="${pattern/#\~/$HOME}"
            [[ $pattern = /* ]] || pattern="$base/$pattern"
            for f in $pattern; do
                [ -f "$f" ] && expand "$f"
            done
        else
            printf '%s\n' "$line"
        fi
    done <"$file"
}

expand "$main"
