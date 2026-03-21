# Dangerous Balloons

**Dangerous Balloons** is an arcade survival game written in **Ada 2022** using the **ncurses** library. Based on the classic trap-and-destroy mechanics, your goal is to clear a maze of lethal balloons while avoiding being touched by them.

## Gameplay

The game takes place in a 23x23 maze filled with walls, bricks, and deadly balloons. You control a hero who can place bombs to clear paths and destroy enemies.

| Symbol | Name           | Meaning                                        |
|--------|----------------|------------------------------------------------|
| `#`    | Wall           | Indestructible obstacle                        |
| ` `    | Brick          | Destructible wall (colored background)         |
| `@`    | Hero           | Controlled by the player                       |
| `Q`    | Balloon        | Enemy (changes behavior based on mode)         |
| `*`    | Explosion      | Created by bombs; destroys bricks and balloons |
| `X`    | Dead Hero      | Visible during death animation                 |
| `1-5`  | Bomb           | Ticking bomb (number shows remaining seconds)  |

### Rules

- **Movement**: Move in 4 directions using Arrow keys or WASD.
- **Bombs**: Press **Space** to place a bomb at your current position. A maximum of 5 bombs can be active simultaneously.
- **Explosions**: Bombs explode after a 5-second countdown. An explosion affects the bomb's position and adjacent cells (8 directions).
- **Scoring**:
  - Destroying a brick: 10 points.
  - Destroying a friendly balloon (magenta): 50 points.
  - Destroying a hostile balloon (red): 100 points.
- **Balloons**:
  - **Friendly (Magenta)**: Moves randomly every second.
  - **Hostile (Red)**: Actively chases the player.
  - The behavior switches every **8 seconds**.
- **Progression**: Destroy all balloons on the screen to advance to the next level.
- **Lives**: You start with **3 lives**. Touching a balloon or being caught in an explosion loses a life.
- **Levels**: There are **10 levels**. Each level increases the number of initial balloons.

## Controls

| Key               | Action                                 |
|-------------------|----------------------------------------|
| ↑ ↓ ← →           | Move hero                              |
| `W`, `A`, `S`, `D`| Alternative movement                   |
| `Space`           | Place a bomb                           |
| `R`               | Restart current level (lives are kept) |
| `Q`               | Quit game                              |

### Navigation & Menus

| Key               | Action                                 |
|-------------------|----------------------------------------|
| Arrow Keys / WASD | Navigate level selection               |
| `Space` / `Enter` | Start game                             |
| `Q`               | Quit                                   |

## Requirements

- GNAT compiler (Ada 2022 standard)
- GPRbuild
- `ncursesada` library
  - Debian/Ubuntu: `sudo apt-get install libncursesada-dev`

## Build & Run

```bash
gprbuild -P dangerous_balloons.gpr
./bin/dangerous-balloons
```

## Project Structure

```text
dangerous-balloons/
├── dangerous_balloons.gpr   GPRbuild project file
└── src/
    ├── settings.ads         Centralized game settings and constants
    ├── maze.ads/adb         Maze generation logic
    └── main.adb             Main game loop, input, and rendering
```

## Configuration

All game balance parameters and visuals can be tweaked in [`src/settings.ads`](src/settings.ads):

| Constant             | Description                                   |
|----------------------|-----------------------------------------------|
| `Max_Levels`         | Total number of levels (10)                   |
| `Initial_Lives`      | Starting player lives (3)                     |
| `Initial_Balloons`   | Starting number of balloons on Level 1 (4)    |
| `Bomb_Timer_Sec`     | Bomb countdown length (5s)                    |
| `Mode_Switch_Sec`    | Time between balloon behavior swaps (8s)      |
| `Char_Brick`         | Visual representation of destructible blocks  |
| `Player_Death_Ticks` | Duration of the flickering death animation    |

---

*Developed with Gemini as a demonstration of Ada 2022 and modern terminal game architecture.*
