module tomasulo #(parameter LM=6,LA=2)(input clk,rst,output reg [3:0] pc,output reg done,output reg [7:0] cycles,retired,output reg cdb_v,output reg [2:0] cdb_tag,output reg [15:0] cdb_val,output [3:0] rs_busy,output [255:0] rf);
reg [15:0] val[0:15];reg [2:0] tag[0:15];
reg rb[1:4],rop[1:4];reg [15:0] vj[1:4],vk[1:4];reg [2:0] qj[1:4],qk[1:4];reg [3:0] rd[1:4];reg [1:0] st[1:4];reg [3:0] cnt[1:4];
wire [13:0] ins;rom r(pc,ins);
wire iv=ins[13],op=ins[12];wire [3:0] d=ins[11:8],s=ins[7:4],t=ins[3:0];
wire [2:0] fr=op?(!rb[1]?1:!rb[2]?2:0):(!rb[3]?3:!rb[4]?4:0);
wire issue=iv&&fr!=0&&!done;
wire idle=!rb[1]&&!rb[2]&&!rb[3]&&!rb[4];
assign rs_busy={rb[4],rb[3],rb[2],rb[1]};
genvar g;generate for(g=0;g<16;g=g+1)begin:x assign rf[g*16+:16]=val[g];end endgenerate
integer i,k;
always @* begin cdb_v=0;cdb_tag=0;for(i=4;i>=1;i=i-1)if(rb[i]&&st[i]==2)begin cdb_v=1;cdb_tag=i;end cdb_val=cdb_v?(rop[cdb_tag]?vj[cdb_tag]*vk[cdb_tag]:vj[cdb_tag]+vk[cdb_tag]):0;end
always @(posedge clk)if(rst)begin pc<=0;done<=0;cycles<=0;retired<=0;for(i=0;i<16;i=i+1)begin val[i]<=i+1;tag[i]<=0;end for(i=1;i<=4;i=i+1)begin rb[i]<=0;st[i]<=0;qj[i]<=0;qk[i]<=0;end end
else begin
	if(!done)cycles<=cycles+1;
	if(cdb_v)begin retired<=retired+1;rb[cdb_tag]<=0;st[cdb_tag]<=0;
		for(k=0;k<16;k=k+1)if(tag[k]==cdb_tag)begin val[k]<=cdb_val;tag[k]<=0;end
		for(i=1;i<=4;i=i+1)if(rb[i])begin if(qj[i]==cdb_tag)begin vj[i]<=cdb_val;qj[i]<=0;end if(qk[i]==cdb_tag)begin vk[i]<=cdb_val;qk[i]<=0;end end
	end
	for(i=1;i<=4;i=i+1)if(rb[i])case(st[i])
		0:if(qj[i]==0&&qk[i]==0)begin st[i]<=1;cnt[i]<=rop[i]?LM:LA;end
		1:if(cnt[i]==1)st[i]<=2;else cnt[i]<=cnt[i]-1;
	endcase
	if(issue)begin rb[fr]<=1;rop[fr]<=op;st[fr]<=0;rd[fr]<=d;pc<=pc+1;tag[d]<=fr;
		if(tag[s]==0)begin vj[fr]<=val[s];qj[fr]<=0;end else if(cdb_v&&tag[s]==cdb_tag)begin vj[fr]<=cdb_val;qj[fr]<=0;end else qj[fr]<=tag[s];
		if(tag[t]==0)begin vk[fr]<=val[t];qk[fr]<=0;end else if(cdb_v&&tag[t]==cdb_tag)begin vk[fr]<=cdb_val;qk[fr]<=0;end else qk[fr]<=tag[t];
	end
	if(!iv&&idle)done<=1;
end
endmodule
