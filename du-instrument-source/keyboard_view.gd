extends Control
## 网格键盘：自己画格子、自己收触摸/鼠标、自己处理按下和松开。
## 不用 Button —— 24 个按钮在手机上又卡又难对齐。

signal key_down(key: int, velocity: float)
signal key_up(key: int)

const GridLayoutScript = preload("res://grid_layout.gd")

@export var columns: int = 12
@export var key_count: int = 24
@export var gap: float = 6.0
@export var padding: float = 0.0

@export var idle_color: Color = Color("#2b2f36")
@export var border_color: Color = Color("#4a5058")
@export var active_color: Color = Color("#4c9aff")
@export var text_color: Color = Color("#c9d1d9")

var _layout = GridLayoutScript.new()
var _pressed := {}          # key -> true
var _pointer_key := {}      # 手指/鼠标 id -> key
var _mouse_down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	_sync_layout()
	queue_redraw()


func _on_resized() -> void:
	_sync_layout()
	queue_redraw()


func _sync_layout() -> void:
	_layout.columns = columns
	_layout.gap = gap
	_layout.padding = padding
	_layout.set_key_count(key_count)
	_layout.resize(size)


## 换音的数量（例如音频文件读完后按实际数量设置）
func set_key_count(count: int) -> void:
	key_count = max(1, count)
	_layout.set_key_count(key_count)
	release_all()
	queue_redraw()


## 松开所有音，切后台、来电、翻页前调用
func release_all() -> void:
	for key in _pressed.keys():
		key_up.emit(key)
	_pressed.clear()
	_pointer_key.clear()
	_mouse_down = false
	queue_redraw()


func _press(id: int, key: int, pos: Vector2) -> void:
	if key < 0:
		return
	if _pointer_key.has(id) and _pointer_key[id] == key:
		return
	if _pointer_key.has(id):
		_release(id)

	_pointer_key[id] = key
	_pressed[key] = true
	key_down.emit(key, _velocity_at(key, pos))
	queue_redraw()


func _release(id: int) -> void:
	if not _pointer_key.has(id):
		return
	var key: int = _pointer_key[id]
	_pointer_key.erase(id)
	_pressed.erase(key)
	key_up.emit(key)
	queue_redraw()


## 力度：按在格子上半部分轻、下半部分重
func _velocity_at(key: int, pos: Vector2) -> float:
	var r := _layout.rect_of(key)
	var t := clampf((pos.y - r.position.y) / r.size.y, 0.0, 1.0)
	return lerpf(0.4, 1.0, t)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, _layout.index_at(event.position), event.position)
		else:
			_release(event.index)

	elif event is InputEventScreenDrag:
		if not _pointer_key.has(event.index):
			return
		var target: int = _layout.index_at(event.position)
		if target < 0:
			_release(event.index)
		elif target != _pointer_key[event.index]:
			_release(event.index)
			_press(event.index, target, event.position)

	# 桌面调试用：鼠标按下/拖动当成一根手指
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_press(-1, _layout.index_at(event.position), event.position)
		elif _mouse_down:
			_mouse_down = false
			_release(-1)

	elif event is InputEventMouseMotion and _mouse_down:
		var hover_key: int = _layout.index_at(event.position)
		if hover_key < 0:
			_release(-1)
		elif not _pointer_key.has(-1) or _pointer_key[-1] != hover_key:
			_press(-1, hover_key, event.position)


func _draw() -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	var font_size: int = max(12, int(_layout.rect_of(0).size.x * 0.10))

	for i in key_count:
		var r := _layout.rect_of(i)
		var active: bool = _pressed.has(i)

		draw_rect(r, active_color if active else idle_color)
		draw_rect(r, border_color, false, 1.5)

		var label := str(i + 1)
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var at: Vector2 = r.position + (r.size - text_size) * 0.5
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color.WHITE if active else text_color)
