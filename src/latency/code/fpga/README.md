# Tick-to-trade cache-and-respond datapath

RTL for a fast-path FPGA responder: on an incoming UDP market-data packet,
extract an instrument key, look it up in a cache, and if there's a hit
stream a precomputed response frame straight back out -- no host round
trip. Software refreshes cache lines over PCIe with a plain pointer write.

## Hardware (confirmed)
**ALINX AXKU3** -- Xilinx Kintex UltraScale+ **XCKU3P-2FFVB676I** (PCB
silkscreen "AX9113"/"AX911130A", JTAG IDCODE `04A63093`). Its only network
interface is a built-in **10/100/1000M copper RJ-45** -- confirmed by the
cable itself (RJ45 both ends, no FMC/SFP+ daughter module). This is a 1G
link, not the 10-100G class originally assumed; see the latency note below.

## Protocol (verified against `pcaps/ny4-xnas-tvitch-a-20230822T145000.pcap.zst`)
NASDAQ TotalView-ITCH 5.0 over MoldUDP64, checked across all 8.6M packets
in the capture and cross-validated against github.com/bbalouki/itch's
message structs (exact byte-for-byte match):
- Every frame is 802.1Q VLAN-tagged (100% of packets) -- adds 4 bytes
  before the real EtherType.
- 100% UDP, dest port 26477, IPv4 with a plain 20-byte header (no options).
- UDP payload = MoldUDP64: `Session[10] SequenceNumber[8] MessageCount[2]`,
  then repeated `{MessageLength[2], MessageData}` blocks.
- Every ITCH message type shares a common header: `MessageType[1]
  StockLocate[2] TrackingNumber[2] Timestamp[6]`. **StockLocate is the
  cache key** -- it's already a small dense per-instrument integer
  assigned by the exchange, so it's used directly as the cache address,
  no hashing needed.
- All multi-byte fields are big-endian (network byte order), including
  StockLocate itself -- get this backwards and lookups silently miss
  (this bit us once already, see `udp_key_parser.sv`'s `byte_at`-based
  big-endian packing).
- **10.3% of packets carry more than one ITCH message** (MoldUDP64
  batching, up to 29 seen in one packet). This design only acts on the
  first message in a packet -- see Known Limitations.

Consequence for the hardware: the header stack through StockLocate is 70
bytes. On this board's Tri-Mode Ethernet MAC (1G copper), the native
AXI4-Stream is 8 bits wide -- 1 byte/cycle -- so `udp_key_parser.sv` is a
byte-serial parser that tracks a running byte position and shift-
accumulates each field of interest as its bytes pass, rather than the
wide-bus single/dual-beat design originally sketched for a 10-100G link.

**Latency reality check**: at 1Gbps, serializing the 70 bytes up to the
key alone takes ~560ns -- that's wire physics, not our logic, and it
dominates the total response latency far more than anything in this RTL.
The "cache-and-respond in hardware" value proposition still holds (it's
still much faster than a host round trip, which would wait for the same
bytes to arrive *and* add OS/software latency on top), but don't expect
sub-microsecond total response times on this link; that class of number
needs a 10G+ interface, which would mean widening `DATA_WIDTH` back up
and reworking the parser again if you add one later (e.g. via the FMC
connector).

## Files (`rtl/`)
- `market_data_pkg.sv` -- all parameters, values above already filled in
  from the verified pcap analysis.
- `udp_key_parser.sv` -- byte-serial VLAN/Eth/IP/UDP header validation + key extraction (1 byte/cycle).
- `td_cache_bram.sv` -- true dual-port cache memory (hand-inferred BRAM).
- `cache_read_port.sv` -- drives the read port, unpacks a cache line.
- `tx_response_fsm.sv` -- streams a hit's stored frame out the TX bus.
- `tick_to_trade_top.sv` -- wires the above between MAC RX/TX AXI4-Stream
  and the cache's refresh port (Port A).
- `tb_tick_to_trade.sv` -- xsim test replaying a real captured frame
  (packet #1 from the pcap above) one byte per cycle; no MAC/PCIe needed.

## Bringing into Vivado
1. Simulate first: `xsim` the testbench standalone before touching
   hardware -- `xvlog -sv rtl/*.sv && xelab tb_tick_to_trade -s tb && xsim tb -R`.
2. `PART` and `ETH_IP` in `build/create_project.tcl` are already set for
   the confirmed hardware (`xcku3p-ffvb676-2-i`, `tri_mode_ethernet_mac`).
   Run it:
   ```
   source /opt/Xilinx/2026.1/Vivado/settings64.sh
   vivado -mode batch -source build/create_project.tcl
   ```
   This creates the project, adds all the RTL sources (testbench routed to
   the sim fileset, not synthesis), and generates three IP cores: `xdma_0`
   (PCIe DMA), `axi_bram_ctrl_0` (bridges XDMA's AXI4 to the cache's native
   BRAM port), and `eth_mac_0` (Tri-Mode Ethernet MAC, 1G).
3. Customize `xdma_0` (lane count/link speed, BAR size -- needs to cover
   `CACHE_DEPTH * (LINE_WIDTH_BITS/8)` bytes) and `eth_mac_0` (this board's
   GMII/RGMII pin locations, from the AXKU3 schematic/pinout) via their IP
   customization GUIs in Vivado. `DATA_WIDTH` in `market_data_pkg.sv` (8)
   already matches Tri-Mode Ethernet MAC's native AXI4-Stream width.
4. Write a plain RTL top wrapper (not a Block Design / `.bd` -- keeps
   everything as diffable text) instantiating `xdma_0`, `axi_bram_ctrl_0`,
   `eth_mac_0` and `tick_to_trade_top`, wiring:
   - `eth_mac_0`'s RX/TX AXI4-Stream <-> `tick_to_trade_top`'s `s_axis`/`m_axis`
   - `axi_bram_ctrl_0`'s `BRAM_PORTA` interface (`bram_clk_a`, `bram_rst_a`,
     `bram_en_a`, `bram_we_a`, `bram_addr_a`, `bram_wrdata_a`,
     `bram_rddata_a`) <-> `tick_to_trade_top`'s Port A -- the whole
     cache-refresh path, no other RTL needed
   - one of `xdma_0`'s AXI4 master ports <-> `axi_bram_ctrl_0`'s AXI4 slave
   Add it with `add_files` and `set_property top` in the project.
5. Software refresh is then just a pointer write into the mapped BAR at
   `key * (LINE_WIDTH_BITS/8)`: build the full response frame bytes
   (dest MAC/IP/UDP header + payload; UDP checksum can be left 0, it's
   optional over IPv4) plus length, set the valid bit, write it.
   **Required write order** (a line is ~258 bytes, wider than one AXI
   beat, so a refresh is multiple transactions -- there is no hardware
   protection against a datapath read landing mid-refresh): (a) clear the
   valid bit first, (b) write length + frame bytes, (c) set the valid bit
   last. This makes the failure mode of a race "packet misses the fast
   path for one cycle" instead of "packet gets a torn, half-old/half-new
   response" -- get the order backwards and you risk the latter.
6. Add constraints (`.xdc`): clock period for `eth_mac_0`'s output clock,
   and GMII/RGMII pin locations for the AXKU3's RJ-45 PHY (check ALINX's
   schematic/example project for this board -- no generic board file
   covers a third-party card like this one).
7. Add an ILA on `lookup_valid`/`resp_start`/`m_axis_tvalid` for your first
   bring-up -- this is the easiest way to confirm the key extraction
   offsets are actually right against live traffic.

## Known limitations to revisit once real traffic is in front of you
- One response in flight at a time (`tx_response_fsm` drops a hit that
  arrives mid-transmit of a previous one). Fine if frames are short and
  hits are sparse; add a small skid FIFO if your pcap shows back-to-back
  hits closer together than one frame's transmit time.
- No IP/UDP checksum recomputation in hardware -- frames are stored and
  replayed byte-exact, so get that right when software writes the line.
- Only the first ITCH message in a MoldUDP64 packet is acted on. ~10.3%
  of packets in the verified capture carry more than one message
  (batched updates); those extra messages are currently invisible to the
  fast path. Revisit if this materially affects hit rate for your
  strategy -- it needs a small loop that walks `MessageLength` fields
  across additional beats, not a one-line fix.
- `udp_key_parser.sv` fires `lookup_valid` right after the key bytes pass
  (byte ~70), well before the frame's Ethernet FCS is known (that's only
  checked at the very end of the frame). This is inherent to true
  cut-through operation -- a real cut-through switch has the same
  tradeoff -- and isn't mitigated here: an extremely rare frame that fails
  FCS late could still trigger a response before that's known.
