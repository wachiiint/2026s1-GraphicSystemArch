`default_nettype none

// Simple dual-port RAM for text cells.
// One port writes an ASCII code; the other port reads the code requested by VGA.
// Default capacity is 2^12 = 4096 bytes, enough for an 80 x 30 text screen.
module simple_dp_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12
) (
    input  wire                  clk,

    // Write port: write dat_in into memory[wr_adr] when wr_en is 1.
    input  wire [DATA_WIDTH-1:0] dat_in,
    input  wire [ADDR_WIDTH-1:0] wr_adr,
    input  wire                  wr_en,

    // Read port: dat_out receives memory[rd_adr] one clock later.
    input  wire [ADDR_WIDTH-1:0] rd_adr,
    output reg  [DATA_WIDTH-1:0] dat_out
);

    // Vivado may infer this as FPGA block RAM.
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] memory [0:(1 << ADDR_WIDTH)-1];

    // Same simple-dual-port structure and ordering as the lecture slide.
    always @(posedge clk) begin
        if (wr_en)
            memory[wr_adr] <= dat_in;

        dat_out <= memory[rd_adr];
    end

endmodule

`default_nettype wire
