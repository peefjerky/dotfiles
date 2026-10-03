#!/bin/bash
# Load t2bce_audio and, if the T2 audio subsystem came up half-initialised,
# reboot ONCE to reinitialise it.
#
# The reboot is the whole point of this script -- T2 audio intermittently
# fails to expose a playback PCM on a cold boot and a second boot fixes it.
# But an unconditional reboot on "pcm0p missing" is a loaded gun: any kernel
# that does not carry the t2bce modules AT ALL also has no pcm0p, so the
# machine reboots, fails again, and loops forever with no way in.
#
# That is exactly what linux-cachyos 7.2.5-1 did on 2026-09-16 -- it shipped
# without the 7.2/t2 branch, so modprobe found nothing, and the box became
# unbootable until it was rolled back to a snapshot. See the forum thread
# "7.2.5-1 dropped the 7.2/t2 branch, T2 builds fail".
#
# Two guards, both of which have to hold before we are allowed to reboot:
#
#   1. modprobe must SUCCEED. A missing module is a broken kernel, not a
#      flaky T2 -- rebooting cannot fix it. Note the old version sent
#      modprobe's stderr to /dev/null, which is why the real cause was
#      invisible in the journal and the loop looked like a udev hang.
#   2. We must not have already retried. The stamp survives the reboot (it is
#      under /var/lib, not /run) and is cleared on any boot that works, so
#      the worst case is one wasted reboot and then a normal boot with no
#      speakers -- degraded, but reachable.

STAMP=/var/lib/t2bce-audio-retried

if ! modprobe t2bce_audio; then
    logger -p daemon.err "t2bce-audio: t2bce_audio unavailable on $(uname -r), not rebooting (kernel lacks the t2bce modules)"
    exit 0
fi

sleep 3

if [ -d /proc/asound/card0/pcm0p ]; then
    logger "t2bce-audio: OK"
    rm -f "$STAMP"
    exit 0
fi

if [ -e "$STAMP" ]; then
    logger -p daemon.err "t2bce-audio: pcm0p still absent after a retry, giving up (audio will be dead this boot)"
    rm -f "$STAMP"
    exit 0
fi

logger "t2bce-audio: pcm0p absent, rebooting once to reinitialize T2 audio"
: >"$STAMP"
systemctl reboot
