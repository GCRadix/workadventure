-- Builds one tileset per floor type: <type>\<type>.aseprite x <type>\NN_<name>.gpl -> <outdir>\<type>.png
--
-- Every FRAME of the project is a pattern (one row of tile designs, or several if the canvas is
-- taller than 32 px). Every palette NN_<name>.gpl is a colour. Each (pattern row, colour) pair gets
-- one 16-column row in the tileset:
--   first export:  pattern 1 in colours 01..NN, then pattern 2 in colours 01..NN, ...
--   later exports: existing rows never move; new pairs are APPENDED at the bottom
--                  (new frame -> a block with that pattern in every colour,
--                   new palette -> one row per pattern in the new colour)
-- The row allocation is stored in <type>\slotmap.tsv. Keep that file: it is what keeps ids stable.
--
-- The export stops if a tile would change its id: a tile design moved to another column or frame
-- (inserted/reordered), or a tile disappeared. force=1 accepts that.
--
-- Run by export.ps1:  aseprite -b --script-param outdir=<dir> [--script-param force=1] --script build_floors.lua

local DIR = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local OUTDIR = assert(app.params["outdir"], "missing --script-param outdir=<folder>")
local FORCE = app.params["force"] == "1"
local T, COLS = 32, 16                       -- changing COLS renumbers every tile in Tiled!
local WIDTH = T * COLS
local SKIP = { out = true }

local function sorted(t) table.sort(t, function(a, b) return a:lower() < b:lower() end) return t end
local problems, warnings = {}, {}
local function problem(msg) table.insert(problems, msg) end

-- FNV-1a over a tile's raw pixel values (palette indices for Indexed projects); nil if empty
local function tileHash(img, x, y, transparent)
  local h, any = 2166136261, false
  for it in img:pixels(Rectangle(x, y, T, T)) do
    local v = it()
    if v ~= transparent then any = true end
    h = ((h ~ v) * 16777619) & 0xffffffff
  end
  return any and string.format("%08x", h) or nil
end

-- previous slotmap.tsv -> { rows = { {row, pkey, nn} }, tiles = { ["f:r:c"] = hash }, bands = { [nn] = label } }
local function readSlotmap(path)
  if not app.fs.isFile(path) then return nil end
  local prev = { rows = {}, tiles = {}, bands = {} }
  for line in io.lines(path) do
    local row, pkey, nn, label = line:match("^#row\t(%d+)\t(%d+:%d+)\t(%d+)\t([^\t]+)")
    if row then
      table.insert(prev.rows, { row = tonumber(row), pkey = pkey, nn = tonumber(nn) })
      prev.bands[tonumber(nn)] = label
    end
    local id, f, r, c, hash = line:match("^(%d+)\t(%d+)\t(%d+)\t%d+\t[^\t]+\t(%d+)\t(%x+)")
    if id then prev.tiles[f .. ":" .. r .. ":" .. c] = hash end
  end
  return prev
end

local built = {}
for _, name in ipairs(sorted(app.fs.listFiles(DIR))) do
  local sub = app.fs.joinPath(DIR, name)
  local src = app.fs.joinPath(sub, name .. ".aseprite")
  if not SKIP[name] and app.fs.isDirectory(sub) and app.fs.isFile(src) then
    local before = #problems

    -- colours: NN_<label>.gpl
    local pals, nums, unnumbered = {}, {}, {}
    for _, f in ipairs(sorted(app.fs.listFiles(sub))) do
      if app.fs.fileExtension(f):lower() == "gpl" then
        local nn, label = f:match("^(%d+)_(.+)%.[gG][pP][lL]$")
        nn = tonumber(nn)
        if not nn or nn < 1 then
          table.insert(unnumbered, f)
        elseif pals[nn] then
          problem(name .. ": " .. pals[nn].file .. " and " .. f .. " both use number " .. nn)
        else
          pals[nn] = { file = f, label = label }
          table.insert(nums, nn)
        end
      end
    end
    table.sort(nums)
    for i, f in ipairs(unnumbered) do
      problem(string.format("%s\\%s: palette file name must start with a number, next free: %02d_%s",
        name, f, (nums[#nums] or 0) + i, f))
    end

    -- patterns: every frame, canvas only
    local spr = app.open(src)
    local w, h, mode, transparent = spr.width, spr.height, spr.colorMode, spr.transparentColor
    local ownPal = Palette(spr.palettes[1])
    local frames = {}
    for f = 1, #spr.frames do
      local img = Image(w, h, mode)
      img:clear(mode == ColorMode.INDEXED and transparent or 0)
      img:drawSprite(spr, f)
      frames[f] = img
    end
    spr:close()
    if mode ~= ColorMode.INDEXED then transparent = 0 end

    if w % T ~= 0 or h % T ~= 0 then problem(name .. ": canvas " .. w .. "x" .. h .. " is not a multiple of 32") end
    if w > WIDTH then problem(name .. ": canvas is " .. w .. " px wide, max " .. WIDTH .. " (" .. COLS .. " tiles)") end
    if #nums == 0 then pals[1] = { label = "_self", own = true }; nums = { 1 } end
    if mode ~= ColorMode.INDEXED and not pals[1].own then
      problem(name .. ": not in Indexed mode, so its .gpl palettes can't be applied")
    end
    local rowsPer, tilesW = h // T, math.min(w, WIDTH) // T

    local patterns, hashes, at = {}, {}, {}
    for f = 1, #frames do
      for r = 0, rowsPer - 1 do
        table.insert(patterns, { f = f, r = r, key = f .. ":" .. r })
        for c = 0, tilesW - 1 do
          local k = f .. ":" .. r .. ":" .. c
          local hh = tileHash(frames[f], c * T, r * T, transparent)
          hashes[k] = hh
          if hh then at[hh] = at[hh] or {}; at[hh][k] = true end
        end
      end
    end

    -- ID-stability check against the previous export
    local slotPath = app.fs.joinPath(sub, "slotmap.tsv")
    local prev = FORCE and nil or readSlotmap(slotPath)
    local prevAny = readSlotmap(slotPath)
    if prevAny then
      local stab, changed = {}, 0
      for key, old in pairs(prevAny.tiles) do
        local now = hashes[key]
        if now ~= old then
          local moved
          for k2 in pairs(at[old] or {}) do
            if prevAny.tiles[k2] ~= old then moved = k2 break end
          end
          if moved then
            table.insert(stab, name .. ": tile frame:row:col " .. key .. " moved to " .. moved ..
              " - tiles or frames were inserted/reordered. Put it back; add new tiles on the right, new frames at the end.")
          elseif now == nil then
            table.insert(stab, name .. ": tile frame:row:col " .. key .. " is now empty, outside the canvas or its frame is gone.")
          else
            changed = changed + 1
          end
        end
      end
      table.sort(stab)
      for _, s in ipairs(stab) do
        if FORCE then table.insert(warnings, "FORCED " .. s) else problem(s) end
      end
      if changed > 0 then table.insert(warnings, name .. ": " .. changed .. " tile design(s) redrawn (ids unchanged)") end
      for nn, label in pairs(prevAny.bands) do
        if not pals[nn] then
          if not FORCE then table.insert(warnings, name .. ": colour " .. nn .. " (" .. label .. ") is gone, its rows are left empty") end
        elseif pals[nn].label ~= label then
          table.insert(warnings, name .. ": colour " .. nn .. " renamed " .. label .. " -> " .. pals[nn].label)
        end
      end
    end

    -- row allocation: keep previous rows, append new (pattern, colour) pairs
    local alloc, used, nextRow, added = {}, {}, 0, 0
    for _, a in ipairs(prev and prev.rows or {}) do
      table.insert(alloc, a)
      used[a.pkey .. "|" .. a.nn] = true
      if a.row >= nextRow then nextRow = a.row + 1 end
    end
    for _, p in ipairs(patterns) do
      for _, nn in ipairs(nums) do
        if not used[p.key .. "|" .. nn] then
          table.insert(alloc, { row = nextRow, pkey = p.key, nn = nn })
          used[p.key .. "|" .. nn] = true
          nextRow = nextRow + 1
          added = added + 1
        end
      end
    end
    if prev and added > 0 then table.insert(warnings, name .. ": " .. added .. " new row(s) appended") end

    if #problems == before then
      local sheet = Image(WIDTH, math.max(nextRow, 1) * T, ColorMode.RGB)
      local palCache = {}
      local rowLines, tileLines = {}, {}
      for _, a in ipairs(alloc) do
        local f, r = a.pkey:match("^(%d+):(%d+)$")
        f, r = tonumber(f), tonumber(r)
        local p = pals[a.nn]
        table.insert(rowLines, string.format("#row\t%d\t%s\t%d\t%s", a.row, a.pkey, a.nn,
          p and p.label or (prevAny and prevAny.bands[a.nn]) or "?"))
        if p and frames[f] and r < rowsPer then
          local pal = palCache[a.nn]
          if not pal then
            pal = p.own and ownPal or Palette{ fromFile = app.fs.joinPath(sub, p.file) }
            palCache[a.nn] = pal
          end
          local oy = a.row * T - r * T
          for it in frames[f]:pixels(Rectangle(0, r * T, tilesW * T, T)) do
            local idx = it()
            if idx ~= transparent then
              if mode == ColorMode.INDEXED then
                if idx >= #pal then
                  problem(name .. "\\" .. (p.file or "own palette") .. " has " .. #pal .. " colours, project uses index " .. idx)
                  break
                end
                sheet:drawPixel(it.x, oy + it.y, pal:getColor(idx))
              else
                sheet:drawPixel(it.x, oy + it.y, idx)
              end
            end
          end
          for c = 0, tilesW - 1 do
            local hh = hashes[f .. ":" .. r .. ":" .. c]
            if hh then
              table.insert(tileLines, string.format("%d\t%d\t%d\t%d\t%s\t%d\t%s",
                a.row * COLS + c, f, r, a.nn, p.label, c, hh))
            end
          end
        end
      end
      if #problems == before then
        sheet:saveAs(app.fs.joinPath(OUTDIR, name .. ".png"))
        local out = {
          "# generated by build_floors.lua - KEEP THIS FILE: it fixes which row every pattern/colour has.",
          "# columns " .. COLS,
          "# tileset rows: #row <row> <frame>:<row_in_frame> <colour_no> <colour>",
        }
        for _, l in ipairs(rowLines) do table.insert(out, l) end
        table.insert(out, "id\tframe\trow_in_frame\tcolour_no\tcolour\tcol\ttile_hash")
        for _, l in ipairs(tileLines) do table.insert(out, l) end
        local fh = assert(io.open(slotPath, "w")); fh:write(table.concat(out, "\n") .. "\n"); fh:close()
        table.insert(built, string.format("%s %dx%d (%d frames x %d colours)", name, WIDTH, sheet.height, #frames, #nums))
      end
    end
  end
end

for _, w in ipairs(warnings) do print("WARNING " .. w) end
for _, p in ipairs(problems) do print("ERROR " .. p) end
for _, b in ipairs(built) do print("tileset " .. b) end
if #problems == 0 then print("floors ok: " .. #built .. " tilesets") end
