@tool
class_name GASEffectPresetStore
extends RefCounted

const USER_PATH: String = "user://gator_audio_studio/effect_presets.json"
const PROJECT_PATH: String = "res://.gator_audio_studio/effect_presets.json"


static func list_presets(effect_type: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	_append_scope(output, _load_path(USER_PATH), effect_type, "User")
	_append_scope(output, _load_path(PROJECT_PATH), effect_type, "Project")
	return output


static func save_user(effect: GASEffectData, name: String) -> Error:
	return _save_effect(USER_PATH, effect, name)


static func save_project(effect: GASEffectData, name: String) -> Error:
	return _save_effect(PROJECT_PATH, effect, name)


static func load_effect(scope: String, effect_type: String, name: String) -> GASEffectData:
	var path: String = USER_PATH if scope == "User" else PROJECT_PATH
	var root: Dictionary = _load_path(path)
	var type_value: Variant = root.get(effect_type, {})
	if not (type_value is Dictionary):
		return null
	var type_presets: Dictionary = type_value as Dictionary
	var preset_value: Variant = type_presets.get(name, {})
	if not (preset_value is Dictionary):
		return null
	var data: Dictionary = preset_value as Dictionary
	var effect: GASEffectData = GASEffectData.new()
	effect.effect_type = effect_type
	effect.enabled = bool(data.get("enabled", true))
	effect.wet = clampf(float(data.get("wet", 1.0)), 0.0, 1.0)
	effect.preset_name = name
	var params_value: Variant = data.get("params", {})
	effect.params = (params_value as Dictionary).duplicate(true) if params_value is Dictionary else {}
	return effect


static func _append_scope(output: Array[Dictionary], root: Dictionary, effect_type: String, scope: String) -> void:
	var type_value: Variant = root.get(effect_type, {})
	if not (type_value is Dictionary):
		return
	var type_presets: Dictionary = type_value as Dictionary
	var names: Array[String] = []
	for key: Variant in type_presets.keys():
		names.append(str(key))
	names.sort()
	for name: String in names:
		output.append({"scope": scope, "name": name})


static func _save_effect(path: String, effect: GASEffectData, name: String) -> Error:
	if effect == null:
		return ERR_INVALID_PARAMETER
	var clean_name: String = name.strip_edges()
	if clean_name.is_empty():
		return ERR_INVALID_PARAMETER
	var root: Dictionary = _load_path(path)
	var type_value: Variant = root.get(effect.effect_type, {})
	var type_presets: Dictionary = (type_value as Dictionary).duplicate(true) if type_value is Dictionary else {}
	type_presets[clean_name] = {
		"enabled": effect.enabled,
		"wet": effect.wet,
		"params": effect.params.duplicate(true),
	}
	root[effect.effect_type] = type_presets
	var global_path: String = ProjectSettings.globalize_path(path)
	var dir_path: String = global_path.get_base_dir()
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_error != OK:
		return dir_error
	var file: FileAccess = FileAccess.open(global_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(root, "\t"))
	file.close()
	return OK


static func _load_path(path: String) -> Dictionary:
	var global_path: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path):
		return {}
	var file: FileAccess = FileAccess.open(global_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
