// Drives one synthetic ping frame (untagged Eth/IPv4/UDP to port 9876,
// 16B payload) into ping_mirror one byte per cycle -- matching the 1G
// Tri-Mode MAC's 8-bit AXI4-Stream -- and checks the frame that comes
// back has src/dst MAC, IP and UDP port swapped with everything else
// (including both checksums) untouched.
import ping_pkg::*;

module tb_ping_mirror;

    logic clk = 0, rst = 1;
    always #1 clk = ~clk;

    logic [DATA_WIDTH-1:0] s_axis_tdata;
    logic [KEEP_WIDTH-1:0] s_axis_tkeep;
    logic                  s_axis_tvalid, s_axis_tlast, s_axis_tuser;

    logic [DATA_WIDTH-1:0] m_axis_tdata;
    logic [KEEP_WIDTH-1:0] m_axis_tkeep;
    logic                  m_axis_tvalid, m_axis_tlast;
    logic                  m_axis_tready = 1'b1;

    ping_mirror dut (
        .clk(clk), .rst(rst),
        .s_axis_tdata(s_axis_tdata), .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid), .s_axis_tlast(s_axis_tlast), .s_axis_tuser(s_axis_tuser),
        .m_axis_tdata(m_axis_tdata), .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid), .m_axis_tlast(m_axis_tlast), .m_axis_tready(m_axis_tready)
    );

    localparam int FRAME_BYTES = 58; // 14 (eth) + 20 (ip) + 8 (udp) + 16 (ping_pkt payload)
    logic [7:0] frame [0:FRAME_BYTES-1];
    logic [7:0] expected [0:FRAME_BYTES-1];
    logic [7:0] got [0:FRAME_BYTES-1];
    int got_n = 0;

    always @(posedge clk) if (m_axis_tvalid) begin
        got[got_n] <= m_axis_tdata;
        got_n <= got_n + 1;
    end

    initial begin
        // dst=fpga_mac, src=sender_mac
        frame[0]='h02; frame[1]='h00; frame[2]='h00; frame[3]='h00; frame[4]='h00; frame[5]='h02;
        frame[6]='h02; frame[7]='h00; frame[8]='h00; frame[9]='h00; frame[10]='h00; frame[11]='h01;
        frame[12]='h08; frame[13]='h00; // ethertype 0x0800
        frame[14]='h45; frame[15]='h00; frame[16]='h00; frame[17]='h2c; // ver/ihl, dscp, total_len=44
        frame[18]='h12; frame[19]='h34; frame[20]='h00; frame[21]='h00; // id, flags/frag
        frame[22]='h40; frame[23]='h11;                                // ttl=64, proto=UDP
        frame[24]='hab; frame[25]='hcd;                                // ip checksum (arbitrary, must survive unchanged)
        frame[26]='hc0; frame[27]='ha8; frame[28]='h00; frame[29]='h32; // src_ip 192.168.0.50
        frame[30]='hc0; frame[31]='ha8; frame[32]='h00; frame[33]='h6b; // dst_ip 192.168.0.107 (fpga)
        frame[34]='hd4; frame[35]='h31;                                // udp src_port 54321
        frame[36]='h26; frame[37]='h94;                                // udp dst_port 9876 (PING_UDP_PORT)
        frame[38]='h00; frame[39]='h18;                                // udp length=24
        frame[40]='h99; frame[41]='h99;                                // udp checksum (arbitrary, must survive unchanged)
        for (int i = 0; i < 16; i++) frame[42+i] = 8'h10 + i[7:0];     // ping_pkt payload, untouched

        expected = frame;
        // MAC swap
        for (int i = 0; i < 6; i++) begin expected[i] = frame[6+i]; expected[6+i] = frame[i]; end
        // IP addr swap
        for (int i = 0; i < 4; i++) begin expected[26+i] = frame[30+i]; expected[30+i] = frame[26+i]; end
        // UDP port swap
        for (int i = 0; i < 2; i++) begin expected[34+i] = frame[36+i]; expected[36+i] = frame[34+i]; end

        s_axis_tdata = '0; s_axis_tkeep = '0; s_axis_tvalid = 0; s_axis_tlast = 0; s_axis_tuser = 0;
        repeat (4) @(posedge clk);
        rst = 0;
        @(posedge clk);

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

        repeat (FRAME_BYTES + 20) @(posedge clk);

        if (got_n != FRAME_BYTES) begin
            $display("FAIL: got %0d bytes back, expected %0d", got_n, FRAME_BYTES);
        end else begin
            automatic int mismatches = 0;
            for (int i = 0; i < FRAME_BYTES; i++)
                if (got[i] !== expected[i]) begin
                    $display("FAIL: byte %0d got=%02h expected=%02h", i, got[i], expected[i]);
                    mismatches++;
                end
            if (mismatches == 0) $display("PASS: %0d-byte reply matches expected swap", FRAME_BYTES);
        end
        $finish;
    end

endmodule
