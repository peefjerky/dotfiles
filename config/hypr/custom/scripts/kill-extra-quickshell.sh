#!/bin/bash
# Kills duplicate quickshell/qs instances, keeping only the longest-running one.
# Workaround for a quickshell bug that spawns extra instances unexpectedly.

mapfile -t lines < <(ps -eo pid,etimes,stat,args | grep -E '/usr/bin/(quickshell|qs)\b' | grep -v grep)

if [ "${#lines[@]}" -le 1 ]; then
    echo "No extra quickshell instances found."
    exit 0
fi

sorted=$(printf '%s\n' "${lines[@]}" | sort -k2,2 -nr)
main_pid=$(echo "$sorted" | head -1 | awk '{print $1}')
echo "Keeping main instance: PID $main_pid"

echo "$sorted" | tail -n +2 | while read -r pid etimes stat _; do
    [[ "$stat" == Z* ]] && continue
    echo "Killing extra instance: PID $pid (running ${etimes}s)"
    kill "$pid"
done
