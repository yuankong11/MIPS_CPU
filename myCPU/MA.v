module MA(
    input clk,
    input rst_p,
    input empty,

    //pipeline signals
    input  EX_ready,
    output MA_enable,
    output MA_ready,
    input  WB_enable,

    //memory access signals
    input  interlayer_ready,
    output MA_mem_read,
    output MA_mem_write,
    output [ 3 : 0] MA_mem_wstrb,
    output [31 : 0] MA_mem_addr,
    output [ 2 : 0] MA_mem_size,
    output [31 : 0] MA_mem_wdata,

    //interact with EX
    input [4 : 0] inst_rd_in,

    input [31 : 0] rf_A_in,
    input [31 : 0] rf_B_in,

    input [4 : 0] rf_waddr_in,
    input [2 : 0] rf_wdata_src_in,
    input rf_wen_in,

    input [1 : 0] mf_hi_lo_in,
    input [1 : 0] mt_hi_lo_in,
    input [2 : 0] mul_div_in,

    input mem_read_in,
    input mem_write_in,
    input [6 : 0] align_load_in,
    input [4 : 0] align_store_in,

    input eret_in,
    input mfc0_in,
    input mtc0_in,

    input [31 : 0] alu_res_in,

    input [31 : 0] EX_PC,

    input in_delay_slot_in,
    input address_error_IF_in,
    input [4 : 0] exccode_in,

    //interact with WB
    output [31 : 0] rf_B_out,
    output [ 4 : 0] rf_waddr_out,
    output [ 2 : 0] rf_wdata_src_out,
    output rf_wen_out,
    output [31 : 0] alu_res_out,
    output mem_read_out,
    output [6 : 0] align_load_out,

    output reg [31 : 0] MA_PC,

    //interact with mul_div
    input mul_div_done_in,
    input [63 : 0] mul_div_res_in,

    //interact with forward
    output valid_out,
    output leaving_out,

    //interract with excption
    output address_error_IF_out,
    output in_delay_slot_out,
    output [ 4 : 0] cp0_addr,
    input  [31 : 0] cp0_rdata,
    output [31 : 0] cp0_wdata,
    output mtc0_out,
    output eret_out,
    output [4 : 0] exccode_out
);

reg valid;
assign valid_out = valid;

wire comming = MA_enable && EX_ready;
wire leaving = WB_enable && MA_ready;

reg [4 : 0] inst_rd;
reg [31 : 0] rf_A;
reg [31 : 0] rf_B;
reg [4 : 0] rf_waddr;
reg [2 : 0] rf_wdata_src;
reg rf_wen;
reg [1 : 0] mf_hi_lo;
reg [1 : 0] mt_hi_lo;
reg [1 : 0] mul_div;
reg mem_read;
reg mem_write;
reg [6 : 0] align_load;
reg [4 : 0] align_store;
reg eret;
reg mfc0;
reg mtc0;

wire write_stall = valid && mem_write && !interlayer_ready;

wire doing;
assign leaving_out = WB_enable && valid && !doing && !write_stall; //to avoid leaving-empty combinational loop

always @(posedge clk)
begin
    if(rst_p || empty) valid <= 1'd0;
    else if(comming) valid <= 1'd1;
    else if(leaving) valid <= 1'd0;
    else ;
end

assign MA_enable = !valid || leaving;
assign MA_ready  =  valid && !doing && ~empty && !write_stall;

reg [31 : 0] alu_res;
reg [31 : 0] HI;
reg [31 : 0] LO;
reg in_delay_slot;
reg address_error_IF;
reg [4 : 0] exccode;

always @(posedge clk)
begin
    if(comming)
    begin
        inst_rd <= inst_rd_in;

        rf_A <= rf_A_in;
        rf_B <= rf_B_in;

        rf_waddr     <= rf_waddr_in;
        rf_wdata_src <= rf_wdata_src_in;
        rf_wen       <= rf_wen_in;

        mf_hi_lo <= mf_hi_lo_in;
        mt_hi_lo <= mt_hi_lo_in;
        mul_div  <= mul_div_in[1:0]; //don't mind signed or unsigned now

        mem_read  <= mem_read_in;
        mem_write <= mem_write_in;
        align_load  <= align_load_in;
        align_store <= align_store_in;

        eret <= eret_in;
        mfc0 <= mfc0_in;
        mtc0 <= mtc0_in;

        alu_res <= alu_res_in;

        in_delay_slot    <= in_delay_slot_in;
        address_error_IF <= address_error_IF_in;
        exccode          <= exccode_in;
    end
    else ;
end

assign rf_waddr_out = rf_waddr;
assign rf_wdata_src_out = rf_wdata_src;
assign rf_wen_out = rf_wen;

assign alu_res_out = mf_hi_lo[0] ? LO :
                     mf_hi_lo[1] ? HI :
                     mfc0 ? cp0_rdata : alu_res;

assign mem_read_out = mem_read;
assign align_load_out = align_load;

assign rf_B_out = rf_B;

assign in_delay_slot_out    = in_delay_slot;
assign address_error_IF_out = address_error_IF;
assign cp0_addr  = inst_rd;
assign cp0_wdata = rf_B;
assign mtc0_out  = mtc0;
assign eret_out  = eret;
assign exccode_out = exccode;

assign doing = valid && (mul_div[0] || mul_div[1]) && !mul_div_done_in;

wire [3 : 0] alu_res_align = {alu_res[1:0] == 2'b11, alu_res[1:0] == 2'b10,
                              alu_res[1:0] == 2'b01, alu_res[1:0] == 2'b00};
wire [31 : 0] mem_sw_data  = rf_B;
wire [31 : 0] mem_sb_data  = ( {32{alu_res_align[2'b00]}} & {24'd0, rf_B[7 : 0]       } ) |
                             ( {32{alu_res_align[2'b01]}} & {16'd0, rf_B[7 : 0],  8'd0} ) |
                             ( {32{alu_res_align[2'b10]}} & { 8'd0, rf_B[7 : 0], 16'd0} ) |
                             ( {32{alu_res_align[2'b11]}} & {       rf_B[7 : 0], 24'd0} ) ;
wire [31 : 0] mem_sh_data  = ( {32{~alu_res[1]}} & {16'd0, rf_B[15 : 0]} ) |
                             ( {32{ alu_res[1]}} & {rf_B[15 : 0], 16'd0} ) ;
wire [31 : 0] mem_swl_data = ( {32{alu_res_align[2'b00]}} & {24'd0, rf_B[31 : 24]} ) |
                             ( {32{alu_res_align[2'b01]}} & {16'd0, rf_B[31 : 16]} ) |
                             ( {32{alu_res_align[2'b10]}} & { 8'd0, rf_B[31 :  8]} ) |
                             ( {32{alu_res_align[2'b11]}} & rf_B ) ;
wire [31 : 0] mem_swr_data = ( {32{alu_res_align[2'b00]}} & rf_B ) |
                             ( {32{alu_res_align[2'b01]}} & {rf_B[23 : 0],  8'd0} ) |
                             ( {32{alu_res_align[2'b10]}} & {rf_B[15 : 0], 16'd0} ) |
                             ( {32{alu_res_align[2'b11]}} & {rf_B[ 7 : 0], 24'd0} ) ;
wire [ 3 : 0] mem_sw_strb  = 4'b1111;
wire [ 3 : 0] mem_sb_strb  = {alu_res_align[2'b11], alu_res_align[2'b10],
                              alu_res_align[2'b01], alu_res_align[2'b00]};
wire [ 3 : 0] mem_sh_strb  = {alu_res[1], alu_res[1], ~alu_res[1], ~alu_res[1]};
wire [ 3 : 0] mem_swl_strb = {alu_res[1] & alu_res[0], alu_res[1], alu_res[1] | alu_res[0], 1'b1};
wire [ 3 : 0] mem_swr_strb = {1'b1, ~(alu_res[1] & alu_res[0]), ~alu_res[1], ~(alu_res[1] | alu_res[0])};

assign MA_mem_read  = mem_read && leaving;
assign MA_mem_write = mem_write && leaving;
assign MA_mem_wstrb = ( {4{align_store[4]}} & mem_sw_strb  ) |
                      ( {4{align_store[3]}} & mem_sb_strb  ) |
                      ( {4{align_store[2]}} & mem_sh_strb  ) |
                      ( {4{align_store[1]}} & mem_swl_strb ) |
                      ( {4{align_store[0]}} & mem_swr_strb ) ;
assign MA_mem_addr  = {alu_res[31 : 2], 2'd0};
wire [2 : 0] load_size  = ( {3{align_load[6]}} & 3'd4 ) |
                          ( {3{align_load[5] | align_load[4]}} & 3'd1 ) |
                          ( {3{align_load[3] | align_load[2]}} & 3'd2 ) |
                          ( {3{align_load[1] | align_load[0]}} & 3'd4 ) ;
wire [2 : 0] store_size = ({3{align_store[4]}} & 3'd4) |
                          ({3{align_store[3]}} & 3'd1) |
                          ({3{align_store[2]}} & 3'd2) |
                          ({3{align_store[1]}} & 3'd4) |
                          ({3{align_store[0]}} & 3'd4) ;
assign MA_mem_size  = mem_read ? load_size : store_size;
assign MA_mem_wdata = ( {32{align_store[4]}} & mem_sw_data  ) |
                      ( {32{align_store[3]}} & mem_sb_data  ) |
                      ( {32{align_store[2]}} & mem_sh_data  ) |
                      ( {32{align_store[1]}} & mem_swl_data ) |
                      ( {32{align_store[0]}} & mem_swr_data ) ;

always @(posedge clk)
begin
    if((mul_div[0] || mul_div[1]) && leaving) {HI, LO} <= mul_div_res_in;
    else if(mt_hi_lo[0] && leaving) LO <= rf_A;
    else if(mt_hi_lo[1] && leaving) HI <= rf_A;
    else ;
end

always @(posedge clk)
begin
    if(comming) MA_PC <= EX_PC;
    else ;
end

endmodule
