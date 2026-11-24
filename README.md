# 8-Entry FIFO with 7-Segment Display (SystemVerilog)

A 4-bit wide, 8-deep synchronous FIFO with a multiplexed 8-digit 7-segment display that shows the contents of every slot. Empty slots are blank.

## Structure

```
rtl/
  fifo_top.sv           top module (set this as the synthesis top)
  fifo_datapath.sv      memory, read/write pointers, count, full/empty, per-slot valid bits
  fifo_fsm.sv           IDLE / WRITE / READ controller (one operation per button press)
  input_cond.sv         synchronizer + debounce + rising-edge pulse for buttons
  display_controller.sv scanning 7-segment driver (blanks slots that are not valid)
tb/
  tb_fifo.sv            self-checking testbench (set this as the simulation top)
```

## How it works

- `write_valid` and `read_ready` are buttons. Each press is synchronized, debounced and turned into a single one-cycle pulse by `input_cond`, so one press performs exactly one write or read.
- Set `din` before pressing write.
- Writing while full or reading while empty is ignored.
- Each slot has a valid bit. The display shows a slot only while its valid bit is set, so a stored `0` is shown as `0` and an empty slot is blank.
- Display outputs are active-low (`seg` bit pattern `1000000` is the digit 0, `an` is one-hot active-low).

## Parameters

| Module    | Parameter       | Default | Meaning |
|-----------|-----------------|---------|---------|
| `fifo_top`| `DEBOUNCE_BITS` | 20      | Debounce counter width (about 10 ms at 100 MHz). The testbench uses 2. |

## Simulation

The testbench is self-checking. It drives writes and reads through the button inputs, compares every operation against a reference model, and prints one log line per instruction. It checks:

- read data comes out in write order
- read/write pointers and wrap-around
- `count`, `full` and `empty` on every clock
- stored data and valid bits one clock after a write, `dout` and cleared valid bit one clock after a read
- enable pulses last exactly one cycle
- writes while full and reads while empty are ignored

A passing run ends with `RESULT: ALL TESTS PASSED`. It was run on Aldec Riviera-PRO (EDA Playground) with 0 errors.

To run it, compile everything in `rtl/` plus `tb/tb_fifo.sv` with a SystemVerilog simulator and use `tb_fifo` as the top module.

## Known limitations

- The display scan clock uses `clkdiv[15]` as a derived clock. It works, but a clock-enable on `clk` is cleaner for FPGA builds.
- `din` is not synchronized, which is fine for slow switches.
- If write and read are pressed in the same cycle, write wins and the read is dropped.
- The display outputs (`seg`, `an`) are not checked by the testbench.
- No board constraints file is included.
