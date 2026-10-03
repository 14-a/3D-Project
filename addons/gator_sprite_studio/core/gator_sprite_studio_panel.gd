@tool
class_name GatorSpriteStudioPanel
extends Control

const StudioThemeBuilder = preload("res://addons/gator_sprite_studio/core/gator_sprite_studio_theme.gd")
const TimelineFrameButton = preload("res://addons/gator_sprite_studio/core/timeline/gator_timeline_frame_button.gd")
const TimelineLayerButton = preload("res://addons/gator_sprite_studio/core/timeline/gator_timeline_layer_button.gd")
const TimelineGroupButton = preload("res://addons/gator_sprite_studio/core/timeline/gator_timeline_group_button.gd")
const ICON_ROOT: String = "res://addons/gator_sprite_studio/icons/"
const USER_SETTINGS_PATH: String = "res://addons/gator_sprite_studio/gss_settings.cfg"
const RECOVERY_DIRECTORY: String = "res://addons/gator_sprite_studio"
const RECOVERY_DOCUMENT_PATH: String = "res://addons/gator_sprite_studio/gss_recovery_document.tres"
const RECOVERY_METADATA_PATH: String = "res://addons/gator_sprite_studio/gss_recovery_metadata.cfg"
const RECOVERY_INTERVAL_SECONDS: float = 60.0
const DEFAULT_TIMELINE_HEIGHT: int = 240
const MINIMUM_CANVAS_HEIGHT: int = 200
const MINIMUM_TIMELINE_HEIGHT: int = 120
const MAX_CANVAS_DIMENSION: int = 1024
const OFFICIAL_EXTENSION_DIRECTORY: String = "res://addons/gator_sprite_studio/extensions_official"
const OFFICIAL_EXTENSION_FILES: Array[String] = [
	"gator_ink_lab_extension.gd",
	"gator_motion_lab_extension.gd",
	"gator_brush_vault_extension.gd",
	"aseprite_import_extension.gd"
]

var sprite_document: GatorSpriteDocument
var canvas_view: GatorCanvas
var document_label: Label
var timeline_grid: GridContainer
var timeline_frame_buttons: Array[Button] = []
var timeline_layer_buttons: Dictionary[int, Button] = {}
var timeline_group_buttons: Dictionary[String, Button] = {}
var timeline_cel_buttons: Dictionary[Vector2i, Button] = {}
var selected_frame_indices: Array[int] = []
var frame_selection_anchor: int = 0
var selected_layer_indices: Array[int] = []
var layer_selection_anchor: int = 0
var color_picker: ColorPickerButton
var secondary_color_picker: ColorPickerButton
var tile_width_input: SpinBox
var tile_height_input: SpinBox
var tile_index_input: SpinBox
var brush_size_input: SpinBox
var brush_dimensions_label: Label
var layer_blend_mode_menu: OptionButton
var layer_opacity_input: SpinBox
var group_opacity_input: SpinBox
var group_opacity_row: HBoxContainer
var reference_position_x_input: SpinBox
var reference_position_y_input: SpinBox
var reference_scale_x_input: SpinBox
var reference_scale_y_input: SpinBox
var reference_rotation_input: SpinBox
var reference_controls: Array[Control] = []
var updating_layer_property_controls: bool = false
var status_label: Label
var canvas_scroll: ScrollContainer
var canvas_center: CenterContainer
var auto_fit_canvas: bool = true
var new_sprite_dialog: ConfirmationDialog
var save_dialog: FileDialog
var overwrite_save_dialog: ConfirmationDialog
var pending_overwrite_save_path: String = ""
var load_dialog: FileDialog
var spritesheet_load_dialog: FileDialog
var reference_image_load_dialog: FileDialog
var spritesheet_slice_dialog: ConfirmationDialog
var spritesheet_slice_mode_menu: OptionButton
var spritesheet_source_label: Label
var spritesheet_columns_input: SpinBox
var spritesheet_rows_input: SpinBox
var spritesheet_cell_width_input: SpinBox
var spritesheet_cell_height_input: SpinBox
var spritesheet_spacing_x_input: SpinBox
var spritesheet_spacing_y_input: SpinBox
var spritesheet_margin_x_input: SpinBox
var spritesheet_margin_y_input: SpinBox
var spritesheet_row_tags_toggle: CheckButton
var pending_spritesheet_image: Image
var pending_spritesheet_path: String = ""
var export_directory_dialog: FileDialog
var export_dialog: ConfirmationDialog
var export_frames_toggle: CheckBox
var export_sheet_toggle: CheckBox
var export_sprite_frames_toggle: CheckBox
var export_custom_brush_toggle: CheckBox
var export_columns_input: SpinBox
var export_rows_input: SpinBox
var export_name_input: LineEdit
var export_feedback_label: Label
var brush_load_dialog: FileDialog
var palette_save_dialog: FileDialog
var palette_load_dialog: FileDialog
var palette_grid: GridContainer
var palette_preset_menu: OptionButton
const BUILTIN_PALETTE_COUNT: int = 14
var user_palette_names: Array[String] = []
var user_palette_entries: Array[PackedColorArray] = []
var replace_color_dialog: ConfirmationDialog
var resize_canvas_dialog: ConfirmationDialog
var replace_source_picker: ColorPickerButton
var replace_target_picker: ColorPickerButton
var metadata_dialog: ConfirmationDialog
var tag_dialog: ConfirmationDialog
var tag_name_input: LineEdit
var tag_from_input: SpinBox
var tag_to_input: SpinBox
var tag_color_picker: ColorPickerButton
var edited_tag_index: int = -1
var edited_tag_original_frames: Array[int] = []
var selected_tag_index: int = -1
var slice_name_input: LineEdit
var slice_x_input: SpinBox
var slice_y_input: SpinBox
var slice_width_input: SpinBox
var slice_height_input: SpinBox
var slice_pivot_x_input: SpinBox
var slice_pivot_y_input: SpinBox
const ASEPRITE_SHORTCUT_BINDINGS: Dictionary = {"Pencil": "B", "Eraser": "E", "Fill": "G", "Picker": "I", "Line": "L", "Rectangle": "U", "Selection": "M", "Decrease Brush Size": "[", "Increase Brush Size": "]", "Copy": "CTRL+C", "Paste": "CTRL+V", "Deselect": "CTRL+D", "Undo": "CTRL+Z", "Redo": "CTRL+Y"}
const LEGACY_SHORTCUT_BINDINGS: Dictionary = {"Pencil": "P", "Eraser": "E", "Fill": "F", "Picker": "I", "Selection": "S", "Undo": "CTRL+Z", "Redo": "CTRL+Y"}

var shortcut_dialog: ConfirmationDialog
var shortcut_inputs: Dictionary = {}
var shortcut_bindings: Dictionary = ASEPRITE_SHORTCUT_BINDINGS.duplicate()
var shortcut_capture_action: String = ""
var extension_load_dialog: FileDialog
var tileset_export_dialog: FileDialog
var loaded_extensions: Array[GatorSpriteExtension] = []
var loaded_extension_paths: Array[String] = []
var unload_extension_dialog: ConfirmationDialog
var unload_extension_menu: OptionButton
var extension_dialog_is_reload: bool = false
var extension_menu_button: MenuButton
var extension_toolbar: HBoxContainer
var extension_panels: TabContainer
var extension_commands: Dictionary = {}
var extension_menu_command_keys: Dictionary = {}
var extension_contexts: Dictionary = {}
var extension_dialogs: Dictionary = {}
var extension_transaction_open: bool = false
var official_extension_paths: Dictionary = {}
var current_document_path: String = ""
var preview_display: TextureRect
var preview_texture: ImageTexture
var preview_fps_input: SpinBox
var preview_play_button: Button
var live_draw_button: Button
var preview_tag_menu: OptionButton
var preview_frame_index: int = 0
var preview_elapsed: float = 0.0
var preview_is_playing: bool = false
var live_draw_enabled: bool = false
var main_workspace_split: HSplitContainer
var canvas_timeline_split: VSplitContainer
var right_sidebar_tabs: TabContainer
var zoom_label: Label
var tool_button_group: ButtonGroup
var tool_buttons: Dictionary = {}
var pencil_shape_menu: PopupMenu
var eraser_shape_menu: PopupMenu
var selected_pencil_brush_shape: int = int(GatorCanvas.PencilBrushShape.SQUARE)
var selected_eraser_brush_shape: int = int(GatorCanvas.PencilBrushShape.SQUARE)
var icon_cache: Dictionary = {}
var unsaved_changes_dialog: ConfirmationDialog
var recovery_dialog: ConfirmationDialog
var pending_protected_action: Callable
var continue_pending_action_after_save: bool = false
var document_is_dirty: bool = false
var recovery_elapsed: float = 0.0
var saved_timeline_height: int = DEFAULT_TIMELINE_HEIGHT
var session_state_restored: bool = false
var recovery_metadata: Dictionary = {}

func _ready() -> void:
	_load_user_settings()
	_build_interface()
	_build_pencil_shape_menu()
	_build_eraser_shape_menu()
	_build_file_dialogs()
	_build_spritesheet_slice_dialog()
	_build_overwrite_save_dialog()
	_build_unsaved_changes_dialog()
	_build_recovery_dialog()
	_build_new_sprite_dialog()
	_build_export_dialog()
	_build_replace_color_dialog()
	_build_resize_canvas_dialog()
	_build_tag_dialog()
	_build_metadata_dialog()
	_build_shortcut_dialog()
	_build_unload_extension_dialog()
	var saved_shortcuts: Variant = ProjectSettings.get_setting("gator_sprite_studio/shortcuts", shortcut_bindings)
	if saved_shortcuts is Dictionary:
		shortcut_bindings = ASEPRITE_SHORTCUT_BINDINGS.duplicate()
		for action_name: String in saved_shortcuts.keys():
			var saved_binding: String = String(saved_shortcuts[action_name])
			if LEGACY_SHORTCUT_BINDINGS.has(action_name) and saved_binding == String(LEGACY_SHORTCUT_BINDINGS[action_name]):
				continue
			shortcut_bindings[action_name] = saved_binding
	set_process_input(false)
	set_process_shortcut_input(false)
	create_new_document(Vector2i(32, 32), false)
	_load_official_extensions()
	resized.connect(_on_panel_resized)
	call_deferred("_fit_canvas_to_viewport")
	call_deferred("_offer_recovery_if_available")

func _on_panel_resized() -> void:
	if auto_fit_canvas:
		call_deferred("_fit_canvas_to_viewport")
	call_deferred("_apply_saved_timeline_split")

func set_shortcuts_enabled(is_enabled: bool) -> void:
	set_process_shortcut_input(is_enabled)

func _build_interface() -> void:
	theme = StudioThemeBuilder.create()
	var root_layout: VBoxContainer = VBoxContainer.new()
	root_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_layout.add_theme_constant_override("separation", 0)
	add_child(root_layout)
	root_layout.add_child(_build_top_bar())

	var workspace_row: HBoxContainer = HBoxContainer.new()
	workspace_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_row.add_theme_constant_override("separation", 0)
	root_layout.add_child(workspace_row)
	workspace_row.add_child(_build_left_toolbar())

	main_workspace_split = HSplitContainer.new()
	main_workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_workspace_split.add_child(_build_center_workspace())
	main_workspace_split.add_child(_build_right_sidebar())
	workspace_row.add_child(main_workspace_split)
	root_layout.add_child(_build_status_bar())
	call_deferred("_set_initial_workspace_split")

func _build_top_bar() -> Control:
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.custom_minimum_size.y = 42.0
	var command_bar: HBoxContainer = HBoxContainer.new()
	command_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_panel.add_child(command_bar)

	var brand_label: Label = Label.new()
	brand_label.text = "GATOR SPRITE STUDIO"
	brand_label.tooltip_text = "Aseprite-inspired pixel art workspace for Godot."
	brand_label.custom_minimum_size.x = 168.0
	brand_label.add_theme_color_override("font_color", Color("f2f5f9"))
	brand_label.add_theme_font_size_override("font_size", 12)
	command_bar.add_child(brand_label)

	command_bar.add_child(_make_icon_button("new", "New sprite", _on_new_pressed))
	command_bar.add_child(_make_icon_button("open", "Open GSS document or image", _on_load_pressed))
	command_bar.add_child(_make_icon_button("spritesheet", "Import and slice a spritesheet", _on_import_spritesheet_pressed))
	command_bar.add_child(_make_icon_button("save", "Save document", _on_save_pressed))
	command_bar.add_child(_make_icon_button("save_as", "Save document as...", _on_save_as_pressed))
	command_bar.add_child(_make_icon_button("export", "Export sprite assets", _on_export_pressed))
	command_bar.add_child(_make_toolbar_separator())
	command_bar.add_child(_make_icon_button("undo", "Undo", _on_undo_pressed))
	command_bar.add_child(_make_icon_button("redo", "Redo", _on_redo_pressed))
	command_bar.add_child(_make_toolbar_separator())
	command_bar.add_child(_make_icon_button("metadata", "Sprite metadata, tags, and slices", _on_metadata_pressed))
	command_bar.add_child(_make_icon_button("shortcuts", "Configure keyboard shortcuts", _on_shortcuts_pressed))

	extension_menu_button = MenuButton.new()
	extension_menu_button.text = "Extensions"
	extension_menu_button.icon = _load_icon("extensions")
	extension_menu_button.tooltip_text = "Run commands registered by loaded extensions."
	extension_menu_button.get_popup().id_pressed.connect(_on_extension_menu_id_pressed)
	command_bar.add_child(extension_menu_button)
	extension_toolbar = HBoxContainer.new()
	command_bar.add_child(extension_toolbar)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_bar.add_child(spacer)
	document_label = Label.new()
	document_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	document_label.add_theme_color_override("font_color", Color("b8c4d6"))
	document_label.tooltip_text = "Current sprite document"
	command_bar.add_child(document_label)
	return top_panel

func _build_left_toolbar() -> Control:
	var toolbar_panel: PanelContainer = PanelContainer.new()
	toolbar_panel.custom_minimum_size.x = 54.0
	var toolbar: VBoxContainer = VBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_BEGIN
	toolbar_panel.add_child(toolbar)

	tool_button_group = ButtonGroup.new()
	tool_button_group.allow_unpress = false
	for tool_option: Dictionary in [
		{"title": "Pencil", "icon": "pencil", "mode": GatorCanvas.ToolMode.PENCIL},
		{"title": "Eraser", "icon": "eraser", "mode": GatorCanvas.ToolMode.ERASER},
		{"title": "Fill", "icon": "fill", "mode": GatorCanvas.ToolMode.FILL},
		{"title": "Picker", "icon": "picker", "mode": GatorCanvas.ToolMode.PICKER},
		{"title": "Line", "icon": "line", "mode": GatorCanvas.ToolMode.LINE},
		{"title": "Rectangle", "icon": "rectangle", "mode": GatorCanvas.ToolMode.RECTANGLE},
		{"title": "Gradient", "icon": "gradient", "mode": GatorCanvas.ToolMode.GRADIENT},
		{"title": "Dither", "icon": "dither", "mode": GatorCanvas.ToolMode.DITHER},
		{"title": "Pattern Fill", "icon": "pattern", "mode": GatorCanvas.ToolMode.PATTERN_FILL},
		{"title": "Tile Stamp", "icon": "tile", "mode": GatorCanvas.ToolMode.TILE_STAMP},
		{"title": "Selection / Move", "icon": "selection", "mode": GatorCanvas.ToolMode.SELECTION},
		{"title": "Custom Brush", "icon": "brush", "mode": GatorCanvas.ToolMode.CUSTOM_BRUSH}
	]:
		var requested_mode: int = int(tool_option["mode"])
		var shortcut_suffix: String = ""
		var tool_title: String = String(tool_option["title"])
		if shortcut_bindings.has(tool_title):
			shortcut_suffix = " (%s)" % String(shortcut_bindings[tool_title])
		var tool_handler: Callable = _on_tool_pressed.bind(requested_mode)
		if requested_mode == GatorCanvas.ToolMode.PENCIL:
			tool_handler = _on_pencil_tool_button_pressed
		elif requested_mode == GatorCanvas.ToolMode.ERASER:
			tool_handler = _on_eraser_tool_button_pressed
		var tool_tooltip: String = "%s%s" % [tool_title, shortcut_suffix]
		if requested_mode == GatorCanvas.ToolMode.PENCIL or requested_mode == GatorCanvas.ToolMode.ERASER:
			tool_tooltip += "\nClick to choose a square or circle brush."
		var tool_button: Button = _make_icon_button(String(tool_option["icon"]), tool_tooltip, tool_handler)
		tool_button.toggle_mode = true
		tool_button.button_group = tool_button_group
		_style_tool_button(tool_button)
		tool_button.button_pressed = requested_mode == GatorCanvas.ToolMode.PENCIL
		tool_buttons[requested_mode] = tool_button
		toolbar.add_child(tool_button)

	toolbar.add_child(_make_toolbar_separator(false))
	toolbar.add_child(_make_icon_button("deselect", "Deselect pixels", _on_deselect_pressed))
	var toolbar_spacer: Control = Control.new()
	toolbar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	var color_label: Label = Label.new()
	color_label.text = "FG"
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_label.add_theme_color_override("font_color", Color("8994a5"))
	color_label.add_theme_font_size_override("font_size", 10)
	toolbar.add_child(color_label)
	color_picker = ColorPickerButton.new()
	color_picker.color = Color.WHITE
	color_picker.custom_minimum_size = Vector2(36.0, 36.0)
	color_picker.tooltip_text = "Primary drawing colour"
	color_picker.color_changed.connect(_on_color_changed)
	toolbar.add_child(color_picker)

	var secondary_label: Label = Label.new()
	secondary_label.text = "BG"
	secondary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary_label.add_theme_color_override("font_color", Color("8994a5"))
	secondary_label.add_theme_font_size_override("font_size", 10)
	toolbar.add_child(secondary_label)
	secondary_color_picker = ColorPickerButton.new()
	secondary_color_picker.color = Color.BLACK
	secondary_color_picker.custom_minimum_size = Vector2(30.0, 30.0)
	secondary_color_picker.tooltip_text = "Secondary drawing colour"
	secondary_color_picker.color_changed.connect(_on_secondary_color_changed)
	toolbar.add_child(secondary_color_picker)
	return toolbar_panel

func _build_pencil_shape_menu() -> void:
	pencil_shape_menu = PopupMenu.new()
	pencil_shape_menu.add_radio_check_item("Square Brush", int(GatorCanvas.PencilBrushShape.SQUARE))
	pencil_shape_menu.add_radio_check_item("Circle Brush", int(GatorCanvas.PencilBrushShape.CIRCLE))
	pencil_shape_menu.id_pressed.connect(_on_pencil_shape_selected)
	add_child(pencil_shape_menu)
	_update_pencil_shape_menu_checks()


func _on_pencil_tool_button_pressed() -> void:
	_on_tool_pressed(GatorCanvas.ToolMode.PENCIL)
	call_deferred("_show_pencil_shape_menu")


func _show_pencil_shape_menu() -> void:
	if pencil_shape_menu == null or not tool_buttons.has(GatorCanvas.ToolMode.PENCIL):
		return
	var pencil_button: Button = tool_buttons[GatorCanvas.ToolMode.PENCIL] as Button
	if pencil_button == null:
		return
	_update_pencil_shape_menu_checks()
	var button_screen_position: Vector2 = pencil_button.get_screen_position()
	var popup_position: Vector2i = Vector2i(
		roundi(button_screen_position.x + pencil_button.size.x + 4.0),
		roundi(button_screen_position.y)
	)
	pencil_shape_menu.position = popup_position
	pencil_shape_menu.popup()


func _on_pencil_shape_selected(shape_id: int) -> void:
	selected_pencil_brush_shape = clampi(
		shape_id,
		int(GatorCanvas.PencilBrushShape.SQUARE),
		int(GatorCanvas.PencilBrushShape.CIRCLE)
	)
	canvas_view.set_pencil_brush_shape(selected_pencil_brush_shape)
	_update_pencil_shape_menu_checks()
	_save_user_settings()
	var shape_name: String = "Circle" if selected_pencil_brush_shape == int(GatorCanvas.PencilBrushShape.CIRCLE) else "Square"
	status_label.text = "Pencil brush shape: %s." % shape_name
	canvas_view.grab_focus()


func _update_pencil_shape_menu_checks() -> void:
	if pencil_shape_menu == null:
		return
	for item_index: int in range(pencil_shape_menu.item_count):
		pencil_shape_menu.set_item_checked(
			item_index,
			pencil_shape_menu.get_item_id(item_index) == selected_pencil_brush_shape
		)


func _build_eraser_shape_menu() -> void:
	eraser_shape_menu = PopupMenu.new()
	eraser_shape_menu.add_radio_check_item("Square Eraser", int(GatorCanvas.PencilBrushShape.SQUARE))
	eraser_shape_menu.add_radio_check_item("Circle Eraser", int(GatorCanvas.PencilBrushShape.CIRCLE))
	eraser_shape_menu.id_pressed.connect(_on_eraser_shape_selected)
	add_child(eraser_shape_menu)
	_update_eraser_shape_menu_checks()


func _on_eraser_tool_button_pressed() -> void:
	_on_tool_pressed(GatorCanvas.ToolMode.ERASER)
	call_deferred("_show_eraser_shape_menu")


func _show_eraser_shape_menu() -> void:
	if eraser_shape_menu == null or not tool_buttons.has(GatorCanvas.ToolMode.ERASER):
		return
	var eraser_button: Button = tool_buttons[GatorCanvas.ToolMode.ERASER] as Button
	if eraser_button == null:
		return
	_update_eraser_shape_menu_checks()
	var button_screen_position: Vector2 = eraser_button.get_screen_position()
	var popup_position: Vector2i = Vector2i(
		roundi(button_screen_position.x + eraser_button.size.x + 4.0),
		roundi(button_screen_position.y)
	)
	eraser_shape_menu.position = popup_position
	eraser_shape_menu.popup()


func _on_eraser_shape_selected(shape_id: int) -> void:
	selected_eraser_brush_shape = clampi(
		shape_id,
		int(GatorCanvas.PencilBrushShape.SQUARE),
		int(GatorCanvas.PencilBrushShape.CIRCLE)
	)
	canvas_view.set_eraser_brush_shape(selected_eraser_brush_shape)
	_update_eraser_shape_menu_checks()
	_save_user_settings()
	var shape_name: String = "Circle" if selected_eraser_brush_shape == int(GatorCanvas.PencilBrushShape.CIRCLE) else "Square"
	status_label.text = "Eraser shape: %s." % shape_name
	canvas_view.grab_focus()


func _update_eraser_shape_menu_checks() -> void:
	if eraser_shape_menu == null:
		return
	for item_index: int in range(eraser_shape_menu.item_count):
		eraser_shape_menu.set_item_checked(
			item_index,
			eraser_shape_menu.get_item_id(item_index) == selected_eraser_brush_shape
		)


func _build_center_workspace() -> Control:
	var center_layout: VBoxContainer = VBoxContainer.new()
	center_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_layout.add_theme_constant_override("separation", 0)
	center_layout.add_child(_build_canvas_toolbar())

	canvas_timeline_split = VSplitContainer.new()
	canvas_timeline_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_timeline_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_timeline_split.dragged.connect(_on_canvas_timeline_split_dragged)
	center_layout.add_child(canvas_timeline_split)

	var canvas_frame: PanelContainer = PanelContainer.new()
	canvas_frame.custom_minimum_size.y = MINIMUM_CANVAS_HEIGHT
	canvas_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_theme_stylebox_override("panel", _make_ui_style(Color("101218"), Color("303541"), 1, 0, 0))
	canvas_timeline_split.add_child(canvas_frame)
	canvas_scroll = ScrollContainer.new()
	canvas_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_scroll.resized.connect(_on_canvas_viewport_resized)
	canvas_frame.add_child(canvas_scroll)
	canvas_center = CenterContainer.new()
	canvas_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_scroll.add_child(canvas_center)
	canvas_view = GatorCanvas.new()
	canvas_view.set_pencil_brush_shape(selected_pencil_brush_shape)
	canvas_view.set_eraser_brush_shape(selected_eraser_brush_shape)
	canvas_view.pixels_changed.connect(_on_pixels_changed)
	canvas_view.color_picked.connect(_on_canvas_color_picked)
	canvas_view.zoom_changed.connect(_on_canvas_zoom_changed)
	canvas_view.pre_edit_provider = Callable(self, "_on_canvas_before_edit")
	canvas_view.custom_brush_stamp_provider = Callable(self, "_resolve_custom_brush_stamp")
	canvas_center.add_child(canvas_view)

	canvas_timeline_split.add_child(_build_timeline_panel())
	call_deferred("_apply_saved_timeline_split")
	return center_layout

func _build_canvas_toolbar() -> Control:
	var toolbar_panel: PanelContainer = PanelContainer.new()
	toolbar_panel.custom_minimum_size.y = 38.0
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar_panel.add_child(toolbar)

	var grid_button: Button = _make_toggle_icon_button("grid", "Toggle pixel grid", true, _on_grid_toggled)
	toolbar.add_child(grid_button)
	var onion_button: Button = _make_toggle_icon_button("onion", "Toggle onion skin", true, _on_onion_toggled)
	toolbar.add_child(onion_button)
	toolbar.add_child(_make_toolbar_separator())
	toolbar.add_child(_make_toggle_icon_button("mirror_h", "Mirror drawing horizontally", false, _on_mirror_horizontal_toggled))
	toolbar.add_child(_make_toggle_icon_button("mirror_v", "Mirror drawing vertically", false, _on_mirror_vertical_toggled))
	toolbar.add_child(_make_toggle_icon_button("tiled", "Wrap drawing across canvas edges", false, _on_tiled_drawing_toggled))

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	toolbar.add_child(_make_icon_button("zoom_out", "Zoom out", _on_zoom_out_pressed))
	toolbar.add_child(_make_icon_button("fit", "Fit canvas to workspace", _on_fit_zoom_pressed))
	toolbar.add_child(_make_icon_button("zoom_in", "Zoom in", _on_zoom_in_pressed))
	zoom_label = Label.new()
	zoom_label.text = "1400%"
	zoom_label.custom_minimum_size.x = 58.0
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_label.add_theme_color_override("font_color", Color("aeb9c9"))
	toolbar.add_child(zoom_label)
	return toolbar_panel

func _build_timeline_panel() -> Control:
	var timeline_panel: PanelContainer = PanelContainer.new()
	timeline_panel.custom_minimum_size.y = MINIMUM_TIMELINE_HEIGHT
	var timeline_layout: VBoxContainer = VBoxContainer.new()
	timeline_layout.add_theme_constant_override("separation", 3)
	timeline_panel.add_child(timeline_layout)
	var timeline_header: HBoxContainer = HBoxContainer.new()
	timeline_layout.add_child(timeline_header)
	var timeline_title: Label = _make_section_title("TIMELINE")
	timeline_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_header.add_child(timeline_title)

	timeline_header.add_child(_make_icon_button("layer_add", "Add layer", _on_add_layer_pressed))
	timeline_header.add_child(_make_icon_button("delete", "Delete selected layer", _on_delete_layer_pressed))
	timeline_header.add_child(_make_icon_button("group", "Group the selected layers", _on_add_group_pressed))
	timeline_header.add_child(_make_icon_button("ungroup", "Remove the selected layers from their groups", _on_ungroup_layer_pressed))
	timeline_header.add_child(_make_toolbar_separator())
	timeline_header.add_child(_make_icon_button("frame_add", "Add frame", _on_add_frame_pressed))
	timeline_header.add_child(_make_icon_button("duplicate", "Duplicate active frame", _on_copy_frame_pressed))
	timeline_header.add_child(_make_icon_button("link", "Duplicate the active frame as linked cels", _on_duplicate_linked_frame_pressed))
	timeline_header.add_child(_make_icon_button("link", "Link the selected frames on the active layer", _on_link_selected_cels_pressed))
	timeline_header.add_child(_make_icon_button("unlink", "Unlink the selected frames on the active layer", _on_unlink_selected_cels_pressed))
	timeline_header.add_child(_make_icon_button("delete", "Delete active frame", _on_delete_frame_pressed))
	timeline_header.add_child(_make_toolbar_separator())
	timeline_header.add_child(_make_icon_button("tag", "Add animation tag", _on_add_tag_pressed))
	timeline_header.add_child(_make_icon_button("delete", "Delete selected animation tag", _on_delete_tag_pressed))

	var timeline_scroll: ScrollContainer = ScrollContainer.new()
	timeline_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_layout.add_child(timeline_scroll)
	timeline_grid = GridContainer.new()
	timeline_grid.add_theme_constant_override("h_separation", 2)
	timeline_grid.add_theme_constant_override("v_separation", 2)
	timeline_scroll.add_child(timeline_grid)
	return timeline_panel

func _build_right_sidebar() -> Control:
	right_sidebar_tabs = TabContainer.new()
	right_sidebar_tabs.custom_minimum_size.x = 300.0
	right_sidebar_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_sidebar_tabs.add_child(_build_preview_tab())
	right_sidebar_tabs.add_child(_build_palette_tab())
	right_sidebar_tabs.add_child(_build_tools_tab())
	right_sidebar_tabs.add_child(_build_extensions_tab())
	return right_sidebar_tabs

func _build_preview_tab() -> Control:
	var preview_scroll: ScrollContainer = ScrollContainer.new()
	preview_scroll.name = "Preview"
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var preview_layout: VBoxContainer = VBoxContainer.new()
	preview_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_scroll.add_child(preview_layout)
	preview_layout.add_child(_make_section_title("ANIMATION PREVIEW"))

	var preview_frame: PanelContainer = PanelContainer.new()
	preview_frame.add_theme_stylebox_override("panel", _make_ui_style(Color("101218"), Color("363c48"), 1, 3, 8))
	preview_layout.add_child(preview_frame)
	preview_display = TextureRect.new()
	preview_display.custom_minimum_size = Vector2(244.0, 220.0)
	preview_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_frame.add_child(preview_display)

	var preview_controls: HBoxContainer = HBoxContainer.new()
	preview_layout.add_child(preview_controls)
	preview_play_button = _make_icon_button("play", "Play animation preview", _on_preview_play_pressed, "Play")
	preview_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_controls.add_child(preview_play_button)
	preview_controls.add_child(_make_dialog_label("FPS"))
	preview_fps_input = SpinBox.new()
	preview_fps_input.min_value = 1.0
	preview_fps_input.max_value = 60.0
	preview_fps_input.step = 1.0
	preview_fps_input.value = 12.0
	preview_fps_input.custom_minimum_size.x = 72.0
	preview_fps_input.value_changed.connect(_on_preview_fps_changed)
	preview_controls.add_child(preview_fps_input)

	live_draw_button = Button.new()
	live_draw_button.text = "Live Draw"
	live_draw_button.toggle_mode = true
	live_draw_button.tooltip_text = "Advance the editable canvas with animation playback so Pencil, Eraser, and Custom Brush strokes can be drawn across playing frames."
	live_draw_button.toggled.connect(_on_live_draw_toggled)
	preview_layout.add_child(live_draw_button)

	var preview_tag_controls: HBoxContainer = HBoxContainer.new()
	preview_layout.add_child(preview_tag_controls)
	preview_tag_controls.add_child(_make_dialog_label("Animation"))
	preview_tag_menu = OptionButton.new()
	preview_tag_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tag_menu.tooltip_text = "None plays every frame. Select a tag to loop its range."
	preview_tag_menu.item_selected.connect(_on_preview_tag_selected)
	preview_tag_controls.add_child(preview_tag_menu)
	return preview_scroll

func _build_palette_tab() -> Control:
	var palette_scroll: ScrollContainer = ScrollContainer.new()
	palette_scroll.name = "Colour"
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var palette_layout: VBoxContainer = VBoxContainer.new()
	palette_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.add_child(palette_layout)
	palette_layout.add_child(_make_section_title("PALETTE"))

	palette_preset_menu = OptionButton.new()
	palette_preset_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset_name: String in ["Studio", "NES", "Game Boy", "Game Boy Gray", "Master System", "SNES", "Genesis", "Atari 2600", "Commodore 64", "CGA", "EGA", "VGA 256", "PICO-8", "Arcade RGB"]:
		palette_preset_menu.add_item(preset_name)
	palette_preset_menu.item_selected.connect(_on_palette_preset_selected)
	palette_layout.add_child(palette_preset_menu)

	var palette_actions: HBoxContainer = HBoxContainer.new()
	palette_layout.add_child(palette_actions)
	palette_actions.add_child(_make_icon_button("palette_add", "Add primary colour to palette", _on_palette_add_pressed))
	palette_actions.add_child(_make_icon_button("new", "Create empty user palette", _on_new_palette_pressed))
	palette_actions.add_child(_make_icon_button("save", "Save palette", _on_save_palette_pressed))
	palette_actions.add_child(_make_icon_button("open", "Load palette", _on_load_palette_pressed))
	palette_actions.add_child(_make_icon_button("delete", "Delete selected user palette", _on_delete_palette_pressed))
	var palette_action_spacer: Control = Control.new()
	palette_action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_actions.add_child(palette_action_spacer)
	palette_actions.add_child(_make_icon_button("capture", "Build palette from every used sprite colour", _on_palette_from_project_pressed))

	var palette_frame: PanelContainer = PanelContainer.new()
	palette_frame.add_theme_stylebox_override("panel", _make_ui_style(Color("16191f"), Color("353b47"), 1, 3, 6))
	palette_layout.add_child(palette_frame)
	palette_grid = GridContainer.new()
	palette_grid.columns = 8
	palette_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_frame.add_child(palette_grid)

	var indexed_color_toggle: CheckButton = CheckButton.new()
	indexed_color_toggle.text = "Indexed Colour"
	indexed_color_toggle.tooltip_text = "Snap drawing colours to the active palette."
	indexed_color_toggle.toggled.connect(_on_indexed_color_toggled)
	palette_layout.add_child(indexed_color_toggle)
	var palette_lock_toggle: CheckButton = CheckButton.new()
	palette_lock_toggle.text = "Lock Palette"
	palette_lock_toggle.tooltip_text = "Prevent palette edits."
	palette_lock_toggle.toggled.connect(_on_palette_lock_toggled)
	palette_layout.add_child(palette_lock_toggle)
	return palette_scroll

func _build_tools_tab() -> Control:
	var tools_scroll: ScrollContainer = ScrollContainer.new()
	tools_scroll.name = "Tools"
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var tools_layout: VBoxContainer = VBoxContainer.new()
	tools_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(tools_layout)

	tools_layout.add_child(_make_section_title("BRUSH AND COLOUR"))
	tools_layout.add_child(_make_icon_button("brush", "Load a custom image brush", _on_load_brush_pressed, "Load Custom Brush"))
	var brush_size_controls: HBoxContainer = HBoxContainer.new()
	tools_layout.add_child(brush_size_controls)
	brush_size_controls.add_child(_make_dialog_label("Brush Size"))
	brush_size_input = _make_metadata_spinbox(1.0, 256.0, 1.0)
	brush_size_input.step = 1.0
	brush_size_input.suffix = " px"
	brush_size_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_size_input.editable = true
	brush_size_input.tooltip_text = "Pencil size in pixels. Custom brushes resize from their untouched source image. Use [ and ] to resize."
	brush_size_input.value_changed.connect(_on_brush_size_changed)
	brush_size_controls.add_child(brush_size_input)
	brush_dimensions_label = Label.new()
	brush_dimensions_label.text = "Pencil: 1 × 1 pixels"
	brush_dimensions_label.add_theme_color_override("font_color", Color("8994a5"))
	tools_layout.add_child(brush_dimensions_label)
	tools_layout.add_child(_make_icon_button("replace", "Replace one colour throughout the sprite", _on_replace_color_pressed, "Replace Colour"))
	tools_layout.add_child(_make_icon_button("deselect", "Clear the current pixel selection", _on_deselect_pressed, "Deselect"))

	tools_layout.add_child(_make_section_title("LAYER PROPERTIES"))
	var blend_row: HBoxContainer = HBoxContainer.new()
	blend_row.add_child(_make_dialog_label("Blend"))
	layer_blend_mode_menu = OptionButton.new()
	layer_blend_mode_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for blend_name: String in ["Normal", "Multiply", "Screen", "Add", "Subtract", "Overlay", "Darken", "Lighten"]:
		layer_blend_mode_menu.add_item(blend_name)
	layer_blend_mode_menu.item_selected.connect(_on_layer_blend_mode_selected)
	blend_row.add_child(layer_blend_mode_menu)
	tools_layout.add_child(blend_row)
	var opacity_row: HBoxContainer = HBoxContainer.new()
	opacity_row.add_child(_make_dialog_label("Opacity"))
	layer_opacity_input = _make_metadata_spinbox(0.0, 100.0, 100.0)
	layer_opacity_input.suffix = "%"
	layer_opacity_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_opacity_input.value_changed.connect(_on_layer_opacity_changed)
	opacity_row.add_child(layer_opacity_input)
	tools_layout.add_child(opacity_row)
	group_opacity_row = HBoxContainer.new()
	group_opacity_row.add_child(_make_dialog_label("Group Opacity"))
	group_opacity_input = _make_metadata_spinbox(0.0, 100.0, 100.0)
	group_opacity_input.suffix = "%"
	group_opacity_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_opacity_input.value_changed.connect(_on_group_opacity_changed)
	group_opacity_row.add_child(group_opacity_input)
	tools_layout.add_child(group_opacity_row)
	tools_layout.add_child(_make_icon_button("reference", "Add a non-exported reference image layer", _on_add_reference_image_pressed, "Add Reference Image"))
	var reference_heading: Label = _make_section_title("REFERENCE TRANSFORM")
	tools_layout.add_child(reference_heading)
	reference_controls.append(reference_heading)
	reference_position_x_input = _add_layer_property_spin_row(tools_layout, "Position X", -4096.0, 4096.0, 0.0, " px", _on_reference_transform_changed)
	reference_position_y_input = _add_layer_property_spin_row(tools_layout, "Position Y", -4096.0, 4096.0, 0.0, " px", _on_reference_transform_changed)
	reference_scale_x_input = _add_layer_property_spin_row(tools_layout, "Scale X", 1.0, 1600.0, 100.0, "%", _on_reference_transform_changed)
	reference_scale_y_input = _add_layer_property_spin_row(tools_layout, "Scale Y", 1.0, 1600.0, 100.0, "%", _on_reference_transform_changed)
	reference_rotation_input = _add_layer_property_spin_row(tools_layout, "Rotation", -360.0, 360.0, 0.0, "°", _on_reference_transform_changed)

	tools_layout.add_child(_make_section_title("CANVAS"))
	tools_layout.add_child(_make_icon_button("resize_canvas", "Resize the full document proportionally so neither dimension exceeds 1024 pixels", _on_resize_canvas_to_limit_pressed, "Resize to Max 1024"))

	tools_layout.add_child(_make_section_title("SELECTION TRANSFORM"))
	var transform_grid: GridContainer = GridContainer.new()
	transform_grid.columns = 4
	tools_layout.add_child(transform_grid)
	transform_grid.add_child(_make_icon_button("flip_h", "Flip selection horizontally", _on_flip_horizontal_pressed))
	transform_grid.add_child(_make_icon_button("flip_v", "Flip selection vertically", _on_flip_vertical_pressed))
	transform_grid.add_child(_make_icon_button("rotate_cw", "Rotate selection clockwise", _on_rotate_clockwise_pressed))
	transform_grid.add_child(_make_icon_button("rotate_ccw", "Rotate selection counter-clockwise", _on_rotate_counter_clockwise_pressed))
	transform_grid.add_child(_make_icon_button("scale_up", "Scale selection to 200%", _on_scale_up_pressed))
	transform_grid.add_child(_make_icon_button("scale_down", "Scale selection to 50%", _on_scale_down_pressed))
	transform_grid.add_child(_make_icon_button("skew_left", "Skew selection left", _on_skew_left_pressed))
	transform_grid.add_child(_make_icon_button("skew_right", "Skew selection right", _on_skew_right_pressed))

	tools_layout.add_child(_make_section_title("TILESET"))
	var tile_size_controls: HBoxContainer = HBoxContainer.new()
	tools_layout.add_child(tile_size_controls)
	tile_size_controls.add_child(_make_dialog_label("W"))
	tile_width_input = _make_metadata_spinbox(1.0, 256.0, 16.0)
	tile_width_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_size_controls.add_child(tile_width_input)
	tile_size_controls.add_child(_make_dialog_label("H"))
	tile_height_input = _make_metadata_spinbox(1.0, 256.0, 16.0)
	tile_height_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_size_controls.add_child(tile_height_input)
	tools_layout.add_child(_make_icon_button("capture", "Capture the current frame as a tileset", _on_capture_tileset_pressed, "Capture Frame as Tileset"))
	tools_layout.add_child(_make_icon_button("export", "Export captured tileset as PNG", _on_export_tileset_pressed, "Export Tileset PNG"))
	var tile_index_controls: HBoxContainer = HBoxContainer.new()
	tools_layout.add_child(tile_index_controls)
	tile_index_controls.add_child(_make_dialog_label("Active Tile"))
	tile_index_input = _make_metadata_spinbox(0.0, 0.0, 0.0)
	tile_index_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_index_input.value_changed.connect(_on_tile_index_changed)
	tile_index_controls.add_child(tile_index_input)
	return tools_scroll

func _add_layer_property_spin_row(parent: VBoxContainer, label_text: String, minimum: float, maximum: float, default_value: float, suffix_text: String, callback: Callable) -> SpinBox:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_make_dialog_label(label_text))
	var input: SpinBox = _make_metadata_spinbox(minimum, maximum, default_value)
	input.suffix = suffix_text
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.value_changed.connect(callback)
	row.add_child(input)
	parent.add_child(row)
	reference_controls.append(row)
	return input

func _build_extensions_tab() -> Control:
	var extensions_layout: VBoxContainer = VBoxContainer.new()
	extensions_layout.name = "Extensions"
	extensions_layout.add_child(_make_section_title("EXTENSIONS"))
	extensions_layout.add_child(_make_icon_button("add", "Load a Gator Sprite Studio extension", _on_load_extension_pressed, "Load Extension"))
	extensions_layout.add_child(_make_icon_button("delete", "Unload a loaded extension", _on_unload_extension_pressed, "Unload Extension"))
	extensions_layout.add_child(_make_icon_button("redo", "Reload a loaded extension and its UI", _on_reload_extension_pressed, "Reload Extension"))
	var extension_hint: Label = Label.new()
	extension_hint.text = "Official extensions load automatically as sidebar tabs. Manually loaded extension panels appear below."
	extension_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extension_hint.add_theme_color_override("font_color", Color("909bad"))
	extensions_layout.add_child(extension_hint)
	var official_extension_hint: Label = Label.new()
	official_extension_hint.text = "Auto-loaded: Gator Ink Lab, Gator Motion Lab, Gator Brush Vault, and the Aseprite Importer."
	official_extension_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	official_extension_hint.add_theme_color_override("font_color", Color("b7c6db"))
	extensions_layout.add_child(official_extension_hint)
	extension_panels = TabContainer.new()
	extension_panels.visible = false
	extension_panels.custom_minimum_size.y = 180.0
	extension_panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	extensions_layout.add_child(extension_panels)
	return extensions_layout

func _build_status_bar() -> Control:
	var status_panel: PanelContainer = PanelContainer.new()
	status_panel.custom_minimum_size.y = 28.0
	var status_layout: HBoxContainer = HBoxContainer.new()
	status_panel.add_child(status_layout)
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.add_theme_color_override("font_color", Color("b6c0cf"))
	status_layout.add_child(status_label)
	var input_hint: Label = Label.new()
	input_hint.text = "Canvas focus enables sprite shortcuts"
	input_hint.add_theme_color_override("font_color", Color("798496"))
	status_layout.add_child(input_hint)
	return status_panel

func _set_initial_workspace_split() -> void:
	if main_workspace_split == null:
		return
	main_workspace_split.split_offset = maxi(420, int(main_workspace_split.size.x) - 310)

func _load_user_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(USER_SETTINGS_PATH) == OK:
		saved_timeline_height = maxi(MINIMUM_TIMELINE_HEIGHT, int(settings.get_value("workspace", "timeline_height", DEFAULT_TIMELINE_HEIGHT)))
		selected_pencil_brush_shape = clampi(
			int(settings.get_value("tools", "pencil_brush_shape", int(GatorCanvas.PencilBrushShape.SQUARE))),
			int(GatorCanvas.PencilBrushShape.SQUARE),
			int(GatorCanvas.PencilBrushShape.CIRCLE)
		)
		selected_eraser_brush_shape = clampi(
			int(settings.get_value("tools", "eraser_brush_shape", int(GatorCanvas.PencilBrushShape.SQUARE))),
			int(GatorCanvas.PencilBrushShape.SQUARE),
			int(GatorCanvas.PencilBrushShape.CIRCLE)
		)

func _save_user_settings() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_SETTINGS_PATH).get_base_dir())
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("workspace", "timeline_height", saved_timeline_height)
	settings.set_value("tools", "pencil_brush_shape", selected_pencil_brush_shape)
	settings.set_value("tools", "eraser_brush_shape", selected_eraser_brush_shape)
	settings.save(USER_SETTINGS_PATH)

func _apply_saved_timeline_split() -> void:
	if canvas_timeline_split == null or canvas_timeline_split.size.y <= 0.0:
		return
	var maximum_timeline_height: int = maxi(MINIMUM_TIMELINE_HEIGHT, int(canvas_timeline_split.size.y) - MINIMUM_CANVAS_HEIGHT)
	saved_timeline_height = clampi(saved_timeline_height, MINIMUM_TIMELINE_HEIGHT, maximum_timeline_height)
	canvas_timeline_split.split_offset = maxi(MINIMUM_CANVAS_HEIGHT, int(canvas_timeline_split.size.y) - saved_timeline_height)

func _on_canvas_timeline_split_dragged(split_offset: int) -> void:
	if canvas_timeline_split == null:
		return
	saved_timeline_height = maxi(MINIMUM_TIMELINE_HEIGHT, int(canvas_timeline_split.size.y) - split_offset)
	_save_user_settings()
	if auto_fit_canvas:
		call_deferred("_fit_canvas_to_viewport")

func _style_tool_button(tool_button: Button) -> void:
	tool_button.add_theme_stylebox_override("pressed", _make_ui_style(Color("1769aa"), Color("b8dcff"), 2, 3, 5))
	tool_button.add_theme_stylebox_override("hover_pressed", _make_ui_style(Color("237fc4"), Color.WHITE, 2, 3, 5))

func _make_icon_button(icon_name: String, tooltip: String, handler: Callable, button_text: String = "") -> Button:
	var result_button: Button = Button.new()
	result_button.text = button_text
	result_button.icon = _load_icon(icon_name)
	result_button.tooltip_text = tooltip
	result_button.custom_minimum_size = Vector2(32.0, 32.0)
	result_button.focus_mode = Control.FOCUS_ALL
	if button_text.is_empty():
		result_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		result_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if handler.is_valid():
		result_button.pressed.connect(handler)
	return result_button

func _make_toggle_icon_button(icon_name: String, tooltip: String, is_pressed: bool, handler: Callable) -> Button:
	var toggle_button: Button = Button.new()
	toggle_button.icon = _load_icon(icon_name)
	toggle_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toggle_button.tooltip_text = tooltip
	toggle_button.custom_minimum_size = Vector2(32.0, 32.0)
	toggle_button.toggle_mode = true
	toggle_button.button_pressed = is_pressed
	toggle_button.toggled.connect(handler)
	return toggle_button

func _make_toolbar_separator(is_vertical: bool = true) -> Control:
	var separator: ColorRect = ColorRect.new()
	separator.color = Color("3a404b")
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_vertical:
		separator.custom_minimum_size = Vector2(1.0, 24.0)
	else:
		separator.custom_minimum_size = Vector2(36.0, 1.0)
	return separator

func _make_section_title(title_text: String) -> Label:
	var section_title: Label = Label.new()
	section_title.text = title_text
	section_title.custom_minimum_size.y = 24.0
	section_title.add_theme_color_override("font_color", Color("9da9ba"))
	section_title.add_theme_font_size_override("font_size", 11)
	return section_title

func _make_ui_style(background_color: Color, border_color: Color, border_width: int = 1, radius: int = 3, padding: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	return style

func _load_icon(icon_name: String) -> Texture2D:
	if icon_cache.has(icon_name):
		return icon_cache[icon_name] as Texture2D
	var icon_path: String = "%s%s.svg" % [ICON_ROOT, icon_name]
	var loaded_icon: Texture2D
	if ResourceLoader.exists(icon_path):
		loaded_icon = ResourceLoader.load(icon_path) as Texture2D
	if loaded_icon == null and FileAccess.file_exists(icon_path):
		var icon_bytes: PackedByteArray = FileAccess.get_file_as_bytes(icon_path)
		var icon_image: Image = Image.new()
		if not icon_bytes.is_empty() and icon_image.load_svg_from_buffer(icon_bytes, 1.0) == OK:
			loaded_icon = ImageTexture.create_from_image(icon_image)
	if loaded_icon != null:
		icon_cache[icon_name] = loaded_icon
	return loaded_icon

func _make_button(button_title: String, handler: Callable) -> Button:
	var result_button: Button = Button.new()
	result_button.text = button_title
	result_button.pressed.connect(handler)
	return result_button

func _build_new_sprite_dialog() -> void:
	new_sprite_dialog = ConfirmationDialog.new()
	new_sprite_dialog.title = "New Pixel Sprite"
	new_sprite_dialog.get_ok_button().hide()
	new_sprite_dialog.ok_button_text = "Cancel"
	var dialog_content: VBoxContainer = VBoxContainer.new()
	new_sprite_dialog.add_child(dialog_content)
	var dialog_prompt: Label = Label.new()
	dialog_prompt.text = "SQUARE"
	dialog_content.add_child(dialog_prompt)
	var size_grid: GridContainer = GridContainer.new()
	size_grid.columns = 4
	dialog_content.add_child(size_grid)
	for pixel_size: int in [8, 16, 32, 64, 128, 180, 256, 360, 480, 512]:
		var size_button: Button = Button.new()
		size_button.text = "%d × %d" % [pixel_size, pixel_size]
		size_button.custom_minimum_size = Vector2(96.0, 42.0)
		size_button.pressed.connect(_on_new_size_selected.bind(pixel_size))
		size_grid.add_child(size_button)
	var widescreen_prompt: Label = Label.new()
	widescreen_prompt.text = "WIDESCREEN"
	dialog_content.add_child(widescreen_prompt)
	var widescreen_grid: GridContainer = GridContainer.new()
	widescreen_grid.columns = 3
	dialog_content.add_child(widescreen_grid)
	for size_option: Dictionary in [
		{"label": "320 x 180", "size": Vector2i(320, 180)},
		{"label": "426 x 240", "size": Vector2i(426, 240)},
		{"label": "480 x 270", "size": Vector2i(480, 270)},
		{"label": "640 x 360", "size": Vector2i(640, 360)},
		{"label": "228 x 128", "size": Vector2i(228, 128)}
	]:
		var rectangular_size_button: Button = Button.new()
		rectangular_size_button.text = String(size_option["label"])
		rectangular_size_button.custom_minimum_size = Vector2(150.0, 42.0)
		rectangular_size_button.pressed.connect(_on_new_rectangular_size_selected.bind(size_option["size"]))
		widescreen_grid.add_child(rectangular_size_button)
	var console_prompt: Label = Label.new()
	console_prompt.text = "CONSOLE"
	dialog_content.add_child(console_prompt)
	var console_grid: GridContainer = GridContainer.new()
	console_grid.columns = 3
	dialog_content.add_child(console_grid)
	for console_option: Dictionary in [
		{"label": "160 x 192 (Atari 2600)", "size": Vector2i(160, 192)},
		{"label": "256 x 192 (Master System)", "size": Vector2i(256, 192)},
		{"label": "256 x 240 (NES)", "size": Vector2i(256, 240)},
		{"label": "256 x 224 (SNES)", "size": Vector2i(256, 224)},
		{"label": "320 x 224 (Genesis)", "size": Vector2i(320, 224)},
		{"label": "256 x 224 (TurboGrafx-16)", "size": Vector2i(256, 224)},
		{"label": "320 x 224 (Neo Geo)", "size": Vector2i(320, 224)},
		{"label": "320 x 240 (PlayStation)", "size": Vector2i(320, 240)},
		{"label": "160 x 144 (Game Boy / Gear)", "size": Vector2i(160, 144)},
		{"label": "160 x 102 (Atari Lynx)", "size": Vector2i(160, 102)},
		{"label": "224 x 144 (WonderSwan)", "size": Vector2i(224, 144)},
		{"label": "240 x 160 (Game Boy Advance)", "size": Vector2i(240, 160)}
	]:
		var console_size_button: Button = Button.new()
		console_size_button.text = String(console_option["label"])
		console_size_button.custom_minimum_size = Vector2(170.0, 42.0)
		console_size_button.pressed.connect(_on_new_rectangular_size_selected.bind(console_option["size"]))
		console_grid.add_child(console_size_button)
	var ultrawide_prompt: Label = Label.new()
	ultrawide_prompt.text = "ULTRAWIDE 21:9"
	dialog_content.add_child(ultrawide_prompt)
	var ultrawide_grid: GridContainer = GridContainer.new()
	ultrawide_grid.columns = 3
	dialog_content.add_child(ultrawide_grid)
	for ultrawide_option: Dictionary in [
		{"label": "299 x 128", "size": Vector2i(299, 128)},
		{"label": "420 x 180", "size": Vector2i(420, 180)},
		{"label": "560 x 240", "size": Vector2i(560, 240)},
		{"label": "630 x 270", "size": Vector2i(630, 270)},
		{"label": "840 x 360", "size": Vector2i(840, 360)}
	]:
		var ultrawide_size_button: Button = Button.new()
		ultrawide_size_button.text = String(ultrawide_option["label"])
		ultrawide_size_button.custom_minimum_size = Vector2(150.0, 42.0)
		ultrawide_size_button.pressed.connect(_on_new_rectangular_size_selected.bind(ultrawide_option["size"]))
		ultrawide_grid.add_child(ultrawide_size_button)
	add_child(new_sprite_dialog)

func _build_file_dialogs() -> void:
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_RESOURCES
	save_dialog.overwrite_warning_enabled = false
	save_dialog.add_filter("*.tres ; Gator Sprite Studio document")
	save_dialog.file_selected.connect(_on_save_path_selected)
	save_dialog.canceled.connect(_on_save_dialog_cancelled)
	add_child(save_dialog)
	load_dialog = FileDialog.new()
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.add_filter("*.tres ; Gator Sprite Studio document")
	load_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Supported image files")
	load_dialog.file_selected.connect(_on_load_path_selected)
	add_child(load_dialog)
	spritesheet_load_dialog = FileDialog.new()
	spritesheet_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	spritesheet_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	spritesheet_load_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Supported image files")
	spritesheet_load_dialog.file_selected.connect(_on_spritesheet_path_selected)
	add_child(spritesheet_load_dialog)
	reference_image_load_dialog = FileDialog.new()
	reference_image_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	reference_image_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	reference_image_load_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp, *.tga, *.svg ; Supported image files")
	reference_image_load_dialog.file_selected.connect(_on_reference_image_path_selected)
	add_child(reference_image_load_dialog)
	export_directory_dialog = FileDialog.new()
	export_directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	export_directory_dialog.access = FileDialog.ACCESS_RESOURCES
	export_directory_dialog.dir_selected.connect(_on_export_directory_selected)
	add_child(export_directory_dialog)
	brush_load_dialog = FileDialog.new()
	brush_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	brush_load_dialog.access = FileDialog.ACCESS_RESOURCES
	brush_load_dialog.add_filter("*.png ; PNG brush image")
	brush_load_dialog.file_selected.connect(_on_brush_path_selected)
	add_child(brush_load_dialog)
	palette_save_dialog = FileDialog.new()
	palette_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	palette_save_dialog.access = FileDialog.ACCESS_RESOURCES
	palette_save_dialog.add_filter("*.gpl ; GIMP palette")
	palette_save_dialog.file_selected.connect(_on_palette_save_path_selected)
	add_child(palette_save_dialog)
	palette_load_dialog = FileDialog.new()
	palette_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	palette_load_dialog.access = FileDialog.ACCESS_RESOURCES
	palette_load_dialog.add_filter("*.gpl ; GIMP palette")
	palette_load_dialog.file_selected.connect(_on_palette_load_path_selected)
	add_child(palette_load_dialog)
	extension_load_dialog = FileDialog.new()
	extension_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	extension_load_dialog.access = FileDialog.ACCESS_RESOURCES
	extension_load_dialog.add_filter("*.gd ; Gator Sprite Studio extension script")
	extension_load_dialog.file_selected.connect(_on_extension_path_selected)
	add_child(extension_load_dialog)
	tileset_export_dialog = FileDialog.new()
	tileset_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	tileset_export_dialog.access = FileDialog.ACCESS_RESOURCES
	tileset_export_dialog.add_filter("*.png ; Tileset PNG")
	tileset_export_dialog.file_selected.connect(_on_tileset_export_path_selected)
	add_child(tileset_export_dialog)

func _build_spritesheet_slice_dialog() -> void:
	spritesheet_slice_dialog = ConfirmationDialog.new()
	spritesheet_slice_dialog.title = "Import Spritesheet"
	spritesheet_slice_dialog.ok_button_text = "Import Frames"
	spritesheet_slice_dialog.min_size = Vector2i(520, 360)
	spritesheet_slice_dialog.max_size = Vector2i(560, 430)
	spritesheet_slice_dialog.confirmed.connect(_on_spritesheet_slice_confirmed)
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(480.0, 0.0)
	content.add_theme_constant_override("separation", 6)
	spritesheet_slice_dialog.add_child(content)
	spritesheet_source_label = Label.new()
	spritesheet_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(spritesheet_source_label)
	var description: Label = Label.new()
	description.text = "Slice the selected image into row-major animation frames."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	spritesheet_slice_mode_menu = OptionButton.new()
	spritesheet_slice_mode_menu.add_item("Slice by Columns and Rows", 0)
	spritesheet_slice_mode_menu.add_item("Slice by Cell Size", 1)
	spritesheet_slice_mode_menu.item_selected.connect(_on_spritesheet_slice_mode_changed)
	content.add_child(spritesheet_slice_mode_menu)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	grid.add_child(_make_dialog_label("Columns"))
	spritesheet_columns_input = _make_metadata_spinbox(1.0, 4096.0, 1.0)
	grid.add_child(spritesheet_columns_input)
	grid.add_child(_make_dialog_label("Rows"))
	spritesheet_rows_input = _make_metadata_spinbox(1.0, 4096.0, 1.0)
	grid.add_child(spritesheet_rows_input)
	grid.add_child(_make_dialog_label("Cell Width"))
	spritesheet_cell_width_input = _make_metadata_spinbox(1.0, 4096.0, 1.0)
	grid.add_child(spritesheet_cell_width_input)
	grid.add_child(_make_dialog_label("Cell Height"))
	spritesheet_cell_height_input = _make_metadata_spinbox(1.0, 4096.0, 1.0)
	grid.add_child(spritesheet_cell_height_input)
	grid.add_child(_make_dialog_label("Spacing X"))
	spritesheet_spacing_x_input = _make_metadata_spinbox(0.0, 256.0, 0.0)
	grid.add_child(spritesheet_spacing_x_input)
	grid.add_child(_make_dialog_label("Spacing Y"))
	spritesheet_spacing_y_input = _make_metadata_spinbox(0.0, 256.0, 0.0)
	grid.add_child(spritesheet_spacing_y_input)
	grid.add_child(_make_dialog_label("Margin X"))
	spritesheet_margin_x_input = _make_metadata_spinbox(0.0, 256.0, 0.0)
	grid.add_child(spritesheet_margin_x_input)
	grid.add_child(_make_dialog_label("Margin Y"))
	spritesheet_margin_y_input = _make_metadata_spinbox(0.0, 256.0, 0.0)
	grid.add_child(spritesheet_margin_y_input)
	spritesheet_row_tags_toggle = CheckButton.new()
	spritesheet_row_tags_toggle.text = "Create one animation tag per row"
	content.add_child(spritesheet_row_tags_toggle)
	add_child(spritesheet_slice_dialog)
	_on_spritesheet_slice_mode_changed(0)

func _on_spritesheet_slice_mode_changed(selected_index: int) -> void:
	var use_grid_count: bool = selected_index == 0
	if spritesheet_columns_input != null:
		spritesheet_columns_input.editable = use_grid_count
		spritesheet_rows_input.editable = use_grid_count
		spritesheet_cell_width_input.editable = not use_grid_count
		spritesheet_cell_height_input.editable = not use_grid_count

func _build_overwrite_save_dialog() -> void:
	overwrite_save_dialog = ConfirmationDialog.new()
	overwrite_save_dialog.title = "Overwrite Existing Document"
	overwrite_save_dialog.ok_button_text = "Overwrite"
	overwrite_save_dialog.cancel_button_text = "Cancel"
	overwrite_save_dialog.confirmed.connect(_on_overwrite_save_confirmed)
	overwrite_save_dialog.canceled.connect(_on_overwrite_save_cancelled)
	add_child(overwrite_save_dialog)

func _build_unsaved_changes_dialog() -> void:
	unsaved_changes_dialog = ConfirmationDialog.new()
	unsaved_changes_dialog.title = "Unsaved Changes"
	unsaved_changes_dialog.dialog_text = "Save changes to the current sprite before replacing it?"
	unsaved_changes_dialog.ok_button_text = "Save"
	unsaved_changes_dialog.cancel_button_text = "Cancel"
	unsaved_changes_dialog.confirmed.connect(_on_unsaved_save_requested)
	unsaved_changes_dialog.canceled.connect(_on_unsaved_cancelled)
	unsaved_changes_dialog.custom_action.connect(_on_unsaved_custom_action)
	unsaved_changes_dialog.add_button("Discard", true, "discard")
	add_child(unsaved_changes_dialog)

func _build_recovery_dialog() -> void:
	recovery_dialog = ConfirmationDialog.new()
	recovery_dialog.title = "Recover Unsaved Sprite"
	recovery_dialog.ok_button_text = "Recover"
	recovery_dialog.confirmed.connect(_on_recovery_confirmed)
	recovery_dialog.custom_action.connect(_on_recovery_custom_action)
	recovery_dialog.add_button("Discard Recovery", true, "discard")
	add_child(recovery_dialog)
	recovery_dialog.get_cancel_button().hide()

func _build_shortcut_dialog() -> void:
	shortcut_dialog = ConfirmationDialog.new()
	shortcut_dialog.title = "Keyboard Shortcuts"
	shortcut_dialog.ok_button_text = "Save Shortcuts"
	shortcut_dialog.min_size = Vector2i(520, 500)
	shortcut_dialog.max_size = Vector2i(560, 540)
	shortcut_dialog.confirmed.connect(_on_shortcuts_confirmed)
	var shortcut_content: VBoxContainer = VBoxContainer.new()
	shortcut_content.custom_minimum_size = Vector2(440.0, 0.0)
	shortcut_dialog.add_child(shortcut_content)
	var shortcut_header: HBoxContainer = HBoxContainer.new()
	shortcut_content.add_child(shortcut_header)
	var shortcut_help: Label = _make_dialog_label("Click a binding, then press its new key or combination. Press Esc to cancel capture.")
	shortcut_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shortcut_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_header.add_child(shortcut_help)
	var aseprite_defaults_button: Button = Button.new()
	aseprite_defaults_button.text = "Aseprite Defaults"
	aseprite_defaults_button.tooltip_text = "Restore all shortcut bindings to the Aseprite-style defaults."
	aseprite_defaults_button.pressed.connect(_on_aseprite_shortcuts_pressed)
	shortcut_header.add_child(aseprite_defaults_button)
	var shortcut_grid: GridContainer = GridContainer.new()
	shortcut_grid.columns = 2
	shortcut_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_content.add_child(shortcut_grid)
	for action_name: String in ["Pencil", "Eraser", "Fill", "Picker", "Line", "Rectangle", "Selection", "Decrease Brush Size", "Increase Brush Size", "Copy", "Paste", "Deselect", "Undo", "Redo"]:
		shortcut_grid.add_child(_make_dialog_label(action_name))
		var shortcut_input: Button = Button.new()
		shortcut_input.text = String(shortcut_bindings[action_name])
		shortcut_input.tooltip_text = "Click, then press a key or shortcut combination."
		shortcut_input.alignment = HORIZONTAL_ALIGNMENT_LEFT
		shortcut_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shortcut_input.pressed.connect(_on_shortcut_capture_requested.bind(action_name))
		shortcut_input.gui_input.connect(_on_shortcut_capture_gui_input.bind(action_name))
		shortcut_inputs[action_name] = shortcut_input
		shortcut_grid.add_child(shortcut_input)
	add_child(shortcut_dialog)

func _build_unload_extension_dialog() -> void:
	unload_extension_dialog = ConfirmationDialog.new()
	unload_extension_dialog.title = "Unload Extension"
	unload_extension_dialog.ok_button_text = "Unload"
	unload_extension_dialog.confirmed.connect(_on_unload_extension_confirmed)
	var unload_content: VBoxContainer = VBoxContainer.new()
	unload_content.custom_minimum_size = Vector2(360.0, 0.0)
	unload_extension_dialog.add_child(unload_content)
	unload_content.add_child(_make_dialog_label("Select the extension to remove from this editor session."))
	unload_extension_menu = OptionButton.new()
	unload_extension_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unload_content.add_child(unload_extension_menu)
	add_child(unload_extension_dialog)

func _build_replace_color_dialog() -> void:
	replace_color_dialog = ConfirmationDialog.new()
	replace_color_dialog.title = "Replace Color Across Sprite"
	replace_color_dialog.ok_button_text = "Replace Everywhere"
	replace_color_dialog.confirmed.connect(_on_replace_color_confirmed)
	var replace_content: VBoxContainer = VBoxContainer.new()
	replace_color_dialog.add_child(replace_content)
	var explanation: Label = Label.new()
	explanation.text = "Replace every exact color match in every layer and frame."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size = Vector2(360.0, 0.0)
	replace_content.add_child(explanation)
	var source_label: Label = Label.new()
	source_label.text = "Replace this color"
	replace_content.add_child(source_label)
	replace_source_picker = ColorPickerButton.new()
	replace_source_picker.custom_minimum_size = Vector2(0.0, 38.0)
	replace_content.add_child(replace_source_picker)
	var target_label: Label = Label.new()
	target_label.text = "With this color"
	replace_content.add_child(target_label)
	replace_target_picker = ColorPickerButton.new()
	replace_target_picker.custom_minimum_size = Vector2(0.0, 38.0)
	replace_content.add_child(replace_target_picker)
	add_child(replace_color_dialog)

func _build_resize_canvas_dialog() -> void:
	resize_canvas_dialog = ConfirmationDialog.new()
	resize_canvas_dialog.title = "Resize Sprite Document"
	resize_canvas_dialog.ok_button_text = "Resize"
	resize_canvas_dialog.cancel_button_text = "Cancel"
	resize_canvas_dialog.confirmed.connect(_on_resize_canvas_confirmed)
	add_child(resize_canvas_dialog)

func _build_metadata_dialog() -> void:
	metadata_dialog = ConfirmationDialog.new()
	metadata_dialog.title = "Slices and Pivot"
	metadata_dialog.ok_button_text = "Save Metadata"
	metadata_dialog.confirmed.connect(_on_metadata_confirmed)
	var metadata_content: VBoxContainer = VBoxContainer.new()
	metadata_dialog.add_child(metadata_content)
	var slice_title: Label = Label.new()
	slice_title.text = "SLICE + PIVOT (same name updates an existing slice)"
	metadata_content.add_child(slice_title)
	slice_name_input = LineEdit.new()
	slice_name_input.placeholder_text = "Slice name"
	metadata_content.add_child(slice_name_input)
	var slice_grid: GridContainer = GridContainer.new()
	slice_grid.columns = 4
	metadata_content.add_child(slice_grid)
	for slice_label: String in ["X", "Y", "Width", "Height", "Pivot X", "Pivot Y"]:
		slice_grid.add_child(_make_dialog_label(slice_label))
		var slice_input: SpinBox = _make_metadata_spinbox(-9999.0 if slice_label.begins_with("Pivot") else 0.0, 9999.0, 0.0)
		slice_grid.add_child(slice_input)
		match slice_label:
			"X": slice_x_input = slice_input
			"Y": slice_y_input = slice_input
			"Width": slice_width_input = slice_input
			"Height": slice_height_input = slice_input
			"Pivot X": slice_pivot_x_input = slice_input
			"Pivot Y": slice_pivot_y_input = slice_input
	add_child(metadata_dialog)

func _build_tag_dialog() -> void:
	tag_dialog = ConfirmationDialog.new()
	tag_dialog.title = "Timeline Tag"
	tag_dialog.ok_button_text = "Save Tag"
	tag_dialog.min_size = Vector2i(440, 260)
	tag_dialog.max_size = Vector2i(480, 340)
	tag_dialog.confirmed.connect(_on_tag_dialog_confirmed)
	var tag_content: VBoxContainer = VBoxContainer.new()
	tag_content.custom_minimum_size = Vector2(400.0, 0.0)
	tag_dialog.add_child(tag_content)
	var tag_help: Label = _make_dialog_label("Tags are visible above the frame headers and export as individual SpriteFrames animations.")
	tag_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_content.add_child(tag_help)
	tag_content.add_child(_make_dialog_label("Name"))
	tag_name_input = LineEdit.new()
	tag_name_input.placeholder_text = "e.g. Idle, Walk, Attack"
	tag_content.add_child(tag_name_input)
	var tag_range: HBoxContainer = HBoxContainer.new()
	tag_content.add_child(tag_range)
	tag_range.add_child(_make_dialog_label("From frame"))
	tag_from_input = _make_metadata_spinbox(1.0, 9999.0, 1.0)
	tag_range.add_child(tag_from_input)
	tag_range.add_child(_make_dialog_label("To frame"))
	tag_to_input = _make_metadata_spinbox(1.0, 9999.0, 1.0)
	tag_range.add_child(tag_to_input)
	tag_content.add_child(_make_dialog_label("Tag color"))
	tag_color_picker = ColorPickerButton.new()
	tag_color_picker.color = Color("3fb950")
	tag_color_picker.custom_minimum_size = Vector2(0.0, 30.0)
	tag_content.add_child(tag_color_picker)
	add_child(tag_dialog)

func _make_dialog_label(label_text: String) -> Label:
	var result_label: Label = Label.new()
	result_label.text = label_text
	return result_label

func _make_metadata_spinbox(minimum_value: float, maximum_value: float, initial_value: float) -> SpinBox:
	var result_spinbox: SpinBox = SpinBox.new()
	result_spinbox.min_value = minimum_value
	result_spinbox.max_value = maximum_value
	result_spinbox.value = initial_value
	result_spinbox.step = 1.0
	return result_spinbox

func _build_export_dialog() -> void:
	export_dialog = ConfirmationDialog.new()
	export_dialog.title = "Export Sprite Assets"
	export_dialog.ok_button_text = "Choose Folder"
	export_dialog.dialog_hide_on_ok = false
	export_dialog.min_size = Vector2i(420, 360)
	export_dialog.max_size = Vector2i(420, 360)
	export_dialog.confirmed.connect(_on_export_folder_requested)
	var export_content: VBoxContainer = VBoxContainer.new()
	export_dialog.add_child(export_content)
	var export_prompt: Label = Label.new()
	export_prompt.text = "Choose the assets to generate:"
	export_content.add_child(export_prompt)
	var export_name_label: Label = Label.new()
	export_name_label.text = "Export name"
	export_content.add_child(export_name_label)
	export_name_input = LineEdit.new()
	export_name_input.placeholder_text = "sprite"
	export_name_input.text = "sprite"
	export_name_input.tooltip_text = "Used for exported files only; this does not save the source document."
	export_content.add_child(export_name_input)
	export_frames_toggle = CheckBox.new()
	export_frames_toggle.text = "Individual PNG frames"
	export_frames_toggle.button_pressed = true
	export_content.add_child(export_frames_toggle)
	export_sheet_toggle = CheckBox.new()
	export_sheet_toggle.text = "Sprite sheet PNG + JSON metadata"
	export_sheet_toggle.button_pressed = true
	export_content.add_child(export_sheet_toggle)
	var grid_options: HBoxContainer = HBoxContainer.new()
	export_content.add_child(grid_options)
	var columns_label: Label = Label.new()
	columns_label.text = "Columns"
	grid_options.add_child(columns_label)
	export_columns_input = SpinBox.new()
	export_columns_input.min_value = 0.0
	export_columns_input.max_value = 128.0
	export_columns_input.step = 1.0
	export_columns_input.value = 0.0
	export_columns_input.tooltip_text = "0 automatically uses one horizontal row."
	grid_options.add_child(export_columns_input)
	var rows_label: Label = Label.new()
	rows_label.text = "Rows"
	grid_options.add_child(rows_label)
	export_rows_input = SpinBox.new()
	export_rows_input.min_value = 0.0
	export_rows_input.max_value = 128.0
	export_rows_input.step = 1.0
	export_rows_input.value = 0.0
	export_rows_input.tooltip_text = "0 automatically calculates the required rows."
	grid_options.add_child(export_rows_input)
	export_sprite_frames_toggle = CheckBox.new()
	export_sprite_frames_toggle.text = "Godot SpriteFrames resource (one animation per tag)"
	export_sprite_frames_toggle.button_pressed = true
	export_content.add_child(export_sprite_frames_toggle)
	export_custom_brush_toggle = CheckBox.new()
	export_custom_brush_toggle.text = "Brush PNG from selection or active frame"
	export_custom_brush_toggle.tooltip_text = "Exports the selected pixels, or the visible active frame when nothing is selected, as <name>_brush.png."
	export_custom_brush_toggle.button_pressed = false
	export_content.add_child(export_custom_brush_toggle)
	export_feedback_label = Label.new()
	export_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_feedback_label.custom_minimum_size = Vector2(360.0, 54.0)
	export_feedback_label.add_theme_color_override("font_color", Color("ff9f43"))
	export_feedback_label.visible = false
	export_content.add_child(export_feedback_label)
	add_child(export_dialog)

func create_new_document(requested_size: Vector2i, clear_existing_recovery: bool = true) -> void:
	if clear_existing_recovery:
		_clear_recovery_data()
	sprite_document = GatorSpriteDocument.new()
	sprite_document.setup_new_sprite(requested_size)
	canvas_view.set_document(sprite_document)
	_reset_frame_selection(0)
	_reset_layer_selection(0)
	_notify_extensions_document_ready()
	current_document_path = ""
	preview_frame_index = 0
	_set_preview_playing(false)
	_set_document_dirty(false)
	_refresh_interface()
	auto_fit_canvas = true
	call_deferred("_fit_canvas_to_viewport")
	status_label.text = "New %d × %d sprite ready." % [requested_size.x, requested_size.y]

func capture_session_state() -> Dictionary:
	return {
		"document": sprite_document,
		"document_path": current_document_path,
		"document_is_dirty": document_is_dirty,
		"recovery_elapsed": recovery_elapsed,
		"frame_index": canvas_view.active_frame_index,
		"layer_index": canvas_view.active_layer_index,
		"selected_layer_indices": selected_layer_indices.duplicate(),
		"preview_fps": preview_fps_input.value,
		"preview_tag_index": _get_selected_preview_tag_index(),
	}

func restore_session_state(session_state: Dictionary) -> void:
	var saved_document: Variant = session_state.get("document")
	if not saved_document is GatorSpriteDocument:
		return
	session_state_restored = true
	sprite_document = saved_document as GatorSpriteDocument
	canvas_view.set_document(sprite_document)
	current_document_path = String(session_state.get("document_path", ""))
	document_is_dirty = bool(session_state.get("document_is_dirty", true))
	recovery_elapsed = float(session_state.get("recovery_elapsed", 0.0))
	canvas_view.active_frame_index = clampi(int(session_state.get("frame_index", 0)), 0, sprite_document.get_active_animation().frame_count - 1)
	_reset_frame_selection(canvas_view.active_frame_index)
	canvas_view.active_layer_index = clampi(int(session_state.get("layer_index", 0)), 0, sprite_document.layers.size() - 1)
	selected_layer_indices.clear()
	var saved_layer_selection: Variant = session_state.get("selected_layer_indices", [canvas_view.active_layer_index])
	if saved_layer_selection is Array:
		for saved_layer_index: Variant in saved_layer_selection:
			selected_layer_indices.append(int(saved_layer_index))
	_sanitize_layer_selection(sprite_document.layers.size())
	preview_fps_input.value = float(session_state.get("preview_fps", sprite_document.get_active_animation().frames_per_second))
	_refresh_interface()
	_select_preview_tag_index(int(session_state.get("preview_tag_index", -1)))
	preview_frame_index = canvas_view.active_frame_index
	_refresh_preview()
	status_label.text = "Restored unsaved sprite session." if document_is_dirty else "Restored sprite session."

func _update_document_label() -> void:
	if document_label == null or sprite_document == null:
		return
	var dirty_suffix: String = " *" if document_is_dirty else ""
	document_label.text = "%s%s  •  %d × %d" % [sprite_document.document_title, dirty_suffix, sprite_document.canvas_size.x, sprite_document.canvas_size.y]

func _set_document_dirty(is_dirty: bool = true) -> void:
	if sprite_document == null:
		return
	if document_is_dirty == is_dirty:
		return
	document_is_dirty = is_dirty
	if is_dirty:
		recovery_elapsed = 0.0
	_update_document_label()

func _mark_document_dirty() -> void:
	_set_document_dirty(true)

func _request_protected_action(requested_action: Callable) -> bool:
	if not document_is_dirty:
		requested_action.call()
		return true
	pending_protected_action = requested_action
	unsaved_changes_dialog.popup_centered(Vector2i(480, 180))
	return false

func _execute_pending_protected_action() -> void:
	if not pending_protected_action.is_valid():
		return
	var requested_action: Callable = pending_protected_action
	pending_protected_action = Callable()
	continue_pending_action_after_save = false
	requested_action.call()

func _on_unsaved_save_requested() -> void:
	continue_pending_action_after_save = true
	if current_document_path.is_empty():
		save_dialog.title = "Save Gator Sprite Studio Document"
		save_dialog.current_file = "%s.tres" % sprite_document.document_title.to_snake_case()
		save_dialog.popup_centered_ratio(0.65)
		return
	if _save_document_to_path(current_document_path):
		_execute_pending_protected_action()
	else:
		_on_unsaved_cancelled()

func _on_unsaved_custom_action(action_name: StringName) -> void:
	if action_name == &"discard":
		unsaved_changes_dialog.hide()
		_execute_pending_protected_action()

func _on_unsaved_cancelled() -> void:
	pending_protected_action = Callable()
	continue_pending_action_after_save = false

func _on_save_dialog_cancelled() -> void:
	pending_overwrite_save_path = ""
	if continue_pending_action_after_save:
		pending_protected_action = Callable()
		continue_pending_action_after_save = false

func _on_overwrite_save_confirmed() -> void:
	if pending_overwrite_save_path.is_empty():
		return
	var save_path: String = pending_overwrite_save_path
	pending_overwrite_save_path = ""
	_complete_selected_save(save_path)

func _on_overwrite_save_cancelled() -> void:
	pending_overwrite_save_path = ""
	if continue_pending_action_after_save:
		_on_unsaved_cancelled()

func _ensure_recovery_directory() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_DIRECTORY))

func save_recovery_now() -> bool:
	if not document_is_dirty or sprite_document == null:
		return false
	if _ensure_recovery_directory() != OK:
		return false
	var recovery_copy: GatorSpriteDocument = sprite_document.duplicate(true) as GatorSpriteDocument
	if recovery_copy == null:
		return false
	var save_error: Error = ResourceSaver.save(recovery_copy, RECOVERY_DOCUMENT_PATH)
	if save_error != OK:
		return false
	var metadata: ConfigFile = ConfigFile.new()
	metadata.set_value("recovery", "document_path", current_document_path)
	metadata.set_value("recovery", "document_title", sprite_document.document_title)
	metadata.set_value("recovery", "frame_index", canvas_view.active_frame_index)
	metadata.set_value("recovery", "layer_index", canvas_view.active_layer_index)
	metadata.set_value("recovery", "saved_at", Time.get_unix_time_from_system())
	if metadata.save(RECOVERY_METADATA_PATH) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_DOCUMENT_PATH))
		return false
	recovery_elapsed = 0.0
	return true

func _clear_recovery_data() -> void:
	for recovery_path: String in [RECOVERY_DOCUMENT_PATH, RECOVERY_METADATA_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(recovery_path)
		if FileAccess.file_exists(recovery_path):
			DirAccess.remove_absolute(absolute_path)
	recovery_metadata.clear()

func _offer_recovery_if_available() -> void:
	if session_state_restored or recovery_dialog == null:
		return
	var has_recovery_document: bool = FileAccess.file_exists(RECOVERY_DOCUMENT_PATH)
	var has_recovery_metadata: bool = FileAccess.file_exists(RECOVERY_METADATA_PATH)
	if not has_recovery_document or not has_recovery_metadata:
		if has_recovery_document or has_recovery_metadata:
			_clear_recovery_data()
		return
	var metadata: ConfigFile = ConfigFile.new()
	if metadata.load(RECOVERY_METADATA_PATH) != OK:
		_clear_recovery_data()
		return
	var source_path: String = String(metadata.get_value("recovery", "document_path", ""))
	var recovery_saved_at: float = float(metadata.get_value("recovery", "saved_at", FileAccess.get_modified_time(RECOVERY_DOCUMENT_PATH)))
	if not source_path.is_empty() and FileAccess.file_exists(source_path):
		var manual_modified_time: int = int(FileAccess.get_modified_time(source_path))
		if recovery_saved_at <= float(manual_modified_time):
			_clear_recovery_data()
			return
	recovery_metadata = {
		"document_path": source_path,
		"document_title": String(metadata.get_value("recovery", "document_title", "Untitled Sprite")),
		"frame_index": int(metadata.get_value("recovery", "frame_index", 0)),
		"layer_index": int(metadata.get_value("recovery", "layer_index", 0)),
	}
	recovery_dialog.dialog_text = "A newer recovery copy of %s is available." % String(recovery_metadata["document_title"])
	recovery_dialog.popup_centered(Vector2i(480, 180))

func _on_recovery_confirmed() -> void:
	var loaded_resource: Resource = ResourceLoader.load(RECOVERY_DOCUMENT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var recovered_document: GatorSpriteDocument = loaded_resource as GatorSpriteDocument
	if recovered_document == null:
		status_label.text = "The recovery copy could not be loaded."
		return
	sprite_document = recovered_document
	current_document_path = String(recovery_metadata.get("document_path", ""))
	canvas_view.set_document(sprite_document)
	canvas_view.active_frame_index = clampi(int(recovery_metadata.get("frame_index", 0)), 0, sprite_document.get_active_animation().frame_count - 1)
	_reset_frame_selection(canvas_view.active_frame_index)
	canvas_view.active_layer_index = clampi(int(recovery_metadata.get("layer_index", 0)), 0, sprite_document.layers.size() - 1)
	_reset_layer_selection(canvas_view.active_layer_index)
	preview_frame_index = canvas_view.active_frame_index
	_set_preview_playing(false)
	_set_document_dirty(true)
	_notify_extensions_document_ready()
	_refresh_interface()
	auto_fit_canvas = true
	call_deferred("_fit_canvas_to_viewport")
	status_label.text = "Recovered unsaved changes for %s." % sprite_document.document_title

func _on_recovery_custom_action(action_name: StringName) -> void:
	if action_name == &"discard":
		recovery_dialog.hide()
		_clear_recovery_data()
		status_label.text = "Discarded the recovery copy."

func _get_selected_preview_tag_index() -> int:
	if preview_tag_menu == null or preview_tag_menu.selected <= 0:
		return -1
	var selected_metadata: Variant = preview_tag_menu.get_item_metadata(preview_tag_menu.selected)
	return int(selected_metadata) if selected_metadata is int else -1

func _select_preview_tag_index(tag_index: int) -> void:
	if preview_tag_menu == null:
		return
	for menu_index: int in range(preview_tag_menu.item_count):
		if int(preview_tag_menu.get_item_metadata(menu_index)) == tag_index:
			preview_tag_menu.select(menu_index)
			return
	preview_tag_menu.select(0)

func _refresh_interface() -> void:
	_update_document_label()
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	_rebuild_timeline_grid(active_animation)
	_rebuild_palette()
	_refresh_layer_property_controls()
	canvas_view.refresh_canvas()
	_update_canvas_centering()
	if preview_fps_input != null:
		preview_fps_input.value = sprite_document.get_active_animation().frames_per_second
	_rebuild_preview_tag_menu()
	_refresh_preview()
	_update_selection_status()
	_update_zoom_label()

func _apply_new_palette(new_colors: PackedColorArray) -> void:
	var old_palette: PackedColorArray = sprite_document.palette
	sprite_document.palette = new_colors
	if sprite_document.indexed_color_mode:
		sprite_document.remap_indexed_pixels(old_palette, new_colors)
	_rebuild_palette()
	_refresh_layer_property_controls()
	canvas_view.refresh_canvas()
	_refresh_preview()
	_mark_document_dirty()

func _rebuild_palette() -> void:
	if palette_grid == null or sprite_document == null:
		return
	for palette_child: Node in palette_grid.get_children():
		palette_grid.remove_child(palette_child)
		palette_child.queue_free()
	for palette_color: Color in sprite_document.palette:
		var swatch: Button = Button.new()
		swatch.custom_minimum_size = Vector2(27.0, 27.0)
		swatch.tooltip_text = "Use %s" % palette_color.to_html(true)
		swatch.add_theme_stylebox_override("normal", _make_color_swatch_style(palette_color))
		swatch.pressed.connect(_on_palette_color_selected.bind(palette_color))
		palette_grid.add_child(swatch)
	_sync_active_color_to_palette()

func _sync_active_color_to_palette() -> void:
	if sprite_document == null or not sprite_document.indexed_color_mode:
		return
	var snapped_primary: Color = sprite_document.resolve_palette_color(color_picker.color)
	color_picker.color = snapped_primary
	canvas_view.brush_color = snapped_primary
	var snapped_secondary: Color = sprite_document.resolve_palette_color(secondary_color_picker.color)
	secondary_color_picker.color = snapped_secondary
	canvas_view.secondary_color = snapped_secondary

func _make_color_swatch_style(swatch_color: Color) -> StyleBoxFlat:
	var swatch_style: StyleBoxFlat = StyleBoxFlat.new()
	swatch_style.bg_color = swatch_color
	swatch_style.border_color = Color("b8c0ca")
	swatch_style.set_border_width_all(1)
	swatch_style.corner_radius_top_left = 2
	swatch_style.corner_radius_top_right = 2
	swatch_style.corner_radius_bottom_left = 2
	swatch_style.corner_radius_bottom_right = 2
	return swatch_style

func _on_palette_color_selected(selected_palette_color: Color) -> void:
	color_picker.color = selected_palette_color
	canvas_view.brush_color = selected_palette_color

func _on_palette_add_pressed() -> void:
	if sprite_document.palette_locked:
		status_label.text = "Unlock the palette before adding colors."
		return
	if sprite_document.palette.has(color_picker.color):
		status_label.text = "That color is already in the palette."
		return
	sprite_document.palette.append(color_picker.color)
	_rebuild_palette()
	_mark_document_dirty()
	status_label.text = "Added %s to the palette." % color_picker.color.to_html(true)

func _on_new_palette_pressed() -> void:
	var new_palette: PackedColorArray = PackedColorArray()
	sprite_document.palette = new_palette
	_rebuild_palette()
	_add_user_palette_entry("New Palette %d" % (user_palette_entries.size() + 1), new_palette)
	_mark_document_dirty()
	status_label.text = "New empty palette created."

func _on_save_palette_pressed() -> void:
	palette_save_dialog.current_file = "gator_palette.gpl"
	palette_save_dialog.popup_centered_ratio(0.65)

func _on_load_palette_pressed() -> void:
	palette_load_dialog.popup_centered_ratio(0.65)

func _on_palette_from_project_pressed() -> void:
	var discovered_colors: Dictionary = {}
	for sprite_layer: GatorSpriteLayer in sprite_document.layers:
		for sprite_cel: GatorSpriteCel in sprite_layer.cels:
			var cel_image: Image = sprite_cel.get_image(sprite_document.canvas_size)
			for pixel_y: int in range(cel_image.get_height()):
				for pixel_x: int in range(cel_image.get_width()):
					var project_color: Color = cel_image.get_pixel(pixel_x, pixel_y)
					if project_color.a <= 0.0:
						continue
					discovered_colors[project_color.to_html(true)] = project_color
					if discovered_colors.size() >= 256:
						break
				if discovered_colors.size() >= 256:
					break
			if discovered_colors.size() >= 256:
				break
		if discovered_colors.size() >= 256:
			break
	sprite_document.palette = PackedColorArray()
	for discovered_color_key: String in discovered_colors.keys():
		var discovered_color: Color = discovered_colors[discovered_color_key]
		sprite_document.palette.append(discovered_color)
	_rebuild_palette()
	_add_user_palette_entry("Project Palette", sprite_document.palette)
	_mark_document_dirty()
	status_label.text = "Created a %d-color palette from the project." % sprite_document.palette.size()

func _on_palette_save_path_selected(selected_path: String) -> void:
	var palette_path: String = selected_path if selected_path.to_lower().ends_with(".gpl") else "%s.gpl" % selected_path
	var palette_file: FileAccess = FileAccess.open(palette_path, FileAccess.WRITE)
	if palette_file == null:
		status_label.text = "Could not save palette: %d" % FileAccess.get_open_error()
		return
	palette_file.store_line("GIMP Palette")
	palette_file.store_line("Name: %s" % sprite_document.document_title)
	palette_file.store_line("Columns: 8")
	palette_file.store_line("#")
	for palette_color: Color in sprite_document.palette:
		palette_file.store_line("%d %d %d %s" % [roundi(palette_color.r * 255.0), roundi(palette_color.g * 255.0), roundi(palette_color.b * 255.0), palette_color.to_html(false)])
	palette_file.close()
	var saved_palette_name: String = palette_path.get_file().get_basename()
	var selected_palette_index: int = palette_preset_menu.selected
	if selected_palette_index >= BUILTIN_PALETTE_COUNT:
		_update_user_palette_entry(selected_palette_index - BUILTIN_PALETTE_COUNT, saved_palette_name, sprite_document.palette)
	else:
		_add_user_palette_entry(saved_palette_name, sprite_document.palette)
	status_label.text = "Saved palette %s" % palette_path.get_file()

func _on_palette_load_path_selected(selected_path: String) -> void:
	var palette_file: FileAccess = FileAccess.open(selected_path, FileAccess.READ)
	if palette_file == null:
		status_label.text = "Could not load palette: %d" % FileAccess.get_open_error()
		return
	var loaded_colors: PackedColorArray = PackedColorArray()
	while not palette_file.eof_reached() and loaded_colors.size() < 256:
		var palette_line: String = palette_file.get_line().strip_edges()
		if palette_line.is_empty() or palette_line.begins_with("#") or palette_line.begins_with("GIMP") or palette_line.begins_with("Name:") or palette_line.begins_with("Columns:"):
			continue
		var color_components: PackedStringArray = palette_line.split(" ", false, 3)
		if color_components.size() < 3:
			continue
		if not color_components[0].is_valid_int() or not color_components[1].is_valid_int() or not color_components[2].is_valid_int():
			continue
		loaded_colors.append(Color(float(color_components[0].to_int()) / 255.0, float(color_components[1].to_int()) / 255.0, float(color_components[2].to_int()) / 255.0, 1.0))
	palette_file.close()
	if loaded_colors.is_empty():
		status_label.text = "No colors found in %s" % selected_path.get_file()
		return
	_apply_new_palette(loaded_colors)
	_add_user_palette_entry(selected_path.get_file().get_basename(), loaded_colors)
	status_label.text = "Loaded %d colors from %s" % [loaded_colors.size(), selected_path.get_file()]

func _on_palette_preset_selected(preset_index: int) -> void:
	var preset_colors: PackedColorArray = _get_palette_preset(preset_index) if preset_index < BUILTIN_PALETTE_COUNT else user_palette_entries[preset_index - BUILTIN_PALETTE_COUNT]
	if preset_colors.is_empty():
		return
	_apply_new_palette(preset_colors)
	_rebuild_palette()
	status_label.text = "%s palette applied." % palette_preset_menu.get_item_text(preset_index)

func _add_user_palette_entry(palette_name: String, palette_colors: PackedColorArray) -> void:
	var entry_name: String = palette_name if not palette_name.is_empty() else "User Palette %d" % (user_palette_entries.size() + 1)
	var existing_entry_index: int = user_palette_names.find(entry_name)
	if existing_entry_index >= 0:
		_update_user_palette_entry(existing_entry_index, entry_name, palette_colors)
		return
	user_palette_names.append(entry_name)
	user_palette_entries.append(palette_colors)
	var entry_index: int = BUILTIN_PALETTE_COUNT + user_palette_entries.size() - 1
	palette_preset_menu.add_item(entry_name)
	palette_preset_menu.select(entry_index)

func _update_user_palette_entry(user_entry_index: int, palette_name: String, palette_colors: PackedColorArray) -> void:
	if user_entry_index < 0 or user_entry_index >= user_palette_entries.size():
		return
	user_palette_names[user_entry_index] = palette_name
	user_palette_entries[user_entry_index] = palette_colors
	var dropdown_index: int = BUILTIN_PALETTE_COUNT + user_entry_index
	palette_preset_menu.set_item_text(dropdown_index, palette_name)
	palette_preset_menu.select(dropdown_index)

func _on_delete_palette_pressed() -> void:
	var selected_palette_index: int = palette_preset_menu.selected
	if selected_palette_index < BUILTIN_PALETTE_COUNT:
		status_label.text = "Built-in palettes cannot be deleted."
		return
	var user_entry_index: int = selected_palette_index - BUILTIN_PALETTE_COUNT
	user_palette_names.remove_at(user_entry_index)
	user_palette_entries.remove_at(user_entry_index)
	palette_preset_menu.remove_item(selected_palette_index)
	palette_preset_menu.select(0)
	_apply_new_palette(_get_palette_preset(0))
	status_label.text = "User palette deleted."

func _get_palette_preset(preset_index: int) -> PackedColorArray:
	match preset_index:
		1:
			return PackedColorArray([Color("000000"), Color("fcfcfc"), Color("f8f8f8"), Color("b8b8b8"), Color("7c7c7c"), Color("3c3c3c"), Color("a80020"), Color("f83800"), Color("f87800"), Color("f8b800"), Color("f8f878"), Color("00a800"), Color("00f800"), Color("00a8f8"), Color("0058f8"), Color("6844fc")])
		2:
			return PackedColorArray([Color("0f380f"), Color("306230"), Color("8bac0f"), Color("9bbc0f")])
		3:
			return PackedColorArray([Color("111111"), Color("555555"), Color("aaaaaa"), Color("eeeeee")])
		4:
			return PackedColorArray([Color("000000"), Color("ffffff"), Color("3f3f3f"), Color("7f7f7f"), Color("bfbfbf"), Color("ff0000"), Color("ff7f00"), Color("ffff00"), Color("00ff00"), Color("00ffff"), Color("0000ff"), Color("7f00ff"), Color("ff00ff")])
		5:
			return PackedColorArray([Color("000000"), Color("ffffff"), Color("7c7c7c"), Color("b8b8b8"), Color("3838bc"), Color("5454e8"), Color("acacfc"), Color("007800"), Color("00b800"), Color("b8f8b8"), Color("b80000"), Color("f87858"), Color("f8b800"), Color("f8f878"), Color("00b8b8"), Color("b800b8")])
		6:
			return PackedColorArray([Color("000000"), Color("ffffff"), Color("202020"), Color("606060"), Color("a0a0a0"), Color("e0e0e0"), Color("004080"), Color("0080c0"), Color("00a040"), Color("40c000"), Color("c08000"), Color("f0c000"), Color("800040"), Color("c00080"), Color("8040c0"), Color("c080ff")])
		7:
			return PackedColorArray([Color("000000"), Color("4a4a4a"), Color("6d001a"), Color("9b1d29"), Color("ab5c1c"), Color("c4a300"), Color("5a7d2b"), Color("1a6b3b"), Color("1a7c8c"), Color("2455a4"), Color("4a3a8c"), Color("7b2f8b"), Color("b83b7a"), Color("d58c4a"), Color("d8d8a8"), Color("ffffff")])
		8:
			return PackedColorArray([Color("000000"), Color("ffffff"), Color("68372b"), Color("70a4b2"), Color("6f3d86"), Color("588d43"), Color("352879"), Color("b8c76f"), Color("6f4f25"), Color("433900"), Color("9a6759"), Color("444444"), Color("6c6c6c"), Color("9adbcf"), Color("b8a8e8"), Color("b8b8b8")])
		9:
			return PackedColorArray([Color("000000"), Color("00aaaa"), Color("aa00aa"), Color("aaaaaa"), Color("555555"), Color("5555ff"), Color("ff5555"), Color("ffffff")])
		10:
			return PackedColorArray([Color("000000"), Color("0000aa"), Color("00aa00"), Color("00aaaa"), Color("aa0000"), Color("aa00aa"), Color("aa5500"), Color("aaaaaa"), Color("555555"), Color("5555ff"), Color("55ff55"), Color("55ffff"), Color("ff5555"), Color("ff55ff"), Color("ffff55"), Color("ffffff")])
		11:
			return PackedColorArray([Color("000000"), Color("0000aa"), Color("00aa00"), Color("00aaaa"), Color("aa0000"), Color("aa00aa"), Color("aa5500"), Color("aaaaaa"), Color("555555"), Color("5555ff"), Color("55ff55"), Color("55ffff"), Color("ff5555"), Color("ff55ff"), Color("ffff55"), Color("ffffff"), Color("202020"), Color("404040"), Color("606060"), Color("808080"), Color("a0a0a0"), Color("c0c0c0"), Color("e0e0e0"), Color("f0f0f0")])
		12:
			return PackedColorArray([Color("000000"), Color("1d2b53"), Color("7e2553"), Color("008751"), Color("ab5236"), Color("5f574f"), Color("c2c3c7"), Color("fff1e8"), Color("ff004d"), Color("ffa300"), Color("ffec27"), Color("00e436"), Color("29adff"), Color("83769c"), Color("ff77a8"), Color("ffccaa")])
		13:
			return PackedColorArray([Color("000000"), Color("202020"), Color("404040"), Color("606060"), Color("808080"), Color("a0a0a0"), Color("c0c0c0"), Color("ffffff"), Color("ff0000"), Color("00ff00"), Color("0000ff"), Color("ffff00"), Color("00ffff"), Color("ff00ff"), Color("ff8000"), Color("8000ff")])
		_:
			return PackedColorArray([Color.WHITE, Color.BLACK, Color("3fb950"), Color("1c3526"), Color("ff9f43"), Color("62d6ff"), Color("d96cff"), Color("f5f5f5")])

func _update_selection_status() -> void:
	if sprite_document == null or status_label == null:
		return
	if selected_layer_indices.size() > 1 and selected_frame_indices.size() > 1:
		status_label.text = "%d layers and %d frames selected. Active frame %d, layer %d." % [selected_layer_indices.size(), selected_frame_indices.size(), canvas_view.active_frame_index + 1, canvas_view.active_layer_index + 1]
	elif selected_layer_indices.size() > 1:
		status_label.text = "%d layers selected. Active frame %d, layer %d." % [selected_layer_indices.size(), canvas_view.active_frame_index + 1, canvas_view.active_layer_index + 1]
	elif selected_frame_indices.size() > 1:
		status_label.text = "%d frames selected. Active frame %d, layer %d." % [selected_frame_indices.size(), canvas_view.active_frame_index + 1, canvas_view.active_layer_index + 1]
	else:
		status_label.text = "Drawing frame %d, layer %d" % [canvas_view.active_frame_index + 1, canvas_view.active_layer_index + 1]

func _sanitize_frame_selection(frame_count: int) -> void:
	var sanitized_selection: Array[int] = []
	for selected_frame_index: int in selected_frame_indices:
		if selected_frame_index >= 0 and selected_frame_index < frame_count and not sanitized_selection.has(selected_frame_index):
			sanitized_selection.append(selected_frame_index)
	sanitized_selection.sort()
	selected_frame_indices = sanitized_selection
	if selected_frame_indices.is_empty() and frame_count > 0:
		var fallback_frame_index: int = clampi(canvas_view.active_frame_index, 0, frame_count - 1)
		selected_frame_indices.append(fallback_frame_index)
	frame_selection_anchor = clampi(frame_selection_anchor, 0, maxi(0, frame_count - 1))

func _reset_frame_selection(frame_index: int) -> void:
	selected_frame_indices.clear()
	selected_frame_indices.append(maxi(0, frame_index))
	frame_selection_anchor = maxi(0, frame_index)

func _copy_selected_frame_indices() -> Array[int]:
	var copied_selection: Array[int] = []
	for selected_frame_index: int in selected_frame_indices:
		copied_selection.append(selected_frame_index)
	return copied_selection

func _sanitize_layer_selection(layer_count: int) -> void:
	var sanitized_selection: Array[int] = []
	for selected_layer_index: int in selected_layer_indices:
		if selected_layer_index >= 0 and selected_layer_index < layer_count and not sanitized_selection.has(selected_layer_index):
			sanitized_selection.append(selected_layer_index)
	sanitized_selection.sort()
	selected_layer_indices = sanitized_selection
	if selected_layer_indices.is_empty() and layer_count > 0:
		var fallback_layer_index: int = clampi(canvas_view.active_layer_index, 0, layer_count - 1)
		selected_layer_indices.append(fallback_layer_index)
	layer_selection_anchor = clampi(layer_selection_anchor, 0, maxi(0, layer_count - 1))

func _reset_layer_selection(layer_index: int) -> void:
	selected_layer_indices.clear()
	selected_layer_indices.append(maxi(0, layer_index))
	layer_selection_anchor = maxi(0, layer_index)

func _copy_selected_layer_indices() -> Array[int]:
	var copied_selection: Array[int] = []
	for selected_layer_index: int in selected_layer_indices:
		copied_selection.append(selected_layer_index)
	return copied_selection

func _rebuild_timeline_grid(active_animation: GatorSpriteAnimation) -> void:
	timeline_frame_buttons.clear()
	timeline_layer_buttons.clear()
	timeline_group_buttons.clear()
	timeline_cel_buttons.clear()
	for timeline_child: Node in timeline_grid.get_children():
		timeline_grid.remove_child(timeline_child)
		timeline_child.queue_free()
	timeline_grid.columns = active_animation.frame_count + 1
	_sanitize_frame_selection(active_animation.frame_count)
	_sanitize_layer_selection(sprite_document.layers.size())
	_build_compact_tag_lanes(active_animation)

	var layer_header: Label = Label.new()
	layer_header.text = "LAYERS"
	layer_header.custom_minimum_size = Vector2(184.0, 30.0)
	layer_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer_header.add_theme_color_override("font_color", Color("a9b4c4"))
	timeline_grid.add_child(layer_header)
	for header_frame_index: int in range(active_animation.frame_count):
		var frame_header: GatorTimelineFrameButton = TimelineFrameButton.new() as GatorTimelineFrameButton
		frame_header.frame_index = header_frame_index
		frame_header.selected_frame_indices = _copy_selected_frame_indices()
		frame_header.text = str(header_frame_index + 1)
		frame_header.tooltip_text = "Frame %d. Ctrl-click toggles selection, Shift-click selects a range, and drag reorders selected frames." % (header_frame_index + 1)
		frame_header.custom_minimum_size = Vector2(44.0, 30.0)
		frame_header.mouse_default_cursor_shape = Control.CURSOR_DRAG
		var frame_is_active: bool = header_frame_index == canvas_view.active_frame_index
		var frame_is_selected: bool = selected_frame_indices.has(header_frame_index)
		frame_header.add_theme_stylebox_override("normal", _timeline_frame_style(frame_is_active, frame_is_selected, false))
		frame_header.add_theme_stylebox_override("hover", _timeline_frame_style(frame_is_active, frame_is_selected, true))
		frame_header.add_theme_color_override("font_color", Color.WHITE if frame_is_active or frame_is_selected else Color("aeb7c5"))
		frame_header.selection_requested.connect(_on_frame_selection_requested)
		frame_header.frames_dropped.connect(_on_frames_dropped)
		timeline_frame_buttons.append(frame_header)
		timeline_grid.add_child(frame_header)

	var rendered_groups: Dictionary[String, bool] = {}
	for layer_index: int in range(sprite_document.layers.size()):
		var sprite_layer: GatorSpriteLayer = sprite_document.layers[layer_index]
		var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(sprite_layer.group_title)
		if layer_group != null and not rendered_groups.has(layer_group.group_title):
			_add_group_timeline_row(layer_group, active_animation)
			rendered_groups[layer_group.group_title] = true
		if layer_group != null and layer_group.collapsed:
			continue
		_add_layer_timeline_row(layer_index, active_animation)

func _add_group_timeline_row(layer_group: GatorSpriteLayerGroup, active_animation: GatorSpriteAnimation) -> void:
	var member_indices: Array[int] = sprite_document.get_group_layer_indices(layer_group.group_title)
	if member_indices.is_empty():
		return
	var group_cell: HBoxContainer = HBoxContainer.new()
	group_cell.custom_minimum_size = Vector2(184.0, 30.0)
	group_cell.add_theme_constant_override("separation", 2)

	var collapse_button: Button = Button.new()
	collapse_button.text = "▸" if layer_group.collapsed else "▾"
	collapse_button.custom_minimum_size = Vector2(24.0, 28.0)
	collapse_button.tooltip_text = "Expand or collapse %s" % layer_group.group_title
	collapse_button.pressed.connect(_on_group_collapsed_toggled.bind(layer_group.group_title))
	group_cell.add_child(collapse_button)

	var visibility_button: Button = Button.new()
	visibility_button.icon = _load_icon("eye" if layer_group.visible else "eye_off")
	visibility_button.toggle_mode = true
	visibility_button.button_pressed = layer_group.visible
	visibility_button.custom_minimum_size = Vector2(28.0, 28.0)
	visibility_button.tooltip_text = "Show or hide every layer in %s" % layer_group.group_title
	visibility_button.toggled.connect(_on_group_visibility_toggled.bind(layer_group.group_title))
	group_cell.add_child(visibility_button)

	var lock_button: Button = Button.new()
	lock_button.icon = _load_icon("lock" if layer_group.locked else "unlock")
	lock_button.toggle_mode = true
	lock_button.button_pressed = layer_group.locked
	lock_button.custom_minimum_size = Vector2(28.0, 28.0)
	lock_button.tooltip_text = "Lock or unlock every layer in %s" % layer_group.group_title
	lock_button.toggled.connect(_on_group_lock_toggled.bind(layer_group.group_title))
	group_cell.add_child(lock_button)

	var group_button: GatorTimelineGroupButton = TimelineGroupButton.new() as GatorTimelineGroupButton
	group_button.group_title = layer_group.group_title
	group_button.member_layer_indices = member_indices.duplicate()
	group_button.text = "%s  (%d)" % [layer_group.group_title, member_indices.size()]
	group_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	group_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_button.mouse_default_cursor_shape = Control.CURSOR_DRAG
	group_button.tooltip_text = "Drag to move the group. Drop layers in the center to add them, or near the top/bottom edge to place them outside the group."
	var group_is_selected: bool = true
	for member_index: int in member_indices:
		if not selected_layer_indices.has(member_index):
			group_is_selected = false
			break
	var group_is_active: bool = member_indices.has(canvas_view.active_layer_index)
	group_button.add_theme_stylebox_override("normal", _timeline_layer_style(group_is_active, group_is_selected, false, true))
	group_button.add_theme_stylebox_override("hover", _timeline_layer_style(group_is_active, group_is_selected, true, true))
	group_button.add_theme_color_override("font_color", Color.WHITE if group_is_active or group_is_selected else Color("cbd4e0"))
	group_button.group_selection_requested.connect(_on_group_selection_requested)
	group_button.layers_dropped.connect(_on_layers_dropped)
	timeline_group_buttons[layer_group.group_title] = group_button
	group_cell.add_child(group_button)
	timeline_grid.add_child(group_cell)

	for frame_index: int in range(active_animation.frame_count):
		var group_frame_cell: PanelContainer = PanelContainer.new()
		group_frame_cell.custom_minimum_size = Vector2(44.0, 30.0)
		group_frame_cell.add_theme_stylebox_override("panel", _make_ui_style(Color("1c222b"), Color("303846"), 1, 2, 2))
		timeline_grid.add_child(group_frame_cell)

func _add_layer_timeline_row(layer_index: int, active_animation: GatorSpriteAnimation) -> void:
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[layer_index]
	var is_active_layer: bool = layer_index == canvas_view.active_layer_index
	var is_selected_layer: bool = selected_layer_indices.has(layer_index)
	var layer_cell: HBoxContainer = HBoxContainer.new()
	layer_cell.custom_minimum_size = Vector2(184.0, 32.0)
	layer_cell.add_theme_constant_override("separation", 2)
	var visibility_button: Button = Button.new()
	visibility_button.icon = _load_icon("eye" if sprite_layer.visible else "eye_off")
	visibility_button.toggle_mode = true
	visibility_button.button_pressed = sprite_layer.visible
	visibility_button.custom_minimum_size = Vector2(28.0, 30.0)
	visibility_button.tooltip_text = "Show or hide %s" % sprite_layer.layer_title
	visibility_button.toggled.connect(_on_layer_visibility_toggled.bind(layer_index))
	layer_cell.add_child(visibility_button)
	var lock_button: Button = Button.new()
	lock_button.icon = _load_icon("lock" if sprite_layer.locked else "unlock")
	lock_button.toggle_mode = true
	lock_button.button_pressed = sprite_layer.locked
	lock_button.custom_minimum_size = Vector2(28.0, 30.0)
	lock_button.tooltip_text = "Lock or unlock %s" % sprite_layer.layer_title
	lock_button.toggled.connect(_on_layer_lock_toggled.bind(layer_index))
	layer_cell.add_child(lock_button)
	var layer_button: GatorTimelineLayerButton = TimelineLayerButton.new() as GatorTimelineLayerButton
	layer_button.layer_index = layer_index
	layer_button.selected_layer_indices = _copy_selected_layer_indices()
	layer_button.target_group_title = sprite_layer.group_title
	var layer_prefix: String = "  ↳ " if not sprite_layer.group_title.is_empty() else ""
	if sprite_layer.is_reference_layer():
		layer_prefix += "◇ "
	layer_button.text = layer_prefix + sprite_layer.layer_title
	layer_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	layer_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_button.mouse_default_cursor_shape = Control.CURSOR_DRAG
	layer_button.tooltip_text = "%s. Ctrl-click toggles selection, Shift-click selects a range, and drag reorders or moves selected layers between groups." % sprite_layer.layer_title
	layer_button.add_theme_stylebox_override("normal", _timeline_layer_style(is_active_layer, is_selected_layer, false, false))
	layer_button.add_theme_stylebox_override("hover", _timeline_layer_style(is_active_layer, is_selected_layer, true, false))
	layer_button.add_theme_color_override("font_color", Color.WHITE if is_active_layer or is_selected_layer else Color("c1c8d2"))
	layer_button.selection_requested.connect(_on_layer_selection_requested)
	layer_button.layers_dropped.connect(_on_layers_dropped)
	timeline_layer_buttons[layer_index] = layer_button
	layer_cell.add_child(layer_button)
	timeline_grid.add_child(layer_cell)

	for cel_frame_index: int in range(active_animation.frame_count):
		if sprite_layer.is_reference_layer():
			# Reference layers exist once for the whole document, not once per frame.
			# Render fixed, non-interactive timeline cells like a group row so later
			# layer rows cannot visually flow into this row.
			var reference_frame_cell: PanelContainer = PanelContainer.new()
			reference_frame_cell.custom_minimum_size = Vector2(44.0, 32.0)
			reference_frame_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reference_frame_cell.tooltip_text = "%s is a document-wide reference image and has no editable frame cels." % sprite_layer.layer_title
			reference_frame_cell.add_theme_stylebox_override("panel", _make_ui_style(Color("1c222b"), Color("303846"), 1, 2, 2))
			timeline_grid.add_child(reference_frame_cell)
			continue

		var cel_button: Button = Button.new()
		var is_active_cel: bool = is_active_layer and cel_frame_index == canvas_view.active_frame_index
		var linked_frames: Array[int] = sprite_document.get_linked_frame_indices(layer_index, cel_frame_index)
		cel_button.text = "◆" if linked_frames.size() > 1 else "■"
		cel_button.custom_minimum_size = Vector2(44.0, 32.0)
		if linked_frames.size() > 1:
			var linked_labels: PackedStringArray = PackedStringArray()
			for linked_frame: int in linked_frames:
				linked_labels.append(str(linked_frame + 1))
			cel_button.tooltip_text = "%s, linked frames %s" % [sprite_layer.layer_title, ", ".join(linked_labels)]
		else:
			cel_button.tooltip_text = "%s, frame %d" % [sprite_layer.layer_title, cel_frame_index + 1]
		cel_button.add_theme_stylebox_override("normal", _timeline_cell_style(is_active_cel, false))
		cel_button.add_theme_stylebox_override("hover", _timeline_cell_style(is_active_cel, true))
		cel_button.add_theme_color_override("font_color", Color("9ed0ff") if is_active_cel else Color("69788c"))
		cel_button.pressed.connect(_on_timeline_cel_selected.bind(layer_index, cel_frame_index))
		timeline_cel_buttons[Vector2i(layer_index, cel_frame_index)] = cel_button
		timeline_grid.add_child(cel_button)

func _build_compact_tag_lanes(active_animation: GatorSpriteAnimation) -> void:
	for tag_lane_index: int in range(2):
		var tag_lane_header: Label = Label.new()
		tag_lane_header.text = "TAGS" if tag_lane_index == 0 else ""
		tag_lane_header.custom_minimum_size = Vector2(184.0, 22.0)
		tag_lane_header.add_theme_color_override("font_color", Color("8894a6"))
		tag_lane_header.add_theme_font_size_override("font_size", 10)
		timeline_grid.add_child(tag_lane_header)
		for tag_frame_index: int in range(active_animation.frame_count):
			timeline_grid.add_child(_create_tag_lane_cell(tag_lane_index, tag_frame_index))

func _create_tag_lane_cell(tag_lane_index: int, frame_index: int) -> Control:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var covering_tag_indices: Array[int] = []
	for tag_index: int in range(sprite_document.tags.size()):
		if tag_index % 2 != tag_lane_index:
			continue
		var sprite_tag: GatorSpriteTag = sprite_document.tags[tag_index]
		if sprite_tag.contains_frame(frame_index, active_animation.frame_count):
			covering_tag_indices.append(tag_index)

	if covering_tag_indices.is_empty():
		var empty_tag_cell: Control = Control.new()
		empty_tag_cell.custom_minimum_size = Vector2(44.0, 22.0)
		return empty_tag_cell

	if covering_tag_indices.size() == 1:
		var tag_index: int = covering_tag_indices[0]
		var sprite_tag: GatorSpriteTag = sprite_document.tags[tag_index]
		var tag_frames: Array[int] = sprite_tag.get_frame_indices(active_animation.frame_count)
		var tag_frame_button: Button = Button.new()
		tag_frame_button.custom_minimum_size = Vector2(44.0, 22.0)
		tag_frame_button.clip_text = true
		tag_frame_button.text = sprite_tag.tag_title if not tag_frames.is_empty() and frame_index == tag_frames[0] else ""
		tag_frame_button.tooltip_text = "%s: %s. Click to edit." % [sprite_tag.tag_title, _get_tag_frame_text(sprite_tag, active_animation.frame_count)]
		_apply_tag_cell_style(tag_frame_button, sprite_tag.color, tag_index == selected_tag_index)
		tag_frame_button.pressed.connect(_on_timeline_tag_selected.bind(tag_index))
		return tag_frame_button

	var overlapping_tag_menu: MenuButton = MenuButton.new()
	overlapping_tag_menu.custom_minimum_size = Vector2(44.0, 22.0)
	overlapping_tag_menu.clip_text = true
	overlapping_tag_menu.text = "%d tags" % covering_tag_indices.size()
	var tooltip_lines: PackedStringArray = PackedStringArray()
	var overlap_popup: PopupMenu = overlapping_tag_menu.get_popup()
	for overlapping_tag_index: int in covering_tag_indices:
		var overlapping_tag: GatorSpriteTag = sprite_document.tags[overlapping_tag_index]
		var overlapping_frame_text: String = _get_tag_frame_text(overlapping_tag, active_animation.frame_count)
		var popup_item_index: int = overlap_popup.item_count
		overlap_popup.add_item("%s  (%s)" % [overlapping_tag.tag_title, overlapping_frame_text])
		overlap_popup.set_item_metadata(popup_item_index, overlapping_tag_index)
		tooltip_lines.append("%s: %s" % [overlapping_tag.tag_title, overlapping_frame_text])
	overlap_popup.index_pressed.connect(_on_tag_lane_menu_selected.bind(overlap_popup))
	overlapping_tag_menu.tooltip_text = "\n".join(tooltip_lines)
	var first_overlapping_tag: GatorSpriteTag = sprite_document.tags[covering_tag_indices[0]]
	_apply_tag_cell_style(overlapping_tag_menu, first_overlapping_tag.color, covering_tag_indices.has(selected_tag_index))
	return overlapping_tag_menu

func _get_tag_frame_text(sprite_tag: GatorSpriteTag, frame_count: int) -> String:
	var tag_frames: Array[int] = sprite_tag.get_frame_indices(frame_count)
	if tag_frames.is_empty():
		return "no frames"
	var is_contiguous: bool = true
	for frame_offset: int in range(1, tag_frames.size()):
		if tag_frames[frame_offset] != tag_frames[frame_offset - 1] + 1:
			is_contiguous = false
			break
	if is_contiguous and tag_frames.size() > 1:
		return "frames %d-%d" % [tag_frames[0] + 1, tag_frames[tag_frames.size() - 1] + 1]
	var frame_labels: PackedStringArray = PackedStringArray()
	for tag_frame_index: int in tag_frames:
		frame_labels.append(str(tag_frame_index + 1))
	return "frame %s" % frame_labels[0] if frame_labels.size() == 1 else "frames %s" % ", ".join(frame_labels)

func _on_tag_lane_menu_selected(popup_item_index: int, overlap_popup: PopupMenu) -> void:
	var selected_metadata: Variant = overlap_popup.get_item_metadata(popup_item_index)
	if selected_metadata is int:
		_on_timeline_tag_selected(int(selected_metadata))

func _refresh_timeline_active_styles() -> void:
	for frame_index: int in range(timeline_frame_buttons.size()):
		var frame_button: Button = timeline_frame_buttons[frame_index]
		var frame_is_active: bool = frame_index == canvas_view.active_frame_index
		var frame_is_selected: bool = selected_frame_indices.has(frame_index)
		frame_button.add_theme_stylebox_override("normal", _timeline_frame_style(frame_is_active, frame_is_selected, false))
		frame_button.add_theme_stylebox_override("hover", _timeline_frame_style(frame_is_active, frame_is_selected, true))
		frame_button.add_theme_color_override("font_color", Color.WHITE if frame_is_active or frame_is_selected else Color("aeb7c5"))
		if frame_button is GatorTimelineFrameButton:
			var timeline_frame_button: GatorTimelineFrameButton = frame_button as GatorTimelineFrameButton
			timeline_frame_button.selected_frame_indices = _copy_selected_frame_indices()
	for layer_index_variant: Variant in timeline_layer_buttons.keys():
		var layer_index: int = int(layer_index_variant)
		var layer_button: Button = timeline_layer_buttons[layer_index]
		var layer_is_active: bool = layer_index == canvas_view.active_layer_index
		var layer_is_selected: bool = selected_layer_indices.has(layer_index)
		layer_button.add_theme_stylebox_override("normal", _timeline_layer_style(layer_is_active, layer_is_selected, false, false))
		layer_button.add_theme_stylebox_override("hover", _timeline_layer_style(layer_is_active, layer_is_selected, true, false))
		layer_button.add_theme_color_override("font_color", Color.WHITE if layer_is_active or layer_is_selected else Color("c1c8d2"))
		if layer_button is GatorTimelineLayerButton:
			var timeline_layer_button: GatorTimelineLayerButton = layer_button as GatorTimelineLayerButton
			timeline_layer_button.selected_layer_indices = _copy_selected_layer_indices()
	for group_title_variant: Variant in timeline_group_buttons.keys():
		var group_title: String = String(group_title_variant)
		var group_button: Button = timeline_group_buttons[group_title]
		var member_indices: Array[int] = sprite_document.get_group_layer_indices(group_title)
		var group_is_active: bool = member_indices.has(canvas_view.active_layer_index)
		var group_is_selected: bool = not member_indices.is_empty()
		for member_index: int in member_indices:
			if not selected_layer_indices.has(member_index):
				group_is_selected = false
				break
		group_button.add_theme_stylebox_override("normal", _timeline_layer_style(group_is_active, group_is_selected, false, true))
		group_button.add_theme_stylebox_override("hover", _timeline_layer_style(group_is_active, group_is_selected, true, true))
		group_button.add_theme_color_override("font_color", Color.WHITE if group_is_active or group_is_selected else Color("cbd4e0"))
	for cel_position: Vector2i in timeline_cel_buttons:
		var cel_button: Button = timeline_cel_buttons[cel_position]
		var cel_is_active: bool = cel_position.x == canvas_view.active_layer_index and cel_position.y == canvas_view.active_frame_index
		cel_button.add_theme_stylebox_override("normal", _timeline_cell_style(cel_is_active, false))
		cel_button.add_theme_stylebox_override("hover", _timeline_cell_style(cel_is_active, true))
		cel_button.add_theme_color_override("font_color", Color("9ed0ff") if cel_is_active else Color("69788c"))

func _timeline_frame_style(is_active: bool, is_selected: bool, is_hovered: bool) -> StyleBoxFlat:
	var background_color: Color = Color("1769aa") if is_active else (Color("244f73") if is_selected else Color("22262e"))
	if is_hovered:
		background_color = Color("237fc4") if is_active else (Color("306b98") if is_selected else Color("303642"))
	var border_color: Color = Color("d7edff") if is_active else (Color("74b9ea") if is_selected else Color("363c48"))
	return _make_ui_style(background_color, border_color, 2 if is_active or is_selected else 1, 2, 3)

func _timeline_layer_style(is_active: bool, is_selected: bool, is_hovered: bool, is_group: bool) -> StyleBoxFlat:
	var base_color: Color = Color("293543") if is_group else Color("22262e")
	var selected_color: Color = Color("315a78") if is_group else Color("244f73")
	var active_color: Color = Color("1769aa")
	var background_color: Color = active_color if is_active else (selected_color if is_selected else base_color)
	if is_hovered:
		background_color = Color("237fc4") if is_active else (Color("3c7196") if is_selected else background_color.lightened(0.08))
	var border_color: Color = Color("d7edff") if is_active else (Color("74b9ea") if is_selected else Color("3c4655"))
	return _make_ui_style(background_color, border_color, 2 if is_active or is_selected else 1, 2, 3)

func _timeline_cell_style(is_active: bool, is_hovered: bool) -> StyleBoxFlat:
	var background_color: Color = Color("1769aa") if is_active else Color("22262e")
	if is_hovered:
		background_color = Color("237fc4") if is_active else Color("303642")
	var border_color: Color = Color("b8dcff") if is_active else Color("363c48")
	return _make_ui_style(background_color, border_color, 2 if is_active else 1, 2, 3)

func _apply_tag_cell_style(tag_button: Button, tag_color: Color, is_selected: bool) -> void:
	var normal_style: StyleBoxFlat = _make_ui_style(tag_color.darkened(0.48), Color.WHITE if is_selected else tag_color.darkened(0.1), 2 if is_selected else 1, 2, 2)
	tag_button.add_theme_stylebox_override("normal", normal_style)
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = tag_color.darkened(0.25)
	tag_button.add_theme_stylebox_override("hover", hover_style)
	tag_button.add_theme_color_override("font_color", Color.WHITE)

func _on_frame_selection_requested(frame_index: int, additive_selection: bool, range_selection: bool) -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if frame_index < 0 or frame_index >= active_animation.frame_count:
		return

	if range_selection:
		var range_start: int = mini(frame_selection_anchor, frame_index)
		var range_end: int = maxi(frame_selection_anchor, frame_index)
		selected_frame_indices.clear()
		for selected_frame_index: int in range(range_start, range_end + 1):
			selected_frame_indices.append(selected_frame_index)
	elif additive_selection:
		if selected_frame_indices.has(frame_index):
			if selected_frame_indices.size() > 1:
				selected_frame_indices.erase(frame_index)
		else:
			selected_frame_indices.append(frame_index)
		selected_frame_indices.sort()
		frame_selection_anchor = frame_index
	elif not selected_frame_indices.has(frame_index) or selected_frame_indices.size() == 1:
		_reset_frame_selection(frame_index)
	else:
		frame_selection_anchor = frame_index

	_select_active_frame_without_rebuild(frame_index)

func _select_active_frame_without_rebuild(frame_index: int) -> void:
	canvas_view.clear_selection()
	canvas_view.active_frame_index = frame_index
	preview_frame_index = frame_index
	_refresh_timeline_active_styles()
	canvas_view.refresh_canvas()
	_refresh_preview()
	_update_selection_status()

func _on_frames_dropped(source_frame_indices: PackedInt32Array, insertion_index: int) -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var sanitized_source_indices: Array[int] = []
	for source_frame_index: int in source_frame_indices:
		if source_frame_index >= 0 and source_frame_index < active_animation.frame_count and not sanitized_source_indices.has(source_frame_index):
			sanitized_source_indices.append(source_frame_index)
	sanitized_source_indices.sort()
	if sanitized_source_indices.is_empty():
		return

	var previous_active_frame_index: int = canvas_view.active_frame_index
	var new_frame_order: Array[int] = sprite_document.move_frames(sanitized_source_indices, insertion_index)
	if new_frame_order.is_empty():
		status_label.text = "The selected frames are already in that position."
		return

	var moved_selection: Array[int] = []
	for previous_selected_frame_index: int in sanitized_source_indices:
		var moved_frame_index: int = new_frame_order.find(previous_selected_frame_index)
		if moved_frame_index >= 0:
			moved_selection.append(moved_frame_index)
	moved_selection.sort()
	selected_frame_indices = moved_selection
	if selected_frame_indices.is_empty():
		_reset_frame_selection(0)
	else:
		frame_selection_anchor = selected_frame_indices[0]

	var remapped_active_frame_index: int = new_frame_order.find(previous_active_frame_index)
	canvas_view.active_frame_index = remapped_active_frame_index if remapped_active_frame_index >= 0 else selected_frame_indices[0]
	preview_frame_index = canvas_view.active_frame_index
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Moved frame %d." % (canvas_view.active_frame_index + 1) if selected_frame_indices.size() == 1 else "Moved %d selected frames." % selected_frame_indices.size()

func _on_layer_selection_requested(layer_index: int, additive_selection: bool, range_selection: bool) -> void:
	if layer_index < 0 or layer_index >= sprite_document.layers.size():
		return
	if range_selection:
		var range_start: int = mini(layer_selection_anchor, layer_index)
		var range_end: int = maxi(layer_selection_anchor, layer_index)
		selected_layer_indices.clear()
		for selected_layer_index: int in range(range_start, range_end + 1):
			selected_layer_indices.append(selected_layer_index)
	elif additive_selection:
		if selected_layer_indices.has(layer_index):
			if selected_layer_indices.size() > 1:
				selected_layer_indices.erase(layer_index)
		else:
			selected_layer_indices.append(layer_index)
		selected_layer_indices.sort()
		layer_selection_anchor = layer_index
	elif not selected_layer_indices.has(layer_index) or selected_layer_indices.size() == 1:
		_reset_layer_selection(layer_index)
	else:
		layer_selection_anchor = layer_index
	canvas_view.clear_selection()
	canvas_view.active_layer_index = layer_index
	_refresh_timeline_active_styles()
	_refresh_layer_property_controls()
	canvas_view.refresh_canvas()
	_refresh_preview()
	_update_selection_status()

func _on_group_selection_requested(group_title: String) -> void:
	var member_indices: Array[int] = sprite_document.get_group_layer_indices(group_title)
	if member_indices.is_empty():
		return
	selected_layer_indices = member_indices.duplicate()
	layer_selection_anchor = member_indices[0]
	canvas_view.clear_selection()
	canvas_view.active_layer_index = member_indices[0]
	_refresh_timeline_active_styles()
	_refresh_layer_property_controls()
	canvas_view.refresh_canvas()
	_refresh_preview()
	_update_selection_status()

func _on_layers_dropped(source_layer_indices: PackedInt32Array, insertion_index: int, target_group_title: String, preserve_groups: bool, join_target_group: bool, drop_after_target: bool) -> void:
	var sanitized_source_indices: Array[int] = []
	for source_layer_index: int in source_layer_indices:
		if source_layer_index >= 0 and source_layer_index < sprite_document.layers.size() and not sanitized_source_indices.has(source_layer_index):
			sanitized_source_indices.append(source_layer_index)
	sanitized_source_indices.sort()
	if sanitized_source_indices.is_empty():
		return

	var moved_layers: Array[GatorSpriteLayer] = []
	for source_layer_index: int in sanitized_source_indices:
		moved_layers.append(sprite_document.layers[source_layer_index])
	var active_layer: GatorSpriteLayer = sprite_document.layers[canvas_view.active_layer_index]
	var resolved_insertion_index: int = insertion_index
	var group_changed: bool = false

	if join_target_group:
		# A group is entered only by dropping directly on its header.
		for moved_layer: GatorSpriteLayer in moved_layers:
			if moved_layer.group_title != target_group_title:
				group_changed = true
			moved_layer.group_title = target_group_title
	elif preserve_groups:
		# Whole-group drags retain membership. When dropped on a member of a
		# different group, place the complete moved group outside that group so
		# neither group can become interleaved.
		var moved_group_titles: Array[String] = []
		for moved_layer: GatorSpriteLayer in moved_layers:
			if not moved_layer.group_title.is_empty() and not moved_group_titles.has(moved_layer.group_title):
				moved_group_titles.append(moved_layer.group_title)
		if not target_group_title.is_empty() and not moved_group_titles.has(target_group_title):
			var preserved_target_members: Array[int] = sprite_document.get_group_layer_indices(target_group_title)
			if not preserved_target_members.is_empty():
				resolved_insertion_index = preserved_target_members[preserved_target_members.size() - 1] + 1 if drop_after_target else preserved_target_members[0]
	else:
		var already_in_target_group: bool = not target_group_title.is_empty()
		for moved_layer: GatorSpriteLayer in moved_layers:
			if moved_layer.group_title != target_group_title:
				already_in_target_group = false
				break

		if already_in_target_group:
			# Reordering members inside their current group is allowed.
			pass
		else:
			# Dropping on a layer row reorders beside it; it never silently joins
			# that layer's group. Existing membership is removed when moving away.
			for moved_layer: GatorSpriteLayer in moved_layers:
				if not moved_layer.group_title.is_empty():
					group_changed = true
				moved_layer.group_title = ""

			if not target_group_title.is_empty():
				var target_member_indices: Array[int] = sprite_document.get_group_layer_indices(target_group_title)
				if not target_member_indices.is_empty():
					# Keep groups contiguous. A drop on any member places the moved
					# layers before or after the complete group, based on drop half.
					resolved_insertion_index = target_member_indices[target_member_indices.size() - 1] + 1 if drop_after_target else target_member_indices[0]

	var new_layer_order: Array[int] = sprite_document.move_layers(sanitized_source_indices, resolved_insertion_index)
	if new_layer_order.is_empty() and not group_changed:
		status_label.text = "The selected layers are already in that position."
		return

	sprite_document.remove_empty_layer_groups()
	selected_layer_indices.clear()
	for moved_layer: GatorSpriteLayer in moved_layers:
		var moved_layer_index: int = sprite_document.layers.find(moved_layer)
		if moved_layer_index >= 0:
			selected_layer_indices.append(moved_layer_index)
	selected_layer_indices.sort()
	canvas_view.active_layer_index = sprite_document.layers.find(active_layer)
	if canvas_view.active_layer_index < 0:
		canvas_view.active_layer_index = selected_layer_indices[0]
	layer_selection_anchor = selected_layer_indices[0]
	_mark_document_dirty()
	_refresh_interface()

	var group_change_text: String = ""
	if join_target_group:
		group_change_text = " into %s" % target_group_title
	elif group_changed:
		group_change_text = " out of its group" if selected_layer_indices.size() == 1 else " out of their groups"
	status_label.text = "Moved %d selected layer%s%s." % [selected_layer_indices.size(), "" if selected_layer_indices.size() == 1 else "s", group_change_text]

func _on_group_collapsed_toggled(group_title: String) -> void:
	var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(group_title)
	if layer_group == null:
		return
	layer_group.collapsed = not layer_group.collapsed
	_mark_document_dirty()
	_refresh_interface()

func _on_group_visibility_toggled(is_visible: bool, group_title: String) -> void:
	var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(group_title)
	if layer_group == null:
		return
	layer_group.visible = is_visible
	_mark_document_dirty()
	_refresh_interface()

func _on_group_lock_toggled(is_locked: bool, group_title: String) -> void:
	var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(group_title)
	if layer_group == null:
		return
	layer_group.locked = is_locked
	_mark_document_dirty()
	_refresh_interface()

func _on_layer_lock_toggled(is_locked: bool, layer_index: int) -> void:
	if layer_index < 0 or layer_index >= sprite_document.layers.size():
		return
	sprite_document.layers[layer_index].locked = is_locked
	_mark_document_dirty()
	_refresh_interface()

func _on_timeline_cel_selected(layer_index: int, frame_index: int) -> void:
	canvas_view.clear_selection()
	canvas_view.active_layer_index = layer_index
	_reset_layer_selection(layer_index)
	canvas_view.active_frame_index = frame_index
	preview_frame_index = frame_index
	_reset_frame_selection(frame_index)
	_refresh_interface()

func _on_add_tag_pressed() -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	edited_tag_index = -1
	edited_tag_original_frames.clear()
	tag_name_input.text = ""
	tag_from_input.max_value = active_animation.frame_count
	tag_to_input.max_value = active_animation.frame_count
	tag_from_input.value = canvas_view.active_frame_index + 1
	tag_to_input.value = canvas_view.active_frame_index + 1
	tag_color_picker.color = Color("3fb950")
	_show_tag_dialog()

func _on_timeline_tag_selected(tag_index: int) -> void:
	if tag_index < 0 or tag_index >= sprite_document.tags.size():
		return
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var selected_tag: GatorSpriteTag = sprite_document.tags[tag_index]
	var selected_tag_frames: Array[int] = selected_tag.get_frame_indices(active_animation.frame_count)
	edited_tag_original_frames = selected_tag_frames.duplicate()
	selected_tag_index = tag_index
	edited_tag_index = tag_index
	tag_name_input.text = selected_tag.tag_title
	tag_from_input.max_value = active_animation.frame_count
	tag_to_input.max_value = active_animation.frame_count
	tag_from_input.value = selected_tag_frames[0] + 1 if not selected_tag_frames.is_empty() else 1
	tag_to_input.value = selected_tag_frames[selected_tag_frames.size() - 1] + 1 if not selected_tag_frames.is_empty() else 1
	tag_color_picker.color = selected_tag.color
	_show_tag_dialog()
	_refresh_interface()

func _show_tag_dialog() -> void:
	tag_dialog.reset_size()
	tag_dialog.popup_centered(Vector2i(440, 300))

func _on_delete_tag_pressed() -> void:
	if selected_tag_index < 0 or selected_tag_index >= sprite_document.tags.size():
		status_label.text = "Select a colored tag range before deleting it."
		return
	var deleted_tag: GatorSpriteTag = sprite_document.tags[selected_tag_index]
	sprite_document.tags.remove_at(selected_tag_index)
	status_label.text = "Deleted tag %s." % deleted_tag.tag_title
	selected_tag_index = -1
	edited_tag_index = -1
	edited_tag_original_frames.clear()
	_mark_document_dirty()
	_refresh_interface()

func _on_layer_visibility_toggled(is_visible: bool, layer_index: int) -> void:
	sprite_document.layers[layer_index].visible = is_visible
	_mark_document_dirty()
	_refresh_interface()

func _on_canvas_viewport_resized() -> void:
	if auto_fit_canvas:
		call_deferred("_fit_canvas_to_viewport")

func _fit_canvas_to_viewport() -> void:
	if sprite_document == null or canvas_scroll == null or canvas_scroll.size.x <= 0.0 or canvas_scroll.size.y <= 0.0:
		return
	var usable_size: Vector2 = canvas_scroll.size - Vector2(24.0, 24.0)
	var horizontal_zoom: float = floorf(usable_size.x / float(sprite_document.canvas_size.x))
	var vertical_zoom: float = floorf(usable_size.y / float(sprite_document.canvas_size.y))
	var fitted_zoom: float = clampf(minf(horizontal_zoom, vertical_zoom), 2.0, 48.0)
	canvas_view.zoom_level = fitted_zoom
	canvas_view.refresh_canvas()
	_update_canvas_centering()
	_update_zoom_label()

func _update_canvas_centering() -> void:
	if canvas_center == null or canvas_scroll == null or canvas_view == null:
		return
	var canvas_size: Vector2 = canvas_view.custom_minimum_size
	canvas_center.custom_minimum_size = Vector2(maxf(canvas_scroll.size.x, canvas_size.x), maxf(canvas_scroll.size.y, canvas_size.y))

func _on_new_pressed() -> void:
	_request_protected_action(Callable(new_sprite_dialog, "popup_centered"))

func _on_new_size_selected(pixel_size: int) -> void:
	new_sprite_dialog.hide()
	create_new_document(Vector2i(pixel_size, pixel_size))

func _on_new_rectangular_size_selected(canvas_size: Vector2i) -> void:
	new_sprite_dialog.hide()
	create_new_document(canvas_size)

func _on_save_pressed() -> void:
	if current_document_path.is_empty():
		save_dialog.title = "Save Gator Sprite Studio Document"
		save_dialog.current_file = "%s.tres" % sprite_document.document_title.to_snake_case()
		save_dialog.popup_centered_ratio(0.65)
		return
	_save_document_to_path(current_document_path)

func _on_save_as_pressed() -> void:
	continue_pending_action_after_save = false
	save_dialog.title = "Save Gator Sprite Studio Document As"
	if current_document_path.is_empty():
		save_dialog.current_file = "%s.tres" % sprite_document.document_title.to_snake_case()
	else:
		save_dialog.current_dir = current_document_path.get_base_dir()
		save_dialog.current_file = current_document_path.get_file()
	save_dialog.popup_centered_ratio(0.65)

func _on_load_pressed() -> void:
	_request_protected_action(Callable(load_dialog, "popup_centered_ratio").bind(0.65))

func _on_save_path_selected(selected_path: String) -> void:
	var save_path: String = selected_path if selected_path.to_lower().ends_with(".tres") else "%s.tres" % selected_path
	if FileAccess.file_exists(save_path):
		pending_overwrite_save_path = save_path
		overwrite_save_dialog.dialog_text = "A document named '%s' already exists. Replace it?" % save_path.get_file()
		overwrite_save_dialog.popup_centered(Vector2i(460, 170))
		return
	_complete_selected_save(save_path)

func _complete_selected_save(save_path: String) -> void:
	var save_succeeded: bool = _save_document_to_path(save_path)
	if save_succeeded and continue_pending_action_after_save:
		_execute_pending_protected_action()
	elif not save_succeeded and continue_pending_action_after_save:
		_on_unsaved_cancelled()

func _save_document_to_path(save_path: String) -> bool:
	var previous_title: String = sprite_document.document_title
	sprite_document.document_title = save_path.get_file().get_basename()
	var save_error: Error = ResourceSaver.save(sprite_document, save_path)
	if save_error == OK:
		current_document_path = save_path
		_set_document_dirty(false)
		_clear_recovery_data()
		_update_document_label()
		status_label.text = "Saved %s" % save_path.get_file()
		return true
	sprite_document.document_title = previous_title
	_update_document_label()
	status_label.text = "Could not save source document: %d" % save_error
	return false

func _on_load_path_selected(selected_path: String) -> void:
	var file_extension: String = selected_path.get_extension().to_lower()
	if file_extension == "tres":
		_load_gss_document(selected_path)
		return
	if file_extension in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]:
		_load_image_as_document(selected_path)
		return
	status_label.text = "Unsupported file type: .%s" % file_extension

func _load_gss_document(selected_path: String) -> void:
	var resource_path: String = selected_path
	if not resource_path.begins_with("res://") and not resource_path.begins_with("user://"):
		resource_path = ProjectSettings.localize_path(selected_path)
	if not resource_path.begins_with("res://") and not resource_path.begins_with("user://"):
		status_label.text = "GSS documents must be inside the current Godot project."
		return
	var loaded_resource: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var loaded_document: GatorSpriteDocument = loaded_resource as GatorSpriteDocument
	if loaded_document == null:
		status_label.text = "That file is not a Gator Sprite Studio document."
		return
	_clear_recovery_data()
	sprite_document = loaded_document
	current_document_path = resource_path
	canvas_view.set_document(sprite_document)
	_reset_frame_selection(0)
	_reset_layer_selection(0)
	_notify_extensions_document_ready()
	preview_frame_index = 0
	_set_preview_playing(false)
	_set_document_dirty(false)
	auto_fit_canvas = true
	_refresh_interface()
	call_deferred("_fit_canvas_to_viewport")
	status_label.text = "Loaded %s" % resource_path.get_file()

func _load_image_as_document(selected_path: String) -> void:
	var image_path: String = selected_path
	if selected_path.begins_with("res://") or selected_path.begins_with("user://"):
		image_path = ProjectSettings.globalize_path(selected_path)
	var imported_image: Image = Image.new()
	var load_error: Error = imported_image.load(image_path)
	if load_error != OK or imported_image.is_empty():
		status_label.text = "Could not load image: %d" % load_error
		return
	if imported_image.get_format() != Image.FORMAT_RGBA8:
		imported_image.convert(Image.FORMAT_RGBA8)
	var original_size: Vector2i = imported_image.get_size()
	var imported_size: Vector2i = _fit_size_within_limit(original_size, MAX_CANVAS_DIMENSION)
	if imported_size != original_size:
		imported_image.resize(imported_size.x, imported_size.y, Image.INTERPOLATE_LANCZOS)
	var imported_document: GatorSpriteDocument = GatorSpriteDocument.new()
	imported_document.setup_new_sprite(imported_image.get_size())
	imported_document.document_title = selected_path.get_file().get_basename()
	var imported_layer: GatorSpriteLayer = imported_document.layers[0]
	imported_layer.layer_title = "Image"
	imported_layer.ensure_cel(0, imported_document.canvas_size).set_image(imported_image)
	_apply_extension_document_replacement(imported_document, "")
	if imported_size != original_size:
		status_label.text = "Imported %s and resized it from %d × %d to %d × %d. Save As to create a GSS document." % [selected_path.get_file(), original_size.x, original_size.y, imported_size.x, imported_size.y]
	else:
		status_label.text = "Imported %s. Save As to create a GSS document." % selected_path.get_file()

func _fit_size_within_limit(source_size: Vector2i, maximum_dimension: int) -> Vector2i:
	if source_size.x <= maximum_dimension and source_size.y <= maximum_dimension:
		return source_size
	if source_size.x >= source_size.y:
		return Vector2i(maximum_dimension, maxi(1, roundi(float(source_size.y) * float(maximum_dimension) / float(source_size.x))))
	return Vector2i(maxi(1, roundi(float(source_size.x) * float(maximum_dimension) / float(source_size.y))), maximum_dimension)

func _on_export_pressed() -> void:
	_set_export_feedback("")
	if export_name_input.text.strip_edges().is_empty():
		export_name_input.text = "sprite"
	export_dialog.popup_centered(Vector2i(420, 360))

func _on_metadata_pressed() -> void:
	slice_width_input.value = sprite_document.canvas_size.x
	slice_height_input.value = sprite_document.canvas_size.y
	metadata_dialog.popup_centered(Vector2i(520, 420))

func _on_shortcuts_pressed() -> void:
	shortcut_capture_action = ""
	for action_name: String in shortcut_inputs.keys():
		var shortcut_input: Button = shortcut_inputs[action_name]
		shortcut_input.text = String(shortcut_bindings[action_name])
	shortcut_dialog.reset_size()
	shortcut_dialog.popup_centered(Vector2i(520, 520))

func _on_shortcuts_confirmed() -> void:
	for action_name: String in shortcut_inputs.keys():
		var shortcut_input: Button = shortcut_inputs[action_name]
		shortcut_bindings[action_name] = shortcut_input.text.strip_edges().to_upper()
	ProjectSettings.set_setting("gator_sprite_studio/shortcuts", shortcut_bindings)
	ProjectSettings.save()
	status_label.text = "Keyboard shortcuts saved for this project."

func _on_aseprite_shortcuts_pressed() -> void:
	shortcut_bindings = ASEPRITE_SHORTCUT_BINDINGS.duplicate()
	shortcut_capture_action = ""
	for action_name: String in shortcut_inputs.keys():
		var shortcut_input: Button = shortcut_inputs[action_name]
		shortcut_input.text = String(shortcut_bindings[action_name])
	ProjectSettings.set_setting("gator_sprite_studio/shortcuts", shortcut_bindings)
	ProjectSettings.save()
	status_label.text = "Aseprite-style shortcuts restored."

func _on_shortcut_capture_requested(action_name: String) -> void:
	shortcut_capture_action = action_name
	for existing_action_name: String in shortcut_inputs.keys():
		var shortcut_button: Button = shortcut_inputs[existing_action_name]
		shortcut_button.text = "Press a key..." if existing_action_name == action_name else String(shortcut_bindings[existing_action_name])
	status_label.text = "Assigning %s: press a key or combination; Esc cancels." % action_name

func _on_shortcut_capture_gui_input(input_event: InputEvent, action_name: String) -> void:
	if action_name != shortcut_capture_action or not input_event is InputEventKey:
		return
	var key_event: InputEventKey = input_event
	if key_event.pressed and not key_event.echo and _capture_shortcut_key(key_event):
		get_viewport().set_input_as_handled()

func _on_load_extension_pressed() -> void:
	extension_load_dialog.popup_centered_ratio(0.65)

func _on_unload_extension_pressed() -> void:
	if loaded_extensions.is_empty():
		status_label.text = "No extensions are loaded."
		return
	extension_dialog_is_reload = false
	unload_extension_dialog.title = "Unload Extension"
	unload_extension_dialog.ok_button_text = "Unload"
	_populate_extension_action_menu()
	unload_extension_dialog.popup_centered(Vector2i(420, 180))

func _on_reload_extension_pressed() -> void:
	if loaded_extensions.is_empty():
		status_label.text = "No extensions are loaded."
		return
	extension_dialog_is_reload = true
	unload_extension_dialog.title = "Reload Extension"
	unload_extension_dialog.ok_button_text = "Reload"
	_populate_extension_action_menu()
	unload_extension_dialog.popup_centered(Vector2i(420, 180))

func _populate_extension_action_menu() -> void:
	unload_extension_menu.clear()
	for extension_path: String in loaded_extension_paths:
		unload_extension_menu.add_item(extension_path.get_file())

func _on_unload_extension_confirmed() -> void:
	var selected_extension_index: int = unload_extension_menu.selected
	if selected_extension_index < 0 or selected_extension_index >= loaded_extensions.size():
		return
	var unloaded_path: String = loaded_extension_paths[selected_extension_index]
	var was_official: bool = official_extension_paths.has(unloaded_path)
	_unload_extension_at(selected_extension_index)
	if extension_dialog_is_reload:
		_load_extension_from_path(unloaded_path, was_official)
	else:
		status_label.text = "Unloaded extension %s" % unloaded_path.get_file()

func _on_extension_path_selected(selected_path: String) -> void:
	_load_extension_from_path(selected_path)

func _load_extension_from_path(selected_path: String, is_official: bool = false) -> void:
	var extension_script: Script = ResourceLoader.load(selected_path) as Script
	if extension_script == null:
		status_label.text = "Could not load extension script."
		return
	var extension_instance: GatorSpriteExtension = extension_script.new() as GatorSpriteExtension
	if extension_instance == null:
		status_label.text = "Extension must inherit GatorSpriteExtension."
		return
	if loaded_extension_paths.has(selected_path):
		status_label.text = "%s is already loaded. Unload it before loading again." % selected_path.get_file()
		return
	var extension_manifest: Dictionary = extension_instance.get_extension_manifest()
	var extension_id: String = String(extension_manifest.get("id", "")).strip_edges()
	if extension_id.is_empty():
		extension_id = selected_path.get_file().get_basename()
	if extension_contexts.has(extension_id):
		status_label.text = "An extension with id '%s' is already loaded." % extension_id
		return
	var dependencies: Variant = extension_manifest.get("dependencies", PackedStringArray())
	if dependencies is Array or dependencies is PackedStringArray:
		for dependency_id: Variant in dependencies:
			if not extension_contexts.has(String(dependency_id)):
				status_label.text = "Extension '%s' requires '%s'." % [extension_id, String(dependency_id)]
				return
	var extension_context: GatorSpriteExtensionContext = GatorSpriteExtensionContext.new()
	extension_context.setup(extension_id, self)
	extension_instance.document_provider = Callable(self, "_get_extension_document")
	extension_instance.on_extension_loaded(extension_context)
	loaded_extensions.append(extension_instance)
	loaded_extension_paths.append(selected_path)
	if is_official:
		official_extension_paths[selected_path] = true
	extension_contexts[extension_id] = extension_context
	extension_instance.on_document_ready(sprite_document)
	status_label.text = "Loaded %s v%s" % [String(extension_manifest.get("name", selected_path.get_file())), String(extension_manifest.get("version", "1.0.0"))]

func _load_official_extensions() -> void:
	var loaded_count: int = 0
	for extension_file: String in OFFICIAL_EXTENSION_FILES:
		var extension_path: String = "%s/%s" % [OFFICIAL_EXTENSION_DIRECTORY, extension_file]
		if not FileAccess.file_exists(extension_path):
			push_warning("Gator Sprite Studio official extension is missing: %s" % extension_path)
			continue
		var previous_count: int = loaded_extensions.size()
		_load_extension_from_path(extension_path, true)
		if loaded_extensions.size() > previous_count:
			loaded_count += 1
	if loaded_count > 0:
		status_label.text = "Loaded %d official GSS extensions." % loaded_count

func _unload_extension_at(extension_index: int) -> void:
	if extension_index < 0 or extension_index >= loaded_extensions.size():
		return
	var unloaded_extension: GatorSpriteExtension = loaded_extensions[extension_index]
	var extension_id: String = ""
	for registered_id: String in extension_contexts.keys():
		if extension_contexts[registered_id] == unloaded_extension.context:
			extension_id = registered_id
			break
	unloaded_extension.on_unloaded()
	_cleanup_extension_ui(extension_id)
	loaded_extensions.remove_at(extension_index)
	var unloaded_path: String = loaded_extension_paths[extension_index]
	loaded_extension_paths.remove_at(extension_index)
	official_extension_paths.erase(unloaded_path)
	extension_contexts.erase(extension_id)

func _get_extension_document() -> GatorSpriteDocument:
	return sprite_document

func _extension_get_document() -> GatorSpriteDocument:
	return sprite_document

func _extension_get_active_frame_index() -> int:
	return canvas_view.active_frame_index

func _extension_get_active_layer_index() -> int:
	return canvas_view.active_layer_index

func _extension_set_active_cell(frame_index: int, layer_index: int) -> void:
	canvas_view.active_frame_index = clampi(frame_index, 0, sprite_document.get_active_animation().frame_count - 1)
	_reset_frame_selection(canvas_view.active_frame_index)
	canvas_view.active_layer_index = clampi(layer_index, 0, sprite_document.layers.size() - 1)
	_reset_layer_selection(canvas_view.active_layer_index)
	_refresh_interface()

func _extension_replace_document(imported_document: GatorSpriteDocument, source_path: String = "") -> bool:
	if imported_document == null or imported_document.layers.is_empty() or imported_document.get_active_animation().frame_count <= 0:
		status_label.text = "The extension supplied an invalid sprite document."
		return false
	if document_is_dirty:
		_request_protected_action(_apply_extension_document_replacement.bind(imported_document, source_path))
		status_label.text = "Choose Save, Discard, or Cancel before importing the new document."
		return false
	_apply_extension_document_replacement(imported_document, source_path)
	return true

func _apply_extension_document_replacement(imported_document: GatorSpriteDocument, source_path: String = "") -> void:
	_clear_recovery_data()
	sprite_document = imported_document
	canvas_view.set_document(sprite_document)
	canvas_view.active_frame_index = 0
	_reset_frame_selection(0)
	canvas_view.active_layer_index = 0
	_reset_layer_selection(0)
	canvas_view.clear_selection()
	current_document_path = source_path if source_path.to_lower().ends_with(".tres") else ""
	preview_frame_index = 0
	_set_preview_playing(false)
	_set_document_dirty(not source_path.to_lower().ends_with(".tres"))
	_notify_extensions_document_ready()
	_refresh_interface()
	auto_fit_canvas = true
	call_deferred("_fit_canvas_to_viewport")
	if current_document_path.is_empty():
		status_label.text = "Imported %s. Save it as a Gator Sprite Studio document." % sprite_document.document_title
	else:
		status_label.text = "Opened %s" % sprite_document.document_title

func _extension_register_command(extension_id: String, command_id: String, command_title: String, command_callback: Callable, show_in_toolbar: bool, shortcut_binding: String) -> bool:
	if command_id.strip_edges().is_empty() or command_title.strip_edges().is_empty() or not command_callback.is_valid():
		_extension_notify(extension_id, "Command registration needs an id, title, and valid callback.", true)
		return false
	var command_key: String = "%s/%s" % [extension_id, command_id]
	if extension_commands.has(command_key):
		_extension_notify(extension_id, "Command '%s' is already registered." % command_id, true)
		return false
	var command_data: Dictionary = {"extension_id": extension_id, "title": command_title, "callback": command_callback, "shortcut": shortcut_binding.to_upper(), "button": null}
	if show_in_toolbar:
		var command_button: Button = _make_button(command_title, _run_extension_command.bind(command_key))
		extension_toolbar.add_child(command_button)
		command_data["button"] = command_button
	extension_commands[command_key] = command_data
	_rebuild_extension_menu()
	return true

func _run_extension_command(command_key: String) -> void:
	if not extension_commands.has(command_key):
		return
	var command_callback: Callable = extension_commands[command_key]["callback"] as Callable
	if command_callback.is_valid():
		command_callback.call()

func _rebuild_extension_menu() -> void:
	var popup_menu: PopupMenu = extension_menu_button.get_popup()
	popup_menu.clear()
	extension_menu_command_keys.clear()
	var menu_id: int = 1
	for command_key: String in extension_commands.keys():
		var command_data: Dictionary = extension_commands[command_key]
		popup_menu.add_item(String(command_data["title"]), menu_id)
		extension_menu_command_keys[menu_id] = command_key
		menu_id += 1
	extension_menu_button.disabled = extension_commands.is_empty()

func _on_extension_menu_id_pressed(menu_id: int) -> void:
	if extension_menu_command_keys.has(menu_id):
		_run_extension_command(String(extension_menu_command_keys[menu_id]))

func _extension_register_panel(extension_id: String, panel_id: String, panel_title: String, panel_control: Control) -> bool:
	if panel_id.strip_edges().is_empty() or panel_title.strip_edges().is_empty() or panel_control == null:
		return false
	var panel_key: String = "%s/%s" % [extension_id, panel_id]
	if panel_control.has_meta("gator_extension_panel_key"):
		return false
	panel_control.set_meta("gator_extension_panel_key", panel_key)
	panel_control.name = panel_title
	extension_panels.add_child(panel_control)
	extension_panels.visible = true
	return true

func _extension_register_sidebar_panel(extension_id: String, panel_id: String, panel_title: String, panel_control: Control) -> bool:
	if panel_id.strip_edges().is_empty() or panel_title.strip_edges().is_empty() or panel_control == null or right_sidebar_tabs == null:
		return false
	var panel_key: String = "%s/%s" % [extension_id, panel_id]
	if panel_control.has_meta("gator_extension_sidebar_key"):
		return false
	panel_control.set_meta("gator_extension_sidebar_key", panel_key)
	panel_control.name = panel_title
	right_sidebar_tabs.add_child(panel_control)
	var extensions_tab_index: int = -1
	for child_index: int in range(right_sidebar_tabs.get_child_count()):
		var child_control: Control = right_sidebar_tabs.get_child(child_index) as Control
		if child_control != null and child_control.name == "Extensions":
			extensions_tab_index = child_index
			break
	if extensions_tab_index >= 0:
		right_sidebar_tabs.move_child(panel_control, extensions_tab_index)
	return true

func _extension_focus_sidebar_panel(extension_id: String, panel_id: String) -> void:
	if right_sidebar_tabs == null:
		return
	var panel_key: String = "%s/%s" % [extension_id, panel_id]
	for child_node: Node in right_sidebar_tabs.get_children():
		if String(child_node.get_meta("gator_extension_sidebar_key", "")) == panel_key:
			right_sidebar_tabs.current_tab = right_sidebar_tabs.get_tab_idx_from_control(child_node as Control)
			return

func _extension_get_selected_frame_indices() -> Array[int]:
	var result: Array[int] = []
	for frame_index: int in selected_frame_indices:
		result.append(frame_index)
	return result

func _extension_set_selected_frame_indices(frame_indices: Array[int], active_frame_index: int = -1) -> void:
	if sprite_document == null:
		return
	var frame_count: int = sprite_document.get_active_animation().frame_count
	var sanitized_frames: Array[int] = []
	for frame_index: int in frame_indices:
		if frame_index >= 0 and frame_index < frame_count and not sanitized_frames.has(frame_index):
			sanitized_frames.append(frame_index)
	sanitized_frames.sort()
	if sanitized_frames.is_empty():
		var fallback_frame_index: int = clampi(active_frame_index, 0, maxi(0, frame_count - 1)) if active_frame_index >= 0 else clampi(canvas_view.active_frame_index, 0, maxi(0, frame_count - 1))
		sanitized_frames.append(fallback_frame_index)
	selected_frame_indices = sanitized_frames
	frame_selection_anchor = selected_frame_indices[0]
	var requested_active_frame: int = active_frame_index if active_frame_index >= 0 else selected_frame_indices[0]
	canvas_view.active_frame_index = clampi(requested_active_frame, 0, maxi(0, frame_count - 1))
	preview_frame_index = canvas_view.active_frame_index
	_refresh_interface()

func _extension_set_selection_mask(selection_mask: Image) -> bool:
	if selection_mask == null or sprite_document == null or selection_mask.get_size() != sprite_document.canvas_size:
		return false
	canvas_view.selection_mask = selection_mask.duplicate()
	canvas_view._refresh_selection_bounds()
	canvas_view._refresh_selection_image()
	canvas_view.queue_redraw()
	_update_selection_status()
	return true

func _extension_get_custom_brush_source_image() -> Image:
	return canvas_view.get_custom_brush_source_image()

func _extension_get_document_brush_image() -> Image:
	return canvas_view.get_document_brush_image()

func _extension_set_custom_brush_image(brush_image: Image) -> Error:
	var brush_error: Error = canvas_view.set_custom_brush_from_image(brush_image)
	if brush_error == OK:
		_on_tool_pressed(GatorCanvas.ToolMode.CUSTOM_BRUSH)
		_sync_brush_size_controls()
	return brush_error

func _extension_set_custom_brush_scale(scale_percent: int) -> Error:
	var scale_error: Error = canvas_view.set_custom_brush_scale(scale_percent)
	if scale_error == OK:
		_sync_brush_size_controls()
	return scale_error

func _extension_get_custom_brush_scale() -> int:
	return canvas_view.get_custom_brush_scale_percent()

func _extension_set_custom_brush_spacing(spacing_percent: int) -> void:
	canvas_view.set_custom_brush_spacing(spacing_percent)

func _extension_get_custom_brush_spacing() -> int:
	return canvas_view.get_custom_brush_spacing()

func _extension_refresh_document(mark_dirty: bool = true) -> void:
	canvas_view.refresh_canvas()
	if mark_dirty:
		_mark_document_dirty()
	_refresh_interface()


func _extension_show_file_dialog(extension_id: String, dialog_title: String, filters: PackedStringArray, completion_callback: Callable, file_mode: FileDialog.FileMode) -> void:
	var helper_dialog: FileDialog = FileDialog.new()
	helper_dialog.title = dialog_title
	helper_dialog.file_mode = file_mode
	helper_dialog.access = FileDialog.ACCESS_FILESYSTEM
	helper_dialog.filters = filters
	add_child(helper_dialog)
	if not extension_dialogs.has(extension_id):
		extension_dialogs[extension_id] = []
	var dialogs_for_extension: Array = extension_dialogs[extension_id]
	dialogs_for_extension.append(helper_dialog)
	helper_dialog.file_selected.connect(func(selected_path: String) -> void: if completion_callback.is_valid(): completion_callback.call(selected_path); helper_dialog.queue_free())
	helper_dialog.dir_selected.connect(func(selected_directory: String) -> void: if completion_callback.is_valid(): completion_callback.call(selected_directory); helper_dialog.queue_free())
	helper_dialog.canceled.connect(func() -> void: helper_dialog.queue_free())
	helper_dialog.popup_centered_ratio(0.65)

func _extension_notify(_extension_id: String, message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_label.modulate = Color("ff9a7a") if is_error else Color.WHITE

func _extension_begin_undo_transaction() -> void:
	if not extension_transaction_open:
		canvas_view._push_undo_snapshot()
		extension_transaction_open = true

func _extension_commit_undo_transaction() -> void:
	if extension_transaction_open:
		extension_transaction_open = false
		canvas_view._finish_edit()
		_mark_document_dirty()

func _extension_undo() -> void:
	canvas_view.undo()

func _extension_redo() -> void:
	canvas_view.redo()

func _extension_has_selection() -> bool:
	return canvas_view.selection_image != null

func _extension_get_selection_bounds() -> Rect2i:
	return canvas_view.selection_rectangle

func _extension_get_selection_mask() -> Image:
	return null if canvas_view.selection_mask == null else canvas_view.selection_mask.duplicate()

func _extension_clear_selection() -> void:
	canvas_view.clear_selection()

func _extension_copy_selection() -> bool:
	return canvas_view.copy_selection()

func _extension_paste_selection() -> bool:
	return canvas_view.paste_selection()

func _extension_export_assets(destination_directory: String, export_name: String, export_frames: bool, export_sheet: bool, export_sprite_frames: bool) -> Error:
	return GatorSpriteExporter.export_document(sprite_document, destination_directory, export_frames, export_sheet, export_sprite_frames, 0, 0, export_name, false, null)

func _cleanup_extension_ui(extension_id: String) -> void:
	for command_key: String in extension_commands.keys().duplicate():
		if command_key.begins_with("%s/" % extension_id):
			var command_data: Dictionary = extension_commands[command_key]
			var command_button: Button = command_data["button"] as Button
			if is_instance_valid(command_button):
				command_button.queue_free()
			extension_commands.erase(command_key)
	for panel_control: Node in extension_panels.get_children():
		if String(panel_control.get_meta("gator_extension_panel_key", "")).begins_with("%s/" % extension_id):
			extension_panels.remove_child(panel_control)
			panel_control.queue_free()
	extension_panels.visible = not extension_panels.get_children().is_empty()
	if right_sidebar_tabs != null:
		for sidebar_panel: Node in right_sidebar_tabs.get_children():
			if String(sidebar_panel.get_meta("gator_extension_sidebar_key", "")).begins_with("%s/" % extension_id):
				right_sidebar_tabs.remove_child(sidebar_panel)
				sidebar_panel.queue_free()
	if extension_dialogs.has(extension_id):
		for helper_dialog_variant: Variant in extension_dialogs[extension_id]:
			if is_instance_valid(helper_dialog_variant):
				var helper_dialog: FileDialog = helper_dialog_variant as FileDialog
				helper_dialog.queue_free()
		extension_dialogs.erase(extension_id)
	_rebuild_extension_menu()

func _resolve_custom_brush_stamp(source_image: Image, source_anchor: Vector2i) -> Dictionary:
	var current_image: Image = source_image
	var current_anchor: Vector2i = source_anchor
	var use_source_colors: bool = false
	for sprite_extension: GatorSpriteExtension in loaded_extensions:
		var modified_stamp: Dictionary = sprite_extension.modify_custom_brush_stamp(current_image, current_anchor)
		var modified_image: Image = modified_stamp.get("image", null) as Image
		if modified_image != null and not modified_image.is_empty():
			current_image = modified_image
			var modified_anchor: Variant = modified_stamp.get("anchor", current_anchor)
			if modified_anchor is Vector2i:
				current_anchor = modified_anchor
		if modified_stamp.has("use_source_colors"):
			use_source_colors = bool(modified_stamp.get("use_source_colors", use_source_colors))
	return {"image": current_image, "anchor": current_anchor, "use_source_colors": use_source_colors}

func _on_canvas_before_edit(operation_name: String, frame_index: int, layer_index: int, pixel_position: Vector2i) -> GatorSpriteEditContext:
	var edit_context: GatorSpriteEditContext = GatorSpriteEditContext.new()
	edit_context.operation_name = operation_name
	edit_context.frame_index = frame_index
	edit_context.layer_index = layer_index
	edit_context.pixel_position = pixel_position
	for sprite_extension: GatorSpriteExtension in loaded_extensions:
		if not sprite_extension.before_edit(edit_context):
			edit_context.cancel()
		if edit_context.is_cancelled:
			return edit_context
	return edit_context

func _on_metadata_confirmed() -> void:
	var slice_name: String = slice_name_input.text.strip_edges()
	if slice_name.is_empty():
		status_label.text = "Enter a slice name before saving metadata."
		return
	var edited_slice: GatorSpriteSlice = _find_or_create_slice(slice_name)
	edited_slice.rectangle = Rect2i(Vector2i(int(slice_x_input.value), int(slice_y_input.value)), Vector2i(maxi(1, int(slice_width_input.value)), maxi(1, int(slice_height_input.value))))
	edited_slice.pivot = Vector2(slice_pivot_x_input.value, slice_pivot_y_input.value)
	_mark_document_dirty()
	status_label.text = "Metadata updated."

func _on_tag_dialog_confirmed() -> void:
	var tag_title: String = tag_name_input.text.strip_edges()
	if tag_title.is_empty():
		status_label.text = "Enter a tag name before saving."
		return
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var from_frame: int = clampi(int(tag_from_input.value) - 1, 0, active_animation.frame_count - 1)
	var to_frame: int = clampi(int(tag_to_input.value) - 1, 0, active_animation.frame_count - 1)
	var range_start: int = mini(from_frame, to_frame)
	var range_end: int = maxi(from_frame, to_frame)
	var edited_tag: GatorSpriteTag
	if edited_tag_index >= 0 and edited_tag_index < sprite_document.tags.size():
		edited_tag = sprite_document.tags[edited_tag_index]
	else:
		edited_tag = GatorSpriteTag.new()
		sprite_document.tags.append(edited_tag)
		edited_tag_index = sprite_document.tags.size() - 1
	edited_tag.tag_title = tag_title
	var original_range_is_unchanged: bool = not edited_tag_original_frames.is_empty() and range_start == edited_tag_original_frames[0] and range_end == edited_tag_original_frames[edited_tag_original_frames.size() - 1]
	if original_range_is_unchanged:
		edited_tag.set_frame_indices(edited_tag_original_frames, active_animation.frame_count)
	else:
		edited_tag.set_contiguous_range(range_start, range_end, active_animation.frame_count)
	edited_tag.color = tag_color_picker.color
	selected_tag_index = edited_tag_index
	edited_tag_original_frames = edited_tag.get_frame_indices(active_animation.frame_count)
	status_label.text = "Tag %s covers %s." % [tag_title, _get_tag_frame_text(edited_tag, active_animation.frame_count)]
	_mark_document_dirty()
	_refresh_interface()

func _find_or_create_tag(tag_name: String) -> GatorSpriteTag:
	for sprite_tag: GatorSpriteTag in sprite_document.tags:
		if sprite_tag.tag_title == tag_name:
			return sprite_tag
	var new_tag: GatorSpriteTag = GatorSpriteTag.new()
	new_tag.tag_title = tag_name
	sprite_document.tags.append(new_tag)
	return new_tag

func _find_or_create_slice(slice_name: String) -> GatorSpriteSlice:
	for sprite_slice: GatorSpriteSlice in sprite_document.slices:
		if sprite_slice.slice_title == slice_name:
			return sprite_slice
	var new_slice: GatorSpriteSlice = GatorSpriteSlice.new()
	new_slice.slice_title = slice_name
	sprite_document.slices.append(new_slice)
	return new_slice

func _on_export_folder_requested() -> void:
	if not export_frames_toggle.button_pressed and not export_sheet_toggle.button_pressed and not export_sprite_frames_toggle.button_pressed and not export_custom_brush_toggle.button_pressed:
		_set_export_feedback("Choose at least one output type before exporting.")
		return
	if export_custom_brush_toggle.button_pressed:
		var brush_export_image: Image = canvas_view.get_document_brush_image()
		if brush_export_image == null or brush_export_image.is_empty():
			_set_export_feedback("The selection or active frame has no visible pixels to export as a brush.")
			return
	if export_name_input.text.strip_edges().is_empty():
		_set_export_feedback("Enter an export name. This does not save the source document.")
		return
	if export_sheet_toggle.button_pressed:
		var configured_columns: int = int(export_columns_input.value)
		var configured_rows: int = int(export_rows_input.value)
		var frame_count: int = sprite_document.get_active_animation().frame_count
		if configured_columns > 0 and configured_rows > 0 and configured_columns * configured_rows < frame_count:
			_set_export_feedback("This animation has %d frames, but %d columns × %d rows provides only %d cells. Increase rows or columns." % [frame_count, configured_columns, configured_rows, configured_columns * configured_rows])
			return
	export_dialog.hide()
	export_directory_dialog.popup_centered_ratio(0.65)

func _set_export_feedback(message: String) -> void:
	export_feedback_label.text = message
	export_feedback_label.visible = not message.is_empty()

func _on_export_directory_selected(destination_directory: String) -> void:
	var brush_export_image: Image = null
	if export_custom_brush_toggle.button_pressed:
		brush_export_image = canvas_view.get_document_brush_image()
	var export_error: Error = GatorSpriteExporter.export_document(sprite_document, destination_directory, export_frames_toggle.button_pressed, export_sheet_toggle.button_pressed, export_sprite_frames_toggle.button_pressed, int(export_columns_input.value), int(export_rows_input.value), export_name_input.text.strip_edges(), export_custom_brush_toggle.button_pressed, brush_export_image)
	if export_error != OK:
		status_label.text = "Export failed: %d" % export_error
		return
	EditorInterface.get_resource_filesystem().scan()
	status_label.text = "Exported sprite assets to %s" % destination_directory

func _on_color_changed(selected_color: Color) -> void:
	canvas_view.brush_color = selected_color

func _on_canvas_color_picked(selected_color: Color) -> void:
	color_picker.color = selected_color
	canvas_view.brush_color = selected_color
	status_label.text = "Picked %s" % selected_color.to_html(true)

func _on_secondary_color_changed(selected_color: Color) -> void:
	canvas_view.secondary_color = selected_color

func _on_indexed_color_toggled(is_enabled: bool) -> void:
	sprite_document.indexed_color_mode = is_enabled
	_mark_document_dirty()
	status_label.text = "Indexed color mode %s." % ("enabled" if is_enabled else "disabled")

func _on_palette_lock_toggled(is_enabled: bool) -> void:
	sprite_document.palette_locked = is_enabled
	_mark_document_dirty()
	status_label.text = "Palette %s." % ("locked" if is_enabled else "unlocked")

func _on_load_brush_pressed() -> void:
	brush_load_dialog.popup_centered_ratio(0.65)

func _on_brush_path_selected(selected_path: String) -> void:
	var brush_error: Error = canvas_view.set_custom_brush_from_path(selected_path)
	if brush_error != OK:
		status_label.text = "Could not load brush image: %d" % brush_error
		return
	_on_tool_pressed(GatorCanvas.ToolMode.CUSTOM_BRUSH)
	_sync_brush_size_controls()
	status_label.text = "Custom brush loaded at 100%. Brush Vault can stamp its source colours or use its transparency as an active-colour mask."


func _uses_custom_brush_size() -> bool:
	return canvas_view.tool_mode == GatorCanvas.ToolMode.CUSTOM_BRUSH


func _sync_brush_size_controls() -> void:
	if brush_size_input == null:
		return
	brush_size_input.set_block_signals(true)
	if _uses_custom_brush_size():
		brush_size_input.min_value = 10.0
		brush_size_input.max_value = 1600.0
		brush_size_input.step = 10.0
		brush_size_input.suffix = "%"
		brush_size_input.editable = canvas_view.get_custom_brush_size() != Vector2i.ZERO
		brush_size_input.set_value_no_signal(float(canvas_view.get_custom_brush_scale_percent()))
	else:
		brush_size_input.min_value = 1.0
		brush_size_input.max_value = 256.0
		brush_size_input.step = 1.0
		brush_size_input.suffix = " px"
		brush_size_input.editable = true
		brush_size_input.set_value_no_signal(float(canvas_view.get_pencil_brush_size()))
	brush_size_input.set_block_signals(false)
	_update_brush_dimensions_label()


func _on_brush_size_changed(new_size: float) -> void:
	if _uses_custom_brush_size():
		var resize_error: Error = canvas_view.set_custom_brush_scale(roundi(new_size))
		if resize_error != OK:
			return
		var custom_brush_size: Vector2i = canvas_view.get_custom_brush_size()
		status_label.text = "Custom brush resized to %d%% (%d × %d)." % [roundi(new_size), custom_brush_size.x, custom_brush_size.y]
	else:
		canvas_view.set_pencil_brush_size(roundi(new_size))
		var standard_brush_size: int = canvas_view.get_pencil_brush_size()
		var tool_name: String = "Eraser" if canvas_view.tool_mode == GatorCanvas.ToolMode.ERASER else "Pencil"
		status_label.text = "%s size: %d × %d pixels." % [tool_name, standard_brush_size, standard_brush_size]
	_update_brush_dimensions_label()


func _change_brush_size(direction: int) -> void:
	if _uses_custom_brush_size():
		brush_size_input.value = clampf(brush_size_input.value + float(direction * 10), brush_size_input.min_value, brush_size_input.max_value)
	else:
		brush_size_input.value = clampf(brush_size_input.value + float(direction), brush_size_input.min_value, brush_size_input.max_value)
	canvas_view.grab_focus()


func _update_brush_dimensions_label() -> void:
	if brush_dimensions_label == null:
		return
	if _uses_custom_brush_size():
		var custom_brush_size: Vector2i = canvas_view.get_custom_brush_size()
		brush_dimensions_label.text = "No brush loaded" if custom_brush_size == Vector2i.ZERO else "Custom: %d × %d pixels" % [custom_brush_size.x, custom_brush_size.y]
	else:
		var standard_brush_size: int = canvas_view.get_pencil_brush_size()
		var tool_name: String = "Eraser" if canvas_view.tool_mode == GatorCanvas.ToolMode.ERASER else "Pencil"
		brush_dimensions_label.text = "%s: %d × %d pixels" % [tool_name, standard_brush_size, standard_brush_size]

func _on_deselect_pressed() -> void:
	canvas_view.clear_selection()
	status_label.text = "Selection cleared."

func _on_resize_canvas_to_limit_pressed() -> void:
	if sprite_document == null:
		return
	var target_size: Vector2i = _fit_size_within_limit(sprite_document.canvas_size, MAX_CANVAS_DIMENSION)
	if target_size == sprite_document.canvas_size:
		status_label.text = "Canvas is already within the 1024-pixel limit."
		return
	resize_canvas_dialog.dialog_text = "Resize the entire document from %d × %d to %d × %d? This resizes every layer and frame." % [sprite_document.canvas_size.x, sprite_document.canvas_size.y, target_size.x, target_size.y]
	resize_canvas_dialog.popup_centered(Vector2i(500, 190))

func _on_resize_canvas_confirmed() -> void:
	if sprite_document == null:
		return
	var old_size: Vector2i = sprite_document.canvas_size
	var target_size: Vector2i = _fit_size_within_limit(old_size, MAX_CANVAS_DIMENSION)
	if target_size == old_size:
		return
	var horizontal_scale: float = float(target_size.x) / float(old_size.x)
	var vertical_scale: float = float(target_size.y) / float(old_size.y)
	for sprite_layer: GatorSpriteLayer in sprite_document.layers:
		if sprite_layer.is_reference_layer():
			sprite_layer.reference_position *= Vector2(horizontal_scale, vertical_scale)
			sprite_layer.reference_scale *= Vector2(horizontal_scale, vertical_scale)
			continue
		for cel_index: int in range(sprite_layer.cels.size()):
			var sprite_cel: GatorSpriteCel = sprite_layer.cels[cel_index]
			var cel_image: Image = sprite_cel.get_image(old_size)
			cel_image.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
			sprite_cel.set_image(cel_image)
	for sprite_slice: GatorSpriteSlice in sprite_document.slices:
		var old_rectangle: Rect2i = sprite_slice.rectangle
		var resized_position: Vector2i = Vector2i(roundi(float(old_rectangle.position.x) * horizontal_scale), roundi(float(old_rectangle.position.y) * vertical_scale))
		var resized_size: Vector2i = Vector2i(maxi(1, roundi(float(old_rectangle.size.x) * horizontal_scale)), maxi(1, roundi(float(old_rectangle.size.y) * vertical_scale)))
		resized_position.x = clampi(resized_position.x, 0, target_size.x - 1)
		resized_position.y = clampi(resized_position.y, 0, target_size.y - 1)
		resized_size.x = clampi(resized_size.x, 1, target_size.x - resized_position.x)
		resized_size.y = clampi(resized_size.y, 1, target_size.y - resized_position.y)
		sprite_slice.rectangle = Rect2i(resized_position, resized_size)
	if sprite_document.tilemap != null and sprite_document.tileset != null:
		var old_grid_size: Vector2i = sprite_document.tilemap.grid_size
		var old_cells: PackedInt32Array = sprite_document.tilemap.cells.duplicate()
		var tile_size: Vector2i = sprite_document.tileset.tile_size.max(Vector2i.ONE)
		var new_grid_size: Vector2i = Vector2i(ceili(float(target_size.x) / float(tile_size.x)), ceili(float(target_size.y) / float(tile_size.y)))
		sprite_document.tilemap.resize_grid(new_grid_size)
		for grid_y: int in range(mini(old_grid_size.y, new_grid_size.y)):
			for grid_x: int in range(mini(old_grid_size.x, new_grid_size.x)):
				var old_cell_index: int = grid_y * old_grid_size.x + grid_x
				if old_cell_index >= 0 and old_cell_index < old_cells.size():
					sprite_document.tilemap.set_cell(Vector2i(grid_x, grid_y), old_cells[old_cell_index])
	sprite_document.canvas_size = target_size
	canvas_view.clear_selection()
	canvas_view.set_document(sprite_document)
	_reset_frame_selection(canvas_view.active_frame_index)
	preview_frame_index = 0
	auto_fit_canvas = true
	_mark_document_dirty()
	_refresh_interface()
	call_deferred("_fit_canvas_to_viewport")
	status_label.text = "Resized the document from %d × %d to %d × %d." % [old_size.x, old_size.y, target_size.x, target_size.y]

func _on_replace_color_pressed() -> void:
	replace_source_picker.color = color_picker.color
	replace_target_picker.color = color_picker.color
	replace_color_dialog.popup_centered(Vector2i(420, 260))

func _on_replace_color_confirmed() -> void:
	if sprite_document == null:
		return
	var source_color: Color = replace_source_picker.color
	var target_color: Color = replace_target_picker.color
	if source_color.is_equal_approx(target_color):
		status_label.text = "Choose a different replacement color."
		return
	var changed_pixels: int = 0
	for sprite_layer: GatorSpriteLayer in sprite_document.layers:
		for cel_index: int in range(sprite_layer.cels.size()):
			var sprite_cel: GatorSpriteCel = sprite_layer.ensure_cel(cel_index, sprite_document.canvas_size)
			var cel_image: Image = sprite_cel.get_image(sprite_document.canvas_size)
			for pixel_y: int in range(cel_image.get_height()):
				for pixel_x: int in range(cel_image.get_width()):
					if sprite_document.colors_match(cel_image.get_pixel(pixel_x, pixel_y), source_color):
						cel_image.set_pixel(pixel_x, pixel_y, target_color)
						changed_pixels += 1
			sprite_cel.set_image(cel_image)
	canvas_view.clear_selection()
	_refresh_interface()
	if changed_pixels > 0:
		_mark_document_dirty()
	status_label.text = "Replaced %d pixels across the sprite." % changed_pixels


func _on_grid_toggled(is_enabled: bool) -> void:
	canvas_view.show_grid = is_enabled
	canvas_view.queue_redraw()

func _on_onion_toggled(is_enabled: bool) -> void:
	canvas_view.show_onion_skin = is_enabled
	canvas_view.refresh_canvas()

func _set_preview_playing(is_playing: bool) -> void:
	preview_is_playing = is_playing
	preview_elapsed = 0.0
	if preview_play_button != null:
		preview_play_button.text = "Stop" if preview_is_playing else "Play"
		preview_play_button.icon = _load_icon("stop" if preview_is_playing else "play")


func _on_preview_play_pressed() -> void:
	_set_preview_playing(not preview_is_playing)
	if preview_is_playing:
		var preview_sequence: Array[int] = _get_preview_frame_sequence()
		if preview_sequence.is_empty():
			_set_preview_playing(false)
			return
		preview_frame_index = canvas_view.active_frame_index if live_draw_enabled and preview_sequence.has(canvas_view.active_frame_index) else preview_sequence[0]
		_refresh_preview()
		_sync_live_draw_frame()
	elif live_draw_enabled:
		_refresh_timeline_active_styles()


func _on_live_draw_toggled(is_enabled: bool) -> void:
	live_draw_enabled = is_enabled
	if live_draw_enabled and not canvas_view.is_live_draw_tool():
		_on_tool_pressed(GatorCanvas.ToolMode.PENCIL)
	if live_draw_enabled and preview_is_playing:
		_sync_live_draw_frame()
	status_label.text = "Live Draw enabled. Draw normally on the canvas while playback advances frames." if live_draw_enabled else "Live Draw disabled."

func _on_preview_fps_changed(new_fps: float) -> void:
	if sprite_document != null and not is_equal_approx(sprite_document.get_active_animation().frames_per_second, new_fps):
		sprite_document.get_active_animation().frames_per_second = new_fps
		_mark_document_dirty()

func _process(delta: float) -> void:
	if document_is_dirty:
		recovery_elapsed += delta
		if recovery_elapsed >= RECOVERY_INTERVAL_SECONDS:
			recovery_elapsed = 0.0
			save_recovery_now()
	if not preview_is_playing or sprite_document == null:
		return
	preview_elapsed += delta
	var seconds_per_frame: float = 1.0 / maxf(1.0, preview_fps_input.value)
	while preview_elapsed >= seconds_per_frame:
		preview_elapsed -= seconds_per_frame
		var preview_sequence: Array[int] = _get_preview_frame_sequence()
		if preview_sequence.is_empty():
			_set_preview_playing(false)
			return
		var sequence_position: int = preview_sequence.find(preview_frame_index)
		sequence_position = 0 if sequence_position < 0 else (sequence_position + 1) % preview_sequence.size()
		preview_frame_index = preview_sequence[sequence_position]
		_refresh_preview()
		_sync_live_draw_frame()


func _sync_live_draw_frame() -> void:
	if not live_draw_enabled or not preview_is_playing or sprite_document == null or not canvas_view.is_live_draw_tool():
		return
	canvas_view.set_live_draw_frame(preview_frame_index)
	_refresh_timeline_active_styles()
	_update_selection_status()


func _refresh_preview() -> void:
	if sprite_document == null or preview_display == null:
		return
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if active_animation.frame_count <= 0:
		return
	preview_frame_index = clampi(preview_frame_index, 0, active_animation.frame_count - 1)
	var preview_image: Image = sprite_document.composite_frame(preview_frame_index)
	if preview_texture == null or Vector2i(preview_texture.get_size()) != preview_image.get_size():
		preview_texture = ImageTexture.create_from_image(preview_image)
	else:
		preview_texture.update(preview_image)
	preview_display.texture = preview_texture

func _rebuild_preview_tag_menu() -> void:
	if preview_tag_menu == null or sprite_document == null:
		return
	var previous_tag_index: int = -1
	if preview_tag_menu.item_count > 0 and preview_tag_menu.selected >= 0:
		var previous_metadata: Variant = preview_tag_menu.get_item_metadata(preview_tag_menu.selected)
		if previous_metadata is int:
			previous_tag_index = int(previous_metadata)
	preview_tag_menu.clear()
	preview_tag_menu.add_item("None")
	preview_tag_menu.set_item_metadata(0, -1)
	var selected_menu_index: int = 0
	for tag_index: int in range(sprite_document.tags.size()):
		var sprite_tag: GatorSpriteTag = sprite_document.tags[tag_index]
		preview_tag_menu.add_item(sprite_tag.tag_title)
		var menu_index: int = preview_tag_menu.item_count - 1
		preview_tag_menu.set_item_metadata(menu_index, tag_index)
		if tag_index == previous_tag_index:
			selected_menu_index = menu_index
	preview_tag_menu.select(selected_menu_index)

func _on_preview_tag_selected(_menu_index: int) -> void:
	preview_elapsed = 0.0
	var preview_sequence: Array[int] = _get_preview_frame_sequence()
	preview_frame_index = preview_sequence[0] if not preview_sequence.is_empty() else 0
	_refresh_preview()
	_sync_live_draw_frame()

func _get_preview_frame_sequence() -> Array[int]:
	var preview_sequence: Array[int] = []
	if sprite_document == null:
		return preview_sequence
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if preview_tag_menu != null and preview_tag_menu.selected > 0:
		var selected_metadata: Variant = preview_tag_menu.get_item_metadata(preview_tag_menu.selected)
		if selected_metadata is int:
			var selected_preview_tag_index: int = int(selected_metadata)
			if selected_preview_tag_index >= 0 and selected_preview_tag_index < sprite_document.tags.size():
				return sprite_document.tags[selected_preview_tag_index].get_frame_indices(active_animation.frame_count)
	for frame_index: int in range(active_animation.frame_count):
		preview_sequence.append(frame_index)
	return preview_sequence

func _on_tool_pressed(requested_mode: GatorCanvas.ToolMode) -> void:
	canvas_view.tool_mode = requested_mode
	for stored_mode: Variant in tool_buttons.keys():
		var stored_button: Button = tool_buttons[stored_mode] as Button
		stored_button.button_pressed = int(stored_mode) == int(requested_mode)
	status_label.modulate = Color.WHITE
	if requested_mode == GatorCanvas.ToolMode.PENCIL:
		var shape_name: String = "Circle" if selected_pencil_brush_shape == int(GatorCanvas.PencilBrushShape.CIRCLE) else "Square"
		status_label.text = "Tool: Pencil (%s)" % shape_name
	elif requested_mode == GatorCanvas.ToolMode.ERASER:
		var shape_name: String = "Circle" if selected_eraser_brush_shape == int(GatorCanvas.PencilBrushShape.CIRCLE) else "Square"
		status_label.text = "Tool: Eraser (%s)" % shape_name
	else:
		status_label.text = "Tool: %s" % GatorCanvas.ToolMode.keys()[requested_mode].capitalize()
	_sync_brush_size_controls()
	canvas_view.grab_focus()
	for sprite_extension: GatorSpriteExtension in loaded_extensions:
		sprite_extension.on_tool_changed(requested_mode)

func _on_mirror_horizontal_toggled(is_enabled: bool) -> void:
	canvas_view.mirror_horizontal = is_enabled

func _on_mirror_vertical_toggled(is_enabled: bool) -> void:
	canvas_view.mirror_vertical = is_enabled

func _on_tiled_drawing_toggled(is_enabled: bool) -> void:
	canvas_view.tiled_drawing = is_enabled

func _on_capture_tileset_pressed() -> void:
	var tile_size: Vector2i = Vector2i(int(tile_width_input.value), int(tile_height_input.value))
	var source_image: Image = sprite_document.composite_frame(canvas_view.active_frame_index)
	sprite_document.tileset = GatorSpriteTileset.new()
	sprite_document.tileset.tile_size = tile_size
	sprite_document.tileset.set_source_image(source_image)
	sprite_document.tilemap = GatorSpriteTilemap.new()
	sprite_document.tilemap.resize_grid(Vector2i(ceili(float(sprite_document.canvas_size.x) / float(tile_size.x)), ceili(float(sprite_document.canvas_size.y) / float(tile_size.y))))
	tile_index_input.max_value = maxi(0, sprite_document.tileset.get_tile_count() - 1)
	tile_index_input.value = 0.0
	canvas_view.active_tile_index = 0
	canvas_view.invalidate_tile_stamp_preview()
	_mark_document_dirty()
	status_label.text = "Captured %d tiles at %d x %d. Tile Stamp places the full selected tile; its cyan outline previews the exact destination." % [sprite_document.tileset.get_tile_count(), tile_size.x, tile_size.y]

func _on_export_tileset_pressed() -> void:
	if sprite_document.tileset == null or sprite_document.tileset.get_source_image().is_empty():
		status_label.text = "Capture a frame as a tileset before exporting it."
		return
	tileset_export_dialog.current_file = "%s_tileset.png" % sprite_document.document_title.to_snake_case()
	tileset_export_dialog.popup_centered_ratio(0.65)

func _on_tileset_export_path_selected(selected_path: String) -> void:
	var export_path: String = selected_path if selected_path.to_lower().ends_with(".png") else "%s.png" % selected_path
	var export_error: Error = sprite_document.tileset.get_source_image().save_png(ProjectSettings.globalize_path(export_path))
	if export_error != OK:
		status_label.text = "Tileset export failed: %d" % export_error
		return
	EditorInterface.get_resource_filesystem().scan()
	status_label.text = "Exported tileset %s" % export_path.get_file()

func _on_tile_index_changed(tile_index: float) -> void:
	canvas_view.active_tile_index = int(tile_index)
	canvas_view.invalidate_tile_stamp_preview()

func _on_flip_horizontal_pressed() -> void:
	canvas_view.flip_selection(true)

func _on_flip_vertical_pressed() -> void:
	canvas_view.flip_selection(false)

func _on_rotate_clockwise_pressed() -> void:
	canvas_view.rotate_selection(true)

func _on_rotate_counter_clockwise_pressed() -> void:
	canvas_view.rotate_selection(false)

func _on_scale_up_pressed() -> void:
	canvas_view.scale_selection(2)

func _on_scale_down_pressed() -> void:
	canvas_view.scale_selection(-1)

func _on_skew_left_pressed() -> void:
	canvas_view.skew_selection(false)

func _on_skew_right_pressed() -> void:
	canvas_view.skew_selection(true)

func _on_undo_pressed() -> void:
	canvas_view.undo()
	preview_frame_index = canvas_view.active_frame_index
	_refresh_timeline_active_styles()
	_refresh_preview()
	_update_selection_status()


func _on_redo_pressed() -> void:
	canvas_view.redo()
	preview_frame_index = canvas_view.active_frame_index
	_refresh_timeline_active_styles()
	_refresh_preview()
	_update_selection_status()

func _on_zoom_in_pressed() -> void:
	auto_fit_canvas = false
	canvas_view.zoom_level = minf(canvas_view.zoom_level + 2.0, 48.0)
	canvas_view.refresh_canvas()
	_update_canvas_centering()
	_update_zoom_label()

func _on_zoom_out_pressed() -> void:
	auto_fit_canvas = false
	canvas_view.zoom_level = maxf(canvas_view.zoom_level - 2.0, 2.0)
	canvas_view.refresh_canvas()
	_update_canvas_centering()
	_update_zoom_label()

func _on_fit_zoom_pressed() -> void:
	auto_fit_canvas = true
	_fit_canvas_to_viewport()

func _on_canvas_zoom_changed(_new_zoom: float) -> void:
	auto_fit_canvas = false
	_update_canvas_centering()
	_update_zoom_label()

func _update_zoom_label() -> void:
	if zoom_label == null or canvas_view == null:
		return
	zoom_label.text = "%d%%" % roundi(canvas_view.zoom_level * 100.0)

func _refresh_layer_property_controls() -> void:
	if sprite_document == null or canvas_view == null or layer_blend_mode_menu == null:
		return
	var layer_index: int = clampi(canvas_view.active_layer_index, 0, sprite_document.layers.size() - 1)
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[layer_index]
	updating_layer_property_controls = true
	layer_blend_mode_menu.select(clampi(int(sprite_layer.blend_mode), 0, layer_blend_mode_menu.item_count - 1))
	layer_opacity_input.value = sprite_layer.opacity * 100.0
	var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(sprite_layer.group_title)
	group_opacity_row.visible = layer_group != null
	group_opacity_input.value = layer_group.opacity * 100.0 if layer_group != null else 100.0
	reference_position_x_input.value = sprite_layer.reference_position.x
	reference_position_y_input.value = sprite_layer.reference_position.y
	reference_scale_x_input.value = sprite_layer.reference_scale.x * 100.0
	reference_scale_y_input.value = sprite_layer.reference_scale.y * 100.0
	reference_rotation_input.value = sprite_layer.reference_rotation_degrees
	var is_reference: bool = sprite_layer.is_reference_layer()
	for reference_control: Control in reference_controls:
		reference_control.visible = is_reference
	updating_layer_property_controls = false

func _on_layer_blend_mode_selected(selected_index: int) -> void:
	if updating_layer_property_controls or sprite_document == null:
		return
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[canvas_view.active_layer_index]
	sprite_layer.blend_mode = selected_index
	_mark_document_dirty()
	canvas_view.refresh_canvas()
	_refresh_preview()

func _on_layer_opacity_changed(new_value: float) -> void:
	if updating_layer_property_controls or sprite_document == null:
		return
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[canvas_view.active_layer_index]
	sprite_layer.opacity = clampf(new_value / 100.0, 0.0, 1.0)
	_mark_document_dirty()
	canvas_view.refresh_canvas()
	_refresh_preview()

func _on_group_opacity_changed(new_value: float) -> void:
	if updating_layer_property_controls or sprite_document == null:
		return
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[canvas_view.active_layer_index]
	var layer_group: GatorSpriteLayerGroup = sprite_document.get_layer_group(sprite_layer.group_title)
	if layer_group == null:
		return
	layer_group.opacity = clampf(new_value / 100.0, 0.0, 1.0)
	_mark_document_dirty()
	canvas_view.refresh_canvas()
	_refresh_preview()

func _on_reference_transform_changed(_new_value: float) -> void:
	if updating_layer_property_controls or sprite_document == null:
		return
	var sprite_layer: GatorSpriteLayer = sprite_document.layers[canvas_view.active_layer_index]
	if not sprite_layer.is_reference_layer():
		return
	sprite_layer.reference_position = Vector2(reference_position_x_input.value, reference_position_y_input.value)
	sprite_layer.reference_scale = Vector2(maxf(0.01, reference_scale_x_input.value / 100.0), maxf(0.01, reference_scale_y_input.value / 100.0))
	sprite_layer.reference_rotation_degrees = reference_rotation_input.value
	_mark_document_dirty()
	canvas_view.refresh_canvas()

func _on_add_reference_image_pressed() -> void:
	reference_image_load_dialog.title = "Add Reference Image Layer"
	reference_image_load_dialog.popup_centered_ratio(0.65)

func _on_reference_image_path_selected(selected_path: String) -> void:
	var reference_image: Image = _load_external_image(selected_path)
	if reference_image == null:
		status_label.text = "Could not load the reference image."
		return
	var original_size: Vector2i = reference_image.get_size()
	var limited_size: Vector2i = _fit_size_within_limit(original_size, MAX_CANVAS_DIMENSION)
	if limited_size != original_size:
		reference_image.resize(limited_size.x, limited_size.y, Image.INTERPOLATE_LANCZOS)
	var reference_layer: GatorSpriteLayer = GatorSpriteLayer.new()
	reference_layer.layer_title = "%s Reference" % selected_path.get_file().get_basename()
	reference_layer.layer_type = GatorSpriteLayer.LayerType.REFERENCE
	reference_layer.exclude_from_export = true
	reference_layer.reference_source_path = selected_path
	reference_layer.reference_position = (Vector2(sprite_document.canvas_size) - Vector2(reference_image.get_size())) * 0.5
	var reference_cel: GatorSpriteCel = GatorSpriteCel.new()
	reference_cel.set_image(reference_image)
	reference_layer.cels.append(reference_cel)
	sprite_document.layers.append(reference_layer)
	canvas_view.active_layer_index = sprite_document.layers.size() - 1
	_reset_layer_selection(canvas_view.active_layer_index)
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Added %s as a non-exported reference layer." % selected_path.get_file()

func _on_import_spritesheet_pressed() -> void:
	_request_protected_action(Callable(spritesheet_load_dialog, "popup_centered_ratio").bind(0.65))

func _on_spritesheet_path_selected(selected_path: String) -> void:
	var loaded_image: Image = _load_external_image(selected_path)
	if loaded_image == null:
		status_label.text = "Could not load the selected spritesheet."
		return
	pending_spritesheet_image = loaded_image
	pending_spritesheet_path = selected_path
	var image_size: Vector2i = loaded_image.get_size()
	spritesheet_columns_input.max_value = image_size.x
	spritesheet_rows_input.max_value = image_size.y
	spritesheet_cell_width_input.max_value = image_size.x
	spritesheet_cell_height_input.max_value = image_size.y
	spritesheet_columns_input.value = 1
	spritesheet_rows_input.value = 1
	spritesheet_cell_width_input.value = image_size.x
	spritesheet_cell_height_input.value = image_size.y
	spritesheet_spacing_x_input.value = 0
	spritesheet_spacing_y_input.value = 0
	spritesheet_margin_x_input.value = 0
	spritesheet_margin_y_input.value = 0
	if spritesheet_source_label != null:
		spritesheet_source_label.text = "%s — %d × %d pixels" % [selected_path.get_file(), image_size.x, image_size.y]
	spritesheet_slice_dialog.popup_centered(Vector2i(520, 390))

func _on_spritesheet_slice_confirmed() -> void:
	if pending_spritesheet_image == null or pending_spritesheet_image.is_empty():
		return
	var sheet_size: Vector2i = pending_spritesheet_image.get_size()
	var margin: Vector2i = Vector2i(int(spritesheet_margin_x_input.value), int(spritesheet_margin_y_input.value))
	var spacing: Vector2i = Vector2i(int(spritesheet_spacing_x_input.value), int(spritesheet_spacing_y_input.value))
	var columns: int
	var rows: int
	var cell_size: Vector2i
	if spritesheet_slice_mode_menu.get_selected_id() == 0:
		columns = maxi(1, int(spritesheet_columns_input.value))
		rows = maxi(1, int(spritesheet_rows_input.value))
		cell_size = Vector2i(
			floori(float(sheet_size.x - margin.x * 2 - spacing.x * (columns - 1)) / float(columns)),
			floori(float(sheet_size.y - margin.y * 2 - spacing.y * (rows - 1)) / float(rows))
		)
	else:
		cell_size = Vector2i(maxi(1, int(spritesheet_cell_width_input.value)), maxi(1, int(spritesheet_cell_height_input.value)))
		columns = maxi(1, floori(float(sheet_size.x - margin.x * 2 + spacing.x) / float(cell_size.x + spacing.x)))
		rows = maxi(1, floori(float(sheet_size.y - margin.y * 2 + spacing.y) / float(cell_size.y + spacing.y)))
	if cell_size.x <= 0 or cell_size.y <= 0 or cell_size.x > MAX_CANVAS_DIMENSION or cell_size.y > MAX_CANVAS_DIMENSION:
		status_label.text = "Each spritesheet frame must be between 1 and %d pixels wide and high." % MAX_CANVAS_DIMENSION
		return
	var frame_count: int = columns * rows
	var imported_document: GatorSpriteDocument = GatorSpriteDocument.new()
	imported_document.setup_new_sprite(cell_size)
	imported_document.document_title = pending_spritesheet_path.get_file().get_basename()
	var imported_animation: GatorSpriteAnimation = imported_document.get_active_animation()
	imported_animation.frame_count = frame_count
	var imported_layer: GatorSpriteLayer = imported_document.layers[0]
	imported_layer.layer_title = "Spritesheet"
	imported_layer.cels.clear()
	for row_index: int in range(rows):
		for column_index: int in range(columns):
			var source_position: Vector2i = margin + Vector2i(column_index * (cell_size.x + spacing.x), row_index * (cell_size.y + spacing.y))
			var source_rectangle: Rect2i = Rect2i(source_position, cell_size)
			var source_end: Vector2i = source_position + cell_size
			if source_position.x < 0 or source_position.y < 0 or source_end.x > sheet_size.x or source_end.y > sheet_size.y:
				continue
			var frame_image: Image = pending_spritesheet_image.get_region(source_rectangle)
			var frame_cel: GatorSpriteCel = GatorSpriteCel.new()
			frame_cel.set_image(frame_image)
			imported_layer.cels.append(frame_cel)
	imported_animation.frame_count = imported_layer.cels.size()
	if imported_animation.frame_count <= 0:
		status_label.text = "The slice settings did not produce any complete frames."
		return
	if spritesheet_row_tags_toggle.button_pressed:
		for row_index: int in range(rows):
			var row_start: int = row_index * columns
			if row_start >= imported_animation.frame_count:
				break
			var row_tag: GatorSpriteTag = GatorSpriteTag.new()
			row_tag.tag_title = "Row %d" % (row_index + 1)
			row_tag.set_contiguous_range(row_start, mini(imported_animation.frame_count - 1, row_start + columns - 1), imported_animation.frame_count)
			imported_document.tags.append(row_tag)
	_apply_extension_document_replacement(imported_document, "")
	pending_spritesheet_image = null
	pending_spritesheet_path = ""
	status_label.text = "Imported %d spritesheet frames at %d × %d." % [imported_animation.frame_count, cell_size.x, cell_size.y]

func _load_external_image(selected_path: String) -> Image:
	var image_path: String = selected_path
	if selected_path.begins_with("res://") or selected_path.begins_with("user://"):
		image_path = ProjectSettings.globalize_path(selected_path)
	var loaded_image: Image = Image.new()
	var load_error: Error = loaded_image.load(image_path)
	if load_error != OK or loaded_image.is_empty():
		return null
	if loaded_image.get_format() != Image.FORMAT_RGBA8:
		loaded_image.convert(Image.FORMAT_RGBA8)
	return loaded_image

func _on_link_selected_cels_pressed() -> void:
	_sanitize_frame_selection(sprite_document.get_active_animation().frame_count)
	if selected_frame_indices.size() < 2:
		status_label.text = "Select at least two frames to link their cels."
		return
	if sprite_document.link_cels(canvas_view.active_layer_index, selected_frame_indices, canvas_view.active_frame_index):
		_mark_document_dirty()
		_refresh_interface()
		status_label.text = "Linked %d cels on %s." % [selected_frame_indices.size(), sprite_document.layers[canvas_view.active_layer_index].layer_title]

func _on_unlink_selected_cels_pressed() -> void:
	_sanitize_frame_selection(sprite_document.get_active_animation().frame_count)
	var unlinked_count: int = sprite_document.unlink_cels(canvas_view.active_layer_index, selected_frame_indices)
	if unlinked_count <= 0:
		status_label.text = "No selected cels were unlinked."
		return
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Unlinked %d cel%s." % [unlinked_count, "" if unlinked_count == 1 else "s"]

func _on_duplicate_linked_frame_pressed() -> void:
	var new_frame_index: int = sprite_document.duplicate_frame_linked(canvas_view.active_frame_index)
	canvas_view.active_frame_index = new_frame_index
	_reset_frame_selection(new_frame_index)
	preview_frame_index = new_frame_index
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Duplicated frame %d as linked cels." % new_frame_index

func _on_add_layer_pressed() -> void:
	var new_layer: GatorSpriteLayer = GatorSpriteLayer.new()
	new_layer.layer_title = "Layer %d" % (sprite_document.layers.size() + 1)
	new_layer.ensure_cel(canvas_view.active_frame_index, sprite_document.canvas_size)
	sprite_document.layers.append(new_layer)
	canvas_view.active_layer_index = sprite_document.layers.size() - 1
	_reset_layer_selection(canvas_view.active_layer_index)
	_mark_document_dirty()
	_refresh_interface()

func _on_add_group_pressed() -> void:
	_sanitize_layer_selection(sprite_document.layers.size())
	if selected_layer_indices.is_empty():
		_reset_layer_selection(canvas_view.active_layer_index)
	var selected_layers: Array[GatorSpriteLayer] = []
	for selected_layer_index: int in selected_layer_indices:
		selected_layers.append(sprite_document.layers[selected_layer_index])
	var group_number: int = sprite_document.layer_groups.size() + 1
	var group_title: String = "Group %d" % group_number
	while sprite_document.get_layer_group(group_title) != null:
		group_number += 1
		group_title = "Group %d" % group_number
	var new_group: GatorSpriteLayerGroup = GatorSpriteLayerGroup.new()
	new_group.group_title = group_title
	sprite_document.layer_groups.append(new_group)
	var first_selected_index: int = selected_layer_indices[0]
	sprite_document.move_layers(selected_layer_indices, first_selected_index)
	for selected_layer: GatorSpriteLayer in selected_layers:
		selected_layer.group_title = group_title
	sprite_document.remove_empty_layer_groups()
	selected_layer_indices.clear()
	for selected_layer: GatorSpriteLayer in selected_layers:
		selected_layer_indices.append(sprite_document.layers.find(selected_layer))
	selected_layer_indices.sort()
	canvas_view.active_layer_index = sprite_document.layers.find(selected_layers[0])
	layer_selection_anchor = canvas_view.active_layer_index
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Created %s with %d selected layer%s." % [group_title, selected_layers.size(), "" if selected_layers.size() == 1 else "s"]

func _on_ungroup_layer_pressed() -> void:
	_sanitize_layer_selection(sprite_document.layers.size())
	var ungrouped_count: int = 0
	for selected_layer_index: int in selected_layer_indices:
		var selected_layer: GatorSpriteLayer = sprite_document.layers[selected_layer_index]
		if not selected_layer.group_title.is_empty():
			selected_layer.group_title = ""
			ungrouped_count += 1
	if ungrouped_count == 0:
		status_label.text = "None of the selected layers are in a group."
		return
	sprite_document.remove_empty_layer_groups()
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Removed %d layer%s from their group%s." % [ungrouped_count, "" if ungrouped_count == 1 else "s", "" if ungrouped_count == 1 else "s"]

func _on_delete_layer_pressed() -> void:
	_sanitize_layer_selection(sprite_document.layers.size())
	var maximum_deletable: int = sprite_document.layers.size() - 1
	if maximum_deletable <= 0:
		status_label.text = "A sprite needs at least one layer."
		return
	var layers_to_delete: Array[int] = selected_layer_indices.duplicate()
	if layers_to_delete.size() > maximum_deletable:
		layers_to_delete.resize(maximum_deletable)
	layers_to_delete.sort()
	for delete_index_position: int in range(layers_to_delete.size() - 1, -1, -1):
		sprite_document.layers.remove_at(layers_to_delete[delete_index_position])
	sprite_document.remove_empty_layer_groups()
	canvas_view.active_layer_index = clampi(layers_to_delete[0], 0, sprite_document.layers.size() - 1)
	_reset_layer_selection(canvas_view.active_layer_index)
	_mark_document_dirty()
	_refresh_interface()
	status_label.text = "Deleted %d layer%s." % [layers_to_delete.size(), "" if layers_to_delete.size() == 1 else "s"]

func _on_add_frame_pressed() -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	var next_frame_index: int = active_animation.frame_count
	sprite_document.ensure_frame(next_frame_index)
	canvas_view.active_frame_index = next_frame_index
	_reset_frame_selection(next_frame_index)
	_mark_document_dirty()
	_refresh_interface()

func _on_copy_frame_pressed() -> void:
	var copied_frame_index: int = sprite_document.duplicate_frame(canvas_view.active_frame_index)
	canvas_view.active_frame_index = copied_frame_index
	_reset_frame_selection(copied_frame_index)
	preview_frame_index = copied_frame_index
	status_label.text = "Copied frame %d to frame %d." % [copied_frame_index, copied_frame_index + 1]
	_mark_document_dirty()
	_refresh_interface()

func _on_delete_frame_pressed() -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if active_animation.frame_count <= 1:
		status_label.text = "An animation needs at least one frame."
		return
	if not sprite_document.delete_frame(canvas_view.active_frame_index):
		return
	canvas_view.active_frame_index = clampi(canvas_view.active_frame_index, 0, active_animation.frame_count - 1)
	_reset_frame_selection(canvas_view.active_frame_index)
	preview_frame_index = canvas_view.active_frame_index
	_mark_document_dirty()
	_refresh_interface()

func _on_move_frame_left_pressed() -> void:
	if canvas_view.active_frame_index <= 0:
		status_label.text = "The selected frame is already first."
		return
	var destination_frame_index: int = canvas_view.active_frame_index - 1
	if sprite_document.move_frame(canvas_view.active_frame_index, destination_frame_index):
		canvas_view.active_frame_index = destination_frame_index
		_reset_frame_selection(destination_frame_index)
		preview_frame_index = destination_frame_index
		status_label.text = "Moved frame %d left." % (destination_frame_index + 2)
		_mark_document_dirty()
		_refresh_interface()

func _on_move_frame_right_pressed() -> void:
	var active_animation: GatorSpriteAnimation = sprite_document.get_active_animation()
	if canvas_view.active_frame_index >= active_animation.frame_count - 1:
		status_label.text = "The selected frame is already last."
		return
	var destination_frame_index: int = canvas_view.active_frame_index + 1
	if sprite_document.move_frame(canvas_view.active_frame_index, destination_frame_index):
		canvas_view.active_frame_index = destination_frame_index
		_reset_frame_selection(destination_frame_index)
		preview_frame_index = destination_frame_index
		status_label.text = "Moved frame %d right." % destination_frame_index
		_mark_document_dirty()
		_refresh_interface()

func _on_copy_selection_pressed() -> void:
	if canvas_view.copy_selection():
		status_label.text = "Copied the selected pixels."
	else:
		status_label.text = "Select pixels before copying."

func _on_paste_selection_pressed() -> void:
	if canvas_view.paste_selection():
		status_label.text = "Pasted selected pixels one cell down and right."
	else:
		status_label.text = "Copy selected pixels before pasting."

func _on_layer_selected(layer_index: int) -> void:
	canvas_view.clear_selection()
	canvas_view.active_layer_index = layer_index
	_reset_layer_selection(layer_index)
	_refresh_interface()

func _on_frame_selected(frame_index: int) -> void:
	_reset_frame_selection(frame_index)
	_select_active_frame_without_rebuild(frame_index)

func _on_pixels_changed() -> void:
	_mark_document_dirty()
	_update_selection_status()
	_refresh_preview()
	for sprite_extension: GatorSpriteExtension in loaded_extensions:
		sprite_extension.on_pixels_changed(sprite_document, canvas_view.active_frame_index, canvas_view.active_layer_index)

func _notify_extensions_document_ready() -> void:
	for sprite_extension: GatorSpriteExtension in loaded_extensions:
		sprite_extension.on_document_ready(sprite_document)

func _shortcut_input(input_event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not input_event is InputEventKey:
		return
	var key_event: InputEventKey = input_event
	if not key_event.pressed or key_event.echo:
		return
	if not shortcut_capture_action.is_empty():
		if _capture_shortcut_key(key_event):
			get_viewport().set_input_as_handled()
			return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or (focus_owner != self and not is_ancestor_of(focus_owner)):
		return
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	var shortcut_text: String = _shortcut_text_from_event(key_event)
	for action_name: String in shortcut_bindings.keys():
		if String(shortcut_bindings[action_name]).to_upper() == shortcut_text:
			_execute_shortcut(action_name)
			get_viewport().set_input_as_handled()
			return
	for command_key: String in extension_commands.keys():
		var command_data: Dictionary = extension_commands[command_key]
		if not String(command_data["shortcut"]).is_empty() and String(command_data["shortcut"]) == shortcut_text:
			_run_extension_command(command_key)
			get_viewport().set_input_as_handled()
			return

func _shortcut_text_from_event(key_event: InputEventKey) -> String:
	var event_keycode: Key = key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
	var key_name: String = OS.get_keycode_string(event_keycode).to_upper()
	if event_keycode == KEY_BRACKETLEFT:
		key_name = "["
	elif event_keycode == KEY_BRACKETRIGHT:
		key_name = "]"
	if key_name.is_empty():
		return ""
	if key_name in ["CTRL", "SHIFT", "ALT", "META"]:
		return ""
	var modifier_names: Array[String] = []
	if key_event.ctrl_pressed:
		modifier_names.append("CTRL")
	if key_event.alt_pressed:
		modifier_names.append("ALT")
	if key_event.shift_pressed:
		modifier_names.append("SHIFT")
	modifier_names.append(key_name)
	return "+".join(modifier_names)

func _capture_shortcut_key(key_event: InputEventKey) -> bool:
	if shortcut_capture_action.is_empty():
		return false
	if key_event.keycode == KEY_ESCAPE:
		var cancelled_button: Button = shortcut_inputs[shortcut_capture_action]
		cancelled_button.text = String(shortcut_bindings[shortcut_capture_action])
		status_label.text = "Shortcut capture cancelled."
		shortcut_capture_action = ""
		return true
	var captured_shortcut: String = _shortcut_text_from_event(key_event)
	if captured_shortcut.is_empty():
		return false
	var captured_button: Button = shortcut_inputs[shortcut_capture_action]
	captured_button.text = captured_shortcut
	shortcut_bindings[shortcut_capture_action] = captured_shortcut
	status_label.text = "%s is now %s. Save Shortcuts to keep it." % [shortcut_capture_action, captured_shortcut]
	shortcut_capture_action = ""
	return true

func _execute_shortcut(action_name: String) -> void:
	match action_name:
		"Pencil": _on_tool_pressed(GatorCanvas.ToolMode.PENCIL)
		"Eraser": _on_tool_pressed(GatorCanvas.ToolMode.ERASER)
		"Fill": _on_tool_pressed(GatorCanvas.ToolMode.FILL)
		"Picker": _on_tool_pressed(GatorCanvas.ToolMode.PICKER)
		"Line": _on_tool_pressed(GatorCanvas.ToolMode.LINE)
		"Rectangle": _on_tool_pressed(GatorCanvas.ToolMode.RECTANGLE)
		"Selection": _on_tool_pressed(GatorCanvas.ToolMode.SELECTION)
		"Decrease Brush Size": _change_brush_size(-1)
		"Increase Brush Size": _change_brush_size(1)
		"Copy": _on_copy_selection_pressed()
		"Paste": _on_paste_selection_pressed()
		"Deselect": _on_deselect_pressed()
		"Undo": _on_undo_pressed()
		"Redo": _on_redo_pressed()
