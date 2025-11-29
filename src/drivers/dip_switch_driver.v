module dip_switch_driver (
    input wire clk,
    input wire rst_n,
    input wire [7:0] dip_in,
    output reg [7:0] dip_out
);

    // ==========================================
    // Parameters
    // ==========================================
    // 20-bit: 2^20 * 20ns = ~21ms (Hardware Default)
    // Simulation ??? ? ?? ???(e.g., 4) ??? ?? ??
    parameter CNTR_WIDTH = 20; 

    // ==========================================
    // 1. Synchronization (Prevent Metastability)
    // ==========================================
    reg [7:0] dip_sync_0;
    reg [7:0] dip_sync_1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dip_sync_0 <= 8'h00;
            dip_sync_1 <= 8'h00;
        end else begin
            dip_sync_0 <= dip_in;
            dip_sync_1 <= dip_sync_0;
        end
    end

    // ==========================================
    // 2. Debouncing (Sampling Method)
    // ==========================================
    reg [CNTR_WIDTH-1:0] debounce_cnt;
    wire sample_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt <= 0;
        end else begin
            debounce_cnt <= debounce_cnt + 1;
        end
    end

    // ???? ?????(? ?? ?)? ??? ? ??? ???
    // CNTR_WIDTH=20? ?, ? 21ms?? sample_tick ??
    assign sample_tick = (debounce_cnt == 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dip_out <= 8'h00;
        end else if (sample_tick) begin
            // ????? ???? ?? ????? ?? ????
            dip_out <= dip_sync_1;
        end
    end

endmodule