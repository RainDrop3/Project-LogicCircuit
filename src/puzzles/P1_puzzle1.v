// =======================================================================================
// Module Name: phase1_puzzle1
// Description: Phase 1 숫자 연산 퍼즐
// Goal: 9개의 숫자와 8개의 연산자를 조합하여 결과값 0xFF 만들기
// Mapping:
//   - Key 1~8: 숫자(N0~N7) 선택 및 수정
//   - Key *: 반전 모드 (숫자 비트 반전)
//   - Key #: 연산자 변경 모드 (AND -> OR -> XOR)
//   - DIP SW: 해당 단계의 연산 수행 여부 (Bypass)
// =======================================================================================

module phase1_puzzle1 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [7:0] dip_sw,     // 8-bit DIP Switch
    input wire key_valid,        // From Keypad Driver
    input wire [3:0] key_value,  // From Keypad Driver
    
    output reg [31:0] seg_data,  // To 7-Segment Controller
    output reg [7:0] led_out,    // To LED Array (Mode Indicator)
    output reg clear,            // Stage Clear Signal
    output reg fail,             // Stage Fail Signal
    output reg correct           // (Optional) Same as clear for this logic
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
    reg [1:0] edit_mode; // 0: Normal, 1: Invert Mode(*), 2: Op Change Mode(#)
    
    // Data Storage
    reg [7:0] nums [0:8]; // 9 Numbers (N0 ~ N8)
    reg [1:0] ops  [0:7]; // 8 Operators (Op0 ~ Op7)

    // Calculation Variables
    reg [7:0] calc_result;
    integer i;

    // ==========================================
    // 1. Input Processing & State Update (Sequential)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear <= 0; fail <= 0; correct <= 0;
            edit_mode <= 0; 
            led_out <= 0;
            
            // Puzzle Initialization (Hardcoded Problem)
            // Goal: Make 0xFF (255)
            nums[0] <= 8'h12; nums[1] <= 8'h34; nums[2] <= 8'h56; 
            nums[3] <= 8'h78; nums[4] <= 8'h9A; nums[5] <= 8'hBC;
            nums[6] <= 8'hDE; nums[7] <= 8'hF0; nums[8] <= 8'hAA;
            
            // Default Operators
            for (i=0; i<8; i=i+1) ops[i] <= OP_AND; 
            
        end else if (enable) begin
            // Pulse Signals Auto-Clear
            clear <= 0; fail <= 0; correct <= 0;

            if (key_valid) begin
                case (key_value)
                    // --- Submit Answer ---
                    KEY_SUBMIT: begin
                        if (calc_result == TARGET_RESULT) begin
                            clear <= 1; 
                            correct <= 1;
                        end else begin
                            fail <= 1;
                        end
                        // Reset Mode
                        edit_mode <= 0; 
                        led_out <= 0;
                    end
                    
                    // --- Enter Invert Mode (*) ---
                    KEY_STAR: begin
                        edit_mode <= 1; 
                        led_out <= 8'hFF; // All LEDs ON
                    end
                    
                    // --- Enter Operator Change Mode (#) ---
                    KEY_HASH: begin
                        edit_mode <= 2; 
                        led_out <= 8'hAA; // Pattern LEDs
                    end
                    
                    // --- Number Keys (1~9) ---
                    default: begin
                        // Valid Keys: 1~8 (Key 9 is System Reset, ignored here)
                        if (key_value >= 1 && key_value <= 8) begin
                            // Array Indexing: Key 1 -> Index 0
                            if (edit_mode == 1) begin
                                // Invert Number Bits
                                nums[key_value - 1] <= ~nums[key_value - 1];
                                edit_mode <= 0; led_out <= 0; // Auto-exit mode
                            end 
                            else if (edit_mode == 2) begin
                                // Rotate Operator: AND -> OR -> XOR
                                if (ops[key_value - 1] == OP_XOR) 
                                    ops[key_value - 1] <= OP_AND;
                                else 
                                    ops[key_value - 1] <= ops[key_value - 1] + 1;
                                
                                edit_mode <= 0; led_out <= 0; // Auto-exit mode
                            end
                        end
                    end
                endcase
            end
        end else begin
             // Disable State
             clear <= 0; fail <= 0; correct <= 0;
        end
    end

    // ==========================================
    // 2. Calculation Logic (Combinational)
    // ==========================================
    // Chain: N0 (op0 N1) (op1 N2) ...
    // DIP SW[i] controls if (op[i] N[i+1]) is executed.
    always @(*) begin
        // Start with the first number
        calc_result = nums[0]; 
        
        // Loop through 8 stages (Op0~7, N1~8, DIP0~7)
        for (i = 0; i < 8; i = i + 1) begin
            if (dip_sw[i]) begin
                // If DIP Switch is ON, perform operation
                case (ops[i])
                    OP_AND: calc_result = calc_result & nums[i+1];
                    OP_OR : calc_result = calc_result | nums[i+1];
                    OP_XOR: calc_result = calc_result ^ nums[i+1];
                    default: calc_result = calc_result;
                endcase
            end else begin
                // If DIP Switch is OFF, Bypass (Maintain previous result)
                calc_result = calc_result; 
            end
        end
    end

    // ==========================================
    // 3. Output Assignment
    // ==========================================
    always @(*) begin
        if (enable) begin
            // Show Result on 7-Segment (Hex)
            // Format: [00] [00] [00] [Result]
            seg_data = {24'h000000, calc_result}; 
        end else begin
            seg_data = 32'h00000000;
        end
    end

endmodule