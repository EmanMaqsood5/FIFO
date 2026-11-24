`timescale 1ns / 1ps

module tb_fifo;

    localparam DB_BITS  = 2;
    localparam HOLD_CYC = 12;   // button held / released for this many cycles
    localparam MAX_LAT  = 20;   // max cycles allowed from button press to FIFO operation

    logic clk, rstn;
    logic write_valid, read_ready;
    logic [3:0] din;
    logic [6:0] seg;
    logic [7:0] an;

    fifo_top #(.DEBOUNCE_BITS(DB_BITS)) uut (
        .clk(clk), .rstn(rstn),
        .write_valid(write_valid), .read_ready(read_ready),
        .din(din), .seg(seg), .an(an)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fifo);
    end

    //------------------------------------------------------------
    // Reference model state
    //------------------------------------------------------------
    logic [3:0] exp_q [$];          // expected data, in FIFO order
    int model_count = 0;
    int model_wptr  = 0;
    int model_rptr  = 0;

    int wr_total = 0, rd_total = 0; // operations the DUT actually accepted
    int instr_no = 0;
    int errors   = 0;
    int checks   = 0;
    time t_last_wr = 0, t_last_rd = 0;

    task automatic check(input bit cond, input string msg);
        checks++;
        if (!cond) begin
            errors++;
            $display("      *** ERROR @ %0d ns: %s", $time, msg);
        end
    endtask

    //------------------------------------------------------------
    // MONITOR: runs every clock edge, independent of the driver.
    // Samples values from just BEFORE the edge.
    //------------------------------------------------------------
    logic       chk_wr_pending, chk_rd_pending;
    logic [3:0] chk_wr_data, chk_rd_data;
    int         chk_wr_slot, chk_rd_slot;
    logic       wr_en_d, rd_en_d;

    always @(posedge clk) begin
        if (!rstn) begin
            chk_wr_pending = 0; chk_rd_pending = 0;
            wr_en_d = 0; rd_en_d = 0;
        end else begin
            // ---- 1. Check the results of the PREVIOUS edge ----
            if (chk_wr_pending) begin
                check(uut.datapath_inst.valid[chk_wr_slot] === 1'b1,
                      $sformatf("slot %0d valid bit not set after write", chk_wr_slot));
                check(uut.datapath_inst.fifo[chk_wr_slot] === chk_wr_data,
                      $sformatf("slot %0d holds %h, expected %h",
                                chk_wr_slot, uut.datapath_inst.fifo[chk_wr_slot], chk_wr_data));
            end
            if (chk_rd_pending) begin
                check(uut.dout === chk_rd_data,
                      $sformatf("dout is %h one clock after read, expected %h", uut.dout, chk_rd_data));
                check(uut.datapath_inst.valid[chk_rd_slot] === 1'b0,
                      $sformatf("slot %0d valid bit not cleared after read", chk_rd_slot));
            end
            check(uut.datapath_inst.count === model_count,
                  $sformatf("count is %0d, expected %0d", uut.datapath_inst.count, model_count));
            check(uut.full  === (model_count == 8),
                  $sformatf("full flag is %b with %0d entries", uut.full, model_count));
            check(uut.empty === (model_count == 0),
                  $sformatf("empty flag is %b with %0d entries", uut.empty, model_count));

            // ---- 2. Enable pulse rules ----
            check(!(uut.wr_en && wr_en_d), "write enable stayed high for more than 1 cycle");
            check(!(uut.rd_en && rd_en_d), "read enable stayed high for more than 1 cycle");
            check(!(uut.wr_en && uut.rd_en), "write and read enable high together");
            check(!(uut.wr_en && uut.full),  "write enable asserted while FIFO is full");
            check(!(uut.rd_en && uut.empty), "read enable asserted while FIFO is empty");

            // ---- 3. New operations accepted at THIS edge ----
            chk_wr_pending = 0;
            chk_rd_pending = 0;

            if (uut.wr_en && !uut.full) begin
                check(uut.datapath_inst.wptr == model_wptr,
                      $sformatf("write pointer is %0d, expected %0d", uut.datapath_inst.wptr, model_wptr));
                $display("[%0d ns]   DUT: WRITE accepted  din=%0h -> slot %0d | count %0d -> %0d",
                         $time, uut.din, model_wptr, model_count, model_count + 1);
                exp_q.push_back(uut.din);
                chk_wr_pending = 1;
                chk_wr_data    = uut.din;
                chk_wr_slot    = model_wptr;
                model_wptr     = (model_wptr + 1) % 8;
                model_count++;
                wr_total++;
                t_last_wr = $time;
            end

            if (uut.rd_en && !uut.empty) begin
                check(uut.datapath_inst.rptr == model_rptr,
                      $sformatf("read pointer is %0d, expected %0d", uut.datapath_inst.rptr, model_rptr));
                if (exp_q.size() == 0) begin
                    check(0, "read accepted but model FIFO is empty");
                end else begin
                    chk_rd_data    = exp_q.pop_front();
                    chk_rd_slot    = model_rptr;
                    chk_rd_pending = 1;
                    $display("[%0d ns]   DUT: READ  accepted  slot %0d -> dout must become %0h on next clock | count %0d -> %0d",
                             $time, model_rptr, chk_rd_data, model_count, model_count - 1);
                    model_rptr = (model_rptr + 1) % 8;
                    model_count--;
                    rd_total++;
                    t_last_rd = $time;
                end
            end

            wr_en_d = uut.wr_en;
            rd_en_d = uut.rd_en;
        end
    end

    //------------------------------------------------------------
    // DRIVER tasks: one task call = one instruction
    //------------------------------------------------------------
    task automatic do_reset();
        rstn = 0; write_valid = 0; read_ready = 0; din = 0;
        exp_q.delete();
        model_count = 0; model_wptr = 0; model_rptr = 0;
        #20;
        rstn = 1;
        repeat (5) @(posedge clk);
        check(uut.datapath_inst.count === 0,       "count not 0 after reset");
        check(uut.datapath_inst.valid === 8'b0,    "valid bits not 0 after reset");
        check(uut.empty === 1'b1,                  "empty not set after reset");
        check(uut.full  === 1'b0,                  "full set after reset");
        $display("[%0d ns] Reset released: count=0, all valid bits 0, empty=1, full=0", $time);
    endtask

    task automatic instr_write(input logic [3:0] data);
        int wr_before, exp_delta, lat;
        time t_press;
        instr_no++;
        exp_delta = (model_count < 8) ? 1 : 0;
        wr_before = wr_total;
        if (exp_delta)
            $display("\n[%0d ns] INSTR #%0d: WRITE %0h   (FIFO has %0d/8, expect it to be stored in slot %0d)",
                     $time, instr_no, data, model_count, model_wptr);
        else
            $display("\n[%0d ns] INSTR #%0d: WRITE %0h   (FIFO is FULL, expect it to be IGNORED)",
                     $time, instr_no, data);

        @(negedge clk);
        din = data;
        write_valid = 1;
        t_press = $time;
        repeat (HOLD_CYC) @(posedge clk);
        @(negedge clk);
        write_valid = 0;
        repeat (HOLD_CYC) @(posedge clk);

        check(wr_total - wr_before == exp_delta,
              $sformatf("one press caused %0d writes, expected %0d", wr_total - wr_before, exp_delta));
        if (exp_delta) begin
            lat = (t_last_wr - t_press) / 10;
            check(lat <= MAX_LAT, $sformatf("write took %0d cycles after press (limit %0d)", lat, MAX_LAT));
            $display("          -> write done ~%0d clocks after the press", lat);
        end else
            $display("          -> correctly ignored, count still %0d", model_count);
    endtask

    task automatic instr_read();
        int rd_before, exp_delta, lat;
        logic [3:0] exp_val;
        time t_press;
        instr_no++;
        exp_delta = (model_count > 0) ? 1 : 0;
        rd_before = rd_total;
        if (exp_delta) begin
            exp_val = exp_q[0];
            $display("\n[%0d ns] INSTR #%0d: READ         (FIFO has %0d/8, expect %0h from slot %0d)",
                     $time, instr_no, model_count, exp_val, model_rptr);
        end else
            $display("\n[%0d ns] INSTR #%0d: READ         (FIFO is EMPTY, expect it to be IGNORED)",
                     $time, instr_no);

        @(negedge clk);
        read_ready = 1;
        t_press = $time;
        repeat (HOLD_CYC) @(posedge clk);
        @(negedge clk);
        read_ready = 0;
        repeat (HOLD_CYC) @(posedge clk);

        check(rd_total - rd_before == exp_delta,
              $sformatf("one press caused %0d reads, expected %0d", rd_total - rd_before, exp_delta));
        if (exp_delta) begin
            lat = (t_last_rd - t_press) / 10;
            check(lat <= MAX_LAT, $sformatf("read took %0d cycles after press (limit %0d)", lat, MAX_LAT));
            check(uut.dout === exp_val,
                  $sformatf("dout is %h after read, expected %h", uut.dout, exp_val));
            $display("          -> read done ~%0d clocks after the press, dout = %0h (expected %0h)",
                     lat, uut.dout, exp_val);
        end else
            $display("          -> correctly ignored, count still %0d", model_count);
    endtask

    //------------------------------------------------------------
    // Test sequence
    //------------------------------------------------------------
    logic [3:0] vals [8] = '{4'h5, 4'h2, 4'h9, 4'h0, 4'h7, 4'h1, 4'h8, 4'h3};

    initial begin
        $display("=== PHASE 1: reset ===");
        do_reset();

        $display("\n=== PHASE 2: read on an empty FIFO (must be ignored) ===");
        instr_read();

        $display("\n=== PHASE 3: fill the FIFO with 8 values ===");
        for (int i = 0; i < 8; i++) instr_write(vals[i]);
        check(uut.full === 1'b1, "FIFO should be full after 8 writes");

        $display("\n=== PHASE 4: write on a full FIFO (must be ignored) ===");
        instr_write(4'h6);

        $display("\n=== PHASE 5: read 3 values (must come out in write order) ===");
        for (int i = 0; i < 3; i++) instr_read();

        $display("\n=== PHASE 6: write 2 more values (write pointer wraps around) ===");
        instr_write(4'h4);
        instr_write(4'h6);

        $display("\n=== PHASE 7: drain the FIFO completely ===");
        for (int i = 0; i < 7; i++) instr_read();
        check(uut.empty === 1'b1, "FIFO should be empty after draining");

        $display("\n=== PHASE 8: read on an empty FIFO again (must be ignored) ===");
        instr_read();

        $display("\n=== PHASE 9: interleaved write then read, 10 times ===");
        for (int i = 0; i < 10; i++) begin
            instr_write(i[3:0]);
            instr_read();
        end

        repeat (5) @(posedge clk);
        check(model_count == 0 && exp_q.size() == 0, "model should be empty at the end");

        $display("\n================ SUMMARY ================");
        $display("Instructions issued : %0d", instr_no);
        $display("Writes accepted     : %0d", wr_total);
        $display("Reads accepted      : %0d", rd_total);
        $display("Checks performed    : %0d", checks);
        $display("Errors              : %0d", errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: TEST FAILED");
        $finish;
    end

    initial begin
        #5_000_000;
        $display("RESULT: TIMEOUT");
        $finish;
    end

endmodule