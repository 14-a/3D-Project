@tool
extends GASExtension

const RetroRadioEffect: GDScript = preload("retro_radio_effect.gd")
const EXTENSION_ID: StringName = &"com.blackwatergator.gas.example.retro_radio"


func get_extension_id() -> StringName:
	return EXTENSION_ID


func get_extension_name() -> String:
	return "GAS Example - Retro Radio"


func get_version() -> String:
	return "1.0.3"


func get_author() -> String:
	return "Blackwater Gator Studios"


func get_description() -> String:
	return "Reference Audio Editor extension demonstrating a complete custom effect package."


func register_components(context: GASExtensionContext) -> void:
	context.register_editor_effect(RetroRadioEffect)


func on_loaded(_context: GASExtensionContext) -> void:
	pass


func on_unloaded(_context: GASExtensionContext) -> void:
	pass
