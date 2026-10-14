Dependencies
```
# in Workspace
python -m venv .venv
source .venv/bin/activate
pip install pillow
```

Generate mem for image
```
cd LAB2-2
mkdir -p data
python image2hex.py <image_path> data/img.mem
```