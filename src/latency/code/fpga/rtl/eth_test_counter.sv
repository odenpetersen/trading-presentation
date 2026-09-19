// Minimal RX visibility for the loopback bring-up test: a running frame
// count and the most recent frame's byte length, both plain continuous
// outputs (no address muxing) since everything here lives in one clock
// domain -- feed straight into a VIO core, which handles the JTAG-safe
// crossing itself. Purely observational; doesn't touch the loopback path.
module eth_test_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        s_axis_tvalid,
    input  logic        s_axis_tlast,

    output logic [15:0] frame_count,
    output logic [15:0] last_frame_len
);

    logic [15:0] byte_pos;

    always_ff @(posedge clk) begin
        if (rst) begin
            frame_count    <= 16'd0;
            byte_pos       <= 16'd0;
            last_frame_len <= 16'd0;
        end else if (s_axis_tvalid) begin
            if (s_axis_tlast) begin
                frame_count    <= frame_count + 16'd1;
                last_frame_len <= byte_pos + 16'd1;
                byte_pos       <= 16'd0;
            end else begin
                byte_pos <= byte_pos + 16'd1;
            end
        end
    end

endmodule
