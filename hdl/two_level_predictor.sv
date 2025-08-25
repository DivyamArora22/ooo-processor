module two_level_predictor #(
    parameter LHT_SIZE = 256,
    parameter HISTORY_LENGTH = 4,
    parameter PHT_SIZE = 16
)(
    input  logic                  clk,
    input  logic                  rst,
    input  logic [31:0]           branch_pc,      //current branch inst pc
    input  logic                  branch_taken,   //True branch outcome from exec
    input  logic                  branch_commit,  //when branch committed from rob
    input  logic                  is_branch,
    output logic                  prediction      //Prediction
);

    //lht
    logic [HISTORY_LENGTH-1:0] lht [LHT_SIZE-1:0];
    logic [HISTORY_LENGTH-1:0] local_history;

    //pht
    logic [1:0] pht [PHT_SIZE-1:0];
    logic [HISTORY_LENGTH-1:0] pht_index;

    //Prediction
    always_comb begin
        prediction = '0;
        pht_index = '0;
        if (is_branch) begin
            local_history = lht[branch_pc % LHT_SIZE];
            pht_index = local_history;
            prediction = (pht[pht_index] >= 2'b10);
        end
    end

    //Update
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < LHT_SIZE; i++) lht[i] <= '0;
            for (int i = 0; i < PHT_SIZE; i++) pht[i] <= 2'b01;
        end else if (branch_commit) begin
            lht[branch_pc % LHT_SIZE] <= {lht[branch_pc % LHT_SIZE][HISTORY_LENGTH-2:0], branch_taken};
            if (branch_taken) begin
                if (pht[pht_index] < 2'b11) pht[pht_index] <= pht[pht_index] + 1'b1;
            end else begin
                if (pht[pht_index] > 2'b00) pht[pht_index] <= pht[pht_index] - 1'b1;
            end
        end
    end
endmodule