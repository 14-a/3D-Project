@tool
extends GASExtension

const ArcadeLaserGenerator: GDScript = preload("arcade_laser_generator.gd")
const EXTENSION_ID: StringName = &"com.blackwatergator.gas.example.arcade_laser"


func get_extension_id() -> StringName:
	return EXTENSION_ID


func get_extension_name() -> String:
	return "GAS Example - Arcade Laser Generator"


func get_version() -> String:
	return "1.0.0"


func get_author() -> String:
	return "Blackwater Gator Studios"


func get_description() -> String:
	return "Reference Generator extension demonstrating the complete GAS procedural-generator extension workflow."


func register_components(context: GASExtensionContext) -> void:
	context.register_generator(ArcadeLaserGenerator)


func on_loaded(_context: GASExtensionContext) -> void:
	pass


func on_unloaded(_context: GASExtensionContext) -> void:
	pass
