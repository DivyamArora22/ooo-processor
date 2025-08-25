module cache 
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);
    logic halt, miss, stall,stall_reg, write_delay;

    cache_pipeline_reg_t cache_pipeline_reg, cache_pipeline_reg_next;
    logic [255:0] cache_lines[4];
    logic [23:0] cache_tags[4];
    logic valid_bits[4];

    logic hit, dirty, fake_dirty;
    logic dfp_resp_indicator;
    logic hit_array[4];
    logic dirty_array[4];
    logic [1:0] way_evicted;
    logic web[4];
    logic clean_update[4];

    logic [23:0] tag, clean_update_tag;
    logic [3:0] rmask, wmask;
    logic [4:0] offset;
    logic [31:0] addr, wdata;
    logic [2:0] lru, lru_next; 
    logic lru_web, idle, idle_delay;

    assign tag = {dirty, cache_pipeline_reg.tag};
    assign clean_update_tag = {1'b0, cache_tags[way_evicted][22:0]};
    assign rmask = cache_pipeline_reg.rmask;
    assign wmask = cache_pipeline_reg.wmask;
    assign offset = cache_pipeline_reg.offset;
    assign addr = cache_pipeline_reg.addr;
    assign wdata = cache_pipeline_reg.wdata;

    assign idle = (rmask == '0 && wmask == '0) && !idle_delay;

    always_ff @ (posedge clk) begin
        if(rst) idle_delay <= '1;
        else idle_delay <= '0;
    end

    always_ff @( posedge clk ) begin
        if (stall || write_delay) stall_reg <= '1;
        else stall_reg <= '0;
    end

    assign halt = (miss || stall || stall_reg) && !idle;


    //increment the pipeline
    always_ff @ (posedge clk) begin
        if(rst) cache_pipeline_reg <= '0;
        else if (halt) cache_pipeline_reg <= cache_pipeline_reg;
        else cache_pipeline_reg <= cache_pipeline_reg_next;
    end

    //stage 1 (depends on the CPU signals and stage 2 hit/miss/stall stuff)
    logic [3:0] set;
    assign set = (halt || (hit && write_delay)) ? cache_pipeline_reg.cache_set : cache_pipeline_reg_next.cache_set;

    always_comb begin
        if(rst) begin
            cache_pipeline_reg_next.tag = '0;
            cache_pipeline_reg_next.cache_set = '0;
            cache_pipeline_reg_next.offset = '0;
            cache_pipeline_reg_next.rmask = '0;
            cache_pipeline_reg_next.wmask = '0;
            cache_pipeline_reg_next.addr = '0;
            cache_pipeline_reg_next.wdata = '0;
        end
        else begin
            cache_pipeline_reg_next.tag = ufp_addr[31:9];
            cache_pipeline_reg_next.cache_set = ufp_addr[8:5];
            cache_pipeline_reg_next.offset = ufp_addr[4:0];
            cache_pipeline_reg_next.rmask = ufp_rmask;
            cache_pipeline_reg_next.wmask = ufp_wmask;
            cache_pipeline_reg_next.addr = ufp_addr;
            cache_pipeline_reg_next.wdata = ufp_wdata;
        end
    end

    // stage 2 (depends on results from SRAM/FF arrays)

    //need 4 copes of everything since we are inspecting 
    //every way within a set at once. we can pick the correct one later

    logic [31:0] temp_word;

    always_comb begin
        for(int i = 0; i < 4; i++) begin
            web[i] = '1;
            clean_update[i] = '1;
            hit_array[i] = '0;
            if(valid_bits[i]) begin 
                dirty_array[i] = cache_tags[i][23];
            end
            else begin 
                dirty_array[i] = '0;
            end
        end

        hit = '0;
        dirty = '0;

        miss = '0;
        stall = '0;

        lru_web = '1;
        lru_next = 'x;
        way_evicted = 'x;
        write_delay = '0;

        ufp_rdata = 'x;
        ufp_resp = '0;
        
        dfp_addr = '0;
        dfp_read = '0;
        dfp_write = '0;
        dfp_wdata = '0;

        if(rmask != '0 || wmask != '0) begin
            //search the cache for our value

            //identify the way that will be evicted
            case (~lru)
                3'b100,3'b000: way_evicted = 2'd0;
                3'b010,3'b110: way_evicted = 2'd1;
                3'b001,3'b011: way_evicted = 2'd2;
                3'b101,3'b111: way_evicted = 2'd3;
            endcase

             //search the cache for our value
            if(!stall_reg) begin
                for(int i = 0; i < 4; i++) begin
                    //hit
                    if(cache_tags[i][22:0] == tag[22:0] && valid_bits[i]) begin
                        //send the entire word (autograder doesn't care about extra data)
                        //(rmask != '0) ufp_rdata = cache_lines[i][offset * 8 +: 32 ];
                        if(rmask != '0) ufp_rdata = cache_lines[i][offset[4:2] * 32+: 32 ];

                        // this is a write, we need to de-assert the WEB of the hit way's cache-line
                        if(wmask != '0) begin 
                            web[i] = '0;
                            dirty = '1;
                            write_delay = '1;
                        end

                        hit_array[i] = '1;
                        ufp_resp = '1;
                        //update the "MRU" array for this set with the cache line we just hit
                        lru_web = '0;
                        if(valid_bits[i]) begin
                            unique case (i) //i == way
                                0: lru_next = {lru[2], 1'b0, 1'b0};
                                1: lru_next = {lru[2], 1'b1, 1'b0};
                                2: lru_next = {1'b0, lru[1], 1'b1};
                                3: lru_next = {1'b1, lru[1], 1'b1};
                                default: lru_next = 'x; //this cannot happen
                            endcase
                        end
                    end
                    //miss
                    else begin
                        hit_array[i] = '0;
                    end
                end
                hit = (hit_array[0] | hit_array[1] | hit_array[2] | hit_array[3]);
                miss = !hit;
            end

            //we missed. go get the block from memory, replace a cacheline based on LRU
            if(miss) begin
                // the way is dirty, write the dirty cache-line to memory first
                if(dirty_array[way_evicted] && !fake_dirty) begin
                    
                    dfp_wdata = cache_lines[way_evicted];
                    dfp_addr = {cache_tags[way_evicted][22:0], set, 5'b0};
                    dfp_write = '1;
                    dfp_read = '0;
                    //the way is now clean, remove its dirty bit
                    if(dfp_resp_indicator && dfp_resp) clean_update[way_evicted] = '0;
                end
                //proceed normally
                else begin
                    dfp_addr = {addr[31:5], 5'b0}; //256-bit alignment
                    dfp_read = '1;
                    if(dfp_resp) begin
                        //use the LRU to evict a line
                        web[way_evicted] = '0;
                        stall = '1;
                    end
                end
            end


        end
    end

    always_ff @ (posedge clk) begin
        if((dfp_resp && dfp_write)) fake_dirty <= '1;
        else fake_dirty <= '0;
    end

    always_ff @ (posedge clk) begin
        if(rst )dfp_resp_indicator <= '0;
        else begin
            if(dfp_write) dfp_resp_indicator <= '1;
            else if(dfp_read) dfp_resp_indicator <= '0;
            else dfp_resp_indicator <= dfp_resp_indicator;
        end
    end

    logic [31:0] cache_line_wmask;
    logic [255:0] cache_line_input;

    always_comb begin
        // write hit, update the specific bytes of the cache line 
        //and ignore memory (this line is now dirty)
        if(wmask != 4'b0000 && hit) begin
            cache_line_input = '0;
            cache_line_wmask = '0;
            /*
            for (int unsigned i = 0; i < 4; i++) begin
                if (wmask[i]) begin 
                    cache_line_input[((8 * offset) + (i * 8)) +: 8] = wdata[(i * 8) +: 8];
                end
            end
            */
            //cache_line_input[offset[4:2] * 32 +: 32] = wdata;
            //cache_line_wmask[(offset & 5'b11110) +: 4] = wmask;
            cache_line_input[offset[4:2] * 32 +: 32] = wdata;
            cache_line_wmask[offset[4:2] * 4 +: 4] = wmask;
        end
        // it's a write miss (or a read, doesn't really matter), 
        //we will be updating the entire block using the DFP, so set things accordingly. 
        else begin
            cache_line_wmask = '1;
            cache_line_input = dfp_rdata;
        end
    end

    logic [23:0] next_tag;
    logic clean_update_combined;
    assign clean_update_combined = !(clean_update[0] && clean_update[1] && clean_update[2] && clean_update[3]);
    assign next_tag = (clean_update_combined) ? clean_update_tag : tag;

    generate for (genvar i = 0; i < 4; i++) begin : arrays
        
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web[i]),
            .wmask0     (cache_line_wmask), 
            .addr0      (set),
            .din0       (cache_line_input),
            .dout0      (cache_lines[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (1'b0),
            .web0       (web[i] && clean_update[i]),
            .addr0      (set),
            .din0       (next_tag),
            .dout0      (cache_tags[i])
        );
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (1'b0),
            .web0       (web[i]),
            .addr0      (set),
            .din0       (1'b1),
            .dout0      (valid_bits[i])
        );

    end endgenerate
    
    logic [3:0] lru_set;
    assign lru_set = (halt || !lru_web) ? cache_pipeline_reg.cache_set : cache_pipeline_reg_next.cache_set;

    //this is actually an MRU tree
    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),

        //read port
        .csb0       (1'b0),
        .web0       (1'b1),
        .addr0      (set),
        .din0       (3'b000),
        .dout0      (lru),

        //write port
        .csb1       (1'b0),
        .web1       (lru_web),
        .addr1      (lru_set),
        .din1       (lru_next),
        .dout1      ()
    );

endmodule

