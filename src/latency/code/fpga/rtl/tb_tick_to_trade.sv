// Simulation harness: replays one real captured frame (packet #1 from
// pcaps/ny4-xnas-tvitch-a-20230822T145000.pcap.zst -- a VLAN-tagged
// MoldUDP64/ITCH 'D' Order Delete message, StockLocate=0x04bf=1215) one
// byte per cycle (matching the Tri-Mode Ethernet MAC's 8-bit AXI4-Stream),
// programs a cache-refresh write for that same key, and checks a response
// comes out.
import market_data_pkg::*;

module tb_tick_to_trade;

    logic clk = 0, rst = 1;
    always #1 clk = ~clk;

    logic [DATA_WIDTH-1:0] s_axis_tdata;
    logic [KEEP_WIDTH-1:0] s_axis_tkeep;
    logic                  s_axis_tvalid, s_axis_tlast, s_axis_tuser;

    logic [DATA_WIDTH-1:0] m_axis_tdata;
    logic [KEEP_WIDTH-1:0] m_axis_tkeep;
    logic                  m_axis_tvalid, m_axis_tlast;
    logic                  m_axis_tready = 1'b1;

    logic                          ena = 0;
    logic [LINE_WIDTH_BITS/8-1:0]  wea = '0;
    logic [CACHE_ADDR_WIDTH-1:0]   addra = '0;
    logic [LINE_WIDTH_BITS-1:0]    dina = '0;
    logic [LINE_WIDTH_BITS-1:0]    douta;

    // Latch the response pulse instead of sampling m_axis_tvalid at a
    // single point in time -- a short cached frame can complete (assert
    // tvalid/tlast and drop back to idle) well within the wait window.
    logic seen_response = 1'b0;
    logic seen_tlast;
    logic [KEEP_WIDTH-1:0] seen_tkeep;
    always @(posedge clk) begin
        if (m_axis_tvalid) begin
            seen_response <= 1'b1;
            seen_tlast    <= m_axis_tlast;
            seen_tkeep    <= m_axis_tkeep;
        end
    end

    tick_to_trade_top dut (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tlast(s_axis_tlast), .s_axis_tuser(s_axis_tuser),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tlast(m_axis_tlast), .m_axis_tready(m_axis_tready),
        .clka(clk), .rsta(rst), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(douta)
    );

    // Packet #1 from the pcap, 87 bytes, byte 0 first.
    localparam int FRAME_BYTES = 87;
    logic [7:0] frame [0:FRAME_BYTES-1];
    localparam int STOCK_LOCATE = 16'h04bf; // matches KEY_OFFSET_BYTES/WIDTH in market_data_pkg.sv

    initial begin
        frame[0]='h01; frame[1]='h00; frame[2]='h5e; frame[3]='h36; frame[4]='h0c; frame[5]='h6f;
        frame[6]='hd4; frame[7]='haf; frame[8]='hf7; frame[9]='hcb; frame[10]='h20; frame[11]='hd5;
        frame[12]='h81; frame[13]='h00; frame[14]='h00; frame[15]='h8d;
        frame[16]='h08; frame[17]='h00; frame[18]='h45; frame[19]='h00; frame[20]='h00; frame[21]='h45;
        frame[22]='hbb; frame[23]='hf5; frame[24]='h40; frame[25]='h00; frame[26]='h15; frame[27]='h11;
        frame[28]='h65; frame[29]='hba; frame[30]='hce; frame[31]='hc8;
        frame[32]='h7f; frame[33]='h8a; frame[34]='he9; frame[35]='h36; frame[36]='h0c; frame[37]='h6f;
        frame[38]='hc1; frame[39]='hf5; frame[40]='h67; frame[41]='h6d; frame[42]='h00; frame[43]='h31;
        frame[44]='h3d; frame[45]='hf9;
        frame[46]='h30; frame[47]='h30; frame[48]='h30; frame[49]='h30; frame[50]='h31; frame[51]='h30;
        frame[52]='h30; frame[53]='h35; frame[54]='h39; frame[55]='h42;
        frame[56]='h00; frame[57]='h00; frame[58]='h00; frame[59]='h00; frame[60]='h07; frame[61]='hcc;
        frame[62]='he7; frame[63]='hdf;
        frame[64]='h00; frame[65]='h01; frame[66]='h00; frame[67]='h13;
        frame[68]='h44; frame[69]='h04; frame[70]='hbf; frame[71]='h00; frame[72]='h00; frame[73]='h23;
        frame[74]='h78; frame[75]='h65; frame[76]='h24; frame[77]='ha7; frame[78]='hf2; frame[79]='h00;
        frame[80]='h00; frame[81]='h00; frame[82]='h07; frame[83]='hea; frame[84]='h31; frame[85]='hed;
        frame[86]='h00; // pad byte, not part of the real 87-byte frame (tkeep masks it off)

        s_axis_tdata = '0; s_axis_tkeep = '0; s_axis_tvalid = 0; s_axis_tlast = 0; s_axis_tuser = 0;
        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk);
        @(posedge clk);

        // Program the cache line for StockLocate=0x04bf with a trivial
        // response frame and mark valid.
        @(posedge clk);
        ena   <= 1;
        wea   <= '1;
        addra <= STOCK_LOCATE[CACHE_ADDR_WIDTH-1:0];
        dina  <= '0;
        dina[LINE_VALID_BIT]                <= 1'b1;
        dina[LINE_LEN_LSB +: LINE_LEN_WIDTH] <= 16'd64;
        @(posedge clk);
        ena <= 0; wea <= '0;

        // Drive the real captured frame one byte per cycle.
        for (int i = 0; i < FRAME_BYTES; i++) begin
            @(posedge clk);
            s_axis_tdata  <= frame[i];
            s_axis_tkeep  <= 1'b1;
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= (i == FRAME_BYTES-1);
        end
        @(posedge clk);
        s_axis_tvalid <= 0;
        s_axis_tlast  <= 0;

        // Frame took FRAME_BYTES cycles; the cached response (64B, also
        // 1 byte/cycle) takes another ~64 plus a few pipeline cycles.
        repeat (FRAME_BYTES + 100) @(posedge clk);
        if (seen_response)
            $display("PASS: got a response beat, tlast=%0b tkeep=%h", seen_tlast, seen_tkeep);
        else
            $display("FAIL: no response observed");
        $finish;
    end

endmodule
