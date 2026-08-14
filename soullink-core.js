// Gemeinsamer Kern der Soullink-Seiten (Trio + Duo)
// Identisch in beiden — Solo hat ein anderes Datenmodell und laedt das hier nicht.
// Wird als eigenes <script> VOR dem Seiten-Skript geladen. Enthaelt nur
// Funktionen; die Daten (data, db, PLAYERS, ...) liegen weiter in der Seite
// und werden erst beim Aufruf aufgeloest.


function checkPassword() {
  const input = document.getElementById('pw-input').value;
  if (input === CORRECT_PW) {
    localStorage.setItem('soullink_pw', CORRECT_PW);
    document.getElementById('password-screen').style.display = 'none';
  } else {
    document.getElementById('pw-error').style.display = 'block';
    document.getElementById('pw-input').value = '';
    document.getElementById('pw-input').focus();
  }
}

function getDataRef() { return db.ref(currentRunId); }

function createRun() {
  const name = document.getElementById('new-run-name').value.trim();
  if (!name) return;
  const runId = 'run_' + Date.now();
  // Im gewählten Ordner anlegen -> der Run übernimmt dessen Spielernamen.
  const meta = { name, created: Date.now() };
  if (_selectedFolder && _selectedFolder !== '__all__') meta.folder = _selectedFolder;
  runsRef.child(runId).set(meta);
  db.ref(runId).set({ links:[], encounters:[], routes:initRoutes(), gymState:{} });
  document.getElementById('new-run-name').value = '';
  switchToRun(runId);
  renderRunList();
}

function showRunOverview() {
  document.getElementById('run-overview-modal').style.display = 'flex';
  renderFolderBar(); renderFolderSettings(); renderRunList();
}

function hideRunOverview() {
  document.getElementById('run-overview-modal').style.display = 'none';
}

function currentFolderId() {
  const m = _runsMeta[currentRunId];
  return (m && m.folder) || null;
}

function folderPlayerLabels() {
  const f = _folders[currentFolderId()];
  return (f && f.players) || {};
}

function setFolderPlayer(folderId, slot, value) {
  const t = (value || '').trim();
  foldersRef.child(folderId).child('players').child(slot).child('label')
    .set(t || null).catch(()=>{});
}

function renderRunList() {
  const list = document.getElementById('run-list');
  if (!list) return;
  const all = Object.entries(_runsMeta);
  const entries = (_selectedFolder === '__all__'
      ? all
      : all.filter(([, m]) => ((m && m.folder) || null) === _selectedFolder)
    ).sort((a,b) => (b[1].created||0)-(a[1].created||0));
  if (entries.length === 0) {
    list.innerHTML = `<div style="color:var(--muted);font-size:13px;text-align:center;padding:16px;">${
      all.length === 0 ? 'Noch keine Runs. Erstelle deinen ersten!' : 'Keine Runs in dieser Ansicht.'}</div>`;
    return;
  }
  list.innerHTML = entries.map(([id, meta]) => {
    const fid = (meta && meta.folder) || null;
    const fname = fid && _folders[fid] ? _folders[fid].name : null;
    return `
      <div class="run-item ${id===currentRunId?'active-run':''}" onclick="switchToRun('${id}')"
        draggable="true" ondragstart="onRunDragStart(event,'${id}')" title="Zum Wechseln klicken · zum Einsortieren auf einen Ordner ziehen">
        <div>
          <div class="run-item-name">⠿ ${meta.name}</div>
          <div class="run-item-meta">${meta.created ? new Date(meta.created).toLocaleDateString('de-DE') : ''}${fname ? ` · 📁 ${fname}` : ''}</div>
        </div>
        <div style="display:flex;gap:8px;align-items:center;">
          ${id===currentRunId ? '<span style="font-size:10px;color:var(--accent);font-family:\'Press Start 2P\',monospace;">AKTIV</span>' : ''}
          <button onclick="event.stopPropagation();renameRun('${id}','${(meta.name||'').replace(/'/g,"\\'")}')" style="background:none;border:none;color:var(--muted);cursor:pointer;font-size:15px;padding:0 4px;" title="Umbenennen">✏️</button>
          <button onclick="event.stopPropagation();deleteRun('${id}')" style="background:none;border:none;color:var(--muted);cursor:pointer;font-size:16px;padding:0 4px;" title="Löschen">🗑</button>
        </div>
      </div>`;
  }).join('');
}

function renameRun(runId, currentName) {
  const newName = prompt('Neuer Name:', currentName);
  if (!newName || !newName.trim()) return;
  runsRef.child(runId).update({ name: newName.trim() });
  if (currentRunId === runId) {
    const subtitle = document.getElementById('run-subtitle');
    if (subtitle) subtitle.textContent = newName.trim();
  }
  renderRunList();
}

function save() {
  isSaving = true;
  db.ref(currentRunId).set(data).finally(() => {
    setTimeout(() => isSaving = false, 300);
  });
}

function showTab(name) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('nav button').forEach(b => b.classList.remove('active'));
  document.getElementById('tab-' + name).classList.add('active');
  event.currentTarget.classList.add('active');
  render();
}

function initRoutes() {
  return [
    { name: 'Eventura City',        type: 'Stadt',    method: 'Starter',          done: false, note: '' },
    { name: 'Route 19',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Route 20',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Dausing-Hof',          type: 'Gebiet',   method: 'Gras',             done: false, note: '' },
    { name: 'Vapydro-City',         type: 'Stadt',    method: '–',                done: false, note: '' },
    { name: 'Vapydro-Werke',        type: 'Gebiet',   method: 'Gras',             done: false, note: '' },
    { name: 'Stratos-Kanalisation', type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Alter Fluchtweg',      type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Stratos City (Park)',  type: 'Stadt',    method: 'Gras',             done: false, note: '' },
    { name: 'Route 4',              type: 'Route',    method: 'Sand',             done: false, note:'' },
    { name:'Route 4 (Static)', type:'Static', method:'Static', done:false, note:'Lv25 · S2: Do · W2: Mo' },
    { name: 'Wüstenresort',         type: 'Gebiet',   method: 'Sand',             done: false, note: '' },
    { name: 'Alter Palast',         type: 'Dungeon',  method: '–',                done: false, note:'' },
    { name:'Alter Palast (Static)', type:'Static', method:'Static', done:false, note:'Nach Seismo Orden' },
    { name: 'Route 5',              type: 'Lichtung', method: 'Static',           done: false, note: '' },
    { name: 'Route 16',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Hain der Täuschung',   type: 'Gebiet',   method: 'Gras',             done: false, note: '' },
    { name: 'Marea-Zugbrücke',      type: 'Gebiet',   method: 'Schwarze Punkte',  done: false, note: '' },
    { name: 'Marea City',           type: 'Stadt',    method: 'Static',           done: false, note: '' },
    { name: 'Route 6',              type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Route 6 (Static)',     type: 'Geschenk', method: 'Static',           done: false, note: '' },
    { name: 'Elektrolithhöhle',     type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Panaero-Höhle',        type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Kammer der Weisung',   type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Route 7',              type: 'Route',    method: 'Hohes Gras',       done: false, note: '' },
    { name: 'Turm des Himmels',     type: 'Dungeon',  method: '–',                done: false, note: '' },
    { name: 'Janusberg',            type: 'Gebiet',   method: 'Gras',             done: false, note: '' },
    { name: 'Bizarro-Haus',         type: 'Dungeon',  method: '–',                done: false, note: '' },
    { name: 'Ondula',               type: 'Stadt',    method: 'Wasser',           done: false, note: '' },
    { name: 'Bucht von Ondula',     type: 'Gebiet',   method: 'Wasser',           done: false, note:'' },
    { name:'Bucht von Ondula (Static)', type:'Static', method:'Static', done:false, note:'Lv40 · S2: Mo · W2: Do' },
    { name: 'Strandgrotte',         type: 'Höhle',    method: '–',                done: false, note:'' },
    { name:'Strandgrotte (Static)', type:'Static', method:'Static', done:false, note:'Lv42' },
    { name: 'Route 14',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Route 13',             type: 'Route',    method: 'Gras/Legi',        done: false, note:'' },
    { name:'Route 13 (Static)', type:'Static', method:'Static', done:false, note:'Lv45' },
    { name: 'Route 12',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Dorfbrücke',           type: 'Gebiet',   method: 'Gras/Wasser',      done: false, note: '' },
    { name: 'Route 11',             type: 'Route',    method: 'Gras/Wasser/Legi', done: false, note:'' },
    { name:'Route 11 (Static)', type:'Static', method:'Static', done:false, note:'Lv45' },
    { name: 'Route 9',              type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Abidaya City',         type: 'Stadt',    method: 'Wasser',           done: false, note: '' },
    { name: 'Route 21',             type: 'Route',    method: 'Wasser',           done: false, note: '' },
    { name: 'Route 22',             type: 'Route',    method: 'Gras/Legi',        done: false, note:'' },
    { name:'Route 22 (Static)', type:'Static', method:'Static', done:false, note:'Lv45' },
    { name: 'Riesengrotte',         type: 'Höhle',    method: '–',                done: false, note: '' },
    { name: 'Route 23',             type: 'Route',    method: 'Gras',             done: false, note: '' },
    { name: 'Schrein der Ernte',    type: 'Gebiet',   method: 'Gras',             done: false, note: '' },
    { name: 'Siegesstraße',         type: 'Höhle',    method: '–',                done: false, note: '' },
  ];
}

function getMapMappings() {
  return (_globalMap && _globalMap.mapIdToRoute) || {};
}

function autoMapKey(at) {
  if (!at) return null;
  if (at.mapHeader != null && at.mapHeader > 0) return String(at.mapHeader);
  const parts = [at.mapId, at.mapSubId, at.mapDetailId, at.biomePtr].filter(v => v != null);
  return parts.length ? parts.join('_') : null;
}

function isTrainerBattle(at) {
  if (!at) return false;
  if (at.battleType) return at.battleType === 'trainer';
  const et = at.enemyTeam || [];
  if (et.length === 0 && !at.enemy) return false;
  const playerTid = ((at.team || [])[0] || {}).otTid;
  const mons = et.length ? et : [at.enemy];
  return mons.some(m => m && m.otTid && m.otTid !== playerTid);
}

function prefetchEvoFamily(speciesId) {
  const sid = Number(speciesId);
  if (!sid || _evoFamilySync[sid]) return Promise.resolve(_evoFamilySync[sid]);
  if (_evoFamilyPending[sid]) return _evoFamilyPending[sid];
  _evoFamilyPending[sid] = (async () => {
    try {
      const s = await fetch(`https://pokeapi.co/api/v2/pokemon-species/${sid}`);
      const sd = await s.json();
      const c = await fetch(sd.evolution_chain.url);
      const cd = await c.json();
      const names = [];
      (function walk(n){ names.push(n.species.name); n.evolves_to.forEach(walk); })(cd.chain);
      const ids = await Promise.all(names.map(async n => {
        try { const r = await fetch(`https://pokeapi.co/api/v2/pokemon-species/${n}`); return (await r.json()).id; }
        catch { return null; }
      }));
      const set = new Set(ids.filter(x => x != null).map(Number));
      set.add(sid);
      for (const id of set) _evoFamilySync[id] = set;
      return set;
    } catch {
      const set = new Set([sid]);
      _evoFamilySync[sid] = set;
      return set;
    } finally {
      delete _evoFamilyPending[sid];
    }
  })();
  return _evoFamilyPending[sid];
}

function fillStarterTrio(player) {
  const at = data['autoTeam_' + player];
  if (!at || !Array.isArray(at.team) || at.team.length === 0) return;
  const starter = at.team[0];
  if (!starter || !starter.species || !starter.pid) return;
  const starterRoute = (data.routes || []).find(r => r.method === 'Starter');
  if (!starterRoute) return;
  if (!data.encounters) return;
  const encIdx = data.encounters.findIndex(e => e.route === starterRoute.name);
  if (encIdx === -1) return;
  const enc = data.encounters[encIdx];
  if (enc[player + '_id']) return;   // Slot dieses Spielers schon belegt

  const speciesId = Number(starter.species);
  const name = (typeof GERMAN_NAMES !== 'undefined' && GERMAN_NAMES[speciesId])
    || starter.nick || ('#' + speciesId);
  enc[player + '_id']   = speciesId;
  enc[player + '_name'] = name;
  enc[player + '_pid']  = starter.pid;
  // WICHTIG: route + status mitschreiben damit syncEncountersToRoutes den
  // Eintrag per Name wiederfindet (sonst wird er bei jedem Listener-Tick
  // als leerer Slot neu erstellt → fillStarter feuert endlos)
  const upd = {};
  upd[`encounters/${encIdx}/route`]          = enc.route;
  upd[`encounters/${encIdx}/status`]         = enc.status || 'uncaught';
  upd[`encounters/${encIdx}/${player}_id`]   = speciesId;
  upd[`encounters/${encIdx}/${player}_name`] = name;
  upd[`encounters/${encIdx}/${player}_pid`]  = starter.pid;
  db.ref(currentRunId).update(upd).catch(()=>{});
  console.log('[Trio AutoTracker] 🎁 Starter:', player, '→', name);
}

function autoMarkRouteDoneIfAllEntered(enc) {
  if (!enc || !PLAYERS.every(p => enc[p + '_id'])) return;
  const routeIdx = (data.routes || []).findIndex(r => r.name === enc.route);
  if (routeIdx === -1 || (data.routes[routeIdx] || {}).done) return;
  data.routes[routeIdx].done = true;
  db.ref(currentRunId).update({ [`routes/${routeIdx}/done`]: true }).catch(()=>{});
  console.log('[Trio AutoTracker] ✅ Route abgehakt (alle eingetragen):', enc.route);
}

function autoTickBadgesTrio() {
  let combined = 0;
  for (const p of PLAYERS) {
    const at = data['autoTeam_' + p];
    if (at && typeof at.badges === 'number') combined |= at.badges;
  }
  if (!combined) return;
  if (!data.gymState) data.gymState = {};
  const updates = {};
  let dirty = false;
  for (let i = 0; i < 8; i++) {
    if ((combined & (1 << i)) && !data.gymState[i]) {
      data.gymState[i] = true;
      updates[`gymState/${i}`] = true;
      dirty = true;
      console.log('[Trio AutoTracker] 🏅 Orden', i + 1, 'auto-getickt');
    }
  }
  if (dirty) {
    db.ref(currentRunId).update(updates).catch(()=>{});
    renderGyms();
  }
}

function persistNicknames() {
  const links = data.links || [];
  if (!links.length) return;
  const updates = {};
  links.forEach((link, i) => {
    if (!link) return;
    for (const p of PLAYERS) {
      const pid = link[p + '_pid'];
      const at  = data['autoTeam_' + p];
      if (!pid || !at) continue;
      const m = (at.team || []).find(x => x && x.pid === pid)
             || (at.box  || []).find(x => x && x.pid === pid);
      if (!m || !m.nick) continue;           // kein Live-Mon / kein Spitzname
      if (link[p + '_nick'] === m.nick) continue;
      link[p + '_nick'] = m.nick;
      updates[`links/${i}/${p}_nick`] = m.nick;
    }
  });
  if (Object.keys(updates).length) {
    db.ref(currentRunId).update(updates).catch(()=>{});
  }
}

function liveAgeLabel(at) {
  const ageS = liveAgeSeconds(at);
  if (ageS == null) return '–';
  if (ageS < 5)   return '<span style="color:#a5d6a7;">live</span>';
  if (ageS < 30)  return `${ageS}s alt`;
  if (ageS < 600) return `<span style="color:#ffd54f;">${ageS}s alt</span>`;
  return `<span style="color:#ef5350;">offline (${Math.round(ageS/60)}m)</span>`;
}

function liveMonCard(m, isMarkedDead) {
  const species = m.species;
  const gname = (GERMAN_NAMES && GERMAN_NAMES[species]) || m.nick || ('#' + species);
  const nick = m.nick || gname;
  const cur = m.curHP, max = m.maxHP;
  const hasHP = (typeof cur === 'number' && typeof max === 'number' && max > 0);
  const ratio = hasHP ? Math.max(0, Math.min(1, cur / max)) : 1;
  const fainted = hasHP && cur === 0;
  const dead = fainted || isMarkedDead;
  const hpColor = ratio > 0.5 ? '#a5d6a7' : ratio > 0.2 ? '#ffd54f' : '#ef5350';
  return `
    <div style="display:flex;gap:8px;align-items:center;background:var(--surface2);border:1px solid var(--border);border-radius:6px;padding:6px 8px;${dead ? 'opacity:0.5;' : ''}">
      <img src="${spriteUrl(species)}" style="width:42px;height:42px;image-rendering:pixelated;flex-shrink:0;${dead ? 'filter:grayscale(1);' : ''}">
      <div style="flex:1;min-width:0;">
        <div style="display:flex;justify-content:space-between;gap:6px;align-items:baseline;">
          <div style="font-weight:700;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;${m.nick ? '' : 'font-style:italic;color:var(--muted);'}" title="${nick} · ${gname}">${nick}</div>
          <div style="font-family:'Press Start 2P',monospace;font-size:9px;color:var(--gold);flex-shrink:0;">Lv${m.level ?? '?'}</div>
        </div>
        <div style="font-size:10px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${gname}</div>
        ${hasHP ? `
          <div style="display:flex;align-items:center;gap:5px;margin-top:3px;">
            <div style="flex:1;height:5px;background:rgba(0,0,0,0.35);border-radius:3px;overflow:hidden;">
              <div style="width:${ratio*100}%;height:100%;background:${hpColor};transition:width 0.3s,background 0.3s;"></div>
            </div>
            <div style="font-family:'Press Start 2P',monospace;font-size:8px;color:${hpColor};flex-shrink:0;">${cur}/${max}</div>
          </div>` : ''}
      </div>
    </div>`;
}

function _renderSoullinkRow(link, linkIdx, slots, isFullyDead) {
  const routeLabel = link.route || '';
  // Header-Zeile + Pokémon untereinander gestapelt + Löschen-Button
  return `
    <div style="background:var(--surface2);border:1px solid var(--border);border-radius:6px;padding:8px 10px;${isFullyDead ? 'opacity:0.55;' : ''}">
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px;flex-wrap:wrap;">
        <div style="font-family:'Press Start 2P',monospace;font-size:9px;color:var(--muted);letter-spacing:1px;flex-shrink:0;">#${linkIdx + 1}${isFullyDead ? ' 💀' : ''}</div>
        ${routeLabel ? `<div style="font-size:11px;color:var(--accent3);flex-shrink:0;">📍 ${routeLabel}</div>` : ''}
        ${isFullyDead
          ? `<button onclick="reviveLink(${linkIdx})" title="Tot-Markierung entfernen (Fehleingabe)"
              style="margin-left:auto;background:transparent;border:1px solid var(--border);color:var(--accent3);padding:0 8px;height:24px;border-radius:4px;cursor:pointer;font-size:11px;">↺</button>`
          : `<button onclick="markLinkDead(${linkIdx})" title="Link manuell als gefallen markieren (z.B. Spieler ohne Tracker)"
              style="margin-left:auto;background:transparent;border:1px solid var(--border);color:var(--muted);padding:0 8px;height:24px;border-radius:4px;cursor:pointer;font-size:12px;"
              onmouseover="this.style.borderColor='var(--dead)';this.style.color='var(--dead)';"
              onmouseout="this.style.borderColor='var(--border)';this.style.color='var(--muted)';">💀</button>`}
        <button onclick="deleteSoullink(${linkIdx})" title="Diesen Soullink löschen"
          style="margin-left:auto;background:transparent;border:1px solid var(--border);color:var(--dead);width:24px;height:24px;border-radius:4px;cursor:pointer;font-size:14px;font-weight:700;line-height:1;display:flex;align-items:center;justify-content:center;transition:background 0.15s,border-color 0.15s;"
          onmouseover="this.style.background='var(--dead)';this.style.color='#fff';this.style.borderColor='var(--dead)';"
          onmouseout="this.style.background='transparent';this.style.color='var(--dead)';this.style.borderColor='var(--border)';">×</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:3px;">
        ${slots.map(s => _renderLinkSlotInline(s, link, linkIdx)).join('')}
      </div>
    </div>`;
}

function reviveLink(linkIdx) {
  const link = (data.links || [])[linkIdx];
  if (!link) return;
  if (!confirm(`Link #${linkIdx + 1} wiederbeleben? (Tot-Markierung aller Partner entfernen — nur bei Fehleingabe.)`)) return;
  link.dead = Object.fromEntries(PLAYERS.map(p => [p, false]));
  link.killer = null;
  db.ref(currentRunId).update({
    [`links/${linkIdx}/dead`]: link.dead,
    [`links/${linkIdx}/killer`]: null,
  }).catch(()=>{});
  render();
}

function _renderLinkSlotInline(slot, link, linkIdx) {
  const { p, pokemon, location, slotIdx } = slot;
  const isDead = link.dead && link.dead[p.slot];
  if (!pokemon) {
    // Kein Live-Mon (manuell eingetragener Spieler ohne Tracker, oder alter
    // Run ohne Live-Daten) — trotzdem anklickbar: Detail kommt aus den
    // Link-Daten. Gespeicherter Spitzname schlaegt den Art-Namen.
    const species = link[p.slot + '_id'];
    const spName = link[p.slot + '_name'] || '?';
    const storedNick = link[p.slot + '_nick'];
    const name = storedNick || spName;
    const clickable = species != null && species !== '';
    return `
      <div ${clickable ? `onclick="showLinkDetailFromLink(${linkIdx},'${p.slot}')" title="${p.label} · ${name}${storedNick ? ' · ' + spName : ''}"` : ''}
        style="display:inline-flex;align-items:center;gap:5px;font-size:12px;${isDead ? 'opacity:0.4;' : 'opacity:0.75;'}${clickable ? 'cursor:pointer;padding:2px 6px;border-radius:4px;border:1px solid transparent;' : ''}"
        ${clickable ? `onmouseover="this.style.borderColor='${p.color}';this.style.background='var(--surface)';" onmouseout="this.style.borderColor='transparent';this.style.background='transparent';"` : ''}>
        ${species ? `<img src="${spriteUrl(species)}" style="width:28px;height:28px;image-rendering:pixelated;${isDead ? 'filter:grayscale(1);' : ''}">` : ''}
        <span style="color:${isDead ? 'var(--muted)' : p.color};font-weight:${isDead ? 400 : 700};">${name}</span>
        ${isDead ? '<span>💀</span>' : ''}
      </div>`;
  }
  const cur = pokemon.curHP, max = pokemon.maxHP;
  const hasHP = (typeof cur === 'number' && typeof max === 'number' && max > 0);
  const fainted = hasHP && cur === 0;
  const dead = fainted || isDead;
  const species = pokemon.species;
  const gname = (GERMAN_NAMES && GERMAN_NAMES[species]) || pokemon.nick || ('#' + species);
  // Live-Spitzname zuerst, dann der im Link gesicherte (falls das RAM ihn
  // gerade nicht liefert), sonst der Art-Name.
  const savedNick = link[p.slot + '_nick'];
  const nick = pokemon.nick || savedNick || gname;
  const ratio = hasHP ? Math.max(0, Math.min(1, cur / max)) : 1;
  const hpColor = ratio > 0.5 ? '#a5d6a7' : ratio > 0.2 ? '#ffd54f' : '#ef5350';
  return `
    <div onclick="showLinkDetail('${p.slot}','${location}',${slotIdx})" title="${p.label} · ${nick} · Lv${pokemon.level ?? '?'}${hasHP ? ` · ${cur}/${max} KP` : ''}" style="display:inline-flex;align-items:center;gap:5px;font-size:12px;cursor:pointer;padding:2px 6px;border-radius:4px;border:1px solid transparent;transition:border-color 0.15s,background 0.15s;${dead ? 'opacity:0.5;' : ''}" onmouseover="this.style.borderColor='${p.color}';this.style.background='var(--surface)';" onmouseout="this.style.borderColor='transparent';this.style.background='transparent';">
      <img src="${spriteUrl(species)}" style="width:28px;height:28px;image-rendering:pixelated;${dead ? 'filter:grayscale(1);' : ''}">
      <span style="color:${p.color};font-weight:700;${(pokemon.nick || savedNick) ? '' : 'font-style:italic;'}">${nick}</span>
      ${hasHP ? `<span style="font-family:'Press Start 2P',monospace;font-size:8px;color:${hpColor};">${cur}/${max}</span>` : ''}
    </div>`;
}

function openManualLinkModal() {
  Object.keys(_manualLinkSel).forEach(k => _manualLinkSel[k] = null);
  _renderManualLinkBody();
  document.getElementById('manual-link-modal').style.display = 'flex';
}

function hideManualLinkModal() {
  document.getElementById('manual-link-modal').style.display = 'none';
}

function selectManualLink(player, source, idx) {
  const at = data['autoTeam_' + player];
  if (!at) return;
  const m = source === 'team' ? (at.team || [])[idx] : (at.box || [])[idx];
  if (!m || !m.pid) return;
  _manualLinkSel[player] = { m, source, idx };
  _renderManualLinkBody();
}

function hideLinkDetail() {
  document.getElementById('link-detail-modal').style.display = 'none';
}

function _pokeWikiLink(label, text, extra) {
  return `<a href="https://www.pokewiki.de/${encodeURIComponent(label)}" target="_blank" rel="noopener" style="color:var(--accent);text-decoration:none;border-bottom:1px dashed var(--accent);">${text || label}</a>${extra || ''}`;
}

function _renderLinkDetailBody(m, playerSlot) {
  const body = document.getElementById('link-detail-body');
  if (!body) return;
  const species = m.species;
  const gname = (GERMAN_NAMES && GERMAN_NAMES[species]) || ('#' + species);
  const cur = m.curHP, max = m.maxHP;
  const hasHP = (typeof cur === 'number' && typeof max === 'number' && max > 0);
  const ratio = hasHP ? Math.max(0, Math.min(1, cur / max)) : 1;
  const dead = hasHP && cur === 0;
  const hpColor = ratio > 0.5 ? 'var(--accent3)' : ratio > 0.2 ? 'var(--gold)' : 'var(--dead)';

  // Item sofort aus Gen5-Tabelle (oder #id wenn unbekannt)
  const itemSyncName = gen5ItemNameSync(m.item);

  body.innerHTML = `
    <div style="display:flex;gap:14px;align-items:flex-start;margin-bottom:16px;">
      <img src="${spriteUrl(species)}" style="width:96px;height:96px;image-rendering:pixelated;flex-shrink:0;${dead ? 'filter:grayscale(1);opacity:0.6;' : ''}">
      <div style="flex:1;min-width:0;">
        <div style="font-weight:700;font-size:18px;${m.nick ? '' : 'font-style:italic;color:var(--muted);'}">${m.nick || _pokeWikiLink(gname, m.nick || gname)}</div>
        <div style="font-size:13px;color:var(--muted);">${_pokeWikiLink(gname)} · #${String(species).padStart(3,'0')}</div>
        <div style="font-family:'Press Start 2P',monospace;font-size:12px;color:var(--gold);margin-top:6px;">Lv ${m.level ?? '?'}</div>
        ${hasHP ? `
          <div style="margin-top:8px;">
            <div style="font-size:12px;color:${hpColor};font-weight:600;">${cur}/${max} KP${dead ? ' 💀' : ''}</div>
            <div style="width:100%;max-width:240px;height:6px;background:var(--surface2);border-radius:3px;overflow:hidden;margin-top:3px;">
              <div style="width:${ratio*100}%;height:100%;background:${hpColor};"></div>
            </div>
          </div>` : ''}
        <div id="ld-types" style="display:flex;gap:5px;margin-top:8px;flex-wrap:wrap;"></div>
      </div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:12px;font-size:12px;">
      <div style="background:var(--surface2);padding:6px 10px;border-radius:4px;">
        <div style="color:var(--muted);font-size:10px;letter-spacing:1px;">ITEM</div>
        <div id="ld-item">${m.item ? itemSyncName : '–'}</div>
      </div>
      <div style="background:var(--surface2);padding:6px 10px;border-radius:4px;">
        <div style="color:var(--muted);font-size:10px;letter-spacing:1px;">FÄHIGKEIT</div>
        <div id="ld-ability">${m.ability ? 'Lade...' : '–'}</div>
      </div>
    </div>
    <div style="background:var(--surface2);padding:10px;border-radius:6px;margin-bottom:10px;">
      <div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px;">
        <div style="color:var(--muted);font-size:10px;letter-spacing:1px;">BASISWERTE</div>
        <div style="font-family:'Press Start 2P',monospace;font-size:11px;color:var(--gold);">BST: <span id="ld-bst">…</span></div>
      </div>
      <div id="ld-stats" style="display:flex;flex-direction:column;gap:3px;font-size:11px;">
        <div style="color:var(--muted);">Lade Stats...</div>
      </div>
    </div>
    <div style="background:var(--surface2);padding:10px;border-radius:6px;margin-bottom:10px;">
      <div style="color:var(--muted);font-size:10px;letter-spacing:1px;margin-bottom:6px;">SCHWÄCHEN / RESISTENZEN</div>
      <div id="ld-eff" style="display:flex;flex-direction:column;gap:4px;font-size:11px;">
        <div style="color:var(--muted);">Lade...</div>
      </div>
    </div>
    <div style="background:var(--surface2);padding:10px;border-radius:6px;">
      <div style="color:var(--muted);font-size:10px;letter-spacing:1px;margin-bottom:6px;">⚔ ATTACKEN</div>
      <div id="ld-moves" style="display:flex;flex-direction:column;gap:4px;font-size:12px;">${
        (m.moves || []).filter(id => id > 0).length
          ? (m.moves || []).filter(id => id > 0).map((id, i) =>
              `<a id="ld-move-${i}" href="#" target="_blank" rel="noopener" style="display:block;background:var(--surface);padding:5px 9px;border-radius:3px;color:var(--text);text-decoration:none;border:1px solid transparent;transition:border-color 0.15s;" onmouseover="this.style.borderColor='var(--accent)'" onmouseout="this.style.borderColor='transparent'">Lade...</a>`
            ).join('')
          : '<div style="color:var(--muted);">Keine Attacken</div>'
      }</div>
    </div>`;

  // BST + Stats + Types async laden
  fetch(`https://pokeapi.co/api/v2/pokemon/${species}`)
    .then(r => r.json())
    .then(async d => {
      const STAT_LABELS = { hp:'KP', attack:'ANG', defense:'VTD', 'special-attack':'SP.ANG', 'special-defense':'SP.VTD', speed:'INI' };
      const STAT_COLORS = { hp:'#a5d6a7', attack:'#ef5350', defense:'#ffd54f', 'special-attack':'#ab47bc', 'special-defense':'#26a69a', speed:'#42a5f5' };
      let total = 0;
      const rows = (d.stats || []).map(s => {
        const val = s.base_stat; total += val;
        const label = STAT_LABELS[s.stat.name] || s.stat.name;
        const color = STAT_COLORS[s.stat.name] || 'var(--accent)';
        const pct = Math.min(100, val / 255 * 100);
        return `<div style="display:flex;align-items:center;gap:8px;">
          <div style="width:55px;font-family:'Press Start 2P',monospace;font-size:8px;color:var(--muted);">${label}</div>
          <div style="flex:1;height:6px;background:rgba(0,0,0,0.35);border-radius:3px;overflow:hidden;">
            <div style="width:${pct}%;height:100%;background:${color};"></div>
          </div>
          <div style="width:28px;text-align:right;font-family:'Press Start 2P',monospace;font-size:10px;color:var(--text);">${val}</div>
        </div>`;
      }).join('');
      const statsEl = document.getElementById('ld-stats'); if (statsEl) statsEl.innerHTML = rows;
      const bstEl = document.getElementById('ld-bst'); if (bstEl) bstEl.textContent = total;

      // Types-Badges (Gen 5: keine Fairy)
      const types = (d.types || []).map(t => t.type.name).filter(t => GEN5_TYPES.includes(t));
      const tEl = document.getElementById('ld-types');
      if (tEl) tEl.innerHTML = types.map(t => {
        const color = TYPE_COLORS[t] || '#666';
        return `<span style="background:${color};color:#fff;padding:2px 10px;border-radius:3px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">${t}</span>`;
      }).join('');

      // Effektivität (Gen 5)
      if (types.length) {
        const eff = await calcEffectivenessGen5(types);
        const buckets = { '4x':[], '2x':[], '0.5x':[], '0.25x':[], '0x':[] };
        Object.entries(eff).forEach(([typ, mult]) => {
          if (mult === 4) buckets['4x'].push(typ);
          else if (mult === 2) buckets['2x'].push(typ);
          else if (mult === 0.5) buckets['0.5x'].push(typ);
          else if (mult === 0.25) buckets['0.25x'].push(typ);
          else if (mult === 0) buckets['0x'].push(typ);
        });
        const renderBucket = (label, types, color) => {
          if (!types.length) return '';
          const badges = types.map(t => `<span style="background:${TYPE_COLORS[t] || '#666'};color:#fff;padding:1px 6px;border-radius:3px;font-size:9px;font-weight:700;text-transform:uppercase;margin-right:3px;">${t}</span>`).join('');
          return `<div style="display:flex;align-items:center;gap:8px;"><span style="min-width:48px;color:${color};font-family:'Press Start 2P',monospace;font-size:9px;">${label}</span><div>${badges}</div></div>`;
        };
        const html = [
          renderBucket('4×', buckets['4x'], '#ef5350'),
          renderBucket('2×', buckets['2x'], '#ff7043'),
          renderBucket('½×', buckets['0.5x'], '#66bb6a'),
          renderBucket('¼×', buckets['0.25x'], '#26a69a'),
          renderBucket('0×', buckets['0x'], '#7986cb'),
        ].filter(s => s).join('');
        const effEl = document.getElementById('ld-eff');
        if (effEl) effEl.innerHTML = html || '<div style="color:var(--muted);">Keine besonderen Schwächen/Resistenzen.</div>';
      }
    }).catch(() => {
      const statsEl = document.getElementById('ld-stats');
      if (statsEl) statsEl.innerHTML = '<div style="color:var(--dead);">Stats konnten nicht geladen werden.</div>';
    });

  // Ability mit PokeWiki-Link
  if (m.ability && m.ability > 0) {
    fetch(`https://pokeapi.co/api/v2/ability/${m.ability}`)
      .then(r => r.json())
      .then(ab => {
        const deName = (ab.names || []).find(n => n.language.name === 'de')?.name || ab.name;
        const el = document.getElementById('ld-ability');
        if (el) el.innerHTML = _pokeWikiLink(deName);
      }).catch(() => {});
  }

  // Item mit Gen5-Tabelle + PokeWiki-Link
  if (m.item && m.item > 0) {
    fetchItemName(m.item).then(name => {
      const el = document.getElementById('ld-item');
      if (el) el.innerHTML = _pokeWikiLink(name);
    });
  }

  // Moves mit PokeWiki-Link
  (m.moves || []).filter(id => id > 0).forEach((id, i) => {
    fetch(`https://pokeapi.co/api/v2/move/${id}`)
      .then(r => r.json())
      .then(mv => {
        const deName = (mv.names || []).find(n => n.language.name === 'de')?.name || mv.name;
        const el = document.getElementById('ld-move-' + i);
        if (el) {
          el.textContent = deName;
          el.href = `https://www.pokewiki.de/${encodeURIComponent(deName)}`;
        }
      }).catch(() => {
        const el = document.getElementById('ld-move-' + i);
        if (el) el.textContent = '#' + id;
      });
  });
}

function assignMapTrio(player, mapKey) {
  const sel = document.getElementById('live-route-' + player);
  if (!sel) return;
  const route = sel.value;
  if (!route) return;
  db.ref('_global/mapIdToRoute/' + mapKey).set(route).catch(()=>{});
  if (!_globalMap.mapIdToRoute) _globalMap.mapIdToRoute = {};
  _globalMap.mapIdToRoute[mapKey] = route;
  renderLive();
}

function showGraveyard() {
  renderLive();  // sicherstellen, dass die Liste aktuell ist
  document.getElementById('graveyard-modal').style.display = 'flex';
}

function hideGraveyard() {
  document.getElementById('graveyard-modal').style.display = 'none';
}

function deleteMapping(key) {
  if (!key) return;
  db.ref('_global/mapIdToRoute/' + key).remove().catch(()=>{});
  if (_globalMap.mapIdToRoute) delete _globalMap.mapIdToRoute[key];
  render();
}

function _setSubtabStyles() {
  document.querySelectorAll('.pi-subtab').forEach(b => {
    const active = b.dataset.mode === piMode;
    b.classList.toggle('active', active);
    b.style.background   = active ? 'var(--accent)' : 'var(--surface)';
    b.style.color        = active ? 'var(--bg)'     : 'var(--muted)';
    b.style.borderColor  = active ? 'var(--accent)' : 'var(--border)';
    b.style.fontWeight   = active ? '700'           : '600';
  });
}

function showPiMode(mode) {
  piMode = mode;
  _setSubtabStyles();
  const isSearch = mode === 'search';
  const searchWrap = document.getElementById('pi-search-wrap');
  const emptyEl    = document.getElementById('pi-enemy-empty');
  const movesBox   = document.getElementById('pi-actual-moves-box');
  const learnBox   = document.getElementById('pi-learnset-box');
  if (searchWrap) searchWrap.style.display = isSearch ? '' : 'none';
  if (isSearch) {
    if (emptyEl)  emptyEl.style.display  = 'none';
    if (movesBox) movesBox.style.display = 'none';
    if (learnBox) learnBox.style.display = '';
    for (const k in _lastEnemyKey) delete _lastEnemyKey[k];
  } else {
    refreshPiEnemy();
  }
}

function setPiEnemyIdx(player, idx) {
  if (!_piEnemyRevealed[player]) _piEnemyRevealed[player] = new Set([0]);
  _piEnemyRevealed[player].add(idx);   // Klick deckt diesen Slot auf
  _piEnemyIdx[player] = idx;
  _lastEnemyKey[player] = null;        // forciere Reload
  refreshPiEnemy();
}

function loadPokeList() {
  if (pokeListLoaded) return Promise.resolve();
  POKEMON_LIST = Object.entries(GERMAN_NAMES).map(([id, name]) => ({ id: Number(id), name }));
  pokeListLoaded = true;
  return Promise.resolve();
}

function spriteUrl(id) {
  return `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${id}.png`;
}

function pokeDisplayName(name) {
  // Namen sind bereits auf Deutsch und korrekt formatiert
  return name;
}

function openEncDrop(encIdx, player) {
  loadPokeList().then(() => {
    const inp = document.getElementById(`eps-${encIdx}-${player}`);
    const list = document.getElementById(`epl-${encIdx}-${player}`);
    if (inp && list) positionDrop(inp, list);
    filterEncPoke(encIdx, player, inp?.value || '');
  });
}

function filterEncPoke(encIdx, player, query) {
  const list = document.getElementById(`epl-${encIdx}-${player}`);
  const inp = document.getElementById(`eps-${encIdx}-${player}`);
  if (!list) return;
  positionDrop(inp, list);
  const q = query.trim().toLowerCase();
  const filtered = q
    ? POKEMON_LIST.filter(p => p.name.toLowerCase().includes(q) || String(p.id).startsWith(q)).slice(0,40)
    : POKEMON_LIST.slice(0,40);
  list.innerHTML = filtered.map(p => `
    <div class="poke-option" onmousedown="selectEncPoke(${encIdx},'${player}',${p.id},'${p.name.replace(/'/g,"\\'")}')">
      <img src="${spriteUrl(p.id)}" alt="${p.name}" loading="lazy">
      <span class="poke-num">#${String(p.id).padStart(3,'0')}</span>
      <span>${p.name}</span>
    </div>
  `).join('');
  list.classList.add('open');
}

function selectEncPoke(encIdx, player, id, name) {
  data.encounters[encIdx][player+'_id'] = id;
  data.encounters[encIdx][player+'_name'] = name;
  const enc = data.encounters[encIdx];
  const upd = {};
  upd[`encounters/${encIdx}/route`]          = enc.route;
  upd[`encounters/${encIdx}/${player}_id`]   = id;
  upd[`encounters/${encIdx}/${player}_name`] = name;
  db.ref(currentRunId).update(upd).catch(()=>{});
  autoMarkRouteDoneIfAllEntered(enc);   // manuell zählt wie auto
  const list = document.getElementById(`epl-${encIdx}-${player}`);
  if (list) list.classList.remove('open');
  const inp = document.getElementById(`eps-${encIdx}-${player}`);
  if (inp) inp.value = name;
  const spriteEl = document.getElementById(`esp-${encIdx}-${player}`);
  if (spriteEl) {
    if (spriteEl.tagName === 'IMG') {
      spriteEl.src = spriteUrl(id);
    } else {
      spriteEl.outerHTML = `<img src="${spriteUrl(id)}" id="esp-${encIdx}-${player}" style="width:32px;height:32px;image-rendering:pixelated;flex-shrink:0;">`;
    }
  }
}

function positionDrop(inp, list) {
  if (!inp) return;
  const rect = inp.getBoundingClientRect();
  list.style.top = (rect.bottom) + 'px';
  list.style.left = rect.left + 'px';
  list.style.width = rect.width + 'px';
}

function closeAllDrops() {
  document.querySelectorAll('.poke-list').forEach(l => l.classList.remove('open'));
}

function matchEncPoke(encIdx, player, query) {
  loadPokeList();
  const q = (query || '').trim().toLowerCase();
  const enc = data.encounters[encIdx];
  // Partielles Update — autoTeam_* nicht clobbern, route immer mitschreiben
  const upd = { [`encounters/${encIdx}/route`]: enc.route };
  if (!q) {
    enc[player+'_id'] = '';
    enc[player+'_name'] = '';
    upd[`encounters/${encIdx}/${player}_id`]   = '';
    upd[`encounters/${encIdx}/${player}_name`] = '';
    updateEncSprite(encIdx, player, null);
    db.ref(currentRunId).update(upd).catch(()=>{});
    return;
  }
  let match = POKEMON_LIST.find(p => p.name.toLowerCase() === q)
           || POKEMON_LIST.find(p => p.name.toLowerCase().startsWith(q))
           || POKEMON_LIST.find(p => p.name.toLowerCase().includes(q));
  if (match) {
    enc[player+'_id'] = match.id;
    enc[player+'_name'] = match.name;
    upd[`encounters/${encIdx}/${player}_id`]   = match.id;
    upd[`encounters/${encIdx}/${player}_name`] = match.name;
    updateEncSprite(encIdx, player, match.id);
  } else {
    enc[player+'_id'] = '';
    enc[player+'_name'] = query;
    upd[`encounters/${encIdx}/${player}_id`]   = '';
    upd[`encounters/${encIdx}/${player}_name`] = query;
    updateEncSprite(encIdx, player, null);
  }
  db.ref(currentRunId).update(upd).catch(()=>{});
}

function updateEncSprite(encIdx, player, id) {
  const el = document.getElementById(`esp-${encIdx}-${player}`);
  if (!el) return;
  if (id) {
    if (el.tagName === 'IMG') {
      el.src = spriteUrl(id);
    } else {
      el.outerHTML = `<img src="${spriteUrl(id)}" id="esp-${encIdx}-${player}" style="width:32px;height:32px;image-rendering:pixelated;flex-shrink:0;" loading="lazy">`;
    }
  } else {
    if (el.tagName === 'IMG') {
      el.outerHTML = `<div id="esp-${encIdx}-${player}" style="width:32px;height:32px;flex-shrink:0;"></div>`;
    }
  }
}

function updateEnc(i, field, val) {
  data.encounters[i][field] = val;
  const upd = {};
  // route immer mitschreiben damit syncEncountersToRoutes den Eintrag findet
  upd[`encounters/${i}/route`]     = data.encounters[i].route;
  upd[`encounters/${i}/${field}`]  = val;
  // Wenn Status auf "gefangen" gesetzt: automatisch Link erstellen
  if (field === 'status' && val === 'caught') {
    autoCreateLink(i);
    upd['links'] = data.links;
  }
  db.ref(currentRunId).update(upd).catch(()=>{});
}

function openEncSearch() {
  loadPokeList().then(() => filterEncSearch(document.getElementById('enc-search').value || ''));
}

function filterEncSearch(query) {
  const list = document.getElementById('enc-search-list');
  const inp = document.getElementById('enc-search');
  if (!list) return;
  positionDrop(inp, list);
  const q = query.trim().toLowerCase();
  const filtered = q
    ? POKEMON_LIST.filter(p => p.name.toLowerCase().includes(q) || String(p.id).startsWith(q)).slice(0, 40)
    : POKEMON_LIST.slice(0, 40);
  list.innerHTML = filtered.map(p => `
    <div class="poke-option" onmousedown="jumpToEncounter(${p.id},'${p.name.replace(/'/g,"\\'")}')">
      <img src="${spriteUrl(p.id)}" alt="${p.name}" loading="lazy">
      <span class="poke-num">#${String(p.id).padStart(3,'0')}</span>
      <span>${p.name}</span>
    </div>
  `).join('');
  list.classList.add('open');
}

function renderRoutes() {
  if (isUserInteracting()) return;
  const body = document.getElementById('route-body');
  if (!body) return;
  body.innerHTML = data.routes.map((r, i) => `
    <tr>
      <td class="route-name">${r.name}</td>
      <td style="color:var(--muted);font-size:12px;">${r.type}</td>
      <td style="color:var(--muted);font-size:12px;">${r.method}</td>
      <td>
        <label style="display:flex;align-items:center;gap:8px;cursor:pointer;">
          <input type="checkbox" ${r.done?'checked':''} onchange="toggleRoute(${i})" style="accent-color:var(--accent3);width:16px;height:16px;">
          <span style="font-size:12px;color:${r.done?'var(--accent3)':'var(--muted)'};">${r.done?'Erledigt':'Offen'}</span>
        </label>
      </td>
      <td><input type="text" value="${r.note||''}" placeholder="Notiz..." oninput="updateRoute(${i},this.value)" style="background:transparent;border:none;color:var(--text);font-family:'Exo 2',sans-serif;font-size:13px;width:100%;"></td>
    </tr>
  `).join('');
}

function toggleRoute(i) { data.routes[i].done = !data.routes[i].done; save(); render(); }

function updateRoute(i, val) { data.routes[i].note = val; save(); }

function resetRoutes() {
  if (confirm('Routenliste zurücksetzen? Notizen und Häkchen gehen verloren.')) {
    data.routes = initRoutes();
    save(); render();
  }
}

function renderGyms() {
  if (isUserInteracting()) return;
  const grid = document.getElementById('gym-grid');
  if (!grid) return;
  const state = data.gymState || {};
  grid.innerHTML = GYMS.map((g, i) => `
    <div class="gym-card">
      <div class="gym-number">${g.label || ('GYM ' + g.num)}</div>
      <div class="gym-name">${g.name}</div>
      ${(g.leader || g.type) ? `<div class="gym-leader">${[g.leader, g.type].filter(Boolean).join(' · ')}</div>` : ''}
      <div class="gym-lvlcap">Lv. ${g.lvl}</div>
      ${g.badge ? `<div class="gym-badge">${g.badge}</div>` : ''}
      <div class="gym-check">
        <input type="checkbox" id="gym-${i}" ${state[i]?'checked':''} onchange="toggleGym(${i})">
        <label for="gym-${i}">✓ Besiegt</label>
      </div>
    </div>
  `).join('');
}

function toggleGym(i) {
  if (!data.gymState) data.gymState = {};
  data.gymState[i] = !data.gymState[i];
  save(); render();
}

function gen5ItemNameSync(id) {
  if (!id || id <= 0) return '–';
  if (GEN5_ITEMS[id]) return GEN5_ITEMS[id];
  if (_itemNameCache[id] !== undefined) return _itemNameCache[id];
  return '#' + id;
}

function fetchItemName(id) {
  if (!id || id <= 0) return Promise.resolve('–');
  if (GEN5_ITEMS[id]) return Promise.resolve(GEN5_ITEMS[id]);
  if (_itemNameCache[id] !== undefined) return Promise.resolve(_itemNameCache[id]);
  if (_itemNamePending[id]) return _itemNamePending[id];
  _itemNamePending[id] = (async () => {
    try {
      const r = await fetch(`https://pokeapi.co/api/v2/item/${id}`);
      const it = await r.json();
      const de = (it.names || []).find(n => n.language.name === 'de')?.name || it.name || ('#' + id);
      _itemNameCache[id] = de;
      return de;
    } catch {
      _itemNameCache[id] = '#' + id;
      return '#' + id;
    } finally {
      delete _itemNamePending[id];
    }
  })();
  return _itemNamePending[id];
}

function mergeDamageRelations(current, past) {
  // Past-Einträge überschreiben aktuelle (für die Richtung "damage_to")
  const merged = {
    no_damage_to: [...(current.no_damage_to || [])],
    half_damage_to: [...(current.half_damage_to || [])],
    double_damage_to: [...(current.double_damage_to || [])],
    no_damage_from: [...(current.no_damage_from || [])],
    half_damage_from: [...(current.half_damage_from || [])],
    double_damage_from: [...(current.double_damage_from || [])]
  };
  // Past-Einträge einfügen/überschreiben
  ['no_damage_to','half_damage_to','double_damage_to','no_damage_from','half_damage_from','double_damage_from'].forEach(key => {
    if (past[key]) {
      past[key].forEach(entry => {
        // Entferne aus allen anderen Listen
        ['no_damage_to','half_damage_to','double_damage_to'].forEach(k => {
          merged[k] = merged[k].filter(e => e.name !== entry.name);
        });
        merged[key].push(entry);
      });
    }
  });
  return merged;
}

function openPokeInfoDrop() {
  loadPokeList().then(() => filterPokeInfo(document.getElementById('pokeinfo-search').value || ''));
}

function filterPokeInfo(query) {
  const list = document.getElementById('pokeinfo-list');
  const inp = document.getElementById('pokeinfo-search');
  if (!list) return;
  positionDrop(inp, list);
  const q = query.trim().toLowerCase();
  const filtered = q
    ? POKEMON_LIST.filter(p => p.name.toLowerCase().includes(q) || String(p.id).startsWith(q)).slice(0,40)
    : POKEMON_LIST.slice(0,40);
  list.innerHTML = filtered.map(p => `
    <div class="poke-option" onmousedown="selectPokeInfo(${p.id},'${p.name.replace(/'/g,"\\'")}')">
      <img src="${spriteUrl(p.id)}" alt="${p.name}" loading="lazy">
      <span class="poke-num">#${String(p.id).padStart(3,'0')}</span>
      <span>${p.name}</span>
    </div>
  `).join('');
  list.classList.add('open');
}

function syncLevelInput(source) {
  const slider = document.getElementById('level-slider');
  const input = document.getElementById('level-input');
  if (!slider || !input) return;
  if (source === 'slider') {
    input.value = slider.value;
  } else {
    let v = Math.min(100, Math.max(1, parseInt(input.value) || 1));
    input.value = v;
    slider.value = v;
  }
  updateMoves();
}

function updateMoves() {
  const slider = document.getElementById('level-slider');
  if (!slider) return;
  const level = parseInt(slider.value);
  if (!currentMovesByLevel.length) return;

  const movesEl = document.getElementById('pokeinfo-moves');

  // Alle Attacken bis zum gewählten Level
  const available = currentMovesByLevel.filter(m => m.level <= level);
  if (!available.length) {
    movesEl.innerHTML = '<div style="color:var(--muted);font-size:13px;">Keine Attacken bei diesem Level.</div>';
    return;
  }

  // Simuliere welche 4 das Pokemon tatsächlich hat:
  // Gehe Level für Level durch, füge Attacken ein, verdrän­ge älteste wenn > 4
  const levelGroups = {};
  available.forEach(m => {
    if (!levelGroups[m.level]) levelGroups[m.level] = [];
    levelGroups[m.level].push(m);
  });

  let moveset = []; // Namen der tatsächlich gehaltenen Attacken
  Object.keys(levelGroups).sort((a,b) => a-b).forEach(lvl => {
    levelGroups[lvl].forEach(m => moveset.push(m.name));
    while (moveset.length > 4) moveset.shift();
  });

  const movesetSet = new Set(moveset);

  // Zeige ALLE verfügbaren Attacken an, neueste oben
  movesEl.innerHTML = [...available].reverse().map(m => {
    const inMoveset = movesetSet.has(m.name);
    return `
    <div style="display:flex;align-items:center;gap:10px;padding:6px 10px;background:var(--surface2);border-radius:6px;${!inMoveset ? 'opacity:0.7;' : ''}">
      <span style="font-family:'Press Start 2P',monospace;font-size:9px;color:${inMoveset ? 'var(--muted)' : 'var(--dead)'};min-width:36px;">Lv.${m.level}</span>
      <span style="font-weight:700;font-size:14px;color:${inMoveset ? 'var(--text)' : 'var(--dead)'};">${m.name}</span>
      <span class="type-badge" style="background:${TYPE_COLORS[m.type]||'#888'};color:#fff;font-size:11px;${!inMoveset ? 'filter:grayscale(0.5);' : ''}">${TYPE_DE[m.type]||m.type}</span>
    </div>`;
  }).join('');
}

function calcLv50Stat(base, statName) {
  // Formel ohne EVs/IVs/Nature (neutrale Schätzung: IVs=15, EVs=0, Nature=1.0)
  const iv = 15;
  if (statName === 'hp') {
    return Math.floor(((2 * base + iv) * 50 / 100) + 50 + 10);
  }
  return Math.floor((((2 * base + iv) * 50 / 100) + 5) * 1.0);
}

function renderStats(stats) {
  const bst = stats.reduce((s, st) => s + st.base_stat, 0);
  const maxStat = 255;
  document.getElementById('pokeinfo-stats').innerHTML = stats.map(st => {
    const base = st.base_stat;
    const name = st.stat.name;
    const pct = Math.min(100, Math.round(base / maxStat * 100));
    const color = STAT_COLORS[name] || '#7986cb';
    const label = STAT_LABELS[name] || name;
    return `<div style="display:flex;flex-direction:column;gap:2px;">
      <div style="display:flex;justify-content:space-between;align-items:center;">
        <span style="font-size:10px;color:var(--muted);font-weight:600;">${label}</span>
        <span style="font-family:'Press Start 2P',monospace;font-size:9px;color:var(--text);">${base}</span>
      </div>
      <div style="background:var(--surface2);border-radius:3px;height:6px;overflow:hidden;">
        <div style="width:${pct}%;height:100%;background:${color};border-radius:3px;transition:width 0.4s ease;"></div>
      </div>
    </div>`;
  }).join('');
  document.getElementById('bst-value').textContent = bst;
}
