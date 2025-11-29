module phase1_puzzle2_dial (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [11:0] adc_dial_val,
    input wire btn_click,
    output reg [31:0] target_seg_data,
    output reg [7:0] cursor_led,
    output reg [7:0] servo_angle,
    output reg clear,
    output reg fail
);
    reg [2:0] target_pos;
    reg [2:0] current_pos;
    reg [15:0] lfsr_reg;
    wire feedback;
    assign feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];
    reg target_set_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hACE1;
            target_pos <= 0;
            target_set_flag <= 0;
        end else begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            if (enable) begin
                if (!target_set_flag) begin
                    target_pos <= lfsr_reg[2:0];
                    target_set_flag <= 1;
                end
            end else begin
                target_set_flag <= 0;
            end
        end
    end

    always @(*) begin
        current_pos = adc_dial_val[11:9];
        case (current_pos)
            3'd0: cursor_led = 8'b00000001;
            3'd1: cursor_led = 8'b00000010;
            3'd2: cursor_led = 8'b00000100;
            3'd3: cursor_led = 8'b00001000;
            3'd4: cursor_led = 8'b00010000;
            3'd5: cursor_led = 8'b00100000;
            3'd6: cursor_led = 8'b01000000;
            3'd7: cursor_led = 8'b10000000;
            default: cursor_led = 8'b00000000;
        endcase
        servo_angle = current_pos * 8'd25; 
    end

    always @(*) begin
        target_seg_data = 32'hFFFFFFFF; 
        case (target_pos)
            3'd0: target_seg_data[3:0]   = 4'h0;
            3'd1: target_seg_data[7:4]   = 4'h0;
            3'd2: target_seg_data[11:8]  = 4'h0;
            3'd3: target_seg_data[15:12] = 4'h0;
            3'd4: target_seg_data[19:16] = 4'h0;
            3'd5: target_seg_data[23:20] = 4'h0;
            3'd6: target_seg_data[27:24] = 4'h0;
            3'd7: target_seg_data[31:28] = 4'h0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear <= 0; fail <= 0;
        end else begin
            clear <= 0; fail <= 0;
            if (enable && btn_click) begin
                if (current_pos == target_pos) clear <= 1;
                else fail <= 1;
            end
        end
    end
endmodule