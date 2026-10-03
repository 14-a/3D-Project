@tool
class_name GASExtensionManager
extends RefCounted

const API_VERSION: int = 1
const GAS_VERSION: String = "1.0.0"
const INSTALLED_ROOT: String = "res://addons/gator_audio_studio/extensions/installed"
const MANIFEST_FILE: String = "manifest.json"
const STATE_FILE: String = "user://gator_audio_studio/extension_state.json"
const ExtensionContext: GDScript = preload("res://addons/gator_audio_studio/audio/extension_context.gd")

static var _loaded_extensions: Array[GASExtension] = []
static var _loaded_contexts: Array[GASExtensionContext] = []
static var _loaded_paths: PackedStringArray = PackedStringArray()
static var _records: Array[Dictionary] = []
static var _load_errors: PackedStringArray = PackedStringArray()
static var _enabled_overrides: Dictionary[StringName, bool] = {}
static var _revision: int = 0


static func revision() -> int:
	return _revision


static func reload_all() -> void:
	_unload_loaded_extensions()
	_load_errors.clear()
	_records.clear()
	_load_enabled_state()
	_ensure_installed_root()
	var child_names: PackedStringArray = _direct_child_directories(INSTALLED_ROOT)
	child_names.sort()
	var seen_ids: Dictionary[StringName, bool] = {}
	for folder_name: String in child_names:
		var folder_path: String = INSTALLED_ROOT.path_join(folder_name)
		var manifest_path: String = folder_path.path_join(MANIFEST_FILE)
		var record: Dictionary = _read_manifest_record(folder_name, folder_path, manifest_path)
		var extension_id: StringName = StringName(str(record.get("id", "")))
		if not str(extension_id).is_empty() and seen_ids.has(extension_id):
			record = _record_error(record, "Duplicate extension id '%s'." % str(extension_id))
		if not str(extension_id).is_empty():
			seen_ids[extension_id] = true
		var enabled: bool = bool(record.get("enabled_default", true))
		if _enabled_overrides.has(extension_id):
			enabled = _enabled_overrides[extension_id]
		record["enabled"] = enabled
		if str(record.get("status", "")) == "valid" and enabled:
			_load_record(record)
		elif str(record.get("status", "")) == "valid":
			record["status"] = "disabled"
		_records.append(record)
	_revision += 1


static func unload_all() -> void:
	_unload_loaded_extensions()
	_records.clear()
	_load_errors.clear()
	GASExtensionAPI.end_extension_registration()
	_revision += 1


static func _unload_loaded_extensions() -> void:
	for index: int in range(_loaded_extensions.size() - 1, -1, -1):
		var extension: GASExtension = _loaded_extensions[index]
		if extension == null:
			continue
		var context: GASExtensionContext = _loaded_contexts[index] if index < _loaded_contexts.size() else null
		var extension_id: StringName = extension.get_extension_id()
		extension.on_unloaded(context)
		GASExtensionAPI.unregister_owner(extension_id)
	_loaded_extensions.clear()
	_loaded_contexts.clear()
	_loaded_paths.clear()
	GASExtensionAPI.end_extension_registration()


static func set_extension_enabled(extension_id: StringName, enabled: bool) -> bool:
	if str(extension_id).is_empty():
		return false
	_enabled_overrides[extension_id] = enabled
	_save_enabled_state()
	reload_all()
	return true


static func is_extension_enabled(extension_id: StringName) -> bool:
	for record: Dictionary in _records:
		if StringName(str(record.get("id", ""))) == extension_id:
			return bool(record.get("enabled", false))
	return false


static func loaded_count() -> int:
	return _loaded_extensions.size()


static func load_errors() -> PackedStringArray:
	return _load_errors.duplicate()


static func extension_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _records:
		rows.append(record.duplicate(true))
	return rows


static func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("GAS Extension System • API %d" % API_VERSION)
	lines.append("")
	lines.append("Installed root:")
	lines.append("  • %s" % INSTALLED_ROOT)
	lines.append("")
	lines.append("Installed packages: %d • Loaded: %d" % [_records.size(), loaded_count()])
	for record: Dictionary in _records:
		var status: String = str(record.get("status", "unknown"))
		var enabled_text: String = "enabled" if bool(record.get("enabled", false)) else "disabled"
		var author: String = str(record.get("author", ""))
		var author_text: String = "" if author.is_empty() else " • " + author
		lines.append("  • %s %s%s [%s] • %s/%s" % [
			str(record.get("name", record.get("id", "Extension"))),
			str(record.get("version", "")),
			author_text,
			str(record.get("id", "")),
			enabled_text,
			status,
		])
		var error_text: String = str(record.get("error", ""))
		if not error_text.is_empty():
			lines.append("      %s" % error_text)
	lines.append("")
	lines.append("Registered components:")
	lines.append("  • Editor effects: %d" % GASExtensionAPI.editor_effect_ids().size())
	lines.append("  • Generators: %d" % GASExtensionAPI.generator_extension_ids().size())
	lines.append("  • Analyzers: %d" % GASExtensionAPI.analyzer_extension_ids().size())
	return "\n".join(lines)


static func _read_manifest_record(folder_name: String, folder_path: String, manifest_path: String) -> Dictionary:
	var record: Dictionary = {
		"id": folder_name,
		"name": folder_name,
		"version": "",
		"author": "",
		"description": "",
		"api_version": 0,
		"min_gas_version": "",
		"max_gas_version": "",
		"min_godot_version": "",
		"entry": "extension.gd",
		"capabilities": PackedStringArray(),
		"folder": folder_path,
		"manifest": manifest_path,
		"enabled_default": true,
		"enabled": true,
		"status": "error",
		"error": "",
	}
	if not FileAccess.file_exists(manifest_path):
		return _record_error(record, "%s is missing." % MANIFEST_FILE)
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(FileAccess.get_file_as_string(manifest_path))
	if parse_error != OK or not (json.data is Dictionary):
		return _record_error(record, "Manifest is not valid JSON object data.")
	var manifest: Dictionary = json.data as Dictionary
	var required: PackedStringArray = PackedStringArray(["id", "name", "version", "api_version", "min_gas_version", "min_godot_version", "capabilities", "entry"])
	for key: String in required:
		if not manifest.has(key):
			return _record_error(record, "Manifest is missing required field '%s'." % key)
	var id_text: String = str(manifest.get("id", "")).strip_edges()
	if id_text.is_empty():
		return _record_error(record, "Manifest id cannot be empty.")
	if id_text != id_text.to_lower():
		return _record_error(record, "Manifest id must be lowercase.")
	if folder_name != id_text:
		return _record_error(record, "Folder name must exactly match manifest id '%s'." % id_text)
	if not _valid_package_id(id_text):
		return _record_error(record, "Manifest id may contain only lowercase letters, digits, '.', '_' and '-'.")
	record["id"] = id_text
	record["name"] = str(manifest.get("name", id_text)).strip_edges()
	record["version"] = str(manifest.get("version", "")).strip_edges()
	record["author"] = str(manifest.get("author", "")).strip_edges()
	record["description"] = str(manifest.get("description", "")).strip_edges()
	record["api_version"] = int(manifest.get("api_version", 0))
	record["min_gas_version"] = str(manifest.get("min_gas_version", "")).strip_edges()
	record["max_gas_version"] = str(manifest.get("max_gas_version", "")).strip_edges()
	record["min_godot_version"] = str(manifest.get("min_godot_version", "")).strip_edges()
	record["entry"] = str(manifest.get("entry", "extension.gd")).strip_edges()
	record["enabled_default"] = bool(manifest.get("enabled", true))
	var capabilities_value: Variant = manifest.get("capabilities", [])
	var capabilities: PackedStringArray = PackedStringArray()
	if capabilities_value is PackedStringArray:
		capabilities = capabilities_value as PackedStringArray
	elif capabilities_value is Array:
		var capabilities_array: Array = capabilities_value as Array
		for value: Variant in capabilities_array:
			capabilities.append(str(value))
	record["capabilities"] = capabilities
	if capabilities.is_empty():
		return _record_error(record, "Manifest must declare at least one GAS capability.")
	var allowed_capabilities: PackedStringArray = PackedStringArray(["editor_effects", "generators", "analyzers"])
	for capability: String in capabilities:
		if not allowed_capabilities.has(capability):
			return _record_error(record, "Unknown capability '%s'." % capability)
	if str(record["name"]).is_empty():
		return _record_error(record, "Manifest name cannot be empty.")
	if str(record["version"]).is_empty():
		return _record_error(record, "Manifest version cannot be empty.")
	if int(record["api_version"]) != API_VERSION:
		return _record_error(record, "Requires GAS extension API %d; this build provides API %d." % [int(record["api_version"]), API_VERSION])
	var min_gas: String = str(record["min_gas_version"])
	if min_gas.is_empty():
		return _record_error(record, "Manifest min_gas_version cannot be empty.")
	if _compare_versions(GAS_VERSION, min_gas) < 0:
		return _record_error(record, "Requires GAS %s or newer." % min_gas)
	var max_gas: String = str(record["max_gas_version"])
	if not max_gas.is_empty() and _compare_versions(GAS_VERSION, max_gas) > 0:
		return _record_error(record, "Supports GAS through %s." % max_gas)
	var min_godot: String = str(record["min_godot_version"])
	if min_godot.is_empty():
		return _record_error(record, "Manifest min_godot_version cannot be empty.")
	if _compare_versions(_godot_version_string(), min_godot) < 0:
		return _record_error(record, "Requires Godot %s or newer." % min_godot)
	var entry: String = str(record["entry"])
	if entry.is_empty() or entry.begins_with("/") or entry.begins_with("res://") or entry.begins_with("user://") or entry.contains(".."):
		return _record_error(record, "Manifest entry must be a relative script path inside the package.")
	if not entry.ends_with(".gd"):
		return _record_error(record, "Manifest entry must point to a GDScript (.gd) file.")
	var entry_path: String = folder_path.path_join(entry).simplify_path()
	if not entry_path.begins_with(folder_path + "/") and entry_path != folder_path:
		return _record_error(record, "Manifest entry resolves outside the package folder.")
	if not FileAccess.file_exists(entry_path):
		return _record_error(record, "Entry script does not exist: %s" % entry)
	record["entry_path"] = entry_path
	record["status"] = "valid"
	return record


static func _load_record(record: Dictionary) -> void:
	var entry_path: String = str(record.get("entry_path", ""))
	var resource: Resource = ResourceLoader.load(entry_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var script: GDScript = resource as GDScript
	if script == null:
		_mark_load_error(record, "Could not load entry script.")
		return
	if not script.can_instantiate():
		script.reload(true)
	if not script.can_instantiate():
		_mark_load_error(record, "Entry script cannot be instantiated.")
		return
	var created: Object = script.new()
	var extension: GASExtension = created as GASExtension
	if extension == null:
		_mark_load_error(record, "Entry script must extend GASExtension.")
		return
	var manifest_id: StringName = StringName(str(record.get("id", "")))
	if extension.get_extension_id() != manifest_id:
		_mark_load_error(record, "Entry get_extension_id() must match manifest id '%s'." % str(manifest_id))
		return
	if extension.get_extension_name() != str(record.get("name", "")):
		_mark_load_error(record, "Entry get_extension_name() must match manifest name.")
		return
	if extension.get_version() != str(record.get("version", "")):
		_mark_load_error(record, "Entry get_version() must match manifest version.")
		return
	var context: GASExtensionContext = ExtensionContext.new(manifest_id) as GASExtensionContext
	if context == null:
		_mark_load_error(record, "Could not create extension context.")
		return
	context._open_registration()
	GASExtensionAPI.begin_extension_registration(manifest_id)
	extension.register_components(context)
	GASExtensionAPI.end_extension_registration()
	context._close_registration()
	if context.has_registration_errors():
		var registration_errors: PackedStringArray = context.registration_errors()
		_mark_load_error(record, "; ".join(registration_errors))
		return
	var capability_error: String = _validate_registered_capabilities(record, manifest_id)
	if not capability_error.is_empty():
		_mark_load_error(record, capability_error)
		return
	extension.on_loaded(context)
	_loaded_extensions.append(extension)
	_loaded_contexts.append(context)
	_loaded_paths.append(entry_path)
	record["status"] = "loaded"
	record["error"] = ""


static func _validate_registered_capabilities(record: Dictionary, owner_id: StringName) -> String:
	var declared_value: Variant = record.get("capabilities", PackedStringArray())
	var declared: PackedStringArray = PackedStringArray()
	if declared_value is PackedStringArray:
		declared = declared_value as PackedStringArray
	var effect_count: int = GASExtensionAPI.editor_effect_ids_for_owner(owner_id).size()
	var generator_count: int = GASExtensionAPI.generator_extension_ids_for_owner(owner_id).size()
	var analyzer_count: int = GASExtensionAPI.analyzer_extension_ids_for_owner(owner_id).size()
	if effect_count > 0 and not declared.has("editor_effects"):
		return "Registers editor effects but manifest does not declare 'editor_effects'."
	if generator_count > 0 and not declared.has("generators"):
		return "Registers generators but manifest does not declare 'generators'."
	if analyzer_count > 0 and not declared.has("analyzers"):
		return "Registers analyzers but manifest does not declare 'analyzers'."
	if declared.has("editor_effects") and effect_count == 0:
		return "Manifest declares 'editor_effects' but no editor effects were registered."
	if declared.has("generators") and generator_count == 0:
		return "Manifest declares 'generators' but no generators were registered."
	if declared.has("analyzers") and analyzer_count == 0:
		return "Manifest declares 'analyzers' but no analyzers were registered."
	return ""


static func _mark_load_error(record: Dictionary, message: String) -> void:
	record["status"] = "error"
	record["error"] = message
	_load_errors.append("%s: %s" % [str(record.get("id", record.get("folder", "extension"))), message])
	var owner_id: StringName = StringName(str(record.get("id", "")))
	if not str(owner_id).is_empty():
		GASExtensionAPI.unregister_owner(owner_id)
	GASExtensionAPI.end_extension_registration()


static func _record_error(record: Dictionary, message: String) -> Dictionary:
	record["status"] = "error"
	record["error"] = message
	_load_errors.append("%s: %s" % [str(record.get("folder", "extension")), message])
	return record


static func _ensure_installed_root() -> void:
	var absolute: String = ProjectSettings.globalize_path(INSTALLED_ROOT)
	if not DirAccess.dir_exists_absolute(absolute):
		DirAccess.make_dir_recursive_absolute(absolute)


static func _direct_child_directories(root: String) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return output
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name.is_empty():
			break
		if name.begins_with(".") or not dir.current_is_dir():
			continue
		output.append(name)
	dir.list_dir_end()
	return output


static func _valid_package_id(value: String) -> bool:
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var valid: bool = (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 46 or code == 95 or code == 45
		if not valid:
			return false
	return true


static func _godot_version_string() -> String:
	var info: Dictionary = Engine.get_version_info()
	return "%d.%d.%d" % [int(info.get("major", 0)), int(info.get("minor", 0)), int(info.get("patch", 0))]


static func _compare_versions(left: String, right: String) -> int:
	var left_parts: PackedStringArray = left.split(".")
	var right_parts: PackedStringArray = right.split(".")
	var count: int = maxi(left_parts.size(), right_parts.size())
	for index: int in range(count):
		var left_value: int = _version_part(left_parts[index]) if index < left_parts.size() else 0
		var right_value: int = _version_part(right_parts[index]) if index < right_parts.size() else 0
		if left_value < right_value:
			return -1
		if left_value > right_value:
			return 1
	return 0


static func _version_part(value: String) -> int:
	var result: int = 0
	var found_digit: bool = false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if code < 48 or code > 57:
			break
		found_digit = true
		result = result * 10 + (code - 48)
	return result if found_digit else 0


static func _load_enabled_state() -> void:
	_enabled_overrides.clear()
	if not FileAccess.file_exists(STATE_FILE):
		return
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(STATE_FILE)) != OK or not (json.data is Dictionary):
		return
	var data: Dictionary = json.data as Dictionary
	for key: Variant in data.keys():
		_enabled_overrides[StringName(str(key))] = bool(data[key])


static func _save_enabled_state() -> void:
	var directory: String = STATE_FILE.get_base_dir()
	var absolute_directory: String = ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		DirAccess.make_dir_recursive_absolute(absolute_directory)
	var plain: Dictionary = {}
	for extension_id: StringName in _enabled_overrides:
		plain[str(extension_id)] = _enabled_overrides[extension_id]
	var file: FileAccess = FileAccess.open(STATE_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(plain, "\t"))
	file.close()
