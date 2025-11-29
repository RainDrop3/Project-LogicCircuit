// =======================================================================================
// Module Name: phase1_puzzle1
// Description: Phase 1 숫자 연산 퍼즐 (Mode Toggle Update)
// Goal: 8개의 비트를 모두 1로 만들어라 (Display "11111111" -> Result 0xFF)
// Update:
//   1. Key *: 모드 순환 (Mode 0 -> Mode 1[Invert] -> Mode 2[Op Change] -> Mode 0)
//   2. Key #: 기능 제거
//   3. Mode Persistence: 숫자 키를 눌러도 모드가 유지됨 (연속 수정 가능)
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

    // Puzzle State
    // 0: Idle (No Edit)
    // 1: Invert Mode (숫자 반전)
    // 2: Op Change Mode (연산자 변경)
    reg [1:0] edit_mode; 
    
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
            edit_mode <= 0; 
            led_out <= 0;
            
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
                        // 제출 시 모드 초기화
                        edit_mode <= 0; led_out <= 0;
                    end
                    
                    // --- Mode Toggle (Key *) ---
                    KEY_STAR: begin
                        if (edit_mode == 0) begin
                            // Mode 1: Invert Mode (LED ON)
                            edit_mode <= 1; 
                            led_out <= 8'hFF; 
                        end else if (edit_mode == 1) begin
                            // Mode 2: Op Change Mode (LED OFF - 요청사항 반영)
                            edit_mode <= 2; 
                            led_out <= 8'h00; 
                        end else begin
                            // Back to Mode 0: Idle
                            edit_mode <= 0; 
                            led_out <= 8'h00;
                        end
                    end
                    
                    // --- Function Removed (Key #) ---
                    KEY_HASH: begin
                        // 아무 기능 없음
                    end
                    
                    // --- Number Keys (1~8) ---
                    default: begin
                        if (key_value >= 1 && key_value <= 8) begin
                            if (edit_mode == 1) begin
                                // Mode 1: 숫자 비트 반전
                                nums[key_value - 1] <= ~nums[key_value - 1];
                                // 모드 유지 (연속 입력 가능)
                            end 
                            else if (edit_mode == 2) begin
                                // Mode 2: 연산자 순환 (AND -> OR -> XOR -> AND...)
                                if (ops[key_value - 1] == OP_XOR) 
                                    ops[key_value - 1] <= OP_AND;
                                else 
                                    ops[key_value - 1] <= ops[key_value - 1] + 1;
                                // 모드 유지 (연속 입력 가능)
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
            // 8비트 결과를 8개의 7-세그먼트 자리에 펼쳐서 표시 (MSB -> LSB)
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
