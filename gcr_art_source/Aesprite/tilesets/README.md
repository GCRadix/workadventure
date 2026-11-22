# Office tilesets

One subfolder per tileset. Each has its own `export.ps1`, `README.md` and `slotmap.tsv`.

| Folder | Tileset | Source |
|---|---|---|
| `floor\` | **brick**, **carpet**, **planks**, … (one per type) | `<type>\<type>.aseprite` + `<type>\NN_<colour>.gpl`, built by `build_floors.lua` (512 px / 16 columns wide) |
| `walls\` | **walls** | `walls_master.aseprite` + `palettes\NN_<colour>.gpl`, built by `build_walls.lua` (256 px / 8 columns) |

Each export writes into an `out\` folder next to its script: `floor\out\<type>.png/.tsx`, `walls\out\walls.png/.tsx`.

**Colours are numbered palettes:** `NN_<colour>.gpl`. For walls, `NN` is the colour band (01 = top). For floors, each frame of a project is a pattern and every pattern/colour pair gets a row. New frames and colours are appended at the bottom, and `<type>\slotmap.tsv` remembers the rows. Existing tile IDs never move, and the export stops if one would (see `floor\README.md`).

```powershell
.\export_all.ps1                     # every tileset
.\export_all.ps1 -CopyTo <folder>    # + copy the .png/.tsx files there (e.g. next to a map)
.\walls\export.ps1                   # just one
```

`_common.ps1` holds the shared export code (Aseprite path, width check, `.tsx` writer). Set `$env:ASEPRITE` if Aseprite lives somewhere else.

## Rules for every tileset (Tiled stores tiles by index)

1. **Each tileset's width is fixed** (floor types 512 px / 16 columns, walls 256 px / 8 columns). Grow sheets downwards only. The export stops with an error otherwise.
2. **Never move or delete a tile that is in use.** Fill empty slots or add rows.
3. Index = `row * columns + col` (0-based; floors 16 columns, walls 8) = the tile ID Tiled shows.
4. Everything in `out\` is generated. Never edit it directly.

## New tileset

Make a folder with its source and an `export.ps1` modelled on `floor\export.ps1` (or `walls\` if it's colour variants of the same pieces). `export_all.ps1` picks it up automatically.

## Using them in Tiled

Map → Add External Tileset → pick the `.tsx`, then click **Embed Tileset** in the Tilesets panel (WorkAdventure needs embedded tilesets; the PNG stays a separate file next to the map). If a sheet grows later, re-export and reopen the map. If the new rows don't show up, open Tileset Properties and re-pick the same image so Tiled recounts the tiles. Existing tile IDs stay the same.

Furniture and decoration (tables, computers, plants…) do **not** go in tilesets. They are single-image entities in WorkAdventure's map-editor collections (`play/public/collections/*.json`).
