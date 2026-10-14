class_name Game
extends RefCounted
## Pure game logic: board, active piece, scoring. No rendering.

signal lines_cleared(count: int)
signal game_over
signal piece_locked(cells: Array, type: String)  # absolute board cells of the piece
signal rows_removed(rows: Array)  # [{y: original row index, row: Array of piece types}]

const COLS := 14
const ROWS := 28
const LINE_SCORES := [0, 100, 300, 500, 800]

var grid: Array = []  # grid[y][x] = "" or piece type
var cur_type := ""
var cur_cells: Array = []  # current offsets
var cur_pos := Vector2i.ZERO
var next_type := ""
var combo := -1  # consecutive locks that cleared lines; -1 = none
var bag: Array = []
var score := 0
var lines := 0
var level := 1
var over := false
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for y in ROWS:
		var row := []
		row.resize(COLS)
		row.fill("")
		grid.append(row)
	next_type = _draw()
	_spawn()

func gravity_interval() -> float:
	return maxf(0.08, 0.8 - (level - 1) * 0.07)

func _draw() -> String:
	if bag.is_empty():
		bag = PieceDefs.types()
		for i in range(bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = bag[i]; bag[i] = bag[j]; bag[j] = t
	return bag.pop_back()

func _spawn() -> void:
	cur_type = next_type
	next_type = _draw()
	cur_cells = PieceDefs.SHAPES[cur_type].duplicate()
	cur_pos = Vector2i(COLS / 2 - 1, 0)
	if not _fits(cur_cells, cur_pos):
		over = true
		game_over.emit()

func _fits(cells: Array, pos: Vector2i) -> bool:
	for c in cells:
		var p: Vector2i = c + pos
		if p.x < 0 or p.x >= COLS or p.y >= ROWS:
			return false
		if p.y >= 0 and grid[p.y][p.x] != "":
			return false
	return true

func move(dx: int) -> bool:
	if over: return false
	if _fits(cur_cells, cur_pos + Vector2i(dx, 0)):
		cur_pos.x += dx
		return true
	return false

func rotate() -> bool:
	if over or cur_type == "O": return false
	var rotated := []
	for c in cur_cells:
		rotated.append(Vector2i(-c.y, c.x))
	for kick in [0, -1, 1, -2, 2]:
		var p := cur_pos + Vector2i(kick, 0)
		if _fits(rotated, p):
			cur_cells = rotated
			cur_pos = p
			return true
	return false

## Returns true if the piece moved down, false if it locked.
func step() -> bool:
	if over: return false
	if _fits(cur_cells, cur_pos + Vector2i(0, 1)):
		cur_pos.y += 1
		return true
	_lock()
	return false

func hard_drop() -> void:
	if over: return
	var dist := 0
	while _fits(cur_cells, cur_pos + Vector2i(0, 1)):
		cur_pos.y += 1
		dist += 1
	score += dist * 2
	_lock()

func ghost_pos() -> Vector2i:
	var p := cur_pos
	while _fits(cur_cells, p + Vector2i(0, 1)):
		p.y += 1
	return p

func _lock() -> void:
	var placed := []
	for c in cur_cells:
		var p: Vector2i = c + cur_pos
		if p.y >= 0:
			grid[p.y][p.x] = cur_type
			placed.append(p)
	piece_locked.emit(placed, cur_type)
	_clear_lines()
	_spawn()

func _clear_lines() -> void:
	var cleared := 0
	var removed := []
	var y := ROWS - 1
	while y >= 0:
		if not grid[y].has(""):
			removed.append({"y": y - cleared, "row": grid[y].duplicate()})
			grid.remove_at(y)
			var row := []
			row.resize(COLS)
			row.fill("")
			grid.push_front(row)
			cleared += 1
		else:
			y -= 1
	if cleared == 0:
		combo = -1
	else:
		combo += 1
		score += LINE_SCORES[cleared] * level + 50 * combo * level
		lines += cleared
		level = 1 + lines / 10
		rows_removed.emit(removed)
		lines_cleared.emit(cleared)
