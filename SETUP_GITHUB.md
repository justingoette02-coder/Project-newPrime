# Compile-Check über GitHub Actions — Schritt für Schritt

Ziel: Du lädst den Code zu GitHub hoch, und GitHub kompiliert die App automatisch. Grüner Haken = alles gut. Roter Haken = Fehler (die kopierst du mir, ich fixe sie). Du brauchst dafür keine Programmierkenntnisse und nichts auf deinem PC zu installieren.

## 1. GitHub-Konto erstellen (falls noch keins)
Geh auf https://github.com → „Sign up" → kostenloses Konto anlegen.

## 2. Neues Repository anlegen
- Oben rechts auf das **+** → **New repository**.
- Name: z.B. `newprime`.
- **Private** auswählen (dein Code bleibt privat).
- **NICHT** „Add a README" ankreuzen (lass es leer).
- **Create repository**.

## 3. Den Code hochladen
- Auf der neuen Repo-Seite: Link **„uploading an existing file"** anklicken
  (oder: Tab **Add file → Upload files**).
- Öffne auf deinem PC den Ordner **`newprime`** (mein Arbeitsordner).
- Markiere **alles darin** (auch die Ordner `lib`, `.github` und die Dateien
  `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`) und **zieh es per Drag & Drop**
  in das GitHub-Upload-Fenster.
  > Wichtig: Der Ordner `.github` muss mit hochgeladen werden — darin steckt die Automatik.
  > Falls dein Datei-Explorer versteckte Ordner (die mit Punkt) ausblendet, schalte
  > „versteckte Dateien anzeigen" ein.
- Unten **Commit changes** klicken.

## 4. Den Compile-Check ansehen
- Geh im Repo auf den Tab **Actions**.
- Du siehst einen Lauf namens **„newPrime CI"**. Er startet automatisch (dauert 2–4 Min).
  - **Grüner Haken** = Code kompiliert sauber. 🎉
  - **Roter Haken** = es gibt Fehler.

## 5. Bei Fehlern (roter Haken)
- Klick den roten Lauf an → klick auf den Schritt **„Analyse"** oder **„Web-Build"**.
- **Kopier den roten/fehlerhaften Text** und schick ihn mir hier im Chat.
- Ich korrigiere den Code, du lädst die geänderten Dateien neu hoch (gleicher Weg wie Schritt 3,
  vorhandene Dateien werden überschrieben), und der Check läuft erneut.

---

### Was die Automatik genau macht
Die Datei `.github/workflows/ci.yml` sagt GitHub: installiere Flutter, erzeuge die Web-Dateien,
lade die Pakete, prüfe den Code (`flutter analyze`) und baue die App (`flutter build web`).
Das ist derselbe Compile, den ich in meiner Sandbox nicht durchführen kann — hier macht ihn GitHub für uns.
