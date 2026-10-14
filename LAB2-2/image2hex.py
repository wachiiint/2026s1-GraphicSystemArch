#install this first
#sudo pip install pillow
#modify res, bitdepth according to your need
#current: 320x240, RGB: 222

import sys
from PIL import Image

if len(sys.argv) < 3:
    print("Usage: img.jpg img.mem")
    sys.exit()
    
input_file = sys.argv[1]
output_file = sys.argv[2]

im = Image.open(input_file);
im = im.resize((320,240))
im = im.convert("RGB")
data = im.getdata()

with open(output_file, 'w') as f:
    for d in data:
        r = int(d[0] / 64)
        g = int(d[1] / 64)
        b = int(d[2] / 64)
        x = int(r * 16 + g * 4 + b)
        f.write(hex(x)[2:])
        f.write("\n")
