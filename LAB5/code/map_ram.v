`default_nettype none

module map_rom (
    input wire clk,
    input wire vsync,
    input wire [9:0] addr, // {x[5:0], y[3:0]} in world tiles.
    output reg [5:0] data
);
  wire [5:0] x = addr[9:4];
  wire [3:0] y = addr[3:0];

  reg [10:0] counter = 11'd0;

  always @(posedge vsync) begin
    counter <= counter + 11'd1;
  end

  always @(posedge clk) begin
    if (x >= 6'd11 && x <= 6'd15 && y == 4'd13) begin
      data <= 4 + 11 * counter[4:3];
    end
    else if (x >= 6'd11 && x <= 6'd15 && y == 4'd14) begin
      data <= 5;
    end
    else if (x == 6'd10 && y == 4'd14) begin
      data <= 25;
    end
    else if (x == 6'd10 && y == 4'd13) begin
      data <= 14;
    end
    else if (x == 6'd16 && y == 4'd14) begin
      data <= 23;
    end
    else if (x == 6'd16 && y == 4'd13) begin
      data <= 12;
    end
    else if (y == 4'd13) begin
      data <= 6'd13;
    end else if (y == 4'd14) begin
      data <= 6'd24;
    end
    else begin
      data <= 6'd63; // Empty foreground cell; show the background layer.
    end

    case (addr)
      // Palms rooted at (4,12) and (22,12), above the banks.
      {6'd3,4'd9}, {6'd21,4'd9}: data <= 6'd8;
      {6'd4,4'd9}, {6'd22,4'd9}: data <= 6'd9;
      {6'd5,4'd9}, {6'd23,4'd9}: data <= 6'd10;
      {6'd3,4'd10}, {6'd21,4'd10}: data <= 6'd19;
      {6'd4,4'd10}, {6'd22,4'd10}: data <= 6'd20;
      {6'd5,4'd10}, {6'd23,4'd10}: data <= 6'd21;
      {6'd4,4'd11}, {6'd22,4'd11}: data <= 6'd18;
      {6'd4,4'd12}, {6'd22,4'd12}: data <= 6'd40;

      {6'd1,4'd12}, {6'd9,4'd12}, {6'd17,4'd12}: data <= 6'd30;
      {6'd7,4'd12}, {6'd25,4'd12}, {6'd28,4'd12}: data <= 6'd41;
      default: ;
    endcase

  end
endmodule

`default_nettype wire
