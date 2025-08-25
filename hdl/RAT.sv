module RAT
import rv32i_types::*;
(
    input   logic               clk,
    input   logic               rst,

    //dispatch/rename or CDB ports
    input   logic [4:0]                     RAT_rd,
    input   logic [PREG_IDX_WIDTH - 1:0]    RAT_pd,
    input   logic                           RAT_we,

    //dispatch/rename ports
    input   logic [4:0]                     RAT_rs1,
    output  logic [PREG_IDX_WIDTH - 1:0]    RAT_ps1,
    output  logic                           RAT_ps1_valid,

    input   logic [4:0]                     RAT_rs2,
    output  logic [PREG_IDX_WIDTH - 1:0]    RAT_ps2,
    output  logic                           RAT_ps2_valid,

    input   cdb_t                           cdb,
    input   free_list_entry_t               areg_array_rrf[32],
    input   logic                           branch_flush

);
    free_list_entry_t areg_array [32];
    logic valid_array [32];

    always_ff @(posedge clk) begin
        if (rst) begin
            // set invalid to every entry and point to 0
            for (int i = 0; i < 32; i++) begin
                valid_array[i] <= 1'b1;
                areg_array[i] <= free_list_entry_t'(i);
            end
        end
        else if (branch_flush) begin
            for (int i=0; i < 32; i++) begin
                areg_array[i] <= areg_array_rrf[i];
                valid_array[i] <= '1;
            end
        end
        else begin

            // commit phase
            if(cdb.cdb_valid && areg_array[cdb.areg_index] == cdb.preg_index) begin
                valid_array[cdb.areg_index] <= 1'b1;
            end
            // renaming case
            if (RAT_we && RAT_rd != '0 && RAT_pd != '0) begin //do not rename rd x0 or pd x0
                areg_array[RAT_rd] <= RAT_pd;
                valid_array[RAT_rd] <= 1'b0;
            end
        end
    end

    // fetching operand
    always_comb begin
    if(cdb.cdb_valid && cdb.preg_index == RAT_ps1) RAT_ps1_valid = '1;
    else RAT_ps1_valid = valid_array[RAT_rs1];

    if(cdb.cdb_valid && cdb.preg_index == RAT_ps2) RAT_ps2_valid = '1;
    else RAT_ps2_valid = valid_array[RAT_rs2];
    end

    assign RAT_ps1 = areg_array[RAT_rs1];
    assign RAT_ps2 = areg_array[RAT_rs2];
    
endmodule : RAT

