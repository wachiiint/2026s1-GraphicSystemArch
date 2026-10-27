# Graphical System Architecture — Workspace

## Description
This is a part of Graphical System Architecture \
Containing 5 projects for this semester

## Group member
1. Wachi: Wachiraphut Intarachart [\@wachiiint](https://github.com/wachiiint)
2. Effpy: Passakorn Yangmak [\@Quackudy](https://github.com/Quackudy)

## Index
1. [`LAB1-FlappyBird`]
    - A simple Flappy Bird game, press up arrow to fly
    - Hard coded plain graphic,
    - Source code is in LAB1/code/project.v
    - See demo in [LAB1.md](./LAB1.md)
2. [`LAB2-TextEditor`]
    - Simple logic to code
    - Difficult for user to type
    - Source code is in LAB2/code/project.v
    - See demo in [LAB2.md](./LAB2.md)
3. [`LAB3-ImageTransition`]
    - Image transition like PowerPoint
    - Use the cutest creature in New Eridu as the model to display
    - Select transition mode by __TBA__
4. LAB4 — _TBD_
5. LAB5 — _TBD_

## Project setup
This workspace will run on localhost (Vite dev server, default http://localhost:5173) \
VgaEngine cloned from https://vga-playground.com/ under their license \
Run following code to install dependencies and start each lab
```bash
# setup
cp .env.example .env
cd vgaEngine
npm install
## change the `compilePath=LAB*/code` to the active lab directory e.g. LAB1/code
npm start
```

## Workflow:
1. Run `npm start` and open http://localhost:5173
2. Edit the `.v` files in `LAB*/code/` with IDE
3. Refresh the browser (F5) to reload and see the new behavior

note: 
- Each lab's code lives in `LAB*/code/`. When open http://localhost:5173,
- The playground loads every `.v` file from that folder as the default preset **"My Project (code/)"** and starts simulating it right away.
- `code/project.v` must contain the top module (`tt_um_*`)

⚠️ Edits made in the **web editor** are not saved to disk — they live in the
browser only and are lost on refresh. Always edit in VSCode; use the web page
just to run and view the game.
