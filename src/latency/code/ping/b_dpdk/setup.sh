#!/bin/bash
# One-time DPDK environment setup for the (B) kernel-bypass ping demo, on
# this box specifically (enp5s0 = 05:00.0, the only NIC and this
# machine's own SSH link). Installs packages and reserves hugepages --
# both safe to run over SSH -- then unbinds enp5s0 from the kernel, which
# is NOT safe over SSH: that link drops the moment the bind command runs
# and only comes back via the console (see teardown.sh) or a reboot.
#
# Run the first two steps over SSH if you like; run the actual unbind
# from the console.
set -euo pipefail
NIC_PCI=05:00.0

echo "== apt install (safe over SSH) =="
sudo apt-get install -y dpdk dpdk-dev

echo "== hugepages (safe over SSH) =="
sudo dpdk-hugepages.py --setup 1G

echo "== about to unbind $NIC_PCI from igb -- this SSH session's own NIC =="
read -p "Run this from the console, not over SSH. Continue anyway? [y/N] " ok
[[ "$ok" == "y" ]] || { echo "aborted before unbind"; exit 1; }

sudo modprobe uio_pci_generic
sudo dpdk-devbind.py --bind=uio_pci_generic "$NIC_PCI"
sudo dpdk-devbind.py --status
