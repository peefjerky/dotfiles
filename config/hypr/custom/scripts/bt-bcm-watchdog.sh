#!/bin/bash
# Watches the journal for the T2/hci_bcm baudrate-renegotiation bug
# (kernel "BCM: failed to write update baudrate" / bluetoothd
# "disconnection value: 21") and bounces the radio to force a reconnect
# instead of leaving it silently dropped.

journalctl -f -o cat 2>/dev/null | grep --line-buffered -E "failed to write update baudrate|disconnection value: 21" | while read -r _; do
    echo "$(date -Is) bt-bcm-watchdog: BT glitch detected, power-cycling hci0" >&2
    echo "power off" | bluetoothctl >/dev/null 2>&1
    sleep 1
    echo "power on" | bluetoothctl >/dev/null 2>&1
done
