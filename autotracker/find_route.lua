-- ═══════════════════════════════════════════════════════════
--  Map-ID-Finder v2: Multi-Snapshot + Intersection
--  Adressen, die sich bei JEDEM Routenwechsel ändern, sind
--  die echten Kandidaten. Filtert das meiste Rauschen weg.
--
--  Bedienung:
--    F1 = Snapshot hinzufügen
--    F2 = Schnittmenge berechnen + ausgeben
--    F3 = alle Snapshots verwerfen, neu anfangen
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

local snaps = {}
local prev = {}

local function takeSnap()
  local s = {}
  local cnt = 0
  for addr = 0, RAM - 2, 2 do
    local v = memory.read_u16_le(addr)
    if v >= 1 and v <= 2000 then
      s[addr] = v
      cnt = cnt + 1
    end
  end
  return s, cnt
end

print("═══ Multi-Snapshot Map-ID Finder ═══")
print("Workflow:")
print("  1. Du stehst still auf Route A. Drücke F2.")
print("  2. Geh zu Route B. F2.")
print("  3. Geh zu Route C (oder zurück zu A). F2.")
print("  4. F3  →  zeigt nur Adressen, die sich bei JEDEM Wechsel änderten.")
print("  (F4 = alles zurücksetzen)")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print(string.format("Snapshot %d läuft...", #snaps + 1))
    local s, n = takeSnap()
    snaps[#snaps + 1] = s
    print(string.format("  → Snapshot %d fertig (%d Werte).", #snaps, n))
  end

  if k.F4 and not prev.F4 then
    snaps = {}
    print("Alle Snapshots verworfen.")
  end

  if k.F3 and not prev.F3 then
    if #snaps < 2 then
      print("Brauche mindestens 2 Snapshots (besser 3).")
    else
      print("Intersection läuft...")
      local consistent = {}
      for addr, v0 in pairs(snaps[1]) do
        local vals = { v0 }
        local changedEvery = true
        for i = 2, #snaps do
          local cur = snaps[i][addr]
          if not cur or cur == vals[#vals] then
            changedEvery = false
            break
          end
          vals[#vals + 1] = cur
        end
        if changedEvery then consistent[addr] = vals end
      end
      local list = {}
      for addr in pairs(consistent) do list[#list + 1] = addr end
      table.sort(list)
      print(string.format("%d Adressen ändern sich bei JEDEM Wechsel:", #list))
      for _, addr in ipairs(list) do
        print(string.format("  0x%07X:  %s",
          addr, table.concat(consistent[addr], "  →  ")))
      end
      print("→ Die Map-ID ist typischerweise eine niedrige Zahl (1–700).")
    end
  end

  prev = k
  emu.frameadvance()
end
