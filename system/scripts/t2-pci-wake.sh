#!/bin/bash
echo "on" > /sys/bus/pci/devices/0000:e6:00.3/power/control 2>/dev/null
echo "on" > /sys/bus/pci/devices/0000:e6:00.1/power/control 2>/dev/null
