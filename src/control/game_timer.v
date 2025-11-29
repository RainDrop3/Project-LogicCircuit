// =======================================================================================
// Module Name: game_timer
// Description: 가변 속도 카운트다운 타이머 (BCD Output)
// Function:
//   - Stability(9~0)에 따라 시간이 줄어드는 속도가 빨라짐 (Penalty)
//   - Stability 9: 1 sec/tick, Stability 0: 0.5 sec/tick
//   - Output Format: [MM][SS] (BCD 16-bit) for direct 7-Segment display
// =======================================================================================

module game_timer (
    input wire clk,
    input wire rst_n,
    input wire game_enable,     // 1: Run, 0: Pause
    input wire timer_reset,     // 1: Reset to 05:00
    input wire [3:0] stability, // 9(Safe) ~ 0(Danger)
    
    output reg [15:0] time_bcd, // {Min_Hi, Min_Lo, Sec_Hi, Sec_Lo}
    output reg time_out         // 1: Time is 00:00 (Game Over)
);

    // ==========================================
    // Parameters
    // ==========================================
    parameter CLK_FREQ      = 50_000_000;
    parameter START_TIME_MM = 8'h05; // 5분
    parameter START_TIME_SS = 8'h00; // 0초
    
    // 시뮬레이션 모드 설정 (1이면 빠른 테스트, 0이면 실전)
    parameter SIM_MODE      = 0; 

    // ==========================================
    // Internal Signals
    // ==========================================
    reg [31:0] tick_cnt;
    reg [31:0] tick_limit;
    reg [7:0] min_val; // BCD Format
    reg [7:0] sec_val; // BCD Format
    
    // Simulation Divider (테스트 시 1000배 빠르게)
    localparam DIVIDER = (SIM_MODE) ? 1000 : 1;

    // ==========================================
    // 1. Tick Limit Calculation (Speed Control)
    // ==========================================
    // Stability가 낮을수록 tick_limit이 줄어들어 시간이 빨리 흐름
    always @(*) begin
        case (stability)
            4'd9: tick_limit = 50_000_000 / DIVIDER; // 1.00x (Normal)
            4'd8: tick_limit = 47_222_222 / DIVIDER;
            4'd7: tick_limit = 44_444_444 / DIVIDER;
            4'd6: tick_limit = 41_666_666 / DIVIDER;
            4'd5: tick_limit = 38_888_888 / DIVIDER;
            4'd4: tick_limit = 36_111_111 / DIVIDER;
            4'd3: tick_limit = 33_333_333 / DIVIDER; // 1.50x
            4'd2: tick_limit = 30_555_555 / DIVIDER;
            4'd1: tick_limit = 27_777_777 / DIVIDER;
            4'd0: tick_limit = 25_000_000 / DIVIDER; // 2.00x (Fastest)
            default: tick_limit = 50_000_000 / DIVIDER;
        endcase
    end

    // ==========================================
    // 2. Countdown Logic (BCD Arithmetic)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_val <= START_TIME_MM;
            sec_val <= START_TIME_SS;
            tick_cnt <= 0;
            time_out <= 0;
        end else begin
            time_out <= 0; // Default Low
            
            if (timer_reset) begin
                min_val <= START_TIME_MM;
                sec_val <= START_TIME_SS;
                tick_cnt <= 0;
            end 
            else if (game_enable) begin
                // Check if time remains
                if (min_val != 0 || sec_val != 0) begin
                    if (tick_cnt >= tick_limit) begin
                        tick_cnt <= 0;
                        
                        // Decrement Second
                        if (sec_val == 0) begin
                            // 00 sec -> 59 sec, Decrement Minute
                            sec_val <= 8'h59;
                            if (min_val != 0) begin
                                // BCD Decrement Logic: 
                                // if low nibble is 0 (e.g., 0x10), subtract 7 to get 0x09
                                // 0x10 - 1 = 0x0F. 0x0F - 6 = 0x09. Total -7.
                                if (min_val[3:0] == 0) min_val <= min_val - 8'h07; 
                                else                   min_val <= min_val - 8'h01;
                            end
                        end else begin
                            // Normal Second Decrement
                            if (sec_val[3:0] == 0) sec_val <= sec_val - 8'h07;
                            else                   sec_val <= sec_val - 8'h01;
                        end
                        
                    end else begin
                        tick_cnt <= tick_cnt + 1;
                    end
                end else begin
                    // Time is 00:00
                    time_out <= 1; 
                end
            end
        end
    end

    // ==========================================
    // 3. Output Assembly
    // ==========================================
    always @(*) begin
        time_bcd = {min_val, sec_val};
    end

endmodule