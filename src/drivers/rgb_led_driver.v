// =======================================================================================
// Module Name: rgb_led_driver
// Description: 4개의 RGB LED 동시 제어 (Stability Indicator)
// Target Board: Combo II-DLD (Active Low: 0=ON)
// Function: 
//    - color_sel[2]: Red, [1]: Green, [0]: Blue
//    - blink_en: 1일 경우 깜빡임 (Event 발생 시 사용)
// =======================================================================================

module rgb_led_driver (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [2:0] color_sel, // [2]:R, [1]:G, [0]:B
    input  wire       blink_en,  // 1: Blink ON, 0: Steady
    
    // 4개의 RGB LED를 동시에 제어하기 위해 4-bit 출력으로 변경
    output wire [3:0] r_out,
    output wire [3:0] g_out,
    output wire [3:0] b_out
);
    // Parameters
    // 50MHz Clock -> 0.5s Period (1Hz Blink)
    parameter BLINK_MAX = 25000000; 
    
    reg [24:0] cnt;
    reg blink_state;
    reg mask; 

    // ==========================================
    // 1. Blink Timer
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt <= 0;
            blink_state <= 1'b1; // Reset 시 켜진 상태로 시작
        end else begin
            if(cnt >= BLINK_MAX) begin
                cnt <= 0;
                blink_state <= ~blink_state;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end

    // ==========================================
    // 2. Output Logic (Masking & Expansion)
    // ==========================================
    always @(*) begin
        // 깜빡임 모드일 때는 blink_state를 마스크로 사용
        if (blink_en) mask = blink_state;
        else          mask = 1'b1; // 항상 켜짐
    end

    // Active Low Output Generation
    // ~(color_bit & mask) -> 마스크가 1이고 컬러비트가 1일 때만 0(ON) 출력
    // {4{...}} 문법을 사용하여 1비트 결과를 4비트로 복제 (Replication)
    assign r_out = {4{ ~(color_sel[2] & mask) }};
    assign g_out = {4{ ~(color_sel[1] & mask) }};
    assign b_out = {4{ ~(color_sel[0] & mask) }};

endmodule