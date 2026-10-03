@tool
extends GatorSpriteExtension

## Official native .ase/.aseprite importer bundled with Gator Sprite Studio.
## Supports RGB, grayscale, and indexed image cels, palettes, layers, frame timing,
## linked cels, tags, slices, groups, and common blend modes. Tilemaps and unsupported blend modes are reported.

const ASE_FILE_MAGIC: int = 0xA5E0
const ASE_FRAME_MAGIC: int = 0xF1FA
const CHUNK_LAYER: int = 0x2004
const CHUNK_CEL: int = 0x2005
const CHUNK_TAGS: int = 0x2018
const CHUNK_PALETTE: int = 0x2019
const CHUNK_SLICE: int = 0x2022
const CHUNK_OLD_PALETTE: int = 0x0004
const CHUNK_OLD_PALETTE_6BIT: int = 0x0011

var source_color_depth: int = 32
var transparent_palette_index: int = 0
var imported_palette: PackedColorArray = PackedColorArray()
var pending_cels: Array[Dictionary] = []
var source_layer_map: Dictionary = {}
var source_layer_chunk_count: int = 0
var frame_durations: Array[int] = []
var import_warnings: Array[String] = []
var group_titles_by_level: Dictionary[int, String] = {}

func get_extension_manifest() -> Dictionary:
	return {"id": "gator_sprite_studio.aseprite_importer", "name": "Aseprite Importer", "version": "1.2.0", "dependencies": PackedStringArray()}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	context.register_command("import_aseprite", "Import Aseprite File...", _choose_aseprite_file, true, "CTRL+ALT+O")

func _choose_aseprite_file() -> void:
	context.show_open_file_dialog("Import Aseprite File", PackedStringArray(["*.ase, *.aseprite ; Aseprite Files"]), _import_selected_file)

func _import_selected_file(source_path: String) -> void:
	var imported_document: GatorSpriteDocument = _read_aseprite_file(source_path)
	if imported_document == null:
		return
	if context.replace_document(imported_document, source_path):
		var warning_text: String = "" if import_warnings.is_empty() else " Warnings: %s" % "; ".join(import_warnings)
		context.notify("Imported %s (%d frames, %d layers).%s" % [source_path.get_file(), imported_document.get_active_animation().frame_count, imported_document.layers.size(), warning_text], not import_warnings.is_empty())

func _read_aseprite_file(source_path: String) -> GatorSpriteDocument:
	_reset_import_state()
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		context.notify("Could not open the selected Aseprite file.", true)
		return null
	if source_file.get_length() < 128:
		context.notify("This file is too small to be an Aseprite document.", true)
		return null
	source_file.get_32()
	if source_file.get_16() != ASE_FILE_MAGIC:
		context.notify("This is not a valid .ase or .aseprite file.", true)
		return null
	var frame_count: int = source_file.get_16()
	var canvas_width: int = source_file.get_16()
	var canvas_height: int = source_file.get_16()
	source_color_depth = source_file.get_16()
	source_file.get_32()
	source_file.get_16()
	source_file.get_32()
	source_file.get_32()
	transparent_palette_index = source_file.get_8()
	source_file.seek(128)
	if frame_count <= 0 or canvas_width <= 0 or canvas_height <= 0 or not source_color_depth in [8, 16, 32]:
		context.notify("Unsupported Aseprite header or color mode.", true)
		return null
	var imported_document: GatorSpriteDocument = GatorSpriteDocument.new()
	imported_document.document_title = source_path.get_file().get_basename()
	imported_document.canvas_size = Vector2i(canvas_width, canvas_height)
	var imported_animation: GatorSpriteAnimation = GatorSpriteAnimation.new()
	imported_animation.animation_title = "default"
	imported_animation.frame_count = frame_count
	imported_document.animations = [imported_animation]
	for frame_index: int in range(frame_count):
		if not _read_frame(source_file, frame_index, imported_document):
			context.notify("Could not parse Aseprite frame %d." % (frame_index + 1), true)
			return null
	if imported_document.layers.is_empty():
		context.notify("The Aseprite file contains no normal image layers.", true)
		return null
	if not imported_palette.is_empty():
		imported_document.palette = imported_palette
		imported_document.indexed_color_mode = source_color_depth == 8
	_decode_pending_cels(imported_document)
	var total_duration: int = 0
	for frame_duration: int in frame_durations:
		total_duration += frame_duration
	if total_duration > 0:
		imported_animation.frames_per_second = clampf(float(frame_count) * 1000.0 / float(total_duration), 1.0, 120.0)
	return imported_document

func _read_frame(source_file: FileAccess, frame_index: int, imported_document: GatorSpriteDocument) -> bool:
	var frame_start: int = source_file.get_position()
	if source_file.get_length() - frame_start < 16:
		return false
	var frame_size: int = source_file.get_32()
	if source_file.get_16() != ASE_FRAME_MAGIC or frame_size < 16:
		return false
	var old_chunk_count: int = source_file.get_16()
	var frame_duration: int = source_file.get_16()
	source_file.get_buffer(2)
	var new_chunk_count: int = source_file.get_32()
	var chunk_count: int = new_chunk_count if new_chunk_count > 0 else old_chunk_count
	frame_durations.append(frame_duration)
	var frame_end: int = frame_start + frame_size
	for chunk_index: int in range(chunk_count):
		if source_file.get_position() + 6 > frame_end:
			return false
		var chunk_size: int = source_file.get_32()
		var chunk_type: int = source_file.get_16()
		var chunk_end: int = source_file.get_position() + chunk_size - 6
		if chunk_size < 6 or chunk_end > frame_end:
			return false
		match chunk_type:
			CHUNK_LAYER:
				_read_layer_chunk(source_file, imported_document)
			CHUNK_CEL:
				_read_cel_chunk(source_file, frame_index, chunk_end)
			CHUNK_TAGS:
				_read_tags_chunk(source_file, imported_document)
			CHUNK_PALETTE:
				_read_palette_chunk(source_file)
			CHUNK_OLD_PALETTE:
				_read_old_palette_chunk(source_file, false)
			CHUNK_OLD_PALETTE_6BIT:
				_read_old_palette_chunk(source_file, true)
			CHUNK_SLICE:
				_read_slice_chunk(source_file, imported_document)
		source_file.seek(chunk_end)
	source_file.seek(frame_end)
	return true

func _read_layer_chunk(source_file: FileAccess, imported_document: GatorSpriteDocument) -> void:
	var flags: int = source_file.get_16()
	var layer_type: int = source_file.get_16()
	var child_level: int = source_file.get_16()
	source_file.get_16()
	source_file.get_16()
	var blend_mode: int = source_file.get_16()
	var opacity: float = float(source_file.get_8()) / 255.0
	source_file.get_buffer(3)
	var layer_name: String = _read_string(source_file)
	var source_layer_index: int = source_layer_chunk_count
	source_layer_chunk_count += 1
	if layer_type == 1:
		var layer_group: GatorSpriteLayerGroup = GatorSpriteLayerGroup.new()
		layer_group.group_title = _make_unique_group_title(imported_document, layer_name if not layer_name.is_empty() else "Group")
		layer_group.visible = (flags & 1) != 0
		layer_group.locked = (flags & 2) == 0
		layer_group.opacity = opacity
		imported_document.layer_groups.append(layer_group)
		for known_level_variant: Variant in group_titles_by_level.keys():
			var known_level: int = int(known_level_variant)
			if known_level >= child_level:
				group_titles_by_level.erase(known_level)
		group_titles_by_level[child_level] = layer_group.group_title
		return
	if layer_type != 0:
		import_warnings.append("tilemap layer '%s' was skipped" % layer_name)
		return
	var mapped_blend_mode: int = _map_aseprite_blend_mode(blend_mode)
	if mapped_blend_mode < 0:
		import_warnings.append("unsupported blend mode on '%s' was changed to Normal" % layer_name)
		mapped_blend_mode = int(GatorSpriteLayer.BlendMode.NORMAL)
	var imported_layer: GatorSpriteLayer = GatorSpriteLayer.new()
	imported_layer.layer_title = layer_name if not layer_name.is_empty() else "Layer %d" % (imported_document.layers.size() + 1)
	imported_layer.visible = (flags & 1) != 0
	imported_layer.locked = (flags & 2) == 0
	imported_layer.opacity = opacity
	imported_layer.blend_mode = mapped_blend_mode
	if child_level > 0 and group_titles_by_level.has(child_level - 1):
		imported_layer.group_title = group_titles_by_level[child_level - 1]
	imported_document.layers.append(imported_layer)
	source_layer_map[source_layer_index] = imported_layer

func _map_aseprite_blend_mode(aseprite_blend_mode: int) -> int:
	match aseprite_blend_mode:
		0:
			return int(GatorSpriteLayer.BlendMode.NORMAL)
		1:
			return int(GatorSpriteLayer.BlendMode.MULTIPLY)
		2:
			return int(GatorSpriteLayer.BlendMode.SCREEN)
		3:
			return int(GatorSpriteLayer.BlendMode.OVERLAY)
		4:
			return int(GatorSpriteLayer.BlendMode.DARKEN)
		5:
			return int(GatorSpriteLayer.BlendMode.LIGHTEN)
		16:
			return int(GatorSpriteLayer.BlendMode.ADD)
		17:
			return int(GatorSpriteLayer.BlendMode.SUBTRACT)
		_:
			return -1

func _make_unique_group_title(imported_document: GatorSpriteDocument, requested_title: String) -> String:
	var base_title: String = requested_title.strip_edges()
	if base_title.is_empty():
		base_title = "Group"
	var unique_title: String = base_title
	var suffix: int = 2
	while imported_document.get_layer_group(unique_title) != null:
		unique_title = "%s (%d)" % [base_title, suffix]
		suffix += 1
	return unique_title

func _read_cel_chunk(source_file: FileAccess, frame_index: int, chunk_end: int) -> void:
	var source_layer_index: int = source_file.get_16()
	var cel_x: int = _signed_16(source_file.get_16())
	var cel_y: int = _signed_16(source_file.get_16())
	var cel_opacity: float = float(source_file.get_8()) / 255.0
	var cel_type: int = source_file.get_16()
	source_file.get_16()
	source_file.get_buffer(5)
	if not source_layer_map.has(source_layer_index):
		return
	var cel_data: Dictionary = {"layer": source_layer_index, "frame": frame_index, "x": cel_x, "y": cel_y, "opacity": cel_opacity, "type": cel_type}
	if cel_type == 1:
		cel_data["linked_frame"] = source_file.get_16()
		pending_cels.append(cel_data)
		return
	if cel_type != 0 and cel_type != 2:
		import_warnings.append("tilemap cel was skipped")
		return
	cel_data["width"] = source_file.get_16()
	cel_data["height"] = source_file.get_16()
	cel_data["pixels"] = source_file.get_buffer(chunk_end - source_file.get_position())
	pending_cels.append(cel_data)

func _read_tags_chunk(source_file: FileAccess, imported_document: GatorSpriteDocument) -> void:
	var tag_count: int = source_file.get_16()
	source_file.get_buffer(8)
	for tag_index: int in range(tag_count):
		var sprite_tag: GatorSpriteTag = GatorSpriteTag.new()
		sprite_tag.from_frame = source_file.get_16()
		sprite_tag.to_frame = source_file.get_16()
		source_file.get_8()
		source_file.get_16()
		source_file.get_buffer(6)
		sprite_tag.color = Color8(source_file.get_8(), source_file.get_8(), source_file.get_8(), 255)
		source_file.get_8()
		sprite_tag.tag_title = _read_string(source_file)
		imported_document.tags.append(sprite_tag)

func _read_palette_chunk(source_file: FileAccess) -> void:
	var palette_size: int = source_file.get_32()
	var first_index: int = source_file.get_32()
	var last_index: int = source_file.get_32()
	source_file.get_buffer(8)
	while imported_palette.size() < palette_size:
		imported_palette.append(Color.TRANSPARENT)
	for color_index: int in range(first_index, last_index + 1):
		var flags: int = source_file.get_16()
		var palette_color: Color = Color8(source_file.get_8(), source_file.get_8(), source_file.get_8(), source_file.get_8())
		if (flags & 1) != 0:
			_read_string(source_file)
		imported_palette[color_index] = palette_color

func _read_old_palette_chunk(source_file: FileAccess, use_6bit_color: bool) -> void:
	var packet_count: int = source_file.get_16()
	var palette_index: int = 0
	for packet_index: int in range(packet_count):
		palette_index += source_file.get_8()
		var color_count: int = source_file.get_8()
		if color_count == 0:
			color_count = 256
		while imported_palette.size() < palette_index + color_count:
			imported_palette.append(Color.TRANSPARENT)
		for color_offset: int in range(color_count):
			var red: int = source_file.get_8()
			var green: int = source_file.get_8()
			var blue: int = source_file.get_8()
			if use_6bit_color:
				red *= 4
				green *= 4
				blue *= 4
			imported_palette[palette_index + color_offset] = Color8(red, green, blue, 255)
		palette_index += color_count

func _read_slice_chunk(source_file: FileAccess, imported_document: GatorSpriteDocument) -> void:
	var key_count: int = source_file.get_32()
	var flags: int = source_file.get_32()
	source_file.get_32()
	var slice_name: String = _read_string(source_file)
	for key_index: int in range(key_count):
		source_file.get_32()
		var slice_x: int = _signed_32(source_file.get_32())
		var slice_y: int = _signed_32(source_file.get_32())
		var slice_width: int = source_file.get_32()
		var slice_height: int = source_file.get_32()
		if (flags & 1) != 0:
			source_file.get_buffer(16)
		var pivot: Vector2 = Vector2.ZERO
		if (flags & 2) != 0:
			pivot = Vector2(_signed_32(source_file.get_32()), _signed_32(source_file.get_32()))
		if key_index == 0:
			var sprite_slice: GatorSpriteSlice = GatorSpriteSlice.new()
			sprite_slice.slice_title = slice_name
			sprite_slice.rectangle = Rect2i(slice_x, slice_y, slice_width, slice_height)
			sprite_slice.pivot = pivot
			imported_document.slices.append(sprite_slice)

func _decode_pending_cels(imported_document: GatorSpriteDocument) -> void:
	var decoded_cels: Dictionary = {}
	for cel_data: Dictionary in pending_cels:
		var source_layer_index: int = int(cel_data["layer"])
		if not source_layer_map.has(source_layer_index):
			continue
		var imported_layer: GatorSpriteLayer = source_layer_map[source_layer_index] as GatorSpriteLayer
		var frame_index: int = int(cel_data["frame"])
		imported_layer.ensure_cel(frame_index, imported_document.canvas_size)
		var target_key: String = "%d:%d" % [source_layer_index, frame_index]
		if int(cel_data["type"]) == 1:
			var linked_key: String = "%d:%d" % [source_layer_index, int(cel_data["linked_frame"])]
			if decoded_cels.has(linked_key):
				var linked_cel: GatorSpriteCel = decoded_cels[linked_key] as GatorSpriteCel
				imported_layer.cels[frame_index] = linked_cel
				decoded_cels[target_key] = linked_cel
			else:
				import_warnings.append("a linked cel could not find its source")
			continue
		var output_image: Image = Image.create_empty(imported_document.canvas_size.x, imported_document.canvas_size.y, false, Image.FORMAT_RGBA8)
		var cel_image: Image = _decode_cel_image(cel_data)
		if cel_image != null:
			output_image.blend_rect(cel_image, Rect2i(Vector2i.ZERO, cel_image.get_size()), Vector2i(int(cel_data["x"]), int(cel_data["y"])))
		var target_cel: GatorSpriteCel = imported_layer.cels[frame_index]
		target_cel.duration = float(frame_durations[frame_index]) / 1000.0
		target_cel.set_image(output_image)
		decoded_cels[target_key] = target_cel

func _decode_cel_image(cel_data: Dictionary) -> Image:
	var image_width: int = int(cel_data["width"])
	var image_height: int = int(cel_data["height"])
	var bytes_per_pixel: int = source_color_depth / 8
	var expected_size: int = image_width * image_height * bytes_per_pixel
	var pixel_bytes: PackedByteArray = cel_data["pixels"] as PackedByteArray
	if int(cel_data["type"]) == 2:
		pixel_bytes = pixel_bytes.decompress(expected_size, FileAccess.COMPRESSION_DEFLATE)
	if pixel_bytes.size() < expected_size:
		import_warnings.append("a cel image was truncated")
		return null
	var result_image: Image = Image.create_empty(image_width, image_height, false, Image.FORMAT_RGBA8)
	var opacity: float = float(cel_data["opacity"])
	for pixel_index: int in range(image_width * image_height):
		var byte_offset: int = pixel_index * bytes_per_pixel
		var pixel_color: Color
		if source_color_depth == 32:
			pixel_color = Color8(pixel_bytes[byte_offset], pixel_bytes[byte_offset + 1], pixel_bytes[byte_offset + 2], roundi(float(pixel_bytes[byte_offset + 3]) * opacity))
		elif source_color_depth == 16:
			pixel_color = Color8(pixel_bytes[byte_offset], pixel_bytes[byte_offset], pixel_bytes[byte_offset], roundi(float(pixel_bytes[byte_offset + 1]) * opacity))
		else:
			var palette_index: int = pixel_bytes[byte_offset]
			pixel_color = imported_palette[palette_index] if palette_index < imported_palette.size() else Color.TRANSPARENT
			pixel_color.a = 0.0 if palette_index == transparent_palette_index else pixel_color.a * opacity
		result_image.set_pixel(pixel_index % image_width, pixel_index / image_width, pixel_color)
	return result_image

func _read_string(source_file: FileAccess) -> String:
	var string_length: int = source_file.get_16()
	return source_file.get_buffer(string_length).get_string_from_utf8()

func _signed_16(value: int) -> int:
	return value - 65536 if value >= 32768 else value

func _signed_32(value: int) -> int:
	return value - 4294967296 if value >= 2147483648 else value

func _reset_import_state() -> void:
	imported_palette = PackedColorArray()
	pending_cels.clear()
	source_layer_map.clear()
	source_layer_chunk_count = 0
	frame_durations.clear()
	import_warnings.clear()
	group_titles_by_level.clear()
