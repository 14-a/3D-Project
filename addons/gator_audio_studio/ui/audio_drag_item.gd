@tool
class_name GASAudioDragItem
extends Button

var wav: AudioStreamWAV
var suggested_name: String = "Generated"


func setup(stream: AudioStreamWAV, display_name: String) -> void:
	wav = stream
	suggested_name = display_name
	text = display_name
	tooltip_text = "Drag this generated sound onto an Audio Editor track."


func _get_drag_data(_at_position: Vector2) -> Variant:
	if wav == null:
		return null
	var preview: Label = Label.new()
	preview.text = suggested_name
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {
		"type": "gas_generated_audio",
		"wav": wav,
		"name": suggested_name,
	}
