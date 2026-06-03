-- ═══════════════════════════════════════════════════════════
--  Orden-Bitfeld-Adresse finden  (Multi-Snapshot-Variante)
--
--  Annahme: Orden werden in einem einzelnen u8 als Bitfeld
--  gespeichert. Beim Sieg gegen einen Arena-Leiter wird
--  GENAU EIN neues Bit gesetzt (was → was | (1<<k)), wobei
--  alle vorher gesetzten Bits erhalten bleiben.
--
--  Diese Variante stackt mehrere Snapshots. Nach jedem
--  Arena-Sieg drückst du F2 für einen neuen Snapshot.
--  Nach F3 werden alle Adressen ausgegeben, die sich
--  ZWISCHEN ALLEN aufeinanderfolgenden Snapshots strikt
--  bit-additiv verhalten haben (alte Bits bleiben, ein
--  neues Bit kommt dazu). Nach 2–3 Orden bleibt typisch
--  nur noch eine handvoll Kandidaten.
--
--  Bedienung:
--    F2 = neuen Snapshot speichern (mind. 2 nötig, max. 8)
--          → idealerweise direkt VOR dem Orden-Hit, oder
--          unmittelbar NACH der Orden-Animation
--    F3 = Kandidaten-Liste ausgeben
--    F4 = alle Snapshots verwerfen, von vorne starten
--
--  Tipp: Bei einem laufenden Run nimm einfach VOR dem
--  nächsten Arena-Kampf einen Snapshot, dann nach dem
--  Sieg den nächsten — schon zwei Snapshots reichen für
--  eine gute Vorauswahl.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

-- Auf den typischen Save-Daten-Bereich begrenzen (Party, Box,
-- Map-Header liegen alle in 0x200000-0x280000). Das reduziert
-- die Treffer dramatisch und filtert Animations-/VRAM-Puffer raus.
-- Auf nil setzen, um den ganzen Main-RAM zu scannen.
local SCAN_FROM = 0x200000
local SCAN_TO   = 0x280000

local PRINT_LIMIT = 200

local snaps = {}    -- Liste von Snapshot-Strings (in Reihenfolge)
local prev  = {}

local function takeSnap()
  local lo = SCAN_FROM or 0
  local hi = (SCAN_TO or RAM) - 1
  local parts = {}
  for a = lo, hi do
    parts[#parts + 1] = string.char(memory.read_u8(a))
  end
  return table.concat(parts), lo
end

local function isPow2(n)
  return n > 0 and (n & (n - 1)) == 0
end

-- Prüft: ist b = a | (1<<k) für genau ein k? (alle alten Bits bleiben,
-- genau ein neues Bit dazu)
local function bitAdditive(a, b)
  if b <= a then return false end
  if (a & b) ~= a then return false end     -- alte Bits müssen bleiben
  local d = b - a
  return isPow2(d)
end

print("═══ Orden-Finder (Multi-Snapshot) ═══")
print(string.format("Scan-Range: 0x%X – 0x%X (%d Bytes)",
  SCAN_FROM or 0, (SCAN_TO or RAM) - 1, (SCAN_TO or RAM) - (SCAN_FROM or 0)))
print("Workflow:")
print("  F2 = Snapshot speichern (vor jedem Orden, oder vor 1. + nach 2.)")
print("  F3 = Kandidaten anzeigen (mind. 2 Snapshots)")
print("  F4 = alle Snapshots löschen")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print(string.format("Snapshot #%d läuft (~3s)...", #snaps + 1))
    local t0 = os.clock()
    local snap, base = takeSnap()
    snaps[#snaps + 1] = { data = snap, base = base }
    print(string.format("  → fertig (%d Bytes, %.1fs) — total Snapshots: %d",
      #snap, os.clock() - t0, #snaps))
  end

  if k.F4 and not prev.F4 then
    snaps = {}
    print("Snapshots gelöscht.")
  end

  if k.F3 and not prev.F3 then
    if #snaps < 2 then
      print(string.format("Brauche mind. 2 Snapshots (aktuell %d).", #snaps))
    else
      print(string.format("Diff über %d Snapshots läuft...", #snaps))
      local t0 = os.clock()
      local base = snaps[1].base
      local n = #snaps[1].data
      -- Kandidaten = Adressen, bei denen ALLE Snapshot-Übergänge
      -- bit-additiv sind, und das Endergebnis hat zwischen 1 und
      -- #snaps gesetzte Bits insgesamt (typisch für Orden-Progression).
      local hits = {}
      for off = 0, n - 1 do
        local ok = true
        local seq = {}
        for i = 1, #snaps do
          seq[i] = snaps[i].data:byte(off + 1)
        end
        -- jeder Übergang muss bit-additiv sein
        for i = 1, #seq - 1 do
          if not bitAdditive(seq[i], seq[i + 1]) then ok = false; break end
        end
        if ok then
          hits[#hits + 1] = { addr = base + off, seq = seq }
        end
      end
      table.sort(hits, function(x, y) return x.addr < y.addr end)
      print(string.format("%d Kandidaten (strikt bit-additiv): (%.1fs)",
        #hits, os.clock() - t0))
      for i, h in ipairs(hits) do
        if i > PRINT_LIMIT then
          print(string.format("  ... (%d weitere — Limit erhöhen falls nötig)",
            #hits - PRINT_LIMIT))
          break
        end
        local seqStr = ""
        for j, v in ipairs(h.seq) do
          if j > 1 then seqStr = seqStr .. " → " end
          seqStr = seqStr .. tostring(v)
        end
        print(string.format("  0x%07X:  %s", h.addr, seqStr))
      end
      print("")
      if #hits == 0 then
        print("Keine bit-additiven Kandidaten — entweder Scan-Range")
        print("erweitern oder Snapshots erneut machen.")
      elseif #hits <= 10 then
        print("→ Wenig Kandidaten! Trage die wahrscheinlichste als")
        print("  BADGE_ADDR in live_team.lua ein und teste.")
      else
        print("→ Noch zu viele Treffer. Mach beim NÄCHSTEN Orden")
        print("  noch einen F2-Snapshot, dann F3 nochmal — die Liste")
        print("  schrumpft weiter.")
      end
    end
  end

  prev = k
  emu.frameadvance()
end
