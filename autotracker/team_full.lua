-- ═══════════════════════════════════════════════════════════
--  Test: vollständige Pokémon-Daten + Level aus EXP berechnet.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")

local PARTY_BASE = 0x21E32C
local MON_SIZE   = 220

local A_POS = {[0]=0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3}
local B_POS = {[0]=1,1,2,3,2,3, 0,0,0,0,0,0, 2,3,1,1,3,2, 2,3,1,1,3,2}
local C_POS = {[0]=2,3,1,1,3,2, 2,3,1,1,3,2, 0,0,0,0,0,0, 3,2,3,2,1,1}

-- ── Wachstumsgruppen (default = Medium Fast) ──
local GROWTH = setmetatable({
  -- Gen-5-Starter (alle Medium Slow)
  [495]="ms",[496]="ms",[497]="ms",   -- Serpifeu-Linie
  [498]="ms",[499]="ms",[500]="ms",   -- Floink-Linie
  [501]="ms",[502]="ms",[503]="ms",   -- Ottaro-Linie
  -- Pseudo-Legendäre & Knakrack-Linie (Slow)
  [443]="s",[444]="s",[445]="s",      -- Kaumalat / Knakrack
  [610]="s",[611]="s",[612]="s",      -- Milza / Sharfax / Maxax
  -- Bekannte Erratic-Beispiele
  [371]="er",[372]="er",[373]="er",   -- Kindwurm / Brutalanda
}, { __index = function() return "mf" end })

-- ── EXP-Schwellen je Wachstumsgruppe ──
local function expForLevel(rate, L)
  if L <= 1 then return 0 end
  if rate == "mf" then return L*L*L end
  if rate == "ms" then
    return math.max(0, math.floor((6*L*L*L)/5 - 15*L*L + 100*L - 140))
  end
  if rate == "f"  then return math.floor((4*L*L*L)/5) end
  if rate == "s"  then return math.floor((5*L*L*L)/4) end
  if rate == "er" then
    if L <= 50 then return math.floor((L*L*L * (100 - L)) / 50)
    elseif L <= 68 then return math.floor((L*L*L * (150 - L)) / 100)
    elseif L <= 98 then return math.floor((L*L*L * math.floor((1911 - 10*L)/3)) / 500)
    else return math.floor((L*L*L * (160 - L)) / 100) end
  end
  if rate == "fl" then
    if L <= 15 then return math.floor((L*L*L * (math.floor((L+1)/3) + 24)) / 50)
    elseif L <= 36 then return math.floor((L*L*L * (L + 14)) / 50)
    else return math.floor((L*L*L * (math.floor(L/2) + 32)) / 50) end
  end
  return L*L*L
end

local function levelFromExp(species, exp)
  local rate = GROWTH[species]
  for L = 1, 100 do
    if expForLevel(rate, L + 1) > exp then return L end
  end
  return 100
end

local function mult32(a, b)
  local al, bl = a % 0x10000, b % 0x10000
  local ah = math.floor(a / 0x10000) % 0x10000
  local bh = math.floor(b / 0x10000) % 0x10000
  return (((ah * bl + al * bh) % 0x10000) * 0x10000 + al * bl) % 0x100000000
end

local function decryptMon(slot)
  local base = PARTY_BASE + slot * MON_SIZE
  local pid  = memory.read_u32_le(base)
  if pid == 0 then return nil end
  local checksum = memory.read_u16_le(base + 6)
  local seed, sum = checksum, 0
  local words = {}
  for i = 0, 63 do
    seed = (mult32(seed, 0x41C64E6D) + 0x6073) % 0x100000000
    local key = math.floor(seed / 0x10000) % 0x10000
    words[i]  = memory.read_u16_le(base + 8 + i * 2) ~ key
    sum       = (sum + words[i]) % 0x10000
  end
  if sum ~= checksum then return nil end

  local shift = ((pid & 0x3E000) >> 13) % 24
  local bA, bB, bC = A_POS[shift], B_POS[shift], C_POS[shift]

  local species = words[bA*16 + 0]
  local item    = words[bA*16 + 1]
  local exp     = words[bA*16 + 4] + words[bA*16 + 5] * 0x10000
  local ability = (words[bA*16 + 6] >> 8) & 0xFF

  local moves = {
    words[bB*16 + 0], words[bB*16 + 1],
    words[bB*16 + 2], words[bB*16 + 3],
  }

  local nick = ""
  for i = 0, 10 do
    local ch = words[bC*16 + i]
    if ch == 0xFFFF or ch == 0 then break end
    if ch >= 32 and ch < 128 then nick = nick .. string.char(ch)
    else nick = nick .. "?" end
  end

  return {
    species = species, item = item, exp = exp,
    ability = ability, moves = moves, nick = nick,
    level = levelFromExp(species, exp),
    growth = GROWTH[species],
  }
end

print("══ Team mit berechnetem Level ══")
for slot = 0, 5 do
  local m = decryptMon(slot)
  if m then
    print(string.format("\nSlot %d:  %-12s  ID %3d  Lv %3d  (EXP %d, %s)",
      slot + 1, "'" .. m.nick .. "'", m.species, m.level, m.exp, m.growth))
    print(string.format("  Fähigkeit-ID %3d   Item-ID %3d   Attacken: %d, %d, %d, %d",
      m.ability, m.item,
      m.moves[1], m.moves[2], m.moves[3], m.moves[4]))
  end
end
print("\n══ Fertig ══")
