module text_lcd_driver (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [127:0] line1_buffer,
    input  wire [127:0] line2_buffer,
    output reg          lcd_rs,
    output reg          lcd_rw,
    output reg          lcd_en,
    output reg  [7:0]   lcd_data
);
    parameter CNT_INIT  = 100000;
    parameter CNT_PULSE = 50;
    parameter CNT_EXEC  = 2500;

    reg [19:0] delay_cnt;
    reg [5:0]  char_idx;
    reg [3:0]  state;
    
    localparam S_INIT_WAIT = 0;
    localparam S_SET_DATA  = 1;
    localparam S_EN_HIGH   = 2;
    localparam S_EN_LOW    = 3;
    localparam S_WAIT_EXEC = 4;
    
    reg [3:0]  cmd_step;
    reg [7:0]  target_data;
    reg        target_rs;
    reg [19:0] wait_limit;

    wire [7:0] char_data [0:31];
    genvar i;
    generate
        for(i=0; i<16; i=i+1) begin : parsing
            assign char_data[i]    = line1_buffer[8*(15-i) +: 8];
            assign char_data[16+i] = line2_buffer[8*(15-i) +: 8];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= S_INIT_WAIT;
            cmd_step <= 0;
            char_idx <= 0;
            lcd_en <= 0;
            delay_cnt <= 0;
        end else begin
            case(state)
                S_INIT_WAIT: begin
                    if(delay_cnt < CNT_INIT) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_SET_DATA;
                        cmd_step <= 0; 
                    end
                end
                S_SET_DATA: begin
                    lcd_rw <= 0;
                    case(cmd_step)
                        0: begin target_rs<=0; target_data<=8'h38; end
                        1: begin target_rs<=0; target_data<=8'h0C; end
                        2: begin target_rs<=0; target_data<=8'h01; end
                        3: begin target_rs<=0; target_data<=8'h06; end
                        4: begin
                            target_rs <= 0;
                            if(char_idx < 16) target_data <= 8'h80 + char_idx;
                            else              target_data <= 8'hC0 + (char_idx-16);
                        end
                        5: begin
                            target_rs <= 1;
                            target_data <= char_data[char_idx];
                        end
                    endcase
                    lcd_rs <= target_rs;
                    lcd_data <= target_data;
                    state <= S_EN_HIGH;
                    delay_cnt <= 0;
                end
                S_EN_HIGH: begin
                    lcd_en <= 1;
                    if(delay_cnt < CNT_PULSE) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_EN_LOW;
                    end
                end
                S_EN_LOW: begin
                    lcd_en <= 0;
                    state <= S_WAIT_EXEC;
                end
                S_WAIT_EXEC: begin
                    wait_limit = (cmd_step == 2) ? CNT_INIT : CNT_EXEC;
                    if(delay_cnt < wait_limit) delay_cnt <= delay_cnt + 1;
                    else begin
                        delay_cnt <= 0;
                        state <= S_SET_DATA;
                        if(cmd_step < 4) cmd_step <= cmd_step + 1;
                        else if(cmd_step == 4) cmd_step <= 5;
                        else begin
                            if(char_idx == 31) begin
                                char_idx <= 0;
                                cmd_step <= 4;
                            end else begin
                                char_idx <= char_idx + 1;
                                cmd_step <= 4;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule