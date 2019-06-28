`include "alu_op.h"

module alu #
(
    parameter DATA_WIDTH = 32
)
(
    input [DATA_WIDTH - 1 : 0] A,
    input [DATA_WIDTH - 1 : 0] B,
    input [`OP_NUM - 1 : 0] operation,
    output zero,
    output overflow,
    output [DATA_WIDTH - 1 : 0] result
);

wire op_add  = operation[0];
wire op_sub  = operation[1];
wire op_and  = operation[2];
wire op_or   = operation[3];
wire op_xor  = operation[4];
wire op_nor  = operation[5];
wire op_slts = operation[6];
wire op_sltu = operation[7];
wire op_sll  = operation[8];
wire op_srl  = operation[9];
wire op_sra  = operation[10];

wire [DATA_WIDTH - 1 : 0] and_result = A & B;
wire [DATA_WIDTH - 1 : 0] or_result  = A | B;
wire [DATA_WIDTH - 1 : 0] xor_result = A ^ B;
wire [DATA_WIDTH - 1 : 0] nor_result = ~or_result;

wire subtract_flag = op_sub | op_slts | op_sltu;
wire [DATA_WIDTH - 1 : 0] adder_A = A;
wire [DATA_WIDTH - 1 : 0] adder_B = subtract_flag ? ~B : B;
wire adder_cin = subtract_flag;
wire adder_cout;
wire [DATA_WIDTH - 1 : 0] adder_result;

assign {adder_cout, adder_result} = adder_A + adder_B + adder_cin;

wire different_signal = A[DATA_WIDTH - 1] ^ B[DATA_WIDTH - 1];
wire slts_result_1 = different_signal ? A[DATA_WIDTH - 1] : adder_result[DATA_WIDTH - 1];
wire [DATA_WIDTH - 1 : 0] slts_result = { {(DATA_WIDTH-1) {1'b0}}, slts_result_1 };
wire sltu_result_1 = subtract_flag ? ~adder_cout : adder_cout;
wire [DATA_WIDTH - 1 : 0] sltu_result = { {(DATA_WIDTH-1) {1'b0}}, sltu_result_1 };

//operation below have inverse operand
wire [DATA_WIDTH - 1 : 0] sll_result = B << A[4 : 0];
wire [DATA_WIDTH - 1 : 0] srl_result = B >> A[4 : 0];
wire [DATA_WIDTH - 1 : 0] sra_result = { {DATA_WIDTH{B[DATA_WIDTH - 1]}}, B } >> A[4:0];

assign result = ( {DATA_WIDTH {op_and }} & and_result   ) |
                ( {DATA_WIDTH {op_or  }} & or_result    ) |
                ( {DATA_WIDTH {op_add }} & adder_result ) |
                ( {DATA_WIDTH {op_sub }} & adder_result ) |
                ( {DATA_WIDTH {op_slts}} & slts_result  ) |
                ( {DATA_WIDTH {op_sltu}} & sltu_result  ) |
                ( {DATA_WIDTH {op_nor }} & nor_result   ) |
                ( {DATA_WIDTH {op_xor }} & xor_result   ) |
                ( {DATA_WIDTH {op_sll }} & sll_result   ) |
                ( {DATA_WIDTH {op_srl }} & srl_result   ) |
                ( {DATA_WIDTH {op_sra }} & sra_result   ) ;

assign zero     = (result == 32'd0);
assign overflow = (different_signal ? op_sub : op_add) &
                  (adder_result[DATA_WIDTH - 1] ^ A[DATA_WIDTH - 1]);

endmodule
