"""
═══════════════════════════════════════════════════════════
  AutoTracker-Brücke: state.json  →  Firebase

  Beobachtet die JSON-Datei, die das Lua-Skript schreibt,
  und schickt jeden Inhalt per HTTP PUT an Firebase.

  Starten:  python bridge.py
═══════════════════════════════════════════════════════════
"""
import json
import time
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

# ── Konfiguration ──
STATE_FILE     = Path("C:/trash/PokemonWebsite/autotracker/state.json")
FIREBASE_URL   = "https://bw2-nuzlocke-default-rtdb.europe-west1.firebasedatabase.app"
NAMESPACE      = "slt_9k3xq7m2"
DEFAULT_RUN_ID = "solo_run_default"   # Fallback, wenn Firebase noch keinen aktiven Run kennt
POLL_INTERVAL  = 0.5   # Sekunden

# Aktiver Run wird dynamisch aus Firebase gelesen
_current_run_id = DEFAULT_RUN_ID
_last_run_check = 0.0
RUN_CHECK_INTERVAL = 3.0   # Sekunden zwischen aktiv-Run-Polls

# ── Logik ──
def fetch_active_run() -> None:
    """Liest den aktuell aktiven Run aus Firebase und aktualisiert _current_run_id."""
    global _current_run_id, _last_run_check
    url = f"{FIREBASE_URL}/{NAMESPACE}/_active_run.json"
    try:
        with urllib.request.urlopen(url, timeout=3) as res:
            body = res.read().decode("utf-8")
        new_run = json.loads(body) if body and body != "null" else None
        if isinstance(new_run, str) and new_run and new_run != _current_run_id:
            print(f"[INFO] Aktiver Run gewechselt: {_current_run_id}  →  {new_run}")
            _current_run_id = new_run
    except Exception:
        pass  # bei Fehler einfach beim alten bleiben
    _last_run_check = time.time()

def push(state_text: str) -> None:
    # Erst lokal validieren — falls Lua mitten im Schreiben war,
    # ist die Datei nicht parsebar → diesen Tick überspringen.
    try:
        d = json.loads(state_text)
    except json.JSONDecodeError:
        return
    # Periodisch prüfen, ob sich der aktive Run geändert hat
    if time.time() - _last_run_check > RUN_CHECK_INTERVAL:
        fetch_active_run()
    url = f"{FIREBASE_URL}/{NAMESPACE}/data/{_current_run_id}/autoTeam.json"
    req = urllib.request.Request(
        url, data=state_text.encode("utf-8"), method="PUT"
    )
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            res.read()
        ts = datetime.now().strftime("%H:%M:%S")
        print(f"[{ts}] OK   Run={_current_run_id[-10:]}  Team={d.get('teamCount', '?')}  Map={d.get('mapHeader', '?')}")
    except urllib.error.HTTPError as e:
        print(f"!! Firebase HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        print(f"!! Netzwerk: {e.reason}")
    except Exception as e:
        print(f"!! Fehler: {e}")

def main() -> None:
    print(f"== AutoTracker-Brücke ==")
    print(f"Beobachte:  {STATE_FILE}")
    print(f"Firebase:   {FIREBASE_URL}/{NAMESPACE}/data/<aktiver-run>/autoTeam")
    fetch_active_run()
    print(f"Aktiver Run: {_current_run_id}")
    print("Warte auf das Lua-Skript ... (Strg+C zum Beenden)\n")

    last_mtime = 0.0
    while True:
        try:
            if STATE_FILE.exists():
                mtime = STATE_FILE.stat().st_mtime
                if mtime != last_mtime:
                    last_mtime = mtime
                    # Kurze Verzögerung, damit Lua das Schreiben + Rename
                    # garantiert fertig hat.
                    time.sleep(0.05)
                    try:
                        text = STATE_FILE.read_text(encoding="utf-8")
                        push(text)
                    except FileNotFoundError:
                        pass  # Race-Condition während Rename – nächste Runde
        except KeyboardInterrupt:
            print("\nBrücke gestoppt.")
            return
        except Exception as e:
            print(f"!! Watch-Fehler: {e}")
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
