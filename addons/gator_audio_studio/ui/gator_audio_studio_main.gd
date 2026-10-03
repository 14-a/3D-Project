@tool
extends Control

const AUDIO_EDITOR_SCRIPT_PATH: String = "res://addons/gator_audio_studio/ui/audio_editor_workspace.gd"
const GENERATOR_SCRIPT_PATH: String = "res://addons/gator_audio_studio/ui/generator_workspace.gd"

var _workspace_tabs: TabContainer
var _audio_editor: Control
var _generator: Control
var _generator_placeholder: Control
var _pending_generator_state: Dictionary = {}
var _extensions_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_workspace()


func _build_workspace() -> void:
	_workspace_tabs = TabContainer.new()
	_workspace_tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_workspace_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workspace_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace_tabs.tabs_position = TabContainer.POSITION_TOP
	_workspace_tabs.tab_changed.connect(_on_workspace_tab_changed)
	add_child(_workspace_tabs)

	_audio_editor = _instantiate_control(AUDIO_EDITOR_SCRIPT_PATH)
	if _audio_editor == null:
		return
	_audio_editor.name = "Audio Editor"
	_audio_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_audio_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace_tabs.add_child(_audio_editor)

	_generator_placeholder = Control.new()
	_generator_placeholder.name = "Generator"
	_generator_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generator_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workspace_tabs.add_child(_generator_placeholder)

	Callable(_audio_editor, "set_project_state_bridge").call(
		Callable(self, "_get_generator_project_state"),
		Callable(self, "_apply_generator_project_state"),
		Callable(self, "_get_workspace_project_state"),
		Callable(self, "_apply_workspace_project_state")
	)
	_workspace_tabs.current_tab = 0

	_extensions_button = Button.new()
	_extensions_button.text = "Extensions"
	_extensions_button.tooltip_text = "Manage installed Gator Audio Studio extensions."
	_extensions_button.anchor_left = 1.0
	_extensions_button.anchor_right = 1.0
	_extensions_button.anchor_top = 0.0
	_extensions_button.anchor_bottom = 0.0
	_extensions_button.offset_left = -118.0
	_extensions_button.offset_right = -8.0
	_extensions_button.offset_top = 2.0
	_extensions_button.offset_bottom = 30.0
	_extensions_button.pressed.connect(_on_extensions_pressed)
	add_child(_extensions_button)
	move_child(_extensions_button, get_child_count() - 1)



func _on_extensions_pressed() -> void:
	if _audio_editor == null:
		return
	if _audio_editor.has_method("show_extensions_manager"):
		_audio_editor.call("show_extensions_manager")

func _instantiate_control(path: String) -> Control:
	var loaded: Resource = load(path)
	var script: GDScript = loaded as GDScript
	if script == null:
		push_error("Gator Audio Studio: could not load %s" % path)
		return null
	if not script.can_instantiate():
		script.reload(true)
	if not script.can_instantiate():
		push_error("Gator Audio Studio: could not instantiate %s" % path)
		return null
	var instance: Object = script.new()
	return instance as Control


func _ensure_generator() -> Control:
	if is_instance_valid(_generator):
		return _generator
	if _workspace_tabs == null:
		return null
	var generator: Control = _instantiate_control(GENERATOR_SCRIPT_PATH)
	if generator == null:
		return null
	var target_index: int = 1
	if is_instance_valid(_generator_placeholder):
		target_index = _generator_placeholder.get_index()
		_workspace_tabs.remove_child(_generator_placeholder)
		_generator_placeholder.queue_free()
	_generator_placeholder = null
	generator.name = "Generator"
	generator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_generator = generator
	_workspace_tabs.add_child(_generator)
	_workspace_tabs.move_child(_generator, clampi(target_index, 0, _workspace_tabs.get_child_count() - 1))
	var generator_tab_index: int = _generator.get_index()
	if generator_tab_index >= 0 and generator_tab_index < _workspace_tabs.get_tab_count():
		_workspace_tabs.set_tab_title(generator_tab_index, "Generator")
	if _generator.has_signal("send_to_audio_editor"):
		_generator.connect("send_to_audio_editor", _on_generator_send_to_editor)
	if _generator.has_signal("project_state_changed"):
		_generator.connect("project_state_changed", _on_generator_project_state_changed)
	if not _pending_generator_state.is_empty():
		Callable(_generator, "apply_project_state").call(_pending_generator_state)
		_pending_generator_state.clear()
	return _generator


func _on_workspace_tab_changed(index: int) -> void:
	if index != 1:
		return
	var generator: Control = _ensure_generator()
	if generator != null and _workspace_tabs.current_tab != 1:
		_workspace_tabs.current_tab = 1


func _on_generator_project_state_changed() -> void:
	if _audio_editor != null:
		Callable(_audio_editor, "mark_project_settings_dirty").call()


func _on_generator_send_to_editor(wav: AudioStreamWAV, suggested_name: String) -> void:
	if _audio_editor == null:
		return
	var generator_state: Dictionary = _get_generator_project_state()
	Callable(_audio_editor, "add_generated_wav").call(wav, suggested_name, generator_state)
	_workspace_tabs.current_tab = 0


func _get_generator_project_state() -> Dictionary:
	if _generator == null:
		return _pending_generator_state.duplicate(true)
	var state_value: Variant = Callable(_generator, "get_project_state").call()
	if state_value is Dictionary:
		return (state_value as Dictionary).duplicate(true)
	return {}


func _apply_generator_project_state(state: Dictionary) -> void:
	if _generator == null:
		_pending_generator_state = state.duplicate(true)
		return
	Callable(_generator, "apply_project_state").call(state)


func _get_workspace_project_state() -> Dictionary:
	return {"current_tab": _workspace_tabs.current_tab if _workspace_tabs != null else 0}


func _apply_workspace_project_state(state: Dictionary) -> void:
	if _workspace_tabs == null or _workspace_tabs.get_tab_count() <= 0:
		return
	var target: int = clampi(int(state.get("current_tab", 0)), 0, _workspace_tabs.get_tab_count() - 1)
	if target == 1:
		_ensure_generator()
	_workspace_tabs.current_tab = target
