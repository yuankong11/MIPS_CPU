module IF(
    input clk,
    input rst_p,
    input empty,

    //pipeline signals
    input  interlayer_ready,
    output IF_enable,
    output IF_ready,
    input  DE_enable,

    //memory access signals
    output IF_skip,
    output [31 : 0] IF_mem_addr,
    input  [31 : 0] IF_mem_rdata,

    //interact with DE
    input  eret,
    input  PC_modified,
    input  [31 : 0] PC_modified_data,
    output [31 : 0] IF_PC,
    output [31 : 0] inst_out,

    output [4 : 0] exccode_out,

    //interact with exception
    input exception,
    input [31 : 0] exception_handler_entry,
    input [31 : 0] epc
);

reg valid;

always @(posedge clk)
begin
    if(rst_p) valid <= 1'd1;
    else ;
end

assign IF_enable = (valid && DE_enable) || exception;
assign IF_ready  = valid && interlayer_ready;

reg  [31 : 0] PC;

always @(posedge clk)
begin
    if(rst_p)                 PC <= 32'hbfc0_0000;
    else if(exception)        PC <= exception_handler_entry;
    else if(eret)             PC <= epc;
    else if(interlayer_ready) PC <= PC_modified_r ? PC_modified_data_r : PC + 32'd4;
    else ;
end

reg PC_modified_r;
reg [31 : 0] PC_modified_data_r;

always @(posedge clk)
begin
    if(rst_p || empty)
        PC_modified_r <= 1'd0;
    else if(PC_modified)
        PC_modified_r <= 1'd1;
    else if(interlayer_ready || exception)
        PC_modified_r <= 1'd0;
    else ;

    if(PC_modified)
        PC_modified_data_r <= PC_modified_data;
    else ;
end

assign IF_skip     = exception || empty;
assign IF_mem_addr = exception ? exception_handler_entry :
                     eret      ? epc : PC;
assign inst_out    = IF_mem_rdata;

assign IF_PC = PC;
assign exccode_out = (IF_PC[1:0] != 2'd0) ? 5'h04 : 5'h00; //AdEL

endmodule
