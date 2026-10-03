@tool
class_name GASSpectrogramView
extends Control

var gain_db: float = 0.0
var dynamic_range_db: float = 90.0
var min_frequency: float = 20.0
var max_frequency: float = 20000.0
var logarithmic_frequency: bool = true

var _texture: ImageTexture
var _data: Dictionary = {}
var _bg: Color = Color(0.045, 0.05, 0.06)
var _grid: Color = Color(0.85, 0.88, 0.92, 0.22)
var _text: Color = Color(0.82, 0.84, 0.88)


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 220.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spectrogram(data: Dictionary) -> void:
	_data = data.duplicate(false)
	_build_texture()
	queue_redraw()


func clear() -> void:
	_data.clear()
	_texture = null
	queue_redraw()


func refresh_color_mapping() -> void:
	if not _data.is_empty():
		_build_texture()
	queue_redraw()


func _build_texture() -> void:
	var columns: int = int(_data.get("columns", 0))
	var rows: int = int(_data.get("rows", 0))
	var values_value: Variant = _data.get("values", PackedFloat32Array())
	var values: PackedFloat32Array = values_value as PackedFloat32Array
	if columns <= 0 or rows <= 0 or values.size() < columns * rows:
		_texture = null
		return
	var color_lut: PackedByteArray = _build_color_lut()
	var pixels: PackedByteArray = PackedByteArray()
	pixels.resize(columns * rows * 4)
	var floor_db: float = -maxf(20.0, dynamic_range_db)
	var inv_range: float = 1.0 / maxf(0.000001, -floor_db)
	for row: int in range(rows):
		var source_row: int = row * columns
		var destination_row: int = (rows - 1 - row) * columns
		for column: int in range(columns):
			var db_value: float = values[source_row + column] + gain_db
			var t: float = clampf((db_value - floor_db) * inv_range, 0.0, 1.0)
			var lut_offset: int = clampi(int(t * 255.0 + 0.5), 0, 255) * 4
			var pixel_offset: int = (destination_row + column) * 4
			pixels[pixel_offset] = color_lut[lut_offset]
			pixels[pixel_offset + 1] = color_lut[lut_offset + 1]
			pixels[pixel_offset + 2] = color_lut[lut_offset + 2]
			pixels[pixel_offset + 3] = 255
	var image: Image = Image.create_from_data(columns, rows, false, Image.FORMAT_RGBA8, pixels)
	_texture = ImageTexture.create_from_image(image)


func _build_color_lut() -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	output.resize(256 * 4)
	for index: int in range(256):
		var color: Color = _spectral_color(float(index) / 255.0)
		var offset: int = index * 4
		output[offset] = clampi(int(color.r * 255.0 + 0.5), 0, 255)
		output[offset + 1] = clampi(int(color.g * 255.0 + 0.5), 0, 255)
		output[offset + 2] = clampi(int(color.b * 255.0 + 0.5), 0, 255)
		output[offset + 3] = 255
	return output


func _spectral_color(t: float) -> Color:
	var value: float = clampf(t, 0.0, 1.0)
	if value < 0.25:
		var segment_a: float = value / 0.25
		return Color(0.02 + segment_a * 0.04, 0.025 + segment_a * 0.07, 0.08 + segment_a * 0.30, 1.0)
	if value < 0.50:
		var segment_b: float = (value - 0.25) / 0.25
		return Color(0.06 + segment_b * 0.12, 0.095 + segment_b * 0.36, 0.38 + segment_b * 0.28, 1.0)
	if value < 0.75:
		var segment_c: float = (value - 0.50) / 0.25
		return Color(0.18 + segment_c * 0.62, 0.455 + segment_c * 0.31, 0.66 - segment_c * 0.43, 1.0)
	var segment_d: float = (value - 0.75) / 0.25
	return Color(0.80 + segment_d * 0.20, 0.765 + segment_d * 0.22, 0.23 + segment_d * 0.63, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg, true)
	if _texture == null:
		draw_string(get_theme_default_font(), Vector2(12.0, 24.0), "Run Spectrogram to generate a time/frequency view.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, _text)
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	_draw_frequency_grid()


func _draw_frequency_grid() -> void:
	var frequencies: PackedFloat32Array = PackedFloat32Array([50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0])
	for frequency: float in frequencies:
		if frequency < min_frequency or frequency > max_frequency:
			continue
		var y: float = _frequency_to_y(frequency)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), _grid, 1.0)
		var label: String = "%.0f Hz" % frequency if frequency < 1000.0 else "%.0f kHz" % (frequency / 1000.0)
		draw_string(get_theme_default_font(), Vector2(4.0, y - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, _text)


func _frequency_to_y(frequency: float) -> float:
	var fraction: float = 0.0
	if logarithmic_frequency:
		var low: float = maxf(1.0, min_frequency)
		var high: float = maxf(low + 1.0, max_frequency)
		fraction = (log(maxf(low, frequency)) - log(low)) / maxf(0.000001, log(high) - log(low))
	else:
		fraction = (frequency - min_frequency) / maxf(0.000001, max_frequency - min_frequency)
	return (1.0 - clampf(fraction, 0.0, 1.0)) * size.y
