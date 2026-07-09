# GBVSR-LobbyFPSUnlocker

> A [UE4SS](https://docs.ue4ss.com) Lua mod for **Granblue Fantasy Versus: Rising** (Steam, UE 4.27) that unlocks the in-game lobby frame rate.

中文说明请见 [README_CN.md](README_CN.md)。

## What it does

In *Granblue Fantasy Versus: Rising*, the game locks the lobby to **30 FPS** while all other scenes (combat, menus, etc.) run at **60 FPS**. This mod unlocks the lobby so it runs at the same fluid frame rate as the rest of the game.

The game controls frame rate via the fixed-timestep mechanism (`UEngine::bUseFixedFrameRate = true` + `UEngine::FixedFrameRate`). The lobby sets the value to **30**, combat to **60**. `t.MaxFPS` and the smoothed-frame-rate range are *not* used, so changing those cvars has no effect — this mod targets the actual mechanism instead.

## How it works

The mod keeps `bUseFixedFrameRate = true` (turning it off would break game-speed in other scenes) and only changes the `FixedFrameRate` value:

- Lobby sets `FixedFrameRate = 30` → mod detects this and swaps in your **target** value (default `60`).
- Combat sets `FixedFrameRate = 60` → not in the trigger range → **mod does nothing**.
- When you leave the lobby the game itself writes the value back to `60`, so no restoration is needed from our side.

Detection is purely threshold-based: only when `FixedFrameRate` falls within `[25, 35]` (the lobby's original `30 ± 5`) will the mod change it. This means:

- No map-name detection needed (the lobby's `LoadMap`/`InitGameState` hooks do not reliably fire in this game).
- No `GetName()` calls that spam the log with C++ errors.
- No interference with combat scenes.

The whole loop is driven by a `LoopAsync` watchdog that re-checks every `250ms` (configurable), plus a `PostLoadMap` hook for instant response on maps that do trigger it.

## Requirements

- **UE4SS** (v3.0.0+ recommended; tested on v3.0.1 Beta, commit `e39e9c8`).
  The game already has UE4SS if you see `RED\Binaries\Win64\UE4SS.dll`.
- (Optional) **ConsoleEnablerMod** enabled (ships with UE4SS) for the `lobbyfps`
  console commands. The mod unlocks the lobby automatically without it — the
  console commands are only for on-the-fly tuning / inspection.

The latest release on this repo ships a **minimal self-contained zip** that bundles
UE4SS's core DLLs plus this mod (see
[Releases](https://github.com/Butterfly0v0/GBVSR-LobbyFPSUnlocker/releases)). It does
**not** ship the standard UE4SS example mods (`ConsoleEnablerMod`, `BPModLoaderMod`,
dumpers, etc.) — for the full UE4SS feature set, download the complete distribution
from <https://github.com/UE4SS-RE/RE-UE4SS/releases>.

## Installation

### Option A — Minimal release (no UE4SS installed yet)

1. Download the latest `GBVSR-LobbyFPSUnlocker-vX.Y.Z.zip` from the
   [Releases page](https://github.com/Butterfly0v0/GBVSR-LobbyFPSUnlocker/releases).
   It bundles UE4SS v3.0.1 Beta (commit `e39e9c8`) core DLLs + the mod.
2. Locate your game install — usually
   `C:\Program Files (x86)\Steam\steamapps\common\Granblue Fantasy Versus Rising`.
   (In Steam: right-click the game → Manage → Browse local files.)
3. Open the `RED\Binaries\Win64\` sub-folder inside it.
4. Extract **everything** from the zip into that `Win64` folder. After extraction
   you should see these new entries:
   ```
   Win64\
       dwmapi.dll                (UE4SS proxy, auto-loaded by the game)
       UE4SS.dll                 (UE4SS main loader)
       UE4SS-settings.ini
       READ-THIS-FIRST.md        (install guide & troubleshooting)
       Mods\
           mods.txt
           GBVSR-LobbyFPSUnlocker\   <-- the actual mod
   ```
   Note: this minimal package does **not** include the standard UE4SS example mods
   (`ConsoleEnablerMod`, etc.) or runtime caches. The mod still works — it
   automatically unlocks the lobby on entry based on its `config.txt`. The
   `lobbyfps` console commands, however, are unavailable in this minimal package
   (they require `ConsoleEnablerMod`).
5. Launch the game. The mod applies automatically on entering the lobby.

### Want the full UE4SS features?

If you also want the in-game console (`lobbyfps force / restore / reload / list`),
the blueprint mod loader, dumpers, live view, or other UE4SS tools:

1. Download the complete UE4SS distribution from
   <https://github.com/UE4SS-RE/RE-UE4SS/releases> and follow its install guide.
2. Then drop this mod's folder into your `Mods\` directory as in Option B below.

### Option B — You already have UE4SS installed

1. Download the release zip (and only use the `Mods\GBVSR-LobbyFPSUnlocker\` folder
   inside it) **or** clone this repo / grab the `GBVSR-LobbyFPSUnlocker` folder.
2. Copy the mod folder into your UE4SS mods directory:
   ```
   <GBVSR install>\RED\Binaries\Win64\Mods\GBVSR-LobbyFPSUnlocker\
       enabled.txt
       config.txt
       Scripts\main.lua
   ```
3. If your `Mods\mods.txt` exists, add this line (load-order independent):
   ```
   GBVSR-LobbyFPSUnlocker : 1
   ```
4. If your UE4SS setup uses per-mod `enabled.txt` files (already shipped in the mod
   folder), the mod starts automatically — no further action needed.

You do **not** need to overwrite your existing `UE4SS.dll`, `dwmapi.dll`, or
`UE4SS-settings.ini` if you go with Option B.

## Configuration

All settings live in `config.txt` next to the mod. Edit values and either restart the game, or run `lobbyfps reload` in the console (F10) to hot-reload.

| Key                  | Default | Description                                                        |
| -------------------- | ------- | ------------------------------------------------------------------ |
| `target_fps`         | `60`    | Frame rate the lobby will be set to. `60`, `120`, `144`, `240` …   |
| `trigger_fps`        | `30`    | Only changes `FixedFrameRate` when it equals this value (the lobby's original). |
| `trigger_tolerance`  | `5`     | Tolerance around `trigger_fps`. Trigger range = `[trigger_fps - tol, trigger_fps + tol]`. |
| `watchdog_ms`        | `250`   | How often the background poller checks and re-applies the value.   |
| `log_apply`          | `true`  | Print a log line each time the value is actually written.          |

### Quick examples

```ini
; Default: lobby -> 60 FPS
target_fps=60

; High-refresh monitor: lobby -> 144 FPS
target_fps=144
```

## Console commands

Requires ConsoleEnablerMod (F10 opens the console by default).

| Command            | Description                                                                  |
| ------------------ | ----------------------------------------------------------------------------- |
| `lobbyfps`         | Print current status (current `FixedFrameRate`, force flag).                  |
| `lobbyfps force`   | Ignore the threshold check and always write `target_fps` to `FixedFrameRate`. Use only to verify/force. |
| `lobbyfps restore` | Stop forcing (return to threshold-based behavior).                           |
| `lobbyfps reload`  | Re-read `config.txt` without restarting the game.                            |
| `lobbyfps list`    | Dump `Engine.bUseFixedFrameRate` and `Engine.FixedFrameRate`.                |

## How to verify it's working

1. Launch the game and enter the lobby.
2. The lobby should now run at your configured `target_fps` (default 60).
3. Open the console (F10) and type `lobbyfps list` to confirm:
   ```
   Engine:
     bUseFixedFrameRate = true
     FixedFrameRate = 60.0
   ```
4. Enter a fight. It should stay at 60 FPS.
5. Return to the lobby — it should automatically be set back to your target FPS (the game sets 30, the mod swaps to target on the next watchdog tick).

## Folder structure

```
GBVSR-LobbyFPSUnlocker/
├── enabled.txt          # Empty marker file — tells UE4SS to load this mod
├── config.txt           # User-editable settings (see Configuration)
└── Scripts/
    └── main.lua         # The mod logic
```

## Troubleshooting

**Mod doesn't take effect.**
- Open the console (F10) and run `lobbyfps list`. If nothing prints, the mod didn't load — check the `UE4SS.log` file in `RED\Binaries\Win64\`. Confirm `enabled.txt` exists in the mod folder (an empty file suffices) and/or that `GBVSR-LobbyFPSUnlocker : 1` is in `Mods\mods.txt`.
- If `lobbyfps list` prints but `FixedFrameRate` doesn't change, check that `trigger_fps`/`trigger_tolerance` in `config.txt` actually cover the lobby value (default `30 ± 5 = [25, 35]`, which is correct for the base game).

**Game speed seems wrong in combat.**
- The mod only writes `FixedFrameRate` when it's within `[25, 35]` (default). It should not touch combat. If you've misconfigured `trigger_fps` to a value near 60, restore defaults and run `lobbyfps reload`.

**Want to lock a non-standard rate (e.g. 90).**
- Set `target_fps=90` in `config.txt`, run `lobbyfps reload`, done.

**Log spam in `UE4SS.log`.**
- Check it's not another mod (e.g. an old FrameRateDiag). This mod writes no `GetName()` calls and no errors.

## Limitations / Notes

- Uses a relative config path (`Mods/GBVSR-LobbyFPSUnlocker/config.txt`), which relies on UE4SS setting the working directory to the game's `Binaries\Win64` folder. This is the default; if you customized `UE4SS-settings.ini` paths significantly, you can fall back to editing `main.lua`.
- The mod reads/writes only `UEngine::FixedFrameRate` (and `bUseFixedFrameRate` for display only). It never turns fixed-timestep off, never touches smoothed-frame-rate cvars, and never modifies `GameUserSettings`.
- Not network-checked. This is a single-player/visual mod; it changes no gameplay or timing that affects match outcome (it speeds up only the lobby, which has no competitive aspects). Use at your own discretion online.

## License

[MIT](LICENSE). Source code and config provided as-is.

## Acknowledgements

- [UE4SS](https://docs.ue4ss.com) — the framework this mod runs on.
- The diagnostic baseline (that `t.MaxFPS` is ineffective here and `bUseFixedFrameRate` is the actual mechanism) was established with the help of `FrameRateDiag`, which shipped as an example mod in earlier iterations.