@tool
class_name GatorSpriteExtension
extends RefCounted

var document_provider: Callable
var context: GatorSpriteExtensionContext

func get_extension_manifest() -> Dictionary:
	return {"id": "", "name": "Unnamed Extension", "version": "1.0.0", "dependencies": PackedStringArray()}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	context = extension_context

func on_document_ready(_sprite_document: GatorSpriteDocument) -> void:
	pass

func on_tool_changed(_tool_mode: GatorCanvas.ToolMode) -> void:
	pass

func on_pixels_changed(_sprite_document: GatorSpriteDocument, _frame_index: int, _layer_index: int) -> void:
	pass

func on_unloaded() -> void:
	pass

func before_edit(_edit_context: GatorSpriteEditContext) -> bool:
	return true

func modify_custom_brush_stamp(_source_image: Image, _source_anchor: Vector2i) -> Dictionary:
	return {}
