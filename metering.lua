-- metering.lua
-- ─────────────────────────────────────────────────────
-- modular audio metering for norns
-- page 1: 4 configurable slots (2x2 grid)
-- page 2: dynamics (LUFS history + L/R bars + balance)
--
-- E1: input offset (dB calibration, always visible)
-- E2: target LUFS
-- E3: spectrum ceiling
-- K1: page toggle
-- K2: freeze
-- K3: reset integrated LUFS + peak holds
--
-- v2.0.0 @semi
-- ─────────────────────────────────────────────────────

engine.name = "Metering"

-- ── slot widget types ───────────────────────────────────
local WIDGETS = {
  "ST LUFS",     -- 1
  "INT LUFS",    -- 2
  "MOM LUFS",    -- 3
  "PHASE",       -- 4
  "GONIOMETER",  -- 5
  "SPECTRUM",    -- 6
  "PEAK/RMS",    -- 7
  "BALANCE",     -- 8
  "CREST",       -- 9
  "EMPTY",       -- 10
}

-- ── state ────────────────────────────────────────────────
local page          = 1
local is_frozen     = false
local input_offset  = 10
local target_lufs   = -14
local spec_ceiling  = 0
local peak_decay    = 0.4
local peak_hold_sec = 2

-- slot assignments (which widget in which slot, 1-4)
-- default: ST top-left, INT top-right, PHASE bottom-left, SPECTRUM bottom-right
local slots = {1, 2, 4, 6}

local data = {
  mom = -70, st = -70, int = -70,
  peak_l = -70, peak_r = -70,
  rms_l = -70, rms_r = -70,
  corr = 0, balance = 0,
  spec = {}, peaks = {},
}
for i = 1, 32 do data.spec[i] = -70; data.peaks[i] = -70 end

local peak_hold_l, peak_hold_r = -70, -70
local peak_timer = 0

-- goniometer buffer (XY points for Lissajous)
local GONIO_SIZE = 80
local gonio = { l = {}, r = {}, idx = 1 }
for i = 1, GONIO_SIZE do gonio.l[i] = 0; gonio.r[i] = 0 end

-- LUFS history (page 2)
local HIST_LEN = 128
local lufs_hist = {}
for i = 1, HIST_LEN do lufs_hist[i] = -70 end
local hist_idx = 1

-- ── init ─────────────────────────────────────────────────
function init()
  params:add_separator("m_head", "m e t e r i n g")

  params:add_control("input_offset", "input offset",
    controlspec.new(-24, 24, 'lin', 0.1, 10, 'dB'))
  params:set_action("input_offset", function(v) input_offset = v end)

  params:add_number("target_lufs", "target LUFS", -40, 0, -14)
  params:set_action("target_lufs", function(v) target_lufs = v end)

  params:add_number("spec_ceiling", "spectrum ceiling", -60, 0, 0)
  params:set_action("spec_ceiling", function(v) spec_ceiling = v end)

  params:add_control("peak_decay", "peak decay",
    controlspec.new(0.1, 2, 'lin', 0.05, 0.4, ''))
  params:set_action("peak_decay", function(v) peak_decay = v end)

  params:add_option("peak_hold", "peak hold",
    {"1s", "2s", "3s", "5s", "inf"}, 2)
  params:set_action("peak_hold", function(v)
    peak_hold_sec = ({1, 2, 3, 5, 9999})[v]
  end)

  -- slot configuration
  params:add_separator("m_slots", "page 1 layout")
  for s = 1, 4 do
    local pos = ({"top-left", "top-right", "bottom-left", "bottom-right"})[s]
    params:add_option("slot_" .. s, "slot " .. s .. " (" .. pos .. ")",
      WIDGETS, slots[s])
    params:set_action("slot_" .. s, function(v) slots[s] = v end)
  end

  params:bang()

  -- 15fps
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if not is_frozen then
        for i = 1, 32 do data.peaks[i] = data.peaks[i] - peak_decay end
        peak_timer = peak_timer + (1/15)
        if peak_timer > peak_hold_sec then
          peak_hold_l = peak_hold_l - 0.5
          peak_hold_r = peak_hold_r - 0.5
        end
      end
      redraw()
    end
  end)
end

-- ── OSC ─────────────────────────────────────────────────
osc.event = function(path, args, from)
  if path ~= "/meter" or is_frozen then return end
  local c = input_offset

  data.mom    = (args[1] or -70) + c
  data.st     = (args[2] or -70) + c
  data.int    = (args[3] or -70) + c
  data.peak_l = (args[4] or -70) + c
  data.peak_r = (args[5] or -70) + c
  data.rms_l  = (args[6] or -70) + c
  data.rms_r  = (args[7] or -70) + c
  data.corr   = args[8] or 0
  data.balance = args[9] or 0

  if data.peak_l > peak_hold_l then peak_hold_l = data.peak_l; peak_timer = 0 end
  if data.peak_r > peak_hold_r then peak_hold_r = data.peak_r; peak_timer = 0 end

  for i = 1, 32 do
    local v = (args[9 + i] or -70) + c
    data.spec[i] = v
    if v > data.peaks[i] then data.peaks[i] = v end
  end

  -- goniometer: push raw L/R (before offset, we want the waveform shape)
  gonio.l[gonio.idx] = args[4] or -70  -- use peak as proxy for amplitude
  gonio.r[gonio.idx] = args[5] or -70
  gonio.idx = (gonio.idx % GONIO_SIZE) + 1

  lufs_hist[hist_idx] = data.st
  hist_idx = (hist_idx % HIST_LEN) + 1
end

-- ── controls ─────────────────────────────────────────────
function key(n, z)
  if z == 0 then return end
  if n == 1 then page = page == 1 and 2 or 1
  elseif n == 2 then is_frozen = not is_frozen
  elseif n == 3 then
    engine.reset_int(); data.int = -70
    peak_hold_l = -70; peak_hold_r = -70
  end
end

function enc(n, d)
  if n == 1 then params:delta("input_offset", d)
  elseif n == 2 then params:delta("target_lufs", d)
  elseif n == 3 then params:delta("spec_ceiling", d)
  end
end

-- ── helpers ─────────────────────────────────────────────
local function fdb(v)
  return v <= -60 and "-inf" or string.format("%.1f", v)
end
local function fdb0(v)
  return v <= -60 and "--" or string.format("%.0f", v)
end

-- ── draw ─────────────────────────────────────────────────
function redraw()
  screen.clear()
  screen.aa(1)

  if page == 1 then draw_slots() else draw_dynamics() end

  -- status bar (top center)
  screen.level(page == 1 and 12 or 3)
  screen.rect(56, 1, 3, 3)
  if page == 1 then screen.fill() else screen.stroke() end
  screen.level(page == 2 and 12 or 3)
  screen.rect(61, 1, 3, 3)
  if page == 2 then screen.fill() else screen.stroke() end

  -- offset (top right, always)
  screen.level(6); screen.font_size(8)
  screen.move(100, 6)
  screen.text((input_offset >= 0 and "+" or "") .. string.format("%.0f", input_offset) .. "dB")

  if is_frozen then
    screen.level(15); screen.move(126, 6); screen.text_right("*")
  end

  screen.update()
end

-- ════════════════════════════════════════════════════════
-- PAGE 1: CONFIGURABLE 4-SLOT GRID
-- ════════════════════════════════════════════════════════
-- slot positions: 2x2 grid
-- slot 1: x=0,  y=8,  w=63, h=28  (top-left)
-- slot 2: x=65, y=8,  w=63, h=28  (top-right)
-- slot 3: x=0,  y=37, w=63, h=27  (bottom-left)
-- slot 4: x=65, y=37, w=63, h=27  (bottom-right)

local SLOT_RECTS = {
  {x=0,  y=8,  w=63, h=28},
  {x=65, y=8,  w=63, h=28},
  {x=0,  y=37, w=63, h=27},
  {x=65, y=37, w=63, h=27},
}

function draw_slots()
  -- dividers
  screen.level(1)
  screen.move(64, 7); screen.line(64, 64); screen.stroke()
  screen.move(0, 36); screen.line(128, 36); screen.stroke()

  for s = 1, 4 do
    local r = SLOT_RECTS[s]
    local w = slots[s]
    draw_widget(w, r.x, r.y, r.w, r.h)
  end
end

function draw_widget(wtype, x, y, w, h)
  if wtype == 1 then      widget_lufs(x, y, w, h, "ST", data.st)
  elseif wtype == 2 then  widget_lufs(x, y, w, h, "INT", data.int)
  elseif wtype == 3 then  widget_lufs(x, y, w, h, "MOM", data.mom)
  elseif wtype == 4 then  widget_phase(x, y, w, h)
  elseif wtype == 5 then  widget_gonio(x, y, w, h)
  elseif wtype == 6 then  widget_spectrum(x, y, w, h)
  elseif wtype == 7 then  widget_peak_rms(x, y, w, h)
  elseif wtype == 8 then  widget_balance(x, y, w, h)
  elseif wtype == 9 then  widget_crest(x, y, w, h)
  -- 10 = empty, draw nothing
  end
end

-- ── LUFS widget ─────────────────────────────────────────
function widget_lufs(x, y, w, h, label, val)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text(label .. " LUFS")

  if label == "ST" then
    screen.level(2)
    screen.move(x + w - 2, y + 7); screen.text_right("T:" .. target_lufs)
  end

  screen.font_size(h > 26 and 16 or 12)
  screen.level(val >= target_lufs and 15 or 6)
  screen.move(x + 2, y + (h > 26 and 22 or 18))
  screen.text(fdb(val))

  -- target relation bar
  if label ~= "MOM" then
    local diff = val - target_lufs
    local bw = util.clamp(math.floor(diff * 2 + (w * 0.5)), 0, w - 4)
    screen.level(diff >= 0 and 5 or 2)
    screen.rect(x + 2, y + h - 3, bw, 2); screen.fill()
  end

  screen.font_size(8)
end

-- ── PHASE widget ────────────────────────────────────────
function widget_phase(x, y, w, h)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text("PHASE")

  screen.level(15)
  screen.move(x + w - 2, y + 7)
  screen.text_right(string.format("%.2f", data.corr))

  -- bar
  local by = y + 14
  local bx1, bx2 = x + 4, x + w - 4
  local bcx = math.floor((bx1 + bx2) / 2)

  screen.level(3)
  screen.move(bx1, by); screen.line(bx2, by); screen.stroke()
  screen.move(bcx, by - 2); screen.line(bcx, by + 2); screen.stroke()

  local dx = util.linlin(-1, 1, bx1, bx2, data.corr)
  screen.level(data.corr < 0 and 15 or 10)
  screen.rect(dx - 1, by - 3, 3, 6); screen.fill()

  screen.level(2)
  screen.move(bx1, by + 7); screen.text("-1")
  screen.move(bx2 - 6, by + 7); screen.text("+1")
end

-- ── GONIOMETER widget ───────────────────────────────────
function widget_gonio(x, y, w, h)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text("GONIO")

  local cx = x + math.floor(w / 2)
  local cy = y + math.floor(h / 2) + 3
  local rad = math.min(w, h) * 0.35

  -- crosshair (rotated 45 degrees = M/S axes)
  screen.level(2)
  screen.move(cx - rad, cy - rad); screen.line(cx + rad, cy + rad); screen.stroke()
  screen.move(cx + rad, cy - rad); screen.line(cx - rad, cy + rad); screen.stroke()

  -- L/R labels on diagonal
  screen.level(3)
  screen.move(cx - rad - 3, cy - rad + 2); screen.text("L")
  screen.move(cx + rad - 1, cy - rad + 2); screen.text("R")

  -- plot recent L/R as rotated XY (M/S projection)
  for i = 0, GONIO_SIZE - 2 do
    local ci = ((gonio.idx - 2 - i) % GONIO_SIZE) + 1
    local l = gonio.l[ci]
    local r = gonio.r[ci]

    -- M/S transform: M = (L+R), S = (L-R)
    -- map to screen: x=S, y=-M (M points up)
    local m = (l + r) * 0.5
    local s = (l - r) * 0.5

    local px = cx + s * rad * 0.02  -- scale for dB values
    local py = cy - m * rad * 0.02

    px = util.clamp(px, x + 2, x + w - 2)
    py = util.clamp(py, y + 8, y + h - 2)

    local age = i / GONIO_SIZE
    local br = math.floor(12 * (1 - age))
    if br > 0 then
      screen.level(br)
      screen.pixel(px, py); screen.fill()
    end
  end
end

-- ── SPECTRUM widget ─────────────────────────────────────
function widget_spectrum(x, y, w, h)
  local bars = math.min(32, math.floor(w / 2))
  local max_h = h - 4

  for i = 1, bars do
    local db = util.clamp(data.spec[i], -70, spec_ceiling)
    local pk = util.clamp(data.peaks[i], -70, spec_ceiling)
    local bh = util.linlin(-70, spec_ceiling, 0, max_h, db)
    local ph = util.linlin(-70, spec_ceiling, 0, max_h, pk)
    local bx = x + (i - 1) * 2

    local br = math.floor(util.linlin(-70, spec_ceiling, 1, 10, db))
    screen.level(br)
    screen.move(bx, y + h - 1); screen.line(bx, y + h - 1 - bh); screen.stroke()

    if ph > 1 then
      screen.level(13)
      screen.move(bx, y + h - 1 - ph)
      screen.line(bx + 1, y + h - 1 - ph); screen.stroke()
    end
  end

  if spec_ceiling < 0 then
    screen.level(2); screen.font_size(8)
    screen.move(x + 2, y + 8); screen.text(spec_ceiling .. "dB")
  end
end

-- ── PEAK/RMS widget ─────────────────────────────────────
function widget_peak_rms(x, y, w, h)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text("PK/RMS")

  -- L
  screen.level(data.peak_l > -1 and 15 or 7)
  screen.move(x + 2, y + 15)
  screen.text("L " .. fdb0(data.peak_l) .. " / " .. fdb0(data.rms_l))

  -- R
  screen.level(data.peak_r > -1 and 15 or 7)
  screen.move(x + 2, y + 23)
  screen.text("R " .. fdb0(data.peak_r) .. " / " .. fdb0(data.rms_r))
end

-- ── BALANCE widget ──────────────────────────────────────
function widget_balance(x, y, w, h)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text("BALANCE")

  local bx1, bx2 = x + 4, x + w - 4
  local by = y + 16
  local bcx = math.floor((bx1 + bx2) / 2)

  screen.level(2)
  screen.move(bx1, by); screen.line(bx2, by); screen.stroke()
  screen.level(4)
  screen.move(bcx, by - 2); screen.line(bcx, by + 2); screen.stroke()

  local bdot = util.linlin(-1, 1, bx1, bx2, data.balance)
  screen.level(15)
  screen.rect(bdot - 1, by - 2, 3, 4); screen.fill()

  screen.level(6)
  screen.move(x + 2, by + 8)
  if math.abs(data.balance) < 0.05 then screen.text("CENTER")
  else screen.text(string.format("%.0f%%", data.balance * 100) ..
    (data.balance > 0 and " R" or " L")) end
end

-- ── CREST widget ────────────────────────────────────────
function widget_crest(x, y, w, h)
  screen.font_size(8); screen.level(4)
  screen.move(x + 2, y + 7); screen.text("CREST")

  local cl = data.peak_l - data.rms_l
  local cr = data.peak_r - data.rms_r
  local avg = (cl + cr) * 0.5

  screen.font_size(14)
  screen.level(avg < 6 and 15 or 8)  -- low crest = compressed, bright warning
  screen.move(x + 2, y + 22)
  if avg > 0 and avg < 60 then
    screen.text(string.format("%.0f", avg) .. " dB")
  else
    screen.text("--")
  end

  screen.font_size(8); screen.level(3)
  screen.move(x + 2, y + h - 2)
  screen.text(avg < 6 and "compressed" or (avg < 14 and "normal" or "dynamic"))
end

-- ════════════════════════════════════════════════════════
-- PAGE 2: DYNAMICS
-- ════════════════════════════════════════════════════════
function draw_dynamics()
  -- LUFS history
  screen.level(5); screen.font_size(8)
  screen.move(0, 7); screen.text("LUFS HISTORY")
  screen.level(2); screen.move(48, 7); screen.text("T:" .. target_lufs)

  local gx1, gx2 = 0, 127
  local gy1, gy2 = 9, 30
  screen.level(1)
  screen.rect(gx1, gy1, gx2 - gx1, gy2 - gy1); screen.stroke()

  local ty = math.floor(util.linlin(-40, 0, gy2, gy1,
    util.clamp(target_lufs, -40, 0)))
  screen.level(3)
  screen.move(gx1, ty); screen.line(gx2, ty); screen.stroke()

  screen.level(8)
  local started = false
  for i = 0, HIST_LEN - 1 do
    local idx = ((hist_idx - 1 - i - 1) % HIST_LEN) + 1
    local val = util.clamp(lufs_hist[idx], -40, 0)
    local px = gx2 - math.floor(i * (gx2 - gx1) / HIST_LEN)
    local py = util.clamp(math.floor(util.linlin(-40, 0, gy2, gy1, val)), gy1, gy2)
    if not started then screen.move(px, py); started = true
    else screen.line(px, py) end
  end
  screen.stroke()

  screen.level(15); screen.font_size(8)
  screen.move(gx2 - 26, gy1 + 6); screen.text(fdb(data.st))

  -- L/R peak bars + numeric
  screen.level(4); screen.font_size(8)
  screen.move(0, 38); screen.text("L")
  screen.move(0, 46); screen.text("R")

  local bx, bw = 8, 60
  local lpf = math.floor(util.linlin(-70, 0, 0, bw, util.clamp(data.peak_l, -70, 0)))
  screen.level(data.peak_l > -1 and 15 or 7)
  screen.rect(bx, 34, lpf, 3); screen.fill()
  local lph = math.floor(util.linlin(-70, 0, 0, bw, util.clamp(peak_hold_l, -70, 0)))
  if lph > 0 then
    screen.level(11)
    screen.move(bx + lph, 34); screen.line(bx + lph, 37); screen.stroke()
  end

  local rpf = math.floor(util.linlin(-70, 0, 0, bw, util.clamp(data.peak_r, -70, 0)))
  screen.level(data.peak_r > -1 and 15 or 7)
  screen.rect(bx, 42, rpf, 3); screen.fill()
  local rph = math.floor(util.linlin(-70, 0, 0, bw, util.clamp(peak_hold_r, -70, 0)))
  if rph > 0 then
    screen.level(11)
    screen.move(bx + rph, 42); screen.line(bx + rph, 45); screen.stroke()
  end

  -- numeric values
  screen.level(7); screen.font_size(8)
  screen.move(72, 38); screen.text("PK " .. fdb0(data.peak_l))
  screen.move(104, 38); screen.text(fdb0(data.rms_l))
  screen.move(72, 46); screen.text("PK " .. fdb0(data.peak_r))
  screen.move(104, 46); screen.text(fdb0(data.rms_r))

  -- balance
  screen.level(4); screen.move(0, 54); screen.text("BAL")
  local bl1, bl2 = 16, 90
  local bly = 55
  screen.level(2)
  screen.move(bl1, bly); screen.line(bl2, bly); screen.stroke()
  screen.level(4)
  local blc = math.floor((bl1+bl2)/2)
  screen.move(blc, bly-1); screen.line(blc, bly+1); screen.stroke()
  local bd = util.linlin(-1, 1, bl1, bl2, data.balance)
  screen.level(15)
  screen.rect(bd-1, bly-2, 3, 4); screen.fill()

  -- crest
  local crest = ((data.peak_l - data.rms_l) + (data.peak_r - data.rms_r)) * 0.5
  screen.level(6); screen.move(96, 54); screen.text("CR")
  screen.level(10); screen.move(108, 54)
  screen.text((crest > 0 and crest < 60) and string.format("%.0f", crest) or "--")

  -- balance numeric
  screen.level(4); screen.move(96, 62)
  if math.abs(data.balance) < 0.05 then screen.text("C")
  else screen.text(string.format("%.0f%%", data.balance * 100)) end
end
