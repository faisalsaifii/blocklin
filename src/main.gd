extends Node2D
## Entry point: owns the screens (menu / game), the shared background and the fade.

const FADE_SPEED := 3.0

var best := 0
var fade := 0.0

var menu := MenuScreen.new()
var game_view := GameView.new()
var fader := ColorRect.new()  # last child, so it draws above both screens

func _ready() -> void:
	UI.load_fonts()
	add_child(menu)
	add_child(game_view)
	fader.size = UI.SIZE
	fader.color = Color(0.04, 0.03, 0.12, 0.0)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fader)

	menu.play_pressed.connect(_on_play)
	game_view.menu_requested.connect(_show_menu)
	game_view.started.connect(_start_fade.bind(1.0))
	game_view.score_changed.connect(func(s: int): best = maxi(best, s))
	menu.set_active(true)

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * FADE_SPEED)
	fader.color.a = fade
	fader.visible = fade > 0.0

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
	var vp := UI.SIZE
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(vp.x, 0), vp, Vector2(0, vp.y)]),
		PackedColorArray([UI.BG_TOP, UI.BG_TOP, UI.BG_BOTTOM, UI.BG_BOTTOM]))
	draw_circle(Vector2(480, 90), 160, Color(UI.ACCENT2, 0.06))
	draw_circle(Vector2(40, 760), 200, Color(UI.ACCENT, 0.05))
