module cdb_arbiter 
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           branch_flush,

    input logic alu_cdb_valid,
    output logic alu_cdb_ready,
    input cdb_t ALU_cdb,

    input logic mul_cdb_valid,
    output logic mul_cdb_ready,
    input cdb_t MUL_cdb,

    input logic ls_cdb_valid,
    output logic ls_cdb_ready,
    input cdb_t LS_cdb,

    output cdb_t cdb

);

cdb_t cdb_reg, cdb_i;
logic cdb_valid_reg;

always_ff @ (posedge clk) begin
     if(rst || branch_flush) begin 
        cdb_valid_reg <= '0;
        cdb_reg <= '0;
     end
     else begin 
        cdb_reg <= cdb;
        if(cdb.cdb_valid) cdb_valid_reg <= cdb.cdb_valid;
        else if(!cdb_i.cdb_valid) cdb_valid_reg <= '0;
     end
end

always_comb begin
    cdb = cdb_i;
    if((cdb_valid_reg && !mul_cdb_valid  && !(cdb_reg.rob_index != cdb_i.rob_index))) cdb.cdb_valid = '0;
end

always_comb begin
    mul_cdb_ready = '1;
    alu_cdb_ready = '1;
    ls_cdb_ready = '1;
    if(mul_cdb_valid) begin
        cdb_i = MUL_cdb;
        alu_cdb_ready = '0;
        ls_cdb_ready = '0;
    end
    else if(ls_cdb_valid) begin
        cdb_i = LS_cdb;
        alu_cdb_ready = '0;
    end
    else if (alu_cdb_valid) begin
        cdb_i = ALU_cdb;
    end
    else cdb_i = cdb_reg;
end

endmodule: cdb_arbiter
