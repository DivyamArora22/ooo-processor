module MUL
import rv32i_types::*;
(   
    input   logic           clk,
    input   logic           rst,

    input   reservation_station_entry_t mul_res_station_reg,
    output  logic                       mul_ready,

    input   logic   [31:0]  mul_ps1_v,
    input   logic   [31:0]  mul_ps2_v,

    input   logic           mul_cdb_ready,
    output  logic           mul_cdb_valid,
    output  cdb_t           MUL_cdb,
    input logic branch_flush
);

    cdb_t MUL_cdb_i;
    cdb_t MUL_cdb_i_reg;

    //  IP parameters
    localparam a_width = 33;    //  width of data
    localparam b_width = 33;    //  width of data
    localparam num_stages = 6;  //  indicates this will take x cycles to reach cdb
    localparam stall_mode = 0;  //  0 = no stalling
    localparam rst_mode = 2;    //  0 = no reset, 1 = async reset, 2 = sync reset
    localparam op_iso_mode = 0; //  controls datapath gating for minPower flow (ignore)
    localparam div_tc = 1;      //  0 = unsigned, 1 = signed (possible source of bug)
    localparam rem_mode = 1;    //  0 = remainder outputs modulus, 1 = remainder outputs remainder

    logic [3:0]  mulop;
    logic [3:0]  mulop_reg;
    logic [32:0] a_in;
    logic [32:0] b_in;
    logic [65:0] product_out;

    logic [32:0] quotient_out;
    logic [32:0] remainder_out;
    logic divide_by_0_flag;

    logic [2:0] counter;        //  edit counters along with num stages to extend

    assign mulop = (counter == 3'd0) ? mul_res_station_reg.op : mulop_reg;

    always_comb             begin
        a_in = 'x;
        b_in = 'x;
        MUL_cdb_i.cdb_valid = '1;
        unique case(mulop)
            mul_f3_mul:     begin
                a_in = {mul_ps1_v[31], mul_ps1_v};
                b_in = {mul_ps2_v[31], mul_ps2_v};
                MUL_cdb_i.result = product_out[31:0];
            end
            mul_f3_mulh:    begin
                a_in = {mul_ps1_v[31], mul_ps1_v};
                b_in = {mul_ps2_v[31], mul_ps2_v};
                MUL_cdb_i.result = product_out[63:32];
            end
            mul_f3_mulhu:  begin
                a_in = {1'b0, mul_ps1_v};
                b_in = {1'b0, mul_ps2_v};
                MUL_cdb_i.result = product_out[63:32];
            end
            mul_f3_mulhsu:     begin
                a_in = {mul_ps1_v[31], mul_ps1_v};
                b_in = {1'b0, mul_ps2_v};
                MUL_cdb_i.result = product_out[63:32];
            end
            mul_f3_div:     begin
                a_in = {mul_ps1_v[31], mul_ps1_v};
                b_in = {mul_ps2_v[31], mul_ps2_v};
                MUL_cdb_i.result = quotient_out[31:0];
                if(divide_by_0_flag) begin
                    MUL_cdb_i.result = '1;          //  return -1
                end
            end
            mul_f3_rem:     begin
                a_in = {mul_ps1_v[31], mul_ps1_v};
                b_in = {mul_ps2_v[31], mul_ps2_v};
                MUL_cdb_i.result = remainder_out[31:0];
                if(divide_by_0_flag) begin
                    MUL_cdb_i.result = mul_ps1_v;   //  return dividend (mul_ps1_v)
                end
            end
            mul_f3_divu:        begin
                a_in = {1'b0, mul_ps1_v};
                b_in = {1'b0, mul_ps2_v};
                MUL_cdb_i.result = quotient_out[31:0];
                if(divide_by_0_flag) begin
                    MUL_cdb_i.result = '1;          //  return 2^32 - 1 (should be all 1's)
                end
            end
            mul_f3_remu:        begin
                a_in = {1'b0, mul_ps1_v};
                b_in = {1'b0, mul_ps2_v};
                MUL_cdb_i.result = remainder_out[31:0];
                if(divide_by_0_flag) begin
                    MUL_cdb_i.result = mul_ps1_v;   //  return dividend (mul_ps1_v)
                end
            end
            default:                begin
                MUL_cdb_i.result = '0;
            end
        endcase
        MUL_cdb_i.rob_index = mul_res_station_reg.rob_index;
        MUL_cdb_i.areg_index = mul_res_station_reg.rd;
        MUL_cdb_i.preg_index = mul_res_station_reg.pd;
    end

    always_ff @(posedge clk) begin
        if(rst || branch_flush) begin
            mul_cdb_valid <= '0;
            MUL_cdb <= '0;
            counter <= '0;
            mul_ready <= '1;
        end
        else begin
            if (mul_res_station_reg.valid && counter == '0) begin
                mul_ready <= '0;
                mulop_reg <= mul_res_station_reg.op;
                counter <= counter + 1'd1;
                MUL_cdb_i_reg.rob_index <= MUL_cdb_i.rob_index;
                MUL_cdb_i_reg.areg_index <= MUL_cdb_i.areg_index;
                MUL_cdb_i_reg.preg_index <= MUL_cdb_i.preg_index;
                if((mulop == 4'd7 || mulop == 4'd6) && divide_by_0_flag) MUL_cdb_i_reg.result <= MUL_cdb_i.result;
            end
            if (counter == 3'd1) counter <= counter + 1'd1;
            else if (counter == 3'd2) counter <= counter + 1'd1;
            else if (counter == 3'd3) counter <= counter + 1'd1;
            else if (counter == 3'd4) counter <= counter + 1'd1;
            else if (counter == 3'd5) begin 
                MUL_cdb.rob_index <= MUL_cdb_i_reg.rob_index;
                MUL_cdb.areg_index <= MUL_cdb_i_reg.areg_index;
                MUL_cdb.preg_index <= MUL_cdb_i_reg.preg_index;
                MUL_cdb.cdb_valid <= MUL_cdb_i.cdb_valid;
                if((mulop == 4'd7 || mulop == 4'd6) && divide_by_0_flag) MUL_cdb.result <= MUL_cdb_i_reg.result;
                else MUL_cdb.result <= MUL_cdb_i.result;
                mul_cdb_valid <= '1;
                counter <= '0;
            end
            if (mul_cdb_ready && mul_cdb_valid) begin
                mul_cdb_valid <= '0;
                MUL_cdb <= '0;
                mul_ready <= '1;
            end
        end
    end

DW_mult_pipe #(a_width, b_width, num_stages, stall_mode, rst_mode, op_iso_mode) mul_i (
    .clk(clk),
    .rst_n(!rst),
    .en('1),
    .tc('1),
    .a(a_in),
    .b(b_in),
    .product(product_out)
);

DW_div_pipe #(a_width, b_width, div_tc, rem_mode, num_stages, stall_mode, rst_mode, op_iso_mode) div_i (
    .clk(clk),
    .rst_n(!rst),
    .en('1),
    .a(a_in),
    .b(b_in),
    .quotient(quotient_out),
    .remainder(remainder_out),
    .divide_by_0(divide_by_0_flag)
);

endmodule : MUL

