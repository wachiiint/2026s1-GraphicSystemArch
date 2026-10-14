#install this first
#sudo pip install pillow
#modify res, bitdepth according to your need
#current: 320x240, RGB: 222

import sys
from PIL import Image, ImageOps

if len(sys.argv) < 3:
    print("Usage: img.jpg img.mem")
    sys.exit()

input_file = sys.argv[1]
output_file = sys.argv[2]

im = Image.open(input_file)
im = im.convert("RGB")
im = ImageOps.pad(im, (320,240), color=(0,0,0))  # keep aspect ratio, black bars

# 64-color palette: index = r*16 + g*4 + b, each channel level 0..3 -> 0,85,170,255
palette = []
for i in range(64):
    palette += [(i >> 4 & 3) * 85, (i >> 2 & 3) * 85, (i & 3) * 85]
pal_im = Image.new("P", (1,1))
pal_im.putpalette(palette)

# nearest palette color (= rounding per channel) + Floyd-Steinberg dithering
im = im.quantize(palette=pal_im, dither=Image.Dither.FLOYDSTEINBERG)
data = im.getdata()

with open(output_file, 'w') as f:
    for x in data:
        f.write(hex(x)[2:])
        f.write("\n")
