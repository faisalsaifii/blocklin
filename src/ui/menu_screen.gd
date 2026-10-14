class_name MenuScreen
extends Node2D
## Main menu: animated backdrop, title, best score and PLAY button.

signal play_pressed

const PLAY_BTN := Rect2(120, 520, 300, 90)
const SETTINGS_BTN := Rect2(170, 646, 200, 52)
const SETTINGS_RECTS := {
	"buttons": Rect2(60, 330, 200, 190),
	"gestures": Rect2(280, 330, 200, 190),
	"back": Rect2(170, 700, 200, 52),
}

var best := 0
var t := 0.0
var play_down := false:
	get: return down_btn == "play"
var down_btn := ""
var in_settings := false
var off := Vector2.ZERO  # where the 540x960 design area sits in the viewport

func set_offset(o: Vector2) -> void:
	off = o
	queue_redraw()

func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	set_process_input(on)
	if on:
		t = 0.0
		down_btn = ""
		in_settings = false
		queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _hit(event: InputEventScreenTouch) -> String:
	var p: Vector2 = event.position - off
	if in_settings:
		for name in SETTINGS_RECTS:
			if (SETTINGS_RECTS[name] as Rect2).grow(8).has_point(p):
				return name
		return ""
	if PLAY_BTN.grow(8).has_point(p):
		return "play"
	if SETTINGS_BTN.grow(8).has_point(p):
		return "settings"
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var hit := _hit(event)
		if event.pressed:
			down_btn = hit
		else:
			if down_btn != "" and down_btn == hit:
				_activate(hit)
			down_btn = ""
	elif event is InputEventKey and event.pressed:
		if in_settings:
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
				Sfx.play("back")
				in_settings = false
			elif event.keycode in [KEY_LEFT, KEY_RIGHT]:
				Settings.set_controls(Settings.Controls.GESTURES if Settings.controls == Settings.Controls.BUTTONS else Settings.Controls.BUTTONS)
				Sfx.play("select")
		elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			play_pressed.emit()
		elif event.keycode == KEY_S:
			Sfx.play("click")
			in_settings = true

func _activate(name: String) -> void:
	match name:
		"play": play_pressed.emit()
		"settings":
			Sfx.play("click")
			in_settings = true
		"back":
			Sfx.play("back")
			in_settings = false
		"buttons":
			Settings.set_controls(Settings.Controls.BUTTONS)
			Sfx.play("select")
		"gestures":
			Settings.set_controls(Settings.Controls.GESTURES)
			Sfx.play("select")

func _draw() -> void:
	MenuBackdrop.draw(self, t, get_viewport_rect().size, off)
	draw_set_transform(off)
	var fade := clampf((t - 0.7) / 0.6, 0.0, 1.0)
	if in_settings:
		_draw_settings()
		return
	_draw_logo(clampf(t / 0.4, 0.0, 1.0))
	_draw_title()
	_draw_tagline(fade)
	_draw_best(fade)
	_draw_play_button(fade)
	_draw_pill(SETTINGS_BTN, "SETTINGS", down_btn == "settings", fade)
	UI.spaced_text(self, "© BLOCKLIN", 270, 934, 10, Color(1, 1, 1, 0.3 * fade), 3.0)

## Showcase piece that cycles through every tetromino, popping in each time.
func _draw_logo(fade: float) -> void:
	var types: Array = PieceDefs.types()
	var ty: String = types[int(t / 2.4) % types.size()]
	var local := fposmod(t, 2.4)
	var pop := clampf(local / 0.45, 0.0, 1.0)
	var squash := 1.0 - pow(1.0 - pop, 3.0)
	var alpha := minf(squash, clampf((2.4 - local) / 0.3, 0.0, 1.0)) * fade
	var cells: Array = PieceDefs.SHAPES[ty]
	var col: Color = PieceDefs.COLORS[ty]
	var lo := Vector2(99, 99)
	var hi := Vector2(-99, -99)
	for c in cells:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var s := 26.0
	var center := Vector2(270, 168 + sin(t * 2.0) * 4.0)
	var half := (hi - lo + Vector2.ONE) * s * 0.5
	for i in 8:
		draw_circle(center, 80 - i * 8, Color(col, 0.014 * alpha))
	draw_set_transform(off + center, sin(t * 1.3) * 0.06, Vector2(1.0, squash))
	for c in cells:
		UI.block(self, Rect2(Vector2(c) * s - lo * s - half, Vector2(s, s)), col, alpha)
	draw_set_transform(off)

## Per-letter drop-in intro, then a steady neon glow (pixel-snapped to avoid shimmer).
func _draw_title() -> void:
	var title := "BLOCKLIN"
	var tsize := 64
	var total := UI.title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
	var x := roundf(270.0 - total / 2)
	for i in title.length():
		var ch: String = title[i]
		var intro := clampf((t - i * 0.06) / 0.5, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - intro, 3.0)
		var y := roundf(300.0 - (1.0 - ease_out) * 160.0)
		var col: Color = UI.ACCENT.lerp(Color.WHITE, 0.6) if i < 5 else UI.ACCENT2
		col.a *= ease_out
		UI.glow_text(self, ch, Vector2(x, y), tsize, col, UI.title_font, 1.3 * ease_out)
		x += roundf(UI.title_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x)

## Divider with centre diamond + tagline.
func _draw_tagline(fade: float) -> void:
	var dc := Color(UI.ACCENT, 0.5 * fade)
	var dy := 336.0
	var grow := 150.0 * fade
	draw_line(Vector2(270 - 12, dy), Vector2(270 - 12 - grow, dy), dc, 1.5)
	draw_line(Vector2(270 + 12, dy), Vector2(270 + 12 + grow, dy), dc, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(270, dy - 5), Vector2(275, dy), Vector2(270, dy + 5), Vector2(265, dy)]), Color(UI.ACCENT2, fade))
	UI.spaced_text(self, "FALLING BLOCKS  ·  ENDLESS FUN", 270, 372, 11, Color(1, 1, 1, 0.6 * fade), 3.0)

func _draw_best(fade: float) -> void:
	var pill := Rect2(185, 420, 170, 42)
	draw_style_box(UI.box(Color(1, 1, 1, 0.06 * fade), 21, 1, Color(UI.ACCENT, 0.35 * fade)), pill)
	var lbl_w := 34.0
	var val := str(best) if best > 0 else "—"
	var val_w := UI.font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var gx := 270.0 - (lbl_w + 14.0 + val_w) / 2.0
	UI.spaced_text(self, "BEST", gx + lbl_w / 2.0, 447, 11, Color(1, 1, 1, 0.55 * fade), 2.0)
	UI.text(self, val, Vector2(gx + lbl_w + 14.0, 448), 20, Color(UI.ACCENT, fade))

func _draw_pill(rect: Rect2, label: String, pressed: bool, fade: float) -> void:
	var r := rect
	if pressed:
		r.position.y += 3
	var base := UI.ACCENT.darkened(0.45)
	draw_style_box(UI.box(Color(base.darkened(0.4), fade), 26), Rect2(rect.position + Vector2(0, 5), rect.size))
	draw_style_box(UI.box(Color(base, fade), 26, 2, Color(1, 1, 1, 0.5 * fade)), r)
	draw_style_box(UI.box(Color(1, 1, 1, 0.18 * fade), 10), Rect2(r.position + Vector2(14, 6), Vector2(r.size.x - 28, 14)))
	UI.spaced_text(self, label, r.get_center().x, r.get_center().y + 6, 16, Color(1, 1, 1, fade), 3.0)

func _draw_settings() -> void:
	UI.glow_text(self, "SETTINGS", Vector2(270 - UI.title_font.get_string_size("SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x / 2, 190), 44, UI.ACCENT.lerp(Color.WHITE, 0.6), UI.title_font, 1.0)
	UI.spaced_text(self, "CONTROLS", 270, 300, 13, UI.TEXT_DIM, 4.0)
	var gestures := Settings.controls == Settings.Controls.GESTURES
	_draw_option(SETTINGS_RECTS["buttons"], "BUTTONS", "On-screen buttons", not gestures, "buttons")
	_draw_option(SETTINGS_RECTS["gestures"], "GESTURES", "Swipe & tap", gestures, "gestures")
	UI.spaced_text(self, "GESTURES: DRAG TO MOVE · TAP TO ROTATE", 270, 570, 9, Color(1, 1, 1, 0.45), 2.0)
	UI.spaced_text(self, "SWIPE DOWN TO DROP · FLICK TO SLAM", 270, 590, 9, Color(1, 1, 1, 0.45), 2.0)
	_draw_pill(SETTINGS_RECTS["back"], "BACK", down_btn == "back", 1.0)

func _draw_option(rect: Rect2, title: String, sub: String, selected: bool, id: String) -> void:
	var r := rect
	if down_btn == id:
		r.position.y += 3
	var col := UI.ACCENT2 if selected else Color.WHITE
	draw_style_box(UI.box(Color(col, 0.18 if selected else 0.06), 22, 3 if selected else 1, Color(col, 0.9 if selected else 0.25)), r)
	var c := r.get_center()
	# Icon
	if id == "buttons":
		for i in 3:
			draw_style_box(UI.box(Color(col, 0.7), 8), Rect2(c.x - 48 + i * 34, c.y - 52, 28, 28))
	else:
		draw_arc(c + Vector2(0, -38), 14, 0, TAU, 24, Color(col, 0.8), 3.0, true)
		draw_line(c + Vector2(-34, -38), c + Vector2(-20, -38), Color(col, 0.7), 3.0)
		draw_line(c + Vector2(20, -38), c + Vector2(34, -38), Color(col, 0.7), 3.0)
	UI.spaced_text(self, title, c.x, c.y + 14, 15, Color(col, 1.0), 2.0)
	UI.spaced_text(self, sub, c.x, c.y + 40, 9, Color(1, 1, 1, 0.55), 1.5)
	if selected:
		UI.spaced_text(self, "SELECTED", c.x, c.y + 70, 9, Color(UI.ACCENT, 1.0), 2.0)

## Breathing glow + press feedback.
func _draw_play_button(fade: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var btn := PLAY_BTN.grow(2.0 * pulse)
	if play_down:
		btn = PLAY_BTN.grow(-3.0)
		btn.position.y += 3
	for i in 5:
		draw_style_box(UI.box(Color(UI.ACCENT2, (0.05 + 0.04 * pulse) * fade), 40 + i * 4), btn.grow(4 + i * 5))
	draw_style_box(UI.box(Color(UI.ACCENT2.darkened(0.35), fade), 40), Rect2(btn.position + Vector2(0, 5), btn.size))
	draw_style_box(UI.box(Color(UI.ACCENT2, fade), 40, 2, Color(1, 1, 1, 0.55 * fade)), btn)
	draw_style_box(UI.box(Color(1, 1, 1, 0.22 * fade), 20), Rect2(btn.position + Vector2(18, 8), Vector2(btn.size.x - 36, 22)))
	var pw := UI.title_font.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var tx := btn.get_center().x - (pw + 34) / 2.0
	var ty := btn.get_center().y
	draw_colored_polygon(PackedVector2Array([Vector2(tx, ty - 14), Vector2(tx + 22, ty), Vector2(tx, ty + 14)]), Color(1, 1, 1, fade))
	UI.text(self, "PLAY", Vector2(tx + 34, ty + 13), 36, Color(1, 1, 1, fade), -1.0, HORIZONTAL_ALIGNMENT_LEFT, UI.title_font)
