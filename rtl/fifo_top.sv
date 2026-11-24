//==================== Top Module ====================
module fifo_top #(
    parameter DEBOUNCE_BITS = 20   // testbench overrides this with a small value
)(
    input  logic clk,
    input  logic rstn,
    input  logic write_valid,
    input  logic read_ready,
    input  logic [3:0] din,
    output logic [6:0] seg,
    output logic [7:0] an
);
    logic wr_en, rd_en;
    logic empty, full;
    logic [3:0] dout;
    logic [3:0] fifo_data [7:0];
    logic [7:0] fifo_valid;
    logic write_pulse, read_pulse;

    // debounce + edge-detect the buttons
    input_cond #(.DEBOUNCE_BITS(DEBOUNCE_BITS)) wr_cond (.clk(clk), .rstn(rstn), .in(write_valid), .pulse(write_pulse));
    input_cond #(.DEBOUNCE_BITS(DEBOUNCE_BITS)) rd_cond (.clk(clk), .rstn(rstn), .in(read_ready),  .pulse(read_pulse));

    fifo_fsm fsm_inst (
        .clk(clk),
        .reset(~rstn),
        .write_valid(write_pulse),
        .read_ready(read_pulse),
        .empty_flag(empty),
        .full_flag(full),
        .write_ready(),
        .write_enable(wr_en),
        .read_valid(),
        .read_enable(rd_en)
    );

    fifo_datapath datapath_inst (
        .rstn(rstn),
        .clk(clk),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .din(din),
        .dout(dout),
        .empty(empty),
        .full(full),
        .fifo_data(fifo_data),
        .fifo_valid(fifo_valid)
    );

    display_controller disp_ctrl (
        .clk(clk),
        .reset(~rstn),
        .data(fifo_data),
        .valid(fifo_valid),
        .seg(seg),
        .an(an)
    );
endmodule
