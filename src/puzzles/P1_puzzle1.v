// =======================================================================================
// Module Name: phase1_puzzle1
// Description: Phase 1 산술 연산 퍼즐 (All OR Logic)
// Goal: 8개의 숫자를 연산하여 1을 만들어라 (Display "11111111" -> Result 0xFF)
// Update: 
//   - 모든 연산자를 'OR'로 고정 (숫자 9개 전부 OR 연산)
//   - DIP Switch Active High (1=ON) 로직 유지
// =======================================================================================

module phase1_puzzle1 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] dip_sw,     // 8-bit DIP Switch
    input wire key_valid,        // From Keypad Driver
    input wire [3:0] key_value,  // From Keypad Driver
    input wire [15:0] timer_data,// [Keep] 하위 호환용
    
    output reg [31:0] seg_data,  // To 7-Segment Controller
    output reg [7:0] led_out,    // To LED Array (Mode Indicator)
    output reg clear,            // Stage Clear Signal
    output reg fail,             // Stage Fail Signal
    output reg correct           // Stability Recovery
);

    // ==========================================
    // Parameters & State Definitions
    // ==========================================
    // [참고] 연산자가 OR로 고정되었으므로 OP 파라미터는 사용되지 않음
    localparam KEY_SUBMIT = 4'd0;  // Key 0
    localparam KEY_STAR   = 4'd10; // Key *
    localparam KEY_HASH   = 4'd11; // Key #
    
    localparam TARGET_RESULT = 8'hFF;

    // Puzzle Mode
    // 0: Invert Mode (숫자 반전)
    // 1: Op Change Mode (기능 없음 - OR 고정)
    reg edit_mode; 
    
    // Data Storage
    reg [7:0] nums [0:8]; 
    reg [1:0] ops  [0:7]; // [참고] 저장 공간은 유지하나 계산엔 쓰이지 않음

    // Calculation Variables
    reg [7:0] calc_result;
    integer i;

    // ==========================================
    // 1. Input Processing & State Update
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear <= 0; fail <= 0; correct <= 0;
            
            // 초기 모드: 숫자 변경 (0)
            edit_mode <= 0; 
            led_out <= 8'hFF; 
            
            // 초기값 설정
            nums[0] <= 8'h12; nums[1] <= 8'h34; nums[2] <= 8'h56; 
            nums[3] <= 8'h78; nums[4] <= 8'h9A; nums[5] <= 8'hBC;
            nums[6] <= 8'hDE; nums[7] <= 8'hF0; nums[8] <= 8'hAA;
            
            // ops 초기화 (사용 안함)
            for (i=0; i<8; i=i+1) ops[i] <= 0; 
            
        end else if (enable) begin
            clear <= 0; fail <= 0; correct <= 0;

            if (key_valid) begin
                case (key_value)
                    // --- Submit Answer (Key 0) ---
                    KEY_SUBMIT: begin
                        if (calc_result == TARGET_RESULT) begin
                            clear <= 1; correct <= 1;
                        end else begin
                            fail <= 1; 
                        end
                        edit_mode <= 0; 
                        led_out <= 8'hFF;
                    end
                    
                    // --- Mode Toggle (Key *) ---
                    KEY_STAR: begin
                        edit_mode <= ~edit_mode;
                        if (edit_mode == 0) led_out <= 8'h00; 
                        else                led_out <= 8'hFF; 
                    end
                    
                    KEY_HASH: begin
                        // 예비용
                    end
                    
                    // --- Number Keys (1~8) ---
                    default: begin
                        if (key_value >= 1 && key_value <= 8) begin
                            if (edit_mode == 0) begin
                                nums[key_value - 1] <= ~nums[key_value - 1];
                            end 
                            // [참고] edit_mode == 1일 때 연산자 변경 로직이 있었으나,
                            // 계산식이 OR로 고정되었으므로 아무 동작 안 함.
                        end
                    end
                endcase
            end
        end else begin
             clear <= 0; fail <= 0; correct <= 0;
        end
    end

    // ==========================================
    // 2. Calculation Logic
    // ==========================================
    always @(*) begin
        calc_result = nums[0]; 
        for (i = 0; i < 8; i = i + 1) begin
            // [요청 반영] 딥스위치가 켜져(1) 있으면 무조건 OR 연산 수행
            // 9개의 숫자가 순차적으로 OR 연산됨
            if (dip_sw[i]) begin 
                calc_result = calc_result | nums[i+1];
            end
        end
    end

    // ==========================================
    // 3. Output Assignment (Binary Display)
    // ==========================================
    always @(*) begin
        seg_data = {
            3'd0, calc_result[7], 
            3'd0, calc_result[6],
            3'd0, calc_result[5],
            3'd0, calc_result[4],
            3'd0, calc_result[3],
            3'd0, calc_result[2],
            3'd0, calc_result[1],
            3'd0, calc_result[0]
        };
    end

endmodule
