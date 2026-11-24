//==================== Input Conditioner ====================
// Synchronizes + debounces a button/switch and outputs a ONE-cycle pulse
// on its rising edge. One press = one pulse.
module input_cond #(
    parameter DEBOUNCE_BITS = 20   // ~10 ms at 100 MHz. Use 2 or 3 in simulation.
)(
    input  logic clk,
    input  logic rstn,
    input  logic in,
    output logic pulse
);
    logic s1, s2, stable, prev;
    logic [DEBOUNCE_BITS-1:0] cnt;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            s1 <= 0; s2 <= 0; stable <= 0; prev <= 0; cnt <= 0;
        end else begin
            s1   <= in;      // 2-FF synchronizer
            s2   <= s1;
            prev <= stable;
            if (s2 == stable)
                cnt <= 0;
            else begin
                cnt <= cnt + 1;
                if (&cnt) stable <= s2;   // input held different long enough
            end
        end
    end

    assign pulse = stable & ~prev;        // rising edge only
endmodule
