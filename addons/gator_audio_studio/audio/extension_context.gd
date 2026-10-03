@tool
class_name GASExtensionContext
extends RefCounted

var _owner_id: StringName = &""
var _registration_open: bool = false
var _registration_errors: PackedStringArray = PackedStringArray()


func _init(owner_id: StringName = &"") -> void:
	_owner_id = owner_id


func get_extension_id() -> StringName:
	return _owner_id


func register_editor_effect(script: GDScript) -> bool:
	if not _registration_open:
		_registration_errors.append("Editor effect registration attempted outside register_components().")
		return false
	var registered: bool = GASExtensionAPI.register_editor_effect_owned(_owner_id, script)
	if not registered:
		_registration_errors.append("Failed to register editor effect: %s" % _script_label(script))
	return registered


func register_generator(script: GDScript) -> bool:
	if not _registration_open:
		_registration_errors.append("Generator registration attempted outside register_components().")
		return false
	var registered: bool = GASExtensionAPI.register_generator_extension_owned(_owner_id, script)
	if not registered:
		_registration_errors.append("Failed to register generator: %s" % _script_label(script))
	return registered


func register_analyzer(script: GDScript) -> bool:
	if not _registration_open:
		_registration_errors.append("Analyzer registration attempted outside register_components().")
		return false
	var registered: bool = GASExtensionAPI.register_analyzer_extension_owned(_owner_id, script)
	if not registered:
		_registration_errors.append("Failed to register analyzer: %s" % _script_label(script))
	return registered


func registration_errors() -> PackedStringArray:
	return _registration_errors.duplicate()


func has_registration_errors() -> bool:
	return not _registration_errors.is_empty()


func _open_registration() -> void:
	_registration_errors.clear()
	_registration_open = true


func _close_registration() -> void:
	_registration_open = false


func _script_label(script: GDScript) -> String:
	if script == null:
		return "<null script>"
	var path: String = script.resource_path
	return path if not path.is_empty() else "<unnamed GDScript>"
