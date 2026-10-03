@tool
class_name GASExtension
extends RefCounted


func get_extension_id() -> StringName:
	return &""


func get_extension_name() -> String:
	return "GAS Extension"


func get_version() -> String:
	return "1.0.0"


func get_author() -> String:
	return ""


func get_description() -> String:
	return ""


func register_components(_context: GASExtensionContext) -> void:
	pass


func on_loaded(_context: GASExtensionContext) -> void:
	pass


func on_unloaded(_context: GASExtensionContext) -> void:
	pass
