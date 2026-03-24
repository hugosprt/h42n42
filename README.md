# H42N42

Interactive web simulation where Creets survive a toxic environment and a contagious virus. The client is written in OCaml and compiled to JavaScript with `js_of_ocaml`, then served by `ocsigenserver`.

## Objectives

- Simulate moving Creets in a rectangular world
- Toxic river contamination at the top
- Manual drag-and-drop healing in the hospital at the bottom
- Virus spread on contact
- Progressive difficulty over time
- Game over when no healthy Creet remains

## Prerequisites

- Docker
- Docker Compose plugin (`docker compose`) or legacy `docker-compose`

## Project structure

- `src/main.eliom`: main simulation source
- `src/dune`: dune build description
- `static/index.html`: page entrypoint
- `static/style.css`: game styles
- `static/game.js`: generated JavaScript bundle (created by `make all` during image build or local build)
- `h42n42.conf.in`: Ocsigen server configuration
- `Makefile`: build automation (`all`, `clean`, `fclean`, `re`)
- `Dockerfile`: container build instructions
- `docker-compose.yml`: one-command deployment

## Build and run (Docker)

```bash
docker-compose up --build
```

or:

```bash
docker compose up --build
```

Then open:

- [http://localhost:8080/index.html](http://localhost:8080/index.html)

## Local build commands

```bash
make all
make clean
make fclean
make re
```

## Mandatory gameplay rules implemented

- Creets move linearly with random direction changes and boundary reflection
- One movement Lwt thread per Creet
- Drag-and-drop interaction with mouse
- Dragging grants contamination immunity
- River contact contaminates healthy Creets immediately
- Sick Creets move 15% slower
- Contact contamination uses center-distance and radius overlap with 2% chance per iteration
- Hospital healing occurs only on manual drop of regular sick Creets
- Berserk and mean Creets cannot be dragged/healed
- Berserk behavior:
  - 10% special roll every 10 seconds after contamination
  - grows 10% every 10 seconds
  - dies at 4x original size
- Mean behavior:
  - 10% special roll every 10 seconds after contamination
  - shrinks to 85% size
  - chases nearest healthy Creet
  - dies after 60 seconds
- New Creets spawn periodically while at least one healthy Creet exists
- Global speed factor increases over time (difficulty progression)
- Clear `GAME OVER` overlay when no healthy Creet remains

## Bonus features

No bonus-specific features are claimed in this version.

## Notes

- `src/main.eliom` is the main authored source file used by the Makefile pipeline.
- `make all` generates `static/game.js`, which is served by Ocsigen.
- `docker compose up --build` builds the JavaScript inside the image and starts the server without writing generated files into the host workspace.
