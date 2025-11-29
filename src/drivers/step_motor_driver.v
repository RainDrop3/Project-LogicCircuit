// =======================================================================================
// Module Name: step_motor_driver
// Description: 유니폴라 스텝 모터 구동 (2-Phase Excitation / Full Step)
// Target: Phase 4 연타 게임 물리 피드백용
// Input: step_pulse는 반드시 1 Clock Cycle 너비의 펄스여야 함 (key_valid 연결 권장)
// =======================================================================================

module step_motor_driver (
    input wire clk,
    input wire rst_n,
    input wire step_pulse,      // 1-Cycle Enable Pulse (Move 1 Step)
    input wire dir,             // 0: CW, 1: CCW (Optional)
    output reg [3:0] motor_phase // Motor Coil Output (A, B, /A, /B)
);
    reg [1:0] step_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_idx <= 0;
            motor_phase <= 4'b0000; // 리셋 시 전원 차단 (Power Saving)
        end else begin
            // 1. Pulse 입력 시 인덱스 변경
            if (step_pulse) begin
                if (dir == 0) step_idx <= step_idx + 1;
                else          step_idx <= step_idx - 1;
            end
            
            // 2. 인덱스에 따른 상(Phase) 출력 (2-Phase Excitation)
            // 토크가 강해 확실한 피드백을 줌
            case (step_idx)
                2'b00: motor_phase <= 4'b1100;
                2'b01: motor_phase <= 4'b0110;
                2'b10: motor_phase <= 4'b0011;
                2'b11: motor_phase <= 4'b1001;
                default: motor_phase <= 4'b0000;
            endcase
        end
    end
endmodule