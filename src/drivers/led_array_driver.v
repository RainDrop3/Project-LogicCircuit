// =======================================================================================
// Module Name: led_array_driver
// Description: 8비트 LED 제어 (Active Low Polarity Handling)
// Target: Combo II-DLD (Cyclone) - 0일 때 LED가 켜짐
// =======================================================================================

module led_array_driver (
    input  wire rst_n,        // Reset (Active Low) - 안전장치
    input  wire [7:0] led_data, // Game Logic Data: 1=ON, 0=OFF (직관적 입력)
    output wire [7:0] led_out   // Hardware Signal: 0=ON, 1=OFF (보드 맞춤형)
);

    // ==========================================
    // Output Logic (Combinational)
    // ==========================================
    // rst_n이 0(Reset)이면: 8'hFF (모두 1 = 모두 OFF)
    // rst_n이 1(Normal)이면: ~led_data (1->0 변환하여 켬)
    assign led_out = (!rst_n) ? 8'hFF : ~led_data;

endmodule