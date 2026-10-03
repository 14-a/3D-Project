@tool
class_name GatorSpriteCel
extends Resource

@export var png_bytes: PackedByteArray = PackedByteArray()
@export var duration: float = 1.0

var cached_image: Image


func set_image(source_image: Image) -> void:
	png_bytes = source_image.save_png_to_buffer()
	cached_image = source_image.duplicate()


func get_image(fallback_size: Vector2i) -> Image:
	return get_image_reference(fallback_size).duplicate()


func get_image_reference(fallback_size: Vector2i) -> Image:
	if cached_image != null and not cached_image.is_empty():
		return cached_image
	var result_image: Image = Image.new()
	if not png_bytes.is_empty() and result_image.load_png_from_buffer(png_bytes) == OK:
		cached_image = result_image
	else:
		cached_image = Image.create_empty(fallback_size.x, fallback_size.y, false, Image.FORMAT_RGBA8)
	return cached_image
