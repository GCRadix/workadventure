# walls tileset

The wall pieces are drawn **once** in `walls_master.aseprite`; every colour is generated from a palette.

| File | Role |
|---|---|
| `walls_master.aseprite` | The 6 pieces (32×64 each), Indexed mode. Index 0 = transparent, 1–4 = dark → light. 256×64. |
| `palettes\NN_<colour>.gpl` | One palette per colour, same 5 entries in the same order. NN = colour band (01 = top). |
| `build_walls.lua` | Builds `walls.png` from master + palettes. |
| `export.ps1` | Runs the build, checks the sheet, writes `walls.tsx` (every wall tile gets `collides = true`). |
| `slotmap.tsv` | Tile index → name. |

Output: `out\walls.png` + `out\walls.tsx` via `.\export.ps1`. General rules: see `..\README.md`.

## Layout

Each colour is a 2-row band (top tile + bottom tile of each piece). Columns are the same in every colour:

| Col | Piece |
|---|---|
| 0 | end_left |
| 1 | top_trim |
| 2 | end_right |
| 3 | side_left |
| 4 | plain |
| 5 | side_right |
| 6 | **top tile**: edge_left · **bottom tile**: edge_right (32×32 pieces, two share a column) |
| 7 | free for a new piece (corner, doorway…) |

| Rows | Colour |
|---|---|
| 0–1 | Blue |
| 2–3 | Brown |
| 4–5 | Charcoal |
| 6–7 | Orange |
| 8–9 | Teal |
| 10+ | next palette number (06_…) |

Switching a wall's colour in Tiled = **+16 tile IDs per band** (2 rows × 8).

## Adding things

- **Change a piece / add a piece**: edit `walls_master.aseprite` (new pieces go in column 7), export. All colours update. A 32×32 piece only needs half a column.
- **New colour**: copy a `.gpl` in `palettes\` with the next free number (e.g. `06_green.gpl`), change the 4 colours (keep dark → light, keep entry 0 transparent), export. A missing number leaves an empty band, so nothing moves.
- **Preview a colour on the master**: Palette menu → Load Palette. The master's own palette doesn't affect the export.
