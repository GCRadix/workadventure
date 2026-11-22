-- Builds walls.png from walls_master.aseprite + one palette per colour
-- (palettes/NN_<name>.gpl: NN = colour band, 01 = top; a missing number leaves an empty band).
-- Layout: 256 px wide (8 columns), 2 rows (one 32x64 piece) per colour band.
-- Run by export.ps1:  aseprite -b --script-param out=<path\walls.png> --script build_walls.lua

local DIR = app.fs.filePath(debug.getinfo(1, "S").source:sub(2))
local OUT = assert(app.params["out"], "missing --script-param out=<walls.png>")
local T, WIDTH, BAND_ROWS = 32, 256, 2

-- colour bands from the palette file names
local colours, nBands, bad = {}, 0, {}
for _, f in ipairs(app.fs.listFiles(app.fs.joinPath(DIR, "palettes"))) do
  if app.fs.fileExtension(f):lower() == "gpl" then
    local nn = tonumber(f:match("^(%d+)_.+%.[gG][pP][lL]$") or "")
    if not nn or nn < 1 then table.insert(bad, f .. " (name must start with its band number, e.g. 06_" .. f .. ")")
    elseif colours[nn] then table.insert(bad, f .. " and " .. colours[nn] .. " both claim band " .. nn)
    else colours[nn] = f; nBands = math.max(nBands, nn) end
  end
end
assert(#bad == 0, "palettes: " .. table.concat(bad, "; "))
assert(nBands > 0, "no palettes/NN_<name>.gpl found")

-- master (indexed): palette index per pixel
local master = app.open(app.fs.joinPath(DIR, "walls_master.aseprite"))
assert(master.colorMode == ColorMode.INDEXED, "walls_master.aseprite must be in Indexed mode")
assert(master.width == WIDTH and master.height == BAND_ROWS * T, "walls_master.aseprite must be 256x64")
local nColours = #master.palettes[1]
local transparent = master.transparentColor
local mImg = Image(master.width, master.height, ColorMode.INDEXED)
mImg:clear(transparent)
mImg:drawSprite(master, 1)
master:close()

local img = Image(WIDTH, BAND_ROWS * T * nBands, ColorMode.RGB)
for band = 1, nBands do
  local file = colours[band]
  if file then
    local pal = Palette{ fromFile = app.fs.joinPath(DIR, "palettes", file) }
    assert(#pal >= nColours, file .. " has " .. #pal .. " colours, master uses " .. nColours)
    local oy = (band - 1) * BAND_ROWS * T
    for it in mImg:pixels() do
      local idx = it()
      if idx ~= transparent then img:drawPixel(it.x, oy + it.y, pal:getColor(idx)) end
    end
  else
    print("WARNING band " .. band .. " has no palette, left empty")
  end
end
img:saveAs(OUT)

-- tiles that contain any pixel (they get collides=true in walls.tsx)
local used = {}
for ty = 0, img.height // T - 1 do
  for tx = 0, WIDTH // T - 1 do
    for it in img:pixels(Rectangle(tx * T, ty * T, T, T)) do
      if app.pixelColor.rgbaA(it()) > 0 then table.insert(used, ty * (WIDTH // T) + tx) break end
    end
  end
end
print("walls ok: " .. nBands .. " colour bands, " .. WIDTH .. "x" .. img.height)
print("used tiles: " .. table.concat(used, ","))
