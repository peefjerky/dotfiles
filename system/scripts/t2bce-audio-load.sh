#!/bin/bash
modprobe t2bce_audio 2>/dev/null
sleep 3

if [ -d /proc/asound/card0/pcm0p ]; then
    logger "t2bce-audio: OK"
    exit 0
fi

# T2 audio subsystem not initialized this boot — reboot for clean T2 reinit
logger "t2bce-audio: pcm0p absent, rebooting to reinitialize T2 audio"
systemctl reboot
