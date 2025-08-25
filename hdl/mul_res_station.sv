module mul_reservation_station
import rv32i_types::*;
#(
    parameter STATION_TYPE = 2'b00
)
(
    input logic                             clk,
    input logic                             rst,
    output logic                            stall,

    input logic global_stall,

    input logic                             fu_ready,
    input reservation_station_entry_t       res_station_entry,
    output logic                            entry_received,
    input logic                             entry_ready,

    input cdb_t                             cdb,

    output reservation_station_entry_t      issued_res_station_reg,
    input logic branch_flush
);

logic [1:0] station_type;
assign station_type = STATION_TYPE;

logic temp;
assign temp = global_stall;

reservation_station_entry_t res_station_reg [NUM_MUL];

logic waiting_to_issue;

int free_index;
always_comb begin
    free_index = -1;
    for (int i = 0; i < NUM_MUL; i++) begin
        if (!res_station_reg[i].valid) begin
            free_index = i;
            break;
        end
    end
end

int occupied_ready_index;
always_comb begin
    occupied_ready_index = -1;
    for (int i = 0; i < NUM_MUL; i++) begin
        if (res_station_reg[i].valid && res_station_reg[i].ps1_valid && res_station_reg[i].ps2_valid) begin
            occupied_ready_index = i;
            break;
        end
    end
end

always_ff @(posedge clk) begin
    if(rst || branch_flush) begin
        stall <= '0;
        issued_res_station_reg <= '0;
        for(int i = 0; i < NUM_MUL; i++) begin
            res_station_reg[i] <= '0;
        end
        waiting_to_issue <= '0;
        entry_received <= '0;
    end
    else begin
        if(free_index != -1 
        && res_station_entry.station_index == station_type 
        && entry_ready
        && !entry_received
        && (res_station_reg[0] != res_station_entry
        && res_station_reg[1] != res_station_entry
        && res_station_reg[2] != res_station_entry)
        ) begin
            res_station_reg[free_index] <= res_station_entry;
            res_station_reg[free_index].valid <= '1;
            stall <= '0;
            entry_received <= '1;
            
            if(cdb.preg_index == res_station_entry.ps1) res_station_reg[free_index].ps1_valid <= '1;
            if(cdb.preg_index == res_station_entry.ps2) res_station_reg[free_index].ps2_valid <= '1;

        end else if(free_index == -1 && res_station_entry.station_index == station_type) begin 
            stall <= '1;
        end else begin 
            stall <= '0;
            entry_received <= '0;
        end

        for (int i = 0; i < NUM_MUL; i++) begin
            if(cdb.cdb_valid) begin
                if(cdb.preg_index == res_station_reg[i].ps1) res_station_reg[i].ps1_valid <= '1;
                if(cdb.preg_index == res_station_reg[i].ps2) res_station_reg[i].ps2_valid <= '1;
            end
        end

        if (fu_ready) begin
            if (waiting_to_issue) begin
                // Wait one cycle before issuing the next instruction
                issued_res_station_reg <= '0;
                waiting_to_issue <= '0;
            end else if (occupied_ready_index != -1) begin
                // Issue the instruction from the lowest indexed valid station
                issued_res_station_reg <= res_station_reg[occupied_ready_index];
                res_station_reg[occupied_ready_index].valid <= 0;
                waiting_to_issue <= '1;  // Set the flag to wait one cycle
            end else begin
                issued_res_station_reg <= '0;
            end
        end else begin
            issued_res_station_reg <= '0;
            waiting_to_issue <= '0;
        end

    end
end

endmodule: mul_reservation_station  
