module tournament_predictor #(
    parameter INDEX = 8,
    parameter TABLE_SIZE = 1 << INDEX
)(
    input  logic         clk,
    input  logic         rst,
    input  logic [31:0]  branch_pc,
    input  logic         branch_commit,
    input  logic [31:0]  branch_taken_pc,
    input  logic         branch_taken,
    input  logic         is_branch,
    input  logic         prediction_1,
    input  logic         prediction_2,

    output logic         final_prediction
);

    logic [1:0] selector[TABLE_SIZE-1:0];
    logic [INDEX-1:0] selector_index, selector_index_reg;
    logic predictor1_correct, predictor2_correct;
    logic choosen_predictor;

    assign selector_index = branch_pc[9:2];
    assign selector_index_reg = branch_taken_pc[9:2];

    always_comb begin
        final_prediction = '0;
        if (is_branch) begin
            if (selector[selector_index] >= 2'b10) begin
                final_prediction = prediction_2;
                choosen_predictor = '1;
            end else begin
                final_prediction = prediction_1;
                choosen_predictor = '0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < TABLE_SIZE; i++) begin
                selector[i] <= 2'b01; 
            end
        end else if (branch_commit) begin
            predictor1_correct = (prediction_1 == branch_taken);
            predictor2_correct   = (prediction_2 == branch_taken);

            if (predictor1_correct && !predictor2_correct) begin
                if (selector[selector_index_reg] > 2'b00) begin
                    selector[selector_index_reg] <= selector[selector_index_reg] - 2'b01;
                end
            end 
            else if (!predictor1_correct && predictor2_correct) begin
                if (selector[selector_index_reg] < 2'b11) begin
                    selector[selector_index_reg] <= selector[selector_index_reg] + 2'b01;
                end
            end
        end
    end
endmodule
