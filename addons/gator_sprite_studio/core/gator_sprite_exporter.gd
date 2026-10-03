@tool
class_name GatorSpriteExporter
extends RefCounted

static func export_document(sprite_document: GatorSpriteDocument, destination_directory: String, export_frames: bool = true, export_sheet: bool = true, export_sprite_frames: bool = true, sheet_columns: int = 0, sheet_rows: int = 0, export_name: String = "sprite", export_custom_brush: bool = false, custom_brush_image: Image = null) -> Error:
	var absolute_directory: String = ProjectSettings.globalize_path(destination_directory)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return directory_error
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var output_name: String = export_name.strip_edges()
	if output_name.is_empty():
		return ERR_INVALID_PARAMETER
	if export_custom_brush:
		if custom_brush_image == null:
			return ERR_INVALID_PARAMETER
		var brush_error: Error = custom_brush_image.save_png(absolute_directory.path_join("%s_brush.png" % output_name))
		if brush_error != OK:
			return brush_error
	var generated_frames: SpriteFrames = SpriteFrames.new()
	if export_sprite_frames:
		generated_frames.remove_animation(&"default")
		if sprite_document.tags.is_empty():
			generated_frames.add_animation(StringName(active_animation.animation_title))
			generated_frames.set_animation_speed(StringName(active_animation.animation_title), active_animation.frames_per_second)
			generated_frames.set_animation_loop(StringName(active_animation.animation_title), active_animation.loop_mode != Animation.LOOP_NONE)
		else:
			for sprite_tag: GatorSpriteTag in sprite_document.tags:
				var tag_animation_name: StringName = StringName(sprite_tag.tag_title)
				if tag_animation_name == StringName() or generated_frames.has_animation(tag_animation_name):
					continue
				generated_frames.add_animation(tag_animation_name)
				generated_frames.set_animation_speed(tag_animation_name, active_animation.frames_per_second)
				generated_frames.set_animation_loop(tag_animation_name, active_animation.loop_mode != Animation.LOOP_NONE)
	var resolved_columns: int = sheet_columns
	var resolved_rows: int = sheet_rows
	if resolved_columns <= 0 and resolved_rows <= 0:
		resolved_columns = active_animation.frame_count
		resolved_rows = 1
	elif resolved_columns <= 0:
		resolved_columns = ceili(float(active_animation.frame_count) / float(resolved_rows))
	elif resolved_rows <= 0:
		resolved_rows = ceili(float(active_animation.frame_count) / float(resolved_columns))
	if resolved_columns * resolved_rows < active_animation.frame_count:
		return ERR_INVALID_PARAMETER
	var sheet_image: Image = Image.create_empty(sprite_document.canvas_size.x * resolved_columns, sprite_document.canvas_size.y * resolved_rows, false, Image.FORMAT_RGBA8)
	for frame_index: int in range(active_animation.frame_count):
		var frame_image: Image = sprite_document.composite_frame(frame_index)
		if export_frames:
			var frame_path: String = absolute_directory.path_join("%s_%03d.png" % [output_name, frame_index])
			var image_error: Error = frame_image.save_png(frame_path)
			if image_error != OK:
				return image_error
		var frame_column: int = frame_index % resolved_columns
		var frame_row: int = frame_index / resolved_columns
		var sheet_position: Vector2i = Vector2i(frame_column * sprite_document.canvas_size.x, frame_row * sprite_document.canvas_size.y)
		sheet_image.blit_rect(frame_image, Rect2i(Vector2i.ZERO, sprite_document.canvas_size), sheet_position)
		if export_sprite_frames:
			if sprite_document.tags.is_empty():
				var default_frame_texture: ImageTexture = ImageTexture.create_from_image(frame_image)
				generated_frames.add_frame(StringName(active_animation.animation_title), default_frame_texture, 1.0)
			else:
				for frame_tag: GatorSpriteTag in sprite_document.tags:
					var frame_tag_name: StringName = StringName(frame_tag.tag_title)
					if not frame_tag.contains_frame(frame_index, active_animation.frame_count) or not generated_frames.has_animation(frame_tag_name):
						continue
					var tag_frame_texture: ImageTexture = ImageTexture.create_from_image(frame_image)
					generated_frames.add_frame(frame_tag_name, tag_frame_texture, 1.0)
	if export_sheet:
		var sheet_error: Error = sheet_image.save_png(absolute_directory.path_join("%s_sheet.png" % output_name))
		if sheet_error != OK:
			return sheet_error
	if export_sprite_frames:
		var frame_resource_error: Error = ResourceSaver.save(generated_frames, destination_directory.path_join("%s_sprite_frames.tres" % output_name))
		if frame_resource_error != OK:
			return frame_resource_error
	var metadata: Dictionary = {
		"animation": active_animation.animation_title,
		"export_name": output_name,
		"canvas_size": [sprite_document.canvas_size.x, sprite_document.canvas_size.y],
		"frames_per_second": active_animation.frames_per_second,
		"frame_count": active_animation.frame_count,
		"sheet": {"columns": resolved_columns, "rows": resolved_rows, "frame_width": sprite_document.canvas_size.x, "frame_height": sprite_document.canvas_size.y},
		"frames": [],
		"tags": [],
		"slices": []
	}
	for metadata_frame_index: int in range(active_animation.frame_count):
		metadata["frames"].append({"index": metadata_frame_index, "x": (metadata_frame_index % resolved_columns) * sprite_document.canvas_size.x, "y": (metadata_frame_index / resolved_columns) * sprite_document.canvas_size.y, "width": sprite_document.canvas_size.x, "height": sprite_document.canvas_size.y})
	for sprite_tag: GatorSpriteTag in sprite_document.tags:
		metadata["tags"].append({"name": sprite_tag.tag_title, "from": sprite_tag.from_frame, "to": sprite_tag.to_frame, "frames": sprite_tag.get_frame_indices(active_animation.frame_count), "color": sprite_tag.color.to_html()})
	for sprite_slice: GatorSpriteSlice in sprite_document.slices:
		metadata["slices"].append({"name": sprite_slice.slice_title, "x": sprite_slice.rectangle.position.x, "y": sprite_slice.rectangle.position.y, "width": sprite_slice.rectangle.size.x, "height": sprite_slice.rectangle.size.y, "pivot": [sprite_slice.pivot.x, sprite_slice.pivot.y]})
	if export_sheet:
		var metadata_file: FileAccess = FileAccess.open(absolute_directory.path_join("%s_metadata.json" % output_name), FileAccess.WRITE)
		if metadata_file == null:
			return FileAccess.get_open_error()
		metadata_file.store_string(JSON.stringify(metadata, "\t"))
		metadata_file.close()
	return OK
