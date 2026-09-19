# Ping, three ways

Same wire protocol throughout (`common/ping_proto.h`): a UDP packet to
port 9876 carrying `{magic, seq, send_ns}`, echoed back byte-for-byte.
Client-side RTT is always `now() - echoed send_ns`, so the three
responders are directly comparable -- only how the *reply* gets built and
sent differs.

- **a_kernel/** -- plain BSD sockets, the normal Linux IP stack handles
  everything. `client.c` also works as-is against (B) and (C) below,
  since the wire format is identical.
- **b_dpdk/** -- kernel bypass: DPDK takes the NIC over from the kernel
  entirely and polls it directly in userspace, so it also has to answer
  ARP for its own IP itself (the kernel no longer will). Runs on
  `enp5s0`, this box's only NIC -- see `b_dpdk/setup.sh`'s header before
  running it, the unbind step drops this machine's own network link.
- **c_fpga/** -- no host software at all: `ping_mirror.sv` swaps
  src/dst MAC+IP+port in hardware and streams the reply straight back
  out, entirely on the NIC. Simulated and passing in `xsim`
  (`rtl/tb_ping_mirror.sv`); hardware bring-up not yet done, same stage
  as `../fpga`.

All of this runs on the mainframe (`matt@192.168.0.107`), which has the
normal NIC (A, B) and the ALINX FPGA (C).

## (A) kernel stack
```
cd a_kernel && make
./server.out &              # on the responder
./client.out <responder_ip> [count]
```

## (B) DPDK kernel bypass
```
cd b_dpdk
./setup.sh      # apt install + hugepages are safe over SSH; the NIC
                 # unbind step is not -- run it from the console
make
sudo ./ping_responder -l 0-1 -n 4 -- 192.168.0.107   # EAL args, then this box's own IP
```
From any other machine on the LAN, point `a_kernel/client.c` at
`192.168.0.107` as usual -- to the sender this looks like ordinary UDP
traffic; only the responder side is bypassing its kernel.
`teardown.sh` rebinds `enp5s0` back to the kernel driver afterwards
(console only, same reason).

## (C) FPGA
```
cd c_fpga/rtl
xvlog -sv ping_pkg.sv ping_mirror.sv tb_ping_mirror.sv
xelab tb_ping_mirror -s tb && xsim tb -R   # PASS: 58-byte reply matches expected swap
```
Then `../build/create_ping_project.tcl` in Vivado for the real board
(see its header for what's still a TODO -- eth_mac_0's RGMII
customization, same known gap as `../../fpga`).
