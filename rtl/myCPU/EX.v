`include "alu_op.h"

module EX(
    input clk,
    input rst_p,
    input empty,

    //pipeline signals
    input  DE_ready,
    output EX_enable,
    output EX_ready,
    input  MA_enable,

    //interact with DE
    input [4 : 0] rf_waddr_in,
    input [2 : 0] rf_wdata_src_in,
    input rf_wen_in,

    input [2 : 0] alu_src1_in,
    input [2 : 0] alu_src2_in,
    input [`OP_NUM - 1 : 0] alu_op_in,
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

    input [15 : 0] imm_16_in,

    input [31 : 0] rf_A_in,
    input [31 : 0] rf_B_in,

    input [31 : 0] DE_PC,

    input in_delay_slot_in,
    input address_error_IF_in,
    input overflow_exception_in,
    input [4 : 0] exccode_in,

    //interact with MA && mul_div
    output [4 : 0] inst_rd_out,

    output [31 : 0] rf_A_out,
    output [31 : 0] rf_B_out,

    output [4 : 0] rf_waddr_out,
    output [2 : 0] rf_wdata_src_out,
    output rf_wen_out,

    output [1 : 0] mf_hi_lo_out,
    output [1 : 0] mt_hi_lo_out,
    output [2 : 0] mul_div_out,

    output mem_read_out,
    output mem_write_out,
    output [6 : 0] align_load_out,
    output [4 : 0] align_store_out,

    output eret_out,
    output mfc0_out,
    output mtc0_out,

    output [31 : 0] alu_res_out,

    output reg [31 : 0] EX_PC,

    output in_delay_slot_out,
    output address_error_IF_out,
    output [4 : 0] exccode_out,

    //interact with forward
    output valid_out
);

reg valid;
assign valid_out = valid;

wire comming = EX_enable && DE_ready;
wire leaving = MA_enable && EX_ready;

always @(posedge clk)
begin
    if(rst_p || empty) valid <= 1'd0;
    else if(comming) valid <= 1'd1;
    else if(leaving) valid <= 1'd0;
    else ;
end

assign EX_enable = !valid || leaving;
assign EX_ready  =  valid && ~empty;

reg [4 : 0] rf_waddr;
reg [2 : 0] rf_wdata_src;
reg rf_wen;

reg [2 : 0] alu_src1;
reg [2 : 0] alu_src2;
reg [`OP_NUM - 1 : 0] alu_op;
reg [1 : 0] mf_hi_lo;
reg [1 : 0] mt_hi_lo;
reg [2 : 0] mul_div;

reg mem_read;
reg mem_write;
reg [6 : 0] align_load;
reg [4 : 0] align_store;

reg [15 : 0] imm_16;

reg [31 :  0] rf_A;
reg [31 :  0] rf_B;

reg eret;
reg mfc0;
reg mtc0;

reg in_delay_slot;
reg address_error_IF;
reg overflow_exception;
reg [4 : 0] exccode;

always @(posedge clk)
begin
    if(comming)
    begin
        rf_waddr     <= rf_waddr_in;
        rf_wdata_src <= rf_wdata_src_in;
        rf_wen       <= rf_wen_in;

        alu_src1 <= alu_src1_in;
        alu_src2 <= alu_src2_in;
        alu_op   <= alu_op_in;
        mt_hi_lo <= mt_hi_lo_in;
        mf_hi_lo <= mf_hi_lo_in;
        mul_div  <= mul_div_in;

        mem_read  <= mem_read_in;
        mem_write <= mem_write_in;
        align_load  <= align_load_in;
        align_store <= align_store_in;

        eret <= eret_in;
        mfc0 <= mfc0_in;
        mtc0 <= mtc0_in;

        imm_16 <= imm_16_in;

        rf_A <= rf_A_in;
        rf_B <= rf_B_in;

        in_delay_slot      <= in_delay_slot_in;
        address_error_IF   <= address_error_IF_in;
        overflow_exception <= overflow_exception_in;
        exccode            <= exccode_in;
    end
    else ;
end

assign inst_rd_out  = imm_16[15 : 11];
wire [ 4 : 0] shamt = imm_16[10 :  6];
wire [31 : 0] alu_A = ( {32{alu_src1[0]}} & rf_A           ) |
                      ( {32{alu_src1[1]}} & {27'd0, shamt} ) |
                      ( {32{alu_src1[2]}} & 32'd16         ) ;
wire [31 : 0] imm_16_se = { {16{imm_16[15]}}, imm_16 };
wire [31 : 0] imm_16_ze = {16'd0, imm_16};
wire [31 : 0] alu_B = ( {32{alu_src2[0]}} & rf_B      ) |
                      ( {32{alu_src2[1]}} & imm_16_se ) |
                      ( {32{alu_src2[2]}} & imm_16_ze ) ;
wire overflow;
wire [31 : 0] alu_res;

alu alu(
    .A (alu_A),
    .B (alu_B),
    .operation (alu_op),
    .zero     (),
    .overflow (overflow),
    .result (alu_res)
);

assign rf_A_out = rf_A;
assign rf_B_out = rf_B;

assign rf_waddr_out = rf_waddr;
assign rf_wdata_src_out = rf_wdata_src;
assign rf_wen_out = rf_wen;

assign mem_read_out  = mem_read;
assign mem_write_out = mem_write;
assign align_load_out  = align_load;
assign align_store_out = align_store;

assign eret_out = eret;
assign mfc0_out = mfc0;
assign mtc0_out = mtc0;

assign alu_res_out  = rf_wdata_src_out[1] ? (EX_PC + 32'd8) : alu_res;
assign mf_hi_lo_out = mf_hi_lo;
assign mt_hi_lo_out = mt_hi_lo;
assign mul_div_out  = mul_div & {3{leaving}};

wire overflow_exception_taken = overflow_exception && overflow;
wire address_error_load  = (align_load[6] && (alu_res[1:0] != 2'd0)) || //lw
                           ((align_load[3] || align_load[2]) && (alu_res[0] != 1'd0)); //lh, lhu
wire address_error_store = (align_store[4] && (alu_res[1:0] != 2'd0)) || //sw
                           (align_store[2] && (alu_res[0]   != 1'd0)) ;  //sh

assign in_delay_slot_out    = in_delay_slot;
assign address_error_IF_out = address_error_IF;
assign exccode_out = (exccode != 5'h00)         ? exccode : //AdEL(IF), RI, Sys, Bp
                     (overflow_exception_taken) ? 5'h0c   : //Ov
                     (address_error_load)       ? 5'h04   : //AdEL
                     (address_error_store)      ? 5'h05   : //AdES
                                                  5'h00   ;

always @(posedge clk)
begin
    if(comming) EX_PC <= DE_PC;
    else ;
end

endmodule
