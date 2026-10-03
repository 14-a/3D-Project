@tool
class_name GMSExtensionLoader
extends RefCounted

const INSTALLED_EXTENSIONS_ROOT: String = "res://addons/gator_model_studio/extensions/installed"

var _loaded: Array[Dictionary] = []
var _messages: PackedStringArray = PackedStringArray()
var _host_version: String = ""


func _init(host_version: String = "") -> void:
	_host_version = host_version.strip_edges()


func load_all() -> PackedStringArray:
	unload_all()
	_messages.clear()
	var manifests: PackedStringArray = _find_manifests()
	for manifest_path: String in manifests:
		_load_manifest(manifest_path)
	return _messages.duplicate()


func unload_all() -> void:
	for index: int in range(_loaded.size() - 1, -1, -1):
		var record: Dictionary = _loaded[index]
		var instance: Object = record.get("instance") as Object
		var api: GMSExtensionAPI = record.get("api") as GMSExtensionAPI
		if instance != null and api != null and instance.has_method("unregister_extension"):
			instance.call("unregister_extension", api)
		if api != null:
			api.unregister_all()
	_loaded.clear()


func get_loaded_extensions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _loaded:
		var manifest: GMSExtensionManifest = record.get("manifest") as GMSExtensionManifest
		if manifest == null:
			continue
		result.append({
			"id": manifest.extension_id,
			"name": manifest.display_name,
			"version": manifest.version,
			"author": manifest.author,
		})
	return result


func _load_manifest(path: String) -> void:
	var manifest: GMSExtensionManifest = GMSExtensionManifest.load_manifest(path)
	if manifest == null:
		_messages.append("Skipped invalid extension manifest: %s" % path)
		return
	if not manifest.enabled:
		return
	var package_folder: String = manifest.get_directory().get_file()
	if package_folder != manifest.extension_id:
		_messages.append(
			"Skipped %s: package folder '%s' must match extension ID '%s'." % [
				manifest.display_name,
				package_folder,
				manifest.extension_id,
			]
		)
		return
	for loaded_record: Dictionary in _loaded:
		var loaded_manifest: GMSExtensionManifest = loaded_record.get("manifest") as GMSExtensionManifest
		if loaded_manifest != null and loaded_manifest.extension_id == manifest.extension_id:
			_messages.append("Skipped %s: extension ID %s is already loaded." % [manifest.display_name, manifest.extension_id])
			return
	var compatibility_error: String = manifest.check_compatibility(
		_host_version,
		GMSExtensionAPI.API_VERSION
	)
	if not compatibility_error.is_empty():
		_messages.append("Skipped %s: %s." % [manifest.display_name, compatibility_error])
		return
	var entry_path: String = manifest.get_entry_path()
	if not ResourceLoader.exists(entry_path):
		_messages.append("Skipped %s: entry script was not found at %s." % [manifest.display_name, entry_path])
		return
	var script_resource: Resource = load(entry_path)
	if not script_resource is Script:
		_messages.append("Skipped %s: entry_script is not a GDScript." % manifest.display_name)
		return
	var instance: Object = (script_resource as Script).new()
	if instance == null or not instance.has_method("register_extension"):
		_messages.append("Skipped %s: entry script does not implement register_extension(api)." % manifest.display_name)
		return
	var api: GMSExtensionAPI = GMSExtensionAPI.new(manifest.extension_id, _host_version)
	instance.call("register_extension", api)
	_loaded.append({"manifest": manifest, "instance": instance, "api": api})
	_messages.append("Loaded extension: %s %s" % [manifest.display_name, manifest.version])


func _find_manifests() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var directory: DirAccess = DirAccess.open(INSTALLED_EXTENSIONS_ROOT)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and directory.current_is_dir():
			var manifest_path: String = INSTALLED_EXTENSIONS_ROOT.path_join(entry).path_join("extension.cfg")
			if FileAccess.file_exists(manifest_path):
				result.append(manifest_path)
		entry = directory.get_next()
	directory.list_dir_end()
	result.sort()
	return result
