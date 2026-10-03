@tool
extends GatorSpriteExtension

## A command-and-panel extension. Load it from Gator Sprite Studio > Load Extension...

var edit_count: int = 0
var report_label: Label

func get_extension_manifest() -> Dictionary:
	return {"id": "gator_sprite_studio.sprite_report", "name": "Sprite Report Demo", "version": "1.0.0", "dependencies": PackedStringArray()}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	report_label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.register_panel("report", "Sprite Report", report_label)
	context.register_command("refresh_report", "Refresh Report", _refresh_report, true, "CTRL+SHIFT+R")

func on_document_ready(sprite_document: GatorSpriteDocument) -> void:
	_refresh_report()

func on_tool_changed(tool_mode: GatorCanvas.ToolMode) -> void:
	print("Gator Sprite Studio example extension: tool changed to %s." % GatorCanvas.ToolMode.keys()[tool_mode])

func on_pixels_changed(_sprite_document: GatorSpriteDocument, frame_index: int, layer_index: int) -> void:
	edit_count += 1
	_refresh_report()

func _refresh_report() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null:
		return
	var animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	report_label.text = "%s\\n%d x %d pixels\\n%d layer(s), %d frame(s)\\n%d committed edit(s)" % [sprite_document.document_title, sprite_document.canvas_size.x, sprite_document.canvas_size.y, sprite_document.layers.size(), animation.frame_count, edit_count]
	context.notify("Sprite Report refreshed.")
