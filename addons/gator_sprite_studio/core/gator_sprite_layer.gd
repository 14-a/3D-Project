@tool
class_name GatorSpriteLayer
extends Resource

enum LayerType { PIXEL, REFERENCE }
enum BlendMode { NORMAL, MULTIPLY, SCREEN, ADD, SUBTRACT, OVERLAY, DARKEN, LIGHTEN }

@export var layer_title: String = "Layer"
@export var visible: bool = true
@export var locked: bool = false
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0
@export var group_title: String = ""
@export var cels: Array[GatorSpriteCel] = []
@export var layer_type: LayerType = LayerType.PIXEL
@export var blend_mode: BlendMode = BlendMode.NORMAL
@export var reference_source_path: String = ""
@export var reference_position: Vector2 = Vector2.ZERO
@export var reference_scale: Vector2 = Vector2.ONE
@export_range(-360.0, 360.0, 0.1) var reference_rotation_degrees: float = 0.0
@export var exclude_from_export: bool = false

func ensure_cel(frame_index: int, canvas_size: Vector2i) -> GatorSpriteCel:
	var resolved_frame_index: int = 0 if layer_type == LayerType.REFERENCE else maxi(0, frame_index)
	while cels.size() <= resolved_frame_index:
		var blank_cel: GatorSpriteCel = GatorSpriteCel.new()
		blank_cel.set_image(Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8))
		cels.append(blank_cel)
	return cels[resolved_frame_index]

func is_reference_layer() -> bool:
	return layer_type == LayerType.REFERENCE
