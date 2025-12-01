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
    parameter DROP_MARGIN   = 12'd100;   // 이벤트 시작 대비 필수 조도 하락 폭
    parameter integer SERVO_STEP_PERIOD = 200_000; // 이벤트2와 동일한 서보 스텝 주기 (clk 사이클)
    
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
    reg [31:0] servo_step_cnt;       // 서보 각도 증가 주기를 세는 카운터
    reg [24:0] beep_cnt;
    reg [11:0] ambient_level;        // 이벤트 시작 시점의 밝기 스냅샷
    reg [11:0] live_cds_value;       // 이벤트 진행 중 실시간으로 들어오는 밝기 값

    wire drop_success;
    wire servo_reach_next;
    // 어두워졌는지 판단: 시작 밝기 대비 100 이상 낮아졌으면 성공 조건 만족
    assign drop_success = (ambient_level > live_cds_value) &&
                          ((ambient_level - live_cds_value) >= DROP_MARGIN);
    // 서보가 180도에 도달했는지 판단
    assign servo_reach_next = (servo_angle >= OVERLOAD_ANGLE) ||
                              ((servo_angle == OVERLOAD_ANGLE - 1) && (servo_step_cnt >= SERVO_STEP_PERIOD));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            event_success <= 0; event_fail <= 0; event_active <= 0;
            servo_angle <= IDLE_ANGLE; piezo_warn <= 0; beep_cnt <= 0;
            ambient_level <= 0; live_cds_value <= 0;
            servo_step_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    event_success <= 0; event_fail <= 0; event_active <= 0;
                    piezo_warn <= 0; beep_cnt <= 0;
                    servo_angle <= IDLE_ANGLE;
                    servo_step_cnt <= 0;
                    
                    // 이벤트 트리거 감지 시 경고 상태 진입
                    if (event_start) begin
                        state <= WARNING;
                        event_active <= 1;
                        ambient_level <= cds_value;
                        live_cds_value <= cds_value;
                        
                        // [개선] 이벤트 시작과 동시에 삐- 소리 출력 (긴박감 조성)
                        piezo_warn <= 1; 
                    end
                end
                
                WARNING: begin
                    live_cds_value <= cds_value;
                    
                    // --- Piezo Beep Pattern (0.25s Interval) ---
                    // 경고음 토글 주기 체크
                    if (beep_cnt >= BEEP_PERIOD) begin
                        beep_cnt <= 0;
                        piezo_warn <= ~piezo_warn; // Toggle Sound
                    end else begin
                        beep_cnt <= beep_cnt + 1;
                    end
                    
                    // --- Win/Loss Check ---
                    // 밝기가 충분히 어두워졌으면 성공
                    if (drop_success) begin
                        event_success <= 1;
                        state <= RESULT;
                    // 서보가 180도에 도달하면 실패
                    end else if (servo_reach_next) begin
                        servo_angle <= OVERLOAD_ANGLE;
                        servo_step_cnt <= 0;
                        event_fail <= 1;
                        state <= RESULT;
                    end else begin
                        // 서보 스텝 타이밍 체크 후 각도 증가
                        if (servo_step_cnt >= SERVO_STEP_PERIOD) begin
                            servo_step_cnt <= 0;
                            servo_angle <= servo_angle + 1;
                        end else begin
                            servo_step_cnt <= servo_step_cnt + 1;
                        end
                    end
                end
                
                RESULT: begin
                    // 1 Cycle Wait to clear flags in next IDLE state
                    event_active <= 0; 
                    piezo_warn <= 0; 
                    servo_angle <= IDLE_ANGLE;
                    servo_step_cnt <= 0;
                    state <= IDLE;      
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule