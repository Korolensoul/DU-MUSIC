extends Control
## 入口：把键盘的按下/松开接到音频引擎上，顺便在左上角显示一行诊断信息。

@onready var _keyboard = $KeyboardView
@onready var _audio = $AudioEngine

var _hud: Label


func _ready() -> void:
	_keyboard.key_down.connect(_on_key_down)
	_keyboard.key_up.connect(_on_key_up)

	_audio.load_samples()
	if _audio.sample_count > 0:
		_keyboard.set_key_count(_audio.sample_count)

	# 左上角一行小字：采样数 + 最后按的键，出问题时一眼能看出卡在哪
	_hud = Label.new()
	_hud.position = Vector2(16, 6)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_font_size_override("font_size", 20)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	add_child(_hud)
	_update_hud(-1)


func _on_key_down(key: int, velocity: float) -> void:
	_audio.play(key, velocity)
	_update_hud(key)


func _on_key_up(key: int) -> void:
	_audio.stop(key)


func _update_hud(key: int) -> void:
	if key < 0:
		_hud.text = "采样 %d" % _audio.sample_count
	else:
		_hud.text = "采样 %d · 键 %d" % [_audio.sample_count, key + 1]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_instance_valid(_keyboard):
			_keyboard.release_all()
