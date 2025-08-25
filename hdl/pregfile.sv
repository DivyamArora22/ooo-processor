module pregfile
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    input   logic           branch_flush,

    input   cdb_t           cdb,

    
    input   logic   [PREG_IDX_WIDTH-1:0] alu_ps1_s, alu_ps2_s,
    output  logic   [31:0]  alu_ps1_v, alu_ps2_v,

    input   logic   [PREG_IDX_WIDTH-1:0] mul_ps1_s, mul_ps2_s,
    output  logic   [31:0]  mul_ps1_v, mul_ps2_v,

    input   logic   [PREG_IDX_WIDTH-1:0] ls_ps1_s, ls_ps2_s,
    output  logic   [31:0]  ls_ps1_v, ls_ps2_v
);


    logic                           pregf_we;
    logic   [31:0]                  pd_v;
    logic   [PREG_IDX_WIDTH-1:0]    pd_s;

    logic temp;
    assign temp = branch_flush;

    always_comb  begin
        if(cdb.cdb_valid && cdb.areg_index != '0 && cdb.jalr_flag) begin
            pd_v = cdb.jalr_return_pc;
            pd_s = cdb.preg_index;
            pregf_we = cdb.cdb_valid;
        end
        else begin
            pd_v = cdb.result;
            pd_s = cdb.preg_index;
            pregf_we = cdb.cdb_valid;
        end
    end

    logic   [31:0]  data [NUM_PHYSICAL_REGISTERS-1:0];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 64; i++) begin
                data[i] <= '0;
            end
        end else if (pregf_we && pd_s != '0) begin // do not write to register pd x0
            data[pd_s] <= pd_v;
        end
    end

    always_comb begin
        if (rst) begin
            alu_ps1_v = 'x;
            alu_ps2_v = 'x;
        end 
        else if (alu_ps2_s == pd_s && alu_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            alu_ps1_v = (alu_ps1_s != '0) ? pd_v : '0;
            alu_ps2_v = (alu_ps2_s != '0) ? pd_v : '0;
        end
        else if(alu_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            alu_ps1_v = (alu_ps1_s != '0) ? pd_v : '0 ;
            alu_ps2_v = (alu_ps2_s != '0) ? data[alu_ps2_s] : '0;
        end
        else if (alu_ps2_s == pd_s && pregf_we && pd_s != '0) begin
            alu_ps1_v = (alu_ps1_s != '0) ? data[alu_ps1_s] : '0;
            alu_ps2_v = (alu_ps2_s != '0) ? pd_v : '0 ;
        end
        else begin
            alu_ps1_v = (alu_ps1_s != '0) ? data[alu_ps1_s] : '0;
            alu_ps2_v = (alu_ps2_s != '0) ? data[alu_ps2_s] : '0;
        end
    end

    always_comb begin
        if (rst) begin
            mul_ps1_v = 'x;
            mul_ps2_v = 'x;
        end 
        else if (mul_ps2_s == pd_s && mul_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            mul_ps1_v = (mul_ps1_s != '0) ? pd_v : '0;
            mul_ps2_v = (mul_ps2_s != '0) ? pd_v : '0;
        end
        else if(mul_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            mul_ps1_v = (mul_ps1_s != '0) ? pd_v : '0 ;
            mul_ps2_v = (mul_ps2_s != '0) ? data[mul_ps2_s] : '0;
        end
        else if (mul_ps2_s == pd_s && pregf_we && pd_s != '0) begin
            mul_ps1_v = (mul_ps1_s != '0) ? data[mul_ps1_s] : '0;
            mul_ps2_v = (mul_ps2_s != '0) ? pd_v : '0 ;
        end
        else begin
            mul_ps1_v = (mul_ps1_s != '0) ? data[mul_ps1_s] : '0;
            mul_ps2_v = (mul_ps2_s != '0) ? data[mul_ps2_s] : '0;
        end
    end

    always_comb begin
        if (rst) begin
            ls_ps1_v = 'x;
            ls_ps2_v = 'x;
        end 
        else if (ls_ps2_s == pd_s && ls_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            ls_ps1_v = (ls_ps1_s != '0) ? pd_v : '0;
            ls_ps2_v = (ls_ps2_s != '0) ? pd_v : '0;
        end
        else if(ls_ps1_s == pd_s && pregf_we && pd_s != '0) begin
            ls_ps1_v = (ls_ps1_s != '0) ? pd_v : '0 ;
            ls_ps2_v = (ls_ps2_s != '0) ? data[ls_ps2_s] : '0;
        end
        else if (ls_ps2_s == pd_s && pregf_we && pd_s != '0) begin
            ls_ps1_v = (ls_ps1_s != '0) ? data[ls_ps1_s] : '0;
            ls_ps2_v = (ls_ps2_s != '0) ? pd_v : '0 ;
        end
        else begin
            ls_ps1_v = (ls_ps1_s != '0) ? data[ls_ps1_s] : '0;
            ls_ps2_v = (ls_ps2_s != '0) ? data[ls_ps2_s] : '0;
        end
    end

endmodule : pregfile
