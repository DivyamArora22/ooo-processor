module dispatch_rename
import rv32i_types::*;
(
    input logic                             clk,
    input logic                             rst,
    input logic                             global_stall,

    //instruction components register
    input   logic                           valid_instruction,
    input   decode_stage_reg_t              decode_reg,

    //RAT ports
    output  logic [4:0]                     RAT_rd,
    output  logic [PREG_IDX_WIDTH - 1:0]    RAT_pd,
    output  logic                           RAT_we,

    output  logic [4:0]                     RAT_rs1,
    input   logic [PREG_IDX_WIDTH - 1:0]    RAT_ps1,
    input   logic                           RAT_ps1_valid,

    output  logic [4:0]                     RAT_rs2,
    input   logic [PREG_IDX_WIDTH - 1:0]    RAT_ps2,
    input   logic                           RAT_ps2_valid,

    //free-list ports
    output  logic                           dequeue_freelist,
    //input   logic                           empty_freelist,
    input   logic [PREG_IDX_WIDTH - 1:0]    preg,

    //ROB ports
    output  logic                           enqueue_rob_packet,
    //output  rob_packet_t   rob_packet,
    output  rob_packet_t                    rob_packet,
    input   logic [ROB_IDX_WIDTH-1:0]       rob_index,

    //Reservation Station ports
    output  reservation_station_entry_t     dispatched_res_station_entry,
    input   logic                           entry_received,
    output  logic                           entry_ready,   

    //rvfi
    input logic [31:0]                      instruction,
    input rvfi_signals_t                    rvfi_fetch,
    output rvfi_signals_t                   rvfi_dispatch_rename,

    input logic branch_flush,
    input logic prediction
);

reservation_station_entry_t res_station_entry_reg, res_station_entry;
logic stall_reg;
logic [4:0] RAT_rd_reg;

always_ff @(posedge clk) begin
    if(rst || branch_flush) begin
        res_station_entry_reg <= '0;
        stall_reg <= '0;
        entry_ready <= '0;
        RAT_rd_reg <= '0;
    end
    else begin
        if(valid_instruction) RAT_rd_reg <= RAT_rd;
        if (!global_stall) res_station_entry_reg <= res_station_entry;
        stall_reg <= global_stall;

        if(entry_ready && entry_received) entry_ready <= '0;
        else if(valid_instruction && instruction != '0) entry_ready <= '1;
    end
end

assign dispatched_res_station_entry = (global_stall || stall_reg) ? res_station_entry_reg : res_station_entry;

always_comb begin
    RAT_rd = 'x;
    RAT_pd = 'x;
    RAT_we = '0;

    RAT_rs1 = 'x;
    RAT_rs2 = 'x;

    enqueue_rob_packet = '0;
    dequeue_freelist = '0;
    rob_packet = '0;

    res_station_entry = '0;
    res_station_entry.station_index = 2'b11;

    if(valid_instruction && instruction != '0) begin

        dequeue_freelist = '1;
        enqueue_rob_packet = '1;

        res_station_entry.rob_index = rob_index;

        res_station_entry.rd  = decode_reg.rd_addr;
        res_station_entry.pd  = preg;

        res_station_entry.ps1 = RAT_ps1;
        res_station_entry.ps1_valid = RAT_ps1_valid;

        res_station_entry.ps2 = RAT_ps2;
        res_station_entry.ps2_valid = RAT_ps2_valid;

        res_station_entry.opcode = decode_reg.opcode;

        RAT_rd = decode_reg.rd_addr;
        RAT_pd = preg;
        RAT_we = '1;
        
        RAT_rs1 = decode_reg.rs1_addr;
        RAT_rs2 = decode_reg.rs2_addr;
        
        rob_packet.areg_index = RAT_rd;
        rob_packet.preg_index = RAT_pd;
        rob_packet.target_pc = '0;
        rob_packet.branch_taken = '0;


        if(decode_reg.funct7 == multiply)   begin
            res_station_entry.op = decode_reg.mulop;
            res_station_entry.station_index = 2'd1;
        end
        else                                begin
            unique case (decode_reg.opcode)
                op_b_lui:                   begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.ps2_valid = '1;
                end
                op_b_auipc:                 begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.pc_flag = '1;
                    res_station_entry.ps1_valid = '1;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.ps2_valid = '1;
                    res_station_entry.return_pc = rvfi_fetch.pc_rdata;
                end
                op_b_imm:                   begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.ps2_valid = '1;
                end
                op_b_reg:                   begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                end
                op_b_br:                    begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.cmpop = decode_reg.cmpop;
                    res_station_entry.pc_flag = '1;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.prediction = prediction;
                    res_station_entry.return_pc = rvfi_fetch.pc_rdata;
                end
                op_b_jal:                   begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.ps1_valid = '1;
                    res_station_entry.ps2_valid = '1;
                    res_station_entry.return_pc = rvfi_fetch.pc_rdata + 4;
                end
                op_b_jalr:                  begin
                    res_station_entry.op = decode_reg.aluop;
                    res_station_entry.station_index = 2'd0;
                    res_station_entry.imm_flag = '1;
                    res_station_entry.imms = decode_reg.imm;
                    res_station_entry.ps2_valid = '1;
                    res_station_entry.return_pc = rvfi_fetch.pc_rdata + 4;
                end
                op_b_load, op_b_store:      begin
                    res_station_entry.op = decode_reg.funct3;
                    res_station_entry.station_index = 2'd2;
                    res_station_entry.imms = decode_reg.imm;
                end
                default:                    begin
                end
            endcase
        end

        if(RAT_rd == '0) begin
            dequeue_freelist = '0;
            enqueue_rob_packet = '1;

            res_station_entry.rob_index = rob_index;
            res_station_entry.pd = '0;

            RAT_pd = '0;
        end
    

    end
end


always_comb begin
    rvfi_dispatch_rename.valid = '0;
    rvfi_dispatch_rename.order = '0;
    rvfi_dispatch_rename.inst  = instruction;
    rvfi_dispatch_rename.rs1_addr = RAT_rs1;
    rvfi_dispatch_rename.rs2_addr = RAT_rs2;
    rvfi_dispatch_rename.rs1_rdata = '0;
    rvfi_dispatch_rename.rs2_rdata = '0;
    rvfi_dispatch_rename.rd_addr = RAT_rd;
    rvfi_dispatch_rename.rd_wdata = '0;
    rvfi_dispatch_rename.pc_rdata = rvfi_fetch.pc_rdata;
    rvfi_dispatch_rename.pc_wdata = rvfi_fetch.pc_wdata;


    rvfi_dispatch_rename.ps1_addr = RAT_ps1;
    rvfi_dispatch_rename.ps2_addr = RAT_ps2;

    rvfi_dispatch_rename.mem_addr = '0;
    rvfi_dispatch_rename.mem_rmask = '0;
    rvfi_dispatch_rename.mem_wmask = '0;
    rvfi_dispatch_rename.mem_rdata = '0;
    rvfi_dispatch_rename.mem_wdata = '0;
end

// always_ff @(posedge clk) begin
//     if(rst || branch_flush) pc_temp <= '0;
//     else if (pc_flag) pc_temp <= rvfi_fetch.pc_rdata;
//     else pc_temp <= pc_temp;
// end

logic temp;

assign temp = (RAT_rd == 5'd2) ? '1 : '0;

endmodule : dispatch_rename