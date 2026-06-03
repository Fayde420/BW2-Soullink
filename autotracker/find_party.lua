-- ═══════════════════════════════════════════════════════════
--  v8  ·  Variable-Stride-Suche nach Live-Stats
--  Sucht das HP-Triplet {24,14,16} mit beliebigem Stride
--  (1 bis 500 Bytes) — findet so kompakte Stat-Arrays.
-- ═══════════════════════════════════════════════════════════

memory.usememorydomain("Main RAM")
local RAM = 0x400000

print("Phase 1: alle u16=24 Positionen sammeln...")
local p24 = {}
for a = 0, RAM - 2, 2 do
  if memory.read_u16_le(a) == 24 then p24[#p24 + 1] = a end
end
print(string.format("  %d Vorkommen", #p24))

print("")
print("Phase 2: variable Stride-Suche {24,14,16}...")
local hits = {}
for _, p in ipairs(p24) do
  for stride = 1, 500 do
    if p + 2 * stride + 1 < RAM then
      if memory.read_u16_le(p + stride) == 14
         and memory.read_u16_le(p + 2 * stride) == 16 then
        hits[#hits + 1] = { base = p, stride = stride }
      end
    end
  end
end
print(string.format("  %d Treffer:", #hits))
local shown = 0
for _, h in ipairs(hits) do
  print(string.format("  base=0x%07X  stride=%d", h.base, h.stride))
  shown = shown + 1
  if shown >= 60 then print("  ... gekürzt"); break end
end

-- Falls Treffer: dieselben Strides nach Level-Triplet {6,2,3} prüfen
if #hits > 0 then
  print("")
  print("Phase 3: Cross-Check mit Level {6,2,3}...")
  -- Suche Level-Triplet mit gleichen Strides wie HP-Treffer
  local strides = {}
  for _, h in ipairs(hits) do strides[h.stride] = true end
  for s, _ in pairs(strides) do
    for a = 0, RAM - 2 * s - 1 do
      if memory.read_u8(a) == 6
         and memory.read_u8(a + s) == 2
         and memory.read_u8(a + 2 * s) == 3 then
        print(string.format("  Level @ 0x%07X  (stride=%d)", a, s))
      end
    end
  end
end
print("=== Fertig ===")
