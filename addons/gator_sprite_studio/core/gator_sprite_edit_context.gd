@tool
class_name GatorSpriteEditContext
extends RefCounted

var operation_name: String = ""
var frame_index: int = 0
var layer_index: int = 0
var pixel_position: Vector2i = Vector2i.ZERO
var is_cancelled: bool = false

func cancel() -> void:
	is_cancelled = true
