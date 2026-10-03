@tool
extends GatorSpriteExtension

## Official bundled extension for non-destructive tween previews and generated in-between frames.

enum TweenMode { CROSSFADE, TRANSFORM }
enum EasingMode { LINEAR, EASE_IN, EASE_OUT, EASE_IN_OUT, SMOOTHSTEP }
enum PathMode { LINEAR, ARC, WAVE, SHAKE }

const RANGE_DATA_KEY: String = "blackwater.gss.motion_lab/ranges"

var start_frame_input: SpinBox
var end_frame_input: SpinBox
var tween_mode_menu: OptionButton
var easing_menu: OptionButton
var path_mode_menu: OptionButton
var offset_x_input: SpinBox
var offset_y_input: SpinBox
var rotation_input: SpinBox
var scale_x_input: SpinBox
var scale_y_input: SpinBox
var opacity_input: SpinBox
var arc_height_input: SpinBox
var wave_amplitude_input: SpinBox
var wave_cycles_input: SpinBox
var shake_amplitude_input: SpinBox
var blend_end_toggle: CheckButton
var insert_count_input: SpinBox
var status_label: Label
var preview_display: TextureRect
var preview_texture: ImageTexture
var preview_timer: Timer
var preview_play_button: Button
var preview_frame_label: Label
var preview_fps_input: SpinBox
var preview_frame_index: int = 0
var preview_is_playing: bool = false
var preview_generated_images: Dictionary = {}
var preview_layer_index: int = -1

func get_extension_manifest() -> Dictionary:
	return {
		"id": "blackwater.gss.motion_lab",
		"name": "Gator Motion Lab",
		"version": "1.2.0",
		"dependencies": PackedStringArray()
	}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	context.register_sidebar_panel("motion_lab", "Motion Lab", _build_panel())
	context.register_command("open_motion_lab", "Open Gator Motion Lab", _focus_panel)

func on_document_ready(sprite_document: GatorSpriteDocument) -> void:
	preview_generated_images.clear()
	preview_layer_index = -1
	_update_frame_limits(sprite_document, true)
	if preview_fps_input != null and sprite_document != null:
		preview_fps_input.value = sprite_document.get_active_animation().frames_per_second
	_reset_preview_to_start()
	_update_preview_image()
	_update_status("Choose endpoints, preview the tween, then apply it.")

func on_pixels_changed(_sprite_document: GatorSpriteDocument, frame_index: int, _layer_index: int) -> void:
	if frame_index == preview_frame_index:
		_update_preview_image()

func on_unloaded() -> void:
	_set_preview_playing(false)
	preview_generated_images.clear()

func _focus_panel() -> void:
	_update_frame_limits(context.get_document())
	context.focus_sidebar_panel("motion_lab")

func _build_panel() -> Control:
	var panel_scroll: ScrollContainer = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel_layout: VBoxContainer = VBoxContainer.new()
	panel_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel_layout)

	panel_layout.add_child(_make_heading("GATOR MOTION LAB"))
	var description: Label = Label.new()
	description.text = "Preview tweened cels without modifying the document, then apply or cancel the result."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(description)

	panel_layout.add_child(_make_heading("FRAME RANGE"))
	start_frame_input = _add_spin_row(panel_layout, "Start Frame", 1.0, 1.0, 1.0, "")
	end_frame_input = _add_spin_row(panel_layout, "End Frame", 1.0, 1.0, 1.0, "")
	start_frame_input.value_changed.connect(_on_preview_range_changed)
	end_frame_input.value_changed.connect(_on_preview_range_changed)
	var selected_range_button: Button = _make_button("Use Selected Frame Range", _use_selected_range)
	panel_layout.add_child(selected_range_button)

	var insert_row: HBoxContainer = HBoxContainer.new()
	insert_row.add_child(_make_label("Insert"))
	insert_count_input = _make_spinbox(1.0, 120.0, 1.0, 2.0)
	insert_count_input.suffix = " frames"
	insert_row.add_child(insert_count_input)
	panel_layout.add_child(insert_row)
	var insert_button: Button = _make_button("Insert In-Betweens After Start", _insert_in_betweens)
	insert_button.tooltip_text = "Duplicate the start frame to create room before the selected end frame."
	panel_layout.add_child(insert_button)

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("TWEEN"))
	tween_mode_menu = OptionButton.new()
	tween_mode_menu.add_item("Crossfade Between Cels", int(TweenMode.CROSSFADE))
	tween_mode_menu.add_item("Transform Start Cel", int(TweenMode.TRANSFORM))
	tween_mode_menu.item_selected.connect(_on_tween_mode_changed)
	panel_layout.add_child(tween_mode_menu)

	easing_menu = OptionButton.new()
	easing_menu.add_item("Linear", int(EasingMode.LINEAR))
	easing_menu.add_item("Ease In", int(EasingMode.EASE_IN))
	easing_menu.add_item("Ease Out", int(EasingMode.EASE_OUT))
	easing_menu.add_item("Ease In/Out", int(EasingMode.EASE_IN_OUT))
	easing_menu.add_item("Smoothstep", int(EasingMode.SMOOTHSTEP))
	panel_layout.add_child(easing_menu)

	path_mode_menu = OptionButton.new()
	path_mode_menu.add_item("Linear Path", int(PathMode.LINEAR))
	path_mode_menu.add_item("Arc Path", int(PathMode.ARC))
	path_mode_menu.add_item("Wave Path", int(PathMode.WAVE))
	path_mode_menu.add_item("Shake Path", int(PathMode.SHAKE))
	path_mode_menu.item_selected.connect(_on_path_mode_changed)
	panel_layout.add_child(path_mode_menu)

	panel_layout.add_child(_make_heading("END TRANSFORM"))
	offset_x_input = _add_spin_row(panel_layout, "Offset X", -4096.0, 4096.0, 0.0, " px")
	offset_y_input = _add_spin_row(panel_layout, "Offset Y", -4096.0, 4096.0, 0.0, " px")
	rotation_input = _add_spin_row(panel_layout, "Rotation", -720.0, 720.0, 0.0, "°")
	scale_x_input = _add_spin_row(panel_layout, "Scale X", 1.0, 800.0, 100.0, "%")
	scale_y_input = _add_spin_row(panel_layout, "Scale Y", 1.0, 800.0, 100.0, "%")
	opacity_input = _add_spin_row(panel_layout, "Opacity", 0.0, 100.0, 100.0, "%")
	blend_end_toggle = CheckButton.new()
	blend_end_toggle.text = "Blend toward end cel"
	blend_end_toggle.button_pressed = true
	panel_layout.add_child(blend_end_toggle)

	panel_layout.add_child(_make_heading("PATH SETTINGS"))
	arc_height_input = _add_spin_row(panel_layout, "Arc Height", -2048.0, 2048.0, 64.0, " px")
	wave_amplitude_input = _add_spin_row(panel_layout, "Wave Height", 0.0, 2048.0, 32.0, " px")
	wave_cycles_input = _add_spin_row(panel_layout, "Wave Cycles", 0.25, 8.0, 1.0, "")
	wave_cycles_input.step = 0.25
	shake_amplitude_input = _add_spin_row(panel_layout, "Shake", 0.0, 512.0, 8.0, " px")

	var action_grid: GridContainer = GridContainer.new()
	action_grid.columns = 2
	panel_layout.add_child(action_grid)
	action_grid.add_child(_make_button("Preview Changes", _preview_changes))
	action_grid.add_child(_make_button("Apply Preview", _apply_preview))
	action_grid.add_child(_make_button("Cancel Preview", _cancel_preview))
	action_grid.add_child(_make_button("Load Applied Settings", _load_applied_settings))
	panel_layout.add_child(_make_button("Reset Transform", _reset_transform))

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(status_label)

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("PREVIEW"))
	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.custom_minimum_size.y = 220.0
	panel_layout.add_child(preview_panel)
	preview_display = TextureRect.new()
	preview_display.custom_minimum_size = Vector2(244.0, 220.0)
	preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_panel.add_child(preview_display)

	var preview_controls: HBoxContainer = HBoxContainer.new()
	panel_layout.add_child(preview_controls)
	preview_controls.add_child(_make_button("◀", _step_preview.bind(-1)))
	preview_play_button = _make_button("Play", _toggle_preview_playback)
	preview_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_controls.add_child(preview_play_button)
	preview_controls.add_child(_make_button("▶", _step_preview.bind(1)))

	var preview_info_row: HBoxContainer = HBoxContainer.new()
	panel_layout.add_child(preview_info_row)
	preview_frame_label = Label.new()
	preview_frame_label.text = "Frame 1"
	preview_frame_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_info_row.add_child(preview_frame_label)
	preview_info_row.add_child(_make_label("FPS"))
	preview_fps_input = _make_spinbox(1.0, 60.0, 1.0, 12.0)
	preview_fps_input.custom_minimum_size.x = 84.0
	preview_fps_input.value_changed.connect(_on_preview_fps_changed)
	preview_info_row.add_child(preview_fps_input)

	preview_timer = Timer.new()
	preview_timer.one_shot = false
	preview_timer.timeout.connect(_advance_preview)
	panel_layout.add_child(preview_timer)
	_on_tween_mode_changed(0)
	_on_path_mode_changed(0)
	return panel_scroll

func _make_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label

func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 88.0
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
	var spinbox: SpinBox = _make_spinbox(minimum, maximum, 1.0, default_value)
	spinbox.suffix = suffix_text
	row.add_child(spinbox)
	parent.add_child(row)
	return spinbox

func _update_frame_limits(sprite_document: GatorSpriteDocument, reset_values: bool = false) -> void:
	if sprite_document == null or start_frame_input == null or end_frame_input == null:
		return
	var frame_count: int = maxi(1, sprite_document.get_active_animation().frame_count)
	start_frame_input.max_value = frame_count
	end_frame_input.max_value = frame_count
	if reset_values:
		start_frame_input.value = clampi(context.get_active_frame_index() + 1, 1, frame_count)
		end_frame_input.value = mini(frame_count, int(start_frame_input.value) + 1)
	else:
		start_frame_input.value = clampi(int(start_frame_input.value), 1, frame_count)
		end_frame_input.value = clampi(int(end_frame_input.value), 1, frame_count)

func _use_selected_range() -> void:
	_update_frame_limits(context.get_document())
	var selected_frames: Array[int] = context.get_selected_frame_indices()
	if selected_frames.size() < 2:
		_update_status("Select at least two frames in the timeline first.")
		return
	selected_frames.sort()
	start_frame_input.value = selected_frames[0] + 1
	end_frame_input.value = selected_frames[selected_frames.size() - 1] + 1
	_cancel_preview(false)
	_reset_preview_to_start()
	_update_preview_image()
	_update_status("Using frames %d through %d." % [int(start_frame_input.value), int(end_frame_input.value)])

func _insert_in_betweens() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null:
		return
	var start_index: int = int(start_frame_input.value) - 1
	var end_index: int = int(end_frame_input.value) - 1
	if start_index < 0 or end_index <= start_index or end_index >= sprite_document.get_active_animation().frame_count:
		_update_status("The end frame must be after the start frame.")
		return
	var insert_count: int = int(insert_count_input.value)
	for insertion_offset: int in range(insert_count):
		sprite_document.duplicate_frame(start_index + insertion_offset)
	end_index += insert_count
	_update_frame_limits(sprite_document)
	end_frame_input.value = end_index + 1
	context.refresh_document(true)
	var inserted_range: Array[int] = []
	for selected_frame_index: int in range(start_index, end_index + 1):
		inserted_range.append(selected_frame_index)
	context.set_selected_frame_indices(inserted_range, start_index)
	preview_frame_index = start_index
	_cancel_preview(false)
	_update_preview_image()
	_update_status("Inserted %d frame(s). Frames %d through %d are now selected and active for Motion Lab." % [insert_count, start_index + 1, end_index + 1])

func _on_tween_mode_changed(selected_index: int) -> void:
	var transform_enabled: bool = tween_mode_menu != null and tween_mode_menu.get_item_id(selected_index) == int(TweenMode.TRANSFORM)
	var transform_inputs: Array[SpinBox] = [offset_x_input, offset_y_input, rotation_input, scale_x_input, scale_y_input, opacity_input]
	for input: SpinBox in transform_inputs:
		if input != null:
			input.visible = transform_enabled
	if blend_end_toggle != null:
		blend_end_toggle.visible = transform_enabled
	if path_mode_menu != null:
		path_mode_menu.visible = transform_enabled
	_on_path_mode_changed(path_mode_menu.selected if path_mode_menu != null else 0)

func _on_path_mode_changed(_selected_index: int) -> void:
	if path_mode_menu == null:
		return
	var path_id: int = path_mode_menu.get_selected_id()
	if arc_height_input != null:
		arc_height_input.visible = path_id == int(PathMode.ARC)
		wave_amplitude_input.visible = path_id == int(PathMode.WAVE)
		wave_cycles_input.visible = path_id == int(PathMode.WAVE)
		shake_amplitude_input.visible = path_id == int(PathMode.SHAKE)

func _preview_changes() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	_update_frame_limits(sprite_document)
	if sprite_document == null:
		return
	var layer_index: int = context.get_active_layer_index()
	var start_index: int = int(start_frame_input.value) - 1
	var end_index: int = int(end_frame_input.value) - 1
	if not _validate_range(sprite_document, layer_index, start_index, end_index):
		return
	var source_layer: GatorSpriteLayer = sprite_document.layers[layer_index]
	var start_image: Image = source_layer.ensure_cel(start_index, sprite_document.canvas_size).get_image(sprite_document.canvas_size)
	var end_image: Image = source_layer.ensure_cel(end_index, sprite_document.canvas_size).get_image(sprite_document.canvas_size)
	preview_generated_images.clear()
	preview_layer_index = layer_index
	for frame_index: int in range(start_index + 1, end_index):
		var raw_progress: float = float(frame_index - start_index) / float(end_index - start_index)
		var eased_progress: float = _apply_easing(raw_progress, easing_menu.get_selected_id())
		var generated_image: Image
		if tween_mode_menu.get_selected_id() == int(TweenMode.CROSSFADE):
			generated_image = _blend_images(start_image, end_image, eased_progress)
		else:
			generated_image = _transform_image(start_image, eased_progress, frame_index - start_index)
			if blend_end_toggle.button_pressed:
				generated_image = _blend_images(generated_image, end_image, eased_progress)
		preview_generated_images[frame_index] = generated_image
	preview_frame_index = start_index
	_update_preview_image()
	_set_preview_playing(true)
	_update_status("Previewing %d generated frame(s). The document has not been modified." % preview_generated_images.size())

func _apply_preview() -> void:
	if preview_generated_images.is_empty() or preview_layer_index < 0:
		_preview_changes()
	if preview_generated_images.is_empty():
		return
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null or preview_layer_index >= sprite_document.layers.size():
		return
	context.begin_undo_transaction()
	for frame_variant: Variant in preview_generated_images.keys():
		var frame_index: int = int(frame_variant)
		var generated_image: Image = preview_generated_images[frame_variant] as Image
		sprite_document.layers[preview_layer_index].ensure_cel(frame_index, sprite_document.canvas_size).set_image(generated_image)
	context.commit_undo_transaction()
	_store_applied_settings(sprite_document, preview_layer_index)
	var applied_count: int = preview_generated_images.size()
	preview_generated_images.clear()
	context.refresh_document(false)
	_update_preview_image()
	_update_status("Applied %d tween frame(s). Re-preview and Apply again to update this range." % applied_count)

func _cancel_preview(show_message: bool = true) -> void:
	preview_generated_images.clear()
	preview_layer_index = -1
	_set_preview_playing(false)
	_update_preview_image()
	if show_message:
		_update_status("Cancelled the temporary tween preview. No frames were changed.")

func _load_applied_settings() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null:
		return
	var ranges_variant: Variant = sprite_document.extension_data.get(RANGE_DATA_KEY, {})
	if not ranges_variant is Dictionary:
		_update_status("This document has no saved Motion Lab ranges.")
		return
	var ranges: Dictionary = ranges_variant
	var range_key: String = _current_range_key(context.get_active_layer_index())
	if not ranges.has(range_key) or not ranges[range_key] is Dictionary:
		_update_status("No applied Motion Lab settings were found for this layer and frame range.")
		return
	_apply_settings_dictionary(ranges[range_key])
	_preview_changes()
	_update_status("Loaded the previously applied settings. Apply Preview to regenerate the range.")

func _store_applied_settings(sprite_document: GatorSpriteDocument, layer_index: int) -> void:
	var ranges: Dictionary = {}
	var existing_ranges: Variant = sprite_document.extension_data.get(RANGE_DATA_KEY, {})
	if existing_ranges is Dictionary:
		ranges = existing_ranges.duplicate(true)
	ranges[_current_range_key(layer_index)] = _capture_settings()
	sprite_document.extension_data[RANGE_DATA_KEY] = ranges

func _current_range_key(layer_index: int) -> String:
	return "%d:%d:%d" % [layer_index, int(start_frame_input.value) - 1, int(end_frame_input.value) - 1]

func _capture_settings() -> Dictionary:
	return {
		"tween_mode": tween_mode_menu.get_selected_id(),
		"easing": easing_menu.get_selected_id(),
		"path": path_mode_menu.get_selected_id(),
		"offset_x": offset_x_input.value,
		"offset_y": offset_y_input.value,
		"rotation": rotation_input.value,
		"scale_x": scale_x_input.value,
		"scale_y": scale_y_input.value,
		"opacity": opacity_input.value,
		"arc_height": arc_height_input.value,
		"wave_amplitude": wave_amplitude_input.value,
		"wave_cycles": wave_cycles_input.value,
		"shake_amplitude": shake_amplitude_input.value,
		"blend_end": blend_end_toggle.button_pressed
	}

func _apply_settings_dictionary(settings: Dictionary) -> void:
	_select_option_by_id(tween_mode_menu, int(settings.get("tween_mode", 0)))
	_select_option_by_id(easing_menu, int(settings.get("easing", 0)))
	_select_option_by_id(path_mode_menu, int(settings.get("path", 0)))
	offset_x_input.value = float(settings.get("offset_x", 0.0))
	offset_y_input.value = float(settings.get("offset_y", 0.0))
	rotation_input.value = float(settings.get("rotation", 0.0))
	scale_x_input.value = float(settings.get("scale_x", 100.0))
	scale_y_input.value = float(settings.get("scale_y", 100.0))
	opacity_input.value = float(settings.get("opacity", 100.0))
	arc_height_input.value = float(settings.get("arc_height", 64.0))
	wave_amplitude_input.value = float(settings.get("wave_amplitude", 32.0))
	wave_cycles_input.value = float(settings.get("wave_cycles", 1.0))
	shake_amplitude_input.value = float(settings.get("shake_amplitude", 8.0))
	blend_end_toggle.button_pressed = bool(settings.get("blend_end", true))
	_on_tween_mode_changed(tween_mode_menu.selected)
	_on_path_mode_changed(path_mode_menu.selected)

func _select_option_by_id(option_button: OptionButton, item_id: int) -> void:
	for item_index: int in range(option_button.item_count):
		if option_button.get_item_id(item_index) == item_id:
			option_button.select(item_index)
			return

func _validate_range(sprite_document: GatorSpriteDocument, layer_index: int, start_index: int, end_index: int) -> bool:
	var frame_count: int = sprite_document.get_active_animation().frame_count
	if start_index < 0 or end_index >= frame_count or end_index - start_index < 2:
		_update_status("Choose a range with at least one frame between the endpoints.")
		return false
	if layer_index < 0 or layer_index >= sprite_document.layers.size():
		_update_status("Select a valid pixel layer first.")
		return false
	if sprite_document.layers[layer_index].is_reference_layer():
		_update_status("Motion Lab cannot generate cels on a reference layer.")
		return false
	return true

func _apply_easing(progress: float, easing_id: int) -> float:
	var t: float = clampf(progress, 0.0, 1.0)
	match easing_id:
		EasingMode.EASE_IN:
			return t * t
		EasingMode.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		EasingMode.EASE_IN_OUT:
			return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		EasingMode.SMOOTHSTEP:
			return t * t * (3.0 - 2.0 * t)
		_:
			return t

func _blend_images(start_image: Image, end_image: Image, progress: float) -> Image:
	var prepared_start: Image = start_image.duplicate()
	var prepared_end: Image = end_image.duplicate()
	if prepared_start.get_format() != Image.FORMAT_RGBA8:
		prepared_start.convert(Image.FORMAT_RGBA8)
	if prepared_end.get_format() != Image.FORMAT_RGBA8:
		prepared_end.convert(Image.FORMAT_RGBA8)
	var image_size: Vector2i = prepared_start.get_size()
	if prepared_end.get_size() != image_size:
		prepared_end.resize(image_size.x, image_size.y, Image.INTERPOLATE_NEAREST)
	var start_data: PackedByteArray = prepared_start.get_data()
	var end_data: PackedByteArray = prepared_end.get_data()
	var output_data: PackedByteArray = start_data.duplicate()
	var byte_count: int = mini(start_data.size(), end_data.size())
	for byte_index: int in range(byte_count):
		output_data[byte_index] = clampi(roundi(lerpf(float(start_data[byte_index]), float(end_data[byte_index]), progress)), 0, 255)
	return Image.create_from_data(image_size.x, image_size.y, false, Image.FORMAT_RGBA8, output_data)

func _transform_image(source_image: Image, progress: float, frame_offset: int) -> Image:
	var image_size: Vector2i = source_image.get_size()
	var output_image: Image = Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var center: Vector2 = (Vector2(image_size) - Vector2.ONE) * 0.5
	var offset: Vector2 = _calculate_path_offset(progress, frame_offset)
	var rotation_radians: float = deg_to_rad(float(rotation_input.value) * progress)
	var scale_value: Vector2 = Vector2(
		lerpf(1.0, float(scale_x_input.value) / 100.0, progress),
		lerpf(1.0, float(scale_y_input.value) / 100.0, progress)
	)
	var opacity_value: float = lerpf(1.0, float(opacity_input.value) / 100.0, progress)
	if is_zero_approx(scale_value.x) or is_zero_approx(scale_value.y):
		return output_image
	var cosine_value: float = cos(-rotation_radians)
	var sine_value: float = sin(-rotation_radians)
	for destination_y: int in range(image_size.y):
		for destination_x: int in range(image_size.x):
			var relative_position: Vector2 = Vector2(destination_x, destination_y) - center - offset
			var rotated_position: Vector2 = Vector2(
				relative_position.x * cosine_value - relative_position.y * sine_value,
				relative_position.x * sine_value + relative_position.y * cosine_value
			)
			var source_relative: Vector2 = Vector2(rotated_position.x / scale_value.x, rotated_position.y / scale_value.y)
			var source_position: Vector2i = Vector2i(roundi(center.x + source_relative.x), roundi(center.y + source_relative.y))
			if source_position.x < 0 or source_position.y < 0 or source_position.x >= image_size.x or source_position.y >= image_size.y:
				continue
			var source_color: Color = source_image.get_pixelv(source_position)
			if source_color.a <= 0.0:
				continue
			source_color.a *= opacity_value
			output_image.set_pixel(destination_x, destination_y, source_color)
	return output_image

func _calculate_path_offset(progress: float, frame_offset: int) -> Vector2:
	var base_offset: Vector2 = Vector2(float(offset_x_input.value), float(offset_y_input.value)) * progress
	match path_mode_menu.get_selected_id():
		PathMode.ARC:
			base_offset.y -= sin(progress * PI) * float(arc_height_input.value)
		PathMode.WAVE:
			var direction: Vector2 = Vector2(float(offset_x_input.value), float(offset_y_input.value))
			var perpendicular: Vector2 = Vector2(0.0, -1.0) if direction.length_squared() <= 0.0001 else direction.normalized().orthogonal()
			base_offset += perpendicular * sin(progress * TAU * float(wave_cycles_input.value)) * float(wave_amplitude_input.value)
		PathMode.SHAKE:
			var shake_amount: float = float(shake_amplitude_input.value) * sin(progress * PI)
			base_offset += Vector2(sin(float(frame_offset) * 12.9898), cos(float(frame_offset) * 78.233)) * shake_amount
	return base_offset

func _reset_transform() -> void:
	offset_x_input.value = 0.0
	offset_y_input.value = 0.0
	rotation_input.value = 0.0
	scale_x_input.value = 100.0
	scale_y_input.value = 100.0
	opacity_input.value = 100.0
	arc_height_input.value = 64.0
	wave_amplitude_input.value = 32.0
	wave_cycles_input.value = 1.0
	shake_amplitude_input.value = 8.0
	blend_end_toggle.button_pressed = true
	_select_option_by_id(path_mode_menu, int(PathMode.LINEAR))
	_cancel_preview(false)

func _get_preview_sequence() -> Array[int]:
	var preview_sequence: Array[int] = []
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null or start_frame_input == null or end_frame_input == null:
		return preview_sequence
	var frame_count: int = sprite_document.get_active_animation().frame_count
	if frame_count <= 0:
		return preview_sequence
	var first_frame: int = clampi(int(start_frame_input.value) - 1, 0, frame_count - 1)
	var last_frame: int = clampi(int(end_frame_input.value) - 1, 0, frame_count - 1)
	if last_frame < first_frame:
		var swap_frame: int = first_frame
		first_frame = last_frame
		last_frame = swap_frame
	for frame_index: int in range(first_frame, last_frame + 1):
		preview_sequence.append(frame_index)
	return preview_sequence

func _on_preview_range_changed(_new_value: float) -> void:
	preview_generated_images.clear()
	var preview_sequence: Array[int] = _get_preview_sequence()
	if preview_sequence.is_empty():
		return
	if not preview_sequence.has(preview_frame_index):
		preview_frame_index = preview_sequence[0]
	_update_preview_image()

func _reset_preview_to_start() -> void:
	var preview_sequence: Array[int] = _get_preview_sequence()
	if not preview_sequence.is_empty():
		preview_frame_index = preview_sequence[0]

func _toggle_preview_playback() -> void:
	_set_preview_playing(not preview_is_playing)

func _set_preview_playing(is_playing: bool) -> void:
	preview_is_playing = is_playing and not _get_preview_sequence().is_empty()
	if preview_play_button != null:
		preview_play_button.text = "Pause" if preview_is_playing else "Play"
	if preview_timer == null:
		return
	if preview_is_playing:
		preview_timer.wait_time = 1.0 / maxf(1.0, float(preview_fps_input.value))
		preview_timer.start()
	else:
		preview_timer.stop()

func _on_preview_fps_changed(new_fps: float) -> void:
	if preview_timer != null:
		preview_timer.wait_time = 1.0 / maxf(1.0, new_fps)
		if preview_is_playing:
			preview_timer.start()

func _advance_preview() -> void:
	var preview_sequence: Array[int] = _get_preview_sequence()
	if preview_sequence.is_empty():
		_set_preview_playing(false)
		return
	var sequence_index: int = preview_sequence.find(preview_frame_index)
	sequence_index = 0 if sequence_index < 0 else (sequence_index + 1) % preview_sequence.size()
	preview_frame_index = preview_sequence[sequence_index]
	_update_preview_image()

func _step_preview(direction: int) -> void:
	_set_preview_playing(false)
	var preview_sequence: Array[int] = _get_preview_sequence()
	if preview_sequence.is_empty():
		return
	var sequence_index: int = preview_sequence.find(preview_frame_index)
	sequence_index = 0 if sequence_index < 0 else posmod(sequence_index + direction, preview_sequence.size())
	preview_frame_index = preview_sequence[sequence_index]
	_update_preview_image()

func _update_preview_image() -> void:
	var sprite_document: GatorSpriteDocument = context.get_document()
	if sprite_document == null or preview_display == null:
		return
	var frame_count: int = sprite_document.get_active_animation().frame_count
	if frame_count <= 0:
		preview_display.texture = null
		return
	preview_frame_index = clampi(preview_frame_index, 0, frame_count - 1)
	var preview_image: Image
	if preview_generated_images.has(preview_frame_index) and preview_layer_index >= 0:
		preview_image = sprite_document.composite_frame_with_override(preview_frame_index, false, preview_layer_index, preview_generated_images[preview_frame_index] as Image)
	else:
		preview_image = sprite_document.composite_frame(preview_frame_index)
	if preview_texture == null or Vector2i(preview_texture.get_size()) != preview_image.get_size():
		preview_texture = ImageTexture.create_from_image(preview_image)
	else:
		preview_texture.update(preview_image)
	preview_display.texture = preview_texture
	if preview_frame_label != null:
		var preview_sequence: Array[int] = _get_preview_sequence()
		var range_position: int = preview_sequence.find(preview_frame_index)
		var preview_marker: String = " • temporary" if preview_generated_images.has(preview_frame_index) else ""
		preview_frame_label.text = "Frame %d   (%d/%d)%s" % [preview_frame_index + 1, range_position + 1 if range_position >= 0 else 1, maxi(1, preview_sequence.size()), preview_marker]

func _update_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
	context.notify(message)
