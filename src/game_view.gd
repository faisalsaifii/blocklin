class_name GameView
extends Node2D
## In-game screen: board, side panels, on-screen controls, pause and game over.

signal started
signal menu_requested
signal score_changed(score: int)

const CELL := 36
const BOARD_ORIGIN := Vector2(20, 100)
const BOARD_SIZE := Vector2(Game.COLS, Game.ROWS) * CELL
const PANEL_X := 396.0
const PANEL_W := 124.0

# On-screen buttons: name -> [rect, repeats_when_held]
const BUTTONS := {
	"left": [Rect2(14, 842, 96, 98), true],
	"right": [Rect2(120, 842, 96, 98), true],
	"down": [Rect2(226, 842, 96, 98), true],
	"rotate": [Rect2(338, 842, 92, 98), false],
	"drop": [Rect2(440, 842, 86, 98), false],
}
const PAUSE_BTN := Rect2(444, 28, 76, 44)
const REPEAT_DELAY := 0.18
const REPEAT_RATE := 0.06

var game: Game
var paused := false
var timer := 0.0
var flash := 0.0
var held := {}  # touch index -> {"name": String, "t": float}
var gesture := {}  # active gesture touch: index, anchor, start, t, moved
var overlay := PauseOverlay.new()

func _ready() -> void:
	add_child(overlay)
	_activate(false)

# ---------- lifecycle ----------

## Moves the 540x960 design area; the pause overlay keeps covering the whole viewport.
func set_offset(o: Vector2) -> void:
	position = o
	overlay.place(o)

func start() -> void:
	game = Game.new()
	game.lines_cleared.connect(func(_n): flash = 1.0)
	timer = 0.0
	flash = 0.0
	held.clear()
	_set_paused(false)
	_activate(true)
	started.emit()

func stop() -> void:
	_activate(false)

func _activate(on: bool) -> void:
	visible = on
	set_process(on)
	set_process_input(on)

func _set_paused(on: bool) -> void:
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
	flash = maxf(0.0, flash - delta * 4.0)
	score_changed.emit(game.score)
	if game.over and not overlay.visible:
		held.clear()
		gesture.clear()
		overlay.show_overlay(true, game.score, true)
	if not game.over and not paused:
		timer += delta
		if timer >= game.gravity_interval():
			timer = 0.0
			game.step()
		for idx in held:
			var h: Dictionary = held[idx]
			if not BUTTONS[h.name][1]:
				continue
			h.t += delta
			while h.t >= REPEAT_DELAY + REPEAT_RATE:
				h.t -= REPEAT_RATE
				_press(h.name)
	queue_redraw()

func _press(name: String) -> void:
	match name:
		"left": game.move(-1)
		"right": game.move(1)
		"down": game.step()
		"rotate": game.rotate()
		"drop": game.hard_drop()

func _button_at(pos: Vector2) -> String:
	for name in BUTTONS:
		if (BUTTONS[name][0] as Rect2).grow(6).has_point(pos):
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
			if PAUSE_BTN.grow(6).has_point(event.position):
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
			KEY_LEFT: game.move(-1)
			KEY_RIGHT: game.move(1)
			KEY_DOWN: game.step()
			KEY_UP: game.rotate()
			KEY_SPACE: game.hard_drop()

## Gesture controls: drag sideways to move, drag down to soft-drop,
## tap to rotate, quick downward flick to hard-drop.
func _drag_gesture(pos: Vector2) -> void:
	var a: Vector2 = gesture.anchor
	while pos.x - a.x >= CELL:
		game.move(1)
		a.x += CELL
		gesture.moved = true
	while a.x - pos.x >= CELL:
		game.move(-1)
		a.x -= CELL
		gesture.moved = true
	while pos.y - a.y >= CELL:
		game.step()
		a.y += CELL
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
		game.hard_drop()
	elif not gesture.moved and ms < 350:
		game.rotate()
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
				overlay.set_settings_open(true)
		return
	if event is InputEventScreenTouch and event.pressed:
		if PauseOverlay.SETTINGS_BTN.grow(6).has_point(event.position):
			overlay.set_settings_open(true)
		elif PauseOverlay.RESUME_BTN.grow(6).has_point(event.position) \
				or (not game.over and PAUSE_BTN.grow(6).has_point(event.position)):
			_resume_or_restart()
		elif PauseOverlay.QUIT_BTN.grow(6).has_point(event.position):
			menu_requested.emit()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
				or (not game.over and event.keycode in [KEY_ESCAPE, KEY_P]):
			_resume_or_restart()
		elif game.over and event.keycode == KEY_ESCAPE:
			menu_requested.emit()

func _resume_or_restart() -> void:
	if game.over:
		start()
	else:
		_set_paused(false)

# ---------- drawing ----------

func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))

func _draw() -> void:
	_draw_header()
	_draw_board()
	_draw_side_panels()
	if Settings.controls == Settings.Controls.BUTTONS:
		_draw_buttons()
	else:
		UI.spaced_text(self, "DRAG TO MOVE  ·  TAP TO ROTATE  ·  FLICK DOWN TO DROP", 270, 900, 9, Color(1, 1, 1, 0.4), 2.0)

func _draw_header() -> void:
	var w1 := UI.title_font.get_string_size("BLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	UI.text(self, "BLOCK", Vector2(22, 66), 38, Color.WHITE, -1.0, HORIZONTAL_ALIGNMENT_LEFT, UI.title_font)
	UI.text(self, "LIN", Vector2(22 + w1, 66), 38, UI.ACCENT2, -1.0, HORIZONTAL_ALIGNMENT_LEFT, UI.title_font)

	draw_style_box(UI.box(Color(1, 1, 1, 0.10), 14, 2, Color(UI.ACCENT, 0.4)), PAUSE_BTN)
	var pc := PAUSE_BTN.get_center()
	if paused:
		draw_colored_polygon(PackedVector2Array([pc + Vector2(-6, -11), pc + Vector2(11, 0), pc + Vector2(-6, 11)]), Color.WHITE)
	else:
		draw_style_box(UI.box(Color.WHITE, 2), Rect2(pc + Vector2(-9, -11), Vector2(6, 22)))
		draw_style_box(UI.box(Color.WHITE, 2), Rect2(pc + Vector2(3, -11), Vector2(6, 22)))

func _draw_board() -> void:
	var board := Rect2(BOARD_ORIGIN, BOARD_SIZE)
	# Soft glow
	for i in 6:
		draw_style_box(UI.box(Color(UI.ACCENT, 0.035), 18 + i * 3), board.grow(4 + i * 3))
	draw_style_box(UI.box(Color(0.05, 0.04, 0.14, 0.85), 14, 2, Color(UI.ACCENT, 0.55)), board.grow(3))
	# Grid
	for x in range(1, Game.COLS):
		var px := BOARD_ORIGIN.x + x * CELL
		draw_line(Vector2(px, BOARD_ORIGIN.y), Vector2(px, BOARD_ORIGIN.y + BOARD_SIZE.y), Color(1, 1, 1, 0.04))
	for y in range(1, Game.ROWS):
		var py := BOARD_ORIGIN.y + y * CELL
		draw_line(Vector2(BOARD_ORIGIN.x, py), Vector2(BOARD_ORIGIN.x + BOARD_SIZE.x, py), Color(1, 1, 1, 0.04))
	# Locked cells
	for y in Game.ROWS:
		for x in Game.COLS:
			var t: String = game.grid[y][x]
			if t != "":
				UI.block(self, _cell_rect(x, y), PieceDefs.COLORS[t])
	# Active piece + ghost outline
	if not game.over:
		var col: Color = PieceDefs.COLORS[game.cur_type]
		var ghost := game.ghost_pos()
		for c in game.cur_cells:
			var g: Vector2i = c + ghost
			draw_style_box(UI.box(Color(col, 0.10), 7, 2, Color(col, 0.55)), _cell_rect(g.x, g.y).grow(-2))
		for c in game.cur_cells:
			var p: Vector2i = c + game.cur_pos
			UI.block(self, _cell_rect(p.x, p.y), col)
	if flash > 0.0:
		draw_style_box(UI.box(Color(1, 1, 1, 0.25 * flash), 14), board)

func _panel(rect: Rect2, label: String, value: String) -> void:
	draw_style_box(UI.box(UI.PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), rect)
	UI.text(self, label, rect.position + Vector2(0, 26), 15, UI.TEXT_DIM, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	UI.text(self, value, rect.position + Vector2(0, 62), 26, Color.WHITE, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_side_panels() -> void:
	# Next piece
	var next_rect := Rect2(PANEL_X, 100, PANEL_W, 130)
	draw_style_box(UI.box(UI.PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), next_rect)
	UI.text(self, "NEXT", next_rect.position + Vector2(0, 26), 15, UI.TEXT_DIM, PANEL_W, HORIZONTAL_ALIGNMENT_CENTER)
	var cells: Array = PieceDefs.SHAPES[game.next_type]
	var lo := Vector2i(99, 99)
	var hi := Vector2i(-99, -99)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var s := 24.0
	var size := Vector2(hi - lo + Vector2i.ONE) * s
	var origin := next_rect.position + Vector2(PANEL_W, 130 + 24) / 2 - size / 2
	for c in cells:
		UI.block(self, Rect2(origin + Vector2(c - lo) * s, Vector2(s, s)), PieceDefs.COLORS[game.next_type])

	_panel(Rect2(PANEL_X, 246, PANEL_W, 86), "SCORE", str(game.score))
	_panel(Rect2(PANEL_X, 348, PANEL_W, 86), "LINES", str(game.lines))
	_panel(Rect2(PANEL_X, 450, PANEL_W, 86), "LEVEL", str(game.level))

func _draw_buttons() -> void:
	var down := {}
	for h in held.values():
		down[h.name] = true
	for name in BUTTONS:
		var rect: Rect2 = BUTTONS[name][0]
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
