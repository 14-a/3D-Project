@tool
extends Control

signal send_to_audio_editor(wav: AudioStreamWAV, suggested_name: String)
signal project_state_changed

const RetroProfiles := preload("res://addons/gator_audio_studio/audio/retro_profiles.gd")
const PresetBank := preload("res://addons/gator_audio_studio/audio/preset_bank.gd")
const SynthEngine := preload("res://addons/gator_audio_studio/audio/synth_engine.gd")
const WaveformPreview := preload("res://addons/gator_audio_studio/ui/waveform_preview.gd")
const WavetableEditor := preload("res://addons/gator_audio_studio/ui/wavetable_editor.gd")
const HardwareRules := preload("res://addons/gator_audio_studio/audio/hardware_rules.gd")
const SoundGraph := preload("res://addons/gator_audio_studio/audio/sound_graph.gd")
const BatchGenerator := preload("res://addons/gator_audio_studio/audio/batch_generator.gd")
const GeneratorExportJob := preload("res://addons/gator_audio_studio/audio/generator_export_job.gd")
const ExportEngine := preload("res://addons/gator_audio_studio/audio/export_engine.gd")
const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const ExtensionAPI: GDScript = preload("res://addons/gator_audio_studio/audio/extension_api.gd")
const ExtensionManager: GDScript = preload("res://addons/gator_audio_studio/audio/extension_manager.gd")
const ExtensionGeneratorJob: GDScript = preload("res://addons/gator_audio_studio/audio/extension_generator_job.gd")

var _player: AudioStreamPlayer
var _waveform: GASWaveformPreview
var _generator_source_option: OptionButton
var _profile_option: OptionButton
var _category_option: OptionButton
var _hardware_toggle: CheckButton
var _accuracy_option: OptionButton
var _seed_spin: SpinBox
var _status: Label
var _profile_info: Label
var _save_dialog: FileDialog
var _save_mode: String = "current"

var _wave_option: OptionButton
var _filter_mode_option: OptionButton
var _noise_mode_option: OptionButton
var _layer_option: OptionButton
var _mutation_slider: HSlider
var _breed_bias_slider: HSlider
var _batch_spin: SpinBox
var _variant_count_option: OptionButton
var _variants_container: HFlowContainer
var _kept_variants_container: HFlowContainer
var _favorite_variants_container: HFlowContainer
var _tab_container: TabContainer
var _wavetable_editor: GASWavetableEditor
var _wavetable_custom_size: SpinBox
var _fm_routing_label: Label
var _sample_loop_toggle: CheckButton
var _sample_reverse_toggle: CheckButton
var _sample_playback_spin: SpinBox
var _sample_rate_reduce_spin: SpinBox
var _sample_loop_start_spin: SpinBox
var _sample_loop_end_spin: SpinBox
var _voice_pitch_min_spin: SpinBox
var _voice_pitch_max_spin: SpinBox
var _voice_random_pitch_spin: SpinBox
var _character_seed_spin: SpinBox

var _param_controls: Dictionary = {}
var _builtin_layer_panel: PanelContainer
var _builtin_param_panel: PanelContainer
var _extension_panel: PanelContainer
var _extension_description: Label
var _extension_preset_option: OptionButton
var _extension_user_preset_option: OptionButton
var _extension_user_preset_name: LineEdit
var _extension_project_preset_option: OptionButton
var _extension_project_preset_name: LineEdit
var _extension_param_grid: GridContainer
var _extension_param_controls: Dictionary = {}
var _extension_revision: int = -1
var _extension_group_id: int = -1
var _extension_job: GASExtensionGeneratorJob
var _extension_job_mode: String = ""
var _extension_job_autoplay: bool = false
var _extension_completion_text: String = ""
var _range_controls: Dictionary = {}
var _lock_controls: Dictionary = {}
var _fm_controls: Array[Dictionary] = []
var _variant_buttons: Array[Button] = []
var _kept_variant_buttons: Array[Button] = []
var _favorite_variant_buttons: Array[Button] = []
var _variant_results: Array[Dictionary] = []
var _kept_variants: Array[Dictionary] = []
var _favorite_variants: Array[Dictionary] = []
var _current_result: Dictionary = {}
var _current_params: Dictionary = {}
var _selected_variant_index: int = -1
var _selected_variant_source: String = ""
var _selected_variant_params: Dictionary = {}
var _selected_variant_result: Dictionary = {}
var _parent_a: Dictionary = {}
var _parent_b: Dictionary = {}
var _user_preset_option: OptionButton
var _project_preset_option: OptionButton
var _user_preset_name: LineEdit
var _project_preset_name: LineEdit
var _advanced_controls: Dictionary = {}
var _distortion_option: OptionButton
var _delay_mode_option: OptionButton
var _fm_algorithm_option: OptionButton
var _opl_mode_option: OptionButton
var _opl_waveform_option: OptionButton
var _osc_sync_toggle: CheckButton
var _ay_envelope_option: OptionButton
var _note_sequence_edit: LineEdit
var _fantasy_bits_spin: SpinBox
var _fantasy_rate_spin: SpinBox
var _fantasy_channels_spin: SpinBox
var _history_option: OptionButton
var _result_history: Array[Dictionary] = []
var _compare_a: Dictionary = {}
var _compare_b: Dictionary = {}
var _seed_history: Array[int] = []
var _favorite_seeds: Array[int] = []
var _naming_template_edit: LineEdit
var _timeline_queue: Array[Dictionary] = []
var _batch_export_dialog: FileDialog
var _sample_dialog: FileDialog
var _graph: Dictionary = {}
var _graph_tree: Tree
var _graph_type_option: OptionButton
var _graph_node_option: OptionButton
var _graph_params_edit: LineEdit
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _suppress_undo: bool = false
var _last_undo_key: String = ""
var _last_undo_usec: int = 0
var _preview_render_queued: bool = false
var _background_group_id: int = -1
var _background_job: GASBatchGenerator
var _background_completion_text: String = ""
var _voice_export_after_generate: bool = false
var _generator_export_job: GASGeneratorExportJob
var _pending_editor_imports: PackedStringArray = PackedStringArray()
var _editor_import_flush_queued: bool = false
var _editor_import_in_progress: bool = false
var _editor_import_wait_frames: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_seed_spin.value = 418731
	_extension_revision = ExtensionManager.revision()
	refresh_extensions()
	_generate_current(false)
	_refresh_preset_lists()
	set_process(true)


func get_project_state() -> Dictionary:
	var favorite_seed_values: Array[int] = []
	for seed: int in _favorite_seeds:
		favorite_seed_values.append(seed)
	var seed_history_values: Array[int] = []
	for seed: int in _seed_history:
		seed_history_values.append(seed)
	var extension_id_text: String = str(_active_extension_generator_id())
	if extension_id_text.is_empty():
		extension_id_text = str(_current_params.get("generator_extension_id", ""))
	var state_profile: String = str(_current_params.get("profile", _selected_profile() if _profile_option != null else RetroProfiles.MODERN)) if not extension_id_text.is_empty() else (_selected_profile() if _profile_option != null else RetroProfiles.MODERN)
	var state_category: String = str(_current_params.get("category", _selected_category() if _category_option != null else "UI Confirm")) if not extension_id_text.is_empty() else (_selected_category() if _category_option != null else "UI Confirm")
	return {
		"generator_extension_id": extension_id_text,
		"profile": state_profile,
		"category": state_category,
		"accuracy_mode": _accuracy_option.get_item_text(_accuracy_option.selected) if _accuracy_option != null and _accuracy_option.selected >= 0 else HardwareRules.MODE_HARDWARE,
		"hardware_limits": _hardware_toggle.button_pressed if _hardware_toggle != null else true,
		"seed": int(_seed_spin.value) if _seed_spin != null else 418731,
		"current_params": _current_params.duplicate(true),
		"kept_variants": _duplicate_dictionary_list(_kept_variants),
		"favorite_variants": _duplicate_dictionary_list(_favorite_variants),
		"favorite_seeds": favorite_seed_values,
		"seed_history": seed_history_values,
		"parent_a": _parent_a.duplicate(true),
		"parent_b": _parent_b.duplicate(true),
		"mutation_amount": float(_mutation_slider.value) if _mutation_slider != null else 0.25,
		"breed_bias": float(_breed_bias_slider.value) if _breed_bias_slider != null else 0.5,
		"variant_count_index": _variant_count_option.selected if _variant_count_option != null else 1,
		"naming_template": _naming_template_edit.text if _naming_template_edit != null else "{profile}_{category}_{seed}",
		"generator_tab": _tab_container.current_tab if _tab_container != null else 0,
		"layer_index": _layer_option.selected if _layer_option != null else 0,
		"wavetable_custom_size": int(_wavetable_custom_size.value) if _wavetable_custom_size != null else 32,
		"character_seed": int(_character_seed_spin.value) if _character_seed_spin != null else 1,
		"voice_pitch_min": float(_voice_pitch_min_spin.value) if _voice_pitch_min_spin != null else 120.0,
		"voice_pitch_max": float(_voice_pitch_max_spin.value) if _voice_pitch_max_spin != null else 520.0,
		"voice_random_pitch": float(_voice_random_pitch_spin.value) if _voice_random_pitch_spin != null else 0.15,
		"graph": _graph.duplicate(true),
	}


func apply_project_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_suppress_undo = true
	var requested_extension_id: String = str(state.get("generator_extension_id", ""))
	var requested_extension_available: bool = requested_extension_id.is_empty() or ExtensionAPI.create_generator_extension(StringName(requested_extension_id)) != null
	_select_generator_source_id(StringName(requested_extension_id))
	_apply_generator_source_mode(false)
	if _profile_option != null:
		_select_option_text(_profile_option, str(state.get("profile", RetroProfiles.MODERN)))
	if _category_option != null:
		_select_option_text(_category_option, str(state.get("category", "UI Confirm")))
	if _accuracy_option != null:
		_select_option_text(_accuracy_option, str(state.get("accuracy_mode", HardwareRules.MODE_HARDWARE)))
	if _hardware_toggle != null:
		_hardware_toggle.set_pressed_no_signal(bool(state.get("hardware_limits", true)))
	if _seed_spin != null:
		_seed_spin.set_value_no_signal(float(int(state.get("seed", 418731))))
	var params_value: Variant = state.get("current_params", {})
	if params_value is Dictionary and not (params_value as Dictionary).is_empty():
		_current_params = (params_value as Dictionary).duplicate(true)
	else:
		var mode: String = str(state.get("accuracy_mode", HardwareRules.MODE_HARDWARE))
		_current_params = PresetBank.make_preset_with_mode(_selected_profile(), _selected_category(), int(_seed_spin.value), mode)
	_kept_variants = _dictionary_array(state.get("kept_variants", []))
	_favorite_variants = _dictionary_array(state.get("favorite_variants", []))
	_favorite_seeds.clear()
	var favorite_value: Variant = state.get("favorite_seeds", [])
	if favorite_value is Array:
		var favorite_array: Array = favorite_value as Array
		for item: Variant in favorite_array:
			_favorite_seeds.append(int(item))
	_seed_history.clear()
	var history_value: Variant = state.get("seed_history", [])
	if history_value is Array:
		var history_array: Array = history_value as Array
		for item: Variant in history_array:
			_seed_history.append(int(item))
	_parent_a = (state.get("parent_a", {}) as Dictionary).duplicate(true) if state.get("parent_a", {}) is Dictionary else {}
	_parent_b = (state.get("parent_b", {}) as Dictionary).duplicate(true) if state.get("parent_b", {}) is Dictionary else {}
	if _mutation_slider != null:
		_mutation_slider.set_value_no_signal(float(state.get("mutation_amount", 0.25)))
	if _breed_bias_slider != null:
		_breed_bias_slider.set_value_no_signal(float(state.get("breed_bias", 0.5)))
	if _variant_count_option != null and _variant_count_option.get_item_count() > 0:
		_variant_count_option.select(clampi(int(state.get("variant_count_index", 1)), 0, _variant_count_option.get_item_count() - 1))
	if _naming_template_edit != null:
		_naming_template_edit.text = str(state.get("naming_template", "{profile}_{category}_{seed}"))
	if _wavetable_custom_size != null:
		_wavetable_custom_size.set_value_no_signal(float(int(state.get("wavetable_custom_size", 32))))
	if _character_seed_spin != null:
		_character_seed_spin.set_value_no_signal(float(int(state.get("character_seed", 1))))
	if _voice_pitch_min_spin != null:
		_voice_pitch_min_spin.set_value_no_signal(float(state.get("voice_pitch_min", 120.0)))
	if _voice_pitch_max_spin != null:
		_voice_pitch_max_spin.set_value_no_signal(float(state.get("voice_pitch_max", 520.0)))
	if _voice_random_pitch_spin != null:
		_voice_random_pitch_spin.set_value_no_signal(float(state.get("voice_random_pitch", 0.15)))
	var graph_value: Variant = state.get("graph", {})
	if graph_value is Dictionary and not (graph_value as Dictionary).is_empty():
		_graph = (graph_value as Dictionary).duplicate(true)
	if requested_extension_available:
		_sync_ui_from_params()
		if _layer_option != null and _layer_option.get_item_count() > 0:
			_layer_option.select(clampi(int(state.get("layer_index", 0)), 0, _layer_option.get_item_count() - 1))
			_refresh_layer_controls()
		_render_params(false)
	else:
		_select_generator_source_id(StringName(requested_extension_id))
		_apply_generator_source_mode(false)
		_current_result.clear()
		if _player != null:
			_player.stop()
			_player.stream = null
		if _waveform != null:
			_waveform.set_samples(PackedFloat32Array())
		_status.text = "Project generator extension '%s' is missing or disabled. Its saved parameters were preserved." % requested_extension_id
	_refresh_saved_variant_buttons()
	_refresh_graph_ui()
	if _tab_container != null and _tab_container.get_tab_count() > 0:
		_tab_container.current_tab = clampi(int(state.get("generator_tab", 0)), 0, _tab_container.get_tab_count() - 1)
	_selected_variant_index = -1
	_selected_variant_source = ""
	_selected_variant_params.clear()
	_selected_variant_result.clear()
	_variant_results.clear()
	_suppress_undo = false


func _duplicate_dictionary_list(source: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in source:
		result.append(item.duplicate(true))
	return result


func _exit_tree() -> void:
	# Generator workers are RefCounted/self-contained. Never block plugin
	# deactivation waiting for an in-flight generation/export batch.
	_background_group_id = -1
	_background_job = null
	_extension_group_id = -1
	_extension_job = null
	_generator_export_job = null


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.055, 0.06, 0.071)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title_bar: HBoxContainer = HBoxContainer.new()
	root.add_child(title_bar)
	var title: Label = Label.new()
	title.text = "GATOR AUDIO STUDIO"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)
	var version: Label = Label.new()
	version.text = "Generator Complete • GAS 1.0.0"
	version.modulate = Color(0.72, 0.75, 0.8)
	title_bar.add_child(version)

	root.add_child(HSeparator.new())

	var top_row: HFlowContainer = _flow_row()
	top_row.add_theme_constant_override("separation", 8)
	root.add_child(top_row)

	top_row.add_child(_label("Source"))
	_generator_source_option = OptionButton.new()
	_generator_source_option.custom_minimum_size.x = 150
	_generator_source_option.item_selected.connect(_on_generator_source_changed)
	top_row.add_child(_generator_source_option)

	top_row.add_child(_label("Profile"))
	_profile_option = OptionButton.new()
	_profile_option.custom_minimum_size.x = 150
	for name: String in RetroProfiles.PROFILE_ORDER:
		_profile_option.add_item(name)
	_profile_option.item_selected.connect(_on_profile_changed)
	top_row.add_child(_profile_option)

	top_row.add_child(_label("Category"))
	_category_option = OptionButton.new()
	_category_option.custom_minimum_size.x = 125
	for category: String in PresetBank.CATEGORY_ORDER:
		_category_option.add_item(category)
	_category_option.item_selected.connect(_on_category_changed)
	top_row.add_child(_category_option)

	top_row.add_child(_label("Accuracy"))
	_accuracy_option = OptionButton.new()
	_accuracy_option.add_item(HardwareRules.MODE_STYLE)
	_accuracy_option.add_item(HardwareRules.MODE_HARDWARE)
	_accuracy_option.select(1)
	_accuracy_option.tooltip_text = "Style keeps the platform character while allowing conveniences. Hardware enforces channel, frequency, envelope, bit-depth and sample-rate restrictions."
	_accuracy_option.item_selected.connect(_on_accuracy_changed)
	top_row.add_child(_accuracy_option)

	_hardware_toggle = CheckButton.new()
	_hardware_toggle.text = "Hardware Limits"
	_hardware_toggle.button_pressed = true
	_hardware_toggle.tooltip_text = "Compatibility toggle for Hardware accuracy mode."
	_hardware_toggle.toggled.connect(_on_hardware_toggled)
	top_row.add_child(_hardware_toggle)

	top_row.add_child(_label("Seed"))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 1
	_seed_spin.max_value = 2147483646
	_seed_spin.step = 1
	_seed_spin.custom_minimum_size.x = 105
	top_row.add_child(_seed_spin)

	var new_seed: Button = Button.new()
	new_seed.text = "New Seed"
	new_seed.tooltip_text = "Create a new deterministic seed without changing the selected waveform."
	new_seed.pressed.connect(_on_new_seed)
	top_row.add_child(new_seed)
	_add_button(top_row, "Copy Seed", _on_copy_seed)
	_add_button(top_row, "Paste Seed", _on_paste_seed)
	_add_button(top_row, "★ Seed", _on_favorite_seed)

	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let the children's stretch ratios define the initial split. This is
	# responsive and avoids a fixed pixel offset that becomes wrong at
	# different editor widths. The divider remains user-draggable.
	body.split_offsets = PackedInt32Array([0])
	root.add_child(body)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_scroll.custom_minimum_size.x = 400
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.45
	body.add_child(left_scroll)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left)

	var info_panel: PanelContainer = PanelContainer.new()
	left.add_child(info_panel)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_panel.add_child(info_box)
	var info_title: Label = Label.new()
	info_title.text = "PROFILE"
	info_title.add_theme_font_size_override("font_size", 14)
	info_box.add_child(info_title)
	_profile_info = Label.new()
	_profile_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_profile_info.custom_minimum_size.y = 74
	info_box.add_child(_profile_info)

	var toolbar: HFlowContainer = _flow_row()
	left.add_child(toolbar)
	_add_button(toolbar, "Generate", _on_generate)
	_add_button(toolbar, "Randomize", _on_randomize)
	_add_button(toolbar, "Reset", _on_reset_generator)
	_add_button(toolbar, "Play", _on_play)
	_add_button(toolbar, "Stop", _on_stop)
	_add_button(toolbar, "Save WAV", _on_save_wav)
	toolbar.add_child(VSeparator.new())
	_add_button(toolbar, "Slight Mutate", _on_slight_mutate)
	_add_button(toolbar, "Mutate", _on_mutate)
	_add_button(toolbar, "Heavy Mutate", _on_heavy_mutate)
	toolbar.add_child(_label("Mutation Amount"))
	_mutation_slider = HSlider.new()
	_mutation_slider.min_value = 0.01
	_mutation_slider.max_value = 1.0
	_mutation_slider.step = 0.01
	_mutation_slider.value = 0.28
	_mutation_slider.custom_minimum_size.x = 120
	toolbar.add_child(_mutation_slider)

	var layer_panel: PanelContainer = PanelContainer.new()
	_builtin_layer_panel = layer_panel
	left.add_child(layer_panel)
	var layer_box: VBoxContainer = VBoxContainer.new()
	layer_panel.add_child(layer_box)
	layer_box.add_child(_section_label("LAYERS"))
	var layer_row: HFlowContainer = _flow_row()
	layer_box.add_child(layer_row)
	_layer_option = OptionButton.new()
	_layer_option.custom_minimum_size.x = 165
	_layer_option.item_selected.connect(_on_layer_selected)
	layer_row.add_child(_layer_option)
	_add_button(layer_row, "Add Layer", _on_add_layer)
	_add_button(layer_row, "Remove Layer", _on_remove_layer)
	_add_button(layer_row, "Rebuild Layers", _on_rebuild_layers)
	_add_button(layer_row, "Apply Workspace", _on_apply_workspace_from_tab)

	var filter_row: HFlowContainer = _flow_row()
	layer_box.add_child(filter_row)
	filter_row.add_child(_label("Waveform"))
	_wave_option = OptionButton.new()
	_wave_option.custom_minimum_size.x = 125
	_wave_option.item_selected.connect(_on_wave_selected)
	filter_row.add_child(_wave_option)
	filter_row.add_child(_label("Filter"))
	_filter_mode_option = OptionButton.new()
	for name: String in ["Lowpass", "Highpass", "Bandpass", "Low+High", "None"]:
		_filter_mode_option.add_item(name)
	_filter_mode_option.item_selected.connect(_on_filter_mode_selected)
	filter_row.add_child(_filter_mode_option)
	filter_row.add_child(_label("Noise"))
	_noise_mode_option = OptionButton.new()
	for name: String in ["white", "pink", "brown", "blue", "violet", "digital", "periodic", "metallic", "impulse", "crackle"]:
		_noise_mode_option.add_item(name)
	_noise_mode_option.item_selected.connect(_on_noise_mode_selected)
	filter_row.add_child(_noise_mode_option)

	var param_panel: PanelContainer = PanelContainer.new()
	_builtin_param_panel = param_panel
	left.add_child(param_panel)
	var param_box: VBoxContainer = VBoxContainer.new()
	param_panel.add_child(param_box)
	param_box.add_child(_section_label("SELECTED LAYER PARAMETERS"))
	var param_grid: GridContainer = GridContainer.new()
	param_grid.columns = 2
	param_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_box.add_child(param_grid)
	for info: Array in [
		["Duration", "duration", 0.02, 8.0, 0.01],
		["Start Hz", "start_hz", 20.0, 12000.0, 1.0],
		["End Hz", "end_hz", 20.0, 12000.0, 1.0],
		["Pitch Slide st/s", "pitch_slide", -96.0, 96.0, 0.1],
		["Pitch Accel st/s²", "pitch_accel", -192.0, 192.0, 0.1],
		["Attack", "attack", 0.0, 2.0, 0.001],
		["Decay", "decay", 0.0, 3.0, 0.001],
		["Sustain", "sustain", 0.0, 1.0, 0.01],
		["Release", "release", 0.001, 4.0, 0.001],
		["Duty", "duty", 0.05, 0.95, 0.01],
		["Duty Sweep /s", "duty_sweep", -4.0, 4.0, 0.01],
		["Vibrato Depth", "vibrato_depth", 0.0, 1.0, 0.005],
		["Vibrato Hz", "vibrato_hz", 0.0, 60.0, 0.1],
		["Noise Mix", "noise_mix", 0.0, 1.0, 0.01],
		["Noise Density", "noise_density", 0.0, 1.0, 0.01],
		["Drive", "drive", 0.1, 6.0, 0.05],
		["Lowpass Hz", "lowpass_hz", 50.0, 22000.0, 10.0],
		["Highpass Hz", "highpass_hz", 0.0, 12000.0, 10.0],
		["Bandpass Hz", "bandpass_hz", 0.0, 12000.0, 10.0],
		["Resonance", "resonance", 0.0, 1.0, 0.01],
		["FM Ratio", "fm_ratio", 0.1, 12.0, 0.01],
		["FM Index", "fm_index", 0.0, 12.0, 0.05],
		["Feedback", "feedback", 0.0, 1.0, 0.01],
		["Echo Mix", "echo_mix", 0.0, 0.7, 0.01],
		["Echo Delay", "echo_delay", 0.005, 2.0, 0.005],
		["Reverb Mix", "reverb_mix", 0.0, 0.6, 0.01],
		["Gain", "gain", 0.0, 2.0, 0.01],
		["Delay", "delay", 0.0, 2.0, 0.001],
		["Noise Freq", "noise_frequency", 10.0, 12000.0, 1.0],
		["Bitcrush Hz", "bitcrush_hz", 0.0, 48000.0, 10.0],
	]:
		param_grid.add_child(_label(info[0]))
		var spin: SpinBox = SpinBox.new()
		spin.min_value = info[2]
		spin.max_value = info[3]
		spin.step = info[4]
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.tooltip_text = "%s controls the selected synthesis layer. Values are rendered non-destructively until WAV export." % str(info[0])
		spin.value_changed.connect(_on_parameter_changed.bind(info[1]))
		param_grid.add_child(spin)
		_param_controls[info[1]] = spin

	_extension_panel = PanelContainer.new()
	_extension_panel.visible = false
	left.add_child(_extension_panel)
	var extension_box: VBoxContainer = VBoxContainer.new()
	extension_box.add_theme_constant_override("separation", 6)
	_extension_panel.add_child(extension_box)
	extension_box.add_child(_section_label("EXTENSION GENERATOR"))
	_extension_description = Label.new()
	_extension_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extension_box.add_child(_extension_description)
	var extension_preset_row: HFlowContainer = _flow_row()
	extension_box.add_child(extension_preset_row)
	extension_preset_row.add_child(_label("Preset"))
	_extension_preset_option = OptionButton.new()
	_extension_preset_option.custom_minimum_size.x = 150.0
	extension_preset_row.add_child(_extension_preset_option)
	_add_button(extension_preset_row, "Apply Preset", _on_extension_preset_apply)
	_add_button(extension_preset_row, "Generate 16 Variants", _on_extension_variants)
	var extension_user_row: HFlowContainer = _flow_row()
	extension_box.add_child(extension_user_row)
	extension_user_row.add_child(_label("User Preset"))
	_extension_user_preset_option = OptionButton.new()
	_extension_user_preset_option.custom_minimum_size.x = 135.0
	extension_user_row.add_child(_extension_user_preset_option)
	_extension_user_preset_name = LineEdit.new()
	_extension_user_preset_name.placeholder_text = "Preset name"
	_extension_user_preset_name.custom_minimum_size.x = 130.0
	extension_user_row.add_child(_extension_user_preset_name)
	_add_button(extension_user_row, "Save", _on_save_extension_user_preset)
	_add_button(extension_user_row, "Load", _on_load_extension_user_preset)
	_add_button(extension_user_row, "Delete", _on_delete_extension_user_preset)
	var extension_project_row: HFlowContainer = _flow_row()
	extension_box.add_child(extension_project_row)
	extension_project_row.add_child(_label("Project Preset"))
	_extension_project_preset_option = OptionButton.new()
	_extension_project_preset_option.custom_minimum_size.x = 135.0
	extension_project_row.add_child(_extension_project_preset_option)
	_extension_project_preset_name = LineEdit.new()
	_extension_project_preset_name.placeholder_text = "Preset name"
	_extension_project_preset_name.custom_minimum_size.x = 130.0
	extension_project_row.add_child(_extension_project_preset_name)
	_add_button(extension_project_row, "Save", _on_save_extension_project_preset)
	_add_button(extension_project_row, "Load", _on_load_extension_project_preset)
	_add_button(extension_project_row, "Delete", _on_delete_extension_project_preset)
	_extension_param_grid = GridContainer.new()
	_extension_param_grid.columns = 2
	_extension_param_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extension_box.add_child(_extension_param_grid)

	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_tab_container)
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_workspace_tab()
	_build_range_tab()
	_build_variant_tools_tab()
	_build_preset_breeding_tab()
	_build_advanced_fx_tab()
	_build_retro_tab()
	_build_history_export_tab()
	_build_graph_tab()

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_waveform = WaveformPreview.new() as GASWaveformPreview
	_waveform.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_waveform)
	var kept_title: Label = Label.new()
	kept_title.text = "KEPT"
	kept_title.add_theme_font_size_override("font_size", 14)
	right.add_child(kept_title)
	_kept_variants_container = _flow_row()
	_kept_variants_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_kept_variants_container)

	var favorite_title: Label = Label.new()
	favorite_title.text = "FAVORITES"
	favorite_title.add_theme_font_size_override("font_size", 14)
	right.add_child(favorite_title)
	_favorite_variants_container = _flow_row()
	_favorite_variants_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_favorite_variants_container)

	var variant_title: Label = Label.new()
	variant_title.text = "NEW VARIANTS"
	variant_title.add_theme_font_size_override("font_size", 14)
	right.add_child(variant_title)
	_variants_container = _flow_row()
	_variants_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_variants_container)
	_set_variant_button_count(_selected_variant_count())
	_refresh_saved_variant_buttons()

	_status = Label.new()
	_status.text = "Ready"
	_status.modulate = Color(0.7, 0.75, 0.82)
	right.add_child(_status)

	_player = AudioStreamPlayer.new()
	add_child(_player)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.wav;WAV Audio;audio/wav"])
	_save_dialog.file_selected.connect(_on_save_path_selected)
	add_child(_save_dialog)

	_update_profile_info()
	_refresh_waveform_choices()


func _build_workspace_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Workspaces"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("DEDICATED GENERATORS"))
	var noise_row: HFlowContainer = _flow_row()
	tab.add_child(noise_row)
	noise_row.add_child(_label("Noise"))
	for subtype: String in ["white", "pink", "brown", "blue", "violet", "digital", "periodic", "metallic", "impulse", "crackle"]:
		var b: Button = Button.new()
		b.text = subtype.capitalize()
		b.pressed.connect(_on_workspace_generate.bind("Noise", subtype))
		noise_row.add_child(b)
	var drum_row: HFlowContainer = _flow_row()
	tab.add_child(drum_row)
	drum_row.add_child(_label("Drums"))
	for subtype: String in ["Kick", "Snare", "Clap", "Hi-Hat", "Tom", "Cymbal", "Retro Percussion"]:
		var b2: Button = Button.new()
		b2.text = subtype
		b2.pressed.connect(_on_workspace_generate.bind("Drum", subtype))
		drum_row.add_child(b2)
	var voice_row: HFlowContainer = _flow_row()
	tab.add_child(voice_row)
	voice_row.add_child(_label("Voices"))
	for subtype: String in ["Sine", "Square", "Speech", "Robot", "Chirp", "Animal", "Growl", "Synthetic", "Retro", "Soft", "Harsh"]:
		var b3: Button = Button.new()
		b3.text = subtype
		b3.pressed.connect(_on_workspace_generate.bind("Voice", subtype))
		voice_row.add_child(b3)
	var foley_row: HFlowContainer = _flow_row()
	tab.add_child(foley_row)
	foley_row.add_child(_label("Foley"))
	for subtype: String in ["Footsteps", "Footsteps Wood", "Footsteps Metal", "Footsteps Stone", "Footsteps Gravel", "Cloth", "Metal", "Rain", "Fire", "Wind", "Water", "Machinery"]:
		var b4: Button = Button.new()
		b4.text = subtype
		b4.pressed.connect(_on_workspace_generate.bind("Foley", subtype))
		foley_row.add_child(b4)

	tab.add_child(_section_label("WAVETABLE EDITOR"))
	var wt_row: HFlowContainer = _flow_row()
	tab.add_child(wt_row)
	for tool_name: String in ["Pencil", "Line"]:
		var t: Button = Button.new()
		t.text = tool_name
		t.pressed.connect(_on_wavetable_tool.bind(tool_name))
		wt_row.add_child(t)
	for shape_name: String in ["Sine", "Triangle", "Saw", "Square", "Harmonics", "Randomize", "Normalize", "Smooth", "Invert"]:
		var sb: Button = Button.new()
		sb.text = shape_name
		sb.pressed.connect(_on_wavetable_action.bind(shape_name))
		wt_row.add_child(sb)
	_wavetable_editor = WavetableEditor.new() as GASWavetableEditor
	_wavetable_editor.values_changed.connect(_on_wavetable_changed)
	tab.add_child(_wavetable_editor)
	var wt_size_row: HFlowContainer = _flow_row()
	tab.add_child(wt_size_row)
	wt_size_row.add_child(_label("Sizes"))
	for size: int in [16, 32, 64, 128, 256]:
		var wb: Button = Button.new()
		wb.text = str(size)
		wb.pressed.connect(_on_wavetable_resize.bind(size))
		wt_size_row.add_child(wb)
	wt_size_row.add_child(_label("Custom"))
	_wavetable_custom_size = SpinBox.new()
	_wavetable_custom_size.min_value = 4
	_wavetable_custom_size.max_value = 2048
	_wavetable_custom_size.step = 1
	_wavetable_custom_size.value = 32
	wt_size_row.add_child(_wavetable_custom_size)
	_add_button(wt_size_row, "Apply Size", _on_wavetable_custom_resize)

	tab.add_child(_section_label("SAMPLE SYNTH"))
	var sample_row: HFlowContainer = _flow_row()
	tab.add_child(sample_row)
	_add_button(sample_row, "New Sample Synth", _on_sample_workspace)
	_add_button(sample_row, "Import WAV", _on_import_sample_wav)
	_sample_loop_toggle = CheckButton.new()
	_sample_loop_toggle.text = "Loop"
	_sample_loop_toggle.toggled.connect(_on_sample_bool_changed.bind("sample_loop"))
	sample_row.add_child(_sample_loop_toggle)
	_sample_reverse_toggle = CheckButton.new()
	_sample_reverse_toggle.text = "Reverse"
	_sample_reverse_toggle.toggled.connect(_on_sample_bool_changed.bind("sample_reverse"))
	sample_row.add_child(_sample_reverse_toggle)
	for spec: Array in [["Rate", "sample_playback_rate", 0.05, 8.0, 0.01], ["Rate Reduce Hz", "sample_rate_reduce_hz", 0.0, 48000.0, 10.0], ["Loop Start", "sample_loop_start", 0.0, 0.999, 0.001], ["Loop End", "sample_loop_end", 0.001, 1.0, 0.001]]:
		sample_row.add_child(_label(str(spec[0])))
		var sample_spin: SpinBox = SpinBox.new()
		sample_spin.min_value = float(spec[2])
		sample_spin.max_value = float(spec[3])
		sample_spin.step = float(spec[4])
		sample_spin.value_changed.connect(_on_sample_value_changed.bind(str(spec[1])))
		sample_row.add_child(sample_spin)
		match str(spec[1]):
			"sample_playback_rate": _sample_playback_spin = sample_spin
			"sample_rate_reduce_hz": _sample_rate_reduce_spin = sample_spin
			"sample_loop_start": _sample_loop_start_spin = sample_spin
			"sample_loop_end": _sample_loop_end_spin = sample_spin

	tab.add_child(_section_label("VOICE SET"))
	var voice_settings: HFlowContainer = _flow_row()
	tab.add_child(voice_settings)
	for voice_spec: Array in [["Pitch Min", "min", 40.0, 2000.0, 1.0], ["Pitch Max", "max", 40.0, 4000.0, 1.0], ["Random Pitch", "random", 0.0, 1.0, 0.01], ["Character Seed", "seed", 1.0, 2147483646.0, 1.0]]:
		voice_settings.add_child(_label(str(voice_spec[0])))
		var voice_spin: SpinBox = SpinBox.new()
		voice_spin.min_value = float(voice_spec[2])
		voice_spin.max_value = float(voice_spec[3])
		voice_spin.step = float(voice_spec[4])
		voice_settings.add_child(voice_spin)
		match str(voice_spec[1]):
			"min": _voice_pitch_min_spin = voice_spin
			"max": _voice_pitch_max_spin = voice_spin
			"random": _voice_random_pitch_spin = voice_spin
			"seed": _character_seed_spin = voice_spin
	_voice_pitch_min_spin.value = 160.0
	_voice_pitch_max_spin.value = 520.0
	_voice_random_pitch_spin.value = 0.18
	_character_seed_spin.value = 418731.0
	_add_button(voice_settings, "Generate Voice Set", _on_generate_voice_set)
	_add_button(voice_settings, "Export Voice Set", _on_export_voice_set)

	tab.add_child(_section_label("FM OPERATORS"))
	var fm_grid: GridContainer = GridContainer.new()
	fm_grid.columns = 2
	fm_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_child(fm_grid)
	for i: int in range(4):
		var op_panel: PanelContainer = PanelContainer.new()
		fm_grid.add_child(op_panel)
		var op_box: VBoxContainer = VBoxContainer.new()
		op_panel.add_child(op_box)
		op_box.add_child(_section_label("OPERATOR %d" % (i + 1)))
		var controls: Dictionary = {}
		for spec: Array in [["Ratio", "ratio", 0.1, 12.0, 0.01], ["Detune cents", "detune", -100.0, 100.0, 0.1], ["Level", "level", 0.0, 1.5, 0.01], ["Attack", "attack", 0.0, 2.0, 0.001], ["Decay", "decay", 0.0, 3.0, 0.001], ["Sustain", "sustain", 0.0, 1.0, 0.01], ["Release", "release", 0.001, 4.0, 0.001], ["Velocity", "velocity", 0.0, 1.0, 0.01]]:
			var row: HFlowContainer = _flow_row()
			op_box.add_child(row)
			row.add_child(_label(str(spec[0])))
			var spin: SpinBox = SpinBox.new()
			spin.min_value = float(spec[2])
			spin.max_value = float(spec[3])
			spin.step = float(spec[4])
			spin.custom_minimum_size.x = 110
			spin.value_changed.connect(_on_fm_changed.bind(i, str(spec[1])))
			row.add_child(spin)
			controls[str(spec[1])] = spin
		_fm_controls.append(controls)
	_fm_routing_label = Label.new()
	_fm_routing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(_fm_routing_label)


func _build_range_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Ranges/Locks"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("GENERATION RANGES AND LOCKS"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size.y = 260
	tab.add_child(scroll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for key: String in PresetBank.MUTABLE_KEYS:
		grid.add_child(_label(key))
		var min_spin: SpinBox = SpinBox.new()
		var spec: Dictionary = PresetBank.PARAM_SPECS.get(key, {"min": 0.0, "max": 1.0})
		min_spin.min_value = float(spec["min"])
		min_spin.max_value = float(spec["max"])
		min_spin.step = 0.01
		min_spin.value_changed.connect(_on_range_changed.bind(key, "min"))
		grid.add_child(min_spin)
		var max_spin: SpinBox = SpinBox.new()
		max_spin.min_value = float(spec["min"])
		max_spin.max_value = float(spec["max"])
		max_spin.step = 0.01
		max_spin.value_changed.connect(_on_range_changed.bind(key, "max"))
		grid.add_child(max_spin)
		var lock: CheckButton = CheckButton.new()
		lock.text = "Lock"
		lock.toggled.connect(_on_lock_toggled.bind(key))
		grid.add_child(lock)
		_range_controls[key] = {"min": min_spin, "max": max_spin}
		_lock_controls[key] = lock


func _build_variant_tools_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Variants"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("VARIATION TOOLS"))
	var row: HFlowContainer = _flow_row()
	tab.add_child(row)
	row.add_child(_label("Visible Variants"))
	_variant_count_option = OptionButton.new()
	_variant_count_option.tooltip_text = "Number of candidate variants shown under the waveform."
	for count: int in [8, 16, 24, 32]:
		_variant_count_option.add_item(str(count), count)
	_variant_count_option.select(1)
	_variant_count_option.item_selected.connect(_on_variant_count_selected)
	row.add_child(_variant_count_option)
	_add_button(row, "Generate Variants", _on_generate_variants)
	row.add_child(_label("Large Batch"))
	_batch_spin = SpinBox.new()
	_batch_spin.min_value = 8
	_batch_spin.max_value = 64
	_batch_spin.step = 1
	_batch_spin.value = 32
	_batch_spin.tooltip_text = "Generate a larger batch. The visible area still shows the selected visible-variant count."
	row.add_child(_batch_spin)
	_add_button(row, "Batch Generate", _on_batch_generate)
	var row2: HFlowContainer = _flow_row()
	tab.add_child(row2)
	_add_button(row2, "Keep Selected Variant", _on_keep_variant)
	_add_button(row2, "Favorite Selected Variant", _on_favorite_variant)
	_add_button(row2, "Remove Selected Saved", _on_remove_selected_saved_variant)
	_add_button(row2, "Mutate Selected Variant", _on_mutate_selected_variant)
	_add_button(row2, "Export Selected Variant", _on_export_selected_variant)


func _build_preset_breeding_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Presets/Breeding"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("PRESETS"))
	var user_row: HFlowContainer = _flow_row()
	tab.add_child(user_row)
	_user_preset_name = LineEdit.new()
	_user_preset_name.placeholder_text = "User preset name"
	user_row.add_child(_user_preset_name)
	_add_button(user_row, "Save User", _on_save_user_preset)
	_user_preset_option = OptionButton.new()
	_user_preset_option.custom_minimum_size.x = 140
	user_row.add_child(_user_preset_option)
	_add_button(user_row, "Load User", _on_load_user_preset)
	_add_button(user_row, "Delete User", _on_delete_user_preset)
	var project_row: HFlowContainer = _flow_row()
	tab.add_child(project_row)
	_project_preset_name = LineEdit.new()
	_project_preset_name.placeholder_text = "Project preset name"
	project_row.add_child(_project_preset_name)
	_add_button(project_row, "Save Project", _on_save_project_preset)
	_project_preset_option = OptionButton.new()
	_project_preset_option.custom_minimum_size.x = 140
	project_row.add_child(_project_preset_option)
	_add_button(project_row, "Load Project", _on_load_project_preset)
	_add_button(project_row, "Delete Project", _on_delete_project_preset)

	tab.add_child(_section_label("BREEDING"))
	var breed_row: HFlowContainer = _flow_row()
	tab.add_child(breed_row)
	_add_button(breed_row, "Set Parent A = Current", _on_set_parent_a)
	_add_button(breed_row, "Set Parent B = Current", _on_set_parent_b)
	breed_row.add_child(_label("Bias"))
	_breed_bias_slider = HSlider.new()
	_breed_bias_slider.min_value = 0.0
	_breed_bias_slider.max_value = 1.0
	_breed_bias_slider.step = 0.01
	_breed_bias_slider.value = 0.5
	_breed_bias_slider.custom_minimum_size.x = 120
	breed_row.add_child(_breed_bias_slider)
	_add_button(breed_row, "Breed Child", _on_breed_child)
	_add_button(breed_row, "Random Child", _on_breed_random)
	_add_button(breed_row, "Mostly A", _on_breed_mostly_a)
	_add_button(breed_row, "Balanced", _on_breed_balanced)
	_add_button(breed_row, "Mostly B", _on_breed_mostly_b)


func _build_advanced_fx_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Advanced FX"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("MODULATION / DISTORTION / SPACE"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size.y = 330
	tab.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var mode_row: HFlowContainer = _flow_row()
	box.add_child(mode_row)
	mode_row.add_child(_label("Distortion"))
	_distortion_option = OptionButton.new()
	for mode_name: String in ["Soft Clip", "Hard Clip", "Saturation", "Digital", "Rectifier", "Foldback"]:
		_distortion_option.add_item(mode_name)
	_distortion_option.tooltip_text = "Select the waveshaping model used by the generator distortion stage."
	_distortion_option.item_selected.connect(_on_distortion_mode_changed)
	mode_row.add_child(_distortion_option)
	mode_row.add_child(_label("Delay"))
	_delay_mode_option = OptionButton.new()
	for delay_name: String in ["Mono", "Ping-Pong"]:
		_delay_mode_option.add_item(delay_name)
	_delay_mode_option.tooltip_text = "Ping-Pong produces a stereo alternating echo."
	_delay_mode_option.item_selected.connect(_on_delay_mode_changed)
	mode_row.add_child(_delay_mode_option)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for info: Array in [
		["Tremolo Depth", "tremolo_depth", 0.0, 1.0, 0.01],
		["Tremolo Hz", "tremolo_hz", 0.1, 60.0, 0.1],
		["AM Depth", "am_depth", 0.0, 1.0, 0.01],
		["AM Hz", "am_hz", 0.1, 2000.0, 0.1],
		["Ring Mod Depth", "ring_mod_depth", 0.0, 1.0, 0.01],
		["Ring Mod Hz", "ring_mod_hz", 1.0, 12000.0, 1.0],
		["FM/Pitch Mod Depth", "fm_mod_depth", 0.0, 1.0, 0.01],
		["FM/Pitch Mod Hz", "fm_mod_hz", 0.1, 2000.0, 0.1],
		["Hardware Pitch Mod Depth", "pitch_mod_depth", 0.0, 1.0, 0.01],
		["Sync Hz", "sync_hz", 1.0, 12000.0, 1.0],
		["Distortion Mix", "distortion_mix", 0.0, 1.0, 0.01],
		["Crush Bits", "crush_bits", 1.0, 16.0, 1.0],
		["Delay Feedback", "delay_feedback", 0.0, 0.9, 0.01],
		["Delay Taps", "delay_taps", 1.0, 12.0, 1.0],
		["Reverb Size", "reverb_size", 0.0, 1.0, 0.01],
		["Reverb Damping", "reverb_damping", 0.0, 1.0, 0.01],
		["Chorus Mix", "chorus_mix", 0.0, 1.0, 0.01],
		["Chorus Rate", "chorus_rate", 0.05, 10.0, 0.05],
		["Chorus Depth ms", "chorus_depth_ms", 0.0, 30.0, 0.1],
		["Flanger Mix", "flanger_mix", 0.0, 1.0, 0.01],
		["Flanger Rate", "flanger_rate", 0.05, 10.0, 0.05],
		["Flanger Depth ms", "flanger_depth_ms", 0.0, 10.0, 0.1],
		["Phaser Mix", "phaser_mix", 0.0, 1.0, 0.01],
		["Phaser Rate", "phaser_rate", 0.05, 10.0, 0.05],
		["Phaser Depth", "phaser_depth", 0.0, 1.0, 0.01],
		["BRR Character", "brr_amount", 0.0, 1.0, 0.01],
		["Pan", "pan", -1.0, 1.0, 0.01],
	]:
		grid.add_child(_label(info[0]))
		var spin: SpinBox = SpinBox.new()
		spin.min_value = float(info[2])
		spin.max_value = float(info[3])
		spin.step = float(info[4])
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.tooltip_text = "Generator parameter: %s" % str(info[0])
		spin.value_changed.connect(_on_advanced_parameter_changed.bind(str(info[1])))
		grid.add_child(spin)
		_advanced_controls[str(info[1])] = spin


func _build_retro_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Retro Hardware"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("RETRO HARDWARE CONTROLS"))
	var row: HFlowContainer = _flow_row()
	tab.add_child(row)
	_add_button(row, "Validate Hardware", _on_validate_hardware)
	_add_button(row, "Rebuild Hardware Voices", _on_rebuild_hardware_voices)
	_add_button(row, "Import Sample WAV", _on_import_sample_wav)
	_add_button(row, "Run Generator QA", _on_run_qa)

	var fm_row: HFlowContainer = _flow_row()
	tab.add_child(fm_row)
	fm_row.add_child(_label("FM Algorithm"))
	_fm_algorithm_option = OptionButton.new()
	for i: int in range(8):
		_fm_algorithm_option.add_item("Algorithm %d" % (i + 1))
	_fm_algorithm_option.item_selected.connect(_on_fm_algorithm_changed)
	fm_row.add_child(_fm_algorithm_option)
	fm_row.add_child(_label("OPL Mode"))
	_opl_mode_option = OptionButton.new()
	_opl_mode_option.add_item("2 Operator", 2)
	_opl_mode_option.add_item("4 Operator", 4)
	_opl_mode_option.item_selected.connect(_on_opl_mode_changed)
	fm_row.add_child(_opl_mode_option)
	fm_row.add_child(_label("OPL Waveform"))
	_opl_waveform_option = OptionButton.new()
	for waveform_name: String in ["Sine", "Half Sine", "Absolute Sine", "Quarter/Clipped"]:
		_opl_waveform_option.add_item(waveform_name)
	_opl_waveform_option.item_selected.connect(_on_opl_waveform_changed)
	fm_row.add_child(_opl_waveform_option)
	fm_row.add_child(_label("Osc Sync"))
	_osc_sync_toggle = CheckButton.new()
	_osc_sync_toggle.tooltip_text = "Hard-sync the selected oscillator. SID-style sounds commonly use this with ring modulation."
	_osc_sync_toggle.toggled.connect(_on_osc_sync_toggled)
	fm_row.add_child(_osc_sync_toggle)
	fm_row.add_child(_label("AY Env"))
	_ay_envelope_option = OptionButton.new()
	for env_name: String in ["Decay", "Attack", "Triangle", "Pulse"]:
		_ay_envelope_option.add_item(env_name)
	_ay_envelope_option.item_selected.connect(_on_ay_envelope_changed)
	fm_row.add_child(_ay_envelope_option)

	var seq_row: HFlowContainer = _flow_row()
	tab.add_child(seq_row)
	seq_row.add_child(_label("PC Speaker / Arp Ratios"))
	_note_sequence_edit = LineEdit.new()
	_note_sequence_edit.placeholder_text = "1.0,1.25,1.5,2.0"
	_note_sequence_edit.tooltip_text = "Comma-separated frequency ratios for PC Speaker or chiptune arpeggio sequencing."
	_note_sequence_edit.text_submitted.connect(_on_note_sequence_submitted)
	seq_row.add_child(_note_sequence_edit)
	_add_button(seq_row, "Apply Sequence", _on_apply_note_sequence)

	var fantasy_row: HFlowContainer = _flow_row()
	tab.add_child(fantasy_row)
	fantasy_row.add_child(_label("Fantasy Bits"))
	_fantasy_bits_spin = SpinBox.new()
	_fantasy_bits_spin.min_value = 1
	_fantasy_bits_spin.max_value = 16
	_fantasy_bits_spin.step = 1
	_fantasy_bits_spin.value = 6
	_fantasy_bits_spin.value_changed.connect(_on_fantasy_setting_changed.bind("fantasy_bits"))
	fantasy_row.add_child(_fantasy_bits_spin)
	fantasy_row.add_child(_label("Sample Rate"))
	_fantasy_rate_spin = SpinBox.new()
	_fantasy_rate_spin.min_value = 4000
	_fantasy_rate_spin.max_value = 48000
	_fantasy_rate_spin.step = 100
	_fantasy_rate_spin.value = 22050
	_fantasy_rate_spin.value_changed.connect(_on_fantasy_setting_changed.bind("fantasy_sample_rate"))
	fantasy_row.add_child(_fantasy_rate_spin)
	fantasy_row.add_child(_label("Channels"))
	_fantasy_channels_spin = SpinBox.new()
	_fantasy_channels_spin.min_value = 1
	_fantasy_channels_spin.max_value = 8
	_fantasy_channels_spin.step = 1
	_fantasy_channels_spin.value = 4
	_fantasy_channels_spin.value_changed.connect(_on_fantasy_setting_changed.bind("fantasy_channels"))
	fantasy_row.add_child(_fantasy_channels_spin)

	_sample_dialog = FileDialog.new()
	_sample_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_sample_dialog.access = FileDialog.ACCESS_RESOURCES
	_sample_dialog.filters = PackedStringArray(["*.wav;WAV Audio;audio/wav"])
	_sample_dialog.file_selected.connect(_on_sample_selected)
	add_child(_sample_dialog)


func _build_history_export_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "History/Export"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("RESULT HISTORY / A-B / EXPORT"))
	var history_row: HFlowContainer = _flow_row()
	tab.add_child(history_row)
	_history_option = OptionButton.new()
	_history_option.custom_minimum_size.x = 180
	history_row.add_child(_history_option)
	_add_button(history_row, "Recall", _on_recall_history)
	_add_button(history_row, "A = Current", _on_set_compare_a)
	_add_button(history_row, "B = Current", _on_set_compare_b)
	_add_button(history_row, "Play A", _on_play_compare_a)
	_add_button(history_row, "Play B", _on_play_compare_b)
	_add_button(history_row, "Loudness-Matched B", _on_play_loudness_matched_b)

	var undo_row: HFlowContainer = _flow_row()
	tab.add_child(undo_row)
	_add_button(undo_row, "Undo", _on_undo)
	_add_button(undo_row, "Redo", _on_redo)
	_add_button(undo_row, "Send to Audio Editor", _on_send_to_timeline)
	_add_button(undo_row, "Clear Timeline Queue", _on_clear_timeline_queue)
	var queue_label: Label = Label.new()
	queue_label.name = "TimelineQueueStatus"
	queue_label.text = "Timeline queue: 0"
	undo_row.add_child(queue_label)

	var export_row: HFlowContainer = _flow_row()
	tab.add_child(export_row)
	export_row.add_child(_label("Naming Template"))
	_naming_template_edit = LineEdit.new()
	_naming_template_edit.text = "{profile}_{category}_{index}_{seed}"
	_naming_template_edit.tooltip_text = "Tokens: {profile}, {category}, {index}, {seed}."
	_naming_template_edit.custom_minimum_size.x = 190
	export_row.add_child(_naming_template_edit)
	_add_button(export_row, "Quick Save res://audio/generated", _on_quick_save)
	_add_button(export_row, "Batch Export Variants", _on_batch_export_variants)
	_add_button(export_row, "Background Batch", _on_background_batch)

	var seed_row: HFlowContainer = _flow_row()
	tab.add_child(seed_row)
	seed_row.add_child(_label("Seed history/favorites are kept for this editor session."))
	_add_button(seed_row, "Use Previous Seed", _on_previous_seed)
	_add_button(seed_row, "Use Favorite Seed", _on_use_favorite_seed)

	_batch_export_dialog = FileDialog.new()
	_batch_export_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_batch_export_dialog.access = FileDialog.ACCESS_RESOURCES
	_batch_export_dialog.dir_selected.connect(_on_batch_export_dir_selected)
	add_child(_batch_export_dialog)


func _build_graph_tab() -> void:
	var tab: VBoxContainer = VBoxContainer.new()
	tab.name = "Sound Graph"
	_tab_container.add_child(tab)
	tab.add_child(_section_label("PROCEDURAL SOUND GRAPH"))
	var toolbar: HFlowContainer = _flow_row()
	tab.add_child(toolbar)
	_graph_type_option = OptionButton.new()
	for node_type: String in SoundGraph.NODE_TYPES:
		_graph_type_option.add_item(node_type)
	toolbar.add_child(_graph_type_option)
	_add_button(toolbar, "Add Node", _on_graph_add_node)
	_graph_node_option = OptionButton.new()
	_graph_node_option.custom_minimum_size.x = 140
	toolbar.add_child(_graph_node_option)
	_add_button(toolbar, "Remove Node", _on_graph_remove_node)
	_add_button(toolbar, "Compile + Generate", _on_graph_compile)
	_add_button(toolbar, "Reset Graph", _on_graph_reset)
	var params_row: HFlowContainer = _flow_row()
	tab.add_child(params_row)
	params_row.add_child(_label("Selected Node Params (JSON)"))
	_graph_params_edit = LineEdit.new()
	_graph_params_edit.custom_minimum_size.x = 220
	_graph_params_edit.tooltip_text = "Edit the selected graph node parameter dictionary as JSON, then Apply Params."
	params_row.add_child(_graph_params_edit)
	_add_button(params_row, "Apply Params", _on_graph_apply_params)
	_graph_node_option.item_selected.connect(_on_graph_node_selected)
	_graph_tree = Tree.new()
	_graph_tree.custom_minimum_size.y = 260
	_graph_tree.columns = 3
	_graph_tree.set_column_title(0, "ID")
	_graph_tree.set_column_title(1, "Type")
	_graph_tree.set_column_title(2, "Parameters")
	_graph_tree.column_titles_visible = true
	tab.add_child(_graph_tree)
	_graph = SoundGraph.new_graph()
	_refresh_graph_ui()


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		var source: Array = value as Array
		for item_value: Variant in source:
			if item_value is Dictionary:
				output.append(item_value as Dictionary)
	return output


func _float_array(value: Variant) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value as PackedFloat32Array
	if value is Array:
		return PackedFloat32Array(value as Array)
	return PackedFloat32Array()


func _flow_row() -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.alignment = FlowContainer.ALIGNMENT_BEGIN
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	return flow


func _label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	return l


func _section_label(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l


func _add_button(parent: Container, text: String, callback: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)


func _selected_profile() -> String:
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		return extension.get_display_name() if extension != null else "Extension"
	return _profile_option.get_item_text(_profile_option.selected)


func _selected_category() -> String:
	return _category_option.get_item_text(_category_option.selected) if _category_option != null and _category_option.selected >= 0 else "Custom"


func _active_extension_generator_id() -> StringName:
	if _generator_source_option == null or _generator_source_option.selected <= 0:
		return &""
	var metadata: Variant = _generator_source_option.get_item_metadata(_generator_source_option.selected)
	return StringName(str(metadata)) if metadata != null else &""


func _is_extension_generator_active() -> bool:
	return not str(_active_extension_generator_id()).is_empty()


func _active_extension_generator() -> GASGeneratorExtension:
	var generator_id: StringName = _active_extension_generator_id()
	return ExtensionAPI.create_generator_extension(generator_id) if not str(generator_id).is_empty() else null


func refresh_extensions() -> void:
	_refresh_generator_source_options()


func _refresh_generator_source_options() -> void:
	if _generator_source_option == null:
		return
	var previous_id: StringName = _active_extension_generator_id()
	if str(previous_id).is_empty():
		previous_id = StringName(str(_current_params.get("generator_extension_id", "")))
	_generator_source_option.clear()
	_generator_source_option.add_item("Built In")
	_generator_source_option.set_item_metadata(0, "")
	var selected_index: int = 0
	for id_text: String in ExtensionAPI.generator_extension_ids():
		var generator_id: StringName = StringName(id_text)
		var extension: GASGeneratorExtension = ExtensionAPI.create_generator_extension(generator_id)
		if extension == null:
			continue
		var index: int = _generator_source_option.get_item_count()
		_generator_source_option.add_item(extension.get_display_name())
		_generator_source_option.set_item_metadata(index, id_text)
		_generator_source_option.set_item_tooltip(index, extension.get_description())
		if generator_id == previous_id:
			selected_index = index
	if selected_index == 0 and not str(previous_id).is_empty():
		selected_index = _append_missing_generator_source(previous_id)
	_generator_source_option.select(selected_index)
	_apply_generator_source_mode(false)


func _select_generator_source_id(generator_id: StringName) -> void:
	if _generator_source_option == null:
		return
	for index: int in range(_generator_source_option.get_item_count()):
		var metadata: Variant = _generator_source_option.get_item_metadata(index)
		if StringName(str(metadata)) == generator_id:
			_generator_source_option.select(index)
			return
	if not str(generator_id).is_empty():
		_generator_source_option.select(_append_missing_generator_source(generator_id))
		return
	_generator_source_option.select(0)


func _append_missing_generator_source(generator_id: StringName) -> int:
	if _generator_source_option == null:
		return 0
	for index: int in range(_generator_source_option.get_item_count()):
		if StringName(str(_generator_source_option.get_item_metadata(index))) == generator_id:
			return index
	var index: int = _generator_source_option.get_item_count()
	_generator_source_option.add_item("Missing • %s" % str(generator_id))
	_generator_source_option.set_item_metadata(index, str(generator_id))
	_generator_source_option.set_item_tooltip(index, "This generator extension is missing or disabled. Saved parameters are preserved.")
	_generator_source_option.set_item_disabled(index, true)
	return index


func _on_generator_source_changed(_index: int) -> void:
	_push_undo()
	_apply_generator_source_mode(true)


func _apply_generator_source_mode(render_after: bool) -> void:
	var requested_extension_id: StringName = _active_extension_generator_id()
	var extension: GASGeneratorExtension = _active_extension_generator()
	var extension_active: bool = extension != null
	var extension_missing: bool = not str(requested_extension_id).is_empty() and extension == null
	var external_source_selected: bool = extension_active or extension_missing
	if _profile_option != null:
		_profile_option.disabled = external_source_selected
	if _accuracy_option != null:
		_accuracy_option.disabled = external_source_selected
	if _hardware_toggle != null:
		_hardware_toggle.disabled = external_source_selected
	if _category_option != null:
		_category_option.disabled = extension_missing
	if _builtin_layer_panel != null:
		_builtin_layer_panel.visible = not external_source_selected
	if _builtin_param_panel != null:
		_builtin_param_panel.visible = not external_source_selected
	if _tab_container != null:
		_tab_container.visible = not external_source_selected
	if _extension_panel != null:
		_extension_panel.visible = external_source_selected
	if extension_missing:
		if _extension_description != null:
			_extension_description.text = "Generator extension '%s' is missing or disabled. Saved parameters are preserved." % str(requested_extension_id)
		if _extension_param_grid != null:
			for child: Node in _extension_param_grid.get_children():
				child.queue_free()
		_extension_param_controls.clear()
		if _extension_preset_option != null:
			_extension_preset_option.clear()
		if _category_option != null:
			var saved_category: String = str(_current_params.get("category", "Unavailable"))
			_category_option.clear()
			_category_option.add_item(saved_category)
			_category_option.select(0)
		_refresh_extension_saved_preset_lists()
		return
	if extension_active:
		var extension_id_text: String = str(extension.get_generator_id())
		var previous_category: String = str(_current_params.get("category", _selected_category()))
		var keep_current: bool = str(_current_params.get("generator_extension_id", "")) == extension_id_text
		_category_option.clear()
		var categories: PackedStringArray = extension.get_categories()
		if categories.is_empty():
			categories = PackedStringArray(["Custom"])
		var selected_category_index: int = 0
		for category_index: int in range(categories.size()):
			var category: String = categories[category_index]
			_category_option.add_item(category)
			if keep_current and category == previous_category:
				selected_category_index = category_index
		_category_option.select(selected_category_index)
		if not keep_current:
			_current_params = _extension_default_params(extension, _selected_category(), int(_seed_spin.value))
		else:
			_current_params["generator_extension_id"] = extension_id_text
			_current_params["profile"] = extension.get_display_name()
			_current_params["category"] = _selected_category()
		_rebuild_extension_parameter_ui()
		_update_profile_info()
		if render_after:
			_render_params(true)
	else:
		var previous_builtin_category: String = str(_current_params.get("category", _selected_category()))
		var was_extension_params: bool = not str(_current_params.get("generator_extension_id", "")).is_empty()
		_category_option.clear()
		var builtin_category_index: int = 0
		for category_index: int in range(PresetBank.CATEGORY_ORDER.size()):
			var category: String = PresetBank.CATEGORY_ORDER[category_index]
			_category_option.add_item(category)
			if not was_extension_params and category == previous_builtin_category:
				builtin_category_index = category_index
		if _category_option.get_item_count() > 0:
			_category_option.select(builtin_category_index)
		if render_after:
			_generate_current(false)


func _extension_default_params(extension: GASGeneratorExtension, category: String, seed: int) -> Dictionary:
	var params: Dictionary = extension.get_default_params(category, seed)
	params["generator_extension_id"] = str(extension.get_generator_id())
	params["profile"] = extension.get_display_name()
	params["category"] = category
	params["seed"] = seed
	return params


func _rebuild_extension_parameter_ui() -> void:
	if _extension_param_grid == null:
		return
	for child: Node in _extension_param_grid.get_children():
		child.queue_free()
	_extension_param_controls.clear()
	var extension: GASGeneratorExtension = _active_extension_generator()
	if extension == null:
		return
	if _extension_description != null:
		_extension_description.text = extension.get_description()
	if _extension_preset_option != null:
		_extension_preset_option.clear()
		for preset: String in extension.get_presets(_selected_category()):
			_extension_preset_option.add_item(preset)
	_refresh_extension_saved_preset_lists()
	var specs: Array[Dictionary] = extension.get_parameter_specs(_selected_category())
	for spec: Dictionary in specs:
		var key: String = str(spec.get("key", ""))
		if key.is_empty():
			continue
		_extension_param_grid.add_child(_label(str(spec.get("label", key))))
		var type_name: String = str(spec.get("type", "float"))
		if type_name == "bool":
			var check: CheckButton = CheckButton.new()
			check.set_pressed_no_signal(bool(_current_params.get(key, false)))
			check.toggled.connect(_on_extension_bool_changed.bind(key))
			_extension_param_grid.add_child(check)
			_extension_param_controls[key] = check
		elif type_name == "enum":
			var option: OptionButton = OptionButton.new()
			var options: PackedStringArray = _extension_spec_options(spec)
			for option_text: String in options:
				option.add_item(option_text)
			var current_text: String = str(_current_params.get(key, options[0] if not options.is_empty() else ""))
			for option_index: int in range(option.get_item_count()):
				if option.get_item_text(option_index) == current_text:
					option.select(option_index)
					break
			option.item_selected.connect(_on_extension_enum_changed.bind(key))
			_extension_param_grid.add_child(option)
			_extension_param_controls[key] = option
		else:
			var spin: SpinBox = SpinBox.new()
			spin.min_value = float(spec.get("min", 0.0))
			spin.max_value = float(spec.get("max", 1.0))
			spin.step = float(spec.get("step", 0.01))
			spin.allow_greater = false
			spin.allow_lesser = false
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.set_value_no_signal(float(_current_params.get(key, spin.min_value)))
			spin.value_changed.connect(_on_extension_number_changed.bind(key, type_name == "int"))
			_extension_param_grid.add_child(spin)
			_extension_param_controls[key] = spin


func _extension_spec_options(spec: Dictionary) -> PackedStringArray:
	var value: Variant = spec.get("options", PackedStringArray())
	if value is PackedStringArray:
		return value as PackedStringArray
	if value is Array:
		return PackedStringArray(value as Array)
	return PackedStringArray()


func _on_extension_number_changed(value: float, key: String, integer: bool) -> void:
	_current_params[key] = int(round(value)) if integer else value
	_status.text = "Extension parameter changed • press Generate to render."


func _on_extension_bool_changed(value: bool, key: String) -> void:
	_current_params[key] = value
	_status.text = "Extension parameter changed • press Generate to render."


func _on_extension_enum_changed(index: int, key: String) -> void:
	var control_value: Variant = _extension_param_controls.get(key, null)
	var option: OptionButton = control_value as OptionButton
	if option == null or index < 0 or index >= option.get_item_count():
		return
	_current_params[key] = option.get_item_text(index)
	_status.text = "Extension parameter changed • press Generate to render."


func _on_extension_preset_apply() -> void:
	var extension: GASGeneratorExtension = _active_extension_generator()
	if extension == null or _extension_preset_option == null or _extension_preset_option.selected < 0:
		return
	_push_undo()
	_current_params = extension.apply_preset(_selected_category(), int(_seed_spin.value), _extension_preset_option.get_item_text(_extension_preset_option.selected))
	_current_params["generator_extension_id"] = str(extension.get_generator_id())
	_current_params["profile"] = extension.get_display_name()
	_current_params["category"] = _selected_category()
	_current_params["seed"] = int(_seed_spin.value)
	_rebuild_extension_parameter_ui()
	_render_params(true)


func _on_extension_variants() -> void:
	_start_background_variant_batch(16, 7919)


func _current_layer() -> Dictionary:
	if not _current_params.has("layers"):
		return _current_params
	var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
	if layers.is_empty():
		layers.append(PresetBank._make_layer_from_params(_current_params, "Primary"))
		_current_params["layers"] = layers
	var index: int = clampi(_layer_option.selected, 0, layers.size() - 1)
	return layers[index]


func _generate_current(autoplay: bool) -> void:
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			if not _current_params.is_empty():
				_current_params["seed"] = int(_seed_spin.value)
			_status.text = "Generator extension '%s' is missing or disabled. Saved parameters were preserved." % str(_active_extension_generator_id())
			return
		_current_params = _extension_default_params(extension, _selected_category(), int(_seed_spin.value))
		_sync_ui_from_params()
		_render_params(autoplay)
		return
	var mode: String = HardwareRules.MODE_HARDWARE if _accuracy_option != null and _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
	_current_params = PresetBank.make_preset_with_mode(_selected_profile(), _selected_category(), int(_seed_spin.value), mode)
	_hardware_toggle.set_pressed_no_signal(mode == HardwareRules.MODE_HARDWARE)
	_sync_ui_from_params()
	_render_params(autoplay)


func _render_params(autoplay: bool) -> void:
	if _is_extension_generator_active():
		if _active_extension_generator() == null:
			_status.text = "Generator extension '%s' is missing or disabled. Nothing was rendered." % str(_active_extension_generator_id())
			return
		_start_extension_generation([_current_params.duplicate(true)], "single", autoplay, "Extension generation complete.")
		return
	_sync_root_from_primary_layer()
	var active_mode: String = str(_current_params.get("accuracy_mode", HardwareRules.MODE_STYLE))
	if active_mode == HardwareRules.MODE_HARDWARE and _selected_profile() != RetroProfiles.MODERN:
		_current_params = HardwareRules.apply_constraints(_current_params, _selected_profile(), active_mode)
		_refresh_layer_list()
		_refresh_layer_controls()
	var render_start_usec: int = Time.get_ticks_usec()
	_current_result = SynthEngine.render(_current_params)
	var render_ms: float = float(Time.get_ticks_usec() - render_start_usec) / 1000.0
	var rendered_stream: AudioStream = _current_result.get("stream") as AudioStream
	var rendered_samples: PackedFloat32Array = _float_array(_current_result.get("samples", PackedFloat32Array()))
	_player.stream = rendered_stream
	_waveform.set_samples(rendered_samples)
	var layer_count: int = 1
	var layers_value: Variant = _current_params.get("layers", [])
	if layers_value is Array:
		layer_count = maxi(1, (layers_value as Array).size())
	_status.text = "%s • %s • %d layer%s • %.1f ms • seed %d" % [
		_selected_profile(),
		str(_current_params.get("category", _selected_category())),
		layer_count,
		"" if layer_count == 1 else "s",
		render_ms,
		int(_current_params.get("seed", 0))
	]
	if not _suppress_undo:
		project_state_changed.emit()
	if autoplay:
		_record_result_history(render_ms)
		_player.play()


func _start_extension_generation(batch_params: Array[Dictionary], mode: String, autoplay: bool, completion_text: String) -> void:
	if _extension_group_id >= 0:
		_status.text = "An extension generator job is already running."
		return
	var generator_id: StringName = _active_extension_generator_id()
	if str(generator_id).is_empty() or batch_params.is_empty():
		return
	var job: GASExtensionGeneratorJob = ExtensionGeneratorJob.new() as GASExtensionGeneratorJob
	if job == null or not job.configure(generator_id, batch_params):
		_status.text = "Could not start extension generator."
		return
	_extension_job = job
	_extension_job_mode = mode
	_extension_job_autoplay = autoplay
	_extension_completion_text = completion_text
	_extension_group_id = WorkerThreadPool.add_group_task(_extension_job.render_index, batch_params.size(), -1, false, "GAS extension generator")
	_status.text = "Generating with extension in background…" if batch_params.size() == 1 else "Generating %d extension variants in background…" % batch_params.size()


func _process_extension_generation() -> void:
	if _extension_group_id < 0 or not WorkerThreadPool.is_group_task_completed(_extension_group_id):
		return
	WorkerThreadPool.wait_for_group_task_completion(_extension_group_id)
	_extension_group_id = -1
	var results: Array[Dictionary] = _extension_job.get_results() if _extension_job != null else []
	_extension_job = null
	if results.is_empty():
		_status.text = "Extension generator returned no audio."
		_extension_job_mode = ""
		return
	if _extension_job_mode == "variants":
		_variant_results.clear()
		for result: Dictionary in results:
			if not result.is_empty():
				_variant_results.append(result)
		_set_variant_button_count(mini(24, maxi(1, _variant_results.size())))
		_refresh_generated_variant_labels()
	else:
		var result: Dictionary = results[0]
		_current_result = result
		var params_value: Variant = result.get("params", {})
		if params_value is Dictionary:
			_current_params = (params_value as Dictionary).duplicate(true)
		var stream: AudioStream = result.get("stream") as AudioStream
		var samples: PackedFloat32Array = _float_array(result.get("samples", PackedFloat32Array()))
		_player.stream = stream
		_waveform.set_samples(samples)
		_sync_ui_from_params()
		if _extension_job_mode == "saved":
			_selected_variant_result = result
			_selected_variant_params = _current_params.duplicate(true)
			_apply_selected_variant(_extension_completion_text)
		elif _extension_job_autoplay:
			_player.play()
		if not _suppress_undo:
			project_state_changed.emit()
	_status.text = _extension_completion_text if not _extension_completion_text.is_empty() else "Extension generation complete."
	_extension_job_mode = ""
	_extension_job_autoplay = false
	_extension_completion_text = ""


func _sync_root_from_primary_layer() -> void:
	if not _current_params.has("layers"):
		return
	var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
	if layers.is_empty():
		return
	var primary: Dictionary = layers[0]
	for key: String in ["wave", "duration", "start_hz", "end_hz", "pitch_slide", "pitch_accel", "attack", "decay", "sustain", "release", "duty", "duty_sweep", "vibrato_depth", "vibrato_hz", "tremolo_depth", "tremolo_hz", "am_depth", "am_hz", "ring_mod_depth", "ring_mod_hz", "fm_mod_depth", "fm_mod_hz", "noise_mix", "noise_density", "drive", "distortion_mode", "distortion_mix", "lowpass_hz", "highpass_hz", "bandpass_hz", "resonance", "fm_ratio", "fm_index", "feedback", "fm_algorithm", "opl_mode", "opl_waveform", "echo_mix", "echo_delay", "delay_mode", "delay_feedback", "delay_taps", "reverb_mix", "reverb_size", "reverb_damping", "chorus_mix", "chorus_rate", "chorus_depth_ms", "flanger_mix", "flanger_rate", "flanger_depth_ms", "phaser_mix", "phaser_rate", "phaser_depth", "bitcrush_hz", "crush_bits", "brr_amount", "noise_mode", "filter_mode", "wavetable", "sample_data", "sample_source_rate", "sample_playback_rate", "sample_rate_reduce_hz", "sample_loop", "sample_reverse", "sample_loop_start", "sample_loop_end", "fm_ops", "note_sequence", "note_rate_hz", "osc_sync", "sync_hz", "pitch_mod_depth", "pan"]:
		if primary.has(key):
			_current_params[key] = primary[key]


func _sync_ui_from_params() -> void:
	_update_profile_info()
	if _is_extension_generator_active():
		_rebuild_extension_parameter_ui()
		return
	_refresh_waveform_choices()
	_refresh_layer_list()
	_refresh_layer_controls()
	_sync_range_ui()
	_sync_wavetable_ui()
	_sync_fm_ui()
	_sync_sample_ui()
	_sync_advanced_ui()
	_sync_retro_ui()


func _refresh_layer_list() -> void:
	_layer_option.clear()
	if not _current_params.has("layers"):
		_current_params["layers"] = []
	var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
	for i: int in range(layers.size()):
		var layer: Dictionary = layers[i]
		_layer_option.add_item("%d: %s" % [i + 1, str(layer.get("role", "Layer"))])
	if _layer_option.get_item_count() > 0:
		_layer_option.select(mini(_layer_option.selected if _layer_option.selected >= 0 else 0, _layer_option.get_item_count() - 1))


func _refresh_layer_controls() -> void:
	var layer: Dictionary = _current_layer()
	if _wave_option != null:
		for i: int in range(_wave_option.get_item_count()):
			if _wave_option.get_item_text(i) == str(layer.get("wave", "Sine")):
				_wave_option.select(i)
				break
	for i: int in range(_filter_mode_option.get_item_count()):
		if _filter_mode_option.get_item_text(i) == str(layer.get("filter_mode", "Lowpass")):
			_filter_mode_option.select(i)
			break
	for i: int in range(_noise_mode_option.get_item_count()):
		if _noise_mode_option.get_item_text(i) == str(layer.get("noise_mode", "white")):
			_noise_mode_option.select(i)
			break
	for key: String in _param_controls.keys():
		if layer.has(key):
			(_param_controls[key] as SpinBox).set_value_no_signal(float(layer[key]))


func _sync_range_ui() -> void:
	var ranges: Dictionary = _current_params.get("generation_ranges", PresetBank._default_generation_ranges())
	var locks: Dictionary = _current_params.get("locks", {})
	for key: String in _range_controls.keys():
		var pair: Dictionary = _range_controls[key]
		var rule: Dictionary = ranges.get(key, {})
		(pair["min"] as SpinBox).set_value_no_signal(float(rule.get("min", 0.0)))
		(pair["max"] as SpinBox).set_value_no_signal(float(rule.get("max", 1.0)))
		(_lock_controls[key] as CheckButton).set_pressed_no_signal(bool(locks.get(key, false)))


func _sync_wavetable_ui() -> void:
	var wt: PackedFloat32Array = _float_array(_current_layer().get("wavetable", PackedFloat32Array()))
	if wt.is_empty():
		wt = PresetBank._default_wavetable(32, "sine")
	_wavetable_editor.set_values(wt)


func _sync_fm_ui() -> void:
	var layer: Dictionary = _current_layer()
	var ops: Array[Dictionary] = _dictionary_array(layer.get("fm_ops", PresetBank._default_fm_ops()))
	for i: int in range(mini(ops.size(), _fm_controls.size())):
		var controls: Dictionary = _fm_controls[i]
		var op: Dictionary = ops[i]
		for key_value: Variant in controls.keys():
			var key: String = str(key_value)
			(controls[key] as SpinBox).set_value_no_signal(float(op.get(key, 0.0)))
	if _fm_routing_label != null:
		var algorithm: int = clampi(int(layer.get("fm_algorithm", _current_params.get("fm_algorithm", 0))), 0, 7)
		_fm_routing_label.text = "Routing: %s" % _fm_algorithm_description(algorithm)


func _sync_sample_ui() -> void:
	if _sample_loop_toggle == null:
		return
	var layer: Dictionary = _current_layer()
	_sample_loop_toggle.set_pressed_no_signal(bool(layer.get("sample_loop", false)))
	_sample_reverse_toggle.set_pressed_no_signal(bool(layer.get("sample_reverse", false)))
	_sample_playback_spin.set_value_no_signal(float(layer.get("sample_playback_rate", 1.0)))
	_sample_rate_reduce_spin.set_value_no_signal(float(layer.get("sample_rate_reduce_hz", 0.0)))
	_sample_loop_start_spin.set_value_no_signal(float(layer.get("sample_loop_start", 0.0)))
	_sample_loop_end_spin.set_value_no_signal(float(layer.get("sample_loop_end", 1.0)))


func _fm_algorithm_description(algorithm: int) -> String:
	match algorithm:
		0: return "OP4 → OP3 → OP2 → OP1 → OUT"
		1: return "OP4 → OP3 → OUT  +  OP2 → OP1 → OUT"
		2: return "OP4 → OP3 → OP1 + OP2 → OP1 → OUT"
		3: return "OP4 → OP3 + OP2 + OP1 → OUT"
		4: return "OP4 → OP2 → OP1 + OP3 → OUT"
		5: return "OP4 → OP2 + OP3 → OP1 → OUT"
		6: return "OP4 + OP3 → OP2 → OP1 → OUT"
		_: return "OP1 + OP2 + OP3 + OP4 → OUT"


func _refresh_waveform_choices() -> void:
	_wave_option.clear()
	var profile: Dictionary = RetroProfiles.get_profile(_selected_profile())
	for wave_value: Variant in Array(profile.get("waveforms", [])):
		var wave: String = str(wave_value)
		_wave_option.add_item(str(wave))
	if _selected_profile() == RetroProfiles.MODERN:
		for extra: String in ["Custom Wavetable", "FM4 Advanced", "Sample PCM"]:
			_wave_option.add_item(extra)
	elif _selected_profile() in [RetroProfiles.AMIGA, RetroProfiles.SNES]:
		_wave_option.add_item("Sample PCM")


func _update_profile_info() -> void:
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		_profile_info.text = "%s\nExtension ID: %s" % [extension.get_description(), str(extension.get_generator_id())] if extension != null else "Extension generator unavailable."
		return
	var p: Dictionary = RetroProfiles.get_profile(_selected_profile())
	_profile_info.text = "%s\nEra: %s • Voices: %d • Native rate: %d Hz • Depth: %d-bit" % [str(p.get("description", "")), str(p.get("era", "")), int(p.get("voices", 0)), int(p.get("sample_rate", 0)), int(p.get("output_bits", 16))]


func _new_random_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


func _on_profile_changed(_index: int) -> void:
	if _is_extension_generator_active():
		return
	_generate_current(false)


func _on_category_changed(_index: int) -> void:
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		_current_params = _extension_default_params(extension, _selected_category(), int(_seed_spin.value))
		_rebuild_extension_parameter_ui()
		_render_params(false)
		return
	_generate_current(false)


func _on_hardware_toggled(enabled: bool) -> void:
	if _is_extension_generator_active():
		return
	if _accuracy_option != null:
		_accuracy_option.select(1 if enabled else 0)
	_generate_current(false)


func _on_accuracy_changed(index: int) -> void:
	if _is_extension_generator_active():
		return
	_hardware_toggle.set_pressed_no_signal(index == 1)
	_generate_current(false)


func _on_new_seed() -> void:
	_seed_spin.value = _new_random_seed()
	if _is_extension_generator_active():
		_current_params["seed"] = int(_seed_spin.value)
		_render_params(false)
		return
	var preserved_wave: String = str(_current_layer().get("wave", "")) if not _current_params.is_empty() else ""
	var mode: String = HardwareRules.MODE_HARDWARE if _accuracy_option != null and _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
	_current_params = PresetBank.make_preset_with_mode(_selected_profile(), _selected_category(), int(_seed_spin.value), mode)
	if not preserved_wave.is_empty() and _profile_supports_wave(preserved_wave):
		var layers_value: Variant = _current_params.get("layers", [])
		if layers_value is Array and not (layers_value as Array).is_empty():
			((layers_value as Array)[0] as Dictionary)["wave"] = preserved_wave
		else:
			_current_params["wave"] = preserved_wave
	_sync_ui_from_params()
	_render_params(false)


func _on_generate() -> void:
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		_push_undo()
		var seed: int = _new_random_seed()
		_seed_spin.value = seed
		_current_params = extension.randomize_params(_current_params, seed)
		_current_params["generator_extension_id"] = str(extension.get_generator_id())
		_current_params["profile"] = extension.get_display_name()
		_current_params["category"] = _selected_category()
		_rebuild_extension_parameter_ui()
		_render_params(true)
		return
	var ranges: Dictionary = _current_params.get("generation_ranges", PresetBank._default_generation_ranges())
	var locks: Dictionary = _current_params.get("locks", {})
	var preserved_wave: String = str(_current_layer().get("wave", ""))
	_seed_spin.value = _new_random_seed()
	_push_undo()
	_current_params = PresetBank.make_generated_preset(_selected_profile(), _selected_category(), int(_seed_spin.value), _accuracy_option.selected == 1, ranges, locks)
	_current_params["accuracy_mode"] = HardwareRules.MODE_HARDWARE if _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
	if _accuracy_option.selected == 1 and _selected_profile() != RetroProfiles.MODERN:
		_current_params = HardwareRules.apply_constraints(_current_params, _selected_profile(), HardwareRules.MODE_HARDWARE)
	if _current_params.has("layers") and not (_current_params["layers"] as Array).is_empty() and not preserved_wave.is_empty():
		(_current_params["layers"][0] as Dictionary)["wave"] = preserved_wave
	_sync_ui_from_params()
	_render_params(true)


func _on_randomize() -> void:
	_push_undo()
	var seed: int = _new_random_seed()
	_seed_spin.value = seed
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		_current_params = extension.randomize_params(_current_params, seed)
		_current_params["generator_extension_id"] = str(extension.get_generator_id())
		_current_params["profile"] = extension.get_display_name()
		_current_params["category"] = _selected_category()
	else:
		_current_params = PresetBank.randomize_parameters(_current_params, seed)
	_sync_ui_from_params()
	_render_params(true)


func _on_reset_generator() -> void:
	_push_undo()
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		_current_params = _extension_default_params(extension, _selected_category(), int(_seed_spin.value))
	else:
		var mode: String = HardwareRules.MODE_HARDWARE if _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
		_current_params = PresetBank.make_preset_with_mode(_selected_profile(), _selected_category(), int(_seed_spin.value), mode)
	_sync_ui_from_params()
	_render_params(false)


func _on_wave_selected(index: int) -> void:
	if index < 0:
		return
	_push_undo()
	_current_layer()["wave"] = _wave_option.get_item_text(index)
	_render_params(false)


func _on_filter_mode_selected(index: int) -> void:
	if index < 0:
		return
	_push_undo()
	_current_layer()["filter_mode"] = _filter_mode_option.get_item_text(index)
	_render_params(false)


func _on_noise_mode_selected(index: int) -> void:
	if index < 0:
		return
	_push_undo()
	_current_layer()["noise_mode"] = _noise_mode_option.get_item_text(index)
	_render_params(false)


func _on_parameter_changed(value: float, key: String) -> void:
	_push_undo("param:" + key)
	_current_layer()[key] = value
	_queue_preview_render()


func _on_play() -> void:
	_flush_preview_render()
	if _player.stream != null:
		_player.play()


func _on_stop() -> void:
	_player.stop()


func _mutate_current(amount: float) -> void:
	if _current_params.is_empty():
		return
	_push_undo()
	var seed: int = _new_random_seed()
	_seed_spin.value = seed
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		_current_params = extension.mutate_params(_current_params, seed, amount)
		_current_params["generator_extension_id"] = str(extension.get_generator_id())
		_current_params["profile"] = extension.get_display_name()
		_current_params["category"] = _selected_category()
	else:
		_current_params = PresetBank.mutate(_current_params, seed, amount)
	_sync_ui_from_params()
	_render_params(true)


func _selected_variant_count() -> int:
	if _variant_count_option == null or _variant_count_option.selected < 0:
		return 16
	return _variant_count_option.get_item_id(_variant_count_option.selected)


func _set_variant_button_count(count: int) -> void:
	if _variants_container == null:
		return
	var target_count: int = clampi(count, 8, 32)
	for button: Button in _variant_buttons:
		button.queue_free()
	_variant_buttons.clear()
	for i: int in range(target_count):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(150.0, 34.0)
		button.text = "Variant %d" % (i + 1)
		button.disabled = i >= _variant_results.size()
		if i < _variant_results.size():
			var params: Dictionary = _variant_results[i].get("params", {}) as Dictionary
			button.text = "Variant %d  #%d" % [i + 1, int(params.get("seed", 0)) % 10000]
		button.pressed.connect(_on_variant_pressed.bind(i))
		_variants_container.add_child(button)
		_variant_buttons.append(button)
	_refresh_generated_variant_labels()


func _on_variant_count_selected(_index: int) -> void:
	_set_variant_button_count(_selected_variant_count())
	if not _variant_results.is_empty():
		_status.text = "Showing %d of %d generated variants." % [mini(_variant_buttons.size(), _variant_results.size()), _variant_results.size()]


func _on_slight_mutate() -> void:
	_mutate_current(0.18)


func _on_mutate() -> void:
	_mutate_current(float(_mutation_slider.value))


func _on_heavy_mutate() -> void:
	_mutate_current(0.82)


func _on_generate_variants() -> void:
	var count: int = _selected_variant_count()
	_start_background_variant_batch(count, 7919)


func _on_batch_generate() -> void:
	_start_background_variant_batch(int(_batch_spin.value))


func _generate_variant_batch(count: int) -> void:
	# Retained as a compatibility entry point; all multi-variant synthesis now uses
	# WorkerThreadPool so even expensive layered presets cannot block the editor.
	_start_background_variant_batch(count, 7919)


func _on_variant_pressed(index: int) -> void:
	if index < 0 or index >= _variant_results.size():
		return
	_selected_variant_index = index
	_selected_variant_source = "generated"
	_selected_variant_result = _variant_results[index]
	_selected_variant_params = (_selected_variant_result.get("params", {}) as Dictionary).duplicate(true)
	_apply_selected_variant("Variant %d" % (index + 1))


func _on_saved_variant_pressed(source: String, index: int) -> void:
	var collection: Array[Dictionary] = _kept_variants if source == "kept" else _favorite_variants
	if index < 0 or index >= collection.size():
		return
	_selected_variant_index = index
	_selected_variant_source = source
	_selected_variant_params = collection[index].duplicate(true)
	var label: String = "Kept" if source == "kept" else "Favorite"
	var extension_id: StringName = StringName(str(_selected_variant_params.get("generator_extension_id", "")))
	if not str(extension_id).is_empty():
		_select_generator_source_id(extension_id)
		_apply_generator_source_mode(false)
		_current_params = _selected_variant_params.duplicate(true)
		_sync_ui_from_params()
		_start_extension_generation([_selected_variant_params.duplicate(true)], "saved", true, "%s %d" % [label, index + 1])
		return
	_selected_variant_result = SynthEngine.render(_selected_variant_params)
	_apply_selected_variant("%s %d" % [label, index + 1])


func _apply_selected_variant(label: String) -> void:
	if _selected_variant_params.is_empty():
		return
	_current_params = _selected_variant_params.duplicate(true)
	var extension_id: StringName = StringName(str(_current_params.get("generator_extension_id", "")))
	if not str(extension_id).is_empty():
		_select_generator_source_id(extension_id)
		_apply_generator_source_mode(false)
	_current_result = _selected_variant_result
	_seed_spin.value = int(_current_params.get("seed", 1))
	_sync_ui_from_params()
	var selected_stream: AudioStream = _current_result.get("stream") as AudioStream
	var selected_samples: PackedFloat32Array = _current_result.get("samples", PackedFloat32Array())
	_player.stream = selected_stream
	_waveform.set_samples(selected_samples)
	_player.play()
	_status.text = "%s selected • seed %d" % [label, int(_current_params.get("seed", 0))]


func _on_keep_variant() -> void:
	if _selected_variant_params.is_empty():
		_status.text = "Select a generated, kept, or favorite variant first."
		return
	var identity: String = _variant_identity(_selected_variant_params)
	for saved: Dictionary in _kept_variants:
		if _variant_identity(saved) == identity:
			_status.text = "That variant is already kept."
			return
	_kept_variants.append(_selected_variant_params.duplicate(true))
	project_state_changed.emit()
	_refresh_saved_variant_buttons()
	_refresh_generated_variant_labels()
	_status.text = "Kept variant • seed %d. It will remain visible after regeneration." % int(_selected_variant_params.get("seed", 0))


func _on_favorite_variant() -> void:
	if _selected_variant_params.is_empty():
		_status.text = "Select a generated, kept, or favorite variant first."
		return
	var identity: String = _variant_identity(_selected_variant_params)
	for saved: Dictionary in _favorite_variants:
		if _variant_identity(saved) == identity:
			_status.text = "That variant is already a favorite."
			return
	_favorite_variants.append(_selected_variant_params.duplicate(true))
	project_state_changed.emit()
	_refresh_saved_variant_buttons()
	_refresh_generated_variant_labels()
	_status.text = "Favorited variant • seed %d." % int(_selected_variant_params.get("seed", 0))


func _on_remove_selected_saved_variant() -> void:
	if _selected_variant_source == "kept":
		if _selected_variant_index >= 0 and _selected_variant_index < _kept_variants.size():
			_kept_variants.remove_at(_selected_variant_index)
			_status.text = "Removed selected kept variant."
	elif _selected_variant_source == "favorite":
		if _selected_variant_index >= 0 and _selected_variant_index < _favorite_variants.size():
			_favorite_variants.remove_at(_selected_variant_index)
			_status.text = "Removed selected favorite variant."
	else:
		_status.text = "Select a kept or favorite variant to remove it."
		return
	_selected_variant_index = -1
	_selected_variant_source = ""
	_selected_variant_params.clear()
	_selected_variant_result.clear()
	project_state_changed.emit()
	_refresh_saved_variant_buttons()
	_refresh_generated_variant_labels()


func _on_mutate_selected_variant() -> void:
	if _selected_variant_params.is_empty():
		_status.text = "Select a variant first."
		return
	_current_params = _selected_variant_params.duplicate(true)
	_mutate_current(float(_mutation_slider.value))


func _on_export_selected_variant() -> void:
	if _selected_variant_params.is_empty():
		_status.text = "Select a variant first."
		return
	_current_params = _selected_variant_params.duplicate(true)
	if _selected_variant_result.is_empty():
		var extension_id: StringName = StringName(str(_current_params.get("generator_extension_id", "")))
		if not str(extension_id).is_empty():
			_status.text = "Regenerate or select the extension variant before exporting it."
			return
		_selected_variant_result = SynthEngine.render(_current_params)
	_current_result = _selected_variant_result
	_on_save_wav()


func _variant_identity(params: Dictionary) -> String:
	return "%s|%s|%s|%d" % [
		str(params.get("generator_extension_id", "")),
		str(params.get("profile", "")),
		str(params.get("category", "")),
		int(params.get("seed", 0)),
	]


func _is_variant_in_collection(params: Dictionary, collection: Array[Dictionary]) -> bool:
	var identity: String = _variant_identity(params)
	for saved: Dictionary in collection:
		if _variant_identity(saved) == identity:
			return true
	return false


func _refresh_saved_variant_buttons() -> void:
	_rebuild_saved_variant_collection(_kept_variants_container, _kept_variant_buttons, _kept_variants, "kept")
	_rebuild_saved_variant_collection(_favorite_variants_container, _favorite_variant_buttons, _favorite_variants, "favorite")


func _rebuild_saved_variant_collection(container: HFlowContainer, buttons: Array[Button], collection: Array[Dictionary], source: String) -> void:
	if container == null:
		return
	for button: Button in buttons:
		button.queue_free()
	buttons.clear()
	for i: int in range(collection.size()):
		var params: Dictionary = collection[i]
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(150.0, 34.0)
		var seed_suffix: int = int(params.get("seed", 0)) % 10000
		button.text = ("★ Kept #%d" % seed_suffix) if source == "kept" else ("♥ Favorite #%d" % seed_suffix)
		button.tooltip_text = "%s • %s • seed %d" % [str(params.get("profile", "")), str(params.get("category", "")), int(params.get("seed", 0))]
		button.pressed.connect(_on_saved_variant_pressed.bind(source, i))
		container.add_child(button)
		buttons.append(button)


func _refresh_generated_variant_labels() -> void:
	for i: int in range(_variant_buttons.size()):
		var button: Button = _variant_buttons[i]
		if i >= _variant_results.size():
			button.disabled = true
			button.text = "Variant %d" % (i + 1)
			continue
		button.disabled = false
		var params: Dictionary = _variant_results[i].get("params", {}) as Dictionary
		var marker: String = ""
		if _is_variant_in_collection(params, _kept_variants):
			marker += "★"
		if _is_variant_in_collection(params, _favorite_variants):
			marker += "♥"
		button.text = "%sVariant %d  #%d" % [marker + " " if not marker.is_empty() else "", i + 1, int(params.get("seed", 0)) % 10000]


func _on_layer_selected(_index: int) -> void:
	_refresh_layer_controls()
	_sync_wavetable_ui()
	_sync_fm_ui()
	_sync_sample_ui()


func _on_add_layer() -> void:
	_push_undo()
	var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
	var source: Dictionary = _current_layer().duplicate(true)
	source["role"] = str(source.get("role", "Layer")) + " Copy"
	layers.append(source)
	_current_params["layers"] = layers
	_refresh_layer_list()
	_layer_option.select(layers.size() - 1)
	_refresh_layer_controls()
	_render_params(false)


func _on_remove_layer() -> void:
	var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
	if layers.size() > 1:
		_push_undo()
	if layers.size() <= 1:
		return
	layers.remove_at(clampi(_layer_option.selected, 0, layers.size() - 1))
	_current_params["layers"] = layers
	_refresh_layer_list()
	_refresh_layer_controls()
	_render_params(false)


func _on_rebuild_layers() -> void:
	_push_undo()
	var regenerated: Dictionary = PresetBank.make_preset(_selected_profile(), _selected_category(), int(_seed_spin.value), _hardware_toggle.button_pressed)
	_current_params["layers"] = regenerated.get("layers", [])
	_refresh_layer_list()
	_refresh_layer_controls()
	_render_params(false)


func _on_apply_workspace_from_tab() -> void:
	_on_workspace_generate("Noise", "white")


func _on_workspace_generate(workspace: String, subtype: String) -> void:
	_seed_spin.value = _new_random_seed()
	_current_params = PresetBank.make_workspace_preset(workspace, subtype, int(_seed_spin.value))
	_current_params["profile"] = RetroProfiles.MODERN
	_current_params["hardware_limits"] = false
	_profile_option.select(0)
	_sync_ui_from_params()
	_render_params(true)


func _on_wavetable_tool(tool_name: String) -> void:
	_wavetable_editor.set_tool(tool_name)


func _on_wavetable_action(action: String) -> void:
	var values: PackedFloat32Array = _wavetable_editor.get_values()
	match action:
		"Sine": values = PresetBank._default_wavetable(values.size(), "sine")
		"Triangle": values = PresetBank._default_wavetable(values.size(), "triangle")
		"Saw": values = PresetBank._default_wavetable(values.size(), "saw")
		"Square": values = PresetBank._default_wavetable(values.size(), "square")
		"Harmonics":
			for i: int in range(values.size()):
				var phase: float = TAU * float(i) / float(values.size())
				values[i] = clampf(sin(phase) + sin(phase * 2.0) * 0.5 + sin(phase * 3.0) * 0.333333 + sin(phase * 5.0) * 0.2, -1.0, 1.0)
		"Randomize":
			for i: int in range(values.size()):
				values[i] = randf_range(-1.0, 1.0)
		"Normalize":
			var peak: float = 0.001
			for v: float in values:
				peak = maxf(peak, absf(v))
			for i: int in range(values.size()):
				values[i] /= peak
		"Smooth":
			var copy: PackedFloat32Array = values.duplicate()
			for i: int in range(values.size()):
				var a: float = copy[(i - 1 + copy.size()) % copy.size()]
				var b: float = copy[i]
				var c: float = copy[(i + 1) % copy.size()]
				values[i] = (a + b + c) / 3.0
		"Invert":
			for i: int in range(values.size()):
				values[i] = -values[i]
	_wavetable_editor.set_values(values)
	_on_wavetable_changed(values)


func _on_wavetable_resize(size_value: int) -> void:
	_wavetable_editor.set_size_steps(size_value)
	_on_wavetable_changed(_wavetable_editor.get_values())


func _on_wavetable_custom_resize() -> void:
	_on_wavetable_resize(clampi(int(_wavetable_custom_size.value), 4, 2048))


func _on_sample_workspace() -> void:
	_push_undo()
	var selected_profile: String = _selected_profile()
	if selected_profile not in [RetroProfiles.MODERN, RetroProfiles.AMIGA, RetroProfiles.SNES]:
		selected_profile = RetroProfiles.MODERN
		_profile_option.select(0)
	var seed: int = _new_random_seed()
	_current_params = PresetBank.make_workspace_preset("Sample", "Sample", seed)
	_current_params["profile"] = selected_profile
	_current_params["hardware_limits"] = _accuracy_option.selected == 1
	_current_params["accuracy_mode"] = HardwareRules.MODE_HARDWARE if _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
	if selected_profile in [RetroProfiles.AMIGA, RetroProfiles.SNES]:
		_current_params = HardwareRules.apply_constraints(_current_params, selected_profile, str(_current_params["accuracy_mode"]))
	_seed_spin.value = seed
	_sync_ui_from_params()
	_render_params(false)


func _on_sample_bool_changed(enabled: bool, key: String) -> void:
	_push_undo("sample:" + key)
	_current_layer()[key] = enabled
	_queue_preview_render()


func _on_sample_value_changed(value: float, key: String) -> void:
	_push_undo("sample:" + key)
	var layer: Dictionary = _current_layer()
	if key == "sample_loop_start":
		value = minf(value, float(layer.get("sample_loop_end", 1.0)) - 0.001)
	elif key == "sample_loop_end":
		value = maxf(value, float(layer.get("sample_loop_start", 0.0)) + 0.001)
	layer[key] = value
	_queue_preview_render()


func _on_wavetable_changed(values: PackedFloat32Array) -> void:
	_current_layer()["wavetable"] = values
	if str(_current_layer().get("wave", "")) in ["GB Wave", "Sample Wavetable", "Custom Wavetable"]:
		_queue_preview_render()


func _on_fm_changed(value: float, index: int, key: String) -> void:
	_push_undo("fm:%d:%s" % [index, key])
	var layer: Dictionary = _current_layer()
	var ops: Array[Dictionary] = _dictionary_array(layer.get("fm_ops", PresetBank._default_fm_ops()))
	while ops.size() <= index:
		ops.append({"ratio": 1.0, "level": 1.0})
	var op: Dictionary = ops[index]
	op[key] = value
	ops[index] = op
	layer["fm_ops"] = ops
	if str(layer.get("wave", "")) in ["FM4", "FM4 Advanced", "FM2", "OPL Half-Sine", "OPL Abs-Sine"]:
		_queue_preview_render()


func _on_range_changed(value: float, key: String, bound: String) -> void:
	if not _current_params.has("generation_ranges"):
		_current_params["generation_ranges"] = PresetBank._default_generation_ranges()
	var ranges: Dictionary = _current_params["generation_ranges"]
	if not ranges.has(key):
		ranges[key] = {}
		_current_params["generation_ranges"] = ranges
	var rule: Dictionary = ranges[key]
	rule[bound] = value
	ranges[key] = rule


func _on_lock_toggled(value: bool, key: String) -> void:
	if not _current_params.has("locks"):
		_current_params["locks"] = {}
	var locks: Dictionary = _current_params["locks"]
	locks[key] = value
	_current_params["locks"] = locks


func _on_save_wav() -> void:
	_flush_preview_render()
	if _current_result.is_empty():
		return
	_save_mode = "current"
	_save_dialog.current_file = "%s_%s_%d.wav" % [_file_stem(_selected_profile()), _file_stem(str(_current_params.get("category", _selected_category()))), int(_current_params.get("seed", 0))]
	_save_dialog.popup_file_dialog()


func _on_save_path_selected(path: String) -> void:
	var wav: AudioStreamWAV = _current_result.get("stream") as AudioStreamWAV
	if wav == null:
		_status.text = "Nothing to save."
		return
	_apply_wav_tags(wav, _current_params)
	var pcm: GASPCMData = PCMData.from_wav(wav)
	var bit_depth: int = 8 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 16
	var err: Error = ExportEngine.save_wav(path, pcm, false, wav.mix_rate, false, bit_depth, wav.tags, wav.loop_begin, wav.loop_end, wav.loop_mode) if pcm != null else ERR_INVALID_DATA
	if err == OK:
		_write_metadata_sidecar(path, _current_params)
		_status.text = "Saved: %s" % path
		_refresh_exported_resources(PackedStringArray([path]))
	else:
		_status.text = "Save failed: %s" % error_string(err)


func _refresh_exported_resources(paths: PackedStringArray) -> void:
	for path: String in paths:
		var localized: String = ProjectSettings.localize_path(path)
		if localized.begins_with("res://") and FileAccess.file_exists(localized) and not _pending_editor_imports.has(localized):
			_pending_editor_imports.append(localized)
	if _pending_editor_imports.is_empty():
		return
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


func _user_preset_dir() -> String:
	return "user://gator_audio_studio_presets"


func _project_preset_dir() -> String:
	return "res://addons/gator_audio_studio/project_presets"


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _save_preset(dir_path: String, name: String) -> void:
	if name.strip_edges().is_empty():
		return
	_ensure_dir(dir_path)
	var file: FileAccess = FileAccess.open(dir_path.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_current_params, "\t"))
	file.close()
	_refresh_preset_lists()


func _load_preset(dir_path: String, option: OptionButton) -> void:
	if option.get_item_count() == 0 or option.selected < 0:
		return
	var path: String = dir_path.path_join(option.get_item_text(option.selected) + ".json")
	if not FileAccess.file_exists(path):
		return
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		_current_params = (json.data as Dictionary).duplicate(true)
		var extension_id: StringName = StringName(str(_current_params.get("generator_extension_id", "")))
		if not str(extension_id).is_empty():
			var extension: GASGeneratorExtension = ExtensionAPI.create_generator_extension(extension_id)
			_select_generator_source_id(extension_id)
			_apply_generator_source_mode(false)
			if extension == null:
				_current_result.clear()
				if _player != null:
					_player.stop()
					_player.stream = null
				if _waveform != null:
					_waveform.set_samples(PackedFloat32Array())
				_status.text = "Preset requires missing or disabled generator extension '%s'. Parameters were preserved." % str(extension_id)
				return
			var loaded_extension_category: String = str(_current_params.get("category", _selected_category()))
			_select_option_text(_category_option, loaded_extension_category)
			_current_params["category"] = _selected_category()
		else:
			_select_generator_source_id(&"")
			_apply_generator_source_mode(false)
			_profile_option.select(maxi(0, RetroProfiles.PROFILE_ORDER.find(str(_current_params.get("profile", RetroProfiles.MODERN)))))
			var loaded_category: String = str(_current_params.get("category", _selected_category()))
			var category_index: int = PresetBank.CATEGORY_ORDER.find(loaded_category)
			if category_index >= 0:
				_category_option.select(category_index)
		_sync_ui_from_params()
		_render_params(false)


func _delete_preset(dir_path: String, option: OptionButton) -> void:
	if option.get_item_count() == 0 or option.selected < 0:
		return
	var path: String = dir_path.path_join(option.get_item_text(option.selected) + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_refresh_preset_lists()


func _refresh_preset_lists() -> void:
	_refresh_option_from_dir(_user_preset_option, _user_preset_dir())
	_refresh_option_from_dir(_project_preset_option, _project_preset_dir())
	_refresh_extension_saved_preset_lists()


func _refresh_extension_saved_preset_lists() -> void:
	_refresh_extension_option_from_dir(_extension_user_preset_option, _user_preset_dir())
	_refresh_extension_option_from_dir(_extension_project_preset_option, _project_preset_dir())


func _refresh_extension_option_from_dir(option: OptionButton, dir_path: String) -> void:
	if option == null:
		return
	option.clear()
	var extension_id: String = str(_active_extension_generator_id())
	if extension_id.is_empty():
		return
	var absolute: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var names: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if dir.current_is_dir() or not name.ends_with(".json"):
			continue
		var path: String = dir_path.path_join(name)
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
			continue
		var params: Dictionary = json.data as Dictionary
		if str(params.get("generator_extension_id", "")) == extension_id:
			names.append(name.get_basename())
	dir.list_dir_end()
	names.sort()
	for name: String in names:
		option.add_item(name)


func _refresh_option_from_dir(option: OptionButton, dir_path: String) -> void:
	if option == null:
		return
	option.clear()
	var absolute: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if not dir.current_is_dir() and name.ends_with(".json"):
			option.add_item(name.get_basename())
	dir.list_dir_end()


func _on_save_user_preset() -> void:
	_save_preset(_user_preset_dir(), _user_preset_name.text)


func _on_load_user_preset() -> void:
	_load_preset(_user_preset_dir(), _user_preset_option)


func _on_delete_user_preset() -> void:
	_delete_preset(_user_preset_dir(), _user_preset_option)


func _on_save_project_preset() -> void:
	_save_preset(_project_preset_dir(), _project_preset_name.text)


func _on_load_project_preset() -> void:
	_load_preset(_project_preset_dir(), _project_preset_option)


func _on_delete_project_preset() -> void:
	_delete_preset(_project_preset_dir(), _project_preset_option)


func _on_save_extension_user_preset() -> void:
	if _extension_user_preset_name != null:
		_save_preset(_user_preset_dir(), _extension_user_preset_name.text)


func _on_load_extension_user_preset() -> void:
	_load_preset(_user_preset_dir(), _extension_user_preset_option)


func _on_delete_extension_user_preset() -> void:
	_delete_preset(_user_preset_dir(), _extension_user_preset_option)


func _on_save_extension_project_preset() -> void:
	if _extension_project_preset_name != null:
		_save_preset(_project_preset_dir(), _extension_project_preset_name.text)


func _on_load_extension_project_preset() -> void:
	_load_preset(_project_preset_dir(), _extension_project_preset_option)


func _on_delete_extension_project_preset() -> void:
	_delete_preset(_project_preset_dir(), _extension_project_preset_option)


func _on_set_parent_a() -> void:
	_parent_a = _current_params.duplicate(true)
	_status.text = "Parent A set."


func _on_set_parent_b() -> void:
	_parent_b = _current_params.duplicate(true)
	_status.text = "Parent B set."


func _on_breed_child() -> void:
	if _parent_a.is_empty() or _parent_b.is_empty():
		_status.text = "Set Parent A and Parent B first."
		return
	_seed_spin.value = _new_random_seed()
	_current_params = PresetBank.breed(_parent_a, _parent_b, int(_seed_spin.value), float(_breed_bias_slider.value))
	_sync_ui_from_params()
	_render_params(true)


func _on_breed_random() -> void:
	_breed_bias_slider.value = randf()
	_on_breed_child()


func _on_breed_mostly_a() -> void:
	_breed_bias_slider.value = 0.2
	_on_breed_child()


func _on_breed_balanced() -> void:
	_breed_bias_slider.value = 0.5
	_on_breed_child()


func _on_breed_mostly_b() -> void:
	_breed_bias_slider.value = 0.8
	_on_breed_child()


func _sync_advanced_ui() -> void:
	if _current_params.is_empty() or _advanced_controls.is_empty():
		return
	var layer: Dictionary = _current_layer()
	for key: String in _advanced_controls.keys():
		var spin: SpinBox = _advanced_controls[key] as SpinBox
		if layer.has(key):
			spin.set_value_no_signal(float(layer[key]))
	if _distortion_option != null:
		_select_option_text(_distortion_option, str(layer.get("distortion_mode", "Soft Clip")))
	if _delay_mode_option != null:
		_select_option_text(_delay_mode_option, str(layer.get("delay_mode", "Mono")))


func _sync_retro_ui() -> void:
	if _current_params.is_empty():
		return
	var layer: Dictionary = _current_layer()
	if _accuracy_option != null:
		var mode: String = str(_current_params.get("accuracy_mode", HardwareRules.MODE_HARDWARE if bool(_current_params.get("hardware_limits", true)) else HardwareRules.MODE_STYLE))
		_select_option_text(_accuracy_option, mode)
		_hardware_toggle.set_pressed_no_signal(mode == HardwareRules.MODE_HARDWARE)
	if _fm_algorithm_option != null:
		_fm_algorithm_option.select(clampi(int(layer.get("fm_algorithm", 0)), 0, 7))
	if _opl_mode_option != null:
		_opl_mode_option.select(1 if int(layer.get("opl_mode", 2)) >= 4 else 0)
	if _opl_waveform_option != null:
		_opl_waveform_option.select(clampi(int(layer.get("opl_waveform", 0)), 0, 3))
	if _osc_sync_toggle != null:
		_osc_sync_toggle.set_pressed_no_signal(bool(layer.get("osc_sync", false)))
	if _ay_envelope_option != null:
		_ay_envelope_option.select(clampi(int(layer.get("ay_envelope_shape", 0)), 0, 3))
	if _note_sequence_edit != null:
		var sequence: PackedFloat32Array = _float_array(layer.get("note_sequence", []))
		var parts: PackedStringArray = PackedStringArray()
		for value: float in sequence:
			parts.append(str(value))
		_note_sequence_edit.text = ",".join(parts)
	if _fantasy_bits_spin != null:
		_fantasy_bits_spin.set_value_no_signal(float(_current_params.get("fantasy_bits", 6)))
		_fantasy_rate_spin.set_value_no_signal(float(_current_params.get("fantasy_sample_rate", 22050)))
		_fantasy_channels_spin.set_value_no_signal(float(_current_params.get("fantasy_channels", 4)))


func _select_option_text(option: OptionButton, text: String) -> void:
	for i: int in range(option.get_item_count()):
		if option.get_item_text(i) == text:
			option.select(i)
			return


func _on_advanced_parameter_changed(value: float, key: String) -> void:
	_push_undo("advanced:" + key)
	_current_layer()[key] = value
	_queue_preview_render()


func _on_distortion_mode_changed(index: int) -> void:
	if index < 0:
		return
	_push_undo()
	_current_layer()["distortion_mode"] = _distortion_option.get_item_text(index)
	_render_params(false)


func _on_delay_mode_changed(index: int) -> void:
	if index < 0:
		return
	_push_undo()
	_current_layer()["delay_mode"] = _delay_mode_option.get_item_text(index)
	_render_params(false)


func _on_fm_algorithm_changed(index: int) -> void:
	_push_undo()
	_current_layer()["fm_algorithm"] = clampi(index, 0, 7)
	if _fm_routing_label != null:
		_fm_routing_label.text = "Routing: %s" % _fm_algorithm_description(clampi(index, 0, 7))
	_render_params(false)


func _on_opl_mode_changed(index: int) -> void:
	_push_undo()
	var mode: int = 2 if index == 0 else 4
	var layer: Dictionary = _current_layer()
	layer["opl_mode"] = mode
	if _selected_profile() == RetroProfiles.OPL:
		layer["wave"] = "FM2" if mode == 2 else "FM4"
		_refresh_waveform_choices()
		_refresh_layer_controls()
	_render_params(false)


func _on_opl_waveform_changed(index: int) -> void:
	_push_undo()
	_current_layer()["opl_waveform"] = clampi(index, 0, 3)
	_render_params(false)


func _on_osc_sync_toggled(enabled: bool) -> void:
	_push_undo()
	_current_layer()["osc_sync"] = enabled
	_render_params(false)


func _on_ay_envelope_changed(index: int) -> void:
	_push_undo()
	_current_layer()["ay_envelope_shape"] = clampi(index, 0, 3)
	_render_params(false)


func _on_note_sequence_submitted(_text: String) -> void:
	_on_apply_note_sequence()


func _on_apply_note_sequence() -> void:
	if _note_sequence_edit == null:
		return
	var sequence: PackedFloat32Array = PackedFloat32Array()
	for token: String in _note_sequence_edit.text.split(","):
		var clean: String = token.strip_edges()
		if clean.is_valid_float():
			sequence.append(clampf(clean.to_float(), 0.05, 16.0))
	_push_undo()
	_current_layer()["note_sequence"] = sequence
	if not _current_layer().has("note_rate_hz"):
		_current_layer()["note_rate_hz"] = 12.0
	_render_params(false)


func _on_fantasy_setting_changed(value: float, key: String) -> void:
	_current_params[key] = int(value)
	if _selected_profile() == RetroProfiles.FANTASY_RETRO:
		if key == "fantasy_bits":
			_current_params["quantize_bits"] = int(value)
			var fantasy_layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
			for layer: Dictionary in fantasy_layers:
				layer["quantize_bits"] = int(value)
			_current_params["layers"] = fantasy_layers
		elif key == "fantasy_channels":
			var layers: Array[Dictionary] = _dictionary_array(_current_params.get("layers", []))
			var wanted: int = clampi(int(value), 1, 8)
			while layers.size() < wanted:
				var copy: Dictionary = _current_layer().duplicate(true)
				copy["role"] = "Fantasy Voice %d" % (layers.size() + 1)
				copy["gain"] = 0.5 / float(layers.size() + 1)
				layers.append(copy)
			if layers.size() > wanted:
				layers.resize(wanted)
			_current_params["layers"] = layers
			_refresh_layer_list()
		_render_params(false)


func _on_validate_hardware() -> void:
	var issues: PackedStringArray = HardwareRules.validate(_current_params, _selected_profile())
	if issues.is_empty():
		_status.text = "Hardware validation passed for %s." % _selected_profile()
	else:
		_status.text = "Hardware validation: %s" % "; ".join(issues)


func _on_rebuild_hardware_voices() -> void:
	_push_undo()
	var mode: String = HardwareRules.MODE_HARDWARE if _accuracy_option.selected == 1 else HardwareRules.MODE_STYLE
	_current_params = PresetBank.make_preset_with_mode(_selected_profile(), _selected_category(), int(_seed_spin.value), mode)
	_sync_ui_from_params()
	_render_params(true)


func _on_run_qa() -> void:
	var report: Dictionary = PresetBank.run_generator_qa()
	var failures: PackedStringArray = PackedStringArray(report.get("failures", PackedStringArray()))
	if bool(report.get("passed", false)):
		_status.text = "Generator QA passed: %d profile/category combinations." % int(report.get("checked", 0))
	else:
		_status.text = "Generator QA: %d failures across %d checks. First: %s" % [failures.size(), int(report.get("checked", 0)), failures[0] if not failures.is_empty() else "unknown"]


func _on_import_sample_wav() -> void:
	if _sample_dialog != null:
		_sample_dialog.popup_file_dialog()


func _on_sample_selected(path: String) -> void:
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
	if wav == null:
		_status.text = "Only WAV resources can be used as generated sample sources."
		return
	var data: PackedByteArray = wav.data
	var samples: PackedFloat32Array = PackedFloat32Array()
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		var stride: int = 4 if wav.stereo else 2
		var frames: int = int(data.size() / stride)
		samples.resize(frames)
		for i: int in range(frames):
			var left_sample: float = float(data.decode_s16(i * stride)) / 32768.0
			if wav.stereo:
				var right_sample: float = float(data.decode_s16(i * stride + 2)) / 32768.0
				samples[i] = (left_sample + right_sample) * 0.5
			else:
				samples[i] = left_sample
	elif wav.format == AudioStreamWAV.FORMAT_8_BITS:
		var stride8: int = 2 if wav.stereo else 1
		var frames8: int = int(data.size() / stride8)
		samples.resize(frames8)
		for i: int in range(frames8):
			var byte_left: int = int(data[i * stride8])
			var signed_left: int = byte_left - 256 if byte_left > 127 else byte_left
			if wav.stereo:
				var byte_right: int = int(data[i * stride8 + 1])
				var signed_right: int = byte_right - 256 if byte_right > 127 else byte_right
				samples[i] = (float(signed_left) + float(signed_right)) / 256.0
			else:
				samples[i] = float(signed_left) / 128.0
	else:
		_status.text = "Sample import currently supports 8-bit and 16-bit WAV PCM."
		return
	if samples.is_empty():
		return
	_push_undo()
	_current_layer()["sample_data"] = samples
	_current_layer()["sample_source_rate"] = wav.mix_rate
	_current_layer()["sample_source_path"] = path
	_current_layer()["sample_playback_rate"] = 1.0
	_current_layer()["sample_loop"] = false
	_current_layer()["sample_reverse"] = false
	_current_layer()["sample_loop_start"] = 0.0
	_current_layer()["sample_loop_end"] = 1.0
	_current_layer()["wave"] = "Sample PCM"
	_current_layer()["duration"] = minf(8.0, float(samples.size()) / float(maxi(1, wav.mix_rate)))
	_refresh_waveform_choices()
	_refresh_layer_controls()
	_sync_sample_ui()
	_render_params(true)
	_status.text = "Loaded sample source: %s" % path


func _on_generate_voice_set() -> void:
	if _background_group_id >= 0:
		_status.text = "A background generation batch is already running."
		return
	var style: String = str(_current_params.get("voice_style", "Speech"))
	var base_seed: int = int(_character_seed_spin.value)
	var pitch_min: float = minf(float(_voice_pitch_min_spin.value), float(_voice_pitch_max_spin.value))
	var pitch_max: float = maxf(float(_voice_pitch_min_spin.value), float(_voice_pitch_max_spin.value))
	var random_pitch: float = float(_voice_random_pitch_spin.value)
	var batch_params: Array[Dictionary] = []
	for i: int in range(24):
		var seed: int = base_seed + i * 3571
		var params: Dictionary = PresetBank.make_workspace_preset("Voice", style, seed)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed
		var layers: Array[Dictionary] = _dictionary_array(params.get("layers", []))
		for layer: Dictionary in layers:
			var pitch: float = rng.randf_range(pitch_min, pitch_max)
			var variation: float = 1.0 + rng.randf_range(-random_pitch, random_pitch)
			layer["start_hz"] = pitch * variation
			layer["end_hz"] = pitch * rng.randf_range(0.92, 1.08) * variation
		params["character_seed"] = base_seed
		params["voice_set_index"] = i + 1
		batch_params.append(params)
	_start_background_params(batch_params, "Generated 24-character voice blips for seed %d." % base_seed)


func _on_export_voice_set() -> void:
	if _background_group_id >= 0:
		_status.text = "A generator batch is already running."
		return
	_voice_export_after_generate = true
	_on_generate_voice_set()


func _record_result_history(render_ms: float) -> void:
	if _current_result.is_empty():
		return
	var seed: int = int(_current_params.get("seed", 0))
	if _seed_history.is_empty() or int(_seed_history.back()) != seed:
		_seed_history.append(seed)
		if _seed_history.size() > 64:
			_seed_history.pop_front()
	var entry: Dictionary = {
		"params": _current_params.duplicate(true),
		"result": _current_result,
		"label": "%s | %s | #%d | %.1f ms" % [_selected_profile(), str(_current_params.get("category", _selected_category())), seed, render_ms]
	}
	_result_history.append(entry)
	if _result_history.size() > 40:
		_result_history.pop_front()
	if _history_option != null:
		_history_option.clear()
		for item: Dictionary in _result_history:
			_history_option.add_item(str((item as Dictionary).get("label", "Result")))
		if _history_option.get_item_count() > 0:
			_history_option.select(_history_option.get_item_count() - 1)


func _on_recall_history() -> void:
	if _history_option == null or _history_option.selected < 0 or _history_option.selected >= _result_history.size():
		return
	var entry: Dictionary = _result_history[_history_option.selected]
	_current_params = (entry.get("params", {}) as Dictionary).duplicate(true)
	_seed_spin.value = int(_current_params.get("seed", 1))
	_sync_ui_from_params()
	_render_params(false)


func _on_set_compare_a() -> void:
	_compare_a = _current_result.duplicate(false)
	_status.text = "A comparison slot set."


func _on_set_compare_b() -> void:
	_compare_b = _current_result.duplicate(false)
	_status.text = "B comparison slot set."


func _on_play_compare_a() -> void:
	_play_comparison(_compare_a)


func _on_play_compare_b() -> void:
	_play_comparison(_compare_b)


func _play_comparison(result: Dictionary) -> void:
	if result.is_empty():
		return
	var compare_stream: AudioStream = result.get("stream") as AudioStream
	var compare_samples: PackedFloat32Array = _float_array(result.get("samples", PackedFloat32Array()))
	_player.stream = compare_stream
	_waveform.set_samples(compare_samples)
	_player.play()


func _on_play_loudness_matched_b() -> void:
	if _compare_a.is_empty() or _compare_b.is_empty():
		_status.text = "Set both A and B first."
		return
	var a_samples: PackedFloat32Array = _float_array(_compare_a.get("samples", PackedFloat32Array()))
	var b_samples: PackedFloat32Array = _float_array(_compare_b.get("samples", PackedFloat32Array()))
	if a_samples.is_empty() or b_samples.is_empty():
		return
	var rms_a: float = _rms(a_samples)
	var rms_b: float = maxf(0.000001, _rms(b_samples))
	var gain: float = clampf(rms_a / rms_b, 0.1, 10.0)
	var matched: PackedFloat32Array = b_samples.duplicate()
	for i: int in range(matched.size()):
		matched[i] = clampf(matched[i] * gain, -1.0, 1.0)
	_player.stream = SynthEngine.make_stream(matched, int(_compare_b.get("sample_rate", 48000)))
	_waveform.set_samples(matched)
	_player.play()
	_status.text = "Playing loudness-matched B (%.2fx)." % gain


func _rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in samples:
		total += value * value
	return sqrt(total / float(samples.size()))


func _push_undo(group_key: String = "") -> void:
	if _suppress_undo or _current_params.is_empty():
		return
	var now_usec: int = Time.get_ticks_usec()
	if not group_key.is_empty() and group_key == _last_undo_key and now_usec - _last_undo_usec < 500000:
		_last_undo_usec = now_usec
		return
	_undo_stack.append(_current_params.duplicate(true))
	if _undo_stack.size() > 64:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_last_undo_key = group_key
	_last_undo_usec = now_usec


func _queue_preview_render() -> void:
	if _preview_render_queued:
		return
	_preview_render_queued = true
	call_deferred("_flush_preview_render")


func _flush_preview_render() -> void:
	if not _preview_render_queued:
		return
	_preview_render_queued = false
	if is_inside_tree() and not _current_params.is_empty():
		_render_params(false)


func _on_undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_current_params.duplicate(true))
	_current_params = _undo_stack.pop_back()
	_suppress_undo = true
	_seed_spin.value = int(_current_params.get("seed", 1))
	_sync_ui_from_params()
	_render_params(false)
	_suppress_undo = false


func _on_redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_current_params.duplicate(true))
	_current_params = _redo_stack.pop_back()
	_suppress_undo = true
	_seed_spin.value = int(_current_params.get("seed", 1))
	_sync_ui_from_params()
	_render_params(false)
	_suppress_undo = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.ctrl_pressed and key_event.keycode == KEY_Z:
		_on_undo()
		get_viewport().set_input_as_handled()
	elif key_event.ctrl_pressed and key_event.keycode == KEY_Y:
		_on_redo()
		get_viewport().set_input_as_handled()


func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(int(_seed_spin.value)))
	_status.text = "Copied seed %d." % int(_seed_spin.value)


func _on_paste_seed() -> void:
	var text: String = DisplayServer.clipboard_get().strip_edges()
	if not text.is_valid_int():
		_status.text = "Clipboard does not contain a valid seed."
		return
	var pasted_seed: int = clampi(text.to_int(), 1, 2147483646)
	_seed_spin.value = pasted_seed
	if _is_extension_generator_active():
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			if not _current_params.is_empty():
				_current_params["seed"] = pasted_seed
			_status.text = "Generator extension '%s' is missing or disabled. Seed was preserved without rendering." % str(_active_extension_generator_id())
			return
		if _current_params.is_empty():
			_current_params = _extension_default_params(extension, _selected_category(), pasted_seed)
		else:
			_current_params["seed"] = pasted_seed
		_render_params(false)
		return
	var preserved_wave: String = str(_current_layer().get("wave", "")) if not _current_params.is_empty() else ""
	_generate_current(false)
	if not preserved_wave.is_empty() and _profile_supports_wave(preserved_wave):
		_current_layer()["wave"] = preserved_wave
		_refresh_layer_controls()
		_render_params(false)


func _on_favorite_seed() -> void:
	var seed: int = int(_seed_spin.value)
	if not _favorite_seeds.has(seed):
		_favorite_seeds.append(seed)
	_status.text = "Favorited seed %d." % seed


func _on_previous_seed() -> void:
	if _seed_history.size() < 2:
		return
	_seed_history.pop_back()
	var seed: int = int(_seed_history.back())
	_seed_spin.value = seed
	_generate_current(false)


func _on_use_favorite_seed() -> void:
	if _favorite_seeds.is_empty():
		_status.text = "No favorite seeds yet."
		return
	var current: int = int(_seed_spin.value)
	var index: int = _favorite_seeds.find(current)
	index = (index + 1) % _favorite_seeds.size()
	_seed_spin.value = int(_favorite_seeds[index])
	_generate_current(false)


func _on_send_to_timeline() -> void:
	if _current_result.is_empty():
		return
	var stream_value: Variant = _current_result.get("stream", null)
	var wav: AudioStreamWAV = stream_value as AudioStreamWAV
	if wav == null:
		_status.text = "Current generated result is not a WAV stream."
		return
	_timeline_queue.append({"params": _current_params.duplicate(true), "result": _current_result})
	var queue_label: Label = find_child("TimelineQueueStatus", true, false) as Label
	if queue_label != null:
		queue_label.text = "Sent to editor: %d" % _timeline_queue.size()
	var suggested_name: String = "%s_%s_%d" % [_file_stem(_selected_profile()), _file_stem(_selected_category()), int(_current_params.get("seed", 0))]
	send_to_audio_editor.emit(wav, suggested_name)
	_status.text = "Sent generated sound to Audio Editor."


func _on_clear_timeline_queue() -> void:
	_timeline_queue.clear()
	var queue_label: Label = find_child("TimelineQueueStatus", true, false) as Label
	if queue_label != null:
		queue_label.text = "Timeline queue: 0"


func _on_quick_save() -> void:
	if _current_result.is_empty():
		return
	var dir: String = "res://audio/generated"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var filename: String = _render_naming_template(_current_params, 1) + ".wav"
	var path: String = dir.path_join(filename)
	var wav: AudioStreamWAV = _current_result.get("stream") as AudioStreamWAV
	if wav != null:
		_apply_wav_tags(wav, _current_params)
	var pcm: GASPCMData = PCMData.from_wav(wav) if wav != null else null
	var bit_depth: int = 8 if wav != null and wav.format == AudioStreamWAV.FORMAT_8_BITS else 16
	if pcm != null and ExportEngine.save_wav(path, pcm, false, wav.mix_rate, false, bit_depth, wav.tags, wav.loop_begin, wav.loop_end, wav.loop_mode) == OK:
		_write_metadata_sidecar(path, _current_params)
		_refresh_exported_resources(PackedStringArray([path]))
		_status.text = "Saved directly to %s" % path


func _on_batch_export_variants() -> void:
	if _variant_results.is_empty():
		_status.text = "Generate variants first."
		return
	_batch_export_dialog.popup_file_dialog()


func _on_batch_export_dir_selected(dir_path: String) -> void:
	if _generator_export_job != null:
		_status.text = "A generated-audio export is already running."
		return
	var filenames: PackedStringArray = PackedStringArray()
	for i: int in range(_variant_results.size()):
		var result: Dictionary = _variant_results[i]
		var params: Dictionary = result.get("params", {}) as Dictionary
		filenames.append(_render_naming_template(params, i + 1) + ".wav")
	var job: GASGeneratorExportJob = GeneratorExportJob.new() as GASGeneratorExportJob
	if job != null and job.start(_variant_results, dir_path, filenames):
		_generator_export_job = job
		_status.text = "Exporting %d generated variants in background…" % _variant_results.size()


func _render_naming_template(params: Dictionary, index: int) -> String:
	var template: String = "{profile}_{category}_{index}_{seed}"
	if _naming_template_edit != null and not _naming_template_edit.text.strip_edges().is_empty():
		template = _naming_template_edit.text.strip_edges()
	var value: String = template
	value = value.replace("{profile}", _file_stem(str(params.get("profile", _selected_profile()))))
	value = value.replace("{category}", _file_stem(str(params.get("category", _selected_category()))))
	value = value.replace("{index}", "%02d" % index)
	value = value.replace("{seed}", str(int(params.get("seed", 0))))
	return _safe_filename(value)


func _safe_filename(value: String) -> String:
	var out: String = value.strip_edges()
	for forbidden: String in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		out = out.replace(forbidden, "_")
	while out.contains("__"):
		out = out.replace("__", "_")
	if out.is_empty():
		out = "generated_sound"
	return out


func _apply_wav_tags(wav: AudioStreamWAV, params: Dictionary) -> void:
	wav.tags = {
		"title": str(params.get("category", "Generated Sound")),
		"artist": "Gator Audio Studio",
		"comment": "Profile=%s; Seed=%d; Accuracy=%s" % [str(params.get("profile", "Modern")), int(params.get("seed", 0)), str(params.get("accuracy_mode", HardwareRules.MODE_STYLE))],
	}


func _write_metadata_sidecar(wav_path: String, params: Dictionary) -> void:
	var layers: Array[Dictionary] = _dictionary_array(params.get("layers", []))
	var metadata: Dictionary = {
		"gator_audio_studio": "1.0.0",
		"profile": str(params.get("profile", "Modern")),
		"category": str(params.get("category", "Generated")),
		"seed": int(params.get("seed", 0)),
		"accuracy_mode": str(params.get("accuracy_mode", HardwareRules.MODE_STYLE)),
		"layer_count": layers.size(),
		"generated_at": Time.get_datetime_string_from_system(),
		"source_wav": wav_path.get_file(),
	}
	var meta_path: String = wav_path.get_basename() + ".gasmeta.json"
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()


func _on_background_batch() -> void:
	_start_background_variant_batch(int(_batch_spin.value))


func _start_background_variant_batch(count: int, seed_stride: int = 104729) -> void:
	var safe_count: int = clampi(count, 1, 64)
	var batch_params: Array[Dictionary] = []
	var base_seed: int = int(_seed_spin.value)
	if _is_extension_generator_active():
		if _extension_group_id >= 0:
			_status.text = "An extension generation job is already running."
			return
		var extension: GASGeneratorExtension = _active_extension_generator()
		if extension == null:
			return
		for i: int in range(safe_count):
			var seed: int = base_seed + (i + 1) * seed_stride
			var amount: float = float(_mutation_slider.value) * (0.55 + float(i) / float(maxi(1, safe_count - 1)) * 0.8)
			var params: Dictionary = extension.mutate_params(_current_params, seed, amount)
			params["generator_extension_id"] = str(extension.get_generator_id())
			params["profile"] = extension.get_display_name()
			params["category"] = _selected_category()
			batch_params.append(params)
		_start_extension_generation(batch_params, "variants", false, "Extension generation complete: %d variants." % safe_count)
		return
	if _background_group_id >= 0:
		_status.text = "A background batch is already running."
		return
	for i: int in range(safe_count):
		var seed: int = base_seed + (i + 1) * seed_stride
		var amount: float = float(_mutation_slider.value) * (0.55 + float(i) / float(maxi(1, safe_count - 1)) * 0.8)
		batch_params.append(PresetBank.mutate(_current_params, seed, amount))
	_start_background_params(batch_params, "Background generation complete: %d new variants. Kept/favorites preserved." % safe_count)


func _start_background_params(batch_params: Array[Dictionary], completion_text: String) -> void:
	if _background_group_id >= 0 or batch_params.is_empty():
		return
	_background_job = BatchGenerator.new() as GASBatchGenerator
	_background_job.configure(batch_params)
	_background_completion_text = completion_text
	_background_group_id = WorkerThreadPool.add_group_task(_background_job.render_index, batch_params.size(), -1, false, "GAS variant generation")
	_status.text = "Generating %d variants in background…" % batch_params.size()


func _process(_delta: float) -> void:
	_process_editor_import_queue()
	_process_generator_export()
	_process_extension_generation()
	if _extension_revision != ExtensionManager.revision():
		_extension_revision = ExtensionManager.revision()
		refresh_extensions()
	if _background_group_id < 0:
		return
	if WorkerThreadPool.is_group_task_completed(_background_group_id):
		WorkerThreadPool.wait_for_group_task_completion(_background_group_id)
		_background_group_id = -1
		_variant_results.clear()
		var finished_results: Array[Dictionary] = []
		if _background_job != null:
			finished_results = _background_job.get_results()
		for result: Dictionary in finished_results:
			if not result.is_empty():
				_variant_results.append(result)
		_background_job = null
		if _selected_variant_source == "generated":
			_selected_variant_index = -1
			_selected_variant_source = ""
			_selected_variant_params.clear()
			_selected_variant_result.clear()
		_set_variant_button_count(mini(24, maxi(1, _variant_results.size())))
		_refresh_generated_variant_labels()
		_status.text = _background_completion_text if not _background_completion_text.is_empty() else "Background generation complete."
		_background_completion_text = ""
		if _voice_export_after_generate:
			_voice_export_after_generate = false
			if _batch_export_dialog != null:
				_batch_export_dialog.popup_file_dialog()


func _process_generator_export() -> void:
	if _generator_export_job == null or not _generator_export_job.is_complete():
		return
	var completed: GASGeneratorExportJob = _generator_export_job
	_generator_export_job = null
	var exported_paths: PackedStringArray = completed.finish()
	_refresh_exported_resources(exported_paths)
	_status.text = "Batch exported %d generated variants." % exported_paths.size()


func _on_graph_add_node() -> void:
	if _graph_type_option == null or _graph_type_option.selected < 0:
		return
	var node_type: String = _graph_type_option.get_item_text(_graph_type_option.selected)
	var new_id: int = SoundGraph.add_node(_graph, node_type)
	var nodes: Array[Dictionary] = _dictionary_array(_graph.get("nodes", []))
	if nodes.size() >= 2:
		var previous: Dictionary = nodes[nodes.size() - 2]
		SoundGraph.connect_nodes(_graph, int(previous.get("id", 0)), new_id)
	_refresh_graph_ui()


func _on_graph_remove_node() -> void:
	if _graph_node_option == null or _graph_node_option.selected < 0:
		return
	var id: int = _graph_node_option.get_item_id(_graph_node_option.selected)
	SoundGraph.remove_node(_graph, id)
	_refresh_graph_ui()


func _on_graph_node_selected(index: int) -> void:
	if index < 0 or _graph_params_edit == null:
		return
	var node_id: int = _graph_node_option.get_item_id(index)
	var nodes: Array[Dictionary] = _dictionary_array(_graph.get("nodes", []))
	for node: Dictionary in nodes:
		if int(node.get("id", -1)) == node_id:
			_graph_params_edit.text = JSON.stringify(node.get("params", {}))
			return


func _on_graph_apply_params() -> void:
	if _graph_node_option.selected < 0 or _graph_params_edit == null:
		return
	var json: JSON = JSON.new()
	if json.parse(_graph_params_edit.text) != OK or not (json.data is Dictionary):
		_status.text = "Graph node parameters must be a valid JSON object."
		return
	var node_id: int = _graph_node_option.get_item_id(_graph_node_option.selected)
	var nodes: Array[Dictionary] = _dictionary_array(_graph.get("nodes", []))
	for i: int in range(nodes.size()):
		var node: Dictionary = nodes[i]
		if int(node.get("id", -1)) == node_id:
			node["params"] = (json.data as Dictionary).duplicate(true)
			nodes[i] = node
			break
	_graph["nodes"] = nodes
	_refresh_graph_ui()
	_status.text = "Graph node parameters updated."


func _on_graph_compile() -> void:
	_push_undo()
	_current_params = SoundGraph.compile_to_params(_graph, _current_params)
	_current_params["seed"] = int(_seed_spin.value)
	_sync_ui_from_params()
	_render_params(true)


func _on_graph_reset() -> void:
	_graph = SoundGraph.new_graph()
	_refresh_graph_ui()


func _refresh_graph_ui() -> void:
	if _graph_tree == null or _graph_node_option == null:
		return
	_graph_tree.clear()
	_graph_node_option.clear()
	var root: TreeItem = _graph_tree.create_item()
	var nodes: Array[Dictionary] = _dictionary_array(_graph.get("nodes", []))
	for node: Dictionary in nodes:
		var item: TreeItem = _graph_tree.create_item(root)
		item.set_text(0, str(int(node.get("id", 0))))
		item.set_text(1, str(node.get("type", "Node")))
		item.set_text(2, JSON.stringify(node.get("params", {})))
		_graph_node_option.add_item("%d: %s" % [int(node.get("id", 0)), str(node.get("type", "Node"))], int(node.get("id", 0)))
	if _graph_node_option.get_item_count() > 0:
		_graph_node_option.select(_graph_node_option.get_item_count() - 1)
		_on_graph_node_selected(_graph_node_option.selected)


func _profile_supports_wave(wave_name: String) -> bool:
	var profile: Dictionary = RetroProfiles.get_profile(_selected_profile())
	for wave_value: Variant in Array(profile.get("waveforms", [])):
		var wave: String = str(wave_value)
		if str(wave) == wave_name:
			return true
	if _selected_profile() == RetroProfiles.MODERN and wave_name in ["Custom Wavetable", "FM4 Advanced", "Sample PCM"]:
		return true
	return false


func _file_stem(value: String) -> String:
	var out: String = value.to_lower().replace(" / ", "_").replace("/", "_").replace(" ", "_").replace("-", "_").replace(":", "_")
	while out.contains("__"):
		out = out.replace("__", "_")
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	return out
