#!/bin/bash
# Rebinds enp5s0 (05:00.0) back to the kernel's igb driver after the DPDK
# demo and brings networking back up. Run from the console -- this is
# exactly the recovery step setup.sh's unbind requires console access for.
set -euo pipefail
NIC_PCI=05:00.0
sudo dpdk-devbind.py --bind=igb "$NIC_PCI"
sudo ip link set enp5s0 up
sudo dhclient enp5s0 || true
ip addr show enp5s0
