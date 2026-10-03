@tool
class_name GMSExtensionAPI
extends RefCounted

const API_VERSION: int = 1
var extension_id: String = ""
var _host_version: String = ""


func _init(owner_extension_id: String = "", host_version: String = "") -> void:
	extension_id = owner_extension_id.strip_edges().to_lower()
	_host_version = host_version.strip_edges()


func register_modelling_tool(descriptor: Dictionary) -> Error:
	return GMSModelToolRegistry.register_tool(extension_id, descriptor)


func register_modifier(descriptor: Dictionary) -> Error:
	return GMSModifierRegistry.register_modifier(extension_id, descriptor)


func register_importer(descriptor: Dictionary) -> Error:
	return GMSImporterRegistry.register_importer(extension_id, descriptor)


func register_exporter(descriptor: Dictionary) -> Error:
	return GMSExporterRegistry.register_exporter(extension_id, descriptor)


func unregister_all() -> void:
	GMSModelToolRegistry.unregister_owner(extension_id)
	GMSModifierRegistry.unregister_owner(extension_id)
	GMSImporterRegistry.unregister_owner(extension_id)
	GMSExporterRegistry.unregister_owner(extension_id)


func get_extension_id() -> String:
	return extension_id


func get_api_version() -> int:
	return API_VERSION


func get_host_version() -> String:
	return _host_version
