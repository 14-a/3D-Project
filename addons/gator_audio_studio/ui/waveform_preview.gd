@tool
class_name GASWaveformPreview
extends Control

var _samples: PackedFloat32Array = PackedFloat32Array()
var _line_color: Color = Color(0.36, 0.82, 0.62)
var _center_color: Color = Color(0.32, 0.35, 0.39, 0.8)
var _bg_color: Color = Color(0.075, 0.082, 0.095)


func _ready() -> void:
	custom_minimum_size = Vector2(320.0, 190.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_samples(samples: PackedFloat32Array) -> void:
	_samples = samples
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)
	var mid_y: float = size.y * 0.5
	draw_line(Vector2(0.0, mid_y), Vector2(size.x, mid_y), _center_color, 1.0)
	if _samples.is_empty() or size.x < 2.0:
		return
	var columns: int = maxi(1, int(size.x))
	var frames_per_column: float = float(_samples.size()) / float(columns)
	for x: int in range(columns):
		var start: int = clampi(int(floor(float(x) * frames_per_column)), 0, _samples.size() - 1)
		var finish: int = clampi(int(ceil(float(x + 1) * frames_per_column)), start + 1, _samples.size())
		var min_v: float = 1.0
		var max_v: float = -1.0
		for i: int in range(start, finish):
			var v: float = _samples[i]
			min_v = minf(min_v, v)
			max_v = maxf(max_v, v)
		var y1: float = mid_y - max_v * mid_y * 0.9
		var y2: float = mid_y - min_v * mid_y * 0.9
		draw_line(Vector2(float(x), y1), Vector2(float(x), y2), _line_color, 1.0)
