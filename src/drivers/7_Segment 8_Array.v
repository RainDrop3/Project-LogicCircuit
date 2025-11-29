module seven_segment_array_driver (
    input wire clk,
    input wire rst_n,
    input wire [31:0] display_data, // [Digit7]...[Digit0] (Hex Code)
    input wire [7:0] dot_point,     // DP control (Active High, 1=ON)
    
    output reg [7:0] seg_com,       // Common Select (Active Low: 0=Select)
    output reg [7:0] seg_data       // Segment Pattern (Active High: 1=ON, Order: a b c d e f g h)
);

    // Parameters
    parameter SCAN_DIV = 5000; // 50MHz / 5000 = 10kHz Base -> /8 Digits ~ 1.25kHz Refresh Rate

    // Internal Signals
    reg [15:0] scan_cnt;
    reg [2:0] digit_sel;
    reg [3:0] hex_val;
    reg dp_val;

    // 1. Scanning Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= 0;
            digit_sel <= 0;
        end else begin
            if (scan_cnt >= SCAN_DIV) begin
                scan_cnt <= 0;
                digit_sel <= digit_sel + 1;
            end else begin
                scan_cnt <= scan_cnt + 1;
            end
        end
    end

    // 2. Digit Selection (Common Signal) - Active Low (0 to Select)
    always @(*) begin
        case (digit_sel)
            3'd0: begin seg_com = 8'b11111110; hex_val = display_data[3:0];   dp_val = dot_point[0]; end
            3'd1: begin seg_com = 8'b11111101; hex_val = display_data[7:4];   dp_val = dot_point[1]; end
            3'd2: begin seg_com = 8'b11111011; hex_val = display_data[11:8];  dp_val = dot_point[2]; end
            3'd3: begin seg_com = 8'b11110111; hex_val = display_data[15:12]; dp_val = dot_point[3]; end
            3'd4: begin seg_com = 8'b11101111; hex_val = display_data[19:16]; dp_val = dot_point[4]; end
            3'd5: begin seg_com = 8'b11011111; hex_val = display_data[23:20]; dp_val = dot_point[5]; end
            3'd6: begin seg_com = 8'b10111111; hex_val = display_data[27:24]; dp_val = dot_point[6]; end
            3'd7: begin seg_com = 8'b01111111; hex_val = display_data[31:28]; dp_val = dot_point[7]; end
            default: begin seg_com = 8'b11111111; hex_val = 4'h0; dp_val = 0; end
        endcase
    end

    // 3. Segment Decoding (Active High Segment)
    // Mapping Rule based on Image: "01100000" -> '1' (b, c ON)
    // Implies Order: [7]=a, [6]=b, [5]=c, [4]=d, [3]=e, [2]=f, [1]=g, [0]=h(dp)
    always @(*) begin
        case (hex_val)
            //                      abcdefgh
            4'h0: seg_data = 8'b11111100; // 0xFC (0)
            4'h1: seg_data = 8'b01100000; // 0x60 (1)
            4'h2: seg_data = 8'b11011010; // 0xDA (2)
            4'h3: seg_data = 8'b11110010; // 0xF2 (3)
            4'h4: seg_data = 8'b01100110; // 0x66 (4)
            4'h5: seg_data = 8'b10110110; // 0xB6 (5)
            4'h6: seg_data = 8'b10111110; // 0xBE (6)
            4'h7: seg_data = 8'b11100000; // 0xE0 (7)
            4'h8: seg_data = 8'b11111110; // 0xFE (8)
            4'h9: seg_data = 8'b11110110; // 0xF6 (9)
            4'hA: seg_data = 8'b11101110; // 0xEE (A)
            
            // [수정] B를 언더바(_)로 변경
            // d segment만 켬 (비트 4) -> 00010000
            4'hB: seg_data = 8'b00010000; // 0x10 (_)
            
            4'hC: seg_data = 8'b10011100; // 0x9C (C)
            4'hD: seg_data = 8'b01111010; // 0x7A (d)
            4'hE: seg_data = 8'b10011110; // 0x9E (E)
            4'hF: seg_data = 8'b10001110; // 0x8E (F)
            default: seg_data = 8'b00000000;
        endcase
        
        // DP Control (Bit 0 is h/dp)
        if (dp_val) begin
            seg_data[0] = 1'b1;
        end
    end

endmodule
