extends Node

## Tiny original procedural sound pack. It avoids shipping third-party audio
## while keeping all gameplay calls centralized for a later mastered soundtrack.
var muted := false
const MIX_RATE := 22050.0
var player: AudioStreamPlayer
var playback
var sfx_frequency := 0.0
var sfx_phase := 0.0
var sfx_time := 0.0
var music_phase := 0.0
var music_clock := 0.0
var music_step := 0
var music_frequency := 146.83

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = int(MIX_RATE)
	stream.buffer_length = 0.3
	player.stream = stream
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func _process(delta: float) -> void:
	music_clock += delta
	if music_clock > 0.36:
		music_clock = 0.0
		var notes := [146.83, 174.61, 196.0, 220.0, 196.0, 174.61]
		music_frequency = notes[music_step % notes.size()]
		music_step += 1
	if playback == null:
		return
	for frame in playback.get_frames_available():
		var sample := 0.0
		if not muted and bool(SaveData.data.music_enabled):
			music_phase = fmod(music_phase + music_frequency / MIX_RATE, 1.0)
			sample += sin(TAU * music_phase) * 0.035
		if sfx_time > 0.0:
			sfx_phase = fmod(sfx_phase + sfx_frequency / MIX_RATE, 1.0)
			sample += sin(TAU * sfx_phase) * minf(0.18, sfx_time * 1.4)
			sfx_time -= 1.0 / MIX_RATE
		playback.push_frame(Vector2(sample, sample))

func play_sfx(cue: String) -> void:
	if muted or not bool(SaveData.data.sfx_enabled):
		return
	var notes := {"mestolo": 410.0, "burro": 470.0, "raccolta": 690.0, "sconfitto": 120.0, "colpo": 90.0, "cucina": 330.0, "scatto": 520.0}
	sfx_frequency = float(notes.get(cue, 240.0))
	sfx_phase = 0.0
	sfx_time = 0.1

func play_music(_cue: String) -> void:
	if muted or not bool(SaveData.data.music_enabled):
		return
