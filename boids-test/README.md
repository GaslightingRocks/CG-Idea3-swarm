# Swarm-Prototyp „Boids mit Individuen“

Spielbarer Prototyp für das Spielgefühl unserer Idee: Der Spieler lenkt einen Boid-Schwarm per Maus durch eine Höhle, schützt ihn vor Jägern und bringt möglichst viele Boids ins Ziel. Jeder Boid ist ein eigenes Objekt mit eigenen Werten (Mut, Zustand, Schwarm-Zugehörigkeit), keine anonyme Masse.

Grafik, Sound, Menüs und Animationen sind bewusst minimal (Dreiecke, Polygone, Labels).

## Starten

- **Godot 4.7** (Standard- oder .NET-Version, der Prototyp ist reines **GDScript**, kein C#)
- In Godot `boids-test/project.godot` importieren, mit **F5** starten (Hauptszene `game/game.tscn`)
- Vorher `git lfs pull`, sonst fehlen die Bilder in `assets/`

## Steuerung

| Eingabe | Wirkung |
|---|---|
| **Maus** | Richtung von der Bildschirmmitte zur Maus = Richtung, in die der Schwarm gezogen wird (Maus auf der Mitte = Schwarm fliegt frei) |
| **Mausrad** | Stärke der Kraft in 10-%-Schritten (0–100 %, Start 60 %) |
| **Leertaste** | Fähigkeit *Ausweichen* (kostet Mut) |
| **Linke Maustaste halten** | Fähigkeit *Angriff* (kostet Mut pro Sekunde, endet beim Loslassen) |
| **R** | Runde neu starten |
| **H** | Slider-Panels für alle Tuning-Werte ein-/ausblenden |
| **F3** | Debug-Overlay ein/aus (bleibt nach R an) |

Alle Tasten sind als Input-Actions unter *Projekt → Projekteinstellungen → Eingabe-Zuordnung* hinterlegt.

## Features

### Schwarm
- Klassische Boids: **Alignment, Cohesion, Separation** innerhalb des eigenen Schwarms, plus ein dezenter Dauer-Zug zum Schwerpunkt, damit getrennte Gruppen zurückfinden
- Steering-Modell: Alle Kräfte werden addiert, pro Physik-Schritt begrenzt (`max_steer_force`) und auf konstante Geschwindigkeit normiert, dadurch weiche Kurven
- **Keine Überlappung:** Boids eines Schwarms schieben sich gegenseitig auseinander (runde Hitbox, Radius 5 px)
- **Wände:** Strahlenfächer in Flugrichtung weicht früh aus, zusätzlich verhindert eine harte Kollision das Durchfliegen. An Wänden gleitet der ganze Schwarm zur selben Seite, damit er nicht zerbricht. Wände sind standardmäßig **nicht tödlich** (`lethal_walls` in den Settings schaltet das um)

### Level
- Höhle aus **geglätteten Polygonen** (`LevelWall`): Kollision wird aus dem sichtbaren Polygon erzeugt, Punkte lassen sich direkt im Editor verschieben
- **Startzone** (grün), **Zielzone** (gelb), **Gegnerzone** (rot), **Streunerzonen** (blau), alle auch im Editor sichtbar und per Verschieben/`radius` anpassbar
- Kamera folgt dem Schwerpunkt des Schwarms (Zoom 1,25)

### Jäger (zweiter Schwarm mit eigenem Verhalten)
- 12 rote, größere Jäger (`Hunter` erweitert `Boid`) jagen den nächsten sichtbaren Boid
- Sehen sie keine Beute, steuern sie auf den Schwarm des Spielers zu (`pursue_weight`, 0 = nur herumstreifen)
- Kontakt: Beute-Boid stirbt, Jäger verliert ein Leben (`hunter_lives`, Standard 3) und wird dunkler, danach kurze Pause
- Normale Boids fliehen vor sichtbaren Jägern (`flee_weight`)

### Streuner einsammeln
- Graue, langsamere Boid-Gruppen kreisen um ihre Streunerzone
- Kommt der Schwarm nah genug (`join_radius`), schließen sie sich an, bekommen eine Farbe und folgen ab dann dem Spieler
- Streuner können ebenfalls gejagt werden

### Mut
- **Mut pro Boid** (0–1): steigt, solange der Boid in einer Gruppe fliegt (sieht mindestens `courage_group_percent` aller Boids seines Schwarms), sinkt, wenn er allein ist
  - Mutige Boids sind **größer und heller**, ängstliche **kleiner und dunkler**
  - Ängstliche Boids folgen der Maus schwächer (`courage_min_follow`) und halten mehr Abstand zu Wänden (`courage_wall_caution`)
- **Mut-Vorrat** (Float, oben in der Mitte): die Währung für Fähigkeiten. Füllt sich langsam (`courage_fill_rate`), aber nur, solange mindestens `courage_min_group_share` der Boids in Gruppen fliegen. Sonst zeigt das HUD „(Schwarm zu verstreut)“. Das Spiel belohnt also, den Schwarm zusammenzuhalten

### Fähigkeiten (kosten Mut)
- **Ausweichen** (Leertaste, 10 Mut): Der ganze Schwarm sprintet 0,6 s mit doppeltem Tempo in Mausrichtung, Jäger können in der Zeit niemanden erwischen. Boids werden halb durchsichtig
- **Angriff** (Linksklick halten, 5 Mut + 12 Mut/s): Der Schwarm stößt geschlossen auf den nächsten Jäger vor, fliegt 1,7× schneller und lenkt 3× schärfer. Jeder Kontakt kostet den Jäger ein Leben und schleudert ihn zurück, der Boid überlebt, die Kamera wackelt. Boids leuchten orange. Loslassen beendet den Angriff sofort, danach zieht sich der Schwarm 1,5 s lang stark zusammen

### HUD und Runde
- Oben rechts: unterwegs / gerettet / verloren / Jäger / Streuner
- Oben Mitte: Mut-Vorrat, Mitte: Kraft-Anzeige (Ring = Stärke, Pfeil = Richtung), unten: Fähigkeiten mit Kosten
- Runde endet, wenn kein Boid mehr unterwegs ist: „Runde vorbei: X von Y gerettet“

### Tuning und Debug
- **Alle Verhaltenswerte** stehen in `BoidSettings`-Resources: `flock/default_boid_settings.tres` (Spieler), `flock/enemy_boid_settings.tres` (Jäger). Im Inspector dauerhaft ändern, mit **H** live per Slider (live-Änderungen werden nicht gespeichert, „Reset“ stellt den Rundenstart wieder her)
- Fähigkeiten: Inspector von `PlayerAbilities`, Steuerung: `PlayerInfluence`, Kamera: `Camera2D`
- **F3-Overlay:** Sichtradien, Geschwindigkeit (grün), Flocking (blau), Spielerkraft (weiß), Wände (orange), Fliehen/Jagen (pink), Schwerpunkte (gelb), FPS, Physik-/Prozesszeit und Zähler pro Schwarm. Die Kamera zoomt dabei auf den ganzen Level heraus

## Projektstruktur

```
boids-test/
├── assets/          Bilder (Git LFS): Tileset nur noch für level_1, Icon
├── game/            game.tscn (Hauptszene) + game.gd: Level, Schwärme, Kamera, UI, Rundenlogik
├── flock/           boid.gd/.tscn (Individuum), hunter.gd/.tscn (Jäger), flock.gd (Schwarm),
│                    boid_settings.gd + .tres (Tuning-Werte)
├── levels/          level_2.tscn (gespieltes Level), level_1.tscn (alt, Tiles), level.gd,
│                    level_wall.gd, start_zone.gd, goal_zone.gd, stray_zone.gd
├── player/          player_influence.gd (Maus → Kraft), player_abilities.gd, swarm_camera.gd
├── ui/              hud.gd, influence_indicator.gd, boid_settings_panel.gd
└── debug/           debug_overlay.gd
```

Architektur in Kürze:
- `Boid` hat pro Individuum: Geschwindigkeit, Zustand (fliegt / gerettet / verloren), Mut, Schwarm-Zugehörigkeit. Alle Nachbarn werden pro Physik-Schritt in **einem** Durchlauf ausgewertet (Performance)
- `Flock` ist ein wiederverwendbarer Node: eigene Boid-Szene, Farbe, Settings. Spieler-Schwarm, Jäger und jede Streunergruppe sind je ein Flock
- Neue Boid-Typen: Skript von `Boid` ableiten und `scan_other()` / `behavior_force()` überschreiben (siehe `hunter.gd`)
- Neues Level: `level_2.tscn` duplizieren, Polygone und Zonen bearbeiten, in `game.tscn` als `Level` einsetzen

## Was noch fehlt / bekannte Baustellen

**Inhalt und Spielablauf**
- Nur **ein spielbares Level**. `level_1.tscn` ist noch aus Pixel-Tiles und hat keine Zonen, kein Level-Wechsel, kein Menü
- Kein Ziel über „X von Y gerettet“ hinaus (keine Wertung, kein Zeitlimit, kein Fortschritt)
- Kein Bezug zum Theme **„Fractured Gravity“**: Die Spielerkraft ist bisher eine einfache Zugrichtung, keine Gravitation mit Brüchen, Zonen oder Ähnlichem
- Mut-Kosten, Fähigkeiten und Jäger sind nur grob ausbalanciert

**Technik**
- Performance nicht systematisch gemessen. Bei 100+ Boids im dichten Schwarm kann es noch ruckeln, F3 zeigt FPS und Physikzeit
- Einige Werte sind noch Konstanten im Code statt im Inspector: Rückstoß der Jäger, Pause nach Treffer, Stärke des Kamera-Wackelns, Anzahl der Wand-Strahlen, Hitbox-Radius
- Slider-Änderungen gelten nur bis zum Neustart, gute Werte müssen von Hand in die `.tres` übernommen werden
- Live-Änderung von `hunter_lives` wirkt erst auf neu gespawnte Jäger, Streuner bekommen beim Rundenstart eine Kopie der Spieler-Settings
- Kamera hat keine Begrenzung auf den Level-Rand
- Repo-Aufbau: Der Prototyp liegt in `boids-test/`, das leere C#-Projekt `Idea3Prototype/` wird nicht genutzt. Die Root-README beschreibt noch das .NET-/C#-Setup. Hier muss das Team entscheiden, wo es weitergeht

**Optik und Feedback**
- Keine Partikel, Sounds oder Animationen (z. B. beim Tod eines Boids, bei Treffern, beim Einsammeln)
- Unbenutztes Asset `assets/triangle-png-28.png` (Boids sind jetzt Polygone)
