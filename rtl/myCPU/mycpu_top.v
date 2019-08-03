`include "alu_op.h"

module mycpu_top(
    input aclk,
    input aresetn,

    input [5 : 0] int,

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
    output bready,

    //debug
    output [31 : 0] debug_wb_pc,
    output [ 3 : 0] debug_wb_rf_wen,
    output [ 4 : 0] debug_wb_rf_wnum,
    output [31 : 0] debug_wb_rf_wdata
);

wire rst_p = ~aresetn;
wire clk   = aclk;

wire interlayer_IF_ready;
wire interlayer_MA_ready;
wire interlayer_WB_ready;
wire IF_enable;
wire IF_ready;
wire DE_enable;
wire DE_ready;
wire EX_enable;
wire EX_ready;
wire MA_enable;
wire MA_ready;
wire WB_enable;

wire [31 : 0] IF_PC, DE_PC, EX_PC, MA_PC;

wire [31 : 0] IF_mem_addr;
wire [31 : 0] IF_mem_rdata;
wire MA_mem_read;
wire MA_mem_write;
wire [ 3 : 0] MA_mem_wstrb;
wire [31 : 0] MA_mem_addr;
wire [ 2 : 0] MA_mem_size;
wire [31 : 0] MA_mem_wdata;
wire [31 : 0] WB_mem_rdata;

wire PC_modified;
wire [31 : 0] PC_modified_data;
wire [31 : 0] IF_inst;

wire [2 : 0] DE_EX_alu_src1;
wire [2 : 0] DE_EX_alu_src2;
wire [`OP_NUM - 1 : 0] DE_EX_alu_op;

wire [1 : 0] DE_EX_mf_hi_lo;
wire [1 : 0] DE_EX_mt_hi_lo;
wire [2 : 0] DE_EX_mul_div;
wire [1 : 0] EX_MA_mf_hi_lo;
wire [1 : 0] EX_MA_mt_hi_lo;
wire [2 : 0] EX_MA_mul_div;

wire DE_EX_mem_read, EX_MA_mem_read, MA_WB_mem_read;
wire DE_EX_mem_write, EX_MA_mem_write;

wire [ 4 : 0] rf_raddr1;
wire [ 4 : 0] rf_raddr2;
wire [31 : 0] rf_rdata1;
wire [31 : 0] rf_rdata2;
wire forward_waiting;
wire [ 4 : 0] forward_raddr1;
wire [ 4 : 0] forward_raddr2;
wire [31 : 0] forward_rdata1;
wire [31 : 0] forward_rdata2;
wire [ 4 : 0] rf_waddr;
wire [31 : 0] rf_wdata;
wire rf_wen;

wire [ 4 : 0] DE_EX_rf_waddr;
wire [ 2 : 0] DE_EX_rf_wdata_src;
wire DE_EX_rf_wen;
wire [ 4 : 0] EX_MA_rf_waddr;
wire [ 2 : 0] EX_MA_rf_wdata_src;
wire EX_MA_rf_wen;
wire [ 4 : 0] MA_WB_rf_waddr;
wire [ 2 : 0] MA_WB_rf_wdata_src;
wire MA_WB_rf_wen;

wire [15 : 0] DE_EX_imm_16;

wire [31 : 0] DE_EX_rf_A, EX_MA_rf_A;
wire [31 : 0] DE_EX_rf_B, EX_MA_rf_B, MA_WB_rf_B;

wire [31 : 0] EX_alu_res;
wire [31 : 0] MA_alu_res;

wire EX_valid, MA_valid, WB_valid;

wire WB_rf_wen;
wire MA_leaving;
wire WB_leaving;

wire mul_div_done;
wire [63 : 0] mul_div_res;

wire [6 : 0] DE_EX_align_load,  EX_MA_align_load,  MA_WB_align_load;
wire [4 : 0] DE_EX_align_store, EX_MA_align_store;

wire [4 : 0] IF_DE_exccode, DE_EX_exccode, EX_MA_exccode, MA_exccode;

wire exception_taken;
wire [31 : 0] exception_handler_entry;

wire empty_exception = exception_taken;

wire [4 : 0] EX_MA_inst_rd;

wire DE_EX_mfc0, EX_MA_mfc0;
wire DE_EX_mtc0, EX_MA_mtc0;
wire DE_EX_eret, EX_MA_eret, MA_eret;

wire [ 4 : 0] MA_cp0_addr;
wire [31 : 0] MA_cp0_rdata;
wire [31 : 0] MA_cp0_wdata;
wire MA_cp0_wen;

wire [31 : 0] epc;

wire DE_EX_in_delay_slot, EX_MA_in_delay_slot, MA_in_delay_slot;
wire DE_EX_address_error_IF, EX_MA_address_error_IF, MA_address_error_IF;
wire overflow_exception;

wire IF_skip;

wire inst_req;
wire [31 : 0] inst_addr;
wire [31 : 0] inst_rdata;
wire inst_addr_ok;
wire inst_data_ok;
wire [31 : 0] inst_addr_done;

wire data_req;
wire data_wr;
wire [31 : 0] data_addr;
wire [ 2 : 0] data_size;
wire [ 3 : 0] data_wstrb;
wire [31 : 0] data_wdata;
wire [31 : 0] data_rdata;
wire data_write_ok;
wire data_data_ok;
wire data_busy;

cache cache(
    .clk   (clk),
	.rst_p (rst_p),

	//inst sram_like
    .inst_req      (inst_req),
    .inst_addr     (inst_addr),
    .inst_rdata    (inst_rdata),
    .inst_addr_ok  (inst_addr_ok),
    .inst_data_ok  (inst_data_ok),

	//data sram_like
	.data_req        (data_req),
    .data_wr         (data_wr),
    .data_addr       (data_addr),
    .data_size       (data_size),
    .data_wstrb      (data_wstrb),
    .data_wdata      (data_wdata),
    .data_rdata      (data_rdata),
    .data_write_ok   (data_write_ok),
    .data_data_ok    (data_data_ok),
    .data_busy       (data_busy),

	//axi
	//ar
	.arid    (arid),
    .araddr  (araddr),
    .arlen   (arlen),
    .arsize  (arsize),
    .arburst (arburst),
    .arlock  (arlock),
    .arcache (arcache),
    .arprot  (arprot),
    .arvalid (arvalid),
    .arready (arready),

	//r
	.rid    (rid),
    .rdata  (rdata),
    .rresp  (rresp),
    .rlast  (rlast),
    .rvalid (rvalid),
    .rready (rready),

	//aw
	.awid    (awid),
    .awaddr  (awaddr),
    .awlen   (awlen),
    .awsize  (awsize),
    .awburst (awburst),
    .awlock  (awlock),
    .awcache (awcache),
    .awprot  (awprot),
    .awvalid (awvalid),
    .awready (awready),

	//w
	.wid    (wid),
    .wdata  (wdata),
    .wstrb  (wstrb),
    .wlast  (wlast),
    .wvalid (wvalid),
    .wready (wready),

	//b
	.bid    (bid),
    .bresp  (bresp),
    .bvalid (bvalid),
    .bready (bready)
);

interlayer interlayer(
    .clk   (clk),
    .rst_p (rst_p),

    //---IF---
    .IF_enable           (IF_enable),
    .IF_skip             (IF_skip),
    .interlayer_IF_ready (interlayer_IF_ready),

    .IF_mem_addr  (IF_mem_addr),
    .IF_mem_rdata (IF_mem_rdata),

    .inst_req     (inst_req),
    .inst_addr    (inst_addr),
    .inst_rdata   (inst_rdata),
    .inst_addr_ok (inst_addr_ok),
    .inst_data_ok (inst_data_ok),
    //---IF---

    //---WB---
    .MA_mem_read  (MA_mem_read),
    .MA_mem_write (MA_mem_write),
    .interlayer_MA_ready (interlayer_MA_ready),
    .interlayer_WB_ready (interlayer_WB_ready),
    .MA_mem_wstrb (MA_mem_wstrb),
    .MA_mem_addr  (MA_mem_addr),
    .MA_mem_size  (MA_mem_size),
    .MA_mem_wdata (MA_mem_wdata),
    .WB_mem_rdata (WB_mem_rdata),

	.data_req      (data_req),
    .data_wr       (data_wr),
    .data_addr     (data_addr),
    .data_size     (data_size),
    .data_wstrb    (data_wstrb),
    .data_wdata    (data_wdata),
    .data_rdata    (data_rdata),
    .data_data_ok  (data_data_ok),
    .data_write_ok (data_write_ok)
    //---MA---
);

IF IF(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (1'd0),

    //pipeline signals
    .interlayer_ready (interlayer_IF_ready),
    .IF_enable        (IF_enable),
    .IF_ready         (IF_ready),
    .DE_enable        (DE_enable),

    //memory access signals
    .IF_skip          (IF_skip),
    .IF_mem_addr      (IF_mem_addr),
    .IF_mem_rdata     (IF_mem_rdata),

    //interact with DE
    .eret             (DE_EX_eret),
    .PC_modified      (PC_modified),
    .PC_modified_data (PC_modified_data),
    .IF_PC            (IF_PC),
    .inst_out         (IF_inst),
    .exccode_out      (IF_DE_exccode),

    //interact with exception
    .exception (exception_taken),
    .exception_handler_entry (exception_handler_entry),
    .epc (epc)
);

DE DE(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (empty_exception),

    //pipeline signals
    .IF_ready  (IF_ready),
    .DE_enable (DE_enable),
    .DE_ready  (DE_ready),
    .EX_enable (EX_enable),

    //interact with IF
    .inst_in          (IF_inst),
    .IF_PC            (IF_PC),
    .PC_modified      (PC_modified),
    .PC_modified_data (PC_modified_data),
    .exccode_in       (IF_DE_exccode),

    //interact with forward
    .waiting   (forward_waiting),
    .rf_raddr1 (forward_raddr1),
    .rf_raddr2 (forward_raddr2),
    .rf_rdata1 (forward_rdata1),
    .rf_rdata2 (forward_rdata2),

    //interact with EX
    .rf_waddr_out     (DE_EX_rf_waddr),
    .rf_wdata_src_out (DE_EX_rf_wdata_src),
    .rf_wen_out       (DE_EX_rf_wen),

    .alu_src1_out (DE_EX_alu_src1),
    .alu_src2_out (DE_EX_alu_src2),
    .alu_op_out   (DE_EX_alu_op),
    .mf_hi_lo_out (DE_EX_mf_hi_lo),
    .mt_hi_lo_out (DE_EX_mt_hi_lo),
    .mul_div_out  (DE_EX_mul_div),

    .mem_read_out  (DE_EX_mem_read),
    .mem_write_out (DE_EX_mem_write),
    .align_load_out  (DE_EX_align_load),
    .align_store_out (DE_EX_align_store),

    .eret_out (DE_EX_eret),
    .mfc0_out (DE_EX_mfc0),
    .mtc0_out (DE_EX_mtc0),

    .imm_16_out (DE_EX_imm_16),

    .rf_A_out  (DE_EX_rf_A),
    .rf_B_out  (DE_EX_rf_B),

    .DE_PC (DE_PC),

    .in_delay_slot_out      (DE_EX_in_delay_slot),
    .address_error_IF_out   (DE_EX_address_error_IF),
    .overflow_exception_out (overflow_exception),
    .exccode_out            (DE_EX_exccode)
);

forward forward(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (empty_exception),

    .EX_rf_waddr (EX_MA_rf_waddr),
    .MA_rf_waddr (MA_WB_rf_waddr),
    .WB_rf_waddr (rf_waddr),

    .EX_rf_wen (EX_MA_rf_wen),
    .MA_rf_wen (MA_WB_rf_wen),
    .WB_rf_wen (WB_rf_wen),

    .EX_valid (EX_valid),
    .MA_valid (MA_valid),
    .WB_valid (WB_valid),

    .MA_leaving (MA_leaving),
    .WB_leaving (WB_leaving),

    .EX_mem_read (EX_MA_mem_read),
    .MA_mem_read (MA_WB_mem_read),
    .EX_mf       ((EX_MA_mf_hi_lo != 2'd0) || EX_MA_mfc0),

    .EX_alu_res  (EX_alu_res),
    .MA_alu_res  (MA_alu_res),
    .WB_rf_wdata (rf_wdata),

    .rf_raddr1 (rf_raddr1),
    .rf_raddr2 (rf_raddr2),
    .rf_rdata1 (rf_rdata1),
    .rf_rdata2 (rf_rdata2),

    .raddr1 (forward_raddr1),
    .raddr2 (forward_raddr2),
    .rdata1 (forward_rdata1),
    .rdata2 (forward_rdata2),

    .waiting (forward_waiting)
);

rf rf
(
    .clk    (clk),
    .rst_p  (rst_p),
    .raddr1 (rf_raddr1),
    .raddr2 (rf_raddr2),
    .rdata1 (rf_rdata1),
    .rdata2 (rf_rdata2),
    .wen    (rf_wen),
    .waddr  (rf_waddr),
    .wdata  (rf_wdata)
);

EX EX(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (empty_exception),

    //pipeline signals
    .DE_ready  (DE_ready),
    .EX_enable (EX_enable),
    .EX_ready  (EX_ready),
    .MA_enable (MA_enable),

    //interact with DE
    .rf_waddr_in     (DE_EX_rf_waddr),
    .rf_wdata_src_in (DE_EX_rf_wdata_src),
    .rf_wen_in       (DE_EX_rf_wen),

    .alu_src1_in (DE_EX_alu_src1),
    .alu_src2_in (DE_EX_alu_src2),
    .alu_op_in   (DE_EX_alu_op),
    .mf_hi_lo_in (DE_EX_mf_hi_lo),
    .mt_hi_lo_in (DE_EX_mt_hi_lo),
    .mul_div_in  (DE_EX_mul_div),

    .mem_read_in  (DE_EX_mem_read),
    .mem_write_in (DE_EX_mem_write),
    .align_load_in  (DE_EX_align_load),
    .align_store_in (DE_EX_align_store),

    .eret_in (DE_EX_eret),
    .mfc0_in (DE_EX_mfc0),
    .mtc0_in (DE_EX_mtc0),

    .imm_16_in (DE_EX_imm_16),

    .rf_A_in (DE_EX_rf_A),
    .rf_B_in (DE_EX_rf_B),

    .DE_PC   (DE_PC),

    .in_delay_slot_in      (DE_EX_in_delay_slot),
    .address_error_IF_in   (DE_EX_address_error_IF),
    .overflow_exception_in (overflow_exception),
    .exccode_in            (DE_EX_exccode),

    //interact with MA && mul_div
    .inst_rd_out (EX_MA_inst_rd),

    .rf_A_out (EX_MA_rf_A),
    .rf_B_out (EX_MA_rf_B),

    .rf_waddr_out     (EX_MA_rf_waddr),
    .rf_wdata_src_out (EX_MA_rf_wdata_src),
    .rf_wen_out       (EX_MA_rf_wen),
    .mf_hi_lo_out     (EX_MA_mf_hi_lo),
    .mt_hi_lo_out     (EX_MA_mt_hi_lo),
    .mul_div_out      (EX_MA_mul_div),

    .mem_read_out  (EX_MA_mem_read),
    .mem_write_out (EX_MA_mem_write),
    .align_load_out  (EX_MA_align_load),
    .align_store_out (EX_MA_align_store),

    .eret_out (EX_MA_eret),
    .mfc0_out (EX_MA_mfc0),
    .mtc0_out (EX_MA_mtc0),

    .alu_res_out (EX_alu_res),

    .EX_PC (EX_PC),

    .in_delay_slot_out    (EX_MA_in_delay_slot),
    .address_error_IF_out (EX_MA_address_error_IF),
    .exccode_out          (EX_MA_exccode),

    //interact with forward
    .valid_out (EX_valid)
);

mul_div mul_div(
    .clk   (clk),
    .rst_p (rst_p),

    .A (EX_MA_rf_A),
    .B (EX_MA_rf_B),

    .mul_div (EX_MA_mul_div),
    .done    (mul_div_done),

    .res (mul_div_res)
);

MA MA(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (empty_exception),

    //pipeline signals
    .EX_ready         (EX_ready),
    .MA_enable        (MA_enable),
    .MA_ready         (MA_ready),
    .WB_enable        (WB_enable),

    //memory access signals
    .interlayer_ready (interlayer_MA_ready),
    .MA_mem_read  (MA_mem_read),
    .MA_mem_write (MA_mem_write),
    .MA_mem_wstrb (MA_mem_wstrb),
    .MA_mem_addr  (MA_mem_addr),
    .MA_mem_size  (MA_mem_size),
    .MA_mem_wdata (MA_mem_wdata),
    .mem_busy     (data_busy),

    //interact with EX
    .inst_rd_in (EX_MA_inst_rd),

    .rf_A_in (EX_MA_rf_A),
    .rf_B_in (EX_MA_rf_B),

    .rf_waddr_in     (EX_MA_rf_waddr),
    .rf_wdata_src_in (EX_MA_rf_wdata_src),
    .rf_wen_in       (EX_MA_rf_wen),
    .mf_hi_lo_in     (EX_MA_mf_hi_lo),
    .mt_hi_lo_in     (EX_MA_mt_hi_lo),
    .mul_div_in      (EX_MA_mul_div),

    .mem_read_in  (EX_MA_mem_read),
    .mem_write_in (EX_MA_mem_write),
    .align_load_in  (EX_MA_align_load),
    .align_store_in (EX_MA_align_store),

    .eret_in (EX_MA_eret),
    .mfc0_in (EX_MA_mfc0),
    .mtc0_in (EX_MA_mtc0),

    .alu_res_in (EX_alu_res),

    .EX_PC (EX_PC),

    .in_delay_slot_in    (EX_MA_in_delay_slot),
    .address_error_IF_in (EX_MA_address_error_IF),
    .exccode_in          (EX_MA_exccode),

    //interact with WB
    .rf_B_out         (MA_WB_rf_B),
    .rf_waddr_out     (MA_WB_rf_waddr),
    .rf_wdata_src_out (MA_WB_rf_wdata_src),
    .rf_wen_out       (MA_WB_rf_wen),
    .alu_res_out      (MA_alu_res),
    .mem_read_out     (MA_WB_mem_read),
    .align_load_out   (MA_WB_align_load),

    .MA_PC (MA_PC),

    //interact with mul_div
    .mul_div_done_in (mul_div_done),
    .mul_div_res_in  (mul_div_res),

    //interact with forward
    .valid_out   (MA_valid),
    .leaving_out (MA_leaving),

    //interract with exception
    .in_delay_slot_out    (MA_in_delay_slot),
    .address_error_IF_out (MA_address_error_IF),
    .cp0_addr  (MA_cp0_addr),
    .cp0_rdata (MA_cp0_rdata),
    .cp0_wdata (MA_cp0_wdata),
    .mtc0_out  (MA_cp0_wen),
    .eret_out  (MA_eret),
    .exccode_out (MA_exccode)
);

WB WB(
    .clk   (clk),
    .rst_p (rst_p),
    .empty (1'd0),

    //pipeline signals
    .MA_ready         (MA_ready),
    .WB_enable        (WB_enable),
    .interlayer_ready (interlayer_WB_ready),

    //interact with MA
    .rf_B_in         (MA_WB_rf_B),
    .rf_waddr_in     (MA_WB_rf_waddr),
    .rf_wdata_src_in (MA_WB_rf_wdata_src),
    .rf_wen_in       (MA_WB_rf_wen),
    .alu_res_in      (MA_alu_res),
    .mem_read_in     (MA_WB_mem_read),
    .align_load_in   (MA_WB_align_load),

    .MA_PC (MA_PC),

    //interact with interlayer
    .mem_data (WB_mem_rdata),

    //interact with rf
    .rf_waddr_out   (rf_waddr),
    .rf_wdata_out   (rf_wdata),
    .rf_wen_leaving (rf_wen),

    //interact with debug
    .debug_PC          (debug_wb_pc),
    .debug_wb_rf_wen   (debug_wb_rf_wen),
    .debug_wb_rf_waddr (debug_wb_rf_wnum),
    .debug_wb_rf_wdata (debug_wb_rf_wdata),

    //interact with forward
    .rf_wen_out  (WB_rf_wen),
    .leaving_out (WB_leaving),
    .valid_out   (WB_valid)
);

exception exception(
    .clk   (clk),
    .rst_p (rst_p),

    .hw_int (int),

    .MA_leaving (MA_leaving),
    .MA_valid   (MA_valid),
    .MA_exccode (MA_exccode),
    .MA_eret    (MA_eret),
    .MA_PC      (MA_PC),
    .MA_alu_res (MA_alu_res),

    .WB_enable(WB_enable),

    .exception (exception_taken),
    .exception_handler_entry (exception_handler_entry),
    .epc_out   (epc),

    .in_delay_slot    (MA_in_delay_slot),
    .address_error_IF (MA_address_error_IF),

    .cp0_raddr (MA_cp0_addr),
    .cp0_rdata (MA_cp0_rdata),

    .cp0_wen   (MA_cp0_wen),
    .cp0_waddr (MA_cp0_addr),
    .cp0_wdata (MA_cp0_wdata)
);

endmodule
