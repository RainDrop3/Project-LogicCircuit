module event2_danger (
    input wire clk,
    input wire rst_n,
    input wire event_start,           
    input wire btn_pressed,
    output reg [7:0] servo_angle,
    output reg [2:0] rgb_led,
    output reg event_success,
    output reg event_fail,
    output reg event_active
);
    parameter SWEEP_SPEED = 200_000; 
    parameter TIME_LIMIT = 250_000_000; 
    localparam RED_ZONE_MAX = 8'd60;
    localparam YEL_ZONE_MAX = 8'd120;
    localparam COLOR_RED = 3'b100;
    localparam COLOR_YEL = 3'b010;  // 노란 구간 표시 대신 초록색을 사용
    localparam COLOR_GRN = 3'b110;  // 성공 구간 표시를 노란색으로 교체
    localparam COLOR_OFF = 3'b000;
    localparam IDLE   = 2'b00;
    localparam SCAN   = 2'b01; 
    localparam FINISH = 2'b10;

    reg [1:0] state;
    reg [31:0] move_cnt;
    reg [31:0] timer_cnt;
    reg direction;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            servo_angle <= 0; rgb_led <= COLOR_OFF;
            event_success <= 0; event_fail <= 0; event_active <= 0;
            move_cnt <= 0; timer_cnt <= 0; direction <= 0;
        end else begin
            case (state)
                IDLE: begin
                    event_success <= 0; event_fail <= 0; event_active <= 0;
                    rgb_led <= COLOR_OFF; move_cnt <= 0; timer_cnt <= 0;
                    if (event_start) begin
                        state <= SCAN;
                        event_active <= 1;
                        servo_angle <= 0;
                        direction <= 0;
                    end
                end
                SCAN: begin
                    if (move_cnt >= SWEEP_SPEED) begin
                        move_cnt <= 0;
                        if (direction == 0) begin 
                            if (servo_angle >= 180) direction <= 1;
                            else servo_angle <= servo_angle + 1;
                        end else begin
                            if (servo_angle <= 0) direction <= 0;
                            else servo_angle <= servo_angle - 1;
                        end
                    end else begin
                        move_cnt <= move_cnt + 1;
                    end
                    if (servo_angle < RED_ZONE_MAX)      rgb_led <= COLOR_RED;
                    else if (servo_angle < YEL_ZONE_MAX) rgb_led <= COLOR_YEL;
                    else                                 rgb_led <= COLOR_GRN;
                    timer_cnt <= timer_cnt + 1;
                    if (timer_cnt >= TIME_LIMIT) begin
                        event_fail <= 1; 
                        state <= FINISH;
                    end else if (btn_pressed) begin
                        if (servo_angle >= YEL_ZONE_MAX) event_success <= 1; 
                        else event_fail <= 1;
                        state <= FINISH;
                    end
                end
                FINISH: begin
                    event_active <= 0; rgb_led <= COLOR_OFF;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule