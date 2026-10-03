@tool
class_name GatorSpriteExtensionContext
extends RefCounted

var extension_id: String = ""
var host_node: Node

func setup(source_extension_id: String, source_host_node: Node) -> void:
	extension_id = source_extension_id
	host_node = source_host_node

func get_document() -> GatorSpriteDocument:
	return host_node.call("_extension_get_document") as GatorSpriteDocument

func get_active_frame_index() -> int:
	return int(host_node.call("_extension_get_active_frame_index"))

func get_active_layer_index() -> int:
	return int(host_node.call("_extension_get_active_layer_index"))

func set_active_cell(frame_index: int, layer_index: int) -> void:
	host_node.call("_extension_set_active_cell", frame_index, layer_index)

func replace_document(imported_document: GatorSpriteDocument, source_path: String = "") -> bool:
	return bool(host_node.call("_extension_replace_document", imported_document, source_path))

func register_command(command_id: String, command_title: String, command_callback: Callable, show_in_toolbar: bool = false, shortcut_binding: String = "") -> bool:
	return bool(host_node.call("_extension_register_command", extension_id, command_id, command_title, command_callback, show_in_toolbar, shortcut_binding))

func register_panel(panel_id: String, panel_title: String, panel_control: Control) -> bool:
	return bool(host_node.call("_extension_register_panel", extension_id, panel_id, panel_title, panel_control))

func register_sidebar_panel(panel_id: String, panel_title: String, panel_control: Control) -> bool:
	return bool(host_node.call("_extension_register_sidebar_panel", extension_id, panel_id, panel_title, panel_control))

func focus_sidebar_panel(panel_id: String) -> void:
	host_node.call("_extension_focus_sidebar_panel", extension_id, panel_id)

func get_selected_frame_indices() -> Array[int]:
	var selected_frames: Array[int] = []
	var source_frames: Variant = host_node.call("_extension_get_selected_frame_indices")
	if source_frames is Array:
		for frame_index: Variant in source_frames:
			selected_frames.append(int(frame_index))
	return selected_frames

func set_selected_frame_indices(frame_indices: Array[int], active_frame_index: int = -1) -> void:
	host_node.call("_extension_set_selected_frame_indices", frame_indices, active_frame_index)

func set_selection_mask(selection_mask: Image) -> bool:
	return bool(host_node.call("_extension_set_selection_mask", selection_mask))

func get_custom_brush_source_image() -> Image:
	return host_node.call("_extension_get_custom_brush_source_image") as Image

func get_document_brush_image() -> Image:
	return host_node.call("_extension_get_document_brush_image") as Image

func set_custom_brush_image(brush_image: Image) -> Error:
	return int(host_node.call("_extension_set_custom_brush_image", brush_image))

func set_custom_brush_scale(scale_percent: int) -> Error:
	return int(host_node.call("_extension_set_custom_brush_scale", scale_percent))

func get_custom_brush_scale() -> int:
	return int(host_node.call("_extension_get_custom_brush_scale"))

func set_custom_brush_spacing(spacing_percent: int) -> void:
	host_node.call("_extension_set_custom_brush_spacing", spacing_percent)

func get_custom_brush_spacing() -> int:
	return int(host_node.call("_extension_get_custom_brush_spacing"))

func refresh_document(mark_dirty: bool = true) -> void:
	host_node.call("_extension_refresh_document", mark_dirty)

func show_open_file_dialog(dialog_title: String, filters: PackedStringArray, completion_callback: Callable) -> void:
	host_node.call("_extension_show_file_dialog", extension_id, dialog_title, filters, completion_callback, FileDialog.FILE_MODE_OPEN_FILE)

func show_save_file_dialog(dialog_title: String, filters: PackedStringArray, completion_callback: Callable) -> void:
	host_node.call("_extension_show_file_dialog", extension_id, dialog_title, filters, completion_callback, FileDialog.FILE_MODE_SAVE_FILE)

func show_folder_dialog(dialog_title: String, completion_callback: Callable) -> void:
	host_node.call("_extension_show_file_dialog", extension_id, dialog_title, PackedStringArray(), completion_callback, FileDialog.FILE_MODE_OPEN_DIR)

func notify(message: String, is_error: bool = false) -> void:
	host_node.call("_extension_notify", extension_id, message, is_error)

func begin_undo_transaction() -> void:
	host_node.call("_extension_begin_undo_transaction")

func commit_undo_transaction() -> void:
	host_node.call("_extension_commit_undo_transaction")

func undo() -> void:
	host_node.call("_extension_undo")

func redo() -> void:
	host_node.call("_extension_redo")

func has_selection() -> bool:
	return bool(host_node.call("_extension_has_selection"))

func get_selection_bounds() -> Rect2i:
	var selection_bounds: Rect2i = host_node.call("_extension_get_selection_bounds")
	return selection_bounds

func get_selection_mask() -> Image:
	return host_node.call("_extension_get_selection_mask") as Image

func clear_selection() -> void:
	host_node.call("_extension_clear_selection")

func copy_selection() -> bool:
	return bool(host_node.call("_extension_copy_selection"))

func paste_selection() -> bool:
	return bool(host_node.call("_extension_paste_selection"))

func export_assets(destination_directory: String, export_name: String, export_frames: bool = true, export_sheet: bool = true, export_sprite_frames: bool = true) -> Error:
	return int(host_node.call("_extension_export_assets", destination_directory, export_name, export_frames, export_sheet, export_sprite_frames))
