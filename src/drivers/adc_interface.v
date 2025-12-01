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

    // =============================================================
    // 1. SPI Clock Divider (Target 10kHz)
    // =============================================================
    // 50MHz / (2 * 2500) = 10kHz (toggle every 2500 cycles)
    localparam integer CLK_DIV = 2500;

    reg [15:0] clk_cnt;
    reg sck_rise_en;
    reg sck_fall_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt      <= 0;
            adc_sclk     <= 0;
            sck_rise_en  <= 0;
            sck_fall_en  <= 0;
        end else begin
            sck_rise_en <= 0;
            sck_fall_en <= 0;
            if (clk_cnt >= (CLK_DIV - 1)) begin
                clk_cnt  <= 0;
                adc_sclk <= ~adc_sclk;
                if (adc_sclk == 0) sck_rise_en <= 1; // about to rise
                else               sck_fall_en <= 1; // about to fall
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // =============================================================
    // 2. SPI Transaction FSM (Reference: tmp.v)
    // =============================================================
    localparam S_IDLE  = 2'd0;
    localparam S_TRANS = 2'd1;
    localparam S_DONE  = 2'd2;

    reg [1:0] state;
    reg [4:0] bit_cnt;
    reg [2:0] channel_addr;
    reg [2:0] prev_addr;
    reg [15:0] shift_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            adc_cs_n     <= 1;
            adc_din      <= 0;
            bit_cnt      <= 0;
            channel_addr <= 0;
            prev_addr    <= 0;
            shift_in     <= 0;
            dial_value   <= 0;
            cds_value    <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    adc_cs_n <= 1;
                    if (sck_fall_en) begin
                        adc_cs_n <= 0;
                        bit_cnt  <= 0;
                        state    <= S_TRANS;
                    end
                end

                S_TRANS: begin
                    if (sck_rise_en) begin
                        // 1. Sample MISO (bits 1~16 valid)
                        if (bit_cnt >= 1 && bit_cnt <= 16)
                            shift_in <= {shift_in[14:0], adc_data_in};

                        // 2. Drive MOSI based on control word
                        case (bit_cnt)
                            0:  adc_din <= 1'b1;                 // WRITE
                            1:  adc_din <= 1'b0;                 // SEQ
                            2:  adc_din <= 1'b0;                 // Don't care
                            3:  adc_din <= channel_addr[2];      // ADD2
                            4:  adc_din <= channel_addr[1];      // ADD1
                            5:  adc_din <= channel_addr[0];      // ADD0
                            6:  adc_din <= 1'b1;                 // PM1
                            7:  adc_din <= 1'b1;                 // PM0
                            8:  adc_din <= 1'b0;                 // SHADOW
                            9:  adc_din <= 1'b0;                 // WEAK
                            10: adc_din <= 1'b1;                 // RANGE
                            11: adc_din <= 1'b1;                 // CODING
                            default: adc_din <= 1'b0;
                        endcase

                        // 3. Progress counter
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 16) begin
                            state    <= S_DONE;
                            adc_cs_n <= 1;
                        end
                    end
                end

                S_DONE: begin
                    // Store data captured during previous address phase
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
