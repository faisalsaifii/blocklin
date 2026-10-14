class_name UI
extends RefCounted
## Shared look-and-feel: palette, fonts and small drawing helpers.

const SIZE := Vector2(540, 960)

# Palette
const BG_TOP := Color("0f0c29")
const BG_BOTTOM := Color("302b63")
const ACCENT := Color("5ee7ff")
const ACCENT2 := Color("ff6bcb")
const PANEL_COL := Color(1, 1, 1, 0.07)
const TEXT_DIM := Color(1, 1, 1, 0.55)

static var font: Font  # UI text (Orbitron)
static var title_font: Font  # headings (Bungee)
static var _styles := {}

static func load_fonts() -> void:
	if font != null:
		return
	title_font = load("res://assets/fonts/Bungee-Regular.ttf")
	(title_font as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Orbitron-VariableFont_wght.ttf")
	fv.variation_opentype = {"wght": 700}
	font = fv

## Cached rounded-rect style.
static func box(color: Color, radius: int, border_w := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
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

static func text(c: CanvasItem, s: String, pos: Vector2, size: int, color := Color.WHITE, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT, f: Font = null) -> void:
	if f == null:
		f = font
	c.draw_string(f, pos + Vector2(0, 2), s, align, width, size, Color(0, 0, 0, 0.35 * color.a))
	c.draw_string(f, pos, s, align, width, size, color)

static func glow_text(c: CanvasItem, s: String, pos: Vector2, size: int, col: Color, f: Font, glow := 1.0) -> void:
	for r: float in [8.0, 5.0, 2.5]:
		for k in 8:
			var o: Vector2 = (Vector2.from_angle(k * TAU / 8.0) * r).round()
			c.draw_string(f, pos + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(col, 0.07 * glow))
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.35))

## Letter-spaced, centred text (Godot has no tracking option).
static func spaced_text(c: CanvasItem, s: String, cx: float, y: float, size: int, col: Color, spacing: float, f: Font = null) -> void:
	if f == null:
		f = font
	var widths := []
	var total := -spacing
	for ch in s:
		var w: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		widths.append(w)
		total += w + spacing
	var x := cx - total / 2.0
	for i in s.length():
		c.draw_string(f, Vector2(x, y + 2), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.35 * col.a))
		c.draw_string(f, Vector2(x, y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += widths[i] + spacing

## Glossy game block.
static func block(c: CanvasItem, rect: Rect2, col: Color, alpha := 1.0) -> void:
	var r := rect.grow(-1)
	c.draw_style_box(box(col.darkened(0.35) * Color(1, 1, 1, alpha), 7), r)
	var inner := Rect2(r.position, r.size - Vector2(0, 4))
	c.draw_style_box(box(col * Color(1, 1, 1, alpha), 7), inner)
	c.draw_style_box(box(Color(1, 1, 1, 0.28 * alpha), 3), Rect2(inner.position + Vector2(5, 4), Vector2(inner.size.x - 10, 5)))
