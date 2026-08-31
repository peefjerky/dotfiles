#!/usr/bin/env bash
# apple-bce -> t2bce migration for CachyOS on a T2 Mac.
#
# linux-cachyos 7.2.0 renamed the T2 driver: drivers/staging/apple-bce/apple-bce.ko
# became drivers/staging/t2bce/{t2bce_core,t2bce_dma,t2bce_vhci,t2bce_audio}.ko.
# chwd still writes MODULES+=(apple-bce), a missing MODULES entry is fatal to
# mkinitcpio, and limine's hook swallows that failure -- so the upgrade "succeeds"
# and leaves a kernel with no initramfs, i.e. emergency mode.
#
# Run as root from a real boot (e.g. the linux-cachyos-lts entry), not a snapshot.
set -euo pipefail

(( EUID == 0 )) || { echo "run me with sudo" >&2; exit 1; }

# A snapshot boot is an overlay on a read-only subvol: changes are discarded on
# reboot. Test the actual root mount, not /proc/cmdline, so this stays correct
# inside a chroot (where the cmdline still names the host's snapshot).
if [[ $(findmnt -no FSTYPE /) == overlay ]] || findmnt -no OPTIONS / | grep -q 'subvol=/@/\.snapshots/'; then
    echo "Root is a snapshot overlay -- changes here are discarded on reboot." >&2
    echo "Boot the linux-cachyos-lts entry and run this there." >&2
    exit 1
fi

# ---- 1. the boot fix -------------------------------------------------------
# mkinitcpio's `?` suffix marks a module optional (functions:add_module sets
# ign_errors), so one config is valid on 7.1.x and 7.2.x alike. t2bce_dma arrives
# via t2bce_core's `depends` and needs no entry of its own.
cp -n /etc/mkinitcpio.conf.d/11-chwd.conf{,.pre-t2bce} 2>/dev/null || true
cat > /etc/mkinitcpio.conf.d/11-chwd.conf <<'EOF'
# Was chwd's MODULES+=(apple-bce); replaced by t2bce-migrate.sh.
# The `?` suffix is what stops the next rename from silently producing no initramfs.
MODULES+=(apple-bce? t2bce_core? t2bce_vhci?)
EOF
echo "==> wrote /etc/mkinitcpio.conf.d/11-chwd.conf"

# apple_bce and t2bce_core share PCI alias 106b:1801, so udev autoloads whichever
# exists. A hardcoded name here only buys a failing systemd-modules-load.service.
if [[ -f /etc/modules-load.d/t2.conf ]]; then
    mv /etc/modules-load.d/t2.conf /etc/modules-load.d/t2.conf.pre-t2bce
    echo "==> retired /etc/modules-load.d/t2.conf (autoloaded by PCI alias)"
fi

# Not `mkinitcpio -P`: linux-cachyos ships no preset here, and /usr/local/bin/mkinitcpio
# is an interactive shim. limine-mkinitcpio rebuilds every kernel -- but it exits 0
# even when a build fails, so its output is the only honest signal.
log=$(mktemp); trap 'rm -f "$log"' EXIT
echo "==> rebuilding initramfs for every installed kernel"
limine-mkinitcpio 2>&1 | tee "$log"
if grep -qE 'mkinitcpio failed|module not found' "$log"; then
    echo; echo "FAILED -- do not reboot. A kernel above has no initramfs." >&2
    exit 1
fi

# ---- 2. retire the apple_bce suspend workaround ----------------------------
# t2bce does its own PM (t2bce_core: bce_pm_resume_stateful/_no_state, t2bce_vhci:
# bce_vhci_bus_suspend/_resume), and t2linux says force-unloading it before sleep
# tears down live BridgeOS queues. HAS_APPLE_BCE is cached in hardware.conf and
# would stay stale, so drop the blocks outright. The Touch Bar, sensor, gmux and
# audio steps are unrelated to bce and stay exactly as they are.
strip_bce() { # $1 = script, $2 = perl regex, $3 = replacement
    [[ -f $1 ]] && grep -q apple_bce "$1" || return 0
    cp -n "$1"{,.pre-t2bce}
    perl -0777 -i -pe "s/$2/$3/" "$1"
    grep -q apple_bce "$1" && { echo "WARN: $1 still mentions apple_bce" >&2; return 0; }
    echo "==> removed the apple_bce block from $1"
}
strip_bce /usr/local/bin/t2-suspend.sh \
    '\n# Unload Apple BCE\nif \[ "\$HAS_APPLE_BCE" = true \]; then\n    unload_mod apple_bce\nfi\n' '\n'
# the industrialio wait is for the sensor modules, not bce -- keep it, unconditional
strip_bce /usr/local/bin/t2-resume.sh \
    '# Load Apple BCE\nif \[ "\$HAS_APPLE_BCE" = true \]; then\n    load_mod apple_bce\n    (\S+ industrialio 10)\nfi' '$1'

echo
echo "OK: every kernel built. Safe to reboot."
