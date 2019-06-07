`define OP_NUM 11

`define OP_ADD  11'b00000000001
`define OP_SUB  11'b00000000010
`define OP_AND  11'b00000000100
`define OP_OR   11'b00000001000
`define OP_XOR  11'b00000010000
`define OP_NOR  11'b00000100000
`define OP_SLTS 11'b00001000000
`define OP_SLTU 11'b00010000000
//for operations below, the 1-st operand of shift operation is B, A is the 2-nd
`define OP_SLL  11'b00100000000
`define OP_SRL  11'b01000000000
`define OP_SRA  11'b10000000000
