@tool
class_name GMSExtensionManifest
extends RefCounted

var manifest_path: String = ""
var extension_id: String = ""
var display_name: String = ""
var version: String = "0.0.0"
var author: String = ""
var description: String = ""
var entry_script: String = ""
var api_version: int = 1
var minimum_gms_version: String = "0.0.0"
var maximum_gms_version: String = ""
var minimum_godot_version: String = "4.0.0"
var enabled: bool = true


static func load_manifest(path: String) -> GMSExtensionManifest:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return null
	if not config.has_section("extension") or not config.has_section("compatibility"):
		return null
	if not config.has_section_key("extension", "id"):
		return null
	if not config.has_section_key("extension", "name"):
		return null
	if not config.has_section_key("extension", "version"):
		return null
	if not config.has_section_key("extension", "entry_script"):
		return null
	if not config.has_section_key("compatibility", "api_version"):
		return null

	var raw_id: String = str(config.get_value("extension", "id", "")).strip_edges()
	var manifest: GMSExtensionManifest = GMSExtensionManifest.new()
	manifest.manifest_path = path
	manifest.extension_id = raw_id.to_lower()
	manifest.display_name = str(config.get_value("extension", "name", "")).strip_edges()
	manifest.version = str(config.get_value("extension", "version", "")).strip_edges()
	manifest.author = str(config.get_value("extension", "author", "")).strip_edges()
	manifest.description = str(config.get_value("extension", "description", "")).strip_edges()
	manifest.entry_script = str(config.get_value("extension", "entry_script", "")).strip_edges()
	manifest.api_version = int(config.get_value("compatibility", "api_version", 0))
	manifest.minimum_gms_version = str(config.get_value("compatibility", "minimum_gms_version", "0.0.0")).strip_edges()
	manifest.maximum_gms_version = str(config.get_value("compatibility", "maximum_gms_version", "")).strip_edges()
	manifest.minimum_godot_version = str(config.get_value("compatibility", "minimum_godot_version", "4.0.0")).strip_edges()
	manifest.enabled = bool(config.get_value("extension", "enabled", true))

	if raw_id != manifest.extension_id or not _is_valid_id(manifest.extension_id):
		return null
	if manifest.display_name.is_empty() or manifest.version.is_empty() or manifest.entry_script.is_empty():
		return null
	if manifest.api_version <= 0:
		return null
	return manifest


func get_directory() -> String:
	return manifest_path.get_base_dir()


func get_entry_path() -> String:
	if entry_script.begins_with("res://"):
		return entry_script
	return get_directory().path_join(entry_script)


func check_compatibility(host_version: String, host_api_version: int) -> String:
	if api_version != host_api_version:
		return "requires extension API %d, but Gator Model Studio provides API %d" % [api_version, host_api_version]
	if _compare_versions(host_version, minimum_gms_version) < 0:
		return "requires Gator Model Studio %s or newer" % minimum_gms_version
	if not maximum_gms_version.is_empty() and _compare_versions(host_version, maximum_gms_version) > 0:
		return "supports Gator Model Studio up to %s" % maximum_gms_version
	var current_godot: String = "%d.%d.%d" % [
		Engine.get_version_info().get("major", 0),
		Engine.get_version_info().get("minor", 0),
		Engine.get_version_info().get("patch", 0),
	]
	if _compare_versions(current_godot, minimum_godot_version) < 0:
		return "requires Godot %s or newer" % minimum_godot_version
	return ""


static func _compare_versions(a: String, b: String) -> int:
	var parts_a: PackedStringArray = a.split(".")
	var parts_b: PackedStringArray = b.split(".")
	var count: int = maxi(parts_a.size(), parts_b.size())
	for index: int in count:
		var value_a: int = _numeric_prefix(parts_a[index]) if index < parts_a.size() else 0
		var value_b: int = _numeric_prefix(parts_b[index]) if index < parts_b.size() else 0
		if value_a < value_b:
			return -1
		if value_a > value_b:
			return 1
	return 0


static func _numeric_prefix(value: String) -> int:
	return value.to_int()


static func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value.begins_with(".") or value.ends_with("."):
		return false
	for index: int in value.length():
		var code: int = value.unicode_at(index)
		var is_letter: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if not is_letter and not is_digit and code != 45 and code != 46 and code != 95:
			return false
	return true
