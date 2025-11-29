module random_event_generator (
    input wire clk,
    input wire rst_n,
    input wire [2:0] current_state, // ?? ?? ??
    input wire event_active,        // ?? ???? ?? ??? ??
    
    output reg trig_ev1,            // Event 1 ?? ??
    output reg trig_ev2             // Event 2 ?? ??
);

    // ==========================================
    // Parameters
    // ==========================================
    // 50MHz Clock ??
    // ?? 10? ~ ?? 30? ?? ?? ?? ?? (???? ?? ?? ?? ??)
    // ???? ???? ?? 5? ~ 15? ??? ??
    parameter MIN_TIME = 32'd250_000_000; // 5?
    parameter MAX_TIME = 32'd750_000_000; // 15?
    
    reg [31:0] timer_cnt;
    reg [31:0] target_time;
    
    // LFSR for Pseudo Random Number
    reg [31:0] lfsr;
    wire feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    // ==========================================
    // LFSR & Target Time Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 32'h1234_5678; // Seed
            target_time <= MIN_TIME;
        end else begin
            lfsr <= {lfsr[30:0], feedback};
            
            // ???? ?? ?? ??? ?? ?? ?? (Masking?? ?? ??)
            if (trig_ev1 || trig_ev2) begin
                target_time <= MIN_TIME + (lfsr % (MAX_TIME - MIN_TIME));
            end
        end
    end

    // ==========================================
    // Trigger Logic
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timer_cnt <= 0;
            trig_ev1 <= 0;
            trig_ev2 <= 0;
        end else begin
            trig_ev1 <= 0; // Pulse Generation
            trig_ev2 <= 0;
            
            // Phase 1, 3, 4 ?? ???, ?? ???? ?? ?? ???
            // Phase 2(???)? ????? ????? ?? (???? ??)
            if ((current_state == 3'd1 || current_state == 3'd3 || current_state == 3'd4) 
                && !event_active) begin
                
                if (timer_cnt >= target_time) begin
                    timer_cnt <= 0;
                    // LFSR? ?? ??? ??? Event 1 ?? 2 ?? ??
                    if (lfsr[0]) trig_ev1 <= 1;
                    else         trig_ev2 <= 1;
                end else begin
                    timer_cnt <= timer_cnt + 1;
                end
            end else begin
                // ?? ??? ? ??? ?? ?? ?? (??? ??)
            end
        end
    end

endmodule