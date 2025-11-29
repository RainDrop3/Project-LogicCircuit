module piezo_driver (
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [19:0] freq_div,
    output reg piezo_out
);
    reg [19:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 20'd0;
            piezo_out <= 1'b0;
        end else if (en && (freq_div != 0)) begin
            if (counter >= freq_div - 1) begin
                counter <= 20'd0;
                piezo_out <= ~piezo_out;
            end else begin
                counter <= counter + 1;
            end
        end else begin
            counter <= 20'd0;
            piezo_out <= 1'b0;
        end
    end
endmodule