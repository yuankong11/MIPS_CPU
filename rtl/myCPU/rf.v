module rf #
(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 5,
    parameter NUM_REG    = 32
)
(
    input  clk,
    input  rst_p,
    input  [ADDR_WIDTH - 1 : 0] raddr1,
    input  [ADDR_WIDTH - 1 : 0] raddr2,
    output [DATA_WIDTH - 1 : 0] rdata1,
    output [DATA_WIDTH - 1 : 0] rdata2,
    input  wen,
    input  [ADDR_WIDTH - 1 : 0] waddr,
    input  [DATA_WIDTH - 1 : 0] wdata
);

reg [DATA_WIDTH - 1 : 0] data [NUM_REG - 1 : 0];

assign rdata1 = data[raddr1];
assign rdata2 = data[raddr2];

always @(posedge clk)
begin
    if(rst_p)
        data[0] <= 0;
    else ;

    if( (!rst_p && wen) && waddr )
        data[waddr] <= wdata;
    else ;
end

endmodule
