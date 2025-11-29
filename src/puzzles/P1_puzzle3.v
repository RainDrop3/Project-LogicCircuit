// =======================================================================================
// Module Name: phase1_puzzle3
// Description: Phase 3 논리 퍼즐 (Lights Out Game)
// Goal: 모든 LED를 꺼라 (Make led_out == 0x00)
// Logic:
//   - DIP Switch Change -> Toggle Self & Neighbors (XOR Mask)
//   - Display: [Timer] [C A F E]
// =======================================================================================

module phase1_puzzle3 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] dip_sw,        // From DIP Switch Driver
    input wire btn_submit,          // Key 0 (Check Answer)
    input wire [15:0] timer_data,   // From Game Timer (상위 4자리 표시용)
    
    output reg [31:0] seg_data,     // [Timer 4-digit] [CAFE]
    output reg [7:0] led_out,       // Current Puzzle Pattern
    output reg clear,               // Stage Clear
    output reg fail                 // Stage Fail
);

    // ==========================================
    // Parameters & Mask Definitions
    // ==========================================
    // 초기 패턴 (난이도 조절 가능, 0xAA = 10101010)
    localparam INITIAL_PATTERN = 8'hAA; 
    
    // Toggle Masks (Self + Left + Right)
    wire [7:0] toggle_mask [0:7];
    assign toggle_mask[0] = 8'b00000011; // Toggle [0], [1]
    assign toggle_mask[1] = 8'b00000111; // Toggle [0], [1], [2]
    assign toggle_mask[2] = 8'b00001110;
    assign toggle_mask[3] = 8'b00011100;
    assign toggle_mask[4] = 8'b00111000;
    assign toggle_mask[5] = 8'b01110000;
    assign toggle_mask[6] = 8'b11100000;
    assign toggle_mask[7] = 8'b11000000; // Toggle [6], [7]

    // ==========================================
    // Internal Signals
    // ==========================================
    reg [7:0] dip_prev;
    reg puzzle_active;
    reg [7:0] next_led_out; // Combinational Calculation
    integer i;

    // ==========================================
    // Main Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_out <= INITIAL_PATTERN;
            dip_prev <= 0;
            clear <= 0; fail <= 0;
            puzzle_active <= 0;
        end else begin
            if (enable) begin
                clear <= 0; fail <= 0; // Pulse Clear
                
                // 1. Puzzle Initialization (Run Once)
                if (!puzzle_active) begin
                    led_out <= INITIAL_PATTERN;
                    dip_prev <= dip_sw; // Sync current switch state
                    puzzle_active <= 1;
                end else begin
                    // 2. Detect DIP Switch Toggle (Edge Detection)
                    // Blocking Assignment(=) for immediate calculation inside loop
                    next_led_out = led_out; 
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        if (dip_sw[i] != dip_prev[i]) begin
                            // Apply Mask (Toggle Neighbors)
                            next_led_out = next_led_out ^ toggle_mask[i];
                        end
                    end
                    
                    // Update State
                    led_out <= next_led_out;
                    dip_prev <= dip_sw; 
                    
                    // 3. Check Answer (Key 0)
                    if (btn_submit) begin
                        if (led_out == 8'h00) clear <= 1;
                        else                  fail <= 1;
                    end
                end
            end else begin
                // Reset State when disabled
                puzzle_active <= 0;
                clear <= 0; fail <= 0;
            end
        end
    end

    // ==========================================
    // Display Logic (Split View)
    // ==========================================
    always @(*) begin
        if (enable) begin
            // Upper: Timer Value (Passed from Top)
            // Lower: "CAFE" (C=12, A=10, F=15, E=14)
            // Note: 7-Segment Driver converts 0xC -> 'C', etc.
            seg_data = {timer_data, 16'hCAFE}; 
        end else begin
            seg_data = 32'h00000000;
        end
    end

endmodule