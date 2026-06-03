-- ═══════════════════════════════════════════════════════════
--  HP-Adresse finden via Mehrfach-Diff
--    F2 = Snapshot hinzufügen (mach es 3+ mal)
--    F3 = zeigt Adressen, die in JEDEM Schritt um 1-60 sanken
--    F4 = Reset
--
--  Workflow:
--   1. Team voll heilen.
--   2. F2  (Snapshot 1 = volle HP).
--   3. Schaden auf Slot 1 zufügen.   F2  (Snapshot 2).
--   4. Nochmal Schaden auf Slot 1.   F2  (Snapshot 3).
--   5. F3  → narrow result. Nur die HP-Adresse bleibt übrig.
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

print("═══ HP-Finder (Multi-Diff) ═══")
print("Workflow:")
print("  1. Team voll heilen.")
print("  2. F2 = Snapshot 1 (volle HP).")
print("  3. Schaden auf Slot 1, F2 = Snapshot 2.")
print("  4. Nochmal Schaden, F2 = Snapshot 3.   (mehr ist besser!)")
print("  5. F3 = nur Adressen, die in JEDEM Schritt sanken.")
print("  (F4 = Reset)")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print(string.format("Snapshot %d läuft (~30s)...", #snaps + 1))
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
      print("Brauche mindestens 2 Snapshots (besser 3).")
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
          -- muss sinken (1–60 HP) UND immer noch im HP-Bereich liegen
          if d < 1 or d > 60 or cur < 1 or cur > 700 then
            ok = false; break
          end
          vals[#vals + 1] = cur
        end
        if ok then hits[#hits + 1] = { addr = addr, vals = vals } end
      end
      table.sort(hits, function(a, b) return a.addr < b.addr end)
      print(string.format("%d Treffer (in jedem Schritt um 1-60 gesunken):", #hits))
      for i, h in ipairs(hits) do
        if i > 60 then print("  ... (gekürzt)"); break end
        local s = string.format("0x%07X:  ", h.addr)
        s = s .. table.concat(h.vals, " → ")
        print("  " .. s)
      end
      print("")
      print("→ Die HP-Adresse für Slot 1 ist die mit den Werten, die zu")
      print("  deinem Spielverlauf passen (vor → nach Schaden 1 → nach 2).")
    end
  end

  prev = k
  emu.frameadvance()
end
