@tool
class_name GatorCanvas
extends Control

signal pixels_changed
signal color_picked(selected_color: Color)
signal zoom_changed(new_zoom: float)

enum ToolMode { PENCIL, ERASER, FILL, PICKER, LINE, RECTANGLE, SELECTION, CUSTOM_BRUSH, GRADIENT, DITHER, PATTERN_FILL, TILE_STAMP }
enum PencilBrushShape { SQUARE, CIRCLE }
enum SelectionEditMode { REPLACE, ADD, SUBTRACT }

var sprite_document: GatorSpriteDocument
var pre_edit_provider: Callable
var active_frame_index: int = 0
var active_layer_index: int = 0
var brush_color: Color = Color.WHITE
var secondary_color: Color = Color.BLACK
var zoom_level: float = 14.0
var show_grid: bool = true
var show_onion_skin: bool = true
var tool_mode: ToolMode = ToolMode.PENCIL
var drawing: bool = false
var last_pixel: Vector2i = Vector2i(-1, -1)
var drag_start_pixel: Vector2i = Vector2i(-1, -1)
var hover_pixel: Vector2i = Vector2i(-1, -1)
var undo_stack: Array[PackedByteArray] = []
var redo_stack: Array[PackedByteArray] = []
var undo_selection_stack: Array[Rect2i] = []
var redo_selection_stack: Array[Rect2i] = []
var undo_selection_masks: Array[PackedByteArray] = []
var redo_selection_masks: Array[PackedByteArray] = []
var undo_frame_stack: Array[int] = []
var redo_frame_stack: Array[int] = []
var undo_layer_stack: Array[int] = []
var redo_layer_stack: Array[int] = []
var display_texture: ImageTexture
var onion_texture: ImageTexture
var paint_buffer_image: Image
var paint_buffer_frame_index: int = -1
var paint_buffer_layer_index: int = -1
var paint_buffer_changed: bool = false
var canvas_refresh_requested: bool = false
var pencil_brush_size: int = 1
var pencil_brush_shape: int = int(PencilBrushShape.SQUARE)
var eraser_brush_shape: int = int(PencilBrushShape.SQUARE)
var custom_brush_image: Image
var custom_brush_source_image: Image
var custom_brush_scale_percent: int = 100
var custom_brush_spacing_percent: int = 25
var last_custom_brush_stamp_position: Vector2i = Vector2i(-1, -1)
var custom_brush_anchor: Vector2i = Vector2i.ZERO
var custom_brush_preview_texture: ImageTexture
var custom_brush_stamp_image: Image
var custom_brush_stamp_color_rgba: int = -1
var custom_brush_stamp_provider: Callable
var custom_brush_stamp_images: Dictionary = {}
var cached_circle_brush_size: int = 0
var cached_circle_row_spans: PackedInt32Array = PackedInt32Array()
var selection_rectangle: Rect2i = Rect2i()
var selection_image: Image
var selection_mask: Image
var moving_selection: bool = false
var selection_move_origin: Vector2i = Vector2i.ZERO
var selection_move_source_image: Image
var selection_move_source_mask: Image
var selection_move_original_rectangle: Rect2i = Rect2i()
var selection_clipboard_image: Image
var selection_clipboard_mask: Image
var selection_clipboard_origin: Vector2i = Vector2i.ZERO
var selection_edit_mode: SelectionEditMode = SelectionEditMode.REPLACE
var mirror_horizontal: bool = false
var mirror_vertical: bool = false
var tiled_drawing: bool = false
var active_tile_index: int = 0
var tile_stamp_preview_texture: ImageTexture
var tile_stamp_preview_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


func _process(_delta: float) -> void:
	if not canvas_refresh_requested:
		return
	canvas_refresh_requested = false
	refresh_canvas()

func set_document(source_document: GatorSpriteDocument) -> void:
	_clear_paint_buffer()
	canvas_refresh_requested = false
	sprite_document = source_document
	active_frame_index = 0
	active_layer_index = 0
	undo_stack.clear()
	redo_stack.clear()
	undo_selection_stack.clear()
	redo_selection_stack.clear()
	undo_selection_masks.clear()
	redo_selection_masks.clear()
	undo_frame_stack.clear()
	redo_frame_stack.clear()
	undo_layer_stack.clear()
	redo_layer_stack.clear()
	refresh_canvas()

func refresh_canvas() -> void:
	if sprite_document == null:
		return
	var composite_image: Image = _composite_frame_for_display(active_frame_index)
	display_texture = _update_image_texture(display_texture, composite_image)
	if show_onion_skin and active_frame_index > 0:
		var onion_image: Image = sprite_document.composite_frame(active_frame_index - 1)
		onion_texture = _update_image_texture(onion_texture, onion_image)
	else:
		onion_texture = null
	var requested_minimum_size: Vector2 = Vector2(sprite_document.canvas_size) * zoom_level
	if custom_minimum_size != requested_minimum_size:
		custom_minimum_size = requested_minimum_size
		update_minimum_size()
	queue_redraw()


func _composite_frame_for_display(frame_index: int) -> Image:
	var override_layer_index: int = -1
	var override_image: Image = null
	if paint_buffer_image != null and frame_index == paint_buffer_frame_index:
		override_layer_index = paint_buffer_layer_index
		override_image = paint_buffer_image
	return sprite_document.composite_frame_with_override(frame_index, true, override_layer_index, override_image)


func _update_image_texture(existing_texture: ImageTexture, source_image: Image) -> ImageTexture:
	if existing_texture == null or Vector2i(existing_texture.get_size()) != source_image.get_size():
		return ImageTexture.create_from_image(source_image)
	existing_texture.update(source_image)
	return existing_texture


func _request_canvas_refresh() -> void:
	canvas_refresh_requested = true

func _gui_input(input_event: InputEvent) -> void:
	if sprite_document == null:
		return
	if input_event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = input_event
		if mouse_button_event.pressed:
			grab_focus()
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button_event.pressed:
			zoom_level = minf(zoom_level + 2.0, 48.0)
			refresh_canvas()
			zoom_changed.emit(zoom_level)
			return
		if mouse_button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button_event.pressed:
			zoom_level = maxf(zoom_level - 2.0, 2.0)
			refresh_canvas()
			zoom_changed.emit(zoom_level)
			return
		if mouse_button_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button_event.pressed and _active_tool_requires_unlocked_layer() and sprite_document.is_layer_effectively_locked(_selected_layer()):
				drawing = false
				return
			drawing = mouse_button_event.pressed
			if drawing:
				_begin_action(_position_to_pixel(mouse_button_event.position), mouse_button_event.shift_pressed, mouse_button_event.ctrl_pressed or mouse_button_event.alt_pressed)
			else:
				_commit_action(_position_to_pixel(mouse_button_event.position))
				last_pixel = Vector2i(-1, -1)
	elif input_event is InputEventMouseMotion:
		var mouse_motion_event: InputEventMouseMotion = input_event
		hover_pixel = _position_to_pixel(mouse_motion_event.position)
		if drawing and (tool_mode == ToolMode.PENCIL or tool_mode == ToolMode.ERASER or tool_mode == ToolMode.CUSTOM_BRUSH):
			paint_stroke_to(hover_pixel)
		elif drawing and tool_mode == ToolMode.SELECTION and moving_selection:
			_preview_move_selection(hover_pixel - drag_start_pixel)
		elif drawing:
			queue_redraw()
		else:
			queue_redraw()

func _active_tool_requires_unlocked_layer() -> bool:
	return tool_mode in [ToolMode.PENCIL, ToolMode.ERASER, ToolMode.FILL, ToolMode.LINE, ToolMode.RECTANGLE, ToolMode.GRADIENT, ToolMode.DITHER, ToolMode.PATTERN_FILL, ToolMode.TILE_STAMP, ToolMode.CUSTOM_BRUSH]

func _begin_action(pixel_position: Vector2i, shift_pressed: bool = false, subtract_pressed: bool = false) -> void:
	if not _is_paintable_position(pixel_position):
		return
	if pre_edit_provider.is_valid():
		var pre_edit_result: Variant = pre_edit_provider.call("Pixel edit", active_frame_index, active_layer_index, pixel_position)
		if pre_edit_result is GatorSpriteEditContext:
			var edit_context: GatorSpriteEditContext = pre_edit_result as GatorSpriteEditContext
			if edit_context.is_cancelled:
				return
			active_frame_index = clampi(edit_context.frame_index, 0, sprite_document.get_active_animation().frame_count - 1)
			active_layer_index = clampi(edit_context.layer_index, 0, sprite_document.layers.size() - 1)
			pixel_position = edit_context.pixel_position
		elif not bool(pre_edit_result):
			return
	drag_start_pixel = pixel_position
	match tool_mode:
		ToolMode.PENCIL, ToolMode.ERASER, ToolMode.CUSTOM_BRUSH:
			_push_undo_snapshot()
			paint_pixel(pixel_position)
		ToolMode.FILL:
			_push_undo_snapshot()
			_fill_pixels(pixel_position)
			_finish_edit()
		ToolMode.PATTERN_FILL:
			_push_undo_snapshot()
			_pattern_fill_pixels(pixel_position)
			_finish_edit()
		ToolMode.TILE_STAMP:
			_push_undo_snapshot()
			_stamp_tile(pixel_position)
			_finish_edit()
		ToolMode.PICKER:
			brush_color = sprite_document.composite_frame(active_frame_index).get_pixelv(pixel_position)
			color_picked.emit(brush_color)
		ToolMode.LINE, ToolMode.RECTANGLE, ToolMode.GRADIENT, ToolMode.DITHER:
			_push_undo_snapshot()
			queue_redraw()
		ToolMode.SELECTION:
			selection_edit_mode = SelectionEditMode.SUBTRACT if subtract_pressed else SelectionEditMode.ADD if shift_pressed else SelectionEditMode.REPLACE
			moving_selection = selection_edit_mode == SelectionEditMode.REPLACE and _is_selected_position(pixel_position) and selection_image != null
			if moving_selection:
				selection_move_origin = selection_rectangle.position
				selection_move_original_rectangle = selection_rectangle
				selection_move_source_image = _selected_image()
				selection_move_source_mask = selection_mask.duplicate()
				_push_undo_snapshot()
			queue_redraw()

func _commit_action(pixel_position: Vector2i) -> void:
	if tool_mode == ToolMode.PENCIL or tool_mode == ToolMode.ERASER or tool_mode == ToolMode.CUSTOM_BRUSH:
		_commit_paint_buffer()
		return
	if not _is_paintable_position(pixel_position):
		return
	if tool_mode == ToolMode.LINE:
		_draw_line(drag_start_pixel, pixel_position)
		_finish_edit()
	elif tool_mode == ToolMode.RECTANGLE:
		_draw_rectangle(drag_start_pixel, pixel_position)
		_finish_edit()
	elif tool_mode == ToolMode.GRADIENT:
		_draw_gradient(drag_start_pixel, pixel_position)
		_finish_edit()
	elif tool_mode == ToolMode.DITHER:
		_draw_dither_rectangle(drag_start_pixel, pixel_position)
		_finish_edit()
	elif tool_mode == ToolMode.SELECTION:
		if moving_selection:
			_preview_move_selection(pixel_position - drag_start_pixel)
			_finish_edit()
		else:
			_apply_selection_rectangle(drag_start_pixel, pixel_position, selection_edit_mode)
		moving_selection = false
		queue_redraw()

func _position_to_pixel(local_position: Vector2) -> Vector2i:
	return Vector2i(floori(local_position.x / zoom_level), floori(local_position.y / zoom_level))

func paint_pixel(pixel_position: Vector2i) -> void:
	if pixel_position == last_pixel or not _is_editable_position(pixel_position):
		return
	var selected_layer: GatorSpriteLayer = _selected_layer()
	if sprite_document.is_layer_effectively_locked(selected_layer):
		return
	var selected_image: Image = _get_paint_buffer()
	_paint_at_position(selected_image, pixel_position)
	paint_buffer_changed = true
	last_pixel = pixel_position
	if tool_mode == ToolMode.CUSTOM_BRUSH:
		last_custom_brush_stamp_position = pixel_position
	_request_canvas_refresh()


func paint_stroke_to(pixel_position: Vector2i) -> void:
	if pixel_position == last_pixel or not _is_editable_position(pixel_position):
		return
	if last_pixel == Vector2i(-1, -1):
		paint_pixel(pixel_position)
		return
	var selected_layer: GatorSpriteLayer = _selected_layer()
	if sprite_document.is_layer_effectively_locked(selected_layer):
		return
	var selected_image: Image = _get_paint_buffer()
	var current_pixel: Vector2i = last_pixel
	var delta_x: int = absi(pixel_position.x - current_pixel.x)
	var step_x: int = 1 if current_pixel.x < pixel_position.x else -1
	var delta_y: int = -absi(pixel_position.y - current_pixel.y)
	var step_y: int = 1 if current_pixel.y < pixel_position.y else -1
	var error_value: int = delta_x + delta_y
	var custom_spacing_pixels: float = _get_custom_brush_spacing_pixels()
	while current_pixel != pixel_position:
		var doubled_error: int = error_value * 2
		if doubled_error >= delta_y:
			error_value += delta_y
			current_pixel.x += step_x
		if doubled_error <= delta_x:
			error_value += delta_x
			current_pixel.y += step_y
		if not _is_editable_position(current_pixel):
			continue
		if tool_mode == ToolMode.CUSTOM_BRUSH and last_custom_brush_stamp_position != Vector2i(-1, -1):
			if Vector2(current_pixel - last_custom_brush_stamp_position).length() < custom_spacing_pixels:
				continue
		_paint_at_position(selected_image, current_pixel)
		if tool_mode == ToolMode.CUSTOM_BRUSH:
			last_custom_brush_stamp_position = current_pixel
	paint_buffer_changed = true
	last_pixel = pixel_position
	_request_canvas_refresh()


func _get_paint_buffer() -> Image:
	if paint_buffer_image != null and paint_buffer_frame_index == active_frame_index and paint_buffer_layer_index == active_layer_index:
		return paint_buffer_image
	_commit_paint_buffer()
	paint_buffer_image = _selected_image()
	paint_buffer_frame_index = active_frame_index
	paint_buffer_layer_index = active_layer_index
	paint_buffer_changed = false
	return paint_buffer_image


func _commit_paint_buffer() -> void:
	if paint_buffer_image == null:
		return
	var changed: bool = paint_buffer_changed
	if changed and sprite_document != null and paint_buffer_layer_index >= 0 and paint_buffer_layer_index < sprite_document.layers.size():
		var sprite_layer: GatorSpriteLayer = sprite_document.layers[paint_buffer_layer_index]
		sprite_layer.ensure_cel(paint_buffer_frame_index, sprite_document.canvas_size).set_image(paint_buffer_image)
	_clear_paint_buffer()
	canvas_refresh_requested = false
	refresh_canvas()
	if changed:
		pixels_changed.emit()


func _clear_paint_buffer() -> void:
	paint_buffer_image = null
	last_custom_brush_stamp_position = Vector2i(-1, -1)
	paint_buffer_frame_index = -1
	paint_buffer_layer_index = -1
	paint_buffer_changed = false

func _paint_at_position(selected_image: Image, pixel_position: Vector2i) -> void:
	for paint_position: Vector2i in _get_paint_positions(pixel_position):
		if not _is_editable_position(paint_position):
			continue
		if tool_mode == ToolMode.CUSTOM_BRUSH and custom_brush_image != null:
			_paint_custom_brush(selected_image, paint_position, false)
		else:
			_paint_standard_brush(selected_image, paint_position, tool_mode == ToolMode.ERASER)


func _paint_standard_brush(selected_image: Image, pixel_position: Vector2i, erase_pixels: bool) -> void:
	var applied_color: Color = Color.TRANSPARENT if erase_pixels else sprite_document.resolve_palette_color(brush_color)
	var active_brush_shape: int = _get_active_standard_brush_shape()
	if selection_mask == null and not tiled_drawing:
		if active_brush_shape == int(PencilBrushShape.SQUARE):
			_paint_square_brush_fast(selected_image, pixel_position, applied_color)
		else:
			_paint_circle_brush_fast(selected_image, pixel_position, applied_color)
		return
	var brush_anchor_offset: int = floori(float(pencil_brush_size - 1) / 2.0)
	var brush_offset: Vector2i = Vector2i(brush_anchor_offset, brush_anchor_offset)
	for brush_y: int in range(pencil_brush_size):
		for brush_x: int in range(pencil_brush_size):
			if not _is_standard_brush_pixel(brush_x, brush_y, active_brush_shape):
				continue
			var destination_pixel: Vector2i = pixel_position + Vector2i(brush_x, brush_y) - brush_offset
			if tiled_drawing:
				destination_pixel = _wrap_position(destination_pixel)
			if _is_editable_position(destination_pixel):
				selected_image.set_pixelv(destination_pixel, applied_color)

func _paint_square_brush_fast(selected_image: Image, pixel_position: Vector2i, applied_color: Color) -> void:
	var brush_anchor_offset: int = floori(float(pencil_brush_size - 1) / 2.0)
	var brush_rectangle: Rect2i = Rect2i(pixel_position - Vector2i(brush_anchor_offset, brush_anchor_offset), Vector2i(pencil_brush_size, pencil_brush_size))
	var clipped_rectangle: Rect2i = brush_rectangle.intersection(Rect2i(Vector2i.ZERO, sprite_document.canvas_size))
	if clipped_rectangle.size.x > 0 and clipped_rectangle.size.y > 0:
		selected_image.fill_rect(clipped_rectangle, applied_color)

func _paint_circle_brush_fast(selected_image: Image, pixel_position: Vector2i, applied_color: Color) -> void:
	var row_spans: PackedInt32Array = _get_circle_row_spans()
	var brush_anchor_offset: int = floori(float(pencil_brush_size - 1) / 2.0)
	var top_left: Vector2i = pixel_position - Vector2i(brush_anchor_offset, brush_anchor_offset)
	for brush_y: int in range(pencil_brush_size):
		var destination_y: int = top_left.y + brush_y
		if destination_y < 0 or destination_y >= sprite_document.canvas_size.y:
			continue
		var span_start: int = row_spans[brush_y * 2]
		var span_end: int = row_spans[brush_y * 2 + 1]
		var destination_start: int = maxi(0, top_left.x + span_start)
		var destination_end: int = mini(sprite_document.canvas_size.x - 1, top_left.x + span_end)
		if destination_end >= destination_start:
			selected_image.fill_rect(Rect2i(destination_start, destination_y, destination_end - destination_start + 1, 1), applied_color)

func _get_circle_row_spans() -> PackedInt32Array:
	if cached_circle_brush_size == pencil_brush_size and cached_circle_row_spans.size() == pencil_brush_size * 2:
		return cached_circle_row_spans
	cached_circle_brush_size = pencil_brush_size
	cached_circle_row_spans = PackedInt32Array()
	cached_circle_row_spans.resize(pencil_brush_size * 2)
	var brush_center: float = float(pencil_brush_size - 1) * 0.5
	var brush_radius: float = maxf(0.5, float(pencil_brush_size) * 0.5 - 0.25)
	var radius_squared: float = brush_radius * brush_radius
	for brush_y: int in range(pencil_brush_size):
		var offset_y: float = float(brush_y) - brush_center
		var horizontal_radius: float = sqrt(maxf(0.0, radius_squared - offset_y * offset_y))
		cached_circle_row_spans[brush_y * 2] = clampi(ceili(brush_center - horizontal_radius), 0, pencil_brush_size - 1)
		cached_circle_row_spans[brush_y * 2 + 1] = clampi(floori(brush_center + horizontal_radius), 0, pencil_brush_size - 1)
	return cached_circle_row_spans

func _is_paintable_position(pixel_position: Vector2i) -> bool:
	return sprite_document != null and active_layer_index >= 0 and active_layer_index < sprite_document.layers.size() and pixel_position.x >= 0 and pixel_position.y >= 0 and pixel_position.x < sprite_document.canvas_size.x and pixel_position.y < sprite_document.canvas_size.y

func _is_editable_position(pixel_position: Vector2i) -> bool:
	return _is_paintable_position(pixel_position) and (selection_mask == null or _is_selected_position(pixel_position))

func _get_paint_positions(origin_position: Vector2i) -> Array[Vector2i]:
	var paint_positions: Array[Vector2i] = []
	var candidate_positions: Array[Vector2i] = [origin_position]
	if mirror_horizontal:
		candidate_positions.append(Vector2i(sprite_document.canvas_size.x - 1 - origin_position.x, origin_position.y))
	if mirror_vertical:
		candidate_positions.append(Vector2i(origin_position.x, sprite_document.canvas_size.y - 1 - origin_position.y))
	if mirror_horizontal and mirror_vertical:
		candidate_positions.append(Vector2i(sprite_document.canvas_size.x - 1 - origin_position.x, sprite_document.canvas_size.y - 1 - origin_position.y))
	for candidate_position: Vector2i in candidate_positions:
		var resolved_position: Vector2i = _wrap_position(candidate_position) if tiled_drawing else candidate_position
		if _is_paintable_position(resolved_position) and not paint_positions.has(resolved_position):
			paint_positions.append(resolved_position)
	return paint_positions

func _wrap_position(source_position: Vector2i) -> Vector2i:
	return Vector2i(posmod(source_position.x, sprite_document.canvas_size.x), posmod(source_position.y, sprite_document.canvas_size.y))

func _selected_layer() -> GatorSpriteLayer:
	return sprite_document.layers[active_layer_index]


func _selected_cel() -> GatorSpriteCel:
	return _selected_layer().ensure_cel(active_frame_index, sprite_document.canvas_size)


func _selected_image() -> Image:
	return _selected_cel().get_image(sprite_document.canvas_size)

func _store_selected_image(updated_image: Image) -> void:
	var selected_layer: GatorSpriteLayer = _selected_layer()
	if sprite_document.is_layer_effectively_locked(selected_layer):
		return
	selected_layer.ensure_cel(active_frame_index, sprite_document.canvas_size).set_image(updated_image)

func _finish_edit() -> void:
	canvas_refresh_requested = false
	refresh_canvas()
	pixels_changed.emit()

func set_pencil_brush_size(new_size: int) -> void:
	var clamped_size: int = clampi(new_size, 1, 256)
	if pencil_brush_size == clamped_size:
		return
	pencil_brush_size = clamped_size
	cached_circle_brush_size = 0
	cached_circle_row_spans = PackedInt32Array()
	queue_redraw()


func get_pencil_brush_size() -> int:
	return pencil_brush_size


func set_pencil_brush_shape(new_shape: int) -> void:
	pencil_brush_shape = clampi(
		new_shape,
		int(PencilBrushShape.SQUARE),
		int(PencilBrushShape.CIRCLE)
	)
	queue_redraw()


func get_pencil_brush_shape() -> int:
	return pencil_brush_shape


func set_eraser_brush_shape(new_shape: int) -> void:
	eraser_brush_shape = clampi(
		new_shape,
		int(PencilBrushShape.SQUARE),
		int(PencilBrushShape.CIRCLE)
	)
	queue_redraw()


func get_eraser_brush_shape() -> int:
	return eraser_brush_shape


func _get_active_standard_brush_shape() -> int:
	return eraser_brush_shape if tool_mode == ToolMode.ERASER else pencil_brush_shape


func _is_standard_brush_pixel(brush_x: int, brush_y: int, brush_shape: int) -> bool:
	if brush_shape == PencilBrushShape.SQUARE:
		return true
	var brush_center: float = float(pencil_brush_size - 1) * 0.5
	var brush_radius: float = maxf(0.5, float(pencil_brush_size) * 0.5 - 0.25)
	var offset_x: float = float(brush_x) - brush_center
	var offset_y: float = float(brush_y) - brush_center
	return offset_x * offset_x + offset_y * offset_y <= brush_radius * brush_radius


func is_live_draw_tool() -> bool:
	return tool_mode == ToolMode.PENCIL or tool_mode == ToolMode.ERASER or tool_mode == ToolMode.CUSTOM_BRUSH


func set_live_draw_frame(frame_index: int) -> void:
	if sprite_document == null:
		return
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if active_animation.frame_count <= 0:
		return
	var requested_frame_index: int = clampi(frame_index, 0, active_animation.frame_count - 1)
	if requested_frame_index == active_frame_index:
		return
	_commit_paint_buffer()
	active_frame_index = requested_frame_index
	last_pixel = Vector2i(-1, -1)
	if drawing and is_live_draw_tool() and _is_editable_position(hover_pixel):
		_push_undo_snapshot()
		paint_pixel(hover_pixel)
	else:
		refresh_canvas()

func set_custom_brush_from_path(image_path: String) -> Error:
	var loaded_brush: Image = Image.new()
	var load_error: Error = loaded_brush.load(image_path)
	if load_error != OK:
		return load_error
	return set_custom_brush_from_image(loaded_brush)

func set_custom_brush_from_image(source_image: Image) -> Error:
	if source_image == null or source_image.is_empty():
		return ERR_INVALID_DATA
	custom_brush_source_image = source_image.duplicate()
	if custom_brush_source_image.get_format() != Image.FORMAT_RGBA8:
		custom_brush_source_image.convert(Image.FORMAT_RGBA8)
	custom_brush_scale_percent = 100
	custom_brush_image = custom_brush_source_image.duplicate()
	_rebuild_custom_brush_cache()
	tool_mode = ToolMode.CUSTOM_BRUSH
	queue_redraw()
	return OK

func get_custom_brush_source_image() -> Image:
	return null if custom_brush_source_image == null else custom_brush_source_image.duplicate()

func get_document_brush_image() -> Image:
	if sprite_document == null:
		return null
	var source_image: Image = sprite_document.composite_frame(active_frame_index)
	if source_image == null or source_image.is_empty():
		return null
	var brush_image: Image = source_image.duplicate()
	if selection_mask != null and selection_rectangle.size != Vector2i.ZERO:
		var selected_bounds: Rect2i = selection_rectangle.intersection(Rect2i(Vector2i.ZERO, sprite_document.canvas_size))
		if selected_bounds.size == Vector2i.ZERO:
			return null
		var selected_source: Image = brush_image.get_region(selected_bounds)
		var selected_mask: Image = selection_mask.get_region(selected_bounds)
		var masked_image: Image = Image.create_empty(selected_bounds.size.x, selected_bounds.size.y, false, Image.FORMAT_RGBA8)
		masked_image.blend_rect_mask(selected_source, selected_mask, Rect2i(Vector2i.ZERO, selected_bounds.size), Vector2i.ZERO)
		brush_image = masked_image
	return _crop_to_opaque_pixels(brush_image)

func _crop_to_opaque_pixels(source_image: Image) -> Image:
	if source_image == null or source_image.is_empty():
		return null
	var minimum_pixel: Vector2i = source_image.get_size()
	var maximum_pixel: Vector2i = Vector2i(-1, -1)
	for pixel_y: int in range(source_image.get_height()):
		for pixel_x: int in range(source_image.get_width()):
			if source_image.get_pixel(pixel_x, pixel_y).a <= 0.0:
				continue
			minimum_pixel = Vector2i(mini(minimum_pixel.x, pixel_x), mini(minimum_pixel.y, pixel_y))
			maximum_pixel = Vector2i(maxi(maximum_pixel.x, pixel_x), maxi(maximum_pixel.y, pixel_y))
	if maximum_pixel.x < minimum_pixel.x or maximum_pixel.y < minimum_pixel.y:
		return null
	var opaque_bounds: Rect2i = Rect2i(minimum_pixel, maximum_pixel - minimum_pixel + Vector2i.ONE)
	return source_image.get_region(opaque_bounds)

func set_custom_brush_scale(scale_percent: int) -> Error:
	if custom_brush_source_image == null:
		return ERR_UNCONFIGURED
	custom_brush_scale_percent = clampi(scale_percent, 10, 1600)
	var source_size: Vector2i = custom_brush_source_image.get_size()
	var target_width: int = maxi(1, roundi(float(source_size.x) * float(custom_brush_scale_percent) / 100.0))
	var target_height: int = maxi(1, roundi(float(source_size.y) * float(custom_brush_scale_percent) / 100.0))
	custom_brush_image = custom_brush_source_image.duplicate()
	custom_brush_image.resize(target_width, target_height, Image.INTERPOLATE_NEAREST)
	_rebuild_custom_brush_cache()
	queue_redraw()
	return OK

func get_custom_brush_size() -> Vector2i:
	return Vector2i.ZERO if custom_brush_image == null else custom_brush_image.get_size()


func get_custom_brush_scale_percent() -> int:
	return custom_brush_scale_percent

func set_custom_brush_spacing(spacing_percent: int) -> void:
	custom_brush_spacing_percent = clampi(spacing_percent, 1, 400)

func get_custom_brush_spacing() -> int:
	return custom_brush_spacing_percent

func _get_custom_brush_spacing_pixels() -> float:
	if custom_brush_image == null or custom_brush_image.is_empty():
		return 1.0
	var largest_dimension: int = maxi(custom_brush_image.get_width(), custom_brush_image.get_height())
	return maxf(1.0, float(largest_dimension) * float(custom_brush_spacing_percent) / 100.0)

func clear_selection() -> void:
	selection_rectangle = Rect2i()
	selection_image = null
	selection_mask = null
	moving_selection = false
	queue_redraw()

func copy_selection() -> bool:
	if sprite_document == null or selection_mask == null or selection_rectangle.size == Vector2i.ZERO:
		return false
	selection_clipboard_image = _selected_image().get_region(selection_rectangle)
	selection_clipboard_mask = selection_mask.get_region(selection_rectangle)
	selection_clipboard_origin = selection_rectangle.position
	return true

func paste_selection() -> bool:
	if sprite_document == null or selection_clipboard_image == null or selection_clipboard_mask == null:
		return false
	if selection_clipboard_image.is_empty() or selection_clipboard_mask.is_empty():
		return false
	_push_undo_snapshot()
	var clipboard_size: Vector2i = selection_clipboard_image.get_size()
	var pasted_origin: Vector2i = selection_clipboard_origin + Vector2i.ONE
	pasted_origin.x = clampi(pasted_origin.x, 0, sprite_document.canvas_size.x - clipboard_size.x)
	pasted_origin.y = clampi(pasted_origin.y, 0, sprite_document.canvas_size.y - clipboard_size.y)
	var selected_image: Image = _selected_image()
	selected_image.blend_rect_mask(selection_clipboard_image, selection_clipboard_mask, Rect2i(Vector2i.ZERO, clipboard_size), pasted_origin)
	_store_selected_image(selected_image)
	selection_mask = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	selection_mask.blit_rect(selection_clipboard_mask, Rect2i(Vector2i.ZERO, clipboard_size), pasted_origin)
	_refresh_selection_bounds()
	_refresh_selection_image()
	_finish_edit()
	return true

func invalidate_tile_stamp_preview() -> void:
	tile_stamp_preview_texture = null
	tile_stamp_preview_index = -1
	queue_redraw()

func _paint_custom_brush(selected_image: Image, pixel_position: Vector2i, erase_pixels: bool) -> void:
	if custom_brush_image == null:
		return
	var active_brush_image: Image = custom_brush_image
	var active_brush_anchor: Vector2i = custom_brush_anchor
	var use_source_colors: bool = false
	if custom_brush_stamp_provider.is_valid():
		var provider_result: Variant = custom_brush_stamp_provider.call(custom_brush_image, custom_brush_anchor)
		if provider_result is Dictionary:
			var brush_data: Dictionary = provider_result
			var provided_image: Image = brush_data.get("image", null) as Image
			if provided_image != null and not provided_image.is_empty():
				active_brush_image = provided_image
				var provided_anchor: Variant = brush_data.get("anchor", _calculate_custom_brush_anchor(active_brush_image))
				if provided_anchor is Vector2i:
					active_brush_anchor = provided_anchor
			use_source_colors = bool(brush_data.get("use_source_colors", false))
	if selection_mask == null and not tiled_drawing and not erase_pixels:
		var destination_origin: Vector2i = pixel_position - active_brush_anchor
		var destination_rectangle: Rect2i = Rect2i(destination_origin, active_brush_image.get_size()).intersection(Rect2i(Vector2i.ZERO, sprite_document.canvas_size))
		if destination_rectangle.size.x <= 0 or destination_rectangle.size.y <= 0:
			return
		var source_position: Vector2i = destination_rectangle.position - destination_origin
		var source_rectangle: Rect2i = Rect2i(source_position, destination_rectangle.size)
		if use_source_colors:
			selected_image.blend_rect(active_brush_image, source_rectangle, destination_rectangle.position)
		else:
			selected_image.blend_rect_mask(_get_custom_brush_stamp_image_for(active_brush_image.get_size()), active_brush_image, source_rectangle, destination_rectangle.position)
		return
	for brush_y: int in range(active_brush_image.get_height()):
		for brush_x: int in range(active_brush_image.get_width()):
			var brush_pixel: Color = active_brush_image.get_pixel(brush_x, brush_y)
			if brush_pixel.a <= 0.0:
				continue
			var destination_pixel: Vector2i = pixel_position + Vector2i(brush_x, brush_y) - active_brush_anchor
			if tiled_drawing:
				destination_pixel = _wrap_position(destination_pixel)
			if not _is_editable_position(destination_pixel):
				continue
			var applied_color: Color = Color.TRANSPARENT
			if not erase_pixels:
				if use_source_colors:
					applied_color = brush_pixel
				else:
					applied_color = sprite_document.resolve_palette_color(Color(brush_color.r, brush_color.g, brush_color.b, brush_color.a * brush_pixel.a))
			selected_image.set_pixelv(destination_pixel, applied_color)

func _get_custom_brush_stamp_image_for(brush_size: Vector2i) -> Image:
	var resolved_color: Color = sprite_document.resolve_palette_color(brush_color)
	var cache_key: String = "%d:%d:%d" % [brush_size.x, brush_size.y, resolved_color.to_rgba32()]
	if custom_brush_stamp_images.has(cache_key):
		return custom_brush_stamp_images[cache_key] as Image
	var stamp_image: Image = Image.create_empty(brush_size.x, brush_size.y, false, Image.FORMAT_RGBA8)
	stamp_image.fill(resolved_color)
	custom_brush_stamp_images[cache_key] = stamp_image
	return stamp_image

func _calculate_custom_brush_anchor(brush_image: Image) -> Vector2i:
	if brush_image == null or brush_image.is_empty():
		return Vector2i.ZERO
	var minimum_pixel: Vector2i = brush_image.get_size()
	var maximum_pixel: Vector2i = Vector2i(-1, -1)
	for brush_y: int in range(brush_image.get_height()):
		for brush_x: int in range(brush_image.get_width()):
			if brush_image.get_pixel(brush_x, brush_y).a <= 0.0:
				continue
			minimum_pixel = Vector2i(mini(minimum_pixel.x, brush_x), mini(minimum_pixel.y, brush_y))
			maximum_pixel = Vector2i(maxi(maximum_pixel.x, brush_x), maxi(maximum_pixel.y, brush_y))
	if maximum_pixel.x < minimum_pixel.x or maximum_pixel.y < minimum_pixel.y:
		return Vector2i(brush_image.get_width() / 2, brush_image.get_height() / 2)
	return minimum_pixel + Vector2i((maximum_pixel.x - minimum_pixel.x) / 2, (maximum_pixel.y - minimum_pixel.y) / 2)

func _rebuild_custom_brush_cache() -> void:
	custom_brush_anchor = Vector2i.ZERO
	custom_brush_preview_texture = null
	custom_brush_stamp_image = null
	custom_brush_stamp_color_rgba = -1
	custom_brush_stamp_images.clear()
	if custom_brush_image == null or custom_brush_image.is_empty():
		return
	var minimum_pixel: Vector2i = custom_brush_image.get_size()
	var maximum_pixel: Vector2i = Vector2i(-1, -1)
	var preview_image: Image = Image.create_empty(custom_brush_image.get_width(), custom_brush_image.get_height(), false, Image.FORMAT_RGBA8)
	for brush_y: int in range(custom_brush_image.get_height()):
		for brush_x: int in range(custom_brush_image.get_width()):
			var brush_alpha: float = custom_brush_image.get_pixel(brush_x, brush_y).a
			if brush_alpha <= 0.0:
				continue
			minimum_pixel = Vector2i(mini(minimum_pixel.x, brush_x), mini(minimum_pixel.y, brush_y))
			maximum_pixel = Vector2i(maxi(maximum_pixel.x, brush_x), maxi(maximum_pixel.y, brush_y))
			preview_image.set_pixel(brush_x, brush_y, Color(1.0, 1.0, 1.0, brush_alpha))
	if maximum_pixel.x < minimum_pixel.x or maximum_pixel.y < minimum_pixel.y:
		custom_brush_anchor = Vector2i(custom_brush_image.get_width() / 2, custom_brush_image.get_height() / 2)
	else:
		custom_brush_anchor = minimum_pixel + Vector2i((maximum_pixel.x - minimum_pixel.x) / 2, (maximum_pixel.y - minimum_pixel.y) / 2)
	custom_brush_preview_texture = ImageTexture.create_from_image(preview_image)

func _get_custom_brush_anchor() -> Vector2i:
	return custom_brush_anchor

func _apply_selection_rectangle(start_pixel: Vector2i, end_pixel: Vector2i, edit_mode: SelectionEditMode) -> void:
	var minimum_pixel: Vector2i = Vector2i(mini(start_pixel.x, end_pixel.x), mini(start_pixel.y, end_pixel.y))
	var maximum_pixel: Vector2i = Vector2i(maxi(start_pixel.x, end_pixel.x), maxi(start_pixel.y, end_pixel.y))
	var edited_rectangle: Rect2i = Rect2i(minimum_pixel, maximum_pixel - minimum_pixel + Vector2i.ONE)
	if edit_mode == SelectionEditMode.REPLACE or selection_mask == null:
		selection_mask = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	var mask_color: Color = Color.TRANSPARENT if edit_mode == SelectionEditMode.SUBTRACT else Color.WHITE
	selection_mask.fill_rect(edited_rectangle, mask_color)
	_refresh_selection_bounds()
	_refresh_selection_image()

func _is_selected_position(pixel_position: Vector2i) -> bool:
	return selection_mask != null and _is_paintable_position(pixel_position) and selection_mask.get_pixelv(pixel_position).a > 0.0

func _refresh_selection_bounds() -> void:
	if selection_mask == null:
		selection_rectangle = Rect2i()
		return
	var minimum_pixel: Vector2i = sprite_document.canvas_size
	var maximum_pixel: Vector2i = Vector2i(-1, -1)
	for pixel_y: int in range(sprite_document.canvas_size.y):
		for pixel_x: int in range(sprite_document.canvas_size.x):
			if selection_mask.get_pixel(pixel_x, pixel_y).a > 0.0:
				minimum_pixel = Vector2i(mini(minimum_pixel.x, pixel_x), mini(minimum_pixel.y, pixel_y))
				maximum_pixel = Vector2i(maxi(maximum_pixel.x, pixel_x), maxi(maximum_pixel.y, pixel_y))
	if maximum_pixel.x < minimum_pixel.x or maximum_pixel.y < minimum_pixel.y:
		clear_selection()
		return
	selection_rectangle = Rect2i(minimum_pixel, maximum_pixel - minimum_pixel + Vector2i.ONE)

func _preview_move_selection(move_delta: Vector2i) -> void:
	if selection_image == null or selection_move_source_mask == null or selection_move_source_image == null:
		return
	var selected_image: Image = selection_move_source_image.duplicate()
	var selection_mask_region: Image = selection_move_source_mask.get_region(selection_move_original_rectangle)
	for source_y: int in range(selection_move_original_rectangle.size.y):
		for source_x: int in range(selection_move_original_rectangle.size.x):
			if selection_mask_region.get_pixel(source_x, source_y).a > 0.0:
				selected_image.set_pixelv(selection_move_original_rectangle.position + Vector2i(source_x, source_y), Color.TRANSPARENT)
	var destination_position: Vector2i = selection_move_origin + move_delta
	selected_image.blend_rect_mask(selection_image, selection_mask_region, Rect2i(Vector2i.ZERO, selection_image.get_size()), destination_position)
	var moved_mask: Image = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	moved_mask.blit_rect(selection_mask_region, Rect2i(Vector2i.ZERO, selection_mask_region.get_size()), destination_position)
	selection_mask = moved_mask
	_refresh_selection_bounds()
	_store_selected_image(selected_image)
	refresh_canvas()

func _push_undo_snapshot() -> void:
	if not _is_paintable_position(Vector2i.ZERO):
		return
	undo_stack.append(_selected_cel().png_bytes.duplicate())
	undo_selection_stack.append(selection_rectangle)
	undo_selection_masks.append(_selection_mask_to_buffer())
	undo_frame_stack.append(active_frame_index)
	undo_layer_stack.append(active_layer_index)
	if undo_stack.size() > 64:
		undo_stack.pop_front()
		undo_selection_stack.pop_front()
		undo_selection_masks.pop_front()
		undo_frame_stack.pop_front()
		undo_layer_stack.pop_front()
	redo_stack.clear()
	redo_selection_stack.clear()
	redo_selection_masks.clear()
	redo_frame_stack.clear()
	redo_layer_stack.clear()

func undo() -> void:
	if undo_stack.is_empty() or sprite_document == null:
		return
	var prior_frame_index: int = undo_frame_stack.pop_back()
	var prior_layer_index: int = undo_layer_stack.pop_back()
	active_frame_index = clampi(prior_frame_index, 0, sprite_document.get_active_animation().frame_count - 1)
	active_layer_index = clampi(prior_layer_index, 0, sprite_document.layers.size() - 1)
	redo_stack.append(_selected_cel().png_bytes.duplicate())
	redo_selection_stack.append(selection_rectangle)
	redo_selection_masks.append(_selection_mask_to_buffer())
	redo_frame_stack.append(active_frame_index)
	redo_layer_stack.append(active_layer_index)
	var prior_data: PackedByteArray = undo_stack.pop_back()
	var prior_selection: Rect2i = undo_selection_stack.pop_back()
	var prior_selection_mask: PackedByteArray = undo_selection_masks.pop_back()
	var prior_image: Image = Image.new()
	if prior_image.load_png_from_buffer(prior_data) == OK:
		_store_selected_image(prior_image)
		selection_rectangle = prior_selection
		_restore_selection_mask(prior_selection_mask)
		_finish_edit()

func redo() -> void:
	if redo_stack.is_empty() or sprite_document == null:
		return
	var future_frame_index: int = redo_frame_stack.pop_back()
	var future_layer_index: int = redo_layer_stack.pop_back()
	active_frame_index = clampi(future_frame_index, 0, sprite_document.get_active_animation().frame_count - 1)
	active_layer_index = clampi(future_layer_index, 0, sprite_document.layers.size() - 1)
	undo_stack.append(_selected_cel().png_bytes.duplicate())
	undo_selection_stack.append(selection_rectangle)
	undo_selection_masks.append(_selection_mask_to_buffer())
	undo_frame_stack.append(active_frame_index)
	undo_layer_stack.append(active_layer_index)
	var future_data: PackedByteArray = redo_stack.pop_back()
	var future_selection: Rect2i = redo_selection_stack.pop_back()
	var future_selection_mask: PackedByteArray = redo_selection_masks.pop_back()
	var future_image: Image = Image.new()
	if future_image.load_png_from_buffer(future_data) == OK:
		_store_selected_image(future_image)
		selection_rectangle = future_selection
		_restore_selection_mask(future_selection_mask)
		_finish_edit()

func _fill_pixels(origin_pixel: Vector2i) -> void:
	var selected_image: Image = _selected_image()
	var original_color: Color = selected_image.get_pixelv(origin_pixel)
	if original_color.is_equal_approx(brush_color):
		return
	var pixels_to_visit: Array[Vector2i] = [origin_pixel]
	while not pixels_to_visit.is_empty():
		var current_pixel: Vector2i = pixels_to_visit.pop_back()
		if not _is_editable_position(current_pixel) or not sprite_document.colors_match(selected_image.get_pixelv(current_pixel), original_color):
			continue
		selected_image.set_pixelv(current_pixel, sprite_document.resolve_palette_color(brush_color))
		pixels_to_visit.append_array([current_pixel + Vector2i.LEFT, current_pixel + Vector2i.RIGHT, current_pixel + Vector2i.UP, current_pixel + Vector2i.DOWN])
	_store_selected_image(selected_image)

func _pattern_fill_pixels(origin_pixel: Vector2i) -> void:
	var selected_image: Image = _selected_image()
	var original_color: Color = selected_image.get_pixelv(origin_pixel)
	var pixels_to_visit: Array[Vector2i] = [origin_pixel]
	while not pixels_to_visit.is_empty():
		var current_pixel: Vector2i = pixels_to_visit.pop_back()
		if not _is_editable_position(current_pixel) or not sprite_document.colors_match(selected_image.get_pixelv(current_pixel), original_color):
			continue
		var pattern_color: Color = brush_color if posmod(current_pixel.x + current_pixel.y, 2) == 0 else secondary_color
		selected_image.set_pixelv(current_pixel, sprite_document.resolve_palette_color(pattern_color))
		pixels_to_visit.append_array([current_pixel + Vector2i.LEFT, current_pixel + Vector2i.RIGHT, current_pixel + Vector2i.UP, current_pixel + Vector2i.DOWN])
	_store_selected_image(selected_image)

func _stamp_tile(pixel_position: Vector2i) -> void:
	if sprite_document.tileset == null or sprite_document.tilemap == null:
		return
	var tileset_image: Image = sprite_document.tileset.get_source_image()
	if tileset_image.is_empty():
		return
	var tile_size: Vector2i = sprite_document.tileset.tile_size
	var tile_columns: int = sprite_document.tileset.get_columns()
	if active_tile_index < 0 or active_tile_index >= sprite_document.tileset.get_tile_count():
		return
	var cell_position: Vector2i = Vector2i(pixel_position.x / tile_size.x, pixel_position.y / tile_size.y)
	var destination_position: Vector2i = cell_position * tile_size
	var source_position: Vector2i = Vector2i(active_tile_index % tile_columns, active_tile_index / tile_columns) * tile_size
	var selected_image: Image = _selected_image()
	selected_image.blend_rect(tileset_image, Rect2i(source_position, tile_size), destination_position)
	sprite_document.tilemap.set_cell(cell_position, active_tile_index)
	_store_selected_image(selected_image)

func _get_tile_stamp_destination(pixel_position: Vector2i) -> Rect2i:
	if sprite_document == null or sprite_document.tileset == null:
		return Rect2i()
	var tile_size: Vector2i = sprite_document.tileset.tile_size
	if tile_size.x <= 0 or tile_size.y <= 0:
		return Rect2i()
	var cell_position: Vector2i = Vector2i(pixel_position.x / tile_size.x, pixel_position.y / tile_size.y)
	return Rect2i(cell_position * tile_size, tile_size)

func _draw_tile_stamp_preview(pixel_position: Vector2i) -> void:
	if sprite_document.tileset == null or not _is_paintable_position(pixel_position):
		return
	var tileset_image: Image = sprite_document.tileset.get_source_image()
	if tileset_image.is_empty() or active_tile_index < 0 or active_tile_index >= sprite_document.tileset.get_tile_count():
		return
	var tile_size: Vector2i = sprite_document.tileset.tile_size
	var tile_columns: int = sprite_document.tileset.get_columns()
	if tile_stamp_preview_texture == null or tile_stamp_preview_index != active_tile_index:
		var source_position: Vector2i = Vector2i(active_tile_index % tile_columns, active_tile_index / tile_columns) * tile_size
		var tile_image: Image = tileset_image.get_region(Rect2i(source_position, tile_size))
		tile_stamp_preview_texture = ImageTexture.create_from_image(tile_image)
		tile_stamp_preview_index = active_tile_index
	var destination_rectangle: Rect2i = _get_tile_stamp_destination(pixel_position)
	var display_rectangle: Rect2 = Rect2(Vector2(destination_rectangle.position) * zoom_level, Vector2(destination_rectangle.size) * zoom_level)
	draw_rect(display_rectangle, Color(0.24, 0.8, 1.0, 0.16), true)
	draw_texture_rect(tile_stamp_preview_texture, display_rectangle, false, Color(1.0, 1.0, 1.0, 0.72))
	draw_rect(display_rectangle, Color("62d6ff"), false, 2.0)

func _draw_dither_rectangle(start_pixel: Vector2i, end_pixel: Vector2i) -> void:
	var minimum_pixel: Vector2i = Vector2i(mini(start_pixel.x, end_pixel.x), mini(start_pixel.y, end_pixel.y))
	var maximum_pixel: Vector2i = Vector2i(maxi(start_pixel.x, end_pixel.x), maxi(start_pixel.y, end_pixel.y))
	var selected_image: Image = _selected_image()
	for pixel_y: int in range(minimum_pixel.y, maximum_pixel.y + 1):
		for pixel_x: int in range(minimum_pixel.x, maximum_pixel.x + 1):
			var current_pixel: Vector2i = Vector2i(pixel_x, pixel_y)
			if _is_editable_position(current_pixel):
				var dither_color: Color = brush_color if posmod(pixel_x + pixel_y, 2) == 0 else secondary_color
				selected_image.set_pixelv(current_pixel, sprite_document.resolve_palette_color(dither_color))
	_store_selected_image(selected_image)

func _draw_gradient(start_pixel: Vector2i, end_pixel: Vector2i) -> void:
	var gradient_delta: Vector2 = Vector2(end_pixel - start_pixel)
	var gradient_length_squared: float = gradient_delta.length_squared()
	var selected_image: Image = _selected_image()
	for pixel_y: int in range(sprite_document.canvas_size.y):
		for pixel_x: int in range(sprite_document.canvas_size.x):
			var current_pixel: Vector2i = Vector2i(pixel_x, pixel_y)
			if not _is_editable_position(current_pixel):
				continue
			var interpolation: float = 1.0 if gradient_length_squared <= 0.0 else clampf(Vector2(current_pixel - start_pixel).dot(gradient_delta) / gradient_length_squared, 0.0, 1.0)
			selected_image.set_pixelv(current_pixel, sprite_document.resolve_palette_color(secondary_color.lerp(brush_color, interpolation)))
	_store_selected_image(selected_image)

func _draw_line(start_pixel: Vector2i, end_pixel: Vector2i) -> void:
	var selected_image: Image = _selected_image()
	var delta_x: int = absi(end_pixel.x - start_pixel.x)
	var step_x: int = 1 if start_pixel.x < end_pixel.x else -1
	var delta_y: int = -absi(end_pixel.y - start_pixel.y)
	var step_y: int = 1 if start_pixel.y < end_pixel.y else -1
	var error_value: int = delta_x + delta_y
	var current_pixel: Vector2i = start_pixel
	while true:
		if _is_editable_position(current_pixel):
			selected_image.set_pixelv(current_pixel, sprite_document.resolve_palette_color(brush_color))
		if current_pixel == end_pixel:
			break
		var doubled_error: int = 2 * error_value
		if doubled_error >= delta_y:
			error_value += delta_y
			current_pixel.x += step_x
		if doubled_error <= delta_x:
			error_value += delta_x
			current_pixel.y += step_y
	_store_selected_image(selected_image)

func _draw_rectangle(start_pixel: Vector2i, end_pixel: Vector2i) -> void:
	_draw_line(start_pixel, Vector2i(end_pixel.x, start_pixel.y))
	_draw_line(Vector2i(end_pixel.x, start_pixel.y), end_pixel)
	_draw_line(end_pixel, Vector2i(start_pixel.x, end_pixel.y))
	_draw_line(Vector2i(start_pixel.x, end_pixel.y), start_pixel)

func _draw_preview_pixel(pixel_position: Vector2i) -> void:
	if not _is_editable_position(pixel_position):
		return
	var pixel_rectangle: Rect2 = Rect2(Vector2(pixel_position) * zoom_level, Vector2.ONE * zoom_level)
	draw_rect(pixel_rectangle, Color(brush_color, 0.55), true)
	draw_rect(pixel_rectangle, Color.WHITE, false, 1.0)

func _draw_preview_standard_brush(pixel_position: Vector2i) -> void:
	var brush_anchor_offset: int = floori(float(pencil_brush_size - 1) / 2.0)
	var top_left: Vector2 = Vector2(pixel_position - Vector2i(brush_anchor_offset, brush_anchor_offset)) * zoom_level
	var preview_size: Vector2 = Vector2(pencil_brush_size, pencil_brush_size) * zoom_level
	var fill_color: Color = Color(brush_color.r, brush_color.g, brush_color.b, 0.22)
	var outline_color: Color = Color.WHITE
	if _get_active_standard_brush_shape() == int(PencilBrushShape.CIRCLE):
		var center: Vector2 = top_left + preview_size * 0.5
		var radius: float = maxf(zoom_level * 0.5, preview_size.x * 0.5)
		draw_circle(center, radius, fill_color)
		draw_arc(center, radius, 0.0, TAU, 48, outline_color, 1.0, true)
	else:
		var preview_rectangle: Rect2 = Rect2(top_left, preview_size)
		draw_rect(preview_rectangle, fill_color, true)
		draw_rect(preview_rectangle, outline_color, false, 1.0)


func _draw_preview_brush(pixel_position: Vector2i) -> void:
	if custom_brush_image == null or custom_brush_preview_texture == null:
		_draw_preview_pixel(pixel_position)
		return
	var top_left: Vector2 = Vector2(pixel_position - custom_brush_anchor) * zoom_level
	var preview_rectangle: Rect2 = Rect2(top_left, Vector2(custom_brush_image.get_size()) * zoom_level)
	draw_texture_rect(custom_brush_preview_texture, preview_rectangle, false, Color(brush_color.r, brush_color.g, brush_color.b, 0.55))
	draw_rect(preview_rectangle, Color.WHITE, false, 1.0)

func _refresh_selection_image() -> void:
	if selection_mask == null or selection_rectangle.size == Vector2i.ZERO:
		selection_image = null
		return
	selection_image = _selected_image().get_region(selection_rectangle)

func flip_selection(horizontal: bool) -> void:
	if selection_mask == null:
		return
	_apply_selection_transform("flip_horizontal" if horizontal else "flip_vertical")

func rotate_selection(clockwise: bool) -> void:
	if selection_mask == null:
		return
	_apply_selection_transform("rotate_clockwise" if clockwise else "rotate_counter_clockwise")

func scale_selection(scale_factor: int) -> void:
	if selection_mask == null or scale_factor == 0:
		return
	_apply_selection_transform("scale_up" if scale_factor > 0 else "scale_down")

func skew_selection(rightward: bool) -> void:
	if selection_mask == null:
		return
	_apply_selection_transform("skew_right" if rightward else "skew_left")

func _apply_selection_transform(transform_name: String) -> void:
	if selection_mask == null or selection_rectangle.size == Vector2i.ZERO:
		return
	_push_undo_snapshot()
	var source_image: Image = _selected_image()
	var source_mask: Image = selection_mask.duplicate()
	var transformed_image: Image = source_image.duplicate()
	var transformed_mask: Image = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	for source_y: int in range(selection_rectangle.position.y, selection_rectangle.end.y):
		for source_x: int in range(selection_rectangle.position.x, selection_rectangle.end.x):
			var source_position: Vector2i = Vector2i(source_x, source_y)
			if source_mask.get_pixelv(source_position).a <= 0.0:
				continue
			transformed_image.set_pixelv(source_position, Color.TRANSPARENT)
	for source_y: int in range(selection_rectangle.position.y, selection_rectangle.end.y):
		for source_x: int in range(selection_rectangle.position.x, selection_rectangle.end.x):
			var source_position: Vector2i = Vector2i(source_x, source_y)
			if source_mask.get_pixelv(source_position).a <= 0.0:
				continue
			var local_position: Vector2i = source_position - selection_rectangle.position
			var transformed_positions: Array[Vector2i] = _get_transform_positions(local_position, transform_name)
			for transformed_local_position: Vector2i in transformed_positions:
				var destination_position: Vector2i = selection_rectangle.position + transformed_local_position
				if not _is_paintable_position(destination_position):
					continue
				var source_color: Color = source_image.get_pixelv(source_position)
				if source_color.a > 0.0:
					transformed_image.set_pixelv(destination_position, source_color)
				transformed_mask.set_pixelv(destination_position, Color.WHITE)
	selection_mask = transformed_mask
	_refresh_selection_bounds()
	_refresh_selection_image()
	_store_selected_image(transformed_image)
	_finish_edit()

func _get_transform_positions(local_position: Vector2i, transform_name: String) -> Array[Vector2i]:
	var width: int = selection_rectangle.size.x
	var height: int = selection_rectangle.size.y
	match transform_name:
		"flip_horizontal":
			return [Vector2i(width - 1 - local_position.x, local_position.y)]
		"flip_vertical":
			return [Vector2i(local_position.x, height - 1 - local_position.y)]
		"rotate_clockwise":
			return [Vector2i(height - 1 - local_position.y, local_position.x)]
		"rotate_counter_clockwise":
			return [Vector2i(local_position.y, width - 1 - local_position.x)]
		"scale_up":
			return [Vector2i(local_position.x * 2, local_position.y * 2), Vector2i(local_position.x * 2 + 1, local_position.y * 2), Vector2i(local_position.x * 2, local_position.y * 2 + 1), Vector2i(local_position.x * 2 + 1, local_position.y * 2 + 1)]
		"scale_down":
			return [Vector2i(local_position.x / 2, local_position.y / 2)]
		"skew_right":
			return [Vector2i(local_position.x + local_position.y, local_position.y)]
		"skew_left":
			return [Vector2i(local_position.x + height - 1 - local_position.y, local_position.y)]
		_:
			return [local_position]

func _selection_mask_to_buffer() -> PackedByteArray:
	return PackedByteArray() if selection_mask == null else selection_mask.save_png_to_buffer()

func _restore_selection_mask(mask_data: PackedByteArray) -> void:
	if mask_data.is_empty():
		selection_mask = null
		selection_rectangle = Rect2i()
		selection_image = null
		return
	var restored_mask: Image = Image.new()
	if restored_mask.load_png_from_buffer(mask_data) == OK:
		selection_mask = restored_mask
		_refresh_selection_bounds()
		_refresh_selection_image()

func _draw_preview_line(start_pixel: Vector2i, end_pixel: Vector2i) -> void:
	var preview_point: Vector2i = start_pixel
	var delta_x: int = absi(end_pixel.x - start_pixel.x)
	var step_x: int = 1 if start_pixel.x < end_pixel.x else -1
	var delta_y: int = -absi(end_pixel.y - start_pixel.y)
	var step_y: int = 1 if start_pixel.y < end_pixel.y else -1
	var error_value: int = delta_x + delta_y
	while true:
		_draw_preview_pixel(preview_point)
		if preview_point == end_pixel:
			break
		var doubled_error: int = error_value * 2
		if doubled_error >= delta_y:
			error_value += delta_y
			preview_point.x += step_x
		if doubled_error <= delta_x:
			error_value += delta_x
			preview_point.y += step_y

func _draw() -> void:
	if sprite_document == null:
		return
	var canvas_rectangle: Rect2 = Rect2(Vector2.ZERO, Vector2(sprite_document.canvas_size) * zoom_level)
	draw_rect(canvas_rectangle, Color("363a40"))
	if onion_texture != null:
		draw_texture_rect(onion_texture, canvas_rectangle, false, Color(1.0, 1.0, 1.0, 0.24))
	if display_texture != null:
		draw_texture_rect(display_texture, canvas_rectangle, false)
	if show_grid and zoom_level >= 6.0:
		for grid_x: int in range(sprite_document.canvas_size.x + 1):
			var line_x: float = float(grid_x) * zoom_level
			draw_line(Vector2(line_x, 0.0), Vector2(line_x, canvas_rectangle.size.y), Color(0.0, 0.0, 0.0, 0.3), 1.0)
		for grid_y: int in range(sprite_document.canvas_size.y + 1):
			var line_y: float = float(grid_y) * zoom_level
			draw_line(Vector2(0.0, line_y), Vector2(canvas_rectangle.size.x, line_y), Color(0.0, 0.0, 0.0, 0.3), 1.0)
	if drawing and (tool_mode == ToolMode.LINE or tool_mode == ToolMode.RECTANGLE or tool_mode == ToolMode.GRADIENT or tool_mode == ToolMode.DITHER) and _is_paintable_position(hover_pixel):
		if tool_mode == ToolMode.LINE:
			_draw_preview_line(drag_start_pixel, hover_pixel)
		elif tool_mode == ToolMode.RECTANGLE or tool_mode == ToolMode.DITHER:
			_draw_preview_line(drag_start_pixel, Vector2i(hover_pixel.x, drag_start_pixel.y))
			_draw_preview_line(Vector2i(hover_pixel.x, drag_start_pixel.y), hover_pixel)
			_draw_preview_line(hover_pixel, Vector2i(drag_start_pixel.x, hover_pixel.y))
			_draw_preview_line(Vector2i(drag_start_pixel.x, hover_pixel.y), drag_start_pixel)
		else:
			_draw_preview_line(drag_start_pixel, hover_pixel)
	_draw_selection_mask()
	if drawing and tool_mode == ToolMode.SELECTION and not moving_selection and _is_paintable_position(hover_pixel):
		var preview_minimum: Vector2i = Vector2i(mini(drag_start_pixel.x, hover_pixel.x), mini(drag_start_pixel.y, hover_pixel.y))
		var preview_size: Vector2i = Vector2i(absi(drag_start_pixel.x - hover_pixel.x) + 1, absi(drag_start_pixel.y - hover_pixel.y) + 1)
		draw_rect(Rect2(Vector2(preview_minimum) * zoom_level, Vector2(preview_size) * zoom_level), Color("ffffff"), false, 1.0)
	if not drawing and _is_editable_position(hover_pixel) and (tool_mode == ToolMode.PENCIL or tool_mode == ToolMode.ERASER or tool_mode == ToolMode.CUSTOM_BRUSH):
		if tool_mode == ToolMode.CUSTOM_BRUSH and custom_brush_image != null:
			_draw_preview_brush(hover_pixel)
		else:
			_draw_preview_standard_brush(hover_pixel)
	if not drawing and tool_mode == ToolMode.TILE_STAMP:
		_draw_tile_stamp_preview(hover_pixel)

func _draw_selection_mask() -> void:
	if selection_mask == null or selection_rectangle.size == Vector2i.ZERO:
		return
	for pixel_y: int in range(selection_rectangle.position.y, selection_rectangle.end.y):
		for pixel_x: int in range(selection_rectangle.position.x, selection_rectangle.end.x):
			var selected_pixel: Vector2i = Vector2i(pixel_x, pixel_y)
			if not _is_selected_position(selected_pixel):
				continue
			var selected_draw_rectangle: Rect2 = Rect2(Vector2(selected_pixel) * zoom_level, Vector2.ONE * zoom_level)
			draw_rect(selected_draw_rectangle, Color(0.38, 0.84, 1.0, 0.12), true)
			draw_rect(selected_draw_rectangle, Color("62d6ff"), false, 1.0)
