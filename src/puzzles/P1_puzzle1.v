// =======================================================================================
// Module Name: phase1_puzzle1
// Description: Phase 1 산술 연산 퍼즐 (Active High Fixed)
// Goal: 8개의 숫자를 연산하여 1을 만들어라 (Display "11111111" -> Result 0xFF)
// Update: 
//   - DIP Switch 로직을 Active High(1=ON)로 변경하여 직관성 확보
//   - 스위치를 내려야(0) 연산이 꺼짐.
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
    localparam OP_AND = 2'd0;
    localparam OP_OR  = 2'd1;
    localparam OP_XOR = 2'd2;
    
    localparam KEY_SUBMIT = 4'd0;  // Key 0
    localparam KEY_STAR   = 4'd10; // Key *
    localparam KEY_HASH   = 4'd11; // Key #
    
    localparam TARGET_RESULT = 8'hFF;

    // Puzzle Mode
    // 0: Invert Mode (숫자 반전)
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
            
            // 초기 모드: 숫자 변경 (0)
            edit_mode <= 0; 
            led_out <= 8'hFF; 
            
            // 초기값 설정
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
                        // 예비용 (기능 없음)
                    end
                    
                    // --- Number Keys (1~8) ---
                    default: begin
                        if (key_value >= 1 && key_value <= 8) begin
                            if (edit_mode == 0) begin
                                nums[key_value - 1] <= ~nums[key_value - 1];
                            end 
                            else begin
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
            // [수정] Active High 로직 적용 (dip_sw가 1일 때 연산 수행)
            // 스위치를 올려야 해당 단계의 연산이 수행됩니다.
            // 스위치를 내리면(0) 해당 단계는 무시하고 넘어갑니다.
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
        // 결과값의 각 비트를 7-Segment 각 자리에 0 또는 1로 표시
        // 예: calc_result = 0x12 (00010010) -> [0][0][0][1][0][0][1][0] 표시
        
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
