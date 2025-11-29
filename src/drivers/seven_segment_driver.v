// =======================================================================================
// Module Name: single_seven_segment_driver
// Description: 단일 7-Segment 제어 (Stability 표시용)
// Target: Combo II-DLD (Active Low: 0=ON 가정)
// =======================================================================================

module single_seven_segment_driver (
    input  wire [3:0] hex_value, // 표시할 값 (0~F)
    input  wire       dp_in,     // Dot Point 제어 (1=ON)
    output reg  [7:0] seg_out    // 실제 물리적 출력 (gfedcba + dp)
);

    // ==========================================
    // Parameters
    // ==========================================
    // 1: Active Low (0=ON, Common Anode) - Combo II Default
    // 0: Active High (1=ON, Common Cathode)
    parameter ACTIVE_LOW = 1;

    reg [7:0] seg_decode; // 극성 적용 전 순수 패턴 (1=ON)

    // ==========================================
    // 1. Segment Decoding (Hex -> Pattern)
    // ==========================================
    // Active High 기준 패턴 (1이 켜짐)
    always @(*) begin
        case(hex_value)
            //                  abcdefgh (h=dp)
            4'h0: seg_decode = 8'b11111100;
            4'h1: seg_decode = 8'b01100000;
            4'h2: seg_decode = 8'b11011010;
            4'h3: seg_decode = 8'b11110010;
            4'h4: seg_decode = 8'b01100110;
            4'h5: seg_decode = 8'b10110110;
            4'h6: seg_decode = 8'b10111110;
            4'h7: seg_decode = 8'b11100000;
            4'h8: seg_decode = 8'b11111110;
            4'h9: seg_decode = 8'b11110110;
            4'hA: seg_decode = 8'b11101110;
            4'hB: seg_decode = 8'b00111110;
            4'hC: seg_decode = 8'b10011100;
            4'hD: seg_decode = 8'b01111010;
            4'hE: seg_decode = 8'b10011110;
            4'hF: seg_decode = 8'b10001110;
            default: seg_decode = 8'b00000000;
        endcase
        
        // DP 처리 (1이면 켜짐)
        if(dp_in) seg_decode[0] = 1'b1;
        else      seg_decode[0] = 1'b0;
    end

    // ==========================================
    // 2. Output Generation (Polarity Handling)
    // ==========================================
    always @(*) begin
        if (ACTIVE_LOW) begin
            // Active Low: 0일 때 켜짐 -> 패턴 반전
            seg_out = ~seg_decode;
        end else begin
            // Active High: 1일 때 켜짐 -> 그대로 출력
            seg_out = seg_decode;
        end
    end

endmodule