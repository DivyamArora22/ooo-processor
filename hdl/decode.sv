module decode
import rv32i_types::*;
(
    input   logic   [31:0]      instruction,
    
    output  decode_stage_reg_t  decode_reg

);

    logic   [2:0]   funct3;
    logic   [6:0]   funct7;
    logic   [31:0]  i_imm;
    logic   [31:0]  s_imm;
    logic   [31:0]  b_imm;
    logic   [31:0]  u_imm;
    logic   [31:0]  j_imm;



    always_comb                     begin
        decode_reg.funct7   = '0;
        decode_reg.funct3   = instruction[14:12];
        decode_reg.opcode   = instruction[6:0];
        decode_reg.aluop    = 'x;
        decode_reg.mulop    = 'x;
        decode_reg.cmpop    = 'x;
        decode_reg.rd_addr  = instruction[11:7];
        decode_reg.rs1_addr = '0;
        decode_reg.rs2_addr = '0;
        decode_reg.imm      = '0;
        decode_reg.cmpop    = '0;

        funct3   = instruction[14:12];
        funct7   = instruction[31:25];
        i_imm    = {{21{instruction[31]}}, instruction[30:20]};
        s_imm    = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
        b_imm    = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        u_imm    = {instruction[31:12], 12'h000};
        j_imm    = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        unique case (decode_reg.opcode)
            op_b_lui:               begin
                decode_reg.imm = u_imm;
                decode_reg.aluop = alu_op_add;
            end
            op_b_auipc:             begin
                decode_reg.imm = u_imm;
                decode_reg.aluop = alu_op_add;
            end
            op_b_imm, op_b_load: begin
                decode_reg.rs1_addr = instruction[19:15];
                decode_reg.rs2_addr = '0;
                decode_reg.imm = i_imm;
                unique case (funct3)
                    arith_f3_slt : begin
                        decode_reg.aluop = alu_op_slt;
                    end
                    arith_f3_sltu : begin
                        decode_reg.aluop = alu_op_sltu;
                    end
                    arith_f3_sr: begin
                        decode_reg.aluop = (funct7[5]) ? alu_op_sra : alu_op_srl;
                    end
                    arith_f3_sll: begin
                        decode_reg.aluop = {1'b0, funct3};
                    end
                    default: begin
                        decode_reg.aluop = {1'b0, funct3};
                    end
                endcase
            end
            op_b_reg:               begin
                decode_reg.rs1_addr = instruction[19:15];
                decode_reg.rs2_addr = instruction[24:20];
                if(funct7 == multiply) begin
                    decode_reg.funct7 = funct7;
                    decode_reg.mulop = {1'b0, funct3};
                end
                else begin 
                    unique case (funct3) 
                    arith_f3_add: begin
                        decode_reg.aluop = (funct7[5]) ? alu_op_sub : alu_op_add;
                    end
                    arith_f3_sr : begin
                        decode_reg.aluop = (funct7[5]) ? alu_op_sra : alu_op_srl;
                    end
                    arith_f3_slt : begin
                        decode_reg.aluop = alu_op_slt;
                    end
                    arith_f3_sltu : begin
                        decode_reg.aluop = alu_op_sltu;
                    end
                    default: begin
                        decode_reg.aluop = {1'b0, funct3};
                    end
                    endcase
                end
            end
            op_b_jal:    begin
                decode_reg.rs1_addr = '0;
                decode_reg.rs2_addr = '0;
                decode_reg.imm = '0;
                decode_reg.aluop = alu_op_jal;
            end
            op_b_jalr:    begin
                decode_reg.rs1_addr = instruction[19:15];
                decode_reg.rs2_addr = '0;
                decode_reg.imm = i_imm;
                decode_reg.aluop = alu_op_jalr;
            end
            op_b_br:                begin
                decode_reg.rs1_addr = instruction[19:15];
                decode_reg.rs2_addr = instruction[24:20];
                decode_reg.aluop = alu_op_add;
                decode_reg.cmpop = funct3;
                decode_reg.imm = b_imm;
                decode_reg.rd_addr = '0;
            end

            op_b_store:              begin
                decode_reg.rs1_addr = instruction[19:15];
                decode_reg.rs2_addr = instruction[24:20];
                decode_reg.imm = s_imm;
                decode_reg.rd_addr = '0;
            end
            default:                begin
                decode_reg.aluop    = 'x;
                decode_reg.mulop    = 'x;
                decode_reg.rs1_addr = '0;
                decode_reg.rs2_addr = '0;
                decode_reg.imm      = '0;
                decode_reg.cmpop    = '0;
            end
        endcase
    end


endmodule : decode
