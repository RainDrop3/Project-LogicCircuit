module adc_interface (
    input wire clk,
    input wire rst_n,
    input wire adc_data_in,      // MISO (SDO from ADC)
    
    output reg adc_cs_n,         // Chip Select (Active Low)
    output reg adc_sclk,         // Serial Clock (~1MHz)
    output reg adc_din,          // MOSI (SDI to ADC - Command)
    
    output reg [11:0] dial_value, // Ch0 Value (Potentiometer) - Phase 2 Use
    output reg [11:0] cds_value   // Ch1 Value (Light Sensor)  - Event 1 Use
);

    // ==========================================
    // State & Counter Definitions
    // ==========================================
    localparam IDLE  = 0;
    localparam TRANS = 1; 
    localparam DONE  = 2;

    reg [1:0] state;
    reg [5:0] clk_cnt;      // 50MHz -> 1MHz divider
    reg tick_rise;          // SCLK Rising Edge Pulse (Sample MISO)
    reg tick_fall;          // SCLK Falling Edge Pulse (Drive MOSI)

    reg [4:0] bit_cnt;      // 0~16 bits
    reg [11:0] shift_reg;   // Data Buffer
    reg channel_sel;        // 0: Ch0, 1: Ch1

    // ==========================================
    // 1. SCLK Generation & Edge Detection
    // ==========================================
    // Generate 1MHz SCLK from 50MHz (Toggle every 25 cycles)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            adc_sclk <= 0; // SPI Mode 0 (Idle Low)
            tick_rise <= 0;
            tick_fall <= 0;
        end else begin
            tick_rise <= 0;
            tick_fall <= 0;
            
            if (clk_cnt >= 24) begin // 25 cycles
                clk_cnt <= 0;
                adc_sclk <= ~adc_sclk;
                
                // sclk가 0->1이 되려는 순간 (Rising Edge) -> 데이터 읽기
                if (adc_sclk == 0) tick_rise <= 1;
                // sclk가 1->0이 되려는 순간 (Falling Edge) -> 데이터 쓰기
                else               tick_fall <= 1;
            end else begin
                clk_cnt <= clk_cnt + 1;
            end
        end
    end

    // ==========================================
    // 2. Main FSM (SPI Protocol)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            adc_cs_n <= 1;
            adc_din <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            channel_sel <= 0;
            dial_value <= 0;
            cds_value <= 0;
        end else begin
            case (state)
                IDLE: begin
                    adc_cs_n <= 1;
                    adc_din <= 0;
                    bit_cnt <= 0;
                    // tick_fall 타이밍에 맞춰 시작 (Setup 시간 확보)
                    if (tick_fall) state <= TRANS; 
                end
                
                TRANS: begin
                    // --- Falling Edge: Master Drives MOSI ---
                    if (tick_fall) begin
                        adc_cs_n <= 0; // CS Active Low
                        
                        // MCP3202 Command: Start(1), SGL(1), Ch(sel), MSBF(1)
                        case (bit_cnt)
                            0: adc_din <= 1;           // Start Bit
                            1: adc_din <= 1;           // SGL/DIFF (1=Single)
                            2: adc_din <= channel_sel; // Channel Select
                            3: adc_din <= 1;           // MSBF (1=MSB First)
                            default: adc_din <= 0;
                        endcase
                    end
                    
                    // --- Rising Edge: Master Samples MISO ---
                    if (tick_rise) begin
                        // MCP3202 sends Null bit at bit 4, Data at 5~16
                        if (bit_cnt >= 5 && bit_cnt <= 16) begin
                            shift_reg <= {shift_reg[10:0], adc_data_in};
                        end
                        
                        // Cycle Control
                        if (bit_cnt == 16) begin
                            state <= DONE;
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                
                DONE: begin
                    if (tick_fall) begin
                        adc_cs_n <= 1; // CS Disable
                        adc_din <= 0;
                        
                        // 결과 저장 (채널별)
                        if (channel_sel == 0) dial_value <= shift_reg;
                        else                  cds_value  <= shift_reg;
                        
                        channel_sel <= ~channel_sel; // 다음 번엔 다른 채널 읽기
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule