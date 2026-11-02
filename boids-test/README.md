# Swarm Prototype "Boids as Individuals"

A playable prototype that proves the game feel of our idea: the player steers a swarm of boids through a cave with the mouse, protects it from hunters and tries to bring as many boids as possible to the goal. Every boid is an object of its own with its own values (courage, state, which swarm it belongs to), not an anonymous mass.

Graphics, sound, menus and animations are deliberately minimal (triangles, polygons, labels).

## Running it

- **Godot 4.7** (standard or .NET version, the prototype is pure **GDScript**, no C#)
- Import `boids-test/project.godot` in Godot and press **F5** (main scene `game/game.tscn`)
- Run `git lfs pull` first, otherwise the images in `assets/` are missing

## Controls

| Input | Effect |
|---|---|
| **Mouse** | The direction from the screen center to the mouse is the direction the swarm is pulled in (mouse on the center = the swarm flies freely) |
| **Mouse wheel** | Strength of the pull in 10 % steps (0–100 %, starts at 60 %) |
| **Space** | *Dodge* ability (costs courage) |
| **Hold left mouse button** | *Attack* ability (costs courage per second, ends when released) |
| **R** | Restart the round |
| **H** | Show/hide the slider panels for all tuning values |
| **F3** | Debug overlay on/off (stays on after R) |

All keys are input actions under *Project → Project Settings → Input Map*.

## Features

### Swarm
- Classic boids: **alignment, cohesion, separation** within the own swarm, plus a gentle constant pull toward the swarm's center so separated groups find back together
- Steering model: all forces are added up, limited per physics step (`max_steer_force`) and normalized to a constant speed, which gives smooth turns
- **No overlapping:** boids of a swarm push each other apart (round hitbox, radius 5 px)
- **Walls:** a fan of rays in flight direction makes boids turn away early, a hard collision on top prevents flying through. At walls the whole swarm slides to the same side, so it doesn't break apart. Walls are **not lethal** by default (`lethal_walls` in the settings switches that)

### Level
- Cave made of **smoothed polygons** (`LevelWall`): the collision is built from the visible polygon, points can be moved directly in the editor
- **Start zone** (green), **goal zone** (yellow), **hunter zone** (red), **stray zones** (blue), all visible in the editor and adjustable by moving them or changing `radius`
- The camera follows the swarm's center of mass (zoom 1.25)

### Hunters (second swarm with its own behavior)
- 12 red, bigger hunters (`Hunter` extends `Boid`) chase the nearest boid they can see
- Without prey in sight they head for the player's swarm (`pursue_weight`, 0 = they only roam)
- Contact: the prey boid dies, the hunter loses a life (`hunter_lives`, default 3) and gets darker, then pauses briefly
- Normal boids flee from hunters they can see (`flee_weight`)

### Collecting strays
- Gray, slower groups of boids circle around their stray zone
- When the swarm comes close enough (`join_radius`) they join it, get a color and follow the player from then on
- Strays can be hunted too

### Courage
- **Courage per boid** (0–1): rises while the boid flies in a group (it sees at least `courage_group_percent` of all boids of its swarm), sinks when it's alone
  - Brave boids are **bigger and brighter**, scared ones **smaller and darker**
  - Scared boids follow the mouse less (`courage_min_follow`) and keep more distance to walls (`courage_wall_caution`)
- **Courage pool** (float, top center): the currency for abilities. It fills slowly (`courage_fill_rate`), but only while at least `courage_min_group_share` of the boids fly in groups. Otherwise the HUD shows "(swarm too scattered)". So the game rewards keeping the swarm together

### Abilities (cost courage)
- **Dodge** (Space, 10 courage): the whole swarm dashes in the mouse direction at double speed for 0.6 s, hunters can't catch anyone during that time. Boids turn see-through
- **Attack** (hold left click, 5 courage + 12 courage/s): the swarm charges the nearest hunter as one, flies 1.7× faster and steers 3× sharper. Every contact costs the hunter a life and throws it back, the boid survives, the camera shakes. Boids glow orange. Releasing the button ends the attack at once, then the swarm is pulled together strongly for 1.5 s

### HUD and round
- Top right: flying / saved / lost / hunters / strays
- Top center: courage pool, center: strength indicator (ring = strength, arrow = direction), bottom: abilities with their costs
- The round ends when no boid is flying anymore: "Round over: X of Y saved"

### Tuning and debugging
- **All behavior values** are in `BoidSettings` resources: `flock/default_boid_settings.tres` (player), `flock/enemy_boid_settings.tres` (hunters). Change them permanently in the inspector, or live with sliders via **H** (live changes are not saved, "Reset" restores the values from the start of the round)
- Abilities: inspector of `PlayerAbilities`, steering: `PlayerInfluence`, camera: `Camera2D`
- **F3 overlay:** vision radii, velocity (green), flocking (blue), player force (white), walls (orange), fleeing/chasing (pink), centers of mass (yellow), FPS, physics/process time and counters per swarm. The camera zooms out to the whole level

## Project structure

```
boids-test/
├── assets/          Images (Git LFS): tileset only used by level_1 now, icon
├── game/            game.tscn (main scene) + game.gd: level, swarms, camera, UI, round logic
├── flock/           boid.gd/.tscn (individual), hunter.gd/.tscn (hunter), flock.gd (swarm),
│                    boid_settings.gd + .tres (tuning values)
├── levels/          level_2.tscn (the played level), level_1.tscn (old, tiles), level.gd,
│                    level_wall.gd, start_zone.gd, goal_zone.gd, stray_zone.gd
├── player/          player_influence.gd (mouse → force), player_abilities.gd, swarm_camera.gd
├── ui/              hud.gd, influence_indicator.gd, boid_settings_panel.gd
└── debug/           debug_overlay.gd
```

Architecture in short:
- Each `Boid` has: velocity, state (flying / saved / lost), courage, the swarm it belongs to. All neighbors are evaluated in **one** pass per physics step (performance)
- `Flock` is a reusable node: its own boid scene, color and settings. The player's swarm, the hunters and every stray group are one flock each
- New boid types: extend the `Boid` script and override `scan_other()` / `behavior_force()` (see `hunter.gd`)
- New level: duplicate `level_2.tscn`, edit the polygons and zones, use it as `Level` in `game.tscn`

## What's still missing / known issues

**Content and gameplay**
- Only **one playable level**. `level_1.tscn` is still made of pixel tiles and has no zones, there's no level switching and no menu
- No goal beyond "X of Y saved" (no score, no time limit, no progression)
- No connection to the theme **"Fractured Gravity"** yet: the player's force is a simple pull in one direction, no gravity with fractures, zones or the like
- Courage costs, abilities and hunters are only roughly balanced

**Technical**
- Performance hasn't been measured systematically. With 100+ boids in a dense swarm it may still stutter, F3 shows FPS and physics time
- Some values are still constants in the code instead of inspector values: hunter knockback, pause after a hit, camera shake strength, number of wall rays, hitbox radius
- Slider changes only last until the restart, good values have to be copied into the `.tres` files by hand
- Changing `hunter_lives` live only affects newly spawned hunters, strays get a copy of the player's settings at the start of the round
- The camera isn't limited to the level bounds
- Repo layout: the prototype lives in `boids-test/`, the empty C# project `Idea3Prototype/` isn't used. The root README still describes the .NET/C# setup. The team has to decide where to continue

**Visuals and feedback**
- No particles, sounds or animations (e.g. when a boid dies, on hits, when collecting strays)
- Unused asset `assets/triangle-png-28.png` (boids are polygons now)
