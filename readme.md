# <Game name>

Team project in the course _Computer Games & Visual Effects_ (University of Tübingen, winter term 26/27) · Theme: **Fractured Gravity**

> **Engine:** Godot **4.7.2-stable .NET** (GDScript + C#)
> **.NET SDK:** 8.x
> **Renderer:** <Forward+ / Mobile / Compatibility>

> **Current state:** The playable swarm prototype lives in [`boids-test/`](boids-test/README.md) (pure GDScript, Godot 4.7). Controls, features and what's still missing are described there. `Idea3Prototype/` is an empty project skeleton so far.

---

## 1. Once per computer: requirements

### 1.1 Install Git + Git LFS

| System                | Command / download                                                                                         |
| --------------------- | ---------------------------------------------------------------------------------------------------------- |
| Windows               | Install [Git for Windows](https://git-scm.com/download/win) (includes Git LFS and Git Credential Manager) |
| macOS                 | `brew install git git-lfs`                                                                                 |
| Linux (Debian/Ubuntu) | `sudo apt install git git-lfs`                                                                             |

Then run this **once** in a terminal:

```bash
git lfs install
```

Without this step, images, sounds and models only arrive as small text files and the project is broken.

**Git 2.45.2 or newer** (check with `git --version`). Older versions abort when cloning repos that use LFS (see [Common problems](#5-common-problems)). Updating on Windows:

```bash
git update-git-for-windows
```

### 1.2 Set your Git identity

```bash
git config --global user.name  "First Last"
git config --global user.email "your-github-mail@example.com"
```

The email should match your GitHub account, otherwise your commits aren't attributed to you (important for the peer review).

### 1.3 GitHub access

1. Accept the invitation to the organization / repo (email or github.com → Notifications)
2. Set up authentication for Git, **one** of these options:
   - **Windows:** do nothing, the Git Credential Manager opens in the browser on your first `git push`
   - **macOS/Linux:** install the [GitHub CLI](https://cli.github.com/) and run `gh auth login`
   - alternatively an SSH key ([guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh))

Your GitHub password does **not** work for `git push` over HTTPS.

### 1.4 Install the .NET SDK

- Install the **.NET 8 SDK (64-bit)** from <https://dotnet.microsoft.com/download/dotnet/8.0>
  - macOS: alternatively `brew install --cask dotnet-sdk@8`
  - Linux: package `dotnet-sdk-8.0` (name depends on the distribution)
- Check in a terminal:
  ```bash
  dotnet --list-sdks     # must contain an 8.x line
  ```
- Newer SDKs may be installed **in addition**. Godot 4.7 builds against .NET 8 though, so 8.x has to be there

### 1.5 Install Godot 4.7.2 .NET

- Download **only** from the official archive: <https://godotengine.org/download/archive/> → **4.7.2-stable** → **".NET"** variant for your system
- **Not** the standard version: it can't run C#
- **Don't** install via Steam, itch.io or a package manager: they update automatically to newer versions, and then Godot changes project files when opening them
- All of us must run **exactly** the same version. Updates only after agreeing on them in the team
- Check: _Help → About Godot_ shows `v4.7.2.stable.mono.official`

Optional (only needed for builds): export templates 4.7.2 **.NET** via _Editor → Manage Export Templates → Download and Install_.

### 1.6 Code editor for C# (recommended)

One of these:

- **VS Code** + the extensions _C# Dev Kit_ and _godot-tools_
- **JetBrains Rider** (free for students)
- **Visual Studio** (Windows only)

Then in Godot: set _Editor → Editor Settings → Dotnet → Editor → External Editor_ to your editor.

### 1.7 Only for C++ (GDExtension), once we need it

Anyone writing C++ code additionally needs Python 3, SCons (`pip install scons`) and a C++ compiler (Windows: Visual Studio Build Tools with "Desktop development with C++", macOS: `xcode-select --install`, Linux: `gcc`/`clang`). Everyone else does **not** need this, the precompiled libraries are in the repo.

---

## 2. Clone and open the project

Always use the **HTTPS** URL, not `git@github.com:…`. Over SSH the LFS download often fails on Windows, even if the clone itself works.

```bash
git clone https://github.com/GaslightingRocks/CG-Idea3-swarm.git
cd CG-Idea3-swarm
git lfs ls-files     # should list assets (once there are any)
```

If the clone ends with `warning: Clone succeeded, but checkout failed.`, do **not** keep working, check [Common problems](#5-common-problems) instead.

1. Start Godot → **Import** → select `project.godot` in the cloned folder
2. On the first start Godot imports all assets, this takes a moment
3. Click **Build** (hammer icon) in the top right to compile the C# code. Errors show up in the _MSBuild_ panel at the bottom
4. **Check:** close Godot, then run `git status`. It must say `nothing to commit, working tree clean`. If not: **don't commit anything**, tell the team instead

---

## 3. Working rules

### Git

- **First `git pull`, then open Godot.** **Close Godot** before pulling or switching branches
- One branch per task: `feature/<short-description>` (e.g. `feature/boid-separation`)
- Changes go into `main` only via **pull request**. `main` must always run
- Commit and merge small and often, that keeps conflicts small
- Always stage everything: `git add -A`, so `.uid` and `.import` files are included

### Godot

- Move or rename files **only in Godot's FileSystem dock**, never in Explorer/Finder
- `.uid` and `.import` files belong in the repo. Don't delete them, don't ignore them
- `.csproj` and `.sln` in the project root belong in the repo too. Changes to them (e.g. NuGet packages) only after agreeing on them
- After every pull with new C# code, click **Build** once before opening scenes
- **Only one person edits a `.tscn` at a time.** Who edits which scene is tracked in the GitHub Project
- For experiments use your own test scene: `levels/sandbox/sandbox_<name>.tscn`
- Change project settings (Input Map, Layer Names, Autoloads) only after agreeing on it, `project.godot` is prone to conflicts

### Code style

- **The default language is GDScript.** C# only for systems that need it (e.g. performance-critical simulation) or where we use C# libraries
- GDScript: **tabs**, files and folders in `snake_case`, nodes in `PascalCase`, static types (`var speed: float = 200.0`)
- C#: 4 spaces, file name = class name in `PascalCase` (`FlockSimulation.cs`), class as `public partial class`
- Tuning values as `@export` or in `.tres` resources, not hardcoded

---

## 4. Project structure

```
assets/        Raw data (art, audio, fonts, shaders), no logic
core/          Autoloads: Events (signal bus), GameState
flock/         Boid system (Flock, BoidSettings, Influencer)
individuals/   Boids split off from the swarm
player/
levels/        Level scenes, sandbox/ for personal test scenes
ui/
tools/         Debug overlays, editor scripts
docs/          Pitch, devlog material (ignored by Godot)
addons/        Third-party plugins
```

---

## 5. Common problems

| Problem                                                                     | Solution                                                                                                                                                                                                 |
| --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Clone aborts: `fatal: active post-checkout hook found during git clone`     | Git version too old (bug in Git ≤ 2.45.1 with LFS). Update Git (`git update-git-for-windows`), delete the folder, clone again                                                                            |
| Clone aborts: `smudge filter lfs failed` … `Permission denied (publickey)`  | Cloned with the SSH URL, LFS can't log in. In the folder: `git remote set-url origin https://github.com/GaslightingRocks/CG-Idea3-swarm.git`, then `git restore --source=HEAD :/` and `git lfs pull` |
| Images/sounds missing or broken, the file contains `version https://git-lfs…` | `git lfs install`, then `git lfs pull`                                                                                                                                                                 |
| Many changed `.uid`/`.tscn` files after opening the project                 | Wrong Godot version or didn't pull before opening. Don't commit, discard the changes (`git restore .`), pull, open again                                                                               |
| `project.godot` changed although nothing was set                            | Check the Godot version (Help → About)                                                                                                                                                                   |
| No **Build** button, C# scripts can't be attached                           | Standard instead of .NET version of Godot installed                                                                                                                                                      |
| Build fails: SDK not found                                                  | Check `dotnet --list-sdks`, install the .NET 8 SDK (64-bit), restart Godot                                                                                                                               |
| Scene reports a missing script after a pull                                 | Click **Build** once                                                                                                                                                                                     |
| Push rejected: `protected branch`                                           | Expected. Merge via branch + pull request                                                                                                                                                                |
| Merge conflict in a `.tscn`                                                 | Don't merge by hand. Pick one version (`git checkout --ours/--theirs <file>`), rebuild the other side's changes in Godot                                                                                |

---

## 6. Contact

- Communication: Discord
- Tasks: GitHub Project (board)
- Setup questions: <Name>
