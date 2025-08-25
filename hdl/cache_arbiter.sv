module cache_arbiter
import rv32i_types::*;
(

    input logic clk,
    input logic rst,
    input logic branch_flush,

    //bmem ports
    output  logic   [31:0]       bmem_addr,
    output  logic                bmem_read,
    output  logic                bmem_write,
    output  logic   [63:0]       bmem_wdata,
    input   logic                bmem_ready,

    input   logic   [31:0]       bmem_raddr,
    input   logic   [63:0]       bmem_rdata,
    input   logic                bmem_rvalid,

    //imem_ports
    input   logic   [31:0]       i_bmem_addr,
    input   logic                i_bmem_read,
    output   logic               i_bmem_ready,  

    output   logic   [31:0]      i_bmem_raddr,
    output   logic   [63:0]      i_bmem_rdata,
    output   logic               i_bmem_rvalid,

    output  logic                i_bmem_received,

    //dmem_ports
    input   logic   [31:0]       d_bmem_addr,
    input   logic                d_bmem_read,
    input   logic                d_bmem_write,
    input   logic   [63:0]       d_bmem_wdata,
    output   logic               d_bmem_ready,

    output   logic   [31:0]      d_bmem_raddr,
    output   logic   [63:0]      d_bmem_rdata,
    output   logic               d_bmem_rvalid,

    output  logic                d_bmem_received
);


typedef enum logic [1:0] {
    IDLE,
    SERVICE_I_BMEM,
    SERVICE_D_BMEM
} arbiter_state_t;

arbiter_state_t state, next_state;
logic request_active;
int burst_counter;
logic last_requester;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
    end else begin
        if(branch_flush && burst_counter != 4) state <= state;
        else state <= next_state;
    end
end

always_comb begin
    next_state = state;
    case (state)
        IDLE: begin
            if (last_requester) begin
                if (d_bmem_write || d_bmem_read) begin
                    next_state = SERVICE_D_BMEM;
                end else if (i_bmem_read) begin
                    next_state = SERVICE_I_BMEM;
                end
            end else begin
                if (i_bmem_read) begin
                    next_state = SERVICE_I_BMEM;
                end else if (d_bmem_write || d_bmem_read) begin
                    next_state = SERVICE_D_BMEM;
                end
            end
        end

        SERVICE_I_BMEM: begin
            if (burst_counter == 4) begin
                next_state = IDLE;
            end
        end

        SERVICE_D_BMEM: begin
            if (burst_counter == 4) begin
               next_state = IDLE;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    if (rst) begin
        burst_counter <= '0;
        i_bmem_received <= '0;
        d_bmem_received <= '0;
        bmem_write <= '0;
        request_active <= '0;

        bmem_addr <= '0;
        bmem_read <= '0;
        bmem_write <= '0;
        //bmem_wdata <= '0;

        last_requester <= '0;

    end else begin
        case (state)
            IDLE: begin
                burst_counter <= '0;
                bmem_write <= '0;
                i_bmem_ready <= '1;
                d_bmem_ready <= '1;

                i_bmem_raddr <= '0;
                i_bmem_rdata <= '0;
                i_bmem_rvalid <= '0;
                d_bmem_raddr <= '0;
                d_bmem_rdata <= '0;
                d_bmem_rvalid <= '0;

            end

            SERVICE_I_BMEM: begin
                last_requester <= '1;
                d_bmem_ready <= '0;

                bmem_addr <= i_bmem_addr;
                if(request_active) bmem_read <= '0;
                else bmem_read <= i_bmem_read;
                
                bmem_write <= '0;
                //bmem_wdata <= '0;

                i_bmem_ready <= bmem_ready;
                i_bmem_raddr <= bmem_raddr;
                i_bmem_rdata <= bmem_rdata;
                i_bmem_rvalid <= bmem_rvalid;

                request_active <= '1;
                i_bmem_received <= '1;

                if (bmem_rvalid) begin
                    burst_counter <= burst_counter + 1;
                end
            end

            SERVICE_D_BMEM: begin
                last_requester <= '0;
                i_bmem_ready <= '0;

                bmem_addr <= d_bmem_addr;
                if(request_active) bmem_read <= '0;
                else bmem_read <= d_bmem_read;

                if(request_active) bmem_write <= d_bmem_write;
                //bmem_wdata <= d_bmem_wdata;

                d_bmem_ready <= bmem_ready;
                d_bmem_raddr <= bmem_raddr;
                d_bmem_rdata <= bmem_rdata;
                d_bmem_rvalid <= bmem_rvalid;

                request_active <= '1;
                d_bmem_received <= '1;

                if (bmem_rvalid || (bmem_write && bmem_ready)) begin
                    burst_counter <= burst_counter + 1;
                    if (bmem_write) bmem_write <= '1;
                end
            end
        endcase
        if(burst_counter == 3) bmem_write <= '0;

        if (burst_counter == 4) begin
            request_active <= '0;
            burst_counter <= '0;
            i_bmem_received <= '0;
            d_bmem_received <= '0;
            bmem_write <= '0;
        end
    end
end

always_comb begin
    if (state == SERVICE_D_BMEM && bmem_write) begin
        bmem_wdata = d_bmem_wdata;
    end
    else bmem_wdata = 'x;

end

endmodule : cache_arbiter