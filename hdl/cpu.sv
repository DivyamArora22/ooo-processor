module cpu
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    output  logic   [31:0]      bmem_addr,
    output  logic               bmem_read,
    output  logic               bmem_write,
    output  logic   [63:0]      bmem_wdata,
    input   logic               bmem_ready,

    input   logic   [31:0]      bmem_raddr,
    input   logic   [63:0]      bmem_rdata,
    input   logic               bmem_rvalid
);

logic alu_stall, mul_stall, rob_stall, ls_stall;
logic global_stall, entry_ready;

assign global_stall = mul_stall || alu_stall || rob_stall || entry_ready || ls_stall;

logic [31:0] instruction;
logic valid_instruction;

rvfi_signals_t rvfi_fetch;
logic [31:0] pc_temp;
logic pc_flag;


logic   [31:0]       i_bmem_addr;
logic                i_bmem_read;
logic               i_bmem_ready; 
logic   [31:0]      i_bmem_raddr;
logic   [63:0]      i_bmem_rdata;
logic               i_bmem_rvalid;
logic   [31:0]       d_bmem_addr;
logic                d_bmem_read;
logic                d_bmem_write;
logic   [63:0]       d_bmem_wdata;
logic               d_bmem_ready;
logic   [31:0]      d_bmem_raddr;
logic   [63:0]      d_bmem_rdata;
logic               d_bmem_rvalid;

logic i_bmem_received;
logic d_bmem_received;
cache_arbiter cache_arbiter_i (
    .*
);
logic [31:0] target_pc;
logic branch_flush;
logic cache_ready_rob;
logic branch_flush_temp;

free_list_entry_t areg_array_rrf [32];
logic prediction;
//dave
fetch fetch_i (
    .*
);

decode_stage_reg_t decode_reg;

//horace
decode decode_i (
    .*
);

logic [4:0] RAT_rd, RAT_rs1, RAT_rs2;
logic [PREG_IDX_WIDTH - 1:0] RAT_pd, RAT_ps1, RAT_ps2;
logic RAT_we, RAT_ps1_valid, RAT_ps2_valid;
logic [31:0] RAT_cdb;
//divyam
RAT RAT_i (
    .*
);

logic dequeue_freelist, empty_freelist;
logic [PREG_IDX_WIDTH-1:0] preg;
logic enqueue_rob_packet;
rob_packet_t rob_packet;
reservation_station_entry_t dispatched_res_station_entry;
logic [ROB_IDX_WIDTH-1:0]       rob_index;
cdb_t cdb;

rvfi_signals_t rvfi_dispatch_rename;

dispatch_rename dispatch_rename_i (
    .*
);

logic pregf_we;
logic [31:0] alu_ps1_v, alu_ps2_v, mul_ps1_v, mul_ps2_v, ls_ps1_v, ls_ps2_v;
logic [PREG_IDX_WIDTH-1:0] alu_ps1_s, alu_ps2_s, mul_ps1_s, mul_ps2_s, ls_ps1_s, ls_ps2_s;

pregfile pregfile_i (
    .*
);

logic [2:0] aluop, mulop;
logic [PREG_IDX_WIDTH-1:0] ALU_pd;
logic [5:0] ALU_rd;
logic [ROB_IDX_WIDTH-1:0] ALU_rob_index;

reservation_station_entry_t alu_res_station_reg;
assign alu_ps1_s = alu_res_station_reg.ps1;
assign alu_ps2_s = alu_res_station_reg.ps2;

logic alu_ready, alu_entry_received, mul_entry_received, ls_entry_received, entry_received;

assign entry_received = mul_entry_received || alu_entry_received || ls_entry_received;

//ALU reservation stations
reservation_station ALU_station_i (
    .clk(clk),
    .rst(rst),
    .stall(alu_stall),
    .global_stall(global_stall),
    .entry_received(alu_entry_received),
    .entry_ready(entry_ready),
    .fu_ready(alu_ready),
    .res_station_entry(dispatched_res_station_entry),
    .cdb(cdb),
    .issued_res_station_reg(alu_res_station_reg),
    .branch_flush(branch_flush)
);

reservation_station_entry_t mul_res_station_reg;
assign mul_ps1_s = mul_res_station_reg.ps1;
assign mul_ps2_s = mul_res_station_reg.ps2;
logic mul_ready;

//MUL reservation stations
mul_reservation_station #(.STATION_TYPE(2'b01)) MUL_station_i 
(
    .clk(clk),
    .rst(rst),
    .stall(mul_stall),
    .global_stall(global_stall),
    .entry_received(mul_entry_received),
    .entry_ready(entry_ready),
    .fu_ready(mul_ready),
    .res_station_entry(dispatched_res_station_entry),
    .cdb(cdb),
    .issued_res_station_reg(mul_res_station_reg),
    .branch_flush(branch_flush)
);

cdb_t ALU_cdb;
logic alu_cdb_ready, alu_cdb_valid;

//alu
ALU ALU_i (
    .*
);

cdb_t MUL_cdb;
logic mul_cdb_ready, mul_cdb_valid;

//mul
MUL MUL_i (
    .*
);

cdb_t LS_cdb;
logic ls_cdb_ready, ls_cdb_valid;
logic [ROB_IDX_WIDTH-1:0] rob_tail_pointer_i;
rvfi_mem_packet_t rvfi_mem_packet;
reservation_station_entry_t ls_res_station_reg;

//LS queue
load_store_queue load_store_queue_i (
    .*
);


cdb_arbiter cdb_arbiter_i (
    .*
);


logic RRF_we;
logic [4:0] RRF_rd;
logic [PREG_IDX_WIDTH-1:0] RRF_pd;
rvfi_signals_t rvfi_rob_committed;
logic jump_flag;

//david
ROB ROB_i(
    .*
);

logic [PREG_IDX_WIDTH-1:0] freed_preg;
logic enqueue_freelist, freelist_full;

// (RAT_i.areg_array.all with ( item inside {free_list_i.queue} ))

RRF RRF_i (
    .*
);

//horace
free_list free_list_i (
    .*
);

logic           monitor_valid;
logic   [63:0]  monitor_order;
logic   [31:0]  monitor_inst;
logic   [4:0]   monitor_rs1_addr;
logic   [4:0]   monitor_rs2_addr;
logic   [31:0]  monitor_rs1_rdata;
logic   [31:0]  monitor_rs2_rdata;
logic           monitor_regf_we;
logic   [4:0]   monitor_rd_addr;
logic   [31:0]  monitor_rd_wdata;
logic   [31:0]  monitor_pc_rdata;
logic   [31:0]  monitor_pc_wdata;
logic   [31:0]  monitor_mem_addr;
logic   [3:0]   monitor_mem_rmask;
logic   [3:0]   monitor_mem_wmask;
logic   [31:0]  monitor_mem_rdata;
logic   [31:0]  monitor_mem_wdata;

assign monitor_valid     = rvfi_rob_committed.valid;
assign monitor_order     = (monitor_valid) ?  rvfi_rob_committed.order  : '0 ;
assign monitor_inst      = (monitor_valid) ?  rvfi_rob_committed.inst  : '0 ;
assign monitor_rs1_addr  = (monitor_valid) ?  rvfi_rob_committed.rs1_addr  : '0 ;
assign monitor_rs2_addr  = (monitor_valid) ?  rvfi_rob_committed.rs2_addr  : '0 ;
assign monitor_rs1_rdata = (monitor_valid) ?  rvfi_rob_committed.rs1_rdata  : '0 ;
assign monitor_rs2_rdata = (monitor_valid) ?  rvfi_rob_committed.rs2_rdata  : '0 ;
assign monitor_rd_addr   = (monitor_valid) ?  rvfi_rob_committed.rd_addr : '0 ;
assign monitor_rd_wdata  = (monitor_valid) ?  rvfi_rob_committed.rd_wdata : '0 ;
assign monitor_pc_rdata  = (monitor_valid) ?  rvfi_rob_committed.pc_rdata : '0 ;
assign monitor_pc_wdata  = (monitor_valid) ?  rvfi_rob_committed.pc_wdata : '0 ;
assign monitor_mem_addr  = (monitor_valid) ?  rvfi_rob_committed.mem_addr : '0 ;
assign monitor_mem_rmask = (monitor_valid) ?  rvfi_rob_committed.mem_rmask : '0 ;
assign monitor_mem_wmask = (monitor_valid) ?  rvfi_rob_committed.mem_wmask : '0 ;
assign monitor_mem_rdata = (monitor_valid) ?  rvfi_rob_committed.mem_rdata : '0 ;
assign monitor_mem_wdata = (monitor_valid) ?  rvfi_rob_committed.mem_wdata : '0 ;

endmodule : cpu
