@tool
class_name GASTrackDragPanel
extends PanelContainer

signal reorder_requested(from_index: int, to_index: int)

var track_index: int = -1


func setup(index: int) -> void:
	track_index = index


func _get_drag_data(_at_position: Vector2) -> Variant:
	if track_index < 0:
		return null
	var preview: Label = Label.new()
	preview.text = "Move Track %d" % (track_index + 1)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {"gas_track_reorder": track_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var dictionary: Dictionary = data as Dictionary
	return dictionary.has("gas_track_reorder") and int(dictionary.get("gas_track_reorder", -1)) >= 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var dictionary: Dictionary = data as Dictionary
	var from_index: int = int(dictionary.get("gas_track_reorder", -1))
	if from_index >= 0 and track_index >= 0 and from_index != track_index:
		reorder_requested.emit(from_index, track_index)
