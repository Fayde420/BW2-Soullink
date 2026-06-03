-- ═══════════════════════════════════════════════════════════
--  Map-Header-Pointer finden  (32-Bit, Main-RAM-Pointer)
--
--  Anders als find_route.lua suchen wir hier nach u32-Zeigern
--  im Main-RAM-Adressbereich (0x02000000–0x02400000). Der
--  „aktuelle Map-Header-Pointer" ist genau so einer — und
--  ändert sich bei jedem Map-Wechsel garantiert.
--
--  Bedienung:
--    F2 = Snapshot hinzufügen
--    F3 = Schnittmenge berechnen
--    F4 = Reset
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

local snaps = {}
local prev = {}

-- Sammelt u32-Werte, die wie Pointer in Main RAM aussehen
local function takeSnap()
  local s = {}
  local cnt = 0
  for addr = 0, RAM - 4, 4 do
    local v = memory.read_u32_le(addr)
    if v >= 0x02000000 and v < 0x02400000 then
      s[addr] = v
      cnt = cnt + 1
    end
  end
  return s, cnt
end

print("═══ Map-Header-Pointer Finder ═══")
print("Workflow:")
print(" 1. Auf Map A still stehen → F2")
print(" 2. Auf Map B still stehen → F2")
print(" 3. Auf Map A zurück       → F2")
print(" 4. F3 → Adressen, wo der Pointer A→B→A wechselt")
print("    (Diese Pointer-Werte sind globale Map-IDs.)")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print(string.format("Snapshot %d läuft...", #snaps + 1))
    local s, n = takeSnap()
    snaps[#snaps + 1] = s
    print(string.format("  → %d Pointer erfasst", n))
  end

  if k.F4 and not prev.F4 then
    snaps = {}
    print("Reset.")
  end

  if k.F3 and not prev.F3 then
    if #snaps < 2 then
      print("Brauche mindestens 2 Snapshots (besser 4-5).")
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
      for addr in pairs(consistent) do list[#list+1] = addr end
      table.sort(list)

      -- Output in eine Datei (kein Flood-Limit)
      local out = io.open("C:/trash/PokemonWebsite/autotracker/map_header_results.txt", "w")
      if out then
        out:write(string.format("Snapshots: %d   Treffer: %d\n\n", #snaps, #list))
        for _, addr in ipairs(list) do
          local hex = {}
          for _, vv in ipairs(consistent[addr]) do
            hex[#hex+1] = string.format("0x%08X", vv)
          end
          out:write(string.format("0x%07X  %s\n", addr, table.concat(hex, "  ")))
        end
        out:close()
      end

      print(string.format("%d Pointer ändern sich bei JEDEM Wechsel.", #list))
      print("Vollständige Liste in:")
      print("  C:\\trash\\PokemonWebsite\\autotracker\\map_header_results.txt")
      print("")
      print("Top 20 (snapshot1 → ... → snapshotN):")
      for i = 1, math.min(20, #list) do
        local addr = list[i]
        local hex = {}
        for _, vv in ipairs(consistent[addr]) do hex[#hex+1] = string.format("0x%08X", vv) end
        print(string.format("  0x%07X  %s", addr, table.concat(hex, "  ")))
      end
    end
  end

  prev = k
  emu.frameadvance()
end
