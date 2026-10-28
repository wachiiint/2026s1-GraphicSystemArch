# LAB3 — Image transition

## Description
Have u seen transition seen in indian movie ??? \
Now we will try to do that using limited memory but extra VFX !! \
Btw, using the cutest creature as a display model in the world. \
(credit source image to [ZZZ Ellen EP](https://youtu.be/cK1ABiGuiG0?si=rPRwHuZNclKfR6ib))
## Dependencies
```
uv init
uv add pillow
# source .venv/bin/activate
```

## Manual

Generate mem for image
```
cd LAB3
mkdir -p data
#python image2hex.py <image_path> data/img.mem
uv run image2hex.py <image_path> data/img.mem
```

Start program
- Run `npm start` in `vgaEngine/`
- Open `localhost:5173` in browser
- The video transition will automaticly play
- 2 option of transition: slide/fade \
    change module name to match in `project.v:22`

## Demo
-- 


