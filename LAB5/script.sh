# Generate .mem files for LAB5 (run from Workspace root, line by line)
cd LAB5
mkdir -p data
uv run image2hex.py TinyTropicalTiles_Tileset.png data/tiny_tropical_tiles.mem
uv run image2hex.py character/Dude_Monster_Idle_Walk_Run_Jump.png data/dude_monster.mem

# 11x4 = 44 tiles, 704 lines -> data/tiny_tropical_tiles.mem
# 8x4 = 32 tiles, 512 lines -> data/dude_monster.mem