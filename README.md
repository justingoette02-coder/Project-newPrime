# Project newPrime — MVP (Phase 4)

Erste lauffähige Basis-Version. Läuft komplett lokal (kein Internet/Backend nötig), damit du den Kern sofort testen kannst. Supabase-Sync wird im nächsten Schritt angedockt.

## Was drin ist

- **Home-Dashboard**: Aura-Orb mit Level, Rang-Badge, XP-Leiste, Streak, Aura-Stufe, heutiges Workout, Wochenvolumen.
- **Workout-Tracking**: Sätze loggen (Gewicht / Wdh / RPE), Aufwärmsätze separat, Pause-Timer, Satz abhaken (mit Haptik am Handy).
- **Gamification-Logik**: Streak-basierte Aura-Stufen (Flacker → Sovereign), XP/Level, Double-Progression-Vorschlag, PR-Erkennung → „Boss-Moment".
- **Default-Template**: Upper/Lower 4× mit gemischten Wdh-Bereichen.

Die animierten Anime-Augen sind noch ein Platzhalter (pulsierender Aura-Ring in der Stufen-Farbe). Die echten Rive-Assets kommen, sobald wir den Augen-Stil final fixiert haben.

---

## So testest du es (Schritt für Schritt, ohne Vorkenntnisse)

### 1. Flutter installieren (einmalig, ~20–30 Min)
Folge der offiziellen Anleitung: https://docs.flutter.dev/get-started/install
Wähle dein Betriebssystem. Installiere am besten auch **VS Code** + die Erweiterung „Flutter".

Prüfen, ob alles passt — im Terminal:
```
flutter doctor
```

### 2. Basis-Projekt erzeugen
Flutter braucht ein paar Plattform-Dateien (Android/iOS/Web), die nicht mitgeliefert sind. Erzeuge daher zuerst ein leeres Projekt:
```
flutter create newprime_app
```

### 3. Meinen Code einsetzen
Ersetze im neu erzeugten Ordner `newprime_app`:
- den Ordner **`lib/`** komplett durch den `lib/`-Ordner aus diesem Paket,
- die Datei **`pubspec.yaml`** durch die aus diesem Paket.

(Die Datei `supabase_schema.sql` und `BAUPLAN.md` brauchst du zum Testen nicht — die sind für später.)

### 4. Pakete laden
Im Ordner `newprime_app`:
```
flutter pub get
```

### 5. Starten
Am einfachsten im Browser (kein Handy nötig):
```
flutter run -d chrome
```
Oder auf einem angeschlossenen Handy / Emulator:
```
flutter run
```

> Hinweis: Die volle Anime-Wucht (hohe Framerate, Haptik beim Abhaken) erlebst du auf einem echten Handy. Chrome ist nur zum schnellen Durchklicken des Ablaufs.

---

## Was du ausprobieren kannst

1. **Dashboard ansehen** — Level 5, Streak 12 (Aura-Stufe „Glut"), Wochenvolumen aus Demo-Daten.
2. **„Session starten"** tippen → du landest im Workout „Upper A".
3. Bei **Schrägbankdrücken** siehst du oben einen **Progression-Vorschlag** (aus den Demo-Daten berechnet).
4. **Gewicht/Wdh/RPE eintragen**, den Kreis rechts antippen → Satz erledigt, **Pause-Timer** startet (Haptik am Handy).
5. „W"/Zahl links antippen → schaltet einen **Aufwärmsatz** um (zählt nicht ins Volumen).
6. Oben rechts **„Fertig"** → Belohnungs-Dialog mit **+XP, Streak, evtl. Level-Up und PR/Boss-Moment**.
   - Tipp: Trag bei einer Übung ein deutlich höheres Gewicht ein als in den Demo-Daten (z.B. Schrägbankdrücken 90 kg × 8) → du löst einen **PR / Boss-Moment** aus.

---

## Projektstruktur

```
lib/
  main.dart                 App-Einstieg, Theme + Provider
  theme/app_theme.dart      Dark-Mastermind Farben & Theme
  models/models.dart        Datenmodelle (Program/Session/Exercise/Set)
  data/templates.dart       Upper/Lower 4x Standard-Template
  services/
    gamification.dart       Aura-Stufen, XP/Level, Progression, PR
    app_state.dart          Zentraler Zustand + Logik (lokal)
  screens/
    home_screen.dart        Dashboard
    workout_screen.dart     Aktives Workout-Tracking
  widgets/
    aura_orb.dart           Aura-Platzhalter (später Rive)
    set_row.dart            Eingabezeile pro Satz
```

## Nächste Schritte (Phase 4, Iteration 2)
- Supabase anbinden (Login + Cloud-Sync, Schema liegt bei).
- Lokale Persistenz, damit Daten App-Neustarts überleben.
- Eigener Split-Builder (Templates manuell erstellen).
- Echte Rive-Augen einbinden (sobald Stil fixiert).
