extends Node
## 发声引擎：一组 AudioStreamPlayer 轮流用，按文件名顺序把 res://audio 里的采样装进来。

@export var voice_count: int = 32

# A 方案（默认）：按下响、松手不停，声音自己放完
@export var stop_on_release := false
# B 方案：长按循环、松手立刻停。同时把 stop_on_release 设为 true
@export var loop_while_held := false

var _samples: Array[AudioStream] = []
var _players: Array[AudioStreamPlayer] = []
var _player_key := {}     # AudioStreamPlayer -> key
var _steal_cursor := 0

var sample_count: int:
	get:
		return _samples.size()


func _ready() -> void:
	for i in voice_count:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = 0.0
		p.autoplay = false
		add_child(p)
		_players.append(p)

	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	limiter.pre_gain_db = 0.0
	AudioServer.add_bus_effect(0, limiter)


## 扫描 res://audio，按文件名里的数字排序加载
func load_samples() -> void:
	var dir := "res://audio"
	var seen := {}

	if DirAccess.dir_exists_absolute(dir):
		for f in DirAccess.get_files_at(dir):
			var n: String = String(f)
			# 编辑器里列出的是 "00.wav" + "00.wav.import"；导出后 PCK 里只剩 "00.wav.import"，
			# 所以两种都还原成真实资源路径
			if n.ends_with(".import"):
				n = n.trim_suffix(".import")
			elif n.ends_with(".remap"):
				n = n.trim_suffix(".remap")
			seen[n] = true

	var files: Array[String] = []
	for n in seen.keys():
		var lower: String = String(n).to_lower()
		if lower.ends_with(".wav") or lower.ends_with(".ogg") or lower.ends_with(".mp3"):
			files.append(n)

	# 按名字开头的数字排，00,01,…,23；没数字的排最后
	files.sort_custom(func(a: String, b: String) -> bool:
		var na := _numeric_prefix(a)
		var nb := _numeric_prefix(b)
		if na != nb:
			return na < nb
		return a < b)

	var loaded: Array[AudioStream] = []
	for f in files:
		var s := load(dir + "/" + f) as AudioStream
		if s == null:
			push_warning("AudioEngine: 读不出 %s" % f)
			continue
		if loop_while_held:
			_enable_loop(s)
		loaded.append(s)

	_samples = loaded
	_player_key.clear()
	print("AudioEngine: 载入 %d 个采样，循环=%s，松手停=%s"
			% [_samples.size(), loop_while_held, stop_on_release])


## 取文件名开头的数字："13.wav" -> 13；没有数字返回 2147483647
func _numeric_prefix(name: String) -> int:
	var i := 0
	while i < name.length() and name[i] >= "0" and name[i] <= "9":
		i += 1
	if i == 0:
		return 2147483647
	return name.substr(0, i).to_int()


## 打开循环。帧数必须用"时长 × 采样率"算：
## 导入后可能是 QOA / IMA-ADPCM 压缩数据，data 的长度不再是帧数
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frames := int(round(wav.get_length() * float(wav.mix_rate)))
		if frames <= 0:
			push_warning("AudioEngine: WAV 长度算不出来，跳过循环")
			return
		wav.loop_begin = 0
		wav.loop_end = frames
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true
		mp3.loop_offset = 0.0


func play(key: int, velocity: float) -> void:
	if key < 0 or key >= _samples.size() or _players.is_empty():
		return

	var player := _take_free_player()
	if player == null:
		return

	_player_key[player] = key
	player.stream = _samples[key]
	player.volume_db = linear_to_db(clampf(velocity, 0.01, 1.0))
	player.play()


## 松手。A 方案（stop_on_release = false）直接什么都不做，让采样自然放完
func stop(key: int) -> void:
	if not stop_on_release:
		return

	for p in _players:
		if p.playing and _player_key.get(p, -1) == key:
			p.stop()
			_player_key.erase(p)


func stop_all() -> void:
	for p in _players:
		if p.playing:
			p.stop()
	_player_key.clear()


## 优先找空闲的；全忙就轮流抢一个（循环模式下 player 永远不会自己结束）
func _take_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p

	var victim: AudioStreamPlayer = _players[_steal_cursor % _players.size()]
	_steal_cursor += 1
	victim.stop()
	_player_key.erase(victim)
	return victim
