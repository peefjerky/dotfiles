#!/bin/bash
MODE=$(ls /sys/bus/hid/drivers/hid-appletb-kbd/0003:05AC:8302.*/mode 2>/dev/null | head -1)
[ -z "$MODE" ] && exit 1
current=$(cat "$MODE")
if [ "$current" = "0" ]; then
    echo 2 > "$MODE"
else
    echo 0 > "$MODE"
fi
