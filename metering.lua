-- scriptname: metering
-- v2.0.0
-- description: Pro Audio Analyzer \n K2: Freeze Display \n K3: Reset INT LUFS \n E2: Target LUFS \n E3: Spec Max dB

engine.name = 'Metering'

-- Global State
local is_frozen = false
local target_lufs = -14  -- Varsayılan endüstri standardı (Örn: Streaming için)
local spec_max = 0       -- Spektrumun tavan noktası (Sinyali görsel olarak büyütmek için)
local peak_decay = 0.5   -- Peak noktalarının düşme hızı

local data = {
  st = -70,
  int = -70,
  corr = 0,
  spec = {},
  peaks = {}
}

-- Spektrum ve Tepe (Peak) tablolarını başlat
for i=1, 32 do 
  data.spec[i] = -70 
  data.peaks[i] = -70
end

_G.screen_dirty = false

function init()
  print("Pro Metering UI Started.")
  
  -- 15 FPS Çizim Döngüsü
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if _G.screen_dirty then
        redraw()
        _G.screen_dirty = false
      end
    end
  end)
end

-- SC Motorundan Gelen OSC Verileri
osc.event = function(path, args, from)
  if path == '/meter_data' then
    if is_frozen then return end -- Ekran dondurulduysa veriyi güncelleme
    
    data.st = args[1]
    data.int = args[2]
    data.corr = args[3]
    
    -- Spektrum verilerini çek ve Peak hesaplamasını yap
    for i = 1, 32 do
      local val = args[3 + i]
      data.spec[i] = val
      
      -- Peak noktası yeni değerden küçükse yukarı zıpla, değilse yavaşça düş
      if val >= data.peaks[i] then
        data.peaks[i] = val
      else
        data.peaks[i] = data.peaks[i] - peak_decay
      end
    end
    
    _G.screen_dirty = true
  end
end

-- DONANIM KONTROLLERİ
function key(n, z)
  if n == 2 and z == 1 then
    -- K2: Ekranı Dondur / Çöz
    is_frozen = not is_frozen
    _G.screen_dirty = true
  elseif n == 3 and z == 1 then
    -- K3: Integrated LUFS'u sıfırla (Yeni parçaya geçerken)
    engine.reset_int()
    data.int = -70
    _G.screen_dirty = true
  end
end

function enc(n, d)
  if n == 2 then
    -- E2: Hedef LUFS çizgisini ayarla
    target_lufs = util.clamp(target_lufs + d, -40, 0)
    _G.screen_dirty = true
  elseif n == 3 then
    -- E3: Spektrum aralığını ayarla (Zayıf sinyaller için görsel gain)
    spec_max = util.clamp(spec_max + d, -60, 0)
    _G.screen_dirty = true
  end
end

-- EKRAN ÇİZİM FONKSİYONU
function redraw()
  screen.clear()
  screen.aa(1) -- Daha pürüzsüz grafikler için Anti-Aliasing açık
  
  -- Dikey Ayırıcı Çizgi (Ekranı ikiye böler: X=62)
  screen.level(2)
  screen.move(62, 0); screen.line(62, 64); screen.stroke()

  -- ==========================================
  -- 1. SOL BLOK: DEV LUFS GÖSTERGELERİ (0 - 60 px)
  -- ==========================================
  
  -- ST LUFS Başlığı ve Target Değeri
  screen.font_size(8)
  screen.level(4)
  screen.move(0, 10); screen.text("ST LUFS")
  screen.level(2)
  screen.move(40, 10); screen.text("T:" .. target_lufs)
  
  -- ST LUFS Rakamı
  screen.font_size(16)
  local st_color = (data.st >= target_lufs) and 15 or 8 -- Hedefi geçerse parla
  screen.level(st_color)
  screen.move(0, 26)
  if data.st < -65 then screen.text("-inf") else screen.text(string.format("%.1f", data.st)) end
  
  -- INT LUFS Başlığı
  screen.font_size(8)
  screen.level(4)
  screen.move(0, 42); screen.text("INT LUFS")
  
  -- INT LUFS Rakamı
  screen.font_size(16)
  local int_color = (data.int >= target_lufs) and 15 or 8
  screen.level(int_color)
  screen.move(0, 58)
  if data.int < -65 then screen.text("-inf") else screen.text(string.format("%.1f", data.int)) end

  -- Diğer ekran birimleri için fontu normale döndür
  screen.font_size(8)

  -- ==========================================
  -- 2. SAĞ ÜST BLOK: PHASE METER (X: 64-128, Y: 0-32)
  -- ==========================================
  screen.level(10)
  screen.move(95, 8); screen.text_center("PHASE")
  
  screen.level(15)
  screen.move(95, 17); screen.text_center(string.format("%.2f", data.corr))
  
  -- Phase Metre Çizgisi
  screen.level(3)
  screen.move(70, 25); screen.line(120, 25); screen.stroke()
  screen.move(95, 23); screen.line(95, 27); screen.stroke() -- Merkez
  
  -- Phase Noktası
  local cx = util.linlin(-1.0, 1.0, 70, 120, data.corr)
  screen.level(15)
  screen.rect(cx - 1, 22, 3, 6); screen.fill()

  -- Yatay Ayırıcı Çizgi (Sağ tarafı altlı üstlü böler)
  screen.level(2)
  screen.move(64, 31); screen.line(128, 31); screen.stroke()

  -- ==========================================
  -- 3. SAĞ ALT BLOK: MİNİ SPEKTRUM + PEAK HOLD (X: 64-128, Y: 32-64)
  -- ==========================================
  for i = 1, 32 do
    local db = util.clamp(data.spec[i], -70, spec_max)
    local peak_db = util.clamp(data.peaks[i], -70, spec_max)
    
    -- Yükseklikleri 0 ile 30 px arasına map et (Alt sınır Y=64)
    local h = util.linlin(-70, spec_max, 0, 30, db)
    local ph = util.linlin(-70, spec_max, 0, 30, peak_db)
    
    local x = 64 + ((i - 1) * 2)
    
    -- Ana Barlar (Sese göre parlaklık)
    local bright = math.floor(util.linlin(-70, spec_max, 2, 10, db))
    screen.level(bright)
    screen.move(x, 64)
    screen.line(x, 64 - h)
    screen.stroke()
    
    -- Peak Hold Noktaları (Her barın üzerinde asılı kalan maksimum noktalar)
    screen.level(15)
    screen.move(x, 64 - ph)
    screen.line(x+1, 64 - ph)
    screen.stroke()
  end
  
  -- Spektrum tavanı bilgisini göster (E3 ile değişir)
  if spec_max < 0 then
    screen.level(2)
    screen.move(65, 38); screen.text(spec_max .. "dB")
  end

  -- Dondurulmuş (Freeze) ekran uyarısı
  if is_frozen then
    screen.level(15)
    screen.move(126, 8)
    screen.text_right("*")
  end

  screen.update()
end
