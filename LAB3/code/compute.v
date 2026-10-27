`ifndef COMPUTE_H
`define COMPUTE_H

`default_nettype none

module compute #(
    parameter IMG_SIZE = 320,  // Size of the image in pixels
    parameter MUL_FACTOR = 2   // vga_res/img_size
    // parameter DISPLAY_WIDTH = 320;  // VGA display width
    // parameter DISPLAY_HEIGHT = 240;  // VGA display height
)(
    input wire [9:0]    x, // pix_x
    input wire [9:0]    y, // pix_y
    input wire [15:0]   t, //Time tick in counter in ms ??
    input wire          rst_n,
    output wire [5:0]   out // color
);
    reg [5:0] img1[76799:0];  // 320x240 word, 1 word = 6 bit{R,G,B}
    wire [16:0] mem_index;

    initial begin
        $readmemh("../data/img.mem", img1);
        // $readmemh("../data/bg1.mem", img2);
    end

    assign mem_index = (y / MUL_FACTOR) * IMG_SIZE + x / MUL_FACTOR;  // read 6 bit at (y/2*320)
    assign out = img1[mem_index];
endmodule

`endif