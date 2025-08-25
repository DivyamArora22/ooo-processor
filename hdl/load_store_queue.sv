module load_store_queue
import rv32i_types::*;
#(
    parameter   QUEUE_DEPTH = SQUEUE_DEPTH,
    parameter   STATION_TYPE = 2'b10
)(

    input   logic                               clk,
    input   logic                               rst,
    input   logic                               branch_flush,
    output  logic                               ls_stall,

    input   reservation_station_entry_t         dispatched_res_station_entry,
    input   logic                               entry_ready,
    output  logic                               ls_entry_received,

    input   cdb_t                               cdb,
    input [ROB_IDX_WIDTH-1:0]                   rob_tail_pointer_i,

    output  logic   [PREG_IDX_WIDTH-1:0]        ls_ps1_s, ls_ps2_s,
    input   logic   [31:0]                      ls_ps1_v, ls_ps2_v,

    input   logic                               ls_cdb_ready,
    output  logic                               ls_cdb_valid,
    output  cdb_t                               LS_cdb,


    //dmem ports
    output   logic   [31:0]         d_bmem_addr,
    output   logic                  d_bmem_read,
    output   logic                  d_bmem_write,
    output   logic   [63:0]         d_bmem_wdata,
    input   logic                   d_bmem_ready,
    
    input   logic   [31:0]          d_bmem_raddr,
    input   logic   [63:0]          d_bmem_rdata,
    input   logic                   d_bmem_rvalid,

    input   logic                   d_bmem_received,

    //for rvfi
    output rvfi_mem_packet_t rvfi_mem_packet,
    output reservation_station_entry_t ls_res_station_reg
);
    localparam PTR_WIDTH  = $clog2(QUEUE_DEPTH); //width of "queue address" is log_2(s_queue_depth) or 6 bits by default

    reservation_station_entry_t     dispatched_RS;
    assign dispatched_RS = dispatched_res_station_entry;

    //cache ports 
    logic   [31:0]  ufp_addr;
    logic   [3:0]   ufp_rmask;
    logic   [3:0]   ufp_wmask;
    logic   [31:0]  ufp_rdata;
    logic   [31:0]  ufp_wdata;
    logic           ufp_resp;
    logic           dfp_write;
    logic   [255:0] dfp_wdata;
    logic           dfp_res;

    //LOAD RESERVATION STATION
    localparam NUM_STATIONS = 3;
    l_entry_t l_res_station_reg [NUM_STATIONS];
    int free_index;
    int occupied_ready_index, occupied_ready_index_i, occupied_ready_index_reg;
    logic l_stall;
    logic l_place;
    logic l_execute;
    logic l_wait;

    //STORE QUEUE
    reservation_station_entry_t     s_rdata;
    logic                           s_enqueue;
    logic                           s_dequeue;
    logic                           s_full;
    logic                           s_empty;
    logic                           s_stall;
    s_queue_entry_t                 s_queue [QUEUE_DEPTH];
    logic [PTR_WIDTH:0]             head_pointer, tail_pointer;
    logic [PTR_WIDTH-1:0]           head_pointer_i, tail_pointer_i; 
    logic                           overflow;

    assign l_place = entry_ready && !ls_entry_received && dispatched_RS.station_index == STATION_TYPE && dispatched_RS.opcode == op_b_load && free_index != -1;
    assign l_execute = ls_cdb_ready && (occupied_ready_index != -1 || l_wait);

    assign s_enqueue = entry_ready && dispatched_RS.station_index == STATION_TYPE && !ls_entry_received && dispatched_RS.opcode == op_b_store && !s_full;
    assign s_dequeue = 
    ls_cdb_ready 
    && !ls_cdb_valid
    && !s_empty 
    && s_queue[tail_pointer_i].rs.valid 
    && rob_tail_pointer_i == s_queue[tail_pointer_i].rs.rob_index 
    && s_queue[tail_pointer_i].rs.ps1_valid 
    && s_queue[tail_pointer_i].rs.ps2_valid
    && !l_wait; 

    assign head_pointer_i = head_pointer[PTR_WIDTH-1:0]; //these "i" pointers are the true addresses 
    assign tail_pointer_i = tail_pointer[PTR_WIDTH-1:0];

    // the MSB of the fake pointers are different, it means that the head is in a different quadrant than the tail
    // the addresses are the same but we are in a different quadrant, we have filled the cache
    assign overflow = head_pointer[PTR_WIDTH] != tail_pointer[PTR_WIDTH]; 

    //logic for potraying s_queue state
    always_comb begin
        // the true pointers line up but the overflow bit is high, cache is s_full
        if(head_pointer_i == tail_pointer_i && overflow) begin
            s_full = '1;
            s_empty = '0;
        end
        // the true pointers line up but the oveflow bit is low, cache is s_empty
        else if(head_pointer_i == tail_pointer_i && !overflow) begin
            s_full = '0;
            s_empty = '1;
        end
        //normal state, ready for standard operation
        else begin
            s_full = '0;
            s_empty = '0;
        end
    end

    //Store forwarding logic
    always_comb begin
        free_index = -1;
        for (int i = 0; i < NUM_STATIONS; i++) begin
            if (!l_res_station_reg[i].rs.valid) begin
                free_index = i;
                break;
            end
        end
    end

    logic [31:0]        store_forward_data;
    logic               store_forward_flag;
    logic [31:0]        load_target_addr[NUM_STATIONS];
    
    logic [31:0]        store_forward_data_i [NUM_STATIONS];
    logic               store_forward_flag_i [NUM_STATIONS];
    logic               unresolved_store_flag_array [NUM_STATIONS];

    assign store_forward_flag = (occupied_ready_index == -1) ? '0 : store_forward_flag_i[occupied_ready_index];
    assign store_forward_data = (occupied_ready_index == -1) ? '0 : store_forward_data_i[occupied_ready_index];

    always_comb begin
        occupied_ready_index_i = -1;
        //check for the stall flag, if it's not high, this station is ready to fire
        for (int i = 0; i < NUM_STATIONS; i++) begin
            if(!unresolved_store_flag_array[i]
            && l_res_station_reg[i].rs.valid
            && l_res_station_reg[i].rs.ps1_valid
            && l_res_station_reg[i].rs.ps2_valid) occupied_ready_index_i = i;
        end

        for (int i = 0; i < NUM_STATIONS; i++) begin
            unresolved_store_flag_array[i] = '0;
            store_forward_flag_i[i] = '0;
            store_forward_data_i[i] = '0;
            load_target_addr[i] = '0;
        end

        //check all the stations, preferring the lower indices
        for (int i = 0; i < NUM_STATIONS; i++) begin
            //check the basic stuff (is the load's addr resolved and is there a valid entry?)
            if (l_res_station_reg[i].rs.valid
            && l_res_station_reg[i].rs.ps1_valid
            && l_res_station_reg[i].rs.ps2_valid
            ) begin
                load_target_addr[i] = l_res_station_reg[i].ls_ps1_v + l_res_station_reg[i].rs.imms;

                if(s_queue[l_res_station_reg[i].store_ptr].rs.valid
                && (s_queue[l_res_station_reg[i].store_ptr].rs.ps1_valid 
                && s_queue[l_res_station_reg[i].store_ptr].rs.ps2_valid)
                ) begin
                    //say our load's target store shares our load's address & width
                    //forward the data and execute it
                    if((s_queue[l_res_station_reg[i].store_ptr].tgt_address == load_target_addr[i]) 
                    && (s_queue[l_res_station_reg[i].store_ptr].rs.op[2:0] == l_res_station_reg[i].rs.op[2:0]
                    )) begin
                        store_forward_flag_i[i] = '1;
                        store_forward_data_i[i] = s_queue[l_res_station_reg[i].store_ptr].wdata;
                    //say we encounter a valid store that is older than our load's target store and encompasses the 
                    //same word as our load but doesn't fulfill the width requirement for forwarding, we must also wait
                    end else if ((s_queue[l_res_station_reg[i].store_ptr].tgt_address[31:2] == load_target_addr[i][31:2])
                    &&  (s_queue[l_res_station_reg[i].store_ptr].rs.op[2:0] != l_res_station_reg[i].rs.op[2:0])
                    ) begin
                        unresolved_store_flag_array[i] = '1;
                    end
                    break;
                end

                //iterate through the entire queue to check for forwading unresolved stores
                for (int j = 0; j < QUEUE_DEPTH; j++) begin
                    
                    //say we encounter a valid store that is older than our load's target store and unresolved, 
                    //we must stop, this load will have to wait
                    if(s_queue[j].rs.valid
                    && s_queue[j].age > s_queue[l_res_station_reg[i].store_ptr].age
                    && (!s_queue[j].rs.ps1_valid || !s_queue[j].rs.ps2_valid)
                    && s_queue[l_res_station_reg[i].store_ptr].rs.valid) begin
                        unresolved_store_flag_array[i] = '1;
                    end

                end
            end

        end
    end

    assign occupied_ready_index = (l_wait) ? occupied_ready_index_reg : occupied_ready_index_i;
    
    logic [31:0] tgt_address;
    always_comb begin
        if(s_dequeue)           tgt_address = s_queue[tail_pointer_i].ls_ps1_v + s_queue[tail_pointer_i].rs.imms;
        else if (l_execute)     tgt_address = l_res_station_reg[occupied_ready_index].ls_ps1_v + l_res_station_reg[occupied_ready_index].rs.imms;
        else                    tgt_address = 'x;
    end
    assign ls_ps1_s = (s_enqueue || l_place) ? dispatched_RS.ps1 : '0;
    assign ls_ps2_s = (s_enqueue || l_place) ? dispatched_RS.ps2 : '0;

    logic [3:0] rmask, wmask;
    assign ufp_rmask = (ufp_resp && !store_forward_flag) ? '0 : rmask;
    assign ufp_wmask = (ufp_resp) ? '0 : wmask;

    assign ls_stall = l_stall || s_stall;

    //interaction with store s_queue and load RS
    always_ff @(posedge clk) begin
        if(rst || branch_flush) begin
            ls_entry_received <= '0;

            //S s_queue
            s_stall <= '0;
            for(int i = 0; i < QUEUE_DEPTH; i++) s_queue[i] <= '0;
            s_rdata <= 'x;
            head_pointer <= '0;
            tail_pointer <= '0;

            //load RS 
            occupied_ready_index_reg <= -1;
            l_wait <= '0;
            l_stall <= '0;
            for(int i = 0; i < NUM_STATIONS; i++) l_res_station_reg[i] <= '0;

            //cache signals
            rmask <= '0;
            wmask <= '0;
            ufp_wdata <= '0;

            //CDB signals
            ls_cdb_valid <= '0;
            LS_cdb <= '0;

        end
        else begin
            //stall signals
            s_stall <= s_full && dispatched_RS.station_index == STATION_TYPE && entry_ready && dispatched_RS.opcode == op_b_store;
            l_stall <= free_index == -1 && dispatched_RS.station_index == STATION_TYPE && entry_ready && dispatched_RS.opcode == op_b_load;

            //de-assert handshake signals
            if(ls_cdb_valid && ls_cdb_ready) begin 
                LS_cdb.cdb_valid <= '0;
                ls_cdb_valid <= '0;
            end

            //push an instruction onto the store s_queue
            if(s_enqueue) begin
                s_queue[head_pointer_i].rs <= dispatched_RS;
                head_pointer <= head_pointer + 1'b1;
                ls_entry_received <= '1;
                s_queue[head_pointer_i].rs.valid <= '1;

                s_queue[head_pointer_i].ls_ps1_v <= ls_ps1_v; 
                s_queue[head_pointer_i].ls_ps2_v <= ls_ps2_v;

                //immediately prior validation edge cases
                if(cdb.preg_index == dispatched_RS.ps1 
                && !dispatched_RS.ps1_valid
                && cdb.preg_index != '0) s_queue[head_pointer_i].rs.ps1_valid <= '1; 
                if(cdb.preg_index == dispatched_RS.ps2 
                && !dispatched_RS.ps2_valid
                && cdb.preg_index != '0) s_queue[head_pointer_i].rs.ps2_valid <= '1;

                //if the address can be resolved, resolve it and the data (for forwarding/ooo_load conflict protection)
                if(dispatched_RS.ps1_valid && dispatched_RS.ps2_valid) begin 
                    s_queue[head_pointer].tgt_address <= ls_ps1_v + dispatched_RS.imms;
                    s_queue[head_pointer].wdata <= ls_ps2_v;
                end

            end else if(l_place) begin //place a load into the load RS
                l_res_station_reg[free_index].rs <= dispatched_RS;
                l_res_station_reg[free_index].rs.valid <= '1;
                ls_entry_received <= '1;

                l_res_station_reg[free_index].ls_ps1_v <= ls_ps1_v; 
                l_res_station_reg[free_index].ls_ps2_v <= ls_ps2_v;

                //immediately prior validation edge cases
                if(cdb.preg_index == dispatched_RS.ps1 
                && cdb.preg_index != '0) l_res_station_reg[free_index].rs.ps1_valid <= '1;
                if(cdb.preg_index == dispatched_RS.ps2
                && cdb.preg_index != '0) l_res_station_reg[free_index].rs.ps2_valid <= '1;

                // Assign the store pointer to the index of the youngest valid store
                l_res_station_reg[free_index].store_ptr <= head_pointer_i - 1'b1;

            end else begin
                ls_entry_received <= '0;
                s_rdata <= 'x;
            end

            //pop an instruction off the store s_queue
            if(s_dequeue) begin 
                ufp_addr <= tgt_address;
                rmask <= '0;
                unique case (s_queue[tail_pointer_i].rs.op[2:0])
                    store_f3_sb: wmask <= 4'b0001 << tgt_address[1:0];
                    store_f3_sh: wmask <= 4'b0011 << tgt_address[1:0];
                    store_f3_sw: wmask <= 4'b1111;
                    default    : wmask <= 'x;
                endcase 
                unique case (s_queue[tail_pointer_i].rs.op[2:0])
                    store_f3_sb: ufp_wdata[8 *tgt_address[1:0] +: 8 ] <= s_queue[tail_pointer_i].ls_ps2_v[7 :0];
                    store_f3_sh: ufp_wdata[16*tgt_address[1]   +: 16] <= s_queue[tail_pointer_i].ls_ps2_v[15:0];
                    store_f3_sw: ufp_wdata <= s_queue[tail_pointer_i].ls_ps2_v;
                    default    : ufp_wdata <= 'x;
                endcase 
                if(ufp_resp && wmask != '0) begin 
                    tail_pointer <= tail_pointer + 1'b1;
                    wmask <= '0;
                    LS_cdb.cdb_valid <= '1;
                    LS_cdb.rob_index <= s_queue[tail_pointer_i].rs.rob_index;
                    ls_cdb_valid <= '1;
                    LS_cdb.areg_index <= '0;
                    LS_cdb.preg_index <= '0;
                    LS_cdb.result <= '0;
                    s_queue[tail_pointer_i].rs.valid <= '0;
                end
            end
            //if the store s_queue isn't ready, try to perform a load instead (potentially OOO)
            else if(l_execute) begin
                if(occupied_ready_index_reg != occupied_ready_index && !l_wait) occupied_ready_index_reg <= occupied_ready_index;
                ufp_addr <= tgt_address;
                ufp_wdata <= '0;
                wmask <= '0;
                if(store_forward_flag) begin
                    LS_cdb.result <= store_forward_data;
                    LS_cdb.cdb_valid <= '1;
                    LS_cdb.areg_index <= l_res_station_reg[occupied_ready_index].rs.rd;
                    LS_cdb.preg_index <= l_res_station_reg[occupied_ready_index].rs.pd;
                    LS_cdb.rob_index <= l_res_station_reg[occupied_ready_index].rs.rob_index;
                    ls_cdb_valid <= '1;
                    l_res_station_reg[occupied_ready_index].rs.valid <= '0;
                end else begin 
                    l_wait <= '1;
                    unique case (l_res_station_reg[occupied_ready_index].rs.op[2:0]) 
                        load_f3_lb, load_f3_lbu: rmask <= 4'b0001 << tgt_address[1:0];
                        load_f3_lh, load_f3_lhu: rmask <= 4'b0011 << tgt_address[1:0];
                        load_f3_lw             : rmask <= 4'b1111;
                        default                : rmask <= 'x;
                    endcase
                    if(ufp_resp && rmask != '0) begin
                        l_wait <= '0;
                        rmask <= '0;
                        case (l_res_station_reg[occupied_ready_index].rs.op[2:0])
                            load_f3_lb : LS_cdb.result <= {{24{ufp_rdata[7 +8 *tgt_address[1:0]]}}  , ufp_rdata[8 *tgt_address[1:0] +: 8 ]};
                            load_f3_lbu: LS_cdb.result <= {{24{1'b0}}                               , ufp_rdata[8 *tgt_address[1:0] +: 8 ]};
                            load_f3_lh : LS_cdb.result <= {{16{ufp_rdata[15 + 16*tgt_address[1]]}}  , ufp_rdata[16*tgt_address[1]   +: 16]};
                            load_f3_lhu: LS_cdb.result <= {{16{1'b0}}                               , ufp_rdata[16*tgt_address[1]   +: 16]};
                            load_f3_lw : LS_cdb.result <= ufp_rdata;
                            default    : LS_cdb.result <= 'x;
                        endcase
                        LS_cdb.cdb_valid <= '1;
                        LS_cdb.areg_index <= l_res_station_reg[occupied_ready_index].rs.rd;
                        LS_cdb.preg_index <= l_res_station_reg[occupied_ready_index].rs.pd;
                        LS_cdb.rob_index <= l_res_station_reg[occupied_ready_index].rs.rob_index;
                        ls_cdb_valid <= '1;
                        l_res_station_reg[occupied_ready_index].rs.valid <= '0;
                    end
                end
            end
            else ls_cdb_valid <= '0;


            //update invalid operands in the store s_queue as they arrive
            for (int i = 0; i < QUEUE_DEPTH; i++) begin
                if(cdb.cdb_valid) begin
                    if(s_queue[i].rs.ps1 == cdb.preg_index && !s_queue[i].rs.ps1_valid && cdb.preg_index != '0) begin 
                        s_queue[i].rs.ps1_valid <= '1;
                        s_queue[i].ls_ps1_v <= cdb.result;
                    end if(s_queue[i].rs.ps2 == cdb.preg_index && !s_queue[i].rs.ps2_valid && cdb.preg_index != '0) begin 
                        s_queue[i].rs.ps2_valid <= '1;
                        s_queue[i].ls_ps2_v <= cdb.result;
                    end
                end

                //update store queue entry ages
                if(s_queue[i].rs.valid) s_queue[i].age <= s_queue[i].age + 1'b1;
                else s_queue[i].age <= '0;

                //resolve addresses and data for forwarding potential as well
                if(s_queue[i].rs.valid && s_queue[i].rs.ps1_valid && s_queue[i].rs.ps2_valid) begin
                    s_queue[i].tgt_address <= s_queue[i].ls_ps1_v + s_queue[i].rs.imms;
                    s_queue[i].wdata <= s_queue[i].ls_ps2_v;
                end
            end 

            //update invalid operands in the load RS as they arrive
            for (int i = 0; i < NUM_STATIONS; i++) begin
                if(cdb.cdb_valid) begin
                    if(cdb.preg_index == l_res_station_reg[i].rs.ps1 && cdb.preg_index != '0 && !l_res_station_reg[i].rs.ps1_valid) begin
                        l_res_station_reg[i].rs.ps1_valid <= '1;
                        l_res_station_reg[i].ls_ps1_v <= cdb.result;
                    end if(cdb.preg_index == l_res_station_reg[i].rs.ps2 && cdb.preg_index != '0 && !l_res_station_reg[i].rs.ps2_valid) begin 
                        l_res_station_reg[i].rs.ps2_valid <= '1;
                        l_res_station_reg[i].ls_ps2_v <= cdb.result;
                    end
                end

                //update load RS entry ages
                if(l_res_station_reg[i].rs.valid) l_res_station_reg[i].age <= l_res_station_reg[i].age + 1'b1;
                else l_res_station_reg[i].age <= '0;
            end

        end
    end

logic [31:0] store_forward_addr;
logic [3:0] store_forward_rmask;

always_comb begin
    if(store_forward_flag) begin
        store_forward_addr = l_res_station_reg[occupied_ready_index].ls_ps1_v + l_res_station_reg[occupied_ready_index].rs.imms;
        unique case (l_res_station_reg[occupied_ready_index].rs.op[2:0]) 
            load_f3_lb, load_f3_lbu: store_forward_rmask = 4'b0001 << store_forward_addr[1:0];
            load_f3_lh, load_f3_lhu: store_forward_rmask = 4'b0011 << store_forward_addr[1:0];
            load_f3_lw             : store_forward_rmask = 4'b1111;
            default                : store_forward_rmask = 'x;
        endcase
    end else begin
        store_forward_addr = '0;
        store_forward_rmask = '0;
    end

end

//RVFI signals for ROB to use
assign rvfi_mem_packet.valid = ufp_resp || (store_forward_flag && !s_dequeue);
assign rvfi_mem_packet.addr  = (store_forward_flag) ? store_forward_addr : ufp_addr;
assign rvfi_mem_packet.rmask = (store_forward_flag && !s_dequeue) ? store_forward_rmask : rmask;
assign rvfi_mem_packet.wmask = wmask;
assign rvfi_mem_packet.rdata = (store_forward_flag) ? store_forward_data : ufp_rdata;
assign rvfi_mem_packet.wdata = ufp_wdata;

always_comb begin 
    if(|wmask) begin 
        ls_res_station_reg = s_queue[tail_pointer_i].rs;
        rvfi_mem_packet.rob_idx = s_queue[tail_pointer_i].rs.rob_index;
        rvfi_mem_packet.rs1_rdata = s_queue[tail_pointer_i].ls_ps1_v;
        rvfi_mem_packet.rs2_rdata = s_queue[tail_pointer_i].ls_ps2_v;
    end else if (|rmask || (store_forward_flag && !s_dequeue)) begin 
        ls_res_station_reg = l_res_station_reg[occupied_ready_index].rs;
        rvfi_mem_packet.rob_idx = l_res_station_reg[occupied_ready_index].rs.rob_index;
        rvfi_mem_packet.rs1_rdata = l_res_station_reg[occupied_ready_index].ls_ps1_v;
        rvfi_mem_packet.rs2_rdata = l_res_station_reg[occupied_ready_index].ls_ps2_v;
    end else begin
        ls_res_station_reg          = 'x;
        rvfi_mem_packet.rob_idx     = 'x;
        rvfi_mem_packet.rs1_rdata   = 'x;
        rvfi_mem_packet.rs2_rdata   = 'x;
    end
end

logic burst_ready, dfp_read;
logic [31:0] cacheline_addr, dfp_addr, d_bmem_addr_write;
logic [255:0] cacheline_data;
logic branch_reg, ufp_resp_i;

always_ff @ (posedge clk) begin
    if(rst) branch_reg <= '0;
    else if(branch_flush && ufp_rmask != '0) branch_reg <= '1;
    else if(ufp_resp_i && branch_reg) branch_reg <= '0; 
end

assign ufp_resp = (branch_reg) ? '0 : ufp_resp_i;


    cache dmem_cache_i(
    .clk(clk),
    .rst(rst),

    .ufp_addr(ufp_addr),
    .ufp_rmask(ufp_rmask),
    .ufp_wmask(ufp_wmask),
    .ufp_rdata(ufp_rdata),
    .ufp_wdata(ufp_wdata),  
    .ufp_resp(ufp_resp_i),


    .dfp_addr(dfp_addr),
    .dfp_read(dfp_read),
    .dfp_write(dfp_write),
    .dfp_rdata(cacheline_data),
    .dfp_wdata(dfp_wdata),
    .dfp_resp(burst_ready)
    );

    always_comb begin
        if(dfp_read && !burst_ready)  begin
            d_bmem_addr = dfp_addr;
            d_bmem_read = '1;
        end
        else if(dfp_write && !burst_ready) begin 
            d_bmem_addr = d_bmem_addr_write;
            d_bmem_read = '0;
        end
        else begin
            d_bmem_addr = '0;
            d_bmem_read = '0;
        end
    end

    cacheline_adapter dmem_cacheline_adapter_i (

    .clk(clk),
    .rst(rst),
    .branch_flush('0),

    .received(d_bmem_received),

    //  bmem facing ports
    .raddr(d_bmem_raddr),
    .rdata(d_bmem_rdata),
    .rvalid(d_bmem_rvalid),
    .ready(d_bmem_ready),

    .bmem_addr(d_bmem_addr_write),
    .bmem_wdata(d_bmem_wdata),
    .bmem_write(d_bmem_write),

    //cache facing ports
    .cache_waddr(dfp_addr),
    .cache_wdata(dfp_wdata),
    .dfp_write(dfp_write),

    .cacheline_addr(cacheline_addr),
    .cacheline_data(cacheline_data),
    .burst_ready(burst_ready)
    );


//performance counters

int ooo_load_counter;
logic [PTR_WIDTH-1:0] ooo_load_storeq_ptrs [NUM_STATIONS];
logic ooo_load_flags [NUM_STATIONS];

int forwarded_stores;
int store_forward_counter_flag;

always_ff @(posedge clk) begin
    if(rst) begin
        ooo_load_counter <= 0;
        for(int i = 0; i < 3; i++) begin 
            ooo_load_storeq_ptrs[i] <= '0;
            ooo_load_flags[i] <= '0;
        end

        forwarded_stores <= 0;
        store_forward_counter_flag <= 0;

    end else begin

        //count how many loads are issued out of order w.r.t the store queue
        //when a load arrives, save the youngest store that was valid when we 
        //initially it in an R.S. 
        //When that load is executed while that youngest but older store is still valid, 
        //we just did an OOO load and can increment the counter
        for(int i = 0; i < 3; i++) begin 
            if(l_res_station_reg[i].rs.valid && !ooo_load_flags[i]) begin
                 ooo_load_flags[i] <= '1;
                 ooo_load_storeq_ptrs[i] <= head_pointer_i - 1'b1;
            end else if (!l_res_station_reg[i].rs.valid) ooo_load_flags[i] <= '0;

            if(ooo_load_flags[i] && !l_res_station_reg[i].rs.valid && s_queue[ooo_load_storeq_ptrs[i]].rs.valid) begin
                ooo_load_counter <= ooo_load_counter + 1;
                ooo_load_flags[i] <= '0;
            end

        end


        //count how many times a store is forwarded to a load (this is rare due to our poor IPC)
        if(store_forward_flag && !store_forward_counter_flag) begin 
            forwarded_stores <= forwarded_stores + 1;
            store_forward_counter_flag <= 1;
        end else if(!store_forward_flag) store_forward_counter_flag <= 0;



    end

end

endmodule : load_store_queue