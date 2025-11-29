// =======================================================================================
// Module Name: phase1_puzzle2_dial
// Description: Phase 2 금고 다이얼 퍼즐 (Speed Aim Version)
// Goal: 제한 시간 내에 제시된 랜덤 숫자 위치로 다이얼을 돌려라!
// Display: [Time(sec)] [ _ _ O _ _ _ _ ]
// Update: 빈 공간을 _(언더바)로 표시 (드라이버에서 0xB를 _로 처리)
// =======================================================================================

module phase1_puzzle2_dial (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [11:0] adc_dial_val, // 가변저항 입력
    input wire btn_click,           // 확인 버튼 (Key 0)
    
    output reg [31:0] target_seg_data, // [Time] ... [Target Position]
    output reg [7:0] cursor_led,       // 현재 내 위치 (LED)
    output reg [7:0] servo_angle,      // 물리 피드백
    output reg clear,
    output reg fail
);

    // ==========================================
    // Parameters
    // ==========================================
    parameter TIME_LIMIT_SEC = 5;       // 제한 시간 5초
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
    
    reg [31:0] timer_cnt;   // 카운트다운 타이머
    
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
        current_pos = adc_dial_val[11:9];
        
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
    // Format: [Time] [ _ _ O _ _ _ _ ]
    // ==========================================
    reg [3:0] sec_display;
    
    always @(*) begin
        if (timer_cnt > 0)
            sec_display = (timer_cnt + CLK_FREQ - 1) / CLK_FREQ;
        else
            sec_display = 0;

        if (enable && state != S_DONE) begin
            // 1. 전체를 언더바(_)로 채움. (드라이버에서 B -> _ 매핑)
            target_seg_data[27:0] = {7{4'hB}}; 
            
            // 2. 타겟 위치에 '0' (O 모양) 표시
            // (Digit 7은 타이머 자리이므로 제외/겹침)
            case (target_pos)
                3'd0: target_seg_data[3:0]   = 4'h0;
                3'd1: target_seg_data[7:4]   = 4'h0;
                3'd2: target_seg_data[11:8]  = 4'h0;
                3'd3: target_seg_data[15:12] = 4'h0;
                3'd4: target_seg_data[19:16] = 4'h0;
                3'd5: target_seg_data[23:20] = 4'h0;
                3'd6: target_seg_data[27:24] = 4'h0;
                3'd7: ; // 7번 위치는 타이머 자리와 겹치므로 표시 생략 (난이도 요소)
            endcase
            
            // 3. Digit 7에 타이머(초) 표시 (최우선)
            target_seg_data[31:28] = sec_display[3:0];
            
        end else begin
            target_seg_data = 32'h00000000;
        end
    end

endmodule
