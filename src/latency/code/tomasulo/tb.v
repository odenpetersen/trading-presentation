`timescale 1ns/1ps
module tb;
reg clk=0,rst=1;always #5 clk=~clk;
wire [3:0] t_pc,i_pc;wire t_done,i_done,cdb_v,stall;wire [7:0] t_cycles,i_cycles,t_ret,i_ret;wire [2:0] cdb_tag;wire [15:0] cdb_val;wire [3:0] rs_busy;wire [255:0] t_rf,i_rf;
tomasulo t(clk,rst,t_pc,t_done,t_cycles,t_ret,cdb_v,cdb_tag,cdb_val,rs_busy,t_rf);
inorder i(clk,rst,i_pc,i_done,i_cycles,i_ret,stall,i_rf);
initial begin #25 rst=0;wait(t_done&&i_done);#20;
	$display("in-order: %0d cycles  tomasulo: %0d cycles  speedup: %0d.%02dx  regs %s",i_cycles,t_cycles,i_cycles*100/t_cycles/100,i_cycles*100/t_cycles%100,t_rf==i_rf?"MATCH":"MISMATCH");
	$finish;end
initial begin #5000 $display("timeout");$finish;end
endmodule
