@tool
class_name GASSpectrumView
extends Control

var spectrum_db: PackedFloat32Array = PackedFloat32Array()
var sample_rate: int = 44100
var fft_size: int = 2048
var min_frequency: float = 20.0
var max_frequency: float = 20000.0
var gain_db: float = 0.0
var dynamic_range_db: float = 90.0
var logarithmic_frequency: bool = true
var bar_mode: bool = false
var peak_frequency: float = 0.0
var dominant_frequency: float = 0.0

var _bg: Color = Color(0.055, 0.06, 0.07)
var _grid: Color = Color(0.22, 0.24, 0.28, 0.72)
var _line: Color = Color(0.35, 0.82, 0.67)
var _bar: Color = Color(0.32, 0.64, 0.88, 0.88)
var _text: Color = Color(0.78, 0.81, 0.85)
var _peak: Color = Color(0.95, 0.76, 0.28)


func _ready() -> void:
	custom_minimum_size = Vector2(420.0, 220.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spectrum(data: Dictionary) -> void:
	var db_value: Variant = data.get("db", PackedFloat32Array())
	spectrum_db = db_value as PackedFloat32Array
	fft_size = int(data.get("size", fft_size))
	peak_frequency = float(data.get("peak_hz", 0.0))
	dominant_frequency = peak_frequency
	queue_redraw()


func clear() -> void:
	spectrum_db = PackedFloat32Array()
	peak_frequency = 0.0
	dominant_frequency = 0.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg, true)
	_draw_grid()
	if spectrum_db.size() < 2 or sample_rate <= 0 or fft_size <= 0:
		draw_string(get_theme_default_font(), Vector2(12.0, 24.0), "Run Analyze or start playback for spectrum data.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, _text)
		return
	var floor_db: float = -maxf(20.0, dynamic_range_db)
	var top_db: float = gain_db
	if bar_mode:
		_draw_bars(floor_db, top_db)
	else:
		_draw_line_spectrum(floor_db, top_db)
	if peak_frequency > 0.0:
		var peak_x: float = _frequency_to_x(peak_frequency)
		if peak_x >= 0.0 and peak_x <= size.x:
			draw_line(Vector2(peak_x, 0.0), Vector2(peak_x, size.y), _peak, 1.0)
			draw_string(get_theme_default_font(), Vector2(minf(size.x - 90.0, peak_x + 4.0), 16.0), "%.1f Hz" % peak_frequency, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, _peak)


func _draw_grid() -> void:
	var db_lines: PackedFloat32Array = PackedFloat32Array([0.0, -12.0, -24.0, -36.0, -48.0, -60.0, -72.0, -84.0])
	var floor_db: float = -maxf(20.0, dynamic_range_db)
	for db_value: float in db_lines:
		if db_value < floor_db:
			continue
		var y: float = _db_to_y(db_value, floor_db, gain_db)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), _grid, 1.0)
		draw_string(get_theme_default_font(), Vector2(4.0, y - 2.0), "%d dB" % int(db_value), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, _text)
	var frequencies: PackedFloat32Array = PackedFloat32Array([20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0])
	for frequency: float in frequencies:
		if frequency < min_frequency or frequency > max_frequency:
			continue
		var x: float = _frequency_to_x(frequency)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), _grid, 1.0)
		var label: String = "%.0f" % frequency if frequency < 1000.0 else "%.0fk" % (frequency / 1000.0)
		draw_string(get_theme_default_font(), Vector2(x + 2.0, size.y - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, _text)


func _draw_line_spectrum(floor_db: float, top_db: float) -> void:
	var bin_hz: float = float(sample_rate) / float(fft_size)
	var points: PackedVector2Array = PackedVector2Array()
	var previous_x: float = -1000.0
	for bin: int in range(1, spectrum_db.size()):
		var frequency: float = float(bin) * bin_hz
		if frequency < min_frequency or frequency > max_frequency:
			continue
		var x: float = _frequency_to_x(frequency)
		if x - previous_x < 0.75 and bin + 1 < spectrum_db.size():
			continue
		var y: float = _db_to_y(spectrum_db[bin] + gain_db, floor_db, top_db)
		points.append(Vector2(x, y))
		previous_x = x
	if points.size() >= 2:
		draw_polyline(points, _line, 1.5, true)


func _draw_bars(floor_db: float, top_db: float) -> void:
	var bar_count: int = clampi(int(size.x / 8.0), 24, 128)
	var bin_hz: float = float(sample_rate) / float(fft_size)
	for bar_index: int in range(bar_count):
		var a_fraction: float = float(bar_index) / float(bar_count)
		var b_fraction: float = float(bar_index + 1) / float(bar_count)
		var a_hz: float = _fraction_to_frequency(a_fraction)
		var b_hz: float = _fraction_to_frequency(b_fraction)
		var start_bin: int = clampi(int(floor(a_hz / bin_hz)), 1, spectrum_db.size() - 1)
		var end_bin: int = clampi(int(ceil(b_hz / bin_hz)), start_bin + 1, spectrum_db.size())
		var maximum_db: float = -160.0
		for bin: int in range(start_bin, end_bin):
			maximum_db = maxf(maximum_db, spectrum_db[bin] + gain_db)
		var x0: float = float(bar_index) / float(bar_count) * size.x
		var x1: float = float(bar_index + 1) / float(bar_count) * size.x
		var y: float = _db_to_y(maximum_db, floor_db, top_db)
		draw_rect(Rect2(x0 + 1.0, y, maxf(1.0, x1 - x0 - 2.0), size.y - y), _bar, true)


func _frequency_to_x(frequency: float) -> float:
	if logarithmic_frequency:
		var low: float = maxf(1.0, min_frequency)
		var high: float = maxf(low + 1.0, max_frequency)
		var fraction: float = (log(maxf(low, frequency)) - log(low)) / maxf(0.000001, log(high) - log(low))
		return clampf(fraction, 0.0, 1.0) * size.x
	var linear_fraction: float = (frequency - min_frequency) / maxf(0.000001, max_frequency - min_frequency)
	return clampf(linear_fraction, 0.0, 1.0) * size.x


func _fraction_to_frequency(fraction: float) -> float:
	var t: float = clampf(fraction, 0.0, 1.0)
	if logarithmic_frequency:
		var low: float = maxf(1.0, min_frequency)
		var high: float = maxf(low + 1.0, max_frequency)
		return exp(lerpf(log(low), log(high), t))
	return lerpf(min_frequency, max_frequency, t)


func _db_to_y(db_value: float, floor_db: float, top_db: float) -> float:
	var normalized: float = (clampf(db_value, floor_db, top_db) - floor_db) / maxf(0.000001, top_db - floor_db)
	return (1.0 - normalized) * size.y
