// =======================================================================================
// Module Name: game_top
// Description: FPGA Bomb Defusal Game - Top Level Module
// Update: 
//   - Main Action (P1, P2, P3): Key 0 (Rolled back)
//   - Phase 4 Action (Mash): Key 1 (Changed)
// =======================================================================================

module game_top (
    input wire clk,             // 50MHz System Clock
    
    // =============================================================
    // 1. Physical Inputs
    // =============================================================
    input wire [11:0] keypad_in,// 12-Key Parallel Input
    input wire [7:0] dip_in,    // 8-bit DIP Switch
    input wire adc_data_in,     // ADC Serial Data (MISO)

    // =============================================================
    // 2. Physical Outputs
    // =============================================================
    output wire [7:0] seg_com,   
    output wire [7:0] seg_data,  
    output wire [7:0] seg_single_data,
    output wire [7:0] led_out,   
    output wire [2:0] f_led1, f_led2, f_led3, f_led4,
    output wire lcd_rs, lcd_rw, lcd_en,
    output wire [7:0] lcd_data,
    output wire servo_pwm,        
    output wire [3:0] step_motor_phase, 
    output wire piezo_out,
    output wire adc_cs_n, adc_sclk, adc_din         
);

    // =================================================================
    // 3. Internal Signals
    // =================================================================
    
    // --- Reset Logic ---
    wire sys_rst; 
    assign sys_rst = keypad_in[8]; // Key 9 is System Reset

    // --- Keypad Signals ---
    wire [3:0] key_val;        
    wire key_pulse;            
    
    // [롤백] Key 0: Main Action (Phase 1, 2, 3 Submit)
    wire btn_main_action;
    assign btn_main_action = key_pulse && (key_val == 4'd0);
    
    // [신규] Key 1: Phase 4 Action (Gauge Charge)
    wire btn_p4_action;
    assign btn_p4_action = key_pulse && (key_val == 4'd1);
    
    // Key #: Event 2 Solution Button
    wire btn_event_action;
    assign btn_event_action = key_pulse && (key_val == 4'd11);

    // --- Driver Outputs ---
    wire [7:0] dip_sync;       
    wire [11:0] adc_dial_val;  
    wire [11:0] adc_cds_val;   

    // --- System Control Signals ---
    wire [2:0] current_state;  
    wire [3:0] stability;      
    wire game_enable;          
    wire timer_reset_sig;      
    wire game_clear_sig;       
    wire game_over_sig;        
    wire time_out_sig;         
    wire [15:0] time_bcd;      

    // --- Puzzle & Event Signals ---
    wire p1_clear, p2_clear, p3_clear, p4_clear;
    wire p1_fail, p2_fail, p3_fail; 
    wire ev1_fail, ev2_fail;
    
    wire p_fail_sig, e_fail_sig;
    assign p_fail_sig = p1_fail | p2_fail | p3_fail;
    assign e_fail_sig = ev1_fail | ev2_fail;
    
    wire p_correct_sig;
    wire ev1_success, ev2_success;
    wire stability_recover_sig;
    assign stability_recover_sig = p_correct_sig | ev1_success | ev2_success;
    
    // Event Status
    wire ev1_active, ev2_active; 
    wire is_event_running;
    assign is_event_running = ev1_active | ev2_active;
    
    // Auto Trigger Signals
    wire auto_trig_ev1, auto_trig_ev2;
    
    // --- Display Registers ---
    reg [31:0] seg_display_data;
    reg [7:0] led_display_data;
    reg [7:0] servo_target_angle;
    reg [2:0] rgb_target_color;
    reg [127:0] lcd_line1; 
    reg [127:0] lcd_line2;
    
    // --- Sub-module Output Wires ---
    wire [7:0] p1_led, p2_led, p3_led;
    wire [31:0] p1_seg, p2_seg, p3_seg, p4_seg;
    wire [7:0] p2_servo, ev1_servo, ev2_servo;
    wire p4_motor_pulse; 
    wire ev1_piezo;
    wire [2:0] ev2_rgb;
    wire [3:0] rgb_r_vec, rgb_g_vec, rgb_b_vec;
        wire piezo_timer_beep;

        // --- Piezo Timer Alert Parameters ---
        localparam integer CLK_FREQ_HZ          = 50_000_000;
        localparam integer PIEZO_ON_TICKS       = CLK_FREQ_HZ / 2;   // 0.5s
        localparam integer PIEZO_PERIOD_LONG    = 5 * CLK_FREQ_HZ;   // 5s interval
        localparam integer PIEZO_PERIOD_SHORT   = 2 * CLK_FREQ_HZ;   // 2s interval (<1min)

        reg [31:0] piezo_period_cnt;
        reg [31:0] piezo_active_cnt;
        reg        piezo_timer_active;
        wire       timer_under_one_min = (time_bcd[15:8] == 8'h00);
        wire [31:0] piezo_period_target = timer_under_one_min ? PIEZO_PERIOD_SHORT : PIEZO_PERIOD_LONG;

        always @(posedge clk or posedge sys_rst) begin
            if (sys_rst) begin
                piezo_period_cnt  <= 0;
                piezo_active_cnt  <= 0;
                piezo_timer_active <= 0;
            end else begin
                if (!game_enable) begin
                    piezo_period_cnt  <= 0;
                    piezo_active_cnt  <= 0;
                    piezo_timer_active <= 0;
                end else if (piezo_timer_active) begin
                    if (piezo_active_cnt >= PIEZO_ON_TICKS) begin
                        piezo_timer_active <= 0;
                        piezo_active_cnt  <= 0;
                    end else begin
                        piezo_active_cnt <= piezo_active_cnt + 1;
                    end
                end else begin
                    piezo_active_cnt <= 0;
                    if (piezo_period_cnt >= piezo_period_target) begin
                        piezo_timer_active <= 1;
                        piezo_period_cnt  <= 0;
                    end else begin
                        piezo_period_cnt <= piezo_period_cnt + 1;
                    end
                end
            end
        end

        assign piezo_timer_beep = piezo_timer_active;

    // =================================================================
    // 4. Driver Instantiation
    // =================================================================

    dip_switch_driver u_dip_driver (
        .clk(clk), .rst_n(~sys_rst), .dip_in(dip_in), .dip_out(dip_sync)
    );

    adc_interface u_adc_driver (
        .clk(clk), .rst_n(~sys_rst),
        .adc_data_in(adc_data_in), .adc_cs_n(adc_cs_n), .adc_sclk(adc_sclk), .adc_din(adc_din),
        .dial_value(adc_dial_val), .cds_value(adc_cds_val)
    );

    keypad_parallel_driver u_keypad_driver (
        .clk(clk), .rst_n(~sys_rst), .key_in(keypad_in), .key_value(key_val), .key_valid(key_pulse)
    );


    // =================================================================
    // 5. Control Logic & Game System
    // =================================================================
    
    random_event_generator u_rand_gen (
        .clk(clk), .rst_n(~sys_rst),
        .current_state(current_state),
        .event_active(is_event_running),
        .trig_ev1(auto_trig_ev1),
        .trig_ev2(auto_trig_ev2)
    );

    main_fsm u_fsm (
        .clk(clk), .rst_n(~sys_rst),
        .game_start_btn(btn_main_action),
        .phase_clear(p1_clear | p2_clear | p3_clear | p4_clear),
        .time_out(time_out_sig),
        .puzzle_fail(p_fail_sig), .event_fail(e_fail_sig), .puzzle_correct(stability_recover_sig),
        .current_state(current_state), .stability(stability), .game_enable(game_enable),
        .timer_reset(timer_reset_sig), .game_clear(game_clear_sig), .game_over(game_over_sig)
    );

    game_timer u_timer (
        .clk(clk), .rst_n(~sys_rst),
        .game_enable(game_enable), .timer_reset(timer_reset_sig), .stability(stability),
        .time_bcd(time_bcd), .time_out(time_out_sig)
    );


    // =================================================================
    // 6. Puzzles
    // =================================================================
    
    // Phase 1: Arithmetic Puzzle (Uses Key 0 for Submit internally)
    phase1_puzzle1 u_puzzle1 (
        .clk(clk), .rst_n(~sys_rst), 
        .enable(current_state == 3'd1),
        .dip_sw(dip_sync), .key_valid(key_pulse), .key_value(key_val),
        .timer_data(time_bcd),
        .led_out(p1_led), .seg_data(p1_seg), .clear(p1_clear), 
        .fail(p1_fail), 
        .correct(p_correct_sig)
    );

    // Phase 2: Safe Dial (Uses Key 0)
    phase1_puzzle2_dial u_puzzle2 (
        .clk(clk), .rst_n(~sys_rst), 
        .enable(current_state == 3'd2),
        .adc_dial_val(adc_dial_val), 
        
        // [유지] Phase 2는 Key 0 사용
        .btn_click(btn_main_action),     
        
        .target_seg_data(p2_seg), .cursor_led(p2_led), .servo_angle(p2_servo),
        .clear(p2_clear), 
        .fail(p2_fail) 
    );
    
    // Phase 3: Lights Out (Uses Key 0)
    phase1_puzzle3 u_puzzle3 (
        .clk(clk), .rst_n(~sys_rst), 
        .enable(current_state == 3'd3),
        .dip_sw(dip_sync), 
        
        // [유지] Phase 3는 Key 0 사용
        .btn_submit(btn_main_action), 
        
        .timer_data(time_bcd),    
        .seg_data(p3_seg), .led_out(p3_led), .clear(p3_clear), 
        .fail(p3_fail) 
    );

    // Phase 4: Final Action (Uses Key 1)
    phase1_final_click u_puzzle4 (
        .clk(clk), .rst_n(~sys_rst), 
        .enable(current_state == 3'd4),
        
        // [수정] Phase 4는 Key 1 (btn_p4_action) 사용
        .btn_click(btn_p4_action),     
        
        .seg_display(p4_seg), .motor_pulse(p4_motor_pulse), .clear(p4_clear)
    );


    // =================================================================
    // 7. Events
    // =================================================================

    event1_overload u_event1 (
        .clk(clk), .rst_n(~sys_rst), 
        .event_start(auto_trig_ev1), 
        .cds_value(adc_cds_val),
        .servo_angle(ev1_servo), .piezo_warn(ev1_piezo),
        .event_success(ev1_success), 
        .event_fail(ev1_fail), 
        .event_active(ev1_active)
    );

    event2_danger u_event2 (
        .clk(clk), .rst_n(~sys_rst), 
        .event_start(auto_trig_ev2), 
        .btn_pressed(btn_event_action), 
        .servo_angle(ev2_servo), .rgb_led(ev2_rgb),
        .event_success(ev2_success), 
        .event_fail(ev2_fail), 
        .event_active(ev2_active)
    );


    // =================================================================
    // 8. Resource Multiplexing & Display Logic
    // =================================================================

    // 1. 7-Segment MUX
    always @(*) begin
        case (current_state)
            3'd1: seg_display_data = p1_seg; 
            3'd2: seg_display_data = p2_seg;
            3'd3: seg_display_data = p3_seg; 
            3'd4: seg_display_data = p4_seg;
            3'd5: seg_display_data = 32'h8888_8888; // SUCCESS
            3'd6: seg_display_data = 32'hDEAD_DEAD; // FAIL
            default: seg_display_data = 32'hFFFF_1d1E; 
        endcase
    end
    
    // 2. LED Array MUX
    always @(*) begin
        case (current_state)
            3'd1: led_display_data = p1_led;
            3'd2: led_display_data = p2_led;
            3'd3: led_display_data = p3_led;
            default: led_display_data = 8'h00;
        endcase
    end
    
    // 3. Servo Motor MUX
    always @(*) begin
        if (ev1_active)      servo_target_angle = ev1_servo;
        else if (ev2_active) servo_target_angle = ev2_servo;
        else if (current_state == 3'd2) servo_target_angle = p2_servo;
        else servo_target_angle = 8'd90;
    end

    // 4. RGB LED Logic
    always @(*) begin
        if (ev2_active) 
            rgb_target_color = ev2_rgb;
        else 
            rgb_target_color = 3'b000;
    end

    // 5. Text LCD Message Logic
    reg [127:0] lcd_timer_str;
    always @(*) begin
        lcd_timer_str = {
            8'h54, 8'h49, 8'h4D, 8'h45, 8'h3A, 8'h20, // "TIME: "
            (8'h30 + {4'b0, time_bcd[15:12]}),        // Min 10
            (8'h30 + {4'b0, time_bcd[11:8]}),         // Min 1
            8'h3A,                                    // ":"
            (8'h30 + {4'b0, time_bcd[7:4]}),          // Sec 10
            (8'h30 + {4'b0, time_bcd[3:0]}),          // Sec 1
            8'h20, 8'h20, 8'h20, 8'h20, 8'h20         // Spacing
        };
    end

    always @(*) begin
        case (current_state)
            3'd0: begin lcd_line1 = "READY TO PLAY   "; lcd_line2 = lcd_timer_str; end
            3'd1: begin lcd_line1 = "PHASE 1: NUMBER "; lcd_line2 = lcd_timer_str; end
            3'd2: begin lcd_line1 = "PHASE 2: DIAL   "; lcd_line2 = lcd_timer_str; end
            3'd3: begin lcd_line1 = "PHASE 3: LOGIC  "; lcd_line2 = lcd_timer_str; end
            3'd4: begin lcd_line1 = "PHASE 4: CLICK  "; lcd_line2 = lcd_timer_str; end
            3'd5: begin lcd_line1 = "BOMB DEFUSED!   "; lcd_line2 = "YOU ARE SAFE :) "; end
            3'd6: begin lcd_line1 = "EXPLOSION !!!   "; lcd_line2 = "GAME OVER :(    "; end
            default: begin lcd_line1 = "FPGA BOMB GAME  "; lcd_line2 = "initializing... "; end
        endcase
    end


    // =================================================================
    // 9. Output Drivers
    // =================================================================
    
    seven_segment_array_driver u_seg_driver (
        .clk(clk), .rst_n(~sys_rst),
        .display_data(seg_display_data), .dot_point(8'h00),
        .seg_com(seg_com), .seg_data(seg_data)
    );

    single_seven_segment_driver #(
        .ACTIVE_LOW(1'b0)
    ) u_single_seg (
        .hex_value(stability), .dp_in(1'b0), .seg_out(seg_single_data)
    );

    servo_motor_driver u_servo_driver (
        .clk(clk), .rst_n(~sys_rst),
        .angle_val(servo_target_angle), .servo_pwm(servo_pwm)
    );

    step_motor_driver u_step_driver (
        .clk(clk), .rst_n(~sys_rst),
        .step_pulse(p4_motor_pulse), .dir(1'b0), .motor_phase(step_motor_phase)
    );
    
    rgb_led_driver u_rgb_driver (
        .clk(clk), .rst_n(~sys_rst),
        .color_sel(rgb_target_color), .blink_en(1'b0), 
        .r_out(rgb_r_vec), .g_out(rgb_g_vec), .b_out(rgb_b_vec)
    );
    
    assign f_led1 = {rgb_b_vec[0], rgb_r_vec[0], rgb_g_vec[0]};
    assign f_led2 = {rgb_b_vec[1], rgb_r_vec[1], rgb_g_vec[1]};
    assign f_led3 = {rgb_b_vec[2], rgb_r_vec[2], rgb_g_vec[2]};
    assign f_led4 = {rgb_b_vec[3], rgb_r_vec[3], rgb_g_vec[3]};

    assign piezo_out = ev1_piezo | piezo_timer_beep; 
    
    led_array_driver u_led_driver (
        .rst_n(~sys_rst), .led_data(~led_display_data), .led_out(led_out)
    );

    text_lcd_driver u_lcd_driver (
        .clk(clk), .rst_n(~sys_rst),
        .line1_buffer(lcd_line1), .line2_buffer(lcd_line2),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_en(lcd_en), .lcd_data(lcd_data)
    );

endmodule