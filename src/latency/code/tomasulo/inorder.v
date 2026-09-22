module inorder #(parameter LM=6,LA=2)(input clk,rst,output reg [3:0] pc,output reg done,output reg [7:0] cycles,retired,output stall,output [255:0] rf);
reg [15:0] val[0:15],pend[0:15];reg [4:0] rc[0:15];
wire [13:0] ins;rom r(pc,ins);
wire iv=ins[13],op=ins[12];wire [3:0] d=ins[11:8],s=ins[7:4],t=ins[3:0];
wire ok=rc[s]==0&&rc[t]==0&&rc[d]==0;
wire issue=iv&&ok&&!done;
assign stall=iv&&!ok&&!done;
genvar g;generate for(g=0;g<16;g=g+1)begin:x assign rf[g*16+:16]=val[g];end endgenerate
reg idle;integer i;
always @* begin idle=1;for(i=0;i<16;i=i+1)if(rc[i]!=0)idle=0;end
always @(posedge clk)if(rst)begin pc<=0;done<=0;cycles<=0;retired<=0;for(i=0;i<16;i=i+1)begin val[i]<=i+1;rc[i]<=0;end end
else begin
	if(!done)cycles<=cycles+1;
	for(i=0;i<16;i=i+1)if(rc[i]!=0)begin if(rc[i]==1)begin val[i]<=pend[i];rc[i]<=0;retired<=retired+1;end else rc[i]<=rc[i]-1;end
	if(issue)begin pend[d]<=op?val[s]*val[t]:val[s]+val[t];rc[d]<=(op?LM:LA)+2;pc<=pc+1;end
	if(!iv&&idle)done<=1;
end
endmodule
