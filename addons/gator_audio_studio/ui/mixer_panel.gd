@tool
class_name GASMixerPanel
extends PanelContainer

signal audio_changed()
signal track_fx_requested(track_index: int)
signal master_fx_requested()
signal bus_preview_toggled(enabled: bool)
signal temporary_buses_requested()

const EditorModel := preload("res://addons/gator_audio_studio/audio/editor_model.gd")
const EditorTrack := preload("res://addons/gator_audio_studio/audio/editor_track.gd")

var _model: GASEditorModel
var _strips: HFlowContainer
var _bus_preview_check: CheckButton
var _track_peak_l: Array[ProgressBar] = []
var _track_peak_r: Array[ProgressBar] = []
var _track_rms_labels: Array[Label] = []
var _track_hold_labels: Array[Label] = []
var _track_hold_l: PackedFloat32Array = PackedFloat32Array()
var _track_hold_r: PackedFloat32Array = PackedFloat32Array()
var _master_peak_l: ProgressBar
var _master_peak_r: ProgressBar
var _master_rms_label: Label
var _master_clip_label: Label
var _master_hold_label: Label
var _master_hold_l: float = -60.0
var _master_hold_r: float = -60.0
var _hold_release_db_per_update: float = 0.75
var _meter_text_enabled: bool = true


func _ready() -> void:
	_build_shell()


func set_model(model: GASEditorModel) -> void:
	_model = model
	refresh()


func refresh() -> void:
	if _strips == null:
		return
	for child: Node in _strips.get_children():
		child.queue_free()
	_track_peak_l.clear()
	_track_peak_r.clear()
	_track_rms_labels.clear()
	_track_hold_labels.clear()
	_track_hold_l.resize(_model.tracks.size() if _model != null else 0)
	_track_hold_r.resize(_model.tracks.size() if _model != null else 0)
	for hold_index: int in range(_track_hold_l.size()):
		_track_hold_l[hold_index] = -60.0
		_track_hold_r[hold_index] = -60.0
	_master_hold_l = -60.0
	_master_hold_r = -60.0
	if _model == null:
		return
	var buses: PackedStringArray = _project_buses()
	for index: int in range(_model.tracks.size()):
		_build_track_strip(index, _model.tracks[index], buses)
	_build_master_strip()
	set_meter_text_enabled(_meter_text_enabled)


func update_meters(track_meters: Array[Vector4], master_meter: Vector4, master_clipping: bool) -> void:
	var count: int = mini(track_meters.size(), _track_peak_l.size())
	for index: int in range(count):
		var values: Vector4 = track_meters[index]
		_track_peak_l[index].value = values.x
		_track_peak_r[index].value = values.y
		_track_rms_labels[index].text = "RMS %.1f / %.1f" % [values.z, values.w]
		_track_hold_l[index] = maxf(values.x, _track_hold_l[index] - _hold_release_db_per_update)
		_track_hold_r[index] = maxf(values.y, _track_hold_r[index] - _hold_release_db_per_update)
		if index < _track_hold_labels.size():
			_track_hold_labels[index].text = "Hold %.1f / %.1f dB" % [_track_hold_l[index], _track_hold_r[index]]
	if _master_peak_l != null:
		_master_peak_l.value = master_meter.x
		_master_peak_r.value = master_meter.y
		_master_rms_label.text = "RMS %.1f / %.1f" % [master_meter.z, master_meter.w]
		_master_hold_l = maxf(master_meter.x, _master_hold_l - _hold_release_db_per_update)
		_master_hold_r = maxf(master_meter.y, _master_hold_r - _hold_release_db_per_update)
		if _master_hold_label != null:
			_master_hold_label.text = "Hold %.1f / %.1f dB" % [_master_hold_l, _master_hold_r]
		_master_clip_label.text = "CLIP" if master_clipping else ""


func set_meter_text_enabled(enabled: bool) -> void:
	_meter_text_enabled = enabled
	for label: Label in _track_rms_labels:
		if is_instance_valid(label):
			label.visible = enabled
	for label: Label in _track_hold_labels:
		if is_instance_valid(label):
			label.visible = enabled
	if _master_rms_label != null:
		_master_rms_label.visible = enabled
	if _master_hold_label != null:
		_master_hold_label.visible = enabled


func bus_preview_enabled() -> bool:
	return _bus_preview_check != null and _bus_preview_check.button_pressed


func _build_shell() -> void:
	custom_minimum_size.y = 245.0
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	root.add_child(header)
	var title: Label = Label.new()
	title.text = "MIXER"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	_bus_preview_check = CheckButton.new()
	_bus_preview_check.text = "Preview Through Godot Buses"
	_bus_preview_check.tooltip_text = "Routes each track to its selected project AudioServer bus during playback. Track sends are auditioned as additional bus feeds."
	_bus_preview_check.toggled.connect(func(value: bool) -> void: bus_preview_toggled.emit(value))
	header.add_child(_bus_preview_check)
	var temp_buses: Button = Button.new()
	temp_buses.text = "Create Temporary GAS Buses"
	temp_buses.tooltip_text = "Creates GAS Preview and GAS Send buses for this editor session. Buses created by GAS are removed when the workspace closes."
	temp_buses.pressed.connect(func() -> void: temporary_buses_requested.emit())
	header.add_child(temp_buses)
	var note: Label = Label.new()
	note.text = "Track strips wrap to fit the dock."
	note.modulate = Color(0.62, 0.68, 0.74)
	header.add_child(note)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_strips = HFlowContainer.new()
	_strips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strips.add_theme_constant_override("h_separation", 6)
	_strips.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_strips)


func _build_track_strip(index: int, track: GASEditorTrack, buses: PackedStringArray) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(185.0, 210.0)
	_strips.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var name_label: Label = Label.new()
	name_label.text = "%d  %s" % [index + 1, track.name]
	name_label.clip_text = true
	name_label.tooltip_text = track.name
	box.add_child(name_label)
	var meter_l: ProgressBar = _meter()
	var meter_r: ProgressBar = _meter()
	box.add_child(meter_l)
	box.add_child(meter_r)
	_track_peak_l.append(meter_l)
	_track_peak_r.append(meter_r)
	var rms: Label = Label.new()
	rms.text = "RMS -60.0 / -60.0"
	rms.add_theme_font_size_override("font_size", 10)
	box.add_child(rms)
	_track_rms_labels.append(rms)
	var hold: Label = Label.new()
	hold.text = "Hold -60.0 / -60.0 dB"
	hold.add_theme_font_size_override("font_size", 9)
	hold.tooltip_text = "Peak hold decays slowly so short transients remain readable."
	box.add_child(hold)
	_track_hold_labels.append(hold)
	var buttons: HBoxContainer = HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_toggle("M", track.mute, _on_mute.bind(index)))
	buttons.add_child(_toggle("S", track.solo, _on_solo.bind(index)))
	buttons.add_child(_toggle("R", track.record_armed, _on_arm.bind(index)))
	var fx: Button = Button.new()
	fx.text = "FX %d" % track.effect_stack.size()
	fx.pressed.connect(func() -> void: track_fx_requested.emit(index))
	buttons.add_child(fx)
	box.add_child(_slider_row("Gain", -36.0, 12.0, 0.5, track.gain_db, _on_gain.bind(index)))
	box.add_child(_slider_row("Pan", -1.0, 1.0, 0.05, track.pan, _on_pan.bind(index)))
	box.add_child(_option_row("Out", buses, track.output_bus, _on_output_bus, index))
	var send_choices: PackedStringArray = PackedStringArray(["None"])
	for bus_name: String in buses:
		send_choices.append(bus_name)
	box.add_child(_option_row("Send", send_choices, track.send_bus if not track.send_bus.is_empty() else "None", _on_send_bus, index))
	box.add_child(_slider_row("Send dB", -60.0, 6.0, 1.0, track.send_db, _on_send_gain.bind(index)))


func _build_master_strip() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(195.0, 210.0)
	_strips.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "MASTER"
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)
	_master_peak_l = _meter()
	_master_peak_r = _meter()
	box.add_child(_master_peak_l)
	box.add_child(_master_peak_r)
	_master_rms_label = Label.new()
	_master_rms_label.text = "RMS -60.0 / -60.0"
	_master_rms_label.add_theme_font_size_override("font_size", 10)
	box.add_child(_master_rms_label)
	_master_hold_label = Label.new()
	_master_hold_label.text = "Hold -60.0 / -60.0 dB"
	_master_hold_label.add_theme_font_size_override("font_size", 9)
	box.add_child(_master_hold_label)
	_master_clip_label = Label.new()
	_master_clip_label.text = ""
	_master_clip_label.modulate = Color(1.0, 0.32, 0.28)
	box.add_child(_master_clip_label)
	var fx: Button = Button.new()
	fx.text = "Master FX %d" % _model.master_effect_stack.size()
	fx.pressed.connect(func() -> void: master_fx_requested.emit())
	box.add_child(fx)
	box.add_child(_slider_row("Gain", -36.0, 12.0, 0.5, _model.master_gain_db, _on_master_gain))
	var limiter: CheckButton = CheckButton.new()
	limiter.text = "Master Limiter"
	limiter.button_pressed = _model.master_limiter_enabled
	limiter.toggled.connect(_on_master_limiter)
	box.add_child(limiter)
	box.add_child(_slider_row("Ceiling", -12.0, 0.0, 0.1, _model.master_limiter_ceiling_db, _on_master_ceiling))


func _on_mute(value: bool, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].mute = value
	_model.dirty = true
	audio_changed.emit()


func _on_solo(value: bool, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].solo = value
	_model.dirty = true
	audio_changed.emit()


func _on_arm(value: bool, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].record_armed = value
	_model.select_track(index, false, false)
	_model.dirty = true


func _on_gain(value: float, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].gain_db = value
	_model.dirty = true
	audio_changed.emit()


func _on_pan(value: float, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].pan = value
	_model.dirty = true
	audio_changed.emit()


func _on_output_bus(item_index: int, track_index: int, option: OptionButton) -> void:
	if not _valid_track(track_index) or item_index < 0:
		return
	_model.tracks[track_index].output_bus = option.get_item_text(item_index)
	_model.dirty = true


func _on_send_bus(item_index: int, track_index: int, option: OptionButton) -> void:
	if not _valid_track(track_index) or item_index < 0:
		return
	var selected_name: String = option.get_item_text(item_index)
	_model.tracks[track_index].send_bus = "" if selected_name == "None" else selected_name
	_model.dirty = true


func _on_send_gain(value: float, index: int) -> void:
	if not _valid_track(index):
		return
	_model.tracks[index].send_db = value
	_model.dirty = true


func _on_master_gain(value: float) -> void:
	if _model == null:
		return
	_model.master_gain_db = value
	_model.dirty = true
	audio_changed.emit()


func _on_master_limiter(value: bool) -> void:
	if _model == null:
		return
	_model.master_limiter_enabled = value
	_model.dirty = true
	audio_changed.emit()


func _on_master_ceiling(value: float) -> void:
	if _model == null:
		return
	_model.master_limiter_ceiling_db = value
	_model.dirty = true
	audio_changed.emit()


func _valid_track(index: int) -> bool:
	return _model != null and index >= 0 and index < _model.tracks.size()


func _project_buses() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for index: int in range(AudioServer.bus_count):
		result.append(AudioServer.get_bus_name(index))
	if result.is_empty():
		result.append("Master")
	return result


func _meter() -> ProgressBar:
	var meter: ProgressBar = ProgressBar.new()
	meter.min_value = -60.0
	meter.max_value = 0.0
	meter.value = -60.0
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(150.0, 12.0)
	return meter


func _toggle(text: String, pressed: bool, callback: Callable) -> CheckButton:
	var button: CheckButton = CheckButton.new()
	button.text = text
	button.button_pressed = pressed
	button.toggled.connect(callback)
	return button


func _slider_row(label_text: String, minimum: float, maximum: float, step: float, value: float, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 48.0
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	return row


func _option_row(label_text: String, items: PackedStringArray, selected_text: String, callback: Callable, track_index: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 48.0
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index: int = 0
	for index: int in range(items.size()):
		option.add_item(items[index])
		if items[index] == selected_text:
			selected_index = index
	option.select(selected_index)
	option.item_selected.connect(func(item_index: int) -> void: callback.call(item_index, track_index, option))
	row.add_child(option)
	return row
