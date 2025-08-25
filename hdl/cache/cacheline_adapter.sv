module cacheline_adapter
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           branch_flush,

    //arbiter prots
    input logic             received,

    //  bmem facing ports
    input   logic   [31:0]  raddr,
    input   logic   [63:0]  rdata,
    input   logic           rvalid,
    input   logic           ready, 
    
    output  logic   [31:0]  bmem_addr,
    output  logic   [63:0]  bmem_wdata,
    output  logic           bmem_write,

    //  cache facing ports
    input   logic   [31:0]  cache_waddr,
    input   logic   [255:0] cache_wdata,
    input   logic           dfp_write,

    output  logic   [31:0]  cacheline_addr,
    output  logic   [255:0] cacheline_data,
    output  logic           burst_ready
);

    logic   [63:0] cacheline_data_next;
    logic   [63:0] bmem_wdata_next;

    cacheline_adapter_state_t   current_state;
    cacheline_adapter_state_t   next_state;

    assign burst_ready = (next_state == DONE) ? '1 : '0;

    always_ff @(posedge clk)                                begin
        if(rst || branch_flush)                             begin
            cacheline_addr <= 'x;
            cacheline_data <= '0;
            bmem_wdata <= '0;
            bmem_addr <= '0;
            current_state <= WAIT;
            bmem_write <= '0;
        end
        else                                                begin
            cacheline_addr <= cacheline_addr;
            cacheline_data <= cacheline_data;
            bmem_wdata <= bmem_wdata;
            if(dfp_write) bmem_addr <= cache_waddr;
            else bmem_addr <= bmem_addr;
            bmem_write <= dfp_write;
            if(ready) begin 
                current_state <= next_state;
            end
            //  need 4 bursting states to concactenate 4 bursts of 64-bits to 1 burst of 256-bits
            if(next_state == BURSTING1 && rvalid )    begin
                cacheline_data[63:0] <= cacheline_data_next;
                cacheline_addr <= raddr;
                bmem_write <= dfp_write;
            end
            else if(next_state == BURSTING2 && rvalid )    begin
                cacheline_data[127:64] <= cacheline_data_next;
                cacheline_addr <= raddr;
            end
            else if(next_state == BURSTING3 && rvalid )    begin
                cacheline_data[191:128] <= cacheline_data_next;
                cacheline_addr <= raddr;
            end
            else if(next_state == BURSTING4 && rvalid )    begin
                cacheline_data[255:192] <= cacheline_data_next;
                cacheline_addr <= raddr;
            end
            if((next_state == BURSTING1 || next_state == BURSTING2 || next_state == BURSTING3 || next_state == BURSTING4) && dfp_write )    begin
                bmem_wdata <= bmem_wdata_next;
                bmem_addr <= cache_waddr;
            end
        end
    end

    always_comb                                             begin
        next_state = current_state;
        unique case (current_state)
            WAIT:                                           begin
                //  stay in the wait state until memory responds (rvalid signal)
                if((rvalid || dfp_write) && received)                                  begin
                    next_state = BURSTING1;
                end
            end
            BURSTING1:                                       begin
                next_state = BURSTING2;
            end
            BURSTING2:                                       begin
                next_state = BURSTING3;
            end
            BURSTING3:                                       begin
                next_state = BURSTING4;
            end
            BURSTING4:                                       begin
                next_state = DONE;
            end
            DONE:                                           begin
                next_state = WAIT;
            end
            default: next_state = WAIT;
        endcase
    end

    always_comb  begin
        //  cacheline_data_next is 64 bits so you set it equal to the data coming in from memory and then update it to the corresponding 64-bit location in cacheline_data to fill it up
        cacheline_data_next = '0;
        if (next_state == BURSTING1 || next_state == BURSTING2 || next_state == BURSTING3 || next_state == BURSTING4) cacheline_data_next = rdata;
        
        if (next_state == BURSTING1 && dfp_write) bmem_wdata_next = cache_wdata[63:0];
        else if (next_state == BURSTING2 && dfp_write) bmem_wdata_next = cache_wdata[127:64];
        else if (next_state == BURSTING3 && dfp_write) bmem_wdata_next = cache_wdata[191:128];
        else if (next_state == BURSTING4 && dfp_write) bmem_wdata_next = cache_wdata[255:192];
        else bmem_wdata_next = '0;
    end

endmodule: cacheline_adapter