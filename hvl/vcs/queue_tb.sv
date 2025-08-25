import "DPI-C" function string getenv(input string env_name);

module queue_tb;

    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps = getenv("ECE411_CLOCK_PERIOD_PS").atoi() / 2;

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;

    int timeout = 10000; // in cycles, change according to your needs

    parameter DATA_WIDTH = 32;
    parameter QUEUE_DEPTH = 64;
    logic [DATA_WIDTH-1:0] wdata, rdata;
    logic full,empty, enqueue, dequeue;

    queue #(.DATA_WIDTH(DATA_WIDTH), .QUEUE_DEPTH(QUEUE_DEPTH))
    dut(
        .*
    );

    task automatic randomize_queue_request();
        bit [2:0] enqueue_or_dequeue;
        std::randomize(enqueue_or_dequeue);
        if(rst) wdata <= '0;
        else if(enqueue != '0) wdata <= wdata + 1;
        else wdata <= wdata;

        if(enqueue_or_dequeue != 3'b000) begin //write
            enqueue <= '1;
            dequeue <= '0;
        end
        else begin //read
            dequeue <= '1;
            enqueue <= '0;
        end
    endtask

    task automatic enqueue_while_full();
        enqueue <= '0;
        dequeue <= '0;
        wdata <= '0;

        for(int i = 0; i < 80; i++) begin
            @(posedge clk) begin
                enqueue <= '1;
                wdata <= i;
            end
        end

        enqueue <= '0;
        dequeue <= '1;
        wdata <= '0;

        for(int i = 0; i < 80; i++) begin
            @(posedge clk) begin
                dequeue <= '1;
                if(rdata > 63) begin
                    $error("Value larger than 63 received");
                    $finish;
                end
            end
        end

        $finish;

    endtask

    task automatic dequeue_while_empty();
        enqueue <= '0;
        dequeue <= '0;
        wdata <= '0;

        for(int i = 0; i < 32; i++) begin
            @(posedge clk) begin
                enqueue <= '1;
                wdata <= i;
            end
        end

        enqueue <= '0;
        dequeue <= '1;
        wdata <= '0;

        for(int i = 0; i < 80; i++) begin
            @(posedge clk) begin
                dequeue <= '1;
                if(rdata > 30) begin
                    $error("Value larger than 30 received");
                    $finish;
                end
            end
        end

        $finish;

    endtask
    

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        dequeue <= '0;
        enqueue <= '0;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        randomize_queue_request();
        //enqueue_while_full();
        //dequeue_while_empty();
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $finish;
        end
        timeout <= timeout - 1;
    end

endmodule
