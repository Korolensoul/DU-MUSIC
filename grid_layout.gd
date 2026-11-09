extends RefCounted
## 纯计算：把一块矩形切成网格，算每个格子的位置、把屏幕坐标换算成格子编号。
## 不继承 Node，不需要挂到场景上 —— KeyboardView 里直接 new 一个用。

var columns: int = 12
var key_count: int = 24
var rows: int = 2
var gap: float = 6.0
var padding: float = 0.0
var size: Vector2 = Vector2(1920, 1080)


func resize(new_size: Vector2) -> void:
	size = new_size


## 设置音的数量，按列数自动算行数
func set_key_count(count: int) -> void:
	key_count = max(1, count)
	rows = (key_count + columns - 1) / columns


func cell_width() -> float:
	return (size.x - 2.0 * padding - (columns - 1) * gap) / columns


func cell_height() -> float:
	return (size.y - 2.0 * padding - (rows - 1) * gap) / rows


## 第 index 个格子的矩形（从左到右、从上到下编号）
func rect_of(index: int) -> Rect2:
	var w := cell_width()
	var h := cell_height()
	var col := index % columns
	var row := index / columns
	var pos := Vector2(padding + col * (w + gap), padding + row * (h + gap))
	return Rect2(pos, Vector2(w, h))


## 命中测试：屏幕点 -> 格子编号，没打中返回 -1
## 缝里和留白里也算作最近的格子，避免出现"按了没反应"的死区
func index_at(p: Vector2) -> int:
	var w := cell_width()
	var h := cell_height()
	if w <= 0.0 or h <= 0.0:
		return -1

	var x := p.x - padding
	var y := p.y - padding
	if x < 0.0 or y < 0.0:
		return -1

	var col := int(x / (w + gap))
	var row := int(y / (h + gap))
	if col >= columns:
		col = columns - 1
	if row >= rows:
		row = rows - 1
	if col < 0 or row < 0:
		return -1

	var index := row * columns + col
	return index if index < key_count else -1
