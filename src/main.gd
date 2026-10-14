extends Node2D
## Entry point: owns the screens (menu / game), the shared background and the fade.

const FADE_SPEED := 3.0

var best := 0
var fade := 0.0
var t := 0.0

var menu := MenuScreen.new()
var game_view := GameView.new()
var fader := ColorRect.new()  # last child, so it draws above both screens

func _ready() -> void:
	UI.load_fonts()
	Settings.load_settings()
	best = Settings.best
	add_child(menu)
	add_child(game_view)
	fader.color = Color(0.04, 0.03, 0.12, 0.0)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fader)

	menu.play_pressed.connect(_on_play)
	game_view.menu_requested.connect(_show_menu)
	game_view.started.connect(_start_fade.bind(1.0))
	game_view.score_changed.connect(func(s: int): best = maxi(best, s))
	menu.set_active(true)
	get_viewport().size_changed.connect(_layout)
	_layout()

## The viewport grows (aspect "expand") to match the device; keep the 540x960
## design area centred and let the background fill the rest.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - UI.SIZE) / 2.0).floor()
	menu.set_offset(off)
	game_view.set_offset(off)
	fader.size = vp
	queue_redraw()

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * FADE_SPEED)
	fader.color.a = fade
	fader.visible = fade > 0.0
	t += delta
	queue_redraw()

func _start_fade(amount: float) -> void:
	fade = amount

func _on_play() -> void:
	menu.set_active(false)
	game_view.start()

func _show_menu() -> void:
	game_view.stop()
	menu.best = best
	menu.set_active(true)
	_start_fade(0.6)

func _draw() -> void:
	# Background shared by both screens
	var vp := get_viewport_rect().size
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([UI.BG_TOP, UI.BG_TOP, UI.BG_BOTTOM, UI.BG_BOTTOM]))
	# Drifting glow orbs
	draw_circle(Vector2(vp.x - 60 + sin(t * 0.35) * 50, 90 + cos(t * 0.3) * 40), 160, Color(UI.ACCENT2, 0.06))
	draw_circle(Vector2(40 + cos(t * 0.25) * 60, vp.y - 200 + sin(t * 0.4) * 50), 200, Color(UI.ACCENT, 0.05))
	draw_circle(Vector2(vp.x * 0.5 + sin(t * 0.2) * 120, vp.y * 0.5 + cos(t * 0.27) * 150), 180, Color(UI.ACCENT2, 0.03))
	# Rising twinkling motes (deterministic from index so nothing needs storing)
	for i in 36:
		var seed_x := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var seed_s := fposmod(sin(i * 78.233) * 24634.6345, 1.0)
		var speed := 12.0 + seed_s * 30.0
		var y := fposmod(vp.y - (t * speed + seed_s * vp.y), vp.y + 20.0) - 10.0
		var x := seed_x * vp.x + sin(t * 0.6 + i) * 12.0
		var a := (0.15 + 0.2 * (0.5 + 0.5 * sin(t * 2.0 + i * 1.7))) * seed_s
		draw_circle(Vector2(x, y), 1.0 + seed_s * 1.8, Color(1, 1, 1, a))
