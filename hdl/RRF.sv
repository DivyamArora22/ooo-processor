module RRF
import rv32i_types::*;
#(
    RRF_DEPTH = 64
)
(
    input   logic                           clk,
    input   logic                           rst,

    //ROB ports
    input   logic [4:0]                     RRF_rd,
    input   logic [PREG_IDX_WIDTH - 1:0]    RRF_pd,
    input   logic                           RRF_we,

    input   logic                           branch_flush,

    //Free-List Ports
    output  logic [PREG_IDX_WIDTH-1:0]      freed_preg,
    output  logic                           enqueue_freelist,
    input   logic                           freelist_full,
    output free_list_entry_t                areg_array_rrf[32]
);

    free_list_entry_t areg_array_rrf_i [32];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++) begin
                areg_array_rrf_i[i] <= free_list_entry_t'(i);
            end
            //freed_preg <= '0;
            //enqueue_freelist <= 1'b0;
        end
        else begin
            if (RRF_we && RRF_rd != '0 && RRF_pd != '0 && !freelist_full) begin //do not re-assign rd x0 or pd x0, and do not free pd x0
                //freed_preg <= areg_array_rrf_i[RRF_rd];
                //enqueue_freelist <= 1'b1;
                areg_array_rrf_i[RRF_rd] <= RRF_pd;
            end
            else begin
                //enqueue_freelist <= 1'b0;
            end
        end
    end

    always_comb begin
        if(RRF_we && RRF_rd != '0 && RRF_pd != '0 && !freelist_full) begin 
            enqueue_freelist = 1'b1;
            freed_preg = areg_array_rrf_i[RRF_rd];
        end
        else begin 
            enqueue_freelist = 1'b0;
            freed_preg = 'x;
        end
    end

    always_comb begin
        areg_array_rrf = areg_array_rrf_i;
        if(RRF_we && branch_flush && RRF_pd != '0 && RRF_rd != '0 ) areg_array_rrf[RRF_rd] = RRF_pd;
    end

endmodule : RRF
