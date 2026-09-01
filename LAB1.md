# LAB1 — TinyVGAPlayground

## Description
I will do either flappybird / snake game in this project

## Setup
```bash
# setup
cd LAB1
npm install

# run on localhost (Vite dev server, default http://localhost:5173)
npm start
```

## How it works
Our game code lives in `LAB1/code/`. When you open http://localhost:5173,
the playground loads every `.v` file from that folder as the default preset
**"My Project (code/)"** and starts simulating it right away.

Workflow:
1. Run `npm start` and open http://localhost:5173
2. Edit the `.v` files in `LAB1/code/` with IDE
3. Refresh the browser (F5) to reload and see the new behavior

Rules to know:
- `code/project.v` must contain the top module, and its name must start with `tt_um_`
- Every module that `project.v` instantiates needs its own `.v` file in `code/`
  (e.g. `hvsync_generator.v` for VGA timing, `gamepad_pmod.v` for controller input)
- Compile errors show up as an overlay + red markers in the web editor

⚠️ Edits made in the **web editor** are not saved to disk — they live in the
browser only and are lost on refresh. Always edit in VSCode; use the web page
just to run and view the game.
