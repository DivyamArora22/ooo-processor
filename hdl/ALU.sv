module ALU 
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,

    input   reservation_station_entry_t alu_res_station_reg,
    output  logic                        alu_ready,

    input   logic [31:0]    alu_ps1_v,
    input   logic [31:0]    alu_ps2_v,

    input   logic           alu_cdb_ready,
    output  logic           alu_cdb_valid,
    output  cdb_t           ALU_cdb,

    input   logic           branch_flush
);

cdb_t ALU_cdb_i;

logic [31:0] a, b;
int branch_taken_counter;
int total_branches_counter;
int misprediction_counter;

assign a = alu_res_station_reg.pc_flag ? alu_res_station_reg.return_pc : alu_ps1_v;
assign b = alu_res_station_reg.imm_flag ? alu_res_station_reg.imms : alu_ps2_v;

/*
always_comb begin
    if(alu_res_station_reg.pc_flag) a = pc_temp;
    else a = alu_ps1_v;
end

always_comb begin
    if(alu_res_station_reg.imm_flag) b = alu_res_station_reg.imms;
    else b = alu_ps2_v;
end
*/

logic signed   [31:0] as;
logic signed   [31:0] bs;
logic unsigned [31:0] au;
logic unsigned [31:0] bu;

logic br_en;

assign as =   signed'(a);
assign bs =   signed'(b);
assign au = unsigned'(a);
assign bu = unsigned'(b);


logic signed   [31:0] ps1_v_signed;
logic signed   [31:0] ps2_v_signed;
logic unsigned [31:0] ps1_v_unsigned;
logic unsigned [31:0] ps2_v_unsigned;

assign ps1_v_signed =   signed'(alu_ps1_v);
assign ps2_v_signed =   signed'(alu_ps2_v);
assign ps1_v_unsigned = unsigned'(alu_ps1_v);
assign ps2_v_unsigned = unsigned'(alu_ps2_v);

//ALU
always_comb begin
    br_en = '0;
    ALU_cdb_i.jalr_return_pc = '0;
    ALU_cdb_i.branch_flag = '0;
    ALU_cdb_i.branch_taken_pc = '0;
    ALU_cdb_i.branch_commit = '0;
    if(alu_res_station_reg.valid) begin
        ALU_cdb_i.cdb_valid = '1;
        unique case (alu_res_station_reg.op)
            alu_op_add: ALU_cdb_i.result = au +   bu;
            alu_op_sll: ALU_cdb_i.result = au <<  bu[4:0];
            alu_op_sra: ALU_cdb_i.result = unsigned'(as >>> bu[4:0]);
            alu_op_sub: ALU_cdb_i.result = au -   bu;
            alu_op_xor: ALU_cdb_i.result = au ^   bu;
            alu_op_srl: ALU_cdb_i.result = au >>  bu[4:0];
            alu_op_or : ALU_cdb_i.result = au |   bu;
            alu_op_and: ALU_cdb_i.result = au &   bu;
            alu_op_slt: begin
                br_en = (as <  bs);
                ALU_cdb_i.result = {31'd0, br_en};
            end
            alu_op_sltu: begin
                br_en = (au <  bu);
                ALU_cdb_i.result = {31'd0, br_en};
            end
            alu_op_jal: ALU_cdb_i.result = alu_res_station_reg.return_pc;
            alu_op_jalr: begin 
                ALU_cdb_i.result = (au +   bu) & 32'hfffffffe;
                ALU_cdb_i.jalr_return_pc = alu_res_station_reg.return_pc;
            end
            default   : ALU_cdb_i.result = '0;
        endcase
        unique case (alu_res_station_reg.cmpop)
            branch_f3_beq : br_en = (ps1_v_unsigned == ps2_v_unsigned);
            branch_f3_bne : br_en = (ps1_v_unsigned != ps2_v_unsigned);
            branch_f3_blt : br_en = (ps1_v_signed <  ps2_v_signed);
            branch_f3_bge : br_en = (ps1_v_signed >=  ps2_v_signed);
            branch_f3_bltu: br_en = (ps1_v_unsigned <  ps2_v_unsigned);
            branch_f3_bgeu: br_en = (ps1_v_unsigned >=  ps2_v_unsigned);
            default       : br_en = '0;
        endcase
        ALU_cdb_i.rob_index = alu_res_station_reg.rob_index;
        ALU_cdb_i.areg_index = alu_res_station_reg.rd;
        ALU_cdb_i.preg_index = alu_res_station_reg.pd;
        if (alu_res_station_reg.opcode == op_b_br ) begin 
            ALU_cdb_i.take_branch =  br_en && alu_res_station_reg.prediction;
        end else ALU_cdb_i.take_branch = '0;

        ALU_cdb_i.branch_taken = br_en && alu_res_station_reg.opcode == op_b_br;
        ALU_cdb_i.branch_taken_pc = alu_res_station_reg.return_pc;
        ALU_cdb_i.branch_commit = (alu_res_station_reg.opcode == op_b_br );

        if(alu_res_station_reg.opcode == op_b_br ) begin
            //misprediction 
            if(br_en != alu_res_station_reg.prediction) begin
                ALU_cdb_i.branch_flag = '1;
                if(br_en) ALU_cdb_i.result = au + bu;
                else ALU_cdb_i.result = au + 4;
            end else begin
                ALU_cdb_i.branch_flag = '0;
            end
        end
        

        ALU_cdb_i.jalr_flag = (alu_res_station_reg.opcode == op_b_jalr) ? 1'b1 : 1'b0;

    end else begin
        ALU_cdb_i = '0;
    end
end

assign alu_ready = alu_cdb_ready;
// assign ALU_cdb_i.branch_flag = (alu_res_station_reg.opcode == op_b_br && br_en) ? 1'b1 : 1'b0;

always_ff @(posedge clk) begin
    if (rst) begin
        branch_taken_counter <= '0;
        total_branches_counter <= '0;
        misprediction_counter <= '0;
    end
    else if (alu_res_station_reg.valid && alu_cdb_ready && alu_res_station_reg.opcode == op_b_br) begin
        total_branches_counter <= total_branches_counter + 1;
        if (br_en) branch_taken_counter <= branch_taken_counter + 1;
        if(br_en != alu_res_station_reg.prediction) misprediction_counter <= misprediction_counter + 1;
    end
end

always_ff @(posedge clk) begin
    if(rst || branch_flush) begin
        alu_cdb_valid <= '0;
        ALU_cdb <= '0;
    end
    else begin
        if(alu_res_station_reg.valid && alu_cdb_ready) begin
            alu_cdb_valid <= '1;
            ALU_cdb <= ALU_cdb_i;
        end
        else if(ALU_cdb.cdb_valid != '0 && !alu_cdb_ready) begin
            alu_cdb_valid <= '1;
            ALU_cdb <= ALU_cdb;
        end
        else if (alu_res_station_reg.valid) begin
            alu_cdb_valid <= '1;
            ALU_cdb <= ALU_cdb;
        end
        else begin
            alu_cdb_valid <= '0;
            ALU_cdb <= '0;
        end
    end
end

endmodule: ALU
