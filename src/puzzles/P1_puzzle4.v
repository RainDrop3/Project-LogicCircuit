module phase1_final_click (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire btn_click,
    output reg [31:0] seg_display,
    output reg motor_pulse,
    output reg clear
);
    reg [7:0] current_cnt;
    reg [7:0] target_cnt;
    reg target_set_flag;
    reg [15:0] lfsr_reg;
    wire feedback = lfsr_reg[15] ^ lfsr_reg[13] ^ lfsr_reg[12] ^ lfsr_reg[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hCAFE;
            target_cnt <= 8'd30;
            target_set_flag <= 0;
        end else begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            if (enable) begin
                if (!target_set_flag) begin
                    target_cnt <= {3'b0, lfsr_reg[4:0]} + 8'd20;
                    target_set_flag <= 1;
                end
            end else begin
                target_set_flag <= 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_cnt <= 0; motor_pulse <= 0; clear <= 0;
        end else begin
            motor_pulse <= 0;
            if (enable) begin
                if (btn_click) begin
                    if (current_cnt < target_cnt) begin
                        current_cnt <= current_cnt + 1;
                        motor_pulse <= 1; 
                    end
                end
                if (current_cnt >= target_cnt) clear <= 1;
                else clear <= 0;
            end else begin
                current_cnt <= 0; clear <= 0;
            end
        end
    end

    function [11:0] bin2bcd(input [7:0] bin);
        integer i;
        begin
            bin2bcd = 0;
            for (i = 7; i >= 0; i = i - 1) begin
                if (bin2bcd[3:0] >= 5) bin2bcd[3:0] = bin2bcd[3:0] + 3;
                if (bin2bcd[7:4] >= 5) bin2bcd[7:4] = bin2bcd[7:4] + 3;
                if (bin2bcd[11:8] >= 5) bin2bcd[11:8] = bin2bcd[11:8] + 3;
                bin2bcd = {bin2bcd[10:0], bin[i]};
            end
        end
    endfunction

    reg [11:0] current_bcd;
    reg [11:0] target_bcd;

    always @(*) begin
        current_bcd = bin2bcd(current_cnt);
        target_bcd = bin2bcd(target_cnt);
        seg_display[31:24] = current_bcd[7:0];
        seg_display[23:16] = {4'hF, 4'hF};
        seg_display[15:8]  = {4'hF, 4'hF};
        seg_display[7:0]   = target_bcd[7:0];
    end
endmodule