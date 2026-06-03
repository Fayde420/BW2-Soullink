-- ═══════════════════════════════════════════════════════════
--  Party-HP-Array gezielt suchen (v2 — Anker-basiert)
--  Findet den eindeutigsten Slot (idealerweise cur != max) und
--  prüft ob die anderen Slots an konsistentem Stride drumherum
--  liegen.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

-- DEIN TEAM (cur, max). Falls's nicht stimmt — Werte hier anpassen!
local TEAM = {
  {cur =   0, max =  81},   -- Slot 1: Ferkokel  Lv 24 (tot)
  {cur =  88, max =  88},   -- Slot 2: Lucario   Lv 31
  {cur =  44, max =  92},   -- Slot 3: Jirachi   Lv 25 (verletzt)
  {cur = 165, max = 165},   -- Slot 4: Celebi    Lv 50
  {cur = 100, max = 100},   -- Slot 5: Suicune   Lv 30
  {cur =  34, max =  34},   -- Slot 6: Dusselgurr Lv 11
}

local function pair(c, m) return c + m * 0x10000 end

-- ── Beste Anker-Slot wählen ──
-- Ein Slot mit cur ≠ max ist viel distinktiver (z.B. 44/92).
local anchorIdx = nil
for i, t in ipairs(TEAM) do
  if t.cur ~= t.max and t.cur > 0 then anchorIdx = i; break end
end
if not anchorIdx then
  -- Kein verletzter Slot — nimm den mit höchstem max (am wenigsten häufig)
  local bestMax = 0
  for i, t in ipairs(TEAM) do
    if t.max > bestMax and t.cur > 0 then anchorIdx = i; bestMax = t.max end
  end
end
if not anchorIdx then anchorIdx = 1 end
local anchorPair = pair(TEAM[anchorIdx].cur, TEAM[anchorIdx].max)
print(string.format("Anker = Slot %d  pair = 0x%08X  (%d/%d)",
  anchorIdx, anchorPair, TEAM[anchorIdx].cur, TEAM[anchorIdx].max))

-- ── Phase 1: alle Stellen, an denen der Anker-Pair vorkommt ──
local positions = {}
for a = 0, RAM - 4, 2 do
  if memory.read_u32_le(a) == anchorPair then positions[#positions + 1] = a end
end
print("Phase 1: " .. #positions .. " Vorkommen")

-- ── Phase 2: für jede Anker-Position, prüfe Strides ──
print("Phase 2: prüfe Strides 4..300...")
local hits = {}
for _, p in ipairs(positions) do
  for stride = 4, 300, 2 do
    local ok = true
    for i = 1, #TEAM do
      if i ~= anchorIdx then
        local offset = (i - anchorIdx) * stride
        local target = p + offset
        -- Bounds-Check
        if target < 0 or target + 4 > RAM then ok = false; break end
        -- Skip Slot mit cur=0 (zu generisch)
        if TEAM[i].cur == 0 and TEAM[i].max > 0 then
          -- nur maxHP prüfen (an target+2)
          if memory.read_u16_le(target + 2) ~= TEAM[i].max then
            ok = false; break
          end
        else
          local expected = pair(TEAM[i].cur, TEAM[i].max)
          if memory.read_u32_le(target) ~= expected then
            ok = false; break
          end
        end
      end
    end
    if ok then
      local base = p + (1 - anchorIdx) * stride
      hits[#hits + 1] = { base = base, stride = stride }
    end
  end
end

print(string.format("%d Treffer:", #hits))
for _, h in ipairs(hits) do
  print(string.format("  base=0x%07X  stride=%d", h.base, h.stride))
end

if #hits == 0 then
  print("")
  print("Kein zusammenhängendes Array gefunden.")
  print("→ Die HP werden außerhalb des Kampfs vermutlich nicht als")
  print("  flaches Array gespeichert (BW2-Eigenart).")
  print("→ Empfehlung: Variante A (HP nur im Kampf) nutzen.")
end
print("Fertig.")
