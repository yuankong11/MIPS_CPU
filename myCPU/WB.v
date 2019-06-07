module WB(
    input clk,
    input rst_p,
    input empty,

    //pipeline signals
    input  MA_ready,
    output WB_enable,

    //interact with MA
    input [31 : 0] rf_B_in,
    input [ 4 : 0] rf_waddr_in,
    input [ 2 : 0] rf_wdata_src_in,
    input rf_wen_in,
    input [31 : 0] alu_res_in,
    input mem_read_in,
    input [6 : 0] align_load_in,

    input [31 : 0] MA_PC,

    //interact with interlayer
    input  interlayer_ready,
    input [31 : 0] mem_data,

    //interact with rf
    output [ 4 : 0] rf_waddr_out,
    output [31 : 0] rf_wdata_out,
    output rf_wen_leaving,

    //interact with debug
    output [31 : 0] debug_PC,
    output [ 3 : 0] debug_wb_rf_wen,
    output [ 4 : 0] debug_wb_rf_waddr,
    output [31 : 0] debug_wb_rf_wdata,

    //interact with forward
    output rf_wen_out,
    output leaving_out,
    output valid_out
);

reg valid;
assign valid_out = valid;

reg [31 : 0] rf_B;
reg [ 4 : 0] rf_waddr;
reg [ 2 : 0] rf_wdata_src;
reg rf_wen;
reg [31 : 0] alu_res;
reg mem_read;
reg [6 :  0] align_load;
reg [31 : 0] WB_PC;

wire comming = WB_enable && MA_ready;
wire leaving = valid && (mem_read ? interlayer_ready : 1'd1);

assign leaving_out = leaving;

always @(posedge clk)
begin
    if(rst_p)        valid <= 1'd0;
    else if(comming) valid <= 1'd1;
    else if(leaving) valid <= 1'd0;
    else ;
end

assign WB_enable = !valid || leaving;

always @(posedge clk)
begin
    if(comming)
    begin
        rf_B <= rf_B_in;

        rf_waddr     <= rf_waddr_in;
        rf_wdata_src <= rf_wdata_src_in;
        rf_wen       <= rf_wen_in;

        alu_res <= alu_res_in;

        mem_read <= mem_read_in;
        align_load <= align_load_in;

        WB_PC <= MA_PC;
    end
    else ;
end

assign rf_wen_out = rf_wen;

wire [3 : 0] alu_res_align = {alu_res[1:0] == 2'b11, alu_res[1:0] == 2'b10,
                              alu_res[1:0] == 2'b01, alu_res[1:0] == 2'b00};
wire [31 : 0] rf_lw_data  = mem_data;
wire [31 : 0] rf_lb_data  = ( {32{alu_res_align[2'b00]}} & { {24{mem_data[ 7]}}, mem_data[ 7 :  0] } ) |
                            ( {32{alu_res_align[2'b01]}} & { {24{mem_data[15]}}, mem_data[15 :  8] } ) |
                            ( {32{alu_res_align[2'b10]}} & { {24{mem_data[23]}}, mem_data[23 : 16] } ) |
                            ( {32{alu_res_align[2'b11]}} & { {24{mem_data[31]}}, mem_data[31 : 24] } ) ;
wire [31 : 0] rf_lbu_data = ( {32{alu_res_align[2'b00]}} & { 24'd0, mem_data[ 7 :  0] } ) |
                            ( {32{alu_res_align[2'b01]}} & { 24'd0, mem_data[15 :  8] } ) |
                            ( {32{alu_res_align[2'b10]}} & { 24'd0, mem_data[23 : 16] } ) |
                            ( {32{alu_res_align[2'b11]}} & { 24'd0, mem_data[31 : 24] } ) ;
wire [31 : 0] rf_lh_data  = ( {32{~alu_res[1]}} & { {16{mem_data[15]}}, mem_data[15 :  0] } ) |
                            ( {32{ alu_res[1]}} & { {16{mem_data[31]}}, mem_data[31 : 16] } ) ;
wire [31 : 0] rf_lhu_data = ( {32{~alu_res[1]}} & { 16'd0, mem_data[15 :  0] } ) |
                            ( {32{ alu_res[1]}} & { 16'd0, mem_data[31 : 16] } ) ;
wire [31 : 0] rf_lwl_data = ( {32{alu_res_align[2'b00]}} & { mem_data[ 7 : 0], rf_B[23 : 0] } ) |
                            ( {32{alu_res_align[2'b01]}} & { mem_data[15 : 0], rf_B[15 : 0] } ) |
                            ( {32{alu_res_align[2'b10]}} & { mem_data[23 : 0], rf_B[ 7 : 0] } ) |
                            ( {32{alu_res_align[2'b11]}} & mem_data) ;
wire [31 : 0] rf_lwr_data = ( {32{alu_res_align[2'b00]}} & mem_data) |
                            ( {32{alu_res_align[2'b01]}} & { rf_B[31 : 24], mem_data[31 :  8] } ) |
                            ( {32{alu_res_align[2'b10]}} & { rf_B[31 : 16], mem_data[31 : 16] } ) |
                            ( {32{alu_res_align[2'b11]}} & { rf_B[31 :  8], mem_data[31 : 24] } ) ;
wire [31 : 0] rf_mem_data = ( {32{align_load[6]}} & rf_lw_data  ) |
                            ( {32{align_load[5]}} & rf_lb_data  ) |
                            ( {32{align_load[4]}} & rf_lbu_data ) |
                            ( {32{align_load[3]}} & rf_lh_data  ) |
                            ( {32{align_load[2]}} & rf_lhu_data ) |
                            ( {32{align_load[1]}} & rf_lwl_data ) |
                            ( {32{align_load[0]}} & rf_lwr_data ) ;

assign rf_wen_leaving = rf_wen && leaving;
assign rf_waddr_out   = rf_waddr;
assign rf_wdata_out   = ( {32{rf_wdata_src[0]}} & alu_res     ) |
                        ( {32{rf_wdata_src[1]}} & alu_res     ) |
                        ( {32{rf_wdata_src[2]}} & rf_mem_data ) ;

assign debug_PC = WB_PC;
assign debug_wb_rf_wen   = {4{rf_wen_leaving}};
assign debug_wb_rf_waddr = rf_waddr;
assign debug_wb_rf_wdata = rf_wdata_out;

endmodule
