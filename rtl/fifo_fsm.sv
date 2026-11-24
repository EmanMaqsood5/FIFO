//==================== FIFO FSM ====================
module fifo_fsm (
    input  logic clk,
    input  logic reset,
    input  logic write_valid,   // ONE-cycle pulse (from input_cond)
    input  logic read_ready,    // ONE-cycle pulse (from input_cond)
    input  logic empty_flag,
    input  logic full_flag,
    output logic write_ready,
    output logic write_enable,
    output logic read_valid,
    output logic read_enable
);
    typedef enum logic [1:0] { IDLE, WRITE, READ } state_t;
    state_t state, next_state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (write_valid && !full_flag)
                    next_state = WRITE;
                else if (read_ready && !empty_flag)
                    next_state = READ;
            end
            // WRITE and READ last exactly one cycle, then go back to IDLE
            WRITE: next_state = IDLE;
            READ:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_comb begin
        write_ready  = ~full_flag;
        write_enable = (state == WRITE);
        read_enable  = (state == READ);
        read_valid   = (state == READ);
    end
endmodule
