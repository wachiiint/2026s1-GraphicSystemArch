`default_nettype none

module background_ram (
    input wire clk,
    input wire vsync,
    input wire [9:0] addr, // {x[5:0], y[3:0]} in world tiles.
    output reg [5:0] data
);
  wire [5:0] x = addr[9:4];
  wire [3:0] y = addr[3:0];

  wire left_edge = x == 6'd3 || x == 6'd12 || x == 6'd24;
  wire right_edge = x == 6'd5 || x == 6'd15 || x == 6'd26;

  reg [10:0] counter = 11'd0;

  always @(posedge vsync) begin
    counter <= counter + 11'd1;
  end

  always @(posedge clk) begin
    if ((x >= 6'd3 && x <= 6'd5) ||
        (x >= 6'd12 && x <= 6'd15) ||
        (x >= 6'd24 && x <= 6'd26)) begin
      if (y == 4'd11)
        data <= left_edge ? 6'd12 : right_edge ? 6'd14 : 6'd13;
      else if (y >= 4'd12)
        data <= left_edge ? 6'd23 : right_edge ? 6'd25 : 6'd24;
      else
        data <= 6'd39;
    end else
      data <= 6'd39;
  end
endmodule

`default_nettype wire
