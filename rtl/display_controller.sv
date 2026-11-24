//==================== Display Controller ====================
module display_controller (
    input  logic clk,
    input  logic reset,
    input  logic [3:0] data [7:0],
    input  logic [7:0] valid,          // valid bit per digit
    output logic [6:0] seg,
    output logic [7:0] an
);
    logic [2:0] digit_sel;
    logic [15:0] clkdiv;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) clkdiv <= 0;
        else clkdiv <= clkdiv + 1;
    end

    always_ff @(posedge clkdiv[15] or posedge reset) begin
        if (reset) digit_sel <= 0;
        else digit_sel <= digit_sel + 1;
    end

    assign an = ~(8'b1 << digit_sel);

    logic [3:0] current_value;
    assign current_value = data[digit_sel];

    always_comb begin
        if (!valid[digit_sel])         // empty slot -> blank
            seg = 7'b1111111;
        else begin
            case (current_value)
                4'h0: seg = 7'b1000000;
                4'h1: seg = 7'b1111001;
                4'h2: seg = 7'b0100100;
                4'h3: seg = 7'b0110000;
                4'h4: seg = 7'b0011001;
                4'h5: seg = 7'b0010010;
                4'h6: seg = 7'b0000010;
                4'h7: seg = 7'b1111000;
                4'h8: seg = 7'b0000000;
                4'h9: seg = 7'b0010000;
                default: seg = 7'b1111111;
            endcase
        end
    end
endmodule
