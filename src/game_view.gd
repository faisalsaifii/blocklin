class_name GameView
extends Node2D
## In-game screen: board, side panels, on-screen controls, pause and game over.

signal started
signal menu_requested
signal score_changed(score: int)

const MARGIN := 10.0
const GAP := 10.0
const BOARD_PAD := 0.0  # side space around the board; 0 = edge to edge
const BAR_H := 52.0  # top bar: score, level, next, pause
const SCORE_W := 118.0
const LEVEL_W := 76.0
const NEXT_W := 84.0
const MIN_BTN_H := 60.0
const MAX_BTN_H := 76.0
const HINT_H := 22.0

# On-screen buttons, left to right: name -> repeats_when_held
const BUTTONS := {"left": true, "right": true, "down": true, "rotate": false, "drop": false}
const REPEAT_DELAY := 0.18
const REPEAT_RATE := 0.06

# Layout, recomputed from the viewport by _relayout() (local coordinates).
var cell := 36.0
var board_origin := Vector2.ZERO
var board_size := Vector2.ZERO
var pause_btn := Rect2()
var btn_rects := {}  # name -> Rect2
var next_rect := Rect2()
var score_rect := Rect2()
var level_rect := Rect2()
var _layout_key := []

var game: Game
var paused := false
var timer := 0.0
var flash := 0.0
var held := {}  # touch index -> {"name": String, "t": float}
var gesture := {}  # active gesture touch: index, anchor, start, t, moved
var overlay := PauseOverlay.new()

# Animation state (view only)
const CLEAR_NAMES := ["", "SINGLE", "DOUBLE", "TRIPLE", "BLOCKLIN"]
var anim_t := 0.0
var particles: Array = []  # {pos, vel, life, max, size, col}
var row_flashes: Array = []  # {y, t}
var lock_glows: Array = []  # {c: Vector2i, t, col}
var drop_trails: Array = []  # {cells: Array, to: Vector2i, t, col}
var popups: Array = []  # {text, y, t, col}
var shake := 0.0
var disp := Vector2.ZERO  # smoothed display position of the active piece
var shown_score := 0.0
var score_bump := 0.0
var level_bump := 0.0
var last_score := 0
var last_level := 1
var banner := 0.0
var danger := 0.0
var _slammed := false  # the lock in progress came from a hard drop (it has its own sound)

func _ready() -> void:
	add_child(overlay)
	_activate(false)

# ---------- lifecycle ----------

## Moves the 540x960 design area; the pause overlay keeps covering the whole viewport.
func set_offset(o: Vector2) -> void:
	position = o
	overlay.place(o)
	_relayout()

## Fills the whole viewport (not just the 540x960 design area): the board takes the
## largest cell size that fits, the side column stretches to the board's height and
## spare height goes to the buttons.
func _relayout() -> void:
	var vp := get_viewport_rect().size
	var btns := Settings.controls == Settings.Controls.BUTTONS
	var key := [vp, position, btns]
	if key == _layout_key:
		return
	_layout_key = key
	var area := Rect2(-position, vp)
	var bottom_min := (MIN_BTN_H + GAP) if btns else HINT_H
	var fit_w := (area.size.x - 2 * BOARD_PAD) / Game.COLS
	var fit_h := (area.size.y - 2 * MARGIN - BAR_H - GAP - bottom_min - 6) / Game.ROWS
	cell = maxf(16.0, minf(fit_w, floorf(fit_h)))
	board_size = Vector2(Game.COLS, Game.ROWS) * cell
	var bottom_h := HINT_H
	if btns:
		bottom_h = clampf(area.size.y - 2 * MARGIN - BAR_H - GAP - board_size.y - GAP, MIN_BTN_H, MAX_BTN_H)
	var group_h := BAR_H + GAP + board_size.y + GAP + bottom_h
	var top := floorf(area.position.y + (area.size.y - group_h) / 2.0)
	board_origin = Vector2(floorf(area.position.x + (area.size.x - board_size.x) / 2.0), top + BAR_H + GAP)
	# Top bar above the board: SCORE and LEVEL on the left, NEXT and pause on the right.
	var x0 := area.position.x + MARGIN
	var x1 := area.end.x - MARGIN
	pause_btn = Rect2(x1 - BAR_H, top, BAR_H, BAR_H)
	next_rect = Rect2(pause_btn.position.x - GAP - NEXT_W, top, NEXT_W, BAR_H)
	score_rect = Rect2(x0, top, SCORE_W, BAR_H)
	level_rect = Rect2(x0 + SCORE_W + GAP, top, LEVEL_W, BAR_H)
	# Control buttons share the row under the board.
	btn_rects.clear()
	var spacing := GAP * 0.6
	var bw := (board_size.x - spacing * (BUTTONS.size() - 1)) / BUTTONS.size()
	var i := 0
	for name in BUTTONS:
		btn_rects[name] = Rect2(board_origin.x + i * (bw + spacing), board_origin.y + board_size.y + GAP, bw, bottom_h)
		i += 1

func start() -> void:
	game = Game.new()
	game.lines_cleared.connect(_on_lines_cleared)
	game.rows_removed.connect(_on_rows_removed)
	game.piece_locked.connect(_on_piece_locked)
	timer = 0.0
	flash = 0.0
	particles.clear()
	row_flashes.clear()
	lock_glows.clear()
	drop_trails.clear()
	popups.clear()
	shake = 0.0
	disp = Vector2(game.cur_pos)
	shown_score = 0.0
	score_bump = 0.0
	level_bump = 0.0
	last_score = 0
	last_level = 1
	banner = 0.0
	danger = 0.0
	held.clear()
	_set_paused(false)
	_activate(true)
	Sfx.play("play")
	started.emit()

func stop() -> void:
	_activate(false)

func _activate(on: bool) -> void:
	visible = on
	set_process(on)
	set_process_input(on)

func _set_paused(on: bool) -> void:
	if game != null and not game.over and on != paused:
		Sfx.play("pause" if on else "resume")
	paused = on
	held.clear()
	gesture.clear()
	overlay.show_overlay(on, game.score if game != null else 0)

func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT) \
			and visible and game != null and not game.over:
		_set_paused(true)

# ---------- update ----------

func _process(delta: float) -> void:
	_relayout()
	_animate(0.0 if paused else delta)
	flash = maxf(0.0, flash - delta * 4.0)
	score_changed.emit(game.score)
	if game.over and not overlay.visible:
		held.clear()
		gesture.clear()
		overlay.show_overlay(true, game.score, true)
		Sfx.play("gameover")
	if not game.over and not paused:
		timer += delta
		if timer >= game.gravity_interval():
			timer = 0.0
			game.step()
		for idx in held:
			var h: Dictionary = held[idx]
			if not BUTTONS[h.name]:
				continue
			h.t += delta
			while h.t >= REPEAT_DELAY + REPEAT_RATE:
				h.t -= REPEAT_RATE
				_press(h.name)
	queue_redraw()

func _press(name: String) -> void:
	match name:
		"left": _move(-1)
		"right": _move(1)
		"down": _soft_drop()
		"rotate": _rotate()
		"drop": _hard_drop()

func _move(dx: int) -> void:
	if game.move(dx):
		Sfx.play("move")

func _rotate() -> void:
	if game.rotate():
		Sfx.play("rotate")

func _soft_drop() -> void:
	if game.step():
		Sfx.play("soft")

func _hard_drop() -> void:
	var cells: Array = game.cur_cells.duplicate()
	var from := game.cur_pos
	var to := game.ghost_pos()
	var col: Color = PieceDefs.COLORS[game.cur_type]
	_slammed = true
	game.hard_drop()
	_slammed = false
	if to.y > from.y:
		drop_trails.append({"cells": cells, "from": from, "to": to, "t": 1.0, "col": col})
	shake = maxf(shake, 5.0)

# ---------- animation ----------

func _cell_center(c: Vector2) -> Vector2:
	return board_origin + (c + Vector2(0.5, 0.5)) * cell

func _burst(pos: Vector2, col: Color, n: int, speed: float, life: float, size: float) -> void:
	for i in n:
		if particles.size() > 400:
			return
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.3, 1.0)
		var l := life * randf_range(0.6, 1.0)
		particles.append({"pos": pos, "vel": v, "life": l, "max": l,
				"size": size * randf_range(0.6, 1.2), "col": col.lerp(Color.WHITE, randf() * 0.5)})

func _on_piece_locked(cells: Array, type: String) -> void:
	Sfx.play("drop" if _slammed else "lock")
	var col: Color = PieceDefs.COLORS[type]
	for c in cells:
		lock_glows.append({"c": c, "t": 1.0, "col": col})
		var bottom := _cell_center(Vector2(c)) + Vector2(0, cell * 0.45)
		_burst(bottom, col, 2, 90.0, 0.35, cell * 0.14)
	shake = maxf(shake, 2.0)

func _on_rows_removed(rows: Array) -> void:
	var mid_y := 0.0
	for r in rows:
		row_flashes.append({"y": r.y, "t": 1.0})
		mid_y += r.y
		for x in Game.COLS:
			var t: String = r.row[x]
			if t != "":
				_burst(_cell_center(Vector2(x, r.y)), PieceDefs.COLORS[t], 3, 320.0, 0.8, cell * 0.2)
	mid_y /= rows.size()
	if rows.size() >= 1 and rows.size() < CLEAR_NAMES.size():
		var col := UI.ACCENT2 if rows.size() >= 4 else (UI.ACCENT if rows.size() >= 2 else Color.WHITE)
		popups.append({"text": CLEAR_NAMES[rows.size()], "y": mid_y, "t": 1.0, "col": col})
	shake = maxf(shake, 4.0 + rows.size() * 2.5)

func _on_lines_cleared(n: int) -> void:
	flash = 1.0
	Sfx.play_clear(n)

func _animate(dt: float) -> void:
	anim_t += dt
	shake = maxf(0.0, shake - dt * 22.0)
	score_bump = maxf(0.0, score_bump - dt * 3.5)
	level_bump = maxf(0.0, level_bump - dt * 2.0)
	banner = maxf(0.0, banner - dt * 0.8)
	if game.score != last_score:
		last_score = game.score
		score_bump = 1.0
	if game.level != last_level:
		last_level = game.level
		level_bump = 1.0
		banner = 1.0
		Sfx.play("level")
		_burst(board_origin + board_size / 2.0, UI.ACCENT, 40, 420.0, 1.0, cell * 0.2)
	shown_score = move_toward(shown_score, float(game.score), maxf(8.0, absf(game.score - shown_score) * 6.0) * dt)
	# Smooth the active piece toward its logical cell; snap on respawn.
	var target := Vector2(game.cur_pos)
	if target.y < disp.y - 1.5 or game.over:
		disp = target
	else:
		disp = disp.lerp(target, 1.0 - exp(-dt * 38.0))
	# Danger glow when the stack nears the top.
	var top_row := Game.ROWS
	for y in Game.ROWS:
		if game.grid[y].any(func(t): return t != ""):
			top_row = y
			break
	danger = move_toward(danger, 1.0 if top_row <= 5 and not game.over else 0.0, dt * 2.0)
	for p in particles:
		p.life -= dt
		p.vel.y += 700.0 * dt
		p.pos += p.vel * dt
	particles = particles.filter(func(p): return p.life > 0.0)
	for list in [row_flashes, lock_glows, drop_trails, popups]:
		for e in list:
			e.t -= dt * (2.5 if is_same(list, lock_glows) else (0.9 if is_same(list, popups) else 3.0))
		list.assign(list.filter(func(e): return e.t > 0.0))

func _button_at(pos: Vector2) -> String:
	for name in btn_rects:
		if (btn_rects[name] as Rect2).grow(6).has_point(pos):
			return name
	return ""

# ---------- input ----------

func _input(ev: InputEvent) -> void:
	# Touch positions are viewport-space; shift into the design area's space.
	var event: InputEvent = ev.duplicate()
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		event.position -= position
	if paused or game.over:
		_input_paused(event)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if pause_btn.grow(6).has_point(event.position):
				_set_paused(true)
				return
			if Settings.controls == Settings.Controls.GESTURES:
				if gesture.is_empty():
					gesture = {"index": event.index, "anchor": event.position, "start": event.position,
							"t": Time.get_ticks_msec(), "moved": false}
				return
			var b := _button_at(event.position)
			if b != "":
				held[event.index] = {"name": b, "t": 0.0}
				_press(b)
		else:
			if not gesture.is_empty() and gesture.index == event.index:
				_end_gesture(event.position)
			held.erase(event.index)
	elif event is InputEventScreenDrag:
		if not gesture.is_empty() and gesture.index == event.index:
			_drag_gesture(event.position)
		elif held.has(event.index) and _button_at(event.position) != held[event.index].name:
			held.erase(event.index)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			_set_paused(true)
			return
		match event.keycode:
			KEY_LEFT: _move(-1)
			KEY_RIGHT: _move(1)
			KEY_DOWN: _soft_drop()
			KEY_UP: _rotate()
			KEY_SPACE: _hard_drop()

## Gesture controls: drag sideways to move, drag down to soft-drop,
## tap to rotate, quick downward flick to hard-drop.
func _drag_gesture(pos: Vector2) -> void:
	var a: Vector2 = gesture.anchor
	while pos.x - a.x >= cell:
		_move(1)
		a.x += cell
		gesture.moved = true
	while a.x - pos.x >= cell:
		_move(-1)
		a.x -= cell
		gesture.moved = true
	while pos.y - a.y >= cell:
		_soft_drop()
		a.y += cell
		gesture.moved = true
	if pos.y < a.y:
		a.y = pos.y  # don't build up a deficit when dragging back up
	gesture.anchor = a
	if (pos - gesture.start).length() > 16.0:
		gesture.moved = true

func _end_gesture(pos: Vector2) -> void:
	var d: Vector2 = pos - gesture.start
	var ms: int = Time.get_ticks_msec() - gesture.t
	if d.y > 100.0 and d.y > absf(d.x) * 1.5 and ms < 250:
		_hard_drop()
	elif not gesture.moved and ms < 350:
		_rotate()
	gesture.clear()

## Handles input while the pause or game-over card is showing.
func _input_paused(event: InputEvent) -> void:
	if overlay.in_settings:
		if event is InputEventScreenTouch and event.pressed:
			overlay.settings_tap(event.position)
		elif event is InputEventKey and event.pressed:
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
				overlay.set_settings_open(false)
			elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
				Settings.set_controls(Settings.Controls.GESTURES if Settings.controls == Settings.Controls.BUTTONS else Settings.Controls.BUTTONS)
				Sfx.play("select")
				overlay.set_settings_open(true)
		return
	if event is InputEventScreenTouch and event.pressed:
		if PauseOverlay.SETTINGS_BTN.grow(6).has_point(event.position):
			overlay.set_settings_open(true)
		elif PauseOverlay.RESUME_BTN.grow(6).has_point(event.position) \
				or (not game.over and pause_btn.grow(6).has_point(event.position)):
			_resume_or_restart()
		elif PauseOverlay.QUIT_BTN.grow(6).has_point(event.position):
			Sfx.play("back")
			menu_requested.emit()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
				or (not game.over and event.keycode in [KEY_ESCAPE, KEY_P]):
			_resume_or_restart()
		elif game.over and event.keycode == KEY_ESCAPE:
			Sfx.play("back")
			menu_requested.emit()

func _resume_or_restart() -> void:
	if game.over:
		start()
	else:
		_set_paused(false)

# ---------- drawing ----------

func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(board_origin + Vector2(x, y) * cell, Vector2(cell, cell))

func _draw() -> void:
	_draw_pause_button()
	_draw_board()
	_draw_side_panels()
	if Settings.controls == Settings.Controls.BUTTONS:
		_draw_buttons()
	else:
		UI.spaced_text(self, "DRAG · TAP TO ROTATE · FLICK TO DROP", board_origin.x + board_size.x / 2.0,
				board_origin.y + board_size.y + 20, 9, Color(1, 1, 1, 0.4), 2.0)

func _draw_pause_button() -> void:
	draw_style_box(UI.box(Color(1, 1, 1, 0.10), 14, 2, Color(UI.ACCENT, 0.4)), pause_btn)
	var pc := pause_btn.get_center()
	if paused:
		draw_colored_polygon(PackedVector2Array([pc + Vector2(-6, -11), pc + Vector2(11, 0), pc + Vector2(-6, 11)]), Color.WHITE)
	else:
		draw_style_box(UI.box(Color.WHITE, 2), Rect2(pc + Vector2(-9, -11), Vector2(6, 22)))
		draw_style_box(UI.box(Color.WHITE, 2), Rect2(pc + Vector2(3, -11), Vector2(6, 22)))

func _draw_board() -> void:
	var board := Rect2(board_origin, board_size)
	var pulse := 0.5 + 0.5 * sin(anim_t * 2.0)
	var rim := UI.ACCENT.lerp(Color(1.0, 0.25, 0.3), snappedf(danger, 0.1))
	if shake > 0.0:
		draw_set_transform(Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 0.6)
	# Soft glow (breathes; turns red when the stack is high)
	var glow_a := snappedf(0.03 + 0.025 * pulse + 0.03 * danger * pulse, 0.005)
	for i in 6:
		draw_style_box(UI.box(Color(rim, glow_a), 18 + i * 3), board.grow(4 + i * 3))
	draw_style_box(UI.box(Color(0.05, 0.04, 0.14, 0.85), 14, 2, Color(rim, snappedf(0.45 + 0.2 * pulse, 0.05))), board.grow(3))
	# Light band drifting down the board
	var band_h := cell * 4.0
	var by := board.position.y + fposmod(anim_t * 110.0, board.size.y + band_h) - band_h
	var y0 := maxf(by, board.position.y)
	var y1 := minf(by + band_h, board.end.y)
	if y1 > y0:
		draw_rect(Rect2(board.position.x, y0, board.size.x, y1 - y0), Color(1, 1, 1, 0.025))
	# Grid
	for x in range(1, Game.COLS):
		var px := board_origin.x + x * cell
		draw_line(Vector2(px, board_origin.y), Vector2(px, board_origin.y + board_size.y), Color(1, 1, 1, 0.04))
	for y in range(1, Game.ROWS):
		var py := board_origin.y + y * cell
		draw_line(Vector2(board_origin.x, py), Vector2(board_origin.x + board_size.x, py), Color(1, 1, 1, 0.04))
	# Locked cells
	for y in Game.ROWS:
		for x in Game.COLS:
			var t: String = game.grid[y][x]
			if t != "":
				UI.block(self, _cell_rect(x, y), PieceDefs.COLORS[t])
	# Landing flashes on freshly locked cells
	for g in lock_glows:
		draw_rect(_cell_rect(g.c.x, g.c.y).grow(-1), Color(1, 1, 1, 0.6 * g.t))
	# Hard-drop trails
	for tr in drop_trails:
		for c in tr.cells:
			var x: float = board_origin.x + (c.x + tr.from.x) * cell
			var top: float = board_origin.y + (c.y + tr.from.y) * cell
			var bot: float = board_origin.y + (c.y + tr.to.y) * cell
			var a: float = 0.4 * tr.t
			draw_polygon(
				PackedVector2Array([Vector2(x + 3, top), Vector2(x + cell - 3, top), Vector2(x + cell - 3, bot), Vector2(x + 3, bot)]),
				PackedColorArray([Color(tr.col, 0.0), Color(tr.col, 0.0), Color(tr.col, a), Color(tr.col, a)]))
	# Active piece + ghost outline
	if not game.over:
		var col: Color = PieceDefs.COLORS[game.cur_type]
		var ghost := game.ghost_pos()
		var ga := snappedf(0.08 + 0.05 * pulse, 0.01)
		var gb := snappedf(0.45 + 0.2 * pulse, 0.05)
		for c in game.cur_cells:
			var g: Vector2i = c + ghost
			draw_style_box(UI.box(Color(col, ga), 7, 2, Color(col, gb)), _cell_rect(g.x, g.y).grow(-2))
		for c in game.cur_cells:
			var r := Rect2(board_origin + (Vector2(c) + disp) * cell, Vector2(cell, cell))
			draw_style_box(UI.box(Color(col, 0.14), 10), r.grow(4))
			UI.block(self, r, col)
	if flash > 0.0:
		draw_rect(board, Color(1, 1, 1, 0.2 * flash))
	# Line-clear sweeps
	for f in row_flashes:
		var ry: float = board_origin.y + f.y * cell
		var grow: float = (1.0 - f.t) * cell * 0.9
		draw_rect(Rect2(board_origin.x, ry - grow, board_size.x, cell + grow * 2.0), Color(UI.ACCENT, 0.25 * f.t))
		draw_rect(Rect2(board_origin.x, ry, board_size.x, cell), Color(1, 1, 1, 0.9 * f.t))
	# Particles
	for p in particles:
		var k: float = p.life / p.max
		var s: float = p.size * (0.4 + 0.6 * k)
		draw_rect(Rect2(p.pos - Vector2(s, s) / 2.0, Vector2(s, s)), Color(p.col, k))
	# Clear-name popups and level-up banner
	for pu in popups:
		var pop: float = 1.0 + 0.4 * maxf(0.0, (pu.t - 0.8) * 5.0)
		var py: float = board_origin.y + pu.y * cell + cell * 0.7 - (1.0 - pu.t) * cell * 2.0
		UI.text(self, pu.text, Vector2(board_origin.x, py), int(30 * pop), Color(pu.col, clampf(pu.t * 2.5, 0.0, 1.0)),
				board_size.x, HORIZONTAL_ALIGNMENT_CENTER, UI.title_font)
	if banner > 0.0:
		var ba := sin(PI * (1.0 - banner))
		UI.text(self, "LEVEL %d" % game.level, Vector2(board_origin.x, board_origin.y + board_size.y * 0.4),
				int(40 + 14 * (1.0 - banner)), Color(UI.ACCENT, ba), board_size.x, HORIZONTAL_ALIGNMENT_CENTER, UI.title_font)
	draw_set_transform(Vector2.ZERO)

func _panel(rect: Rect2, label: String, value: String, bump := 0.0) -> void:
	draw_style_box(UI.box(UI.PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), rect)
	draw_line(rect.position + Vector2(14, 1.5), rect.position + Vector2(rect.size.x - 14, 1.5), Color(1, 1, 1, 0.14), 1.0)
	UI.text(self, label, rect.position + Vector2(0, 19), 11, UI.TEXT_DIM, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var fs := 24
	while fs > 12 and UI.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 12:
		fs -= 1
	var col := Color.WHITE.lerp(UI.ACCENT, bump)
	UI.text(self, value, rect.position + Vector2(0, 43 - 2.0 * bump), fs + int(5 * bump), col, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_side_panels() -> void:
	_panel(score_rect, "SCORE", str(int(shown_score)), snappedf(score_bump, 0.1))
	_panel(level_rect, "LEVEL", str(game.level), snappedf(level_bump, 0.1))
	# Next piece
	draw_style_box(UI.box(UI.PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), next_rect)
	var cells: Array = PieceDefs.SHAPES[game.next_type]
	var lo := Vector2i(99, 99)
	var hi := Vector2i(-99, -99)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var s := floorf(minf((next_rect.size.x - 12.0) / 4.0, (next_rect.size.y - 12.0) / 2.0))
	var size := Vector2(hi - lo + Vector2i.ONE) * s
	var origin := next_rect.get_center() - size / 2
	for c in cells:
		UI.block(self, Rect2(origin + Vector2(c - lo) * s, Vector2(s, s)), PieceDefs.COLORS[game.next_type])

func _draw_buttons() -> void:
	var down := {}
	for h in held.values():
		down[h.name] = true
	for name in BUTTONS:
		var rect: Rect2 = btn_rects[name]
		var pressed := down.has(name)
		var accent := UI.ACCENT2 if name == "drop" else (UI.ACCENT if name == "rotate" else Color.WHITE)
		if pressed:
			rect.position.y += 3
		draw_style_box(UI.box(Color(0, 0, 0, 0.35), 22), Rect2(rect.position + Vector2(0, 4), rect.size))
		var fill := Color(1, 1, 1, 0.20) if pressed else Color(1, 1, 1, 0.10)
		draw_style_box(UI.box(fill, 22, 2, Color(accent, 0.5 if pressed else 0.28)), rect)
		_draw_icon(name, rect.get_center(), Color(accent, 1.0 if pressed else 0.9))

func _draw_icon(name: String, c: Vector2, col: Color) -> void:
	match name:
		"left":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 0), c + Vector2(10, -20), c + Vector2(10, 20)]), col)
		"right":
			draw_colored_polygon(PackedVector2Array([c + Vector2(16, 0), c + Vector2(-10, -20), c + Vector2(-10, 20)]), col)
		"down":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 16), c + Vector2(-20, -10), c + Vector2(20, -10)]), col)
		"rotate":
			draw_arc(c, 19, deg_to_rad(-60), deg_to_rad(240), 32, col, 5.0, true)
			var tip := c + Vector2(19, 0).rotated(deg_to_rad(240))
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-12, -2), tip + Vector2(8, -10), tip + Vector2(8, 12)]), col)
		"drop":
			for dy in [-14, 4]:
				draw_polyline(PackedVector2Array([c + Vector2(-16, dy), c + Vector2(0, dy + 14), c + Vector2(16, dy)]), col, 5.0, true)
