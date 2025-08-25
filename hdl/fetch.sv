module fetch
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    input   logic               i_bmem_received,

    output  logic   [31:0]      i_bmem_addr,
    output  logic               i_bmem_read,
    input   logic               i_bmem_ready,

    input   logic   [31:0]      i_bmem_raddr,
    input   logic   [63:0]      i_bmem_rdata,
    input   logic               i_bmem_rvalid,

    input   logic               global_stall,
    output  logic   [31:0]      instruction,
    output  logic               valid_instruction,

    output  logic               prediction,

    output  rvfi_signals_t      rvfi_fetch,
    input   logic               branch_flush,
    input   logic [31:0]        target_pc,
    output  logic cache_ready_rob,
    input logic branch_flush_temp,

    input cdb_t cdb

);
logic cache_ready;
logic [31:0] pc, pc_next, cache_instruction, cache_instruction_reg, next_instruction;
logic stall_reg, valid_instruction_reg, full_flag;
logic [3:0] rmask;
logic full, enqueue, dequeue, empty, dequeue_i;
logic [31:0] wdata, rdata;

//regs and flags related to JAL
logic [31:0] j_imm, i_imm, b_imm, pc_next_reg;
logic jump_flag, jump_reg, jalr_flag;

//predictor
logic branch_flag;
logic branch_taken;
logic branch_commit;

assign jump_flag = ((instruction[6:0] == op_b_jal) && valid_instruction) ? 1'b1 : 1'b0;
assign jalr_flag = ((instruction[6:0] == op_b_jalr) && valid_instruction) ? 1'b1 : 1'b0;
assign branch_flag = (instruction[6:0] == op_b_br && valid_instruction) ? '1 : '0;

assign j_imm = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
assign b_imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};

assign instruction = rdata;
assign valid_instruction = (global_stall) ? '0 : valid_instruction_reg;

rvfi_signals_t enqueue_rvfi, dequeue_rvfi;

// always_comb begin
//     if(jump_flag) pc_next =  dequeue_rvfi.pc_rdata + j_imm;
//     else if(jump_reg) pc_next = pc_next_reg;
//     else pc_next = pc + 4;
// end

always_comb begin
    if (branch_flush) begin
        pc_next = target_pc; // Correct target on misprediction
    end else if (jump_flag) begin
        pc_next = dequeue_rvfi.pc_rdata + j_imm; // JAL
    end else if (branch_flag && prediction) begin
        pc_next = dequeue_rvfi.pc_rdata + b_imm; // Conditional branch (predicted taken)
    end else begin
        pc_next = pc + 4; // Sequential fetch
    end
end

//RVFI stuff
always_comb begin
    rvfi_fetch = dequeue_rvfi;
    if(jump_flag) rvfi_fetch.pc_wdata = pc_next;
end

always_comb begin 
    enqueue_rvfi = '0;
    enqueue_rvfi.pc_rdata = pc;
    enqueue_rvfi.pc_wdata = pc_next;
end

always_comb begin
    if(cache_ready && !full && !(branch_flush_temp)) begin
        rmask = '1;
        enqueue = '1;
        wdata = cache_instruction;
    end
    else if (full) begin
        rmask = '0;
        enqueue = '0;
        wdata = cache_instruction_reg;
    end
    else begin
        rmask = '1;
        enqueue = '0;
        wdata = 'x;
    end
end

always_ff @ (posedge clk) begin
    if(rst) begin
        pc <= 32'h1eceb000;
        cache_instruction_reg <= '0;

        jump_reg <= '0;
        pc_next_reg <= '0;
    end else begin
        
        if(jump_flag) begin 
            pc <= pc_next;
        end

        if(branch_flag && prediction) pc <= pc_next;
        else if(cache_ready && !full && cache_instruction != '0 && !branch_flush_temp)    begin //could be fucked
            if(jump_reg) pc <= pc_next_reg;
            else pc <= pc_next;
        end
        else if (branch_flush) begin
            pc <= target_pc;
        end
        else begin
            cache_instruction_reg <= cache_instruction;
        end
    end
end

assign dequeue = dequeue_i && !global_stall;

always_ff @(posedge clk) begin
    if (rst) begin
        branch_taken <= 1'b0;
        branch_commit <= 1'b0;
    end else if (branch_flush) begin
        branch_taken <= (target_pc != pc + 4); // Branch taken if not sequential
        branch_commit <= 1'b1;
    end else begin
        branch_commit <= 1'b0;
    end
end

always_ff @(posedge clk) begin
    if(rst || branch_flush) begin
        dequeue_i <= '0;
        next_instruction <= '0;
        valid_instruction_reg <= '0;
        stall_reg <= '0;
    end else begin 
        
        if(global_stall) begin 
            stall_reg <= '1;
        end
        else begin
            stall_reg <= '0;
            dequeue_i <= '1;
        end

        if(global_stall || branch_flag) begin
            next_instruction <= next_instruction;
            valid_instruction_reg <= '0;
            dequeue_i <= '0;
        end
        else if(stall_reg) begin
            valid_instruction_reg <= '0;
            next_instruction <= '0;
        end
        else if (!empty) begin
            next_instruction <= rdata;
            
            if(dequeue_i) dequeue_i <= '0;
            else dequeue_i <= '1;
            //dequeue_i <= '1;

            if(dequeue_i) valid_instruction_reg <= '1;
            else valid_instruction_reg <= '0;
        end
        else begin
            dequeue_i <= '0;
            valid_instruction_reg <= '0;
        end

    end
end

instruction_queue instruction_queue_i (
    .*
);

logic burst_ready, dfp_read;
logic [31:0] cacheline_addr, dfp_addr;
logic [255:0] cacheline_data;

always_ff @ (posedge clk) begin
    if(rst || branch_flush) begin 
        i_bmem_read <= '0;
        i_bmem_addr <= '0;
    end
    else if (i_bmem_ready) begin
        if(dfp_addr != '0 && dfp_read && !burst_ready) begin
            i_bmem_addr <= dfp_addr;
            i_bmem_read <= dfp_read;
            if(i_bmem_received) begin
                i_bmem_addr <= '0;
                i_bmem_read <= '0;
            end
        end
    end
end

logic [31:0] ufp_addr;


always_comb begin
    if (cache_ready && (branch_flush || branch_flush_temp)) ufp_addr = target_pc;
    else if(cache_ready) ufp_addr = pc_next;
    else ufp_addr = pc;
end

logic branch_reg, ufp_resp_i;

always_ff @ (posedge clk) begin
    if(rst) branch_reg <= '0;
    else if((branch_flush || jump_flag) && rmask != '0) branch_reg <= '1;
    else if(prediction) branch_reg <= '1;
    else if(ufp_resp_i && branch_reg) branch_reg <= '0; 
end

assign cache_ready = (branch_reg) ? '0 : ufp_resp_i;
assign cache_ready_rob = ufp_resp_i;

logic gselect_prediction, two_level_prediction;

gselect_predictor gselect_predictor_i (
    .clk(clk),
    .rst(rst),
    .branch_pc(pc),            // Current PC
    .branch_taken(cdb.branch_taken),
    .branch_taken_pc(cdb.branch_taken_pc),
    .branch_commit(cdb.branch_commit),
    .prediction(gselect_prediction),
    .is_branch(branch_flag)
);

two_level_predictor predictor (
    .clk(clk),
    .rst(rst),
    .branch_pc(pc),            // Current PC
    .branch_taken(branch_taken),
    .branch_commit(branch_flush),
    .prediction(two_level_prediction),
    .is_branch(branch_flag)
);

tournament_predictor tournament_predictor_i (
    .clk(clk),
    .rst(rst),
    .branch_pc(pc),
    .branch_taken(cdb.branch_taken),
    .branch_taken_pc(cdb.branch_taken_pc),
    .branch_commit(cdb.branch_commit),
    .is_branch(branch_flag),
    .prediction_1(two_level_prediction),
    .prediction_2(gselect_prediction),
    .final_prediction(prediction) 
);

cache cache_i(
    .clk(clk),
    .rst(rst),

    .ufp_addr(ufp_addr),
    .ufp_rmask(rmask),
    .ufp_wmask(4'b0000),
    .ufp_rdata(cache_instruction),
    .ufp_wdata(32'b0),  
    .ufp_resp(ufp_resp_i),

    .dfp_addr(dfp_addr),
    .dfp_read(dfp_read),
    .dfp_rdata(cacheline_data),
    .dfp_resp(burst_ready)

);

cacheline_adapter cacheline_adapter_i (

    .clk(clk),
    .rst(rst),
    .branch_flush('0),

    .received(i_bmem_received),

    .raddr(i_bmem_raddr),
    .rdata(i_bmem_rdata),
    .rvalid(i_bmem_rvalid),
    .ready(i_bmem_ready),

    .cache_waddr(32'b0),
    .cache_wdata(256'b0),
    .dfp_write(1'b0),

    .cacheline_addr(cacheline_addr),
    .cacheline_data(cacheline_data),
    .burst_ready(burst_ready)
);


endmodule : fetch
