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

Every top-level folder is a **category**, except `tilesets`, `out`, `debug` and names starting with `_`. Every `.aseprite` file in it (at any depth) is an **object**.

| What | How it is read |
|---|---|
| **Colours** | `.gpl` files next to the `.aseprite`. A `.gpl` belongs to the project whose name it starts with: `<object>_<colour>.gpl`, or `<object>.gpl` for colour `default`. If no project name fits fully, the one sharing the longest prefix up to a `_` wins (`butterfly_frame_1.gpl` → `butterfly_frame_large`, colour `1`). No `.gpl` means the project's own palette (colour `default`). Colours appear as swatches in the editor. |
| **Frames: untagged** | Each frame is its own object, named by frame number: `<Name> 1`, `<Name> 2`, … (just `<Name>` if there is only one frame). Faces Down. |
| **Frames: tag `Down`/`Up`/`Left`/`Right`** (also `South`/`North`/`West`/`East`, `Front`/`Back`) | That frame is that direction of the same object. The editor's rotate button switches between them. |
| **Frames: tag with another name** | A separate object called `<Name> <tag>`. End the tag with a direction, like `curtain left`, to give it one. |
| **Layers** | Layers named `collision` or `ignore` are not exported. Hidden layers aren't either. |

Each image is cropped to the object's content, using the same box for all its frames. It's then padded to whole 32 px tiles: centred horizontally and standing on the bottom edge.

## objects.cfg

Collision and draw order per object or category. See the comments in the file.
- `collision=base` makes the bottom tile row block players. `all` or a number of rows also work.
- `depth=32` makes something placed on a table draw over the table.

## Keep placed objects working

Placed objects refer to their id: `gcr:<category>/<object>:<tag or frame number>:<colour>:<direction>`.

**Safe:** editing pixels, resizing, adding frames at the end, adding tags to new frames, adding palettes, adding projects (also to a folder that already has one), moving a project into a subfolder of the same category, changing `objects.cfg`.

**Breaks placed copies:** renaming or deleting an `.aseprite`, a `.gpl` or a tag; giving a tag to a frame that was exported by its number; inserting or deleting frames *before* untagged ones (their numbers shift); adding the first `.gpl` to a project that had none (its `default` colour goes; name one palette `<object>.gpl` to keep it).

Every export compares the new ids with the last export (in `out\objects` and in the repo). If any id would disappear, it lists them (`GONE …`), stops, and writes and copies nothing. If you meant it, run again with `-AllowBreaking`.

The export also warns when a palette is shorter than the colours the drawing uses. That colour is skipped until it's fixed. If it was exported before, the guard above stops the export.
