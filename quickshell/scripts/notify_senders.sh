#!/bin/bash
# notify_senders.sh — for every desktop notification, the pid of the process that sent it:
# "id pid" per line (services/Notifs.qml). The Notify call itself doesn't say who sent it,
# so this watches the session bus: the call comes from a bus connection, and the server's
# reply to that connection carries the new notification id.
declare -A pid_of call_pid
expect=""
exec 3< <(dbus-monitor --session \
    "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" \
    "type='method_return',sender='org.freedesktop.Notifications'")
# quickshell stops this script on reload; take the monitor down with it
monitor=$!
trap 'kill $monitor 2>/dev/null' EXIT
trap 'exit' TERM INT HUP
while read -r line <&3; do
    if [[ $line =~ ^method\ call.*sender=([^ ]+).*serial=([0-9]+).*member=Notify ]]; then
        sender=${BASH_REMATCH[1]}
        # look the pid up now: short-lived senders (notify-send) are gone by the reply
        if [ -z "${pid_of[$sender]}" ]; then
            read -r _ pid < <(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
                org.freedesktop.DBus GetConnectionUnixProcessID s "$sender" 2>/dev/null)
            pid_of[$sender]=$pid
        fi
        call_pid["$sender ${BASH_REMATCH[2]}"]=${pid_of[$sender]}
    elif [[ $line =~ ^method\ return.*destination=([^ ]+).*reply_serial=([0-9]+) ]]; then
        expect="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    elif [ -n "$expect" ] && [[ $line =~ ^uint32\ ([0-9]+)$ ]]; then
        pid=${call_pid[$expect]}
        [ -n "$pid" ] && echo "${BASH_REMATCH[1]} $pid"
        unset "call_pid[$expect]"
        expect=""
    else
        expect=""
    fi
done
