@tool
class_name GASAnalyzerPanel
extends PanelContainer

signal markers_requested(frames: PackedInt32Array, prefix: String)
signal status_changed(message: String)

const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")
const SpectrumView := preload("res://addons/gator_audio_studio/ui/spectrum_view.gd")
const SpectrogramView := preload("res://addons/gator_audio_studio/ui/spectrogram_view.gd")
const AnalyzerBackgroundJob := preload("res://addons/gator_audio_studio/audio/analyzer_background_job.gd")
const ExtensionAPI: GDScript = preload("res://addons/gator_audio_studio/audio/extension_api.gd")

var model: GASEditorModel
var _scope_option: OptionButton
var _selection_check: CheckButton
var _fft_option: OptionButton
var _window_option: OptionButton
var _min_frequency: SpinBox
var _max_frequency: SpinBox
var _gain: SpinBox
var _dynamic_range: SpinBox
var _log_frequency: CheckButton
var _live_check: CheckButton
var _spectrum_view: GASSpectrumView
var _spectrogram_view: GASSpectrogramView
var _metrics: RichTextLabel
var _beat_threshold: SpinBox
var _beat_spacing: SpinBox
var _bpm_label: Label
var _job_label: Label
var _extension_option: OptionButton
var _extension_run_button: Button
var _last_analysis: Dictionary = {}
var _last_beats: Dictionary = {}
var _last_spectrogram: Dictionary = {}
var _job: GASAnalyzerBackgroundJob
var _live_job: GASAnalyzerBackgroundJob
var _job_kind: String = ""
var _live_elapsed: float = 0.0


func _ready() -> void:
	custom_minimum_size.y = 330.0
	_build_ui()
	set_process(true)


func set_model(value: GASEditorModel) -> void:
	model = value


func _exit_tree() -> void:
	# Analyzer workers are self-contained RefCounted jobs. Do not block plugin
	# deactivation waiting for long FFT/spectrogram work to finish.
	_job = null
	_live_job = null


func is_live_enabled() -> bool:
	return _live_check != null and _live_check.button_pressed and visible


func update_realtime(pcm: GASPCMData, center_frame: int, delta: float) -> void:
	if not is_live_enabled() or pcm == null or pcm.frame_count() <= 0:
		return
	_live_elapsed += delta
	if _live_elapsed < 0.10 or _live_job != null:
		return
	_live_elapsed = 0.0
	var size: int = mini(2048, _selected_fft_size())
	var half: int = size / 2
	var start_frame: int = clampi(center_frame - half, 0, maxi(0, pcm.frame_count() - 1))
	var end_frame: int = mini(pcm.frame_count(), start_frame + size)
	# Copy only the bounded live-analysis window on the main thread. All FFT work
	# happens on the worker, so realtime bars cannot stall the editor frame.
	var window_pcm: GASPCMData = pcm.slice_frames(start_frame, end_frame)
	var job: GASAnalyzerBackgroundJob = AnalyzerBackgroundJob.new() as GASAnalyzerBackgroundJob
	if job != null and job.start_live(window_pcm, size, _window_option.selected):
		_live_job = job


func refresh_extensions() -> void:
	if _extension_option == null:
		return
	var previous_id: String = ""
	if _extension_option.selected >= 0:
		var previous_value: Variant = _extension_option.get_item_metadata(_extension_option.selected)
		previous_id = str(previous_value) if previous_value != null else ""
	_extension_option.clear()
	var analyzer_ids: PackedStringArray = ExtensionAPI.analyzer_extension_ids()
	var selected_index: int = 0
	for index: int in range(analyzer_ids.size()):
		var analyzer_id: StringName = StringName(analyzer_ids[index])
		var analyzer: GASAnalyzerExtension = ExtensionAPI.create_analyzer_extension(analyzer_id)
		if analyzer == null:
			continue
		var item_index: int = _extension_option.get_item_count()
		_extension_option.add_item(analyzer.get_display_name())
		_extension_option.set_item_metadata(item_index, str(analyzer_id))
		_extension_option.set_item_tooltip(item_index, analyzer.get_description())
		if str(analyzer_id) == previous_id:
			selected_index = item_index
	if _extension_option.get_item_count() > 0:
		_extension_option.select(selected_index)
	var has_extensions: bool = _extension_option.get_item_count() > 0
	_extension_option.visible = has_extensions
	if _extension_run_button != null:
		_extension_run_button.visible = has_extensions


func request_extension_analysis() -> void:
	if _job != null:
		status_changed.emit("Analyzer is already processing a job.")
		return
	if _extension_option == null or _extension_option.selected < 0:
		status_changed.emit("No extension analyzer is registered.")
		return
	var metadata: Variant = _extension_option.get_item_metadata(_extension_option.selected)
	var analyzer_id: StringName = StringName(str(metadata))
	if str(analyzer_id).is_empty():
		return
	var use_mixdown: bool = _scope_option.selected == 1
	var snapshot: GASEditorModel = _create_source_snapshot(use_mixdown)
	if snapshot == null or snapshot.project_end_frame() <= 0:
		status_changed.emit("Extension analyzer needs audio on the selected track or in the mixdown.")
		return
	var requested_start: int = -1
	var requested_end: int = -1
	if _selection_check.button_pressed and model != null and model.has_selection():
		requested_start = model.selection_start
		requested_end = model.selection_end
	var job: GASAnalyzerBackgroundJob = AnalyzerBackgroundJob.new() as GASAnalyzerBackgroundJob
	if job != null and job.start_extension(snapshot, use_mixdown, requested_start, requested_end, analyzer_id):
		_job = job
		_job_kind = "extension"
		_job_label.text = "Running extension analyzer in background…"
		status_changed.emit("Extension analyzer is running in background…")


func request_analysis(include_spectrogram: bool = false) -> void:
	if _job != null:
		status_changed.emit("Analyzer is already processing a job.")
		return
	var use_mixdown: bool = _scope_option.selected == 1
	var snapshot: GASEditorModel = _create_source_snapshot(use_mixdown)
	if snapshot == null or snapshot.project_end_frame() <= 0:
		status_changed.emit("Analyzer needs audio on the selected track or in the mixdown.")
		return
	var requested_start: int = -1
	var requested_end: int = -1
	if _selection_check.button_pressed and model != null and model.has_selection():
		requested_start = model.selection_start
		requested_end = model.selection_end
	var fft_size: int = _selected_fft_size()
	var window_type: int = _window_option.selected
	var min_hz: float = float(_min_frequency.value)
	var max_hz: float = float(_max_frequency.value)
	var log_scale: bool = _log_frequency.button_pressed
	_job_kind = "analysis+spectrogram" if include_spectrogram else "analysis"
	_job_label.text = "Rendering + analyzing in background…"
	status_changed.emit("Analyzer rendering and processing in background…")
	var job: GASAnalyzerBackgroundJob = AnalyzerBackgroundJob.new() as GASAnalyzerBackgroundJob
	if job != null and job.start_analysis(snapshot, use_mixdown, requested_start, requested_end, fft_size, window_type, min_hz, max_hz, log_scale, include_spectrogram):
		_job = job


func request_beats() -> void:
	if _job != null:
		status_changed.emit("Analyzer is already processing a job.")
		return
	var use_mixdown: bool = _scope_option.selected == 1
	var snapshot: GASEditorModel = _create_source_snapshot(use_mixdown)
	if snapshot == null or snapshot.project_end_frame() <= 0:
		status_changed.emit("Beat detection needs audio.")
		return
	var requested_start: int = -1
	var requested_end: int = -1
	if _selection_check.button_pressed and model != null and model.has_selection():
		requested_start = model.selection_start
		requested_end = model.selection_end
	var threshold: float = float(_beat_threshold.value)
	var spacing: float = float(_beat_spacing.value) * 0.001
	_job_kind = "beats"
	_job_label.text = "Rendering + detecting beats in background…"
	var job: GASAnalyzerBackgroundJob = AnalyzerBackgroundJob.new() as GASAnalyzerBackgroundJob
	if job != null and job.start_beats(snapshot, use_mixdown, requested_start, requested_end, threshold, spacing):
		_job = job


func _process(_delta: float) -> void:
	_process_live_job()
	if _job == null or not _job.is_complete():
		return
	var completed: GASAnalyzerBackgroundJob = _job
	_job = null
	var result: Dictionary = completed.finish()
	var error_message: String = str(result.get("error", ""))
	if not error_message.is_empty():
		_job_label.text = "Analyzer failed"
		status_changed.emit(error_message)
		_job_kind = ""
		return
	if _job_kind == "beats":
		_apply_beat_result(result)
	elif _job_kind == "extension":
		_apply_extension_result(result)
	else:
		_apply_analysis_result(result)
	_job_kind = ""


func _process_live_job() -> void:
	if _live_job == null or not _live_job.is_complete():
		return
	var completed: GASAnalyzerBackgroundJob = _live_job
	_live_job = null
	var spectrum: Dictionary = completed.finish()
	if spectrum.is_empty() or not is_live_enabled():
		return
	_configure_views()
	_spectrum_view.bar_mode = true
	_spectrum_view.set_spectrum(spectrum)
	var peak_hz: float = float(spectrum.get("peak_hz", 0.0))
	_job_label.text = "LIVE • Peak %.1f Hz" % peak_hz


func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	header.add_theme_constant_override("v_separation", 4)
	root.add_child(header)
	var title: Label = Label.new()
	title.text = "ANALYZER / SPECTRAL VIEW"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	header.add_child(_label("Scope"))
	_scope_option = OptionButton.new()
	_scope_option.add_item("Selected Track")
	_scope_option.add_item("Mixdown")
	header.add_child(_scope_option)
	_selection_check = CheckButton.new()
	_selection_check.text = "Use Time Selection"
	_selection_check.button_pressed = true
	header.add_child(_selection_check)
	header.add_child(_label("FFT"))
	_fft_option = OptionButton.new()
	for size: int in PackedInt32Array([512, 1024, 2048, 4096, 8192, 16384]):
		_fft_option.add_item(str(size))
	_fft_option.select(3)
	header.add_child(_fft_option)
	header.add_child(_label("Window"))
	_window_option = OptionButton.new()
	for window_name: String in FFTEngine.window_names():
		_window_option.add_item(window_name)
	_window_option.select(FFTEngine.WINDOW_HANN)
	header.add_child(_window_option)
	_add_button(header, "Analyze", "Calculate spectrum and measurements for the selected source", request_analysis.bind(false))
	_add_button(header, "Spectrogram", "Calculate measurements plus the time/frequency spectrogram", request_analysis.bind(true))
	_extension_option = OptionButton.new()
	_extension_option.custom_minimum_size.x = 150.0
	header.add_child(_extension_option)
	_extension_run_button = Button.new()
	_extension_run_button.text = "Run Extension"
	_extension_run_button.tooltip_text = "Run the selected third-party GAS analyzer on the current source."
	_extension_run_button.pressed.connect(request_extension_analysis)
	header.add_child(_extension_run_button)
	refresh_extensions()
	_live_check = CheckButton.new()
	_live_check.text = "Live Bars"
	_live_check.tooltip_text = "While audio is playing, update a lightweight spectrum around the playback cursor."
	_live_check.toggled.connect(_on_live_toggled)
	header.add_child(_live_check)
	_add_button(header, "Hide", "Hide the analyzer panel", _on_hide)

	var settings: HFlowContainer = HFlowContainer.new()
	settings.add_theme_constant_override("h_separation", 6)
	settings.add_theme_constant_override("v_separation", 4)
	root.add_child(settings)
	settings.add_child(_label("Min Hz"))
	_min_frequency = _spin(0.0, 22000.0, 1.0, 20.0, 78.0)
	settings.add_child(_min_frequency)
	settings.add_child(_label("Max Hz"))
	_max_frequency = _spin(20.0, 96000.0, 10.0, 20000.0, 88.0)
	settings.add_child(_max_frequency)
	settings.add_child(_label("Gain dB"))
	_gain = _spin(-30.0, 60.0, 1.0, 0.0, 72.0)
	_gain.value_changed.connect(_on_display_setting_changed)
	settings.add_child(_gain)
	settings.add_child(_label("Range dB"))
	_dynamic_range = _spin(20.0, 160.0, 1.0, 90.0, 72.0)
	_dynamic_range.value_changed.connect(_on_display_setting_changed)
	settings.add_child(_dynamic_range)
	_log_frequency = CheckButton.new()
	_log_frequency.text = "Log Frequency"
	_log_frequency.button_pressed = true
	_log_frequency.toggled.connect(_on_display_setting_toggled)
	settings.add_child(_log_frequency)
	_job_label = Label.new()
	_job_label.text = "Ready"
	_job_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(_job_label)

	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 225.0
	root.add_child(tabs)
	_spectrum_view = SpectrumView.new()
	_spectrum_view.name = "Spectrum"
	tabs.add_child(_spectrum_view)
	_spectrogram_view = SpectrogramView.new()
	_spectrogram_view.name = "Spectrogram"
	tabs.add_child(_spectrogram_view)
	var metrics_tab: VBoxContainer = VBoxContainer.new()
	metrics_tab.name = "Measurements & Detection"
	tabs.add_child(metrics_tab)
	var detection: HFlowContainer = HFlowContainer.new()
	metrics_tab.add_child(detection)
	detection.add_child(_label("Beat threshold"))
	_beat_threshold = _spin(1.05, 3.0, 0.05, 1.45, 70.0)
	detection.add_child(_beat_threshold)
	detection.add_child(_label("Min spacing ms"))
	_beat_spacing = _spin(80.0, 1000.0, 10.0, 180.0, 80.0)
	detection.add_child(_beat_spacing)
	_add_button(detection, "Detect Beats", "Transient/energy detection plus tempo autocorrelation", request_beats)
	_add_button(detection, "Add Beat Markers", "Add detected beats to the Audio Editor timeline", _on_add_beat_markers)
	_add_button(detection, "Add Silence Markers", "Add markers at detected silence-region starts", _on_add_silence_markers)
	_add_button(detection, "Add Sound Markers", "Add markers at detected sound-region starts", _on_add_sound_markers)
	_add_button(detection, "Add Clip Markers", "Add markers at detected clipping-region starts", _on_add_clip_markers)
	_bpm_label = Label.new()
	_bpm_label.text = "BPM: —"
	detection.add_child(_bpm_label)
	_metrics = RichTextLabel.new()
	_metrics.bbcode_enabled = true
	_metrics.fit_content = false
	_metrics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_metrics.text = "Run Analyze to calculate measurements."
	metrics_tab.add_child(_metrics)
	_configure_views()


func _create_source_snapshot(use_mixdown: bool) -> GASEditorModel:
	if model == null:
		return null
	if use_mixdown:
		return model.create_render_snapshot()
	if model.selected_track < 0 or model.selected_track >= model.tracks.size():
		return null
	return model.create_track_render_snapshot(model.selected_track)


func _selected_fft_size() -> int:
	if _fft_option == null or _fft_option.item_count == 0:
		return 4096
	return int(_fft_option.get_item_text(_fft_option.selected))


func _apply_extension_result(result: Dictionary) -> void:
	var extension_result_value: Variant = result.get("extension_result", {})
	var extension_result: Dictionary = extension_result_value as Dictionary if extension_result_value is Dictionary else {}
	var extension_id: StringName = StringName(str(result.get("extension_id", "")))
	var analyzer: GASAnalyzerExtension = ExtensionAPI.create_analyzer_extension(extension_id)
	var display_name: String = analyzer.get_display_name() if analyzer != null else str(extension_id)
	_job_label.text = "Extension complete"
	_metrics.text = "[b]%s[/b]\n%s" % [display_name, JSON.stringify(extension_result, "  ")]
	status_changed.emit("%s analysis complete." % display_name)


func _apply_analysis_result(result: Dictionary) -> void:
	var analysis_value: Variant = result.get("analysis", {})
	var analysis: Dictionary = analysis_value as Dictionary
	_last_analysis = analysis
	var spectrum_value: Variant = analysis.get("spectrum", {})
	var spectrum: Dictionary = spectrum_value as Dictionary
	_configure_views()
	_spectrum_view.bar_mode = false
	_spectrum_view.set_spectrum(spectrum)
	var spectrogram_value: Variant = result.get("spectrogram", {})
	if spectrogram_value is Dictionary:
		var spectrogram: Dictionary = spectrogram_value as Dictionary
		if not spectrogram.is_empty():
			_last_spectrogram = spectrogram
			_spectrogram_view.set_spectrogram(spectrogram)
	_update_metrics_text()
	_job_label.text = "Analysis complete • Peak %.1f Hz" % float(spectrum.get("peak_hz", 0.0))
	status_changed.emit("Analysis complete.")


func _apply_beat_result(result: Dictionary) -> void:
	_last_beats = result
	var bpm: float = float(result.get("bpm", 0.0))
	var confidence: float = float(result.get("confidence", 0.0))
	var beats_value: Variant = result.get("beats", PackedInt32Array())
	var beats: PackedInt32Array = beats_value as PackedInt32Array
	_bpm_label.text = "BPM: %.1f • Confidence %.0f%% • %d beats" % [bpm, confidence * 100.0, beats.size()]
	_job_label.text = "Beat detection complete"
	status_changed.emit("Beat detection complete: %.1f BPM, %d beats." % [bpm, beats.size()])


func _update_metrics_text() -> void:
	if _last_analysis.is_empty():
		_metrics.text = "Run Analyze to calculate measurements."
		return
	var clipping_value: Variant = _last_analysis.get("clipping_regions", [])
	var silence_value: Variant = _last_analysis.get("silence_regions", [])
	var sound_value: Variant = _last_analysis.get("sound_regions", [])
	var clipping_regions: Array = clipping_value as Array
	var silence_regions: Array = silence_value as Array
	var sound_regions: Array = sound_value as Array
	var text: String = "[b]Signal[/b]\n"
	text += "Duration: %.4f s    Samples: %d    Rate: %d Hz    Channels: %d\n" % [float(_last_analysis.get("duration_seconds", 0.0)), int(_last_analysis.get("sample_count", 0)), int(_last_analysis.get("sample_rate", 0)), int(_last_analysis.get("channels", 0))]
	text += "Peak: %.2f dBFS    RMS: %.2f dBFS    Dynamic range: %.2f dB\n" % [float(_last_analysis.get("peak_db", -160.0)), float(_last_analysis.get("rms_db", -160.0)), float(_last_analysis.get("dynamic_range_db", 0.0))]
	text += "DC offset: %.7f    Zero crossings: %d    ZCR: %.2f / s\n" % [float(_last_analysis.get("dc_offset", 0.0)), int(_last_analysis.get("zero_crossings", 0)), float(_last_analysis.get("zero_crossing_rate", 0.0))]
	text += "Estimated fundamental: %.2f Hz\n\n" % float(_last_analysis.get("fundamental_hz", 0.0))
	text += "[b]Detection[/b]\nClipped samples: %d    Clip regions: %d    Silence regions: %d    Sound regions: %d\n" % [int(_last_analysis.get("clipped_samples", 0)), clipping_regions.size(), silence_regions.size(), sound_regions.size()]
	var spectrum_value: Variant = _last_analysis.get("spectrum", {})
	var spectrum: Dictionary = spectrum_value as Dictionary
	text += "Spectrum peak / dominant frequency: %.2f Hz at %.2f dBFS    FFT windows averaged: %d" % [float(spectrum.get("peak_hz", 0.0)), float(spectrum.get("peak_db", -160.0)), int(spectrum.get("windows", 0))]
	_metrics.text = text


func _configure_views() -> void:
	if _spectrum_view == null or _spectrogram_view == null:
		return
	var min_hz: float = float(_min_frequency.value) if _min_frequency != null else 20.0
	var max_hz: float = float(_max_frequency.value) if _max_frequency != null else 20000.0
	var gain_value: float = float(_gain.value) if _gain != null else 0.0
	var range_value: float = float(_dynamic_range.value) if _dynamic_range != null else 90.0
	var log_value: bool = _log_frequency.button_pressed if _log_frequency != null else true
	_spectrum_view.sample_rate = model.sample_rate if model != null else 44100
	_spectrum_view.min_frequency = min_hz
	_spectrum_view.max_frequency = max_hz
	_spectrum_view.gain_db = gain_value
	_spectrum_view.dynamic_range_db = range_value
	_spectrum_view.logarithmic_frequency = log_value
	_spectrogram_view.min_frequency = min_hz
	_spectrogram_view.max_frequency = max_hz
	_spectrogram_view.gain_db = gain_value
	_spectrogram_view.dynamic_range_db = range_value
	_spectrogram_view.logarithmic_frequency = log_value


func _on_display_setting_changed(_value: float) -> void:
	_configure_views()
	_spectrum_view.queue_redraw()
	_spectrogram_view.refresh_color_mapping()


func _on_display_setting_toggled(_enabled: bool) -> void:
	_configure_views()
	_spectrum_view.queue_redraw()
	if not _last_spectrogram.is_empty():
		_spectrogram_view.queue_redraw()


func _on_live_toggled(enabled: bool) -> void:
	_spectrum_view.bar_mode = enabled
	if not enabled and not _last_analysis.is_empty():
		var spectrum_value: Variant = _last_analysis.get("spectrum", {})
		_spectrum_view.set_spectrum(spectrum_value as Dictionary)
		_job_label.text = "Ready"


func _on_add_beat_markers() -> void:
	var value: Variant = _last_beats.get("beats", PackedInt32Array())
	var beats: PackedInt32Array = value as PackedInt32Array
	if beats.is_empty():
		status_changed.emit("Detect beats first.")
		return
	markers_requested.emit(beats, "Beat")


func _on_add_silence_markers() -> void:
	_emit_region_markers("silence_regions", "Silence")


func _on_add_sound_markers() -> void:
	_emit_region_markers("sound_regions", "Sound")


func _on_add_clip_markers() -> void:
	_emit_region_markers("clipping_regions", "Clip")


func _emit_region_markers(key: String, prefix: String) -> void:
	var value: Variant = _last_analysis.get(key, [])
	var regions: Array = value as Array
	if regions.is_empty():
		status_changed.emit("Run Analyze first; no %s regions are available." % prefix.to_lower())
		return
	var frames: PackedInt32Array = PackedInt32Array()
	for region_value: Variant in regions:
		if region_value is Vector2i:
			var region: Vector2i = region_value
			frames.append(region.x)
	markers_requested.emit(frames, prefix)


func _on_hide() -> void:
	visible = false


func _label(text: String) -> Label:
	var output: Label = Label.new()
	output.text = text
	return output


func _spin(minimum: float, maximum: float, step_value: float, default_value: float, width: float) -> SpinBox:
	var output: SpinBox = SpinBox.new()
	output.min_value = minimum
	output.max_value = maximum
	output.step = step_value
	output.value = default_value
	output.custom_minimum_size.x = width
	return output


func _add_button(parent: Control, text: String, tooltip: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
