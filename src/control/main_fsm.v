module main_fsm (
    input wire clk,
    input wire rst_n,
    
    input wire game_start_btn,
    input wire phase_clear,
    input wire time_out,
    
    input wire puzzle_fail,
    input wire event_fail,
    input wire puzzle_correct,

    output reg [2:0] current_state,
    output reg [3:0] stability,
    output reg game_enable,
    output reg timer_reset,
    output reg game_clear,
    output reg game_over
);

    localparam IDLE    = 3'd0;
    localparam PHASE1  = 3'd1;
    localparam PHASE2  = 3'd2;
    localparam PHASE3  = 3'd3;
    localparam PHASE4  = 3'd4;
    localparam SUCCESS = 3'd5;
    localparam FAIL    = 3'd6;

    reg [2:0] next_state;
    reg p_fail_prev, e_fail_prev, p_corr_prev;
    wire p_fail_edge, e_fail_edge, p_corr_edge;

    assign p_fail_edge = puzzle_fail & ~p_fail_prev;
    assign e_fail_edge = event_fail & ~e_fail_prev;
    assign p_corr_edge = puzzle_correct & ~p_corr_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            p_fail_prev <= 0; e_fail_prev <= 0; p_corr_prev <= 0;
        end else begin
            current_state <= next_state;
            p_fail_prev <= puzzle_fail;
            e_fail_prev <= event_fail;
            p_corr_prev <= puzzle_correct;
        end
    end

    // [???] ?? ?? ???: ?? time_out? ?? FAIL? ??
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (game_start_btn) next_state = PHASE1;
            PHASE1: begin
                if (time_out) next_state = FAIL; // ??? ?? ?? ??
                else if (phase_clear) next_state = PHASE2;
            end
            PHASE2: begin
                if (time_out) next_state = FAIL;
                else if (phase_clear) next_state = PHASE3;
            end
            PHASE3: begin
                if (time_out) next_state = FAIL;
                else if (phase_clear) next_state = PHASE4;
            end
            PHASE4: begin
                if (time_out) next_state = FAIL;
                else if (phase_clear) next_state = SUCCESS;
            end
            SUCCESS: begin end
            FAIL: begin end
            default: next_state = IDLE;
        endcase
    end

    // ??? ??: 0?? ? ?? ???? ?? (?? ?? ??? ??)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stability <= 4'd9;
        end else begin
            if (current_state == IDLE) begin
                stability <= 4'd9;
            end else if (game_enable) begin
                if ((p_fail_edge || e_fail_edge) && stability > 0)
                    stability <= stability - 1; // 0??? ????? ? ???? ? ?
                else if (p_corr_edge && stability < 9)
                    stability <= stability + 1;
            end
        end
    end

    always @(*) begin
        game_enable = 0;
        game_clear = 0;
        game_over = 0;
        timer_reset = 0;

        case (current_state)
            IDLE: timer_reset = 1;
            PHASE1, PHASE2, PHASE3, PHASE4: game_enable = 1;
            SUCCESS: game_clear = 1;
            FAIL:    game_over = 1;
        endcase
    end
endmodule
