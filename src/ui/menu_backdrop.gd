class_name MenuBackdrop
extends RefCounted
## Animated synthwave backdrop for the main menu: stars, sun, perspective floor.

const HORIZON := 760.0

static func draw(c: CanvasItem, t: float) -> void:
	var hy := HORIZON
	var accent := UI.ACCENT
	var accent2 := UI.ACCENT2

	# Twinkling stars
	for i in 48:
		var sx := float((i * 97) % 540)
		var sy := float((i * 53) % 600)
		var tw := 0.5 + 0.5 * sin(t * (0.8 + (i % 3) * 0.6) + i * 1.7)
		c.draw_circle(Vector2(sx, sy), 1.0 + (1.0 if i % 7 == 0 else 0.0), Color(1, 1, 1, 0.08 + 0.45 * tw))

	_draw_sun(c, hy)

	# Floor
	c.draw_rect(Rect2(0, hy, 540, 960 - hy), Color(0.03, 0.02, 0.1, 0.55))
	for k in range(-9, 10):
		c.draw_line(Vector2(270, hy), Vector2(270 + k * 110, 960), Color(accent2, 0.06), 5.0)
		c.draw_line(Vector2(270, hy), Vector2(270 + k * 110, 960), Color(accent2, 0.22), 1.5)
	# Soft haze hugging the horizon so the first lines blend into it
	var hz := Color(accent2, 0.32)
	c.draw_polygon(PackedVector2Array([Vector2(0, hy), Vector2(540, hy), Vector2(540, hy + 26), Vector2(0, hy + 26)]), PackedColorArray([hz, hz, Color(hz, 0.0), Color(hz, 0.0)]))
	# True-perspective horizontals: spacing shrinks toward the horizon so it stays filled
	var depth_n := 120.0
	var floor_h := 960.0 - hy
	for j in 120:
		var z := fposmod(j - t * 0.6, depth_n)
		var frac := 1.0 / (1.0 + z * 0.7)
		var ly := hy + floor_h * frac
		var vis := clampf((depth_n - z) / 6.0, 0.0, 1.0)
		var a := (0.08 + 0.4 * frac) * vis
		c.draw_line(Vector2(0, ly), Vector2(540, ly), Color(accent2, 0.05 * frac * vis), 5.0)
		c.draw_line(Vector2(0, ly), Vector2(540, ly), Color(accent2, a), 1.5)
	c.draw_line(Vector2(0, hy), Vector2(540, hy), Color(accent, 0.15), 6.0)
	c.draw_line(Vector2(0, hy), Vector2(540, hy), Color(accent, 0.85), 2.0)

	# Edge vignette
	var vc := Color(0.03, 0.02, 0.1, 0.55)
	var clear := Color(vc, 0.0)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(540, 0), Vector2(540, 140), Vector2(0, 140)]), PackedColorArray([vc, vc, clear, clear]))

## Retro sun sitting on the horizon, sliced by gaps that widen toward the bottom.
static func _draw_sun(c: CanvasItem, hy: float) -> void:
	var accent2 := UI.ACCENT2
	var sun_r := 112.0
	var sun_c := Vector2(270, hy - 8)
	for i in 8:
		c.draw_circle(sun_c, sun_r + 3 + i * 5, Color(accent2, 0.014))
	var row := sun_c.y - sun_r
	while row < hy:
		var d := hy - row
		var gap_w := 0.0
		if d < 95.0:
			gap_w = 1.0 + (1.0 - d / 95.0) * 7.0
		if fposmod(d, 18.0) >= gap_w:
			var dy := absf(sun_c.y - (row + 1.0))
			var half := sqrt(maxf(sun_r * sun_r - dy * dy, 0.0))
			var col := accent2.lerp(Color("ffc15e"), clampf(d / (sun_r * 1.6), 0.0, 1.0))
			c.draw_rect(Rect2(270 - half, row, half * 2.0, 1.2), Color(col, 0.6))
		row += 1.0
	for i in 6:
		c.draw_circle(sun_c, sun_r + 8 + i * 16, Color(accent2, 0.012))
