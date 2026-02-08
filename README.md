# Dr. Mario (MIPS Assembly)

A Dr. Mario–style falling-capsule puzzle game implemented in **MIPS assembly**, featuring **memory-mapped keyboard input** (polling) and **bitmap display rendering** on a **32×32 grid** (256×256 pixels with 8×8 units). Includes basic movement/rotation, landing + locking into a board grid, match clearing, simple sound effects, and a game-over + retry flow.

## Features
- **Real-time game loop** (~60 FPS using `syscall 32` sleep)
- **MMIO keyboard input (polling)**
  - Reads key-ready flag at `0xffff0000`
  - Reads ASCII key code at `0xffff0004`
- **Bitmap display rendering**
  - Base address `0x10008000`
  - 32×32 “units” in row-major order
- **Capsule mechanics**
  - Two-halved capsule (horizontal/vertical orientation)
  - Controls:
    - `A` / `D`: move left/right
    - `W`: rotate 90°
    - `S`: move down
    - `Q`: quit
- **Board/grid state**
  - `board` is a 32×32 grid in memory (4 bytes per cell)
  - `0` = empty, `9` = wall, otherwise stores 24-bit RGB color values
- **Landing & locking**
  - When the active capsule collides with bottom / existing blocks, it is written into `board`
  - A new capsule is spawned at the entrance
- **Match clearing**
  - Detects and clears vertical 4-in-a-row matches (board update + screen clear)
- **Sound effects**
  - Plays a short tone on movement/rotation (MARS/Saturn MIDI syscall)
- **Game over + retry**
  - Entrance blocked ⇒ displays a red “X”
  - Press `r` to reset and restart

## Controls
| Key | Action |
|---|---|
| `W` | Rotate capsule |
| `A` | Move left |
| `S` | Move down |
| `D` | Move right |
| `Q` | Quit |
| `R` | Retry after Game Over |

## Display Configuration (Bitmap)
Use these settings in your Bitmap Display tool:
- Unit width: **8**
- Unit height: **8**
- Display width: **256**
- Display height: **256**
- Base address: **0x10008000**

## How It Works (High-Level)
- The game maintains a **persistent board** (`board`) for walls, viruses, and locked capsules.
- The **active capsule** is tracked by `(capsule_x, capsule_y, capsule_orientation)` and drawn directly to the display each frame.
- Each frame:
  1. Erase previous capsule tiles (paint background)
  2. Poll keyboard MMIO and update capsule state
  3. Draw capsule at new state
  4. Check landing → lock into `board` → spawn new capsule
  5. Run match clearing
  6. Sleep ~16ms and repeat

## Notes / Known Limitations
- Match clearing currently focuses on **vertical** 4-in-a-row detection.
- Gravity / unsupported-piece falling can be extended for more accurate Dr. Mario behavior.

## Repository Layout
- `DrMario.asm` — main MIPS assembly source (game logic + drawing + input)

## Credits
- Original game concept: **Nintendo** (Dr. Mario, 1990).
- This repository is a from-scratch MIPS implementation inspired by the classic falling-capsule puzzle gameplay.

