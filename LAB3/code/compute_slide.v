`ifndef COMPUTE_H
`define COMPUTE_H

`default_nettype none

parameter MAX_T = 640;  // maximum time of the transition

module compute_slide #(
    parameter IMG_SIZE = 320,  // number pixel per lines
    parameter MUL_FACTOR = 2   // vga_res/img_size
    // parameter DISPLAY_WIDTH = 320;  // VGA display width
    // parameter DISPLAY_HEIGHT = 240;  // VGA display height
)(
    input wire [9:0]    xin, // pix_x input
    input wire [9:0]    yin, // pix_y input
    input wire          clk,
    input wire          fsync,
    input wire          rst_n,
    output wire [5:0]   out // color
);
    reg [5:0] img1[76799:0];  // 320x240 word, 1 word = 6 bit{R,G,B}
    // reg [5:0] img2[76799:0]; 

    initial begin
        $readmemh("../data/img.mem", img1);
        // $readmemh("../data/img.mem", img2);
    end

    reg [16:0] counter;
    reg f_prev; // last fsync
    always @(posedge clk) begin
        if(~rst_n) counter <= 0;
        else if (~f_prev & fsync) 
        counter <= counter == MAX_T ? 0: counter + 1; // +1 when complete the render frame
        f_prev <= fsync;
    end

    /*
    do the math equation without always block
    counter + 1 when for each complete render loop
    avg FPS = 45
    */

    //
    wire [11:0] x,y;
    
    // assign x = xin + counter;
    // assign y = yin;

    assign x = xin + counter;
    assign y = yin;


    wire[16:0] mem_index = (y / MUL_FACTOR) * IMG_SIZE + (x / MUL_FACTOR);  // read 6 bit at (y/2*320)
    assign out = x>= MAX_T ? 0 : img1[mem_index];

endmodule

`endif