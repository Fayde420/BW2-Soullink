-- ═══════════════════════════════════════════════════════════
--  HP-Probe: zeigt Live-Werte an verschiedenen Kandidaten-
--  Adressen + Strides für Slot 1 UND Slot 2.
--
--  Sei im Spiel, idealerweise in einem Kampf. Vergleiche die
--  Werte mit den echten KP deiner Pokémon auf dem Bildschirm.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")

-- Kandidaten für Slot-1-HP-Basis
local CANDIDATES = {
  {0x025B134, "find_hp #1"},          -- aus find_hp.lua
  {0x025BE0C, "find_hp #2"},
  {0x02AB930, "find_hp #3"},
  {0x0257CB4 + 0x88 + 6, "battle@0x0257CB4 +0x8E"},  -- IronMon Stil
  {0x0258214 + 0x88 + 6, "battle@0x0258214 +0x8E"},
}

local STRIDES = { 220, 84, 12, 8, 0xDC }   -- für Slot 2 zu testen

while true do
  gui.text(8, 8, "== HP-PROBE ==  Slot 1 / Slot 2 (Stride)")
  local y = 24
  for _, c in ipairs(CANDIDATES) do
    local addr, label = c[1], c[2]
    local s1_cur = memory.read_u16_le(addr)
    local s1_max = memory.read_u16_le(addr + 2)
    gui.text(8, y, string.format("%-26s 0x%07X => %3d/%3d",
      label, addr, s1_cur, s1_max))
    y = y + 12
    -- Slot 2 mit verschiedenen Strides
    local stridesLine = "  S2:"
    for _, s in ipairs(STRIDES) do
      local v = memory.read_u16_le(addr + s)
      stridesLine = stridesLine .. string.format(" +%-3d=%-3d", s, v)
    end
    gui.text(8, y, stridesLine)
    y = y + 14
  end
  emu.frameadvance()
end
