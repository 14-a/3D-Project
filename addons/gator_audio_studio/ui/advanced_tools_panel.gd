@tool
class_name GASAdvancedToolsPanel
extends PanelContainer

signal audio_changed
signal status_changed(message: String)
signal jump_requested(frame: int)
signal spectral_selection_changed(low_hz: float, high_hz: float)

const SpectralEditEngine := preload("res://addons/gator_audio_studio/audio/spectral_edit_engine.gd")
const AutomationEngine := preload("res://addons/gator_audio_studio/audio/automation_engine.gd")
const LoopEngine := preload("res://addons/gator_audio_studio/audio/loop_engine.gd")
const ExportEngine := preload("res://addons/gator_audio_studio/audio/export_engine.gd")
const MacroEngine := preload("res://addons/gator_audio_studio/audio/macro_engine.gd")
const AssetOptimizer := preload("res://addons/gator_audio_studio/audio/asset_optimizer.gd")
const CompressedAudioDecoder := preload("res://addons/gator_audio_studio/audio/compressed_audio_decoder.gd")
const CompressedDecodeSession := preload("res://addons/gator_audio_studio/audio/compressed_decode_session.gd")
const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")
const RestorationEngine := preload("res://addons/gator_audio_studio/audio/restoration_engine.gd")
const AdvancedEffectsEngine := preload("res://addons/gator_audio_studio/audio/advanced_effects_engine.gd")
const AutomationCurveEditor := preload("res://addons/gator_audio_studio/ui/automation_curve_editor.gd")
const RenderJob := preload("res://addons/gator_audio_studio/audio/render_job.gd")
const AdvancedBackgroundJob := preload("res://addons/gator_audio_studio/audio/advanced_background_job.gd")

var _model: GASEditorModel
var _tabs: TabContainer
var _spectral_action: OptionButton
var _spectral_low: SpinBox
var _spectral_high: SpinBox
var _spectral_amount: SpinBox
var _spectral_fft: OptionButton
var _restoration_fft: OptionButton
var _restoration_strength: SpinBox
var _restoration_sensitivity: SpinBox
var _restoration_smoothing: SpinBox
var _restoration_floor: SpinBox
var _restoration_stretch: SpinBox
var _restoration_profile: Dictionary = {}
var _restoration_profile_label: Label
var _advanced_source_track: OptionButton
var _advanced_eq_gains: Array[SpinBox] = []
var _duck_threshold: SpinBox
var _duck_reduction: SpinBox
var _duck_attack: SpinBox
var _duck_release: SpinBox
var _vocoder_bands: SpinBox
var _vocoder_attack: SpinBox
var _vocoder_release: SpinBox
var _automation_parameter: OptionButton
var _automation_value: SpinBox
var _automation_curve: OptionButton
var _automation_list: ItemList
var _automation_curve_editor: GASAutomationCurveEditor
var _automation_keys: PackedStringArray = PackedStringArray()
var _label_list: ItemList
var _label_name: LineEdit
var _label_kind: OptionButton
var _label_color: ColorPickerButton
var _label_start_seconds: SpinBox
var _label_end_seconds: SpinBox
var _loop_start: SpinBox
var _loop_end: SpinBox
var _loop_mode: OptionButton
var _loop_crossfade_ms: SpinBox
var _loop_candidates: ItemList
var _loop_player: AudioStreamPlayer
var _export_target: OptionButton
var _export_mono: CheckButton
var _export_bits: OptionButton
var _export_rate: SpinBox
var _export_use_track_rate: CheckButton
var _export_normalize: CheckButton
var _export_pattern: LineEdit
var _export_dialog: FileDialog
var _export_dir_dialog: FileDialog
var _pending_export_batch: bool = false
var _macro_steps: Array[Dictionary] = []
var _macro_list: ItemList
var _macro_effect: OptionButton
var _macro_save_dialog: FileDialog
var _macro_load_dialog: FileDialog
var _macro_batch_dialog: FileDialog
var _macro_files_dialog: FileDialog
var _macro_current_path: String = ""
var _optimizer_text: RichTextLabel
var _optimizer_dir_dialog: FileDialog
var _optimizer_output_dialog: FileDialog
var _optimizer_source_folder: String = ""
var _optimizer_batch_fix_pending: bool = false
var _history_list: ItemList
var _compare_player: AudioStreamPlayer
var _compare_original: GASPCMData
var _compare_edited: GASPCMData
var _metadata_edits: Dictionary = {}
var _preview_mode: OptionButton
var _preview_distance: HSlider
var _preview_pan: HSlider
var _preview_max_distance: SpinBox
var _preview_doppler: CheckButton
var _preview_directional: CheckButton
var _preview_attenuation: OptionButton
var _preview_unit_size: SpinBox
var _preview_panning_strength: SpinBox
var _preview_listener_x: SpinBox
var _preview_listener_z: SpinBox
var _preview_source_x: SpinBox
var _preview_source_z: SpinBox
var _preview_2d: AudioStreamPlayer2D
var _preview_3d: AudioStreamPlayer3D
var _preview_flat: AudioStreamPlayer
var _assign_save_dialog: FileDialog
var _project_audio_list: ItemList
var _project_audio_info: Label
var _project_audio_player: AudioStreamPlayer
var _project_audio_paths: PackedStringArray = PackedStringArray()
var _project_audio_rename_dialog: ConfirmationDialog
var _project_audio_rename_edit: LineEdit
var _project_audio_thumbnail_cache: Dictionary = {}
var _project_audio_entry_cache: Dictionary = {}
var _project_audio_pending_select_path: String = ""
var _heavy_job: GASAdvancedBackgroundJob
var _heavy_job_kind: String = ""
var _heavy_job_label_text: String = ""
var _heavy_job_context: Dictionary = {}
var _heavy_job_cancel_requested: bool = false
var _heavy_job_elapsed: float = 0.0
var _heavy_job_status: Label
var _heavy_job_progress_bar: ProgressBar
var _heavy_job_cancel: Button
var _compressed_insert_session: GASCompressedDecodeSession
var _compressed_insert_path: String = ""
var _compressed_insert_target: int = -1
var _compressed_insert_cursor: int = 0
var _compressed_insert_elapsed: float = 0.0
var _render_job: GASAudioRenderJob
var _render_job_kind: String = ""
var _render_job_track_index: int = -1
var _render_job_track_signature: String = ""
var _render_assign_nodes: Array[Node] = []
var _render_job_last_progress_percent: int = -1
var _render_job_elapsed: float = 0.0
var _pending_editor_imports: PackedStringArray = PackedStringArray()
var _editor_import_flush_queued: bool = false
var _editor_import_in_progress: bool = false
var _editor_import_wait_frames: int = 0


func _ready() -> void:
	_build_ui()
	set_process(true)


func _exit_tree() -> void:
	if _compressed_insert_session != null and not _compressed_insert_session.finished:
		_compressed_insert_session.cancel()
	if _heavy_job != null:
		_heavy_job.cancel()
	# Background jobs are RefCounted and own their worker Callables. Dropping the
	# panel reference is safe and avoids blocking plugin deactivation while a DSP
	# task finishes. The task object remains alive until WorkerThreadPool releases it.
	_heavy_job = null
	# GASAudioRenderJob is also RefCounted/self-contained; do not synchronously wait.
	_render_job = null


func _process(delta: float) -> void:
	_process_editor_import_queue()
	_process_compressed_insert(delta)
	_process_render_job(delta)
	if _heavy_job == null:
		return
	_heavy_job_elapsed += delta
	var progress_value: float = _heavy_job.progress()
	if _heavy_job_status != null:
		_heavy_job_status.text = "%s • %d%% • %.1f s" % [_heavy_job_label_text, int(round(progress_value * 100.0)), _heavy_job_elapsed]
	if _heavy_job_progress_bar != null:
		_heavy_job_progress_bar.value = progress_value * 100.0
	if not _heavy_job.is_complete():
		return
	var completed_job: GASAdvancedBackgroundJob = _heavy_job
	_heavy_job = null
	var result: Dictionary = completed_job.finish()
	var was_cancelled: bool = completed_job.is_cancel_requested() or bool(result.get("cancelled", false))
	_heavy_job_cancel_requested = false
	if _heavy_job_cancel != null:
		_heavy_job_cancel.visible = false
		_heavy_job_cancel.disabled = false
	if was_cancelled:
		if _heavy_job_status != null:
			_heavy_job_status.text = "Cancelled — result discarded"
		status_changed.emit("Background audio job cancelled; its result was discarded.")
		_heavy_job_kind = ""
		_heavy_job_context.clear()
		return
	_apply_heavy_job_result(result)


func set_model(model: GASEditorModel) -> void:
	_model = model
	refresh()


func show_tab(tab_name: String) -> void:
	visible = true
	if _tabs == null:
		return
	for index: int in range(_tabs.get_tab_count()):
		if _tabs.get_tab_title(index) == tab_name:
			_tabs.current_tab = index
			break
	refresh()


func refresh() -> void:
	if _model == null or _tabs == null:
		return
	_refresh_advanced_fx_tracks()
	_refresh_automation()
	_refresh_labels()
	_refresh_loop()
	_refresh_history()
	_refresh_metadata()


func _build_ui() -> void:
	custom_minimum_size.y = 260.0
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)
	var header: HBoxContainer = HBoxContainer.new()
	root.add_child(header)
	var title: Label = Label.new()
	title.text = "Advanced Audio Tools"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_heavy_job_status = Label.new()
	_heavy_job_status.text = "Ready"
	_heavy_job_status.tooltip_text = "Long spectral/restoration jobs run in Godot's worker pool so the editor remains responsive."
	header.add_child(_heavy_job_status)
	_heavy_job_progress_bar = ProgressBar.new()
	_heavy_job_progress_bar.min_value = 0.0; _heavy_job_progress_bar.max_value = 100.0
	_heavy_job_progress_bar.value = 0.0; _heavy_job_progress_bar.show_percentage = false
	_heavy_job_progress_bar.custom_minimum_size.x = 110.0
	header.add_child(_heavy_job_progress_bar)
	_heavy_job_cancel = Button.new()
	_heavy_job_cancel.text = "Cancel Job"
	_heavy_job_cancel.visible = false
	_heavy_job_cancel.pressed.connect(_on_cancel_heavy_job)
	header.add_child(_heavy_job_cancel)
	var hide_button: Button = Button.new()
	hide_button.text = "Hide"
	hide_button.pressed.connect(_on_hide)
	header.add_child(hide_button)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_build_spectral_tab()
	_build_restoration_tab()
	_build_advanced_fx_tab()
	_build_automation_tab()
	_build_labels_tab()
	_build_loop_tab()
	_build_export_tab()
	_build_macros_tab()
	_build_optimizer_tab()
	_build_history_tab()
	_build_compare_tab()
	_build_metadata_tab()
	_build_project_audio_tab()
	_build_preview_tab()


func _new_tab(name: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


func _flow(parent: Container) -> HFlowContainer:
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	parent.add_child(row)
	return row


func _button(parent: Container, text: String, callback: Callable, tooltip: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Container, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _spin(parent: Container, minimum: float, maximum: float, step: float, value: float, suffix: String = "") -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.suffix = suffix
	parent.add_child(spin)
	return spin


func _build_spectral_tab() -> void:
	var box: VBoxContainer = _new_tab("Spectral Edit")
	_label(box, "Destructive STFT spectral editing. Uses the selected track and current time selection; no time selection means the full track.")
	var row: HFlowContainer = _flow(box)
	_label(row, "Action")
	_spectral_action = OptionButton.new()
	for action: String in SpectralEditEngine.actions():
		_spectral_action.add_item(action)
	row.add_child(_spectral_action)
	_label(row, "Low")
	_spectral_low = _spin(row, 0.0, 24000.0, 10.0, 200.0, " Hz")
	_label(row, "High")
	_spectral_high = _spin(row, 20.0, 24000.0, 10.0, 4000.0, " Hz")
	_spectral_low.value_changed.connect(_on_spectral_band_changed)
	_spectral_high.value_changed.connect(_on_spectral_band_changed)
	_label(row, "Amount")
	_spectral_amount = _spin(row, 0.0, 48.0, 0.5, 18.0, " dB")
	_label(row, "FFT")
	_spectral_fft = OptionButton.new()
	for size: int in [512, 1024, 2048, 4096, 8192]:
		_spectral_fft.add_item(str(size), size)
	_spectral_fft.select(2)
	row.add_child(_spectral_fft)
	_button(row, "Apply Spectral Edit", _on_spectral_apply, "Renders the selected frequency band destructively into the selected track.")


func _on_spectral_band_changed(_value: float) -> void:
	if _spectral_low == null or _spectral_high == null:
		return
	spectral_selection_changed.emit(minf(float(_spectral_low.value), float(_spectral_high.value)), maxf(float(_spectral_low.value), float(_spectral_high.value)))


func _on_spectral_apply() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or track_index >= _model.tracks.size() or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable audio track first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var start_frame: int = _model.selection_start if _model.has_selection() else 0
	var end_frame: int = _model.selection_end if _model.has_selection() else -1
	var action: String = _spectral_action.get_item_text(_spectral_action.selected)
	var fft_size: int = _spectral_fft.get_item_id(_spectral_fft.selected)
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Spectral " + action,
		"undo_name": "Spectral " + action,
		"success_message": "Applied %s from %.0f–%.0f Hz." % [action, _spectral_low.value, _spectral_high.value],
	}
	_begin_heavy_job_method(&"spectral", [snapshot, start_frame, end_frame, float(_spectral_low.value), float(_spectral_high.value), action, float(_spectral_amount.value), fft_size], "pcm", context, "Spectral %s" % action)


func _build_restoration_tab() -> void:
	var box: VBoxContainer = _new_tab("Restoration")
	_label(box, "FFT noise-profile reduction, click repair, and pitch-preserving time stretch. Capture a noise-only selection before Noise Reduce.")
	var noise_row: HFlowContainer = _flow(box)
	_label(noise_row, "FFT")
	_restoration_fft = OptionButton.new()
	for size: int in [512, 1024, 2048, 4096, 8192]:
		_restoration_fft.add_item(str(size), size)
	_restoration_fft.select(2)
	noise_row.add_child(_restoration_fft)
	_label(noise_row, "Reduction")
	_restoration_strength = _spin(noise_row, 0.0, 4.0, 0.05, 1.25, "×")
	_label(noise_row, "Sensitivity")
	_restoration_sensitivity = _spin(noise_row, 0.25, 4.0, 0.05, 1.0, "×")
	_label(noise_row, "Smoothing")
	_restoration_smoothing = _spin(noise_row, 0.0, 16.0, 1.0, 3.0, " bins")
	_label(noise_row, "Floor")
	_restoration_floor = _spin(noise_row, -72.0, 0.0, 1.0, -36.0, " dB")
	_button(noise_row, "Capture Noise Profile", _on_capture_noise_profile, "Use the current time selection as a representative noise-only region.")
	_button(noise_row, "Noise Reduce", _on_noise_reduce, "Apply spectral subtraction using the captured profile.")
	_restoration_profile_label = Label.new()
	_restoration_profile_label.text = "No noise profile captured."
	box.add_child(_restoration_profile_label)
	var repair_row: HFlowContainer = _flow(box)
	_button(repair_row, "Repair Clicks / Pops", _on_restore_clicks, "Detect isolated discontinuities and interpolate across them.")
	_label(repair_row, "Stretch")
	_restoration_stretch = _spin(repair_row, 0.25, 20.0, 0.05, 1.5, "×")
	_button(repair_row, "HQ Time Stretch", _on_hq_stretch, "Pitch-preserving WSOLA stretch, intended for normal 0.25×–4× changes.")
	_button(repair_row, "Extreme Stretch", _on_extreme_stretch, "Longer-grain pitch-preserving stretch for ambient/extreme durations up to 20×.")


func _build_advanced_fx_tab() -> void:
	var box: VBoxContainer = _new_tab("Advanced FX")
	_label(box, "Advanced destructive processing deferred from the first FX-rack pass: curve-style EQ, sidechain ducking, and a multiband vocoder.")
	var eq_row: HFlowContainer = _flow(box)
	_label(eq_row, "Filter Curve EQ")
	var labels: PackedStringArray = PackedStringArray(["80 Hz", "250 Hz", "1 kHz", "4 kHz", "12 kHz"])
	_advanced_eq_gains.clear()
	for band_label: String in labels:
		_label(eq_row, band_label)
		var gain: SpinBox = _spin(eq_row, -24.0, 24.0, 0.1, 0.0, " dB")
		gain.custom_minimum_size.x = 86.0
		_advanced_eq_gains.append(gain)
	_button(eq_row, "Apply Curve EQ", _on_filter_curve_eq)
	var duck_row: HFlowContainer = _flow(box)
	_label(duck_row, "Sidechain Track")
	_advanced_source_track = OptionButton.new()
	duck_row.add_child(_advanced_source_track)
	_label(duck_row, "Threshold")
	_duck_threshold = _spin(duck_row, -60.0, 0.0, 0.5, -24.0, " dB")
	_label(duck_row, "Reduction")
	_duck_reduction = _spin(duck_row, 0.0, 36.0, 0.5, 12.0, " dB")
	_label(duck_row, "Attack")
	_duck_attack = _spin(duck_row, 0.1, 500.0, 0.5, 12.0, " ms")
	_label(duck_row, "Release")
	_duck_release = _spin(duck_row, 5.0, 3000.0, 1.0, 250.0, " ms")
	_button(duck_row, "Auto Duck Selected Track", _on_auto_duck, "Uses the chosen sidechain track to lower the selected track when the sidechain is active.")
	var vocoder_row: HFlowContainer = _flow(box)
	_label(vocoder_row, "Vocoder: selected track = modulator; sidechain track = carrier")
	_label(vocoder_row, "Bands")
	_vocoder_bands = _spin(vocoder_row, 4.0, 24.0, 1.0, 12.0)
	_label(vocoder_row, "Attack")
	_vocoder_attack = _spin(vocoder_row, 0.5, 100.0, 0.5, 8.0, " ms")
	_label(vocoder_row, "Release")
	_vocoder_release = _spin(vocoder_row, 5.0, 1000.0, 1.0, 70.0, " ms")
	_button(vocoder_row, "Apply Vocoder", _on_vocoder)
	_refresh_advanced_fx_tracks()


func _refresh_advanced_fx_tracks() -> void:
	if _advanced_source_track == null:
		return
	var previous_id: int = _advanced_source_track.get_item_id(_advanced_source_track.selected) if _advanced_source_track.selected >= 0 else -1
	_advanced_source_track.clear()
	if _model == null:
		return
	for track_index: int in range(_model.tracks.size()):
		if track_index == _model.selected_track:
			continue
		var track: GASEditorTrack = _model.tracks[track_index]
		if track.clips.is_empty():
			continue
		_advanced_source_track.add_item("%d: %s" % [track_index + 1, track.name], track_index)
	for item_index: int in range(_advanced_source_track.item_count):
		if _advanced_source_track.get_item_id(item_index) == previous_id:
			_advanced_source_track.select(item_index)
			return
	if _advanced_source_track.item_count > 0:
		_advanced_source_track.select(0)


func _selection_bounds_for_background() -> Vector2i:
	if _model == null:
		return Vector2i(0, -1)
	if _model.has_selection():
		return Vector2i(_model.selection_start, _model.selection_end)
	return Vector2i(0, -1)


func _on_filter_curve_eq() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track with audio.")
		return
	var gains: PackedFloat32Array = PackedFloat32Array()
	for spin: SpinBox in _advanced_eq_gains:
		gains.append(float(spin.value))
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	var bounds: Vector2i = _selection_bounds_for_background()
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Curve EQ",
		"undo_name": "Filter Curve EQ",
		"success_message": "Applied five-band interpolated Filter Curve EQ.",
	}
	_begin_heavy_job_method(&"curve_eq", [snapshot, bounds.x, bounds.y, gains], "pcm", context, "Filter Curve EQ")


func _on_auto_duck() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select the target track first.")
		return
	if _advanced_source_track == null or _advanced_source_track.selected < 0:
		status_changed.emit("Choose a sidechain track with audio.")
		return
	var source_track_index: int = _advanced_source_track.get_item_id(_advanced_source_track.selected)
	var target_snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	var source_snapshot: GASEditorModel = _model.create_track_render_snapshot(source_track_index)
	if target_snapshot == null or source_snapshot == null:
		return
	var bounds: Vector2i = _selection_bounds_for_background()
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Auto Duck",
		"undo_name": "Auto Duck",
		"success_message": "Applied sidechain auto-ducking from %s." % _advanced_source_track.get_item_text(_advanced_source_track.selected),
		"source_track_index": source_track_index,
	}
	_begin_heavy_job_method(&"auto_duck", [target_snapshot, source_snapshot, bounds.x, bounds.y, float(_duck_threshold.value), float(_duck_reduction.value), float(_duck_attack.value), float(_duck_release.value)], "pcm", context, "Auto Duck")


func _on_vocoder() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select the vocoder modulator track first.")
		return
	if _advanced_source_track == null or _advanced_source_track.selected < 0:
		status_changed.emit("Choose a carrier track with audio.")
		return
	var source_track_index: int = _advanced_source_track.get_item_id(_advanced_source_track.selected)
	var modulator_snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	var carrier_snapshot: GASEditorModel = _model.create_track_render_snapshot(source_track_index)
	if modulator_snapshot == null or carrier_snapshot == null:
		return
	var bounds: Vector2i = _selection_bounds_for_background()
	var bands: int = int(round(_vocoder_bands.value))
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Vocoder",
		"undo_name": "Vocoder",
		"success_message": "Applied %d-band vocoder." % bands,
		"source_track_index": source_track_index,
	}
	_begin_heavy_job_method(&"vocoder", [modulator_snapshot, carrier_snapshot, bounds.x, bounds.y, bands, float(_vocoder_attack.value), float(_vocoder_release.value)], "pcm", context, "Vocoder")


func _on_capture_noise_profile() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track and a noise-only time range first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var bounds: Vector2i = _selection_bounds_for_background()
	var fft_size: int = _restoration_fft.get_item_id(_restoration_fft.selected)
	var context: Dictionary = {"track_index": track_index, "fft_size": fft_size}
	_begin_heavy_job_method(&"noise_profile", [snapshot, bounds.x, bounds.y, fft_size], "noise_profile", context, "Capturing Noise Profile")


func _on_noise_reduce() -> void:
	if _restoration_profile.is_empty():
		status_changed.emit("Capture a noise-only profile first.")
		return
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track with audio.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var bounds: Vector2i = _selection_bounds_for_background()
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Noise Reduced",
		"undo_name": "FFT Noise Reduction",
		"success_message": "Applied FFT noise reduction using the captured profile.",
	}
	_begin_heavy_job_method(&"noise_reduce", [snapshot, bounds.x, bounds.y, _restoration_profile.duplicate(true), float(_restoration_strength.value), float(_restoration_sensitivity.value), int(round(_restoration_smoothing.value)), float(_restoration_floor.value)], "pcm", context, "FFT Noise Reduction")


func _on_restore_clicks() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track with audio.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var bounds: Vector2i = _selection_bounds_for_background()
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Click Repaired",
		"undo_name": "Repair Clicks / Pops",
		"success_message": "Repaired isolated click/pop discontinuities in the selected range.",
	}
	_begin_heavy_job_method(&"restore_clicks", [snapshot, bounds.x, bounds.y], "pcm", context, "Repairing Clicks / Pops")


func _on_hq_stretch() -> void:
	_apply_restoration_stretch(false)


func _on_extreme_stretch() -> void:
	_apply_restoration_stretch(true)


func _apply_restoration_stretch(extreme: bool) -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track with audio.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var factor: float = float(_restoration_stretch.value)
	if not extreme:
		factor = clampf(factor, 0.25, 4.0)
	var bounds: Vector2i = _selection_bounds_for_background()
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Stretched",
		"undo_name": "Extreme Stretch" if extreme else "HQ Time Stretch",
		"success_message": "Time stretch complete: %.2f× duration." % factor,
	}
	_begin_heavy_job_method(&"stretch", [snapshot, bounds.x, bounds.y, factor, extreme], "pcm", context, "Extreme Stretch" if extreme else "HQ Time Stretch")


func _begin_heavy_job_method(method: StringName, args: Array, kind: String, context: Dictionary, display_name: String) -> void:
	if _heavy_job != null:
		status_changed.emit("Finish or cancel the current background audio job first.")
		return
	_heavy_job_kind = kind
	_heavy_job_context = context.duplicate(true)
	var target_track_index: int = int(_heavy_job_context.get("track_index", -1))
	if target_track_index >= 0:
		_heavy_job_context["target_signature"] = _track_signature(target_track_index)
	var source_track_index: int = int(_heavy_job_context.get("source_track_index", -1))
	if source_track_index >= 0:
		_heavy_job_context["source_signature"] = _track_signature(source_track_index)
	_heavy_job_label_text = display_name
	_heavy_job_elapsed = 0.0
	_heavy_job_cancel_requested = false
	if _heavy_job_status != null:
		_heavy_job_status.text = display_name + " • starting…"
	if _heavy_job_progress_bar != null:
		_heavy_job_progress_bar.value = 0.0
	if _heavy_job_cancel != null:
		_heavy_job_cancel.visible = true
		_heavy_job_cancel.disabled = false
	var job: GASAdvancedBackgroundJob = AdvancedBackgroundJob.new() as GASAdvancedBackgroundJob
	var task: Callable = Callable(job, method).bindv(args)
	job.start(task, display_name)
	_heavy_job = job
	status_changed.emit(display_name + " is running in the background.")


func _track_signature(track_index: int) -> String:
	if _model == null or track_index < 0 or track_index >= _model.tracks.size():
		return ""
	var track: GASEditorTrack = _model.tracks[track_index]
	var signature_text: String = "%d|%d|%.5f|%.5f|%d|%s" % [
		track_index,
		track.clips.size(),
		track.gain_db,
		track.pan,
		track.effect_stack.size(),
		str(track.automation_lanes),
	]
	for track_effect: GASEffectData in track.effect_stack:
		signature_text += "|TFX:%s:%.5f:%s" % [track_effect.effect_type, track_effect.wet, str(track_effect.params)]
	for clip: GASEditorClip in track.clips:
		var pcm_id: int = clip.pcm.get_instance_id() if clip.pcm != null else 0
		signature_text += "|%d:%d:%d:%d:%d:%d" % [clip.clip_id, clip.timeline_start, clip.source_start_frame, clip.source_end_frame, clip.effect_stack.size(), pcm_id]
		for clip_effect: GASEffectData in clip.effect_stack:
			signature_text += "|CFX:%s:%.5f:%s" % [clip_effect.effect_type, clip_effect.wet, str(clip_effect.params)]
	return signature_text


func _on_cancel_heavy_job() -> void:
	if _heavy_job == null:
		return
	_heavy_job_cancel_requested = true
	_heavy_job.cancel()
	if _heavy_job_cancel != null:
		_heavy_job_cancel.disabled = true
	if _heavy_job_status != null:
		_heavy_job_status.text = _heavy_job_label_text + " • cancelling (result will be discarded)…"


func _background_context_track_is_current(context: Dictionary) -> bool:
	if _model == null:
		return false
	var track_index: int = int(context.get("track_index", -1))
	if track_index < 0:
		return true
	if track_index >= _model.tracks.size():
		status_changed.emit("The target track is no longer available; background result was discarded.")
		return false
	var signature: String = str(context.get("target_signature", ""))
	if not signature.is_empty() and _track_signature(track_index) != signature:
		status_changed.emit("The target track changed while processing; stale background result was discarded.")
		return false
	return true


func _apply_heavy_job_result(result: Dictionary) -> void:
	var kind: String = _heavy_job_kind
	var context: Dictionary = _heavy_job_context.duplicate(true)
	_heavy_job_kind = ""
	_heavy_job_context.clear()
	if kind == "loop_candidates":
		if not _background_context_track_is_current(context):
			return
		_loop_candidates.clear()
		var candidates_value: Variant = result.get("candidates", [])
		if candidates_value is Array:
			var candidates: Array = candidates_value as Array
			for candidate_value: Variant in candidates:
				if not (candidate_value is Dictionary):
					continue
				var candidate: Dictionary = candidate_value as Dictionary
				_loop_candidates.add_item("%d → %d   score %.5f" % [int(candidate.get("start", 0)), int(candidate.get("end", 0)), float(candidate.get("score", 0.0))])
				_loop_candidates.set_item_metadata(_loop_candidates.item_count - 1, candidate)
		if _heavy_job_status != null:
			_heavy_job_status.text = "Seamless-loop search complete"
		status_changed.emit("Seamless-loop candidates ready.")
		return
	if kind == "loop_preview":
		if not _background_context_track_is_current(context):
			return
		var preview_wav: AudioStreamWAV = result.get("wav") as AudioStreamWAV
		if preview_wav == null:
			status_changed.emit("Could not prepare loop preview.")
			return
		_loop_player.stop()
		_loop_player.stream = preview_wav
		_loop_player.play(float(result.get("start_seconds", 0.0)))
		status_changed.emit("Loop preview playing. Stop Preview ends auditioning.")
		return
	if kind == "compare_capture":
		if not _background_context_track_is_current(context):
			return
		_compare_original = result.get("original") as GASPCMData
		_compare_edited = result.get("edited") as GASPCMData
		if _compare_original == null or _compare_edited == null:
			status_changed.emit("A/B capture failed.")
			return
		status_changed.emit("Captured A/B comparison in the background.")
		return
	if kind == "optimizer_analysis" or kind == "optimizer_mix_analysis":
		if _model == null:
			return
		if kind == "optimizer_analysis":
			var analysis_track_index: int = int(context.get("track_index", -1))
			var analysis_signature: String = str(context.get("target_signature", ""))
			if analysis_track_index < 0 or analysis_track_index >= _model.tracks.size():
				status_changed.emit("The analyzed track is no longer available; result discarded.")
				return
			if not analysis_signature.is_empty() and _track_signature(analysis_track_index) != analysis_signature:
				status_changed.emit("The track changed while analysis was running; stale result discarded.")
				return
		var analysis_value: Variant = result.get("analysis", {})
		var analysis: Dictionary = {}
		if analysis_value is Dictionary:
			analysis = analysis_value as Dictionary
		_show_optimization(analysis)
		if _heavy_job_status != null:
			_heavy_job_status.text = _heavy_job_label_text + " • complete"
		status_changed.emit("Audio analysis complete.")
		return
	if kind == "macro_batch":
		var processed_count: int = int(result.get("count", 0))
		var total_count: int = int(result.get("total", 0))
		var output_dir: String = str(result.get("output_dir", ""))
		status_changed.emit("Macro processed %d/%d selected WAV files into %s." % [processed_count, total_count, output_dir])
		return
	if kind == "optimizer_folder":
		var error_message: String = str(result.get("error", ""))
		if not error_message.is_empty():
			status_changed.emit(error_message)
			return
		if bool(result.get("fix", false)):
			status_changed.emit("Safe optimization wrote %d WAV copies (%d changed) to %s. Originals were untouched." % [int(result.get("processed", 0)), int(result.get("changed", 0)), str(result.get("output_dir", ""))])
		else:
			_optimizer_text.text = str(result.get("report", "No WAV files found."))
			status_changed.emit("Batch optimization scan complete.")
		return
	if kind == "compare_play":
		var compare_wav: AudioStreamWAV = result.get("wav") as AudioStreamWAV
		if compare_wav == null:
			status_changed.emit("Could not prepare A/B playback.")
			return
		_compare_player.stop()
		_compare_player.stream = compare_wav
		_compare_player.play()
		return
	if kind == "project_audio_scan":
		_project_audio_paths = PackedStringArray()
		_project_audio_entry_cache.clear()
		_project_audio_thumbnail_cache.clear()
		_project_audio_list.clear()
		var entries_value: Variant = result.get("entries", [])
		if entries_value is Array:
			var entries: Array = entries_value as Array
			for entry_value: Variant in entries:
				if not (entry_value is Dictionary):
					continue
				var entry: Dictionary = entry_value as Dictionary
				var path: String = str(entry.get("path", ""))
				if path.is_empty():
					continue
				_project_audio_paths.append(path)
				_project_audio_entry_cache[path] = entry
				var item_index: int = _project_audio_list.add_item(path.trim_prefix("res://"))
				var rgba_value: Variant = entry.get("thumbnail_rgba", PackedByteArray())
				if rgba_value is PackedByteArray:
					var rgba: PackedByteArray = rgba_value as PackedByteArray
					if rgba.size() == 112 * 28 * 4:
						var image: Image = Image.create_from_data(112, 28, false, Image.FORMAT_RGBA8, rgba)
						var texture: ImageTexture = ImageTexture.create_from_image(image)
						_project_audio_thumbnail_cache[path] = texture
						_project_audio_list.set_item_icon(item_index, texture)
		_project_audio_info.text = "%d audio asset(s) found in res://." % _project_audio_paths.size()
		if not _project_audio_pending_select_path.is_empty():
			var pending_path: String = _project_audio_pending_select_path
			_project_audio_pending_select_path = ""
			_select_project_audio_path(pending_path)
		status_changed.emit("Project audio scan complete.")
		return
	if kind == "project_audio_insert":
		var insert_pcm: GASPCMData = result.get("pcm") as GASPCMData
		var insert_path: String = str(result.get("path", context.get("path", "")))
		if insert_pcm == null or _model == null:
			status_changed.emit("Could not load %s." % insert_path)
			return
		var insert_target: int = int(context.get("target", -1))
		var insert_cursor: int = int(context.get("cursor", 0))
		if insert_target >= 0 and insert_target < _model.tracks.size() and _model.is_track_editable(insert_target):
			_model.add_pcm_to_track(insert_pcm, insert_path.get_file().get_basename(), insert_path, insert_target, insert_cursor)
		else:
			_model.add_pcm_as_new_track_at(insert_pcm, insert_path.get_file().get_basename(), insert_path, insert_cursor, "Insert Project Audio")
		audio_changed.emit()
		status_changed.emit("Inserted %s at the cursor." % insert_path)
		return
	if kind == "noise_profile":
		var profile_value: Variant = result.get("profile", {})
		if not (profile_value is Dictionary) or (profile_value as Dictionary).is_empty():
			if _heavy_job_status != null:
				_heavy_job_status.text = "Noise profile failed"
			status_changed.emit("Noise profile capture failed.")
			return
		_restoration_profile = (profile_value as Dictionary).duplicate(true)
		var fft_size: int = int(context.get("fft_size", 0))
		var duration: float = float(result.get("duration", context.get("duration", 0.0)))
		if _restoration_profile_label != null:
			_restoration_profile_label.text = "Captured profile: %d FFT • %.3f s" % [fft_size, duration]
		if _heavy_job_status != null:
			_heavy_job_status.text = "Noise profile ready"
		status_changed.emit("Noise profile captured from the current selection.")
		return
	var processed: GASPCMData = result.get("processed") as GASPCMData
	if processed == null:
		if _heavy_job_status != null:
			_heavy_job_status.text = "Processing failed"
		status_changed.emit(_heavy_job_label_text + " failed.")
		return
	if _model == null:
		return
	var track_index: int = int(context.get("track_index", -1))
	if track_index < 0 or track_index >= _model.tracks.size() or not _model.is_track_editable(track_index):
		status_changed.emit("The target track is no longer available; background result was discarded.")
		return
	var target_signature: String = str(context.get("target_signature", ""))
	if not target_signature.is_empty() and _track_signature(track_index) != target_signature:
		if _heavy_job_status != null:
			_heavy_job_status.text = "Discarded — target changed"
		status_changed.emit("The target track changed while processing; the stale background result was discarded.")
		return
	var source_track_index: int = int(context.get("source_track_index", -1))
	var source_signature: String = str(context.get("source_signature", ""))
	if source_track_index >= 0 and not source_signature.is_empty() and _track_signature(source_track_index) != source_signature:
		if _heavy_job_status != null:
			_heavy_job_status.text = "Discarded — source changed"
		status_changed.emit("The sidechain/carrier track changed while processing; the stale background result was discarded.")
		return
	var start_frame: int = int(result.get("start_frame", context.get("start", 0)))
	var end_frame: int = int(result.get("end_frame", context.get("end", start_frame)))
	if result.has("original_frames"):
		start_frame = 0
		end_frame = int(result.get("original_frames", end_frame))
	_model.replace_track_region_with_pcm(track_index, start_frame, end_frame, processed, str(context.get("clip_name", "Processed")), str(context.get("undo_name", "Advanced Audio Process")))
	audio_changed.emit()
	if _heavy_job_status != null:
		_heavy_job_status.text = _heavy_job_label_text + " • complete"
	status_changed.emit(str(context.get("success_message", _heavy_job_label_text + " complete.")))


func _build_automation_tab() -> void:
	var box: VBoxContainer = _new_tab("Automation")
	_label(box, "Automation points are stored per track and saved in .gasproj. Volume, pan, pitch, filters and numeric effect parameters render into track playback/export; send automation drives routed bus-preview sends.")
	var row: HFlowContainer = _flow(box)
	_label(row, "Parameter")
	_automation_parameter = OptionButton.new()
	row.add_child(_automation_parameter)
	_label(row, "Value")
	_automation_value = _spin(row, -60.0, 24000.0, 0.1, 0.0)
	_label(row, "Curve")
	_automation_curve = OptionButton.new()
	_automation_curve.item_selected.connect(_on_automation_curve_changed)
	for curve: String in PackedStringArray(["linear", "smooth", "exponential", "stepped"]):
		_automation_curve.add_item(curve)
	row.add_child(_automation_curve)
	_button(row, "Add Point at Cursor", _on_automation_add)
	_button(row, "Delete Point", _on_automation_delete)
	_button(row, "Clear Lane", _on_automation_clear)
	_populate_automation_parameters()
	_automation_parameter.item_selected.connect(_on_automation_parameter_changed)
	_automation_list = ItemList.new()
	_automation_list.custom_minimum_size.y = 100.0
	box.add_child(_automation_list)
	_automation_curve_editor = AutomationCurveEditor.new()
	_automation_curve_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_automation_curve_editor.automation_changed.connect(_on_automation_curve_editor_changed)
	box.add_child(_automation_curve_editor)
	_on_automation_parameter_changed(0)


func _populate_automation_parameters() -> void:
	if _automation_parameter == null:
		return
	var previous_key: String = _automation_key() if not _automation_keys.is_empty() else AutomationEngine.PARAM_VOLUME_DB
	_automation_parameter.clear()
	_automation_keys = PackedStringArray([
		AutomationEngine.PARAM_VOLUME_DB,
		AutomationEngine.PARAM_PAN,
		AutomationEngine.PARAM_PITCH,
		AutomationEngine.PARAM_LOW_PASS,
		AutomationEngine.PARAM_HIGH_PASS,
		AutomationEngine.PARAM_SEND_DB,
	])
	for label: String in PackedStringArray(["Volume dB", "Pan", "Pitch semitones", "Low-pass Hz", "High-pass Hz", "Send dB"]):
		_automation_parameter.add_item(label)
	if _model != null and _model.selected_track >= 0 and _model.selected_track < _model.tracks.size():
		var track: GASEditorTrack = _model.tracks[_model.selected_track]
		for effect_index: int in range(track.effect_stack.size()):
			var effect: GASEffectData = track.effect_stack[effect_index]
			_automation_keys.append("fx:%d:wet" % effect_index)
			_automation_parameter.add_item("FX %d %s • Overall Wet" % [effect_index + 1, effect.effect_type])
			var specs: Array[Dictionary] = EffectEngine.parameter_specs(effect.effect_type)
			for spec: Dictionary in specs:
				var parameter_key: String = str(spec.get("key", ""))
				if parameter_key.is_empty():
					continue
				_automation_keys.append(AutomationEngine.effect_parameter_lane_key(effect_index, parameter_key))
				_automation_parameter.add_item("FX %d %s • %s" % [effect_index + 1, effect.effect_type, str(spec.get("label", parameter_key))])
	for index: int in range(_automation_keys.size()):
		if _automation_keys[index] == previous_key:
			_automation_parameter.select(index)
			return
	_automation_parameter.select(0)


func _automation_key() -> String:
	var index: int = _automation_parameter.selected if _automation_parameter != null else -1
	if index >= 0 and index < _automation_keys.size():
		return _automation_keys[index]
	return AutomationEngine.PARAM_VOLUME_DB


func _on_automation_parameter_changed(_index: int) -> void:
	if _automation_value == null:
		return
	var key: String = _automation_key()
	var spec: Dictionary = _automation_spec_for_key(key)
	_automation_value.min_value = float(spec.get("min", -1.0))
	_automation_value.max_value = float(spec.get("max", 1.0))
	_automation_value.step = float(spec.get("step", 0.01))
	_automation_value.value = clampf(float(spec.get("default", 0.0)), _automation_value.min_value, _automation_value.max_value)
	_automation_value.suffix = str(spec.get("suffix", ""))
	_update_automation_curve_context()
	_refresh_automation()


func _automation_spec_for_key(key: String) -> Dictionary:
	match key:
		AutomationEngine.PARAM_VOLUME_DB:
			return {"min": -60.0, "max": 24.0, "step": 0.1, "default": 0.0, "suffix": " dB"}
		AutomationEngine.PARAM_PAN:
			return {"min": -1.0, "max": 1.0, "step": 0.01, "default": 0.0, "suffix": ""}
		AutomationEngine.PARAM_PITCH:
			return {"min": -24.0, "max": 24.0, "step": 0.1, "default": 0.0, "suffix": " st"}
		AutomationEngine.PARAM_LOW_PASS:
			return {"min": 20.0, "max": 24000.0, "step": 10.0, "default": 12000.0, "suffix": " Hz"}
		AutomationEngine.PARAM_HIGH_PASS:
			return {"min": 20.0, "max": 24000.0, "step": 10.0, "default": 40.0, "suffix": " Hz"}
		AutomationEngine.PARAM_SEND_DB:
			return {"min": -60.0, "max": 12.0, "step": 0.5, "default": -12.0, "suffix": " dB"}
	if key.begins_with("fx:") and key.ends_with(":wet"):
		return {"min": 0.0, "max": 1.0, "step": 0.01, "default": 1.0, "suffix": ""}
	var parts: PackedStringArray = key.split(":")
	if parts.size() >= 4 and parts[0] == "fx" and parts[2] == "param" and _model != null:
		var effect_index: int = int(parts[1])
		var parameter_key: String = parts[3]
		if _model.selected_track >= 0 and _model.selected_track < _model.tracks.size():
			var track: GASEditorTrack = _model.tracks[_model.selected_track]
			if effect_index >= 0 and effect_index < track.effect_stack.size():
				var effect: GASEffectData = track.effect_stack[effect_index]
				for spec: Dictionary in EffectEngine.parameter_specs(effect.effect_type):
					if str(spec.get("key", "")) == parameter_key:
						var label: String = str(spec.get("label", ""))
						var suffix: String = ""
						if label.contains("dB"):
							suffix = " dB"
						elif label.contains("Hz"):
							suffix = " Hz"
						elif label.contains("ms"):
							suffix = " ms"
						elif label.contains("Semitone"):
							suffix = " st"
						var default_value: float = float(effect.params.get(parameter_key, spec.get("min", 0.0)))
						return {"min": float(spec.get("min", 0.0)), "max": float(spec.get("max", 1.0)), "step": float(spec.get("step", 0.01)), "default": default_value, "suffix": suffix}
	return {"min": 0.0, "max": 1.0, "step": 0.01, "default": 0.0, "suffix": ""}


func _on_automation_curve_changed(_index: int) -> void:
	_update_automation_curve_context()


func _update_automation_curve_context() -> void:
	if _automation_curve_editor == null or _automation_value == null or _automation_curve == null:
		return
	var curve: String = _automation_curve.get_item_text(_automation_curve.selected) if _automation_curve.selected >= 0 else "linear"
	_automation_curve_editor.set_context(_model, _automation_key(), float(_automation_value.min_value), float(_automation_value.max_value), curve)


func _on_automation_curve_editor_changed() -> void:
	_refresh_automation()
	audio_changed.emit()


func _on_automation_add() -> void:
	if _model == null or _model.selected_track < 0:
		status_changed.emit("Select a track first.")
		return
	var curve: String = _automation_curve.get_item_text(_automation_curve.selected)
	_model.add_automation_point(_model.selected_track, _automation_key(), _model.cursor_frame, float(_automation_value.value), curve)
	_refresh_automation()
	audio_changed.emit()


func _on_automation_delete() -> void:
	if _model == null or _model.selected_track < 0 or _automation_list.get_selected_items().is_empty():
		return
	var key: String = _automation_key()
	var value: Variant = _model.tracks[_model.selected_track].automation_lanes.get(key, [])
	if not (value is Array):
		return
	var points: Array[Dictionary] = []
	var source: Array = value as Array
	var remove_index: int = _automation_list.get_selected_items()[0]
	for index: int in range(source.size()):
		if index == remove_index:
			continue
		var item: Variant = source[index]
		if item is Dictionary:
			points.append((item as Dictionary).duplicate(true))
	_model.set_automation_lane(_model.selected_track, key, points)
	_refresh_automation()
	audio_changed.emit()


func _on_automation_clear() -> void:
	if _model != null and _model.selected_track >= 0 and _model.clear_automation_lane(_model.selected_track, _automation_key()):
		_refresh_automation()
		audio_changed.emit()


func _refresh_automation() -> void:
	if _automation_list == null:
		return
	_populate_automation_parameters()
	if _automation_curve_editor != null and _automation_value != null and _automation_curve != null:
		var curve: String = _automation_curve.get_item_text(_automation_curve.selected) if _automation_curve.selected >= 0 else "linear"
		_automation_curve_editor.set_context(_model, _automation_key(), float(_automation_value.min_value), float(_automation_value.max_value), curve)
	_automation_list.clear()
	if _model == null or _model.selected_track < 0 or _model.selected_track >= _model.tracks.size():
		return
	var value: Variant = _model.tracks[_model.selected_track].automation_lanes.get(_automation_key(), [])
	if value is Array:
		var points: Array = value as Array
		for item: Variant in points:
			if item is Dictionary:
				var point: Dictionary = item as Dictionary
				var seconds: float = float(int(point.get("frame", 0))) / float(maxi(1, _model.sample_rate))
				_automation_list.add_item("%.3f s  •  %.3f  •  %s" % [seconds, float(point.get("value", 0.0)), str(point.get("curve", "linear"))])


func _build_labels_tab() -> void:
	var box: VBoxContainer = _new_tab("Labels & Regions")
	var row: HFlowContainer = _flow(box)
	_label(row, "Name")
	_label_name = LineEdit.new(); _label_name.text = "Region"; _label_name.custom_minimum_size.x = 130.0; row.add_child(_label_name)
	_label(row, "Kind")
	_label_kind = OptionButton.new()
	for kind: String in PackedStringArray(["Marker", "Region", "Loop Start", "Loop End", "Attack", "Sustain", "Release", "Cue", "Animation Sync", "Footstep", "Hit Frame"]):
		_label_kind.add_item(kind)
	row.add_child(_label_kind)
	_label_color = ColorPickerButton.new()
	_label_color.color = Color(0.92, 0.67, 0.20)
	row.add_child(_label_color)
	_label(row, "Start")
	_label_start_seconds = _spin(row, 0.0, 86400.0, 0.001, 0.0, " s")
	_label(row, "End")
	_label_end_seconds = _spin(row, 0.0, 86400.0, 0.001, 0.0, " s")
	_button(row, "Selection → Region", _on_label_add_region)
	_button(row, "Cursor → Marker", _on_label_add_marker)
	_button(row, "Update", _on_label_update)
	_button(row, "Delete", _on_label_delete)
	_button(row, "Jump", _on_label_jump)
	_label_list = ItemList.new(); _label_list.custom_minimum_size.y = 130.0; _label_list.item_selected.connect(_on_label_selected); box.add_child(_label_list)


func _refresh_labels() -> void:
	if _label_list == null:
		return
	_label_list.clear()
	if _model == null:
		return
	for marker: Dictionary in _model.markers:
		var start: int = int(marker.get("frame", 0))
		var end: int = int(marker.get("end_frame", start))
		var range_text: String = "%.3f s" % (float(start) / float(maxi(1, _model.sample_rate)))
		if end > start:
			range_text += "–%.3f s" % (float(end) / float(maxi(1, _model.sample_rate)))
		_label_list.add_item("%s  •  %s  •  %s" % [str(marker.get("name", "Marker")), str(marker.get("kind", "Marker")), range_text])


func _on_label_add_region() -> void:
	if _model == null or not _model.has_selection():
		status_changed.emit("Create a time selection first.")
		return
	_model.add_region(_model.selection_start, _model.selection_end, _label_name.text, _label_kind.get_item_text(_label_kind.selected), _label_color.color)
	var rate: float = float(maxi(1, _model.sample_rate))
	_label_start_seconds.value = float(_model.selection_start) / rate
	_label_end_seconds.value = float(_model.selection_end) / rate
	_refresh_labels()
	audio_changed.emit()


func _on_label_add_marker() -> void:
	if _model == null:
		return
	_model.add_region(_model.cursor_frame, _model.cursor_frame, _label_name.text, _label_kind.get_item_text(_label_kind.selected), _label_color.color)
	var seconds: float = float(_model.cursor_frame) / float(maxi(1, _model.sample_rate))
	_label_start_seconds.value = seconds
	_label_end_seconds.value = seconds
	_refresh_labels()
	audio_changed.emit()


func _on_label_selected(index: int) -> void:
	if _model == null or index < 0 or index >= _model.markers.size():
		return
	var marker: Dictionary = _model.markers[index]
	_label_name.text = str(marker.get("name", "Marker"))
	var kind: String = str(marker.get("kind", "Marker"))
	for i: int in range(_label_kind.item_count):
		if _label_kind.get_item_text(i) == kind:
			_label_kind.select(i); break
	_label_color.color = Color.from_string(str(marker.get("color", "eaaa33")), Color(0.92, 0.67, 0.20))
	var rate: float = float(maxi(1, _model.sample_rate))
	_label_start_seconds.value = float(int(marker.get("frame", 0))) / rate
	_label_end_seconds.value = float(int(marker.get("end_frame", int(marker.get("frame", 0))))) / rate


func _on_label_update() -> void:
	if _model == null or _label_list.get_selected_items().is_empty():
		return
	var index: int = _label_list.get_selected_items()[0]
	var rate: float = float(maxi(1, _model.sample_rate))
	var start_frame: int = maxi(0, int(round(float(_label_start_seconds.value) * rate)))
	var end_frame: int = maxi(start_frame, int(round(float(_label_end_seconds.value) * rate)))
	_model.update_marker(index, _label_name.text, start_frame, end_frame, _label_kind.get_item_text(_label_kind.selected), _label_color.color)
	_refresh_labels()
	audio_changed.emit()


func _on_label_delete() -> void:
	if _model == null or _label_list.get_selected_items().is_empty():
		return
	_model.remove_marker(_label_list.get_selected_items()[0]); _refresh_labels(); audio_changed.emit()


func _on_label_jump() -> void:
	if _model == null or _label_list.get_selected_items().is_empty():
		return
	var marker: Dictionary = _model.markers[_label_list.get_selected_items()[0]]
	jump_requested.emit(int(marker.get("frame", 0)))


func _build_loop_tab() -> void:
	var box: VBoxContainer = _new_tab("Loop Editor")
	var row: HFlowContainer = _flow(box)
	_label(row, "Start sample")
	_loop_start = _spin(row, 0.0, 1000000000.0, 1.0, 0.0)
	_label(row, "End sample")
	_loop_end = _spin(row, 1.0, 1000000000.0, 1.0, 1.0)
	_label(row, "Mode")
	_loop_mode = OptionButton.new(); _loop_mode.add_item("Forward", AudioStreamWAV.LOOP_FORWARD); _loop_mode.add_item("Ping-Pong", AudioStreamWAV.LOOP_PINGPONG); _loop_mode.add_item("Reverse", AudioStreamWAV.LOOP_BACKWARD); row.add_child(_loop_mode)
	_label(row, "Crossfade")
	_loop_crossfade_ms = _spin(row, 0.0, 500.0, 1.0, 10.0, " ms")
	_button(row, "Use Selection", _on_loop_use_selection)
	_button(row, "Snap Zero Crossings", _on_loop_snap)
	_button(row, "Apply Settings", _on_loop_apply_settings)
	_button(row, "Crossfade Loop", _on_loop_crossfade)
	_button(row, "Find Seamless", _on_loop_find)
	_button(row, "Preview Loop", _on_loop_preview)
	_button(row, "Stop Preview", _on_loop_preview_stop)
	_loop_player = AudioStreamPlayer.new()
	add_child(_loop_player)
	_loop_candidates = ItemList.new(); _loop_candidates.custom_minimum_size.y = 110.0; _loop_candidates.item_activated.connect(_on_loop_candidate_activated); box.add_child(_loop_candidates)


func _refresh_loop() -> void:
	if _model == null or _loop_start == null:
		return
	_loop_start.value = _model.loop_start_frame
	_loop_end.value = maxi(_model.loop_start_frame + 1, _model.loop_end_frame)
	for i: int in range(_loop_mode.item_count):
		if _loop_mode.get_item_id(i) == _model.loop_mode:
			_loop_mode.select(i)


func _on_loop_use_selection() -> void:
	if _model == null or not _model.has_selection():
		return
	_loop_start.value = _model.selection_start; _loop_end.value = _model.selection_end


func _on_loop_snap() -> void:
	if _model == null or _model.selected_track < 0:
		return
	_loop_start.value = _model.nearest_zero_crossing_on_track(_model.selected_track, int(_loop_start.value), 4096)
	_loop_end.value = _model.nearest_zero_crossing_on_track(_model.selected_track, int(_loop_end.value), 4096)


func _on_loop_apply_settings() -> void:
	if _model == null:
		return
	_model.push_undo("Loop Settings")
	_model.loop_start_frame = maxi(0, int(_loop_start.value))
	_model.loop_end_frame = maxi(_model.loop_start_frame + 1, int(_loop_end.value))
	_model.loop_mode = _loop_mode.get_item_id(_loop_mode.selected)
	_model.dirty = true
	audio_changed.emit(); status_changed.emit("Loop metadata updated; WAV export can embed it.")


func _on_loop_crossfade() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var frames: int = int(round(float(_loop_crossfade_ms.value) * 0.001 * float(_model.sample_rate)))
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Loop Crossfade",
		"undo_name": "Loop Crossfade",
		"success_message": "Applied loop crossfade in the background.",
	}
	_begin_heavy_job_method(&"loop_crossfade", [snapshot, int(_loop_start.value), int(_loop_end.value), frames], "pcm", context, "Crossfading Loop")


func _on_loop_find() -> void:
	_loop_candidates.clear()
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0:
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var radius: int = maxi(32, int(round(float(_model.sample_rate) * 0.15)))
	var context: Dictionary = {"track_index": track_index}
	_begin_heavy_job_method(&"loop_find", [snapshot, int(_loop_start.value), int(_loop_end.value), radius, 10], "loop_candidates", context, "Finding Seamless Loop")


func _on_loop_preview() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0:
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var context: Dictionary = {"track_index": track_index}
	_begin_heavy_job_method(&"loop_preview", [snapshot, int(_loop_start.value), int(_loop_end.value), _loop_mode.get_item_id(_loop_mode.selected)], "loop_preview", context, "Preparing Loop Preview")


func _on_loop_preview_stop() -> void:
	if _loop_player != null:
		_loop_player.stop()


func _on_loop_candidate_activated(index: int) -> void:
	var value: Variant = _loop_candidates.get_item_metadata(index)
	if value is Dictionary:
		var candidate: Dictionary = value as Dictionary
		_loop_start.value = int(candidate.get("start", 0)); _loop_end.value = int(candidate.get("end", 1))


func _selected_track_index() -> int:
	if _model == null:
		return -1
	return _model.primary_selected_track()


func _build_export_tab() -> void:
	var box: VBoxContainer = _new_tab("Export")
	var row: HFlowContainer = _flow(box)
	_label(row, "Target")
	_export_target = OptionButton.new()
	for target: String in PackedStringArray(["Entire Project", "Selected Track", "Selection", "Selected Clips", "Each Clip", "Each Track", "Each Label Region"]):
		_export_target.add_item(target)
	row.add_child(_export_target)
	_export_mono = CheckButton.new(); _export_mono.text = "Mono"; row.add_child(_export_mono)
	_label(row, "Bits")
	_export_bits = OptionButton.new(); _export_bits.add_item("16-bit", 16); _export_bits.add_item("8-bit", 8); row.add_child(_export_bits)
	_label(row, "Rate")
	_export_rate = _spin(row, 4000.0, 192000.0, 1.0, 44100.0, " Hz")
	_export_use_track_rate = CheckButton.new(); _export_use_track_rate.text = "Use Track Rate"; _export_use_track_rate.button_pressed = true; row.add_child(_export_use_track_rate)
	_export_normalize = CheckButton.new(); _export_normalize.text = "Normalize"; row.add_child(_export_normalize)
	_label(row, "Name")
	_export_pattern = LineEdit.new(); _export_pattern.text = "{track}_{label}_{index}"; _export_pattern.custom_minimum_size.x = 180.0; row.add_child(_export_pattern)
	_button(row, "Export...", _on_export_clicked)
	_export_dialog = FileDialog.new(); _export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; _export_dialog.access = FileDialog.ACCESS_FILESYSTEM; _export_dialog.filters = PackedStringArray(["*.wav;WAV Audio"]); _export_dialog.file_selected.connect(_on_export_file); add_child(_export_dialog)
	_export_dir_dialog = FileDialog.new(); _export_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR; _export_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM; _export_dir_dialog.dir_selected.connect(_on_export_directory); add_child(_export_dir_dialog)


func _on_export_clicked() -> void:
	if _model == null:
		return
	if _export_target.selected == 1 and _selected_track_index() < 0:
		status_changed.emit("Select a track first.")
		return
	if _export_target.selected == 3 and _model.selected_clip_ids.is_empty():
		status_changed.emit("Select one or more clips first.")
		return
	_pending_export_batch = _export_target.selected >= 3
	if _pending_export_batch:
		_export_dir_dialog.popup_file_dialog()
	else:
		_export_dialog.current_file = "audio.wav"
		_export_dialog.popup_file_dialog()


func _export_options() -> Dictionary:
	return {
		"mono": _export_mono.button_pressed,
		"bits": _export_bits.get_item_id(_export_bits.selected),
		"rate": int(_export_rate.value),
		"use_track_rate": _export_use_track_rate.button_pressed,
		"normalize": _export_normalize.button_pressed,
	}


func _on_export_file(path: String) -> void:
	if _model == null:
		return
	if _render_job != null and _render_job.task_id >= 0:
		status_changed.emit("Finish the current preview/export render first.")
		return
	var selected_track_index: int = _selected_track_index()
	var opts: Dictionary = _export_options()
	var output_rate: int = _model.sample_rate if bool(opts["use_track_rate"]) else int(opts["rate"])
	var job: GASAudioRenderJob = RenderJob.new() as GASAudioRenderJob
	var started: bool = false
	var signature_track: int = -1
	match _export_target.selected:
		0:
			var mix_snapshot: GASEditorModel = _model.create_render_snapshot()
			started = job.start_mix_to_file(mix_snapshot, path, int(opts["bits"]), bool(opts["mono"]), output_rate, bool(opts["normalize"]), _model.metadata, _model.loop_start_frame, _model.loop_end_frame, _model.loop_mode)
		1:
			if selected_track_index >= 0:
				if bool(opts["use_track_rate"]):
					output_rate = _model.tracks[selected_track_index].sample_rate
				var track_snapshot: GASEditorModel = _model.create_track_render_snapshot(selected_track_index)
				started = job.start_track_to_file(track_snapshot, path, int(opts["bits"]), bool(opts["mono"]), output_rate, bool(opts["normalize"]), _model.metadata, _model.loop_start_frame, _model.loop_end_frame, _model.loop_mode)
				signature_track = selected_track_index
		2:
			var selection_snapshot: GASEditorModel = _model.create_render_snapshot()
			var slice_start: int = _model.selection_start if _model.has_selection() else -1
			var slice_end: int = _model.selection_end if _model.has_selection() else -1
			started = job.start_mix_to_file(selection_snapshot, path, int(opts["bits"]), bool(opts["mono"]), output_rate, bool(opts["normalize"]), _model.metadata, _model.loop_start_frame, _model.loop_end_frame, _model.loop_mode, slice_start, slice_end)
	if not started:
		status_changed.emit("Nothing to export or background export could not start.")
		return
	_render_job = job
	_render_job_last_progress_percent = -1
	_render_job_elapsed = 0.0
	_render_job_kind = "export_file"
	_render_job_track_index = signature_track
	_render_job_track_signature = _track_signature(signature_track) if signature_track >= 0 else ""
	_render_assign_nodes.clear()
	status_changed.emit("Rendering and exporting WAV in the background…")


func _on_export_directory(folder: String) -> void:
	if _model == null:
		return
	if _render_job != null and _render_job.task_id >= 0:
		status_changed.emit("Finish the current preview/export render first.")
		return
	var opts: Dictionary = _export_options()
	var snapshot: GASEditorModel = _model.create_render_snapshot()
	var job: GASAudioRenderJob = RenderJob.new() as GASAudioRenderJob
	var started: bool = job.start_batch_to_directory(
		snapshot,
		folder,
		_export_target.selected,
		_model.selected_clip_ids,
		_export_pattern.text,
		int(opts["bits"]),
		bool(opts["mono"]),
		int(opts["rate"]),
		bool(opts["use_track_rate"]),
		bool(opts["normalize"]),
		_model.metadata
	)
	if not started:
		status_changed.emit("Could not start background batch export.")
		return
	_render_job = job
	_render_job_last_progress_percent = -1
	_render_job_elapsed = 0.0
	_render_job_kind = "export_batch"
	_render_job_track_index = -1
	_render_job_track_signature = ""
	_render_assign_nodes.clear()
	status_changed.emit("Batch export is running in the background…")


func _build_macros_tab() -> void:
	var box: VBoxContainer = _new_tab("Macros")
	var row: HFlowContainer = _flow(box)
	_macro_effect = OptionButton.new()
	_refresh_macro_effect_options()
	row.add_child(_macro_effect)
	_button(row, "Add Effect", _on_macro_add_effect)
	_button(row, "Add Normalize", _on_macro_add_normalize)
	_button(row, "Add Trim Silence", _on_macro_add_trim)
	_button(row, "Add Mono", _on_macro_add_mono)
	_button(row, "Add Export WAV", _on_macro_add_export, "Marks the end of a batch macro as an export step. Batch processing always writes outputs to a separate folder.")
	_button(row, "Up", _on_macro_up)
	_button(row, "Down", _on_macro_down)
	_button(row, "Remove", _on_macro_remove)
	_button(row, "Duplicate Step", _on_macro_duplicate_step)
	_button(row, "Apply to Selected Track", _on_macro_apply_track)
	_button(row, "Save Macro", _on_macro_save)
	_button(row, "Save Copy…", _on_macro_save_copy, "Duplicate the current macro into another .gasmacro file.")
	_button(row, "Load Macro", _on_macro_load)
	_button(row, "Batch Folder", _on_macro_batch)
	_button(row, "Batch Selected WAVs", _on_macro_batch_files)
	_macro_list = ItemList.new(); _macro_list.custom_minimum_size.y = 130.0; box.add_child(_macro_list)
	_macro_save_dialog = FileDialog.new(); _macro_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE; _macro_save_dialog.access = FileDialog.ACCESS_FILESYSTEM; _macro_save_dialog.filters = PackedStringArray(["*.gasmacro;GAS Macro"]); _macro_save_dialog.file_selected.connect(_on_macro_save_path); add_child(_macro_save_dialog)
	_macro_load_dialog = FileDialog.new(); _macro_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE; _macro_load_dialog.access = FileDialog.ACCESS_FILESYSTEM; _macro_load_dialog.filters = PackedStringArray(["*.gasmacro;GAS Macro"]); _macro_load_dialog.file_selected.connect(_on_macro_load_path); add_child(_macro_load_dialog)
	_macro_batch_dialog = FileDialog.new()
	_macro_batch_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_macro_batch_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_macro_batch_dialog.dir_selected.connect(_on_macro_batch_dir)
	add_child(_macro_batch_dialog)
	_macro_files_dialog = FileDialog.new()
	_macro_files_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_macro_files_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_macro_files_dialog.filters = PackedStringArray(["*.wav;WAV Audio"])
	_macro_files_dialog.files_selected.connect(_on_macro_files_selected)
	add_child(_macro_files_dialog)


func _refresh_macro_list() -> void:
	_macro_list.clear()
	for index: int in range(_macro_steps.size()):
		var step: Dictionary = _macro_steps[index]
		var effect_suffix: String = ""
		var effect_value: Variant = step.get("effect", {})
		if effect_value is Dictionary:
			var effect_type: String = str((effect_value as Dictionary).get("effect_type", ""))
			if not effect_type.is_empty():
				effect_suffix = " — " + EffectEngine.effect_display_name(effect_type)
		_macro_list.add_item("%d. %s%s" % [index + 1, str(step.get("command", "Step")), effect_suffix])


func refresh_extensions() -> void:
	_refresh_macro_effect_options()


func _refresh_macro_effect_options() -> void:
	if _macro_effect == null:
		return
	var previous_type: String = ""
	if _macro_effect.selected >= 0:
		var previous_value: Variant = _macro_effect.get_item_metadata(_macro_effect.selected)
		previous_type = str(previous_value) if previous_value != null else ""
	_macro_effect.clear()
	var effect_types: PackedStringArray = EffectEngine.available_effect_types()
	var selected_index: int = 0
	for index: int in range(effect_types.size()):
		var effect_type: String = effect_types[index]
		_macro_effect.add_item(EffectEngine.effect_display_name(effect_type))
		_macro_effect.set_item_metadata(index, effect_type)
		if effect_type == previous_type:
			selected_index = index
	if _macro_effect.get_item_count() > 0:
		_macro_effect.select(selected_index)


func _on_macro_add_effect() -> void:
	if _macro_effect == null or _macro_effect.selected < 0:
		return
	var metadata: Variant = _macro_effect.get_item_metadata(_macro_effect.selected)
	var effect_type: String = str(metadata) if metadata != null else _macro_effect.get_item_text(_macro_effect.selected)
	var effect: GASEffectData = EffectEngine.create_default(effect_type)
	_macro_steps.append({"command": "Effect", "enabled": true, "effect": MacroEngine.effect_to_dictionary(effect)})
	_refresh_macro_list()
func _on_macro_add_normalize() -> void:
	_macro_steps.append({"command": "Normalize", "target_db": -1.0, "enabled": true})
	_refresh_macro_list()


func _on_macro_add_trim() -> void:
	_macro_steps.append({"command": "Trim Silence", "threshold_db": -50.0, "enabled": true})
	_refresh_macro_list()


func _on_macro_add_mono() -> void:
	_macro_steps.append({"command": "Mono", "enabled": true})
	_refresh_macro_list()


func _on_macro_add_export() -> void:
	_macro_steps.append({"command": "Export WAV", "enabled": true, "bits": 16, "sample_rate": 0, "normalize": false})
	_refresh_macro_list()


func _on_macro_duplicate_step() -> void:
	var index: int = _macro_selected_index()
	if index < 0 or index >= _macro_steps.size():
		return
	_macro_steps.insert(index + 1, _macro_steps[index].duplicate(true))
	_refresh_macro_list()
	_macro_list.select(index + 1)


func _macro_selected_index() -> int:
	var selected: PackedInt32Array = _macro_list.get_selected_items()
	return selected[0] if not selected.is_empty() else -1


func _on_macro_up() -> void:
	var index: int = _macro_selected_index()
	if index <= 0:
		return
	var tmp: Dictionary = _macro_steps[index - 1]
	_macro_steps[index - 1] = _macro_steps[index]
	_macro_steps[index] = tmp
	_refresh_macro_list()
	_macro_list.select(index - 1)


func _on_macro_down() -> void:
	var index: int = _macro_selected_index()
	if index < 0 or index >= _macro_steps.size() - 1:
		return
	var tmp: Dictionary = _macro_steps[index + 1]
	_macro_steps[index + 1] = _macro_steps[index]
	_macro_steps[index] = tmp
	_refresh_macro_list()
	_macro_list.select(index + 1)


func _on_macro_remove() -> void:
	var index: int = _macro_selected_index()
	if index < 0:
		return
	_macro_steps.remove_at(index)
	_refresh_macro_list()


func _on_macro_apply_track() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Macro Result",
		"undo_name": "Apply Macro",
		"success_message": "Applied macro to the selected track in the background.",
	}
	var macro_steps_copy: Array[Dictionary] = []
	for step: Dictionary in _macro_steps:
		macro_steps_copy.append(step.duplicate(true))
	_begin_heavy_job_method(&"macro_track", [snapshot, macro_steps_copy], "pcm", context, "Applying Macro")


func _on_macro_save() -> void:
	_macro_save_dialog.current_file = _macro_current_path.get_file() if not _macro_current_path.is_empty() else "macro.gasmacro"
	_macro_save_dialog.popup_file_dialog()


func _on_macro_save_copy() -> void:
	var base_name: String = _macro_current_path.get_file().get_basename() if not _macro_current_path.is_empty() else "macro"
	_macro_save_dialog.current_file = base_name + "_copy.gasmacro"
	_macro_save_dialog.popup_file_dialog()


func _on_macro_load() -> void:
	_macro_load_dialog.popup_file_dialog()


func _on_macro_batch() -> void:
	_macro_batch_dialog.popup_file_dialog()


func _on_macro_batch_files() -> void:
	_macro_files_dialog.popup_file_dialog()


func _on_macro_save_path(path: String) -> void:
	var final_path: String = path if path.to_lower().ends_with(".gasmacro") else path + ".gasmacro"
	var error: Error = MacroEngine.save_macro(final_path, final_path.get_file().get_basename(), _macro_steps)
	if error == OK:
		_macro_current_path = final_path
	status_changed.emit("Macro saved." if error == OK else "Could not save macro.")
func _on_macro_load_path(path: String) -> void:
	var data: Dictionary = MacroEngine.load_macro(path)
	if data.is_empty():
		status_changed.emit("Could not load macro.")
		return
	_macro_current_path = path
	var steps_value: Variant = data.get("steps", [])
	_macro_steps.clear()
	if steps_value is Array:
		var loaded_steps: Array = steps_value as Array
		for item: Variant in loaded_steps:
			if item is Dictionary:
				_macro_steps.append((item as Dictionary).duplicate(true))
	_refresh_macro_list()
func _on_macro_batch_dir(folder: String) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	var paths: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.to_lower().ends_with(".wav"):
			paths.append(folder.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	_process_macro_paths(paths, folder.path_join("gas_macro_output"))


func _on_macro_files_selected(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	var common_folder: String = paths[0].get_base_dir()
	_process_macro_paths(paths, common_folder.path_join("gas_macro_output"))


func _process_macro_paths(paths: PackedStringArray, output_dir: String) -> void:
	if paths.is_empty():
		return
	var steps_copy: Array[Dictionary] = []
	for step: Dictionary in _macro_steps:
		steps_copy.append(step.duplicate(true))
	_begin_heavy_job_method(&"macro_batch", [paths, output_dir, steps_copy], "macro_batch", {}, "Batch Macro Processing")


func _build_optimizer_tab() -> void:
	var box: VBoxContainer = _new_tab("Game Optimization")
	var row: HFlowContainer = _flow(box)
	_button(row, "Analyze Selected Track", _on_optimizer_track)
	_button(row, "Analyze Mixdown", _on_optimizer_mix)
	_button(row, "Batch Scan Folder", _on_optimizer_batch)
	_button(row, "Batch Safe Optimize Folder", _on_optimizer_batch_fix, "Writes optimized copies into gas_optimized; source WAVs are never overwritten.")
	_button(row, "Convert Selected Track to Mono", _on_optimizer_mono)
	_button(row, "Resample Selected Track to 22050", _on_optimizer_22050)
	_optimizer_text = RichTextLabel.new(); _optimizer_text.bbcode_enabled = true; _optimizer_text.fit_content = false; _optimizer_text.custom_minimum_size.y = 150.0; box.add_child(_optimizer_text)
	_optimizer_dir_dialog = FileDialog.new(); _optimizer_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR; _optimizer_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM; _optimizer_dir_dialog.dir_selected.connect(_on_optimizer_batch_dir); add_child(_optimizer_dir_dialog)


func _show_optimization(result: Dictionary) -> void:
	if result.is_empty():
		_optimizer_text.text = "No audio to analyze."
		return
	var rec_value: Variant = result.get("recommendations", PackedStringArray())
	var recs: PackedStringArray = rec_value as PackedStringArray
	var text: String = "[b]Duration:[/b] %.3f s   [b]Channels:[/b] %d   [b]Rate:[/b] %d Hz\n[b]Memory:[/b] %s   [b]WAV:[/b] %s\n[b]Peak:[/b] %.1f dBFS   [b]RMS:[/b] %.1f dBFS   [b]Silence:[/b] %.1f%%   [b]Clipped frames:[/b] %d\n\n[b]Recommendations[/b]\n" % [float(result.get("duration", 0.0)), int(result.get("channels", 1)), int(result.get("sample_rate", 0)), AssetOptimizer.format_bytes(int(result.get("estimated_memory_bytes", 0))), AssetOptimizer.format_bytes(int(result.get("estimated_wav_bytes", 0))), float(result.get("peak_db", -160.0)), float(result.get("rms_db", -160.0)), float(result.get("silence_ratio", 0.0)) * 100.0, int(result.get("clipping_frames", 0))]
	for rec: String in recs:
		text += "• %s\n" % rec
	_optimizer_text.text = text
func _on_optimizer_track() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or track_index >= _model.tracks.size():
		status_changed.emit("Select a track first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		status_changed.emit("Could not snapshot the selected track for analysis.")
		return
	var context: Dictionary = {"track_index": track_index}
	_begin_heavy_job_method(&"optimizer_track", [snapshot, _model.tracks[track_index].name], "optimizer_analysis", context, "Analyzing Selected Track")


func _on_optimizer_mix() -> void:
	if _model == null or _model.tracks.is_empty():
		status_changed.emit("There is no project audio to analyze.")
		return
	var snapshot: GASEditorModel = _model.create_render_snapshot()
	_begin_heavy_job_method(&"optimizer_mix", [snapshot], "optimizer_mix_analysis", {}, "Analyzing Mixdown")
func _on_optimizer_batch() -> void:
	_optimizer_batch_fix_pending = false
	_optimizer_dir_dialog.popup_file_dialog()


func _on_optimizer_batch_fix() -> void:
	_optimizer_batch_fix_pending = true
	_optimizer_dir_dialog.popup_file_dialog()


func _on_optimizer_batch_dir(folder: String) -> void:
	var fix: bool = _optimizer_batch_fix_pending
	_optimizer_batch_fix_pending = false
	_begin_heavy_job_method(&"optimizer_folder", [folder, fix], "optimizer_folder", {}, "Optimizing Audio Folder" if fix else "Scanning Audio Folder")


func _on_optimizer_mono() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Optimized Mono",
		"undo_name": "Convert Track to Mono",
		"success_message": "Converted the selected track to mono in the background.",
	}
	_begin_heavy_job_method(&"optimizer_mono", [snapshot], "optimizer_pcm", context, "Converting Track to Mono")


func _on_optimizer_22050() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0 or not _model.is_track_editable(track_index):
		status_changed.emit("Select an editable track first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var context: Dictionary = {
		"track_index": track_index,
		"clip_name": "Optimized 22050",
		"undo_name": "Optimize Sample Rate",
		"success_message": "Resampled the selected track through 22050 Hz in the background.",
	}
	_begin_heavy_job_method(&"optimizer_resample", [snapshot, 22050, _model.sample_rate], "optimizer_pcm", context, "Resampling Selected Track")


func _build_history_tab() -> void:
	var box: VBoxContainer = _new_tab("History")
	_label(box, "Select an earlier operation and jump back to the state immediately before/after it using Undo history.")
	_history_list = ItemList.new(); _history_list.custom_minimum_size.y = 160.0; box.add_child(_history_list)
	_button(_flow(box), "Jump Back to Selected", _on_history_jump)


func _refresh_history() -> void:
	if _history_list == null:
		return
	_history_list.clear()
	if _model == null:
		return
	var labels: PackedStringArray = _model.history_labels()
	for index: int in range(labels.size()):
		_history_list.add_item("%02d  %s" % [index + 1, labels[index]])


func _on_history_jump() -> void:
	if _model == null or _history_list.get_selected_items().is_empty():
		return
	var selected: int = _history_list.get_selected_items()[0]
	var total: int = _model.history_labels().size()
	var steps: int = maxi(0, total - selected - 1)
	if steps > 0:
		_model.jump_history_back(steps); audio_changed.emit(); _refresh_history()


func _build_compare_tab() -> void:
	var box: VBoxContainer = _new_tab("A/B Compare")
	_label(box, "A = selected track without realtime track FX. B = current edited/rendered track. Loudness Match adjusts A to B RMS; Difference plays B−A.")
	var row: HFlowContainer = _flow(box)
	_button(row, "Capture A/B", _on_compare_capture)
	_button(row, "Play A", _on_compare_a)
	_button(row, "Play B", _on_compare_b)
	_button(row, "Play A Loudness-Matched", _on_compare_a_matched)
	_button(row, "Play Difference", _on_compare_difference)
	_compare_player = AudioStreamPlayer.new(); add_child(_compare_player)


func _on_compare_capture() -> void:
	var track_index: int = _selected_track_index()
	if _model == null or track_index < 0:
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		return
	var context: Dictionary = {"track_index": track_index}
	_begin_heavy_job_method(&"compare_capture", [snapshot], "compare_capture", context, "Capturing A/B")
func _play_compare(pcm: GASPCMData) -> void:
	if pcm == null:
		return
	_begin_heavy_job_method(&"compare_prepare", [pcm, pcm, 0], "compare_play", {}, "Preparing A/B Playback")


func _on_compare_a() -> void:
	_play_compare(_compare_original)


func _on_compare_b() -> void:
	_play_compare(_compare_edited)


func _on_compare_a_matched() -> void:
	if _compare_original == null or _compare_edited == null:
		return
	_begin_heavy_job_method(&"compare_prepare", [_compare_original, _compare_edited, 1], "compare_play", {}, "Preparing Loudness-Matched A/B")


func _on_compare_difference() -> void:
	if _compare_original == null or _compare_edited == null:
		return
	_begin_heavy_job_method(&"compare_prepare", [_compare_original, _compare_edited, 2], "compare_play", {}, "Preparing Difference Playback")


func _build_metadata_tab() -> void:
	var box: VBoxContainer = _new_tab("Metadata")
	var grid: GridContainer = GridContainer.new(); grid.columns = 2; box.add_child(grid)
	for key: String in PackedStringArray(["title", "artist", "album", "tracknumber", "genre", "date", "comment"]):
		_label(grid, key.capitalize())
		var edit: LineEdit = LineEdit.new()
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(edit)
		_metadata_edits[key] = edit
	_button(_flow(box), "Save Metadata to Project", _on_metadata_save)


func _refresh_metadata() -> void:
	if _model == null:
		return
	for key_value: Variant in _metadata_edits.keys():
		var key: String = str(key_value)
		var edit: LineEdit = _metadata_edits[key] as LineEdit
		if edit != null:
			edit.text = str(_model.metadata.get(key, ""))
func _on_metadata_save() -> void:
	if _model == null:
		return
	_model.push_undo("Metadata"); _model.metadata.clear()
	for key_value: Variant in _metadata_edits.keys():
		var key: String = str(key_value)
		var edit: LineEdit = _metadata_edits[key] as LineEdit
		if edit != null and not edit.text.strip_edges().is_empty():
			_model.metadata[key] = edit.text.strip_edges()
	_model.dirty = true
	audio_changed.emit()
	status_changed.emit("Metadata saved in the project and embedded in supported WAV exports.")


func _build_project_audio_tab() -> void:
	var box: VBoxContainer = _new_tab("Project Audio")
	_label(box, "Browse WAV, MP3 and Ogg assets already inside res://. All three formats are decoded to editable PCM when inserted.")
	var row: HFlowContainer = _flow(box)
	_button(row, "Refresh res:// Audio", _on_project_audio_refresh)
	_button(row, "Preview", _on_project_audio_preview)
	_button(row, "Stop", _on_project_audio_stop)
	_button(row, "Insert at Cursor", _on_project_audio_insert)
	_button(row, "Duplicate Asset", _on_project_audio_duplicate, "Creates a copy beside the selected audio asset without changing the original.")
	_button(row, "Rename Asset", _on_project_audio_rename, "Renames the selected res:// audio asset and updates open GAS clip source references.")
	_button(row, "Reveal in FileSystem", _on_project_audio_reveal, "Selects the asset in Godot's FileSystem dock.")
	_project_audio_info = Label.new()
	_project_audio_info.text = "Select an asset to inspect it."
	_project_audio_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_project_audio_info)
	_project_audio_list = ItemList.new()
	_project_audio_list.custom_minimum_size.y = 150.0
	_project_audio_list.item_selected.connect(_on_project_audio_selected)
	box.add_child(_project_audio_list)
	_project_audio_player = AudioStreamPlayer.new()
	add_child(_project_audio_player)
	_project_audio_rename_dialog = ConfirmationDialog.new()
	_project_audio_rename_dialog.title = "Rename Project Audio Asset"
	_project_audio_rename_dialog.dialog_text = "Enter a new audio filename. The asset remains in the same res:// folder and keeps its original format."
	_project_audio_rename_dialog.confirmed.connect(_on_project_audio_rename_confirmed)
	_project_audio_rename_edit = LineEdit.new()
	_project_audio_rename_edit.placeholder_text = "audio_name"
	_project_audio_rename_dialog.add_child(_project_audio_rename_edit)
	add_child(_project_audio_rename_dialog)


func _on_project_audio_refresh() -> void:
	if _project_audio_list == null:
		return
	_project_audio_info.text = "Scanning res:// audio in background…"
	_begin_heavy_job_method(&"project_audio_scan", ["res://"], "project_audio_scan", {}, "Scanning Project Audio")


func _selected_project_audio_path() -> String:
	if _project_audio_list == null:
		return ""
	var selected: PackedInt32Array = _project_audio_list.get_selected_items()
	if selected.is_empty() or selected[0] < 0 or selected[0] >= _project_audio_paths.size():
		return ""
	return _project_audio_paths[selected[0]]


func _on_project_audio_selected(_index: int) -> void:
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		return
	var entry_value: Variant = _project_audio_entry_cache.get(path, {})
	if not (entry_value is Dictionary):
		_project_audio_info.text = path
		return
	var entry: Dictionary = entry_value as Dictionary
	var bytes: int = int(entry.get("bytes", 0))
	var extension: String = str(entry.get("extension", path.get_extension().to_lower()))
	if extension == "wav" and entry.has("duration"):
		_project_audio_info.text = "%s • %.3f s • %d Hz • %s • WAV • %s" % [path, float(entry.get("duration", 0.0)), int(entry.get("rate", 0)), "Stereo" if int(entry.get("channels", 1)) > 1 else "Mono", AssetOptimizer.format_bytes(bytes)]
	else:
		_project_audio_info.text = "%s • %s • editable after PCM decode • %s" % [path, extension.to_upper(), AssetOptimizer.format_bytes(bytes)]


func _on_project_audio_preview() -> void:
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		return
	var stream: AudioStream = _load_project_audio_stream(path)
	if stream == null:
		return
	_project_audio_player.stop()
	_project_audio_player.stream = stream
	_project_audio_player.play()


func _begin_compressed_insert(path: String) -> void:
	if _compressed_insert_session != null and not _compressed_insert_session.finished:
		status_changed.emit("A compressed audio insert is already decoding.")
		return
	var session: GASCompressedDecodeSession = CompressedAudioDecoder.begin_decode(path, _model.sample_rate)
	if session == null:
		status_changed.emit("Could not open %s." % path)
		return
	_compressed_insert_session = session
	_compressed_insert_path = path
	_compressed_insert_target = _model.selected_track
	_compressed_insert_cursor = _model.cursor_frame
	_compressed_insert_elapsed = 0.0
	status_changed.emit("Decoding %s… 0%%" % path.get_file())


func _process_compressed_insert(delta: float) -> void:
	if _compressed_insert_session == null:
		return
	if not _compressed_insert_session.finished:
		_compressed_insert_session.step(3500)
		_compressed_insert_elapsed += delta
		if _compressed_insert_elapsed >= 0.2:
			_compressed_insert_elapsed = 0.0
			status_changed.emit("Decoding %s… %d%%" % [_compressed_insert_path.get_file(), int(round(_compressed_insert_session.progress() * 100.0))])
	if not _compressed_insert_session.finished:
		return
	var session: GASCompressedDecodeSession = _compressed_insert_session
	var path: String = _compressed_insert_path
	var target: int = _compressed_insert_target
	var cursor: int = _compressed_insert_cursor
	_compressed_insert_session = null
	_compressed_insert_path = ""
	_compressed_insert_target = -1
	if session.failed:
		status_changed.emit("Could not decode %s%s" % [path, ": " + session.error_message if not session.error_message.is_empty() else "."])
		return
	var decoded_pcm: GASPCMData = session.pcm_result()
	if decoded_pcm == null:
		status_changed.emit("Could not decode %s." % path)
		return
	var cache: GASWaveformCache = session.waveform_cache_result(decoded_pcm)
	if target >= 0 and target < _model.tracks.size() and _model.is_track_editable(target):
		_model.add_pcm_to_track(decoded_pcm, path.get_file().get_basename(), path, target, cursor, cache)
	else:
		_model.add_pcm_as_new_track_at(decoded_pcm, path.get_file().get_basename(), path, cursor, "Insert Project Audio", cache)
	audio_changed.emit()
	status_changed.emit("Decoded and inserted editable %s audio: %s" % [path.get_extension().to_upper(), path])


func _on_project_audio_stop() -> void:
	if _project_audio_player != null:
		_project_audio_player.stop()


func _on_project_audio_insert() -> void:
	if _model == null:
		return
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		status_changed.emit("Select a res:// audio asset first.")
		return
	var extension: String = path.get_extension().to_lower()
	if extension != "wav":
		_begin_compressed_insert(path)
		return
	var context: Dictionary = {"path": path, "target": _model.selected_track, "cursor": _model.cursor_frame}
	_begin_heavy_job_method(&"project_audio_load_wav", [path, _model.sample_rate], "project_audio_insert", context, "Loading Project WAV")


func _on_project_audio_duplicate() -> void:
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		status_changed.emit("Select a res:// audio asset first.")
		return
	var folder: String = path.get_base_dir()
	var extension: String = path.get_extension().to_lower()
	var stem: String = path.get_file().get_basename() + "_copy"
	var candidate: String = folder.path_join(stem + "." + extension)
	var suffix: int = 2
	while FileAccess.file_exists(candidate):
		candidate = folder.path_join("%s_%d.%s" % [stem, suffix, extension])
		suffix += 1
	var copy_error: Error = _copy_project_audio_file(path, candidate)
	if copy_error != OK:
		status_changed.emit("Could not duplicate audio asset: %s" % error_string(copy_error))
		return
	EditorInterface.get_resource_filesystem().update_file(candidate)
	_project_audio_pending_select_path = candidate
	_on_project_audio_refresh()
	status_changed.emit("Duplicated project audio as %s." % candidate)


func _on_project_audio_rename() -> void:
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		status_changed.emit("Select a res:// audio asset first.")
		return
	_project_audio_rename_edit.text = path.get_file().get_basename()
	_project_audio_rename_dialog.popup_centered(Vector2i(480, 150))
	_project_audio_rename_edit.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	_project_audio_rename_edit.focus_mode = Control.FOCUS_ALL
	if _project_audio_rename_edit.get_focus_mode_with_override() != Control.FOCUS_NONE:
		_project_audio_rename_edit.grab_focus()
	_project_audio_rename_edit.select_all()


func _on_project_audio_rename_confirmed() -> void:
	var old_path: String = _selected_project_audio_path()
	if old_path.is_empty():
		return
	var typed_name: String = _project_audio_rename_edit.text.strip_edges()
	if typed_name.is_empty():
		status_changed.emit("A filename is required.")
		return
	var extension: String = old_path.get_extension().to_lower()
	var stem: String = typed_name.get_basename() if typed_name.get_extension().to_lower() == extension else typed_name
	stem = ExportEngine.safe_name(stem)
	var new_path: String = old_path.get_base_dir().path_join(stem + "." + extension)
	if new_path == old_path:
		return
	if FileAccess.file_exists(new_path):
		status_changed.emit("An audio asset named %s already exists." % new_path.get_file())
		return
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(old_path), ProjectSettings.globalize_path(new_path))
	if rename_error != OK:
		status_changed.emit("Could not rename audio asset: %s" % error_string(rename_error))
		return
	var reference_count: int = _replace_open_source_references(old_path, new_path)
	EditorInterface.get_resource_filesystem().update_file(new_path)
	_project_audio_pending_select_path = new_path
	_on_project_audio_refresh()
	status_changed.emit("Renamed asset to %s and updated %d open clip source reference(s)." % [new_path, reference_count])
	if reference_count > 0:
		audio_changed.emit()


func _on_project_audio_reveal() -> void:
	var path: String = _selected_project_audio_path()
	if path.is_empty():
		status_changed.emit("Select a res:// audio asset first.")
		return
	EditorInterface.get_file_system_dock().navigate_to_path(path)
	status_changed.emit("Selected %s in Godot's FileSystem dock." % path)


func _copy_project_audio_file(source_path: String, destination_path: String) -> Error:
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var destination: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		var open_error: Error = FileAccess.get_open_error()
		source.close()
		return open_error
	var chunk_bytes: int = 1048576
	var total: int = source.get_length()
	while source.get_position() < total:
		var remaining: int = total - source.get_position()
		var chunk_size: int = mini(chunk_bytes, remaining)
		destination.store_buffer(source.get_buffer(chunk_size))
	source.close()
	destination.close()
	return OK


func _replace_open_source_references(old_path: String, new_path: String) -> int:
	if _model == null:
		return 0
	var changed: int = 0
	for track: GASEditorTrack in _model.tracks:
		if str(track.generated_settings.get("compressed_reference_path", "")) == old_path:
			track.generated_settings["compressed_reference_path"] = new_path
			changed += 1
		for clip: GASEditorClip in track.clips:
			if clip.source_path == old_path:
				clip.source_path = new_path
				clip.source_missing = false
				changed += 1
	if changed > 0:
		_model.dirty = true
	return changed


func _select_project_audio_path(path: String) -> void:
	if _project_audio_list == null:
		return
	for index: int in range(_project_audio_paths.size()):
		if _project_audio_paths[index] == path:
			_project_audio_list.select(index)
			_on_project_audio_selected(index)
			break


func _load_project_audio_stream(path: String) -> AudioStream:
	if path.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(path)
	return CompressedAudioDecoder.load_stream(path)


func _build_preview_tab() -> void:
	var box: VBoxContainer = _new_tab("Game Preview")
	_label(box, "Audition the selected track through actual Godot AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D nodes, then assign it to selected scene audio players.")
	var row: HFlowContainer = _flow(box)
	_preview_mode = OptionButton.new()
	_preview_mode.add_item("Flat")
	_preview_mode.add_item("2D")
	_preview_mode.add_item("3D")
	row.add_child(_preview_mode)
	_label(row, "Source X")
	_preview_source_x = _spin(row, -500.0, 500.0, 0.5, 0.0)
	_label(row, "Source Z")
	_preview_source_z = _spin(row, -500.0, 500.0, 0.5, 10.0)
	_label(row, "Listener X")
	_preview_listener_x = _spin(row, -500.0, 500.0, 0.5, 0.0)
	_label(row, "Listener Z")
	_preview_listener_z = _spin(row, -500.0, 500.0, 0.5, 0.0)
	_label(row, "Pan / X Trim")
	_preview_pan = HSlider.new()
	_preview_pan.min_value = -1.0
	_preview_pan.max_value = 1.0
	_preview_pan.step = 0.05
	_preview_pan.value = 0.0
	_preview_pan.custom_minimum_size.x = 110.0
	row.add_child(_preview_pan)
	var row2: HFlowContainer = _flow(box)
	_label(row2, "Attenuation")
	_preview_attenuation = OptionButton.new()
	_preview_attenuation.add_item("Inverse", AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
	_preview_attenuation.add_item("Inverse Square", AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE)
	_preview_attenuation.add_item("Logarithmic", AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC)
	_preview_attenuation.add_item("Disabled", AudioStreamPlayer3D.ATTENUATION_DISABLED)
	row2.add_child(_preview_attenuation)
	_label(row2, "Unit Size")
	_preview_unit_size = _spin(row2, 0.1, 1000.0, 0.1, 10.0)
	_label(row2, "Panning")
	_preview_panning_strength = _spin(row2, 0.0, 4.0, 0.05, 1.0)
	_label(row2, "Max Distance")
	_preview_max_distance = _spin(row2, 0.0, 10000.0, 1.0, 50.0)
	_preview_doppler = CheckButton.new()
	_preview_doppler.text = "Doppler"
	row2.add_child(_preview_doppler)
	_preview_directional = CheckButton.new()
	_preview_directional.text = "Directional"
	row2.add_child(_preview_directional)
	_button(row2, "Play", _on_preview_play)
	_button(row2, "Stop", _on_preview_stop)
	_button(row2, "Assign to Selected Godot Audio Player", _on_assign_selected_node)
	_button(row2, "Export Selected Track to res://…", _on_export_selected_to_res)
	_preview_flat = AudioStreamPlayer.new()
	add_child(_preview_flat)
	_preview_2d = AudioStreamPlayer2D.new()
	add_child(_preview_2d)
	_preview_3d = AudioStreamPlayer3D.new()
	add_child(_preview_3d)
	_assign_save_dialog = FileDialog.new()
	_assign_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_assign_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_assign_save_dialog.filters = PackedStringArray(["*.wav;WAV Audio"])
	_assign_save_dialog.file_selected.connect(_on_export_selected_res_path)
	add_child(_assign_save_dialog)


func _on_preview_play() -> void:
	var track_index: int = _selected_track_index()
	if track_index < 0:
		status_changed.emit("Select a track first.")
		return
	var direct_stream: AudioStream = _direct_source_stream(track_index)
	if direct_stream != null:
		_apply_preview_stream(direct_stream)
		return
	_start_track_wav_job("preview", track_index, [])


func _apply_preview_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	_on_preview_stop()
	var relative_x: float = float(_preview_source_x.value - _preview_listener_x.value)
	var relative_z: float = float(_preview_source_z.value - _preview_listener_z.value)
	match _preview_mode.selected:
		1:
			_preview_2d.stream = stream
			_preview_2d.position = Vector2(relative_x * 50.0 + float(_preview_pan.value) * 250.0, relative_z * 50.0)
			_preview_2d.play()
		2:
			_preview_3d.stream = stream
			_preview_3d.position = Vector3(relative_x + float(_preview_pan.value) * 2.0, 0.0, relative_z)
			_preview_3d.max_distance = float(_preview_max_distance.value)
			_preview_3d.unit_size = float(_preview_unit_size.value)
			_preview_3d.panning_strength = float(_preview_panning_strength.value)
			_preview_3d.attenuation_model = _preview_attenuation.get_item_id(_preview_attenuation.selected)
			_preview_3d.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP if _preview_doppler.button_pressed else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			_preview_3d.emission_angle_enabled = _preview_directional.button_pressed
			_preview_3d.play()
		_:
			_preview_flat.stream = stream
			_preview_flat.play()
	status_changed.emit("Game-audio preview started in %s mode." % _preview_mode.get_item_text(_preview_mode.selected))


func _on_preview_stop() -> void:
	_preview_flat.stop()
	_preview_2d.stop()
	_preview_3d.stop()


func _on_assign_selected_node() -> void:
	var track_index: int = _selected_track_index()
	if track_index < 0:
		status_changed.emit("Select a track first.")
		return
	var selected: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var compatible: Array[Node] = []
	for node: Node in selected:
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			compatible.append(node)
	if compatible.is_empty():
		status_changed.emit("Select an AudioStreamPlayer, AudioStreamPlayer2D, or AudioStreamPlayer3D node in the scene first.")
		return
	var direct_stream: AudioStream = _direct_source_stream(track_index)
	if direct_stream != null:
		_apply_assignment(direct_stream, compatible)
		return
	_start_track_wav_job("assign", track_index, compatible)


func _on_export_selected_to_res() -> void:
	var track_index: int = _selected_track_index()
	if track_index < 0:
		status_changed.emit("Select a track first.")
		return
	_assign_save_dialog.current_file = ExportEngine.safe_name(_model.tracks[track_index].name) + ".wav"
	_assign_save_dialog.popup_file_dialog()


func _on_export_selected_res_path(path: String) -> void:
	var track_index: int = _selected_track_index()
	if track_index < 0:
		status_changed.emit("Select a track first.")
		return
	if _render_job != null and _render_job.task_id >= 0:
		status_changed.emit("Finish the current preview/export render first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		status_changed.emit("Could not snapshot the selected track for export.")
		return
	var job: GASAudioRenderJob = RenderJob.new() as GASAudioRenderJob
	if not job.start_track_to_file(snapshot, path, 16, false, _model.sample_rate, false, _model.metadata, _model.loop_start_frame, _model.loop_end_frame, _model.loop_mode):
		status_changed.emit("Could not start background track export.")
		return
	_render_job = job
	_render_job_last_progress_percent = -1
	_render_job_elapsed = 0.0
	_render_job_kind = "export_res"
	_render_job_track_index = track_index
	_render_job_track_signature = _track_signature(track_index)
	_render_assign_nodes.clear()
	status_changed.emit("Rendering and exporting selected track in the background…")


func _direct_source_stream(track_index: int) -> AudioStream:
	if _model == null or track_index < 0 or track_index >= _model.tracks.size():
		return null
	var track: GASEditorTrack = _model.tracks[track_index]
	if track.clips.size() != 1 or track.channel_mode != GASEditorTrack.CHANNEL_AUTO:
		return null
	if not track.effect_stack.is_empty() or not track.automation_lanes.is_empty():
		return null
	if absf(track.gain_db) > 0.0001 or absf(track.pan) > 0.0001:
		return null
	var clip: GASEditorClip = track.clips[0]
	if clip == null or clip.pcm == null or clip.timeline_start != 0 or clip.muted:
		return null
	if not clip.effect_stack.is_empty() or clip.fade_in_samples > 0 or clip.fade_out_samples > 0:
		return null
	if absf(clip.gain_db) > 0.0001 or absf(clip.pan) > 0.0001:
		return null
	if clip.source_start_frame != 0 or clip.source_end() != clip.pcm.frame_count():
		return null
	var source_extension: String = clip.source_path.get_extension().to_lower()
	var source_global: String = ProjectSettings.globalize_path(clip.source_path) if clip.source_path.begins_with("res://") or clip.source_path.begins_with("user://") else clip.source_path
	var localized_source: String = ProjectSettings.localize_path(source_global)
	if localized_source.begins_with("res://"):
		var loaded_resource: Resource = load(localized_source)
		var loaded_stream: AudioStream = loaded_resource as AudioStream
		if loaded_stream != null:
			return loaded_stream
	if source_extension == "wav":
		# Avoid synchronously parsing a large external WAV on the editor thread.
		# The normal background render path handles external WAV assignment instead.
		return null
	if CompressedAudioDecoder.is_compressed_path(clip.source_path):
		return CompressedAudioDecoder.load_stream(clip.source_path)
	return null


func _start_track_wav_job(kind: String, track_index: int, assign_nodes: Array[Node]) -> void:
	if _render_job != null and _render_job.task_id >= 0:
		status_changed.emit("Finish the current preview/export render first.")
		return
	if _model == null or track_index < 0 or track_index >= _model.tracks.size():
		status_changed.emit("Select a track first.")
		return
	var snapshot: GASEditorModel = _model.create_track_render_snapshot(track_index)
	if snapshot == null:
		status_changed.emit("Could not snapshot the selected track.")
		return
	var job: GASAudioRenderJob = RenderJob.new() as GASAudioRenderJob
	if not job.start_track_to_wav(snapshot):
		status_changed.emit("Could not start background track render.")
		return
	_render_job = job
	_render_job_last_progress_percent = -1
	_render_job_elapsed = 0.0
	_render_job_kind = kind
	_render_job_track_index = track_index
	_render_job_track_signature = _track_signature(track_index)
	_render_assign_nodes = assign_nodes.duplicate()
	status_changed.emit("Rendering selected track in the background…")


func _process_render_job(delta: float) -> void:
	if _render_job == null or _render_job.task_id < 0:
		return
	_render_job_elapsed += delta
	var progress_value: float = _render_job.progress()
	var progress_percent: int = clampi(int(round(progress_value * 100.0)), 0, 100)
	if progress_percent != _render_job_last_progress_percent:
		_render_job_last_progress_percent = progress_percent
		var progress_label: String = "Rendering audio"
		match _render_job_kind:
			"export_file", "export_res":
				progress_label = "Rendering and exporting WAV"
			"export_batch":
				progress_label = "Batch exporting WAV"
			"preview":
				progress_label = "Rendering preview"
			"assign":
				progress_label = "Rendering audio for assignment"
		status_changed.emit("%s… %d%%" % [progress_label, progress_percent])
		if _heavy_job == null:
			if _heavy_job_status != null:
				_heavy_job_status.text = "%s • %d%% • %.1f s" % [progress_label, progress_percent, _render_job_elapsed]
			if _heavy_job_progress_bar != null:
				_heavy_job_progress_bar.value = progress_value * 100.0
	if not _render_job.is_complete():
		return
	var job: GASAudioRenderJob = _render_job
	var kind: String = _render_job_kind
	var track_index: int = _render_job_track_index
	var signature: String = _render_job_track_signature
	var assign_nodes: Array[Node] = _render_assign_nodes.duplicate()
	job.collect()
	_render_job = null
	_render_job_kind = ""
	_render_job_track_index = -1
	_render_job_track_signature = ""
	_render_assign_nodes.clear()
	_render_job_last_progress_percent = -1
	_render_job_elapsed = 0.0
	if _heavy_job == null:
		if _heavy_job_progress_bar != null:
			_heavy_job_progress_bar.value = 0.0
		if _heavy_job_status != null:
			_heavy_job_status.text = "Ready"
	if job.error != OK:
		status_changed.emit("Background audio render failed: %s" % error_string(job.error))
		return
	if (kind == "preview" or kind == "assign") and track_index >= 0 and not signature.is_empty() and _track_signature(track_index) != signature:
		status_changed.emit("The selected track changed while rendering; the stale result was discarded.")
		return
	match kind:
		"preview":
			_apply_preview_stream(job.wav_result)
		"assign":
			_apply_assignment(job.wav_result, assign_nodes)
		"export_res", "export_file":
			if job.error == OK:
				_update_editor_file(job.output_path)
				status_changed.emit("Exported WAV: %s" % job.output_path)
		"export_batch":
			for exported_path: String in job.exported_paths:
				_update_editor_file(exported_path)
			status_changed.emit("Exported %d WAV files." % job.files_exported)


func _apply_assignment(stream: AudioStream, nodes: Array[Node]) -> void:
	if stream == null:
		status_changed.emit("Rendered track produced no assignable WAV.")
		return
	var compatible: Array[Node] = []
	for node: Node in nodes:
		if is_instance_valid(node) and (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
			compatible.append(node)
	if compatible.is_empty():
		status_changed.emit("The selected audio player node is no longer available.")
		return
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Assign Gator Audio Studio Audio")
	for node: Node in compatible:
		var previous_stream: AudioStream = node.get("stream") as AudioStream
		undo_redo.add_do_property(node, &"stream", stream)
		undo_redo.add_undo_property(node, &"stream", previous_stream)
	undo_redo.commit_action()
	status_changed.emit("Assigned audio to %d selected Godot audio player node(s) with editor Undo support." % compatible.size())


func _update_editor_file(path: String) -> void:
	var localized: String = ProjectSettings.localize_path(path)
	if not localized.begins_with("res://") or not FileAccess.file_exists(localized):
		return
	if not _pending_editor_imports.has(localized):
		_pending_editor_imports.append(localized)
	_editor_import_flush_queued = true
	_editor_import_wait_frames = maxi(_editor_import_wait_frames, 2)


func _process_editor_import_queue() -> void:
	if _editor_import_in_progress or not _editor_import_flush_queued:
		return
	if _editor_import_wait_frames > 0:
		_editor_import_wait_frames -= 1
		return
	if _pending_editor_imports.is_empty():
		_editor_import_flush_queued = false
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		_pending_editor_imports.clear()
		_editor_import_flush_queued = false
		return
	if filesystem.is_scanning():
		return
	var import_paths: PackedStringArray = _pending_editor_imports.duplicate()
	_pending_editor_imports.clear()
	_editor_import_flush_queued = false
	var valid_paths: PackedStringArray = PackedStringArray()
	for localized: String in import_paths:
		if FileAccess.file_exists(localized):
			filesystem.update_file(localized)
			valid_paths.append(localized)
	if valid_paths.is_empty():
		return
	_editor_import_in_progress = true
	filesystem.reimport_files(valid_paths)
	_editor_import_in_progress = false
	if not _pending_editor_imports.is_empty():
		_editor_import_flush_queued = true
		_editor_import_wait_frames = 2


func _on_hide() -> void:
	visible = false
