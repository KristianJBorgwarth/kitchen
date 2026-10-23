#!/bin/sh
# top_procs.sh [n] [cpu|mem] [name] — top n processes by CPU (or resident memory) over a 0.5s window,
# one per line: "pid cpu% rssMiB name" (cpu% is per core, like top)
# Two `cat`s and one awk pass, picking the top n itself: few processes and little CPU,
# since process starts are costly under EDR/AV. cat (not awk) reads /proc because
# mawk, ubuntu's awk, gives up on pids that exit mid-read.
export LC_ALL=C
n=${1:-8}
sortby=${2:-cpu}
filter=$(printf %s "$3" | tr 'A-Z ' 'a-z_')
page=$(getconf PAGESIZE)

before=$(cat /proc/[0-9]*/stat 2>/dev/null)
sleep 0.5
after=$(cat /proc/[0-9]*/stat 2>/dev/null)

printf '%s\n@@\n%s\n' "$before" "$after" | awk -v n="$n" -v by="$sortby" -v pat="$filter" -v page="$page" '
    # "pid (comm) state …": comm may hold spaces and parens, so cut at the last ") "
    function parse(line) {
        rest = line
        sub(/^[0-9]+ \(.*\) /, "", rest)
        open = index(line, "(")
        comm = substr(line, open + 1, length(line) - length(rest) - open - 2)
        gsub(/ /, "_", comm)
        split(rest, f, " ")
        ticks = f[12] + f[13]
        rss = f[22]
    }
    $0 == "@@" { second = 1; next }
    !second { parse($0); t[$1] = ticks; next }
    ($1 in t) {
        parse($0)
        if (pat != "" && index(tolower(comm), pat) == 0) next
        cnt++; tcpu += (ticks - t[$1]) * 2; trss += rss
        cpu = (ticks - t[$1]) * 200 / 100   # USER_HZ is 100 on linux
        # insertion into a top-n list (mawk has no asort)
        for (i = 1; i <= n; i++) {
            if (by == "mem") { better = !(i in best) || rss > brss[i] || (rss == brss[i] && cpu > bcpu[i]) }
            else { better = !(i in best) || cpu > bcpu[i] || (cpu == bcpu[i] && rss > brss[i]) }
            if (better) {
                for (j = n; j > i; j--) if ((j - 1) in best) { best[j] = best[j - 1]; bcpu[j] = bcpu[j - 1]; brss[j] = brss[j - 1] }
                best[i] = $1 " " comm; bcpu[i] = cpu; brss[i] = rss
                break
            }
        }
    }
    END {
        printf "@ %d %.1f %d\n", cnt, tcpu, trss * page / 1048576
        for (i = 1; i <= n && (i in best); i++) {
            split(best[i], b, " ")
            printf "%s %.1f %d %s\n", b[1], bcpu[i], brss[i] * page / 1048576, b[2]
        }
    }'
