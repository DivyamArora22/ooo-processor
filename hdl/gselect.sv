module gselect_predictor #(
    parameter HISTORY_LENGTH = 3,
    parameter INDEX = 4,
    parameter PHT_SIZE = 128
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [31:0]           branch_pc,

    input  logic                  branch_taken,
    input  logic [31:0]           branch_taken_pc,
    input  logic                  branch_commit,

    input  logic                  is_branch,
    output logic                  prediction
);

    logic [HISTORY_LENGTH-1:0] ghr;

    logic [1:0] pht [PHT_SIZE-1:0];

    logic [INDEX-1:0] pc_index, pc_index_reg;

    assign pc_index = branch_pc[INDEX+1:2];
    assign pc_index_reg = branch_taken_pc[INDEX+1:2];

    logic [HISTORY_LENGTH+INDEX-1:0] pht_index;
    logic [HISTORY_LENGTH+INDEX-1:0] pht_index_reg;

    assign pht_index    = {pc_index, ghr};
    assign pht_index_reg = {pc_index_reg, ghr};

    always_comb begin
        prediction = 1'b0;
        if (is_branch) begin
            prediction = (pht[pht_index] >= 2'b10);
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            ghr <= '0;
            for (int i = 0; i < PHT_SIZE; i++) begin
                pht[i] <= 2'b01;
            end
        end else if (branch_commit) begin
            //ghr update
            ghr <= {ghr[HISTORY_LENGTH-2:0], branch_taken};

            //pht update
            if (branch_taken) begin
                if (pht[pht_index_reg] < 2'b11) 
                    pht[pht_index_reg] <= pht[pht_index_reg] + 2'b01;
            end else begin
                if (pht[pht_index_reg] > 2'b00) 
                    pht[pht_index_reg] <= pht[pht_index_reg] - 2'b01;
            end
        end
    end

endmodule
