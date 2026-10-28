# <Spielname>

Teamprojekt im Kurs *Computerspiele & Visual Effects* (Uni Tübingen, WiSe 26/27) · Theme: **Fractured Gravity**

> **Engine:** Godot **4.7.2-stable .NET** (GDScript + C#)
> **.NET SDK:** 8.x
> **Renderer:** <Forward+ / Mobile / Compatibility>

---

## 1. Einmalig pro Rechner: Voraussetzungen

### 1.1 Git + Git LFS installieren

| System | Befehl / Download |
|---|---|
| Windows | [Git for Windows](https://git-scm.com/download/win) installieren (enthält Git LFS und Git Credential Manager) |
| macOS | `brew install git git-lfs` |
| Linux (Debian/Ubuntu) | `sudo apt install git git-lfs` |

Danach **einmal** im Terminal:

```bash
git lfs install
```

Ohne diesen Schritt kommen Bilder, Sounds und Modelle nur als kleine Textdateien an und das Projekt ist kaputt.

### 1.2 Git-Identität setzen

```bash
git config --global user.name  "Vorname Nachname"
git config --global user.email "deine-github-mail@example.com"
```

Die Mail sollte zu deinem GitHub-Account passen, sonst werden Commits nicht dir zugeordnet (wichtig für die Peer-Bewertung).

### 1.3 GitHub-Zugang

1. Einladung zur Organisation / zum Repo annehmen (Mail oder github.com → Notifications)
2. Anmeldung für Git einrichten, **eine** der Varianten:
   - **Windows:** nichts tun, beim ersten `git push` öffnet sich der Git Credential Manager im Browser
   - **macOS/Linux:** [GitHub CLI](https://cli.github.com/) installieren und `gh auth login` ausführen
   - alternativ SSH-Key ([Anleitung](https://docs.github.com/en/authentication/connecting-to-github-with-ssh))

Das GitHub-Passwort funktioniert für `git push` über HTTPS **nicht**.

### 1.4 .NET SDK installieren

- **.NET 8 SDK (64-bit)** von <https://dotnet.microsoft.com/download/dotnet/8.0> installieren
  - macOS: alternativ `brew install --cask dotnet-sdk@8`
  - Linux: Paket `dotnet-sdk-8.0` (Name je nach Distribution)
- Prüfen im Terminal:
  ```bash
  dotnet --list-sdks     # muss eine 8.x-Zeile enthalten
  ```
- Neuere SDKs dürfen **zusätzlich** installiert sein. Godot 4.7 baut aber gegen .NET 8, deshalb muss 8.x vorhanden sein

### 1.5 Godot 4.7.2 .NET installieren

- Download **nur** aus dem offiziellen Archiv: <https://godotengine.org/download/archive/> → **4.7.2-stable** → **„.NET“**-Variante für dein System
- **Nicht** die Standard-Version: Die kann kein C# ausführen
- **Nicht** über Steam, itch.io oder Paketmanager installieren: Die aktualisieren automatisch auf neuere Versionen, und dann ändert Godot beim Öffnen Projektdateien
- Bei uns allen muss **exakt** dieselbe Version laufen. Updates nur nach Absprache im Team
- Kontrolle: *Hilfe → Über Godot* zeigt `v4.7.2.stable.mono.official`

Optional (erst für Builds nötig): Export Templates 4.7.2 **.NET** über *Editor → Manage Export Templates → Download and Install*.

### 1.6 Code-Editor für C# (empfohlen)

Eine der Varianten:
- **VS Code** + Extensions *C# Dev Kit* und *godot-tools*
- **JetBrains Rider** (für Studierende kostenlos)
- **Visual Studio** (nur Windows)

Dann in Godot: *Editor → Editor Settings → Dotnet → Editor → External Editor* auf deinen Editor stellen.

### 1.7 Nur für C++ (GDExtension), erst wenn wir es brauchen

Wer C++-Code schreibt, braucht zusätzlich Python 3, SCons (`pip install scons`) und einen C++-Compiler (Windows: Visual Studio Build Tools mit „Desktop development with C++“, macOS: `xcode-select --install`, Linux: `gcc`/`clang`). Alle anderen brauchen das **nicht**, die fertig kompilierten Bibliotheken liegen im Repo.

---

## 2. Projekt klonen und öffnen

```bash
git clone <repo-url>
cd <repo-ordner>
git lfs ls-files     # sollte Assets auflisten (sobald welche existieren)
```

1. Godot starten → **Import** → `project.godot` im geklonten Ordner auswählen
2. Beim ersten Öffnen importiert Godot alle Assets, das dauert kurz
3. Oben rechts auf **Build** (Hammer-Symbol) klicken, um den C#-Code zu kompilieren. Fehler stehen unten im Panel *MSBuild*
4. **Kontrolle:** Godot schließen, dann `git status` ausführen. Es muss `nothing to commit, working tree clean` erscheinen. Falls nicht: **nichts committen**, sondern im Team melden

---

## 3. Arbeitsregeln

### Git

- **Erst `git pull`, dann Godot öffnen.** Vor Pull oder Branch-Wechsel **Godot schließen**
- Pro Aufgabe ein Branch: `feature/<kurzbeschreibung>` (z. B. `feature/boid-separation`)
- Nach `main` nur per **Pull Request**. `main` muss immer lauffähig sein
- Klein und oft committen und mergen, das hält Konflikte klein
- Immer alles stagen: `git add -A`, damit `.uid`- und `.import`-Dateien mitkommen

### Godot

- Dateien **nur im FileSystem-Dock von Godot** verschieben oder umbenennen, nie im Explorer/Finder
- `.uid`- und `.import`-Dateien gehören ins Repo. Nicht löschen, nicht ignorieren
- `.csproj` und `.sln` im Projekt-Root gehören ebenfalls ins Repo. Änderungen daran (z. B. NuGet-Pakete) nur nach Absprache
- Nach jedem Pull mit neuem C#-Code einmal **Build** klicken, bevor du Szenen öffnest
- **Eine `.tscn` gleichzeitig nur von einer Person bearbeiten.** Wer welche Szene bearbeitet, steht im GitHub Project
- Zum Experimentieren eigene Testszene: `levels/sandbox/sandbox_<name>.tscn`
- Project Settings (Input Map, Layer Names, Autoloads) nur nach Absprache ändern, `project.godot` ist konfliktanfällig

### Code-Stil

- **Standardsprache ist GDScript.** C# nur für Systeme, die es brauchen (z. B. performancekritische Simulation) oder wo wir C#-Bibliotheken nutzen
- GDScript: **Tabs**, Dateien und Ordner in `snake_case`, Nodes in `PascalCase`, statische Typen (`var speed: float = 200.0`)
- C#: 4 Leerzeichen, Dateiname = Klassenname in `PascalCase` (`FlockSimulation.cs`), Klasse als `public partial class`
- Tuning-Werte als `@export` oder in `.tres`-Resources, nicht hardcoden

---

## 4. Projektstruktur

```
assets/        Rohdaten (art, audio, fonts, shaders), keine Logik
core/          Autoloads: Events (Signal-Bus), GameState
flock/         Boid-System (Flock, BoidSettings, Influencer)
individuals/   herausgelöste Boids
player/
levels/        Level-Szenen, sandbox/ für persönliche Testszenen
ui/
tools/         Debug-Overlays, Editor-Skripte
docs/          Pitch, Devlog-Material (von Godot ignoriert)
addons/        Fremd-Plugins
```

---

## 5. Häufige Probleme

| Problem | Lösung |
|---|---|
| Bilder/Sounds fehlen oder sind kaputt, Datei enthält `version https://git-lfs…` | `git lfs install`, dann `git lfs pull` |
| Nach dem Öffnen viele geänderte `.uid`/`.tscn`-Dateien | Falsche Godot-Version oder vor dem Öffnen nicht gepullt. Nicht committen, Änderungen verwerfen (`git restore .`), pullen, neu öffnen |
| `project.godot` geändert, obwohl nichts eingestellt | Godot-Version prüfen (Hilfe → Über) |
| Kein **Build**-Knopf, C#-Skripte lassen sich nicht anhängen | Standard- statt .NET-Version von Godot installiert |
| Build schlägt fehl: SDK nicht gefunden | `dotnet --list-sdks` prüfen, .NET 8 SDK (64-bit) installieren, Godot neu starten |
| Szene meldet fehlendes Skript nach Pull | Einmal **Build** klicken |
| Push abgelehnt: `protected branch` | Normal. Über Branch + Pull Request mergen |
| Merge-Konflikt in einer `.tscn` | Nicht von Hand mischen. Eine Version wählen (`git checkout --ours/--theirs <datei>`), Änderungen der anderen Seite in Godot nachbauen |

---

## 6. Kontakt

- Kommunikation: Discord
- Aufgaben: GitHub Project (Board)
- Setup-Fragen: <Name>