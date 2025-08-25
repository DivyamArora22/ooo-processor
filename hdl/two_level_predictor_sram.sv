module two_level_predictor_s #(
    parameter LHT_SIZE = 256,
    parameter HISTORY_LENGTH = 4,
    parameter PHT_SIZE = 16
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
    logic [7:0] branch_index, branch_index_reg;
    assign branch_index = branch_pc[9:2];

    //lht
    logic lht_valid_array[LHT_SIZE-1:0];
    logic [HISTORY_LENGTH-1:0] lht_dout0,lht_dout0_reg, lht_dout1, lht_dout1_reg;
    logic [HISTORY_LENGTH-1:0] lht_din1;
    logic [$clog2(LHT_SIZE)-1:0] lht_addr0, lht_addr1;
    logic lht_web1;

    //pht
    logic pht_valid_array[PHT_SIZE-1:0];
    logic [1:0] pht_dout0, pht_dout1;
    logic [1:0] pht_din1;
    logic [$clog2(PHT_SIZE)-1:0] pht_addr0, pht_addr1;
    logic pht_web1;

    typedef enum logic [1:0] {
        IDLE_LHT_READ,
        PHT_READ,
        SEND_PREDICTION
    } read_states;

    read_states read_state, read_next_state;

    always_ff @(posedge clk) begin
        if(rst) begin 
            read_state <= IDLE_LHT_READ;
            branch_index_reg <= '0;
            lht_dout0_reg <= '0;
        end else begin 
            read_state <= read_next_state;
            if(read_state == IDLE_LHT_READ && is_branch) branch_index_reg <= branch_index;

            if(read_state == PHT_READ) lht_dout0_reg <= lht_dout0;
        end
    end

    always_comb begin
        read_next_state = read_state;
        lht_addr0 = 'x;
        pht_addr0 = 'x;
        prediction = '0;
        case (read_state) 
            IDLE_LHT_READ : begin
                if(is_branch) read_next_state = PHT_READ;
                else read_next_state = IDLE_LHT_READ;

                lht_addr0 = branch_index;
                pht_addr0 = 'x;

            end
            PHT_READ : begin
                read_next_state = SEND_PREDICTION;
                lht_addr0 = 'x;
                pht_addr0 = lht_dout0;
            end
            SEND_PREDICTION: begin
                read_next_state = IDLE_LHT_READ;
                lht_addr0 = 'x;
                pht_addr0 = lht_dout0_reg;

                
                //if(lht_valid_array[branch_index_reg]) begin
                //   if(pht_valid_array[pht_addr0]) prediction = (pht_dout0 >= 2'b10);
                //end 
            end
        endcase
    end

    logic branch_taken_reg;

    logic [7:0] branch_taken_pc_index, branch_taken_pc_index_reg; 
    assign branch_taken_pc_index = branch_taken_pc[9:2];

    typedef enum logic [1:0] {
        IDLE_LHT_READ_W,
        LHT_WRITE_PHT_READ,
        PHT_WRITE,
        HOLD
    } write_states;

    write_states write_state, write_next_state;
    logic pht_valid;

    always_ff @(posedge clk) begin
        if(rst) begin 
            write_state <= IDLE_LHT_READ_W;
            branch_taken_pc_index_reg <= '0;
            lht_dout1_reg <= '0;

            for (int i = 0; i < LHT_SIZE; i++) lht_valid_array[i] <= '0;
            for (int i = 0; i < PHT_SIZE; i++) pht_valid_array[i] <= '0;

        end else begin 
            write_state <= write_next_state;
            if(write_state == IDLE_LHT_READ_W && branch_commit) begin 
                branch_taken_reg <= branch_taken;
                branch_taken_pc_index_reg <= branch_taken_pc_index;
            end

            if(write_state == LHT_WRITE_PHT_READ) lht_dout1_reg <= lht_dout1;

            if(write_state == PHT_WRITE && !lht_valid_array[lht_addr1]) lht_valid_array[lht_addr1] <= '1;
            if(write_state == PHT_WRITE && pht_valid) pht_valid_array[pht_addr1] <= '1;

        end
    end

    always_comb begin
        write_next_state = write_state;
        lht_addr1 = 'x;
        pht_addr1 = 'x;
        lht_web1 = '1;
        pht_web1 = '1;
        lht_din1 = 'x;
        pht_din1 = 'x;

        pht_valid = '0;
        case (write_state) 
            IDLE_LHT_READ_W : begin
                if (branch_commit) write_next_state = LHT_WRITE_PHT_READ;
                else write_next_state = IDLE_LHT_READ_W;

                lht_addr1 = branch_taken_pc_index;
            end
            LHT_WRITE_PHT_READ : begin
                write_next_state = PHT_WRITE;

                pht_addr1 = lht_dout1;

                lht_addr1 = branch_taken_pc_index;
                lht_web1 = '0;
                if(lht_valid_array[lht_addr1]) lht_din1 = {lht_dout1[HISTORY_LENGTH-2:0], branch_taken_reg};
                else lht_din1 = {3'b000, branch_taken_reg};

            end
            PHT_WRITE : begin
                write_next_state = HOLD;

                lht_addr1 = branch_taken_pc_index;

                if(lht_valid_array[lht_addr1]) begin
                    pht_web1 = '0;
                    pht_addr1 = lht_dout1;
                    if(pht_valid_array[pht_addr1]) begin
                        if (pht_dout1 < 2'b11 && branch_taken_reg)  pht_din1 = pht_dout1 + 1'b1;
                        else pht_din1 = pht_dout1;
                        if (pht_dout1 > 2'b00 && !branch_taken_reg)  pht_din1 = pht_dout1 - 1'b1;
                        else pht_din1 = pht_dout1;
                    end else begin
                        pht_valid = '1;
                        if(branch_taken_reg) pht_din1 = 2'b10;
                        else pht_din1 = 2'b01;
                    end
                end
            end
            HOLD : begin
                if (branch_commit) write_next_state = HOLD;
                else write_next_state = IDLE_LHT_READ_W;
            end
        endcase
    end

    sram_lht lht_table (
        .clk0(clk),
        .csb0(1'b0),
        .web0(1'b1),
        .addr0(lht_addr0),
        .din0('0),
        .dout0(lht_dout0),

        .clk1(clk),
        .csb1(1'b0),
        .web1(lht_web1),
        .addr1(lht_addr1),
        .din1(lht_din1),
        .dout1(lht_dout1)
    );

    sram_pht pht_table (
        .clk0(clk),
        .csb0(1'b0),
        .web0(1'b1),
        .addr0(pht_addr0),
        .din0('0),
        .dout0(pht_dout0),

        .clk1(clk),
        .csb1(1'b0),
        .web1(pht_web1),
        .addr1(pht_addr1),
        .din1(pht_din1),
        .dout1(pht_dout1)
    );



endmodule
