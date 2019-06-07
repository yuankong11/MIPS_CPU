`include "alu_op.h"

module decoder(
    input  [31 : 0] inst,

    output jump_reg,
    output jump_imm,

    output [4 : 0] branch,

    output [2 : 0] rf_waddr_src,
    output [2 : 0] rf_wdata_src,
    output rf_wen,

    output [2 : 0] alu_src1,
    output [2 : 0] alu_src2,
    output [`OP_NUM - 1 : 0] alu_op,
    output [1 : 0] mf_hi_lo,
    output [1 : 0] mt_hi_lo,
    output [2 : 0] mul_div,

    output mem_read,
    output mem_write,
    output [6 : 0] align_load,
    output [4 : 0] align_store,

    output eret,
    output mfc0,
    output mtc0,
    output [1 : 0] trap,

    output overflow_exception,

    output reserved_inst
);

wire [31 : 26] opcode = inst[31 : 26];
wire [25 : 21] rs = inst[25 : 21];
wire [20 : 16] rt = inst[20 : 16];
wire [15 : 11] rd = inst[15 : 11];
wire [10 :  6] shamt = inst[10 : 6];
wire [ 5 :  0] func  = inst[5 :  0];

wire [63 : 0] opcode_d; //decoded
wire [31 : 0] rs_d;
wire [31 : 0] rt_d;
wire [31 : 0] rd_d;
wire [31 : 0] shamt_d;
wire [63 : 0] func_d;

decoder_6_64 decoder_6_64_opcode(.in(opcode), .out(opcode_d));
decoder_5_32 decoder_5_32_rs(.in(rs), .out(rs_d));
decoder_5_32 decoder_5_32_rt(.in(rt), .out(rt_d));
decoder_5_32 decoder_5_32_rd(.in(rd), .out(rd_d));
decoder_5_32 decoder_5_32_shamt(.in(shamt), .out(shamt_d));
decoder_6_64 decoder_6_64_func(.in(func), .out(func_d));

//----------decode----------
wire inst_sll  = opcode_d[6'h0] & func_d[6'h00];
wire inst_srl  = opcode_d[6'h0] & func_d[6'h02];
wire inst_sra  = opcode_d[6'h0] & func_d[6'h03];
wire inst_sllv = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h04];
wire inst_srlv = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h06];
wire inst_srav = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h07];

wire inst_jr   = opcode_d[6'h0] & rt_d[5'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h08];
wire inst_jalr = opcode_d[6'h0] & rt_d[5'h0] & shamt_d[5'h0] & func_d[6'h09];

wire inst_syscall = opcode_d[6'h0] & func_d[6'h0c];
wire inst_break   = opcode_d[6'h0] & func_d[6'h0d];

wire inst_mfhi = opcode_d[6'h0] & rs_d[5'h0] & rt_d[5'h0] & shamt_d[5'h0] & func_d[6'h10];
wire inst_mthi = opcode_d[6'h0] & rt_d[5'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h11];
wire inst_mflo = opcode_d[6'h0] & rs_d[5'h0] & rt_d[5'h0] & shamt_d[5'h0] & func_d[6'h12];
wire inst_mtlo = opcode_d[6'h0] & rt_d[5'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h13];

wire inst_mul  = opcode_d[6'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h18];
wire inst_mulu = opcode_d[6'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h19];
wire inst_div  = opcode_d[6'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h1a];
wire inst_divu = opcode_d[6'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h1b];

wire inst_add  = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h20];
wire inst_addu = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h21];
wire inst_sub  = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h22];
wire inst_subu = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h23];
wire inst_and  = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h24];
wire inst_or   = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h25];
wire inst_xor  = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h26];
wire inst_nor  = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h27];

wire inst_slts = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h2a];
wire inst_sltu = opcode_d[6'h0] & shamt_d[5'h0] & func_d[6'h2b];

wire inst_bltz   = opcode_d[6'h01] & rt_d[5'h00];
wire inst_bgez   = opcode_d[6'h01] & rt_d[5'h01];
wire inst_bltzal = opcode_d[6'h01] & rt_d[5'h10];
wire inst_bgezal = opcode_d[6'h01] & rt_d[5'h11];

wire inst_j   = opcode_d[6'h02];
wire inst_jal = opcode_d[6'h03];

wire inst_beq  = opcode_d[6'h04];
wire inst_bne  = opcode_d[6'h05];
wire inst_blez = opcode_d[6'h06] & rt_d[5'h0];
wire inst_bgtz = opcode_d[6'h07] & rt_d[5'h0];

wire inst_addi  = opcode_d[6'h08];
wire inst_addiu = opcode_d[6'h09];
wire inst_sltis = opcode_d[6'h0a];
wire inst_sltiu = opcode_d[6'h0b];
wire inst_andi  = opcode_d[6'h0c];
wire inst_ori   = opcode_d[6'h0d];
wire inst_xori  = opcode_d[6'h0e];
wire inst_lui   = opcode_d[6'h0f] & rs_d[5'h0];

wire inst_eret = opcode_d[6'h10] & rs_d[5'h10] & rt_d[5'h0] & rd_d[5'h0] & shamt_d[5'h0] & func_d[6'h18];
wire inst_mfc0 = opcode_d[6'h10] & rs_d[5'h00] & shamt_d[5'h0] & (func[5:3] == 3'd0);
wire inst_mtc0 = opcode_d[6'h10] & rs_d[5'h04] & shamt_d[5'h0] & (func[5:3] == 3'd0);

wire inst_lb  = opcode_d[6'h20];
wire inst_lh  = opcode_d[6'h21];
wire inst_lwl = opcode_d[6'h22];
wire inst_lw  = opcode_d[6'h23];
wire inst_lbu = opcode_d[6'h24];
wire inst_lhu = opcode_d[6'h25];
wire inst_lwr = opcode_d[6'h26];

wire inst_sb  = opcode_d[6'h28];
wire inst_sh  = opcode_d[6'h29];
wire inst_swl = opcode_d[6'h2a];
wire inst_sw  = opcode_d[6'h2b];
wire inst_swr = opcode_d[6'h2e];
//----------decode----------

wire inst_load  = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr;
wire inst_store = inst_sw | inst_sb | inst_sh | inst_swl | inst_swr;
assign align_load  = {inst_lw, inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lwl, inst_lwr};
assign align_store = {inst_sw, inst_sb, inst_sh, inst_swl, inst_swr};
assign alu_op = {inst_sra | inst_srav, inst_srl | inst_srlv, inst_sll | inst_sllv | inst_lui,
                 inst_sltu | inst_sltiu, inst_slts | inst_sltis,
                 inst_nor, inst_xor | inst_xori, inst_or | inst_ori, inst_and | inst_andi,
                 inst_sub | inst_subu | inst_beq | inst_bne,
                 inst_add | inst_addu | inst_addi | inst_addiu | inst_load | inst_store};
assign mf_hi_lo = {inst_mfhi, inst_mflo};
assign mt_hi_lo = {inst_mthi, inst_mtlo};
assign mul_div = {inst_mul | inst_div, inst_mul | inst_mulu, inst_div | inst_divu};

assign jump_reg  = inst_jr | inst_jalr;
assign jump_imm  = inst_j  | inst_jal;
assign branch[0] = inst_beq | inst_bne;
assign branch[1] = inst_bgtz;
assign branch[2] = inst_bgez | inst_bgezal;
assign branch[3] = inst_bltz | inst_bltzal;
assign branch[4] = inst_blez;

wire inst_ALI = inst_addi | inst_addiu |
                inst_andi | inst_ori | inst_xori |
                inst_sltis | inst_sltiu | inst_lui;
wire inst_ALR = inst_add | inst_addu | inst_sub | inst_subu | inst_slts | inst_sltu |
                inst_and | inst_or | inst_xor | inst_nor |
                inst_sll | inst_sllv | inst_srl | inst_srlv | inst_sra | inst_srav;

assign rf_waddr_src[0] = inst_ALI | inst_load | inst_mfc0; //rt
assign rf_waddr_src[1] = inst_jalr | inst_ALR | inst_mfhi | inst_mflo; //rd
assign rf_waddr_src[2] = inst_jal | inst_bgezal | inst_bltzal; //31-st

assign rf_wdata_src[0] = inst_ALR | inst_ALI | inst_mfhi | inst_mflo | inst_mfc0;  //alu_out_MA
assign rf_wdata_src[1] = inst_jal | inst_jalr | inst_bgezal | inst_bltzal; //alu_out_EX
assign rf_wdata_src[2] = inst_load; //mem_data

assign rf_wen = inst_jal | inst_jalr | inst_bgezal | inst_bltzal |
                inst_ALR | inst_ALI | inst_load | inst_mfhi | inst_mflo | inst_mfc0;

wire inst_shift_shamt = inst_sll | inst_srl | inst_sra;

assign alu_src1[0] = (inst_ALR & ~inst_shift_shamt) |
                     (inst_ALI & ~inst_lui) |
                     inst_load | inst_store; //rf_A
assign alu_src1[1] = inst_shift_shamt; //{27'd0, inst_shamt}
assign alu_src1[2] = inst_lui; //32'd16

assign alu_src2[0] = inst_ALR; //rf_B
assign alu_src2[1] = inst_sltis | inst_sltiu | inst_addi | inst_addiu |
                     inst_load | inst_store; //inst_imm_I_se
assign alu_src2[2] = inst_andi | inst_ori | inst_xori | inst_lui; //inst_imm_I_ze

assign mem_read  = inst_load;
assign mem_write = inst_store;

assign eret = inst_eret;
assign mfc0 = inst_mfc0;
assign mtc0 = inst_mtc0;
assign trap = {inst_break, inst_syscall};

assign overflow_exception = inst_add | inst_sub | inst_addi;

assign reserved_inst = !(
    inst_sll | inst_srl | inst_sra |
    inst_sllv | inst_srlv | inst_srav |
    inst_jr | inst_jalr |
    inst_syscall | inst_break |
    inst_mfhi | inst_mthi | inst_mflo | inst_mtlo |
    inst_mul | inst_mulu | inst_div | inst_divu |
    inst_add | inst_addu | inst_sub | inst_subu |
    inst_and | inst_or | inst_xor | inst_nor |
    inst_slts | inst_sltu |
    inst_bltz | inst_bgez | inst_bltzal | inst_bgezal |
    inst_j | inst_jal |
    inst_beq | inst_bne | inst_blez | inst_bgtz |
    inst_addi | inst_addiu | inst_sltis | inst_sltiu |
    inst_andi | inst_ori | inst_xori | inst_lui |
    inst_eret | inst_mfc0 | inst_mtc0 |
    inst_load | inst_store
);

endmodule

module decoder_5_32(
    input  [ 4 : 0] in,
    output [31 : 0] out
);

wire [3 : 0] high;
wire [7 : 0] low;

assign high[3] = ( in[4]) & ( in[3]);
assign high[2] = ( in[4]) & (~in[3]);
assign high[1] = (~in[4]) & ( in[3]);
assign high[0] = (~in[4]) & (~in[3]);

assign low[7] = ( in[2]) & ( in[1]) & ( in[0]);
assign low[6] = ( in[2]) & ( in[1]) & (~in[0]);
assign low[5] = ( in[2]) & (~in[1]) & ( in[0]);
assign low[4] = ( in[2]) & (~in[1]) & (~in[0]);
assign low[3] = (~in[2]) & ( in[1]) & ( in[0]);
assign low[2] = (~in[2]) & ( in[1]) & (~in[0]);
assign low[1] = (~in[2]) & (~in[1]) & ( in[0]);
assign low[0] = (~in[2]) & (~in[1]) & (~in[0]);

assign out[31] = high[3] & low[7];
assign out[30] = high[3] & low[6];
assign out[29] = high[3] & low[5];
assign out[28] = high[3] & low[4];
assign out[27] = high[3] & low[3];
assign out[26] = high[3] & low[2];
assign out[25] = high[3] & low[1];
assign out[24] = high[3] & low[0];
assign out[23] = high[2] & low[7];
assign out[22] = high[2] & low[6];
assign out[21] = high[2] & low[5];
assign out[20] = high[2] & low[4];
assign out[19] = high[2] & low[3];
assign out[18] = high[2] & low[2];
assign out[17] = high[2] & low[1];
assign out[16] = high[2] & low[0];
assign out[15] = high[1] & low[7];
assign out[14] = high[1] & low[6];
assign out[13] = high[1] & low[5];
assign out[12] = high[1] & low[4];
assign out[11] = high[1] & low[3];
assign out[10] = high[1] & low[2];
assign out[ 9] = high[1] & low[1];
assign out[ 8] = high[1] & low[0];
assign out[ 7] = high[0] & low[7];
assign out[ 6] = high[0] & low[6];
assign out[ 5] = high[0] & low[5];
assign out[ 4] = high[0] & low[4];
assign out[ 3] = high[0] & low[3];
assign out[ 2] = high[0] & low[2];
assign out[ 1] = high[0] & low[1];
assign out[ 0] = high[0] & low[0];

endmodule

module decoder_6_64(
    input  [ 5 : 0] in,
    output [63 : 0] out
);

wire [7 : 0] high;
wire [7 : 0] low;

assign high[7] = ( in[5]) & ( in[4]) & ( in[3]);
assign high[6] = ( in[5]) & ( in[4]) & (~in[3]);
assign high[5] = ( in[5]) & (~in[4]) & ( in[3]);
assign high[4] = ( in[5]) & (~in[4]) & (~in[3]);
assign high[3] = (~in[5]) & ( in[4]) & ( in[3]);
assign high[2] = (~in[5]) & ( in[4]) & (~in[3]);
assign high[1] = (~in[5]) & (~in[4]) & ( in[3]);
assign high[0] = (~in[5]) & (~in[4]) & (~in[3]);

assign low[7] = ( in[2]) & ( in[1]) & ( in[0]);
assign low[6] = ( in[2]) & ( in[1]) & (~in[0]);
assign low[5] = ( in[2]) & (~in[1]) & ( in[0]);
assign low[4] = ( in[2]) & (~in[1]) & (~in[0]);
assign low[3] = (~in[2]) & ( in[1]) & ( in[0]);
assign low[2] = (~in[2]) & ( in[1]) & (~in[0]);
assign low[1] = (~in[2]) & (~in[1]) & ( in[0]);
assign low[0] = (~in[2]) & (~in[1]) & (~in[0]);

assign out[63] = high[7] & low[7];
assign out[62] = high[7] & low[6];
assign out[61] = high[7] & low[5];
assign out[60] = high[7] & low[4];
assign out[59] = high[7] & low[3];
assign out[58] = high[7] & low[2];
assign out[57] = high[7] & low[1];
assign out[56] = high[7] & low[0];
assign out[55] = high[6] & low[7];
assign out[54] = high[6] & low[6];
assign out[53] = high[6] & low[5];
assign out[52] = high[6] & low[4];
assign out[51] = high[6] & low[3];
assign out[50] = high[6] & low[2];
assign out[49] = high[6] & low[1];
assign out[48] = high[6] & low[0];
assign out[47] = high[5] & low[7];
assign out[46] = high[5] & low[6];
assign out[45] = high[5] & low[5];
assign out[44] = high[5] & low[4];
assign out[43] = high[5] & low[3];
assign out[42] = high[5] & low[2];
assign out[41] = high[5] & low[1];
assign out[40] = high[5] & low[0];
assign out[39] = high[4] & low[7];
assign out[38] = high[4] & low[6];
assign out[37] = high[4] & low[5];
assign out[36] = high[4] & low[4];
assign out[35] = high[4] & low[3];
assign out[34] = high[4] & low[2];
assign out[33] = high[4] & low[1];
assign out[32] = high[4] & low[0];
assign out[31] = high[3] & low[7];
assign out[30] = high[3] & low[6];
assign out[29] = high[3] & low[5];
assign out[28] = high[3] & low[4];
assign out[27] = high[3] & low[3];
assign out[26] = high[3] & low[2];
assign out[25] = high[3] & low[1];
assign out[24] = high[3] & low[0];
assign out[23] = high[2] & low[7];
assign out[22] = high[2] & low[6];
assign out[21] = high[2] & low[5];
assign out[20] = high[2] & low[4];
assign out[19] = high[2] & low[3];
assign out[18] = high[2] & low[2];
assign out[17] = high[2] & low[1];
assign out[16] = high[2] & low[0];
assign out[15] = high[1] & low[7];
assign out[14] = high[1] & low[6];
assign out[13] = high[1] & low[5];
assign out[12] = high[1] & low[4];
assign out[11] = high[1] & low[3];
assign out[10] = high[1] & low[2];
assign out[ 9] = high[1] & low[1];
assign out[ 8] = high[1] & low[0];
assign out[ 7] = high[0] & low[7];
assign out[ 6] = high[0] & low[6];
assign out[ 5] = high[0] & low[5];
assign out[ 4] = high[0] & low[4];
assign out[ 3] = high[0] & low[3];
assign out[ 2] = high[0] & low[2];
assign out[ 1] = high[0] & low[1];
assign out[ 0] = high[0] & low[0];

endmodule
