-- ═══════════════════════════════════════════════════════════
--  Persistente HP-Adresse finden via Vergiftung
--
--  Idee: Vergiftete Pokémon verlieren beim LAUFEN außerhalb
--  des Kampfs HP. Wenn wir Snapshots davor/dazwischen/danach
--  machen, sinkt die persistente HP-Adresse monoton.
--
--    F2 = Snapshot hinzufügen
--    F3 = zeigt Adressen, die in JEDEM Schritt um 1-30 sanken
--    F4 = Reset
--
--  Workflow:
--   1. Ein Pokémon vergiften lassen (z.B. von Zubat/Koffing/etc).
--      Status-Anzeige: "VRG" links unten neben Pokémon im Menü.
--   2. KAMPF VERLASSEN, auf Route stehen.
--   3. F2 = Snapshot 1.
--   4. ~5 Schritte laufen (HP des vergifteten Pokémon sinkt).
--   5. F2 = Snapshot 2.
--   6. Weitere ~5 Schritte, F2 = Snapshot 3.
--   7. F3 = Schnittmenge.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

local snaps = {}
local prev = {}

local function takeSnap()
  local s = {}
  local cnt = 0
  for a = 0, RAM - 2, 2 do
    local v = memory.read_u16_le(a)
    if v >= 1 and v <= 700 then
      s[a] = v
      cnt = cnt + 1
    end
  end
  return s, cnt
end

print("═══ Persistente HP-Finder (Vergiftung-Trick) ═══")
print("Vor dem Start: ein Pokémon im Team muss VERGIFTET sein.")
print("")
print("Workflow:")
print("  1. Außerhalb des Kampfs auf einer Route stehen.")
print("  2. F2 = Snapshot 1 (Start-HP)")
print("  3. ~5 Schritte laufen, F2 = Snapshot 2")
print("  4. ~5 Schritte laufen, F2 = Snapshot 3")
print("  5. F3 = Schnittmenge (= persistente HP-Adresse)")
print("  (F4 = Reset)")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print(string.format("Snapshot %d läuft (~2s)...", #snaps + 1))
    local t0 = os.clock()
    local s, n = takeSnap()
    snaps[#snaps + 1] = s
    print(string.format("  → Snapshot %d: %d Werte  (%.1fs)",
      #snaps, n, os.clock() - t0))
  end

  if k.F4 and not prev.F4 then
    snaps = {}
    print("Reset.")
  end

  if k.F3 and not prev.F3 then
    if #snaps < 2 then
      print("Brauche mindestens 2 Snapshots.")
    else
      print("Schnittmenge berechnen...")
      local hits = {}
      for addr, v0 in pairs(snaps[1]) do
        local vals = { v0 }
        local ok = true
        for i = 2, #snaps do
          local cur = snaps[i][addr]
          if not cur then ok = false; break end
          local d = vals[#vals] - cur
          -- Vergiftung-Schaden ist klein (1-30 pro Snapshot-Intervall)
          if d < 1 or d > 30 or cur < 1 or cur > 700 then
            ok = false; break
          end
          vals[#vals + 1] = cur
        end
        if ok then hits[#hits + 1] = { addr = addr, vals = vals } end
      end
      table.sort(hits, function(a, b) return a.addr < b.addr end)
      print(string.format("%d Treffer (in jedem Schritt um 1-30 gesunken):", #hits))
      for i, h in ipairs(hits) do
        if i > 80 then print("  ... (gekürzt)"); break end
        print(string.format("  0x%07X:  %s", h.addr, table.concat(h.vals, " → ")))
      end
      print("")
      print("→ Die persistente HP-Adresse ist die mit Werten, die zur")
      print("  echten KP-Abnahme deines vergifteten Pokémon passen.")
    end
  end

  prev = k
  emu.frameadvance()
end
