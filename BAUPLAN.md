# Project newPrime — Bauplan (Master-Spec)

Stand: Phase 4, Start der Implementierung. Dieses Dokument hält alle Entscheidungen aus Phase 1–3 fest und ist der verbindliche Bauplan für die App.

---

## 1. Vision

Eine Trainings-Tracking-App für Hypertrophie & Kraft, die wissenschaftlich fundiertes Tracking mit einer süchtig machenden, Anime-inspirierten „Dark Mastermind"-Ästhetik verbindet. Der Nutzer soll sich fühlen, als würde er sich zu einem physisch wie mental übermächtigen Charakter hochleveln (Energie: Gojo + Intellekt: Johan Liebert). Disziplin und Konsistenz stehen im Zentrum.

---

## 2. Tech-Stack

- **Framework:** Flutter (Dart) — native Performance, hohe Framerate (Ziel bis 120 fps), eine Codebasis für iOS & Android.
- **Animation:** Rive — für die animierten Aura-Augen und cineastische Level-Up-/PR-Sequenzen.
- **Backend/Sync:** Supabase — Datenbank, Auth, Sync. Wird nach dem lokalen MVP angedockt.
- **Lokaler Speicher (MVP):** In-Memory/Local-Store zuerst, damit die App sofort offline läuft. Supabase als spätere Sync-Schicht.

---

## 3. Design: „Dark Mastermind"

- **Prinzip:** Ruhe statt Lärm. Fast-schwarze Bühne, EINE kühle Akzentfarbe (Aura-Blau/Violett), viel Leere, strenge Hierarchie (pro Screen ein Held-Element). Macht zeigt sich durch Reduktion. Die seltenen cineastischen Momente (Level-Up, PR) wirken dadurch umso wuchtiger.
- **Farbwelt:** Near-Black Hintergrund (#0A0A0F), Surfaces (#13131A), Aura-Akzent kühles Violett→Blau (#7F77DD / #378ADD), Streak-Akzent (kühles Cyan). Eskalation der Aura immer im kühlen Spektrum; „Feuer" = blaue Flamme, niemals orange.
- **Signatur-Element:** Animierte Anime-Augen als Visualisierung der Aura (siehe Abschnitt 5).

---

## 4. Gamification (Streak-zentriert)

Die **Streak (Konsistenz) ist das Rückgrat** der App — wichtiger als Einzelrekorde, passend zur Disziplin-Philosophie.

Vier ineinandergreifende Dopamin-Schleifen:

1. **Mikro-Reward (pro Satz):** sofortiges haptisches Feedback + sichtbares XP-Füllen beim Abschließen eines Satzes.
2. **Tägliche Schleife (Streak + Aura):** Konsistenz lässt die Aura „lauter" werden; Pause lässt sie verblassen (Verlustangst als stärkster Hebel).
3. **Mittelfristig (Progression):** Auto-Progression schlägt minimal mehr vor; das alte Ich schlagen gibt Level-XP.
4. **Seltene Eskalation (Boss-Moment):** echter PR löst eine cineastische Anime-Sequenz aus (Rive).

Zusätzlich: **Rang-System E→S** als ferner Horizont. Belohnung ist immer an reale Leistung gekoppelt, nie an bloßes Einloggen.

**Verlust-Mechanik (fair):** Ausgelassener Tag → Aura wird zunächst nur trüb (sichtbare Warnung). Ein Schutz-/Gnadentag pro Woche verhindert echten Verlust (Krankheit). Erst längeres Aussetzen lässt eine Aura-Stufe absteigen.

---

## 5. Aura-Augen (6 Stufen, nach Streak)

| Stufe | Name | Streak | Rang | Optik |
|------|------|--------|------|-------|
| 1 | Flacker | Tag 1–6 | E | gedämpft, grau-blau, leichter Nebel |
| 2 | Glut | Tag 7–20 | D | klareres Blau, sanftes Leuchten |
| 3 | Fokus | Tag 21–45 | C | Stern-Burst in der Iris |
| 4 | Durchbruch | Tag 46–89 | B | Energie-Ring, erste blaue Flammen |
| 5 | Flow-State | Tag 90–179 | A | spiralende blaue Flammen (Blue-Lock) |
| 6 | Sovereign | Tag 180+ | S | kosmischer Mechanismus, kühle Flamme, Glitch |

**Status Assets:** Die finalen Augen werden als handgezeichnete Illustrationen (PNG-Quelle) erstellt und in Rive animiert (.riv im App-Einsatz, WebP als statischer Fallback). Art-Briefs liegen vor. OFFEN: einheitlicher Master-Stil + Intensitäts-Kurve müssen noch fixiert werden (geparkt). Im MVP: Platzhalter-Aura-Widget, das die Stufe korrekt anzeigt.

---

## 6. Datenmodell

Verschachtelte Hierarchie:

```
Programm (dein Split)
  Session / Trainingstag (z.B. "Upper A")
    Uebung (z.B. Schraegbankdruecken)
      Satz  <- Kern-Einheit
```

Jeder **Satz** speichert: Gewicht (kg), Wiederholungen, RPE/RIR, Pausenzeit, Tempo/Notizen, Flag „Aufwärmsatz". Jeder abgeschlossene Satz wird mit Datum/Zeit gespeichert → vollständige Historie. Daraus berechnet die App automatisch Progression und Volumen/Tonnage pro Muskelgruppe.

---

## 7. Tracking-Defaults (Justins Vorlieben)

- **Satz-Felder:** Gewicht + Wiederholungen (immer), RPE/RIR, Pausenzeit, Tempo/Notizen (aufklappbar, damit Eingabe schnell bleibt).
- **Wiederholungsbereich:** gemischt je Übung (schwer bei Grundübungen, leichter bei Isolation).
- **Progression:** Double Progression als Standard.
- **Einheit:** Kilogramm.
- **Aufwärmsätze:** separat, zählen nicht ins Arbeitsvolumen.
- **PR-Erkennung:** an (löst Boss-Moment aus).
- **Frequenz:** 4×/Woche (Upper/Lower je 2×).

---

## 8. MVP-Umfang (diese Phase)

1. Projektgerüst (Flutter) + Dark-Mastermind-Theme.
2. Datenmodelle + Default-Template „Upper/Lower 4×".
3. Gamification-Logik: Streak, XP/Level, Aura-Stufe, Double-Progression-Vorschlag, PR-Erkennung.
4. Home-Dashboard (Level/XP/Streak/Aura/heutiges Workout).
5. Aktiver Workout-Screen (Sätze loggen mit Gewicht/Wdh/RPE/Pause/Tempo).
6. Lokaler Speicher; Supabase-Anbindung als nächster Schritt.

**Bewusst noch NICHT im MVP:** echte Rive-Augen-Assets, Cloud-Sync, Social/Ränge-Vergleich, vollständige Statistik-Charts. Folgt iterativ.
