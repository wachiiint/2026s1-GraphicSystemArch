`ifndef COMPUTE_H
`define COMPUTE_H

`default_nettype none

parameter MAX_T = 640;      // maximum time of the transition
parameter BLOCK = 16;       // block size 2^^n
parameter BAND = 1;         // BAND of changing
parameter T_SCALE = 4;      // TIME SCALING

module compute_fade #(
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
    reg [5:0] img1[76799:0];  // 320x240 word, 1 word = 6 bit{R,G,B)

    initial begin
        $readmemh("../data/img.mem", img1);
    end

    reg [15:0] counter;
    reg [15:0] tick;
    reg f_prev; // last fsync
    always @(posedge clk) begin
        if(~rst_n) begin
            counter <= 0;
            tick <= 0;
        end
        else if (~f_prev & fsync) 
            counter <= counter == MAX_T ? 0: counter + 1; // +1 when complete the render frame
        
        f_prev <= fsync;
        tick <= counter / T_SCALE;
    end
    /*
    do the math equation without always block
    tick + 1 when for each complete render loop
    avg FPS = 45
    fade by manhuttan distance from mid right (x0, y0)
    */

    //
    wire [11:0] x,y; //640, 480
    wire [11:0] xb,yb; // block
    wire [11:0] dx,dy; // diff
    assign x = xin;
    assign y = yin;
    assign xb = x / BLOCK;
    assign yb = y / BLOCK;

    localparam x0 = 639 / BLOCK;
    localparam y0 = 239 / BLOCK;
    wire[16:0] mem_index = (y / MUL_FACTOR) * IMG_SIZE + (x / MUL_FACTOR); 
    wire [5:0] color = img1[mem_index];
    
    assign dx = (xb > x0 ? xb-x0 : x0-xb) * 2 / 3; // from *0.667 cuz aspect ration 640x480 idk
    assign dy = yb > y0 ? yb-y0 : y0-yb;
    // wire in_pass = (dx+dy) == tick; // currently passing
    wire in_pass = tick >= (dx+dy) & tick - (dx+dy) < BAND; // currently passing
    wire is_pass = tick >= (dx+dy) & tick - (dx+dy) >= BAND; // already passed

    localparam GRAY = 6'b101010;

    /*
    if passing -> graining effect in chess pattern with GREY 333 for 2 bit color
    if passed -> negative image
    */
    assign out =    in_pass ? ((x & 3'b100) ^ (y & 3'b100) ? color : GRAY): 
                    is_pass ? ~color : color;

endmodule

`endif