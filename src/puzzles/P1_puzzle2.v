// =======================================================================================
// Module Name: phase1_puzzle2_dial
// Description: Phase 2 금고 다이얼 퍼즐 (Full Display & 3s Limit Version)
// Goal: 3초 안에 랜덤 위치 조준!
// Display: [ _ _ _ O _ _ _ _ ] (8자리 전체 사용)
// Update:
//   1. 제한 시간 5초 -> 3초 단축
//   2. 7-Segment 전체(8자리)를 타겟 위치 표시용으로 사용 (타이머 표시 제거)
//   3. 타겟 위치는 '0'(O), 나머지는 '_'(B)로 표시
// =======================================================================================

module phase1_puzzle2_dial (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] adc_dial_val,  // 가변저항 입력 (8-bit from ADC)
    input wire btn_click,           // 확인 버튼 (Key 0)
    
    output reg [31:0] target_seg_data, // [Target Position Map]
    output reg [7:0] cursor_led,       // 현재 내 위치 (LED)
    output reg [7:0] servo_angle,      // 물리 피드백
    output reg clear,
    output reg fail
);

    // ==========================================
    // Parameters
    // ==========================================
    // [수정] 제한 시간 3초로 단축
    parameter TIME_LIMIT_SEC = 3;       
    parameter CLK_FREQ = 50_000_000;    
    parameter MAX_TICK = TIME_LIMIT_SEC * CLK_FREQ; 

    // ==========================================
    // State & Signals
    // ==========================================
    localparam S_INIT = 0;
    localparam S_PLAY = 1;
    localparam S_DONE = 2;

    reg [1:0] state;
    reg [2:0] target_pos;   // 목표 위치 (0~7)
    reg [2:0] current_pos;  // 현재 위치 (0~7)
    
    reg [31:0] timer_cnt;   // 카운트다운 타이머 (내부 동작용)
    
    // LFSR for Random Generation
    reg [15:0] lfsr_reg;
    wire feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];

    // ==========================================
    // Main Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hACE1;
            target_pos <= 0;
            state <= S_INIT;
            timer_cnt <= 0;
            clear <= 0; fail <= 0;
        end else begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            clear <= 0; 
            fail <= 0;

            if (enable) begin
                case (state)
                    S_INIT: begin
                        target_pos <= lfsr_reg[2:0]; 
                        timer_cnt <= MAX_TICK;
                        state <= S_PLAY;
                    end
                    
                    S_PLAY: begin
                        if (timer_cnt > 0) begin
                            timer_cnt <= timer_cnt - 1;
                            if (btn_click) begin
                                if (current_pos == target_pos) begin
                                    clear <= 1;
                                    state <= S_DONE; 
                                end else begin
                                    fail <= 1; 
                                    state <= S_INIT; 
                                end
                            end
                        end else begin
                            // Time Over -> Fail & Restart
                            fail <= 1;
                            state <= S_INIT;
                        end
                    end
                    
                    S_DONE: begin
                    end
                endcase
            end else begin
                state <= S_INIT;
            end
        end
    end

    // ==========================================
    // Input Processing (ADC -> Position)
    // ==========================================
    always @(*) begin
        current_pos = adc_dial_val[7:5]; // Use upper 3 bits to map 8 zones
        
        case (current_pos)
            3'd0: cursor_led = 8'b00000001;
            3'd1: cursor_led = 8'b00000010;
            3'd2: cursor_led = 8'b00000100;
            3'd3: cursor_led = 8'b00001000;
            3'd4: cursor_led = 8'b00010000;
            3'd5: cursor_led = 8'b00100000;
            3'd6: cursor_led = 8'b01000000;
            3'd7: cursor_led = 8'b10000000;
            default: cursor_led = 8'b00000000;
        endcase
        
        servo_angle = current_pos * 8'd25; 
    end

    // ==========================================
    // 7-Segment Display Logic
    // Format: [ _ _ _ O _ _ _ _ ] (8자리 전체 사용)
    // ==========================================
    always @(*) begin
        if (enable && state != S_DONE) begin
            // 1. 전체를 언더바(_)로 초기화 (드라이버에서 B -> _)
            target_seg_data = {8{4'hB}}; 
            
            // 2. 타겟 위치에만 '0' (O 모양) 표시
            // Digit 0 ~ 7 전체 사용 (타이머 표시 없음)
            case (target_pos)
                3'd0: target_seg_data[3:0]   = 4'h0; // Digit 0 (Rightmost)
                3'd1: target_seg_data[7:4]   = 4'h0; 
                3'd2: target_seg_data[11:8]  = 4'h0; 
                3'd3: target_seg_data[15:12] = 4'h0; 
                3'd4: target_seg_data[19:16] = 4'h0; 
                3'd5: target_seg_data[23:20] = 4'h0; 
                3'd6: target_seg_data[27:24] = 4'h0; 
                3'd7: target_seg_data[31:28] = 4'h0; // Digit 7 (Leftmost)
            endcase
            
        end else begin
            target_seg_data = 32'h00000000;
        end
    end

endmodule
