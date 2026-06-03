-- ═══════════════════════════════════════════════════════════
--  PC-Box-Adresse finden  ·  v2  (robusterer Diff)
--    F2 = Snapshot 1 vor dem Ablegen   (~30 s)
--    F3 = Snapshot 2 nach dem Ablegen + Diff
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

local function mult32(a, b)
  local al, bl = a % 0x10000, b % 0x10000
  local ah = math.floor(a / 0x10000) % 0x10000
  local bh = math.floor(b / 0x10000) % 0x10000
  return (((ah * bl + al * bh) % 0x10000) * 0x10000 + al * bl) % 0x100000000
end

local A_POS = {[0]=0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3}

local function tryDecrypt(base)
  local pid = memory.read_u32_le(base)
  if pid == 0 then return nil end
  local checksum = memory.read_u16_le(base + 6)
  if checksum == 0 then return nil end
  local seed, sum = checksum, 0
  local words = {}
  for i = 0, 63 do
    seed = (mult32(seed, 0x41C64E6D) + 0x6073) % 0x100000000
    local key = math.floor(seed / 0x10000) % 0x10000
    words[i] = memory.read_u16_le(base + 8 + i * 2) ~ key
    sum = (sum + words[i]) % 0x10000
  end
  if sum ~= checksum then return nil end
  local shift = ((pid & 0x3E000) >> 13) % 24
  local species = words[A_POS[shift] * 16]
  if species < 1 or species > 700 then return nil end
  return { pid = pid, species = species }
end

-- Liefert eine Tabelle  addr -> { pid, species }
local function scan()
  local s = {}
  local n = 0
  for base = 0, RAM - 0x88, 4 do
    local m = tryDecrypt(base)
    if m then
      s[base] = m
      n = n + 1
    end
  end
  return s, n
end

local snap1 = nil
local prev = {}

print("═══ PC-Box-Finder  v2 ═══")
print("Workflow:")
print(" 1. Du hast Pokémon im Team. Drücke F2.")
print(" 2. Geh in den PC, lege ein Team-Pokémon in die Box.")
print(" 3. WICHTIG: bleib im Box-Bildschirm (PC-Box muss geladen sein)!")
print(" 4. Drücke F3.")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print("Scan 1 läuft (~30 s, Spiel friert ein)...")
    local t0 = os.clock()
    local n
    snap1, n = scan()
    print(string.format("  → %d Pokémon-Vorkommen gefunden (%.1f s)", n, os.clock() - t0))
    -- Adressen aufgelistet
    local addrs = {}
    for a in pairs(snap1) do addrs[#addrs+1] = a end
    table.sort(addrs)
    print("  Fundorte:")
    for _, a in ipairs(addrs) do
      print(string.format("    0x%07X  Spezies %3d  PID 0x%08X",
        a, snap1[a].species, snap1[a].pid))
    end
    print("→ Jetzt im Spiel ein Pokémon in die PC-Box ablegen, dann F3.")
  end

  if k.F3 and not prev.F3 then
    if not snap1 then
      print("Erst F2 drücken!")
    else
      print("Scan 2 läuft...")
      local t0 = os.clock()
      local snap2, n2 = scan()
      print(string.format("  → %d Pokémon-Vorkommen gefunden (%.1f s)", n2, os.clock() - t0))

      -- Verschwundene Adressen (snap1, aber nicht snap2)
      local gone = {}
      for a, m in pairs(snap1) do
        if not snap2[a] then gone[#gone+1] = { addr = a, m = m } end
      end
      -- Neu aufgetauchte Adressen (snap2, aber nicht snap1)
      local newAddrs = {}
      for a, m in pairs(snap2) do
        if not snap1[a] then newAddrs[#newAddrs+1] = { addr = a, m = m } end
      end
      -- PID-Wechsel an gleicher Adresse
      local changed = {}
      for a, m2 in pairs(snap2) do
        local m1 = snap1[a]
        if m1 and m1.pid ~= m2.pid then
          changed[#changed+1] = { addr = a, was = m1, now = m2 }
        end
      end

      table.sort(gone,     function(a,b) return a.addr < b.addr end)
      table.sort(newAddrs, function(a,b) return a.addr < b.addr end)
      table.sort(changed,  function(a,b) return a.addr < b.addr end)

      print("")
      print(string.format("── VERSCHWUNDEN  (waren da, jetzt weg)  %d ──", #gone))
      for _, e in ipairs(gone) do
        print(string.format("  0x%07X  Spezies %3d  PID 0x%08X",
          e.addr, e.m.species, e.m.pid))
      end

      print("")
      print(string.format("── NEU AUFGETAUCHT  %d ──", #newAddrs))
      for _, e in ipairs(newAddrs) do
        print(string.format("  0x%07X  Spezies %3d  PID 0x%08X",
          e.addr, e.m.species, e.m.pid))
      end

      print("")
      print(string.format("── PID-WECHSEL AN GLEICHER ADRESSE  %d ──", #changed))
      for _, e in ipairs(changed) do
        print(string.format("  0x%07X  Spezies %d→%d  PID 0x%08X→0x%08X",
          e.addr, e.was.species, e.now.species, e.was.pid, e.now.pid))
      end

      -- Wenn ein Pokémon abgelegt wurde: die PID, die aus dem Party-Bereich
      -- verschwand und an einer neuen Adresse auftauchte, zeigt uns die PC-Box
      print("")
      print("→ Der NEU AUFGETAUCHTE Eintrag ist die PC-Box-Adresse.")
      print("→ Falls die Liste leer ist: vermutlich PC-Box nicht in Main RAM")
      print("  oder du hast den Box-Bildschirm zu früh verlassen.")
    end
  end

  prev = k
  emu.frameadvance()
end
