// Streams a cached response frame out over the MAC TX AXI4-Stream as soon
// as cache_read_port signals a hit. No header rebuilding: the frame was
// stored byte-exact by software when it wrote the cache line, so this is
// a straight memory-to-wire copy.
//
// Limitation: single frame in flight. A resp_start pulse that arrives
// while `busy` is high is dropped (the packet just doesn't get a fast-path
// response). If your pcaps show hits closer together than
// MAX_FRAME_BEATS cycles, add a small (2-4 entry) skid FIFO in front of
// this FSM rather than widening this module.
import market_data_pkg::*;

module tx_response_fsm (
    input  logic                  clk,
    input  logic                  rst,

    input  logic                  resp_start,
    input  cache_line_t           resp_line,
    output logic                  busy,

    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic [KEEP_WIDTH-1:0] m_axis_tkeep,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready
);

    logic [MAX_FRAME_BYTES*8-1:0] frame_reg;
    logic [15:0]                  len_reg;
    logic [$clog2(MAX_FRAME_BEATS+1)-1:0] beat_idx;

    typedef enum logic [0:0] {IDLE, SEND} state_t;
    state_t state;

    assign busy = (state == SEND);

    function automatic logic [7:0] frame_byte(input logic [MAX_FRAME_BYTES*8-1:0] f, input int idx);
        frame_byte = f[idx*8 +: 8];
    endfunction

    always_comb begin
        m_axis_tvalid = (state == SEND);
        for (int lane = 0; lane < KEEP_WIDTH; lane++) begin
            automatic int byte_idx = beat_idx*KEEP_WIDTH + lane;
            m_axis_tdata[lane*8 +: 8] = (byte_idx < MAX_FRAME_BYTES) ? frame_byte(frame_reg, byte_idx) : 8'h00;
            m_axis_tkeep[lane]        = (byte_idx < len_reg);
        end
        m_axis_tlast = ((beat_idx+1)*KEEP_WIDTH >= len_reg);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (resp_start) begin
                        frame_reg <= resp_line.frame;
                        len_reg   <= resp_line.len_bytes;
                        beat_idx  <= '0;
                        state     <= SEND;
                    end
                end
                SEND: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        if (m_axis_tlast) state <= IDLE;
                        else              beat_idx <= beat_idx + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
