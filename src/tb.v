`timescale 1ns / 1ps

module tb_game_top_all_drivers;

    // ==========================================
    // 1. Inputs (To UUT)
    // ==========================================
    reg clk;
    reg [11:0] keypad_in; // 12-bit (Active Low)
    reg [7:0] dip_in;
    reg adc_data_in;      // MISO Simulation

    // ==========================================
    // 2. Outputs (From UUT)
    // ==========================================
    wire [7:0] seg_com;
    wire [7:0] seg_data;
    wire [7:0] seg_single_data;
    wire [7:0] led_out;
    wire [2:0] f_led1, f_led2, f_led3, f_led4;
    wire lcd_rs, lcd_rw, lcd_en;
    wire [7:0] lcd_data;
    wire servo_pwm;
    wire [3:0] step_motor_phase;
    wire adc_cs_n, adc_sclk, adc_din;
    wire piezo_out;

    // ==========================================
    // 3. Instantiate UUT
    // ==========================================
    game_top uut (
        .clk(clk),
        .keypad_in(keypad_in),
        .dip_in(dip_in),
        .adc_data_in(adc_data_in),

        .seg_com(seg_com),
        .seg_data(seg_data),
        .seg_single_data(seg_single_data),
        .led_out(led_out),
        .f_led1(f_led1), .f_led2(f_led2), .f_led3(f_led3), .f_led4(f_led4),
        .lcd_rs(lcd_rs), .lcd_rw(lcd_rw), .lcd_en(lcd_en), .lcd_data(lcd_data),
        .servo_pwm(servo_pwm),
        .step_motor_phase(step_motor_phase),
        .adc_cs_n(adc_cs_n), .adc_sclk(adc_sclk), .adc_din(adc_din),
        .piezo_out(piezo_out)
    );

    // ==========================================
    // 4. Clock & ADC Simulation
    // ==========================================
    always #10 clk = ~clk; // 50MHz

    // ADC Dummy Data Generator (Toggle MISO to simulate changing value)
    always @(negedge adc_sclk) begin
        adc_data_in <= ~adc_data_in; 
    end

    // ==========================================
    // 5. Test Sequence
    // ==========================================
    initial begin
        // --- Initialize ---
        clk = 0;
        keypad_in = 12'hFFF; // All Released (Active Low)
        dip_in = 8'h00;
        adc_data_in = 0;

        $display("==================================================");
        $display(" Start Integrated Driver Test");
        $display("==================================================");

        // -----------------------------------------------------------
        // 1. System Reset Test (Driver: Keypad, LCD Init)
        // -----------------------------------------------------------
        $display("[0ns] Apply Reset (Key 9)");
        keypad_in[8] = 0; // Press Key 9
        #200;
        keypad_in[8] = 1; // Release Key 9
        #1000;
        
        // Wait for LCD Initialization (Skip large delay in wave viewer)
        $display("Waiting for LCD Init...");
        #50000; 

        // -----------------------------------------------------------
        // 2. Start Game -> Phase 1 (Driver: 7-Seg Array, LCD Update)
        // -----------------------------------------------------------
        $display("[Step 2] Start Game (Transition to Phase 1)");
        press_key(10); // Press Key 0 (Start)
        
        // Check 7-Segment output is changing
        #1000;
        if(seg_com != 8'hFF) $display(" -> 7-Segment Active: OK");

        // -----------------------------------------------------------
        // 3. Phase 2 Test (Driver: Servo, ADC Interface)
        // -----------------------------------------------------------
        $display("[Step 3] Force Jump to Phase 2 (Dial Matching)");
        // Force internal state to Phase 2 to test Servo/ADC drivers
        force uut.u_fsm.current_state = 3'd2; 
        #100;
        
        // Wait to see Servo PWM changes
        $display(" -> Observing Servo PWM & ADC SPI...");
        #100000; // 100us wait
        release uut.u_fsm.current_state; // Release force

        // -----------------------------------------------------------
        // 4. Phase 3 Test (Driver: DIP Switch, LED Array)
        // -----------------------------------------------------------
        $display("[Step 4] Force Jump to Phase 3 (Lights Out)");
        force uut.u_fsm.current_state = 3'd3;
        #100;
        
        // Toggle DIP Switch
        dip_in = 8'hAA; 
        #500;
        dip_in = 8'h55;
        #500;
        $display(" -> Check LED Array (led_out) changes in Waveform");

        // -----------------------------------------------------------
        // 5. Phase 4 Test (Driver: Step Motor, Keypad)
        // -----------------------------------------------------------
        $display("[Step 5] Force Jump to Phase 4 (Rapid Click)");
        force uut.u_fsm.current_state = 3'd4;
        #100;
        
        $display(" -> Pressing Key 0 Rapidly for Step Motor Feedback");
        repeat(5) begin
            press_key(10); // Key 0
            #10000;        // Wait between clicks
        end

        // -----------------------------------------------------------
        // 6. Event Test (Driver: RGB LED, Piezo)
        // -----------------------------------------------------------
        $display("[Step 6] Force Trigger Event 2 (Danger Search)");
        // Force trigger event
        force uut.ev2_active = 1;
        #100;
        
        $display(" -> Check RGB LED (f_led) & Servo Sweep");
        #200000; // Wait to see LED color change
        
        $display("[Step 7] Force Trigger Event 1 (Overload)");
        force uut.ev2_active = 0;
        force uut.ev1_active = 1;
        #100;
        
        $display(" -> Check Piezo Out (Sound)");
        #200000; // Wait to see Piezo toggling

        $display("==================================================");
        $display(" Test Finished. Please inspect Waveform.");
        $display("==================================================");
        $finish;
    end

    // ==========================================
    // Helper Task: Key Press
    // ==========================================
    task press_key(input integer key_idx);
        begin
            keypad_in[key_idx] = 0; // Active Low Press
            #20000;                 // Hold (Simulate Debounce)
            keypad_in[key_idx] = 1; // Release
            #20000;
        end
    endtask

endmodule