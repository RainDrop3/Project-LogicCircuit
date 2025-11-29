    // =======================================================================================
    // Module Name: phase1_puzzle3
    // Description: Phase 3 논리 퍼즐 (DIP Switch Lights Out - Modified Masks)
    // Goal: 모든 LED를 꺼라 (Make led_out == 0x00)
    // Update: SW 1+5, 3+7 조합 무효화 및 초기 패턴 재설정 (0x2B)
    // =======================================================================================

    module phase1_puzzle3 (
        input wire clk,
        input wire rst_n,
        input wire enable,
        input wire [7:0] dip_sw,        // DIP Switch Input
        input wire btn_submit,          // Key 0 (Check Answer)
        input wire [15:0] timer_data,   // [Keep] 화면엔 미표시
        
        output reg [31:0] seg_data,     // [0000] [CAFE]
        output reg [7:0] led_out,       // Current Puzzle Pattern
        output reg clear,               // Stage Clear
        output reg fail                 // Stage Fail
    );

        // ==========================================
        // Parameters
        // ==========================================
        // [수정] 초기 패턴 변경: 0x2B (00101011)
        // 정답: SW 1, 2, 7, 8번을 모두 조작해야 꺼짐
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
                
                switch_masks[0] <= 8'b01001011; // SW 1 (유지)
                switch_masks[1] <= 8'b00010110; // SW 2 (유지)
                switch_masks[2] <= 8'b10101101; // SW 3 (유지)
                switch_masks[3] <= 8'b01011010; // SW 4 (유지)
                
                // [수정] SW 5: 1+5 조합 방지를 위해 패턴 변경 (LED 1번 추가)
                // 3, 5, 6, 8 -> 1, 3, 5, 6, 8 (5개)
                switch_masks[4] <= 8'b10110101; 
                
                switch_masks[5] <= 8'b11101101; // SW 6 (유지)
                
                // [수정] SW 7: 3+7 조합 방지를 위해 패턴 변경 (LED 8번 추가)
                // 2, 5, 7 -> 2, 5, 7, 8 (4개)
                switch_masks[6] <= 8'b11010010; 
                
                switch_masks[7] <= 8'b10100100; // SW 8 (유지)
                
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
                        if (btn_submit) begin
                            if (led_out == 8'h00) clear <= 1;
                            else                  fail <= 1;
                        end
                    end
                end else begin
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
                seg_data = {16'h0000, 16'hCAFE}; 
            end else begin
                seg_data = 32'h00000000;
            end
        end

    endmodule
