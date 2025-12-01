// =======================================================================================
// Module Name: phase1_puzzle3
// Description: Phase 3 논리 퍼즐 (DIP Switch Lights Out - Modified Masks)
// Goal: 모든 LED를 꺼라 (Make led_out == 0x00)
// Update: 
//   - Display: [Timer] [C A F E] (수정됨)
//   - Clear Condition: All LEDs OFF (0x00) (수정됨)
//   - Initial Pattern: 0x2B (Solution: SW 1, 2, 7, 8)
// =======================================================================================

module phase1_puzzle3 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] dip_sw,        // DIP Switch Input
    input wire btn_submit,          // Key 0 (Check Answer)
    input wire [15:0] timer_data,   // Game Timer Input
    
    output reg [31:0] seg_data,     // [Timer] [CAFE]
    output reg [7:0] led_out,       // Current Puzzle Pattern
    output reg clear,               // Stage Clear
    output reg fail                 // Stage Fail
);

    // ==========================================
    // Parameters
    // ==========================================
    // [설정] 초기 패턴: 0x2B (00101011)
    // 목표가 0x00(All Off)일 때, SW 1, 2, 7, 8번을 조작하면 클리어됨
    localparam INITIAL_PATTERN = 8'h2B; 

    // ==========================================
    // Internal Signals
    // ==========================================
    reg [7:0] dip_prev;
    reg puzzle_active;
    reg [7:0] next_led_out; 
    
    // Fixed Mask Storage
    reg [7:0] switch_masks [0:7];
    
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
            
            // 고정 마스크 설정 (Hard Mode)
            // LSB(Bit 0)=LED 1, MSB(Bit 7)=LED 8
            
            switch_masks[0] <= 8'b01001011; // SW 1
            switch_masks[1] <= 8'b00010110; // SW 2
            switch_masks[2] <= 8'b10101101; // SW 3
            switch_masks[3] <= 8'b01011010; // SW 4
            switch_masks[4] <= 8'b10110101; // SW 5
            switch_masks[5] <= 8'b11101101; // SW 6
            switch_masks[6] <= 8'b11010010; // SW 7
            switch_masks[7] <= 8'b10100100; // SW 8
            
        end else begin
            if (enable) begin
                clear <= 0; fail <= 0; 
                
                // 1. Puzzle Initialization
                if (!puzzle_active) begin
                    led_out <= INITIAL_PATTERN;
                    dip_prev <= dip_sw; 
                    puzzle_active <= 1;
                end else begin
                    // 2. Detect DIP Switch Toggle
                    next_led_out = led_out; 
                    
                    for (i = 0; i < 8; i = i + 1) begin
                        if (dip_sw[i] != dip_prev[i]) begin
                            next_led_out = next_led_out ^ switch_masks[i];
                        end
                    end
                    
                    led_out <= next_led_out;
                    dip_prev <= dip_sw; 
                    
                    // 3. Check Answer
                    // [수정] 모든 LED가 꺼져야(0x00) 성공
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
    // Display Logic
    // ==========================================
    always @(*) begin
        if (enable) begin
            // [수정] 왼쪽: 타이머, 오른쪽: CAFE
            // 0xC = 'C', 0xA = 'A', 0xF = 'F', 0xE = 'E'
            seg_data = {timer_data, 16'hCAFE}; 
        end else begin
            seg_data = 32'h00000000;
        end
    end

endmodule
