// =======================================================================================
// Module Name: phase1_puzzle2_dial
// Description: Phase 2 금고 다이얼 퍼즐 (Keypad Steering Edition)
// Goal: 키패드 1/2를 눌러 서보를 좌/우로 이동시키고, LED와 세그먼트가 일치할 때 Key 0으로 확정
// Display: [ _ _ _ O _ _ _ _ ] (8자리 전체 사용)
// Update:
//   1. 아날로그 다이얼 입력 제거, Key1/Key2 홀드 기반 서보 제어
//   2. 서보 각도를 8등분하여 LED 1~8을 해당 위치만 점등
//   3. 한 라운드 성공/실패 과정을 5번 반복해야 퍼즐 클리어
// =======================================================================================

module phase1_puzzle2_dial (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire btn_left_hold,       // Keypad 1 (hold = move left)
    input wire btn_right_hold,      // Keypad 2 (hold = move right)
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
    // [유지] 제한 시간 3초
    parameter TIME_LIMIT_SEC = 3;       
    parameter CLK_FREQ = 50_000_000;    
    parameter MAX_TICK = TIME_LIMIT_SEC * CLK_FREQ; 
    parameter integer TOTAL_ROUNDS = 5;
    parameter integer MOVE_INTERVAL = 250_000; // ~5ms per step at 50MHz

    // ==========================================
    // State & Signals
    // ==========================================
    localparam S_INIT = 0;
    localparam S_PLAY = 1;
    localparam S_DONE = 2;

    reg [1:0] state;
    reg [2:0] target_pos;   // 목표 위치 (0~7)
    reg [2:0] servo_zone;   // 현재 서보 위치 (0~7)
    reg [2:0] round_count;  // 진행된 라운드 수
    reg [18:0] move_cnt;    // 좌/우 이동 속도 제어
    reg round_done;
    reg round_success;
    
    reg [31:0] timer_cnt;   // 카운트다운 타이머 (내부 동작용)
    
    // LFSR for Random Generation
    reg [15:0] lfsr_reg;
    wire feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];

    // ==========================================
    // Main Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg    <= 16'hACE1;
            target_pos  <= 3'd0;
            timer_cnt   <= 32'd0;
            state       <= S_INIT;
            round_count <= 3'd0;
            clear       <= 1'b0;
            fail        <= 1'b0;
        end else begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            clear    <= 1'b0;
            fail     <= 1'b0;

            if (!enable) begin
                state       <= S_INIT;
                round_count <= 3'd0;
            end else begin
                case (state)
                    S_INIT: begin
                        target_pos <= lfsr_reg[2:0];
                        timer_cnt  <= MAX_TICK;
                        state      <= S_PLAY;
                    end

                    S_PLAY: begin
                        round_done    = 1'b0;
                        round_success = 1'b0;

                        if (timer_cnt == 0) begin
                            round_done    = 1'b1;
                            round_success = 1'b0;
                        end else if (btn_click) begin
                            round_done    = 1'b1;
                            round_success = (servo_zone == target_pos);
                        end else begin
                            timer_cnt <= timer_cnt - 1;
                        end

                        if (round_done) begin
                            if (!round_success)
                                fail <= 1'b1;

                            if (round_count == TOTAL_ROUNDS-1) begin
                                clear <= 1'b1;
                                state <= S_DONE;
                            end else begin
                                round_count <= round_count + 1'b1;
                                state <= S_INIT;
                            end
                        end
                    end

                    S_DONE: begin
                        // 유지: enable이 내려가면 상위 FSM이 초기화하면서 다시 시작
                    end
                endcase
            end
        end
    end

    // ==========================================
    // Keypad Steering -> Servo Angle
    // ==========================================
    wire move_left  = btn_left_hold  && !btn_right_hold;
    wire move_right = btn_right_hold && !btn_left_hold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            servo_zone <= 3'd3;
            move_cnt   <= 0;
        end else begin
            if (!enable || state == S_INIT) begin
                servo_zone <= 3'd3;
                move_cnt   <= 0;
            end else if (state == S_PLAY) begin
                if (move_left || move_right) begin
                    if (move_cnt >= MOVE_INTERVAL) begin
                        move_cnt <= 0;
                        if (move_left && servo_zone > 0)
                            servo_zone <= servo_zone - 1'b1;
                        else if (move_right && servo_zone < 3'd7)
                            servo_zone <= servo_zone + 1'b1;
                    end else begin
                        move_cnt <= move_cnt + 1'b1;
                    end
                end else begin
                    move_cnt <= 0;
                end
            end else begin
                move_cnt <= 0;
            end
        end
    end

    // ==========================================
    // Input Processing (Servo -> LED / Angle)
    // ==========================================
    always @(*) begin
        if (!enable) begin
            cursor_led = 8'b0000_0000;
            servo_angle = 8'd90; // 중앙 유지
        end else begin
            cursor_led = 8'b0000_0001 << servo_zone;
            servo_angle = servo_zone * 8'd25;
        end
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
