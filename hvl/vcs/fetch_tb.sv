import "DPI-C" function string getenv(input string env_name);

module fetch_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000; // in cycles, change according to your needs
    
    mem_itf_banked bmem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(bmem_itf));


    cpu dut(
        .clk(clk),
        .rst(rst),

        .bmem_addr(bmem_itf.addr),
        .bmem_read(bmem_itf.read),
        .bmem_write(bmem_itf.write),
        .bmem_wdata(bmem_itf.wdata),
        .bmem_ready(bmem_itf.ready),

        .bmem_raddr(bmem_itf.raddr),
        .bmem_rdata(bmem_itf.rdata),
        .bmem_rvalid(bmem_itf.rvalid)
    );


    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end


    always @(posedge clk) begin
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
