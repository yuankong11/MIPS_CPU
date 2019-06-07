module interlayer(
    input clk,
    input rst_p,

    //IF
    input  IF_enable,
    input  IF_skip,
    output interlayer_IF_ready,
    input  [31 : 0] IF_mem_addr,
    output [31 : 0] IF_mem_rdata,

	//inst sram_like
	output inst_req,
    output [31 : 0] inst_addr,
    input  [31 : 0] inst_rdata,
    input  inst_addr_ok,
    input  inst_data_ok,

    //WB
    input  MA_mem_read,
    input  MA_mem_write,
    output interlayer_MA_ready,
    output interlayer_WB_ready,
    input  [ 3 : 0] MA_mem_wstrb,
    input  [31 : 0] MA_mem_addr,
    input  [31 : 0] MA_mem_wdata,
    output [31 : 0] WB_mem_rdata,

	//data sram_like
	output data_req,
    output data_wr,
    output [31 : 0] data_addr,
    output [ 3 : 0] data_wstrb,
    output [31 : 0] data_wdata,
    input  [31 : 0] data_rdata,
    input  data_read_ok,
    input  data_write_full
);

reg inst_undone;
always @(posedge clk)
begin
    if(rst_p) inst_undone <= 1'd0;
    else inst_undone <= inst_undone + inst_addr_ok - inst_data_ok;
end

reg skip_state;
always @(posedge clk)
begin
    if(rst_p) skip_state <= 1'd0;
    else if(IF_skip && inst_undone) skip_state <= 1'd1;
    else if(inst_addr_ok) skip_state <= 1'd0;
    else ;
end

assign interlayer_IF_ready = inst_data_ok && !skip_state && !IF_skip;
assign IF_mem_rdata        = inst_rdata;

assign inst_req  = IF_enable;
assign inst_addr = IF_mem_addr;

assign interlayer_MA_ready = !data_write_full;
assign interlayer_WB_ready = data_read_ok;
assign WB_mem_rdata        = data_rdata;

assign data_req   = MA_mem_read || MA_mem_write;
assign data_wr    = MA_mem_write;
assign data_addr  = MA_mem_addr;
assign data_wstrb = MA_mem_wstrb;
assign data_wdata = MA_mem_wdata;

endmodule
