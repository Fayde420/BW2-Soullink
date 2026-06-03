-- ═══════════════════════════════════════════════════════════
--  Pokémon Schwarz 2 (DE)  ·  Team-Auslese (v2)
--  Live-Anzeige der 6 Team-Slots als Overlay.
--  Adressen für die DEUTSCHE Version (selbst gefunden).
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")

local PARTY_BASE = 0x21E32C       -- DE Schwarz 2
local MON_SIZE   = 220
local A_POS = {[0]=0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3}

local function mult32(a, b)
  local al, bl = a % 0x10000, b % 0x10000
  local ah = math.floor(a / 0x10000) % 0x10000
  local bh = math.floor(b / 0x10000) % 0x10000
  return (((ah * bl + al * bh) % 0x10000) * 0x10000 + al * bl) % 0x100000000
end

local function readSpecies(slot)
  local base = PARTY_BASE + slot * MON_SIZE
  local pid  = memory.read_u32_le(base)
  if pid == 0 then return nil end
  local checksum = memory.read_u16_le(base + 6)
  local seed, sum = checksum, 0
  local words = {}
  for i = 0, 63 do
    seed = (mult32(seed, 0x41C64E6D) + 0x6073) % 0x100000000
    local key = math.floor(seed / 0x10000) % 0x10000
    local w = memory.read_u16_le(base + 8 + i * 2) ~ key
    words[i] = w
    sum = (sum + w) % 0x10000
  end
  if sum ~= checksum then return nil end
  local shift = ((pid & 0x3E000) >> 13) % 24
  return words[A_POS[shift] * 16]
end

-- Spritzige Anzeige: alle 30 Frames neu auslesen (zweimal pro Sekunde reicht)
local cache = {}
local frame = 0

while true do
  frame = frame + 1
  if frame % 30 == 0 or frame == 1 then
    for slot = 0, 5 do
      cache[slot] = readSpecies(slot)
    end
  end

  gui.text(8, 8, "== TEAM ==")
  for slot = 0, 5 do
    local sp = cache[slot]
    if sp then
      gui.text(8, 26 + slot * 16, string.format("Slot %d:  ID %3d", slot + 1, sp))
    else
      gui.text(8, 26 + slot * 16, string.format("Slot %d:  (leer)", slot + 1))
    end
  end

  emu.frameadvance()
end
