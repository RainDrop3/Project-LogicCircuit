// =======================================================================================
// Module Name: adc_interface
// Description: AD7908 (8-bit ADC) Control Interface for Combo II-DLD
// Updated: Rebased on working reference design (AD7908, 10kHz SPI)
// =======================================================================================

module adc_interface (
    input  wire clk,
    input  wire rst_n,
    input  wire adc_data_in,    // MISO
    output reg  adc_cs_n,       // CS (Active Low)
    output reg  adc_sclk,       // SPI Clock ~10kHz
    output reg  adc_din,        // MOSI
    output reg [7:0] dial_value,
    output reg [7:0] cds_value
);

    localparam integer CLK_DIV = 2500; // 50MHz -> 10kHz SCK

    reg [15:0] clk_cnt;
    reg sck_enable_rise;
    reg sck_enable_fall;

    wire rst = ~rst_n;

    // === Clock Divider (copied from friend reference) ===
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0;
            adc_sclk <= 0;
            sck_enable_rise <= 0;
            sck_enable_fall <= 0;
        end else begin
            sck_enable_rise <= 0;
            sck_enable_fall <= 0;
            if (clk_cnt >= (CLK_DIV - 1)) begin
                clk_cnt <= 0;
                adc_sclk <= ~adc_sclk;
                if (adc_sclk == 0) sck_enable_rise <= 1;
                else               sck_enable_fall <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // === AD7908 SPI FSM (identical sequencing as reference) ===
    localparam S_IDLE = 2'd0;
    localparam S_TRANS = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0] state;
    reg [4:0] bit_cnt;
    reg [2:0] channel_addr;
    reg [2:0] prev_addr;
    reg [15:0] shift_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            adc_cs_n <= 1;
            adc_din <= 0;
            state <= S_IDLE;
            bit_cnt <= 0;
            channel_addr <= 0;
            prev_addr <= 0;
            shift_in <= 0;
            dial_value <= 0;
            cds_value <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    adc_cs_n <= 1;
                    if (sck_enable_fall) begin
                        state <= S_TRANS;
                        adc_cs_n <= 0;
                        bit_cnt <= 0;
                    end
                end

                S_TRANS: begin
                    if (sck_enable_rise) begin
                        if (bit_cnt >= 1 && bit_cnt <= 16)
                            shift_in <= {shift_in[14:0], adc_data_in};

                        case (bit_cnt)
                            0:  adc_din <= 1'b1;
                            1:  adc_din <= 1'b0;
                            2:  adc_din <= 1'b0;
                            3:  adc_din <= channel_addr[2];
                            4:  adc_din <= channel_addr[1];
                            5:  adc_din <= channel_addr[0];
                            6:  adc_din <= 1'b1;
                            7:  adc_din <= 1'b1;
                            8:  adc_din <= 1'b0;
                            9:  adc_din <= 1'b0;
                            10: adc_din <= 1'b1;
                            11: adc_din <= 1'b1;
                            default: adc_din <= 1'b0;
                        endcase

                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 16) begin
                            state <= S_DONE;
                            adc_cs_n <= 1;
                        end
                    end
                end

                S_DONE: begin
                    if (prev_addr == 0)      dial_value <= shift_in[12:5];
                    else if (prev_addr == 1) cds_value  <= shift_in[12:5];

                    prev_addr <= channel_addr;
                    channel_addr <= (channel_addr == 0) ? 1 : 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
