extends Node2D
## Rendering and input for Blocklin.

const CELL := 36
const BOARD_ORIGIN := Vector2(20, 100)
const BOARD_SIZE := Vector2(Game.COLS, Game.ROWS) * CELL
const PANEL_X := 396.0
const PANEL_W := 124.0

# Palette
const BG_TOP := Color("0f0c29")
const BG_BOTTOM := Color("302b63")
const ACCENT := Color("5ee7ff")
const ACCENT2 := Color("ff6bcb")
const PANEL_COL := Color(1, 1, 1, 0.07)
const TEXT_DIM := Color(1, 1, 1, 0.55)

# On-screen buttons: name -> [rect, repeats_when_held]
const BUTTONS := {
	"left": [Rect2(14, 842, 96, 98), true],
	"right": [Rect2(120, 842, 96, 98), true],
	"down": [Rect2(226, 842, 96, 98), true],
	"rotate": [Rect2(338, 842, 92, 98), false],
	"drop": [Rect2(440, 842, 86, 98), false],
}
const REPEAT_DELAY := 0.18
const REPEAT_RATE := 0.06

var game: Game
var timer := 0.0
var flash := 0.0
var held := {}  # touch index -> {"name": String, "t": float}
var font: SystemFont
var _styles := {}

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Poppins", "Montserrat", "Roboto", "SF Pro Rounded", "Segoe UI", "Arial"])
	font.font_weight = 700
	_new_game()

func _new_game() -> void:
	game = Game.new()
	game.lines_cleared.connect(func(_n): flash = 1.0)
	timer = 0.0
	held.clear()

func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 4.0)
	if not game.over:
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

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if game.over:
				_new_game()
				return
			var b := _button_at(event.position)
			if b != "":
				held[event.index] = {"name": b, "t": 0.0}
				_press(b)
		else:
			held.erase(event.index)
	elif event is InputEventScreenDrag:
		if held.has(event.index) and _button_at(event.position) != held[event.index].name:
			held.erase(event.index)
	elif event is InputEventKey and event.pressed:
		if game.over:
			_new_game()
			return
		match event.keycode:
			KEY_LEFT: game.move(-1)
			KEY_RIGHT: game.move(1)
			KEY_DOWN: game.step()
			KEY_UP: game.rotate()
			KEY_SPACE: game.hard_drop()

# ---------- drawing helpers ----------

func _box(color: Color, radius: int, border_w := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var key := [color, radius, border_w, border_col]
	if _styles.has(key):
		return _styles[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border_col
	sb.anti_aliasing = true
	_styles[key] = sb
	return sb

func _text(s: String, pos: Vector2, size: int, color := Color.WHITE, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, pos + Vector2(0, 2), s, align, width, size, Color(0, 0, 0, 0.35))
	draw_string(font, pos, s, align, width, size, color)

func _block(rect: Rect2, col: Color, alpha := 1.0) -> void:
	var r := rect.grow(-1)
	draw_style_box(_box(col.darkened(0.35) * Color(1, 1, 1, alpha), 7), r)
	var inner := Rect2(r.position + Vector2(0, 0), r.size - Vector2(0, 4))
	draw_style_box(_box(col * Color(1, 1, 1, alpha), 7), inner)
	draw_style_box(_box(Color(1, 1, 1, 0.28 * alpha), 3), Rect2(inner.position + Vector2(5, 4), Vector2(inner.size.x - 10, 5)))

func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(x, y) * CELL, Vector2(CELL, CELL))

func _panel(rect: Rect2, label: String, value: String) -> void:
	draw_style_box(_box(PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), rect)
	_text(label, rect.position + Vector2(0, 26), 15, TEXT_DIM, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	_text(value, rect.position + Vector2(0, 62), 30, Color.WHITE, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)

# ---------- main draw ----------

func _draw() -> void:
	# Background gradient
	var vp := Vector2(540, 960)
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	draw_circle(Vector2(480, 90), 160, Color(ACCENT2, 0.06))
	draw_circle(Vector2(40, 760), 200, Color(ACCENT, 0.05))

	# Title
	var w1 := font.get_string_size("BLOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	_text("BLOCK", Vector2(22, 66), 38)
	_text("LIN", Vector2(22 + w1, 66), 38, ACCENT2)

	_draw_board()
	_draw_side_panels()
	_draw_buttons()

	if game.over:
		draw_rect(Rect2(BOARD_ORIGIN, BOARD_SIZE), Color(0, 0, 0, 0.55))
		var card := Rect2(BOARD_ORIGIN + Vector2(30, 250), Vector2(300, 170))
		draw_style_box(_box(Color(0.1, 0.08, 0.25, 0.95), 20, 2, ACCENT2), card)
		_text("GAME OVER", card.position + Vector2(0, 62), 36, Color.WHITE, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text("Score  %d" % game.score, card.position + Vector2(0, 100), 20, ACCENT, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text("tap to play again", card.position + Vector2(0, 140), 16, TEXT_DIM, card.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_board() -> void:
	var board := Rect2(BOARD_ORIGIN, BOARD_SIZE)
	# Soft glow
	for i in 6:
		draw_style_box(_box(Color(ACCENT, 0.035), 18 + i * 3), board.grow(4 + i * 3))
	draw_style_box(_box(Color(0.05, 0.04, 0.14, 0.85), 14, 2, Color(ACCENT, 0.55)), board.grow(3))
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
				_block(_cell_rect(x, y), PieceDefs.COLORS[t])
	# Active piece + ghost outline
	if not game.over:
		var col: Color = PieceDefs.COLORS[game.cur_type]
		var ghost := game.ghost_pos()
		for c in game.cur_cells:
			var g: Vector2i = c + ghost
			draw_style_box(_box(Color(col, 0.10), 7, 2, Color(col, 0.55)), _cell_rect(g.x, g.y).grow(-2))
		for c in game.cur_cells:
			var p: Vector2i = c + game.cur_pos
			_block(_cell_rect(p.x, p.y), col)
	if flash > 0.0:
		draw_style_box(_box(Color(1, 1, 1, 0.25 * flash), 14), board)

func _draw_side_panels() -> void:
	# Next piece
	var next_rect := Rect2(PANEL_X, 100, PANEL_W, 130)
	draw_style_box(_box(PANEL_COL, 14, 1, Color(1, 1, 1, 0.1)), next_rect)
	_text("NEXT", next_rect.position + Vector2(0, 26), 15, TEXT_DIM, PANEL_W, HORIZONTAL_ALIGNMENT_CENTER)
	var cells: Array = PieceDefs.SHAPES[game.next_type]
	var lo := Vector2i(99, 99)
	var hi := Vector2i(-99, -99)
	for c in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var s := 24.0
	var size := Vector2(hi - lo + Vector2i.ONE) * s
	var origin := next_rect.position + Vector2(PANEL_W, 130 + 24) / 2 - size / 2 - Vector2(0, 0)
	for c in cells:
		_block(Rect2(origin + Vector2(c - lo) * s, Vector2(s, s)), PieceDefs.COLORS[game.next_type])

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
		var accent := ACCENT2 if name == "drop" else (ACCENT if name == "rotate" else Color.WHITE)
		if pressed:
			rect.position.y += 3
		draw_style_box(_box(Color(0, 0, 0, 0.35), 22), Rect2(rect.position + Vector2(0, 4), rect.size))
		var fill := Color(1, 1, 1, 0.20) if pressed else Color(1, 1, 1, 0.10)
		draw_style_box(_box(fill, 22, 2, Color(accent, 0.5 if pressed else 0.28)), rect)
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
