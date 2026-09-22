module rom(input [3:0] pc,output reg [13:0] ins);
localparam N=8;
function [13:0] i(input o,input [3:0] d,s,t);i={1'b1,o,d,s,t};endfunction
always @* case(pc)
0:ins=i(1,1,2,3);
1:ins=i(0,4,1,5);
2:ins=i(0,6,7,8);
3:ins=i(0,9,7,7);
4:ins=i(1,10,7,8);
5:ins=i(0,11,10,2);
6:ins=i(0,12,7,8);
7:ins=i(0,13,12,12);
default:ins=0;
endcase
endmodule
