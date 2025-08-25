module free_list
import rv32i_types::*;
(
    input   logic                       clk,
    input   logic                       rst,

    //pushing (connected to RRF)
    input   logic [PREG_IDX_WIDTH-1:0]  freed_preg,
    input   logic                       enqueue_freelist,
    output  logic                       freelist_full,

    //popping (connected to DISPATCH/RENAME)
    output  logic [PREG_IDX_WIDTH-1:0]  preg,
    input   logic                       dequeue_freelist,

    //status (connected to DISPATCH/RENAME)
    output  logic                       empty_freelist,
    input   logic                       branch_flush,
    input   logic                       jump_flag
);

    free_list_entry_t  queue [32]; //queue array

    logic [PREG_IDX_WIDTH-1:0]   head_pointer, tail_pointer; //keep an extra bit at the top to indicate if head has "lapped" tail

    logic [PREG_IDX_WIDTH-2:0]  head_pointer_i, tail_pointer_i; 
    logic overflow;
    logic full;
    logic dequeue_reg;
    assign freelist_full = full;

    assign preg = queue[tail_pointer_i];
    assign head_pointer_i = head_pointer[PREG_IDX_WIDTH-2:0]; //these "i" pointers are the true addresses 
    assign tail_pointer_i = tail_pointer[PREG_IDX_WIDTH-2:0];

    // the MSB of the fake pointers are different, it means that the head is in a different quadrant than the tail
    // the addresses are the same but we are in a different quadrant, we have filled the cache
    assign overflow = head_pointer[PREG_IDX_WIDTH-1] != tail_pointer[PREG_IDX_WIDTH-1]; 

    //logic for potraying queue state
    always_comb begin
        // the true pointers line up but the overflow bit is high, cache is full
        if(head_pointer_i == tail_pointer_i && overflow) begin
            full = '1;
            empty_freelist = '0;
        end
        // the true pointers line up but the oveflow bit is low, cache is empty_freelist
        else if(head_pointer_i == tail_pointer_i && !overflow) begin
            full = '0;
            empty_freelist = '1;
        end
        //normal state, ready for standard operation
        else begin
            full = '0;
            empty_freelist = '0;
        end
    end


    logic [PREG_IDX_WIDTH-2:0] tail_pointer_i_reg;

    //interaction with actual queue array
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < 32; i++) begin
                queue[i] <= free_list_entry_t'(i + 32);
            end
            head_pointer <= 6'd32;
            tail_pointer <= '0;
            dequeue_reg <= '0;
            tail_pointer_i_reg <= '0;
        end
        else begin
            dequeue_reg <= dequeue_freelist;
            tail_pointer_i_reg <= tail_pointer_i;


            if(jump_flag || branch_flush) begin
                head_pointer <= 6'd32;
                tail_pointer <= '0;
                if(jump_flag && enqueue_freelist && !full && freed_preg != '0 && queue[head_pointer_i] != freed_preg) begin
                    queue[head_pointer_i] <= free_list_entry_t'(freed_preg);
                end
            end
            else begin 
                if(enqueue_freelist && !full && freed_preg != '0 && queue[head_pointer_i] != freed_preg) begin
                    head_pointer <= head_pointer + 1'b1;
                    queue[head_pointer_i] <= free_list_entry_t'(freed_preg);
                end
                if(dequeue_freelist && !empty_freelist) begin
                    tail_pointer <= tail_pointer + 1'b1;
                end
            end


        end
    end


endmodule : free_list

