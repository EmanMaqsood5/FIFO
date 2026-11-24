//==================== FIFO Datapath ====================
module fifo_datapath #(
    parameter DEPTH = 8,
    parameter DWIDTH = 4
)(
    input  logic              rstn,
    input  logic              clk,
    input  logic              wr_en,
    input  logic              rd_en,
    input  logic [DWIDTH-1:0] din,
    output logic [DWIDTH-1:0] dout,
    output logic              empty,
    output logic              full,
    output logic [DWIDTH-1:0] fifo_data [7:0], // expose FIFO contents to display
    output logic [7:0]        fifo_valid       // per-slot valid bit
);

    logic [2:0] wptr, rptr;
    logic [3:0] count;
    logic [DWIDTH-1:0] fifo [7:0];
    logic [7:0] valid;                         // valid bit per slot

    // Write and read/clear in ONE always_ff (fifo[] has a single driver)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            wptr  <= 0;
            rptr  <= 0;
            dout  <= 0;
            valid <= 8'b0;
            for (int j = 0; j < 8; j++) fifo[j] <= 0;
        end else begin
            if (wr_en && !full) begin
                fifo[wptr]  <= din;
                valid[wptr] <= 1'b1;
                wptr <= wptr + 1;
            end
            if (rd_en && !empty) begin
                dout <= fifo[rptr];
                fifo[rptr]  <= 0;      // Clear on read
                valid[rptr] <= 1'b0;   // slot is now empty -> display blanks it
                rptr <= rptr + 1;
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) count <= 0;
        else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

    assign full  = (count == DEPTH);
    assign empty = (count == 0);

    // Expose FIFO contents to top for display
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign fifo_data[i] = fifo[i];
        end
    endgenerate

    assign fifo_valid = valid;

endmodule
