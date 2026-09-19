// Simplest possible hardware bring-up proof: a free-running counter,
// visible to the host through the same native-BRAM Port A convention used
// elsewhere in this project (wire directly to an AXI BRAM Controller).
// No RX/MAC dependency at all -- deliberately, to get something running
// on real silicon without waiting on the Tri-Mode Ethernet MAC's license
// (see fpga/README.md). Two host reads a moment apart returning different
// values is a complete proof that PCIe -> XDMA -> AXI BRAM Controller ->
// FPGA fabric -> back is alive and correctly clocked on real hardware.
// Once the MAC license is sorted, rx_packet_counter.sv (already written
// and simulated) picks up where this leaves off.
module heartbeat_reg (
    input  logic         clka,
    input  logic         rsta,
    input  logic         ena,
    input  logic [3:0]   wea,     // unused, read-only register, present for axi_bram_ctrl compatibility
    input  logic [3:0]   addra,
    input  logic [31:0]  dina,
    output logic [31:0]  douta
);

    logic [31:0] heartbeat;
    always_ff @(posedge clka) begin
        if (rsta) heartbeat <= 32'd0;
        else      heartbeat <= heartbeat + 32'd1;
    end

    always_ff @(posedge clka) begin
        if (ena) douta <= heartbeat;
    end

endmodule
