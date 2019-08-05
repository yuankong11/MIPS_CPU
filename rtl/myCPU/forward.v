module forward(
    input clk,
    input rst_p,
    input empty,

    input [4 : 0] EX_rf_waddr,
    input [4 : 0] MA_rf_waddr,
    input [4 : 0] WB_rf_waddr,

    input EX_rf_wen,
    input MA_rf_wen,
    input WB_rf_wen,

    input EX_valid,
    input MA_valid,
    input WB_valid,

    input MA_leaving,
    input WB_leaving,

    input EX_mem_read,
    input MA_mem_read,
    input EX_mf,

    input [31 : 0] EX_alu_res,
    input [31 : 0] MA_alu_res,
    input [31 : 0] WB_rf_wdata,

    output [ 4 : 0] rf_raddr1,
    output [ 4 : 0] rf_raddr2,
    input  [31 : 0] rf_rdata1,
    input  [31 : 0] rf_rdata2,

    input  [ 4 : 0] raddr1,
    input  [ 4 : 0] raddr2,
    output [31 : 0] rdata1,
    output [31 : 0] rdata2,

    output waiting,
    input isbr
);

assign rf_raddr1 = raddr1;
assign rf_raddr2 = raddr2;

wire [2 : 0]clash_EX;
wire [2 : 0]clash_MA;
wire [2 : 0]clash_WB;

assign clash_EX[1] = EX_valid && EX_rf_wen && (raddr1 != 5'd0) && (raddr1 == EX_rf_waddr);
assign clash_EX[2] = EX_valid && EX_rf_wen && (raddr2 != 5'd0) && (raddr2 == EX_rf_waddr);
assign clash_EX[0] = clash_EX[1] || clash_EX[2];

assign clash_MA[1] = MA_valid && MA_rf_wen && (raddr1 != 5'd0) && (raddr1 == MA_rf_waddr);
assign clash_MA[2] = MA_valid && MA_rf_wen && (raddr2 != 5'd0) && (raddr2 == MA_rf_waddr);
assign clash_MA[0] = clash_MA[1] || clash_MA[2];

assign clash_WB[1] = WB_valid && WB_rf_wen && (raddr1 != 5'd0) && (raddr1 == WB_rf_waddr);
assign clash_WB[2] = WB_valid && WB_rf_wen && (raddr2 != 5'd0) && (raddr2 == WB_rf_waddr);
assign clash_WB[0] = clash_WB[1] || clash_WB[2];

wire waiting_br      = (clash_EX[0] || clash_MA[0] || clash_WB[0]) && isbr;
wire waiting_EX_load = EX_mem_read && clash_EX[0]; //2 cycles, fetch from WB_wf_wdata
wire waiting_MA_load = MA_mem_read && clash_MA[0]; //1 cycle, fetch from WB_wf_wdata
wire waiting_EX_mf   = EX_mf       && clash_EX[0]; //1 cycle, fetch from MA_alu_res
wire waiting_WB      = !WB_leaving && clash_WB[0];
reg  [1 : 0] wait_cycle; //not clock cycle, but pipeline cycle

always @(posedge clk)
begin
    if(rst_p || empty) wait_cycle <= 2'd0;
    else if(wait_cycle == 2'd0)
        begin
            if(waiting_MA_load && !MA_leaving)
                wait_cycle <= 2'd1;
            else if(waiting_EX_mf && !MA_leaving && MA_valid)
                wait_cycle <= 2'd1;
            else if(waiting_EX_load)
                wait_cycle <= (MA_leaving || !MA_valid) ? 2'd1 : 2'd2;
            else ;
        end
    else wait_cycle <= wait_cycle - {1'b0, MA_leaving};
end

assign waiting = !empty && (waiting_br || waiting_EX_load || waiting_MA_load || waiting_EX_mf || (wait_cycle != 2'd0) || waiting_WB);

assign rdata1 = clash_EX[1] ? EX_alu_res  :
                clash_MA[1] ? MA_alu_res  :
                clash_WB[1] ? WB_rf_wdata :
                              rf_rdata1   ;

assign rdata2 = clash_EX[2] ? EX_alu_res  :
                clash_MA[2] ? MA_alu_res  :
                clash_WB[2] ? WB_rf_wdata :
                              rf_rdata2   ;

endmodule
