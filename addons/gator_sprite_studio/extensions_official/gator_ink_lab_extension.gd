@tool
extends GatorSpriteExtension

## Official bundled extension for outlines, lighting effects, cleanup, colour adjustment, and pixel extraction.

enum TargetMode { ACTIVE_CEL, SELECTED_FRAMES, CURRENT_LAYER }
enum OutlineMode { OUTSIDE, INSIDE }

var target_menu: OptionButton
var outline_mode_menu: OptionButton
var effect_color_picker: ColorPickerButton
var outline_thickness_input: SpinBox
var shadow_x_input: SpinBox
var shadow_y_input: SpinBox
var glow_radius_input: SpinBox
var highlight_x_input: SpinBox
var highlight_y_input: SpinBox
var cleanup_isolated_input: SpinBox
var cleanup_gap_input: SpinBox
var hue_input: SpinBox
var saturation_input: SpinBox
var value_input: SpinBox
var alpha_input: SpinBox
var status_label: Label

func get_extension_manifest() -> Dictionary:
	return {
		"id": "blackwater.gss.ink_lab",
		"name": "Gator Ink Lab",
		"version": "1.1.0",
		"dependencies": PackedStringArray()
	}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	context.register_sidebar_panel("ink_lab", "Ink Lab", _build_panel())
	context.register_command("open_ink_lab", "Open Gator Ink Lab", _focus_panel)

func on_document_ready(_sprite_document: GatorSpriteDocument) -> void:
	_update_status("Ready.")

func _focus_panel() -> void:
	context.focus_sidebar_panel("ink_lab")

func _build_panel() -> Control:
	var panel_scroll: ScrollContainer = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel_layout: VBoxContainer = VBoxContainer.new()
	panel_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel_layout)

	panel_layout.add_child(_make_heading("GATOR INK LAB"))
	var description: Label = Label.new()
	description.text = "Apply outlines, shadows, highlights, glow, silhouettes, cleanup, selections, and colour adjustments."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(description)

	panel_layout.add_child(_make_heading("TARGET"))
	target_menu = OptionButton.new()
	target_menu.add_item("Active Cel", int(TargetMode.ACTIVE_CEL))
	target_menu.add_item("Selected Frames", int(TargetMode.SELECTED_FRAMES))
	target_menu.add_item("Current Layer, All Frames", int(TargetMode.CURRENT_LAYER))
	panel_layout.add_child(target_menu)

	var colour_row: HBoxContainer = HBoxContainer.new()
	colour_row.add_child(_make_label("Effect Colour"))
	effect_color_picker = ColorPickerButton.new()
	effect_color_picker.color = Color.BLACK
	effect_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colour_row.add_child(effect_color_picker)
	panel_layout.add_child(colour_row)

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("OUTLINE AND SILHOUETTE"))
	outline_mode_menu = OptionButton.new()
	outline_mode_menu.add_item("Outside Outline", int(OutlineMode.OUTSIDE))
	outline_mode_menu.add_item("Inside Outline", int(OutlineMode.INSIDE))
	panel_layout.add_child(outline_mode_menu)
	outline_thickness_input = _add_spin_row(panel_layout, "Thickness", 1.0, 16.0, 1.0, " px")
	panel_layout.add_child(_make_button("Apply Outline", _apply_outline))
	panel_layout.add_child(_make_button("Create Silhouette", _apply_silhouette))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("LIGHTING EFFECTS"))
	shadow_x_input = _add_spin_row(panel_layout, "Shadow X", -128.0, 128.0, 4.0, " px")
	shadow_y_input = _add_spin_row(panel_layout, "Shadow Y", -128.0, 128.0, 4.0, " px")
	panel_layout.add_child(_make_button("Apply Drop Shadow", _apply_drop_shadow))
	glow_radius_input = _add_spin_row(panel_layout, "Glow Radius", 1.0, 32.0, 3.0, " px")
	panel_layout.add_child(_make_button("Apply Outer Glow", _apply_glow))
	highlight_x_input = _add_spin_row(panel_layout, "Light X", -1.0, 1.0, -1.0, "")
	highlight_y_input = _add_spin_row(panel_layout, "Light Y", -1.0, 1.0, -1.0, "")
	panel_layout.add_child(_make_button("Apply Edge Highlight", _apply_highlight))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("PIXEL CLEANUP"))
	cleanup_isolated_input = _add_spin_row(panel_layout, "Max Neighbours", 0.0, 7.0, 1.0, "")
	var isolated_hint: Label = Label.new()
	isolated_hint.text = "Opaque pixels with this many or fewer neighbours are removed."
	isolated_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(isolated_hint)
	panel_layout.add_child(_make_button("Remove Isolated Pixels", _remove_isolated_pixels))
	cleanup_gap_input = _add_spin_row(panel_layout, "Min Neighbours", 1.0, 8.0, 5.0, "")
	panel_layout.add_child(_make_button("Fill Small Gaps", _fill_small_gaps))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("COLOUR ADJUSTMENT"))
	hue_input = _add_spin_row(panel_layout, "Hue", -180.0, 180.0, 0.0, "°")
	saturation_input = _add_spin_row(panel_layout, "Saturation", -100.0, 100.0, 0.0, "%")
	value_input = _add_spin_row(panel_layout, "Value", -100.0, 100.0, 0.0, "%")
	alpha_input = _add_spin_row(panel_layout, "Alpha", -100.0, 100.0, 0.0, "%")
	panel_layout.add_child(_make_button("Apply Colour Adjustment", _apply_colour_adjustment))
	panel_layout.add_child(_make_button("Reset Adjustment Values", _reset_adjustments))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("SELECTION AND LAYERS"))
	panel_layout.add_child(_make_button("Select Opaque Pixels", _select_opaque_pixels))
	panel_layout.add_child(_make_button("Select Matching Effect Colour", _select_matching_colour))
	var extract_button: Button = _make_button("Extract Selection/Opaque to New Layer", _extract_to_new_layer)
	extract_button.tooltip_text = "Move selected pixels into a new layer. Without a selection, all opaque pixels are extracted."
	panel_layout.add_child(extract_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Ready."
	panel_layout.add_child(status_label)
	return panel_scroll

func _make_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label

func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 104.0
	return label

func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _make_spinbox(minimum: float, maximum: float, step_value: float, default_value: float) -> SpinBox:
	var spinbox: SpinBox = SpinBox.new()
	spinbox.min_value = minimum
	spinbox.max_value = maximum
	spinbox.step = step_value
	spinbox.value = default_value
	spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spinbox

func _add_spin_row(parent: VBoxContainer, title: String, minimum: float, maximum: float, default_value: float, suffix_text: String) -> SpinBox:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_make_label(title))
	var input: SpinBox = _make_spinbox(minimum, maximum, 1.0, default_value)
	input.suffix = suffix_text
	row.add_child(input)
	parent.add_child(row)
	return input

func _get_target_frames() -> Array[int]:
	var sprite_document: GatorSpriteDocument = context.get_document()
	var frames: Array[int] = []
	if sprite_document == null:
		return frames
	var frame_count: int = sprite_document.get_active_animation().frame_count
	match target_menu.get_selected_id():
		TargetMode.ACTIVE_CEL:
			frames.append(context.get_active_frame_index())
		TargetMode.SELECTED_FRAMES:
			for frame_index: int in context.get_selected_frame_indices():
				if frame_index >= 0 and frame_index < frame_count and not frames.has(frame_index):
					frames.append(frame_index)
			if frames.is_empty():
				frames.append(context.get_active_frame_index())
		_:
			for frame_index: int in range(frame_count):
				frames.append(frame_index)
	frames.sort()
	return frames

func _get_active_pixel_layer() -> GatorSpriteLayer:
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null:
		return null
	var layer_index: int = context.get_active_layer_index()
	if layer_index < 0 or layer_index >= sprite_document.layers.size():
		return null
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[layer_index]
	if sprite_layer.is_reference_layer():
		_update_status("Ink Lab cannot edit a reference layer.", true)
		return null
	return sprite_layer

func _apply_to_target_frames(operation_name: String, image_operation: Callable) -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	var sprite_layer: GatorSpriteLayer = _get_active_pixel_layer()
	if sprite_document == null or sprite_layer == null:
		return
	var target_frames: Array[int] = _get_target_frames()
	if target_frames.is_empty():
		_update_status("No frames are available.", true)
		return
	context.begin_undo_transaction()
	var processed_cels: Dictionary[int, bool] = {}
	var changed_cel_count: int = 0
	for frame_index: int in target_frames:
		var sprite_cel: GatorSpriteCel = sprite_layer.ensure_cel(frame_index, sprite_document.canvas_size)
		var cel_id: int = sprite_cel.get_instance_id()
		if processed_cels.has(cel_id):
			continue
		processed_cels[cel_id] = true
		var source_image: Image = sprite_cel.get_image(sprite_document.canvas_size)
		var result_variant: Variant = image_operation.call(source_image)
		if result_variant is Image:
			var result_image: Image = result_variant as Image
			sprite_cel.set_image(result_image)
			changed_cel_count += 1
	context.commit_undo_transaction()
	context.refresh_document(false)
	_update_status("%s on %d frame(s) across %d unique cel(s)." % [operation_name, target_frames.size(), changed_cel_count])

func _apply_outline() -> void:
	var thickness: int = int(outline_thickness_input.value)
	var outline_mode: int = outline_mode_menu.get_selected_id()
	_apply_to_target_frames("Applied outline", func(source_image: Image) -> Image:
		return _create_outline(source_image, effect_color_picker.color, thickness, outline_mode)
	)

func _apply_silhouette() -> void:
	_apply_to_target_frames("Created silhouette", func(source_image: Image) -> Image:
		var result_image: Image = source_image.duplicate()
		for y: int in range(result_image.get_height()):
			for x: int in range(result_image.get_width()):
				var source_color: Color = source_image.get_pixel(x, y)
				if source_color.a > 0.0:
					var silhouette_color: Color = effect_color_picker.color
					silhouette_color.a *= source_color.a
					result_image.set_pixel(x, y, silhouette_color)
		return result_image
	)

func _apply_drop_shadow() -> void:
	var shadow_offset: Vector2i = Vector2i(int(shadow_x_input.value), int(shadow_y_input.value))
	_apply_to_target_frames("Applied drop shadow", func(source_image: Image) -> Image:
		var shadow_image: Image = Image.create_empty(source_image.get_width(), source_image.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in range(source_image.get_height()):
			for x: int in range(source_image.get_width()):
				var source_color: Color = source_image.get_pixel(x, y)
				if source_color.a <= 0.0:
					continue
				var destination: Vector2i = Vector2i(x, y) + shadow_offset
				if destination.x < 0 or destination.y < 0 or destination.x >= source_image.get_width() or destination.y >= source_image.get_height():
					continue
				var shadow_color: Color = effect_color_picker.color
				shadow_color.a *= source_color.a
				shadow_image.set_pixelv(destination, shadow_color)
		shadow_image.blend_rect(source_image, Rect2i(Vector2i.ZERO, source_image.get_size()), Vector2i.ZERO)
		return shadow_image
	)

func _apply_glow() -> void:
	var radius: int = int(glow_radius_input.value)
	_apply_to_target_frames("Applied glow", func(source_image: Image) -> Image:
		var glow_image: Image = Image.create_empty(source_image.get_width(), source_image.get_height(), false, Image.FORMAT_RGBA8)
		for y: int in range(source_image.get_height()):
			for x: int in range(source_image.get_width()):
				var source_alpha: float = source_image.get_pixel(x, y).a
				if source_alpha <= 0.0:
					continue
				for offset_y: int in range(-radius, radius + 1):
					for offset_x: int in range(-radius, radius + 1):
						var distance: float = Vector2(offset_x, offset_y).length()
						if distance > radius:
							continue
						var destination: Vector2i = Vector2i(x + offset_x, y + offset_y)
						if destination.x < 0 or destination.y < 0 or destination.x >= source_image.get_width() or destination.y >= source_image.get_height():
							continue
						var glow_color: Color = effect_color_picker.color
						glow_color.a *= source_alpha * (1.0 - distance / float(radius + 1))
						if glow_color.a > glow_image.get_pixelv(destination).a:
							glow_image.set_pixelv(destination, glow_color)
		glow_image.blend_rect(source_image, Rect2i(Vector2i.ZERO, source_image.get_size()), Vector2i.ZERO)
		return glow_image
	)

func _apply_highlight() -> void:
	var light_direction: Vector2i = Vector2i(int(highlight_x_input.value), int(highlight_y_input.value))
	if light_direction == Vector2i.ZERO:
		light_direction = Vector2i(-1, -1)
	_apply_to_target_frames("Applied edge highlight", func(source_image: Image) -> Image:
		var result_image: Image = source_image.duplicate()
		for y: int in range(source_image.get_height()):
			for x: int in range(source_image.get_width()):
				var source_color: Color = source_image.get_pixel(x, y)
				if source_color.a <= 0.0:
					continue
				var neighbour: Vector2i = Vector2i(x, y) + light_direction
				if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= source_image.get_width() or neighbour.y >= source_image.get_height() or source_image.get_pixelv(neighbour).a <= 0.0:
					var highlight_color: Color = effect_color_picker.color
					highlight_color.a *= source_color.a
					result_image.set_pixel(x, y, highlight_color)
		return result_image
	)

func _remove_isolated_pixels() -> void:
	var maximum_neighbours: int = int(cleanup_isolated_input.value)
	_apply_to_target_frames("Removed isolated pixels", func(source_image: Image) -> Image:
		var result_image: Image = source_image.duplicate()
		for y: int in range(source_image.get_height()):
			for x: int in range(source_image.get_width()):
				if source_image.get_pixel(x, y).a <= 0.0:
					continue
				if _count_opaque_neighbours(source_image, x, y) <= maximum_neighbours:
					result_image.set_pixel(x, y, Color.TRANSPARENT)
		return result_image
	)

func _fill_small_gaps() -> void:
	var minimum_neighbours: int = int(cleanup_gap_input.value)
	_apply_to_target_frames("Filled small gaps", func(source_image: Image) -> Image:
		var result_image: Image = source_image.duplicate()
		for y: int in range(source_image.get_height()):
			for x: int in range(source_image.get_width()):
				if source_image.get_pixel(x, y).a > 0.0:
					continue
				var neighbour_colors: Array[Color] = _get_opaque_neighbour_colors(source_image, x, y)
				if neighbour_colors.size() < minimum_neighbours:
					continue
				var average_color: Color = Color.TRANSPARENT
				for neighbour_color: Color in neighbour_colors:
					average_color += neighbour_color
				average_color /= float(neighbour_colors.size())
				result_image.set_pixel(x, y, average_color)
		return result_image
	)

func _count_opaque_neighbours(source_image: Image, pixel_x: int, pixel_y: int) -> int:
	return _get_opaque_neighbour_colors(source_image, pixel_x, pixel_y).size()

func _get_opaque_neighbour_colors(source_image: Image, pixel_x: int, pixel_y: int) -> Array[Color]:
	var colors: Array[Color] = []
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var neighbour_x: int = pixel_x + offset_x
			var neighbour_y: int = pixel_y + offset_y
			if neighbour_x < 0 or neighbour_y < 0 or neighbour_x >= source_image.get_width() or neighbour_y >= source_image.get_height():
				continue
			var neighbour_color: Color = source_image.get_pixel(neighbour_x, neighbour_y)
			if neighbour_color.a > 0.0:
				colors.append(neighbour_color)
	return colors

func _create_outline(source_image: Image, outline_color: Color, thickness: int, outline_mode: int) -> Image:
	var result_image: Image = source_image.duplicate()
	var image_size: Vector2i = source_image.get_size()
	var radius_squared: int = thickness * thickness
	if outline_mode == int(OutlineMode.OUTSIDE):
		for pixel_y: int in range(image_size.y):
			for pixel_x: int in range(image_size.x):
				if source_image.get_pixel(pixel_x, pixel_y).a <= 0.0:
					continue
				for offset_y: int in range(-thickness, thickness + 1):
					for offset_x: int in range(-thickness, thickness + 1):
						if offset_x * offset_x + offset_y * offset_y > radius_squared:
							continue
						var target_x: int = pixel_x + offset_x
						var target_y: int = pixel_y + offset_y
						if target_x < 0 or target_y < 0 or target_x >= image_size.x or target_y >= image_size.y:
							continue
						if source_image.get_pixel(target_x, target_y).a <= 0.0:
							result_image.set_pixel(target_x, target_y, outline_color)
		return result_image
	for pixel_y: int in range(image_size.y):
		for pixel_x: int in range(image_size.x):
			var source_color: Color = source_image.get_pixel(pixel_x, pixel_y)
			if source_color.a <= 0.0:
				continue
			var is_edge_pixel: bool = false
			for offset_y: int in range(-thickness, thickness + 1):
				if is_edge_pixel:
					break
				for offset_x: int in range(-thickness, thickness + 1):
					if offset_x * offset_x + offset_y * offset_y > radius_squared:
						continue
					var target_x: int = pixel_x + offset_x
					var target_y: int = pixel_y + offset_y
					if target_x < 0 or target_y < 0 or target_x >= image_size.x or target_y >= image_size.y or source_image.get_pixel(target_x, target_y).a <= 0.0:
						is_edge_pixel = true
						break
			if is_edge_pixel:
				var applied_outline: Color = outline_color
				applied_outline.a *= source_color.a
				result_image.set_pixel(pixel_x, pixel_y, applied_outline)
	return result_image

func _apply_colour_adjustment() -> void:
	var hue_shift: float = hue_input.value / 360.0
	var saturation_shift: float = saturation_input.value / 100.0
	var value_shift: float = value_input.value / 100.0
	var alpha_shift: float = alpha_input.value / 100.0
	_apply_to_target_frames("Applied colour adjustment", func(source_image: Image) -> Image:
		var result_image: Image = source_image.duplicate()
		for y: int in range(result_image.get_height()):
			for x: int in range(result_image.get_width()):
				var pixel_color: Color = source_image.get_pixel(x, y)
				if pixel_color.a <= 0.0:
					continue
				var adjusted_color: Color = Color.from_hsv(
					fposmod(pixel_color.h + hue_shift, 1.0),
					clampf(pixel_color.s + saturation_shift, 0.0, 1.0),
					clampf(pixel_color.v + value_shift, 0.0, 1.0),
					clampf(pixel_color.a + alpha_shift, 0.0, 1.0)
				)
				result_image.set_pixel(x, y, adjusted_color)
		return result_image
	)

func _reset_adjustments() -> void:
	hue_input.value = 0.0
	saturation_input.value = 0.0
	value_input.value = 0.0
	alpha_input.value = 0.0

func _select_opaque_pixels() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	var sprite_layer: GatorSpriteLayer = _get_active_pixel_layer()
	if sprite_document == null or sprite_layer == null:
		return
	var source_image: Image = sprite_layer.ensure_cel(context.get_active_frame_index(), sprite_document.canvas_size).get_image_reference(sprite_document.canvas_size)
	var selection_mask: Image = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	for y: int in range(sprite_document.canvas_size.y):
		for x: int in range(sprite_document.canvas_size.x):
			if source_image.get_pixel(x, y).a > 0.0:
				selection_mask.set_pixel(x, y, Color.WHITE)
	context.set_selection_mask(selection_mask)
	_update_status("Selected opaque pixels.")

func _select_matching_colour() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	var sprite_layer: GatorSpriteLayer = _get_active_pixel_layer()
	if sprite_document == null or sprite_layer == null:
		return
	var source_image: Image = sprite_layer.ensure_cel(context.get_active_frame_index(), sprite_document.canvas_size).get_image_reference(sprite_document.canvas_size)
	var selection_mask: Image = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
	var target_rgba: int = effect_color_picker.color.to_rgba32()
	for y: int in range(sprite_document.canvas_size.y):
		for x: int in range(sprite_document.canvas_size.x):
			if source_image.get_pixel(x, y).to_rgba32() == target_rgba:
				selection_mask.set_pixel(x, y, Color.WHITE)
	context.set_selection_mask(selection_mask)
	_update_status("Selected matching colour pixels.")

func _extract_to_new_layer() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	var source_layer: GatorSpriteLayer = _get_active_pixel_layer()
	if sprite_document == null or source_layer == null:
		return
	var source_layer_index: int = context.get_active_layer_index()
	var target_frames: Array[int] = _get_target_frames()
	var expanded_target_frames: Array[int] = target_frames.duplicate()
	for target_frame: int in target_frames:
		for linked_frame: int in sprite_document.get_linked_frame_indices(source_layer_index, target_frame):
			if not expanded_target_frames.has(linked_frame):
				expanded_target_frames.append(linked_frame)
	expanded_target_frames.sort()
	var selection_mask: Image = context.get_selection_mask()
	var use_selection: bool = selection_mask != null and not selection_mask.is_empty()
	var extracted_layer: GatorSpriteLayer = GatorSpriteLayer.new()
	extracted_layer.layer_title = "%s Extracted" % source_layer.layer_title
	extracted_layer.group_title = source_layer.group_title
	var extracted_by_source_cel: Dictionary[int, GatorSpriteCel] = {}
	for frame_index: int in range(sprite_document.get_active_animation().frame_count):
		var output_cel: GatorSpriteCel
		if expanded_target_frames.has(frame_index):
			var source_cel: GatorSpriteCel = source_layer.ensure_cel(frame_index, sprite_document.canvas_size)
			var source_cel_id: int = source_cel.get_instance_id()
			if extracted_by_source_cel.has(source_cel_id):
				output_cel = extracted_by_source_cel[source_cel_id]
			else:
				var source_image: Image = source_cel.get_image(sprite_document.canvas_size)
				var output_image: Image = Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8)
				for y: int in range(sprite_document.canvas_size.y):
					for x: int in range(sprite_document.canvas_size.x):
						var source_color: Color = source_image.get_pixel(x, y)
						var should_extract: bool = selection_mask.get_pixel(x, y).a > 0.0 if use_selection else source_color.a > 0.0
						if should_extract and source_color.a > 0.0:
							output_image.set_pixel(x, y, source_color)
							source_image.set_pixel(x, y, Color.TRANSPARENT)
				source_cel.set_image(source_image)
				output_cel = GatorSpriteCel.new()
				output_cel.set_image(output_image)
				extracted_by_source_cel[source_cel_id] = output_cel
		else:
			output_cel = GatorSpriteCel.new()
			output_cel.set_image(Image.create_empty(sprite_document.canvas_size.x, sprite_document.canvas_size.y, false, Image.FORMAT_RGBA8))
		extracted_layer.cels.append(output_cel)
	sprite_document.layers.insert(source_layer_index + 1, extracted_layer)
	context.clear_selection()
	context.set_active_cell(context.get_active_frame_index(), source_layer_index + 1)
	context.refresh_document(true)
	_update_status("Extracted pixels into %s." % extracted_layer.layer_title)

func _update_status(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
	context.notify(message, is_error)
