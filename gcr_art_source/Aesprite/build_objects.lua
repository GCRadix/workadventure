-- Builds a WorkAdventure entity collection (map editor objects) from the object projects in this folder.
--
-- Sources: <category>\...\<object>.aseprite   (every top-level folder except tilesets, out, debug, _*)
--   Colours:  *.gpl next to the .aseprite. <object>_<colour>.gpl (or <object>.gpl = "default") belongs to that
--             project; otherwise to the project sharing the longest name prefix up to a _ or -. No .gpl -> the
--             project's own palette ("default").
--   Every project is ONE tile in the editor, with a variant picker (tags / frames), colour swatches (palettes)
--   and positions (direction tags).
--   Frames:   Tag named Down/Up/Left/Right (or South/North/West/East, Front/Back) -> that direction.
--             Tag with another name -> a variant (end the tag name with a direction, e.g. "curtain left", to
--             give it one).
--             Untagged frame -> a variant named by its frame number (also for a 1-frame project, so adding
--             frames later never changes existing ids).
--   Layers named "collision" or "ignore" are not exported. Tiles mostly painted on a "collision" layer block
--   players (per frame; it overrides objects.cfg collision for that frame).
-- Settings per object (collision, depth): objects.cfg
--
-- Every image is cropped to the object's content (the same box for all its frames), then padded to whole
-- 32 px tiles: centred horizontally, standing on the bottom edge. The collision grid uses those tiles.
--
-- Run by export_objects.ps1:
--   aseprite -b --script-param out=<dir> --script-param name=<collection name> --script-param prefix=<id prefix> --script build_objects.lua

local DIR = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local OUT = assert(app.params["out"], "missing --script-param out=<folder>")
local COLLECTION = app.params["name"] or "GCR Objects"
local PREFIX = app.params["prefix"] or "gcr"
local T = 32
local SKIP = { tilesets = true, out = true, debug = true }
local DIRS = { down = "Down", south = "Down", front = "Down", up = "Up", north = "Up", back = "Up",
               left = "Left", west = "Left", right = "Right", east = "Right" }
local DIR_ORDER = { Down = 1, Right = 2, Up = 3, Left = 4 }

local warnings, problems = {}, {}
local function warn(m) table.insert(warnings, m) end
local function problem(m) table.insert(problems, m) end
local function sorted(t) table.sort(t, function(a, b) return a:lower() < b:lower() end) return t end
local function slug(s) return (s:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")) end
local function title(s) s = s:gsub("[_%-]+", " "); return s:sub(1, 1):upper() .. s:sub(2) end
local function jstr(s) return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end

-- objects.cfg:  <category>/<object>  or  <category>/*   followed by  collision=none|base|all|<rows>  depth=<px>
local cfg = {}
local cfgPath = app.fs.joinPath(DIR, "objects.cfg")
if app.fs.isFile(cfgPath) then
  local n = 0
  for line in io.lines(cfgPath) do
    n = n + 1
    line = line:gsub("#.*", "")
    local key, rest = line:match("^%s*(%S+)%s+(.-)%s*$")
    if key then
      cfg[key] = cfg[key] or {}
      for k, v in rest:gmatch("(%w+)=(%S+)") do cfg[key][k] = v end
    elseif line:match("%S") then
      problem("objects.cfg line " .. n .. ": expected '<category>/<object> key=value ...'")
    end
  end
end
local function setting(cat, obj, key, default)
  local o, c = cfg[cat .. "/" .. obj], cfg[cat .. "/*"]
  if o and o[key] then return o[key] end
  if c and c[key] then return c[key] end
  return default
end

-- find every object project
local objects = {}
local function scan(cat, dir)
  local files = app.fs.listFiles(dir)
  local sprites, gpls = {}, {}
  for _, f in ipairs(sorted(files)) do
    local p = app.fs.joinPath(dir, f)
    if app.fs.isDirectory(p) then
      if not f:match("^[_%.]") and f ~= "out" then scan(cat, p) end
    else
      local ext = app.fs.fileExtension(f):lower()
      if ext == "aseprite" or ext == "ase" then table.insert(sprites, f) end
      if ext == "gpl" then table.insert(gpls, app.fs.fileTitle(f)) end
    end
  end
  -- each .gpl belongs to the object in its folder whose name shares the longest prefix with it, cut at a word
  -- boundary (butterfly_frame_1 -> butterfly_frame_large, colour "1"; table_glass_dark -> table_glass, "dark").
  -- This does not depend on how many projects the folder holds, so adding a project never re-labels colours.
  local pals = {}
  local function sep(c) return c == "_" or c == "-" or c == " " end
  for _, g in ipairs(gpls) do
    local gl = g:lower()
    local best, bestP, tie = nil, 0, false
    for _, f in ipairs(sprites) do
      local ol = app.fs.fileTitle(f):lower()
      local p = 0
      while p < #gl and p < #ol and gl:sub(p + 1, p + 1) == ol:sub(p + 1, p + 1) do p = p + 1 end
      -- full: the .gpl name is <object> or <object>_<colour>; it always beats a partial prefix match
      local full = p == #ol and (p == #gl or sep(gl:sub(p + 1, p + 1)))
      local ok = full or (p > 0 and (p == #gl or sep(gl:sub(p, p))))
      local score = full and 10000 + p or p
      if ok then
        if score > bestP then best, bestP, tie = f, score, false elseif score == bestP then tie = true end
      end
    end
    if not best then
      warn(cat .. ": " .. g .. ".gpl matches no project in its folder, ignored")
    elseif tie then
      problem(cat .. ": " .. g .. ".gpl matches several projects equally well - rename it to <object>_<colour>.gpl")
    else
      local label = g:sub(bestP % 10000 + 1):gsub("^[_%-%s]+", "")
      pals[best] = pals[best] or {}
      table.insert(pals[best], { file = app.fs.joinPath(dir, g .. ".gpl"), label = label == "" and "default" or slug(label) })
    end
  end
  for _, f in ipairs(sprites) do
    table.insert(objects, { cat = cat, obj = app.fs.fileTitle(f), path = app.fs.joinPath(dir, f), pals = pals[f] or {} })
  end
end
for _, cat in ipairs(sorted(app.fs.listFiles(DIR))) do
  local p = app.fs.joinPath(DIR, cat)
  if app.fs.isDirectory(p) and not SKIP[cat:lower()] and not cat:match("^[_%.]") then scan(cat, p) end
end

local entries, files = {}, 0
for _, o in ipairs(objects) do
  local spr = app.open(o.path)
  local mode, transparent = spr.colorMode, spr.transparentColor
  local collisionLayers = {}
  local function hide(layers)
    for _, l in ipairs(layers) do
      local n = l.name:lower()
      if n == "collision" then table.insert(collisionLayers, l) end
      if n == "collision" or n == "ignore" then l.isVisible = false end
      if l.isGroup then hide(l.layers) end
    end
  end
  hide(spr.layers)
  if mode == ColorMode.GRAY then problem(o.cat .. "/" .. o.obj .. ": grayscale mode is not supported, use Indexed or RGB") end
  if mode ~= ColorMode.INDEXED and #o.pals > 0 then
    warn(o.cat .. "/" .. o.obj .. ": not Indexed, so its .gpl palettes are ignored")
    o.pals = {}
  end
  local pals = #o.pals > 0 and o.pals or { { label = "default", own = true } }

  -- frames -> (variant, direction)
  local frameInfo = {}
  for _, tag in ipairs(spr.tags) do
    local shown = tag.name:gsub("^%s+", ""):gsub("%s+$", "")   -- as written, for the editor's variant picker
    local name = shown:lower()
    local variant, dir
    if DIRS[name] then
      variant, dir, shown = "", DIRS[name], ""
    else
      local base, d = name:match("^(.-)[%s_%-]+(%a+)$")
      if base and DIRS[d] then
        variant, dir, shown = base, DIRS[d], shown:sub(1, #base)
      else
        variant, dir = name, "Down"
      end
    end
    for f = tag.fromFrame.frameNumber, tag.toFrame.frameNumber do
      if frameInfo[f] then
        warn(o.cat .. "/" .. o.obj .. ": frame " .. f .. " is in more than one tag, using '" .. frameInfo[f].tag .. "'")
      elseif f == tag.fromFrame.frameNumber then
        frameInfo[f] = { variant = variant, shown = shown, dir = dir, tag = tag.name }
      end
    end
  end
  local multi = #spr.frames > 1
  for f = 1, #spr.frames do
    if not frameInfo[f] then
      local covered = false
      for _, tag in ipairs(spr.tags) do
        if f >= tag.fromFrame.frameNumber and f <= tag.toFrame.frameNumber then covered = true end
      end
      -- untagged: a variant named by its frame number (also for a 1-frame project, so adding frames later
      -- keeps frame 1's id)
      if not covered then frameInfo[f] = { variant = tostring(f), shown = tostring(f), dir = "Down" } end
    end
  end

  -- render frames (indexed or rgb), find the common content box
  local frames, box, lastFrame = {}, nil, #spr.frames
  for f = 1, #spr.frames do
    if frameInfo[f] then
      local img = Image(spr.width, spr.height, mode)
      img:clear(mode == ColorMode.INDEXED and transparent or 0)
      img:drawSprite(spr, f)
      frames[f] = img
      local b = img:shrinkBounds(mode == ColorMode.INDEXED and transparent or 0)
      if b.width > 0 and b.height > 0 then box = box and box:union(b) or b end
    end
  end

  -- painted colliders: every pixel of a "collision" layer, per frame (sprite coordinates)
  local collisionPixels = {}
  for f = 1, #spr.frames do
    if frameInfo[f] then
      for _, l in ipairs(collisionLayers) do
        local cel = l:cel(f)
        if cel then
          for it in cel.image:pixels() do
            local v = it()
            local solid = (mode == ColorMode.INDEXED) and (v ~= transparent) or (mode ~= ColorMode.INDEXED and app.pixelColor.rgbaA(v) > 0)
            if solid then
              collisionPixels[f] = collisionPixels[f] or {}
              table.insert(collisionPixels[f], { cel.position.x + it.x, cel.position.y + it.y })
            end
          end
        end
      end
    end
  end
  local ownPal = Palette(spr.palettes[1])
  spr:close()

  if not box then
    warn(o.cat .. "/" .. o.obj .. ": empty, skipped")
  else
    local tw, th = math.ceil(box.width / T), math.ceil(box.height / T)
    local W, H = tw * T, th * T
    local ox, oy = (W - box.width) // 2, H - box.height
    local collision = setting(o.cat, o.obj, "collision", "none")
    local cfgDepth = tonumber(setting(o.cat, o.obj, "depth", ""))
    local rows = collision == "all" and th or collision == "base" and 1 or tonumber(collision) or 0
    if collision ~= "none" and rows == 0 then problem(o.cat .. "/" .. o.obj .. ": collision=" .. collision .. " is not none|base|all|<rows>") end
    rows = math.min(rows, th)
    local depth = cfgDepth or -rows * T   -- sort by the top of the collision area, like the built-in furniture
    local name = title(o.obj)
    local used = {}

    -- swatch colour for the editor's colour picker: the most used palette entry that differs between this
    -- object's palettes (so outlines shared by every colour don't win); with one palette, the most used entry
    local swatchIndex
    if mode == ColorMode.INDEXED then
      local counts = {}
      for _, img in pairs(frames) do
        for it in img:pixels(box) do
          local v = it()
          if v ~= transparent then counts[v] = (counts[v] or 0) + 1 end
        end
      end
      local loaded = {}
      for _, p in ipairs(pals) do table.insert(loaded, p.own and ownPal or Palette{ fromFile = p.file }) end
      -- score = pixels using the entry x how far that entry moves between palettes (+ its saturation)
      local bestN, bestAny, bestAnyN = 0, nil, -1
      for idx, n in pairs(counts) do
        if n > bestAnyN then bestAny, bestAnyN = idx, n end
        local spread, sat = 0, 0
        for i = 1, #loaded do
          if idx < #loaded[i] then
            local c = loaded[i]:getColor(idx)
            sat = math.max(sat, math.max(c.red, c.green, c.blue) - math.min(c.red, c.green, c.blue))
            for j = i + 1, #loaded do
              if idx < #loaded[j] then
                local d = loaded[j]:getColor(idx)
                spread = math.max(spread, math.abs(c.red - d.red) + math.abs(c.green - d.green) + math.abs(c.blue - d.blue))
              end
            end
          end
        end
        local score = n * spread * (1 + sat / 255)
        if spread > 0 and score > bestN then swatchIndex, bestN = idx, score end
      end
      swatchIndex = swatchIndex or bestAny
    end

    for _, p in ipairs(pals) do
      local pal = p.own and ownPal or Palette{ fromFile = p.file }
      -- a palette shorter than the colours the drawing uses can't colour it: skip that colour
      local maxUsed = -1
      if mode == ColorMode.INDEXED then
        for _, img in pairs(frames) do
          for it in img:pixels(box) do
            local v = it()
            if v ~= transparent and v > maxUsed then maxUsed = v end
          end
        end
      end
      if maxUsed >= #pal then
        warn(o.cat .. "/" .. o.obj .. ": " .. app.fs.fileName(p.file or "palette") .. " has " .. #pal ..
          " colours but the drawing uses colour " .. maxUsed .. " - colour '" .. p.label .. "' skipped")
        goto nextPalette
      end
      do
      local cssColours = {}
      for f = 1, lastFrame do
        local img, info = frames[f], frameInfo[f]
        if img then
        local out = Image(W, H, ColorMode.RGB)
        local counts, bad = {}, false
        for it in img:pixels(box) do
          local v = it()
          local px
          if mode == ColorMode.INDEXED then
            if v ~= transparent then
              if v >= #pal then bad = true else px = pal:getColor(v).rgbaPixel end
            end
          else
            px = v
          end
          if px and app.pixelColor.rgbaA(px) > 0 then
            out:drawPixel(it.x - box.x + ox, it.y - box.y + oy, px)
            local key = px & 0xffffff
            counts[key] = (counts[key] or 0) + 1
          end
        end
        if bad then problem(o.cat .. "/" .. o.obj .. ": " .. (p.file and app.fs.fileName(p.file) or "palette") .. " has fewer colours than the project uses") end

        -- swatch colour: one per palette, the same for every variant of the object (the editor shows variants in
        -- their own picker). It's the colour that differs between the palettes; unique within the object.
        local swatchKey = p.label
        if not cssColours[swatchKey] then
          local best, bestN = 0, -1
          if swatchIndex then
            best = pal:getColor(swatchIndex).rgbaPixel & 0xffffff
          else
            for k, n in pairs(counts) do if n > bestN then best, bestN = k, n end end
          end
          local r, g, b = best & 0xff, (best >> 8) & 0xff, (best >> 16) & 0xff
          local css = string.format("#%02x%02x%02x", r, g, b)
          while used[css] do b = (b + 7) % 256; css = string.format("#%02x%02x%02x", r, g, b) end
          used[css] = true
          cssColours[swatchKey] = css
        end

        -- collision grid. A painted "collision" layer wins: exactly the tiles it touches block players.
        -- Otherwise objects.cfg: the bottom <rows> tile rows, only cells that contain pixels.
        local grid, frameDepth = nil, depth
        if collisionPixels[f] then
          -- count the paint per tile; a tile blocks when it holds at least half as much paint as the most painted
          -- tile, so paint spilling over a tile border doesn't block a whole extra tile
          local counts, most = {}, 0
          for _, px in ipairs(collisionPixels[f]) do
            local x, y = px[1] - box.x + ox, px[2] - box.y + oy
            if x >= 0 and y >= 0 and x < W and y < H then
              local k = (y // T) * tw + (x // T)
              counts[k] = (counts[k] or 0) + 1
              most = math.max(most, counts[k])
            end
          end
          local hits, top = {}, nil
          for k, n in pairs(counts) do
            if n * 2 >= most then
              hits[k] = true
              top = top and math.min(top, k // tw) or k // tw
            end
          end
          if top then
            grid = {}
            for ty = 0, th - 1 do
              local row = {}
              for tx = 0, tw - 1 do row[#row + 1] = hits[ty * tw + tx] and 1 or 0 end
              grid[#grid + 1] = row
            end
            frameDepth = cfgDepth or -(th - top) * T
          else
            warn(o.cat .. "/" .. o.obj .. ": frame " .. f .. " collision layer is outside the drawing, ignored")
          end
        elseif rows > 0 then
          grid = {}
          for ty = 0, th - 1 do
            local row = {}
            for tx = 0, tw - 1 do
              local hit = 0
              if ty >= th - rows then
                for it in out:pixels(Rectangle(tx * T, ty * T, T, T)) do
                  if app.pixelColor.rgbaA(it()) > 0 then hit = 1 break end
                end
              end
              row[#row + 1] = hit
            end
            grid[#grid + 1] = row
          end
        end

        local variant = info.variant
        -- one name per object: the editor groups everything with the same name into one tile
        local entName = name
        local fileBase = slug(o.obj .. (variant ~= "" and ("_" .. variant) or "") .. "_" .. p.label .. "_" .. info.dir)
        local rel = "entities/" .. slug(o.cat) .. "/" .. slug(o.obj) .. "/" .. fileBase .. ".png"
        local id = PREFIX .. ":" .. slug(o.cat) .. "/" .. slug(o.obj) .. ":" .. (variant ~= "" and slug(variant) or "-") .. ":" .. p.label .. ":" .. info.dir:lower()
        local target = app.fs.joinPath(OUT, (rel:gsub("/", "\\")))
        app.fs.makeAllDirectories(app.fs.filePath(target))
        out:saveAs(target)
        files = files + 1
        table.insert(entries, {
          id = id, name = entName, cat = o.cat, colour = p.label, css = cssColours[swatchKey], dir = info.dir, variant = info.shown,
          rel = rel, grid = grid, depth = frameDepth, sort = slug(o.cat) .. "/" .. slug(o.obj) .. "/" .. string.format("%05d", f) .. "/" .. p.label .. "/" .. DIR_ORDER[info.dir],
        })
        end
      end
      end
      ::nextPalette::
    end
  end
end

-- duplicate ids (two frames claiming the same variant + direction)
local seen = {}
for _, e in ipairs(entries) do
  if seen[e.id] then problem("two images for " .. e.id .. " - give the frames different tags") end
  seen[e.id] = true
end

table.sort(entries, function(a, b) return a.sort < b.sort end)
local lines = {}
for _, e in ipairs(entries) do
  local parts = {
    '"id": ' .. jstr(e.id),
    '"name": ' .. jstr(e.name),
    -- the editor lists every tag as a category, so only the category goes here (colours are swatches already)
    '"tags": [' .. jstr(slug(e.cat)) .. "]",
    '"imagePath": ' .. jstr(e.rel),
    '"direction": ' .. jstr(e.dir),
    '"color": ' .. jstr(e.css),
  }
  -- variant (tag or frame number): the editor's variant picker; colours and directions are chosen per variant
  if e.variant and e.variant ~= "" then table.insert(parts, '"variant": ' .. jstr(e.variant)) end
  if e.grid then
    local rs = {}
    for _, r in ipairs(e.grid) do rs[#rs + 1] = "[" .. table.concat(r, ", ") .. "]" end
    table.insert(parts, '"collisionGrid": [' .. table.concat(rs, ", ") .. "]")
  end
  if e.depth ~= 0 then table.insert(parts, '"depthOffset": ' .. e.depth) end
  lines[#lines + 1] = "  {" .. table.concat(parts, ", ") .. "}"
end
local json = "{\n \"version\": \"1.0\",\n \"collectionName\": " .. jstr(COLLECTION) .. ",\n \"tags\": [" ..
  -- no collection-wide tag: the editor adds it to every object, which would make one big extra category
  "],\n \"collection\": [\n" .. table.concat(lines, ",\n") .. "\n ]\n}\n"

for _, w in ipairs(warnings) do print("WARNING " .. w) end
for _, p in ipairs(problems) do print("ERROR " .. p) end
if #problems == 0 then
  local f = assert(io.open(app.fs.joinPath(OUT, "collection.json"), "w")); f:write(json); f:close()
  print("objects ok: " .. #objects .. " objects, " .. files .. " images")
end
