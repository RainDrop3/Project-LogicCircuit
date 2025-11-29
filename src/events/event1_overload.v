// =======================================================================================
// Module Name: event1_overload
// Description: 돌발 이벤트 1 - 폭탄 과부하 (Overload)
// Situation: 서보모터 180도 급발진 + 경고음
// Solution: CDS 센서를 가려(Dark) 과열을 막아라!
// =======================================================================================

module event1_overload (
    input wire clk,
    input wire rst_n,
    input wire event_start,         // From Game Top (Random Trigger)
    input wire [11:0] cds_value,    // From ADC (0~4095)
    
    output reg [7:0] servo_angle,   // To Servo Driver (Override Phase 2)
    output reg piezo_warn,          // To Piezo Driver (Enable Signal)
    output reg event_success,       // 1 Cycle Pulse
    output reg event_fail,          // 1 Cycle Pulse
    output reg event_active         // 1: Event Running (Mux Control)
);
    // Parameters
    // CDS값은 보드 환경(밝기)에 따라 튜닝 필요. (어두울 때의 값 기준)
    parameter CDS_THRESHOLD = 12'd1000; 
    parameter TIME_LIMIT_SEC = 3;
    parameter CLK_FREQ = 50_000_000;    
    
    parameter OVERLOAD_ANGLE = 8'd180; // 서보모터 튀어오름
    parameter IDLE_ANGLE     = 8'd0;
    
    // 0.25초 주기 (2Hz Beep-Beep)
    // 50MHz * 0.25s = 12,500,000
    parameter BEEP_PERIOD = 12500000;

    // FSM States
    localparam IDLE    = 2'b00;
    localparam WARNING = 2'b01; 
    localparam RESULT  = 2'b10;

    reg [1:0] state;
    reg [31:0] timer_cnt;
    reg [31:0] limit_cnt;
    reg [24:0] beep_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            timer_cnt <= 0; limit_cnt <= 0;
            event_success <= 0; event_fail <= 0; event_active <= 0;
            servo_angle <= IDLE_ANGLE; piezo_warn <= 0; beep_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    event_success <= 0; event_fail <= 0; event_active <= 0;
                    piezo_warn <= 0; timer_cnt <= 0; beep_cnt <= 0;
                    servo_angle <= IDLE_ANGLE;
                    
                    if (event_start) begin
                        state <= WARNING;
                        event_active <= 1;
                        limit_cnt <= TIME_LIMIT_SEC * CLK_FREQ;
                        
                        // [개선] 이벤트 시작과 동시에 삐- 소리 출력 (긴박감 조성)
                        piezo_warn <= 1; 
                    end
                end
                
                WARNING: begin
                    servo_angle <= OVERLOAD_ANGLE; 
                    
                    // --- Piezo Beep Pattern (0.25s Interval) ---
                    if (beep_cnt >= BEEP_PERIOD) begin
                        beep_cnt <= 0;
                        piezo_warn <= ~piezo_warn; // Toggle Sound
                    end else begin
                        beep_cnt <= beep_cnt + 1;
                    end
                    
                    // --- Time Limit Check ---
                    timer_cnt <= timer_cnt + 1;
                    
                    // --- Win/Loss Check ---
                    // 주의: 보드 회로에 따라 어두울 때 ADC 값이 커질 수도 있음.
                    // 현재는 (어두움 < Threshold) 로직 가정
                    if (cds_value < CDS_THRESHOLD) begin
                        event_success <= 1; // 1 Cycle Pulse generated here
                        state <= RESULT;
                    end else if (timer_cnt >= limit_cnt) begin
                        event_fail <= 1;    // 1 Cycle Pulse generated here
                        state <= RESULT;
                    end
                end
                
                RESULT: begin
                    // 1 Cycle Wait to clear flags in next IDLE state
                    event_active <= 0; 
                    piezo_warn <= 0; 
                    servo_angle <= IDLE_ANGLE;
                    state <= IDLE;      
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule