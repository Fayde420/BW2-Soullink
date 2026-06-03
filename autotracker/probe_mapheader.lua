-- ═══════════════════════════════════════════════════════════
--  Probe: Map-Header-Adressen (parent + child)
--
--  Zeigt live u16-Werte an den IronMon-US-Adressen + nahen
--  Offsets. Lauf damit durch verschiedene Maps und beobachte:
--  - Welche Adresse hat einen kleinen, plausiblen u16-Wert?
--  - Welche ändert sich beim Map-Wechsel?
--  - Welche ist STABIL beim Stehenbleiben?
--
--  Die Adresse, die alle 3 Kriterien erfüllt, ist unser Goldgriff.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")

-- IronMon-US-Adressen + ±0x100 Offsets (Party-DE-Shift war -0x100)
local CANDIDATES = {
  {addr = 0x246848, label = "US parent"},
  {addr = 0x246860, label = "US child"},
  {addr = 0x246748, label = "-0x100 parent"},
  {addr = 0x246760, label = "-0x100 child"},
  {addr = 0x246948, label = "+0x100 parent"},
  {addr = 0x246960, label = "+0x100 child"},
  {addr = 0x246548, label = "-0x300 parent"},
  {addr = 0x246560, label = "-0x300 child"},
  {addr = 0x247248, label = "+0xA00 parent"},
  {addr = 0x247260, label = "+0xA00 child"},
}

while true do
  gui.text(8, 8, "MAP-HEADER PROBE")
  for i, c in ipairs(CANDIDATES) do
    local v = memory.read_u16_le(c.addr)
    gui.text(8, 24 + (i - 1) * 12,
      string.format("0x%07X (%-14s) = %5d", c.addr, c.label, v))
  end
  emu.frameadvance()
end
