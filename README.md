# BW2-Soullink — Live-Tracker (Trio-Soullink)

Live-Anzeige eines **3-Spieler-Soullinks** in Pokémon Schwarz 2: Teams, PC-Box,
aktueller Gegner (folgt automatisch dem Kampf), Routen und Orden — direkt aus
dem laufenden Spiel.

**Live:** https://fayde420.github.io/BW2-Soullink/

## Mitspielen — Tracker einrichten
Du brauchst: **BizHawk** (melonDS-Core), dein **BW2-ROM**, **Python 3**.

1. Den Ordner **`tracker/`** herunterladen.
2. In der CMD einmalig den Ordner festlegen, dann BizHawk neu starten:
   ```cmd
   setx AUTOTRACKER_DIR "C:\Pfad\zum\tracker"
   ```
3. BizHawk → ROM laden → **Tools → Lua Console** → `live_team.lua` laden.
4. Bridge starten — jeder Spieler seinen Slot:
   - `start_linus.bat` / `start_jonah.bat` / `start_jannik.bat`
     (= `python bridge_trio.py --player linus|jonah|jannik`)
5. Diese Seite öffnen — die Daten erscheinen live.

## Hinweise
- Firebase-DB ist offen (kein Login) — URL nicht breit teilen.
- BW2-ROM & BizHawk sind nicht enthalten.
