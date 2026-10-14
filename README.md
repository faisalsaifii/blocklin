# Blocklin

A Tetris-like falling-block puzzle game for Android and iOS, built with Godot 4. Open source (MIT).

## Run
1. Install [Godot 4.3+](https://godotengine.org/download).
2. Open this folder as a project and press F5.

Touch: on-screen buttons - < > move (hold to repeat), v soft-drop, ROT rotate, DROP hard-drop.
Desktop: arrows move/soft-drop, Up rotates, Space hard-drops.

## Layout
- `src/core/` – pure game logic (no rendering), easy to test and extend with new mechanics
- `src/main.gd` – rendering and input
- `tests/` – logic tests (add GUT or gdUnit4)

