`default_nettype none

// Active-high pushbutton debouncer and one-shot pulse generator.
// With a 25 MHz clock, 250,000 cycles = 10 ms.
module debounce (
    input  wire clk,
    input  wire noisy_button,
    output reg  clean_button
);

    localparam [17:0] STABLE_CYCLES = 18'd250_000;

    // Synchronizer: safely sample a signal that changes outside clk's timing.
    reg sync_0;
    reg sync_1;

    // Debounced state and time spent seeing a different input value.
    reg stable_button;
    reg [17:0] counter;

    // FPGA power-up values. No reset port is needed.
    initial begin
        sync_0        = 1'b0;
        sync_1        = 1'b0;
        stable_button = 1'b0;
        counter       = 18'd0;
        clean_button  = 1'b0;
    end

    always @(posedge clk) begin
        sync_0 <= noisy_button;
        sync_1 <= sync_0;

        // Default: clean_button is a one-clock pulse, not a held level.
        clean_button <= 1'b0;

        if (sync_1 == stable_button) begin
            // No pending state change.
            counter <= 18'd0;
        end else if (counter == STABLE_CYCLES - 1'b1) begin
            // The new state survived the whole debounce interval.
            stable_button <= sync_1;
            counter <= 18'd0;

            // Pulse only for a debounced press, never for a release.
            if (sync_1)
                clean_button <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
        end
    end

endmodule

`default_nettype wire
