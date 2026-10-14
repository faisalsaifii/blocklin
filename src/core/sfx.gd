class_name Sfx
extends RefCounted
## Procedural sound effects: every sound is synthesised once from a few layers
## (oscillator sweep or noise burst) into an AudioStreamWAV, then played from a small player pool.

const RATE := 22050
const POOL_SIZE := 8
const MASTER_DB := -4.0

# Layer: [start, duration, freq_from, freq_to, wave, volume]
const NOTES := {
	"move": [[0.0, 0.04, 520.0, 420.0, "tri", 0.35]],
	"rotate": [[0.0, 0.035, 600.0, 900.0, "square", 0.16], [0.03, 0.05, 900.0, 1150.0, "square", 0.14]],
	"soft": [[0.0, 0.025, 320.0, 260.0, "tri", 0.22]],
	"lock": [[0.0, 0.10, 150.0, 55.0, "sine", 0.65], [0.0, 0.05, 0.0, 0.0, "noise", 0.22]],
	"drop": [[0.0, 0.14, 1100.0, 110.0, "sine", 0.5], [0.0, 0.10, 0.0, 0.0, "noise", 0.3], [0.09, 0.12, 120.0, 45.0, "sine", 0.75]],
	"clear1": [[0.0, 0.12, 523.0, 523.0, "tri", 0.4], [0.07, 0.16, 784.0, 784.0, "tri", 0.4]],
	"clear2": [[0.0, 0.12, 523.0, 523.0, "tri", 0.4], [0.07, 0.12, 659.0, 659.0, "tri", 0.4], [0.14, 0.2, 988.0, 988.0, "tri", 0.4]],
	"clear3": [[0.0, 0.12, 523.0, 523.0, "tri", 0.4], [0.07, 0.12, 659.0, 659.0, "tri", 0.4], [0.14, 0.12, 784.0, 784.0, "tri", 0.4], [0.21, 0.24, 1047.0, 1047.0, "tri", 0.4]],
	"clear4": [[0.0, 0.12, 523.0, 523.0, "square", 0.22], [0.06, 0.12, 659.0, 659.0, "square", 0.22], [0.12, 0.12, 784.0, 784.0, "square", 0.22],
			[0.18, 0.12, 1047.0, 1047.0, "square", 0.22], [0.24, 0.45, 1319.0, 1319.0, "tri", 0.45], [0.24, 0.45, 659.0, 659.0, "sine", 0.3]],
	"level": [[0.0, 0.1, 392.0, 392.0, "tri", 0.4], [0.09, 0.1, 523.0, 523.0, "tri", 0.4], [0.18, 0.1, 659.0, 659.0, "tri", 0.4],
			[0.27, 0.1, 784.0, 784.0, "tri", 0.4], [0.36, 0.4, 1047.0, 1047.0, "tri", 0.45]],
	"gameover": [[0.0, 0.2, 392.0, 380.0, "square", 0.2], [0.2, 0.2, 330.0, 320.0, "square", 0.2], [0.4, 0.2, 262.0, 250.0, "square", 0.2],
			[0.6, 0.7, 196.0, 120.0, "tri", 0.5]],
	"pause": [[0.0, 0.08, 640.0, 480.0, "tri", 0.35], [0.07, 0.1, 480.0, 340.0, "tri", 0.35]],
	"resume": [[0.0, 0.08, 340.0, 480.0, "tri", 0.35], [0.07, 0.1, 480.0, 640.0, "tri", 0.35]],
	"click": [[0.0, 0.045, 760.0, 520.0, "square", 0.18]],
	"back": [[0.0, 0.06, 520.0, 340.0, "square", 0.16]],
	"select": [[0.0, 0.05, 700.0, 1000.0, "tri", 0.35]],
	"play": [[0.0, 0.09, 392.0, 392.0, "square", 0.2], [0.08, 0.09, 523.0, 523.0, "square", 0.2], [0.16, 0.09, 659.0, 659.0, "square", 0.2],
			[0.24, 0.3, 1047.0, 1047.0, "tri", 0.4]],
}

static var enabled := true
static var _streams := {}
static var _players: Array[AudioStreamPlayer] = []
static var _next := 0

## Plays a named sound; `pitch` and `volume_db` tweak this one playback.
static func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not enabled or not NOTES.has(sound):
		return
	if _players.is_empty() and not _make_pool():
		return
	if not _streams.has(sound):
		_streams[sound] = _synth(NOTES[sound])
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	if not p.is_inside_tree():
		return
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = MASTER_DB + volume_db
	p.play()

## Clear fanfare for 1-4 lines.
static func play_clear(count: int) -> void:
	play("clear%d" % clampi(count, 1, 4))

static func _make_pool() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		tree.root.add_child.call_deferred(p)
		_players.append(p)
	return true

static func _synth(layers: Array) -> AudioStreamWAV:
	var total := 0.0
	for l in layers:
		total = maxf(total, l[0] + l[1])
	var n := int(total * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for l in layers:
		var start := int(l[0] * RATE)
		var count := int(l[1] * RATE)
		var phase := 0.0
		for i in count:
			var k := float(i) / count
			var f: float = l[2] * pow(maxf(l[3], 1.0) / maxf(l[2], 1.0), k) if l[2] > 0.0 else 0.0
			phase = fposmod(phase + f / RATE, 1.0)
			var s := 0.0
			match l[4]:
				"sine": s = sin(phase * TAU)
				"square": s = 1.0 if phase < 0.5 else -1.0
				"tri": s = 4.0 * absf(phase - 0.5) - 1.0
				"noise": s = rng.randf_range(-1.0, 1.0)
			# 2 ms attack to avoid clicks, then an exponential-ish decay.
			var env := minf(1.0, i / (RATE * 0.002)) * pow(1.0 - k, 1.6)
			buf[start + i] += s * env * l[5]
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
