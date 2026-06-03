-- ═══════════════════════════════════════════════════════════
--  Gegner-Pokémon-Adresse im Kampf finden
--    F2 = Snapshot 1 (außerhalb eines Kampfs)
--    Im Spiel einen Wild-Kampf auslösen, im Kampf-Menü stehen
--    F3 = Snapshot 2 + Diff -> zeigt, wo der Gegner liegt
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

local A_POS = {[0]=0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3}

local function mult32(a, b)
  local al, bl = a % 0x10000, b % 0x10000
  local ah = math.floor(a / 0x10000) % 0x10000
  local bh = math.floor(b / 0x10000) % 0x10000
  return (((ah * bl + al * bh) % 0x10000) * 0x10000 + al * bl) % 0x100000000
end

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

local function scan()
  local s = {}
  local n = 0
  for base = 0, RAM - 0x88, 4 do
    local m = tryDecrypt(base)
    if m then s[base] = m; n = n + 1 end
  end
  return s, n
end

local snap1, prev = nil, {}

print("═══ Gegner-Pokémon-Finder ═══")
print("Workflow:")
print(" 1. Du stehst auf einer Route, KEIN Kampf. Drücke F2  (~30s).")
print(" 2. Lauf ins Gras bis ein Kampf startet.")
print(" 3. Bleib stehen im Kampf-Menü (Attacken-/Bag-Auswahl).")
print(" 4. Drücke F3  -> zeigt neue Pokémon (= Gegner).")
print("")

while true do
  local k = input.get()

  if k.F2 and not prev.F2 then
    print("Scan 1 läuft (~30s, Spiel friert ein)...")
    local t0 = os.clock()
    local n
    snap1, n = scan()
    print(string.format("  → %d Pokémon-Vorkommen (%.1fs)", n, os.clock() - t0))
    print("  Jetzt einen Kampf auslösen, dann F3.")
  end

  if k.F3 and not prev.F3 then
    if not snap1 then
      print("Erst F2 drücken!")
    else
      print("Scan 2 läuft...")
      local t0 = os.clock()
      local snap2, n2 = scan()
      print(string.format("  → %d Pokémon-Vorkommen (%.1fs)", n2, os.clock() - t0))

      local newAddrs = {}
      for a, m in pairs(snap2) do
        if not snap1[a] then newAddrs[#newAddrs+1] = { addr = a, m = m } end
      end
      table.sort(newAddrs, function(a,b) return a.addr < b.addr end)

      print("")
      print(string.format("── NEU AUFGETAUCHT IM KAMPF  %d ──", #newAddrs))
      for _, e in ipairs(newAddrs) do
        print(string.format("  0x%07X  Spezies %3d  PID 0x%08X",
          e.addr, e.m.species, e.m.pid))
      end
      print("")
      print("→ Der Gegner liegt typischerweise zwischen 0x024xxxx und 0x026xxxx.")
      print("→ Spieler-Battle-Kopie ist auch dabei — wähle die unbekannte Spezies.")
    end
  end

  prev = k
  emu.frameadvance()
end
