@tool
extends GatorSpriteExtension

## Official bundled extension for categorized custom-brush libraries, thumbnails, presets, spacing, and stamp variation.

const BRUSH_DIRECTORY: String = "res://addons/gator_sprite_studio/brush_vault"
const SETTINGS_PATH: String = "res://addons/gator_sprite_studio/brush_vault.cfg"
const MAX_BRUSH_DIMENSION: int = 512

var brush_list: ItemList
var brush_name_input: LineEdit
var brush_search_input: LineEdit
var category_menu: OptionButton
var move_category_menu: OptionButton
var new_category_input: LineEdit
var random_rotation_toggle: CheckButton
var random_flip_horizontal_toggle: CheckButton
var random_flip_vertical_toggle: CheckButton
var random_scale_input: SpinBox
var brush_spacing_input: SpinBox
var source_color_toggle: CheckButton
var preset_menu: OptionButton
var preset_name_input: LineEdit
var variation_presets: Dictionary = {}
var status_label: Label
var delete_dialog: ConfirmationDialog
var pending_delete_path: String = ""
var cached_stamp_source: Image
var stamp_variant_cache: Dictionary = {}
var variation_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_variation_key: String = ""

func get_extension_manifest() -> Dictionary:
	return {
		"id": "blackwater.gss.brush_vault",
		"name": "Gator Brush Vault",
		"version": "1.2.1",
		"dependencies": PackedStringArray()
	}

func on_extension_loaded(extension_context: GatorSpriteExtensionContext) -> void:
	super.on_extension_loaded(extension_context)
	variation_rng.randomize()
	_ensure_brush_directory()
	context.register_sidebar_panel("brush_vault", "Brush Vault", _build_panel())
	context.register_command("open_brush_vault", "Open Gator Brush Vault", _focus_panel)
	_load_settings()
	_refresh_categories()
	_refresh_preset_menu()
	_refresh_brush_list()
	context.set_custom_brush_spacing(int(brush_spacing_input.value))

func on_document_ready(_sprite_document: GatorSpriteDocument) -> void:
	_update_status("Brush library ready.")

func on_unloaded() -> void:
	_save_settings()
	stamp_variant_cache.clear()
	cached_stamp_source = null
	last_variation_key = ""

func _focus_panel() -> void:
	context.focus_sidebar_panel("brush_vault")

func _build_panel() -> Control:
	var panel_scroll: ScrollContainer = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel_layout: VBoxContainer = VBoxContainer.new()
	panel_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel_layout)

	panel_layout.add_child(_make_heading("GATOR BRUSH VAULT"))
	var description: Label = Label.new()
	description.text = "Organize brushes into folders, search thumbnails, save variation presets, and control stamp spacing."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(description)

	brush_search_input = LineEdit.new()
	brush_search_input.placeholder_text = "Search brushes"
	brush_search_input.text_changed.connect(_on_search_changed)
	panel_layout.add_child(brush_search_input)

	var category_row: HBoxContainer = HBoxContainer.new()
	category_menu = OptionButton.new()
	category_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_menu.item_selected.connect(_on_category_selected)
	category_row.add_child(category_menu)
	panel_layout.add_child(category_row)
	var new_category_row: HBoxContainer = HBoxContainer.new()
	new_category_input = LineEdit.new()
	new_category_input.placeholder_text = "New category"
	new_category_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_category_row.add_child(new_category_input)
	new_category_row.add_child(_make_button("Create", _create_category))
	panel_layout.add_child(new_category_row)

	brush_name_input = LineEdit.new()
	brush_name_input.placeholder_text = "Brush name"
	panel_layout.add_child(brush_name_input)

	brush_list = ItemList.new()
	brush_list.select_mode = ItemList.SELECT_MULTI
	brush_list.custom_minimum_size.y = 230.0
	brush_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brush_list.icon_mode = ItemList.ICON_MODE_TOP
	brush_list.fixed_icon_size = Vector2i(64, 64)
	brush_list.max_columns = 3
	brush_list.same_column_width = true
	brush_list.item_selected.connect(_on_brush_selected)
	brush_list.item_activated.connect(_on_brush_activated)
	panel_layout.add_child(brush_list)
	var multi_select_help: Label = Label.new()
	multi_select_help.text = "Ctrl/Cmd-click or Shift-click to select multiple brushes."
	multi_select_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(multi_select_help)

	var move_category_label: Label = Label.new()
	move_category_label.text = "Move selected brushes to"
	panel_layout.add_child(move_category_label)
	var move_category_row: HBoxContainer = HBoxContainer.new()
	move_category_menu = OptionButton.new()
	move_category_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	move_category_row.add_child(move_category_menu)
	move_category_row.add_child(_make_button("Move Selected", _move_selected_brushes_to_category))
	panel_layout.add_child(move_category_row)

	var library_buttons: GridContainer = GridContainer.new()
	library_buttons.columns = 2
	panel_layout.add_child(library_buttons)
	library_buttons.add_child(_make_button("Import Brush...", _choose_import_brush))
	library_buttons.add_child(_make_button("Save Frame/Selection", _save_document_brush))
	library_buttons.add_child(_make_button("Load Selected", _load_selected_brush))
	library_buttons.add_child(_make_button("Save Loaded Brush", _save_loaded_brush))
	library_buttons.add_child(_make_button("Delete Selected", _request_delete_selected))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("CURRENT BRUSH TRANSFORM"))
	var transform_buttons: GridContainer = GridContainer.new()
	transform_buttons.columns = 2
	panel_layout.add_child(transform_buttons)
	transform_buttons.add_child(_make_button("Rotate Left", _rotate_current_left))
	transform_buttons.add_child(_make_button("Rotate Right", _rotate_current_right))
	transform_buttons.add_child(_make_button("Flip Horizontal", _flip_current_horizontal))
	transform_buttons.add_child(_make_button("Flip Vertical", _flip_current_vertical))

	panel_layout.add_child(HSeparator.new())
	panel_layout.add_child(_make_heading("STAMP APPEARANCE"))
	source_color_toggle = CheckButton.new()
	source_color_toggle.text = "Stamp source colours"
	source_color_toggle.button_pressed = true
	source_color_toggle.toggled.connect(_on_source_color_changed)
	panel_layout.add_child(source_color_toggle)
	var spacing_row: HBoxContainer = HBoxContainer.new()
	var spacing_label: Label = Label.new()
	spacing_label.text = "Brush spacing"
	spacing_label.custom_minimum_size.x = 110.0
	spacing_row.add_child(spacing_label)
	brush_spacing_input = SpinBox.new()
	brush_spacing_input.min_value = 1.0
	brush_spacing_input.max_value = 400.0
	brush_spacing_input.step = 1.0
	brush_spacing_input.value = 25.0
	brush_spacing_input.suffix = "%"
	brush_spacing_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_spacing_input.value_changed.connect(_on_brush_spacing_changed)
	spacing_row.add_child(brush_spacing_input)
	panel_layout.add_child(spacing_row)

	panel_layout.add_child(_make_heading("STAMP VARIATION"))
	random_rotation_toggle = CheckButton.new()
	random_rotation_toggle.text = "Random quarter-turn rotation"
	random_rotation_toggle.toggled.connect(_on_random_settings_changed)
	panel_layout.add_child(random_rotation_toggle)
	random_flip_horizontal_toggle = CheckButton.new()
	random_flip_horizontal_toggle.text = "Random horizontal flip"
	random_flip_horizontal_toggle.toggled.connect(_on_random_settings_changed)
	panel_layout.add_child(random_flip_horizontal_toggle)
	random_flip_vertical_toggle = CheckButton.new()
	random_flip_vertical_toggle.text = "Random vertical flip"
	random_flip_vertical_toggle.toggled.connect(_on_random_settings_changed)
	panel_layout.add_child(random_flip_vertical_toggle)
	var scale_row: HBoxContainer = HBoxContainer.new()
	var scale_label: Label = Label.new()
	scale_label.text = "Scale variation"
	scale_label.custom_minimum_size.x = 110.0
	scale_row.add_child(scale_label)
	random_scale_input = SpinBox.new()
	random_scale_input.min_value = 0.0
	random_scale_input.max_value = 75.0
	random_scale_input.step = 5.0
	random_scale_input.value = 0.0
	random_scale_input.suffix = "%"
	random_scale_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_scale_input.value_changed.connect(_on_random_scale_changed)
	scale_row.add_child(random_scale_input)
	panel_layout.add_child(scale_row)

	panel_layout.add_child(_make_heading("VARIATION PRESETS"))
	preset_menu = OptionButton.new()
	preset_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_layout.add_child(preset_menu)
	preset_name_input = LineEdit.new()
	preset_name_input.placeholder_text = "Preset name"
	panel_layout.add_child(preset_name_input)
	var preset_buttons: GridContainer = GridContainer.new()
	preset_buttons.columns = 3
	preset_buttons.add_child(_make_button("Save", _save_variation_preset))
	preset_buttons.add_child(_make_button("Apply", _apply_variation_preset))
	preset_buttons.add_child(_make_button("Delete", _delete_variation_preset))
	panel_layout.add_child(preset_buttons)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_layout.add_child(status_label)

	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = "Delete Brush"
	delete_dialog.dialog_text = "Delete the selected brush from the Brush Vault?"
	delete_dialog.ok_button_text = "Delete"
	delete_dialog.confirmed.connect(_delete_selected_confirmed)
	panel_scroll.add_child(delete_dialog)
	return panel_scroll

func _make_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	return label

func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _ensure_brush_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BRUSH_DIRECTORY))

func _refresh_categories() -> void:
	if category_menu == null:
		return
	var previous_category: String = _selected_category()
	var previous_move_category: String = _selected_move_category()
	var categories: Array[String] = []
	var directory: DirAccess = DirAccess.open(BRUSH_DIRECTORY)
	if directory != null:
		directory.list_dir_begin()
		var entry_name: String = directory.get_next()
		while not entry_name.is_empty():
			if directory.current_is_dir() and not entry_name.begins_with("."):
				categories.append(entry_name)
			entry_name = directory.get_next()
		directory.list_dir_end()
	categories.sort()

	category_menu.clear()
	category_menu.add_item("All Categories")
	category_menu.set_item_metadata(0, "*")
	category_menu.add_item("Uncategorized")
	category_menu.set_item_metadata(1, "")
	for category_name: String in categories:
		category_menu.add_item(category_name.capitalize())
		category_menu.set_item_metadata(category_menu.item_count - 1, category_name)
	var filter_index: int = 0
	for item_index: int in range(category_menu.item_count):
		if String(category_menu.get_item_metadata(item_index)) == previous_category:
			filter_index = item_index
			break
	category_menu.select(filter_index)

	if move_category_menu == null:
		return
	move_category_menu.clear()
	move_category_menu.add_item("Uncategorized")
	move_category_menu.set_item_metadata(0, "")
	for category_name: String in categories:
		move_category_menu.add_item(category_name.capitalize())
		move_category_menu.set_item_metadata(move_category_menu.item_count - 1, category_name)
	var move_index: int = 0
	for item_index: int in range(move_category_menu.item_count):
		if String(move_category_menu.get_item_metadata(item_index)) == previous_move_category:
			move_index = item_index
			break
	move_category_menu.select(move_index)

func _selected_category() -> String:
	if category_menu == null or category_menu.item_count == 0:
		return "*"
	return String(category_menu.get_item_metadata(category_menu.selected))

func _select_filter_category(category_name: String) -> void:
	if category_menu == null:
		return
	for item_index: int in range(category_menu.item_count):
		if String(category_menu.get_item_metadata(item_index)) == category_name:
			category_menu.select(item_index)
			return

func _selected_move_category() -> String:
	if move_category_menu == null or move_category_menu.item_count == 0:
		return ""
	return String(move_category_menu.get_item_metadata(move_category_menu.selected))

func _select_move_category(category_name: String) -> void:
	if move_category_menu == null:
		return
	for item_index: int in range(move_category_menu.item_count):
		if String(move_category_menu.get_item_metadata(item_index)) == category_name:
			move_category_menu.select(item_index)
			return

func _create_category() -> void:
	var category_name: String = _sanitize_file_name(new_category_input.text)
	if category_name.is_empty():
		_update_status("Enter a category name.", true)
		return
	var category_path: String = BRUSH_DIRECTORY.path_join(category_name)
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(category_path))
	if error != OK:
		_update_status("Could not create the category.", true)
		return
	new_category_input.clear()
	_refresh_categories()
	_select_move_category(category_name)
	_update_status("Created %s. Select brushes and click Move Selected." % category_name.capitalize())

func _on_category_selected(_index: int) -> void:
	_refresh_brush_list()

func _on_search_changed(_search_text: String) -> void:
	_refresh_brush_list()

func _move_selected_brushes_to_category() -> void:
	var selected_paths: PackedStringArray = _get_selected_brush_paths()
	if selected_paths.is_empty():
		_update_status("Select one or more brushes first.", true)
		return
	var target_category: String = _selected_move_category()
	var destination_directory: String = BRUSH_DIRECTORY if target_category.is_empty() else BRUSH_DIRECTORY.path_join(target_category)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_directory))
	if directory_error != OK:
		_update_status("Could not access the destination category.", true)
		return
	var moved_paths: PackedStringArray = PackedStringArray()
	var moved_count: int = 0
	for source_path: String in selected_paths:
		if source_path.get_base_dir() == destination_directory:
			moved_paths.append(source_path)
			continue
		var destination_path: String = _unique_destination_path(destination_directory, source_path.get_file(), source_path)
		var move_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(destination_path))
		if move_error != OK:
			continue
		moved_paths.append(destination_path)
		moved_count += 1
	_select_filter_category(target_category)
	_refresh_brush_list()
	_select_brush_paths(moved_paths)
	if moved_count == 0:
		_update_status("The selected brushes are already in that category.")
	elif moved_count == selected_paths.size():
		_update_status("Moved %d brush%s to %s." % [moved_count, "" if moved_count == 1 else "es", "Uncategorized" if target_category.is_empty() else target_category.capitalize()])
	else:
		_update_status("Moved %d of %d selected brushes. Some files could not be moved." % [moved_count, selected_paths.size()], true)

func _unique_destination_path(destination_directory: String, file_name: String, source_path: String) -> String:
	var candidate_path: String = destination_directory.path_join(file_name)
	if candidate_path == source_path or not FileAccess.file_exists(candidate_path):
		return candidate_path
	var base_name: String = file_name.get_basename()
	var extension: String = file_name.get_extension()
	var suffix: int = 2
	while true:
		var candidate_name: String = "%s_%d.%s" % [base_name, suffix, extension]
		candidate_path = destination_directory.path_join(candidate_name)
		if not FileAccess.file_exists(candidate_path):
			return candidate_path
		suffix += 1
	return candidate_path

func _refresh_brush_list() -> void:
	if brush_list == null:
		return
	brush_list.clear()
	var category_filter: String = _selected_category()
	var search_text: String = brush_search_input.text.strip_edges().to_lower() if brush_search_input != null else ""
	var brush_entries: Array[Dictionary] = []
	_collect_brush_entries(BRUSH_DIRECTORY, "", brush_entries)
	brush_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["display"]) < String(b["display"])
	)
	for brush_entry: Dictionary in brush_entries:
		var category_name: String = String(brush_entry["category"])
		var display_name: String = String(brush_entry["display"])
		if category_filter != "*" and category_name != category_filter:
			continue
		if not search_text.is_empty() and not display_name.to_lower().contains(search_text):
			continue
		var thumbnail_image: Image = Image.new()
		thumbnail_image.load(ProjectSettings.globalize_path(String(brush_entry["path"])))
		var thumbnail_texture: ImageTexture
		if not thumbnail_image.is_empty():
			var thumbnail_size: Vector2i = thumbnail_image.get_size()
			var largest_dimension: int = maxi(thumbnail_size.x, thumbnail_size.y)
			if largest_dimension > 64:
				var thumbnail_scale: float = 64.0 / float(largest_dimension)
				thumbnail_image.resize(maxi(1, roundi(thumbnail_size.x * thumbnail_scale)), maxi(1, roundi(thumbnail_size.y * thumbnail_scale)), Image.INTERPOLATE_NEAREST)
			thumbnail_texture = ImageTexture.create_from_image(thumbnail_image)
		var item_label: String = display_name if category_name.is_empty() else "%s\n%s" % [display_name, category_name.capitalize()]
		brush_list.add_item(item_label, thumbnail_texture)
		brush_list.set_item_metadata(brush_list.item_count - 1, String(brush_entry["path"]))
	if brush_list.item_count > 0:
		brush_list.select(0)
		_on_brush_selected(0)

func _collect_brush_entries(directory_path: String, category_name: String, output_entries: Array[Dictionary]) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if directory.current_is_dir():
			if category_name.is_empty() and not entry_name.begins_with("."):
				_collect_brush_entries(directory_path.path_join(entry_name), entry_name, output_entries)
		elif entry_name.to_lower().ends_with(".png"):
			output_entries.append({"path": directory_path.path_join(entry_name), "category": category_name, "display": entry_name.get_basename().capitalize()})
		entry_name = directory.get_next()
	directory.list_dir_end()

func _choose_import_brush() -> void:
	context.show_open_file_dialog("Import Brush", PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Image Files"]), _import_brush)

func _import_brush(source_path: String) -> void:
	var brush_image: Image = Image.new()
	var load_error: Error = brush_image.load(source_path)
	if load_error != OK or brush_image.is_empty():
		_update_status("Could not load the selected brush image.", true)
		return
	_limit_brush_size(brush_image)
	var brush_name: String = source_path.get_file().get_basename()
	var destination_path: String = _brush_path_for_name(brush_name)
	var save_error: Error = brush_image.save_png(ProjectSettings.globalize_path(destination_path))
	if save_error != OK:
		_update_status("Could not save the imported brush.", true)
		return
	_refresh_brush_list()
	_select_brush_path(destination_path)
	if context.set_custom_brush_image(brush_image) != OK:
		_update_status("The brush was saved, but GSS could not activate it.", true)
		return
	_clear_variant_cache()
	_update_status("Imported and loaded %s." % brush_name)

func _save_document_brush() -> void:
	var brush_image: Image = context.get_document_brush_image()
	if brush_image == null or brush_image.is_empty():
		_update_status("The selection or active frame has no visible pixels.", true)
		return
	_save_brush_image(brush_image, "selection" if context.has_selection() else "active frame", true)

func _save_loaded_brush() -> void:
	var brush_image: Image = context.get_custom_brush_source_image()
	if brush_image == null or brush_image.is_empty():
		_update_status("Load a custom brush first.", true)
		return
	_save_brush_image(brush_image, "loaded brush", false)

func _save_brush_image(brush_image: Image, source_description: String, activate_after_save: bool) -> void:
	var saved_image: Image = brush_image.duplicate()
	_limit_brush_size(saved_image)
	var brush_name: String = brush_name_input.text.strip_edges()
	if brush_name.is_empty():
		brush_name = "Brush %d" % (brush_list.item_count + 1)
	var destination_path: String = _brush_path_for_name(brush_name)
	var save_error: Error = saved_image.save_png(ProjectSettings.globalize_path(destination_path))
	if save_error != OK:
		_update_status("Could not save the %s." % source_description, true)
		return
	if activate_after_save and context.set_custom_brush_image(saved_image) != OK:
		_update_status("The brush was saved, but GSS could not activate it.", true)
		return
	_refresh_brush_list()
	_select_brush_path(destination_path)
	_clear_variant_cache()
	_update_status("Saved %s as %s%s." % [source_description, brush_name, " and loaded it" if activate_after_save else ""])

func _load_selected_brush() -> void:
	var selected_path: String = _get_selected_brush_path()
	if selected_path.is_empty():
		_update_status("Select a brush first.", true)
		return
	var brush_image: Image = Image.new()
	if brush_image.load(ProjectSettings.globalize_path(selected_path)) != OK:
		_update_status("Could not load the selected brush.", true)
		return
	if context.set_custom_brush_image(brush_image) != OK:
		_update_status("GSS rejected the selected brush.", true)
		return
	_clear_variant_cache()
	_update_status("Loaded %s." % selected_path.get_file().get_basename().capitalize())

func _on_brush_selected(item_index: int) -> void:
	if item_index < 0 or item_index >= brush_list.item_count:
		return
	brush_name_input.text = String(brush_list.get_item_metadata(item_index)).get_file().get_basename().capitalize()

func _on_brush_activated(_item_index: int) -> void:
	_load_selected_brush()

func _get_selected_brush_path() -> String:
	var selected_items: PackedInt32Array = brush_list.get_selected_items()
	if selected_items.is_empty():
		return ""
	return String(brush_list.get_item_metadata(selected_items[0]))

func _get_selected_brush_paths() -> PackedStringArray:
	var selected_paths: PackedStringArray = PackedStringArray()
	if brush_list == null:
		return selected_paths
	for item_index: int in brush_list.get_selected_items():
		selected_paths.append(String(brush_list.get_item_metadata(item_index)))
	return selected_paths

func _select_brush_paths(brush_paths: PackedStringArray) -> void:
	if brush_list == null or brush_paths.is_empty():
		return
	brush_list.deselect_all()
	var first_selected_index: int = -1
	for item_index: int in range(brush_list.item_count):
		var item_path: String = String(brush_list.get_item_metadata(item_index))
		if not brush_paths.has(item_path):
			continue
		brush_list.select(item_index, false)
		if first_selected_index < 0:
			first_selected_index = item_index
	if first_selected_index >= 0:
		_on_brush_selected(first_selected_index)

func _select_brush_path(brush_path: String) -> void:
	for item_index: int in range(brush_list.item_count):
		if String(brush_list.get_item_metadata(item_index)) == brush_path:
			brush_list.select(item_index)
			_on_brush_selected(item_index)
			return

func _request_delete_selected() -> void:
	pending_delete_path = _get_selected_brush_path()
	if pending_delete_path.is_empty():
		_update_status("Select a brush first.", true)
		return
	delete_dialog.dialog_text = "Delete %s from the Brush Vault?" % pending_delete_path.get_file()
	delete_dialog.popup_centered(Vector2i(420, 150))

func _delete_selected_confirmed() -> void:
	if pending_delete_path.is_empty():
		return
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_delete_path))
	if error != OK:
		_update_status("Could not delete the selected brush.", true)
		return
	pending_delete_path = ""
	_refresh_brush_list()
	_update_status("Deleted brush.")

func _brush_path_for_name(brush_name: String) -> String:
	var file_name: String = _sanitize_file_name(brush_name)
	if file_name.is_empty():
		file_name = "brush"
	var category_name: String = _selected_category()
	var destination_directory: String = BRUSH_DIRECTORY if category_name == "*" or category_name.is_empty() else BRUSH_DIRECTORY.path_join(category_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination_directory))
	return destination_directory.path_join("%s.png" % file_name)

func _sanitize_file_name(source_name: String) -> String:
	var result: String = source_name.strip_edges().to_snake_case()
	for invalid_character: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(invalid_character, "_")
	return result.strip_edges()

func _limit_brush_size(brush_image: Image) -> void:
	if brush_image.get_format() != Image.FORMAT_RGBA8:
		brush_image.convert(Image.FORMAT_RGBA8)
	var brush_size: Vector2i = brush_image.get_size()
	var largest_dimension: int = maxi(brush_size.x, brush_size.y)
	if largest_dimension <= MAX_BRUSH_DIMENSION:
		return
	var resize_scale: float = float(MAX_BRUSH_DIMENSION) / float(largest_dimension)
	brush_image.resize(maxi(1, roundi(float(brush_size.x) * resize_scale)), maxi(1, roundi(float(brush_size.y) * resize_scale)), Image.INTERPOLATE_NEAREST)

func _rotate_current_left() -> void:
	_transform_current_brush(_rotate_counterclockwise)

func _rotate_current_right() -> void:
	_transform_current_brush(_rotate_clockwise)

func _flip_current_horizontal() -> void:
	_transform_current_brush(_flip_horizontal)

func _flip_current_vertical() -> void:
	_transform_current_brush(_flip_vertical)

func _transform_current_brush(transform_callback: Callable) -> void:
	var source_image: Image = context.get_custom_brush_source_image()
	if source_image == null or source_image.is_empty():
		_update_status("Load a custom brush first.", true)
		return
	var transformed_image: Image = transform_callback.call(source_image) as Image
	if transformed_image == null or context.set_custom_brush_image(transformed_image) != OK:
		_update_status("Could not transform the current brush.", true)
		return
	_clear_variant_cache()
	_update_status("Current brush transformed.")

func _rotate_clockwise(source_image: Image) -> Image:
	var source_size: Vector2i = source_image.get_size()
	var output_image: Image = Image.create_empty(source_size.y, source_size.x, false, Image.FORMAT_RGBA8)
	for source_y: int in range(source_size.y):
		for source_x: int in range(source_size.x):
			output_image.set_pixel(source_size.y - 1 - source_y, source_x, source_image.get_pixel(source_x, source_y))
	return output_image

func _rotate_counterclockwise(source_image: Image) -> Image:
	var source_size: Vector2i = source_image.get_size()
	var output_image: Image = Image.create_empty(source_size.y, source_size.x, false, Image.FORMAT_RGBA8)
	for source_y: int in range(source_size.y):
		for source_x: int in range(source_size.x):
			output_image.set_pixel(source_y, source_size.x - 1 - source_x, source_image.get_pixel(source_x, source_y))
	return output_image

func _flip_horizontal(source_image: Image) -> Image:
	var output_image: Image = source_image.duplicate()
	output_image.flip_x()
	return output_image

func _flip_vertical(source_image: Image) -> Image:
	var output_image: Image = source_image.duplicate()
	output_image.flip_y()
	return output_image

func modify_custom_brush_stamp(source_image: Image, source_anchor: Vector2i) -> Dictionary:
	if source_image == null or source_image.is_empty():
		return {}
	var use_source_colors: bool = source_color_toggle != null and source_color_toggle.button_pressed
	if not _has_random_variation():
		return {"image": source_image, "anchor": source_anchor, "use_source_colors": true} if use_source_colors else {}
	if cached_stamp_source != source_image:
		cached_stamp_source = source_image
		stamp_variant_cache.clear()
		last_variation_key = ""
	var variation_settings: Dictionary = _roll_stamp_variation()
	var cache_key: String = String(variation_settings["cache_key"])
	if not stamp_variant_cache.has(cache_key):
		if stamp_variant_cache.size() >= 128:
			stamp_variant_cache.clear()
		var variant_image: Image = source_image.duplicate()
		for _rotation_index: int in range(int(variation_settings["rotation_steps"])):
			variant_image = _rotate_clockwise(variant_image)
		if bool(variation_settings["flip_horizontal"]):
			variant_image = _flip_horizontal(variant_image)
		if bool(variation_settings["flip_vertical"]):
			variant_image = _flip_vertical(variant_image)
		var scale_percent: int = int(variation_settings["scale_percent"])
		if scale_percent != 100:
			var source_size: Vector2i = variant_image.get_size()
			variant_image.resize(maxi(1, roundi(float(source_size.x) * scale_percent / 100.0)), maxi(1, roundi(float(source_size.y) * scale_percent / 100.0)), Image.INTERPOLATE_NEAREST)
		stamp_variant_cache[cache_key] = {"image": variant_image, "anchor": _calculate_anchor(variant_image)}
	var stamp_result: Dictionary = stamp_variant_cache[cache_key].duplicate()
	stamp_result["use_source_colors"] = use_source_colors
	return stamp_result

func _roll_stamp_variation() -> Dictionary:
	var selected_settings: Dictionary = {"rotation_steps": 0, "flip_horizontal": false, "flip_vertical": false, "scale_percent": 100, "cache_key": "r0:100"}
	for attempt_index: int in range(12):
		var rotation_steps: int = variation_rng.randi_range(0, 3) if random_rotation_toggle.button_pressed else 0
		var flip_horizontal_enabled: bool = random_flip_horizontal_toggle.button_pressed and variation_rng.randi_range(0, 1) == 1
		var flip_vertical_enabled: bool = random_flip_vertical_toggle.button_pressed and variation_rng.randi_range(0, 1) == 1
		var scale_percent: int = 100
		var scale_variation: int = int(random_scale_input.value)
		if scale_variation > 0:
			scale_percent = clampi(int(round(float(variation_rng.randi_range(100 - scale_variation, 100 + scale_variation)) / 5.0)) * 5, 10, 400)
		var transform_key: String = _canonical_transform_key(rotation_steps, flip_horizontal_enabled, flip_vertical_enabled)
		var cache_key: String = "%s:%d" % [transform_key, scale_percent]
		selected_settings = {"rotation_steps": rotation_steps, "flip_horizontal": flip_horizontal_enabled, "flip_vertical": flip_vertical_enabled, "scale_percent": scale_percent, "cache_key": cache_key}
		var is_identity: bool = transform_key == "r0" and scale_percent == 100
		if last_variation_key.is_empty() and is_identity and attempt_index < 11:
			continue
		if cache_key == last_variation_key and attempt_index < 11:
			continue
		break
	last_variation_key = String(selected_settings["cache_key"])
	return selected_settings

func _canonical_transform_key(rotation_steps: int, flip_horizontal_enabled: bool, flip_vertical_enabled: bool) -> String:
	if flip_horizontal_enabled == flip_vertical_enabled:
		return "r%d" % posmod(rotation_steps + (2 if flip_horizontal_enabled else 0), 4)
	return "f%d" % posmod(-rotation_steps if flip_horizontal_enabled else 2 - rotation_steps, 4)

func _calculate_anchor(brush_image: Image) -> Vector2i:
	var minimum_pixel: Vector2i = brush_image.get_size()
	var maximum_pixel: Vector2i = Vector2i(-1, -1)
	for pixel_y: int in range(brush_image.get_height()):
		for pixel_x: int in range(brush_image.get_width()):
			if brush_image.get_pixel(pixel_x, pixel_y).a <= 0.0:
				continue
			minimum_pixel = Vector2i(mini(minimum_pixel.x, pixel_x), mini(minimum_pixel.y, pixel_y))
			maximum_pixel = Vector2i(maxi(maximum_pixel.x, pixel_x), maxi(maximum_pixel.y, pixel_y))
	if maximum_pixel.x < minimum_pixel.x or maximum_pixel.y < minimum_pixel.y:
		return Vector2i(brush_image.get_width() / 2, brush_image.get_height() / 2)
	return minimum_pixel + Vector2i((maximum_pixel.x - minimum_pixel.x) / 2, (maximum_pixel.y - minimum_pixel.y) / 2)

func _has_random_variation() -> bool:
	return random_rotation_toggle != null and (random_rotation_toggle.button_pressed or random_flip_horizontal_toggle.button_pressed or random_flip_vertical_toggle.button_pressed or int(random_scale_input.value) > 0)

func _clear_variant_cache() -> void:
	stamp_variant_cache.clear()
	cached_stamp_source = null
	last_variation_key = ""

func _on_random_settings_changed(_is_enabled: bool) -> void:
	_clear_variant_cache()
	_save_settings()

func _on_source_color_changed(_is_enabled: bool) -> void:
	_save_settings()

func _on_random_scale_changed(_new_value: float) -> void:
	_clear_variant_cache()
	_save_settings()

func _on_brush_spacing_changed(new_value: float) -> void:
	context.set_custom_brush_spacing(int(new_value))
	_save_settings()

func _capture_variation_settings() -> Dictionary:
	return {"source_colors": source_color_toggle.button_pressed, "rotation": random_rotation_toggle.button_pressed, "flip_horizontal": random_flip_horizontal_toggle.button_pressed, "flip_vertical": random_flip_vertical_toggle.button_pressed, "scale": random_scale_input.value, "spacing": brush_spacing_input.value}

func _apply_variation_settings(settings: Dictionary) -> void:
	source_color_toggle.button_pressed = bool(settings.get("source_colors", true))
	random_rotation_toggle.button_pressed = bool(settings.get("rotation", false))
	random_flip_horizontal_toggle.button_pressed = bool(settings.get("flip_horizontal", false))
	random_flip_vertical_toggle.button_pressed = bool(settings.get("flip_vertical", false))
	random_scale_input.value = float(settings.get("scale", 0.0))
	brush_spacing_input.value = float(settings.get("spacing", 25.0))
	context.set_custom_brush_spacing(int(brush_spacing_input.value))
	_clear_variant_cache()

func _save_variation_preset() -> void:
	var preset_name: String = preset_name_input.text.strip_edges()
	if preset_name.is_empty():
		_update_status("Enter a preset name.", true)
		return
	variation_presets[preset_name] = _capture_variation_settings()
	_refresh_preset_menu()
	_save_settings()
	_update_status("Saved variation preset %s." % preset_name)

func _apply_variation_preset() -> void:
	var preset_name: String = _selected_preset_name()
	if preset_name.is_empty() or not variation_presets.has(preset_name):
		_update_status("Select a variation preset first.", true)
		return
	_apply_variation_settings(variation_presets[preset_name])
	_save_settings()
	_update_status("Applied variation preset %s." % preset_name)

func _delete_variation_preset() -> void:
	var preset_name: String = _selected_preset_name()
	if preset_name.is_empty() or not variation_presets.has(preset_name):
		_update_status("Select a variation preset first.", true)
		return
	variation_presets.erase(preset_name)
	_refresh_preset_menu()
	_save_settings()
	_update_status("Deleted variation preset %s." % preset_name)

func _selected_preset_name() -> String:
	if preset_menu == null or preset_menu.item_count == 0:
		return ""
	return String(preset_menu.get_item_metadata(preset_menu.selected))

func _refresh_preset_menu() -> void:
	if preset_menu == null:
		return
	var previous_name: String = _selected_preset_name()
	preset_menu.clear()
	var preset_names: Array[String] = []
	for preset_name_variant: Variant in variation_presets.keys():
		preset_names.append(String(preset_name_variant))
	preset_names.sort()
	for preset_name: String in preset_names:
		preset_menu.add_item(preset_name)
		preset_menu.set_item_metadata(preset_menu.item_count - 1, preset_name)
		if preset_name == previous_name:
			preset_menu.select(preset_menu.item_count - 1)

func _load_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	_apply_variation_settings({
		"source_colors": settings.get_value("appearance", "source_colors", true),
		"rotation": settings.get_value("variation", "rotation", false),
		"flip_horizontal": settings.get_value("variation", "flip_horizontal", false),
		"flip_vertical": settings.get_value("variation", "flip_vertical", false),
		"scale": settings.get_value("variation", "scale", 0.0),
		"spacing": settings.get_value("variation", "spacing", 25.0)
	})
	var presets_variant: Variant = settings.get_value("presets", "items", {})
	if presets_variant is Dictionary:
		variation_presets = presets_variant.duplicate(true)

func _save_settings() -> void:
	if random_rotation_toggle == null:
		return
	var settings: ConfigFile = ConfigFile.new()
	var current_settings: Dictionary = _capture_variation_settings()
	settings.set_value("appearance", "source_colors", current_settings["source_colors"])
	settings.set_value("variation", "rotation", current_settings["rotation"])
	settings.set_value("variation", "flip_horizontal", current_settings["flip_horizontal"])
	settings.set_value("variation", "flip_vertical", current_settings["flip_vertical"])
	settings.set_value("variation", "scale", current_settings["scale"])
	settings.set_value("variation", "spacing", current_settings["spacing"])
	settings.set_value("presets", "items", variation_presets)
	settings.save(SETTINGS_PATH)

func _update_status(message: String, is_error: bool = false) -> void:
	if status_label != null:
		status_label.text = message
	context.notify(message, is_error)
