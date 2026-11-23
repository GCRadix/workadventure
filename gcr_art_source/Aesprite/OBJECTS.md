# Map-editor objects

Chairs, computers, decoration, tables… are exported as one WorkAdventure **entity collection**, which shows up in the in-game map editor (Objects tool).

```powershell
.\export_objects.ps1                                   # build and copy into A:\Git\workadventure\maps\assets\gcr_objects
.\export_objects.ps1 -NoCopy                           # only build out\objects
.\export_objects.ps1 -AllowBreaking                    # you renamed/deleted something on purpose
.\export_objects.ps1 -RegisterMap gcr_office/map.wam   # also add the collection to a map (once per map)
```

- The copy lands where the local maps server serves it: `http://maps.workadventure.localhost/assets/gcr_objects/collection.json`. Reload the game to see changes.
- `-CopyTo <folder>` copies somewhere else instead.
- `-RegisterMap` adds that URL to the map's `entityCollections` in the local map-storage. You only need it once per map.

## Source layout

Every top-level folder is a **category** in the editor, except `tilesets`, `out`, `debug` and names starting with `_`. Every `.aseprite` file in it (at any depth) is an **object**, and every object is **one tile** in the editor. Picking it shows:

- **Variants**: one thumbnail per tag (or untagged frame),
- **Colors**: one dot per palette,
- **Positions**: one thumbnail per direction.

The variant picker is a change in this WorkAdventure fork (`variant` field in the collection, see `EntityVariant.ts`); it isn't in upstream WorkAdventure.

| What | How it is read |
|---|---|
| **Colours** | `.gpl` files next to the `.aseprite`. A `.gpl` belongs to the project whose name it starts with: `<object>_<colour>.gpl`, or `<object>.gpl` for colour `default`. If no project name fits fully, the one sharing the longest prefix up to a `_` wins (`butterfly_frame_1.gpl` → `butterfly_frame_large`, colour `1`). No `.gpl` means the project's own palette (colour `default`). |
| **Frames: tag `Down`/`Up`/`Left`/`Right`** (also `South`/`North`/`West`/`East`, `Front`/`Back`) | That frame is that direction. |
| **Frames: tag with another name** | A variant, shown under the tag's name. End the tag with a direction, like `curtain left`, to give the variant several directions. Every tag name must be unique in the file. |
| **Frames: untagged** | A variant named by its frame number. Tag it later; that changes its id (see below). |
| **Layers** | Layers named `collision` or `ignore` are not exported. Hidden layers aren't either. |
| **Layer `collision`** | Paint where players can't walk, in any colour. A 32 px tile of the exported image blocks players when it holds at least half as much paint as the most painted tile, so paint spilling over a tile border doesn't block an extra tile. (If the paint is split about evenly between two tiles, both still block: move it so most of it is in one.) It works per frame, so each variant/direction can have its own. A frame with paint on this layer ignores the `collision=` setting in `objects.cfg`; frames without paint still use it. |

The collider grid is 32 px tiles of the *exported* image: the drawing is cropped, centred horizontally and stands on the bottom edge. So on an object an even number of tiles wide, the exact centre is a tile border, and a centred trunk blocks the two middle tiles. Paint a little left or right of the centre to block just one.

A colour dot shows the colour that differs between the palettes. Variants are in timeline order.

Each image is cropped to the object's content, using the same box for all its frames. It's then padded to whole 32 px tiles: centred horizontally and standing on the bottom edge.

## objects.cfg

Collision and draw order per object or category. See the comments in the file. For precise colliders (a tree trunk), paint a `collision` layer instead.
- `collision=base` makes the bottom tile row block players. `all` or a number of rows also work.
- `depth=32` makes something placed on a table draw over the table.

## Keep placed objects working

Placed objects refer to their id: `gcr:<category>/<object>:<tag or frame number>:<colour>:<direction>`.

**Safe:** editing pixels, resizing, adding frames at the end, adding tags to new frames, adding palettes, adding projects (also to a folder that already has one), moving a project into a subfolder of the same category, changing `objects.cfg`.

**Breaks placed copies:** renaming or deleting an `.aseprite`, a `.gpl` or a tag; giving a tag to a frame that was exported by its number; inserting or deleting frames *before* untagged ones (their numbers shift); adding the first `.gpl` to a project that had none (its `default` colour goes; name one palette `<object>.gpl` to keep it).

Every export compares the new ids with the last export (in `out\objects` and in the repo). If any id would disappear, it lists them (`GONE …`), stops, and writes and copies nothing. If you meant it, run again with `-AllowBreaking`.

The export also warns when a palette is shorter than the colours the drawing uses. That colour is skipped until it's fixed. If it was exported before, the guard above stops the export.
