# Slice a sprite sheet into 16x16 tiles -> .mem for $readmemh
# Usage: uv run image2hex.py <sheet.png> <out.mem>
#
# Tile order: row-major (left->right, top->bottom), tile id = row * cols + col
# One line = one tile row = 16 pixels x 7 bit = 112 bit (28 hex digits)
#   address  = tile_id * 16 + y
#   pixel x  = bits [(15 - x) * 7 +: 7]   (x = 0 at MSB)
#   pixel    = {opaque, R[1:0], G[1:0], B[1:0]}
# No dithering: keeps pixel art clean.

import sys
from PIL import Image

TILE = 16

if len(sys.argv) < 3:
    print("Usage: uv run image2hex.py <sheet.png> <out.mem>")
    sys.exit(1)

im = Image.open(sys.argv[1]).convert("RGBA")
if im.width % TILE or im.height % TILE:
    sys.exit(f"Size {im.width}x{im.height} is not a multiple of {TILE}")

cols, rows = im.width // TILE, im.height // TILE
px = im.load()


def to7(r, g, b, a):
    if a < 128:
        return 0  # transparent
    q = lambda c: (c + 42) // 85  # 0..255 -> 0..3 (nearest)
    return (1 << 6) | (q(r) << 4) | (q(g) << 2) | q(b)


with open(sys.argv[2], "w") as f:
    for ty in range(rows):
        for tx in range(cols):
            for y in range(TILE):
                word = 0
                for x in range(TILE):
                    word = (word << 7) | to7(*px[tx * TILE + x, ty * TILE + y])
                f.write(f"{word:028x}\n")

print(f"{cols}x{rows} = {cols * rows} tiles, {cols * rows * TILE} lines -> {sys.argv[2]}")
