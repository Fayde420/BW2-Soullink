-- ═══════════════════════════════════════════════════════════
--  Aktuelle Map-ID anzeigen (alle 5 Kandidaten).
--  Lauf damit durch verschiedene Routen/Städte und notier dir,
--  welche ID an welchem Ort steht.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")

local CANDIDATES = {
  0x009DB6E,
  0x009E08E,
  0x009E0A6,
  0x009E0B2,
  0x009E0C6,
}

-- Bekannte Zuordnung (wird wachsen)
local MAP_NAMES = {
  [2] = "Dausing",          -- Floccesy Town (die Stadt)
  [3] = "Route 19",
  -- Dausing-Hof (= Floccesy Ranch) hat eigene ID, noch zu finden
}

while true do
  local primary = memory.read_u16_le(CANDIDATES[1])
  local name = MAP_NAMES[primary] or ("? (neue ID)")
  gui.text(8, 8, string.format("MAP: %s", name))
  for i, addr in ipairs(CANDIDATES) do
    gui.text(8, 26 + (i - 1) * 14,
      string.format("0x%07X = %d", addr, memory.read_u16_le(addr)))
  end
  emu.frameadvance()
end
