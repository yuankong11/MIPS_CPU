`include "alu_op.h"

module DE(
    input clk,
    input rst_p,
    input empty,

    //pipeline signals
    input  IF_ready,
    output DE_enable,
    output DE_ready,
    input  EX_enable,

    //interact with IF
    input  [31 : 0] inst_in,
    input  [31 : 0] IF_PC,
    output PC_modified,
    output [31 : 0] PC_modified_data,
    input  [4 : 0] exccode_in,

    //interact with forward
    input  waiting,
    output isbr,
    output [ 4 : 0] rf_raddr1,
    output [ 4 : 0] rf_raddr2,
    input  [31 : 0] rf_rdata1,
    input  [31 : 0] rf_rdata2,
    input  [31 : 0] drf_rdata1,
    input  [31 : 0] drf_rdata2,

    //interact with EX
    output [4 : 0] rf_waddr_out,
    output [2 : 0] rf_wdata_src_out,
    output rf_wen_out,

    output [2 : 0] alu_src1_out,
    output [2 : 0] alu_src2_out,
    output [`OP_NUM - 1 : 0] alu_op_out,
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

    output [15 : 0] imm_16_out,

    output [31 : 0] rf_A_out,
    output [31 : 0] rf_B_out,

    output reg [31 : 0] DE_PC,

    output in_delay_slot_out,
    output address_error_IF_out,
    output overflow_exception_out,
    output [4 : 0] exccode_out
);

reg valid;

wire comming = DE_enable && IF_ready;
wire leaving = EX_enable && DE_ready;

always @(posedge clk)
begin
    if(rst_p || empty) valid <= 1'd0;
    else if(comming) valid <= 1'd1;
    else if(leaving) valid <= 1'd0;
    else ;
end

assign DE_enable = !valid ||  leaving;
assign DE_ready  =  valid && !waiting && ~empty;

reg [31 : 0] IR;

always @(posedge clk)
begin
    if(comming) IR <= inst_in;
    else ;
end

wire [31 :  0] inst = IR;
wire [31 : 26] inst_opcode = inst[31 : 26];
wire [ 5 :  0] inst_func   = inst[ 5 :  0];
wire [25 : 21] inst_rs = inst[25 : 21];
wire [20 : 16] inst_rt = inst[20 : 16];
wire [15 : 11] inst_rd = inst[15 : 11];
wire [15 :  0] inst_imm_16 = inst[15 : 0];
wire [25 :  0] inst_imm_26 = inst[25 : 0];

wire jump_reg_in;
wire jump_imm_in;
wire [4 : 0] branch_in;
wire [2 : 0] rf_waddr_src_in;
wire [2 : 0] rf_wdata_src_in;
wire rf_wen_in;
wire [2 : 0] alu_src1_in;
wire [2 : 0] alu_src2_in;
wire [`OP_NUM - 1 : 0] alu_op_in;
wire [1 : 0] mf_hi_lo_in;
wire [1 : 0] mt_hi_lo_in;
wire [2 : 0] mul_div_in;
wire mem_read_in;
wire mem_write_in;
wire [6 : 0] align_load_in;
wire [4 : 0] align_store_in;
wire eret_in;
wire mfc0_in;
wire mtc0_in;
wire [1 : 0] trap_in;
wire overflow_exception_in;
wire reserved_inst_in;

decoder decoder(
    .inst (inst),

    .jump_reg (jump_reg_in),
    .jump_imm (jump_imm_in),

    .branch (branch_in),

    .rf_waddr_src (rf_waddr_src_in),
    .rf_wdata_src (rf_wdata_src_in),
    .rf_wen       (rf_wen_in),

    .alu_src1 (alu_src1_in),
    .alu_src2 (alu_src2_in),
    .alu_op   (alu_op_in),
    .mf_hi_lo (mf_hi_lo_in),
    .mt_hi_lo (mt_hi_lo_in),
    .mul_div  (mul_div_in),

    .mem_read  (mem_read_in),
    .mem_write (mem_write_in),
    .align_store (align_store_in),
    .align_load  (align_load_in),

    .eret (eret_in),
    .mfc0 (mfc0_in),
    .mtc0 (mtc0_in),
    .trap (trap_in),

    .overflow_exception (overflow_exception_in),

    .reserved_inst (reserved_inst_in)
);

assign rf_raddr1 = inst_rs;
assign rf_raddr2 = inst_rt;

assign rf_waddr_out = ( {5{rf_waddr_src_in[0]}} & inst_rt ) |
                      ( {5{rf_waddr_src_in[1]}} & inst_rd ) |
                      ( {5{rf_waddr_src_in[2]}} & 5'd31   ) ;
assign rf_wdata_src_out = rf_wdata_src_in;
assign rf_wen_out = rf_wen_in;

assign alu_src1_out = alu_src1_in;
assign alu_src2_out = alu_src2_in;
assign alu_op_out   = alu_op_in;
assign mf_hi_lo_out = mf_hi_lo_in;
assign mt_hi_lo_out = mt_hi_lo_in;
assign mul_div_out  = mul_div_in;

assign mem_read_out  = mem_read_in;
assign mem_write_out = mem_write_in;
assign align_load_out  = align_load_in;
assign align_store_out = align_store_in;

assign eret_out = eret_in && leaving; //impact on IF
assign mfc0_out = mfc0_in;
assign mtc0_out = mtc0_in;

assign overflow_exception_out = overflow_exception_in;

assign imm_16_out = inst_imm_16;
assign rf_A_out   = rf_rdata1;
assign rf_B_out   = rf_rdata2;

assign isbr = jump_reg_in || jump_imm_in || |branch_in;

wire rf_equal = (drf_rdata1 == drf_rdata2);
wire rf_rdata1_ez  = (drf_rdata1 == 32'd0);
wire rf_rdata1_gtz = ~drf_rdata1[31] & ~rf_rdata1_ez;
wire rf_rdata1_gez = ~drf_rdata1[31];
wire rf_rdata1_ltz =  drf_rdata1[31];
wire rf_rdata1_lez =  drf_rdata1[31] |  rf_rdata1_ez;
wire branch_taken  = (branch_in[0] & (inst_opcode[26] ^ rf_equal)) |
                     (branch_in[1] & rf_rdata1_gtz) |
                     (branch_in[2] & rf_rdata1_gez) |
                     (branch_in[3] & rf_rdata1_ltz) |
                     (branch_in[4] & rf_rdata1_lez) ;
assign PC_modified = (jump_reg_in || jump_imm_in || branch_taken) && leaving;

wire [31 : 0] DE_PC_inc = DE_PC + 32'd4;
wire [31 : 0] PC_jump_reg = drf_rdata1[31 : 0];
wire [31 : 0] PC_jump_imm = { DE_PC_inc[31 : 28], inst_imm_26, 2'd0 };
wire [31 : 0] PC_branch   = ( DE_PC_inc + { {14{inst_imm_16[15]}}, inst_imm_16, 2'd0 } );
assign PC_modified_data = ( {32{jump_reg_in} } & PC_jump_reg) |
                          ( {32{jump_imm_in} } & PC_jump_imm) |
                          ( {32{branch_taken}} & PC_branch  ) ;

always @(posedge clk)
begin
    if(comming) DE_PC <= IF_PC;
    else ;
end

reg [4 : 0] exccode;

assign address_error_IF_out = (exccode != 5'd0);

reg in_delay_slot;

always @(posedge clk)
begin
    if(rst_p) in_delay_slot <= 1'd0;
    else if(leaving) in_delay_slot <= jump_reg_in || jump_imm_in || (branch_in != 5'd0);
    else ;
end

assign in_delay_slot_out = in_delay_slot;

always @(posedge clk)
begin
    if(comming) exccode <= exccode_in;
    else ;
end

assign exccode_out = (exccode != 5'h00) ? exccode : //AdEL(IF)
                     (reserved_inst_in) ? 5'h0a   : //RI
                     (trap_in[0])       ? 5'h08   : //Sys
                     (trap_in[1])       ? 5'h09   : //Bp
                                          5'h00   ;

endmodule
