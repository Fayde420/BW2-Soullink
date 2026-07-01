-- ═══════════════════════════════════════════════════════════
--  Live-AutoTracker für Pokémon Schwarz 2 (DE)
--  Liest das Team + Map-ID einmal pro Sekunde und schreibt
--  alles in eine JSON-Datei. Die Python-Brücke schickt sie
--  dann an Firebase.
-- ═══════════════════════════════════════════════════════════

-- Memory-Domain wird erst gesetzt sobald eine ROM geladen ist
-- (sonst crasht NullHawk-Core mit "does not implement memory domains").
-- Siehe ensureDomain() unten – die Hauptschleife wartet bis ROM da ist.
local _domainReady = false
local function ensureDomain()
  if _domainReady then return true end
  local sys = nil
  pcall(function() sys = emu.getsystemid() end)
  if not sys or sys == "NULL" or sys == "" then return false end
  local ok = pcall(memory.usememorydomain, "Main RAM")
  if ok then
    _domainReady = true
    print(string.format("[AutoTracker] ROM erkannt: %s — Main RAM verbunden.", sys))
  end
  return ok
end

local PARTY_BASE   = 0x21E32C
local MON_SIZE     = 220
local PCBOX_BASE   = 0x205924
local BOX_MON_SIZE = 136
local BOX_COUNT    = 24
local BOX_SLOTS    = 30
-- ★ KANONISCHE MAP-ID  (wie IronMon-Tracker es macht) ★
-- parent + child Map-Header (u16). Outdoor: parent == child.
-- Indoor (Gebäude in Stadt): child ist spezifischer.
-- DE-Offset = US - 0x100 (gleich wie Party-Block).
local MAP_HEADER_PARENT = 0x246748   -- US: 0x246848
local MAP_HEADER_CHILD  = 0x246760   -- US: 0x246860
local ENEMY_BASE      = 0x0258774   -- Gegner-Team (Wild + Trainer)
local ENEMY_SLOTS     = 6
-- Live-HP-Leiste der AKTIVEN Gegner-Position (UI-Heap). Folgt KO/Wechsel,
-- d.h. zeigt immer das Mon, das gerade vorne steht — anders als ENEMY_BASE,
-- das die Party in fester Reihenfolge mit eingefrorener HP hält.
local ENEMY_ACTIVE_CUR = 0x02AA37C  -- curHP des aktiven Gegners
local ENEMY_ACTIVE_MAX = 0x02AA380  -- maxHP des aktiven Gegners (= curHP-Addr + 4)
local BADGE_ADDR      = 0x226628    -- Orden-Bitfeld (u8) — identifiziert via find_badges.lua
                                    -- 0 → 1 (1. Orden) → 3 (2. Orden) → 7 (3.) → 15 (4.) → ...
                                    -- Wird als state.badges (Bit N = Orden N+1) gesendet

-- ── Rare Candy Cheat (jeden Frame Slot 1 der Items auf 65535× Sonderbonbon erzwingen) ──
-- Ersatz für AR-Code:
--   B2000024 00000000
--   000194F8 FFFF0032
-- Auf nil setzen um Cheat zu deaktivieren.
local CHEAT_RARE_CANDY_QTY  = 65535       -- Menge (max 65535), nil = aus
local CHEAT_RARE_CANDY_ID   = 50          -- Item-ID 50 = Sonderbonbon (Gen 5)
local CHEAT_SAVE_PTR_ADDR   = 0x000024    -- Hier liegt der Save-Pointer in Main RAM
local CHEAT_ITEM_SLOT_OFF   = 0x0194F8    -- Offset zum 1. Slot der Items-Tasche
-- HP wird jetzt direkt aus dem verschlüsselten Party-Stats-Block
-- gelesen (siehe decryptPartyStats unten). Keine externen Adressen
-- mehr nötig.
-- ── Wohin wird state.json geschrieben? ──
-- WARUM nicht automatisch "neben das Skript": BizHawk meldet den Skript-Pfad
-- oft nur RELATIV (z.B. "./live_team.lua"), daher kann das Skript seinen echten
-- Ordner nicht zuverlässig selbst ermitteln — die Datei landete sonst im
-- Arbeitsverzeichnis von EmuHawk.
-- Lösung (universell & scp-sicher): Ordner aus der Umgebungsvariable
-- AUTOTRACKER_DIR. Pro Rechner EINMAL in der CMD setzen, dann BizHawk neu
-- starten:   setx AUTOTRACKER_DIR "C:\Pfad\zum\autotracker"
-- Reihenfolge: Env-Variable  >  fester Fallback unten  >  neben dem Skript.
local OUTPUT_DIR = os.getenv("AUTOTRACKER_DIR")
                or "C:/trash/PokemonWebsite/autotracker"   -- Fallback, falls keine Env-Var

local function _scriptDir()
  local src = debug.getinfo(1, 'S').source
  if src:sub(1,1) == '@' then src = src:sub(2) end
  local dir = src:match("(.+)[/\\][^/\\]+$")
  return dir or "."
end
local OUTPUT_FILE = (OUTPUT_DIR or _scriptDir()) .. "/state.json"
print("[AutoTracker] state.json → " .. OUTPUT_FILE)

local A_POS = {[0]=0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3}
local B_POS = {[0]=1,1,2,3,2,3, 0,0,0,0,0,0, 2,3,1,1,3,2, 2,3,1,1,3,2}
local C_POS = {[0]=2,3,1,1,3,2, 2,3,1,1,3,2, 0,0,0,0,0,0, 3,2,3,2,1,1}

-- Wachstumsgruppen-Codes: mf=MedFast, ms=MedSlow, s=Slow,
-- f=Fast, er=Erratic, fl=Fluctuating. Default = mf.
local GROWTH = setmetatable({
  -- ── Gen 5 Starter (alle Medium Slow) ──
  [495]="ms",[496]="ms",[497]="ms",   -- Serpifeu-Linie
  [498]="ms",[499]="ms",[500]="ms",   -- Floink-Linie
  [501]="ms",[502]="ms",[503]="ms",   -- Ottaro-Linie
  -- ── Andere Gen-5 Medium-Slow-Linien ──
  [506]="ms",[507]="ms",[508]="ms",   -- Yorkleff / Terribark / Bissbark
  [519]="ms",[520]="ms",[521]="ms",   -- Piccolente / Swaroness
  [524]="ms",[525]="ms",[526]="ms",   -- Kiesling / Sedimantur / Brockoloss
  [532]="ms",[533]="ms",[534]="ms",   -- Praktibalk / Strepoli / Meistagrif
  [535]="ms",[536]="ms",[537]="ms",   -- Schallquap / Mebrana / Branawarz
  [540]="ms",[541]="ms",[542]="ms",   -- Strawickl / Folikon / Matrifol
  [543]="ms",[544]="ms",[545]="ms",   -- Toxiped / Rollum / Cerapendra
  [570]="ms",[571]="ms",              -- Zorua / Zoroark
  [574]="ms",[575]="ms",[576]="ms",   -- Mollimorba / Hypnomorba / Morbitesse
  [577]="ms",[578]="ms",[579]="ms",   -- Monozyto / Mitodos / Zytomega
  [599]="ms",[600]="ms",[601]="ms",   -- Klikk / Kliklak / Klikdiklak
  [607]="ms",[608]="ms",[609]="ms",   -- Lichtel / Laternecto / Skelabra
  [619]="ms",[620]="ms",              -- Lin-Fu / Wie-Shu
  [624]="ms",[625]="ms",              -- Gladiantri / Caesurio
  -- ── Gen 5 Slow-Linien ──
  [551]="s",[552]="s",[553]="s",      -- Rokkaiman / Rabigator
  [554]="s",[555]="s",                -- Flampion / Flampivian
  [582]="s",[583]="s",[584]="s",      -- Gelatini-Linie
  [602]="s",[603]="s",[604]="s",      -- Zapplardin-Linie
  [610]="s",[611]="s",[612]="s",      -- Milza / Sharfax / Maxax
  [627]="s",[628]="s",                -- Geronimatz / Washakwil
  [629]="s",[630]="s",                -- Skallyk / Grypheldis
  [633]="s",[634]="s",[635]="s",      -- Kapuno / Duodino / Trikephalo
  [636]="s",[637]="s",                -- Ignivor / Ramoth
  -- ── Gen-5-Legendäre & Mythen (alle Slow) ──
  [494]="s",                          -- Victini
  [638]="s",[639]="s",[640]="s",      -- Kobalium / Terrakium / Viridium
  [641]="s",[642]="s",                -- Boreos / Voltolos
  [643]="s",[644]="s",                -- Reshiram / Zekrom
  [645]="s",[646]="s",                -- Demeteros / Kyurem
  [647]="s",[648]="s",[649]="s",      -- Keldeo / Meloetta / Genesect
  -- ── Gen 5 Fast-Linien ──
  [517]="f",[518]="f",                -- Somniam / Somnivora
  [531]="f",                          -- Ohrdoch
  [572]="f",[573]="f",                -- Picochilla / Chillabell
  [594]="f",                          -- Mamolida
  -- ── Legendäre & Mythen aus älteren Gens (alle Slow) ──
  [144]="s",[145]="s",[146]="s",      -- Arktos / Zapdos / Lavados
  [150]="s",[151]="s",                -- Mewtu / Mew
  [243]="s",[244]="s",[245]="s",      -- Raikou / Entei / Suicune
  [249]="s",[250]="s",                -- Lugia / Ho-Oh
  [377]="s",[378]="s",[379]="s",      -- Regirock / Regice / Registeel
  [380]="s",[381]="s",                -- Latias / Latios
  [382]="s",[383]="s",[384]="s",      -- Kyogre / Groudon / Rayquaza
  [385]="s",[386]="s",                -- Jirachi / Deoxys
  [483]="s",[484]="s",[485]="s",      -- Dialga / Palkia / Heatran
  [486]="s",[487]="s",[488]="s",      -- Regigigas / Giratina / Cresselia
  [489]="s",[490]="s",[491]="s",      -- Phione / Manaphy / Darkrai
  [492]="s",[493]="s",                -- Shaymin / Arceus
  -- ── Mythen mit Medium Slow ──
  [251]="ms",                         -- Celebi
  [480]="ms",[481]="ms",[482]="ms",   -- Selfe / Vesprit / Tobutz
  -- ── Pseudo-Legendäre (alle Slow) ──
  [147]="s",[148]="s",[149]="s",      -- Dratini-Linie
  [246]="s",[247]="s",[248]="s",      -- Larvitar-Linie
  [371]="s",[372]="s",[373]="s",      -- Kindwurm / Draschel / Brutalanda
  [374]="s",[375]="s",[376]="s",      -- Tanhel / Metang / Metagross
  [443]="s",[444]="s",[445]="s",      -- Kaumalat / Knarksel / Knakrack
  -- ── Lucario-Linie & andere wichtige Pokémon ──
  [447]="ms",[448]="ms",              -- Riolu / Lucario
}, { __index = function() return "mf" end })

local function expForLevel(rate, L)
  if L <= 1 then return 0 end
  if rate == "mf" then return L*L*L end
  if rate == "ms" then return math.max(0, math.floor((6*L*L*L)/5 - 15*L*L + 100*L - 140)) end
  if rate == "f"  then return math.floor((4*L*L*L)/5) end
  if rate == "s"  then return math.floor((5*L*L*L)/4) end
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

-- Generischer Decoder für eine beliebige Pokémon-Adresse
local function decryptAt(base)
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
  local bA, bB, bC = A_POS[shift], B_POS[shift], C_POS[shift]

  local species = words[bA*16]
  if species < 1 or species > 700 then return nil end
  local item    = words[bA*16 + 1]
  local otTid   = words[bA*16 + 2]   -- OT Trainer-ID
  local otSid   = words[bA*16 + 3]   -- OT Secret-ID
  local exp     = words[bA*16 + 4] + words[bA*16 + 5] * 0x10000
  local ability = (words[bA*16 + 6] >> 8) & 0xFF

  local moves = {
    words[bB*16], words[bB*16 + 1],
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
    pid = pid,
    species = species, item = item, exp = exp, ability = ability,
    otTid = otTid, otSid = otSid,
    moves = moves, nick = nick, level = levelFromExp(species, exp),
  }
end

-- Entschlüsselt den Party-Stats-Block (+0x88..+0xDB, 84 Bytes / 42 u16-Wörter).
-- Verwendet PID als Initial-Seed (NICHT Checksum) und dieselbe LCRNG.
-- Liefert Level + curHP + maxHP zurück.
local function decryptPartyStats(base, pid)
  local seed = pid
  local words = {}
  for i = 0, 41 do
    seed = (mult32(seed, 0x41C64E6D) + 0x6073) % 0x100000000
    local key = math.floor(seed / 0x10000) % 0x10000
    words[i] = memory.read_u16_le(base + 0x88 + i * 2) ~ key
  end
  return {
    statusCond = words[0] + words[1] * 0x10000,
    level      = words[2] & 0xFF,
    curHP      = words[3],
    maxHP      = words[4],
  }
end

-- Vollständiger Decode: Hauptblock + Party-Stats (Level/curHP/maxHP/Status).
-- Funktioniert für Party- UND Gegner-Strukturen (gleiches 220-Byte-Layout).
local function decryptFull(base)
  local m = decryptAt(base)
  if not m then return nil end
  local ps = decryptPartyStats(base, m.pid)
  -- Validieren: nur wenn Level + maxHP plausibel sind, ersetzen
  if ps.level >= 1 and ps.level <= 100 and ps.maxHP >= 1 and ps.maxHP <= 999 then
    m.level  = ps.level         -- echtes Level statt EXP-Schätzung
    m.curHP  = ps.curHP
    m.maxHP  = ps.maxHP
    m.status = ps.statusCond
  end
  return m
end

local function decryptMon(slot)
  return decryptFull(PARTY_BASE + slot * MON_SIZE)
end

-- PC-Box komplett auslesen (24 × 30 = 720 Slots, kleinster Aufwand:
-- erst PID prüfen, nur bei nichtleer entschlüsseln)
local function readPcBox()
  local box = {}
  for b = 0, BOX_COUNT - 1 do
    for s = 0, BOX_SLOTS - 1 do
      local addr = PCBOX_BASE + (b * BOX_SLOTS + s) * BOX_MON_SIZE
      if memory.read_u32_le(addr) ~= 0 then
        local m = decryptAt(addr)
        if m then
          m.box  = b + 1
          m.slot = s + 1
          box[#box + 1] = m
        end
      end
    end
  end
  return box
end

-- ── Minimaler JSON-Serializer ──
local function jsonEscape(s)
  return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

local function toJson(v)
  local t = type(v)
  if t == "number"  then return tostring(v) end
  if t == "string"  then return '"' .. jsonEscape(v) .. '"' end
  if t == "boolean" then return v and "true" or "false" end
  if t == "nil"     then return "null" end
  if t == "table" then
    if #v > 0 or next(v) == nil then
      local parts = {}
      for _, x in ipairs(v) do parts[#parts + 1] = toJson(x) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, x in pairs(v) do
        parts[#parts + 1] = '"' .. tostring(k) .. '":' .. toJson(x)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

local lastTeamCount   = 0
local lastHPSrc       = nil
local lastBoxCount    = 0
local lastEnemyCount  = 0
local lastBattleType  = nil
local lastWriteOk     = false

local function readEnemyTeam()
  local t = {}
  for slot = 0, ENEMY_SLOTS - 1 do
    local m = decryptFull(ENEMY_BASE + slot * MON_SIZE)
    if m then
      m.slot = slot + 1
      t[#t + 1] = m
    end
  end
  return t
end

-- Aktiven Gegner bestimmen: Die UI-HP-Leiste an ENEMY_ACTIVE_* hält die
-- LIVE-HP der aktuell vorne stehenden Position (folgt KO/Wechsel). Wir matchen
-- ihre maxHP gegen die Party-Slots (maxHP ist im Kampf konstant) und liefern
-- den passenden Slot mit live überschriebener HP zurück.
-- Kein gültiger Leisten-Wert / kein Match -> nil (z.B. ausserhalb Kampf).
local function readActiveEnemy(team)
  local cur = memory.read_u16_le(ENEMY_ACTIVE_CUR)
  local mx  = memory.read_u16_le(ENEMY_ACTIVE_MAX)
  if mx < 1 or mx > 999 or cur > mx then return nil end
  for _, m in ipairs(team) do
    if m.maxHP == mx then
      local a = {}
      for k, v in pairs(m) do a[k] = v end
      a.curHP  = cur
      a.maxHP  = mx
      a.active = true
      return a
    end
  end
  return nil
end

-- (Veraltete HP-Kandidaten-Logik entfernt — HP kommt jetzt aus
-- decryptPartyStats direkt im decryptMon.)

-- ── Caches (FrameCounter-Muster, vgl. NDS-Ironmon-Tracker) ──
-- Teure RAM-Reads/Decrypts laufen NICHT jeden Frame, sondern gedrosselt.
-- Der Draw-Pfad und writeState nutzen NUR diese gecachten Werte — so bleibt
-- die Pro-Frame-Last minimal und der Emulator-Speed-Up wird nicht limitiert.
local cTeam        = {}
local cBox         = {}
local cEnemyTeam   = {}
local cEnemy       = nil
local cBattleType  = nil
local cHP          = {}     -- slot(0..2) -> Mon-Tabelle fürs HP-HUD

-- Party (6 Slots) lesen + HP der ersten 3 fürs HUD cachen
local function refreshTeam()
  local team, hp = {}, {}
  for slot = 0, 5 do
    local m = decryptMon(slot)
    if m then
      team[#team + 1] = m
      if slot <= 2 and m.curHP then hp[slot] = m end
    end
  end
  cTeam, cHP = team, hp
  lastTeamCount = #team
end

-- Gegner-Team lesen + Kampf-Typ ableiten
local function refreshEnemy()
  -- Die Live-HP-Leiste existiert nur während eines Kampfes. Ist sie ungültig,
  -- ist gerade kein Kampf -> Gegneranzeige leeren (löst "bleibt nach Kampfende
  -- stehen"). Das ist robuster als ENEMY_BASE, das nach dem Kampf veraltet
  -- weiterlebt, bis der Battle-Heap überschrieben wird.
  local cur = memory.read_u16_le(ENEMY_ACTIVE_CUR)
  local mx  = memory.read_u16_le(ENEMY_ACTIVE_MAX)
  if mx < 1 or mx > 999 or cur > mx then
    cEnemyTeam, cEnemy = {}, nil
    cBattleType, lastBattleType = nil, nil
    lastEnemyCount = 0
    return
  end

  local et = readEnemyTeam()
  cEnemyTeam = et
  -- Aktiver Gegner folgt der vorne stehenden Position (KO/Wechsel).
  -- Fallback = Slot 1, falls das maxHP-Matching (noch) nicht greift.
  local active = readActiveEnemy(et)
  cEnemy     = active or et[1]
  local bt = (#et >= 2) and "trainer" or "wild"
  cBattleType    = bt
  lastEnemyCount = #et
  lastBattleType = bt
end

-- PC-Box (720 Slots) — teuerster Scan, läuft deshalb am seltensten
local function refreshBox()
  cBox = readPcBox()
  lastBoxCount = #cBox
end

local function writeState()
  -- Baut den State NUR aus den gecachten Werten (kein Decrypt im Schreibpfad).
  local childMap  = memory.read_u16_le(MAP_HEADER_CHILD)
  local parentMap = memory.read_u16_le(MAP_HEADER_PARENT)
  local state = {
    -- Kanonische Map-ID: child bevorzugt (genauer), parent als Fallback
    mapHeader       = (childMap > 0) and childMap or parentMap,
    mapHeaderChild  = childMap,
    mapHeaderParent = parentMap,
    team        = cTeam,
    box         = cBox,
    enemy       = cEnemy,
    enemyTeam   = cEnemyTeam,
    battleType  = cBattleType,
    badges      = BADGE_ADDR and memory.read_u8(BADGE_ADDR) or nil,
    teamCount   = #cTeam,
    boxCount    = #cBox,
    updatedAt   = os.time() * 1000,
  }
  local f = io.open(OUTPUT_FILE, "w")
  if f then
    f:write(toJson(state))
    f:close()
    lastWriteOk = true
  else
    lastWriteOk = false
  end
end

-- ── Cheat: Sonderbonbon-Menge auf festen Wert erzwingen ──
local function applyRareCandyCheat()
  if not CHEAT_RARE_CANDY_QTY then return end
  local base = memory.read_u32_le(CHEAT_SAVE_PTR_ADDR)
  if not base or base < 0x02000000 or base >= 0x02400000 then return end
  local addr = (base - 0x02000000) + CHEAT_ITEM_SLOT_OFF
  if addr < 0 or addr >= 0x400000 then return end
  local packed = (CHEAT_RARE_CANDY_QTY * 0x10000) + CHEAT_RARE_CANDY_ID
  memory.write_u32_le(addr, packed)
end

-- ── Hauptschleife ──
local frame = 0
while true do
  if not ensureDomain() then
    -- Noch keine ROM geladen → warten, keine Memory-Reads versuchen
    gui.text(8, 8, "AutoTracker: warte auf ROM-Load...")
    emu.frameadvance()
  else
    frame = frame + 1
    applyRareCandyCheat()

    -- Teure Reads gedrosselt (FrameCounter-Muster), Phasen versetzt damit
    -- nicht mehrere schwere Reads im selben Frame zusammenfallen:
    if frame % 20  ==  2 then refreshTeam()  end   -- Party + HP-HUD  (~3×/s)
    if frame % 20  == 12 then refreshEnemy() end   -- Gegner-Team     (~3×/s)
    if frame % 300 ==  5 then refreshBox()   end   -- PC-Box (teuer)  (~1/5s)
    if frame % 60  == 20 then writeState()   end   -- Datei schreiben (~1/s)

    -- Draw-Pfad: nur gecachte Werte (KEIN Decrypt hier)
    gui.text(8, 8,  "AutoTracker " .. (lastWriteOk and "AKTIV" or "(...)"))
    gui.text(8, 24, string.format("Map-ID: %d (parent %d)",
      memory.read_u16_le(MAP_HEADER_CHILD), memory.read_u16_le(MAP_HEADER_PARENT)))
    gui.text(8, 40, string.format("Team:   %d", lastTeamCount))
    gui.text(8, 56, string.format("Box:    %d", lastBoxCount))
    if lastBattleType then
      gui.text(8, 72, string.format("Kampf:  %s (%d)", lastBattleType, lastEnemyCount))
    else
      gui.text(8, 72, "Kampf:  -")
    end
    -- HP der ersten 3 Slots aus Cache
    for slot = 0, 2 do
      local m = cHP[slot]
      if m then
        gui.text(8, 92 + slot * 14, string.format(
          "S%d: Lv%2d  %3d/%3d", slot + 1, m.level, m.curHP, m.maxHP))
      end
    end

    emu.frameadvance()
  end
end
