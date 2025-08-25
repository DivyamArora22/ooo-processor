module instruction_queue
import rv32i_types::*;
#(
    parameter   DATA_WIDTH  = 32,
    parameter   QUEUE_DEPTH = IQUEUE_DEPTH
)(
    input   logic                   clk,
    input   logic                   rst,

    //pushing
    input   logic [DATA_WIDTH-1:0]  wdata,
    input   logic                   enqueue,

    //popping
    output  logic [DATA_WIDTH-1:0]  rdata,
    input   logic                   dequeue,

    //status
    output  logic                   full,
    output  logic                   empty,

    //rvfi
    input rvfi_signals_t            enqueue_rvfi,
    output rvfi_signals_t           dequeue_rvfi,

    //jumps and branches
    input logic branch_flush,
    input logic prediction,
    input logic jump_flag
);
    localparam PTR_WIDTH  = $clog2(QUEUE_DEPTH); //width of "queue address" is log_2(queue_depth) or 6 bits by default

    logic [DATA_WIDTH-1:0]  queue [QUEUE_DEPTH]; //queue array

    logic [PTR_WIDTH:0]   head_pointer, tail_pointer; //keep an extra bit at the top to indicate if head has "lapped" tail

    logic [PTR_WIDTH-1:0]  head_pointer_i, tail_pointer_i; 
    logic overflow;

    assign head_pointer_i = head_pointer[PTR_WIDTH-1:0]; //these "i" pointers are the true addresses 
    assign tail_pointer_i = tail_pointer[PTR_WIDTH-1:0];

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

    rvfi_signals_t rvfi_queue [QUEUE_DEPTH];

    //interaction with actual queue array
    always_ff @(posedge clk) begin
        if(rst || branch_flush || jump_flag || prediction) begin
            for(int i = 0; i < QUEUE_DEPTH; i++) begin
                queue[i] <= '0;
                rvfi_queue[i] <= '0;
            end
            rdata <= 'x;
            head_pointer <= '0;
            tail_pointer <= '0;
        end
        else begin
            //push an instruction onto the queue
            if(enqueue && !full) begin // the queue is not full..
                queue[head_pointer_i] <= wdata;
                head_pointer <= head_pointer + 1'b1;

                rvfi_queue[head_pointer_i] <= enqueue_rvfi;
            end
            //pop an instruction off the queue
            if(dequeue && !empty) begin // the queue is not empty...
                rdata <= queue[tail_pointer_i];
                tail_pointer <= tail_pointer + 1'b1;

                dequeue_rvfi <= rvfi_queue[tail_pointer_i];
            end
            else begin 
                rdata <= 'x;
                dequeue_rvfi <= 'x;
            end
        end
    end


endmodule : instruction_queue
