class_name PauseOverlay
extends ColorRect
## Blurs whatever is behind it and shows a centred pause card on top.

const PAUSE_CARD := Rect2(120, 330, 300, 320)
const RESUME_BTN := Rect2(150, 450, 240, 50)
const SETTINGS_BTN := Rect2(150, 512, 240, 50)
const QUIT_BTN := Rect2(150, 574, 240, 50)
# Settings view inside the card
const SETTINGS_CARD := Rect2(120, 290, 300, 400)
const OPT_BUTTONS := Rect2(150, 438, 240, 56)
const OPT_GESTURES := Rect2(150, 510, 240, 56)
const BACK_BTN := Rect2(150, 616, 240, 50)

const BLUR_SHADER := "
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 acc = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			acc += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 6.0, 2.0).rgb;
		}
	}
	vec3 c = acc / 9.0;
	COLOR = vec4(mix(c, vec3(0.03, 0.02, 0.1), 0.4), 1.0);
}
"

var score := 0
var game_over := false
var in_settings := false
# Child drawn after (so above) the blurred rect; the blur material would
# otherwise apply to the card too.
var _card := Node2D.new()

func _ready() -> void:
	size = get_viewport_rect().size
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat
	_card.draw.connect(_draw_card)
	add_child(_card)

## `off` is the parent's position; the blur covers the viewport, the card stays in design space.
func place(off: Vector2) -> void:
	position = -off
	size = get_viewport_rect().size
	_card.position = off

func show_overlay(on: bool, current_score: int, is_game_over := false) -> void:
	score = current_score
	game_over = is_game_over
	visible = on
	in_settings = false
	if on:
		_card.queue_redraw()

func set_settings_open(on: bool) -> void:
	if on != in_settings:
		Sfx.play("click" if on else "back")
	in_settings = on
	_card.queue_redraw()

## Tap inside the settings view (design-space position).
func settings_tap(pos: Vector2) -> void:
	if OPT_BUTTONS.grow(6).has_point(pos):
		Settings.set_controls(Settings.Controls.BUTTONS)
		Sfx.play("select")
	elif OPT_GESTURES.grow(6).has_point(pos):
		Settings.set_controls(Settings.Controls.GESTURES)
		Sfx.play("select")
	elif BACK_BTN.grow(6).has_point(pos):
		Sfx.play("back")
		in_settings = false
	_card.queue_redraw()

func _option(c: Node2D, rect: Rect2, label: String, selected: bool) -> void:
	var col := UI.ACCENT2 if selected else Color.WHITE
	c.draw_style_box(UI.box(Color(col, 0.2 if selected else 0.06), 16, 2, Color(col, 0.9 if selected else 0.3)), rect)
	UI.text(c, label, rect.position + Vector2(0, 32), 18, col, rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, UI.title_font)

func _draw_card() -> void:
	var c := _card
	var card := SETTINGS_CARD if in_settings else PAUSE_CARD
	for i in 5:
		c.draw_style_box(UI.box(Color(UI.ACCENT, 0.03), 22 + i * 3), card.grow(3 + i * 4))
	c.draw_style_box(UI.box(Color(0.1, 0.08, 0.25, 0.96), 22, 2, Color(UI.ACCENT, 0.7)), card)
	var mid := HORIZONTAL_ALIGNMENT_CENTER
	if in_settings:
		UI.text(c, "SETTINGS", card.position + Vector2(0, 74), 30, Color.WHITE, card.size.x, mid, UI.title_font)
		c.draw_line(Vector2(card.position.x + 40, card.position.y + 100), Vector2(card.end.x - 40, card.position.y + 100), Color(UI.ACCENT, 0.3), 1.5)
		UI.spaced_text(c, "CONTROLS", card.get_center().x, card.position.y + 134, 12, UI.ACCENT, 4.0)
		var g := Settings.controls == Settings.Controls.GESTURES
		_option(c, OPT_BUTTONS, "BUTTONS", not g)
		_option(c, OPT_GESTURES, "GESTURES", g)
		c.draw_style_box(UI.box(Color(1, 1, 1, 0.08), 16, 2, Color(1, 1, 1, 0.3)), BACK_BTN)
		UI.text(c, "BACK", BACK_BTN.position + Vector2(0, 33), 18, Color(1, 1, 1, 0.9), BACK_BTN.size.x, mid, UI.title_font)
		return
	var title := "GAME OVER" if game_over else "PAUSED"
	UI.text(c, title, PAUSE_CARD.position + Vector2(0, 66), 32 if game_over else 36, Color.WHITE, PAUSE_CARD.size.x, mid, UI.title_font)
	UI.text(c, "Score  %d" % score, PAUSE_CARD.position + Vector2(0, 106), 15, UI.ACCENT, PAUSE_CARD.size.x, mid)
	c.draw_style_box(UI.box(Color(UI.ACCENT2.darkened(0.35)), 16), Rect2(RESUME_BTN.position + Vector2(0, 4), RESUME_BTN.size))
	c.draw_style_box(UI.box(UI.ACCENT2, 16, 2, Color(1, 1, 1, 0.5)), RESUME_BTN)
	UI.text(c, "PLAY AGAIN" if game_over else "RESUME", RESUME_BTN.position + Vector2(0, 33), 20, Color.WHITE, RESUME_BTN.size.x, mid, UI.title_font)
	c.draw_style_box(UI.box(Color(1, 1, 1, 0.08), 16, 2, Color(UI.ACCENT, 0.4)), SETTINGS_BTN)
	UI.text(c, "SETTINGS", SETTINGS_BTN.position + Vector2(0, 33), 18, Color(1, 1, 1, 0.9), SETTINGS_BTN.size.x, mid, UI.title_font)
	c.draw_style_box(UI.box(Color(1, 1, 1, 0.08), 16, 2, Color(1, 1, 1, 0.3)), QUIT_BTN)
	UI.text(c, "MENU", QUIT_BTN.position + Vector2(0, 33), 18, Color(1, 1, 1, 0.9), QUIT_BTN.size.x, mid, UI.title_font)
