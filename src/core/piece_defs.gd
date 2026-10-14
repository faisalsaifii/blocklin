class_name PieceDefs
extends RefCounted
## Piece shapes as cell offsets. Add new piece types here.

const SHAPES := {
	"I": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	"O": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"T": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	"S": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	"Z": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"J": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)],
	"L": [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
}

const COLORS := {
	"I": Color("4dd0e1"), "O": Color("ffd54f"), "T": Color("ba68c8"),
	"S": Color("81c784"), "Z": Color("e57373"), "J": Color("64b5f6"), "L": Color("ffb74d"),
}

static func types() -> Array:
	return SHAPES.keys()
