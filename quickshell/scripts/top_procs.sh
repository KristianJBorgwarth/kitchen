#!/bin/bash
# top_procs.sh [n] — top n processes by CPU over a 0.5s window,
# one per line: "pid cpu% rssMiB name" (cpu% is per core, like top)
n=${1:-8}
hz=$(getconf CLK_TCK)
page=$(getconf PAGESIZE)

sample() {
    for f in /proc/[0-9]*/stat; do
        IFS= read -r l <"$f" 2>/dev/null || continue
        # comm may contain spaces and parens, so split around the last ")"
        comm=${l#*(}
        comm=${comm%)*}
        read -r -a a <<<"${l##*) }"
        # a[0] is field 3 (state): utime=14 stime=15 rss=24
        echo "${l%% *} $((a[11] + a[12])) ${a[21]} ${comm// /_}"
    done
}

before=$(sample)
sleep 0.5
after=$(sample)

awk -v hz="$hz" -v page="$page" '
    NR == FNR { t[$1] = $2; next }
    ($1 in t) { printf "%s %.1f %d %s\n", $1, ($2 - t[$1]) * 200 / hz, $3 * page / 1048576, $4 }
' <(echo "$before") <(echo "$after") | sort -k2,2nr -k3,3nr | head -n "$n"
