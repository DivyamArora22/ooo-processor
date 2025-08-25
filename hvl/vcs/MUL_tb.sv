module MUL_tb;
import rv32i_types::*;
    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------

    reservation_station_entry_t mul_res_station_reg;

    logic           mul_valid;

    logic   [31:0]  mul_ps1_v;
    logic   [31:0]  mul_ps2_v;

    logic           mul_cdb_ready;
    logic           mul_cdb_valid;

    cdb_t           MUL_cdb;

    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------

    bit clk;
    initial clk = 1'b1;
    always #1 clk = ~clk;    

    int timeout = 1000;

    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------

    bit rst;
    initial begin
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    //---------------------------------------------------------------------------------
    // TODO: Instantiate the DUT and physical memory:
    //---------------------------------------------------------------------------------
    MUL dut(
        .clk            (clk),
        .rst            (rst),

        .mul_res_station_reg(mul_res_station_reg),
        .mul_valid(mul_valid),

        .mul_ps1_v(mul_ps1_v),
        .mul_ps2_v(mul_ps2_v),

        .mul_cdb_ready(mul_cdb_ready),
        .mul_cdb_valid(mul_cdb_valid),
        .MUL_cdb(MUL_cdb)
    );


    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------

    task MUL_op(mul1, mul2);
        logic [31:0] mul1, mul2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_mul;
        mul_cdb_ready <= '1;
        mul_ps1_v <= mul1;
        mul_ps2_v <= mul2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask

    task MULH_op(mulh1, mulh2);
        logic [31:0] mulh1, mulh2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_mulh;
        mul_cdb_ready <= '1;
        mul_ps1_v <= mulh1;
        mul_ps2_v <= mulh2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask
    
    task MULHU_op(mulhu1, mulhu2);
        logic [31:0] mulhu1, mulhu2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_mulhu;
        mul_cdb_ready <= '1;
        mul_ps1_v <= mulhu1;
        mul_ps2_v <= mulhu2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask

    task MULHSU_op(mulhsu1, mulhsu2);
        logic [31:0] mulhsu1, mulhsu2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_mulhsu;
        mul_cdb_ready <= '1;
        mul_ps1_v <= mulhsu1;
        mul_ps2_v <= mulhsu2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask

    task DIV_op(div1, div2);
        logic [31:0] div1, div2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_div;
        mul_cdb_ready <= '1;
        mul_ps1_v <= div1;
        mul_ps2_v <= div2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask

    task REM_op(rem1, rem2);
        logic [31:0] rem1, rem2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_rem;
        mul_cdb_ready <= '1;
        mul_res_station_reg.valid <= '1;
        mul_ps1_v <= rem1;
        mul_ps2_v <= rem2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask
    
    task DIVU_op(divu1, divu2);
        logic [31:0] divu1, divu2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_divu;
        mul_cdb_ready <= '1;
        mul_ps1_v <= divu1;
        mul_ps2_v <= divu2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask

    task REMU_op(remu1, remu2);
        logic [31:0] remu1, remu2;
        mul_res_station_reg.valid <= '1;
        mul_res_station_reg.op <= mul_f3_remu;
        mul_cdb_ready <= '1;
        mul_ps1_v <= remu1;
        mul_ps2_v <= remu2;
        @(posedge clk);
        mul_res_station_reg.valid <= '0;
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    endtask


    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------

    initial begin
        mul_ps1_v <= '0;
        mul_ps2_v <= '0;
        @(posedge clk)
        @(posedge clk)
        MUL_op(32'd1, 32'd1);
        @(posedge clk)
        @(posedge clk)
        @(posedge clk)
        @(posedge clk)
        MULH_op(32'b11000000000000000000000000000000, 32'b11000000000000000000000000000000);
        MULHU_op(32'b11000000000000000000000000000000, 32'b11000000000000000000000000000000);
        MULHSU_op(32'b11000000000000000000000000000000, 32'b11000000000000000000000000000000);
        DIV_op(32'd4, 32'd1);
        REM_op(32'd5, 32'd3);
        DIV_op(32'b11111111111111111111111111111110, 32'b00000000000000000000000000000010);
        DIVU_op(32'b11111111111111111111111111111110, 32'b00000000000000000000000000000010);
        @(posedge clk)
        @(posedge clk)
        $finish;
    end

    always @(posedge clk) begin
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule : MUL_tb

//  MAKEFILE
/*
vcs/MUL_tb: $(VCS_SRCS) $(HDRS)
	mkdir -p vcs
	python3 check_sus.py
	python3 ../bin/rvfi_reference.py
	cd vcs && vcs $(VCS_SRCS) $(VCS_FLAGS) -l compile.log -top MUL_tb -o MUL_tb
	
	cat vcs/xprop.log

.PHONY: run_vcs_MUL_tb
run_vcs_MUL_tb: vcs/MUL_tb $(PROG)
	mkdir -p spike
	rm -f vcs/dump.fsdb
	python3 $(PWD)/../bin/get_options.py clock
	python3 $(PWD)/../bin/get_options.py bmem_x
	export ECE411_CLOCK_PERIOD_PS=$(shell python3 $(PWD)/../bin/get_options.py clock) ;\
	cd vcs && ./MUL_tb -l simulation.log -exitstatus

.PHONY: covrep
covrep: vcs/MUL_tb.vdb
	cd vcs && urg -dir MUL_tb.vdb
*/


