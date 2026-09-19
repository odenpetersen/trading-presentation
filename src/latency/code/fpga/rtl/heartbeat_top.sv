// Top-level for the licensing-free bring-up MVP: just heartbeat_reg,
// wired to an AXI BRAM Controller (Port A) fed by XDMA. See
// heartbeat_reg.sv for why this exists as a separate, smaller milestone.
module heartbeat_top (
    input  logic         clka,
    input  logic         rsta,
    input  logic         ena,
    input  logic [3:0]   wea,
    input  logic [3:0]   addra,
    input  logic [31:0]  dina,
    output logic [31:0]  douta
);

    heartbeat_reg u_heartbeat (
        .clka(clka), .rsta(rsta), .ena(ena), .wea(wea),
        .addra(addra), .dina(dina), .douta(douta)
    );

endmodule
