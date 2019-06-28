`define CP0_BADVADDR 8
`define CP0_COUNT    9
`define CP0_COMPARE  11
`define CP0_STATUS   12
`define CP0_CAUSE    13
`define CP0_EPC      14

module exception(
    input clk,
    input rst_p,

    input [5 : 0] hw_int,

    input MA_leaving,
    input [6 :  2] MA_exccode,
    input MA_eret,
    input [31 : 0] MA_PC,
    input [31 : 0] MA_alu_res,

    output exception,
    output [31 : 0] exception_handler_entry,
    output [31 : 0] epc_out,

    input in_delay_slot,
    input address_error_IF,

    input  [4 :  0] cp0_raddr,
    output [31 : 0] cp0_rdata,

    input cp0_wen,
    input [4 :  0] cp0_waddr,
    input [31 : 0] cp0_wdata
);

//-----CP0_REGS-----
reg [31 : 0] badvaddr;
reg [31 : 0] count;
reg [31 : 0] compare;
reg [31 : 0] epc;

wire [22 : 22] status_bev = 1'b1;
reg  [15 :  8] status_im;
reg  [ 1 :  1] status_exl;
reg  [ 0 :  0] status_ie;

wire [31 : 0] status = {9'd0, status_bev, 6'd0, status_im, 6'd0, status_exl, status_ie};

reg [31 : 31] cause_bd;
reg [30 : 30] cause_ti;
reg [15 :  8] cause_ip;
reg [ 6 :  2] cause_exccode;

wire [31 : 0] cause = {cause_bd, cause_ti, 14'd0, cause_ip, 1'd0, cause_exccode, 2'd0};
//-----CP0_REGS-----

assign epc_out = epc;

wire int_taken = !status_exl && status_ie &&
                 ( ({hw_int[5] | cause_ti, hw_int[4:0], cause_ip[9:8]} & status_im) != 8'd0 );
assign exception = MA_leaving && (int_taken || (MA_exccode != 5'd0));

assign exception_handler_entry = 32'hbfc0_0380;

assign cp0_rdata = ( {32{( cp0_raddr == `CP0_BADVADDR )}} & badvaddr ) |
                   ( {32{( cp0_raddr == `CP0_COUNT    )}} & count    ) |
                   ( {32{( cp0_raddr == `CP0_COMPARE  )}} & compare  ) |
                   ( {32{( cp0_raddr == `CP0_STATUS   )}} & status   ) |
                   ( {32{( cp0_raddr == `CP0_CAUSE    )}} & cause    ) |
                   ( {32{( cp0_raddr == `CP0_EPC      )}} & epc      ) ;

//todo : if-else
always @(posedge clk)
begin
    if(rst_p)
    begin
        status_im  <= 8'd0;
        status_exl <= 1'd0;
        status_ie  <= 1'd0;
        cause_bd   <= 1'd0;
        cause_ip   <= 8'd0;
    end
    else if(exception)
    begin
        cause_bd        <= in_delay_slot;
        cause_exccode   <= int_taken ? 5'd0 : MA_exccode;
        status_exl      <= 1'd1;
        epc             <= in_delay_slot ? MA_PC - 32'd4 : MA_PC;
        cause_ip[15:10] <= {hw_int[5] | cause_ti, hw_int[4:0]};
        if(MA_exccode == 5'h04 || MA_exccode == 5'h05)
            badvaddr <= address_error_IF ? MA_PC : MA_alu_res;
        else ;
    end
    else if(MA_eret && MA_leaving)
    begin
        status_exl <= 1'b0;
    end
    else if(cp0_wen && MA_leaving)
    begin
        if(cp0_waddr == `CP0_COMPARE)
            compare <= cp0_wdata;
        else if(cp0_waddr == `CP0_STATUS)
        begin
            status_im  <= cp0_wdata[15:8];
            status_exl <= cp0_wdata[1];
            status_ie  <= cp0_wdata[0];
        end
        else if(cp0_waddr == `CP0_CAUSE)
            cause_ip[9:8] <= cp0_wdata[9:8];
        else if(cp0_waddr == `CP0_EPC)
            epc <= cp0_wdata;
        else ;
    end
    else ;

    if(rst_p)
        cause_ti <= 1'd0;
    else if(cp0_wen && MA_leaving && cp0_waddr == `CP0_COMPARE)
        cause_ti <= 1'd0;
    else if(count == compare)
        cause_ti <= 1'd1;
    else ;
end

reg count_add_flag;

always @(posedge clk)
begin
    if(rst_p)
        count_add_flag <= 1'd0;
    else if(cp0_wen && MA_leaving && cp0_waddr == `CP0_COUNT)
        count_add_flag <= 1'd0;
    else
        count_add_flag <= !count_add_flag;
end

always @(posedge clk)
begin
    if(cp0_wen && MA_leaving && cp0_waddr == `CP0_COUNT)
        count <= cp0_wdata;
    else
        count <= count + {31'd0, count_add_flag};
end

endmodule
