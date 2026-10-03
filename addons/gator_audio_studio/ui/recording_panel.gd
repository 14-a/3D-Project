@tool
class_name GASRecordingPanel
extends PanelContainer

signal record_requested(device_name: String, stereo: bool, mode: int, countdown_seconds: float, timer_seconds: float, compensation_ms: float, monitor: bool)
signal stop_requested()
signal input_meter_toggled(enabled: bool)
signal monitor_toggled(enabled: bool)
signal enable_input_setting_requested()
signal refresh_devices_requested()
signal calibration_requested(device_name: String)

enum RecordMode {
	NEW_TRACK,
	SELECTED_TRACK_AT_CURSOR,
	APPEND_SELECTED_TRACK,
	PUNCH_SELECTION,
	OVERDUB_NEW_TRACK,
}

var _device_option: OptionButton
var _channel_option: OptionButton
var _mode_option: OptionButton
var _countdown_spin: SpinBox
var _timer_spin: SpinBox
var _compensation_spin: SpinBox
var _round_trip_spin: SpinBox
var _input_meter_check: CheckButton
var _monitor_check: CheckButton
var _record_button: Button
var _stop_button: Button
var _input_setting_button: Button
var _peak_l: ProgressBar
var _peak_r: ProgressBar
var _rms_label: Label
var _clip_label: Label
var _latency_label: Label
var _record_time_label: Label
var _status_label: Label


func _ready() -> void:
	_build_ui()


func set_devices(devices: PackedStringArray, selected_device: String) -> void:
	_device_option.clear()
	var chosen: int = -1
	for index: int in range(devices.size()):
		_device_option.add_item(devices[index])
		if devices[index] == selected_device:
			chosen = index
	if _device_option.item_count == 0:
		_device_option.add_item("Default")
		chosen = 0
	_device_option.select(maxi(0, chosen))


func set_input_setting_enabled(enabled: bool) -> void:
	_input_setting_button.visible = not enabled
	if not enabled:
		_status_label.text = "Audio input is disabled in Project Settings. Enable it here, then restart Godot once."


func set_recording_state(recording: bool, pending: bool = false) -> void:
	_record_button.disabled = recording or pending
	_stop_button.disabled = not recording and not pending
	_device_option.disabled = recording or pending
	_channel_option.disabled = recording or pending
	_mode_option.disabled = recording or pending
	_countdown_spin.editable = not recording and not pending
	_timer_spin.editable = not recording and not pending


func update_input_meter(peak_left: float, peak_right: float, rms_left: float, rms_right: float, clipping: bool) -> void:
	_peak_l.value = _linear_to_meter_db(peak_left)
	_peak_r.value = _linear_to_meter_db(peak_right)
	_rms_label.text = "RMS L %.1f dB  R %.1f dB" % [_linear_to_meter_db(rms_left), _linear_to_meter_db(rms_right)]
	_clip_label.text = "CLIP" if clipping else ""


func update_record_time(seconds: float) -> void:
	_record_time_label.text = "REC %s" % _format_time(seconds)


func set_latency_info(input_buffer_ms: float, output_ms: float) -> void:
	_latency_label.text = "Input buffer ~%.1f ms • Output %.1f ms" % [input_buffer_ms, output_ms]


func set_measured_round_trip(milliseconds: float) -> void:
	_round_trip_spin.value = maxf(0.0, milliseconds)


func set_status(text: String) -> void:
	_status_label.text = text


func current_mode() -> int:
	return _mode_option.selected


func current_device() -> String:
	if _device_option == null or _device_option.selected < 0:
		return "Default"
	return _device_option.get_item_text(_device_option.selected)


func current_stereo() -> bool:
	return _channel_option != null and _channel_option.selected == 1


func countdown_seconds() -> float:
	return _countdown_spin.value if _countdown_spin != null else 0.0


func trigger_record() -> void:
	_on_record()


func timer_seconds() -> float:
	return _timer_spin.value


func compensation_ms() -> float:
	return _compensation_spin.value


func monitor_enabled() -> bool:
	return _monitor_check.button_pressed


func input_meter_enabled() -> bool:
	return _input_meter_check.button_pressed


func set_input_meter_enabled(enabled: bool) -> void:
	if _input_meter_check != null:
		_input_meter_check.set_pressed_no_signal(enabled)


func set_monitor_enabled(enabled: bool) -> void:
	if _monitor_check != null:
		_monitor_check.set_pressed_no_signal(enabled)


func _build_ui() -> void:
	custom_minimum_size.y = 184.0
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	header.add_theme_constant_override("v_separation", 4)
	root.add_child(header)
	var title: Label = Label.new()
	title.text = "RECORDING"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	_input_setting_button = Button.new()
	_input_setting_button.text = "Enable Audio Input Setting"
	_input_setting_button.tooltip_text = "Enables audio/driver/enable_input in project.godot. Godot must be restarted once after changing this setting."
	_input_setting_button.pressed.connect(func() -> void: enable_input_setting_requested.emit())
	header.add_child(_input_setting_button)
	var refresh: Button = Button.new()
	refresh.text = "Refresh Devices"
	refresh.pressed.connect(func() -> void: refresh_devices_requested.emit())
	header.add_child(refresh)
	_record_time_label = Label.new()
	_record_time_label.text = "REC 00:00.000"
	header.add_child(_record_time_label)
	_clip_label = Label.new()
	_clip_label.text = ""
	_clip_label.modulate = Color(1.0, 0.32, 0.28)
	header.add_child(_clip_label)

	var settings: HFlowContainer = HFlowContainer.new()
	settings.add_theme_constant_override("h_separation", 5)
	settings.add_theme_constant_override("v_separation", 4)
	root.add_child(settings)
	settings.add_child(_label("Input"))
	_device_option = OptionButton.new()
	_device_option.custom_minimum_size.x = 180.0
	settings.add_child(_device_option)
	settings.add_child(_label("Channels"))
	_channel_option = OptionButton.new()
	_channel_option.add_item("Mono")
	_channel_option.add_item("Stereo")
	_channel_option.select(0)
	settings.add_child(_channel_option)
	settings.add_child(_label("Mode"))
	_mode_option = OptionButton.new()
	_mode_option.add_item("New Track")
	_mode_option.add_item("Selected Track @ Cursor")
	_mode_option.add_item("Append Selected Track")
	_mode_option.add_item("Punch Selection")
	_mode_option.add_item("Overdub New Track")
	_mode_option.custom_minimum_size.x = 190.0
	settings.add_child(_mode_option)
	settings.add_child(_label("Countdown"))
	_countdown_spin = _spin(0.0, 10.0, 1.0, 0.0, " s")
	settings.add_child(_countdown_spin)
	settings.add_child(_label("Timer"))
	_timer_spin = _spin(0.0, 3600.0, 0.5, 0.0, " s")
	_timer_spin.tooltip_text = "0 = manual stop. Punch mode automatically stops at the selection length."
	settings.add_child(_timer_spin)

	var options: HFlowContainer = HFlowContainer.new()
	options.add_theme_constant_override("h_separation", 6)
	root.add_child(options)
	_input_meter_check = CheckButton.new()
	_input_meter_check.text = "Input Meter"
	_input_meter_check.toggled.connect(func(value: bool) -> void: input_meter_toggled.emit(value))
	options.add_child(_input_meter_check)
	_monitor_check = CheckButton.new()
	_monitor_check.text = "Monitor Input"
	_monitor_check.tooltip_text = "Plays microphone input through the current output. Use headphones to avoid feedback."
	_monitor_check.toggled.connect(func(value: bool) -> void: monitor_toggled.emit(value))
	options.add_child(_monitor_check)
	options.add_child(_label("Manual Compensation"))
	_compensation_spin = _spin(-500.0, 1000.0, 0.1, 0.0, " ms")
	options.add_child(_compensation_spin)
	options.add_child(_label("Measured Round Trip"))
	_round_trip_spin = _spin(0.0, 1000.0, 0.1, 0.0, " ms")
	options.add_child(_round_trip_spin)
	var calibrate: Button = Button.new()
	calibrate.text = "Calibrate"
	calibrate.tooltip_text = "Plays a short calibration pulse and measures when it returns through the selected input. Use speakers or a loopback path and keep the room quiet."
	calibrate.pressed.connect(func() -> void: calibration_requested.emit(current_device()))
	options.add_child(calibrate)
	var use_round_trip: Button = Button.new()
	use_round_trip.text = "Use Measured"
	use_round_trip.tooltip_text = "Copies the measured round-trip latency into recording compensation."
	use_round_trip.pressed.connect(_on_use_measured)
	options.add_child(use_round_trip)
	_latency_label = Label.new()
	_latency_label.text = "Input buffer -- • Output --"
	options.add_child(_latency_label)

	var meter_row: HBoxContainer = HBoxContainer.new()
	root.add_child(meter_row)
	meter_row.add_child(_label("Input L"))
	_peak_l = _meter()
	meter_row.add_child(_peak_l)
	meter_row.add_child(_label("R"))
	_peak_r = _meter()
	meter_row.add_child(_peak_r)
	_rms_label = Label.new()
	_rms_label.text = "RMS L -∞ dB  R -∞ dB"
	_rms_label.custom_minimum_size.x = 190.0
	meter_row.add_child(_rms_label)

	var actions: HFlowContainer = HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 6)
	root.add_child(actions)
	_record_button = Button.new()
	_record_button.text = "● Record"
	_record_button.tooltip_text = "Start recording with the settings above"
	_record_button.pressed.connect(_on_record)
	actions.add_child(_record_button)
	_stop_button = Button.new()
	_stop_button.text = "■ Stop Recording"
	_stop_button.disabled = true
	_stop_button.pressed.connect(func() -> void: stop_requested.emit())
	actions.add_child(_stop_button)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = "Ready."
	actions.add_child(_status_label)


func _on_record() -> void:
	var device_name: String = _device_option.get_item_text(_device_option.selected) if _device_option.selected >= 0 else "Default"
	var record_stereo: bool = _channel_option.selected == 1
	record_requested.emit(device_name, record_stereo, _mode_option.selected, _countdown_spin.value, _timer_spin.value, _compensation_spin.value, _monitor_check.button_pressed)


func _on_use_measured() -> void:
	_compensation_spin.value = _round_trip_spin.value


func _label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


func _spin(minimum: float, maximum: float, step: float, value: float, suffix: String) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.suffix = suffix
	spin.custom_minimum_size.x = 94.0
	return spin


func _meter() -> ProgressBar:
	var meter: ProgressBar = ProgressBar.new()
	meter.min_value = -60.0
	meter.max_value = 0.0
	meter.value = -60.0
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(150.0, 16.0)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return meter


func _linear_to_meter_db(value: float) -> float:
	if value <= 0.000001:
		return -60.0
	return maxf(-60.0, linear_to_db(value))


func _format_time(seconds: float) -> String:
	var safe: float = maxf(0.0, seconds)
	var minutes: int = int(floor(safe / 60.0))
	var remainder: float = safe - float(minutes) * 60.0
	return "%02d:%06.3f" % [minutes, remainder]
