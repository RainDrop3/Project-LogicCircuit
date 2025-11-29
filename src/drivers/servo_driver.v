module servo_motor_driver (
    input wire clk,
    input wire rst_n,
    input wire [7:0] angle_val, // 0 ~ 180 degree
    output reg servo_pwm
);

    // Parameters (50MHz Clock)
    parameter PWM_PERIOD = 1000000; // 20ms (50Hz)
    
    // SG90 등 일반 서보모터 범위: 0.6ms(0도) ~ 2.4ms(180도)
    // 0.6ms = 30,000 cycles
    // 2.4ms = 120,000 cycles
    parameter MIN_WIDTH = 30000;
    parameter MAX_WIDTH = 120000;
    
    reg [19:0] cnt;
    reg [19:0] target_width;  // 계산된 펄스 폭 (조합회로 출력)
    reg [19:0] current_width; // 현재 주기에서 사용 중인 펄스 폭 (레지스터)
    
    // 1. 각도 -> 펄스 폭 변환 (Combinational Logic)
    // Formula: Width = 30000 + (angle * 500)
    // 0도 -> 30000, 180도 -> 120000
    always @(*) begin
        if (angle_val > 180) 
            target_width = MAX_WIDTH;
        else 
            target_width = MIN_WIDTH + (angle_val * 500);
    end

    // 2. PWM 생성 및 글리치 방지 (Sequential Logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            servo_pwm <= 0;
            current_width <= MIN_WIDTH; // 리셋 시 0도 위치
        end else begin
            if (cnt >= PWM_PERIOD - 1) begin
                cnt <= 0;
                servo_pwm <= 1; // 주기 시작
                
                // [중요] 주기가 새로 시작될 때만 새로운 각도 값을 반영합니다.
                // 이를 통해 주기 중간에 펄스 폭이 변해 모터가 튀는 것을 막습니다.
                current_width <= target_width; 
                
            end else begin
                cnt <= cnt + 1;
                
                // 래치된 current_width와 비교
                if (cnt < current_width) 
                    servo_pwm <= 1;
                else 
                    servo_pwm <= 0;
            end
        end
    end

endmodule