module cacheline_adapter_tb;
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

    
    logic           ready;
    logic   [31:0]  raddr;
    logic   [63:0]  rdata;
    logic           rvalid;

    logic   [31:0]  addr;
    logic   [255:0] cacheline_data;



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
    cacheline_adapter dut(
        .clk            (clk),
        .rst            (rst),

        .ready          (ready),
        .raddr          (raddr),
        .rdata          (rdata),
        .rvalid         (rvalid),

        .addr           (addr),
        .cacheline_data (cacheline_data)
    );


    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------

    task pleasework(rdata_in, raddr_in);
        logic   [63:0]  rdata_in;
        logic   [31:0]  raddr_in;
        rdata <= rdata_in;
        raddr <= raddr_in;
        rvalid <= '1;
        @(posedge clk);
        $display(cacheline_data);
    endtask

    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------

    initial begin
        rdata <= 'x;
        raddr <= 'x;
        rvalid <= '0;
        @(posedge clk)
        @(posedge clk)
        @(posedge clk)
        @(posedge clk)
        pleasework('1, '0);
        pleasework('0, '0);
        pleasework('1, '0);
        pleasework('0, '0);
        rdata <= 'x;
        raddr <= 'x;
        rvalid <= '0;
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

endmodule : cacheline_adapter_tb




