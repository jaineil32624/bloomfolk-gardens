extends Node
## Audio — procedural music and sound effects, synthesized at runtime.
##
## No audio files: a cozy day theme and a gentle night theme are composed
## from a chord progression + seeded melody and rendered on a background
## thread; short SFX (till, water, plant, harvest, discovery jingle, coins,
## UI clicks, level-up fanfare, rain ambience) are rendered on first use.

const RATE := 16000
const BPM_DAY := 84.0
const BPM_NIGHT := 66.0

## MIDI notes. Progression: C Am F G | C Am F G | F G Em Am | F G C C
const PROG := [
	[48, [60, 64, 67]], [45, [57, 60, 64]], [41, [57, 60, 65]], [43, [59, 62, 67]],
	[48, [60, 64, 67]], [45, [57, 60, 64]], [41, [57, 60, 65]], [43, [59, 62, 67]],
	[41, [57, 60, 65]], [43, [59, 62, 67]], [40, [55, 59, 64]], [45, [57, 60, 64]],
	[41, [57, 60, 65]], [43, [59, 62, 67]], [48, [60, 64, 67]], [48, [55, 60, 64]],
]
const PENTA := [0, 2, 4, 7, 9]

var music_player: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var sfx_players: Array = []
var _sfx_cache := {}
var _themes := {}
var _want_theme := ""
var _cur_theme := ""
var _thread: Thread = null
var music_on := true
var sfx_on := true
var music_volume := 0.7
var _last_sfx := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player_b = AudioStreamPlayer.new()
	rain_player = AudioStreamPlayer.new()
	for p in [music_player, music_player_b, rain_player]:
		add_child(p)
	music_player.volume_db = -80
	music_player_b.volume_db = -80
	for i in 8:
		var s := AudioStreamPlayer.new()
		add_child(s)
		sfx_players.append(s)
	_start_rendering()
	Events.discovery_popup.connect(func(_k, _t): play("discover"))
	Events.level_up.connect(func(_l): play("levelup"))
	Events.milestone_reached.connect(func(_t): play("levelup"))
	Events.tool_upgraded.connect(func(_a, _b): play("coin"))
	Events.weather_changed.connect(func(_w): _update_rain())
	Events.day_started.connect(_update_rain)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ================================================================= SYNTH HELPERS
static func freq(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Adds a note into buf. kind: "pluck", "pad", "bass", "bell", "soft"
static func note(buf: PackedFloat32Array, start: float, dur: float, midi: float, amp: float, kind: String) -> void:
	var f := freq(midi)
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var tail := n
	match kind:
		"pluck", "bell": tail = int(n * 1.6)
		"pad": tail = n + int(0.4 * RATE)
	var inc := TAU * f / RATE
	var ph := 0.0
	for i in tail:
		var j := i0 + i
		if j >= buf.size():
			break
		var t := float(i) / RATE
		var env := 0.0
		var s := 0.0
		match kind:
			"pluck":
				env = exp(-t * 5.0) * minf(1.0, t * 200.0)
				s = sin(ph) + 0.35 * sin(ph * 2.0) * exp(-t * 9.0) + 0.12 * sin(ph * 3.0) * exp(-t * 14.0)
			"bell":
				env = exp(-t * 3.2) * minf(1.0, t * 300.0)
				s = sin(ph) + 0.5 * sin(ph * 2.76) * exp(-t * 6.0) + 0.25 * sin(ph * 5.4) * exp(-t * 10.0)
			"pad":
				var a := minf(1.0, t / 0.5)
				var r := 1.0 if i < n else maxf(0.0, 1.0 - float(i - n) / (0.4 * RATE))
				env = a * r
				var tri := 2.0 * absf(2.0 * (ph / TAU - floor(ph / TAU + 0.5))) - 1.0
				s = 0.6 * sin(ph) + 0.4 * tri + 0.15 * sin(ph * 1.003 + 1.0)
			"bass":
				env = minf(1.0, t * 80.0) * (1.0 if i < n * 0.85 else maxf(0.0, 1.0 - (i - n * 0.85) / (n * 0.15)))
				s = sin(ph) + 0.25 * sin(ph * 2.0)
			_:
				env = minf(1.0, t * 40.0) * exp(-t * 2.0)
				s = sin(ph)
		buf[j] += s * env * amp
		ph += inc
		if ph > TAU * 1000.0:
			ph = fmod(ph, TAU)


static func to_wav(buf: PackedFloat32Array, loop: bool, gain: float = 1.0) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var k := gain * 0.85 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * k, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


# ================================================================= MUSIC
## Builds the note list for a theme (cheap); rendering happens separately.
func _compose(bpm: float, seed: int, night: bool) -> Dictionary:
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var total := bar * PROG.size()
	var notes := []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var last := 72
	for b in PROG.size():
		var t0 := b * bar
		var root: int = PROG[b][0]
		var chord: Array = PROG[b][1]
		for m in chord:
			notes.append([t0, bar, m, 0.10 if not night else 0.12, "pad"])
		notes.append([t0, beat * 2.0, root, 0.30, "bass"])
		notes.append([t0 + beat * 2.0, beat * 2.0, root + 7, 0.22, "bass"])
		if not night:
			for e in 8:
				var m2: int = chord[[0, 1, 2, 1, 0, 2, 1, 2][e]] + 12
				notes.append([t0 + e * beat * 0.5, beat * 0.5, m2, 0.07, "pluck"])
		var steps := [1.0, 0.5, 0.5, 1.0, 1.0] if not night else [2.0, 1.0, 1.0]
		if b % 4 == 3:
			steps = [1.5, 0.5, 2.0] if not night else [4.0]
		var t := t0
		for d in steps:
			if rng.randf() < (0.12 if not night else 0.25) and t > t0:
				t += d * beat
				continue
			var cand := []
			for o in [60, 72]:
				for p in PENTA:
					var mm: int = o + p
					if abs(mm - last) <= 5 and mm >= 64 and mm <= 81:
						cand.append(mm)
			var target: int = chord[rng.randi_range(0, 2)] + 12
			if t == t0 or cand.is_empty():
				last = target
			else:
				last = cand[rng.randi_range(0, cand.size() - 1)]
			notes.append([t, d * beat, last, 0.20 if not night else 0.17, "bell" if night else "pluck"])
			t += d * beat
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE) + 10)
	return {"notes": notes, "buf": buf, "i": 0}


static func _render_job(job: Dictionary, budget_ms: int) -> bool:
	## Renders notes until done (true) or the time budget runs out (false).
	var t0 := Time.get_ticks_msec()
	var notes: Array = job["notes"]
	var buf: PackedFloat32Array = job["buf"]
	while job["i"] < notes.size():
		var n: Array = notes[job["i"]]
		note(buf, n[0], n[1], n[2], n[3], n[4])
		job["i"] += 1
		if budget_ms > 0 and Time.get_ticks_msec() - t0 > budget_ms:
			job["buf"] = buf
			return false
	job["buf"] = buf
	return true


var _jobs := []


func _start_rendering() -> void:
	_jobs = [["day", _compose(BPM_DAY, 7, false)], ["night", _compose(BPM_NIGHT, 21, true)]]
	if OS.has_feature("web"):
		return  # rendered a little each frame in _process (no threads on web)
	_thread = Thread.new()
	_thread.start(_render_themes)


func _render_themes() -> void:
	for j in _jobs:
		_render_job(j[1], 0)
		call_deferred("_theme_ready", j[0], to_wav(j[1]["buf"], true, 0.9))


func _theme_ready(name: String, w: AudioStreamWAV) -> void:
	_themes[name] = w
	if _want_theme == name:
		_crossfade_to(name)


func set_theme(name: String) -> void:
	_want_theme = name
	if name == _cur_theme:
		return
	if _themes.has(name) or name == "":
		_crossfade_to(name)


func _crossfade_to(name: String) -> void:
	_cur_theme = name
	var old := music_player
	music_player = music_player_b
	music_player_b = old
	var target_db := linear_to_db(maxf(0.001, music_volume)) - 8.0 if music_on else -80.0
	if name != "":
		music_player.stream = _themes[name]
		music_player.volume_db = -40
		music_player.play()
		create_tween().tween_property(music_player, "volume_db", target_db, 2.5)
	var tw := create_tween()
	tw.tween_property(old, "volume_db", -60.0, 2.0)
	tw.tween_callback(old.stop)


func toggle_music() -> void:
	music_on = not music_on
	music_player.volume_db = (linear_to_db(music_volume) - 8.0) if music_on else -80.0


func _process(_d: float) -> void:
	if OS.has_feature("web") and not _jobs.is_empty():
		var j: Array = _jobs[0]
		if _render_job(j[1], 6):
			_theme_ready(j[0], to_wav(j[1]["buf"], true, 0.9))
			_jobs.pop_front()
	var want := "night" if GameState.daylight() < 0.35 else "day"
	if want != _want_theme:
		set_theme(want)


func _update_rain() -> void:
	if GameState.weather == "rain":
		if not rain_player.playing:
			rain_player.stream = _rain()
			rain_player.volume_db = -14
			rain_player.play()
	else:
		rain_player.stop()


# ================================================================= SFX
func play(name: String, pitch: float = 1.0) -> void:
	if not sfx_on:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get(name, 0)) < 45:
		return
	_last_sfx[name] = now
	if not _sfx_cache.has(name):
		_sfx_cache[name] = _make_sfx(name)
	for p in sfx_players:
		if not p.playing:
			p.stream = _sfx_cache[name]
			p.pitch_scale = pitch * randf_range(0.96, 1.04)
			p.volume_db = -4
			p.play()
			return


func _noise(buf: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, lp: float) -> void:
	var y := 0.0
	for i in int(dur * RATE):
		var j := int(start * RATE) + i
		if j >= buf.size():
			break
		var t := float(i) / RATE
		y += (randf() * 2.0 - 1.0 - y) * lp
		buf[j] += y * amp * exp(-t * decay)


func _make_sfx(name: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	match name:
		"till":
			buf.resize(int(0.25 * RATE))
			_noise(buf, 0, 0.25, 1.0, 18.0, 0.25)
			note(buf, 0, 0.08, 40, 0.5, "bass")
		"water":
			buf.resize(int(0.45 * RATE))
			_noise(buf, 0, 0.45, 0.6, 5.0, 0.6)
			for i in 4:
				note(buf, 0.05 + i * 0.07, 0.06, 84 + i * 3, 0.15, "soft")
		"plant":
			buf.resize(int(0.25 * RATE))
			_noise(buf, 0, 0.1, 0.5, 30.0, 0.3)
			note(buf, 0.03, 0.12, 72, 0.4, "pluck")
		"harvest":
			buf.resize(int(0.6 * RATE))
			note(buf, 0, 0.12, 72, 0.5, "pluck")
			note(buf, 0.08, 0.12, 76, 0.5, "pluck")
			note(buf, 0.16, 0.3, 79, 0.5, "pluck")
		"forage":
			buf.resize(int(0.5 * RATE))
			_noise(buf, 0, 0.15, 0.5, 20.0, 0.4)
			note(buf, 0.06, 0.25, 79, 0.4, "bell")
			note(buf, 0.14, 0.25, 84, 0.3, "bell")
		"discover":
			buf.resize(int(1.4 * RATE))
			var seq := [72, 76, 79, 84, 88]
			for i in seq.size():
				note(buf, i * 0.09, 0.5, seq[i], 0.4, "bell")
			note(buf, 0.45, 0.8, 91, 0.3, "bell")
		"levelup":
			buf.resize(int(1.6 * RATE))
			for i in 4:
				note(buf, i * 0.12, 0.3, [67, 72, 76, 79][i], 0.45, "pluck")
			for m in [72, 76, 79, 84]:
				note(buf, 0.5, 0.9, m, 0.18, "pad")
		"coin":
			buf.resize(int(0.4 * RATE))
			note(buf, 0, 0.08, 88, 0.4, "bell")
			note(buf, 0.07, 0.3, 93, 0.4, "bell")
		"click":
			buf.resize(int(0.08 * RATE))
			note(buf, 0, 0.04, 84, 0.4, "pluck")
		"open":
			buf.resize(int(0.25 * RATE))
			note(buf, 0, 0.1, 76, 0.35, "pluck")
			note(buf, 0.06, 0.15, 83, 0.3, "pluck")
		"close":
			buf.resize(int(0.25 * RATE))
			note(buf, 0, 0.1, 83, 0.3, "pluck")
			note(buf, 0.06, 0.15, 76, 0.3, "pluck")
		"error":
			buf.resize(int(0.3 * RATE))
			note(buf, 0, 0.12, 52, 0.4, "bass")
			note(buf, 0.1, 0.15, 49, 0.4, "bass")
		"sleep":
			buf.resize(int(2.2 * RATE))
			for i in 5:
				note(buf, i * 0.3, 0.8, [79, 76, 72, 67, 64][i], 0.3, "bell")
		_:
			buf.resize(int(0.1 * RATE))
			note(buf, 0, 0.05, 72, 0.3, "soft")
	return to_wav(buf, false, 0.8)


func _rain() -> AudioStreamWAV:
	if _sfx_cache.has("_rain"):
		return _sfx_cache["_rain"]
	var buf := PackedFloat32Array()
	buf.resize(int(3.0 * RATE))
	var y := 0.0
	for i in buf.size():
		y += (randf() * 2.0 - 1.0 - y) * 0.35
		buf[i] = y * 0.5
		if randf() < 0.0015:
			for k in 60:
				if i + k < buf.size():
					buf[i + k] += (randf() - 0.5) * exp(-k / 12.0)
	# crossfade loop seam
	var fade := int(0.2 * RATE)
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[buf.size() - fade + i] * (1.0 - a)
	buf.resize(buf.size() - fade)
	var w := to_wav(buf, true, 0.6)
	_sfx_cache["_rain"] = w
	return w
