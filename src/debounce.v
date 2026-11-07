`default_nettype none

// Active-high pushbutton debouncer with auto-repeat.
//   in  = 010001011111111111
//   out = 000000001001001001   (STABLE_CYCLES = 2, REPEAT_CYCLES = 3)
// - Noise: in must stay high for STABLE_CYCLES before the first pulse.
// - Long press: one more pulse every REPEAT_CYCLES while in stays high.
// out is a one-clock pulse, 3 clocks after in (2 sync + 1 register).
// With a 25 MHz clock: 250,000 cycles = 10 ms, 1,250,000 cycles = 50 ms.
module debounce #(
    parameter STABLE_CYCLES = 250_000,   // noise filter
    parameter REPEAT_CYCLES = 250_000  // long-press repeat period
)(
    input  wire clk,
    input  wire in,
    output reg  out
);

    localparam HW = $clog2(STABLE_CYCLES + 1);
    localparam RW = $clog2(REPEAT_CYCLES + 1);

    // Synchronizer: safely sample a signal that changes outside clk's timing.
    reg sync_0;
    reg sync_1;

    reg [HW-1:0] hold;    // cycles in has been high, stops at STABLE_CYCLES-1
    reg [RW-1:0] repeat_cnt; // cycles left until the next pulse

    // FPGA power-up values. No reset port is needed.
    initial begin
        sync_0     = 1'b0;
        sync_1     = 1'b0;
        hold       = 0;
        repeat_cnt = 0;
        out        = 1'b0;
    end

    always @(posedge clk) begin
        sync_0 <= in;
        sync_1 <= sync_0;

        out <= 1'b0;

        if (!sync_1) begin
            hold       <= 0;
            repeat_cnt <= 0;
        end else if (hold != STABLE_CYCLES - 1) begin
            hold <= hold + 1'b1;
        end else if (repeat_cnt == 0) begin
            out        <= 1'b1;
            repeat_cnt <= REPEAT_CYCLES - 1;
        end else begin
            repeat_cnt <= repeat_cnt - 1'b1;
        end
    end

endmodule

`default_nettype wire
