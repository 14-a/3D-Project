@tool
class_name GatorSpriteDocument
extends Resource

@export var document_title: String = "Untitled Sprite"
@export var canvas_size: Vector2i = Vector2i(32, 32)
@export var palette: PackedColorArray = PackedColorArray([Color.WHITE, Color.BLACK, Color(0.25, 0.72, 0.32, 1.0), Color(0.12, 0.22, 0.16, 1.0)])
@export var layers: Array[GatorSpriteLayer] = []
@export var layer_groups: Array[GatorSpriteLayerGroup] = []
@export var tileset: GatorSpriteTileset
@export var tilemap: GatorSpriteTilemap
@export var animations: Array[GatorSpriteAnimation] = []
@export var tags: Array[GatorSpriteTag] = []
@export var slices: Array[GatorSpriteSlice] = []
@export var active_animation_index: int = 0
@export var indexed_color_mode: bool = false
@export var palette_locked: bool = false
@export var extension_data: Dictionary = {}

func setup_new_sprite(requested_size: Vector2i) -> void:
	canvas_size = requested_size.max(Vector2i.ONE)
	extension_data = {}
	tags = []
	var base_animation: GatorSpriteAnimation = GatorSpriteAnimation.new()
	base_animation.animation_title = "default"
	animations = [base_animation]
	var base_layer: GatorSpriteLayer = GatorSpriteLayer.new()
	base_layer.layer_title = "Layer 1"
	base_layer.ensure_cel(0, canvas_size)
	layers = [base_layer]
	layer_groups = []
	tileset = GatorSpriteTileset.new()
	tilemap = GatorSpriteTilemap.new()
	var base_slice: GatorSpriteSlice = GatorSpriteSlice.new()
	base_slice.rectangle = Rect2i(Vector2i.ZERO, canvas_size)
	slices = [base_slice]


func get_layer_group(group_title: String) -> GatorSpriteLayerGroup:
	if group_title.is_empty():
		return null
	for layer_group: GatorSpriteLayerGroup in layer_groups:
		if layer_group.group_title == group_title:
			return layer_group
	return null

func get_group_layer_indices(group_title: String) -> Array[int]:
	var member_indices: Array[int] = []
	if group_title.is_empty():
		return member_indices
	for layer_index: int in range(layers.size()):
		if layers[layer_index].group_title == group_title:
			member_indices.append(layer_index)
	return member_indices

func is_layer_effectively_visible(sprite_layer: GatorSpriteLayer) -> bool:
	if sprite_layer == null or not sprite_layer.visible:
		return false
	var layer_group: GatorSpriteLayerGroup = get_layer_group(sprite_layer.group_title)
	return layer_group == null or layer_group.visible

func is_layer_effectively_locked(sprite_layer: GatorSpriteLayer) -> bool:
	if sprite_layer == null or sprite_layer.locked or sprite_layer.is_reference_layer():
		return true
	var layer_group: GatorSpriteLayerGroup = get_layer_group(sprite_layer.group_title)
	return layer_group != null and layer_group.locked

func remove_empty_layer_groups() -> void:
	for group_index: int in range(layer_groups.size() - 1, -1, -1):
		if get_group_layer_indices(layer_groups[group_index].group_title).is_empty():
			layer_groups.remove_at(group_index)

func move_layers(source_layer_indices: Array[int], insertion_index: int) -> Array[int]:
	var layer_count: int = layers.size()
	var sorted_source_indices: Array[int] = []
	for source_layer_index: int in source_layer_indices:
		if source_layer_index >= 0 and source_layer_index < layer_count and not sorted_source_indices.has(source_layer_index):
			sorted_source_indices.append(source_layer_index)
	sorted_source_indices.sort()
	if sorted_source_indices.is_empty():
		return []

	var clamped_insertion_index: int = clampi(insertion_index, 0, layer_count)
	var adjusted_insertion_index: int = clamped_insertion_index
	for source_layer_index: int in sorted_source_indices:
		if source_layer_index < clamped_insertion_index:
			adjusted_insertion_index -= 1

	var remaining_layer_order: Array[int] = []
	for layer_index: int in range(layer_count):
		if not sorted_source_indices.has(layer_index):
			remaining_layer_order.append(layer_index)
	adjusted_insertion_index = clampi(adjusted_insertion_index, 0, remaining_layer_order.size())

	var new_layer_order: Array[int] = []
	for remaining_layer_index: int in remaining_layer_order:
		new_layer_order.append(remaining_layer_index)
	for moved_offset: int in range(sorted_source_indices.size()):
		new_layer_order.insert(adjusted_insertion_index + moved_offset, sorted_source_indices[moved_offset])

	var identity_order: Array[int] = []
	for layer_index: int in range(layer_count):
		identity_order.append(layer_index)
	if new_layer_order == identity_order:
		return []

	var previous_layers: Array[GatorSpriteLayer] = []
	for sprite_layer: GatorSpriteLayer in layers:
		previous_layers.append(sprite_layer)
	layers.clear()
	for previous_layer_index: int in new_layer_order:
		layers.append(previous_layers[previous_layer_index])
	return new_layer_order

func get_active_animation() -> GatorSpriteAnimation:
	if animations.is_empty():
		setup_new_sprite(canvas_size)
	active_animation_index = clampi(active_animation_index, 0, animations.size() - 1)
	return animations[active_animation_index]

func ensure_frame(frame_index: int) -> void:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	current_animation.frame_count = maxi(current_animation.frame_count, frame_index + 1)
	for sprite_layer: GatorSpriteLayer in layers:
		sprite_layer.ensure_cel(frame_index, canvas_size)

func duplicate_frame(frame_index: int) -> int:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	var previous_frame_count: int = current_animation.frame_count
	var source_frame_index: int = clampi(frame_index, 0, previous_frame_count - 1)
	var inserted_frame_index: int = source_frame_index + 1
	for sprite_layer: GatorSpriteLayer in layers:
		if sprite_layer.is_reference_layer():
			continue
		var source_cel: GatorSpriteCel = sprite_layer.ensure_cel(source_frame_index, canvas_size)
		var duplicated_cel: GatorSpriteCel = GatorSpriteCel.new()
		duplicated_cel.duration = source_cel.duration
		duplicated_cel.set_image(source_cel.get_image(canvas_size))
		sprite_layer.cels.insert(inserted_frame_index, duplicated_cel)
	current_animation.frame_count += 1
	for sprite_tag: GatorSpriteTag in tags:
		var previous_tag_frames: Array[int] = sprite_tag.get_frame_indices(previous_frame_count)
		var duplicated_tag_frames: Array[int] = []
		for previous_tag_frame_index: int in previous_tag_frames:
			if previous_tag_frame_index > source_frame_index:
				duplicated_tag_frames.append(previous_tag_frame_index + 1)
			else:
				duplicated_tag_frames.append(previous_tag_frame_index)
				if previous_tag_frame_index == source_frame_index:
					duplicated_tag_frames.append(inserted_frame_index)
		sprite_tag.set_frame_indices(duplicated_tag_frames, current_animation.frame_count)
	return inserted_frame_index

func move_frame(source_frame_index: int, destination_frame_index: int) -> bool:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	if source_frame_index < 0 or source_frame_index >= current_animation.frame_count:
		return false
	var target_frame_index: int = clampi(destination_frame_index, 0, current_animation.frame_count - 1)
	if source_frame_index == target_frame_index:
		return false
	var insertion_index: int = target_frame_index if target_frame_index < source_frame_index else target_frame_index + 1
	var single_frame_indices: Array[int] = []
	single_frame_indices.append(source_frame_index)
	return not move_frames(single_frame_indices, insertion_index).is_empty()

func move_frames(source_frame_indices: Array[int], insertion_index: int) -> Array[int]:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	var frame_count: int = current_animation.frame_count
	var sorted_source_indices: Array[int] = []
	for source_frame_index: int in source_frame_indices:
		if source_frame_index >= 0 and source_frame_index < frame_count and not sorted_source_indices.has(source_frame_index):
			sorted_source_indices.append(source_frame_index)
	sorted_source_indices.sort()
	if sorted_source_indices.is_empty():
		return []

	var clamped_insertion_index: int = clampi(insertion_index, 0, frame_count)
	var adjusted_insertion_index: int = clamped_insertion_index
	for source_frame_index: int in sorted_source_indices:
		if source_frame_index < clamped_insertion_index:
			adjusted_insertion_index -= 1

	var remaining_frame_order: Array[int] = []
	for frame_index: int in range(frame_count):
		if not sorted_source_indices.has(frame_index):
			remaining_frame_order.append(frame_index)
	adjusted_insertion_index = clampi(adjusted_insertion_index, 0, remaining_frame_order.size())

	var new_frame_order: Array[int] = []
	for remaining_frame_index: int in remaining_frame_order:
		new_frame_order.append(remaining_frame_index)
	for moved_offset: int in range(sorted_source_indices.size()):
		new_frame_order.insert(adjusted_insertion_index + moved_offset, sorted_source_indices[moved_offset])

	var identity_order: Array[int] = []
	for frame_index: int in range(frame_count):
		identity_order.append(frame_index)
	if new_frame_order == identity_order:
		return []

	for sprite_layer: GatorSpriteLayer in layers:
		if sprite_layer.is_reference_layer():
			continue
		while sprite_layer.cels.size() < frame_count:
			sprite_layer.ensure_cel(sprite_layer.cels.size(), canvas_size)
		var previous_cels: Array[GatorSpriteCel] = []
		for previous_cel: GatorSpriteCel in sprite_layer.cels:
			previous_cels.append(previous_cel)
		sprite_layer.cels.clear()
		for previous_frame_index: int in new_frame_order:
			sprite_layer.cels.append(previous_cels[previous_frame_index])
		for trailing_cel_index: int in range(frame_count, previous_cels.size()):
			sprite_layer.cels.append(previous_cels[trailing_cel_index])

	_remap_tags_for_frame_order(new_frame_order)
	return new_frame_order

func _remap_tags_for_frame_order(new_frame_order: Array[int]) -> void:
	var frame_count: int = new_frame_order.size()
	for sprite_tag: GatorSpriteTag in tags:
		var previous_tag_frames: Array[int] = sprite_tag.get_frame_indices(frame_count)
		var remapped_tag_frames: Array[int] = []
		for previous_tag_frame_index: int in previous_tag_frames:
			var remapped_frame_index: int = new_frame_order.find(previous_tag_frame_index)
			if remapped_frame_index >= 0:
				remapped_tag_frames.append(remapped_frame_index)
		sprite_tag.set_frame_indices(remapped_tag_frames, frame_count)

func delete_frame(frame_index: int) -> bool:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	var previous_frame_count: int = current_animation.frame_count
	if previous_frame_count <= 1 or frame_index < 0 or frame_index >= previous_frame_count:
		return false
	for sprite_layer: GatorSpriteLayer in layers:
		if sprite_layer.is_reference_layer():
			continue
		if frame_index < sprite_layer.cels.size():
			sprite_layer.cels.remove_at(frame_index)
	current_animation.frame_count -= 1
	for sprite_tag: GatorSpriteTag in tags:
		var previous_tag_frames: Array[int] = sprite_tag.get_frame_indices(previous_frame_count)
		var remapped_tag_frames: Array[int] = []
		for previous_tag_frame_index: int in previous_tag_frames:
			if previous_tag_frame_index == frame_index:
				continue
			remapped_tag_frames.append(previous_tag_frame_index - 1 if previous_tag_frame_index > frame_index else previous_tag_frame_index)
		if remapped_tag_frames.is_empty():
			remapped_tag_frames.append(clampi(frame_index, 0, current_animation.frame_count - 1))
		sprite_tag.set_frame_indices(remapped_tag_frames, current_animation.frame_count)
	return true

func link_cels(layer_index: int, frame_indices: Array[int], source_frame_index: int = -1) -> bool:
	if layer_index < 0 or layer_index >= layers.size() or layers[layer_index].is_reference_layer():
		return false
	var frame_count: int = get_active_animation().frame_count
	var valid_frames: Array[int] = []
	for frame_index: int in frame_indices:
		if frame_index >= 0 and frame_index < frame_count and not valid_frames.has(frame_index):
			valid_frames.append(frame_index)
	valid_frames.sort()
	if valid_frames.size() < 2:
		return false
	var resolved_source_frame: int = source_frame_index if valid_frames.has(source_frame_index) else valid_frames[0]
	var source_cel: GatorSpriteCel = layers[layer_index].ensure_cel(resolved_source_frame, canvas_size)
	for frame_index: int in valid_frames:
		layers[layer_index].ensure_cel(frame_index, canvas_size)
		layers[layer_index].cels[frame_index] = source_cel
	return true

func unlink_cels(layer_index: int, frame_indices: Array[int]) -> int:
	if layer_index < 0 or layer_index >= layers.size() or layers[layer_index].is_reference_layer():
		return 0
	var unlinked_count: int = 0
	for frame_index: int in frame_indices:
		if frame_index < 0 or frame_index >= get_active_animation().frame_count:
			continue
		var current_cel: GatorSpriteCel = layers[layer_index].ensure_cel(frame_index, canvas_size)
		var duplicate_cel: GatorSpriteCel = GatorSpriteCel.new()
		duplicate_cel.duration = current_cel.duration
		duplicate_cel.set_image(current_cel.get_image(canvas_size))
		layers[layer_index].cels[frame_index] = duplicate_cel
		unlinked_count += 1
	return unlinked_count

func get_linked_frame_indices(layer_index: int, frame_index: int) -> Array[int]:
	var linked_frames: Array[int] = []
	if layer_index < 0 or layer_index >= layers.size():
		return linked_frames
	if layers[layer_index].is_reference_layer():
		if frame_index >= 0 and frame_index < get_active_animation().frame_count:
			linked_frames.append(frame_index)
		return linked_frames
	var source_cel: GatorSpriteCel = layers[layer_index].ensure_cel(frame_index, canvas_size)
	for candidate_frame: int in range(get_active_animation().frame_count):
		if layers[layer_index].ensure_cel(candidate_frame, canvas_size) == source_cel:
			linked_frames.append(candidate_frame)
	return linked_frames

func duplicate_frame_linked(frame_index: int) -> int:
	var current_animation: GatorSpriteAnimation = get_active_animation()
	var source_frame_index: int = clampi(frame_index, 0, current_animation.frame_count - 1)
	var inserted_frame_index: int = source_frame_index + 1
	for sprite_layer: GatorSpriteLayer in layers:
		if sprite_layer.is_reference_layer():
			continue
		var source_cel: GatorSpriteCel = sprite_layer.ensure_cel(source_frame_index, canvas_size)
		sprite_layer.cels.insert(inserted_frame_index, source_cel)
	current_animation.frame_count += 1
	for sprite_tag: GatorSpriteTag in tags:
		var previous_tag_frames: Array[int] = sprite_tag.get_frame_indices(current_animation.frame_count - 1)
		var remapped_frames: Array[int] = []
		for previous_frame: int in previous_tag_frames:
			remapped_frames.append(previous_frame + 1 if previous_frame > source_frame_index else previous_frame)
			if previous_frame == source_frame_index:
				remapped_frames.append(inserted_frame_index)
		sprite_tag.set_frame_indices(remapped_frames, current_animation.frame_count)
	return inserted_frame_index

func composite_frame(frame_index: int, include_reference_layers: bool = false) -> Image:
	return composite_frame_with_override(frame_index, include_reference_layers, -1, null)

func composite_frame_with_override(frame_index: int, include_reference_layers: bool, override_layer_index: int, override_image: Image) -> Image:
	ensure_frame(frame_index)
	var output_image: Image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	for layer_index: int in range(layers.size()):
		var sprite_layer: GatorSpriteLayer = layers[layer_index]
		if not is_layer_effectively_visible(sprite_layer):
			continue
		if sprite_layer.is_reference_layer() and (not include_reference_layers or sprite_layer.exclude_from_export):
			if not include_reference_layers:
				continue
		var source_image: Image
		if layer_index == override_layer_index and override_image != null:
			source_image = override_image
		else:
			source_image = sprite_layer.ensure_cel(frame_index, canvas_size).get_image_reference(canvas_size)
		var prepared_image: Image = _render_layer_image(sprite_layer, source_image)
		var layer_group: GatorSpriteLayerGroup = get_layer_group(sprite_layer.group_title)
		var combined_opacity: float = sprite_layer.opacity * (layer_group.opacity if layer_group != null else 1.0)
		_blend_layer_into(output_image, prepared_image, int(sprite_layer.blend_mode), combined_opacity)
	return output_image

func _render_layer_image(sprite_layer: GatorSpriteLayer, source_image: Image) -> Image:
	if not sprite_layer.is_reference_layer():
		return source_image
	var output_image: Image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	var source_size: Vector2i = source_image.get_size()
	if source_size.x <= 0 or source_size.y <= 0:
		return output_image
	var scale_value: Vector2 = sprite_layer.reference_scale
	if is_zero_approx(scale_value.x) or is_zero_approx(scale_value.y):
		return output_image
	var source_center: Vector2 = (Vector2(source_size) - Vector2.ONE) * 0.5
	var destination_center: Vector2 = source_center + sprite_layer.reference_position
	var inverse_rotation: float = -deg_to_rad(sprite_layer.reference_rotation_degrees)
	var cosine_value: float = cos(inverse_rotation)
	var sine_value: float = sin(inverse_rotation)
	for destination_y: int in range(canvas_size.y):
		for destination_x: int in range(canvas_size.x):
			var relative_position: Vector2 = Vector2(destination_x, destination_y) - destination_center
			var rotated_position: Vector2 = Vector2(
				relative_position.x * cosine_value - relative_position.y * sine_value,
				relative_position.x * sine_value + relative_position.y * cosine_value
			)
			var source_position: Vector2 = Vector2(rotated_position.x / scale_value.x, rotated_position.y / scale_value.y) + source_center
			var source_pixel: Vector2i = Vector2i(roundi(source_position.x), roundi(source_position.y))
			if source_pixel.x < 0 or source_pixel.y < 0 or source_pixel.x >= source_size.x or source_pixel.y >= source_size.y:
				continue
			output_image.set_pixel(destination_x, destination_y, source_image.get_pixelv(source_pixel))
	return output_image

func _blend_layer_into(destination_image: Image, source_image: Image, blend_mode: int, opacity_value: float) -> void:
	var applied_opacity: float = clampf(opacity_value, 0.0, 1.0)
	if applied_opacity <= 0.0:
		return
	if blend_mode == int(GatorSpriteLayer.BlendMode.NORMAL) and is_equal_approx(applied_opacity, 1.0):
		destination_image.blend_rect(source_image, Rect2i(Vector2i.ZERO, canvas_size), Vector2i.ZERO)
		return
	for pixel_y: int in range(canvas_size.y):
		for pixel_x: int in range(canvas_size.x):
			var source_color: Color = source_image.get_pixel(pixel_x, pixel_y)
			var source_alpha: float = source_color.a * applied_opacity
			if source_alpha <= 0.0:
				continue
			var destination_color: Color = destination_image.get_pixel(pixel_x, pixel_y)
			var blended_rgb: Vector3 = _blend_rgb(Vector3(destination_color.r, destination_color.g, destination_color.b), Vector3(source_color.r, source_color.g, source_color.b), blend_mode)
			var output_alpha: float = source_alpha + destination_color.a * (1.0 - source_alpha)
			var output_rgb: Vector3 = blended_rgb
			if output_alpha > 0.0:
				output_rgb = (blended_rgb * source_alpha + Vector3(destination_color.r, destination_color.g, destination_color.b) * destination_color.a * (1.0 - source_alpha)) / output_alpha
			destination_image.set_pixel(pixel_x, pixel_y, Color(output_rgb.x, output_rgb.y, output_rgb.z, output_alpha))

func _blend_rgb(destination_rgb: Vector3, source_rgb: Vector3, blend_mode: int) -> Vector3:
	match blend_mode:
		GatorSpriteLayer.BlendMode.MULTIPLY:
			return destination_rgb * source_rgb
		GatorSpriteLayer.BlendMode.SCREEN:
			return Vector3.ONE - (Vector3.ONE - destination_rgb) * (Vector3.ONE - source_rgb)
		GatorSpriteLayer.BlendMode.ADD:
			return Vector3(minf(1.0, destination_rgb.x + source_rgb.x), minf(1.0, destination_rgb.y + source_rgb.y), minf(1.0, destination_rgb.z + source_rgb.z))
		GatorSpriteLayer.BlendMode.SUBTRACT:
			return Vector3(maxf(0.0, destination_rgb.x - source_rgb.x), maxf(0.0, destination_rgb.y - source_rgb.y), maxf(0.0, destination_rgb.z - source_rgb.z))
		GatorSpriteLayer.BlendMode.OVERLAY:
			return Vector3(_overlay_channel(destination_rgb.x, source_rgb.x), _overlay_channel(destination_rgb.y, source_rgb.y), _overlay_channel(destination_rgb.z, source_rgb.z))
		GatorSpriteLayer.BlendMode.DARKEN:
			return Vector3(minf(destination_rgb.x, source_rgb.x), minf(destination_rgb.y, source_rgb.y), minf(destination_rgb.z, source_rgb.z))
		GatorSpriteLayer.BlendMode.LIGHTEN:
			return Vector3(maxf(destination_rgb.x, source_rgb.x), maxf(destination_rgb.y, source_rgb.y), maxf(destination_rgb.z, source_rgb.z))
		_:
			return source_rgb

func _overlay_channel(destination_value: float, source_value: float) -> float:
	return 2.0 * destination_value * source_value if destination_value < 0.5 else 1.0 - 2.0 * (1.0 - destination_value) * (1.0 - source_value)

func resolve_palette_color(source_color: Color) -> Color:
	if not indexed_color_mode or palette.is_empty() or source_color.a <= 0.0:
		return source_color
	var closest_color: Color = palette[0]
	var closest_distance: float = INF
	for palette_color: Color in palette:
		var color_distance: float = pow(source_color.r - palette_color.r, 2.0) + pow(source_color.g - palette_color.g, 2.0) + pow(source_color.b - palette_color.b, 2.0) + pow(source_color.a - palette_color.a, 2.0)
		if color_distance < closest_distance:
			closest_distance = color_distance
			closest_color = palette_color
	return closest_color

func colors_match(color_a: Color, color_b: Color) -> bool:
	return color_a.to_rgba32() == color_b.to_rgba32()

func remap_indexed_pixels(old_palette: PackedColorArray, new_palette: PackedColorArray) -> void:
	if old_palette.is_empty():
		return
	var entry_count: int = mini(old_palette.size(), new_palette.size())
	var processed_cels: Dictionary[int, bool] = {}
	for sprite_layer: GatorSpriteLayer in layers:
		if sprite_layer.is_reference_layer():
			continue
		for sprite_cel: GatorSpriteCel in sprite_layer.cels:
			var cel_id: int = sprite_cel.get_instance_id()
			if processed_cels.has(cel_id):
				continue
			processed_cels[cel_id] = true
			var cel_image: Image = sprite_cel.get_image(canvas_size)
			var image_changed: bool = false
			for pixel_y: int in range(cel_image.get_height()):
				for pixel_x: int in range(cel_image.get_width()):
					var pixel_color: Color = cel_image.get_pixel(pixel_x, pixel_y)
					if pixel_color.a <= 0.0:
						continue
					for entry_index: int in range(entry_count):
						if colors_match(pixel_color, old_palette[entry_index]):
							cel_image.set_pixel(pixel_x, pixel_y, new_palette[entry_index])
							image_changed = true
							break
			if image_changed:
				sprite_cel.set_image(cel_image)
