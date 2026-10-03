@tool
class_name GatorSpriteTileset
extends Resource

@export var tile_size: Vector2i = Vector2i(16, 16)
@export var source_png: PackedByteArray = PackedByteArray()

func set_source_image(source_image: Image) -> void:
	source_png = source_image.save_png_to_buffer()

func get_source_image() -> Image:
	var source_image: Image = Image.new()
	if not source_png.is_empty() and source_image.load_png_from_buffer(source_png) == OK:
		return source_image
	return Image.new()

func get_columns() -> int:
	var source_image: Image = get_source_image()
	return maxi(1, source_image.get_width() / maxi(1, tile_size.x))

func get_tile_count() -> int:
	var source_image: Image = get_source_image()
	return get_columns() * maxi(1, source_image.get_height() / maxi(1, tile_size.y))
