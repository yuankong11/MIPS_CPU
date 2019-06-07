module mul_div(
    input clk,
    input rst_p,

    input [31 : 0] A,
    input [31 : 0] B,

    input  [2 : 0] mul_div,
    output done,

    output [63 : 0] res
);

wire [63 : 0] mul_res;
wire [31 : 0] q_res;
wire [31 : 0] r_res;
wire mul_doing;
wire div_doing;

reg [1 : 0] mul_div_save;
always @(posedge clk)
begin
    if(done) mul_div_save <= mul_div[1:0];
    else ;
end

assign res = mul_div_save[1] ? mul_res : {r_res, q_res};
assign done = !mul_doing && !div_doing;

mul_32 mul_32(
    .clk   (clk),
    .rst_p (rst_p),

    .A (A),
    .B (B),
    .signed_mul (mul_div[2]),

    .start (mul_div[1]),
    .doing (mul_doing),

    .S (mul_res)
);

div_32 div_32(
    .clk   (clk),
    .rst_p (rst_p),

    .A (A),
    .B (B),
    .signed_div (mul_div[2]),

    .start (mul_div[0]),
    .doing (div_doing),

    .Q (q_res),
    .R (r_res)
);

/*
wire [63 : 0] mul_res;
wire [79 : 0] div_res;
wire [31 : 0] q_res = div_res[71:40];
wire [31 : 0] r_res = div_res[31:0];

wire [32 : 0] out_A = {mul_div[2] ? A[31] : 1'b0, A};
wire [32 : 0] out_B = {mul_div[2] ? B[31] : 1'b0, B};

reg [32 : 0] out_A_save;
reg [32 : 0] out_B_save;

reg [1 : 0] mul_div_save;
always @(posedge clk)
begin
    if(done)
    begin
        mul_div_save <= mul_div[1:0];
        out_A_save <= out_A;
        out_B_save <= out_B;
    end
    else ;
end

assign res = mul_div_save[1] ? mul_res : {r_res, q_res};

wire mul_doing = 1'b0; //delaying res receiving leads to unnecessary to wait
                       //waiting hear leading to combinatorial loop

wire out_valid;
wire in_ready;
wire in_valid;

reg [1 : 0] div_state;

always @(posedge clk)
begin
    if(rst_p) div_state <= 2'd0;
    else if(div_state == 2'd0 && mul_div[0]) div_state <= 2'd1;
    else if(div_state == 2'd1 && in_ready)   div_state <= 2'd2;
    else if(div_state == 2'd2 && in_valid)   div_state <= 2'd0;
    else ;
end

wire in_ready_1;
wire in_ready_2;
assign in_ready  = in_ready_1 && in_ready_2;
assign out_valid = (mul_div[0] && (div_state == 2'd0)) || (div_state == 2'd1);

wire div_doing = (div_state != 2'd0); //delaying res receiving leads to unnecessary to wait in first cycle
                                      //waiting hear leading to combinatorial loop

assign done = !mul_doing && !div_doing;

mult_gen_0 mul_32(
    .CLK (clk),
    .A   (out_A),
    .B   (out_B),
    .P   (mul_res)
);

div_gen_0 div_32(
    .aclk (clk),

    .s_axis_dividend_tvalid (out_valid),
    .s_axis_dividend_tready (in_ready_2),
    .s_axis_dividend_tdata  (div_doing ? out_A_save : out_A),

    .s_axis_divisor_tvalid  (out_valid),
    .s_axis_divisor_tready  (in_ready_1),
    .s_axis_divisor_tdata   (div_doing ? out_B_save : out_B),

    .m_axis_dout_tvalid (in_valid),
    .m_axis_dout_tdata  (div_res)
);
*/

endmodule

module mul_32(
    input clk,
    input rst_p,

    input [31 : 0] A,
    input [31 : 0] B,
    input signed_mul,

    input  start,
    output doing,

    output [63 : 0] S
);

assign doing = 1'b0; //delaying res receiving leads to unnecessary to wait when start
                     //waiting hear leading to combinatorial loop

wire [63 : 0] A_extended = { {32{signed_mul?A[31]:1'b0}}, A};
wire [63 : 0] B_extended = { {32{signed_mul?B[31]:1'b0}}, B};

reg  [63 : 0] add_num[16 : 0];
wire [34 : 0] booth_flag = {{2{B_extended[32]}}, B, 1'd0};
reg  [16 : 0] cin_0;

genvar i;

generate
    for(i = 0; i < 17; i = i + 1)
    begin: generate_add_num
        always @(posedge clk)
        begin
            add_num[i] <= ( {64{(booth_flag[2*i+2 : 2*i] == 3'b000)}} & 64'd0                   ) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b001)}} &  A_extended << 2*i      ) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b010)}} &  A_extended << 2*i      ) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b011)}} &  (A_extended << 1 + 2*i)) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b100)}} & ~(A_extended << 1 + 2*i)) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b101)}} & ~(A_extended << 2*i)    ) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b110)}} & ~(A_extended << 2*i)    ) |
                          ( {64{(booth_flag[2*i+2 : 2*i] == 3'b111)}} &  64'd0                  ) ;
            cin_0[i] <= (booth_flag[2*i+2 : 2*i] == 3'b100) |
                        (booth_flag[2*i+2 : 2*i] == 3'b101) |
                        (booth_flag[2*i+2 : 2*i] == 3'b110) ;
        end
    end
endgenerate

wire [16 : 0] root[63 : 0];

generate
    for(i = 0; i < 64; i = i + 1)
    begin: generate_root
    //todo: for j
        assign root[i] = {add_num[16][i], add_num[15][i], add_num[14][i], add_num[13][i],
                          add_num[12][i], add_num[11][i], add_num[10][i], add_num[ 9][i],
                          add_num[ 8][i], add_num[ 7][i], add_num[ 6][i], add_num[ 5][i],
                          add_num[ 4][i], add_num[ 3][i], add_num[ 2][i], add_num[ 1][i],
                          add_num[ 0][i]};
    end
endgenerate

wire [14 : 0] cin[63 : 0];
assign cin[0] = cin_0[14 : 0];
wire [63 : 0] num1;
wire [63 : 0] num2;

generate
    for(i = 0; i < 64; i = i + 1)
    begin: connect_Wallace_tree
        if(i < 63) Wallace_tree Wallace_tree(root[i], cin[i], cin[i+1], num1[i], num2[i+1]);
        else       Wallace_tree Wallace_tree(root[i], cin[i],         , num1[i],          );
    end
endgenerate

assign num2[0] = cin_0[15];
assign S = num1 + num2 + cin_0[16];

endmodule

module Wallace_tree(
    //todo: 16 roots
    //1 bit, 17 roots, 15 cin & cout
    input [16 : 0] root,
    input [14 : 0] cin,

    output [14 : 0] cout,
    output S,
    output C

);

wire [16 : 0] level_0 = root;
wire [11 : 0] level_1;
wire [ 8 : 0] level_2;
wire [ 5 : 0] level_3;
wire [ 2 : 0] level_4;
wire [ 2 : 0] level_5;

CSA #(.WIDTH(5)) CSA_0(level_0[4:0], level_0[9:5], level_0[14:10], level_1[4:0], cout[4:0]);
assign level_1[6:5] = level_0[16:15];
assign level_1[11:7] = cin[4:0];

CSA #(.WIDTH(4)) CSA_1(level_1[3:0], level_1[7:4], level_1[11:8], level_2[3:0], cout[8:5]);
assign level_2[7:4] = cin[8:5];
assign level_2[8] = 1'b0;

CSA #(.WIDTH(3)) CSA_2(level_2[2:0], level_2[5:3], level_2[8:6], level_3[2:0], cout[11:9]);
assign level_3[5:3] = cin[11:9];

CSA #(.WIDTH(2)) CSA_3(level_3[1:0], level_3[3:2], level_3[5:4], level_4[1:0], cout[13:12]);
assign level_4[2] = cin[12];

CSA #(.WIDTH(1)) CSA_4(level_4[0], level_4[1], level_4[2], level_5[0], cout[14]);
assign level_5[2:1] = cin[14:13];

CSA #(.WIDTH(1)) CSA_5(level_5[0], level_5[1], level_5[2], S, C);

endmodule

module CSA #
(
    parameter WIDTH = 1
)
(
    input [WIDTH - 1 : 0] A,
    input [WIDTH - 1 : 0] B,
    input [WIDTH - 1 : 0] C,

    output [WIDTH - 1 : 0] D,
    output [WIDTH - 1 : 0] E
);

assign D = A ^ B ^ C;
assign E = ((A & B) | (B & C) | (C & A));

endmodule

module div_32(
    input clk,
    input rst_p,

    input [31 : 0] A,
    input [31 : 0] B,
    input signed_div,

    input  start,
    output doing,

    output [31 : 0] Q,
    output [31 : 0] R
);

reg [4 : 0] count;
wire running = (count != 5'd0); //31 cycles after start

assign doing = running; //delaying res receiving leads to unnecessary to wait when start
                        //waiting hear leading to combinatorial loop

always @(posedge clk)
begin
    if(rst_p) count <= 5'd0;
    else if(!running && start) count <= 5'd31;
    else if(running) count <= count - 5'd1;
    else ;
end

wire A_signal = A[31];
wire B_signal = B[31];
wire Q_signal = (A_signal ^ B_signal) && signed_div;
wire R_siganl = A_signal && signed_div;

wire [63 : 0] A_extended = {32'b0, (signed_div && A_signal) ? ({1'b0, (~A[30:0])} + 32'd1) : A};
wire [32 : 0] B_extended = { 1'b0, (signed_div && B_signal) ? ({1'b0, (~B[30:0])} + 32'd1) : B};

reg Q_signal_save;
reg R_signal_save;

reg [63 : 0] A_extended_save;
reg [32 : 0] B_extended_save;

always @(posedge clk)
begin
    if(!running && start)
    begin
        Q_signal_save   <= Q_signal;
        R_signal_save   <= R_siganl;
        B_extended_save <= B_extended;
    end
    else ;
end

wire [32 : 0] sub_res = (running ? A_extended_save[63:31] : A_extended[63:31]) - (running ? B_extended_save : B_extended);
wire [32 : 0] restore = running ? A_extended_save[63:31] : A_extended[63:31];

wire less = sub_res[32];
reg  [31 : 0] Q_temp;

always @(posedge clk)
begin
    if(start || running)
    begin
        A_extended_save[63:0] <= {(less ? restore[31:0] : sub_res[31:0]),
                                  running ? A_extended_save[30:0] : A_extended[30:0], 1'b0};
        Q_temp[0] <= !less;
        Q_temp[31:1] <= Q_temp[30:0];
    end
    else ;
end

assign Q = Q_signal_save ? {1'b1, ~Q_temp[30 : 0]} + 32'd1 : Q_temp[31 : 0];
assign R = R_signal_save ? {1'b1, ~A_extended_save[62 : 32]} + 32'd1 : A_extended_save[63 : 32];

endmodule
