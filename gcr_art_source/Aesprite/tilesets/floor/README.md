# Floor tilesets — one tileset per type

Each subfolder is one floor **type** (brick, carpet, planks…) and becomes its own Tiled tileset `out\<type>.png/.tsx`.

```
floor\
  <type>\<type>.aseprite   Indexed. Each FRAME = one pattern (a row of tiles). Max 512 px (16 tiles) wide
  <type>\NN_<colour>.gpl   one palette per colour; NN fixes the colour's order
  <type>\slotmap.tsv       generated: which tileset row each pattern/colour has. KEEP IT (it keeps ids stable)
  build_floors.lua         builds all types
  export.ps1               -> out\<type>.png + out\<type>.tsx
```

## Layout (16 columns, fixed)

Every (pattern, colour) pair gets one row. The first export groups by pattern:

```
row 0   frame 1 in 01_brown     ▢ ▢ ▢ … (tile designs = columns)
row 1   frame 1 in 02_grey
…
row 6   frame 2 in 01_brown
row 7   frame 2 in 02_grey
…
```

After that, **existing rows never move**. New pairs are appended at the bottom:
- **New frame (pattern):** a block of that pattern in every colour.
- **New colour:** one row per pattern in that colour.

Tile ID = `row × 16 + column`. `slotmap.tsv` lists every row (`#row <row> <frame>:<row_in_frame> <colour_no> <colour>`) and every tile ID.

## Adding things

- **New pattern:** add a frame at the **end** of the timeline and export.
- **New tile in a pattern:** draw it in the next free column on the **right** and export. It appears in every colour at once.
- **New colour:** add a `.gpl` with the next free number (for example `07_sand.gpl`) and export.
- **New type:** make `floor\<type>\<type>.aseprite` (Indexed) plus `01_<colour>.gpl`…, then export. A project without `.gpl` files is exported once with its own palette.
- **Rename a colour:** change only the part after the number. IDs stay the same.
- **Delete a colour or frame:** its rows stay in the tileset (empty or unchanged), so nothing below them moves.
- Only what's inside the canvas is exported. Pixels outside it are ignored.

## What the export checks

It stops and changes nothing (no `out\` files and no copy) when:
- a palette file has no number, or two palettes share a number;
- a project is wider than 16 tiles or not a multiple of 32 px;
- compared with the last export, a tile design **moved** to another column or frame (something was inserted or reordered), or a tile disappeared.

A redrawn tile in the same place only gives a warning: its ID stays the same.

`.\export.ps1 -Force` accepts the change and **lays out the whole tileset fresh** (grouped by pattern again). Only use it for a type that no map uses yet.

## Legacy sheet

`maps/assets/walls_floors/gcr/floors_legacy.png` is the old 8-column floor sheet. `maps/starter/map.json` still paints its floor with it (old tiles 2 and 10). The export does not rebuild it. Once those areas are repainted with the new tilesets, the legacy tileset can be removed from the map.
