// Gemeinsamer Kern aller drei Tracker-Seiten
// Identisch in Trio, Duo und Solo — hier einmal gepflegt.
// Wird als eigenes <script> VOR dem Seiten-Skript geladen. Enthaelt nur
// Funktionen; die Daten (data, db, PLAYERS, ...) liegen weiter in der Seite
// und werden erst beim Aufruf aufgeloest.


function createFolder() {
  const name = prompt('Name des Ordners:');
  if (name === null) return;
  const t = name.trim();
  if (!t) return;
  const id = 'f_' + Date.now();
  foldersRef.child(id).set({ name: t, created: Date.now() }).catch(()=>{});
  _selectedFolder = id;
}

function selectFolder(id) {
  _selectedFolder = id;
  renderFolderBar(); renderFolderSettings(); renderRunList();
}

function renameFolder(id) {
  const f = _folders[id]; if (!f) return;
  const name = prompt('Neuer Ordnername:', f.name || '');
  if (name === null) return;
  const t = name.trim(); if (!t) return;
  foldersRef.child(id).update({ name: t }).catch(()=>{});
}

function deleteFolder(id) {
  const f = _folders[id]; if (!f) return;
  const inside = Object.entries(_runsMeta).filter(([, m]) => m && m.folder === id);
  if (!confirm(`Ordner "${f.name}" löschen?${inside.length ? `\n\nDie ${inside.length} Run(s) darin bleiben erhalten und liegen danach wieder ohne Ordner.` : ''}`)) return;
  const upd = {};
  inside.forEach(([rid]) => { upd[`${rid}/folder`] = null; });
  if (Object.keys(upd).length) runsRef.update(upd).catch(()=>{});
  foldersRef.child(id).remove().catch(()=>{});
  if (_selectedFolder === id) _selectedFolder = null;
}

function onRunDragStart(ev, runId) {
  _folderDragState.runId = runId;
  try { ev.dataTransfer.setData('text/plain', runId); } catch (e) {}
  ev.dataTransfer.effectAllowed = 'move';
}

function onFolderDragOver(ev, el) {
  ev.preventDefault();
  ev.dataTransfer.dropEffect = 'move';
  if (el) { el.style.borderColor = 'var(--accent)'; el.style.background = 'rgba(79,195,247,0.15)'; }
}

function onFolderDragLeave(ev, el) {
  if (el) { el.style.borderColor = ''; el.style.background = ''; }
  renderFolderBar();
}

function onFolderDrop(ev, folderId, el) {
  ev.preventDefault();
  let runId = '';
  try { runId = ev.dataTransfer.getData('text/plain'); } catch (e) {}
  runId = runId || _folderDragState.runId;
  _folderDragState.runId = null;
  if (el) { el.style.borderColor = ''; el.style.background = ''; }
  if (!runId || !_runsMeta[runId]) { renderFolderBar(); return; }
  runsRef.child(runId).update({ folder: folderId }).catch(()=>{});
}

function renderFolderBar() {
  const bar = document.getElementById('folder-bar');
  if (!bar) return;
  const countIn = id => id === '__all__'
    ? Object.keys(_runsMeta).length
    : Object.values(_runsMeta).filter(m => m && (m.folder || null) === id).length;
  // id: '__all__' (alle) | null (ohne Ordner) | Ordner-ID. "Alle" ist kein Drop-Ziel.
  const chip = (id, label, icon) => {
    const active = _selectedFolder === id;
    const isDrop = id !== '__all__';
    const arg = id === '__all__' ? `'__all__'` : (id === null ? 'null' : `'${id}'`);
    return `
      <div onclick="selectFolder(${arg})"
        ${isDrop ? `ondragover="onFolderDragOver(event,this)" ondragleave="onFolderDragLeave(event,this)" ondrop="onFolderDrop(event,${id === null ? 'null' : `'${id}'`},this)"` : ''}
        title="${isDrop ? 'Klicken zum Filtern · Run hierher ziehen' : 'Alle Runs zeigen'}"
        style="display:flex;align-items:center;gap:6px;white-space:nowrap;cursor:pointer;user-select:none;
               border:1px solid ${active ? 'var(--accent)' : 'var(--border)'};
               background:${active ? 'rgba(79,195,247,0.12)' : 'var(--surface2)'};
               color:${active ? 'var(--accent)' : 'var(--text)'};
               padding:5px 10px;border-radius:999px;font-size:12px;transition:border-color .15s,background .15s;">
        <span>${icon}</span><span>${label}</span>
        <span style="color:var(--muted);font-size:10px;">${countIn(id)}</span>
      </div>`;
  };
  const folderChips = Object.entries(_folders)
    .sort((a,b) => (a[1].created||0)-(b[1].created||0))
    .map(([id, f]) => chip(id, f.name || 'Ordner', '📁')).join('');
  bar.innerHTML =
    chip('__all__', 'Alle', '🗂') +
    chip(null, 'Ohne Ordner', '📄') +
    folderChips +
    `<div onclick="createFolder()" title="Neuen Ordner anlegen"
       style="white-space:nowrap;cursor:pointer;user-select:none;border:1px dashed var(--border);
              color:var(--muted);padding:5px 10px;border-radius:999px;font-size:12px;">+ Ordner</div>`;
}

function isUserInteracting() {
  const a = document.activeElement;
  if (!a || a === document.body) return false;
  const t = a.tagName;
  return t === 'INPUT' || t === 'SELECT' || t === 'TEXTAREA';
}

function serverNow() { return Date.now() + _serverTimeOffset; }

function liveAgeSeconds(at) {
  if (!at) return null;
  if (at.serverAt) return Math.max(0, Math.round((serverNow() - at.serverAt) / 1000));
  // Fallback fuer alte Bridge-Staende ohne serverAt (PC-Uhr vs. Browser-Uhr).
  if (at.updatedAt) return Math.max(0, Math.round((Date.now() - at.updatedAt) / 1000));
  return null;
}

function showMapMappings() {
  document.getElementById('mapmap-modal').style.display = 'flex';
  renderMapMappingsList();
}

function hideMapMappings() {
  document.getElementById('mapmap-modal').style.display = 'none';
}

function deleteMappingFromModal(key) {
  deleteMapping(key);
  renderMapMappingsList();
}

// ── Welche vier Attacken hat ein Pokémon auf diesem Level wirklich? ──
// Das Spiel geht das Lernset von unten nach oben durch und verdrängt die
// älteste Attacke, sobald ein fünfter Platz gebraucht wird. Eine bereits
// bekannte Attacke wird dabei übersprungen, nicht erneut gelernt.
//
// Unsicher wird es, wenn auf EINEM Level mehr als vier neue Attacken liegen:
// dann fällt ein Teil davon weg, und welcher, entscheidet allein die
// Reihenfolge innerhalb dieses Levels. Die stammt aus der Nachschlage-Quelle
// und ist dort nicht zugesichert — solche Level melden wir als unsicher,
// statt eine Auswahl vorzutäuschen.
// (Liegen vier oder weniger auf einem Level, passen sie immer alle hinein —
//  verdrängt werden dann nur ältere Attacken, die Auswahl bleibt eindeutig.)
function simulateMoveset(moves, level) {
  const byLevel = {};
  (moves || []).filter(m => m && m.level <= level)
               .forEach(m => { (byLevel[m.level] = byLevel[m.level] || []).push(m); });

  const held = [];                 // Namen der gehaltenen Attacken, in Lernreihenfolge
  const uncertainLevels = new Set();

  Object.keys(byLevel).map(Number).sort((a, b) => a - b).forEach(lvl => {
    const group = byLevel[lvl];
    const fresh = [];              // auf diesem Level wirklich neu Gelerntes
    group.forEach(m => {
      if (!held.includes(m.name) && !fresh.includes(m.name)) fresh.push(m.name);
    });
    if (fresh.length > 4) uncertainLevels.add(lvl);
    fresh.forEach(name => {
      held.push(name);
      if (held.length > 4) held.shift();
    });
  });
  return { held, heldSet: new Set(held), uncertainLevels };
}

// ── Starter dieses Runs ──
// Die drei zur Wahl stehenden Starter stammen aus der Randomizer-Logdatei und
// werden vom Starter-Programm hochgeladen — als NAMEN, nicht als Nummern.
// Aufgeloest wird hier, wo die Namenstabelle ohnehin liegt; so gibt es keine
// zweite Liste, die auseinanderlaufen koennte.
//
// `sets` ist eine Liste von { label, names }. Sind alle Eintraege gleich
// (alle spielen dieselbe ROM), wird nur eine Reihe gezeigt.
function renderStarterBox(boxId, sets, nameToId, spriteUrlFn, onClick) {
  const box = typeof document !== 'undefined' && document.getElementById(boxId);
  if (!box) return;
  const valid = (sets || []).filter(s => Array.isArray(s.names) && s.names.length);
  if (!valid.length) { box.style.display = 'none'; box.innerHTML = ''; return; }

  // Alle gleich? Dann reicht eine Reihe ohne Spieler-Beschriftung.
  const key = s => s.names.join('|');
  const allSame = valid.every(s => key(s) === key(valid[0]));
  const rows = allSame ? [{ label: null, names: valid[0].names }] : valid;

  const chip = (name, i) => {
    const id = nameToId[name];
    const img = id
      ? `<img src="${spriteUrlFn(id)}" alt="" style="width:56px;height:56px;image-rendering:pixelated;">`
      : `<span style="font-size:26px;color:var(--muted);">?</span>`;
    const click = id ? ` onclick="${onClick}(${id},'${String(name).replace(/'/g, "\\'")}')"` : '';
    return `
      <div${click} title="${id ? name + ' — anklicken für Details' : name + ' (unbekannter Name)'}"
        style="display:flex;flex-direction:column;align-items:center;gap:2px;min-width:74px;padding:8px 6px;
               background:var(--surface2);border:1px solid var(--border);border-radius:8px;
               ${id ? 'cursor:pointer;' : ''}transition:border-color .15s,transform .12s;"
        ${id ? `onmouseover="this.style.borderColor='var(--accent)';this.style.transform='translateY(-2px)';"
               onmouseout="this.style.borderColor='var(--border)';this.style.transform='';"` : ''}>
        <div style="font-family:'Press Start 2P',monospace;font-size:8px;color:var(--muted);">${i + 1}</div>
        ${img}
        <div style="font-size:11px;font-weight:700;text-align:center;">${name}</div>
      </div>`;
  };

  box.innerHTML = `
    <div style="background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:12px 14px;">
      <div style="font-family:'Press Start 2P',monospace;font-size:9px;color:var(--muted);letter-spacing:1px;margin-bottom:10px;">
        STARTER DIESES RUNS
      </div>
      ${rows.map(r => `
        ${r.label ? `<div style="font-size:11px;color:var(--muted);margin:6px 0 4px;">${r.label}</div>` : ''}
        <div style="display:flex;gap:8px;justify-content:center;flex-wrap:wrap;">
          ${r.names.map(chip).join('')}
        </div>`).join('')}
    </div>`;
  box.style.display = 'block';
}
