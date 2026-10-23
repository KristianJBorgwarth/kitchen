#!/bin/bash
# focus_proc.sh name interval_s — streams one line per sample for processes whose name contains
# `name` (case-insensitive):
#   count cpuTicks rssBytes readBytes writeBytes gpuEngineNs gpuBusyPct vramBytes netRxBytes netTxBytes
# Totals are cumulative (the consumer takes deltas), except gpuBusyPct (nvidia, instantaneous).
# io, gpu fdinfo and sockets are only readable for the user's own processes; net is TCP only.
export LC_ALL=C
pat=$(printf %s "$1" | tr 'A-Z ' 'a-z_')
every=${2:-1}
page=$(getconf PAGESIZE)
nvidia=
command -v nvidia-smi >/dev/null && nvidia=1
trap exit TERM INT

while :; do
    out=$(cat /proc/[0-9]*/stat 2>/dev/null | awk -v pat="$pat" -v page="$page" '
        {
            rest = $0; sub(/^[0-9]+ \(.*\) /, "", rest)
            open = index($0, "("); comm = substr($0, open + 1, length($0) - length(rest) - open - 2)
            gsub(/ /, "_", comm)
            if (index(tolower(comm), pat) == 0) next
            split(rest, f, " ")
            n++; ticks += f[12] + f[13]; rss += f[22] * page
            print "P", $1
        }
        END { print "S", n + 0, ticks + 0, rss + 0 }')

    pids=()
    stat="0 0 0"
    while read -r k a b c; do
        case $k in
            P) pids+=("$a") ;;
            S) stat="$a $b $c" ;;
        esac
    done <<<"$out"

    io="0 0"
    gpu="0 0 0"
    net="0 0"
    if ((${#pids[@]})); then
        files=()
        for p in "${pids[@]}"; do files+=(/proc/"$p"/io); done
        io=$(cat "${files[@]}" 2>/dev/null | awk '/^read_bytes/{r+=$2} /^write_bytes/{w+=$2} END{print r+0, w+0}')

        # amdgpu fdinfo: a client id can show up on several fds, count each once
        files=()
        for p in "${pids[@]}"; do files+=(/proc/"$p"/fdinfo/*); done
        gpu=$(cat "${files[@]}" 2>/dev/null | awk '
            /^pos:/ { skip = 0 }
            /^drm-client-id:/ { if ($2 in seen) skip = 1; seen[$2] = 1 }
            skip { next }
            /^drm-engine-(gfx|compute):/ { ns += $2 }
            /^drm-memory-vram:/ { vram += $2 * 1024 }
            END { printf "%d 0 %d", ns, vram }')

        if [ -n "$nvidia" ]; then
            nv=$(nvidia-smi pmon -c 1 -s um 2>/dev/null | awk -v pids="${pids[*]}" '
                BEGIN { split(pids, a, " "); for (i in a) want[a[i]] = 1 }
                /^#/ { if (!h) { for (i = 2; i <= NF; i++) col[$i] = i - 1; h = 1 } next }
                ($(col["pid"]) in want) {
                    if ($(col["sm"]) ~ /^[0-9]+$/) sm += $(col["sm"])
                    if ($(col["fb"]) ~ /^[0-9]+$/) fb += $(col["fb"])
                }
                END { printf "0 %d %d", sm, fb * 1048576 }')
            [ -n "$nv" ] && gpu=$nv
        fi

        net=$(ss -tinpH 2>/dev/null | awk -v pids="${pids[*]}" '
            BEGIN { split(pids, a, " "); for (i in a) want[a[i]] = 1 }
            /^[^ \t]/ {
                cur = 0; s = $0
                while (match(s, /pid=[0-9]+/)) {
                    if (substr(s, RSTART + 4, RLENGTH - 4) in want) cur = 1
                    s = substr(s, RSTART + RLENGTH)
                }
                next
            }
            cur {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^bytes_sent:/) tx += substr($i, 12)
                    else if ($i ~ /^bytes_received:/) rx += substr($i, 16)
                }
            }
            END { printf "%d %d", rx, tx }')
    fi
    echo "$stat $io $gpu $net"
    sleep "$every"
done
