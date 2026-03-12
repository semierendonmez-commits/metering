-- scriptname: metering
-- v2.2.1
-- description: Pro Audio Analyzer \n K2: Freeze \n K3: Reset INT \n E1: Calib Trim \n E2: Target \n E3: Spec Max

engine.name = 'Metering'

local is_frozen = false
local target_lufs = -14
local spec_max = 0
local peak_decay = 0.5
local calib_db = 10 

local data = {
  mom = -70,
  st = -70,
  int = -70,
  corr = 0,
  spec = {},
  peaks = {}
}

for i=1, 32 do 
  data.spec[i] = -70 
  data.peaks[i] = -70
end

-- GLOBAL YERİNE LOCAL DEĞİŞKEN (Best Practice)
local screen_dirty = false

function init()
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if screen_dirty then
        redraw()
        screen_dirty = false
      end
    end
  end)
end

osc.event = function(path, args, from)
  if path == '/meter_data' then
    if is_frozen then return end
    
    data.mom = args[1] + calib_db
    data.st = args[2] + calib_db
    data.int = args[3] + calib_db
    data.corr = args[4] 
    
    for i = 1, 32 do
      local val = args[4 + i] + calib_db
      data.spec[i] = val
      if val >= data.peaks[i] then
        data.peaks[i] = val
      else
        data.peaks[i] = data.peaks[i] - peak_decay
      end
    end
    
    screen_dirty = true
  end
end

function key(n, z)
  if n == 2 and z == 1 then
    is_frozen = not is_frozen
    screen_dirty = true
  elseif n == 3 and z == 1 then
    engine.reset_int()
    data.int = -70
    screen_dirty = true
  end
end

function enc(n, d)
  if n == 1 then
    calib_db = util.clamp(calib_db + d, -24, 24)
    screen_dirty = true
  elseif n == 2 then
    target_lufs = util.clamp(target_lufs + d, -40, 0)
    screen_dirty = true
  elseif n == 3 then
    spec_max = util.clamp(spec_max + d, -60, 0)
    screen_dirty = true
  end
end

local function format_lufs(val)
  if val < -65 then return "-inf" else return string.format("%.1f", val) end
end

function redraw()
  screen.clear()
  screen.aa(1)
  
  screen.level(2)
  screen.move(62, 0); screen.line(62, 64); screen.stroke()

  -- ==========================================
  -- 1. SOL BLOK: LUFS GÖSTERGELERİ (M, S, I)
  -- ==========================================
  screen.font_size(8)
  screen.level(2)
  screen.move(40, 7); screen.text("T:" .. target_lufs)
  
  screen.level(4)
  screen.move(0, 7); screen.text("MOM")
  screen.font_size(14)
  screen.level((data.mom >= target_lufs) and 15 or 8)
  screen.move(0, 20); screen.text(format_lufs(data.mom))
  
  screen.font_size(8)
  screen.level(4)
  screen.move(0, 29); screen.text("SHORT")
  screen.font_size(14)
  screen.level((data.st >= target_lufs) and 15 or 8)
  screen.move(0, 42); screen.text(format_lufs(data.st))
  
  screen.font_size(8)
  screen.level(4)
  screen.move(0, 51); screen.text("INT")
  screen.font_size(14)
  screen.level((data.int >= target_lufs) and 15 or 10) 
  screen.move(0, 64); screen.text(format_lufs(data.int))

  screen.font_size(8)

  -- ==========================================
  -- 2. SAĞ ÜST BLOK: PHASE METER & CALIB INFO
  -- ==========================================
  screen.level(2)
  if calib_db ~= 0 then
    screen.move(65, 8); screen.text(string.format("%+ddB", calib_db))
  end

  screen.level(10)
  screen.move(95, 8); screen.text_center("PHASE")
  screen.level(15)
  screen.move(95, 17); screen.text_center(string.format("%.2f", data.corr))
  
  screen.level(3)
  screen.move(70, 25); screen.line(120, 25); screen.stroke()
  screen.move(95, 23); screen.line(95, 27); screen.stroke()
  
  local cx = util.linlin(-1.0, 1.0, 70, 120, data.corr)
  screen.level(15)
  screen.rect(cx - 1, 22, 3, 6); screen.fill()

  screen.level(2)
  screen.move(64, 31); screen.line(128, 31); screen.stroke()

  -- ==========================================
  -- 3. SAĞ ALT BLOK: SPECTRUM + PEAK HOLD
  -- ==========================================
  for i = 1, 32 do
    local db = util.clamp(data.spec[i], -70, spec_max)
    local peak_db = util.clamp(data.peaks[i], -70, spec_max)
    
    local h = util.linlin(-70, spec_max, 0, 30, db)
    local ph = util.linlin(-70, spec_max, 0, 30, peak_db)
    
    local x = 64 + ((i - 1) * 2)
    
    local bright = math.floor(util.linlin(-70, spec_max, 2, 10, db))
    screen.level(bright)
    screen.move(x, 64)
    screen.line(x, 64 - h)
    screen.stroke()
    
    screen.level(15)
    screen.move(x, 64 - ph)
    screen.line(x+1, 64 - ph)
    screen.stroke()
  end
  
  if spec_max < 0 then
    screen.level(2)
    screen.move(65, 38); screen.text(spec_max .. "dB")
  end

  if is_frozen then
    screen.level(15)
    screen.move(126, 8)
    screen.text_right("*")
  end

  screen.update()
end
