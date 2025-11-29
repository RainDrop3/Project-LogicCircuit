// =======================================================================================
// Module Name: keypad_parallel_driver
// Description: 12-Key Parallel Keypad Driver (with Mapping Fix)
// Target: Combo II-DLD (Cyclone)
// Fix: ??? ??? ??? ???? ? ?? ??? (S/W Correction)
// =======================================================================================

module keypad_parallel_driver (
    input wire clk,
    input wire rst_n,
    input wire [11:0] key_in,   // KEY01 ~ KEY12 (Physical Pins)
    output reg [3:0] key_value, // 0~9, 10(*), 11(#) (Logical Value)
    output reg key_valid        // Pulse
);
    // 50MHz Clock -> 20ms Debounce
    parameter CNT_MAX = 1000000; 
    
    wire [11:0] key_in_inv;
    wire [11:0] key_clean;
    reg [11:0] key_prev;

    // Active Low Input Inversion
    assign key_in_inv = ~key_in; 

    // ==========================================
    // 1. Parallel Debouncing Logic (12 Keys)
    // ==========================================
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : key_debounce
            reg [19:0] cnt;
            reg sync_0, sync_1;
            reg clean_reg;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    cnt <= 0; clean_reg <= 0; sync_0 <= 0; sync_1 <= 0;
                end else begin
                    sync_0 <= key_in_inv[i];
                    sync_1 <= sync_0;
                    if (sync_1 != clean_reg) begin
                        cnt <= cnt + 1;
                        if (cnt >= CNT_MAX) begin
                            clean_reg <= sync_1;
                            cnt <= 0;
                        end
                    end else begin
                        cnt <= 0;
                    end
                end
            end
            assign key_clean[i] = clean_reg;
        end
    endgenerate

    // ==========================================
    // 2. Key Mapping (Corrected based on Test)
    // ==========================================
    // [??? ?? ??]
    // - 0? ?(??) -> 2? ??? (key_clean[1] -> 2) : key_clean[1]? '0'?? ??
    // - 2? ?(??) -> ? ??(0) (key_clean[10] -> 0) : key_clean[10]? '2'? ??
    // - # ?(??) -> 8? ??? (key_clean[7] -> 8) : key_clean[7]? '#'?? ??
    // - 8? ?(??) -> #? ??? (key_clean[11] -> #) : key_clean[11]? '8'? ??
    // (??? ??? ??? ?? ???? ??)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_prev <= 0; key_valid <= 0; key_value <= 0;
        end else begin
            key_prev <= key_clean; 
            key_valid <= 0;        
            
            // Priority Encoder with FIXED Mapping
            
            // [KEY 1] (??)
            if (key_clean[0] && !key_prev[0]) begin key_value <= 4'd1; key_valid <= 1; end
            
            // [KEY 0] (Physical 0 -> Pin Index 1) - ??? 2???? ??
            else if (key_clean[1] && !key_prev[1]) begin key_value <= 4'd0; key_valid <= 1; end
            
            // [KEY 3] (??)
            else if (key_clean[2] && !key_prev[2]) begin key_value <= 4'd3; key_valid <= 1; end
            
            // [KEY 4] (??)
            else if (key_clean[3] && !key_prev[3]) begin key_value <= 4'd4; key_valid <= 1; end
            
            // [KEY 5] (??)
            else if (key_clean[4] && !key_prev[4]) begin key_value <= 4'd5; key_valid <= 1; end
            
            // [KEY 6] (??)
            else if (key_clean[5] && !key_prev[5]) begin key_value <= 4'd6; key_valid <= 1; end
            
            // [KEY 7] (??)
            else if (key_clean[6] && !key_prev[6]) begin key_value <= 4'd7; key_valid <= 1; end
            
            // [KEY #] (Physical # -> Pin Index 7) - ??? 8???? ??
            else if (key_clean[7] && !key_prev[7]) begin key_value <= 4'd11; key_valid <= 1; end
            
            // [KEY 9 (Reset)] (Physical 9 -> Pin Index 8) - Ignored (Handled by rst_n)
            // else if (key_clean[8] && !key_prev[8]) ...
            
            // [KEY *] (??)
            else if (key_clean[9] && !key_prev[9]) begin key_value <= 4'd10; key_valid <= 1; end
            
            // [KEY 2] (Physical 2 -> Pin Index 10) - ??? 0???? ??
            else if (key_clean[10] && !key_prev[10]) begin key_value <= 4'd2; key_valid <= 1; end
            
            // [KEY 8] (Physical 8 -> Pin Index 11) - ??? #???? ??
            else if (key_clean[11] && !key_prev[11]) begin key_value <= 4'd8; key_valid <= 1; end
        end
    end
endmodule