module reservation_station
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
    input   logic                           entry_ready,

    input cdb_t                             cdb,

    output reservation_station_entry_t      issued_res_station_reg,
    input logic branch_flush
);

localparam NUM_STATIONS = 3;
logic flag;

logic temp;
assign temp = global_stall;


logic [1:0] station_type;
assign station_type = STATION_TYPE;

reservation_station_entry_t res_station_reg [NUM_STATIONS];

int free_index;
assign flag = free_index != -1 && res_station_entry.station_index == station_type && !global_stall;

always_comb begin
    free_index = -1;
    for (int i = 0; i < NUM_STATIONS; i++) begin
        if (!res_station_reg[i].valid) begin
            free_index = i;
            break;
        end
    end
end

int occupied_ready_index;
always_comb begin
    occupied_ready_index = -1;
    for (int i = 0; i < NUM_STATIONS; i++) begin
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
        for(int i = 0; i < NUM_STATIONS; i++) begin
            res_station_reg[i] <= '0;
        end
        entry_received <= '0;
    end
    else begin
        if(free_index != -1 
        && res_station_entry.station_index == station_type 
        && entry_ready
        && !entry_received) begin
            res_station_reg[free_index] <= res_station_entry;
            res_station_reg[free_index].valid <= '1;
            stall <= '0;
            entry_received <= '1;

            if(cdb.preg_index == res_station_entry.ps1 
            && cdb.preg_index != '0) res_station_reg[free_index].ps1_valid <= '1;
            if(cdb.preg_index == res_station_entry.ps2
            && cdb.preg_index != '0) res_station_reg[free_index].ps2_valid <= '1;

        end else if(free_index == -1 && res_station_entry.station_index == station_type) begin 
            stall <= '1;
        end else begin 
            stall <= '0;
            entry_received <= '0;
        end

        if(entry_received && res_station_entry.valid) entry_received <= '0;

        for (int i = 0; i < NUM_STATIONS; i++) begin
            if(cdb.cdb_valid) begin
                if(cdb.preg_index == res_station_reg[i].ps1
                && cdb.preg_index != '0) res_station_reg[i].ps1_valid <= '1;
                if(cdb.preg_index == res_station_reg[i].ps2
                && cdb.preg_index != '0) res_station_reg[i].ps2_valid <= '1;
            end
        end

        if(fu_ready) begin
            if(occupied_ready_index != -1) begin
                issued_res_station_reg <= res_station_reg[occupied_ready_index];
                res_station_reg[occupied_ready_index].valid <= '0;
            end
            else issued_res_station_reg <= '0;
        end
        else issued_res_station_reg <= issued_res_station_reg;

    end
end

endmodule: reservation_station  
