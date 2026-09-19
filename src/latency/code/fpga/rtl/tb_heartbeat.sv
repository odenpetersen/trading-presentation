// Simulation check: read the heartbeat register twice with real time
// passing in between, confirm the second read is larger than the first.
module tb_heartbeat;

    logic clka = 0; always #5 clka = ~clka; // 100MHz, standing in for the PCIe/XDMA clock
    logic rsta = 1;
    logic        ena = 0;
    logic [3:0]  wea = '0;
    logic [3:0]  addra = '0;
    logic [31:0] dina = '0;
    logic [31:0] douta;

    heartbeat_top dut (
        .clka(clka), .rsta(rsta), .ena(ena), .wea(wea),
        .addra(addra), .dina(dina), .douta(douta)
    );

    task automatic read_reg(output logic [31:0] val);
        @(posedge clka);
        ena <= 1'b1;
        @(posedge clka);
        #1;
        val = douta;
        ena <= 1'b0;
    endtask

    logic [31:0] first_val, second_val;

    initial begin
        repeat (5) @(posedge clka);
        rsta = 0;

        read_reg(first_val);
        repeat (50) @(posedge clka);
        read_reg(second_val);

        $display("first=%0d second=%0d", first_val, second_val);
        if (second_val > first_val)
            $display("PASS: heartbeat advanced between reads");
        else
            $display("FAIL: heartbeat did not advance");
        $finish;
    end

endmodule
