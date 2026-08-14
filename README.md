# BW2-Soullink — Live-Tracker (Trio-Soullink)

Live-Anzeige eines **3-Spieler-Soullinks** in Pokémon Schwarz 2: Teams, PC-Box,
aktueller Gegner (folgt automatisch dem Kampf), Routen und Orden — direkt aus
dem laufenden Spiel.

**Live:** https://fayde420.github.io/BW2-Soullink/  (Passwort erforderlich)

## Schnellstart: Tracker-Starter

Ein Programm für alles — **kein Python nötig**:

**[⬇ BW2-Tracker-Starter.exe herunterladen](https://github.com/Fayde420/BW2-Soullink/releases/latest/download/BW2-Tracker-Starter.exe)**

Modus wählen, ROM wählen, **Starten** — es öffnet BizHawk mit Lua und
übernimmt die Übertragung selbst. Die Einrichtung steht auf der
[Release-Seite](https://github.com/Fayde420/BW2-Soullink/releases/latest).

Die Schritte unten brauchst du nur, wenn du es lieber von Hand machst.

## Mitspielen — Tracker einrichten
Du brauchst: **BizHawk** (melonDS-Core), dein **BW2-ROM**, **Python 3**.

1. Den Ordner **`tracker/`** herunterladen.
2. *(Meist überflüssig — nur prüfen!)* Beim Laden des Lua-Skripts zeigt die
   BizHawk-Konsole `state.json → <Ordner>`. Zeigt sie **deinen tracker-Ordner**,
   ist nichts weiter zu tun. Nur falls dort ein falscher Pfad steht: einmalig
   festlegen (Pfad anpassen!) und danach CMD **und** BizHawk neu starten:
   ```cmd
   setx AUTOTRACKER_DIR "C:\Pfad\zum\tracker"
   ```
3. BizHawk → ROM laden → **Tools → Lua Console** → `live_team.lua` laden.
4. Bridge starten — jeder Spieler seinen Slot:
   - `start_spieler1.bat` / `start_spieler2.bat` / `start_spieler3.bat`
     (= `python bridge_trio.py --player spieler1|spieler2|spieler3`)
   - Wer welcher Spieler ist, stellst du auf der Seite ein:
     Run Übersicht → Ordner wählen → Spielernamen.
   - Die alten `start_linus.bat` usw. funktionieren weiter und starten
     denselben Slot.
5. Diese Seite öffnen (Passwort eingeben) — die Daten erscheinen live.

## Hinweise
- Firebase-DB ist offen (kein Login) — URL nicht breit teilen.
- BW2-ROM & BizHawk sind nicht enthalten.
