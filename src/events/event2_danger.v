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
    localparam SERVO_MAX   = 8'd180;
    localparam GRN_WIDTH   = 8'd40;   // 초록 구간 크기
    localparam YEL_MARGIN  = 8'd40;   // 초록 좌우 노랑 폭
    localparam BASE_MIN    = YEL_MARGIN;
    localparam BASE_MAX    = SERVO_MAX - GRN_WIDTH - YEL_MARGIN;
    localparam RAND_SPAN   = BASE_MAX - BASE_MIN + 1;
    localparam COLOR_RED = 3'b110;  // RGB
    localparam COLOR_YEL = 3'b010;
    localparam COLOR_GRN = 3'b011;
    localparam COLOR_OFF = 3'b000;
    // 110: 빨강 / 100: 보라 / 010: 노랑
    localparam IDLE   = 2'b00;
    localparam SCAN   = 2'b01; 
    localparam FINISH = 2'b10;

    reg [1:0] state;
    reg [31:0] move_cnt;
    reg [31:0] timer_cnt;
    reg direction;
    reg [7:0] rand_state;
    reg [7:0] green_start, green_end;
    reg [7:0] yel_low_start, yel_low_end;
    reg [7:0] yel_high_start, yel_high_end;

    wire [7:0] rand_next = {rand_state[6:0], rand_state[7] ^ rand_state[5] ^ rand_state[4] ^ rand_state[3]};
    wire [7:0] next_green_start = BASE_MIN + (rand_next % RAND_SPAN);
    wire [7:0] next_green_end   = next_green_start + GRN_WIDTH;
    wire [7:0] next_yel_low_start  = (next_green_start >= YEL_MARGIN) ? (next_green_start - YEL_MARGIN) : 8'd0;
    wire [7:0] next_yel_low_end    = next_green_start;
    wire [7:0] next_yel_high_start = next_green_end;
    wire [7:0] next_yel_high_end   = (next_green_end + YEL_MARGIN <= SERVO_MAX) ? (next_green_end + YEL_MARGIN) : SERVO_MAX;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            servo_angle <= 0; rgb_led <= COLOR_OFF;
            event_success <= 0; event_fail <= 0; event_active <= 0;
            move_cnt <= 0; timer_cnt <= 0; direction <= 0;
            rand_state <= 8'hA5;
            green_start <= BASE_MIN;
            green_end <= BASE_MIN + GRN_WIDTH;
            yel_low_start <= (BASE_MIN >= YEL_MARGIN) ? (BASE_MIN - YEL_MARGIN) : 8'd0;
            yel_low_end <= BASE_MIN;
            yel_high_start <= BASE_MIN + GRN_WIDTH;
            yel_high_end <= ((BASE_MIN + GRN_WIDTH + YEL_MARGIN) <= SERVO_MAX) ? (BASE_MIN + GRN_WIDTH + YEL_MARGIN) : SERVO_MAX;
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
                        rand_state <= rand_next;
                        green_start <= next_green_start;
                        green_end <= next_green_end;
                        yel_low_start <= next_yel_low_start;
                        yel_low_end <= next_yel_low_end;
                        yel_high_start <= next_yel_high_start;
                        yel_high_end <= next_yel_high_end;
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
                    if (servo_angle < yel_low_start) rgb_led <= COLOR_RED;
                    else if (servo_angle < yel_low_end) rgb_led <= COLOR_YEL;
                    else if (servo_angle < green_end) rgb_led <= COLOR_GRN;
                    else if (servo_angle < yel_high_end) rgb_led <= COLOR_YEL;
                    else rgb_led <= COLOR_RED;
                    timer_cnt <= timer_cnt + 1;
                    if (timer_cnt >= TIME_LIMIT) begin
                        event_fail <= 1; 
                        state <= FINISH;
                    end else if (btn_pressed) begin
                        if ((servo_angle >= green_start) && (servo_angle < green_end)) event_success <= 1; 
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