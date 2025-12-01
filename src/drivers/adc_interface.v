// =======================================================================================
// Module Name: adc_interface
// Description: AD7908 (8-bit ADC) Control Interface for Combo II-DLD
// Updated: Based on PDF manual (AD7908, 8-bit, 50kHz SPI)
// =======================================================================================

module adc_interface (
    input wire clk,             // 50MHz System Clock
    input wire rst_n,
    input wire adc_data_in,     // MISO (DOUT from ADC)
    
    output reg adc_cs_n,        // Chip Select (Active Low)
    output reg adc_sclk,        // Serial Clock (~50kHz)
    output reg adc_din,         // MOSI (DIN to ADC)
    
    // 호환성을 위해 12비트 출력 유지 (상위 8비트 유효, 하위 4비트 0)
    output reg [11:0] dial_value, // Ch0 (Potentiometer)
    output reg [11:0] cds_value   // Ch1 (CDS Sensor)
);

    // =============================================================
    // Parameters & Definitions
    // =============================================================
    // SCLK Frequency: 50kHz (PDF suggests low freq)
    // 50MHz / 1000 = 50kHz -> Toggle every 500 cycles
    parameter CLK_DIV = 500; 

    // AD7908 Control Register Config (12-bit)
    // WRITE(1) | SEQ(0) | DC(0) | ADD[2:0] | PM[1:0](11) | SHADOW(0) | WEAK(0) | RANGE(0) | CODING(1)
    // Range=0 (0~Vref), Coding=1 (Binary)
    // CH0 Config: 100 000 11 00 01 -> 0x831
    // CH1 Config: 100 001 11 00 01 -> 0x871
    localparam CMD_CH0 = 12'h831;
    localparam CMD_CH1 = 12'h871;

    // States
    localparam S_IDLE       = 0;
    localparam S_SETUP_CH0  = 1; // Send Config for CH0 (Initial)
    localparam S_READ_CH0   = 2; // Read CH0 Data & Send Config for CH1
    localparam S_READ_CH1   = 3; // Read CH1 Data & Send Config for CH0

    reg [2:0] state;
    reg [9:0] clk_cnt;
    reg sclk_en;
    reg [4:0] bit_cnt;       // 0~15 (16 clocks per cycle)
    reg [15:0] shift_in;     // Input Buffer
    reg [11:0] shift_out;    // Output Command Buffer

    // =============================================================
    // 1. SCLK Generation (50kHz)
    // =============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            adc_sclk <= 1; // Idle High (CPOL=1, CPHA=1 typical for AD7908)
            sclk_en <= 0;  // Rising edge enable
        end else begin
            sclk_en <= 0;
            if (clk_cnt >= CLK_DIV - 1) begin
                clk_cnt <= 0;
                adc_sclk <= ~adc_sclk;
                if (adc_sclk == 0) sclk_en <= 1; // Rising Edge of SCLK (Data Shift)
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // =============================================================
    // 2. Main FSM (AD7908 SPI Protocol)
    // =============================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            adc_cs_n <= 1;
            adc_din <= 0;
            bit_cnt <= 0;
            dial_value <= 0;
            cds_value <= 0;
            shift_in <= 0;
            shift_out <= 0;
        end else if (sclk_en) begin // Run on SCLK Rising Edge
            case (state)
                S_IDLE: begin
                    adc_cs_n <= 1;
                    state <= S_SETUP_CH0;
                end

                // [Initial Step] CS Low, Send CH0 Config, Ignore Input
                S_SETUP_CH0: begin
                    adc_cs_n <= 0;
                    // Output Logic (MOSI)
                    if (bit_cnt < 12) adc_din <= CMD_CH0[11 - bit_cnt];
                    else              adc_din <= 0; // Padding

                    // Next State Logic
                    if (bit_cnt == 15) begin
                        bit_cnt <= 0;
                        state <= S_READ_CH0; // Next: Read CH0, Write CH1
                        adc_cs_n <= 1;       // CS Pulse High between frames
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // [Loop A] Read CH0 Data, Write CH1 Config
                S_READ_CH0: begin
                    adc_cs_n <= 0;
                    
                    // MOSI: Send CH1 Config
                    if (bit_cnt < 12) adc_din <= CMD_CH1[11 - bit_cnt];
                    else              adc_din <= 0;

                    // MISO: Shift In Data (Sample on Rising Edge)
                    shift_in <= {shift_in[14:0], adc_data_in};

                    if (bit_cnt == 15) begin
                        bit_cnt <= 0;
                        // AD7908 Data Format: 4 Zeros + 8 Data + 4 Zeros
                        // shift_in[11:4] contains the 8-bit result
                        // 12-bit 호환성을 위해: {8bit_data, 4'b0}
                        dial_value <= {shift_in[11:4], 4'b0000}; 
                        
                        state <= S_READ_CH1;
                        adc_cs_n <= 1; 
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // [Loop B] Read CH1 Data, Write CH0 Config
                S_READ_CH1: begin
                    adc_cs_n <= 0;
                    
                    // MOSI: Send CH0 Config
                    if (bit_cnt < 12) adc_din <= CMD_CH0[11 - bit_cnt];
                    else              adc_din <= 0;

                    // MISO: Shift In Data
                    shift_in <= {shift_in[14:0], adc_data_in};

                    if (bit_cnt == 15) begin
                        bit_cnt <= 0;
                        // Save CH1 Data
                        cds_value <= {shift_in[11:4], 4'b0000};
                        
                        state <= S_READ_CH0; // Go back to Read CH0
                        adc_cs_n <= 1; 
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule
