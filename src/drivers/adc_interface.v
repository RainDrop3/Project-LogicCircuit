// =======================================================================================
// Module Name: adc_interface (Based on Code B's naming)
// Description: AD7908 Interface using Code A's proven logic
// Key Updates:
//   1. Port names match 'adc_interface' (Code B)
//   2. Reset logic changed to Active High (matches Code A's success)
//   3. Data slicing fixed to [11:4] (matches Code A's timing fix)
// =======================================================================================

module adc_interface (
    input  wire clk,
    input  wire rst,         // [중요] Code B의 rst_n 대신 Code A의 rst(Active High) 사용
    
    // SPI Interface
    input  wire adc_data_in, // (구 spi_miso)
    output reg  adc_cs_n,    // (구 spi_cs_n)
    output reg  adc_sclk,    // (구 spi_sck)
    output reg  adc_din,     // (구 spi_mosi)
    
    // ADC Values
    output reg [7:0] dial_value, // CH1 값 (Code A의 adc_accel 대응)
    output reg [7:0] cds_value   // CH0 값 (Code A의 adc_cds 대응)
);

    // =============================================================
    // 1. SPI Clock Divider (Target 10kHz)
    // =============================================================
    // 50MHz / 10kHz = 5000 (Toggle every 2500 cycles)
    localparam integer CLK_DIV = 2500;

    reg [15:0] clk_cnt;
    reg sck_rise_en; // 데이터 샘플링 (Rising)
    reg sck_fall_en; // CS 제어 (Falling)

    // [로직 적용] Code A의 Active High 리셋 사용
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt     <= 0;
            adc_sclk    <= 0;
            sck_rise_en <= 0;
            sck_fall_en <= 0;
        end else begin
            sck_rise_en <= 0;
            sck_fall_en <= 0;
            
            if (clk_cnt >= (CLK_DIV - 1)) begin
                clk_cnt  <= 0;
                adc_sclk <= ~adc_sclk;
                
                if (adc_sclk == 0) sck_rise_en <= 1; // 0->1 Rising
                else               sck_fall_en <= 1; // 1->0 Falling
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // =============================================================
    // 2. SPI Transaction FSM (Code A Logic)
    // =============================================================
    localparam S_IDLE  = 2'd0;
    localparam S_TRANS = 2'd1;
    localparam S_DONE  = 2'd2;

    reg [1:0] state;
    reg [4:0] bit_cnt;
    reg [2:0] channel_addr;
    reg [2:0] prev_addr;
    reg [15:0] shift_in;

    // [로직 적용] Code A의 Active High 리셋 사용
    always @(posedge clk or posedge rst) begin
        if (rst) begin
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
                    if (sck_fall_en) begin // Falling Edge Start
                        adc_cs_n <= 0;
                        bit_cnt  <= 0;
                        state    <= S_TRANS;
                    end
                end

                S_TRANS: begin
                    if (sck_rise_en) begin // Rising Edge Action
                        // 1. Read MISO (adc_data_in)
                        // [로직 적용] Code A와 동일하게 1~16비트 구간 샘플링
                        if (bit_cnt >= 1 && bit_cnt <= 16) begin
                            shift_in <= {shift_in[14:0], adc_data_in};
                        end

                        // 2. Write MOSI (adc_din)
                        case (bit_cnt)
                            0:  adc_din <= 1'b1;            // WRITE
                            1:  adc_din <= 1'b0;            // SEQ
                            2:  adc_din <= 1'b0;            // Don't Care
                            3:  adc_din <= channel_addr[2]; // ADD2
                            4:  adc_din <= channel_addr[1]; // ADD1
                            5:  adc_din <= channel_addr[0]; // ADD0
                            6:  adc_din <= 1'b1;            // PM1
                            7:  adc_din <= 1'b1;            // PM0
                            8:  adc_din <= 1'b0;            // SHADOW
                            9:  adc_din <= 1'b0;            // WEAK
                            10: adc_din <= 1'b1;            // RANGE
                            11: adc_din <= 1'b1;            // CODING
                            default: adc_din <= 1'b0;
                        endcase

                        // 3. Count
                        bit_cnt <= bit_cnt + 1;
                        if (bit_cnt == 16) begin
                            state    <= S_DONE;
                            adc_cs_n <= 1;
                        end
                    end
                end

                S_DONE: begin
                    // [핵심 로직 적용] Code A에서 검증된 [11:4] 비트 사용
                    // Code A: prev_addr==0 -> cds, prev_addr==1 -> accel
                    // Code B Port 매핑: cds -> cds_value, accel -> dial_value
                    if (prev_addr == 0)      cds_value  <= shift_in[11:4]; // CH0
                    else if (prev_addr == 1) dial_value <= shift_in[11:4]; // CH1
                    
                    prev_addr <= channel_addr;
                    // Toggle Channel (0 -> 1 -> 0)
                    channel_addr <= (channel_addr == 0) ? 1 : 0;
                    
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
