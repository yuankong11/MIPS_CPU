module cache(
    input clk,
    input rst_p,

    input  inst_req,
    input  [31 : 0] inst_addr,
    output [31 : 0] inst_rdata,
    output inst_addr_ok,
    output inst_data_ok,

    input  data_req,
    input  data_wr,
    input  [31 : 0] data_addr,
    input  [ 2 : 0] data_size,
    input  [ 3 : 0] data_wstrb,
    input  [31 : 0] data_wdata,
    output [31 : 0] data_rdata,
    output data_write_ok,
    output data_data_ok,
    output data_busy,

    //axi
	//ar
	output [ 3 : 0] arid,
    output [31 : 0] araddr,
    output [ 7 : 0] arlen,
    output [ 2 : 0] arsize,
    output [ 1 : 0] arburst,
    output [ 1 : 0] arlock,
    output [ 3 : 0] arcache,
    output [ 2 : 0] arprot,
    output arvalid,
    input  arready,

	//r
	input  [ 3 : 0] rid,
    input  [31 : 0] rdata,
    input  [ 1 : 0] rresp,
    input  rlast,
    input  rvalid,
    output rready,

	//aw
	output [ 3 : 0] awid,
    output [31 : 0] awaddr,
    output [ 7 : 0] awlen,
    output [ 2 : 0] awsize,
    output [ 1 : 0] awburst,
    output [ 1 : 0] awlock,
    output [ 3 : 0] awcache,
    output [ 2 : 0] awprot,
    output awvalid,
    input  awready,

	//w
	output [ 3 : 0] wid,
    output [31 : 0] wdata,
    output [ 3 : 0] wstrb,
    output wlast,
    output wvalid,
    input  wready,

	//b
	input  [3 : 0] bid,
    input  [1 : 0] bresp,
    input  bvalid,
    output bready
);

wire uncacheable_inst = 1'b0; //inst_req && (inst_addr[31:29] & 3'b111) == 3'b101;
wire uncacheable_data = (data_addr[31:29] & 3'b111) == 3'b101;
wire read_req;
wire write_req;

wire [31 : 0] icache_data;
wire icache_valid;
wire [31 : 0] icache_addr;
wire icache_req;
wire [255 : 0] icache_buffer;
wire icache_ok;
wire icache_busy;

icache icache(
    .clk    (clk),
    .resetn (~rst_p),

    .pgOffsetIn    (inst_addr[11:0]),
    .pgOffsetValid (inst_req && !uncacheable_inst),
    .tagIn         (inst_addr[31:12]),
    .tagValid      (inst_req && !uncacheable_inst),

    .dataOut       (icache_data),
    .dataOutReady  (icache_valid),

    .addr2Cache2         (icache_addr),
    .addr2Cache2Valid    (icache_req),
    .data2ICacheBlk1     (icache_buffer[31:0]),
    .data2ICacheBlk2     (icache_buffer[63:32]),
    .data2ICacheBlk3     (icache_buffer[95:64]),
    .data2ICacheBlk4     (icache_buffer[127:96]),
    .data2ICacheBlk5     (icache_buffer[159:128]),
    .data2ICacheBlk6     (icache_buffer[191:160]),
    .data2ICacheBlk7     (icache_buffer[223:192]),
    .data2ICacheBlk8     (icache_buffer[255:224]),
    .dataRequestedReady  (icache_ok),
    .data2ICacheBlkReady (icache_ok),

    .busy (icache_busy)
);

wire [31 : 0] dcache_data;
wire dcache_valid;
wire [31 : 0] dcache_addr;
wire dcache_req;
wire [255 : 0] dcache_buffer;
wire dcache_ok;
wire dcache_wb;
wire dcache_wb_ok;
wire [31 : 0] dcache_wb_addr;
wire [255 : 0] dcache_wb_data;
wire dcache_busy;

dcache dcache(
    .clk    (clk),
    .resetn (~rst_p),

    .pgOffsetIn    (data_addr[11:0]),
    .pgOffsetValid (data_req && !uncacheable_data),
    .tagIn         (data_addr[31:12]),
    .tagValid      (data_req && !uncacheable_data),
    .wrIn          (data_wr),
    .wstrbIn       (data_wstrb),
    .wdataIn       (data_wdata),

    .dataOut       (dcache_data),
    .dataOutReady  (dcache_valid),

    .addr2Cache2         (dcache_addr),
    .addr2Cache2Valid    (dcache_req),
    .data2ICacheBlk1     (dcache_buffer[31:0]),
    .data2ICacheBlk2     (dcache_buffer[63:32]),
    .data2ICacheBlk3     (dcache_buffer[95:64]),
    .data2ICacheBlk4     (dcache_buffer[127:96]),
    .data2ICacheBlk5     (dcache_buffer[159:128]),
    .data2ICacheBlk6     (dcache_buffer[191:160]),
    .data2ICacheBlk7     (dcache_buffer[223:192]),
    .data2ICacheBlk8     (dcache_buffer[255:224]),
    .dataRequestedReady  (dcache_ok),
    .data2ICacheBlkReady (dcache_ok),

    .dataWriteBackValid  (dcache_wb),
    .dataWriteBackAck    (dcache_wb_ok),
    .dataWriteBackAddr   (dcache_wb_addr),
    .dataWriteBack       (dcache_wb_data),

    .busy (dcache_busy)
);

reg [ 3 : 0] read_index;
reg [31 : 0] read_buffer[7 : 0];
reg [ 1 : 0] read_dst;
wire read_free;
wire read_send_addr;
wire read_wait_data;

reg write_dst;
wire write_free;
wire write_send_addr;
wire write_send_data;
wire write_wait_resp;

assign inst_addr_ok = inst_req && !icache_busy;
assign inst_data_ok = icache_valid;
assign inst_rdata   = icache_data;

assign data_write_ok = data_wr && (uncacheable_data ? (bvalid && write_dst == 1'b1) : dcache_valid);
assign data_data_ok  = (dcache_valid || (rvalid && rlast && (read_dst == 2'd1)));
assign data_rdata    = dcache_valid ? dcache_data : rdata;
assign data_busy     = dcache_busy;

assign read_req = icache_req || dcache_req || (data_req && uncacheable_data && !data_wr);
assign write_req = dcache_wb || (data_req && uncacheable_data && data_wr);

`define READ_STATE_WIDTH     2
`define READ_STATE_FREE      2'd0
`define READ_STATE_SEND_ADDR 2'd1
`define READ_STATE_WAIT_DATA 2'd2

reg [`READ_STATE_WIDTH - 1 : 0] read_state;

assign read_free      = (read_state == `READ_STATE_FREE);
assign read_send_addr = (read_state == `READ_STATE_SEND_ADDR);
assign read_wait_data = (read_state == `READ_STATE_WAIT_DATA);

reg [31 : 0] read_addr;
reg [ 7 : 0] read_len;
reg [ 2 : 0] read_size;

always @(posedge clk)
begin
    if(rst_p) read_state <= `READ_STATE_FREE;
    else
    begin
        case(read_state)
            `READ_STATE_FREE:
                if(read_req)
                    read_state <= `READ_STATE_SEND_ADDR;
                else ;
            `READ_STATE_SEND_ADDR:
                if(arready)
                    read_state <= `READ_STATE_WAIT_DATA;
                else ;
            `READ_STATE_WAIT_DATA:
                if(rvalid && rlast)
                    read_state <= `READ_STATE_FREE;
                else ;
            default: read_state <= `READ_STATE_FREE;
        endcase
    end
end

always @(posedge clk)
begin
    if(rst_p) read_index <= 4'd0;
    else if(read_req && read_free) read_index <= 4'd0;
    else if(read_wait_data && rvalid) read_index <= read_index + 4'd1;
    else ;

    if(read_wait_data && rvalid) read_buffer[read_index] <= rdata;

    if(read_req && read_free)
    begin
        read_addr <= dcache_req                   ? dcache_addr :
                     data_req && uncacheable_data ? data_addr   :
                                                    icache_addr ;
        read_len  <= dcache_req                   ? 8'd7 :
                     data_req && uncacheable_data ? 8'd0 :
                                                    8'd7 ;
        read_size <= dcache_req                   ? 3'd2 :
                     data_req && uncacheable_data ? data_size :
                                                    3'd2 ;
        read_dst  <= dcache_req                   ? 2'd0 :
                     data_req && uncacheable_data ? 2'd1 :
                                                    2'd2 ;
    end
end

wire [255 : 0] cache_buffer = {rdata,
                               read_buffer[6],
                               read_buffer[5],
                               read_buffer[4],
                               read_buffer[3],
                               read_buffer[2],
                               read_buffer[1],
                               read_buffer[0]};

assign icache_ok = rvalid && rlast && (read_dst == 2'd2);
assign icache_buffer = cache_buffer;

assign dcache_ok = rvalid && rlast && (read_dst == 2'd0);
assign dcache_buffer = cache_buffer;

assign arid    = 4'd0;
assign araddr  = {3'd0, read_addr[28:0]};
assign arlen   = read_len;
assign arsize  = read_size;
assign arburst = 2'b01;
assign arlock  = 2'd0;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = read_send_addr;

assign rready  = read_wait_data;

`define WRITE_STATE_WIDTH     2
`define WRITE_STATE_FREE      2'd0
`define WRITE_STATE_SEND_ADDR 2'd1
`define WRITE_STATE_SEND_DATA 2'd2
`define WRITE_STATE_WAIT_RESP 2'd3

reg [`WRITE_STATE_WIDTH - 1 : 0] write_state;

assign write_free      = (write_state == `WRITE_STATE_FREE);
assign write_send_addr = (write_state == `WRITE_STATE_SEND_ADDR);
assign write_send_data = (write_state == `WRITE_STATE_SEND_DATA);
assign write_wait_resp = (write_state == `WRITE_STATE_WAIT_RESP);

reg [ 3 : 0] write_index;
reg [31 : 0] write_buffer[7 : 0];

reg [31 : 0] write_addr;
reg [ 7 : 0] write_len;
reg [ 2 : 0] write_size;
reg [ 3 : 0] write_strb;

always @(posedge clk)
begin
    if(rst_p) write_state <= `WRITE_STATE_FREE;
    else
    begin
        case(write_state)
            `WRITE_STATE_FREE:
                if(write_req)
                    write_state <= `WRITE_STATE_SEND_ADDR;
                else ;
            `WRITE_STATE_SEND_ADDR:
                if(awready)
                    write_state <= `WRITE_STATE_SEND_DATA;
                else ;
            `WRITE_STATE_SEND_DATA:
                if(wready && wlast)
                    write_state <= `WRITE_STATE_WAIT_RESP;
                else ;
            `WRITE_STATE_WAIT_RESP:
                if(bvalid)
                    write_state <= `WRITE_STATE_FREE;
                else ;
            default: write_state <= `WRITE_STATE_FREE;
        endcase
    end
end

always @(posedge clk)
begin
    if(rst_p) write_index <= 4'd0;
    else if(write_req && write_free) write_index <= 4'd0;
    else if(write_send_data && wready) write_index <= write_index + 4'd1;
    else ;

    if(write_req && write_free)
    begin
        write_addr      <= data_req && uncacheable_data ? data_addr : dcache_wb_addr;
        write_len       <= data_req && uncacheable_data ? 8'd0 : 8'd7;
        write_size      <= data_req && uncacheable_data ? data_size : 3'd2;
        write_strb      <= data_req && uncacheable_data ? data_wstrb : 4'b1111;
        write_dst       <= data_req && uncacheable_data ? 1'b1 : 1'b0;
        write_buffer[0] <= data_req && uncacheable_data ? data_wdata : dcache_wb_data[31:0];
        write_buffer[1] <= dcache_wb_data[63:32];
        write_buffer[2] <= dcache_wb_data[95:64];
        write_buffer[3] <= dcache_wb_data[127:96];
        write_buffer[4] <= dcache_wb_data[159:128];
        write_buffer[5] <= dcache_wb_data[191:160];
        write_buffer[6] <= dcache_wb_data[223:192];
        write_buffer[7] <= dcache_wb_data[255:224];
    end
end

assign dcache_wb_ok = bvalid && (write_dst == 1'b0);

assign awid    = 4'd0;
assign awaddr  = {3'd0, write_addr[28:0]};
assign awlen   = write_len;
assign awsize  = write_size;
assign awburst = 2'b01;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = write_send_addr;

assign wid    = 4'd0;
assign wdata  = write_buffer[write_index];
assign wstrb  = write_strb;
assign wlast  = (write_index == write_len);
assign wvalid = write_send_data;

assign bready = write_wait_resp;

endmodule
