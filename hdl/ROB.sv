module ROB
import rv32i_types::*;
(
    input   logic                           clk,
    input   logic                           rst,

    //DISPATCH+RENAME ports 
    input   logic                           enqueue_rob_packet,
    input   rob_packet_t                    rob_packet,
    output  logic [ROB_IDX_WIDTH-1:0]       rob_index,

    //RRF ports
    output  logic [4:0]                     RRF_rd,
    output  logic [PREG_IDX_WIDTH - 1:0]    RRF_pd,
    output  logic                           RRF_we,

    //CDB
    input   cdb_t                           cdb,

    //LS queue
    output  logic   [ROB_IDX_WIDTH-1:0]     rob_tail_pointer_i,

    //rvfi
    input   rvfi_signals_t                  rvfi_dispatch_rename,
    input   reservation_station_entry_t     alu_res_station_reg, mul_res_station_reg,
    input   logic [PREG_IDX_WIDTH-1:0]      alu_ps1_s, alu_ps2_s, mul_ps1_s, mul_ps2_s,
    input   logic [31:0]                    alu_ps1_v, alu_ps2_v, mul_ps1_v, mul_ps2_v, 
    input   rvfi_mem_packet_t               rvfi_mem_packet,

    output  rvfi_signals_t                  rvfi_rob_committed,
    output  logic                           rob_stall,
    output  logic                           branch_flush,
    output  logic                           jump_flag,
    output  logic [31:0]                    target_pc,
    input   logic cache_ready_rob,
    output logic branch_flush_temp

);
    logic full, empty;

    assign rob_stall = full;

    localparam PTR_WIDTH  = $clog2(ROB_DEPTH); //width of "queue address" is log_2(queue_depth) or 6 bits by default

    logic                           ROB_valid_queue [ROB_DEPTH];    //valid array
    rob_packet_t ROB_queue [ROB_DEPTH];

    logic [PTR_WIDTH:0]   head_pointer, tail_pointer; //keep an extra bit at the top to indicate if head has "lapped" tail

    logic [PTR_WIDTH-1:0]  head_pointer_i, tail_pointer_i; 
    logic overflow;

    assign head_pointer_i = head_pointer[PTR_WIDTH-1:0]; //these "i" pointers are the true addresses 
    assign tail_pointer_i = tail_pointer[PTR_WIDTH-1:0];
    assign rob_tail_pointer_i = tail_pointer_i;

    // the MSB of the fake pointers are different, it means that the head is in a different quadrant than the tail
    // the addresses are the same but we are in a different quadrant, we have filled the cache
    assign overflow = head_pointer[PTR_WIDTH] != tail_pointer[PTR_WIDTH]; 

    //logic for potraying queue state
    always_comb begin
        // the true pointers line up but the overflow bit is high, cache is full
        if(head_pointer_i == tail_pointer_i && overflow) begin
            full = '1;
            empty = '0;
        end
        // the true pointers line up but the oveflow bit is low, cache is empty
        else if(head_pointer_i == tail_pointer_i && !overflow) begin
            full = '0;
            empty = '1;
        end
        //normal state, ready for standard operation
        else begin
            full = '0;
            empty = '0;
        end
    end

    //interaction with actual queue array
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < ROB_DEPTH; i++) begin
                ROB_queue[i] <= '0;
                ROB_valid_queue[i] <= '0;
            end
            head_pointer <= '0;
            tail_pointer <= '0;

            rob_index <= '0;

            RRF_rd <= 'x;
            RRF_pd <= 'x;
            RRF_we <= '0;

            branch_flush <= '0;
            branch_flush_temp <= '0;
            jump_flag <= '0;
            target_pc <= '0;
        end
        else begin
            if (cache_ready_rob) branch_flush_temp <= '0;

            branch_flush <= '0;
            jump_flag <= '0;
            //push an ROB_packet onto the queue
            //this is done by dispatch/rename
            if(enqueue_rob_packet && !full) begin // the queue is not full..
                ROB_queue[head_pointer_i] <= rob_packet;
                ROB_valid_queue[head_pointer_i] <= '0;
                head_pointer <= head_pointer + 1'b1;
                rob_index <= head_pointer_i + 1'b1;
            end


            //pop an ROB_packet off the queue
            // the queue is not empty, and the tail instruction is valid...
            if(!empty && ROB_valid_queue[tail_pointer_i] == '1) begin 
                //we must point the arch register at the new register 
                if(ROB_queue[tail_pointer_i].branch_taken && ROB_queue[tail_pointer_i].areg_index != '0) begin
                    branch_flush <= '1;
                    jump_flag <= '1;
                    branch_flush_temp <= '1;
                    target_pc <= ROB_queue[tail_pointer_i].target_pc;
                end
                else if(ROB_queue[tail_pointer_i].branch_taken) begin
                    branch_flush <= '1;
                    jump_flag <= '0;
                    branch_flush_temp <= '1;
                    target_pc <= ROB_queue[tail_pointer_i].target_pc;
                end
                else if(ROB_queue[tail_pointer_i].take_branch) target_pc <= ROB_queue[tail_pointer_i].target_pc;

                RRF_pd <= ROB_queue[tail_pointer_i].preg_index;
                RRF_rd <= ROB_queue[tail_pointer_i].areg_index;
                RRF_we <= '1;

                tail_pointer <= tail_pointer + 1'b1;

                //zero the entry
                ROB_valid_queue[tail_pointer_i] <= '0;
                ROB_queue[tail_pointer_i] <= '0;


            end
            else begin 
                RRF_pd <= 'x;
                RRF_rd <= 'x;
                RRF_we <= '0;
            end

            // a CDB value has been received, this implies that the 
            //valid bit assosciated with this physical result is ready.
            //set the cdb entry's valid bit.
            if(cdb.cdb_valid && ROB_valid_queue[cdb.rob_index] == '0) begin 
                ROB_valid_queue[cdb.rob_index] <= '1;
                if(cdb.jalr_flag || cdb.branch_flag) ROB_queue[cdb.rob_index].branch_taken <= '1;
                if(cdb.take_branch) ROB_queue[cdb.rob_index].take_branch <= '1;
                ROB_queue[cdb.rob_index].target_pc <= cdb.result;
            end

            if(branch_flush) begin
                for(int i = 0; i < ROB_DEPTH; i++) begin
                    ROB_queue[i] <= '0;
                    ROB_valid_queue[i] <= '0;
                end
                head_pointer <= '0;
                tail_pointer <= '0;

                rob_index <= '0;

                RRF_rd <= 'x;
                RRF_pd <= 'x;
                RRF_we <= '0;

                branch_flush <= '0;
                jump_flag <= '0;
            end
        end
    end

rvfi_signals_t rob_rvfi_queue[ROB_DEPTH];
rvfi_signals_t rvfi_rob;
assign rvfi_rob = rob_rvfi_queue[tail_pointer_i];
logic [63:0] order_counter;

always_ff @(posedge clk) begin
        if(rst) begin
            order_counter <= '0;
            for(int i = 0; i < ROB_DEPTH; i++) begin
                rob_rvfi_queue[i] <= '0;
            end
            rvfi_rob_committed <= '0;
        end
        else if (branch_flush) begin
            for(int i = 0; i < ROB_DEPTH; i++) begin
                rob_rvfi_queue[i] <= '0;
            end
            rvfi_rob_committed <= '0;
        end
        else begin
            if(enqueue_rob_packet && !full) begin
                rob_rvfi_queue[head_pointer_i] <= rvfi_dispatch_rename;
            end
            if(!empty && ROB_valid_queue[tail_pointer_i] == '1) begin 
                order_counter <= order_counter + 1;


                rvfi_rob_committed.valid <= '1;
                rvfi_rob_committed.order <= order_counter;
                rvfi_rob_committed.inst <= rvfi_rob.inst;
                rvfi_rob_committed.rs1_addr <= rvfi_rob.rs1_addr;
                rvfi_rob_committed.rs2_addr <= rvfi_rob.rs2_addr;
                rvfi_rob_committed.rs1_rdata <= rvfi_rob.rs1_rdata;
                rvfi_rob_committed.rs2_rdata <= rvfi_rob.rs2_rdata;
                rvfi_rob_committed.rd_addr  <= rvfi_rob.rd_addr;
                rvfi_rob_committed.rd_wdata <= rvfi_rob.rd_wdata;
                rvfi_rob_committed.pc_rdata <= rvfi_rob.pc_rdata;
                rvfi_rob_committed.pc_wdata <= rvfi_rob.pc_wdata;
                rvfi_rob_committed.ps1_addr <= 'x;
                rvfi_rob_committed.ps2_addr <= 'x;

                if(ROB_queue[tail_pointer_i].branch_taken || ROB_queue[tail_pointer_i].take_branch) begin
                    rvfi_rob_committed.pc_wdata <= ROB_queue[tail_pointer_i].target_pc;
                end

                rvfi_rob_committed.mem_addr  <= rvfi_rob.mem_addr;
                rvfi_rob_committed.mem_rmask <= rvfi_rob.mem_rmask;
                rvfi_rob_committed.mem_wmask <= rvfi_rob.mem_wmask;
                rvfi_rob_committed.mem_rdata <= rvfi_rob.mem_rdata;
                rvfi_rob_committed.mem_wdata <= rvfi_rob.mem_wdata;
                rvfi_rob_committed.mem_rdata <= rvfi_rob.mem_rdata;
            end
            else rvfi_rob_committed <= '0;

            if(cdb.cdb_valid) begin 
                // the CDB has our rd_wdata...
                if (ROB_queue[cdb.rob_index].areg_index == cdb.areg_index && cdb.jalr_flag)
                    rob_rvfi_queue[cdb.rob_index].rd_wdata <= cdb.jalr_return_pc;
                else if(ROB_queue[cdb.rob_index].areg_index == cdb.areg_index) begin
                    rob_rvfi_queue[cdb.rob_index].rd_wdata <= cdb.result;
                end
            end


            // a relevant memory instruction has executed...
            if(rvfi_mem_packet.valid) begin
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_addr <=  rvfi_mem_packet.addr;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_rmask <= rvfi_mem_packet.rmask;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_wmask <= rvfi_mem_packet.wmask;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_rdata <= rvfi_mem_packet.rdata;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_wdata <= rvfi_mem_packet.wdata;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].mem_rdata <= rvfi_mem_packet.rdata;

                rob_rvfi_queue[rvfi_mem_packet.rob_idx].rs1_rdata <= rvfi_mem_packet.rs1_rdata;
                rob_rvfi_queue[rvfi_mem_packet.rob_idx].rs2_rdata <= rvfi_mem_packet.rs2_rdata;
            end


            // the RES_STATIONS have our rs1/2_rdata...
            if(alu_res_station_reg.valid) begin
                if(rob_rvfi_queue[alu_res_station_reg.rob_index].ps1_addr == alu_ps1_s) begin
                    rob_rvfi_queue[alu_res_station_reg.rob_index].rs1_rdata <= alu_ps1_v;
                end
                if(rob_rvfi_queue[alu_res_station_reg.rob_index].ps2_addr == alu_ps2_s) begin
                    rob_rvfi_queue[alu_res_station_reg.rob_index].rs2_rdata <= alu_ps2_v;
                end
            end
            if(mul_res_station_reg.valid) begin
                if(rob_rvfi_queue[mul_res_station_reg.rob_index].ps1_addr == mul_ps1_s) begin
                    rob_rvfi_queue[mul_res_station_reg.rob_index].rs1_rdata <= mul_ps1_v;
                end
                if(rob_rvfi_queue[mul_res_station_reg.rob_index].ps2_addr == mul_ps2_s) begin
                    rob_rvfi_queue[mul_res_station_reg.rob_index].rs2_rdata <= mul_ps2_v;
                end
            end

        end
end


endmodule : ROB
