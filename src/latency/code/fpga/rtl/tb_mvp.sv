// Simulation harness for the bring-up MVP: drives a few RX frames on one
// clock (125MHz, standing in for the Tri-Mode MAC's RX clock) and polls
// the register file on a genuinely different clock (100MHz, standing in
// for the PCIe/XDMA clock) to actually exercise the Gray-code CDC in
// rx_packet_counter.sv, not accidentally rely on same-clock behavior.
import market_data_pkg::*;

module tb_mvp;

    logic clk_rx = 0; always #4 clk_rx = ~clk_rx;   // ~125MHz
    logic clka   = 0; always #5 clka   = ~clka;     // ~100MHz
    logic rst_rx = 1, rsta = 1;

    logic [DATA_WIDTH-1:0] s_axis_tdata;
    logic [KEEP_WIDTH-1:0] s_axis_tkeep;
    logic                  s_axis_tvalid, s_axis_tlast, s_axis_tuser;
    logic [DATA_WIDTH-1:0] m_axis_tdata;
    logic [KEEP_WIDTH-1:0] m_axis_tkeep;
    logic                  m_axis_tvalid, m_axis_tlast;
    logic                  m_axis_tready = 1'b1;

    logic         ena = 0;
    logic [3:0]   wea = '0;
    logic [3:0]   addra = '0;
    logic [31:0]  dina = '0;
    logic [31:0]  douta;
    logic [31:0]  count_val, len_val;

    mvp_top dut (
        .clk_rx(clk_rx), .rst_rx(rst_rx),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tlast(s_axis_tlast), .s_axis_tuser(s_axis_tuser),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tlast(m_axis_tlast), .m_axis_tready(m_axis_tready),
        .clka(clka), .rsta(rsta), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(douta)
    );

    task automatic send_frame(input int len_bytes);
        for (int i = 0; i < len_bytes; i++) begin
            @(posedge clk_rx);
            s_axis_tdata  <= i[7:0];
            s_axis_tkeep  <= 1'b1;
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= (i == len_bytes-1);
        end
        @(posedge clk_rx);
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
    endtask

    task automatic read_reg(input logic [3:0] addr, output logic [31:0] val);
        @(posedge clka);
        ena   <= 1'b1;
        addra <= addr;
        @(posedge clka); // douta registers here (NBA) -- wait for it to settle before reading
        #1;
        val = douta;
        ena <= 1'b0;
    endtask

    initial begin
        s_axis_tdata = '0; s_axis_tkeep = '0; s_axis_tvalid = 0; s_axis_tlast = 0; s_axis_tuser = 0;
        repeat (5) @(posedge clk_rx);
        rst_rx = 0;
        repeat (5) @(posedge clka);
        rsta = 0;
        repeat (5) @(posedge clk_rx);

        send_frame(64);
        repeat (10) @(posedge clka); // let the Gray-code sync settle

        read_reg(4'd0, count_val);
        read_reg(4'd1, len_val);
        $display("After 1 frame: count=%0d last_len=%0d", count_val, len_val);
        if (count_val != 32'd1 || len_val != 32'd64) begin
            $display("FAIL: expected count=1 len=64");
            $finish;
        end

        send_frame(100);
        send_frame(42);
        repeat (10) @(posedge clka);
        read_reg(4'd0, count_val);
        read_reg(4'd1, len_val);
        $display("After 3 frames: count=%0d last_len=%0d", count_val, len_val);
        if (count_val != 32'd3 || len_val != 32'd42) begin
            $display("FAIL: expected count=3 len=42");
            $finish;
        end

        $display("PASS: counter tracks frames correctly across the clock domain crossing");
        $finish;
    end

endmodule
