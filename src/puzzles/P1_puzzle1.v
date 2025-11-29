// =======================================================================================
// Module Name: phase1_puzzle1
// Description: Phase 1 숫자 연산 퍼즐 (2-Mode Toggle Version)
// Goal: 8개의 비트를 모두 1로 만들어라 (Display "11111111" -> Result 0xFF)
// Update:
//   1. Default(Idle) Mode 제거
//   2. Key *: 반전 모드 <-> 연산자 변경 모드 토글 (Toggle)
//   3. 초기 상태: 반전 모드 (LED ON)
// =======================================================================================

module phase1_puzzle1 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] dip_sw,     // 8-bit DIP Switch
    input wire key_valid,        // From Keypad Driver
    input wire [3:0] key_value,  // From Keypad Driver
    input wire [15:0] timer_data,// [Keep] 포트 유지
    
    output reg [31:0] seg_data,  // To 7-Segment Controller
    output reg [7:0] led_out,    // To LED Array (Mode Indicator)
    output reg clear,            // Stage Clear Signal
    output reg fail,             // Stage Fail Signal
    output reg correct           // Stability Recovery
);

    // ==========================================
    // Parameters & State Definitions
    // ==========================================
    localparam OP_AND = 2'd0;
    localparam OP_OR  = 2'd1;
    localparam OP_XOR = 2'd2;
    
    localparam KEY_SUBMIT = 4'd0;  // Key 0
    localparam KEY_STAR   = 4'd10; // Key *
    localparam KEY_HASH   = 4'd11; // Key #
    
    localparam TARGET_RESULT = 8'hFF;

    // Puzzle Mode
    // 0: Invert Mode (반전 모드) - 초기 상태
    // 1: Op Change Mode (연산자 변경 모드)
    reg edit_mode; 
    
    // Data Storage
    reg [7:0] nums [0:8]; 
    reg [1:0] ops  [0:7]; 

    // Calculation Variables
    reg [7:0] calc_result;
    integer i;

    // ==========================================
    // 1. Input Processing & State Update
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear <= 0; fail <= 0; correct <= 0;
            
            // 초기 모드: 반전 모드 (0)
            edit_mode <= 0; 
            led_out <= 8'hFF; // 반전 모드임으로 LED 켜기
            
            // Puzzle Initialization
            nums[0] <= 8'h12; nums[1] <= 8'h34; nums[2] <= 8'h56; 
            nums[3] <= 8'h78; nums[4] <= 8'h9A; nums[5] <= 8'hBC;
            nums[6] <= 8'hDE; nums[7] <= 8'hF0; nums[8] <= 8'hAA;
            
            for (i=0; i<8; i=i+1) ops[i] <= OP_AND; 
            
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
                        // 제출 후 반전 모드(0)로 초기화 (안전장치)
                        edit_mode <= 0; 
                        led_out <= 8'hFF;
                    end
                    
                    // --- Mode Toggle (Key *) ---
                    KEY_STAR: begin
                        // 0(반전) <-> 1(연산자) 토글
                        edit_mode <= ~edit_mode;
                        
                        // 현재가 0이면 1로 가니까 LED 끄기, 1이면 0으로 가니까 LED 켜기
                        if (edit_mode == 0) led_out <= 8'h00; // To Op Mode
                        else                led_out <= 8'hFF; // To Invert Mode
                    end
                    
                    // --- Key #: 기능 없음 ---
                    KEY_HASH: begin
                    end
                    
                    // --- Number Keys (1~8) ---
                    default: begin
                        if (key_value >= 1 && key_value <= 8) begin
                            if (edit_mode == 0) begin
                                // Mode 0: 숫자 비트 반전 (Invert)
                                nums[key_value - 1] <= ~nums[key_value - 1];
                            end 
                            else begin
                                // Mode 1: 연산자 순환 (Op Change)
                                if (ops[key_value - 1] == OP_XOR) 
                                    ops[key_value - 1] <= OP_AND;
                                else 
                                    ops[key_value - 1] <= ops[key_value - 1] + 1;
                            end
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
            if (dip_sw[i]) begin
                case (ops[i])
                    OP_AND: calc_result = calc_result & nums[i+1];
                    OP_OR : calc_result = calc_result | nums[i+1];
                    OP_XOR: calc_result = calc_result ^ nums[i+1];
                    default: calc_result = calc_result;
                endcase
            end
        end
    end

    // ==========================================
    // 3. Output Assignment (Binary Display)
    // ==========================================
    always @(*) begin
        if (enable) begin
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
        end else begin
            seg_data = 32'h00000000;
        end
    end

endmodule
