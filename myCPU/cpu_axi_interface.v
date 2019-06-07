module cpu_axi_interface #
(
    parameter NUM_WRITE_BUFFER = 4
)
(
    input clk,
	input rst_p,

	//inst sram_like
	input  inst_req,
    input  [31 : 0] inst_addr,
    output [31 : 0] inst_rdata,
    output inst_addr_ok,
    output inst_data_ok,
    output reg [31 : 0] inst_addr_buf,

	//data sram_like
	input  data_req,
    input  data_wr,
    input  [31 : 0] data_addr,
    input  [ 3 : 0] data_wstrb,
    input  [31 : 0] data_wdata,
    output [31 : 0] data_rdata,
    output data_read_ok,
    output data_write_full,

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

`define READ_STATE_WIDTH     2
`define READ_STATE_FREE      2'd0
`define READ_STATE_STALL     2'd1
`define READ_STATE_SEND_ADDR 2'd2
`define READ_STATE_WAIT_DATA 2'd3

`define WRITE_STATE_WIDTH     3
`define WRITE_STATE_FREE      3'd0
`define WRITE_STATE_SEND      3'd1 //addr & data
`define WRITE_STATE_SEND_ADDR 3'd2 //data sended
`define WRITE_STATE_SEND_DATA 3'd3 //addr sended
`define WRITE_STATE_WAIT_RESP 3'd4

//----------inst----------

`define INST_READ_ID 4'd0

reg [`READ_STATE_WIDTH - 1 : 0] inst_read_state;

wire inst_read_free      = (inst_read_state == `READ_STATE_FREE);
wire inst_read_send_addr = (inst_read_state == `READ_STATE_SEND_ADDR);
wire inst_read_wait_data = (inst_read_state == `READ_STATE_WAIT_DATA);

wire inst_read_id_ar = (arid == `INST_READ_ID);
wire inst_read_id_r  = ( rid == `INST_READ_ID);

always @(posedge clk)
begin
    if(rst_p) inst_read_state <= `READ_STATE_FREE;
    else
    begin
        case(inst_read_state)
            `READ_STATE_FREE:
                if(inst_req)
                    inst_read_state <= `READ_STATE_SEND_ADDR;
                else ;
            `READ_STATE_SEND_ADDR:
                if(inst_read_id_ar && arready)
                    inst_read_state <= `READ_STATE_WAIT_DATA;
                else ;
            `READ_STATE_WAIT_DATA:
                if(inst_read_id_r && rvalid )
                    inst_read_state <= `READ_STATE_FREE;
                else ;
            default: inst_read_state <= `READ_STATE_FREE;
        endcase
    end
end

assign inst_addr_ok = inst_read_free && inst_req;
assign inst_data_ok = inst_read_wait_data && inst_read_id_r && rvalid;
assign inst_rdata   = rdata;

always @(posedge clk)
begin
    if(inst_read_free && inst_req)
        inst_addr_buf  <= {3'd0, inst_addr[28:0]};
    else ;
end

//----------inst----------

`define DATA_READ_ID  4'd1

reg [`READ_STATE_WIDTH - 1 : 0] data_read_state;
reg [31 : 0] data_read_addr_buf;

wire data_read_free      = (data_read_state == `READ_STATE_FREE);
wire data_read_stall     = (data_read_state == `READ_STATE_STALL);
wire data_read_send_addr = (data_read_state == `READ_STATE_SEND_ADDR);
wire data_read_wait_data = (data_read_state == `READ_STATE_WAIT_DATA);

wire data_read_id_ar = (arid == `DATA_READ_ID);
wire data_read_id_r  = ( rid == `DATA_READ_ID);

wire data_read_last_cycle = data_read_wait_data && data_read_id_r && rvalid;

genvar i;

reg [`WRITE_STATE_WIDTH - 1 : 0] data_write_state[NUM_WRITE_BUFFER - 1 : 0];
reg [31 : 0] data_waddr_buf[NUM_WRITE_BUFFER - 1 : 0];
reg [ 3 : 0] data_wstrb_buf[NUM_WRITE_BUFFER - 1 : 0];
reg [31 : 0] data_wdata_buf[NUM_WRITE_BUFFER - 1 : 0];

wire [NUM_WRITE_BUFFER - 1 : 0] data_write_free;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_send;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_send_addr;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_send_data;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_wait_resp;

wire [NUM_WRITE_BUFFER - 1 : 0] data_write_id_aw;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_id_w;
wire [NUM_WRITE_BUFFER - 1 : 0] data_write_id_b;

wire [NUM_WRITE_BUFFER - 1 : 0] acceptable;

wire [NUM_WRITE_BUFFER - 1 : 0] clash;
wire [1 : 0] clash_e;
reg  [1 : 0] clash_index;

reg  [NUM_WRITE_BUFFER - 1 : 0] data_write_sending[1 : 0]; //0 for addr, 1 for data
wire [1 : 0] data_write_sending_e[1 : 0];

wire stall = clash && !(data_write_id_b[clash_e] && bvalid);

//----------data_read----------

always @(posedge clk)
begin
    if(rst_p) data_read_state <= `READ_STATE_FREE;
    else
    begin
        case(data_read_state)
            `READ_STATE_FREE:
                if(data_req && !data_wr)
                    data_read_state <= stall ? `READ_STATE_STALL : `READ_STATE_SEND_ADDR;
                else ;
            `READ_STATE_STALL:
                if(data_write_id_b[clash_index] && bvalid)
                    data_read_state <= `READ_STATE_SEND_ADDR;
                else ;
            `READ_STATE_SEND_ADDR:
                if(data_read_id_ar && arready)
                    data_read_state <= `READ_STATE_WAIT_DATA;
                else ;
            `READ_STATE_WAIT_DATA:
                if(data_read_id_r && rvalid )
                begin
                    if(data_req && !data_wr)
                        data_read_state <= stall ? `READ_STATE_STALL : `READ_STATE_SEND_ADDR;
                    else
                        data_read_state <= `READ_STATE_FREE;
                end
                else ;
            default: data_read_state <= `READ_STATE_FREE;
        endcase
    end
end

always @(posedge clk)
begin
    if(data_req && !data_wr && (data_read_free || data_read_last_cycle))
        data_read_addr_buf <= {3'd0, data_addr[28:0]};
    else ;
end

assign data_read_ok = (data_read_wait_data && data_read_id_r && rvalid);
assign data_rdata   = rdata;

//----------data_read----------

//----------data_write----------

generate
    for(i = 0; i < NUM_WRITE_BUFFER; i = i + 1)
    begin: generate_state_and_id
        assign data_write_free[i]      = (data_write_state[i] == `WRITE_STATE_FREE);
        assign data_write_send[i]      = (data_write_state[i] == `WRITE_STATE_SEND);
        assign data_write_send_addr[i] = (data_write_state[i] == `WRITE_STATE_SEND_ADDR);
        assign data_write_send_data[i] = (data_write_state[i] == `WRITE_STATE_SEND_DATA);
        assign data_write_wait_resp[i] = (data_write_state[i] == `WRITE_STATE_WAIT_RESP);

        assign data_write_id_aw[i] = (awid == i);
        assign data_write_id_w[i]  = ( wid == i);
        assign data_write_id_b[i]  = ( bid == i);
    end
endgenerate

generate
    for(i = 0; i < NUM_WRITE_BUFFER; i = i + 1)
    begin: generate_FSM
        assign acceptable[i] = !(data_write_free & {{NUM_WRITE_BUFFER-i{1'b0}}, {i{1'b1}}}) &&
                               !(bvalid && (data_write_id_b & {{NUM_WRITE_BUFFER-i{1'b0}}, {i{1'b1}}}));

        always @(posedge clk)
        begin
            if(rst_p) data_write_state[i] <= `WRITE_STATE_FREE;
            else
            begin
                case(data_write_state[i])
                    `WRITE_STATE_FREE:
                        if(data_req && data_wr && acceptable[i])
                            data_write_state[i] <= `WRITE_STATE_SEND;
                        else ;
                    `WRITE_STATE_SEND:
                        begin
                            case({data_write_id_aw[i] && awready, data_write_id_w[i] && wready})
                                2'b01: data_write_state[i] <= `WRITE_STATE_SEND_ADDR;
                                2'b10: data_write_state[i] <= `WRITE_STATE_SEND_DATA;
                                2'b11: data_write_state[i] <= `WRITE_STATE_WAIT_RESP;
                                default: ;
                            endcase
                        end
                    `WRITE_STATE_SEND_ADDR:
                        if(data_write_id_aw[i] && awready)
                            data_write_state[i] <= `WRITE_STATE_WAIT_RESP;
                        else ;
                    `WRITE_STATE_SEND_DATA:
                        if(data_write_id_w[i] && wready)
                            data_write_state[i] <= `WRITE_STATE_WAIT_RESP;
                        else ;
                    `WRITE_STATE_WAIT_RESP:
                        if(data_write_id_b[i] && bvalid)
                        begin
                            if(data_req && data_wr && acceptable[i])
                                data_write_state[i] <= `WRITE_STATE_SEND;
                            else
                                data_write_state[i] <= `WRITE_STATE_FREE;
                        end
                        else ;
                    default: data_write_state[i] <= `WRITE_STATE_FREE;
                endcase
            end
        end
    end
endgenerate

generate
    for(i = 0; i < NUM_WRITE_BUFFER; i = i + 1)
    begin: generate_buffer
        always @(posedge clk)
        begin
            if(data_req && data_wr && acceptable[i])
            begin
                data_waddr_buf[i] <= {3'd0, data_addr[28:0]};
                data_wstrb_buf[i] <= data_wstrb;
                data_wdata_buf[i] <= data_wdata;
            end
            else ;
        end
    end
endgenerate

generate
    for(i = 0; i < NUM_WRITE_BUFFER; i = i + 1)
    begin: generate_clash
        assign clash[i] = !data_write_free[i] &&
                          (data_read_free || data_read_last_cycle) &&
                          data_req && !data_wr &&
                          (data_waddr_buf[i][31:2] == data_addr[31:2]);
    end
endgenerate

encoder_4_2 encoder_4_2_0(.in(clash), .out(clash_e));

always @(posedge clk)
begin
    if(data_req && !data_wr && clash)
        clash_index <= clash_e;
    else ;
end

//----------data_write----------

reg inst_sending;
always @(posedge clk)
begin
    if(rst_p) inst_sending <= 1'd0;
    else if(inst_read_id_ar && arready) inst_sending <= 1'd0;
    else if(inst_read_id_ar && inst_read_send_addr) inst_sending <= 1'd1;
    else ;
end

assign arid    = (!inst_sending && data_read_send_addr) ? `DATA_READ_ID : `INST_READ_ID;
assign araddr  = (!inst_sending && data_read_send_addr) ? data_read_addr_buf : inst_addr_buf;
assign arlen   = 8'd0;
assign arsize  = 3'd4;
assign arburst = 2'b01;
assign arlock  = 2'd0;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = (data_read_send_addr || inst_read_send_addr);

assign rready = data_read_wait_data || inst_read_wait_data;

generate
    for(i = 0; i < NUM_WRITE_BUFFER; i = i + 1)
    begin: generate_data_write_sending
        always @(posedge clk)
        begin
            if(rst_p)
                data_write_sending[0][i] <= 1'b0;
            else if(data_write_id_aw[i] && awready)
                data_write_sending[0][i] <= 1'd0;
            else if(data_write_id_aw[i] && (data_write_send_addr[i] || data_write_send[i]))
                data_write_sending[0][i] <= 1'd1;
            else ;
        end

        always @(posedge clk)
        begin
            if(rst_p)
                data_write_sending[1][i] <= 1'b0;
            else if(data_write_id_w[i] && wready)
                data_write_sending[1][i] <= 1'd0;
            else if(data_write_id_w[i] && (data_write_send_data[i] || data_write_send[i]))
                data_write_sending[1][i] <= 1'd1;
            else ;
        end
    end
endgenerate

encoder_4_2 encoder_4_2_1(.in(data_write_sending[0]), .out(data_write_sending_e[0]));
encoder_4_2 encoder_4_2_2(.in(data_write_sending[1]), .out(data_write_sending_e[1]));

assign data_write_full = (data_write_free == {NUM_WRITE_BUFFER{1'b0}}) && !bvalid;

assign awid = data_write_sending[0] ? data_write_sending_e[0] :
              (data_write_send[0] || data_write_send_addr[0]) ? 4'd0 :
              (data_write_send[1] || data_write_send_addr[1]) ? 4'd1 :
              (data_write_send[2] || data_write_send_addr[2]) ? 4'd2 :
                                                                4'd3 ;
assign awaddr = data_write_sending[0] ? data_waddr_buf[data_write_sending_e[0]] :
                (data_write_send[0] || data_write_send_addr[0]) ? data_waddr_buf[0] :
                (data_write_send[1] || data_write_send_addr[1]) ? data_waddr_buf[1] :
                (data_write_send[2] || data_write_send_addr[2]) ? data_waddr_buf[2] :
                                                                  data_waddr_buf[3] ;
assign awlen   = 8'd0;
assign awsize  = 3'd4; //todo
assign awburst = 2'b01;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = (data_write_send != {NUM_WRITE_BUFFER{1'd0}}) ||
                 (data_write_send_addr != {NUM_WRITE_BUFFER{1'd0}});

assign wid = data_write_sending[1] ? data_write_sending_e[1] :
             (data_write_send[0] || data_write_send_data[0]) ? 4'd0 :
             (data_write_send[1] || data_write_send_data[1]) ? 4'd1 :
             (data_write_send[2] || data_write_send_data[2]) ? 4'd2 :
                                                               4'd3 ;
assign wdata = data_write_sending[1] ? data_wdata_buf[data_write_sending_e[1]] :
               (data_write_send[0] || data_write_send_data[0]) ? data_wdata_buf[0] :
               (data_write_send[1] || data_write_send_data[1]) ? data_wdata_buf[1] :
               (data_write_send[2] || data_write_send_data[2]) ? data_wdata_buf[2] :
                                                                 data_wdata_buf[3] ;
assign wstrb = data_write_sending[1] ? data_wstrb_buf[data_write_sending_e[1]] :
               (data_write_send[0] || data_write_send_data[0]) ? data_wstrb_buf[0] :
               (data_write_send[1] || data_write_send_data[1]) ? data_wstrb_buf[1] :
               (data_write_send[2] || data_write_send_data[2]) ? data_wstrb_buf[2] :
                                                                 data_wstrb_buf[3] ;
assign wlast  = 1'd1;
assign wvalid = (data_write_send != {NUM_WRITE_BUFFER{1'd0}}) ||
                (data_write_send_data != {NUM_WRITE_BUFFER{1'd0}});

assign bready = (data_write_wait_resp != {NUM_WRITE_BUFFER{1'd0}});

endmodule

module encoder_8_3(
    input  [7 : 0] in,
    output [2 : 0] out
);

assign out = (3'd0 & {3{in == 8'h01}}) |
             (3'd1 & {3{in == 8'h02}}) |
             (3'd2 & {3{in == 8'h04}}) |
             (3'd3 & {3{in == 8'h08}}) |
             (3'd4 & {3{in == 8'h10}}) |
             (3'd5 & {3{in == 8'h20}}) |
             (3'd6 & {3{in == 8'h40}}) |
             (3'd7 & {3{in == 8'h80}}) ;

endmodule

module encoder_4_2(
    input  [3 : 0] in,
    output [1 : 0] out
);

assign out = (3'd0 & {3{in == 8'h01}}) |
             (3'd1 & {3{in == 8'h02}}) |
             (3'd2 & {3{in == 8'h04}}) |
             (3'd3 & {3{in == 8'h08}}) ;

endmodule
