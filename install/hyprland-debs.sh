#!/bin/bash
# Installs or updates Hyprland on Ubuntu from the prebuilt packages of ppa:cppiber/hyprland,
# without adding the PPA (that needs add-apt-repository and root; this only needs `sudo apt-get`).
# The .debs are fetched from Launchpad's API, and `apt-get install` runs only when one of them
# is newer than what is installed.
#
#   hyprland-debs.sh            install or update
#   hyprland-debs.sh --check    only say whether there is an update (exit 0 = yes, 1 = no)
#   hyprland-debs.sh --notify   like --check, plus a desktop notification when there is one
set -euo pipefail

mode="${1:-install}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprland-debs"
mkdir -p "$cache"

# prints "<name> <version> <file>" for every package to have installed, for this Ubuntu series
plan() {
    python3 - "$(. /etc/os-release && echo "$VERSION_CODENAME")" "$(dpkg --print-architecture)" "$cache" <<'PY'
import json, os, re, subprocess, sys, urllib.request

series, arch, cache = sys.argv[1:4]
archive = "https://api.launchpad.net/1.0/~cppiber/+archive/ubuntu/hyprland"
roots = ["hyprland", "xdg-desktop-portal-hyprland", "hyprland-guiutils", "hyprshutdown"]

def get(url):
    return json.load(urllib.request.urlopen(url, timeout=30))

index, url = {}, (archive + "?ws.op=getPublishedBinaries&status=Published&ws.size=75"
                  "&distro_arch_series=https://api.launchpad.net/1.0/ubuntu/%s/%s" % (series, arch))
while url:
    page = get(url)
    for e in page["entries"]:
        index[e["binary_package_name"]] = e
    url = page.get("next_collection_link")

def fetch(entry):
    name, version = entry["binary_package_name"], entry["binary_package_version"]
    pkg_arch = "all" if entry["architecture_specific"] is False else arch
    file = "%s_%s_%s.deb" % (name, version.split(":")[-1], pkg_arch)
    path = os.path.join(cache, file)
    if not os.path.exists(path):
        urllib.request.urlretrieve("https://launchpad.net/~cppiber/+archive/ubuntu/hyprland/+files/" + file, path + ".part")
        os.rename(path + ".part", path)
    return file, path

# the Depends field is only in the .deb itself, so each one is fetched (and kept) to read it
def depends(path):
    field = subprocess.check_output(["dpkg-deb", "-f", path, "Depends"], text=True).replace("\n", " ")
    return [re.split(r"[ (:]", d.strip().split("|")[0].strip())[0] for d in field.split(",") if d.strip()]

seen, queue = [], list(roots)
while queue:
    name = queue.pop()
    if name in seen or name not in index:
        continue
    seen.append(name)
    file, path = fetch(index[name])
    print(name, index[name]["binary_package_version"], file)
    queue += depends(path)
PY
}

installed() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true; }

updates=()
while read -r name version file; do
    have=$(installed "$name")
    [ "$have" = "$version" ] && continue
    updates+=("$name $version $file")
done < <(plan)

if [ ${#updates[@]} -eq 0 ]; then
    [ "$mode" = --check ] && exit 1
    [ "$mode" = install ] && echo "Hyprland is up to date ($(installed hyprland))"
    exit 0
fi

case "$mode" in
--check)
    printf '%s\n' "${updates[@]}"
    exit 0
    ;;
--notify)
    notify-send -i system-software-update "Hyprland update available" \
        "$(installed hyprland || echo none) → $(printf '%s\n' "${updates[@]}" | awk '$1=="hyprland"{print $2}'). Run install/hyprland-debs.sh" || true
    exit 0
    ;;
esac

files=()
for u in "${updates[@]}"; do
    read -r name version file <<<"$u"
    files+=("$cache/$file")
done

# apt resolves the rest (libraries from the Ubuntu archive) and orders the install
sudo apt-get install -y --no-install-recommends "${files[@]}"
