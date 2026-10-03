@tool
class_name GMSMainScreen
extends VBoxContainer

enum MeshExportMode {
	ACTIVE_OBJECT,
	SELECTED_COMBINED,
}

enum PendingDocumentAction {
	NONE,
	NEW_DOCUMENT,
	OPEN_DOCUMENT,
}


enum WorkspaceMode {
	MODEL,
	RIG,
	ANIMATE,
}


enum RigSubmode {
	EDIT,
	WEIGHTS,
	POSE,
}

const UI_ICON_ROOT: String = "res://addons/gator_model_studio/ui/icons"
const RECOVERY_DIRECTORY: String = "res://addons/gator_model_studio/recovery"
const RECOVERY_DOCUMENT_PATH: String = RECOVERY_DIRECTORY + "/recovery.tres"
const RECOVERY_TEMP_PATH: String = RECOVERY_DIRECTORY + "/recovery_pending.tres"
const RECOVERY_METADATA_PATH: String = RECOVERY_DIRECTORY + "/recovery.cfg"
const AUTO_EXPORT_STAGING_DIRECTORY: String = "user://gator_model_studio/export_staging"
const AUTOSAVE_INTERVAL_SECONDS: float = 300.0
const REMESH_HEAVY_TRIANGLE_WARNING: int = 100000
const REMESH_REGION_WHOLE_OBJECT: int = 0
const REMESH_REGION_SELECTED_FACES: int = 1
const SUBDIVISION_WARNING_FACES: int = 100000
const FILESYSTEM_REFRESH_INITIAL_DELAY_SECONDS: float = 0.5
const FILESYSTEM_REFRESH_RETRY_SECONDS: float = 0.25
const AUTO_EXPORT_RETRY_SECONDS: float = 0.25
const FILESYSTEM_REFRESH_IDLE_GRACE_MSEC: int = 250
const FILESYSTEM_REFRESH_SIGNAL_TIMEOUT_MSEC: int = 5000
const LOCAL_SAVE_EXTERNAL_SUPPRESSION_MSEC: int = 250
const HELP_MENU_HOTKEYS: int = 0
const HELP_MENU_DOCUMENTATION: int = 1
const HELP_MENU_REPORT_BUG: int = 2
const HELP_MENU_DONATE: int = 3
const HELP_MENU_ABOUT: int = 4
const EDITOR_METADATA_SECTION: String = "gator_model_studio"
const HELP_OPENED_METADATA_KEY: String = "help_menu_opened"
const FIRST_ACTIVATION_NOTICE_METADATA_KEY: String = "first_activation_donation_notice_shown"
const REPORT_BUG_URL: String = "mailto:blackwatergatordev@gmail.com?subject=GMS%20Report"
const DONATION_URL: String = "https://ko-fi.com/blackwatergatorstudios"

var _plugin_version: String = ""
var _extension_api_version: int = 0

var _document: GMSDocument
var _selection: GMSSelection = GMSSelection.new()
var _history: GMSHistory = GMSHistory.new()
var _current_path: String = ""
var _is_dirty: bool = false
var _suppress_ui_signals: bool = false
var _autosave_timer: Timer
var _unsaved_changes_dialog: ConfirmationDialog
var _recovery_dialog: ConfirmationDialog
var _first_activation_notice_dialog: AcceptDialog
var _first_activation_notice_pending: bool = false
var _startup_notices_queued: bool = false
var _startup_notices_started: bool = false
var _pending_document_action: PendingDocumentAction = PendingDocumentAction.NONE
var _save_continuation_action: PendingDocumentAction = PendingDocumentAction.NONE
var _save_dialog_is_save_as: bool = false
var _open_discards_current_document: bool = false
var _recovery_metadata: Dictionary = {}
var _last_local_save_shortcut_msec: int = -1000
var _auto_export_request_serial: int = 0
var _auto_export_pending_path: String = ""
var _auto_export_pending_document: GMSDocument
var _auto_export_retry_timer: Timer

var _viewport: GMSModelViewport
var _outliner: Tree
var _tree_items: Dictionary = {}
var _status_label: Label
var _document_label: Label
var _undo_button: Button
var _redo_button: Button
var _auto_export_on_save_check: CheckBox
var _mode_buttons: Dictionary = {}
var _workspace_mode: int = WorkspaceMode.MODEL
var _rig_mode_button: Button
var _model_properties_root: VBoxContainer
var _rig_properties_root: VBoxContainer
var _rig_submode: int = RigSubmode.EDIT
var _rig_submode_buttons: Dictionary = {}
var _rig_bone_tree: GMSBoneHierarchyTree
var _rig_selected_bone: int = -1
var _rig_status_label: Label
var _rig_edit_section: VBoxContainer
var _rig_weights_section: VBoxContainer
var _rig_pose_section: VBoxContainer
var _rig_bone_name_edit: LineEdit
var _rig_parent_option: OptionButton
var _rig_head_fields: Array[SpinBox] = []
var _rig_tail_fields: Array[SpinBox] = []
var _rig_roll_spin: SpinBox
var _rig_weight_bone_option: OptionButton
var _rig_auto_smooth_iterations: SpinBox
var _rig_brush_mode_option: OptionButton
var _rig_brush_radius_spin: SpinBox
var _rig_brush_strength_spin: SpinBox
var _rig_weight_value_spin: SpinBox
var _rig_vertex_select_check: CheckBox
var _rig_pose_rotation_fields: Array[SpinBox] = []
var _rig_attachment_list: ItemList
var _rig_attach_button: Button
var _rig_detach_button: Button
var _rig_attachment_status_label: Label
var _rig_drag_original: GMSRigData
var _rig_drag_object_id: String = ""
var _animate_mode_button: Button
var _animation_properties_root: VBoxContainer
var _animation_timeline_panel: PanelContainer
var _animation_timeline: GMSAnimationTimeline
var _animation_clip_option: OptionButton
var _animation_clip_name_edit: LineEdit
var _animation_fps_spin: SpinBox
var _animation_frame_count_spin: SpinBox
var _animation_loop_check: CheckBox
var _animation_auto_key_check: CheckBox
var _animation_interpolation_option: OptionButton
var _animation_position_fields: Array[SpinBox] = []
var _animation_rotation_fields: Array[SpinBox] = []
var _animation_scale_fields: Array[SpinBox] = []
var _animation_pose_list: ItemList
var _animation_pose_name_edit: LineEdit
var _animation_frame_spin: SpinBox
var _animation_play_button: Button
var _animation_status_label: Label
var _animation_active_clip_id: String = ""
var _animation_current_frame: int = 0
var _animation_playing: bool = false
var _animation_play_accumulator: float = 0.0
var _animation_selected_keys: PackedStringArray = PackedStringArray()
var _animation_dirty_bones: Dictionary = {}
var _animation_pose_clipboard: Dictionary = {}
var _animation_key_clipboard: Array[Dictionary] = []
var _animation_transform_object_id: String = ""
var _animation_transform_bone_index: int = -1
var _animation_transform_original_offsets: Array[Transform3D] = []
var _animation_transform_original_world: Transform3D = Transform3D.IDENTITY
var _animation_transform_parent_global: Transform3D = Transform3D.IDENTITY
var _animation_transform_local_rest: Transform3D = Transform3D.IDENTITY
var _animation_transform_was_dirty: bool = false
var _animation_numeric_change_active: bool = false
var _animation_ik_chain_option: OptionButton
var _animation_ik_root_option: OptionButton
var _animation_ik_tip_option: OptionButton
var _animation_ik_target_fields: Array[SpinBox] = []
var _animation_ik_pole_fields: Array[SpinBox] = []
var _animation_ik_iterations_spin: SpinBox
var _animation_ik_tolerance_spin: SpinBox
var _animation_ik_pole_influence_spin: SpinBox
var _animation_active_ik_chain_id: String = ""
var _animation_ik_gizmo_control: int = GMSModelViewport.AnimationIKControl.NONE
var _animation_ik_transform_object_id: String = ""
var _animation_ik_transform_chain_id: String = ""
var _animation_ik_transform_original_rig: GMSRigData
var _animation_ik_transform_was_dirty: bool = false
var _animation_ik_transform_is_pole: bool = false
var _animation_constraint_list: ItemList
var _animation_constraint_type_option: OptionButton
var _animation_constraint_target_option: OptionButton
var _animation_constraint_influence_spin: SpinBox
var _animation_constraint_min_fields: Array[SpinBox] = []
var _animation_constraint_max_fields: Array[SpinBox] = []
var _animation_constraint_enabled_check: CheckBox
var _animation_live_constraints_check: CheckBox
var _animation_active_constraint_id: String = ""
var _animation_curve_channel_option: OptionButton
var _animation_curve_editor: GMSAnimationCurveEditor
var _animation_root_motion_bone_option: OptionButton
var _animation_root_axis_x: CheckBox
var _animation_root_axis_y: CheckBox
var _animation_root_axis_z: CheckBox
var _animation_root_preview_in_place: CheckBox
var _animation_root_show_path: CheckBox
var _snap_button: Button
var _snap_element_option: OptionButton
var _snap_base_option: OptionButton
var _gizmo_buttons: Dictionary = {}
var _gizmo_visibility_button: Button
var _gizmo_orientation_option: OptionButton
var _pivot_option: OptionButton
var _xray_button: Button
var _proportional_button: Button
var _proportional_radius_spin: SpinBox
var _proportional_falloff_option: OptionButton
var _proportional_enabled: bool = false
var _last_edit_mode: GMSSelection.Mode = GMSSelection.Mode.VERTEX
var _last_selection_context_object_id: String = ""
var _last_selection_context_mode: int = -1

var _name_edit: LineEdit
var _visible_check: CheckBox
var _locked_check: CheckBox
var _position_fields: Array[SpinBox] = []
var _rotation_fields: Array[SpinBox] = []
var _scale_fields: Array[SpinBox] = []
var _material_slot_option: OptionButton
var _material_name_edit: LineEdit
var _material_add_button: Button
var _material_remove_button: Button
var _material_assign_button: Button
var _material_apply_button: Button
var _material_color: ColorPickerButton
var _metallic_spin: SpinBox
var _roughness_spin: SpinBox
var _texture_path_label: Label
var _load_texture_button: Button
var _clear_texture_button: Button
var _collision_type_option: OptionButton
var _collision_layer_spin: SpinBox
var _collision_mask_spin: SpinBox
var _collision_apply_button: Button

var _uv_projection_option: OptionButton
var _uv_project_button: Button
var _uv_offset_u: SpinBox
var _uv_offset_v: SpinBox
var _uv_scale_u: SpinBox
var _uv_scale_v: SpinBox
var _uv_rotation_spin: SpinBox
var _uv_transform_button: Button
var _uv_clear_button: Button
var _uv_status_label: Label
var _uv_preview: GMSUVPreview
var _uv_editor_button: Button
var _uv_mark_seam_button: Button
var _uv_clear_seam_button: Button
var _uv_unwrap_button: Button
var _uv_auto_unwrap_button: Button
var _uv_pack_button: Button
var _uv_auto_angle_spin: SpinBox
var _uv_editor_window: GMSUVEditorWindow
var _uv_checker_preview_object_id: String = ""
var _uv_live_preview_object_id: String = ""
var _uv_live_preview_original_mesh: GMSMeshData
var _uv_live_preview_was_dirty: bool = false

var _remesh_window: Window
var _remesh_resolution_spin: SpinBox
var _remesh_smooth_iterations_spin: SpinBox
var _remesh_smooth_strength_spin: SpinBox
var _remesh_projection_spin: SpinBox
var _remesh_density_levels_spin: SpinBox
var _remesh_region_option: OptionButton
var _remesh_boundary_padding_spin: SpinBox
var _remesh_output_option: OptionButton
var _remesh_guide_mode_option: OptionButton
var _remesh_guide_radius_spin: SpinBox
var _remesh_guide_strength_spin: SpinBox
var _remesh_guide_list: ItemList
var _remesh_draw_guide_button: Button
var _remesh_remove_guide_button: Button
var _remesh_clear_guides_button: Button
var _remesh_apply_button: Button
var _remesh_cancel_button: Button
var _remesh_progress: ProgressBar
var _remesh_progress_label: Label
var _remesh_warning_dialog: ConfirmationDialog
var _remesh_guides_by_object: Dictionary = {}
var _remesh_pending_guide_object_id: String = ""
var _remesh_waiting_for_surface_index_object_id: String = ""
var _remesh_task_id: int = -1
var _remesh_job: GMSRemeshJob
var _remesh_result_holder: Dictionary = {}
var _remesh_source_object_id: String = ""
var _remesh_source_signature: int = 0
var _remesh_output_duplicate: bool = true
var _remesh_poll_timer: Timer

var _background_operation_row: HBoxContainer
var _background_operation_label: Label
var _background_operation_progress: ProgressBar
var _background_operation_cancel_button: Button
var _background_operation_job: GMSBackgroundJob
var _background_operation_task_id: int = -1
var _background_operation_result_holder: Dictionary = {}
var _background_operation_completion: Callable = Callable()
var _background_operation_poll_timer: Timer
var _background_operation_title: String = ""
var _main_thread_operation_pending: bool = false
var _main_thread_operation_worker: Callable = Callable()
var _main_thread_operation_completion: Callable = Callable()
var _main_thread_operation_job: GMSBackgroundJob
var _main_thread_operation_title: String = ""
var _modifier_evaluation_object_id: String = ""

var _selection_label: Label
var _move_fields: Array[SpinBox] = []
var _component_scale_fields: Array[SpinBox] = []
var _move_selection_button: Button
var _scale_selection_button: Button
var _extrude_distance_spin: SpinBox
var _extrude_button: Button
var _inset_amount_spin: SpinBox
var _inset_button: Button
var _smooth_button: Button
var _flat_button: Button
var _make_face_button: Button
var _merge_button: Button
var _delete_components_button: Button
var _cleanup_button: Button
var _validate_topology_button: Button
var _flip_normals_button: Button
var _duplicate_geometry_button: Button
var _triangulate_button: Button
var _tris_to_quads_button: Button
var _recalculate_normals_button: Button
var _loop_cut_button: Button
var _loop_cut_count_spin: SpinBox
var _loop_cut_slide_spin: SpinBox
var _subdivide_button: Button
var _bevel_width_spin: SpinBox
var _bevel_edges_button: Button
var _bevel_vertices_button: Button
var _crease_weight_spin: SpinBox
var _crease_button: Button
var _dissolve_button: Button
var _bridge_button: Button
var _fill_holes_button: Button
var _knife_button: Button
var _separate_button: Button
var _join_button: Button
var _origin_to_geometry_button: Button
var _geometry_to_origin_button: Button
var _apply_rotation_scale_button: Button

var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _import_dialog: FileDialog
var _export_dialog: FileDialog
var _mesh_export_dialog: FileDialog
var _texture_dialog: FileDialog
var _modifier_add_option: OptionButton
var _modifier_add_button: Button
var _modifier_list: ItemList
var _modifier_name_edit: LineEdit
var _modifier_enabled_check: CheckBox
var _modifier_mirror_settings: VBoxContainer
var _modifier_mirror_x: CheckBox
var _modifier_mirror_y: CheckBox
var _modifier_mirror_z: CheckBox
var _modifier_merge_check: CheckBox
var _modifier_clipping_check: CheckBox
var _modifier_merge_distance: SpinBox
var _modifier_array_settings: VBoxContainer
var _modifier_array_count: SpinBox
var _modifier_array_offset_fields: Array[SpinBox] = []
var _modifier_solidify_settings: VBoxContainer
var _modifier_thickness: SpinBox
var _modifier_solidify_offset: SpinBox
var _modifier_subdivide_settings: VBoxContainer
var _modifier_subdivision_levels: SpinBox
var _modifier_subdivide_note: Label
var _modifier_bevel_settings: VBoxContainer
var _modifier_bevel_width: SpinBox
var _modifier_bevel_segments: SpinBox
var _modifier_decimate_settings: VBoxContainer
var _modifier_decimate_ratio: SpinBox
var _modifier_triangulate_settings: VBoxContainer
var _modifier_weighted_normal_settings: VBoxContainer
var _modifier_weighted_normal_strength: SpinBox
var _modifier_weighted_normal_power: SpinBox
var _modifier_weighted_normal_keep_sharp: CheckBox
var _modifier_displace_settings: VBoxContainer
var _modifier_displace_strength: SpinBox
var _modifier_displace_scale: SpinBox
var _modifier_displace_seed: SpinBox
var _modifier_displace_noise: CheckBox
var _modifier_displace_direction: OptionButton
var _modifier_bend_settings: VBoxContainer
var _modifier_bend_angle: SpinBox
var _modifier_bend_axis: OptionButton
var _modifier_smooth_settings: VBoxContainer
var _modifier_smooth_factor: SpinBox
var _modifier_smooth_iterations: SpinBox
var _modifier_smooth_preserve_boundary: CheckBox
var _modifier_custom_settings: VBoxContainer
var _modifier_custom_controls: Dictionary = {}
var _modifier_custom_active_id: String = ""
var _modifier_custom_option_ids: Dictionary = {}
var _modifier_type_help_label: Label
var _modifier_update_button: Button
var _modifier_remove_button: Button
var _modifier_up_button: Button
var _modifier_down_button: Button
var _modifier_apply_button: Button
var _selected_modifier_index: int = -1
var _modifier_preview_timer: Timer
var _modifier_preview_pending: bool = false
var _modifier_live_commit_active: bool = false
var _pending_modifier_object_id: String = ""
var _pending_modifier_index: int = -1
var _queued_modifier_apply_object_id: String = ""
var _queued_modifier_apply_index: int = -1
var _queued_modifier_apply_signature: int = 0

var _texture_target_object_id: String = ""
var _texture_target_material_index: int = -1
var _add_menu: PopupMenu
var _extension_tool_menu_ids: Dictionary = {}
var _extension_tool_dialog: ConfirmationDialog
var _extension_tool_controls: Dictionary = {}
var _extension_tool_id: String = ""
var _export_mesh_menu: PopupMenu
var _mesh_export_mode: int = MeshExportMode.ACTIVE_OBJECT
var _uv_menu: PopupMenu
var _help_menu_button: MenuButton
var _help_menu_opened: bool = false
var _hotkey_dialog: AcceptDialog
var _documentation_dialog: AcceptDialog
var _documentation_topic_list: ItemList
var _documentation_text: RichTextLabel
var _documentation_paths: PackedStringArray = PackedStringArray()
var _about_dialog: AcceptDialog
var _filesystem_refresh_timer: Timer
var _filesystem_refresh_pending: bool = false
var _filesystem_refresh_paths: Dictionary = {}
var _filesystem_memory_refresh_paths: Dictionary = {}
var _filesystem_reimporting: bool = false
var _filesystem_idle_since_msec: int = 0
var _filesystem_refresh_not_before_msec: int = 0
var _filesystem_scan_requested: bool = false
var _filesystem_scan_requested_msec: int = 0
var _filesystem_scan_attempts: int = 0

var _transform_active: bool = false
var _transform_kind: int = GMSModelViewport.TransformKind.NONE
var _transform_object_id: String = ""
var _transform_original_transform: Transform3D = Transform3D.IDENTITY
var _transform_object_ids: PackedStringArray = PackedStringArray()
var _transform_original_transforms: Array[Transform3D] = []
var _transform_original_mesh: GMSMeshData
var _transform_vertex_indices: PackedInt32Array = PackedInt32Array()
var _transform_proportional_weights: PackedFloat32Array = PackedFloat32Array()
var _transform_dynamic_preview: bool = false
var _transform_original_vertex_positions: PackedVector3Array = PackedVector3Array()
var _transform_preview_vertex_positions: PackedVector3Array = PackedVector3Array()
var _transform_vertex_weights: PackedFloat32Array = PackedFloat32Array()
var _transform_was_dirty: bool = false
var _transform_action_name: String = ""
var _transform_selection_mode: GMSSelection.Mode = GMSSelection.Mode.OBJECT
var _transform_selection_object_ids: PackedStringArray = PackedStringArray()
var _transform_selection_vertex_indices: PackedInt32Array = PackedInt32Array()
var _transform_selection_edge_indices: PackedInt32Array = PackedInt32Array()
var _transform_selection_face_indices: PackedInt32Array = PackedInt32Array()

var _scalar_tool_active: bool = false
var _scalar_tool_kind: String = ""
var _scalar_tool_object_id: String = ""
var _scalar_tool_original_mesh: GMSMeshData
var _scalar_tool_component_indices: PackedInt32Array = PackedInt32Array()
var _scalar_tool_was_dirty: bool = false


func configure_plugin_metadata(plugin_version: String, extension_api_version: int) -> void:
	_plugin_version = plugin_version.strip_edges()
	_extension_api_version = extension_api_version


func _ready() -> void:
	name = "Gator Model Studio"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_interface()
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	_first_activation_notice_pending = not bool(editor_settings.get_project_metadata(
		EDITOR_METADATA_SECTION,
		FIRST_ACTIVATION_NOTICE_METADATA_KEY,
		false
	))
	set_process(false)
	set_process_input(true)
	_modifier_preview_timer = Timer.new()
	_modifier_preview_timer.one_shot = true
	_modifier_preview_timer.wait_time = 0.04
	_modifier_preview_timer.timeout.connect(_flush_modifier_live_change)
	add_child(_modifier_preview_timer)
	_remesh_poll_timer = Timer.new()
	_remesh_poll_timer.wait_time = 0.05
	_remesh_poll_timer.timeout.connect(_poll_remesh_job)
	add_child(_remesh_poll_timer)
	_background_operation_poll_timer = Timer.new()
	_background_operation_poll_timer.wait_time = 0.05
	_background_operation_poll_timer.timeout.connect(_poll_background_operation)
	add_child(_background_operation_poll_timer)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SECONDS
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)
	_filesystem_refresh_timer = Timer.new()
	_filesystem_refresh_timer.one_shot = true
	_filesystem_refresh_timer.timeout.connect(_try_refresh_editor_filesystem)
	add_child(_filesystem_refresh_timer)
	_auto_export_retry_timer = Timer.new()
	_auto_export_retry_timer.one_shot = true
	_auto_export_retry_timer.wait_time = AUTO_EXPORT_RETRY_SECONDS
	_auto_export_retry_timer.timeout.connect(_on_auto_export_retry_timeout)
	add_child(_auto_export_retry_timer)
	_connect_editor_filesystem_signals()
	_sync_snap_settings()
	_sync_gizmo_settings()
	_on_proportional_toggled(false)
	_selection.changed.connect(_on_selection_changed)
	_history.changed.connect(_update_history_buttons)
	_create_new_document()
	_ensure_recovery_directory()
	_autosave_timer.start()
	visibility_changed.connect(_on_main_screen_visibility_changed)
	# Startup modal windows are intentionally delayed until GMS is actually
	# visible. Enabling an EditorPlugin commonly happens while Godot's plugin
	# management window is still active; opening another exclusive transient
	# window during that transaction can produce unstable native window state.
	call_deferred("_queue_startup_notices_if_visible")


func _on_main_screen_visibility_changed() -> void:
	_queue_startup_notices_if_visible()


func _queue_startup_notices_if_visible() -> void:
	if _startup_notices_started or _startup_notices_queued:
		return
	if not is_inside_tree() or not visible or not is_visible_in_tree():
		return
	_startup_notices_queued = true
	call_deferred("_run_startup_notices_after_editor_settles")


func _run_startup_notices_after_editor_settles() -> void:
	_startup_notices_queued = false
	if not is_inside_tree() or not visible or not is_visible_in_tree():
		return
	# Give the editor two complete frames after the GMS screen becomes visible.
	# This keeps recovery/welcome dialogs out of the plugin-enable transaction.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or not visible or not is_visible_in_tree():
		return
	_startup_notices_started = true
	_offer_recovery_if_available()
	if _recovery_dialog == null or not _recovery_dialog.visible:
		_show_first_activation_notice_if_ready()


func _input(event: InputEvent) -> void:
	if not visible or not is_visible_in_tree() or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		not key_event.pressed
		or key_event.echo
		or not key_event.ctrl_pressed
		or key_event.alt_pressed
		or key_event.keycode != KEY_S
	):
		return
	_last_local_save_shortcut_msec = Time.get_ticks_msec()
	get_viewport().set_input_as_handled()
	if key_event.shift_pressed:
		_on_save_as_pressed()
	else:
		request_save()


func _exit_tree() -> void:
	_stop_animation_playback()
	if _autosave_timer != null:
		_autosave_timer.stop()
	if _filesystem_refresh_timer != null:
		_filesystem_refresh_timer.stop()
	if _auto_export_retry_timer != null:
		_auto_export_retry_timer.stop()
	_filesystem_refresh_paths.clear()
	_filesystem_memory_refresh_paths.clear()
	_disconnect_editor_filesystem_signals()
	if _remesh_job != null:
		_remesh_job.request_cancel()
	if _background_operation_job != null:
		_background_operation_job.request_cancel()
	if _main_thread_operation_job != null:
		_main_thread_operation_job.request_cancel()
	_main_thread_operation_pending = false
	if _remesh_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_remesh_task_id)
		_remesh_task_id = -1
	if _background_operation_task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_background_operation_task_id)
		_background_operation_task_id = -1
	if _document != null:
		for object: GMSModelObject in _document.objects:
			if object == null:
				continue
			var evaluation_state: Dictionary = object.get_async_evaluation_state()
			if bool(evaluation_state.get("running", false)):
				object.cancel_async_evaluation()
		for object: GMSModelObject in _document.objects:
			if object != null:
				object.finish_async_evaluation()


func has_unsaved_changes() -> bool:
	return _is_dirty


func save_external_data() -> void:
	# Ctrl+S is handled directly while the GMS main screen is visible. Godot may
	# still invoke EditorPlugin._save_external_data() during the same editor save
	# cycle, so ignore that duplicate callback instead of saving/exporting twice.
	if Time.get_ticks_msec() - _last_local_save_shortcut_msec <= LOCAL_SAVE_EXTERNAL_SUPPRESSION_MSEC:
		return
	if not _current_path.is_empty():
		_save_document(_current_path)
	elif _is_dirty:
		_write_recovery_copy(true)


func save_recovery_copy() -> void:
	if _is_dirty:
		_write_recovery_copy(true)


func request_save() -> void:
	_cancel_active_transform()
	if _current_path.is_empty():
		_show_save_dialog(false)
	else:
		_save_document(_current_path)


func _build_interface() -> void:
	add_child(_build_toolbar())

	var workspace_split: VSplitContainer = VSplitContainer.new()
	workspace_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_split.split_offset = -230
	add_child(workspace_split)

	var main_split: HSplitContainer = HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.split_offset = -380
	workspace_split.add_child(main_split)

	var viewport_area: HBoxContainer = HBoxContainer.new()
	viewport_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_area.add_theme_constant_override("separation", 0)
	viewport_area.add_child(_build_left_tool_shelf())

	_viewport = GMSModelViewport.new()
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport.selection_clicked.connect(_on_viewport_selection_clicked)
	_viewport.box_selection_requested.connect(_on_viewport_box_selection_requested)
	_viewport.box_object_selection_requested.connect(_on_viewport_box_object_selection_requested)
	_viewport.shortcut_requested.connect(_on_viewport_shortcut_requested)
	_viewport.transform_preview.connect(_on_viewport_transform_preview)
	_viewport.transform_committed.connect(_on_viewport_transform_committed)
	_viewport.transform_cancelled.connect(_on_viewport_transform_cancelled)
	_viewport.transform_status_changed.connect(_on_viewport_transform_status_changed)
	_viewport.snap_toggled.connect(_on_viewport_snap_toggled)
	_viewport.gizmo_transform_requested.connect(_on_viewport_gizmo_transform_requested)
	_viewport.knife_cut_requested.connect(_on_viewport_knife_cut_requested)
	_viewport.remesh_guide_stroke_completed.connect(_on_remesh_guide_stroke_completed)
	_viewport.remesh_guide_drawing_cancelled.connect(_on_remesh_guide_drawing_cancelled)
	_viewport.xray_toggled.connect(_on_viewport_xray_toggled)
	_viewport.scalar_adjust_preview.connect(_on_viewport_scalar_adjust_preview)
	_viewport.scalar_adjust_committed.connect(_on_viewport_scalar_adjust_committed)
	_viewport.scalar_adjust_cancelled.connect(_on_viewport_scalar_adjust_cancelled)
	_viewport.async_evaluation_completed.connect(_on_async_evaluation_completed)
	_viewport.rig_bone_clicked.connect(_on_viewport_rig_bone_clicked)
	_viewport.rig_bone_endpoint_dragged.connect(_on_viewport_rig_bone_endpoint_dragged)
	_viewport.rig_weight_brush_requested.connect(_on_viewport_rig_weight_brush_requested)
	_viewport.animation_bone_transform_preview.connect(_on_viewport_animation_bone_transform_preview)
	_viewport.animation_bone_transform_committed.connect(_on_viewport_animation_bone_transform_committed)
	_viewport.animation_bone_transform_cancelled.connect(_on_viewport_animation_bone_transform_cancelled)
	_viewport.animation_ik_target_transform_preview.connect(_on_viewport_animation_ik_target_transform_preview)
	_viewport.animation_ik_target_transform_committed.connect(_on_viewport_animation_ik_target_transform_committed)
	_viewport.animation_ik_target_transform_cancelled.connect(_on_viewport_animation_ik_target_transform_cancelled)
	_viewport.animation_ik_control_selected.connect(_on_viewport_animation_ik_control_selected)
	viewport_area.add_child(_viewport)
	main_split.add_child(viewport_area)

	var right_split: VSplitContainer = VSplitContainer.new()
	right_split.custom_minimum_size.x = 300.0
	right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_split.split_offset = 190
	right_split.add_child(_build_outliner_panel())
	right_split.add_child(_build_properties_panel())
	main_split.add_child(right_split)

	_animation_timeline_panel = _build_animation_timeline_panel()
	_animation_timeline_panel.visible = false
	workspace_split.add_child(_animation_timeline_panel)

	var status_panel: PanelContainer = PanelContainer.new()
	var status_column: VBoxContainer = VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 4)
	status_panel.add_child(status_column)
	var status_row: HBoxContainer = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 16)
	status_column.add_child(status_row)
	_document_label = Label.new()
	_document_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_document_label)
	_status_label = Label.new()
	status_row.add_child(_status_label)

	_background_operation_row = HBoxContainer.new()
	_background_operation_row.add_theme_constant_override("separation", 8)
	_background_operation_row.visible = false
	status_column.add_child(_background_operation_row)
	_background_operation_label = Label.new()
	_background_operation_label.custom_minimum_size.x = 190.0
	_background_operation_row.add_child(_background_operation_label)
	_background_operation_progress = ProgressBar.new()
	_background_operation_progress.min_value = 0.0
	_background_operation_progress.max_value = 100.0
	_background_operation_progress.show_percentage = true
	_background_operation_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_background_operation_row.add_child(_background_operation_progress)
	_background_operation_cancel_button = Button.new()
	_background_operation_cancel_button.text = "Cancel"
	_background_operation_cancel_button.pressed.connect(_on_background_operation_cancel_pressed)
	_background_operation_row.add_child(_background_operation_cancel_button)
	add_child(status_panel)

	_build_file_dialogs()
	_build_document_safety_dialogs()
	_build_first_activation_notice_dialog()
	_build_add_menu()
	_build_export_mesh_menu()
	_build_uv_menu()
	_build_hotkey_dialog()
	_build_documentation_dialog()
	_build_about_dialog()
	_build_uv_editor_window()
	_build_remesh_window()

func _build_toolbar() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	# Flow containers prevent the toolbar from imposing its full one-line width
	# on Godot's editor. Groups wrap onto another line when the center workspace
	# is narrow instead of pushing the Inspector and other editor docks off-screen.
	var main_flow: HFlowContainer = HFlowContainer.new()
	main_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_flow.add_theme_constant_override("h_separation", 6)
	main_flow.add_theme_constant_override("v_separation", 4)
	column.add_child(main_flow)

	var file_group: HBoxContainer = HBoxContainer.new()
	file_group.add_theme_constant_override("separation", 4)
	main_flow.add_child(file_group)
	_add_toolbar_button(file_group, "New", _on_new_pressed, "Create a new model document")
	_add_toolbar_button(file_group, "Open", _on_open_pressed, "Open a .tres model document")
	_add_toolbar_button(file_group, "Save", _on_save_pressed, "Save the current model document")
	_add_toolbar_button(file_group, "Save As", _on_save_as_pressed, "Save a new copy and continue editing that copy (Ctrl+Shift+S)")

	var import_group: HBoxContainer = HBoxContainer.new()
	import_group.add_theme_constant_override("separation", 4)
	main_flow.add_child(import_group)
	_add_toolbar_button(import_group, "Import", _on_import_pressed, "Convert a Godot Mesh resource or scene into editable geometry")
	_add_toolbar_button(import_group, "Import Selected", _on_import_selected_pressed, "Convert selected MeshInstance3D nodes from the edited scene")

	var export_group: HBoxContainer = HBoxContainer.new()
	export_group.add_theme_constant_override("separation", 4)
	main_flow.add_child(export_group)
	_add_toolbar_button(export_group, "Export Scene", _on_export_pressed, "Export the complete document")
	_add_toolbar_button(export_group, "Export Mesh", _on_export_mesh_pressed, "Export active or selected geometry")
	_auto_export_on_save_check = CheckBox.new()
	_auto_export_on_save_check.text = "Auto Export on Save"
	_auto_export_on_save_check.tooltip_text = "After a successful scene export, automatically export to that same path whenever this document is saved"
	_auto_export_on_save_check.toggled.connect(_on_auto_export_on_save_toggled)
	export_group.add_child(_auto_export_on_save_check)

	var edit_group: HBoxContainer = HBoxContainer.new()
	edit_group.add_theme_constant_override("separation", 4)
	main_flow.add_child(edit_group)
	_add_toolbar_button(edit_group, "Add", _popup_add_menu, "Add a primitive or extension tool (Shift+A)")
	_undo_button = _add_toolbar_button(edit_group, "Undo", _on_undo_pressed, "Undo the latest modelling action")
	_redo_button = _add_toolbar_button(edit_group, "Redo", _on_redo_pressed, "Redo the latest modelling action")

	var mode_controls: HBoxContainer = HBoxContainer.new()
	mode_controls.add_theme_constant_override("separation", 4)
	main_flow.add_child(mode_controls)
	var mode_label: Label = Label.new()
	mode_label.text = "Mode"
	mode_controls.add_child(mode_label)
	var mode_group: ButtonGroup = ButtonGroup.new()
	_add_mode_button(mode_controls, "Object", GMSSelection.Mode.OBJECT, mode_group)
	_add_mode_button(mode_controls, "1 Vertex", GMSSelection.Mode.VERTEX, mode_group)
	_add_mode_button(mode_controls, "2 Edge", GMSSelection.Mode.EDGE, mode_group)
	_add_mode_button(mode_controls, "3 Face", GMSSelection.Mode.FACE, mode_group)
	_rig_mode_button = Button.new()
	_rig_mode_button.text = "Rig"
	_rig_mode_button.toggle_mode = true
	_rig_mode_button.button_group = mode_group
	_rig_mode_button.tooltip_text = "Rig mode: armature editing, automatic weights, correction tools, and pose preview"
	_rig_mode_button.pressed.connect(_on_rig_mode_pressed)
	mode_controls.add_child(_rig_mode_button)
	_animate_mode_button = Button.new()
	_animate_mode_button.text = "Animate"
	_animate_mode_button.toggle_mode = true
	_animate_mode_button.button_group = mode_group
	_animate_mode_button.tooltip_text = "Animate mode: bone posing, automatic keying, pose tools, and clip timeline"
	_animate_mode_button.pressed.connect(_on_animate_mode_pressed)
	mode_controls.add_child(_animate_mode_button)

	var help_group: HBoxContainer = HBoxContainer.new()
	main_flow.add_child(help_group)
	_build_help_menu_button(help_group)

	var settings_flow: HFlowContainer = HFlowContainer.new()
	settings_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_flow.add_theme_constant_override("h_separation", 6)
	settings_flow.add_theme_constant_override("v_separation", 4)
	column.add_child(settings_flow)

	var gizmo_group: HBoxContainer = HBoxContainer.new()
	gizmo_group.add_theme_constant_override("separation", 4)
	settings_flow.add_child(gizmo_group)
	_gizmo_visibility_button = Button.new()
	_gizmo_visibility_button.text = "Gizmo"
	_gizmo_visibility_button.toggle_mode = true
	_gizmo_visibility_button.button_pressed = true
	_gizmo_visibility_button.tooltip_text = "Show transform handles for the active tool"
	_gizmo_visibility_button.toggled.connect(_on_gizmo_visibility_toggled)
	gizmo_group.add_child(_gizmo_visibility_button)

	_gizmo_orientation_option = OptionButton.new()
	_gizmo_orientation_option.tooltip_text = "Transform orientation"
	_gizmo_orientation_option.add_item("Global", GMSTransformGizmo.Orientation.GLOBAL)
	_gizmo_orientation_option.add_item("Local", GMSTransformGizmo.Orientation.LOCAL)
	_gizmo_orientation_option.item_selected.connect(_on_gizmo_orientation_selected)
	gizmo_group.add_child(_gizmo_orientation_option)

	_pivot_option = OptionButton.new()
	_pivot_option.tooltip_text = "Transform pivot"
	_pivot_option.add_item("Median", GMSModelViewport.PivotMode.MEDIAN)
	_pivot_option.add_item("Active", GMSModelViewport.PivotMode.ACTIVE)
	_pivot_option.add_item("Origin", GMSModelViewport.PivotMode.OBJECT_ORIGIN)
	_pivot_option.add_item("Individual", GMSModelViewport.PivotMode.INDIVIDUAL_ORIGINS)
	_pivot_option.item_selected.connect(_on_pivot_selected)
	gizmo_group.add_child(_pivot_option)

	var snap_group: HBoxContainer = HBoxContainer.new()
	snap_group.add_theme_constant_override("separation", 4)
	settings_flow.add_child(snap_group)
	_snap_button = Button.new()
	_snap_button.text = "Snap"
	_snap_button.toggle_mode = true
	_snap_button.tooltip_text = "Toggle transform snapping (Shift+Tab)"
	_snap_button.toggled.connect(_on_snap_toggled)
	snap_group.add_child(_snap_button)

	_snap_element_option = OptionButton.new()
	_snap_element_option.tooltip_text = "Transform snap element"
	_snap_element_option.add_item("Increment", GMSModelViewport.SnapElement.INCREMENT)
	_snap_element_option.add_item("Vertex", GMSModelViewport.SnapElement.VERTEX)
	_snap_element_option.item_selected.connect(_on_snap_element_selected)
	snap_group.add_child(_snap_element_option)

	_snap_base_option = OptionButton.new()
	_snap_base_option.tooltip_text = "Selected point placed on the snap target"
	_snap_base_option.add_item("Closest", GMSSnapMath.BaseMode.CLOSEST)
	_snap_base_option.add_item("Center", GMSSnapMath.BaseMode.CENTER)
	_snap_base_option.add_item("Median", GMSSnapMath.BaseMode.MEDIAN)
	_snap_base_option.add_item("Active", GMSSnapMath.BaseMode.ACTIVE)
	_snap_base_option.item_selected.connect(_on_snap_base_selected)
	snap_group.add_child(_snap_base_option)

	var display_group: HBoxContainer = HBoxContainer.new()
	display_group.add_theme_constant_override("separation", 4)
	settings_flow.add_child(display_group)
	_xray_button = Button.new()
	_xray_button.text = "X-Ray"
	_xray_button.toggle_mode = true
	_xray_button.tooltip_text = "Select through the mesh (Alt+Z)"
	_xray_button.toggled.connect(_on_xray_toggled)
	display_group.add_child(_xray_button)

	_proportional_button = Button.new()
	_proportional_button.text = "Proportional"
	_proportional_button.toggle_mode = true
	_proportional_button.tooltip_text = "Proportional editing (O)"
	_proportional_button.toggled.connect(_on_proportional_toggled)
	display_group.add_child(_proportional_button)

	_proportional_radius_spin = _make_spin_box(0.01, 10000.0, 0.1)
	_proportional_radius_spin.value = 2.0
	_proportional_radius_spin.prefix = "Radius "
	_proportional_radius_spin.tooltip_text = "Proportional editing radius"
	display_group.add_child(_proportional_radius_spin)

	_proportional_falloff_option = OptionButton.new()
	_proportional_falloff_option.tooltip_text = "Proportional editing falloff"
	_proportional_falloff_option.add_item("Smooth", GMSAdvancedMeshOperations.ProportionalFalloff.SMOOTH)
	_proportional_falloff_option.add_item("Sphere", GMSAdvancedMeshOperations.ProportionalFalloff.SPHERE)
	_proportional_falloff_option.add_item("Root", GMSAdvancedMeshOperations.ProportionalFalloff.ROOT)
	_proportional_falloff_option.add_item("Linear", GMSAdvancedMeshOperations.ProportionalFalloff.LINEAR)
	_proportional_falloff_option.add_item("Constant", GMSAdvancedMeshOperations.ProportionalFalloff.CONSTANT)
	_proportional_falloff_option.add_item("Sharp", GMSAdvancedMeshOperations.ProportionalFalloff.SHARP)
	display_group.add_child(_proportional_falloff_option)

	var selection_group: HBoxContainer = HBoxContainer.new()
	selection_group.add_theme_constant_override("separation", 4)
	settings_flow.add_child(selection_group)
	_add_toolbar_button(selection_group, "Select All", _on_select_all_pressed, "Select all components (A)")
	_add_toolbar_button(selection_group, "Clear", _on_clear_selection_pressed, "Clear component selection (Alt+A)")
	_add_toolbar_button(selection_group, "Invert", _on_invert_selection_pressed, "Invert component selection (Ctrl+I)")
	_add_toolbar_button(selection_group, "Frame", _on_frame_pressed, "Frame selected (Numpad .)")

	return panel


func _build_help_menu_button(parent: Control) -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	_help_menu_opened = bool(editor_settings.get_project_metadata(
		EDITOR_METADATA_SECTION,
		HELP_OPENED_METADATA_KEY,
		false
	))
	_help_menu_button = MenuButton.new()
	_help_menu_button.icon = _get_ui_icon("book")
	_help_menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_help_menu_button.add_theme_constant_override("icon_max_width", 16)
	_help_menu_button.tooltip_text = (
		"Help and documentation for modelling, materials, UVs, rigging, IK, "
		+ "animation, remeshing, hotkeys, bug reports, Donate, and About"
	)
	_help_menu_button.about_to_popup.connect(_on_help_menu_about_to_popup)
	var popup: PopupMenu = _help_menu_button.get_popup()
	popup.add_item("Documentation", HELP_MENU_DOCUMENTATION)
	popup.add_item("Hotkeys", HELP_MENU_HOTKEYS)
	popup.add_separator()
	popup.add_item("Report a Bug", HELP_MENU_REPORT_BUG)
	popup.add_item("Donate", HELP_MENU_DONATE)
	popup.add_separator()
	popup.add_item("About Gator Model Studio", HELP_MENU_ABOUT)
	popup.id_pressed.connect(_on_help_menu_id_pressed)
	parent.add_child(_help_menu_button)
	_refresh_help_menu_button()


func _on_help_menu_about_to_popup() -> void:
	if _help_menu_opened:
		return
	_help_menu_opened = true
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	editor_settings.set_project_metadata(
		EDITOR_METADATA_SECTION,
		HELP_OPENED_METADATA_KEY,
		true
	)
	_refresh_help_menu_button()


func _refresh_help_menu_button() -> void:
	if _help_menu_button == null:
		return
	var accent_color: Color = _get_editor_accent_color()
	var normal_background: Color
	var hover_background: Color
	var pressed_background: Color
	var border_color: Color
	var border_width: int
	if _help_menu_opened:
		_help_menu_button.text = "Help"
		normal_background = accent_color.darkened(0.82)
		hover_background = accent_color.darkened(0.68)
		pressed_background = accent_color.darkened(0.58)
		border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.58)
		border_width = 1
	else:
		_help_menu_button.text = "Help  NEW"
		normal_background = accent_color.darkened(0.68)
		hover_background = accent_color.darkened(0.52)
		pressed_background = accent_color.darkened(0.42)
		border_color = Color(accent_color.r, accent_color.g, accent_color.b, 1.0)
		border_width = 2
	_help_menu_button.add_theme_stylebox_override(
		"normal",
		_make_help_button_style(normal_background, border_color, border_width)
	)
	_help_menu_button.add_theme_stylebox_override(
		"hover",
		_make_help_button_style(hover_background, border_color, border_width)
	)
	_help_menu_button.add_theme_stylebox_override(
		"pressed",
		_make_help_button_style(pressed_background, border_color, border_width)
	)
	_help_menu_button.add_theme_stylebox_override(
		"focus",
		_make_help_button_style(hover_background, border_color, border_width)
	)
	_help_menu_button.add_theme_color_override("font_color", Color.WHITE)
	_help_menu_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_help_menu_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_help_menu_button.add_theme_color_override("icon_normal_color", Color.WHITE)
	_help_menu_button.add_theme_color_override("icon_hover_color", Color.WHITE)
	_help_menu_button.add_theme_color_override("icon_pressed_color", Color.WHITE)


func _make_help_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _get_editor_accent_color() -> Color:
	var fallback_color: Color = Color(0.48, 0.36, 0.84, 1.0)
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if not editor_settings.has_setting("interface/theme/accent_color"):
		return fallback_color
	var setting_value: Variant = editor_settings.get_setting("interface/theme/accent_color")
	if typeof(setting_value) != TYPE_COLOR:
		return fallback_color
	var accent_color: Color = setting_value
	return accent_color

func _build_left_tool_shelf() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 56.0
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# The full tool shelf is taller than a small editor window. Keep every tool
	# available without forcing Godot's bottom panel below the window.
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	scroll.add_child(column)

	_add_icon_tool_button(column, "select", "Box Select (B)", _on_box_select_pressed)
	column.add_child(HSeparator.new())

	var gizmo_group: ButtonGroup = ButtonGroup.new()
	_add_gizmo_icon_button(column, "move", GMSModelViewport.TransformKind.MOVE, gizmo_group, "Move tool (G)")
	_add_gizmo_icon_button(column, "rotate", GMSModelViewport.TransformKind.ROTATE, gizmo_group, "Rotate tool (R)")
	_add_gizmo_icon_button(column, "scale", GMSModelViewport.TransformKind.SCALE, gizmo_group, "Scale tool (S)")
	column.add_child(HSeparator.new())

	_add_icon_tool_button(column, "extrude", "Extrude selection (E)", _on_extrude_pressed)
	_add_icon_tool_button(column, "inset", "Inset selected face (I)", _on_inset_face_pressed)
	_add_icon_tool_button(column, "bevel", "Bevel selected edges or vertices (Ctrl+B)", _on_bevel_tool_pressed)
	_add_icon_tool_button(column, "loop_cut", "Loop cut (Ctrl+R)", _on_loop_cut_pressed)
	_add_icon_tool_button(column, "knife", "Knife cut (K)", _on_knife_pressed)
	column.add_child(HSeparator.new())
	_add_icon_tool_button(column, "remesh", "Guided voxel remesh", _on_remesh_pressed)

	return panel

func _add_mode_button(
	parent: Control,
	text: String,
	mode: GMSSelection.Mode,
	group: ButtonGroup
) -> void:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(_on_mode_pressed.bind(mode))
	button.tooltip_text = "%s selection mode" % text
	button.button_pressed = mode == GMSSelection.Mode.OBJECT
	parent.add_child(button)
	_mode_buttons[mode] = button


func _add_gizmo_button(
	parent: Control,
	text: String,
	kind: int,
	group: ButtonGroup
) -> void:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.tooltip_text = "%s XYZ handle. G/R/S still start Blender-style modal transforms." % text
	button.pressed.connect(_on_gizmo_mode_pressed.bind(kind))
	button.button_pressed = kind == GMSModelViewport.TransformKind.MOVE
	parent.add_child(button)
	_gizmo_buttons[kind] = button


func _add_icon_tool_button(
	parent: Control,
	icon_name: String,
	tooltip: String,
	callback: Callable
) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(40.0, 40.0)
	button.icon = _get_ui_icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 20)
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_gizmo_icon_button(
	parent: Control,
	icon_name: String,
	kind: int,
	group: ButtonGroup,
	tooltip: String
) -> Button:
	var button: Button = _add_icon_tool_button(
		parent,
		icon_name,
		tooltip,
		_on_gizmo_mode_pressed.bind(kind)
	)
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = kind == GMSModelViewport.TransformKind.MOVE
	_gizmo_buttons[kind] = button
	return button


func _get_ui_icon(icon_name: String) -> Texture2D:
	return load("%s/%s.svg" % [UI_ICON_ROOT, icon_name]) as Texture2D


func _build_outliner_panel() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(240.0, 72.0)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "Outliner"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	_outliner = Tree.new()
	_outliner.hide_root = true
	_outliner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outliner.item_selected.connect(_on_outliner_selected)
	column.add_child(_outliner)


	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_child(_make_button("Duplicate", _on_duplicate_pressed))
	_join_button = _make_button("Join", _on_join_objects_pressed)
	_join_button.tooltip_text = "Object mode: Shift-click at least two objects in the viewport, then press Join or Ctrl+J. The last selected object stays active; other modifier results are baked into it."
	actions.add_child(_join_button)
	actions.add_child(_make_button("Delete", _on_delete_pressed))
	column.add_child(actions)
	return panel


func _build_properties_panel() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 280.0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	_model_properties_root = VBoxContainer.new()
	_model_properties_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_properties_root.add_theme_constant_override("separation", 8)
	content.add_child(_model_properties_root)
	var column: VBoxContainer = _model_properties_root

	column.add_child(_section_title("Object"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Object name"
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(_on_name_focus_exited)
	column.add_child(_labelled_control("Name", _name_edit))

	_visible_check = CheckBox.new()
	_visible_check.text = "Visible"
	_visible_check.toggled.connect(_on_visible_toggled)
	column.add_child(_visible_check)
	_locked_check = CheckBox.new()
	_locked_check.text = "Locked"
	_locked_check.toggled.connect(_on_locked_toggled)
	column.add_child(_locked_check)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Transform"))
	_position_fields = _make_vector_editor(column, "Position", -100000.0, 100000.0, 0.1)
	_rotation_fields = _make_vector_editor(column, "Rotation", -36000.0, 36000.0, 1.0)
	_scale_fields = _make_vector_editor(column, "Scale", -1000.0, 1000.0, 0.05)
	var apply_transform: Button = _make_button("Set Object Transform", _on_apply_transform_pressed)
	apply_transform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(apply_transform)

	var origin_row: HBoxContainer = HBoxContainer.new()
	_origin_to_geometry_button = _make_button("Origin to Geometry", _on_origin_to_geometry_pressed)
	_origin_to_geometry_button.tooltip_text = "Move the object origin to the mesh centre without moving the visible model. Example: centre the rotation pivot after modelling off-centre."
	_origin_to_geometry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	origin_row.add_child(_origin_to_geometry_button)
	_geometry_to_origin_button = _make_button("Geometry to Origin", _on_geometry_to_origin_pressed)
	_geometry_to_origin_button.tooltip_text = "Move mesh vertices so their centre sits at the current object origin."
	_geometry_to_origin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	origin_row.add_child(_geometry_to_origin_button)
	column.add_child(origin_row)

	_apply_rotation_scale_button = _make_button("Apply Rotation & Scale", _on_apply_rotation_scale_pressed)
	_apply_rotation_scale_button.tooltip_text = "Bake rotation and scale into mesh vertices. The model intentionally looks unchanged; Rotation resets to 0 and Scale resets to 1. Useful before bevel, mirror, or export."
	_apply_rotation_scale_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_apply_rotation_scale_button)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Collision"))
	var collision_note: Label = Label.new()
	collision_note.text = "Generated collision is included when exporting a Godot scene."
	collision_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(collision_note)
	_collision_type_option = OptionButton.new()
	_collision_type_option.add_item("None", GMSModelObject.CollisionType.NONE)
	_collision_type_option.add_item("Trimesh (Static Only)", GMSModelObject.CollisionType.TRIMESH)
	_collision_type_option.add_item("Convex", GMSModelObject.CollisionType.CONVEX)
	_collision_type_option.add_item("Box", GMSModelObject.CollisionType.BOX)
	_collision_type_option.add_item("Sphere", GMSModelObject.CollisionType.SPHERE)
	_collision_type_option.add_item("Capsule", GMSModelObject.CollisionType.CAPSULE)
	_collision_type_option.tooltip_text = "Trimesh follows the evaluated mesh exactly and is intended for static level geometry. Convex and primitive shapes are suitable for moving physics bodies after export."
	column.add_child(_labelled_control("Shape", _collision_type_option))
	var collision_layers_row: HBoxContainer = HBoxContainer.new()
	_collision_layer_spin = _make_spin_box(1.0, 32.0, 1.0)
	_collision_layer_spin.value = 1.0
	_collision_layer_spin.rounded = true
	_collision_layer_spin.prefix = "Layer "
	_collision_layer_spin.tooltip_text = "Single Godot physics layer used by the exported StaticBody3D"
	_collision_layer_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collision_layers_row.add_child(_collision_layer_spin)
	_collision_mask_spin = _make_spin_box(1.0, 32.0, 1.0)
	_collision_mask_spin.value = 1.0
	_collision_mask_spin.rounded = true
	_collision_mask_spin.prefix = "Mask "
	_collision_mask_spin.tooltip_text = "Single Godot physics layer detected by the exported StaticBody3D"
	_collision_mask_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collision_layers_row.add_child(_collision_mask_spin)
	column.add_child(collision_layers_row)
	_collision_apply_button = _make_button("Apply Collision Settings", _on_apply_collision_pressed)
	_collision_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_collision_apply_button)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Modifiers"))
	var modifier_note: Label = Label.new()
	modifier_note.text = "Non-destructive modifiers are evaluated from top to bottom, update live, and are included in scene export."
	modifier_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(modifier_note)

	var modifier_add_row: HBoxContainer = HBoxContainer.new()
	_modifier_add_option = OptionButton.new()
	_modifier_add_option.add_item("Mirror", GMSModifier.Kind.MIRROR)
	_modifier_add_option.add_item("Array", GMSModifier.Kind.ARRAY)
	_modifier_add_option.add_item("Solidify", GMSModifier.Kind.SOLIDIFY)
	_modifier_add_option.add_item("Simple Subdivide", GMSModifier.Kind.SIMPLE_SUBDIVIDE)
	_modifier_add_option.add_item("Subdivision Surface", GMSModifier.Kind.SUBDIVISION_SURFACE)
	_modifier_add_option.add_item("Bevel", GMSModifier.Kind.BEVEL)
	_modifier_add_option.add_item("Decimate", GMSModifier.Kind.DECIMATE)
	_modifier_add_option.add_item("Triangulate", GMSModifier.Kind.TRIANGULATE)
	_modifier_add_option.add_item("Weighted Normal", GMSModifier.Kind.WEIGHTED_NORMAL)
	_modifier_add_option.add_item("Displace", GMSModifier.Kind.DISPLACE)
	_modifier_add_option.add_item("Bend", GMSModifier.Kind.BEND)
	_modifier_add_option.add_item("Smooth", GMSModifier.Kind.SMOOTH)
	for option_index: int in _modifier_add_option.item_count:
		var option_kind: int = _modifier_add_option.get_item_id(option_index)
		_modifier_add_option.set_item_tooltip(
			option_index,
			GMSModifier.kind_to_tooltip(option_kind)
		)
	var custom_option_id: int = 1000
	for descriptor: Dictionary in GMSModifierRegistry.get_modifiers():
		_modifier_add_option.add_item(str(descriptor.get("name", "Extension Modifier")), custom_option_id)
		_modifier_add_option.set_item_tooltip(
			_modifier_add_option.item_count - 1,
			str(descriptor.get("tooltip", "Custom extension modifier."))
		)
		_modifier_custom_option_ids[custom_option_id] = str(descriptor.get("id", ""))
		custom_option_id += 1
	_modifier_add_option.item_selected.connect(_on_modifier_add_type_selected)
	_modifier_add_option.tooltip_text = GMSModifier.kind_to_tooltip(GMSModifier.Kind.MIRROR)
	_modifier_add_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_add_row.add_child(_modifier_add_option)
	_modifier_add_button = _make_button("Add", _on_add_modifier_pressed)
	_modifier_add_button.tooltip_text = "Add a non-destructive modifier to the selected object"
	modifier_add_row.add_child(_modifier_add_button)
	column.add_child(modifier_add_row)

	_modifier_type_help_label = Label.new()
	_modifier_type_help_label.text = GMSModifier.kind_to_tooltip(GMSModifier.Kind.MIRROR)
	_modifier_type_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_type_help_label.tooltip_text = "The first line explains the modifier. The second line gives a common use."
	column.add_child(_modifier_type_help_label)

	_modifier_list = ItemList.new()
	_modifier_list.custom_minimum_size.y = 105.0
	_modifier_list.select_mode = ItemList.SELECT_SINGLE
	_modifier_list.item_selected.connect(_on_modifier_selected)
	column.add_child(_modifier_list)

	var modifier_order_row: HBoxContainer = HBoxContainer.new()
	_modifier_up_button = _make_button("Up", _on_modifier_up_pressed)
	_modifier_up_button.tooltip_text = "Move the selected modifier earlier in the stack"
	_modifier_up_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_order_row.add_child(_modifier_up_button)
	_modifier_down_button = _make_button("Down", _on_modifier_down_pressed)
	_modifier_down_button.tooltip_text = "Move the selected modifier later in the stack"
	_modifier_down_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_order_row.add_child(_modifier_down_button)
	_modifier_remove_button = _make_button("Remove", _on_modifier_remove_pressed)
	_modifier_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_order_row.add_child(_modifier_remove_button)
	column.add_child(modifier_order_row)

	_modifier_name_edit = LineEdit.new()
	_modifier_name_edit.placeholder_text = "Modifier name"
	column.add_child(_labelled_control("Name", _modifier_name_edit))
	_modifier_enabled_check = CheckBox.new()
	_modifier_enabled_check.text = "Enabled in viewport and export"
	column.add_child(_modifier_enabled_check)

	_modifier_mirror_settings = VBoxContainer.new()
	var mirror_axis_row: HBoxContainer = HBoxContainer.new()
	_modifier_mirror_x = CheckBox.new()
	_modifier_mirror_x.text = "X"
	mirror_axis_row.add_child(_modifier_mirror_x)
	_modifier_mirror_y = CheckBox.new()
	_modifier_mirror_y.text = "Y"
	mirror_axis_row.add_child(_modifier_mirror_y)
	_modifier_mirror_z = CheckBox.new()
	_modifier_mirror_z.text = "Z"
	mirror_axis_row.add_child(_modifier_mirror_z)
	_modifier_mirror_settings.add_child(_labelled_control("Axes", mirror_axis_row))
	_modifier_merge_check = CheckBox.new()
	_modifier_merge_check.text = "Merge vertices on mirror planes"
	_modifier_merge_check.tooltip_text = "Welds the original and mirrored results when their vertices are within Merge Distance of an enabled mirror plane."
	_modifier_mirror_settings.add_child(_modifier_merge_check)
	_modifier_clipping_check = CheckBox.new()
	_modifier_clipping_check.text = "Clipping: keep seam vertices on the mirror plane"
	_modifier_clipping_check.tooltip_text = "Snaps vertices within the merge distance to the mirror plane and prevents them crossing it while transforming."
	_modifier_mirror_settings.add_child(_modifier_clipping_check)
	_modifier_merge_distance = _make_spin_box(0.000001, 10.0, 0.0001)
	_modifier_merge_distance.value = 0.001
	_modifier_merge_distance.tooltip_text = "Maximum distance from a mirror plane at which evaluated seam vertices weld. Clipping uses the same threshold."
	_modifier_mirror_settings.add_child(_labelled_control("Merge Distance", _modifier_merge_distance))
	column.add_child(_modifier_mirror_settings)

	_modifier_array_settings = VBoxContainer.new()
	_modifier_array_count = _make_spin_box(1.0, 1000.0, 1.0)
	_modifier_array_count.value = 2.0
	_modifier_array_count.rounded = true
	_modifier_array_count.tooltip_text = "Total number of copies, including the original mesh."
	_modifier_array_settings.add_child(_labelled_control("Count", _modifier_array_count))
	_modifier_array_offset_fields = _make_vector_editor(_modifier_array_settings, "Offset", -100000.0, 100000.0, 0.1)
	_set_vector_fields(_modifier_array_offset_fields, Vector3(2.0, 0.0, 0.0))
	column.add_child(_modifier_array_settings)

	_modifier_solidify_settings = VBoxContainer.new()
	_modifier_thickness = _make_spin_box(-1000.0, 1000.0, 0.01)
	_modifier_thickness.value = 0.1
	_modifier_thickness.tooltip_text = "Distance between the generated front and back surfaces."
	_modifier_solidify_settings.add_child(_labelled_control("Thickness", _modifier_thickness))
	_modifier_solidify_offset = _make_spin_box(-1.0, 1.0, 0.01)
	_modifier_solidify_offset.tooltip_text = "Controls whether thickness grows inward, outward, or equally on both sides."
	_modifier_solidify_settings.add_child(_labelled_control("Offset", _modifier_solidify_offset))
	var solidify_note: Label = Label.new()
	solidify_note.text = "Offset -1 keeps the outer surface, 0 centres the shell, and 1 keeps the inner surface."
	solidify_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_solidify_settings.add_child(solidify_note)
	column.add_child(_modifier_solidify_settings)

	_modifier_subdivide_settings = VBoxContainer.new()
	_modifier_subdivision_levels = _make_spin_box(1.0, 4.0, 1.0)
	_modifier_subdivision_levels.value = 1.0
	_modifier_subdivision_levels.rounded = true
	_modifier_subdivision_levels.tooltip_text = "Each level divides every resulting quad again. Geometry increases rapidly, so start with 1 or 2."
	_modifier_subdivide_settings.add_child(_labelled_control("Levels", _modifier_subdivision_levels))
	_modifier_subdivide_note = Label.new()
	_modifier_subdivide_note.text = "Simple Subdivide adds quad density without changing the visible shape. Apply it before editing the generated topology."
	_modifier_subdivide_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_subdivide_settings.add_child(_modifier_subdivide_note)
	column.add_child(_modifier_subdivide_settings)

	_modifier_bevel_settings = VBoxContainer.new()
	_modifier_bevel_width = _make_spin_box(0.0001, 1000.0, 0.01)
	_modifier_bevel_width.value = 0.1
	_modifier_bevel_width.tooltip_text = "Approximate chamfer width. Large values are clamped by the shortest connected edges."
	_modifier_bevel_settings.add_child(_labelled_control("Width", _modifier_bevel_width))
	_modifier_bevel_segments = _make_spin_box(1.0, 4.0, 1.0)
	_modifier_bevel_segments.value = 1.0
	_modifier_bevel_segments.rounded = true
	_modifier_bevel_segments.tooltip_text = "Number of bevel passes. More segments create denser, rounder edge bands but increase geometry rapidly."
	_modifier_bevel_settings.add_child(_labelled_control("Segments", _modifier_bevel_segments))
	var bevel_note: Label = Label.new()
	bevel_note.text = "Use a small width first. Weighted Normal after Bevel usually gives cleaner hard-surface shading."
	bevel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_bevel_settings.add_child(bevel_note)
	column.add_child(_modifier_bevel_settings)

	_modifier_decimate_settings = VBoxContainer.new()
	_modifier_decimate_ratio = _make_spin_box(0.01, 1.0, 0.01)
	_modifier_decimate_ratio.value = 0.5
	_modifier_decimate_ratio.tooltip_text = "Approximate fraction of vertices to retain. 1 keeps the original density; 0.5 targets roughly half."
	_modifier_decimate_settings.add_child(_labelled_control("Ratio", _modifier_decimate_ratio))
	var decimate_note: Label = Label.new()
	decimate_note.text = "Decimate uses spatial clustering. It is intended for quick LODs and rough optimisation, not final hand-authored topology."
	decimate_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_decimate_settings.add_child(decimate_note)
	column.add_child(_modifier_decimate_settings)

	_modifier_triangulate_settings = VBoxContainer.new()
	var triangulate_note: Label = Label.new()
	triangulate_note.text = "Triangulate has no settings. Place it near the end of the stack to preview final game-rendered triangle topology."
	triangulate_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_triangulate_settings.add_child(triangulate_note)
	column.add_child(_modifier_triangulate_settings)

	_modifier_weighted_normal_settings = VBoxContainer.new()
	_modifier_weighted_normal_strength = _make_spin_box(0.0, 1.0, 0.01)
	_modifier_weighted_normal_strength.value = 1.0
	_modifier_weighted_normal_strength.tooltip_text = "Blends from each face normal toward the weighted result. 1 uses the full weighted normal."
	_modifier_weighted_normal_settings.add_child(_labelled_control("Strength", _modifier_weighted_normal_strength))
	_modifier_weighted_normal_power = _make_spin_box(0.0, 4.0, 0.1)
	_modifier_weighted_normal_power.value = 1.0
	_modifier_weighted_normal_power.tooltip_text = "Controls how strongly large faces dominate the result."
	_modifier_weighted_normal_settings.add_child(_labelled_control("Face Weight", _modifier_weighted_normal_power))
	_modifier_weighted_normal_keep_sharp = CheckBox.new()
	_modifier_weighted_normal_keep_sharp.text = "Keep flat faces sharp"
	_modifier_weighted_normal_keep_sharp.button_pressed = true
	_modifier_weighted_normal_keep_sharp.tooltip_text = "Leaves flat-shaded faces using their own normal while smoothing bevel and other smooth-shaded faces."
	_modifier_weighted_normal_settings.add_child(_modifier_weighted_normal_keep_sharp)
	column.add_child(_modifier_weighted_normal_settings)

	_modifier_displace_settings = VBoxContainer.new()
	_modifier_displace_strength = _make_spin_box(-1000.0, 1000.0, 0.01)
	_modifier_displace_strength.value = 0.25
	_modifier_displace_strength.tooltip_text = "Maximum distance vertices move. Negative values reverse the displacement."
	_modifier_displace_settings.add_child(_labelled_control("Strength", _modifier_displace_strength))
	_modifier_displace_scale = _make_spin_box(0.001, 1000.0, 0.01)
	_modifier_displace_scale.value = 1.0
	_modifier_displace_scale.tooltip_text = "Procedural-noise frequency. Higher values create smaller, denser surface variation."
	_modifier_displace_settings.add_child(_labelled_control("Noise Scale", _modifier_displace_scale))
	_modifier_displace_seed = _make_spin_box(-100000.0, 100000.0, 1.0)
	_modifier_displace_seed.rounded = true
	_modifier_displace_seed.tooltip_text = "Changes the procedural noise pattern without changing its scale."
	_modifier_displace_settings.add_child(_labelled_control("Seed", _modifier_displace_seed))
	_modifier_displace_noise = CheckBox.new()
	_modifier_displace_noise.text = "Use procedural noise"
	_modifier_displace_noise.button_pressed = true
	_modifier_displace_noise.tooltip_text = "When disabled, every vertex moves by the same amount for a uniform inflate or axis offset."
	_modifier_displace_settings.add_child(_modifier_displace_noise)
	_modifier_displace_direction = OptionButton.new()
	_modifier_displace_direction.add_item("X", GMSModifier.Axis.X)
	_modifier_displace_direction.add_item("Y", GMSModifier.Axis.Y)
	_modifier_displace_direction.add_item("Z", GMSModifier.Axis.Z)
	_modifier_displace_direction.add_item("Normal", GMSModifier.Axis.NORMAL)
	_modifier_displace_direction.select(3)
	_modifier_displace_direction.tooltip_text = "Direction used to move vertices. Normal follows the current surface shape."
	_modifier_displace_settings.add_child(_labelled_control("Direction", _modifier_displace_direction))
	column.add_child(_modifier_displace_settings)

	_modifier_bend_settings = VBoxContainer.new()
	_modifier_bend_angle = _make_spin_box(-3600.0, 3600.0, 1.0)
	_modifier_bend_angle.value = 90.0
	_modifier_bend_angle.tooltip_text = "Total bend across the mesh bounds. Negative values curve in the opposite direction."
	_modifier_bend_settings.add_child(_labelled_control("Angle", _modifier_bend_angle))
	_modifier_bend_axis = OptionButton.new()
	_modifier_bend_axis.add_item("X", GMSModifier.Axis.X)
	_modifier_bend_axis.add_item("Y", GMSModifier.Axis.Y)
	_modifier_bend_axis.add_item("Z", GMSModifier.Axis.Z)
	_modifier_bend_axis.select(1)
	_modifier_bend_axis.tooltip_text = "Local axis running along the length of the bend."
	_modifier_bend_settings.add_child(_labelled_control("Axis", _modifier_bend_axis))
	column.add_child(_modifier_bend_settings)

	_modifier_smooth_settings = VBoxContainer.new()
	_modifier_smooth_factor = _make_spin_box(0.0, 1.0, 0.01)
	_modifier_smooth_factor.value = 0.5
	_modifier_smooth_factor.tooltip_text = "How far each vertex moves toward the average of its connected neighbours per iteration."
	_modifier_smooth_settings.add_child(_labelled_control("Factor", _modifier_smooth_factor))
	_modifier_smooth_iterations = _make_spin_box(1.0, 50.0, 1.0)
	_modifier_smooth_iterations.value = 1.0
	_modifier_smooth_iterations.rounded = true
	_modifier_smooth_iterations.tooltip_text = "Repeats the relaxation pass. High values can shrink closed meshes significantly."
	_modifier_smooth_settings.add_child(_labelled_control("Iterations", _modifier_smooth_iterations))
	_modifier_smooth_preserve_boundary = CheckBox.new()
	_modifier_smooth_preserve_boundary.text = "Preserve open boundaries"
	_modifier_smooth_preserve_boundary.button_pressed = true
	_modifier_smooth_preserve_boundary.tooltip_text = "Keeps vertices on open mesh borders fixed while smoothing interior vertices."
	_modifier_smooth_settings.add_child(_modifier_smooth_preserve_boundary)
	column.add_child(_modifier_smooth_settings)

	_modifier_custom_settings = VBoxContainer.new()
	_modifier_custom_settings.visible = false
	column.add_child(_modifier_custom_settings)

	var modifier_apply_row: HBoxContainer = HBoxContainer.new()
	_modifier_update_button = _make_button("Update Now", _on_modifier_update_pressed)
	_modifier_update_button.tooltip_text = "Modifier settings already preview live. Use this to explicitly commit the current controls."
	_modifier_update_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_apply_row.add_child(_modifier_update_button)
	_modifier_apply_button = _make_button("Apply Through", _on_modifier_apply_pressed)
	_modifier_apply_button.tooltip_text = "Bake this modifier and every modifier above it into the editable mesh"
	_modifier_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_apply_row.add_child(_modifier_apply_button)
	column.add_child(modifier_apply_row)
	_connect_modifier_live_signals()

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Materials"))

	_material_slot_option = OptionButton.new()
	_material_slot_option.tooltip_text = "Choose the active material slot for editing and face assignment"
	_material_slot_option.item_selected.connect(_on_material_slot_selected)
	column.add_child(_labelled_control("Active Slot", _material_slot_option))

	var material_slot_row: HBoxContainer = HBoxContainer.new()
	_material_add_button = _make_button("Add Slot", _on_add_material_slot_pressed)
	_material_add_button.tooltip_text = "Add another material slot to this object"
	_material_add_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	material_slot_row.add_child(_material_add_button)
	_material_remove_button = _make_button("Remove Slot", _on_remove_material_slot_pressed)
	_material_remove_button.tooltip_text = "Remove the active slot. Faces assigned to it fall back to slot 1."
	_material_remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	material_slot_row.add_child(_material_remove_button)
	column.add_child(material_slot_row)

	_material_name_edit = LineEdit.new()
	_material_name_edit.placeholder_text = "Material name"
	column.add_child(_labelled_control("Name", _material_name_edit))
	_material_color = ColorPickerButton.new()
	_material_color.edit_alpha = false
	column.add_child(_labelled_control("Base Colour", _material_color))
	_metallic_spin = _make_spin_box(0.0, 1.0, 0.01)
	column.add_child(_labelled_control("Metallic", _metallic_spin))
	_roughness_spin = _make_spin_box(0.0, 1.0, 0.01)
	column.add_child(_labelled_control("Roughness", _roughness_spin))
	_material_apply_button = _make_button("Apply Material", _on_apply_material_pressed)
	_material_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_material_apply_button)

	_material_assign_button = _make_button("Assign to Selected Faces", _on_assign_material_to_faces_pressed)
	_material_assign_button.tooltip_text = "In Face mode, assign the active material slot to the selected faces"
	_material_assign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_material_assign_button)

	_texture_path_label = Label.new()
	_texture_path_label.text = "Albedo Texture: None"
	_texture_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_texture_path_label)
	var texture_row: HBoxContainer = HBoxContainer.new()
	_load_texture_button = _make_button("Load Texture", _on_load_texture_pressed)
	_load_texture_button.tooltip_text = "Assign an image from the current Godot project as the active material's albedo texture"
	_load_texture_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_row.add_child(_load_texture_button)
	_clear_texture_button = _make_button("Clear Texture", _on_clear_texture_pressed)
	_clear_texture_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_row.add_child(_clear_texture_button)
	column.add_child(texture_row)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("UV Mapping"))
	_uv_status_label = Label.new()
	_uv_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_uv_status_label)
	_uv_preview = GMSUVPreview.new()
	_uv_preview.tooltip_text = "Shows the active material's texture and only the UV faces assigned to that material."
	_uv_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_uv_preview)
	_uv_editor_button = _make_button("Open Full UV Editor", _on_open_uv_editor_pressed)
	_uv_editor_button.tooltip_text = "Open the resizable UV workspace for island selection, direct transforms, seams, unwrap, packing, relaxing, stitching, and texel density"
	_uv_editor_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_uv_editor_button)

	var seam_row: HBoxContainer = HBoxContainer.new()
	_uv_mark_seam_button = _make_button("Mark Seam", _on_mark_uv_seams_pressed.bind(true))
	_uv_mark_seam_button.tooltip_text = "In 3D Edge mode, mark selected edges as UV island boundaries"
	_uv_mark_seam_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seam_row.add_child(_uv_mark_seam_button)
	_uv_clear_seam_button = _make_button("Clear Seam", _on_mark_uv_seams_pressed.bind(false))
	_uv_clear_seam_button.tooltip_text = "Remove UV seam flags from selected 3D edges"
	_uv_clear_seam_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seam_row.add_child(_uv_clear_seam_button)
	column.add_child(seam_row)

	_uv_unwrap_button = _make_button("Unwrap", _on_unwrap_from_seams_pressed)
	_uv_unwrap_button.tooltip_text = "Unwrap selected faces from the currently marked seams, ignoring the previous UV layout"
	_uv_unwrap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_uv_unwrap_button)

	var unwrap_row: HBoxContainer = HBoxContainer.new()
	_uv_auto_angle_spin = _make_spin_box(1.0, 180.0, 1.0)
	_uv_auto_angle_spin.value = 66.0
	_uv_auto_angle_spin.prefix = "Angle "
	_uv_auto_angle_spin.suffix = "°"
	_uv_auto_angle_spin.tooltip_text = "Auto-seam edges at or above this face angle. Example: 66° separates cube faces but keeps gentler curves together."
	_uv_auto_angle_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unwrap_row.add_child(_uv_auto_angle_spin)
	_uv_auto_unwrap_button = _make_button("Smart UV Project", _on_auto_unwrap_pressed)
	_uv_auto_unwrap_button.tooltip_text = "Create temporary angle-based cuts, unwrap the resulting charts, and pack them without changing your marked seams"
	_uv_auto_unwrap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unwrap_row.add_child(_uv_auto_unwrap_button)
	column.add_child(unwrap_row)

	_uv_pack_button = _make_button("Pack UV Islands", _on_pack_uv_islands_pressed)
	_uv_pack_button.tooltip_text = "Pack all UV islands into the 0–1 tile with safe padding"
	_uv_pack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_uv_pack_button)
	_uv_projection_option = OptionButton.new()
	_uv_projection_option.add_item("Cube Projection", 0)
	_uv_projection_option.add_item("Planar X", 1)
	_uv_projection_option.add_item("Planar Y", 2)
	_uv_projection_option.add_item("Planar Z", 3)
	_uv_projection_option.add_item("Cylinder (Y Axis)", 4)
	_uv_projection_option.add_item("Sphere", 5)
	column.add_child(_labelled_control("Projection", _uv_projection_option))
	_uv_project_button = _make_button("Project UVs", _on_project_uv_pressed)
	_uv_project_button.tooltip_text = "Map all faces in Object mode or selected faces in Face mode (U)"
	_uv_project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_uv_project_button)

	var uv_offset_row: HBoxContainer = HBoxContainer.new()
	_uv_offset_u = _make_spin_box(-1000.0, 1000.0, 0.01)
	_uv_offset_u.prefix = "U "
	_uv_offset_u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_offset_row.add_child(_uv_offset_u)
	_uv_offset_v = _make_spin_box(-1000.0, 1000.0, 0.01)
	_uv_offset_v.prefix = "V "
	_uv_offset_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_offset_row.add_child(_uv_offset_v)
	column.add_child(_labelled_control("Offset", uv_offset_row))

	var uv_scale_row: HBoxContainer = HBoxContainer.new()
	_uv_scale_u = _make_spin_box(-1000.0, 1000.0, 0.01)
	_uv_scale_u.prefix = "U "
	_uv_scale_u.value = 1.0
	_uv_scale_u.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_scale_row.add_child(_uv_scale_u)
	_uv_scale_v = _make_spin_box(-1000.0, 1000.0, 0.01)
	_uv_scale_v.prefix = "V "
	_uv_scale_v.value = 1.0
	_uv_scale_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_scale_row.add_child(_uv_scale_v)
	column.add_child(_labelled_control("Scale", uv_scale_row))

	_uv_rotation_spin = _make_spin_box(-36000.0, 36000.0, 1.0)
	_uv_rotation_spin.suffix = "°"
	column.add_child(_labelled_control("Rotation", _uv_rotation_spin))
	var uv_action_row: HBoxContainer = HBoxContainer.new()
	_uv_transform_button = _make_button("Transform UVs", _on_transform_uv_pressed)
	_uv_transform_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_action_row.add_child(_uv_transform_button)
	_uv_clear_button = _make_button("Clear UV Map", _on_clear_uv_pressed)
	_uv_clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv_action_row.add_child(_uv_clear_button)
	column.add_child(uv_action_row)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Mesh Editing"))
	_selection_label = Label.new()
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_selection_label)

	var topology_row: HBoxContainer = HBoxContainer.new()
	_make_face_button = _make_button("Make Face", _on_make_face_pressed)
	_make_face_button.tooltip_text = "Create a face from three or more selected coplanar vertices (F)"
	_make_face_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topology_row.add_child(_make_face_button)
	_merge_button = _make_button("Merge Centre", _on_merge_vertices_pressed)
	_merge_button.tooltip_text = "Merge selected vertices at their centre (M)"
	_merge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topology_row.add_child(_merge_button)
	column.add_child(topology_row)

	var cleanup_row: HBoxContainer = HBoxContainer.new()
	_delete_components_button = _make_button("Delete Selected", _on_delete_pressed)
	_delete_components_button.tooltip_text = "Delete selected vertices, edges, or faces according to the active mode (X/Delete)"
	_delete_components_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleanup_row.add_child(_delete_components_button)
	_cleanup_button = _make_button("Remove Unused", _on_remove_unused_vertices_pressed)
	_cleanup_button.tooltip_text = "Remove vertices that are not referenced by any face"
	_cleanup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleanup_row.add_child(_cleanup_button)
	column.add_child(cleanup_row)

	_validate_topology_button = _make_button("Validate Topology", _on_validate_topology_pressed)
	_validate_topology_button.tooltip_text = "Report boundary loops and non-manifold edges. A closed game-ready solid normally has 0 boundary loops and 0 non-manifold edges."
	_validate_topology_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_validate_topology_button)

	var topology_help: Label = Label.new()
	topology_help.text = "Boundary = an open edge loop. Non-manifold = an edge used by more than two faces. Validation only reports problems; unsafe topology tools are cancelled before they damage the mesh."
	topology_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	topology_help.tooltip_text = "Closed game-ready solids normally have no boundaries and no non-manifold edges. Open surfaces such as planes are allowed to have boundaries."
	column.add_child(topology_help)

	_move_fields = _make_vector_editor(column, "Move Offset", -100000.0, 100000.0, 0.05)
	_move_selection_button = _make_button("Move Selection", _on_move_selection_pressed)
	_move_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_move_selection_button)

	_component_scale_fields = _make_vector_editor(column, "Scale Factor", -1000.0, 1000.0, 0.05)
	_set_vector_fields(_component_scale_fields, Vector3.ONE)
	_scale_selection_button = _make_button("Scale Selection", _on_scale_selection_pressed)
	_scale_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_scale_selection_button)

	var face_note: Label = Label.new()
	face_note.text = "Extrude works in Vertex, Edge, and Face modes. Inset currently requires exactly one face."
	face_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(face_note)

	_extrude_distance_spin = _make_spin_box(-100.0, 100.0, 0.1)
	_extrude_distance_spin.value = 0.5
	column.add_child(_labelled_control("Extrude", _extrude_distance_spin))
	_extrude_button = _make_button("Extrude Selection", _on_extrude_pressed)
	_extrude_button.tooltip_text = "Create connected geometry from the selected vertices, boundary edges, or faces (E). Example: pull a wall out of a cube or extend a loose edge chain."
	_extrude_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_extrude_button)

	_inset_amount_spin = _make_spin_box(0.0, 0.95, 0.05)
	_inset_amount_spin.value = 0.25
	column.add_child(_labelled_control("Inset", _inset_amount_spin))
	_inset_button = _make_button("Inset Selected Face", _on_inset_face_pressed)
	_inset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_inset_button)

	_bevel_width_spin = _make_spin_box(0.0001, 1000.0, 0.01)
	_bevel_width_spin.value = 0.1
	_bevel_width_spin.tooltip_text = "Distance used by direct edge or vertex bevel"
	column.add_child(_labelled_control("Bevel Width", _bevel_width_spin))
	var bevel_row: HBoxContainer = HBoxContainer.new()
	_bevel_edges_button = _make_button("Bevel Edges", _begin_bevel_adjust.bind(false))
	_bevel_edges_button.tooltip_text = "Chamfer selected edges (Ctrl+B). Move the mouse to set width, then click or press Enter to confirm. Example: remove razor-sharp corners from a hard-surface prop."
	_bevel_edges_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bevel_row.add_child(_bevel_edges_button)
	_bevel_vertices_button = _make_button("Bevel Vertices", _begin_bevel_adjust.bind(true))
	_bevel_vertices_button.tooltip_text = "Cut off selected corners (Ctrl+Shift+B). Move the mouse to set width, then click or press Enter to confirm. Example: flatten the point of a pyramid."
	_bevel_vertices_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bevel_row.add_child(_bevel_vertices_button)
	column.add_child(bevel_row)

	_crease_weight_spin = _make_spin_box(0.0, 1.0, 0.05)
	_crease_weight_spin.value = 1.0
	_crease_weight_spin.tooltip_text = "Subdivision Surface crease strength: 0 is fully smooth, 1 keeps the selected edge sharp"
	column.add_child(_labelled_control("Edge Crease", _crease_weight_spin))
	_crease_button = _make_button("Set Selected Edge Crease", _on_set_crease_pressed)
	_crease_button.tooltip_text = "Control how strongly Subdivision Surface preserves selected edges (Shift+E). Example: keep a panel seam sharp while the surrounding form rounds."
	_crease_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_crease_button)

	var loop_settings_row: HBoxContainer = HBoxContainer.new()
	_loop_cut_count_spin = _make_spin_box(1.0, 32.0, 1.0)
	_loop_cut_count_spin.value = 1.0
	_loop_cut_count_spin.prefix = "Cuts "
	_loop_cut_count_spin.tooltip_text = "Number of evenly spaced cuts inserted through the selected quad ring"
	loop_settings_row.add_child(_loop_cut_count_spin)
	_loop_cut_slide_spin = _make_spin_box(-0.95, 0.95, 0.05)
	_loop_cut_slide_spin.value = 0.0
	_loop_cut_slide_spin.prefix = "Slide "
	_loop_cut_slide_spin.tooltip_text = "Shift the cut positions toward one side of the ring"
	loop_settings_row.add_child(_loop_cut_slide_spin)
	column.add_child(loop_settings_row)

	var topology_tools_row: HBoxContainer = HBoxContainer.new()
	_loop_cut_button = _make_button("Loop Cut", _on_loop_cut_pressed)
	_loop_cut_button.tooltip_text = "Insert one or more cuts through a continuous quad ring (Ctrl+R). Example: add supporting geometry before bending or subdivision."
	_loop_cut_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topology_tools_row.add_child(_loop_cut_button)
	_subdivide_button = _make_button("Subdivide Faces", _on_subdivide_faces_pressed)
	_subdivide_button.tooltip_text = "Permanently split selected faces into connected quads"
	_subdivide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topology_tools_row.add_child(_subdivide_button)
	column.add_child(topology_tools_row)

	var boundary_row: HBoxContainer = HBoxContainer.new()
	_bridge_button = _make_button("Bridge Edge Loops", _on_bridge_loops_pressed)
	_bridge_button.tooltip_text = "Connect two selected edge loops or open chains with faces. Both selections must be in the same object and have matching vertex counts. For separate objects: Object mode, Shift-click both, Join, then return to Edge mode."
	_bridge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boundary_row.add_child(_bridge_button)
	_fill_holes_button = _make_button("Fill Hole", _on_fill_holes_pressed)
	_fill_holes_button.tooltip_text = "Create faces across selected boundary loops. Example: cap an open cylinder."
	_fill_holes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boundary_row.add_child(_fill_holes_button)
	column.add_child(boundary_row)

	var bridge_help: Label = Label.new()
	bridge_help.text = "Bridge: select two complete boundary loops or open chains in one object. For separate objects: Object mode > Shift-click both > Join > Edge mode > select both boundaries."
	bridge_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(bridge_help)

	var destructive_row: HBoxContainer = HBoxContainer.new()
	_dissolve_button = _make_button("Dissolve Selection", _on_dissolve_pressed)
	_dissolve_button.tooltip_text = "Remove selected components while preserving the surrounding surface when possible. Unlike Delete, Dissolve tries not to leave a hole."
	_dissolve_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destructive_row.add_child(_dissolve_button)
	_knife_button = _make_button("Knife Cut", _on_knife_pressed)
	_knife_button.tooltip_text = "Cut the active face between two clicked boundary points (K). Example: add a custom diagonal or local topology line."
	_knife_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destructive_row.add_child(_knife_button)
	column.add_child(destructive_row)

	_separate_button = _make_button("Separate Selected Faces", _on_separate_pressed)
	_separate_button.tooltip_text = "Move selected faces into a new object (P). Example: split a door or wheel from a combined mesh."
	_separate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_separate_button)

	var conversion_row: HBoxContainer = HBoxContainer.new()
	_duplicate_geometry_button = _make_button("Duplicate Faces", _on_duplicate_pressed)
	_duplicate_geometry_button.tooltip_text = "Duplicate selected face geometry and begin moving it (Shift+D)"
	_duplicate_geometry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversion_row.add_child(_duplicate_geometry_button)
	_triangulate_button = _make_button("Triangulate", _on_triangulate_pressed)
	_triangulate_button.tooltip_text = "Triangulate selected faces (Ctrl+T)"
	_triangulate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversion_row.add_child(_triangulate_button)
	column.add_child(conversion_row)

	var quad_row: HBoxContainer = HBoxContainer.new()
	_tris_to_quads_button = _make_button("Tris to Quads", _on_tris_to_quads_pressed)
	_tris_to_quads_button.tooltip_text = "Join compatible selected triangle pairs into quads (Alt+J)"
	_tris_to_quads_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quad_row.add_child(_tris_to_quads_button)
	_recalculate_normals_button = _make_button("Recalculate Outside", _on_recalculate_normals_pressed)
	_recalculate_normals_button.tooltip_text = "Make selected face winding consistent and point it outside (Shift+N)"
	_recalculate_normals_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quad_row.add_child(_recalculate_normals_button)
	column.add_child(quad_row)

	var shading_row: HBoxContainer = HBoxContainer.new()
	_smooth_button = _make_button("Shade Smooth", _on_shade_smooth_pressed)
	_smooth_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shading_row.add_child(_smooth_button)
	_flat_button = _make_button("Shade Flat", _on_shade_flat_pressed)
	_flat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shading_row.add_child(_flat_button)
	column.add_child(shading_row)

	_flip_normals_button = _make_button("Flip Selected Face Normals", _on_flip_normals_pressed)
	_flip_normals_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_flip_normals_button)

	_rig_properties_root = _build_rig_properties_panel()
	_rig_properties_root.visible = false
	content.add_child(_rig_properties_root)

	_animation_properties_root = _build_animation_properties_panel()
	_animation_properties_root.visible = false
	content.add_child(_animation_properties_root)

	return panel


func _build_rig_properties_panel() -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)

	root.add_child(_section_title("Rigging"))
	var mode_row: HBoxContainer = HBoxContainer.new()
	var mode_group: ButtonGroup = ButtonGroup.new()
	for entry: Dictionary in [
		{"text": "Edit", "mode": RigSubmode.EDIT},
		{"text": "Weights", "mode": RigSubmode.WEIGHTS},
		{"text": "Pose Preview", "mode": RigSubmode.POSE},
	]:
		var button: Button = Button.new()
		button.text = str(entry["text"])
		button.toggle_mode = true
		button.button_group = mode_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: int = int(entry["mode"])
		button.pressed.connect(_on_rig_submode_pressed.bind(mode))
		button.button_pressed = mode == RigSubmode.EDIT
		mode_row.add_child(button)
		_rig_submode_buttons[mode] = button
	root.add_child(mode_row)

	_rig_status_label = Label.new()
	_rig_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rig_status_label.text = "Select a mesh object to create or edit its armature."
	root.add_child(_rig_status_label)

	root.add_child(_section_title("Bone Hierarchy"))
	_rig_bone_tree = GMSBoneHierarchyTree.new()
	_rig_bone_tree.hide_root = true
	_rig_bone_tree.custom_minimum_size.y = 170.0
	_rig_bone_tree.tooltip_text = "Drag a bone onto another bone to reparent it. Drop in empty space to make it a root."
	_rig_bone_tree.item_selected.connect(_on_rig_bone_tree_selected)
	_rig_bone_tree.bone_reparent_requested.connect(_on_rig_bone_reparent_requested)
	root.add_child(_rig_bone_tree)

	_rig_edit_section = VBoxContainer.new()
	_rig_edit_section.add_theme_constant_override("separation", 6)
	_rig_edit_section.add_child(_section_title("Armature Edit"))
	var edit_actions: HBoxContainer = HBoxContainer.new()
	var add_root: Button = _make_button("Add Root", _on_rig_add_root_pressed)
	add_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_actions.add_child(add_root)
	var extrude: Button = _make_button("Extrude", _on_rig_extrude_pressed)
	extrude.tooltip_text = "Create a child bone from the selected bone's tail"
	extrude.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_actions.add_child(extrude)
	_rig_edit_section.add_child(edit_actions)

	var edit_actions_second: HBoxContainer = HBoxContainer.new()
	var mirror: Button = _make_button("Mirror X", _on_rig_mirror_bone_pressed)
	mirror.tooltip_text = "Mirror the selected bone and its complete child chain across the object's local X axis"
	mirror.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_actions_second.add_child(mirror)
	var delete: Button = _make_button("Delete", _on_rig_delete_bone_pressed)
	delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_actions_second.add_child(delete)
	_rig_edit_section.add_child(edit_actions_second)

	_rig_bone_name_edit = LineEdit.new()
	_rig_bone_name_edit.placeholder_text = "Bone name"
	_rig_bone_name_edit.text_submitted.connect(_on_rig_bone_name_submitted)
	_rig_bone_name_edit.focus_exited.connect(_on_rig_bone_name_focus_exited)
	_rig_edit_section.add_child(_labelled_control("Name", _rig_bone_name_edit))
	_rig_parent_option = OptionButton.new()
	_rig_parent_option.tooltip_text = "A bone can only be parented to an earlier bone in the hierarchy"
	_rig_parent_option.item_selected.connect(_on_rig_parent_selected)
	_rig_edit_section.add_child(_labelled_control("Parent", _rig_parent_option))
	_rig_head_fields = _make_vector_editor(_rig_edit_section, "Head", -100000.0, 100000.0, 0.05)
	_rig_tail_fields = _make_vector_editor(_rig_edit_section, "Tail", -100000.0, 100000.0, 0.05)
	_rig_roll_spin = _make_spin_box(-360.0, 360.0, 1.0)
	_rig_roll_spin.suffix = "°"
	_rig_edit_section.add_child(_labelled_control("Roll", _rig_roll_spin))
	var apply_rest: Button = _make_button("Apply Bone Rest", _on_rig_apply_rest_pressed)
	apply_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rig_edit_section.add_child(apply_rest)

	_rig_edit_section.add_child(HSeparator.new())
	_rig_edit_section.add_child(_section_title("Object Attachments"))
	var attachment_note: Label = Label.new()
	attachment_note.text = "Attach separate rigid objects, such as eyes, teeth, armour, or accessories, to the active bone. Their current world transform is preserved."
	attachment_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rig_edit_section.add_child(attachment_note)
	_rig_attachment_list = ItemList.new()
	_rig_attachment_list.select_mode = ItemList.SELECT_MULTI
	_rig_attachment_list.custom_minimum_size.y = 120.0
	_rig_attachment_list.item_selected.connect(_on_rig_attachment_selection_changed)
	_rig_attachment_list.multi_selected.connect(_on_rig_attachment_multi_selected)
	_rig_edit_section.add_child(_rig_attachment_list)
	var attachment_actions: HBoxContainer = HBoxContainer.new()
	_rig_attach_button = _make_button("Attach to Active Bone", _on_rig_attach_objects_pressed)
	_rig_attach_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attachment_actions.add_child(_rig_attach_button)
	_rig_detach_button = _make_button("Detach", _on_rig_detach_objects_pressed)
	_rig_detach_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attachment_actions.add_child(_rig_detach_button)
	_rig_edit_section.add_child(attachment_actions)
	_rig_attachment_status_label = Label.new()
	_rig_attachment_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rig_attachment_status_label.text = "Select one or more rigid objects from the list."
	_rig_edit_section.add_child(_rig_attachment_status_label)
	root.add_child(_rig_edit_section)

	_rig_weights_section = VBoxContainer.new()
	_rig_weights_section.add_theme_constant_override("separation", 6)
	_rig_weights_section.add_child(_section_title("Automatic Weights"))
	var auto_note: Label = Label.new()
	auto_note.text = "Automatic binding assigns up to four normalized bone influences per vertex, then smooths them over connected topology."
	auto_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rig_weights_section.add_child(auto_note)
	_rig_auto_smooth_iterations = _make_spin_box(0.0, 8.0, 1.0)
	_rig_auto_smooth_iterations.value = 3.0
	_rig_auto_smooth_iterations.rounded = true
	_rig_weights_section.add_child(_labelled_control("Smooth Passes", _rig_auto_smooth_iterations))
	var auto_weights: Button = _make_button("Generate Automatic Weights", _on_rig_auto_weights_pressed)
	auto_weights.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rig_weights_section.add_child(auto_weights)

	_rig_weights_section.add_child(HSeparator.new())
	_rig_weights_section.add_child(_section_title("Weight Correction"))
	_rig_weight_bone_option = OptionButton.new()
	_rig_weight_bone_option.item_selected.connect(_on_rig_weight_bone_selected)
	_rig_weights_section.add_child(_labelled_control("Active Bone", _rig_weight_bone_option))

	_rig_vertex_select_check = CheckBox.new()
	_rig_vertex_select_check.text = "Vertex Select Instead of Brush"
	_rig_vertex_select_check.tooltip_text = "Enable normal vertex selection in the viewport for exact numerical weight assignment"
	_rig_vertex_select_check.toggled.connect(_on_rig_vertex_select_toggled)
	_rig_weights_section.add_child(_rig_vertex_select_check)

	_rig_brush_mode_option = OptionButton.new()
	_rig_brush_mode_option.add_item("Add", GMSRigData.BrushMode.ADD)
	_rig_brush_mode_option.add_item("Subtract", GMSRigData.BrushMode.SUBTRACT)
	_rig_brush_mode_option.add_item("Replace", GMSRigData.BrushMode.REPLACE)
	_rig_brush_mode_option.add_item("Smooth", GMSRigData.BrushMode.SMOOTH)
	_rig_brush_mode_option.item_selected.connect(_on_rig_brush_setting_changed)
	_rig_weights_section.add_child(_labelled_control("Brush", _rig_brush_mode_option))
	_rig_brush_radius_spin = _make_spin_box(0.01, 100000.0, 0.1)
	_rig_brush_radius_spin.value = 1.0
	_rig_brush_radius_spin.suffix = "%"
	_rig_brush_radius_spin.tooltip_text = "Percentage-style brush radius. 1% = 0.01 model-local units, 25% = 0.25, and 100% = 1.0."
	_rig_brush_radius_spin.value_changed.connect(_on_rig_brush_setting_changed)
	_rig_weights_section.add_child(_labelled_control("Radius", _rig_brush_radius_spin))
	_rig_brush_strength_spin = _make_spin_box(0.0, 1.0, 0.01)
	_rig_brush_strength_spin.value = 0.5
	_rig_brush_strength_spin.value_changed.connect(_on_rig_brush_setting_changed)
	_rig_weights_section.add_child(_labelled_control("Strength", _rig_brush_strength_spin))

	_rig_weight_value_spin = _make_spin_box(0.0, 1.0, 0.01)
	_rig_weight_value_spin.value = 1.0
	_rig_weights_section.add_child(_labelled_control("Selected Weight", _rig_weight_value_spin))
	var vertex_actions: HBoxContainer = HBoxContainer.new()
	var assign: Button = _make_button("Assign", _on_rig_assign_weight_pressed)
	assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertex_actions.add_child(assign)
	var remove: Button = _make_button("Remove", _on_rig_remove_weight_pressed)
	remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertex_actions.add_child(remove)
	var smooth: Button = _make_button("Smooth", _on_rig_smooth_selected_weights_pressed)
	smooth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vertex_actions.add_child(smooth)
	_rig_weights_section.add_child(vertex_actions)
	var mirror_weights: Button = _make_button("Mirror Weights +X to -X", _on_rig_mirror_weights_pressed)
	mirror_weights.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rig_weights_section.add_child(mirror_weights)
	root.add_child(_rig_weights_section)

	_rig_pose_section = VBoxContainer.new()
	_rig_pose_section.add_theme_constant_override("separation", 6)
	_rig_pose_section.add_child(_section_title("Pose Preview"))
	var pose_note: Label = Label.new()
	pose_note.text = "Pose Preview only checks deformation. It creates no animation tracks and is not written as an animation."
	pose_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rig_pose_section.add_child(pose_note)
	_rig_pose_rotation_fields = _make_vector_editor(_rig_pose_section, "Rotation", -3600.0, 3600.0, 1.0)
	for field: SpinBox in _rig_pose_rotation_fields:
		field.suffix = "°"
		field.value_changed.connect(_on_rig_pose_rotation_changed)
	var pose_actions: HBoxContainer = HBoxContainer.new()
	var reset_bone: Button = _make_button("Reset Bone", _on_rig_reset_pose_bone_pressed)
	reset_bone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pose_actions.add_child(reset_bone)
	var reset_all: Button = _make_button("Reset All", _on_rig_reset_pose_all_pressed)
	reset_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pose_actions.add_child(reset_all)
	_rig_pose_section.add_child(pose_actions)
	root.add_child(_rig_pose_section)

	_rig_weights_section.visible = false
	_rig_pose_section.visible = false
	return root


func _build_animation_properties_panel() -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 7)

	root.add_child(_section_title("Animation Clips"))
	_animation_clip_option = OptionButton.new()
	_animation_clip_option.item_selected.connect(_on_animation_clip_selected)
	root.add_child(_labelled_control("Clip", _animation_clip_option))
	var clip_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "New", "callback": _on_animation_new_clip_pressed},
		{"text": "Duplicate", "callback": _on_animation_duplicate_clip_pressed},
		{"text": "Delete", "callback": _on_animation_delete_clip_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clip_actions.add_child(button)
	root.add_child(clip_actions)

	_animation_clip_name_edit = LineEdit.new()
	_animation_clip_name_edit.placeholder_text = "Animation name"
	_animation_clip_name_edit.text_submitted.connect(_on_animation_clip_name_submitted)
	_animation_clip_name_edit.focus_exited.connect(_on_animation_clip_name_focus_exited)
	root.add_child(_labelled_control("Name", _animation_clip_name_edit))

	var clip_settings: HBoxContainer = HBoxContainer.new()
	_animation_fps_spin = _make_spin_box(1.0, 240.0, 1.0)
	_animation_fps_spin.value = 24.0
	_animation_fps_spin.rounded = true
	_animation_fps_spin.prefix = "FPS "
	_animation_fps_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_fps_spin.value_changed.connect(_on_animation_clip_settings_changed)
	clip_settings.add_child(_animation_fps_spin)
	_animation_frame_count_spin = _make_spin_box(1.0, 100000.0, 1.0)
	_animation_frame_count_spin.value = 24.0
	_animation_frame_count_spin.rounded = true
	_animation_frame_count_spin.prefix = "Frames "
	_animation_frame_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_frame_count_spin.value_changed.connect(_on_animation_clip_settings_changed)
	clip_settings.add_child(_animation_frame_count_spin)
	root.add_child(clip_settings)
	_animation_loop_check = CheckBox.new()
	_animation_loop_check.text = "Loop"
	_animation_loop_check.button_pressed = true
	_animation_loop_check.toggled.connect(_on_animation_clip_settings_changed)
	root.add_child(_animation_loop_check)

	_animation_auto_key_check = CheckBox.new()
	_animation_auto_key_check.text = "Auto Key Changed Bones"
	_animation_auto_key_check.button_pressed = true
	_animation_auto_key_check.tooltip_text = "Insert or update a key when a bone transform is completed."
	root.add_child(_animation_auto_key_check)

	_animation_interpolation_option = OptionButton.new()
	_animation_interpolation_option.add_item("Constant", GMSAnimationKey.Interpolation.CONSTANT)
	_animation_interpolation_option.add_item("Linear", GMSAnimationKey.Interpolation.LINEAR)
	_animation_interpolation_option.add_item("Smooth", GMSAnimationKey.Interpolation.SMOOTH)
	_animation_interpolation_option.add_item("Ease In", GMSAnimationKey.Interpolation.EASE_IN)
	_animation_interpolation_option.add_item("Ease Out", GMSAnimationKey.Interpolation.EASE_OUT)
	_animation_interpolation_option.add_item("Ease In/Out", GMSAnimationKey.Interpolation.EASE_IN_OUT)
	_animation_interpolation_option.add_item("Custom Curve", GMSAnimationKey.Interpolation.CUSTOM)
	_animation_interpolation_option.select(2)
	_animation_interpolation_option.item_selected.connect(_on_animation_interpolation_selected)
	root.add_child(_labelled_control("Interpolation", _animation_interpolation_option))

	_animation_status_label = Label.new()
	_animation_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animation_status_label.text = "Select a rigged object and create an animation clip."
	root.add_child(_animation_status_label)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Current Bone Pose"))
	_animation_position_fields = _make_vector_editor(root, "Position", -100000.0, 100000.0, 0.01)
	_animation_rotation_fields = _make_vector_editor(root, "Rotation", -36000.0, 36000.0, 1.0)
	_animation_scale_fields = _make_vector_editor(root, "Scale", -1000.0, 1000.0, 0.01)
	for field: SpinBox in _animation_position_fields:
		field.value_changed.connect(_on_animation_pose_field_changed)
	for field: SpinBox in _animation_rotation_fields:
		field.suffix = "°"
		field.value_changed.connect(_on_animation_pose_field_changed)
	for field: SpinBox in _animation_scale_fields:
		field.value_changed.connect(_on_animation_pose_field_changed)

	var key_actions: HBoxContainer = HBoxContainer.new()
	var key_selected: Button = _make_button("Key Bone", _on_animation_key_selected_bone_pressed)
	key_selected.tooltip_text = "Insert a key for the active bone (K)"
	key_selected.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_actions.add_child(key_selected)
	var key_changed: Button = _make_button("Key Changed", _on_animation_key_changed_bones_pressed)
	key_changed.tooltip_text = "Insert keys for bones changed since the current frame was sampled (Shift+K)"
	key_changed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_actions.add_child(key_changed)
	var key_all: Button = _make_button("Key Full Pose", _on_animation_key_full_pose_pressed)
	key_all.tooltip_text = "Insert keys for every bone (Ctrl+K)"
	key_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_actions.add_child(key_all)
	root.add_child(key_actions)

	var reset_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Reset Bone", "callback": _on_animation_reset_bone_pressed},
		{"text": "Reset Chain", "callback": _on_animation_reset_chain_pressed},
		{"text": "Reset All", "callback": _on_animation_reset_all_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reset_actions.add_child(button)
	root.add_child(reset_actions)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("IK Posing"))
	var ik_note: Label = Label.new()
	ik_note.text = "Create a chain from a selected end bone. Click the cyan target or purple pole, then drag the normal move gizmo. The chain solves continuously; Auto Key stores the result when the drag ends."
	ik_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(ik_note)
	_animation_ik_chain_option = OptionButton.new()
	_animation_ik_chain_option.item_selected.connect(_on_animation_ik_chain_selected)
	root.add_child(_labelled_control("Chain", _animation_ik_chain_option))
	var ik_chain_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "New from Bone", "callback": _on_animation_new_ik_chain_pressed},
		{"text": "Delete", "callback": _on_animation_delete_ik_chain_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ik_chain_actions.add_child(button)
	root.add_child(ik_chain_actions)
	_animation_ik_root_option = OptionButton.new()
	_animation_ik_root_option.item_selected.connect(_on_animation_ik_settings_changed)
	root.add_child(_labelled_control("Root", _animation_ik_root_option))
	_animation_ik_tip_option = OptionButton.new()
	_animation_ik_tip_option.item_selected.connect(_on_animation_ik_settings_changed)
	root.add_child(_labelled_control("Tip", _animation_ik_tip_option))
	_animation_ik_target_fields = _make_vector_editor(root, "Target", -100000.0, 100000.0, 0.01)
	_animation_ik_pole_fields = _make_vector_editor(root, "Pole", -100000.0, 100000.0, 0.01)
	for field: SpinBox in _animation_ik_target_fields:
		field.value_changed.connect(_on_animation_ik_settings_changed)
	for field: SpinBox in _animation_ik_pole_fields:
		field.value_changed.connect(_on_animation_ik_settings_changed)
	var ik_solver_row: HBoxContainer = HBoxContainer.new()
	_animation_ik_iterations_spin = _make_spin_box(1.0, 64.0, 1.0)
	_animation_ik_iterations_spin.rounded = true
	_animation_ik_iterations_spin.value = 16.0
	_animation_ik_iterations_spin.prefix = "Passes "
	_animation_ik_iterations_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_ik_iterations_spin.value_changed.connect(_on_animation_ik_settings_changed)
	ik_solver_row.add_child(_animation_ik_iterations_spin)
	_animation_ik_tolerance_spin = _make_spin_box(0.000001, 1.0, 0.0001)
	_animation_ik_tolerance_spin.value = 0.0005
	_animation_ik_tolerance_spin.prefix = "Tolerance "
	_animation_ik_tolerance_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_ik_tolerance_spin.value_changed.connect(_on_animation_ik_settings_changed)
	ik_solver_row.add_child(_animation_ik_tolerance_spin)
	root.add_child(ik_solver_row)
	_animation_ik_pole_influence_spin = _make_spin_box(0.0, 1.0, 0.01)
	_animation_ik_pole_influence_spin.value = 1.0
	_animation_ik_pole_influence_spin.value_changed.connect(_on_animation_ik_settings_changed)
	root.add_child(_labelled_control("Pole Influence", _animation_ik_pole_influence_spin))
	var ik_target_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Target from Tip", "callback": _on_animation_ik_target_from_tip_pressed},
		{"text": "Pole from Bend", "callback": _on_animation_ik_pole_from_bend_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ik_target_actions.add_child(button)
	root.add_child(ik_target_actions)
	var ik_gizmo_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Target Gizmo", "callback": _on_animation_move_ik_target_pressed},
		{"text": "Pole Gizmo", "callback": _on_animation_move_ik_pole_pressed},
		{"text": "Key IK Pose", "callback": _on_animation_solve_and_key_ik_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ik_gizmo_actions.add_child(button)
	root.add_child(ik_gizmo_actions)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Bone Constraints"))
	var constraint_note: Label = Label.new()
	constraint_note.text = "Constraints improve posing inside GMS and can be baked into ordinary keys. They are not required at runtime."
	constraint_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(constraint_note)
	_animation_live_constraints_check = CheckBox.new()
	_animation_live_constraints_check.text = "Apply Constraints While Posing"
	_animation_live_constraints_check.button_pressed = true
	_animation_live_constraints_check.toggled.connect(_on_animation_live_constraints_toggled)
	root.add_child(_animation_live_constraints_check)
	_animation_constraint_list = ItemList.new()
	_animation_constraint_list.custom_minimum_size.y = 90.0
	_animation_constraint_list.item_selected.connect(_on_animation_constraint_selected)
	root.add_child(_animation_constraint_list)
	var constraint_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Add to Bone", "callback": _on_animation_add_constraint_pressed},
		{"text": "Delete", "callback": _on_animation_delete_constraint_pressed},
		{"text": "Apply Now", "callback": _on_animation_apply_constraints_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		constraint_actions.add_child(button)
	root.add_child(constraint_actions)
	_animation_constraint_type_option = OptionButton.new()
	_animation_constraint_type_option.add_item("Limit Rotation", GMSBoneConstraintData.Type.LIMIT_ROTATION)
	_animation_constraint_type_option.add_item("Copy Rotation", GMSBoneConstraintData.Type.COPY_ROTATION)
	_animation_constraint_type_option.add_item("Copy Transform", GMSBoneConstraintData.Type.COPY_TRANSFORM)
	_animation_constraint_type_option.add_item("Look At", GMSBoneConstraintData.Type.LOOK_AT)
	_animation_constraint_type_option.item_selected.connect(_on_animation_constraint_settings_changed)
	root.add_child(_labelled_control("Type", _animation_constraint_type_option))
	_animation_constraint_target_option = OptionButton.new()
	_animation_constraint_target_option.item_selected.connect(_on_animation_constraint_settings_changed)
	root.add_child(_labelled_control("Target", _animation_constraint_target_option))
	_animation_constraint_influence_spin = _make_spin_box(0.0, 1.0, 0.01)
	_animation_constraint_influence_spin.value = 1.0
	_animation_constraint_influence_spin.value_changed.connect(_on_animation_constraint_settings_changed)
	root.add_child(_labelled_control("Influence", _animation_constraint_influence_spin))
	_animation_constraint_min_fields = _make_vector_editor(root, "Min Rotation", -3600.0, 3600.0, 1.0)
	_animation_constraint_max_fields = _make_vector_editor(root, "Max Rotation", -3600.0, 3600.0, 1.0)
	for field: SpinBox in _animation_constraint_min_fields:
		field.suffix = "°"
		field.value_changed.connect(_on_animation_constraint_settings_changed)
	for field: SpinBox in _animation_constraint_max_fields:
		field.suffix = "°"
		field.value_changed.connect(_on_animation_constraint_settings_changed)
	_animation_constraint_enabled_check = CheckBox.new()
	_animation_constraint_enabled_check.text = "Enabled"
	_animation_constraint_enabled_check.button_pressed = true
	_animation_constraint_enabled_check.toggled.connect(_on_animation_constraint_settings_changed)
	root.add_child(_animation_constraint_enabled_check)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Curve Editor"))
	var curve_note: Label = Label.new()
	curve_note.text = "Interpolation presets remain available. Select a key that has a following key, then drag the handles for optional per-channel timing control."
	curve_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(curve_note)
	_animation_curve_channel_option = OptionButton.new()
	_animation_curve_channel_option.add_item("Position", GMSAnimationCurveEditor.Channel.POSITION)
	_animation_curve_channel_option.add_item("Rotation", GMSAnimationCurveEditor.Channel.ROTATION)
	_animation_curve_channel_option.add_item("Scale", GMSAnimationCurveEditor.Channel.SCALE)
	_animation_curve_channel_option.item_selected.connect(_on_animation_curve_channel_selected)
	root.add_child(_labelled_control("Channel", _animation_curve_channel_option))
	_animation_curve_editor = GMSAnimationCurveEditor.new()
	_animation_curve_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_curve_editor.curve_committed.connect(_on_animation_curve_committed)
	root.add_child(_animation_curve_editor)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Root Motion"))
	var root_motion_note: Label = Label.new()
	root_motion_note.text = "Designate the motion bone, preview the clip in place, inspect its path, or bake an in-place/loop-corrected version before export."
	root_motion_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(root_motion_note)
	_animation_root_motion_bone_option = OptionButton.new()
	_animation_root_motion_bone_option.item_selected.connect(_on_animation_root_motion_bone_selected)
	root.add_child(_labelled_control("Motion Bone", _animation_root_motion_bone_option))
	var root_axes: HBoxContainer = HBoxContainer.new()
	_animation_root_axis_x = CheckBox.new()
	_animation_root_axis_x.text = "X"
	_animation_root_axis_x.button_pressed = true
	_animation_root_axis_x.toggled.connect(_on_animation_root_motion_settings_changed)
	root_axes.add_child(_animation_root_axis_x)
	_animation_root_axis_y = CheckBox.new()
	_animation_root_axis_y.text = "Y"
	_animation_root_axis_y.toggled.connect(_on_animation_root_motion_settings_changed)
	root_axes.add_child(_animation_root_axis_y)
	_animation_root_axis_z = CheckBox.new()
	_animation_root_axis_z.text = "Z"
	_animation_root_axis_z.button_pressed = true
	_animation_root_axis_z.toggled.connect(_on_animation_root_motion_settings_changed)
	root_axes.add_child(_animation_root_axis_z)
	root.add_child(_labelled_control("Motion Axes", root_axes))
	_animation_root_preview_in_place = CheckBox.new()
	_animation_root_preview_in_place.text = "Preview In Place"
	_animation_root_preview_in_place.toggled.connect(_on_animation_root_preview_toggled)
	root.add_child(_animation_root_preview_in_place)
	_animation_root_show_path = CheckBox.new()
	_animation_root_show_path.text = "Show Motion Path"
	_animation_root_show_path.button_pressed = true
	_animation_root_show_path.toggled.connect(_on_animation_root_path_toggled)
	root.add_child(_animation_root_show_path)
	var root_motion_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Convert In Place", "callback": _on_animation_convert_root_motion_pressed},
		{"text": "Remove Loop Drift", "callback": _on_animation_remove_root_drift_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root_motion_actions.add_child(button)
	root.add_child(root_motion_actions)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Pose Clipboard"))
	var copy_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Copy Bone", "callback": _on_animation_copy_bone_pose_pressed},
		{"text": "Copy Full", "callback": _on_animation_copy_full_pose_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy_actions.add_child(button)
	root.add_child(copy_actions)
	var paste_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Paste", "callback": _on_animation_paste_pose_pressed},
		{"text": "Paste Mirrored", "callback": _on_animation_paste_mirrored_pose_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		paste_actions.add_child(button)
	root.add_child(paste_actions)

	root.add_child(HSeparator.new())
	root.add_child(_section_title("Pose Library"))
	_animation_pose_name_edit = LineEdit.new()
	_animation_pose_name_edit.placeholder_text = "Pose name"
	root.add_child(_animation_pose_name_edit)
	_animation_pose_list = ItemList.new()
	_animation_pose_list.custom_minimum_size.y = 110.0
	root.add_child(_animation_pose_list)
	var pose_actions: HBoxContainer = HBoxContainer.new()
	for entry: Dictionary in [
		{"text": "Save Pose", "callback": _on_animation_save_pose_pressed},
		{"text": "Apply", "callback": _on_animation_apply_pose_pressed},
		{"text": "Delete", "callback": _on_animation_delete_pose_pressed},
	]:
		var button: Button = _make_button(str(entry["text"]), entry["callback"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pose_actions.add_child(button)
	root.add_child(pose_actions)
	return root


func _build_animation_timeline_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.y = 96.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)

	var playback_row: HBoxContainer = HBoxContainer.new()
	playback_row.add_theme_constant_override("separation", 3)
	_animation_play_button = _make_button("Play", _on_animation_play_pressed)
	playback_row.add_child(_animation_play_button)
	playback_row.add_child(_make_button("|<", _on_animation_first_frame_pressed))
	playback_row.add_child(_make_button("<", _on_animation_previous_frame_pressed))
	playback_row.add_child(_make_button(">", _on_animation_next_frame_pressed))
	playback_row.add_child(_make_button(">|", _on_animation_last_frame_pressed))
	playback_row.add_child(_make_button("Prev Key", _on_animation_previous_key_pressed))
	playback_row.add_child(_make_button("Next Key", _on_animation_next_key_pressed))
	_animation_frame_spin = _make_spin_box(0.0, 100000.0, 1.0)
	_animation_frame_spin.rounded = true
	_animation_frame_spin.prefix = "Frame "
	_animation_frame_spin.value_changed.connect(_on_animation_frame_spin_changed)
	playback_row.add_child(_animation_frame_spin)
	var playback_spacer: Control = Control.new()
	playback_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	playback_row.add_child(playback_spacer)
	var help: Label = Label.new()
	help.text = "Space play | K bone | Shift+K changed | Ctrl+K full pose"
	playback_row.add_child(help)
	column.add_child(playback_row)

	var key_row: HBoxContainer = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 3)
	key_row.add_child(_make_button("Key Bone", _on_animation_key_selected_bone_pressed))
	key_row.add_child(_make_button("Key Changed", _on_animation_key_changed_bones_pressed))
	key_row.add_child(_make_button("Key Full", _on_animation_key_full_pose_pressed))
	key_row.add_child(_make_button("Delete Keys", _on_animation_delete_selected_keys_pressed))
	key_row.add_child(_make_button("Copy Keys", _on_animation_copy_selected_keys_pressed))
	key_row.add_child(_make_button("Paste Keys", _on_animation_paste_keys_pressed))
	key_row.add_child(_make_button("Paste Mirrored", _on_animation_paste_keys_mirrored_pressed))
	column.add_child(key_row)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_animation_timeline = GMSAnimationTimeline.new()
	_animation_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_timeline.frame_requested.connect(_on_animation_timeline_frame_requested)
	_animation_timeline.bone_requested.connect(_on_animation_timeline_bone_requested)
	_animation_timeline.key_requested.connect(_on_animation_timeline_key_requested)
	_animation_timeline.key_move_requested.connect(_on_animation_timeline_key_move_requested)
	scroll.add_child(_animation_timeline)
	column.add_child(scroll)
	return panel


func _build_file_dialogs() -> void:
	_open_dialog = FileDialog.new()
	_configure_editor_window(_open_dialog)
	_open_dialog.title = "Open Gator Model Document"
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_RESOURCES
	_open_dialog.filters = PackedStringArray(["*.tres ; Gator Model Document"])
	_open_dialog.file_selected.connect(_on_open_file_selected)
	_open_dialog.canceled.connect(_on_open_dialog_cancelled)
	add_child(_open_dialog)

	_save_dialog = FileDialog.new()
	_configure_editor_window(_save_dialog)
	_save_dialog.title = "Save Gator Model Document"
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_dialog.filters = PackedStringArray(["*.tres ; Gator Model Document"])
	_save_dialog.current_file = "untitled_model.tres"
	_save_dialog.file_selected.connect(_on_save_file_selected)
	_save_dialog.canceled.connect(_on_save_dialog_cancelled)
	add_child(_save_dialog)

	_import_dialog = FileDialog.new()
	_configure_editor_window(_import_dialog)
	_import_dialog.title = "Import Godot Mesh or Scene"
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.access = FileDialog.ACCESS_RESOURCES
	var import_filters: PackedStringArray = PackedStringArray([
		"*.tres,*.res ; Godot Mesh Resources",
		"*.tscn,*.scn,*.glb,*.gltf ; Godot and Imported Scenes",
		"*.obj ; Imported OBJ Meshes",
	])
	import_filters.append_array(GMSImporterRegistry.get_filters())
	_import_dialog.filters = import_filters
	_import_dialog.file_selected.connect(_on_import_file_selected)
	add_child(_import_dialog)

	_export_dialog = FileDialog.new()
	_configure_editor_window(_export_dialog)
	_export_dialog.title = "Export Model"
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_RESOURCES
	var document_export_filters: PackedStringArray = PackedStringArray([
		"*.tscn ; Godot Scene",
		"*.glb ; Binary glTF 2.0",
		"*.gltf ; glTF 2.0",
		"*.obj ; Wavefront OBJ",
	])
	document_export_filters.append_array(GMSExporterRegistry.get_document_filters())
	_export_dialog.filters = document_export_filters
	_export_dialog.current_file = "model.tscn"
	_export_dialog.file_selected.connect(_on_export_file_selected)
	add_child(_export_dialog)

	_mesh_export_dialog = FileDialog.new()
	_configure_editor_window(_mesh_export_dialog)
	_mesh_export_dialog.title = "Export Mesh"
	_mesh_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_mesh_export_dialog.access = FileDialog.ACCESS_RESOURCES
	var mesh_export_filters: PackedStringArray = PackedStringArray([
		"*.tres ; Text Mesh Resource",
		"*.res ; Binary Mesh Resource",
		"*.glb ; Binary glTF 2.0",
		"*.gltf ; glTF 2.0",
		"*.obj ; Wavefront OBJ",
	])
	mesh_export_filters.append_array(GMSExporterRegistry.get_mesh_filters())
	_mesh_export_dialog.filters = mesh_export_filters
	_mesh_export_dialog.current_file = "model_mesh.tres"
	_mesh_export_dialog.file_selected.connect(_on_mesh_export_file_selected)
	add_child(_mesh_export_dialog)

	_texture_dialog = FileDialog.new()
	_configure_editor_window(_texture_dialog)
	_texture_dialog.title = "Select Albedo Texture"
	_texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_texture_dialog.access = FileDialog.ACCESS_RESOURCES
	_texture_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.svg ; Image Files"])
	_texture_dialog.file_selected.connect(_on_texture_file_selected)
	add_child(_texture_dialog)


func _configure_editor_window(window: Window) -> void:
	if window == null:
		return
	# Godot does not allow a Window to be both transient and always-on-top.
	# Transient windows remain above their editor parent. grab_focus() raises an
	# already-visible popup without using the deprecated move_to_foreground().
	window.always_on_top = false
	window.transient = true


func _show_window_centered(window: Window, minimum_size: Vector2i = Vector2i.ZERO) -> void:
	if window == null:
		return
	if window.visible:
		window.grab_focus()
		return
	window.popup_centered(minimum_size)
	window.call_deferred("grab_focus")


func _show_window_centered_ratio(window: Window, ratio: float) -> void:
	if window == null:
		return
	if window.visible:
		window.grab_focus()
		return
	window.popup_centered_ratio(ratio)
	window.call_deferred("grab_focus")


func _build_document_safety_dialogs() -> void:
	_unsaved_changes_dialog = ConfirmationDialog.new()
	_configure_editor_window(_unsaved_changes_dialog)
	_unsaved_changes_dialog.exclusive = false
	_unsaved_changes_dialog.title = "Unsaved Model Changes"
	_unsaved_changes_dialog.ok_button_text = "Save"
	_unsaved_changes_dialog.get_cancel_button().text = "Cancel"
	_unsaved_changes_dialog.dialog_text = "Save changes before continuing?"
	_unsaved_changes_dialog.confirmed.connect(_on_unsaved_save_confirmed)
	_unsaved_changes_dialog.canceled.connect(_on_unsaved_cancelled)
	_unsaved_changes_dialog.custom_action.connect(_on_unsaved_custom_action)
	_unsaved_changes_dialog.add_button("Discard", true, "discard")
	add_child(_unsaved_changes_dialog)

	_recovery_dialog = ConfirmationDialog.new()
	_configure_editor_window(_recovery_dialog)
	_recovery_dialog.exclusive = true
	_recovery_dialog.title = "Recover Unsaved Model"
	_recovery_dialog.ok_button_text = "Recover"
	_recovery_dialog.get_cancel_button().text = "Discard"
	_recovery_dialog.confirmed.connect(_on_recovery_confirmed)
	_recovery_dialog.canceled.connect(_on_recovery_discarded)
	add_child(_recovery_dialog)


func _build_first_activation_notice_dialog() -> void:
	_first_activation_notice_dialog = AcceptDialog.new()
	_configure_editor_window(_first_activation_notice_dialog)
	_first_activation_notice_dialog.exclusive = true
	_first_activation_notice_dialog.title = "Welcome to Gator Model Studio"
	_first_activation_notice_dialog.ok_button_text = "Continue"
	_first_activation_notice_dialog.dialog_text = (
		"Thank you for using Gator Model Studio.

"
		+ "This is a one-time message and will not appear every time you open the project.

"
		+ "The Donate option in the Help menu opens my Ko-fi page. There you can make a "
		+ "standard donation, support me through the shop, or view my paid Godot development services."
	)
	add_child(_first_activation_notice_dialog)


func _show_first_activation_notice_if_ready() -> void:
	if not _first_activation_notice_pending or _first_activation_notice_dialog == null:
		return
	if _recovery_dialog != null and _recovery_dialog.visible:
		return
	_first_activation_notice_pending = false
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	editor_settings.set_project_metadata(
		EDITOR_METADATA_SECTION,
		FIRST_ACTIVATION_NOTICE_METADATA_KEY,
		true
	)
	_show_window_centered(_first_activation_notice_dialog, Vector2i(500, 180))


func _build_add_menu() -> void:
	_add_menu = PopupMenu.new()
	_add_menu.add_item("Plane", 0)
	_add_menu.add_item("Cube", 1)
	_add_menu.add_item("Circle", 2)
	_add_menu.add_item("UV Sphere", 3)
	_add_menu.add_item("Icosphere", 4)
	_add_menu.add_item("Cylinder", 5)
	_add_menu.add_item("Cone", 6)
	_add_menu.add_item("Torus", 7)
	_add_menu.add_item("Grid", 8)
	var extension_tools: Array[Dictionary] = GMSModelToolRegistry.get_tools()
	if not extension_tools.is_empty():
		_add_menu.add_separator("Extensions")
		var menu_id: int = 1000
		for descriptor: Dictionary in extension_tools:
			_add_menu.add_item(str(descriptor.get("name", "Extension Tool")), menu_id)
			var extension_item_index: int = _add_menu.item_count - 1
			_add_menu.set_item_tooltip(
				extension_item_index,
				str(descriptor.get("tooltip", ""))
			)
			var extension_icon: Texture2D = descriptor.get("icon") as Texture2D
			if extension_icon != null:
				_add_menu.set_item_icon(extension_item_index, extension_icon)
				_add_menu.set_item_icon_max_width(extension_item_index, 18)
			_extension_tool_menu_ids[menu_id] = str(descriptor.get("id", ""))
			menu_id += 1
	_add_menu.id_pressed.connect(_on_add_menu_id_pressed)
	add_child(_add_menu)


func _build_export_mesh_menu() -> void:
	_export_mesh_menu = PopupMenu.new()
	_export_mesh_menu.add_item("Active Object (Local Mesh)", MeshExportMode.ACTIVE_OBJECT)
	_export_mesh_menu.add_item("Selected Objects Combined (Apply Transforms)", MeshExportMode.SELECTED_COMBINED)
	_export_mesh_menu.id_pressed.connect(_on_export_mesh_menu_id_pressed)
	add_child(_export_mesh_menu)


func _build_uv_menu() -> void:
	_uv_menu = PopupMenu.new()
	_uv_menu.add_item("Cube Projection", 0)
	_uv_menu.add_item("Planar X", 1)
	_uv_menu.add_item("Planar Y", 2)
	_uv_menu.add_item("Planar Z", 3)
	_uv_menu.add_item("Cylinder (Y Axis)", 4)
	_uv_menu.add_item("Sphere", 5)
	_uv_menu.id_pressed.connect(_on_uv_menu_id_pressed)
	add_child(_uv_menu)


func _build_uv_editor_window() -> void:
	_uv_editor_window = GMSUVEditorWindow.new()
	_uv_editor_window.mesh_commit_requested.connect(_on_uv_editor_mesh_commit_requested)
	_uv_editor_window.mesh_preview_requested.connect(_on_uv_editor_mesh_preview_requested)
	_uv_editor_window.mesh_preview_cancelled.connect(_on_uv_editor_mesh_preview_cancelled)
	_uv_editor_window.checker_preview_toggled.connect(_on_uv_checker_preview_toggled)
	_uv_editor_window.face_selection_changed.connect(_on_uv_editor_face_selection_changed)
	_uv_editor_window.active_material_changed.connect(_on_uv_editor_active_material_changed)
	add_child(_uv_editor_window)


func _build_remesh_window() -> void:
	_remesh_window = Window.new()
	_configure_editor_window(_remesh_window)
	_remesh_window.title = "Guided Voxel Remesh (Experimental)"
	_remesh_window.min_size = Vector2i(430, 360)
	_remesh_window.size = Vector2i(470, 500)
	_remesh_window.visible = false
	_remesh_window.close_requested.connect(_on_remesh_window_close_requested)
	add_child(_remesh_window)
	_remesh_window.hide()

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_remesh_window.add_child(margin)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	var note: Label = Label.new()
	note.text = "Builds a new mostly-quad voxel surface. Whole Object remeshes the complete mesh. Selected Faces uses the local selection bounding box, preserves its padded boundary, and stitches the remeshed area back into the untouched mesh. UVs, seams, creases, and custom normals are discarded from the result. Duplicate output is recommended."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	column.add_child(_section_title("Remesh Settings"))
	var settings_grid: GridContainer = GridContainer.new()
	settings_grid.columns = 2
	settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(settings_grid)

	_remesh_resolution_spin = _make_spin_box(12.0, 256.0, 1.0)
	_remesh_resolution_spin.value = 32.0
	_remesh_resolution_spin.rounded = true
	_remesh_resolution_spin.allow_greater = false
	_remesh_resolution_spin.allow_lesser = false
	_remesh_resolution_spin.tooltip_text = "Voxel samples along the object's longest axis. Values up to 256 are supported. Higher values preserve thin details but cost substantially more time and memory. The effective resolution may be reduced only if the voxel grid would exceed the safety limit."
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Resolution"
	settings_grid.add_child(_remesh_resolution_spin)

	_remesh_smooth_iterations_spin = _make_spin_box(0.0, 12.0, 1.0)
	_remesh_smooth_iterations_spin.value = 3.0
	_remesh_smooth_iterations_spin.rounded = true
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Smooth Iterations"
	settings_grid.add_child(_remesh_smooth_iterations_spin)

	_remesh_smooth_strength_spin = _make_spin_box(0.0, 1.0, 0.05)
	_remesh_smooth_strength_spin.value = 0.35
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Smooth Strength"
	settings_grid.add_child(_remesh_smooth_strength_spin)

	_remesh_projection_spin = _make_spin_box(0.0, 1.0, 0.05)
	_remesh_projection_spin.value = 1.0
	_remesh_projection_spin.tooltip_text = "Projects generated vertices back onto the source surface. 1.0 preserves the original silhouette most closely."
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Surface Projection"
	settings_grid.add_child(_remesh_projection_spin)

	_remesh_density_levels_spin = _make_spin_box(0.0, 2.0, 1.0)
	_remesh_density_levels_spin.value = 1.0
	_remesh_density_levels_spin.rounded = true
	_remesh_density_levels_spin.tooltip_text = "Extra local subdivisions near Density guides."
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Density Subdivisions"
	settings_grid.add_child(_remesh_density_levels_spin)

	_remesh_region_option = OptionButton.new()
	_remesh_region_option.add_item("Whole Object", REMESH_REGION_WHOLE_OBJECT)
	_remesh_region_option.add_item("Selected Faces", REMESH_REGION_SELECTED_FACES)
	_remesh_region_option.tooltip_text = "Whole Object uses voxel remeshing across the complete mesh. Selected Faces remeshes only the current face selection, preserves its outer boundary, and stitches the result back into the untouched mesh."
	_remesh_region_option.item_selected.connect(_on_remesh_region_changed)
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Region"
	settings_grid.add_child(_remesh_region_option)

	_remesh_boundary_padding_spin = _make_spin_box(0.0, 4.0, 1.0)
	_remesh_boundary_padding_spin.value = 2.0
	_remesh_boundary_padding_spin.rounded = true
	_remesh_boundary_padding_spin.tooltip_text = "Adds untouched neighboring face rings to the selected remesh region. Two rings is recommended because it gives the voxel result room to transition before the preserved boundary is stitched."
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Boundary Padding"
	settings_grid.add_child(_remesh_boundary_padding_spin)

	_remesh_output_option = OptionButton.new()
	_remesh_output_option.add_item("Create Duplicate", 0)
	_remesh_output_option.add_item("Replace Selected Object", 1)
	settings_grid.add_child(Label.new())
	(settings_grid.get_child(settings_grid.get_child_count() - 1) as Label).text = "Output"
	settings_grid.add_child(_remesh_output_option)

	column.add_child(HSeparator.new())
	column.add_child(_section_title("Surface Guides"))
	var guide_note: Label = Label.new()
	guide_note.text = "Flow guides bias vertex relaxation along the stroke. Preserve Shape guides resist smoothing. Density guides create smaller polygons near the stroke."
	guide_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(guide_note)

	var guide_settings: HBoxContainer = HBoxContainer.new()
	guide_settings.add_theme_constant_override("separation", 6)
	column.add_child(guide_settings)
	_remesh_guide_mode_option = OptionButton.new()
	_remesh_guide_mode_option.add_item("Flow", GMSRemeshGuide.GuideMode.FLOW)
	_remesh_guide_mode_option.add_item("Preserve Shape", GMSRemeshGuide.GuideMode.PRESERVE_SHAPE)
	_remesh_guide_mode_option.add_item("Density", GMSRemeshGuide.GuideMode.DENSITY)
	_remesh_guide_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_settings.add_child(_remesh_guide_mode_option)
	_remesh_guide_radius_spin = _make_spin_box(0.0001, 100000.0, 0.01)
	_remesh_guide_radius_spin.value = 0.25
	_remesh_guide_radius_spin.prefix = "Radius "
	_remesh_guide_radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_settings.add_child(_remesh_guide_radius_spin)
	_remesh_guide_strength_spin = _make_spin_box(0.0, 1.0, 0.05)
	_remesh_guide_strength_spin.value = 1.0
	_remesh_guide_strength_spin.prefix = "Strength "
	_remesh_guide_strength_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_settings.add_child(_remesh_guide_strength_spin)

	var guide_buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(guide_buttons)
	_remesh_draw_guide_button = _make_button("Draw Guide", _on_remesh_draw_guide_pressed)
	_remesh_draw_guide_button.tooltip_text = "Hide this window and drag a stroke directly across the selected mesh."
	_remesh_draw_guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_buttons.add_child(_remesh_draw_guide_button)
	_remesh_remove_guide_button = _make_button("Remove", _on_remesh_remove_guide_pressed)
	_remesh_remove_guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_buttons.add_child(_remesh_remove_guide_button)
	_remesh_clear_guides_button = _make_button("Clear All", _on_remesh_clear_guides_pressed)
	_remesh_clear_guides_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_buttons.add_child(_remesh_clear_guides_button)

	_remesh_guide_list = ItemList.new()
	_remesh_guide_list.custom_minimum_size.y = 120.0
	_remesh_guide_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_remesh_guide_list.item_selected.connect(_on_remesh_guide_selected)
	column.add_child(_remesh_guide_list)

	_remesh_progress_label = Label.new()
	_remesh_progress_label.text = "Ready"
	_remesh_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_remesh_progress_label)
	_remesh_progress = ProgressBar.new()
	_remesh_progress.min_value = 0.0
	_remesh_progress.max_value = 100.0
	_remesh_progress.value = 0.0
	_remesh_progress.show_percentage = false
	_remesh_progress.custom_minimum_size.y = 6.0
	_remesh_progress.visible = false
	layout.add_child(_remesh_progress)

	var action_row: HBoxContainer = HBoxContainer.new()
	layout.add_child(action_row)
	_remesh_apply_button = _make_button("Remesh", _on_remesh_apply_pressed)
	_remesh_apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(_remesh_apply_button)
	_remesh_cancel_button = _make_button("Cancel Job", _on_remesh_cancel_pressed)
	_remesh_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_remesh_cancel_button.disabled = true
	_remesh_cancel_button.visible = false
	action_row.add_child(_remesh_cancel_button)

	_remesh_warning_dialog = ConfirmationDialog.new()
	_configure_editor_window(_remesh_warning_dialog)
	_remesh_warning_dialog.exclusive = false
	_remesh_warning_dialog.title = "Remesh Warning"
	_remesh_warning_dialog.ok_button_text = "Continue"
	_remesh_warning_dialog.get_cancel_button().text = "Cancel"
	_remesh_warning_dialog.transient = true
	_remesh_warning_dialog.exclusive = true
	_remesh_warning_dialog.confirmed.connect(_on_remesh_warning_confirmed)
	_remesh_window.add_child(_remesh_warning_dialog)


func _build_hotkey_dialog() -> void:
	_hotkey_dialog = AcceptDialog.new()
	_configure_editor_window(_hotkey_dialog)
	_hotkey_dialog.title = "Gator Model Studio Hotkeys"
	_hotkey_dialog.min_size = Vector2i(520, 360)
	_hotkey_dialog.size = Vector2i(620, 480)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480.0, 300.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var text: RichTextLabel = RichTextLabel.new()
	text.fit_content = true
	text.custom_minimum_size = Vector2(460.0, 0.0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.bbcode_enabled = true
	text.text = """[b]Modes and selection[/b]
Tab — toggle Object/Edit mode
1 / 2 / 3 — Vertex / Edge / Face mode while editing
LMB — select
Shift+LMB — add or remove from selection
Alt+LMB on an edge — select its edge loop
Ctrl+Alt+LMB on an edge — select its quad edge ring
B — box select visible geometry; enable X-Ray for through-selection; Shift adds, Ctrl subtracts
A — select all components in Edit mode
Alt+A — clear component selection
Ctrl+I — invert component selection
L — select linked geometry
Ctrl+Numpad + / - — grow / shrink selection

[b]Transform[/b]
G — move
R — rotate
S — scale
X / Y / Z — constrain globally; press the same axis twice for local
Drag the visible X/Y/Z gizmo handle — transform with the mouse
Global / Local — change gizmo orientation in the toolbar
Median / Active / Object / Individual — choose the transform pivot in the toolbar
O — toggle proportional editing in Edit mode
Alt+Z — toggle X-Ray selection
Shift — precision movement
Shift+Tab — toggle snapping
Ctrl during transform — temporarily invert snapping
LMB or Enter — confirm modal transform
Release LMB — confirm gizmo drag
RMB or Esc — cancel

[b]Modelling and objects[/b]
Shift+A — add primitive menu in Object mode
Shift+D — duplicate selected object or selected faces
Ctrl+R — insert one or more loop cuts under the pointer using sidebar count/slide
Ctrl+B — bevel selected edges; move mouse to set width, then click to confirm
Ctrl+Shift+B — bevel selected vertices; move mouse to set width, then click to confirm
Shift+E — set selected edge crease from the sidebar value
K — knife-cut one face between two clicked points
Ctrl+J — join selected objects in Object mode
P — separate selected faces into a new object
Ctrl+T — triangulate selected faces
Alt+J — join compatible selected triangles into quads
Shift+N — recalculate selected normals outside
X or Delete — delete object or selected components
E — extrude selected vertices, boundary edges, or face region using the sidebar distance
I — inset one selected face using the sidebar amount
F — create a face from selected coplanar vertices
M — merge selected vertices at their centre
U — open UV projection menu in Face mode

[b]Rig mode[/b]
Use the Rig button to enter Armature Edit, Weights, or Pose Preview
E — extrude a child from the selected bone in Armature Edit
Delete — delete the selected bone in Armature Edit
Drag a bone head or tail — edit the rest position
Weights > Vertex Select — use normal vertex selection for exact weight controls
Weights brush — LMB paints the active bone using Add, Subtract, Replace, or Smooth
Pose Preview — test deformation only; no animation tracks are created

[b]Animate mode[/b]
Click a bone or its timeline row — select it
G / R / S — move / rotate / scale the selected bone
Space — play or pause the current clip
Left / Right — previous / next frame
Up / Down — previous / next keyframe
K — key the selected bone
Shift+K — key changed bones
Ctrl+K — key the full pose
Delete — delete selected timeline keys
Ctrl+C / Ctrl+V — copy / paste selected keys
Ctrl+Shift+V — paste selected keys mirrored

[b]Full UV Editor[/b]
1 / 2 / 3 / 4 — UV Vertex / Edge / Face / Island selection
G / R / S — move / rotate / scale selected UVs
A / Alt+A — select all / clear selection
B — box selection, then drag with LMB
Home — frame the UV layout
MMB drag — pan; mouse wheel — zoom

[b]Viewport[/b]
MMB drag — orbit
Shift+MMB drag — pan
Ctrl+MMB drag — zoom
Mouse wheel — zoom
Numpad . — frame selected
Home — frame all
Numpad 1 / 3 / 7 — front / right / top
Ctrl+1 / 3 / 7 or Ctrl+Numpad 1 / 3 / 7 — back / left / bottom
Numpad 5 — perspective / orthographic

[b]History and files[/b]
Ctrl+Z — undo
Ctrl+Shift+Z — redo
Ctrl+S — save
Ctrl+Shift+S — save as
F1 — this hotkey reference
"""
	scroll.add_child(text)
	_hotkey_dialog.add_child(scroll)
	add_child(_hotkey_dialog)


func _build_documentation_dialog() -> void:
	_documentation_dialog = AcceptDialog.new()
	_configure_editor_window(_documentation_dialog)
	_documentation_dialog.title = "Gator Model Studio Documentation"
	_documentation_dialog.min_size = Vector2i(760, 520)
	_documentation_dialog.size = Vector2i(900, 650)

	var split: HSplitContainer = HSplitContainer.new()
	split.custom_minimum_size = Vector2(720.0, 460.0)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 210

	_documentation_topic_list = ItemList.new()
	_documentation_topic_list.custom_minimum_size.x = 200.0
	_documentation_topic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_documentation_topic_list.item_selected.connect(_on_documentation_topic_selected)
	split.add_child(_documentation_topic_list)

	_documentation_text = RichTextLabel.new()
	_documentation_text.bbcode_enabled = true
	_documentation_text.fit_content = false
	_documentation_text.scroll_active = true
	_documentation_text.selection_enabled = true
	_documentation_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_documentation_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_documentation_text)

	_add_documentation_topic("Getting Started", "res://addons/gator_model_studio/docs/getting_started.bbcode")
	_add_documentation_topic("Materials and UV Tiles", "res://addons/gator_model_studio/docs/materials_and_uv_tiles.bbcode")
	_add_documentation_topic("UV Editor", "res://addons/gator_model_studio/docs/uv_editor.bbcode")
	_add_documentation_topic("Rigging", "res://addons/gator_model_studio/docs/rigging.bbcode")
	_add_documentation_topic("Animation and IK", "res://addons/gator_model_studio/docs/animation.bbcode")
	_add_documentation_topic("Guided Voxel Remesh", "res://addons/gator_model_studio/docs/guided_voxel_remesh.bbcode")
	_add_documentation_topic("Saving, Recovery, and Auto Export", "res://addons/gator_model_studio/docs/recovery_and_safety.bbcode")

	_documentation_dialog.add_child(split)
	add_child(_documentation_dialog)
	if _documentation_topic_list.item_count > 0:
		_documentation_topic_list.select(0)
		_load_documentation_topic(0)


func _add_documentation_topic(title: String, path: String) -> void:
	_documentation_topic_list.add_item(title)
	_documentation_paths.append(path)


func _build_about_dialog() -> void:
	_about_dialog = AcceptDialog.new()
	_configure_editor_window(_about_dialog)
	_about_dialog.title = "About Gator Model Studio"
	_about_dialog.min_size = Vector2i(460, 260)

	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(420.0, 200.0)
	text.text = "[center][font_size=22][b]Gator Model Studio[/b][/font_size]\nVersion %s\n\nA Godot-native 3D modelling, rigging, UV, and animation workspace.\n\nCreated by Blackwater Gator Studios.[/center]" % _plugin_version
	_about_dialog.add_child(text)
	add_child(_about_dialog)


func _sync_snap_settings() -> void:
	if _viewport == null or _snap_button == null:
		return
	_viewport.set_snap_settings(
		_snap_button.button_pressed,
		_snap_element_option.get_selected_id(),
		_snap_base_option.get_selected_id(),
		1.0,
		5.0,
		0.1
	)
	_snap_base_option.disabled = _snap_element_option.get_selected_id() != GMSModelViewport.SnapElement.VERTEX


func _sync_gizmo_settings() -> void:
	if _viewport == null or _gizmo_visibility_button == null or _gizmo_orientation_option == null:
		return
	var active_kind: int = GMSModelViewport.TransformKind.MOVE
	for kind_value: Variant in _gizmo_buttons.keys():
		var kind: int = int(kind_value)
		var button: Button = _gizmo_buttons[kind] as Button
		if button != null and button.button_pressed:
			active_kind = kind
			break
	_viewport.set_gizmo_settings(
		active_kind,
		_gizmo_orientation_option.get_selected_id(),
		_gizmo_visibility_button.button_pressed
	)
	if _pivot_option != null:
		_viewport.set_pivot_mode(_pivot_option.get_selected_id())
	if _xray_button != null:
		_viewport.set_xray_enabled(_xray_button.button_pressed)


func _create_new_document() -> void:
	var new_document: GMSDocument = GMSDocument.new()
	new_document.document_name = "Untitled Model"

	var starter_object: GMSModelObject = GMSModelObject.new()
	starter_object.display_name = "Cube"
	starter_object.mesh_data = GMSPrimitiveFactory.create_cube()
	starter_object.material = GMSModelObject.create_default_material("Material 1")
	starter_object.ensure_defaults()
	new_document.add_object(starter_object)

	_set_document(new_document, "")
	_selection.select_object(starter_object.object_id)
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_is_dirty = false
	_update_document_label()


func _set_document(new_document: GMSDocument, path: String) -> void:
	_stop_animation_playback()
	_cancel_pending_auto_export()
	if _transform_active or _animation_transform_bone_index >= 0:
		_viewport.cancel_transform()
	if _workspace_mode in [WorkspaceMode.RIG, WorkspaceMode.ANIMATE]:
		_reset_all_pose_previews()
	_workspace_mode = WorkspaceMode.MODEL
	_rig_submode = RigSubmode.EDIT
	_rig_selected_bone = -1
	_animation_active_clip_id = ""
	_animation_current_frame = 0
	_animation_selected_keys.clear()
	_animation_dirty_bones.clear()
	_clear_animation_transform_context()
	if _remesh_job != null:
		_remesh_job.request_cancel()
	_remesh_guides_by_object.clear()
	_remesh_pending_guide_object_id = ""
	if _viewport != null:
		_viewport.cancel_remesh_guide_draw(false)
		_viewport.clear_remesh_guides()
	if _document != null:
		if _document.object_updated.is_connected(_on_document_object_updated):
			_document.object_updated.disconnect(_on_document_object_updated)
		if _document.structure_changed.is_connected(_on_document_structure_changed):
			_document.structure_changed.disconnect(_on_document_structure_changed)

	_document = new_document
	_current_path = path
	if _document != null:
		_document.last_export_path = _document.last_export_path.strip_edges()
		if _document.last_export_path.is_empty():
			_document.auto_export_on_save = false
	_history.clear()
	_selection.clear()
	_selected_modifier_index = -1

	if _document != null:
		for object: GMSModelObject in _document.objects:
			if object != null:
				object.ensure_defaults()
		_document.object_updated.connect(_on_document_object_updated)
		_document.structure_changed.connect(_on_document_structure_changed)
	_viewport.set_document(_document)
	_sync_mode_buttons()
	if _rig_submode_buttons.has(RigSubmode.EDIT):
		var edit_button: Button = _rig_submode_buttons[RigSubmode.EDIT] as Button
		if edit_button != null:
			edit_button.button_pressed = true
	_sync_viewport_rig_state()
	_rebuild_outliner()
	_update_properties()
	_update_status()
	_update_document_label()
	_sync_auto_export_control()


func _add_primitive(kind: String) -> void:
	if _document == null:
		return

	var object: GMSModelObject = GMSModelObject.new()
	object.display_name = _unique_name(kind)
	object.mesh_data = _create_primitive_mesh(kind)
	object.material = GMSModelObject.create_default_material("Material 1")
	var initial_transform: Transform3D = Transform3D.IDENTITY
	initial_transform.origin = Vector3(float(_document.objects.size()) * 0.25, 0.0, 0.0)
	object.transform = initial_transform
	object.ensure_defaults()

	_history.add_object(_document, object)
	_selection.select_object(object.object_id)
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_mark_dirty()


func _open_extension_tool(tool_id: String) -> void:
	var descriptor: Dictionary = GMSModelToolRegistry.get_tool(tool_id)
	if descriptor.is_empty():
		_status_label.text = "The selected extension tool is no longer registered."
		return
	var parameters: Array = descriptor.get("parameters", [])
	if parameters.is_empty():
		_create_extension_tool_object(tool_id, {})
		return
	if is_instance_valid(_extension_tool_dialog):
		_extension_tool_dialog.queue_free()
	_extension_tool_id = tool_id
	_extension_tool_controls.clear()
	_extension_tool_dialog = ConfirmationDialog.new()
	_configure_editor_window(_extension_tool_dialog)
	_extension_tool_dialog.exclusive = false
	_extension_tool_dialog.title = str(descriptor.get("name", "Extension Tool"))
	_extension_tool_dialog.ok_button_text = "Create"
	_extension_tool_dialog.min_size = Vector2i(420, 260)
	var form: VBoxContainer = VBoxContainer.new()
	form.add_theme_constant_override("separation", 6)
	for value: Variant in parameters:
		if not value is Dictionary:
			continue
		var parameter: Dictionary = value
		var input: Control = _create_extension_parameter_input(
			parameter,
			parameter.get("default", 0.0)
		)
		if input == null:
			continue
		_extension_tool_controls[str(parameter.get("id", ""))] = input
		form.add_child(_wrap_extension_parameter(parameter, input))
	_extension_tool_dialog.add_child(form)
	_extension_tool_dialog.confirmed.connect(_on_extension_tool_confirmed)
	_extension_tool_dialog.close_requested.connect(_clear_extension_tool_dialog)
	add_child(_extension_tool_dialog)
	_show_window_centered(_extension_tool_dialog)


func _on_extension_tool_confirmed() -> void:
	var descriptor: Dictionary = GMSModelToolRegistry.get_tool(_extension_tool_id)
	var parameters: Dictionary = _read_extension_parameters(
		descriptor.get("parameters", []),
		_extension_tool_controls
	)
	_create_extension_tool_object(_extension_tool_id, parameters)
	_clear_extension_tool_dialog()


func _clear_extension_tool_dialog() -> void:
	if is_instance_valid(_extension_tool_dialog):
		_extension_tool_dialog.queue_free()
	_extension_tool_dialog = null
	_extension_tool_controls.clear()
	_extension_tool_id = ""


func _create_extension_tool_object(tool_id: String, parameters: Dictionary) -> void:
	if _document == null:
		return
	var descriptor: Dictionary = GMSModelToolRegistry.get_tool(tool_id)
	var mesh: GMSMeshData = GMSModelToolRegistry.generate(tool_id, parameters)
	if mesh == null:
		_status_label.text = "Extension tool failed to create valid mesh geometry."
		return
	var object: GMSModelObject = GMSModelObject.new()
	object.display_name = _unique_name(str(descriptor.get("object_name", descriptor.get("name", "Object"))))
	object.mesh_data = mesh
	object.material = GMSModelObject.create_default_material("Material 1")
	var initial_transform: Transform3D = Transform3D.IDENTITY
	initial_transform.origin = Vector3(float(_document.objects.size()) * 0.25, 0.0, 0.0)
	object.transform = initial_transform
	object.ensure_defaults()
	_history.add_object(_document, object)
	_selection.select_object(object.object_id)
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_mark_dirty()
	_status_label.text = "Created %s with extension tool %s." % [object.display_name, str(descriptor.get("name", tool_id))]


func _create_primitive_mesh(kind: String) -> GMSMeshData:
	match kind:
		"Plane":
			return GMSPrimitiveFactory.create_plane()
		"Circle":
			return GMSPrimitiveFactory.create_circle()
		"UV Sphere":
			return GMSPrimitiveFactory.create_uv_sphere()
		"Icosphere":
			return GMSPrimitiveFactory.create_icosphere()
		"Cylinder":
			return GMSPrimitiveFactory.create_cylinder()
		"Cone":
			return GMSPrimitiveFactory.create_cone()
		"Torus":
			return GMSPrimitiveFactory.create_torus()
		"Grid":
			return GMSPrimitiveFactory.create_grid()
		_:
			return GMSPrimitiveFactory.create_cube()


func _unique_name(base_name: String) -> String:
	var number: int = 1
	var candidate: String = base_name
	while _has_object_name(candidate):
		number += 1
		candidate = "%s %d" % [base_name, number]
	return candidate


func _has_object_name(object_name: String) -> bool:
	for object: GMSModelObject in _document.objects:
		if object != null and object.display_name == object_name:
			return true
	return false


func _unique_name_reserved(base_name: String, reserved_names: Dictionary) -> String:
	var number: int = 1
	var candidate: String = base_name
	while _has_object_name(candidate) or reserved_names.has(candidate):
		number += 1
		candidate = "%s %d" % [base_name, number]
	return candidate




func _rebuild_outliner() -> void:
	_tree_items.clear()
	_outliner.clear()
	var root: TreeItem = _outliner.create_item()

	if _document == null:
		return

	for object: GMSModelObject in _document.objects:
		if object == null:
			continue
		var item: TreeItem = _outliner.create_item(root)
		item.set_text(0, _outliner_object_label(object))
		item.set_metadata(0, object.object_id)
		item.set_tooltip_text(0, _object_summary(object))
		if not object.visible:
			item.set_custom_color(0, Color(0.52, 0.52, 0.52))
		elif object.locked:
			item.set_custom_color(0, Color(0.72, 0.64, 0.48))
		_tree_items[object.object_id] = item

	_select_tree_item(_selection.get_primary_object_id())


func _update_properties() -> void:
	_suppress_ui_signals = true
	var object: GMSModelObject = _get_selected_object()
	var has_object: bool = object != null
	var can_change_object: bool = object != null and not object.locked

	_name_edit.editable = has_object
	_visible_check.disabled = not has_object
	_locked_check.disabled = not has_object
	_set_vector_editor_enabled(_position_fields, has_object)
	_set_vector_editor_enabled(_rotation_fields, has_object)
	_set_vector_editor_enabled(_scale_fields, has_object)
	_collision_type_option.disabled = not can_change_object
	_collision_layer_spin.editable = can_change_object
	_collision_mask_spin.editable = can_change_object
	_collision_apply_button.disabled = not can_change_object
	_material_slot_option.disabled = not can_change_object
	_material_name_edit.editable = can_change_object
	_material_add_button.disabled = not can_change_object
	_material_apply_button.disabled = not can_change_object
	var material_slot_count: int = object.materials.size() if object != null else 0
	_material_remove_button.disabled = not can_change_object or material_slot_count <= 1
	_material_assign_button.disabled = (
		not can_change_object
		or _selection.mode != GMSSelection.Mode.FACE
		or _selection.face_indices.is_empty()
	)
	_material_color.disabled = not can_change_object
	_metallic_spin.editable = can_change_object
	_roughness_spin.editable = can_change_object
	_load_texture_button.disabled = not can_change_object
	_clear_texture_button.disabled = not can_change_object
	_uv_editor_button.disabled = not has_object
	_uv_unwrap_button.disabled = not can_change_object
	_uv_auto_unwrap_button.disabled = not can_change_object
	_uv_pack_button.disabled = (
		not can_change_object
		or object == null
		or object.mesh_data == null
		or not object.mesh_data.has_uv_map
	)
	var can_mark_seams: bool = (
		can_change_object
		and _selection.mode == GMSSelection.Mode.EDGE
		and not _selection.edge_indices.is_empty()
	)
	_uv_mark_seam_button.disabled = not can_mark_seams
	_uv_clear_seam_button.disabled = not can_mark_seams
	_origin_to_geometry_button.disabled = not can_change_object
	_geometry_to_origin_button.disabled = not can_change_object
	_apply_rotation_scale_button.disabled = not can_change_object
	_join_button.disabled = (
		_selection.mode != GMSSelection.Mode.OBJECT
		or _selection.object_ids.size() < 2
	)

	_refresh_material_slot_option(object)
	if object == null:
		_name_edit.text = ""
		_visible_check.button_pressed = false
		_locked_check.button_pressed = false
		_set_vector_fields(_position_fields, Vector3.ZERO)
		_set_vector_fields(_rotation_fields, Vector3.ZERO)
		_set_vector_fields(_scale_fields, Vector3.ONE)
		_collision_type_option.select(0)
		_collision_layer_spin.value = 1.0
		_collision_mask_spin.value = 1.0
		_material_name_edit.text = ""
		_texture_path_label.text = "Albedo Texture: None"
		_uv_status_label.text = "Select an object to inspect its UV map."
	else:
		_name_edit.text = object.display_name
		_visible_check.button_pressed = object.visible
		_locked_check.button_pressed = object.locked
		_set_vector_fields(_position_fields, object.transform.origin)
		_set_vector_fields(_rotation_fields, object.transform.basis.get_euler() * 180.0 / PI)
		_set_vector_fields(_scale_fields, object.transform.basis.get_scale())
		var collision_item_index: int = _collision_type_option.get_item_index(object.collision_type)
		_collision_type_option.select(maxi(collision_item_index, 0))
		_collision_layer_spin.value = float(object.collision_layer)
		_collision_mask_spin.value = float(object.collision_mask)

		var active_material: StandardMaterial3D = object.get_active_material()
		if active_material == null:
			active_material = GMSModelObject.create_default_material("Material %d" % (object.active_material_index + 1))
		_material_name_edit.text = active_material.resource_name
		_material_color.color = active_material.albedo_color
		_metallic_spin.value = active_material.metallic
		_roughness_spin.value = active_material.roughness
		if active_material.albedo_texture == null:
			_texture_path_label.text = "Albedo Texture: None"
		else:
			var texture_path: String = active_material.albedo_texture.resource_path
			_texture_path_label.text = "Albedo Texture: %s" % (texture_path if not texture_path.is_empty() else "Embedded")
		if object.mesh_data != null and object.mesh_data.has_uv_map:
			var material_face_count: int = 0
			for face_index: int in object.mesh_data.faces.size():
				if object.mesh_data.get_face_material(face_index) == object.active_material_index:
					material_face_count += 1
			_uv_status_label.text = "Material %d UVs: %d faces, %d marked seams." % [
				object.active_material_index + 1,
				material_face_count,
				object.mesh_data.seam_edges.size()
			]
		else:
			_uv_status_label.text = "No UV map. Use Object mode for all faces or Face mode for selected faces."

	var preview_faces: PackedInt32Array = PackedInt32Array()
	var preview_mesh: GMSMeshData = null
	var preview_material_index: int = 0
	var preview_texture: Texture2D = null
	if object != null:
		preview_mesh = object.mesh_data
		if not object.materials.is_empty():
			preview_material_index = clampi(object.active_material_index, 0, object.materials.size() - 1)
			var preview_material: StandardMaterial3D = object.materials[preview_material_index]
			if preview_material != null:
				preview_texture = preview_material.albedo_texture
		if _selection.mode == GMSSelection.Mode.FACE:
			preview_faces = _selection.face_indices
	_uv_preview.set_uv_data(preview_mesh, preview_faces, preview_material_index, preview_texture)
	if _uv_editor_window != null:
		_uv_editor_window.set_data(
			preview_mesh,
			_get_uv_editor_textures(object),
			_get_uv_editor_material_names(object),
			object.active_material_index if object != null else 0
		)
	_update_modifier_panel(object)
	_update_mesh_edit_controls(object)
	_update_remesh_controls()
	if _model_properties_root != null:
		_model_properties_root.visible = _workspace_mode == WorkspaceMode.MODEL
	if _rig_properties_root != null:
		_rig_properties_root.visible = _workspace_mode == WorkspaceMode.RIG
	if _animation_properties_root != null:
		_animation_properties_root.visible = _workspace_mode == WorkspaceMode.ANIMATE
	_update_rig_panel(object)
	_update_animation_panel(object)
	_suppress_ui_signals = false


func _refresh_material_slot_option(object: GMSModelObject) -> void:
	_material_slot_option.clear()
	if object == null:
		_material_slot_option.add_item("No Material")
		_material_slot_option.select(0)
		return
	for material_index: int in object.materials.size():
		var slot_material: StandardMaterial3D = object.materials[material_index]
		var slot_name: String = slot_material.resource_name if slot_material != null else "Material %d" % (material_index + 1)
		if slot_name.is_empty():
			slot_name = "Material %d" % (material_index + 1)
		_material_slot_option.add_item("%d: %s" % [material_index + 1, slot_name], material_index)
	_material_slot_option.select(clampi(object.active_material_index, 0, object.materials.size() - 1))


func _update_modifier_panel(object: GMSModelObject) -> void:
	var can_edit: bool = object != null and not object.locked
	_modifier_add_option.disabled = not can_edit
	_modifier_add_button.disabled = not can_edit

	_modifier_list.clear()
	if object != null:
		for modifier_index: int in object.modifiers.size():
			var modifier: GMSModifier = object.modifiers[modifier_index]
			if modifier == null:
				continue
			var state: String = "" if modifier.enabled else " [Disabled]"
			_modifier_list.add_item("%d. %s%s" % [modifier_index + 1, modifier.get_display_name(), state])
			_modifier_list.set_item_tooltip(
				_modifier_list.get_item_count() - 1,
				GMSModifierRegistry.get_tooltip(modifier.custom_id)
				if modifier.is_custom()
				else GMSModifier.kind_to_tooltip(modifier.kind)
			)

	if object == null or object.modifiers.is_empty():
		_selected_modifier_index = -1
	else:
		_selected_modifier_index = clampi(_selected_modifier_index, 0, object.modifiers.size() - 1)
		_modifier_list.select(_selected_modifier_index)

	var has_modifier: bool = (
		object != null
		and _selected_modifier_index >= 0
		and _selected_modifier_index < object.modifiers.size()
	)
	_modifier_name_edit.editable = can_edit and has_modifier
	_modifier_enabled_check.disabled = not can_edit or not has_modifier
	_modifier_update_button.disabled = not can_edit or not has_modifier
	_modifier_remove_button.disabled = not can_edit or not has_modifier
	_modifier_apply_button.disabled = not can_edit or not has_modifier or _selection.mode != GMSSelection.Mode.OBJECT
	_modifier_up_button.disabled = not can_edit or not has_modifier or _selected_modifier_index <= 0
	_modifier_down_button.disabled = (
		not can_edit
		or not has_modifier
		or _selected_modifier_index >= object.modifiers.size() - 1
	)

	if not has_modifier:
		var add_option_id: int = _modifier_add_option.get_selected_id()
		_modifier_type_help_label.text = (
			GMSModifierRegistry.get_tooltip(str(_modifier_custom_option_ids[add_option_id]))
			if _modifier_custom_option_ids.has(add_option_id)
			else GMSModifier.kind_to_tooltip(add_option_id)
		)
		_modifier_name_edit.text = ""
		_modifier_enabled_check.button_pressed = false
		_modifier_mirror_settings.visible = false
		_modifier_array_settings.visible = false
		_modifier_solidify_settings.visible = false
		_modifier_subdivide_settings.visible = false
		_modifier_bevel_settings.visible = false
		_modifier_decimate_settings.visible = false
		_modifier_triangulate_settings.visible = false
		_modifier_weighted_normal_settings.visible = false
		_modifier_displace_settings.visible = false
		_modifier_bend_settings.visible = false
		_modifier_smooth_settings.visible = false
		_modifier_custom_settings.visible = false
		_modifier_custom_active_id = ""
		return

	var modifier: GMSModifier = object.modifiers[_selected_modifier_index]
	var is_custom_modifier: bool = modifier.is_custom()
	_modifier_type_help_label.text = (
		GMSModifierRegistry.get_tooltip(modifier.custom_id)
		if is_custom_modifier
		else GMSModifier.kind_to_tooltip(modifier.kind)
	)
	_modifier_name_edit.text = modifier.get_display_name()
	_modifier_enabled_check.button_pressed = modifier.enabled
	_modifier_mirror_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.MIRROR
	_modifier_array_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.ARRAY
	_modifier_solidify_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.SOLIDIFY
	_modifier_subdivide_settings.visible = not is_custom_modifier and (
		modifier.kind == GMSModifier.Kind.SIMPLE_SUBDIVIDE
		or modifier.kind == GMSModifier.Kind.SUBDIVISION_SURFACE
	)
	_modifier_bevel_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.BEVEL
	_modifier_decimate_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.DECIMATE
	_modifier_triangulate_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.TRIANGULATE
	_modifier_weighted_normal_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.WEIGHTED_NORMAL
	_modifier_displace_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.DISPLACE
	_modifier_bend_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.BEND
	_modifier_smooth_settings.visible = not is_custom_modifier and modifier.kind == GMSModifier.Kind.SMOOTH
	_modifier_custom_settings.visible = is_custom_modifier
	if is_custom_modifier:
		_rebuild_custom_modifier_controls(modifier, can_edit)
	if modifier.kind == GMSModifier.Kind.SUBDIVISION_SURFACE:
		_modifier_subdivide_note.text = "Subdivision Surface smooths and rounds the evaluated mesh while the low-density base cage remains editable. Apply it only when you need direct access to the generated topology."
	else:
		_modifier_subdivide_note.text = "Simple Subdivide adds quad density without changing the visible shape. Apply it before editing the generated topology."

	_modifier_mirror_x.button_pressed = modifier.mirror_x
	_modifier_mirror_y.button_pressed = modifier.mirror_y
	_modifier_mirror_z.button_pressed = modifier.mirror_z
	_modifier_merge_check.button_pressed = modifier.merge
	_modifier_clipping_check.button_pressed = modifier.clipping
	_modifier_merge_distance.value = modifier.merge_distance
	_modifier_array_count.value = modifier.array_count
	_set_vector_fields(_modifier_array_offset_fields, modifier.array_offset)
	_modifier_thickness.value = modifier.thickness
	_modifier_solidify_offset.value = modifier.solidify_offset
	_modifier_subdivision_levels.value = modifier.subdivision_levels
	_modifier_bevel_width.value = modifier.bevel_width
	_modifier_bevel_segments.value = modifier.bevel_segments
	_modifier_decimate_ratio.value = modifier.decimate_ratio
	_modifier_weighted_normal_strength.value = modifier.weighted_normal_strength
	_modifier_weighted_normal_power.value = modifier.weighted_normal_power
	_modifier_weighted_normal_keep_sharp.button_pressed = modifier.weighted_normal_keep_sharp
	_modifier_displace_strength.value = modifier.displace_strength
	_modifier_displace_scale.value = modifier.displace_scale
	_modifier_displace_seed.value = modifier.displace_seed
	_modifier_displace_noise.button_pressed = modifier.displace_noise
	_select_option_by_id(_modifier_displace_direction, modifier.displace_direction)
	_modifier_bend_angle.value = modifier.bend_angle_degrees
	_select_option_by_id(_modifier_bend_axis, modifier.bend_axis)
	_modifier_smooth_factor.value = modifier.smooth_factor
	_modifier_smooth_iterations.value = modifier.smooth_iterations
	_modifier_smooth_preserve_boundary.button_pressed = modifier.smooth_preserve_boundary

	var fields_enabled: bool = can_edit and has_modifier
	_modifier_mirror_x.disabled = not fields_enabled
	_modifier_mirror_y.disabled = not fields_enabled
	_modifier_mirror_z.disabled = not fields_enabled
	_modifier_merge_check.disabled = not fields_enabled
	_modifier_clipping_check.disabled = not fields_enabled
	_modifier_merge_distance.editable = fields_enabled
	_modifier_array_count.editable = fields_enabled
	_set_vector_editor_enabled(_modifier_array_offset_fields, fields_enabled)
	_modifier_thickness.editable = fields_enabled
	_modifier_solidify_offset.editable = fields_enabled
	_modifier_subdivision_levels.editable = fields_enabled
	_modifier_bevel_width.editable = fields_enabled
	_modifier_bevel_segments.editable = fields_enabled
	_modifier_decimate_ratio.editable = fields_enabled
	_modifier_weighted_normal_strength.editable = fields_enabled
	_modifier_weighted_normal_power.editable = fields_enabled
	_modifier_weighted_normal_keep_sharp.disabled = not fields_enabled
	_modifier_displace_strength.editable = fields_enabled
	_modifier_displace_scale.editable = fields_enabled
	_modifier_displace_seed.editable = fields_enabled
	_modifier_displace_noise.disabled = not fields_enabled
	_modifier_displace_direction.disabled = not fields_enabled
	_modifier_bend_angle.editable = fields_enabled
	_modifier_bend_axis.disabled = not fields_enabled
	_modifier_smooth_factor.editable = fields_enabled
	_modifier_smooth_iterations.editable = fields_enabled
	_modifier_smooth_preserve_boundary.disabled = not fields_enabled


func _update_mesh_edit_controls(object: GMSModelObject) -> void:
	var is_edit_mode: bool = _selection.mode != GMSSelection.Mode.OBJECT
	var can_edit: bool = object != null and object.mesh_data != null and not object.locked and is_edit_mode
	var selected_vertex_count: int = _get_selected_mesh_vertices().size() if can_edit else 0
	var selected_face_count: int = _selection.face_indices.size() if can_edit else 0
	var selected_edge_count: int = _selection.edge_indices.size() if can_edit else 0
	var selected_vertex_mode_count: int = _selection.vertex_indices.size() if can_edit else 0
	var selected_component_count: int = _selection.get_component_count() if can_edit else 0

	_set_vector_editor_enabled(_move_fields, can_edit and selected_vertex_count > 0)
	_set_vector_editor_enabled(_component_scale_fields, can_edit and selected_vertex_count > 0)
	_move_selection_button.disabled = not can_edit or selected_vertex_count == 0
	_scale_selection_button.disabled = not can_edit or selected_vertex_count == 0

	_make_face_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.size() < 3
	_merge_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.size() < 2
	_delete_components_button.disabled = not can_edit or selected_component_count == 0
	_cleanup_button.disabled = not can_edit or object.mesh_data.vertices.is_empty()
	_validate_topology_button.disabled = object == null or object.mesh_data == null

	_extrude_distance_spin.editable = can_edit and selected_component_count > 0
	_extrude_button.disabled = not can_edit or selected_component_count == 0
	_bevel_width_spin.editable = can_edit and (
		(_selection.mode == GMSSelection.Mode.EDGE and selected_edge_count > 0)
		or (_selection.mode == GMSSelection.Mode.VERTEX and selected_vertex_mode_count > 0)
	)
	_bevel_edges_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.EDGE or selected_edge_count == 0
	_bevel_vertices_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.VERTEX or selected_vertex_mode_count == 0
	_crease_weight_spin.editable = can_edit and _selection.mode == GMSSelection.Mode.EDGE and selected_edge_count > 0
	_crease_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.EDGE or selected_edge_count == 0
	_dissolve_button.disabled = not can_edit or selected_component_count == 0
	_bridge_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.EDGE or selected_edge_count < 2
	_fill_holes_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.EDGE
	_knife_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE
	_separate_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE or selected_face_count == 0
	_inset_amount_spin.editable = can_edit and _selection.mode == GMSSelection.Mode.FACE and selected_face_count == 1
	_inset_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE or selected_face_count != 1
	_smooth_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE or selected_face_count == 0
	_flat_button.disabled = _smooth_button.disabled
	_flip_normals_button.disabled = _smooth_button.disabled
	_duplicate_geometry_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE or selected_face_count == 0
	_triangulate_button.disabled = _duplicate_geometry_button.disabled
	_tris_to_quads_button.disabled = _duplicate_geometry_button.disabled
	_recalculate_normals_button.disabled = _duplicate_geometry_button.disabled
	_loop_cut_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.EDGE or _selection.edge_indices.is_empty()
	_loop_cut_count_spin.editable = not _loop_cut_button.disabled
	_loop_cut_slide_spin.editable = not _loop_cut_button.disabled
	_subdivide_button.disabled = not can_edit or _selection.mode != GMSSelection.Mode.FACE or selected_face_count == 0

	var can_uv_project: bool = object != null and object.mesh_data != null and not object.locked and (
		_selection.mode == GMSSelection.Mode.OBJECT
		or (_selection.mode == GMSSelection.Mode.FACE and selected_face_count > 0)
	)
	_uv_projection_option.disabled = not can_uv_project
	_uv_project_button.disabled = not can_uv_project
	_uv_transform_button.disabled = not can_uv_project or not object.mesh_data.has_uv_map
	_uv_clear_button.disabled = object == null or object.mesh_data == null or object.locked or not object.mesh_data.has_uv_map
	_uv_offset_u.editable = can_uv_project
	_uv_offset_v.editable = can_uv_project
	_uv_scale_u.editable = can_uv_project
	_uv_scale_v.editable = can_uv_project
	_uv_rotation_spin.editable = can_uv_project

	if object == null:
		_selection_label.text = "Select an object, then choose Vertex, Edge, or Face mode."
	elif object.locked:
		_selection_label.text = "This object is locked."
	else:
		_selection_label.text = _selection_description()


func _selection_description() -> String:
	match _selection.mode:
		GMSSelection.Mode.VERTEX:
			return "%d vertices selected. Shift-click to add or remove." % _selection.vertex_indices.size()
		GMSSelection.Mode.EDGE:
			return "%d edges selected. Shift-click to add or remove." % _selection.edge_indices.size()
		GMSSelection.Mode.FACE:
			return "%d faces selected. Shift-click to add or remove." % _selection.face_indices.size()
		_:
			return "Object mode. Choose a component mode to edit topology."


func _update_status() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		var object_count: int = 0
		if _document != null:
			object_count = _document.objects.size()
		_status_label.text = "%d objects" % object_count
		return

	var mesh: GMSMeshData = object.mesh_data
	var selection_suffix: String = ""
	if _selection.mode != GMSSelection.Mode.OBJECT:
		selection_suffix = " | %s" % _selection_description().get_slice(".", 0)
	var modifier_suffix: String = ""
	if not object.modifiers.is_empty():
		var evaluated_counts: Vector2i = object.get_evaluated_counts()
		modifier_suffix = " | %d modifiers → %d vertices, %d faces" % [
			object.modifiers.size(),
			evaluated_counts.x,
			evaluated_counts.y,
		]
	var edge_text: String
	var cached_edge_count: int = mesh.get_cached_edge_count()
	if cached_edge_count >= 0:
		edge_text = str(cached_edge_count)
	elif mesh.faces.size() >= GMSModelViewport.DENSE_SPATIAL_INDEX_FACE_THRESHOLD:
		edge_text = "preparing"
	else:
		edge_text = str(mesh.get_edge_count())
	_status_label.text = "%d objects | base %d vertices | %s edges | %d faces%s%s" % [
		_document.objects.size(),
		mesh.vertices.size(),
		edge_text,
		mesh.faces.size(),
		modifier_suffix,
		selection_suffix,
	]


func _update_document_label() -> void:
	if _document_label == null or _document == null:
		return
	var marker: String = " *" if _is_dirty else ""
	var location: String = "Unsaved" if _current_path.is_empty() else _current_path
	_document_label.text = "%s%s — %s" % [_document.document_name, marker, location]


func _update_history_buttons() -> void:
	if _undo_button != null:
		_undo_button.disabled = not _history.has_undo()
		_undo_button.tooltip_text = "Undo %s" % _history.get_undo_name() if _history.has_undo() else "Nothing to undo"
	if _redo_button != null:
		_redo_button.disabled = not _history.has_redo()


func _on_document_object_updated(object_id: String, change_flags: int) -> void:
	if _transform_active or _scalar_tool_active:
		return
	if (
		object_id == _uv_live_preview_object_id
		and bool(change_flags & GMSDocument.ChangeFlags.GEOMETRY)
	):
		return
	var selected_object: GMSModelObject = _get_selected_object()
	var position_changed: bool = bool(change_flags & GMSDocument.ChangeFlags.POSITIONS)
	if bool(change_flags & GMSDocument.ChangeFlags.GEOMETRY):
		_selection.sanitize(selected_object.mesh_data if selected_object != null else null)
	_mark_dirty()
	if bool(change_flags & (GMSDocument.ChangeFlags.METADATA | GMSDocument.ChangeFlags.TRANSFORM | GMSDocument.ChangeFlags.RIG | GMSDocument.ChangeFlags.ATTACHMENT)):
		_update_outliner_item(object_id)
	if (
		bool(change_flags & (GMSDocument.ChangeFlags.ATTACHMENT | GMSDocument.ChangeFlags.METADATA))
		and _workspace_mode == WorkspaceMode.RIG
	):
		_refresh_rig_attachment_list(_get_selected_object())
	if (
		object_id == _selection.get_primary_object_id()
		and not position_changed
		and not (_modifier_live_commit_active and bool(change_flags & GMSDocument.ChangeFlags.MODIFIERS))
	):
		_update_properties()
	if bool(change_flags & (GMSDocument.ChangeFlags.GEOMETRY | GMSDocument.ChangeFlags.MODIFIERS)):
		_update_status()
	if bool(change_flags & GMSDocument.ChangeFlags.MODIFIERS):
		call_deferred("_monitor_modifier_evaluation", object_id)


func _on_async_evaluation_completed(object_id: String) -> void:
	if object_id == _modifier_evaluation_object_id:
		_clear_modifier_evaluation_monitor()
	if object_id == _selection.get_primary_object_id():
		_update_status()
	if object_id == _queued_modifier_apply_object_id:
		call_deferred("_apply_queued_modifier")
	if object_id == _remesh_waiting_for_surface_index_object_id:
		call_deferred("_try_begin_remesh_guide_draw", object_id)


func _on_document_structure_changed() -> void:
	if _transform_active or _scalar_tool_active:
		return
	if _document != null:
		var existing_ids: Dictionary = {}
		for object: GMSModelObject in _document.objects:
			if object != null:
				existing_ids[object.object_id] = true
		for object_id_value: Variant in _remesh_guides_by_object.keys():
			if not existing_ids.has(str(object_id_value)):
				_remesh_guides_by_object.erase(object_id_value)
	_mark_dirty()
	_rebuild_outliner()
	_update_properties()
	_update_status()
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()


func _update_outliner_item(object_id: String) -> void:
	var item: TreeItem = _tree_items.get(object_id) as TreeItem
	var object: GMSModelObject = _document.get_object(object_id) if _document != null else null
	if item == null or object == null:
		return
	item.set_text(0, _outliner_object_label(object))
	item.set_tooltip_text(0, _object_summary(object))
	item.clear_custom_color(0)
	if not object.visible:
		item.set_custom_color(0, Color(0.52, 0.52, 0.52))
	elif object.locked:
		item.set_custom_color(0, Color(0.72, 0.64, 0.48))


func _on_selection_changed() -> void:
	var selected_id: String = _selection.get_primary_object_id()
	var context_changed: bool = (
		selected_id != _last_selection_context_object_id
		or _selection.mode != _last_selection_context_mode
		or _selection.mode == GMSSelection.Mode.OBJECT
	)
	if not _uv_checker_preview_object_id.is_empty() and _uv_checker_preview_object_id != selected_id:
		_viewport.clear_material_preview_override(_uv_checker_preview_object_id)
		_uv_checker_preview_object_id = ""
		if _uv_editor_window != null:
			_uv_editor_window.set_checker_preview_enabled(false)
	_viewport.set_selection_state(
		_selection.mode,
		_selection.object_ids,
		_selection.vertex_indices,
		_selection.edge_indices,
		_selection.face_indices
	)
	_select_tree_item(selected_id)
	_sync_mode_buttons()
	if context_changed:
		_update_properties()
	else:
		_update_component_selection_ui()
	_update_status()
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	_update_remesh_controls()
	if _workspace_mode == WorkspaceMode.ANIMATE:
		var animation_object: GMSModelObject = _get_selected_object()
		_ensure_animation_clip_selection(animation_object)
		_apply_animation_frame(true)
	_last_selection_context_object_id = selected_id
	_last_selection_context_mode = _selection.mode


func _update_component_selection_ui() -> void:
	_suppress_ui_signals = true
	var object: GMSModelObject = _get_selected_object()
	var can_change_object: bool = object != null and not object.locked
	_material_assign_button.disabled = (
		not can_change_object
		or _selection.mode != GMSSelection.Mode.FACE
		or _selection.face_indices.is_empty()
	)
	var can_mark_seams: bool = (
		can_change_object
		and _selection.mode == GMSSelection.Mode.EDGE
		and not _selection.edge_indices.is_empty()
	)
	_uv_mark_seam_button.disabled = not can_mark_seams
	_uv_clear_seam_button.disabled = not can_mark_seams
	var preview_faces: PackedInt32Array = PackedInt32Array()
	if _selection.mode == GMSSelection.Mode.FACE:
		preview_faces = _selection.face_indices
	_uv_preview.set_selected_faces(preview_faces)
	if _uv_editor_window != null:
		_uv_editor_window.set_data(
			object.mesh_data if object != null else null,
			_get_uv_editor_textures(object),
			_get_uv_editor_material_names(object),
			object.active_material_index if object != null else 0
		)
	_update_mesh_edit_controls(object)
	_suppress_ui_signals = false


func _sync_mode_buttons() -> void:
	if _workspace_mode == WorkspaceMode.RIG:
		if _rig_mode_button != null:
			_rig_mode_button.button_pressed = true
		return
	if _workspace_mode == WorkspaceMode.ANIMATE:
		if _animate_mode_button != null:
			_animate_mode_button.button_pressed = true
		return
	var button: Button = _mode_buttons.get(_selection.mode) as Button
	if button != null:
		button.button_pressed = true


func _on_viewport_selection_clicked(
	object_id: String,
	component_index: int,
	additive: bool,
	edge_pattern: int
) -> void:
	if object_id.is_empty():
		if _selection.mode == GMSSelection.Mode.OBJECT:
			_selection.clear()
		else:
			_selection.clear_components()
		return

	if _selection.mode == GMSSelection.Mode.OBJECT:
		_selection.select_object(object_id, additive)
		return

	if _selection.get_primary_object_id() != object_id:
		_selection.select_object(object_id)

	if edge_pattern != GMSModelViewport.EdgeSelectionPattern.SINGLE and _selection.mode == GMSSelection.Mode.EDGE:
		var object: GMSModelObject = _get_selected_object()
		if object != null and object.mesh_data != null:
			var pattern_indices: PackedInt32Array
			if edge_pattern == GMSModelViewport.EdgeSelectionPattern.RING:
				pattern_indices = GMSMeshOperations.get_edge_ring(object.mesh_data, component_index)
			else:
				pattern_indices = GMSMeshOperations.get_edge_loop(object.mesh_data, component_index)
			_selection.set_component_indices(
				pattern_indices,
				GMSSelection.Operation.ADD if additive else GMSSelection.Operation.SET
			)
		return

	match _selection.mode:
		GMSSelection.Mode.VERTEX:
			_selection.select_vertex(component_index, additive)
		GMSSelection.Mode.EDGE:
			_selection.select_edge(component_index, additive)
		GMSSelection.Mode.FACE:
			_selection.select_face(component_index, additive)


func _on_viewport_shortcut_requested(action: String) -> void:
	if _workspace_mode == WorkspaceMode.ANIMATE:
		match action:
			"hotkeys":
				_show_hotkeys()
			"undo":
				_on_undo_pressed()
			"redo":
				_on_redo_pressed()
			"save":
				request_save()
			"save_as":
				_on_save_as_pressed()
			"move":
				_set_active_gizmo_mode(GMSModelViewport.TransformKind.MOVE)
				_begin_animation_bone_transform(GMSModelViewport.TransformKind.MOVE)
			"rotate":
				_set_active_gizmo_mode(GMSModelViewport.TransformKind.ROTATE)
				_begin_animation_bone_transform(GMSModelViewport.TransformKind.ROTATE)
			"scale":
				_set_active_gizmo_mode(GMSModelViewport.TransformKind.SCALE)
				_begin_animation_bone_transform(GMSModelViewport.TransformKind.SCALE)
			"animation_play_pause":
				_on_animation_play_pressed()
			"animation_previous_frame":
				_on_animation_previous_frame_pressed()
			"animation_next_frame":
				_on_animation_next_frame_pressed()
			"animation_previous_key":
				_on_animation_previous_key_pressed()
			"animation_next_key":
				_on_animation_next_key_pressed()
			"key_selected_bone":
				_on_animation_key_selected_bone_pressed()
			"key_changed_bones":
				_on_animation_key_changed_bones_pressed()
			"key_full_pose":
				_on_animation_key_full_pose_pressed()
			"delete_animation_keys":
				_on_animation_delete_selected_keys_pressed()
			"copy_animation_keys":
				_on_animation_copy_selected_keys_pressed()
			"paste_animation_keys":
				_on_animation_paste_keys_pressed()
			"paste_animation_keys_mirrored":
				_on_animation_paste_keys_mirrored_pressed()
		return
	if _workspace_mode == WorkspaceMode.RIG:
		match action:
			"toggle_edit_mode":
				_toggle_edit_mode()
			"hotkeys":
				_show_hotkeys()
			"undo":
				_on_undo_pressed()
			"redo":
				_on_redo_pressed()
			"save":
				request_save()
			"save_as":
				_on_save_as_pressed()
			"delete":
				if _rig_submode == RigSubmode.EDIT:
					_on_rig_delete_bone_pressed()
			"extrude":
				if _rig_submode == RigSubmode.EDIT:
					_on_rig_extrude_pressed()
			"select_all":
				if _rig_submode == RigSubmode.WEIGHTS and _rig_vertex_select_check.button_pressed:
					_on_select_all_pressed()
			"clear_selection":
				if _rig_submode == RigSubmode.WEIGHTS and _rig_vertex_select_check.button_pressed:
					_on_clear_selection_pressed()
			"invert_selection":
				if _rig_submode == RigSubmode.WEIGHTS and _rig_vertex_select_check.button_pressed:
					_on_invert_selection_pressed()
		return
	match action:
		"toggle_edit_mode":
			_toggle_edit_mode()
		"vertex_mode":
			_set_edit_selection_mode(GMSSelection.Mode.VERTEX)
		"edge_mode":
			_set_edit_selection_mode(GMSSelection.Mode.EDGE)
		"face_mode":
			_set_edit_selection_mode(GMSSelection.Mode.FACE)
		"move":
			_set_active_gizmo_mode(GMSModelViewport.TransformKind.MOVE)
			_begin_modal_transform(GMSModelViewport.TransformKind.MOVE)
		"rotate":
			_set_active_gizmo_mode(GMSModelViewport.TransformKind.ROTATE)
			_begin_modal_transform(GMSModelViewport.TransformKind.ROTATE)
		"scale":
			_set_active_gizmo_mode(GMSModelViewport.TransformKind.SCALE)
			_begin_modal_transform(GMSModelViewport.TransformKind.SCALE)
		"select_all":
			_on_select_all_pressed()
		"clear_selection":
			_on_clear_selection_pressed()
		"invert_selection":
			_on_invert_selection_pressed()
		"select_linked":
			_on_select_linked_pressed()
		"grow_selection":
			_on_grow_selection_pressed()
		"shrink_selection":
			_on_shrink_selection_pressed()
		"loop_cut":
			_on_loop_cut_pressed(true)
		"triangulate":
			_on_triangulate_pressed()
		"tris_to_quads":
			_on_tris_to_quads_pressed()
		"recalculate_normals":
			_on_recalculate_normals_pressed()
		"duplicate":
			_on_duplicate_pressed()
		"delete":
			_on_delete_pressed()
		"extrude":
			_on_extrude_pressed()
		"inset":
			_on_inset_face_pressed()
		"make_face":
			_on_make_face_pressed()
		"merge":
			_on_merge_vertices_pressed()
		"bevel_edges":
			_begin_bevel_adjust(false)
		"bevel_vertices":
			_begin_bevel_adjust(true)
		"crease":
			_on_set_crease_pressed()
		"join_objects":
			_on_join_objects_pressed()
		"toggle_proportional":
			_proportional_button.button_pressed = not _proportional_button.button_pressed
		"separate":
			_on_separate_pressed()
		"uv_menu":
			_popup_uv_menu()
		"undo":
			_on_undo_pressed()
		"redo":
			_on_redo_pressed()
		"save":
			request_save()
		"save_as":
			_on_save_as_pressed()
		"add_menu":
			_popup_add_menu()
		"hotkeys":
			_show_hotkeys()


func _on_viewport_box_selection_requested(
	object_id: String,
	component_indices: PackedInt32Array,
	operation: int
) -> void:
	if object_id.is_empty() or _selection.mode == GMSSelection.Mode.OBJECT:
		return
	if _selection.get_primary_object_id() != object_id:
		_selection.select_object(object_id)
	_selection.set_component_indices(component_indices, operation)


func _on_viewport_box_object_selection_requested(
	object_ids: PackedStringArray,
	operation: int
) -> void:
	if _selection.mode != GMSSelection.Mode.OBJECT:
		return
	_selection.select_objects(object_ids, operation)


func _on_box_select_pressed() -> void:
	if _transform_active:
		return
	_viewport.begin_box_select()


func _on_invert_selection_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null or _selection.mode == GMSSelection.Mode.OBJECT:
		return
	_selection.invert(object.mesh_data)


func _on_select_linked_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.get_component_count() == 0:
		_status_label.text = "Select at least one mesh component before selecting linked geometry."
		return
	var linked: PackedInt32Array = GMSMeshOperations.get_linked_component_indices(
		object.mesh_data,
		_selection.mode,
		_selection.vertex_indices,
		_selection.edge_indices,
		_selection.face_indices
	)
	_selection.set_component_indices(linked, GMSSelection.Operation.SET)


func _on_grow_selection_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.get_component_count() == 0:
		return
	var grown: PackedInt32Array = GMSMeshOperations.grow_component_selection(
		object.mesh_data,
		_selection.mode,
		_selection.vertex_indices,
		_selection.edge_indices,
		_selection.face_indices
	)
	_selection.set_component_indices(grown, GMSSelection.Operation.SET)


func _on_shrink_selection_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.get_component_count() == 0:
		return
	var shrunk: PackedInt32Array = GMSMeshOperations.shrink_component_selection(
		object.mesh_data,
		_selection.mode,
		_selection.vertex_indices,
		_selection.edge_indices,
		_selection.face_indices
	)
	_selection.set_component_indices(shrunk, GMSSelection.Operation.SET)


func _toggle_edit_mode() -> void:
	if _transform_active:
		return
	if _workspace_mode == WorkspaceMode.RIG:
		_set_workspace_mode(WorkspaceMode.MODEL)
		_selection.set_mode(GMSSelection.Mode.OBJECT)
		return
	if _selection.mode == GMSSelection.Mode.OBJECT:
		if _get_selected_object() == null:
			_status_label.text = "Select an object before entering Edit mode."
			return
		_selection.set_mode(_last_edit_mode)
	else:
		_last_edit_mode = _selection.mode
		_selection.set_mode(GMSSelection.Mode.OBJECT)


func _set_edit_selection_mode(mode: GMSSelection.Mode) -> void:
	if _workspace_mode == WorkspaceMode.RIG:
		return
	if _transform_active or _selection.mode == GMSSelection.Mode.OBJECT:
		return
	_last_edit_mode = mode
	_selection.set_mode(mode)


func _begin_modal_transform(
	kind: int,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false
) -> void:
	if _transform_active or _scalar_tool_active:
		return
	_set_active_gizmo_mode(kind)
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked:
		_status_label.text = "Select an unlocked object before transforming."
		return

	var selected_vertices: PackedInt32Array = PackedInt32Array()
	_transform_object_ids.clear()
	_transform_original_transforms.clear()
	_transform_proportional_weights.clear()
	_transform_vertex_indices.clear()
	_transform_original_vertex_positions.clear()
	_transform_preview_vertex_positions.clear()
	_transform_vertex_weights.clear()
	_transform_dynamic_preview = false
	if _selection.mode == GMSSelection.Mode.OBJECT:
		for object_id: String in _selection.object_ids:
			var selected_object: GMSModelObject = _document.get_object(object_id)
			if selected_object == null or selected_object.locked:
				continue
			_transform_object_ids.append(selected_object.object_id)
			_transform_original_transforms.append(selected_object.transform)
		if _transform_object_ids.is_empty():
			_status_label.text = "Select at least one unlocked object before transforming."
			return
	else:
		if object.mesh_data == null:
			return
		selected_vertices = _get_selected_mesh_vertices()
		if selected_vertices.is_empty():
			_status_label.text = "Select vertices, edges, or faces before transforming in Edit mode."
			return
		if _proportional_enabled:
			_transform_proportional_weights = GMSAdvancedMeshOperations.calculate_proportional_weights(
				object.mesh_data,
				selected_vertices,
				float(_proportional_radius_spin.value),
				_proportional_falloff_option.get_selected_id()
			)
		var affected_vertices: PackedInt32Array = PackedInt32Array()
		if _transform_proportional_weights.size() == object.mesh_data.vertices.size():
			for vertex_index: int in _transform_proportional_weights.size():
				if _transform_proportional_weights[vertex_index] > 0.0:
					affected_vertices.append(vertex_index)
		else:
			affected_vertices = selected_vertices.duplicate()
		affected_vertices.sort()
		_transform_vertex_indices = affected_vertices
		_transform_original_vertex_positions = object.mesh_data.get_vertex_positions(affected_vertices)
		_transform_preview_vertex_positions = _transform_original_vertex_positions.duplicate()
		_transform_vertex_weights.resize(affected_vertices.size())
		for index: int in affected_vertices.size():
			var vertex_index: int = affected_vertices[index]
			_transform_vertex_weights[index] = (
				_transform_proportional_weights[vertex_index]
				if vertex_index < _transform_proportional_weights.size()
				else 1.0
			)
		_transform_dynamic_preview = (
			object.supports_dynamic_vertex_preview()
			and _viewport.begin_dynamic_vertex_preview(
				object.object_id, object.mesh_data, object.mesh_data.get_aabb()
			)
		)

	var viewport_source_points: PackedVector3Array = PackedVector3Array()
	if _selection.mode != GMSSelection.Mode.OBJECT:
		viewport_source_points.resize(selected_vertices.size())
		for index: int in selected_vertices.size():
			viewport_source_points[index] = object.transform * object.mesh_data.vertices[selected_vertices[index]]

	_transform_active = true
	_transform_kind = kind
	_transform_object_id = object.object_id
	_transform_original_transform = object.transform
	_transform_original_mesh = (
		null
		if _selection.mode == GMSSelection.Mode.OBJECT or _transform_dynamic_preview
		else object.mesh_data.duplicate_mesh_data()
	)
	_transform_was_dirty = _is_dirty
	_transform_action_name = _get_transform_action_name(kind)
	_capture_transform_selection()

	if not _viewport.begin_transform(
		kind,
		custom_axis,
		start_mouse_position,
		confirm_on_release,
		viewport_source_points,
		object.object_id
	):
		if _transform_dynamic_preview:
			_viewport.finish_dynamic_vertex_preview(false)
		_clear_transform_context()
		_status_label.text = "The transform could not start."


func _on_viewport_gizmo_transform_requested(
	kind: int,
	axis: Vector3,
	mouse_position: Vector2
) -> void:
	if _workspace_mode == WorkspaceMode.ANIMATE:
		if (
			_animation_ik_gizmo_control != GMSModelViewport.AnimationIKControl.NONE
			and not _animation_active_ik_chain_id.is_empty()
		):
			_begin_animation_ik_control_transform(
				_animation_ik_gizmo_control == GMSModelViewport.AnimationIKControl.POLE,
				axis,
				mouse_position,
				true
			)
		else:
			_begin_animation_bone_transform(kind, axis, mouse_position, true)
	else:
		_begin_modal_transform(kind, axis, mouse_position, true)


func _get_transform_action_name(kind: int) -> String:
	var operation: String = "Transform"
	match kind:
		GMSModelViewport.TransformKind.MOVE:
			operation = "Move"
		GMSModelViewport.TransformKind.ROTATE:
			operation = "Rotate"
		GMSModelViewport.TransformKind.SCALE:
			operation = "Scale"
	if _selection.mode == GMSSelection.Mode.OBJECT:
		return "%s Object%s" % [operation, "s" if _transform_object_ids.size() > 1 else ""]
	return "%s Mesh Selection%s" % [operation, " (Proportional)" if _proportional_enabled else ""]


func _on_viewport_transform_preview(
	kind: int,
	value: Vector3,
	axis: Vector3,
	pivot_world: Vector3
) -> void:
	if not _transform_active or _document == null:
		return
	var object: GMSModelObject = _document.get_object(_transform_object_id)
	if object == null:
		return

	if _selection.mode == GMSSelection.Mode.OBJECT:
		var new_transforms: Array[Transform3D] = []
		var individual: bool = (
			_pivot_option != null
			and _pivot_option.get_selected_id() == GMSModelViewport.PivotMode.INDIVIDUAL_ORIGINS
		)
		for source_transform: Transform3D in _transform_original_transforms:
			var new_transform: Transform3D = source_transform
			var object_pivot: Vector3 = source_transform.origin if individual else pivot_world
			match kind:
				GMSModelViewport.TransformKind.MOVE:
					new_transform.origin = source_transform.origin + value
				GMSModelViewport.TransformKind.ROTATE:
					if not axis.is_zero_approx():
						var rotation: Basis = Basis(axis.normalized(), value.x)
						new_transform.basis = rotation * source_transform.basis
						new_transform.origin = object_pivot + rotation * (source_transform.origin - object_pivot)
				GMSModelViewport.TransformKind.SCALE:
					if axis.is_zero_approx():
						new_transform.basis = source_transform.basis.scaled(value)
						new_transform.origin = object_pivot + (source_transform.origin - object_pivot) * value
					else:
						new_transform.basis = _scale_basis_along_world_axis(
							source_transform.basis,
							axis,
							value.x
						)
						var relative: Vector3 = source_transform.origin - object_pivot
						var normalized_axis: Vector3 = axis.normalized()
						relative += normalized_axis * relative.dot(normalized_axis) * (value.x - 1.0)
						new_transform.origin = object_pivot + relative
			new_transforms.append(new_transform)
		_document.set_object_transforms(_transform_object_ids, new_transforms)
		return

	if _transform_dynamic_preview:
		_transform_preview_vertex_positions = _calculate_dynamic_vertex_positions(
			kind, value, axis, pivot_world
		)
		_viewport.update_dynamic_vertex_preview(
			_transform_vertex_indices, _transform_preview_vertex_positions
		)
		return

	if _transform_original_mesh == null:
		return
	var preview_mesh: GMSMeshData
	var use_proportional: bool = (
		_proportional_enabled
		and _transform_proportional_weights.size() == _transform_original_mesh.vertices.size()
	)
	match kind:
		GMSModelViewport.TransformKind.MOVE:
			if use_proportional:
				preview_mesh = GMSAdvancedMeshOperations.translate_vertices_world_weighted(
					_transform_original_mesh,
					_transform_proportional_weights,
					_transform_original_transform,
					value
				)
			else:
				preview_mesh = GMSMeshOperations.translate_vertices_world(
					_transform_original_mesh,
					_transform_vertex_indices,
					_transform_original_transform,
					value
				)
		GMSModelViewport.TransformKind.ROTATE:
			if use_proportional:
				preview_mesh = GMSAdvancedMeshOperations.rotate_vertices_world_weighted(
					_transform_original_mesh,
					_transform_proportional_weights,
					_transform_original_transform,
					pivot_world,
					axis,
					value.x
				)
			else:
				preview_mesh = GMSMeshOperations.rotate_vertices_world(
					_transform_original_mesh,
					_transform_vertex_indices,
					_transform_original_transform,
					pivot_world,
					axis,
					value.x
				)
		GMSModelViewport.TransformKind.SCALE:
			if axis.is_zero_approx():
				if use_proportional:
					preview_mesh = GMSAdvancedMeshOperations.scale_vertices_world_weighted(
						_transform_original_mesh,
						_transform_proportional_weights,
						_transform_original_transform,
						pivot_world,
						value
					)
				else:
					preview_mesh = GMSMeshOperations.scale_vertices_world(
						_transform_original_mesh,
						_transform_vertex_indices,
						_transform_original_transform,
						pivot_world,
						value
					)
			else:
				if use_proportional:
					preview_mesh = GMSAdvancedMeshOperations.scale_vertices_world_axis_weighted(
						_transform_original_mesh,
						_transform_proportional_weights,
						_transform_original_transform,
						pivot_world,
						axis,
						value.x
					)
				else:
					preview_mesh = GMSMeshOperations.scale_vertices_world_axis(
						_transform_original_mesh,
						_transform_vertex_indices,
						_transform_original_transform,
						pivot_world,
						axis,
						value.x
					)
		_:
			return
	preview_mesh = _apply_mirror_clipping(object, _transform_original_mesh, preview_mesh)
	_document.set_object_mesh(object.object_id, preview_mesh)


func _calculate_dynamic_vertex_positions(
	kind: int,
	value: Vector3,
	axis: Vector3,
	pivot_world: Vector3
) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	result.resize(_transform_original_vertex_positions.size())
	var inverse: Transform3D = _transform_original_transform.affine_inverse()
	var inverse_basis: Basis = inverse.basis
	var source_basis: Basis = _transform_original_transform.basis
	var local_pivot: Vector3 = inverse * pivot_world
	var normalized_axis: Vector3 = axis.normalized() if not axis.is_zero_approx() else Vector3.ZERO
	var weighted: bool = _proportional_enabled
	match kind:
		GMSModelViewport.TransformKind.MOVE:
			var local_delta: Vector3 = inverse_basis * value
			for index: int in _transform_original_vertex_positions.size():
				var move_weight: float = _transform_vertex_weights[index] if weighted else 1.0
				result[index] = _transform_original_vertex_positions[index] + local_delta * move_weight
		GMSModelViewport.TransformKind.ROTATE:
			if normalized_axis.is_zero_approx():
				return _transform_original_vertex_positions
			if not weighted:
				var fixed_local_rotation: Basis = (
					inverse_basis * Basis(normalized_axis, value.x) * source_basis
				)
				for index: int in _transform_original_vertex_positions.size():
					result[index] = local_pivot + fixed_local_rotation * (
						_transform_original_vertex_positions[index] - local_pivot
					)
			else:
				for index: int in _transform_original_vertex_positions.size():
					var rotate_weight: float = _transform_vertex_weights[index]
					var weighted_local_rotation: Basis = (
						inverse_basis * Basis(normalized_axis, value.x * rotate_weight) * source_basis
					)
					result[index] = local_pivot + weighted_local_rotation * (
						_transform_original_vertex_positions[index] - local_pivot
					)
		GMSModelViewport.TransformKind.SCALE:
			for index: int in _transform_original_vertex_positions.size():
				var scale_weight: float = _transform_vertex_weights[index] if weighted else 1.0
				var relative_local: Vector3 = _transform_original_vertex_positions[index] - local_pivot
				var relative_world: Vector3 = source_basis * relative_local
				if normalized_axis.is_zero_approx():
					var effective: Vector3 = Vector3(
						lerpf(1.0, value.x, scale_weight),
						lerpf(1.0, value.y, scale_weight),
						lerpf(1.0, value.z, scale_weight)
					)
					relative_world *= effective
				else:
					var effective_factor: float = lerpf(1.0, value.x, scale_weight)
					relative_world += normalized_axis * relative_world.dot(normalized_axis) * (
						effective_factor - 1.0
					)
				result[index] = local_pivot + inverse_basis * relative_world
		_:
			return _transform_original_vertex_positions
	return result


func _apply_mirror_clipping(
	object: GMSModelObject,
	original_mesh: GMSMeshData,
	preview_mesh: GMSMeshData
) -> GMSMeshData:
	if object == null or original_mesh == null or preview_mesh == null:
		return preview_mesh
	var clipping_modifiers: Array[GMSModifier] = []
	for modifier: GMSModifier in object.modifiers:
		if (
			modifier != null
			and modifier.enabled
			and modifier.kind == GMSModifier.Kind.MIRROR
			and modifier.clipping
		):
			clipping_modifiers.append(modifier)
	if clipping_modifiers.is_empty():
		return preview_mesh

	var affected_vertices: PackedInt32Array = _transform_vertex_indices.duplicate()
	if _transform_proportional_weights.size() == preview_mesh.vertices.size():
		affected_vertices.clear()
		for vertex_index: int in _transform_proportional_weights.size():
			if _transform_proportional_weights[vertex_index] > 0.0:
				affected_vertices.append(vertex_index)
	var result: GMSMeshData = preview_mesh.duplicate_mesh_data()
	for vertex_index: int in affected_vertices:
		if vertex_index < 0 or vertex_index >= result.vertices.size() or vertex_index >= original_mesh.vertices.size():
			continue
		var original: Vector3 = original_mesh.vertices[vertex_index]
		var current: Vector3 = result.vertices[vertex_index]
		for modifier: GMSModifier in clipping_modifiers:
			var threshold: float = maxf(modifier.merge_distance, 0.000001)
			if modifier.mirror_x and _should_clip_axis(original.x, current.x, threshold):
				current.x = 0.0
			if modifier.mirror_y and _should_clip_axis(original.y, current.y, threshold):
				current.y = 0.0
			if modifier.mirror_z and _should_clip_axis(original.z, current.z, threshold):
				current.z = 0.0
		result.vertices[vertex_index] = current
	result.emit_changed()
	return result


func _should_clip_axis(original_value: float, current_value: float, threshold: float) -> bool:
	return (
		absf(original_value) <= threshold
		or absf(current_value) <= threshold
		or (original_value < 0.0 and current_value > 0.0)
		or (original_value > 0.0 and current_value < 0.0)
	)


func _on_viewport_transform_committed() -> void:
	if not _transform_active or _document == null:
		return
	var changed: bool = false
	if _transform_selection_mode == GMSSelection.Mode.OBJECT:
		var final_transforms: Array[Transform3D] = []
		for object_id: String in _transform_object_ids:
			var transformed_object: GMSModelObject = _document.get_object(object_id)
			if transformed_object != null:
				final_transforms.append(transformed_object.transform)
		if final_transforms.size() == _transform_original_transforms.size():
			for index: int in final_transforms.size():
				if not final_transforms[index].is_equal_approx(_transform_original_transforms[index]):
					changed = true
					break
		_document.set_object_transforms(_transform_object_ids, _transform_original_transforms)
		_transform_active = false
		if changed:
			_history.set_transforms(
				_document,
				_transform_object_ids,
				final_transforms,
				_transform_action_name
			)
	elif _transform_dynamic_preview:
		changed = not _vector3_arrays_equal(
			_transform_original_vertex_positions, _transform_preview_vertex_positions
		)
		var preserved_array_mesh: ArrayMesh = _viewport.finish_dynamic_vertex_preview(changed)
		_transform_active = false
		if changed:
			_history.set_vertex_positions(
				_document,
				_transform_object_id,
				_transform_vertex_indices,
				_transform_original_vertex_positions,
				_transform_preview_vertex_positions,
				_transform_action_name,
				preserved_array_mesh
			)
	else:
		var object: GMSModelObject = _document.get_object(_transform_object_id)
		if object != null:
			var final_mesh: GMSMeshData = object.mesh_data
			changed = final_mesh != null and not _mesh_data_equal(_transform_original_mesh, final_mesh)
			_document.set_object_mesh(object.object_id, _transform_original_mesh)
			_transform_active = false
			if changed:
				_history.set_mesh(_document, object.object_id, final_mesh, _transform_action_name)

	var was_dirty: bool = _transform_was_dirty
	_restore_transform_selection()
	_clear_transform_context()
	if changed:
		_mark_dirty()
	else:
		_is_dirty = was_dirty
		_update_document_label()
	_update_status()


func _on_viewport_transform_cancelled() -> void:
	if not _transform_active or _document == null:
		return
	if _transform_selection_mode == GMSSelection.Mode.OBJECT:
		_document.set_object_transforms(_transform_object_ids, _transform_original_transforms)
	elif _transform_dynamic_preview:
		_viewport.finish_dynamic_vertex_preview(false)
	else:
		var object: GMSModelObject = _document.get_object(_transform_object_id)
		if object != null and _transform_original_mesh != null:
			_document.set_object_mesh(object.object_id, _transform_original_mesh)
	var was_dirty: bool = _transform_was_dirty
	_restore_transform_selection()
	_clear_transform_context()
	_is_dirty = was_dirty
	_update_document_label()
	_update_properties()
	_update_status()


func _on_viewport_transform_status_changed(text: String) -> void:
	if text.is_empty():
		if not _transform_active:
			_update_status()
		return
	_status_label.text = text


func _capture_transform_selection() -> void:
	_transform_selection_mode = _selection.mode
	_transform_selection_object_ids = _selection.object_ids.duplicate()
	_transform_selection_vertex_indices = _selection.vertex_indices.duplicate()
	_transform_selection_edge_indices = _selection.edge_indices.duplicate()
	_transform_selection_face_indices = _selection.face_indices.duplicate()


func _restore_transform_selection() -> void:
	_selection.restore_state(
		_transform_selection_mode,
		_transform_selection_object_ids,
		_transform_selection_vertex_indices,
		_transform_selection_edge_indices,
		_transform_selection_face_indices
	)
	if _viewport != null:
		_viewport.restore_selection_overlay()


func _clear_transform_context() -> void:
	_transform_active = false
	_transform_kind = GMSModelViewport.TransformKind.NONE
	_transform_object_id = ""
	_transform_object_ids.clear()
	_transform_original_transforms.clear()
	_transform_original_transform = Transform3D.IDENTITY
	_transform_original_mesh = null
	_transform_vertex_indices.clear()
	_transform_proportional_weights.clear()
	_transform_dynamic_preview = false
	_transform_original_vertex_positions.clear()
	_transform_preview_vertex_positions.clear()
	_transform_vertex_weights.clear()
	_transform_was_dirty = false
	_transform_action_name = ""
	_transform_selection_mode = GMSSelection.Mode.OBJECT
	_transform_selection_object_ids.clear()
	_transform_selection_vertex_indices.clear()
	_transform_selection_edge_indices.clear()
	_transform_selection_face_indices.clear()


func _vector3_arrays_equal(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		if not a[index].is_equal_approx(b[index]):
			return false
	return true


func _scale_basis_along_world_axis(
	source: Basis,
	axis_world: Vector3,
	factor: float
) -> Basis:
	var axis: Vector3 = axis_world.normalized()
	var scaled_x: Vector3 = source.x + axis * source.x.dot(axis) * (factor - 1.0)
	var scaled_y: Vector3 = source.y + axis * source.y.dot(axis) * (factor - 1.0)
	var scaled_z: Vector3 = source.z + axis * source.z.dot(axis) * (factor - 1.0)
	return Basis(scaled_x, scaled_y, scaled_z)


func _mesh_data_equal(a: GMSMeshData, b: GMSMeshData) -> bool:
	if a == null or b == null:
		return a == b
	return (
		a.vertices == b.vertices
		and a.faces == b.faces
		and a.smooth_faces == b.smooth_faces
		and a.uv_faces == b.uv_faces
		and a.has_uv_map == b.has_uv_map
		and a.corner_normals == b.corner_normals
		and a.has_custom_normals == b.has_custom_normals
		and a.loose_edges == b.loose_edges
		and a.crease_edges == b.crease_edges
		and a.crease_weights == b.crease_weights
		and a.seam_edges == b.seam_edges
		and a.face_materials == b.face_materials
	)


func _on_snap_toggled(_enabled: bool) -> void:
	_sync_snap_settings()


func _on_snap_element_selected(_index: int) -> void:
	_sync_snap_settings()


func _on_snap_base_selected(_index: int) -> void:
	_sync_snap_settings()


func _set_active_gizmo_mode(kind: int) -> void:
	for kind_value: Variant in _gizmo_buttons.keys():
		var button: Button = _gizmo_buttons[int(kind_value)] as Button
		if button != null:
			button.button_pressed = int(kind_value) == kind
	_sync_gizmo_settings()


func _on_gizmo_mode_pressed(_kind: int) -> void:
	_sync_gizmo_settings()


func _on_gizmo_visibility_toggled(_enabled: bool) -> void:
	_sync_gizmo_settings()


func _on_gizmo_orientation_selected(_index: int) -> void:
	_sync_gizmo_settings()


func _on_pivot_selected(_index: int) -> void:
	_sync_gizmo_settings()


func _on_xray_toggled(enabled: bool) -> void:
	if _viewport != null:
		_viewport.set_xray_enabled(enabled)


func _on_viewport_xray_toggled(enabled: bool) -> void:
	if _xray_button != null:
		_xray_button.set_pressed_no_signal(enabled)
	_on_xray_toggled(enabled)


func _on_proportional_toggled(enabled: bool) -> void:
	_proportional_enabled = enabled
	_proportional_radius_spin.editable = enabled
	_proportional_falloff_option.disabled = not enabled


func _on_viewport_snap_toggled(enabled: bool) -> void:
	_snap_button.set_pressed_no_signal(enabled)
	_sync_snap_settings()


func _popup_add_menu() -> void:
	if _selection.mode != GMSSelection.Mode.OBJECT:
		_status_label.text = "Shift+A mesh insertion is not implemented yet. Use Shift+A in Object mode."
		return
	if _add_menu == null:
		return
	var popup_position: Vector2 = _viewport.get_screen_position() + _viewport.get_local_mouse_position()
	_add_menu.position = Vector2i(popup_position)
	_add_menu.popup()


func _on_add_menu_id_pressed(id: int) -> void:
	if _extension_tool_menu_ids.has(id):
		_open_extension_tool(str(_extension_tool_menu_ids[id]))
		return
	match id:
		0:
			_add_primitive("Plane")
		1:
			_add_primitive("Cube")
		2:
			_add_primitive("Circle")
		3:
			_add_primitive("UV Sphere")
		4:
			_add_primitive("Icosphere")
		5:
			_add_primitive("Cylinder")
		6:
			_add_primitive("Cone")
		7:
			_add_primitive("Torus")
		8:
			_add_primitive("Grid")


func _popup_uv_menu() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		_status_label.text = "U requires one or more selected faces in Face mode."
		return
	if _uv_menu == null:
		return
	var popup_position: Vector2 = _viewport.get_screen_position() + _viewport.get_local_mouse_position()
	_uv_menu.position = Vector2i(popup_position)
	_uv_menu.popup()


func _on_uv_menu_id_pressed(id: int) -> void:
	_uv_projection_option.select(_uv_projection_option.get_item_index(id))
	_apply_uv_projection(id)


func _show_hotkeys() -> void:
	_show_window_centered(_hotkey_dialog)


func _on_help_menu_id_pressed(id: int) -> void:
	match id:
		HELP_MENU_HOTKEYS:
			_show_hotkeys()
		HELP_MENU_DOCUMENTATION:
			_show_documentation()
		HELP_MENU_REPORT_BUG:
			_open_help_url(REPORT_BUG_URL, "bug report")
		HELP_MENU_DONATE:
			_open_help_url(DONATION_URL, "donation page")
		HELP_MENU_ABOUT:
			_show_window_centered(_about_dialog)


func _show_documentation() -> void:
	_show_window_centered(_documentation_dialog)


func _on_documentation_topic_selected(index: int) -> void:
	_load_documentation_topic(index)


func _load_documentation_topic(index: int) -> void:
	if index < 0 or index >= _documentation_paths.size() or _documentation_text == null:
		return
	var path: String = _documentation_paths[index]
	if not FileAccess.file_exists(path):
		_documentation_text.text = "Documentation file is missing:\n%s" % path
		return
	var documentation_content: String = FileAccess.get_file_as_string(path)
	documentation_content = documentation_content.replace("{GMS_VERSION}", _plugin_version)
	documentation_content = documentation_content.replace(
		"{GMS_API_VERSION}",
		str(_extension_api_version)
	)
	_documentation_text.text = documentation_content
	_documentation_text.scroll_to_line(0)


func _open_help_url(url: String, label: String) -> void:
	var open_error: Error = OS.shell_open(url)
	if open_error != OK:
		_status_label.text = "Could not open the %s." % label


func _on_outliner_selected() -> void:
	var item: TreeItem = _outliner.get_selected()
	if item == null:
		return
	_selection.select_object(str(item.get_metadata(0)))


func _select_tree_item(object_id: String) -> void:
	var item: TreeItem = _tree_items.get(object_id) as TreeItem
	if item != null:
		item.select(0)


func _on_mode_pressed(mode: GMSSelection.Mode) -> void:
	if _transform_active or _animation_transform_bone_index >= 0:
		return
	_set_workspace_mode(WorkspaceMode.MODEL)
	if mode != GMSSelection.Mode.OBJECT:
		_last_edit_mode = mode
	_selection.set_mode(mode)


func _on_animate_mode_pressed() -> void:
	if _transform_active or _animation_transform_bone_index >= 0:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null or object.rig_data == null or object.rig_data.bones.is_empty():
		_status_label.text = "Select a rigged mesh object before entering Animate mode."
		_sync_mode_buttons()
		return
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_set_workspace_mode(WorkspaceMode.ANIMATE)
	_ensure_animation_clip_selection(object)
	_apply_animation_frame(true)


func _on_rig_mode_pressed() -> void:
	if _transform_active or _animation_transform_bone_index >= 0:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		_status_label.text = "Select a mesh object before entering Rig mode."
		_sync_mode_buttons()
		return
	_set_workspace_mode(WorkspaceMode.RIG)
	_on_rig_submode_pressed(_rig_submode)


func _set_workspace_mode(mode: int) -> void:
	var previous_mode: int = _workspace_mode
	_workspace_mode = clampi(mode, WorkspaceMode.MODEL, WorkspaceMode.ANIMATE)
	if previous_mode != _workspace_mode:
		_stop_animation_playback()
	if (
		previous_mode == WorkspaceMode.ANIMATE
		and _workspace_mode != WorkspaceMode.ANIMATE
	) or (previous_mode == WorkspaceMode.RIG and _workspace_mode == WorkspaceMode.MODEL):
		_reset_all_pose_previews()
	if previous_mode == WorkspaceMode.ANIMATE and _workspace_mode != WorkspaceMode.ANIMATE:
		_animation_selected_keys.clear()
		_animation_dirty_bones.clear()
	if _model_properties_root != null:
		_model_properties_root.visible = _workspace_mode == WorkspaceMode.MODEL
	if _rig_properties_root != null:
		_rig_properties_root.visible = _workspace_mode == WorkspaceMode.RIG
	if _animation_properties_root != null:
		_animation_properties_root.visible = _workspace_mode == WorkspaceMode.ANIMATE
	if _animation_timeline_panel != null:
		_animation_timeline_panel.visible = _workspace_mode == WorkspaceMode.ANIMATE
	_sync_mode_buttons()
	_sync_viewport_rig_state()
	_update_properties()


func _on_rig_submode_pressed(mode: int) -> void:
	if _workspace_mode != WorkspaceMode.RIG:
		return
	var previous_submode: int = _rig_submode
	_rig_submode = clampi(mode, RigSubmode.EDIT, RigSubmode.POSE)
	if previous_submode == RigSubmode.POSE and _rig_submode != RigSubmode.POSE:
		_reset_all_pose_previews()
	var button: Button = _rig_submode_buttons.get(_rig_submode) as Button
	if button != null:
		button.button_pressed = true
	if _rig_submode == RigSubmode.WEIGHTS:
		_selection.set_mode(GMSSelection.Mode.VERTEX)
	else:
		_selection.set_mode(GMSSelection.Mode.OBJECT)
	if _rig_edit_section != null:
		_rig_edit_section.visible = _rig_submode == RigSubmode.EDIT
	if _rig_weights_section != null:
		_rig_weights_section.visible = _rig_submode == RigSubmode.WEIGHTS
	if _rig_pose_section != null:
		_rig_pose_section.visible = _rig_submode == RigSubmode.POSE
	_sync_viewport_rig_state()
	_update_properties()


func _reset_all_pose_previews() -> void:
	if _document == null or _viewport == null:
		return
	for object: GMSModelObject in _document.objects:
		if object == null or object.rig_data == null:
			continue
		object.rig_data.reset_pose()
		_viewport.refresh_rig_preview(object.object_id)


func _sync_viewport_rig_state() -> void:
	if _viewport == null or _rig_brush_radius_spin == null:
		return
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_viewport.set_animation_state(true, _rig_selected_bone)
		return
	_viewport.set_rig_state(
		_workspace_mode == WorkspaceMode.RIG,
		_rig_submode,
		_rig_selected_bone,
		float(_rig_brush_radius_spin.value) / 100.0,
		float(_rig_brush_strength_spin.value),
		_rig_brush_mode_option.get_selected_id(),
		_rig_vertex_select_check.button_pressed
	)


func _update_rig_panel(object: GMSModelObject) -> void:
	if _rig_properties_root == null:
		return
	var rig: GMSRigData = object.rig_data if object != null else null
	if rig != null:
		rig.ensure_defaults()
	if rig == null or rig.bones.is_empty():
		_rig_selected_bone = -1
	elif _rig_selected_bone < 0 or _rig_selected_bone >= rig.bones.size():
		_rig_selected_bone = 0
	_refresh_rig_bone_tree(rig)
	_refresh_rig_bone_options(rig)
	_refresh_rig_parent_options(rig)
	_refresh_rig_attachment_list(object)

	var bone: GMSBoneData = null
	if rig != null and _rig_selected_bone >= 0 and _rig_selected_bone < rig.bones.size():
		bone = rig.bones[_rig_selected_bone]
	if bone == null:
		_rig_bone_name_edit.text = ""
		_set_vector_fields(_rig_head_fields, Vector3.ZERO)
		_set_vector_fields(_rig_tail_fields, Vector3.UP)
		_rig_roll_spin.value = 0.0
		_set_vector_fields(_rig_pose_rotation_fields, Vector3.ZERO)
	else:
		_rig_bone_name_edit.text = bone.display_name
		_set_vector_fields(_rig_head_fields, bone.head)
		_set_vector_fields(_rig_tail_fields, bone.tail)
		_rig_roll_spin.value = rad_to_deg(bone.roll)
		_set_vector_fields(_rig_pose_rotation_fields, rig.get_pose_rotation_degrees(_rig_selected_bone))

	var can_edit: bool = object != null and object.mesh_data != null and not object.locked
	_set_vector_editor_enabled(_rig_head_fields, can_edit and bone != null)
	_set_vector_editor_enabled(_rig_tail_fields, can_edit and bone != null)
	_set_vector_editor_enabled(_rig_pose_rotation_fields, can_edit and bone != null)
	_rig_bone_name_edit.editable = can_edit and bone != null
	_rig_parent_option.disabled = not can_edit or bone == null
	_rig_roll_spin.editable = can_edit and bone != null
	_rig_weight_bone_option.disabled = not can_edit or bone == null
	if object == null:
		_rig_status_label.text = "Select a mesh object to create or edit its armature."
	elif object.locked:
		_rig_status_label.text = "Unlock this object before editing its rig."
	elif rig == null or rig.bones.is_empty():
		_rig_status_label.text = "No armature. Add a root bone, then extrude the hierarchy."
	elif not rig.is_compatible(object.mesh_data.vertices.size()):
		_rig_status_label.text = "%d bones. Weights need to be regenerated for the current topology." % rig.bones.size()
	else:
		_rig_status_label.text = "%d bones | %d weighted vertices | four influences per vertex" % [
			rig.bones.size(),
			rig.get_vertex_count(),
		]
	_sync_viewport_rig_state()


func _refresh_rig_bone_tree(rig: GMSRigData) -> void:
	if _rig_bone_tree == null:
		return
	# Tree cannot be cleared or populated from inside one of its own selection
	# callbacks. The callback is deferred below, and signals are blocked here so
	# restoring the selected item cannot start another refresh.
	var previous_suppression: bool = _suppress_ui_signals
	_suppress_ui_signals = true
	_rig_bone_tree.set_block_signals(true)
	_rig_bone_tree.clear()
	var root: TreeItem = _rig_bone_tree.create_item()
	if root != null:
		root.set_metadata(0, -1)
	if root == null or rig == null:
		_rig_bone_tree.set_block_signals(false)
		_suppress_ui_signals = previous_suppression
		return
	var items: Array[TreeItem] = []
	items.resize(rig.bones.size())
	var selected_item: TreeItem = null
	for bone_index: int in rig.bones.size():
		var bone: GMSBoneData = rig.bones[bone_index]
		var parent_item: TreeItem = root
		if bone.parent_index >= 0 and bone.parent_index < items.size() and items[bone.parent_index] != null:
			parent_item = items[bone.parent_index]
		var item: TreeItem = _rig_bone_tree.create_item(parent_item)
		if item == null:
			continue
		item.set_text(0, bone.display_name)
		item.set_metadata(0, bone_index)
		items[bone_index] = item
		if bone_index == _rig_selected_bone:
			selected_item = item
	if selected_item != null:
		selected_item.select(0)
	_rig_bone_tree.set_block_signals(false)
	_suppress_ui_signals = previous_suppression


func _refresh_rig_bone_options(rig: GMSRigData) -> void:
	if _rig_weight_bone_option == null:
		return
	_rig_weight_bone_option.clear()
	if rig == null or rig.bones.is_empty():
		_rig_weight_bone_option.add_item("No Bones", -1)
		_rig_weight_bone_option.select(0)
		return
	for bone_index: int in rig.bones.size():
		_rig_weight_bone_option.add_item(rig.bones[bone_index].display_name, bone_index)
	var selected_item: int = _rig_weight_bone_option.get_item_index(_rig_selected_bone)
	_rig_weight_bone_option.select(maxi(selected_item, 0))


func _refresh_rig_parent_options(rig: GMSRigData) -> void:
	if _rig_parent_option == null:
		return
	_rig_parent_option.clear()
	_rig_parent_option.add_item("None", -1)
	if rig == null or _rig_selected_bone < 0 or _rig_selected_bone >= rig.bones.size():
		_rig_parent_option.select(0)
		return
	for bone_index: int in rig.bones.size():
		if bone_index == _rig_selected_bone or not rig.can_parent_bone(_rig_selected_bone, bone_index):
			continue
		_rig_parent_option.add_item(rig.bones[bone_index].display_name, bone_index)
	var parent_index: int = rig.bones[_rig_selected_bone].parent_index
	var item_index: int = _rig_parent_option.get_item_index(parent_index)
	_rig_parent_option.select(maxi(item_index, 0))


func _on_rig_parent_selected(_item_index: int) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or _rig_selected_bone < 0:
		return
	var parent_index: int = _rig_parent_option.get_selected_id()
	_reparent_bone(object, _rig_selected_bone, parent_index)


func _on_rig_bone_reparent_requested(bone_index: int, new_parent_index: int) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null:
		return
	_reparent_bone(object, bone_index, new_parent_index)


func _reparent_bone(object: GMSModelObject, bone_index: int, new_parent_index: int) -> void:
	var source_rig: GMSRigData = object.rig_data
	if source_rig == null or bone_index < 0 or bone_index >= source_rig.bones.size():
		return
	if new_parent_index >= source_rig.bones.size():
		return
	if source_rig.bones[bone_index].parent_index == new_parent_index:
		return
	var selected_bone_id: String = source_rig.bones[bone_index].bone_id
	var parent_bone_id: String = ""
	if new_parent_index >= 0:
		parent_bone_id = source_rig.bones[new_parent_index].bone_id
	var rig: GMSRigData = source_rig.duplicate_rig()
	var duplicate_bone_index: int = rig.find_bone_by_id(selected_bone_id)
	var duplicate_parent_index: int = rig.find_bone_by_id(parent_bone_id) if not parent_bone_id.is_empty() else -1
	if duplicate_bone_index < 0 or not rig.set_bone_parent(duplicate_bone_index, duplicate_parent_index):
		_rig_status_label.text = "Cannot parent a bone to itself or one of its descendants."
		return
	_rig_selected_bone = rig.find_bone_by_id(selected_bone_id)
	_history.set_rig(_document, object.object_id, rig, "Reparent Bone")


func _on_rig_bone_tree_selected() -> void:
	if _suppress_ui_signals:
		return
	var item: TreeItem = _rig_bone_tree.get_selected()
	if item == null:
		return
	var bone_index: int = int(item.get_metadata(0))
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_animation_ik_gizmo_control = GMSModelViewport.AnimationIKControl.NONE
		_viewport.set_animation_ik_control(_animation_ik_gizmo_control)
	if bone_index == _rig_selected_bone:
		return
	# Leave the Tree's internal blocked section before rebuilding panel data.
	call_deferred("_set_rig_selected_bone", bone_index)


func _on_viewport_rig_bone_clicked(bone_index: int) -> void:
	if _workspace_mode not in [WorkspaceMode.RIG, WorkspaceMode.ANIMATE]:
		return
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_animation_ik_gizmo_control = GMSModelViewport.AnimationIKControl.NONE
		_viewport.set_animation_ik_control(_animation_ik_gizmo_control)
	_set_rig_selected_bone(bone_index)
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_refresh_animation_pose_fields()
		_refresh_animation_timeline()


func _on_viewport_rig_bone_endpoint_dragged(
	object_id: String,
	bone_index: int,
	move_tail: bool,
	local_position: Vector3,
	phase: int
) -> void:
	var object: GMSModelObject = _document.get_object(object_id)
	if object == null or object.locked or object.rig_data == null:
		return
	match phase:
		0:
			_rig_drag_object_id = object_id
			_rig_drag_original = object.rig_data.duplicate_rig()
		1:
			if _rig_drag_original == null or _rig_drag_object_id != object_id:
				return
			var preview: GMSRigData = _rig_drag_original.duplicate_rig()
			if preview.move_bone_endpoint(bone_index, move_tail, local_position):
				_document.set_object_rig(object_id, preview)
		2:
			if _rig_drag_original == null or _rig_drag_object_id != object_id:
				return
			var final_rig: GMSRigData = _rig_drag_original.duplicate_rig()
			if final_rig.move_bone_endpoint(bone_index, move_tail, local_position):
				_document.set_object_rig(object_id, _rig_drag_original)
				_history.set_rig(_document, object_id, final_rig, "Move Bone Endpoint")
			_rig_drag_original = null
			_rig_drag_object_id = ""
		3:
			if _rig_drag_original != null and _rig_drag_object_id == object_id:
				_document.set_object_rig(object_id, _rig_drag_original)
			_rig_drag_original = null
			_rig_drag_object_id = ""


func _set_rig_selected_bone(bone_index: int) -> void:
	var object: GMSModelObject = _get_selected_object()
	var rig: GMSRigData = object.rig_data if object != null else null
	_rig_selected_bone = bone_index
	if rig == null or bone_index < 0 or bone_index >= rig.bones.size():
		_rig_selected_bone = -1
	_update_properties()


func _copy_or_create_rig(object: GMSModelObject) -> GMSRigData:
	var rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else GMSRigData.new()
	rig.ensure_defaults()
	return rig


func _on_rig_add_root_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.mesh_data == null:
		return
	var rig: GMSRigData = _copy_or_create_rig(object)
	var bounds: AABB = object.mesh_data.get_aabb()
	var head: Vector3 = bounds.get_center()
	head.y = bounds.position.y
	var tail: Vector3 = bounds.get_center()
	if tail.distance_to(head) < 0.001:
		tail = head + Vector3.UP
	var new_index: int = rig.add_root_bone(head, tail, "Root" if rig.bones.is_empty() else "Root Bone")
	_history.set_rig(_document, object.object_id, rig, "Add Root Bone")
	_rig_selected_bone = new_index
	_update_properties()


func _on_rig_extrude_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.mesh_data == null:
		return
	var rig: GMSRigData = _copy_or_create_rig(object)
	if rig.bones.is_empty():
		_on_rig_add_root_pressed()
		return
	var new_index: int = rig.extrude_bone(_rig_selected_bone)
	if new_index < 0:
		return
	_history.set_rig(_document, object.object_id, rig, "Extrude Bone")
	_rig_selected_bone = new_index
	_update_properties()


func _on_rig_delete_bone_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	if not rig.delete_bone(_rig_selected_bone):
		return
	_history.set_rig(_document, object.object_id, rig, "Delete Bone")
	_rig_selected_bone = mini(_rig_selected_bone, rig.bones.size() - 1)
	_update_properties()


func _on_rig_mirror_bone_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var mirrored_indices: PackedInt32Array = rig.mirror_bone_subtree_x(_rig_selected_bone)
	if mirrored_indices.is_empty():
		return
	_history.set_rig(_document, object.object_id, rig, "Mirror Bone Chain")
	_rig_selected_bone = mirrored_indices[0]
	_rig_status_label.text = "Mirrored %d bone%s across X." % [
		mirrored_indices.size(),
		"" if mirrored_indices.size() == 1 else "s",
	]
	_update_properties()


func _on_rig_bone_name_submitted(_value: String) -> void:
	_commit_rig_bone_name()


func _on_rig_bone_name_focus_exited() -> void:
	_commit_rig_bone_name()


func _commit_rig_bone_name() -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or _rig_selected_bone < 0:
		return
	if object.rig_data.bones[_rig_selected_bone].display_name == _rig_bone_name_edit.text.strip_edges():
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	rig.set_bone_name(_rig_selected_bone, _rig_bone_name_edit.text)
	_history.set_rig(_document, object.object_id, rig, "Rename Bone")


func _on_rig_apply_rest_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or _rig_selected_bone < 0:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	rig.set_bone_rest(
		_rig_selected_bone,
		_get_vector_fields(_rig_head_fields),
		_get_vector_fields(_rig_tail_fields),
		deg_to_rad(float(_rig_roll_spin.value))
	)
	_history.set_rig(_document, object.object_id, rig, "Edit Bone Rest")


func _get_selected_rig_attachment_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if _rig_attachment_list == null:
		return result
	for item_index: int in _rig_attachment_list.get_selected_items():
		var object_id: String = str(_rig_attachment_list.get_item_metadata(item_index))
		if not object_id.is_empty():
			result.append(object_id)
	return result


func _refresh_rig_attachment_list(rig_object: GMSModelObject) -> void:
	if _rig_attachment_list == null:
		return
	var previous_selection: PackedStringArray = _get_selected_rig_attachment_ids()
	_rig_attachment_list.clear()
	if _document == null or rig_object == null:
		_update_rig_attachment_buttons(rig_object)
		return
	for candidate: GMSModelObject in _document.objects:
		if candidate == null or candidate.object_id == rig_object.object_id:
			continue
		var label: String = candidate.display_name
		if candidate.has_bone_attachment():
			var owner: GMSModelObject = _document.get_object(candidate.attachment_rig_object_id)
			var owner_name: String = owner.display_name if owner != null else "Missing Rig"
			label += "  →  %s / %s" % [owner_name, candidate.attachment_bone_name]
		var item_index: int = _rig_attachment_list.add_item(label)
		_rig_attachment_list.set_item_metadata(item_index, candidate.object_id)
		var candidate_has_rig: bool = candidate.rig_data != null and candidate.rig_data.has_bones()
		var unavailable: bool = candidate.locked or candidate_has_rig
		_rig_attachment_list.set_item_disabled(item_index, unavailable)
		if candidate.locked:
			_rig_attachment_list.set_item_tooltip(item_index, "Unlock this object before attaching or detaching it.")
		elif candidate_has_rig:
			_rig_attachment_list.set_item_tooltip(item_index, "Bone attachments are for separate rigid objects without their own armature.")
		else:
			_rig_attachment_list.set_item_tooltip(item_index, "Attach %s to the active bone." % candidate.display_name)
		if previous_selection.has(candidate.object_id) and not unavailable:
			_rig_attachment_list.select(item_index, false)
	_update_rig_attachment_buttons(rig_object)


func _update_rig_attachment_buttons(rig_object: GMSModelObject = null) -> void:
	if _rig_attach_button == null or _rig_detach_button == null:
		return
	if rig_object == null:
		rig_object = _get_selected_object()
	var selected_ids: PackedStringArray = _get_selected_rig_attachment_ids()
	var valid_bone: bool = (
		rig_object != null
		and not rig_object.locked
		and rig_object.rig_data != null
		and _rig_selected_bone >= 0
		and _rig_selected_bone < rig_object.rig_data.bones.size()
	)
	_rig_attach_button.disabled = not valid_bone or selected_ids.is_empty()
	var has_attached: bool = false
	if _document != null:
		for object_id: String in selected_ids:
			var object: GMSModelObject = _document.get_object(object_id)
			if object != null and object.has_bone_attachment() and not object.locked:
				has_attached = true
				break
	_rig_detach_button.disabled = not has_attached


func _on_rig_attachment_selection_changed(_item_index: int) -> void:
	_update_rig_attachment_buttons()


func _on_rig_attachment_multi_selected(_item_index: int, _selected: bool) -> void:
	_update_rig_attachment_buttons()


func _attachment_would_create_cycle(object_id: String, rig_object_id: String) -> bool:
	if _document == null:
		return true
	var visited: Dictionary = {}
	var current_id: String = rig_object_id
	while not current_id.is_empty() and not visited.has(current_id):
		if current_id == object_id:
			return true
		visited[current_id] = true
		var current: GMSModelObject = _document.get_object(current_id)
		if current == null or not current.has_bone_attachment():
			break
		current_id = current.attachment_rig_object_id
	return false


func _on_rig_attach_objects_pressed() -> void:
	var rig_object: GMSModelObject = _get_selected_object()
	if (
		rig_object == null
		or rig_object.locked
		or rig_object.rig_data == null
		or _rig_selected_bone < 0
		or _rig_selected_bone >= rig_object.rig_data.bones.size()
	):
		return
	var bone: GMSBoneData = rig_object.rig_data.bones[_rig_selected_bone]
	var bone_world: Transform3D = rig_object.transform * rig_object.rig_data.get_bone_global_rest(_rig_selected_bone)
	var states: Array[Dictionary] = []
	var skipped: int = 0
	for object_id: String in _get_selected_rig_attachment_ids():
		var object: GMSModelObject = _document.get_object(object_id)
		if object == null or object.locked or (object.rig_data != null and object.rig_data.has_bones()):
			skipped += 1
			continue
		if _attachment_would_create_cycle(object.object_id, rig_object.object_id):
			skipped += 1
			continue
		var world_transform: Transform3D = _document.get_object_rest_world_transform(object.object_id)
		states.append({
			"object_id": object.object_id,
			"rig_object_id": rig_object.object_id,
			"bone_id": bone.bone_id,
			"bone_name": bone.display_name,
			"offset": bone_world.affine_inverse() * world_transform,
			"transform": world_transform,
		})
	if states.is_empty():
		_rig_attachment_status_label.text = "No valid rigid objects were selected."
		return
	_history.set_attachment_states(_document, states, "Attach Objects to Bone")
	_rig_attachment_status_label.text = "Attached %d object%s to %s.%s" % [
		states.size(),
		"" if states.size() == 1 else "s",
		bone.display_name,
		" %d object(s) were skipped." % skipped if skipped > 0 else "",
	]
	_refresh_rig_attachment_list(rig_object)


func _on_rig_detach_objects_pressed() -> void:
	if _document == null:
		return
	var states: Array[Dictionary] = []
	for object_id: String in _get_selected_rig_attachment_ids():
		var object: GMSModelObject = _document.get_object(object_id)
		if object == null or object.locked or not object.has_bone_attachment():
			continue
		var world_transform: Transform3D = _document.get_object_rest_world_transform(object.object_id)
		states.append({
			"object_id": object.object_id,
			"rig_object_id": "",
			"bone_id": "",
			"bone_name": "",
			"offset": Transform3D.IDENTITY,
			"transform": world_transform,
		})
	if states.is_empty():
		return
	_history.set_attachment_states(_document, states, "Detach Objects from Bone")
	_rig_attachment_status_label.text = "Detached %d object%s while preserving the current rest transform." % [
		states.size(), "" if states.size() == 1 else "s"
	]
	_refresh_rig_attachment_list(_get_selected_object())


func _on_rig_auto_weights_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.mesh_data == null or object.rig_data == null or object.rig_data.bones.is_empty():
		_rig_status_label.text = "Create at least one bone before generating weights."
		return
	for modifier: GMSModifier in object.modifiers:
		if modifier != null and modifier.enabled:
			_rig_status_label.text = "Apply the modifier stack before generating rig weights."
			return
	var evaluated_mesh: GMSMeshData = object.get_evaluated_mesh_data()
	if evaluated_mesh == null or evaluated_mesh.vertices.size() != object.mesh_data.vertices.size():
		_rig_status_label.text = "Apply topology-changing modifiers before generating rig weights."
		return
	_rig_status_label.text = "Generating automatic weights..."
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	if not rig.automatic_weights(object.mesh_data, int(_rig_auto_smooth_iterations.value)):
		_rig_status_label.text = "Automatic weighting failed."
		return
	_history.set_rig(_document, object.object_id, rig, "Generate Automatic Weights")
	_viewport.refresh_rig_preview(object.object_id)
	_rig_status_label.text = "Automatic weights generated for %d vertices." % object.mesh_data.vertices.size()


func _on_rig_weight_bone_selected(_item_index: int) -> void:
	if _suppress_ui_signals:
		return
	_set_rig_selected_bone(_rig_weight_bone_option.get_selected_id())


func _on_rig_vertex_select_toggled(_enabled: bool) -> void:
	if _suppress_ui_signals:
		return
	_sync_viewport_rig_state()


func _on_rig_brush_setting_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	_sync_viewport_rig_state()


func _on_viewport_rig_weight_brush_requested(
	object_id: String,
	local_point: Vector3,
	radius: float,
	strength: float,
	mode: int
) -> void:
	if _workspace_mode != WorkspaceMode.RIG or _rig_submode != RigSubmode.WEIGHTS or _rig_selected_bone < 0:
		return
	var object: GMSModelObject = _document.get_object(object_id)
	if object == null or object.locked or object.mesh_data == null or object.rig_data == null:
		return
	if not object.rig_data.is_compatible(object.mesh_data.vertices.size()):
		_rig_status_label.text = "Generate automatic weights for the current topology before painting."
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var affected: int = rig.apply_weight_brush(
		object.mesh_data,
		_rig_selected_bone,
		local_point,
		radius,
		strength,
		mode
	)
	if affected <= 0:
		return
	_history.set_rig(_document, object.object_id, rig, "Paint Bone Weights", true)
	_rig_status_label.text = "Adjusted %d vertices." % affected


func _on_rig_assign_weight_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or object.mesh_data == null or _rig_selected_bone < 0 or _selection.vertex_indices.is_empty():
		return
	if not object.rig_data.is_compatible(object.mesh_data.vertices.size()):
		_rig_status_label.text = "Generate automatic weights for the current topology first."
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	rig.assign_weight(_selection.vertex_indices, _rig_selected_bone, float(_rig_weight_value_spin.value))
	_history.set_rig(_document, object.object_id, rig, "Assign Vertex Weights")


func _on_rig_remove_weight_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or object.mesh_data == null or _rig_selected_bone < 0 or _selection.vertex_indices.is_empty():
		return
	if not object.rig_data.is_compatible(object.mesh_data.vertices.size()):
		_rig_status_label.text = "Generate automatic weights for the current topology first."
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	rig.remove_weight(_selection.vertex_indices, _rig_selected_bone)
	_history.set_rig(_document, object.object_id, rig, "Remove Vertex Weights")


func _on_rig_smooth_selected_weights_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null or object.mesh_data == null or _selection.vertex_indices.is_empty():
		return
	if not object.rig_data.is_compatible(object.mesh_data.vertices.size()):
		_rig_status_label.text = "Generate automatic weights for the current topology first."
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	rig.smooth_selected_weights(object.mesh_data, _selection.vertex_indices, 0.5)
	_history.set_rig(_document, object.object_id, rig, "Smooth Vertex Weights")


func _on_rig_mirror_weights_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.rig_data == null:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var mirrored: int = rig.mirror_weights_x(object.mesh_data)
	if mirrored <= 0:
		_rig_status_label.text = "No mirrored vertex pairs were found."
		return
	_history.set_rig(_document, object.object_id, rig, "Mirror Bone Weights")
	_rig_status_label.text = "Mirrored weights to %d vertices." % mirrored


func _on_rig_pose_rotation_changed(_value: float) -> void:
	if _suppress_ui_signals or _workspace_mode != WorkspaceMode.RIG or _rig_submode != RigSubmode.POSE:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.rig_data == null or _rig_selected_bone < 0:
		return
	object.rig_data.set_pose_rotation_degrees(_rig_selected_bone, _get_vector_fields(_rig_pose_rotation_fields))
	_viewport.refresh_rig_preview(object.object_id)


func _on_rig_reset_pose_bone_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.rig_data == null or _rig_selected_bone < 0:
		return
	object.rig_data.reset_pose(_rig_selected_bone)
	_viewport.refresh_rig_preview(object.object_id)
	_update_properties()


func _on_rig_reset_pose_all_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.rig_data == null:
		return
	object.rig_data.reset_pose()
	_viewport.refresh_rig_preview(object.object_id)
	_update_properties()


func _get_animation_object() -> GMSModelObject:
	var object: GMSModelObject = _get_selected_object()
	if (
		object == null
		or object.mesh_data == null
		or object.rig_data == null
		or object.rig_data.bones.is_empty()
	):
		return null
	return object


func _get_active_animation_clip(object: GMSModelObject = null) -> GMSAnimationClip:
	var target: GMSModelObject = object if object != null else _get_animation_object()
	if target == null or target.animation_data == null or _animation_active_clip_id.is_empty():
		return null
	return target.animation_data.find_clip(_animation_active_clip_id)


func _ensure_animation_clip_selection(object: GMSModelObject) -> void:
	if object == null or object.animation_data == null or object.animation_data.clips.is_empty():
		_animation_active_clip_id = ""
		_animation_current_frame = 0
		return
	object.animation_data.ensure_defaults(object.rig_data)
	if object.animation_data.find_clip(_animation_active_clip_id) == null:
		_animation_active_clip_id = object.animation_data.clips[0].clip_id
	var clip: GMSAnimationClip = object.animation_data.find_clip(_animation_active_clip_id)
	if clip != null:
		_animation_current_frame = clampi(_animation_current_frame, 0, clip.frame_count)


func _update_animation_panel(object: GMSModelObject) -> void:
	if _animation_properties_root == null:
		return
	var animation_object: GMSModelObject = object
	if (
		animation_object == null
		or animation_object.rig_data == null
		or animation_object.rig_data.bones.is_empty()
	):
		animation_object = null
	_ensure_animation_clip_selection(animation_object)
	var clip: GMSAnimationClip = _get_active_animation_clip(animation_object)

	_animation_clip_option.clear()
	if animation_object == null or animation_object.animation_data == null or animation_object.animation_data.clips.is_empty():
		_animation_clip_option.add_item("No Clips")
		_animation_clip_option.set_item_metadata(0, "")
		_animation_clip_option.select(0)
	else:
		for clip_index: int in animation_object.animation_data.clips.size():
			var candidate: GMSAnimationClip = animation_object.animation_data.clips[clip_index]
			_animation_clip_option.add_item(candidate.display_name)
			_animation_clip_option.set_item_metadata(clip_index, candidate.clip_id)
			if candidate.clip_id == _animation_active_clip_id:
				_animation_clip_option.select(clip_index)

	var has_clip: bool = animation_object != null and clip != null
	_animation_clip_option.disabled = animation_object == null
	_animation_clip_name_edit.editable = has_clip and not animation_object.locked
	_animation_fps_spin.editable = has_clip and not animation_object.locked
	_animation_frame_count_spin.editable = has_clip and not animation_object.locked
	_animation_loop_check.disabled = not has_clip or animation_object.locked
	_animation_clip_name_edit.text = clip.display_name if clip != null else ""
	_animation_fps_spin.value = clip.fps if clip != null else 24.0
	_animation_frame_count_spin.value = float(clip.frame_count if clip != null else 24)
	_animation_loop_check.button_pressed = clip.loop if clip != null else true
	_animation_frame_spin.max_value = float(clip.frame_count if clip != null else 1)
	_animation_frame_spin.value = float(_animation_current_frame)

	var rig: GMSRigData = animation_object.rig_data if animation_object != null else null
	var valid_bone: bool = (
		rig != null
		and _rig_selected_bone >= 0
		and _rig_selected_bone < rig.bones.size()
	)
	var editable_bone: bool = (
		has_clip
		and valid_bone
		and not animation_object.locked
		and not rig.bones[_rig_selected_bone].locked
	)
	_set_vector_editor_enabled(_animation_position_fields, editable_bone)
	_set_vector_editor_enabled(_animation_rotation_fields, editable_bone)
	_set_vector_editor_enabled(_animation_scale_fields, editable_bone)
	_refresh_animation_pose_fields(animation_object)

	_animation_pose_list.clear()
	if animation_object != null and animation_object.animation_data != null:
		for pose_index: int in animation_object.animation_data.poses.size():
			var pose: GMSPoseData = animation_object.animation_data.poses[pose_index]
			_animation_pose_list.add_item(pose.display_name)
			_animation_pose_list.set_item_metadata(pose_index, pose.pose_id)

	_update_animation_authoring_panels(animation_object, clip)

	if animation_object == null:
		_animation_status_label.text = "Select a rigged object before animating."
	elif clip == null:
		_animation_status_label.text = "Create an animation clip. GMS will generate bone tracks automatically when keys are inserted."
	else:
		_animation_status_label.text = "%s | %d frames at %d FPS | %d animated bone tracks%s" % [
			clip.display_name,
			clip.frame_count,
			int(clip.fps),
			clip.tracks.size(),
			" | loop" if clip.loop else "",
		]
	_refresh_animation_timeline(animation_object)

func _option_selected_metadata(option: OptionButton, fallback: Variant = null) -> Variant:
	if option == null or option.selected < 0 or option.selected >= option.get_item_count():
		return fallback
	return option.get_item_metadata(option.selected)


func _select_option_metadata(option: OptionButton, metadata: Variant) -> void:
	if option == null:
		return
	for item_index: int in option.get_item_count():
		if option.get_item_metadata(item_index) == metadata:
			option.select(item_index)
			return


func _update_animation_authoring_panels(object: GMSModelObject, clip: GMSAnimationClip) -> void:
	var rig: GMSRigData = object.rig_data if object != null else null
	if rig != null:
		rig.ensure_defaults()

	_animation_ik_chain_option.clear()
	if rig == null or rig.ik_chains.is_empty():
		_animation_ik_chain_option.add_item("No IK Chains")
		_animation_ik_chain_option.set_item_metadata(0, "")
		_animation_active_ik_chain_id = ""
		_animation_ik_gizmo_control = GMSModelViewport.AnimationIKControl.NONE
	else:
		if rig.find_ik_chain(_animation_active_ik_chain_id) == null:
			_animation_active_ik_chain_id = rig.ik_chains[0].chain_id
			_animation_ik_gizmo_control = GMSModelViewport.AnimationIKControl.TARGET
		for chain_index: int in rig.ik_chains.size():
			var chain: GMSIKChainData = rig.ik_chains[chain_index]
			_animation_ik_chain_option.add_item(chain.display_name)
			_animation_ik_chain_option.set_item_metadata(chain_index, chain.chain_id)
			if chain.chain_id == _animation_active_ik_chain_id:
				_animation_ik_chain_option.select(chain_index)
	_animation_ik_chain_option.disabled = rig == null
	var active_chain: GMSIKChainData = rig.find_ik_chain(_animation_active_ik_chain_id) if rig != null else null
	_animation_ik_root_option.clear()
	_animation_ik_tip_option.clear()
	if rig != null:
		for bone_index: int in rig.bones.size():
			var bone: GMSBoneData = rig.bones[bone_index]
			_animation_ik_root_option.add_item(bone.display_name)
			_animation_ik_root_option.set_item_metadata(bone_index, bone_index)
			_animation_ik_tip_option.add_item(bone.display_name)
			_animation_ik_tip_option.set_item_metadata(bone_index, bone_index)
	if active_chain != null:
		_select_option_metadata(_animation_ik_root_option, active_chain.resolve_root(rig))
		_select_option_metadata(_animation_ik_tip_option, active_chain.resolve_tip(rig))
		_set_vector_fields(_animation_ik_target_fields, active_chain.target_position)
		_set_vector_fields(_animation_ik_pole_fields, active_chain.pole_position)
		_animation_ik_iterations_spin.value = float(active_chain.iterations)
		_animation_ik_tolerance_spin.value = active_chain.tolerance
		_animation_ik_pole_influence_spin.value = active_chain.pole_influence
	else:
		_set_vector_fields(_animation_ik_target_fields, Vector3.ZERO)
		_set_vector_fields(_animation_ik_pole_fields, Vector3.ZERO)
	var chain_editable: bool = active_chain != null and object != null and not object.locked
	_animation_ik_root_option.disabled = not chain_editable
	_animation_ik_tip_option.disabled = not chain_editable
	_animation_ik_iterations_spin.editable = chain_editable
	_animation_ik_tolerance_spin.editable = chain_editable
	_animation_ik_pole_influence_spin.editable = chain_editable
	_set_vector_editor_enabled(_animation_ik_target_fields, chain_editable)
	_set_vector_editor_enabled(_animation_ik_pole_fields, chain_editable)

	_animation_constraint_list.clear()
	if rig != null:
		if rig.find_constraint(_animation_active_constraint_id) == null:
			_animation_active_constraint_id = rig.constraints[0].constraint_id if not rig.constraints.is_empty() else ""
		for constraint_index: int in rig.constraints.size():
			var constraint: GMSBoneConstraintData = rig.constraints[constraint_index]
			var label: String = "%s — %s" % [constraint.display_name, constraint.bone_name]
			_animation_constraint_list.add_item(label)
			_animation_constraint_list.set_item_metadata(constraint_index, constraint.constraint_id)
			if constraint.constraint_id == _animation_active_constraint_id:
				_animation_constraint_list.select(constraint_index)
	var active_constraint: GMSBoneConstraintData = rig.find_constraint(_animation_active_constraint_id) if rig != null else null
	_animation_constraint_target_option.clear()
	_animation_constraint_target_option.add_item("None")
	_animation_constraint_target_option.set_item_metadata(0, -1)
	if rig != null:
		for bone_index: int in rig.bones.size():
			_animation_constraint_target_option.add_item(rig.bones[bone_index].display_name)
			_animation_constraint_target_option.set_item_metadata(bone_index + 1, bone_index)
	if active_constraint != null:
		var type_index: int = _animation_constraint_type_option.get_item_index(active_constraint.type)
		if type_index >= 0:
			_animation_constraint_type_option.select(type_index)
		_select_option_metadata(_animation_constraint_target_option, active_constraint.resolve_target(rig))
		_animation_constraint_influence_spin.value = active_constraint.influence
		_set_vector_fields(_animation_constraint_min_fields, active_constraint.minimum_rotation_degrees)
		_set_vector_fields(_animation_constraint_max_fields, active_constraint.maximum_rotation_degrees)
		_animation_constraint_enabled_check.button_pressed = active_constraint.enabled
	else:
		_animation_constraint_influence_spin.value = 1.0
		_set_vector_fields(_animation_constraint_min_fields, Vector3(-180.0, -180.0, -180.0))
		_set_vector_fields(_animation_constraint_max_fields, Vector3(180.0, 180.0, 180.0))
		_animation_constraint_enabled_check.button_pressed = true
	var constraint_editable: bool = active_constraint != null and object != null and not object.locked
	_animation_constraint_type_option.disabled = not constraint_editable
	_animation_constraint_target_option.disabled = not constraint_editable or not active_constraint.requires_target()
	_animation_constraint_influence_spin.editable = constraint_editable
	_animation_constraint_enabled_check.disabled = not constraint_editable
	var limit_editable: bool = constraint_editable and active_constraint.type == GMSBoneConstraintData.Type.LIMIT_ROTATION
	_set_vector_editor_enabled(_animation_constraint_min_fields, limit_editable)
	_set_vector_editor_enabled(_animation_constraint_max_fields, limit_editable)

	_animation_root_motion_bone_option.clear()
	_animation_root_motion_bone_option.add_item("None")
	_animation_root_motion_bone_option.set_item_metadata(0, -1)
	if rig != null:
		for bone_index: int in rig.bones.size():
			_animation_root_motion_bone_option.add_item(rig.bones[bone_index].display_name)
			_animation_root_motion_bone_option.set_item_metadata(bone_index + 1, bone_index)
	if clip != null and rig != null:
		_select_option_metadata(_animation_root_motion_bone_option, clip.resolve_root_motion_bone(rig))
		_animation_root_axis_x.button_pressed = clip.root_motion_axes.x > 0.5
		_animation_root_axis_y.button_pressed = clip.root_motion_axes.y > 0.5
		_animation_root_axis_z.button_pressed = clip.root_motion_axes.z > 0.5
	else:
		_animation_root_motion_bone_option.select(0)
	_animation_root_motion_bone_option.disabled = clip == null or object == null or object.locked
	_animation_root_axis_x.disabled = clip == null or object == null or object.locked
	_animation_root_axis_y.disabled = clip == null or object == null or object.locked
	_animation_root_axis_z.disabled = clip == null or object == null or object.locked
	var has_root_motion_bone: bool = clip != null and rig != null and clip.resolve_root_motion_bone(rig) >= 0
	_animation_root_preview_in_place.disabled = not has_root_motion_bone
	_animation_root_show_path.disabled = not has_root_motion_bone
	_refresh_animation_curve_editor(object, clip)
	_refresh_animation_authoring_guides(object, clip)


func _get_animation_curve_context(object: GMSModelObject = null, clip: GMSAnimationClip = null) -> Dictionary:
	var target_object: GMSModelObject = object if object != null else _get_animation_object()
	var target_clip: GMSAnimationClip = clip if clip != null else _get_active_animation_clip(target_object)
	if target_object == null or target_clip == null or target_object.rig_data == null:
		return {}
	var bone_index: int = _rig_selected_bone
	var frame: int = _animation_current_frame
	if not _animation_selected_keys.is_empty():
		var parsed: Dictionary = _parse_animation_key_id(_animation_selected_keys[0])
		if not parsed.is_empty():
			bone_index = target_object.rig_data.find_bone_by_id(str(parsed["bone_id"]))
			frame = int(parsed["frame"])
	if bone_index < 0 or bone_index >= target_object.rig_data.bones.size():
		return {}
	var bone: GMSBoneData = target_object.rig_data.bones[bone_index]
	var track: GMSBoneAnimationTrack = target_clip.find_track(bone.bone_id, bone.display_name)
	var key_index: int = track.get_key_index(frame) if track != null else -1
	if key_index < 0 or key_index + 1 >= track.keys.size():
		return {}
	return {
		"bone_index": bone_index,
		"bone": bone,
		"track": track,
		"key": track.keys[key_index],
		"next_key": track.keys[key_index + 1],
	}


func _refresh_animation_curve_editor(object: GMSModelObject = null, clip: GMSAnimationClip = null) -> void:
	if _animation_curve_editor == null:
		return
	var context: Dictionary = _get_animation_curve_context(object, clip)
	var channel: int = _animation_curve_channel_option.get_selected_id() if _animation_curve_channel_option != null else 0
	if context.is_empty():
		_animation_curve_editor.set_curve_data(
			channel,
			Vector2(0.33, 0.0),
			Vector2(0.67, 1.0),
			false,
			"Select a key with a following key."
		)
		return
	var key: GMSAnimationKey = context["key"]
	var next_key: GMSAnimationKey = context["next_key"]
	var bone: GMSBoneData = context["bone"]
	var controls: Array[Vector2] = key.get_curve_controls(channel)
	_animation_curve_editor.set_curve_data(
		channel,
		controls[0],
		controls[1],
		true,
		"%s: frame %d → %d" % [bone.display_name, key.frame, next_key.frame]
	)
	var interpolation_index: int = _animation_interpolation_option.get_item_index(key.interpolation)
	if interpolation_index >= 0:
		_animation_interpolation_option.select(interpolation_index)


func _refresh_animation_authoring_guides(object: GMSModelObject = null, clip: GMSAnimationClip = null) -> void:
	if _viewport == null:
		return
	var target_object: GMSModelObject = object if object != null else _get_animation_object()
	var target_clip: GMSAnimationClip = clip if clip != null else _get_active_animation_clip(target_object)
	if target_object == null or target_object.rig_data == null or _workspace_mode != WorkspaceMode.ANIMATE:
		_viewport.clear_animation_authoring_guides()
		return
	var rig: GMSRigData = target_object.rig_data
	var chain_points: PackedVector3Array = PackedVector3Array()
	var target_position: Vector3 = Vector3.ZERO
	var pole_position: Vector3 = Vector3.ZERO
	var show_ik: bool = false
	var chain: GMSIKChainData = rig.find_ik_chain(_animation_active_ik_chain_id)
	if chain != null:
		var chain_indices: PackedInt32Array = chain.get_chain_indices(rig)
		var globals: Array[Transform3D] = rig.get_pose_global_transforms()
		for bone_index: int in chain_indices:
			chain_points.append(globals[bone_index].origin)
		if not chain_indices.is_empty():
			chain_points.append(rig.get_bone_tail_pose_position(chain_indices[chain_indices.size() - 1]))
		target_position = chain.target_position
		pole_position = chain.pole_position
		show_ik = true
	var root_path: PackedVector3Array = PackedVector3Array()
	if (
		target_clip != null
		and _animation_root_show_path != null
		and _animation_root_show_path.button_pressed
		and target_clip.resolve_root_motion_bone(rig) >= 0
	):
		root_path = target_clip.get_root_motion_path(rig, mini(target_clip.frame_count + 1, 512))
	_viewport.set_animation_authoring_guides(
		target_object.object_id,
		chain_points,
		target_position,
		pole_position,
		show_ik,
		root_path
	)
	_viewport.set_animation_ik_control(
		_animation_ik_gizmo_control
		if show_ik
		else GMSModelViewport.AnimationIKControl.NONE
	)


func _on_animation_ik_chain_selected(item_index: int) -> void:
	if _suppress_ui_signals or item_index < 0 or item_index >= _animation_ik_chain_option.get_item_count():
		return
	_animation_active_ik_chain_id = str(_animation_ik_chain_option.get_item_metadata(item_index))
	_animation_ik_gizmo_control = (
		GMSModelViewport.AnimationIKControl.TARGET
		if not _animation_active_ik_chain_id.is_empty()
		else GMSModelViewport.AnimationIKControl.NONE
	)
	_update_properties()


func _on_animation_new_ik_chain_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked or _rig_selected_bone < 0:
		return
	var tip_index: int = _rig_selected_bone
	var root_index: int = object.rig_data.bones[tip_index].parent_index
	if root_index >= 0 and object.rig_data.bones[root_index].parent_index >= 0:
		root_index = object.rig_data.bones[root_index].parent_index
	if root_index < 0:
		_animation_status_label.text = "Select an end bone with at least one parent before creating an IK chain."
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var chain: GMSIKChainData = rig.create_ik_chain(
		root_index,
		tip_index,
		"%s IK" % rig.bones[tip_index].display_name
	)
	if chain == null:
		_animation_status_label.text = "The selected root and tip do not form one parent chain."
		return
	_animation_active_ik_chain_id = chain.chain_id
	_animation_ik_gizmo_control = GMSModelViewport.AnimationIKControl.TARGET
	_history.set_rig(_document, object.object_id, rig, "Create IK Chain")


func _on_animation_delete_ik_chain_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked or _animation_active_ik_chain_id.is_empty():
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	if not rig.remove_ik_chain(_animation_active_ik_chain_id):
		return
	_animation_active_ik_chain_id = rig.ik_chains[0].chain_id if not rig.ik_chains.is_empty() else ""
	_animation_ik_gizmo_control = (
		GMSModelViewport.AnimationIKControl.TARGET
		if not rig.ik_chains.is_empty()
		else GMSModelViewport.AnimationIKControl.NONE
	)
	_history.set_rig(_document, object.object_id, rig, "Delete IK Chain")


func _on_animation_ik_settings_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var chain: GMSIKChainData = rig.find_ik_chain(_animation_active_ik_chain_id)
	if chain == null:
		return
	var root_index: int = int(_option_selected_metadata(_animation_ik_root_option, -1))
	var tip_index: int = int(_option_selected_metadata(_animation_ik_tip_option, -1))
	if root_index < 0 or tip_index < 0:
		return
	chain.root_bone_id = rig.bones[root_index].bone_id
	chain.root_bone_name = rig.bones[root_index].display_name
	chain.tip_bone_id = rig.bones[tip_index].bone_id
	chain.tip_bone_name = rig.bones[tip_index].display_name
	chain.target_position = _get_vector_fields(_animation_ik_target_fields)
	chain.pole_position = _get_vector_fields(_animation_ik_pole_fields)
	chain.iterations = int(_animation_ik_iterations_spin.value)
	chain.tolerance = float(_animation_ik_tolerance_spin.value)
	chain.pole_influence = float(_animation_ik_pole_influence_spin.value)
	chain.ensure_defaults(rig)
	if chain.get_chain_indices(rig).size() < 2:
		_animation_status_label.text = "IK root must be an ancestor of the tip bone."
		return
	_history.set_rig(_document, object.object_id, rig, "Change IK Chain", true)


func _on_animation_ik_target_from_tip_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var chain: GMSIKChainData = rig.find_ik_chain(_animation_active_ik_chain_id)
	if chain == null:
		return
	var tip_index: int = chain.resolve_tip(rig)
	if tip_index < 0:
		return
	chain.target_position = rig.get_bone_tail_pose_position(tip_index)
	_history.set_rig(_document, object.object_id, rig, "Set IK Target from Tip")


func _on_animation_ik_pole_from_bend_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var chain: GMSIKChainData = rig.find_ik_chain(_animation_active_ik_chain_id)
	if chain == null:
		return
	var indices: PackedInt32Array = chain.get_chain_indices(rig)
	if indices.size() < 3:
		_animation_status_label.text = "A pole target requires a chain with at least three bones."
		return
	var globals: Array[Transform3D] = rig.get_pose_global_transforms()
	var root_position: Vector3 = globals[indices[0]].origin
	var middle_position: Vector3 = globals[indices[1]].origin
	var tip_position: Vector3 = rig.get_bone_tail_pose_position(indices[indices.size() - 1])
	var bend: Vector3 = middle_position - root_position
	var chain_length: float = maxf(root_position.distance_to(tip_position), 0.1)
	if bend.is_zero_approx():
		bend = globals[indices[0]].basis.z
	chain.pole_position = middle_position + bend.normalized() * chain_length
	_history.set_rig(_document, object.object_id, rig, "Set IK Pole from Bend")


func _solve_active_ik(key_result: bool) -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var changed: PackedInt32Array = object.rig_data.solve_ik(
		_animation_active_ik_chain_id,
		_animation_live_constraints_check.button_pressed
	)
	var bones_to_key: PackedInt32Array = changed.duplicate()
	if key_result:
		var chain: GMSIKChainData = object.rig_data.find_ik_chain(_animation_active_ik_chain_id)
		if chain != null:
			for bone_index: int in chain.get_chain_indices(object.rig_data):
				if not bones_to_key.has(bone_index):
					bones_to_key.append(bone_index)
	if changed.is_empty() and not key_result:
		_animation_status_label.text = "IK target is already solved or the chain is invalid."
		return
	for bone_index: int in changed:
		_animation_dirty_bones[bone_index] = true
	if not changed.is_empty():
		_viewport.refresh_rig_preview(object.object_id)
		_refresh_animation_pose_fields(object)
		_refresh_animation_authoring_guides(object, _get_active_animation_clip(object))
	if key_result:
		if bones_to_key.is_empty():
			_animation_status_label.text = "The active IK chain is invalid."
			return
		_key_animation_bones(bones_to_key, "Key IK Pose")
	else:
		_animation_status_label.text = "Solved %d IK bones. Press Shift+K to store changed bones." % changed.size()


func _on_animation_solve_ik_pressed() -> void:
	_solve_active_ik(false)


func _on_animation_solve_and_key_ik_pressed() -> void:
	_solve_active_ik(true)


func _begin_animation_ik_control_transform(
	move_pole: bool,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false
) -> void:
	var object: GMSModelObject = _get_animation_object()
	var chain: GMSIKChainData = object.rig_data.find_ik_chain(_animation_active_ik_chain_id) if object != null else null
	if object == null or object.locked or chain == null:
		return
	_animation_ik_transform_object_id = object.object_id
	_animation_ik_transform_chain_id = chain.chain_id
	_animation_ik_transform_original_rig = object.rig_data.duplicate_rig()
	_animation_ik_transform_was_dirty = _is_dirty
	_animation_ik_transform_is_pole = move_pole
	var control_position: Vector3 = chain.pole_position if move_pole else chain.target_position
	if not _viewport.begin_animation_ik_target_transform(
		object.object_id,
		control_position,
		custom_axis,
		start_mouse_position,
		confirm_on_release
	):
		_clear_animation_ik_transform_context()


func _select_animation_ik_gizmo_control(control: int) -> void:
	var object: GMSModelObject = _get_animation_object()
	if (
		object == null
		or object.rig_data == null
		or object.rig_data.find_ik_chain(_animation_active_ik_chain_id) == null
	):
		return
	_animation_ik_gizmo_control = control
	_viewport.set_animation_ik_control(control)
	_animation_status_label.text = (
		"Drag the purple pole gizmo to control the limb bend."
		if control == GMSModelViewport.AnimationIKControl.POLE
		else "Drag the cyan target gizmo to pose the IK chain."
	)


func _on_animation_move_ik_target_pressed() -> void:
	_select_animation_ik_gizmo_control(GMSModelViewport.AnimationIKControl.TARGET)


func _on_animation_move_ik_pole_pressed() -> void:
	_select_animation_ik_gizmo_control(GMSModelViewport.AnimationIKControl.POLE)


func _on_viewport_animation_ik_control_selected(control: int) -> void:
	_animation_ik_gizmo_control = control
	if control == GMSModelViewport.AnimationIKControl.TARGET:
		_animation_status_label.text = "IK target selected. Drag the move gizmo; the chain solves continuously."
	elif control == GMSModelViewport.AnimationIKControl.POLE:
		_animation_status_label.text = "IK pole selected. Drag the move gizmo to control the bend direction."


func _on_viewport_animation_ik_target_transform_preview(world_delta: Vector3) -> void:
	if _animation_ik_transform_original_rig == null or _animation_ik_transform_object_id.is_empty():
		return
	var object: GMSModelObject = _document.get_object(_animation_ik_transform_object_id)
	if object == null:
		return
	var preview_rig: GMSRigData = _animation_ik_transform_original_rig.duplicate_rig()
	var chain: GMSIKChainData = preview_rig.find_ik_chain(_animation_ik_transform_chain_id)
	if chain == null:
		return
	var local_delta: Vector3 = object.transform.basis.inverse() * world_delta
	if _animation_ik_transform_is_pole:
		chain.pole_position += local_delta
	else:
		chain.target_position += local_delta
	preview_rig.solve_ik(chain.chain_id, _animation_live_constraints_check.button_pressed)
	object.rig_data = preview_rig
	_viewport.refresh_rig_preview(object.object_id)
	var previous_suppression: bool = _suppress_ui_signals
	_suppress_ui_signals = true
	_set_vector_fields(_animation_ik_target_fields, chain.target_position)
	_set_vector_fields(_animation_ik_pole_fields, chain.pole_position)
	_suppress_ui_signals = previous_suppression
	_refresh_animation_pose_fields(object)
	_refresh_animation_authoring_guides(object, _get_active_animation_clip(object))


func _on_viewport_animation_ik_target_transform_committed() -> void:
	if _animation_ik_transform_original_rig == null:
		return
	var object: GMSModelObject = _document.get_object(_animation_ik_transform_object_id)
	if object == null or object.rig_data == null:
		_clear_animation_ik_transform_context()
		return
	var old_rig: GMSRigData = _animation_ik_transform_original_rig
	var new_rig: GMSRigData = object.rig_data.duplicate_rig()
	var changed: PackedInt32Array = PackedInt32Array()
	var old_offsets: Array[Transform3D] = old_rig.get_pose_offsets()
	var new_offsets: Array[Transform3D] = new_rig.get_pose_offsets()
	for bone_index: int in mini(old_offsets.size(), new_offsets.size()):
		if not GMSRigData._transform_approximately_equal(old_offsets[bone_index], new_offsets[bone_index]):
			changed.append(bone_index)
	_history.set_rig_states(
		_document,
		object.object_id,
		old_rig,
		new_rig,
		"Move IK Pole" if _animation_ik_transform_is_pole else "Move IK Target"
	)
	_clear_animation_ik_transform_context()
	for bone_index: int in changed:
		_animation_dirty_bones[bone_index] = true
	if _animation_auto_key_check.button_pressed and not changed.is_empty():
		_key_animation_bones(changed, "Auto Key IK")
	elif not changed.is_empty():
		_animation_status_label.text = "IK pose updated. Press Shift+K or Key IK Pose to store it."


func _on_viewport_animation_ik_target_transform_cancelled() -> void:
	if _animation_ik_transform_original_rig != null and not _animation_ik_transform_object_id.is_empty():
		var object: GMSModelObject = _document.get_object(_animation_ik_transform_object_id)
		if object != null:
			object.set_rig_data(_animation_ik_transform_original_rig)
			_viewport.refresh_rig_preview(object.object_id)
	_is_dirty = _animation_ik_transform_was_dirty
	_clear_animation_ik_transform_context()
	_update_properties()


func _clear_animation_ik_transform_context() -> void:
	_animation_ik_transform_object_id = ""
	_animation_ik_transform_chain_id = ""
	_animation_ik_transform_original_rig = null
	_animation_ik_transform_was_dirty = false
	_animation_ik_transform_is_pole = false


func _on_animation_constraint_selected(item_index: int) -> void:
	if _suppress_ui_signals or item_index < 0 or item_index >= _animation_constraint_list.get_item_count():
		return
	_animation_active_constraint_id = str(_animation_constraint_list.get_item_metadata(item_index))
	_update_properties()


func _on_animation_add_constraint_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked or _rig_selected_bone < 0:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var constraint: GMSBoneConstraintData = rig.create_constraint(_rig_selected_bone)
	if constraint == null:
		return
	_animation_active_constraint_id = constraint.constraint_id
	_history.set_rig(_document, object.object_id, rig, "Add Bone Constraint")


func _on_animation_delete_constraint_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked or _animation_active_constraint_id.is_empty():
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	if not rig.remove_constraint(_animation_active_constraint_id):
		return
	_animation_active_constraint_id = rig.constraints[0].constraint_id if not rig.constraints.is_empty() else ""
	_history.set_rig(_document, object.object_id, rig, "Delete Bone Constraint")


func _on_animation_constraint_settings_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var rig: GMSRigData = object.rig_data.duplicate_rig()
	var constraint: GMSBoneConstraintData = rig.find_constraint(_animation_active_constraint_id)
	if constraint == null:
		return
	constraint.type = _animation_constraint_type_option.get_selected_id()
	var target_index: int = int(_option_selected_metadata(_animation_constraint_target_option, -1))
	if target_index >= 0 and target_index < rig.bones.size():
		constraint.target_bone_id = rig.bones[target_index].bone_id
		constraint.target_bone_name = rig.bones[target_index].display_name
	else:
		constraint.target_bone_id = ""
		constraint.target_bone_name = ""
	constraint.influence = float(_animation_constraint_influence_spin.value)
	constraint.minimum_rotation_degrees = _get_vector_fields(_animation_constraint_min_fields)
	constraint.maximum_rotation_degrees = _get_vector_fields(_animation_constraint_max_fields)
	constraint.enabled = _animation_constraint_enabled_check.button_pressed
	constraint.ensure_defaults(rig)
	if constraint.requires_target() and constraint.resolve_target(rig) < 0:
		_animation_status_label.text = "This constraint type requires a target bone."
		return
	_history.set_rig(_document, object.object_id, rig, "Change Bone Constraint", true)
	_apply_animation_frame(false)


func _apply_live_constraints_to_pose(object: GMSModelObject, mark_dirty: bool = true) -> PackedInt32Array:
	var changed: PackedInt32Array = PackedInt32Array()
	if (
		object == null
		or object.rig_data == null
		or _animation_live_constraints_check == null
		or not _animation_live_constraints_check.button_pressed
	):
		return changed
	changed = object.rig_data.apply_constraints()
	if mark_dirty:
		for bone_index: int in changed:
			_animation_dirty_bones[bone_index] = true
	return changed


func _on_animation_live_constraints_toggled(_enabled: bool) -> void:
	if _suppress_ui_signals:
		return
	_apply_animation_frame(true)


func _on_animation_apply_constraints_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null:
		return
	var changed: PackedInt32Array = object.rig_data.apply_constraints()
	if changed.is_empty():
		_animation_status_label.text = "Constraints made no pose changes."
		return
	for bone_index: int in changed:
		_animation_dirty_bones[bone_index] = true
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Apply and Key Constraints")


func _on_animation_curve_channel_selected(_item_index: int) -> void:
	if _suppress_ui_signals:
		return
	_refresh_animation_curve_editor()


func _on_animation_curve_committed(channel: int, control_1: Vector2, control_2: Vector2) -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	var context: Dictionary = _get_animation_curve_context(object, clip)
	if object == null or object.locked or clip == null or context.is_empty():
		return
	var bone: GMSBoneData = context["bone"]
	var key: GMSAnimationKey = context["key"]
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	if not target.set_custom_curve(bone.bone_id, bone.display_name, key.frame, channel, control_1, control_2):
		return
	_history.set_animation_data(_document, object.object_id, data, "Edit Animation Curve")
	_apply_animation_frame(false)


func _on_animation_root_motion_bone_selected(item_index: int) -> void:
	if _suppress_ui_signals or item_index < 0:
		return
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	var bone_index: int = int(_animation_root_motion_bone_option.get_item_metadata(item_index))
	if bone_index >= 0 and bone_index < object.rig_data.bones.size():
		target.set_root_motion_bone(object.rig_data.bones[bone_index])
	else:
		target.clear_root_motion_bone()
	_history.set_animation_data(_document, object.object_id, data, "Set Root Motion Bone")


func _on_animation_root_motion_settings_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	target.root_motion_axes = Vector3(
		1.0 if _animation_root_axis_x.button_pressed else 0.0,
		1.0 if _animation_root_axis_y.button_pressed else 0.0,
		1.0 if _animation_root_axis_z.button_pressed else 0.0
	)
	_history.set_animation_data(_document, object.object_id, data, "Change Root Motion Axes", true)
	_apply_animation_frame(false)


func _on_animation_root_preview_toggled(_enabled: bool) -> void:
	if _suppress_ui_signals:
		return
	_apply_animation_frame(true)


func _on_animation_root_path_toggled(_enabled: bool) -> void:
	if _suppress_ui_signals:
		return
	_refresh_animation_authoring_guides()


func _on_animation_convert_root_motion_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	if not target.convert_root_motion_to_in_place(object.rig_data):
		_animation_status_label.text = "Assign a root-motion bone with keyed movement first."
		return
	_history.set_animation_data(_document, object.object_id, data, "Convert Animation In Place")
	_apply_animation_frame(true)


func _on_animation_remove_root_drift_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	if not target.remove_root_motion_loop_drift(object.rig_data):
		_animation_status_label.text = "The selected root-motion track has no removable loop drift."
		return
	_history.set_animation_data(_document, object.object_id, data, "Remove Root Motion Loop Drift")
	_apply_animation_frame(true)


func _refresh_animation_pose_fields(object: GMSModelObject = null) -> void:
	var target: GMSModelObject = object if object != null else _get_animation_object()
	var previous_suppression: bool = _suppress_ui_signals
	_suppress_ui_signals = true
	if (
		target == null
		or target.rig_data == null
		or _rig_selected_bone < 0
		or _rig_selected_bone >= target.rig_data.bones.size()
	):
		_set_vector_fields(_animation_position_fields, Vector3.ZERO)
		_set_vector_fields(_animation_rotation_fields, Vector3.ZERO)
		_set_vector_fields(_animation_scale_fields, Vector3.ONE)
	else:
		var offset: Transform3D = target.rig_data.get_pose_offset(_rig_selected_bone)
		_set_vector_fields(_animation_position_fields, offset.origin)
		_set_vector_fields(_animation_rotation_fields, offset.basis.get_rotation_quaternion().get_euler() * 180.0 / PI)
		_set_vector_fields(_animation_scale_fields, offset.basis.get_scale())
	_suppress_ui_signals = previous_suppression


func _refresh_animation_timeline(object: GMSModelObject = null) -> void:
	if _animation_timeline == null:
		return
	var target: GMSModelObject = object if object != null else _get_animation_object()
	var rig: GMSRigData = target.rig_data if target != null else null
	_animation_timeline.set_timeline_data(
		rig,
		_get_active_animation_clip(target),
		_animation_current_frame,
		_rig_selected_bone,
		_animation_selected_keys
	)
	if _animation_frame_spin != null:
		var previous_suppression: bool = _suppress_ui_signals
		_suppress_ui_signals = true
		_animation_frame_spin.value = float(_animation_current_frame)
		_suppress_ui_signals = previous_suppression
	_refresh_animation_curve_editor(target, _get_active_animation_clip(target))
	_refresh_animation_authoring_guides(target, _get_active_animation_clip(target))


func _apply_animation_frame(clear_dirty: bool = true) -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.rig_data == null:
		return
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if clip == null:
		object.rig_data.reset_pose()
	else:
		object.rig_data.apply_pose_offsets(clip.sample_pose(
			object.rig_data,
			float(_animation_current_frame),
			_animation_root_preview_in_place != null and _animation_root_preview_in_place.button_pressed
		))
	_apply_live_constraints_to_pose(object, false)
	_viewport.refresh_rig_preview(object.object_id)
	if clear_dirty:
		_animation_dirty_bones.clear()
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)


func _set_animation_current_frame(frame: int, clear_dirty: bool = true) -> void:
	var clip: GMSAnimationClip = _get_active_animation_clip()
	_animation_current_frame = clampi(frame, 0, clip.frame_count if clip != null else 0)
	_apply_animation_frame(clear_dirty)


func _on_animation_clip_selected(item_index: int) -> void:
	if _suppress_ui_signals or item_index < 0 or item_index >= _animation_clip_option.get_item_count():
		return
	_stop_animation_playback()
	_animation_active_clip_id = str(_animation_clip_option.get_item_metadata(item_index))
	_animation_current_frame = 0
	_animation_selected_keys.clear()
	_apply_animation_frame(true)
	_update_properties()


func _on_animation_new_clip_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data() if object.animation_data != null else GMSAnimationData.new()
	var clip: GMSAnimationClip = data.create_clip("Animation")
	_history.set_animation_data(_document, object.object_id, data, "Create Animation Clip")
	_animation_active_clip_id = clip.clip_id
	_animation_current_frame = 0
	_animation_selected_keys.clear()
	_apply_animation_frame(true)


func _on_animation_duplicate_clip_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var source: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or source == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var source_copy: GMSAnimationClip = data.find_clip(source.clip_id)
	var duplicate: GMSAnimationClip = source_copy.duplicate_clip()
	duplicate.clip_id = ""
	duplicate.display_name = "%s Copy" % source.display_name
	duplicate.ensure_defaults(object.rig_data)
	data.clips.append(duplicate)
	data.ensure_defaults(object.rig_data)
	_history.set_animation_data(_document, object.object_id, data, "Duplicate Animation Clip")
	_animation_active_clip_id = duplicate.clip_id
	_animation_current_frame = 0
	_animation_selected_keys.clear()
	_apply_animation_frame(true)


func _on_animation_delete_clip_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null or object.animation_data == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	data.remove_clip(clip.clip_id)
	_history.set_animation_data(_document, object.object_id, data, "Delete Animation Clip")
	_animation_active_clip_id = data.clips[0].clip_id if not data.clips.is_empty() else ""
	_animation_current_frame = 0
	_animation_selected_keys.clear()
	_apply_animation_frame(true)


func _on_animation_clip_name_submitted(_value: String) -> void:
	_commit_animation_clip_name()


func _on_animation_clip_name_focus_exited() -> void:
	_commit_animation_clip_name()


func _commit_animation_clip_name() -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var cleaned: String = _animation_clip_name_edit.text.strip_edges()
	if cleaned.is_empty() or cleaned == clip.display_name:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	target.display_name = cleaned
	data.ensure_defaults(object.rig_data)
	_history.set_animation_data(_document, object.object_id, data, "Rename Animation Clip")


func _on_animation_clip_settings_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	target.fps = clampf(float(_animation_fps_spin.value), 1.0, 240.0)
	target.frame_count = clampi(int(_animation_frame_count_spin.value), 1, 100000)
	target.loop = _animation_loop_check.button_pressed
	target.ensure_defaults(object.rig_data)
	_animation_current_frame = clampi(_animation_current_frame, 0, target.frame_count)
	_history.set_animation_data(_document, object.object_id, data, "Change Animation Settings", true)


func _on_animation_interpolation_selected(_item_index: int) -> void:
	if _suppress_ui_signals or _animation_selected_keys.is_empty():
		return
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	var changed: bool = false
	for key_id: String in _animation_selected_keys:
		var parsed: Dictionary = _parse_animation_key_id(key_id)
		if parsed.is_empty():
			continue
		var bone_index: int = object.rig_data.find_bone_by_id(str(parsed["bone_id"]))
		if bone_index < 0:
			continue
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		changed = target.set_key_interpolation(
			bone.bone_id,
			bone.display_name,
			int(parsed["frame"]),
			_animation_interpolation_option.get_selected_id()
		) or changed
	if changed:
		_history.set_animation_data(_document, object.object_id, data, "Change Key Interpolation")
		_apply_animation_frame(false)


func _on_animation_pose_field_changed(_value: float) -> void:
	if _suppress_ui_signals or _workspace_mode != WorkspaceMode.ANIMATE:
		return
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked or _get_active_animation_clip(object) == null:
		return
	if _rig_selected_bone < 0 or _rig_selected_bone >= object.rig_data.bones.size():
		return
	if object.rig_data.bones[_rig_selected_bone].locked:
		return
	var rotation_degrees: Vector3 = _get_vector_fields(_animation_rotation_fields)
	var offset: Transform3D = Transform3D(
		Basis(Quaternion.from_euler(rotation_degrees * PI / 180.0)).scaled(_get_vector_fields(_animation_scale_fields)),
		_get_vector_fields(_animation_position_fields)
	)
	object.rig_data.set_pose_offset(_rig_selected_bone, offset)
	_animation_dirty_bones[_rig_selected_bone] = true
	var changed: PackedInt32Array = PackedInt32Array([_rig_selected_bone])
	for constrained_index: int in _apply_live_constraints_to_pose(object):
		if not changed.has(constrained_index):
			changed.append(constrained_index)
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Auto Key Bone", true)


func _key_animation_bones(
	bone_indices: PackedInt32Array,
	action_name: String,
	merge_ends: bool = false
) -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null or bone_indices.is_empty():
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	var interpolation: int = _animation_interpolation_option.get_selected_id()
	var keyed: int = 0
	for bone_index: int in bone_indices:
		if bone_index < 0 or bone_index >= object.rig_data.bones.size():
			continue
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		if target.set_bone_key(
			bone,
			_animation_current_frame,
			object.rig_data.get_pose_offset(bone_index),
			interpolation
		):
			keyed += 1
			_animation_dirty_bones.erase(bone_index)
			_animation_selected_keys.append(_animation_key_id(bone.bone_id, _animation_current_frame))
	if keyed <= 0:
		return
	_animation_selected_keys = _unique_strings(_animation_selected_keys)
	_history.set_animation_data(_document, object.object_id, data, action_name, merge_ends)
	_animation_status_label.text = "Keyed %d bone%s at frame %d." % [keyed, "" if keyed == 1 else "s", _animation_current_frame]
	_refresh_animation_timeline(object)


func _on_animation_key_selected_bone_pressed() -> void:
	if _rig_selected_bone >= 0:
		_key_animation_bones(PackedInt32Array([_rig_selected_bone]), "Key Bone")


func _on_animation_key_changed_bones_pressed() -> void:
	var indices: PackedInt32Array = PackedInt32Array()
	for bone_value: Variant in _animation_dirty_bones.keys():
		indices.append(int(bone_value))
	if indices.is_empty():
		_animation_status_label.text = "No changed bones need keys."
		return
	_key_animation_bones(indices, "Key Changed Bones")


func _on_animation_key_full_pose_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null:
		return
	var indices: PackedInt32Array = PackedInt32Array()
	for bone_index: int in object.rig_data.bones.size():
		indices.append(bone_index)
	_key_animation_bones(indices, "Key Full Pose")


func _animation_chain_indices(rig: GMSRigData, root_index: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if rig == null or root_index < 0 or root_index >= rig.bones.size():
		return result
	result.append(root_index)
	var cursor: int = 0
	while cursor < result.size():
		var parent_index: int = result[cursor]
		for bone_index: int in rig.bones.size():
			if rig.bones[bone_index].parent_index == parent_index:
				result.append(bone_index)
		cursor += 1
	return result


func _reset_animation_bones(indices: PackedInt32Array) -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null:
		return
	for bone_index: int in indices:
		if bone_index < 0 or bone_index >= object.rig_data.bones.size():
			continue
		if object.rig_data.bones[bone_index].locked:
			continue
		object.rig_data.reset_pose(bone_index)
		_animation_dirty_bones[bone_index] = true
	var changed: PackedInt32Array = indices.duplicate()
	for constrained_index: int in _apply_live_constraints_to_pose(object):
		if not changed.has(constrained_index):
			changed.append(constrained_index)
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Auto Key Reset Pose")


func _on_animation_reset_bone_pressed() -> void:
	if _rig_selected_bone >= 0:
		_reset_animation_bones(PackedInt32Array([_rig_selected_bone]))


func _on_animation_reset_chain_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object != null:
		_reset_animation_bones(_animation_chain_indices(object.rig_data, _rig_selected_bone))


func _on_animation_reset_all_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null:
		return
	var indices: PackedInt32Array = PackedInt32Array()
	for bone_index: int in object.rig_data.bones.size():
		indices.append(bone_index)
	_reset_animation_bones(indices)


func _capture_animation_pose(indices: PackedInt32Array) -> Dictionary:
	var object: GMSModelObject = _get_animation_object()
	var result: Dictionary = {}
	if object == null:
		return result
	for bone_index: int in indices:
		if bone_index < 0 or bone_index >= object.rig_data.bones.size():
			continue
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		result[bone.bone_id] = {
			"bone_name": bone.display_name,
			"offset": object.rig_data.get_pose_offset(bone_index),
		}
	return result


func _on_animation_copy_bone_pose_pressed() -> void:
	if _rig_selected_bone < 0:
		return
	_animation_pose_clipboard = _capture_animation_pose(PackedInt32Array([_rig_selected_bone]))
	_animation_status_label.text = "Copied the active bone pose."


func _on_animation_copy_full_pose_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null:
		return
	var indices: PackedInt32Array = PackedInt32Array()
	for bone_index: int in object.rig_data.bones.size():
		indices.append(bone_index)
	_animation_pose_clipboard = _capture_animation_pose(indices)
	_animation_status_label.text = "Copied the full pose."


func _mirrored_pose_offset_x(offset: Transform3D) -> Transform3D:
	var mirror: Basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var mirrored_basis: Basis = mirror * offset.basis * mirror
	return Transform3D(mirrored_basis, Vector3(-offset.origin.x, offset.origin.y, offset.origin.z))


func _animation_bone_has_explicit_side(name: String) -> bool:
	return (
		name.ends_with(".L")
		or name.ends_with(".R")
		or name.ends_with("_L")
		or name.ends_with("_R")
		or name.begins_with("Left ")
		or name.begins_with("Right ")
	)


func _paste_animation_pose(mirrored: bool) -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or _animation_pose_clipboard.is_empty():
		return
	var changed: PackedInt32Array = PackedInt32Array()
	for source_id_value: Variant in _animation_pose_clipboard.keys():
		var source_id: String = str(source_id_value)
		var source_index: int = object.rig_data.find_bone_by_id(source_id)
		var target_index: int = source_index
		if mirrored and source_index >= 0:
			var source_bone: GMSBoneData = object.rig_data.bones[source_index]
			var mirrored_index: int = object.rig_data.find_mirrored_bone(source_index)
			if mirrored_index >= 0:
				target_index = mirrored_index
			elif _animation_bone_has_explicit_side(source_bone.display_name):
				target_index = -1
		if target_index < 0:
			continue
		if object.rig_data.bones[target_index].locked:
			continue
		var entry: Dictionary = _animation_pose_clipboard[source_id]
		var offset: Transform3D = entry.get("offset", Transform3D.IDENTITY)
		object.rig_data.set_pose_offset(target_index, _mirrored_pose_offset_x(offset) if mirrored else offset)
		_animation_dirty_bones[target_index] = true
		changed.append(target_index)
	if changed.is_empty():
		return
	for constrained_index: int in _apply_live_constraints_to_pose(object):
		if not changed.has(constrained_index):
			changed.append(constrained_index)
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Paste Mirrored Pose" if mirrored else "Paste Pose")


func _on_animation_paste_pose_pressed() -> void:
	_paste_animation_pose(false)


func _on_animation_paste_mirrored_pose_pressed() -> void:
	_paste_animation_pose(true)


func _on_animation_save_pose_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or object.locked:
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data() if object.animation_data != null else GMSAnimationData.new()
	var pose_name: String = _animation_pose_name_edit.text.strip_edges()
	if pose_name.is_empty():
		pose_name = "Pose"
	data.create_pose(pose_name, object.rig_data)
	_history.set_animation_data(_document, object.object_id, data, "Save Pose")
	_animation_pose_name_edit.text = ""


func _get_selected_pose_id() -> String:
	var selected: PackedInt32Array = _animation_pose_list.get_selected_items()
	if selected.is_empty():
		return ""
	return str(_animation_pose_list.get_item_metadata(selected[0]))


func _on_animation_apply_pose_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var pose_id: String = _get_selected_pose_id()
	if object == null or object.animation_data == null or pose_id.is_empty():
		return
	var pose: GMSPoseData = object.animation_data.find_pose(pose_id)
	if pose == null:
		return
	var changed: PackedInt32Array = PackedInt32Array()
	for bone_index: int in object.rig_data.bones.size():
		if object.rig_data.bones[bone_index].locked:
			continue
		object.rig_data.set_pose_offset(bone_index, pose.get_offset_for_bone(object.rig_data, bone_index))
		_animation_dirty_bones[bone_index] = true
		changed.append(bone_index)
	for constrained_index: int in _apply_live_constraints_to_pose(object):
		if not changed.has(constrained_index):
			changed.append(constrained_index)
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_timeline(object)
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Apply Pose")


func _on_animation_delete_pose_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var pose_id: String = _get_selected_pose_id()
	if object == null or object.locked or object.animation_data == null or pose_id.is_empty():
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	if data.remove_pose(pose_id):
		_history.set_animation_data(_document, object.object_id, data, "Delete Pose")


func _on_animation_timeline_frame_requested(frame: int) -> void:
	_stop_animation_playback()
	_set_animation_current_frame(frame)


func _on_animation_timeline_bone_requested(bone_index: int) -> void:
	_set_rig_selected_bone(bone_index)


func _on_animation_timeline_key_requested(bone_index: int, frame: int, additive: bool) -> void:
	var object: GMSModelObject = _get_animation_object()
	if object == null or bone_index < 0 or bone_index >= object.rig_data.bones.size():
		return
	var bone: GMSBoneData = object.rig_data.bones[bone_index]
	var key_id: String = _animation_key_id(bone.bone_id, frame)
	if not additive:
		_animation_selected_keys.clear()
	if _animation_selected_keys.has(key_id):
		if additive:
			_animation_selected_keys.remove_at(_animation_selected_keys.find(key_id))
	else:
		_animation_selected_keys.append(key_id)
	_set_rig_selected_bone(bone_index)
	_set_animation_current_frame(frame)


func _on_animation_timeline_key_move_requested(bone_index: int, old_frame: int, new_frame: int) -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null or bone_index < 0 or bone_index >= object.rig_data.bones.size():
		return
	var bone: GMSBoneData = object.rig_data.bones[bone_index]
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	if not target.move_bone_key(bone.bone_id, bone.display_name, old_frame, new_frame):
		return
	var old_id: String = _animation_key_id(bone.bone_id, old_frame)
	var new_id: String = _animation_key_id(bone.bone_id, new_frame)
	var selection_index: int = _animation_selected_keys.find(old_id)
	if selection_index >= 0:
		_animation_selected_keys[selection_index] = new_id
	_history.set_animation_data(_document, object.object_id, data, "Move Animation Key")
	_animation_current_frame = new_frame
	_apply_animation_frame(true)


func _on_animation_delete_selected_keys_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null or _animation_selected_keys.is_empty():
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	var removed: int = 0
	for key_id: String in _animation_selected_keys:
		var parsed: Dictionary = _parse_animation_key_id(key_id)
		if parsed.is_empty():
			continue
		var bone_index: int = object.rig_data.find_bone_by_id(str(parsed["bone_id"]))
		if bone_index < 0:
			continue
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		if target.remove_bone_key(bone.bone_id, bone.display_name, int(parsed["frame"])):
			removed += 1
	if removed <= 0:
		return
	_history.set_animation_data(_document, object.object_id, data, "Delete Animation Keys")
	_animation_selected_keys.clear()
	_apply_animation_frame(true)


func _on_animation_copy_selected_keys_pressed() -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	_animation_key_clipboard.clear()
	if object == null or clip == null or _animation_selected_keys.is_empty():
		return
	var minimum_frame: int = 1000000000
	var entries: Array[Dictionary] = []
	for key_id: String in _animation_selected_keys:
		var parsed: Dictionary = _parse_animation_key_id(key_id)
		if parsed.is_empty():
			continue
		var bone_index: int = object.rig_data.find_bone_by_id(str(parsed["bone_id"]))
		if bone_index < 0:
			continue
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		var track: GMSBoneAnimationTrack = clip.find_track(bone.bone_id, bone.display_name)
		var key: GMSAnimationKey = track.get_key(int(parsed["frame"])) if track != null else null
		if key == null:
			continue
		minimum_frame = mini(minimum_frame, key.frame)
		entries.append({"bone_id": bone.bone_id, "bone_name": bone.display_name, "key": key.duplicate_key()})
	if entries.is_empty():
		return
	for entry: Dictionary in entries:
		var key: GMSAnimationKey = entry["key"]
		entry["frame_offset"] = key.frame - minimum_frame
	_animation_key_clipboard = entries
	_animation_status_label.text = "Copied %d animation key%s." % [entries.size(), "" if entries.size() == 1 else "s"]


func _paste_animation_keys(mirrored: bool) -> void:
	var object: GMSModelObject = _get_animation_object()
	var clip: GMSAnimationClip = _get_active_animation_clip(object)
	if object == null or object.locked or clip == null or _animation_key_clipboard.is_empty():
		return
	var data: GMSAnimationData = object.animation_data.duplicate_data()
	var target: GMSAnimationClip = data.find_clip(clip.clip_id)
	var pasted: int = 0
	_animation_selected_keys.clear()
	for entry: Dictionary in _animation_key_clipboard:
		var source_index: int = object.rig_data.resolve_bone(str(entry.get("bone_id", "")), str(entry.get("bone_name", "")))
		var target_index: int = source_index
		if mirrored and source_index >= 0:
			var source_bone: GMSBoneData = object.rig_data.bones[source_index]
			var mirrored_index: int = object.rig_data.find_mirrored_bone(source_index)
			if mirrored_index >= 0:
				target_index = mirrored_index
			elif _animation_bone_has_explicit_side(source_bone.display_name):
				target_index = -1
		if target_index < 0:
			continue
		var bone: GMSBoneData = object.rig_data.bones[target_index]
		var source_key: GMSAnimationKey = entry.get("key") as GMSAnimationKey
		if source_key == null:
			continue
		var new_frame: int = clampi(_animation_current_frame + int(entry.get("frame_offset", 0)), 0, target.frame_count)
		var offset: Transform3D = source_key.get_offset_transform()
		if mirrored:
			offset = _mirrored_pose_offset_x(offset)
		target.set_bone_key(bone, new_frame, offset, source_key.interpolation)
		_animation_selected_keys.append(_animation_key_id(bone.bone_id, new_frame))
		pasted += 1
	if pasted <= 0:
		return
	_history.set_animation_data(_document, object.object_id, data, "Paste Mirrored Keys" if mirrored else "Paste Animation Keys")
	_apply_animation_frame(true)


func _on_animation_paste_keys_pressed() -> void:
	_paste_animation_keys(false)


func _on_animation_paste_keys_mirrored_pressed() -> void:
	_paste_animation_keys(true)


func _on_animation_frame_spin_changed(value: float) -> void:
	if _suppress_ui_signals:
		return
	_stop_animation_playback()
	_set_animation_current_frame(int(value))


func _on_animation_first_frame_pressed() -> void:
	_stop_animation_playback()
	_set_animation_current_frame(0)


func _on_animation_last_frame_pressed() -> void:
	_stop_animation_playback()
	var clip: GMSAnimationClip = _get_active_animation_clip()
	_set_animation_current_frame(clip.frame_count if clip != null else 0)


func _on_animation_previous_frame_pressed() -> void:
	_stop_animation_playback()
	_set_animation_current_frame(_animation_current_frame - 1)


func _on_animation_next_frame_pressed() -> void:
	_stop_animation_playback()
	_set_animation_current_frame(_animation_current_frame + 1)


func _on_animation_previous_key_pressed() -> void:
	var clip: GMSAnimationClip = _get_active_animation_clip()
	if clip == null:
		return
	var previous: int = -1
	for frame: int in clip.get_all_key_frames():
		if frame < _animation_current_frame:
			previous = frame
		else:
			break
	if previous < 0 and clip.loop:
		var frames: PackedInt32Array = clip.get_all_key_frames()
		previous = frames[frames.size() - 1] if not frames.is_empty() else 0
	_stop_animation_playback()
	_set_animation_current_frame(maxi(previous, 0))


func _on_animation_next_key_pressed() -> void:
	var clip: GMSAnimationClip = _get_active_animation_clip()
	if clip == null:
		return
	var next: int = -1
	var frames: PackedInt32Array = clip.get_all_key_frames()
	for frame: int in frames:
		if frame > _animation_current_frame:
			next = frame
			break
	if next < 0 and clip.loop:
		next = frames[0] if not frames.is_empty() else 0
	_stop_animation_playback()
	_set_animation_current_frame(next if next >= 0 else clip.frame_count)


func _on_animation_play_pressed() -> void:
	if _animation_playing:
		_stop_animation_playback()
		return
	if _get_active_animation_clip() == null:
		return
	_animation_playing = true
	_animation_play_accumulator = 0.0
	_animation_play_button.text = "Pause"
	set_process(true)


func _stop_animation_playback() -> void:
	_animation_playing = false
	_animation_play_accumulator = 0.0
	if _animation_play_button != null:
		_animation_play_button.text = "Play"
	set_process(false)


func _process(delta: float) -> void:
	if not _animation_playing or _workspace_mode != WorkspaceMode.ANIMATE:
		return
	var clip: GMSAnimationClip = _get_active_animation_clip()
	if clip == null:
		_stop_animation_playback()
		return
	_animation_play_accumulator += delta * clip.fps
	var advance: int = int(floor(_animation_play_accumulator))
	if advance <= 0:
		return
	_animation_play_accumulator -= float(advance)
	var next_frame: int = _animation_current_frame + advance
	if next_frame > clip.frame_count:
		if clip.loop:
			next_frame %= clip.frame_count + 1
		else:
			next_frame = clip.frame_count
			_stop_animation_playback()
	_animation_current_frame = next_frame
	_apply_animation_frame(true)


func _begin_animation_bone_transform(
	kind: int,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false
) -> void:
	var object: GMSModelObject = _get_animation_object()
	if (
		object == null
		or object.locked
		or _get_active_animation_clip(object) == null
		or _rig_selected_bone < 0
		or _rig_selected_bone >= object.rig_data.bones.size()
		or object.rig_data.bones[_rig_selected_bone].locked
	):
		return
	var skeleton: Skeleton3D = object.rig_data.build_skeleton(true)
	var bone_global: Transform3D = skeleton.get_bone_global_pose(_rig_selected_bone)
	_animation_transform_object_id = object.object_id
	_animation_transform_bone_index = _rig_selected_bone
	_animation_transform_original_offsets = object.rig_data.get_pose_offsets()
	_animation_transform_original_world = object.transform * bone_global
	var parent_index: int = object.rig_data.bones[_rig_selected_bone].parent_index
	_animation_transform_parent_global = skeleton.get_bone_global_pose(parent_index) if parent_index >= 0 else Transform3D.IDENTITY
	skeleton.free()
	_animation_transform_local_rest = object.rig_data.get_bone_local_rest(_rig_selected_bone)
	_animation_transform_was_dirty = _is_dirty
	if not _viewport.begin_animation_bone_transform(
		kind,
		object.object_id,
		_rig_selected_bone,
		custom_axis,
		start_mouse_position,
		confirm_on_release
	):
		_clear_animation_transform_context()


func _on_viewport_animation_bone_transform_preview(
	kind: int,
	value: Vector3,
	axis: Vector3,
	_pivot_world: Vector3
) -> void:
	if _animation_transform_bone_index < 0 or _animation_transform_object_id.is_empty():
		return
	var object: GMSModelObject = _document.get_object(_animation_transform_object_id)
	if object == null or object.rig_data == null:
		return
	object.rig_data.apply_pose_offsets(_animation_transform_original_offsets)
	var desired_world: Transform3D = _animation_transform_original_world
	match kind:
		GMSModelViewport.TransformKind.MOVE:
			desired_world.origin += value
		GMSModelViewport.TransformKind.ROTATE:
			if not axis.is_zero_approx():
				desired_world.basis = Basis(axis.normalized(), value.x) * _animation_transform_original_world.basis
		GMSModelViewport.TransformKind.SCALE:
			if axis.is_zero_approx():
				desired_world.basis = _animation_transform_original_world.basis.scaled(value)
			else:
				desired_world.basis = _scale_basis_along_world_axis(
					_animation_transform_original_world.basis,
					axis,
					value.x
				)
	var desired_global: Transform3D = object.transform.affine_inverse() * desired_world
	var desired_local: Transform3D = _animation_transform_parent_global.affine_inverse() * desired_global
	var offset: Transform3D = _animation_transform_local_rest.affine_inverse() * desired_local
	object.rig_data.set_pose_offset(_animation_transform_bone_index, offset)
	_animation_dirty_bones[_animation_transform_bone_index] = true
	_apply_live_constraints_to_pose(object)
	_viewport.refresh_rig_preview(object.object_id)
	_refresh_animation_pose_fields(object)
	_refresh_animation_authoring_guides(object, _get_active_animation_clip(object))


func _on_viewport_animation_bone_transform_committed() -> void:
	if _animation_transform_bone_index < 0:
		return
	var changed: PackedInt32Array = PackedInt32Array()
	for bone_value: Variant in _animation_dirty_bones.keys():
		changed.append(int(bone_value))
	_clear_animation_transform_context()
	if _animation_auto_key_check.button_pressed:
		_key_animation_bones(changed, "Auto Key Bone")
	else:
		_animation_status_label.text = "Bone pose changed but is not keyed. Press K to key it."


func _on_viewport_animation_bone_transform_cancelled() -> void:
	var object: GMSModelObject = _document.get_object(_animation_transform_object_id) if _document != null else null
	if object != null and object.rig_data != null:
		object.rig_data.apply_pose_offsets(_animation_transform_original_offsets)
		_viewport.refresh_rig_preview(object.object_id)
	_is_dirty = _animation_transform_was_dirty
	_clear_animation_transform_context()
	_refresh_animation_pose_fields(object)


func _clear_animation_transform_context() -> void:
	_animation_transform_object_id = ""
	_animation_transform_bone_index = -1
	_animation_transform_original_offsets.clear()
	_animation_transform_original_world = Transform3D.IDENTITY
	_animation_transform_parent_global = Transform3D.IDENTITY
	_animation_transform_local_rest = Transform3D.IDENTITY


func _animation_key_id(bone_id: String, frame: int) -> String:
	return "%s|%d" % [bone_id, frame]


func _parse_animation_key_id(value: String) -> Dictionary:
	var separator: int = value.rfind("|")
	if separator <= 0 or separator >= value.length() - 1:
		return {}
	return {
		"bone_id": value.substr(0, separator),
		"frame": int(value.substr(separator + 1)),
	}


func _unique_strings(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var known: Dictionary = {}
	for value: String in values:
		if known.has(value):
			continue
		known[value] = true
		result.append(value)
	return result



func _background_operation_is_running() -> bool:
	return (
		_background_operation_task_id >= 0
		or _main_thread_operation_pending
		or not _modifier_evaluation_object_id.is_empty()
	)


func _start_main_thread_operation(
	title: String,
	worker: Callable,
	completion: Callable
) -> bool:
	if _background_operation_is_running() or _remesh_task_id >= 0:
		_status_label.text = "Another operation is already running."
		return false
	if not worker.is_valid() or not completion.is_valid():
		_status_label.text = "The export operation could not be started."
		return false

	_main_thread_operation_pending = true
	_main_thread_operation_worker = worker
	_main_thread_operation_completion = completion
	_main_thread_operation_job = GMSBackgroundJob.new()
	_main_thread_operation_title = title
	_background_operation_title = title
	_background_operation_label.text = "%s: Preparing safe export" % title
	_background_operation_progress.value = 0.0
	_background_operation_progress.show_percentage = false
	_background_operation_cancel_button.disabled = true
	_background_operation_row.visible = true
	_status_label.text = "%s is starting on the main thread to avoid unsafe engine calls from a worker thread." % title
	call_deferred("_run_main_thread_operation")
	return true


func _run_main_thread_operation() -> void:
	# Give the editor one frame to draw the operation row before the engine's
	# glTF serializer blocks the main thread. GLTFDocument, scene nodes, meshes,
	# materials, and image resources must not be driven from WorkerThreadPool.
	await get_tree().process_frame
	if not _main_thread_operation_pending:
		return
	var worker: Callable = _main_thread_operation_worker
	var completion: Callable = _main_thread_operation_completion
	var job: GMSBackgroundJob = _main_thread_operation_job
	_background_operation_label.text = "%s: Exporting" % _main_thread_operation_title
	var result: Variant = worker.call(job)
	var cancelled: bool = job != null and job.is_cancelled()

	_main_thread_operation_pending = false
	_main_thread_operation_worker = Callable()
	_main_thread_operation_completion = Callable()
	_main_thread_operation_job = null
	_main_thread_operation_title = ""
	_background_operation_title = ""
	_background_operation_row.visible = false
	_background_operation_progress.show_percentage = true
	_background_operation_cancel_button.disabled = false
	if completion.is_valid():
		completion.call(result, cancelled)
	_resume_pending_auto_export_after_refresh()


func _start_background_operation(
	title: String,
	worker: Callable,
	completion: Callable
) -> bool:
	if _background_operation_is_running() or _remesh_task_id >= 0:
		_status_label.text = "Another background operation is already running."
		return false
	if not worker.is_valid() or not completion.is_valid():
		_status_label.text = "The background operation could not be started."
		return false

	_background_operation_title = title
	_background_operation_job = GMSBackgroundJob.new()
	_background_operation_result_holder = {}
	_background_operation_completion = completion
	var holder: Dictionary = _background_operation_result_holder
	var job: GMSBackgroundJob = _background_operation_job
	var action: Callable = func() -> void:
		holder["result"] = worker.call(job)
		if not job.is_cancelled():
			job.update_progress(1.0, "Finishing")

	_background_operation_task_id = WorkerThreadPool.add_task(
		action,
		false,
		"Gator Model Studio %s" % title.to_lower()
	)
	_background_operation_label.text = "%s: Preparing" % title
	_background_operation_progress.value = 0.0
	_background_operation_cancel_button.disabled = false
	_background_operation_row.visible = true
	_background_operation_poll_timer.start()
	_status_label.text = "%s is running in the background." % title
	return true


func _monitor_modifier_evaluation(object_id: String) -> void:
	if object_id.is_empty() or _document == null:
		return
	if _background_operation_task_id >= 0 or _remesh_task_id >= 0:
		return
	var object: GMSModelObject = _document.get_object(object_id)
	if object == null:
		return
	var state: Dictionary = object.get_async_evaluation_state()
	if not bool(state.get("running", false)):
		return
	_modifier_evaluation_object_id = object_id
	_background_operation_title = "Modifier Evaluation"
	_background_operation_progress.value = clampf(float(state.get("progress", 0.0)), 0.0, 1.0) * 100.0
	var stage: String = str(state.get("stage", "Evaluating modifiers"))
	_background_operation_label.text = "Modifier Evaluation: %s" % stage
	_background_operation_cancel_button.disabled = bool(state.get("cancelled", false))
	_background_operation_row.visible = true
	_background_operation_poll_timer.start()


func _clear_modifier_evaluation_monitor() -> void:
	_modifier_evaluation_object_id = ""
	if _background_operation_task_id < 0:
		_background_operation_poll_timer.stop()
		_background_operation_title = ""
		_background_operation_row.visible = false
		_background_operation_cancel_button.disabled = false


func _on_background_operation_cancel_pressed() -> void:
	if _background_operation_task_id >= 0 and _background_operation_job != null:
		_background_operation_job.request_cancel()
		_background_operation_cancel_button.disabled = true
		_background_operation_label.text = "%s: Cancelling..." % _background_operation_title
		return
	if _modifier_evaluation_object_id.is_empty() or _document == null:
		return
	var object: GMSModelObject = _document.get_object(_modifier_evaluation_object_id)
	if object == null:
		_clear_modifier_evaluation_monitor()
		return
	object.cancel_async_evaluation()
	if _queued_modifier_apply_object_id == object.object_id:
		_queued_modifier_apply_object_id = ""
		_queued_modifier_apply_index = -1
		_queued_modifier_apply_signature = 0
	_background_operation_cancel_button.disabled = true
	_background_operation_label.text = "Modifier Evaluation: Cancelling..."


func _poll_background_operation() -> void:
	if _background_operation_task_id >= 0 and _background_operation_job != null:
		_poll_owned_background_operation()
		return
	if not _modifier_evaluation_object_id.is_empty():
		_poll_modifier_evaluation()
		return
	_background_operation_poll_timer.stop()


func _poll_owned_background_operation() -> void:
	var state: Dictionary = _background_operation_job.get_state()
	var progress: float = clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
	var stage: String = str(state.get("stage", "Working"))
	_background_operation_progress.value = progress * 100.0
	_background_operation_label.text = "%s: %s" % [_background_operation_title, stage]
	if not WorkerThreadPool.is_task_completed(_background_operation_task_id):
		return

	WorkerThreadPool.wait_for_task_completion(_background_operation_task_id)
	state = _background_operation_job.get_state()
	var result: Variant = _background_operation_result_holder.get("result")
	var cancelled: bool = bool(state.get("cancelled", false))
	if result is Dictionary:
		cancelled = cancelled or bool((result as Dictionary).get("cancelled", false))
	var completion: Callable = _background_operation_completion

	_background_operation_poll_timer.stop()
	_background_operation_task_id = -1
	_background_operation_job = null
	_background_operation_result_holder = {}
	_background_operation_completion = Callable()
	_background_operation_title = ""
	_background_operation_row.visible = false
	_background_operation_cancel_button.disabled = false
	if completion.is_valid():
		completion.call(result, cancelled)
	_resume_pending_auto_export_after_refresh()


func _poll_modifier_evaluation() -> void:
	if _document == null:
		_clear_modifier_evaluation_monitor()
		return
	var object_id: String = _modifier_evaluation_object_id
	var object: GMSModelObject = _document.get_object(object_id)
	if object == null:
		_clear_modifier_evaluation_monitor()
		return
	var state: Dictionary = object.get_async_evaluation_state()
	if bool(state.get("completed", false)) and bool(state.get("cancelled", false)):
		object.poll_async_evaluation()
		state = object.get_async_evaluation_state()
	if bool(state.get("running", false)):
		var progress: float = clampf(float(state.get("progress", 0.0)), 0.0, 1.0)
		var stage: String = str(state.get("stage", "Evaluating modifiers"))
		_background_operation_progress.value = progress * 100.0
		_background_operation_label.text = "Modifier Evaluation: %s" % stage
		if bool(state.get("cancelled", false)):
			_background_operation_cancel_button.disabled = true
			_background_operation_label.text = "Modifier Evaluation: Cancelling..."
		return
	var cancelled: bool = bool(state.get("cancelled", false))
	_clear_modifier_evaluation_monitor()
	if cancelled:
		_status_label.text = (
			"Modifier evaluation cancelled. The base mesh and modifier stack were left unchanged."
		)
	_resume_pending_auto_export_after_refresh()


func _on_remesh_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		_status_label.text = "Select an unlocked mesh object before opening Guided Voxel Remesh."
		return
	_cancel_active_transform()
	var display_mesh: GMSMeshData = object.get_evaluated_mesh_data()
	if (
		_selection.mode == GMSSelection.Mode.FACE
		and not _selection.face_indices.is_empty()
		and object.modifiers.is_empty()
	):
		_remesh_region_option.select(
			_remesh_region_option.get_item_index(REMESH_REGION_SELECTED_FACES)
		)
	else:
		_remesh_region_option.select(
			_remesh_region_option.get_item_index(REMESH_REGION_WHOLE_OBJECT)
		)
	if display_mesh != null and _get_remesh_guides(object.object_id).is_empty():
		var suggested_radius: float = maxf(display_mesh.get_aabb().size.length() * 0.04, 0.001)
		_remesh_guide_radius_spin.value = suggested_radius
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	_update_remesh_controls()
	_show_window_centered(_remesh_window)


func _on_remesh_window_close_requested() -> void:
	_remesh_waiting_for_surface_index_object_id = ""
	_remesh_window.hide()


func _on_remesh_draw_guide_pressed() -> void:
	if _remesh_task_id >= 0:
		return
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		_remesh_progress_label.text = "Select an unlocked mesh object first."
		return
	_try_begin_remesh_guide_draw(object.object_id)


func _try_begin_remesh_guide_draw(object_id: String) -> void:
	var object: GMSModelObject = _document.get_object(object_id) if _document != null else null
	if object == null or object.locked or object.mesh_data == null:
		_remesh_waiting_for_surface_index_object_id = ""
		_remesh_progress_label.text = "Guide drawing could not start because the object is unavailable."
		_update_remesh_controls()
		return
	if not _viewport.prepare_remesh_guide_surface(object_id):
		_remesh_waiting_for_surface_index_object_id = object_id
		_remesh_progress_label.text = "Preparing the complete surface for guide drawing..."
		_remesh_progress.value = 0.0
		_update_remesh_controls()
		return
	_remesh_waiting_for_surface_index_object_id = ""
	_remesh_pending_guide_object_id = object_id
	_refresh_remesh_guides_for_selection()
	if not _viewport.begin_remesh_guide_draw(object_id):
		_remesh_pending_guide_object_id = ""
		_remesh_progress_label.text = "Guide drawing could not start."
		_update_remesh_controls()
		return
	_remesh_progress_label.text = "Drag across the selected surface. Right-click or Esc cancels."
	_update_remesh_controls()
	_remesh_window.hide()


func _on_remesh_guide_stroke_completed(
	object_id: String,
	local_points: PackedVector3Array
) -> void:
	if object_id.is_empty() or object_id != _remesh_pending_guide_object_id or local_points.size() < 2:
		_remesh_pending_guide_object_id = ""
		_remesh_progress_label.text = "Guide stroke was not added."
		_show_window_centered(_remesh_window)
		return
	var guide: GMSRemeshGuide = GMSRemeshGuide.new()
	guide.mode = _remesh_guide_mode_option.get_selected_id()
	guide.points = local_points.duplicate()
	guide.radius = float(_remesh_guide_radius_spin.value)
	guide.strength = float(_remesh_guide_strength_spin.value)
	var guides: Array[GMSRemeshGuide] = _get_remesh_guides(object_id)
	guides.append(guide)
	_remesh_guides_by_object[object_id] = guides
	_remesh_pending_guide_object_id = ""
	_remesh_progress_label.text = "%s guide added." % guide.get_mode_name()
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	_update_remesh_controls()
	_show_window_centered(_remesh_window)


func _on_remesh_guide_drawing_cancelled() -> void:
	if _remesh_pending_guide_object_id.is_empty():
		return
	_remesh_pending_guide_object_id = ""
	_remesh_progress_label.text = "Guide drawing cancelled."
	_show_window_centered(_remesh_window)


func _on_remesh_remove_guide_pressed() -> void:
	if _remesh_task_id >= 0:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		return
	var selected_items: PackedInt32Array = _remesh_guide_list.get_selected_items()
	if selected_items.is_empty():
		return
	var guides: Array[GMSRemeshGuide] = _get_remesh_guides(object.object_id)
	var guide_index: int = selected_items[0]
	if guide_index >= 0 and guide_index < guides.size():
		guides.remove_at(guide_index)
	_remesh_guides_by_object[object.object_id] = guides
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	_update_remesh_controls()


func _on_remesh_clear_guides_pressed() -> void:
	if _remesh_task_id >= 0:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		return
	_remesh_guides_by_object.erase(object.object_id)
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	_update_remesh_controls()


func _on_remesh_guide_selected(_index: int) -> void:
	_update_remesh_controls()


func _on_remesh_region_changed(_index: int) -> void:
	if _remesh_region_option.get_selected_id() == REMESH_REGION_SELECTED_FACES:
		_remesh_progress_label.text = "Selected Faces uses the current face selection and preserves the padded outer boundary."
	else:
		_remesh_progress_label.text = "Whole Object remeshes the complete selected mesh."
	_update_remesh_controls()


func _on_remesh_apply_pressed() -> void:
	_request_remesh_start(false)


func _on_remesh_warning_confirmed() -> void:
	_request_remesh_start(true)


func _request_remesh_start(skip_warning: bool) -> void:
	if _remesh_task_id >= 0:
		return
	if _background_operation_task_id >= 0:
		_remesh_progress_label.text = "Finish or cancel the current background operation before remeshing."
		if not _remesh_window.visible:
			_show_window_centered(_remesh_window)
		return
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		_remesh_progress_label.text = "Select an unlocked mesh object first."
		return
	object.finish_async_evaluation()
	if object.object_id == _modifier_evaluation_object_id:
		_clear_modifier_evaluation_monitor()
	var region_mode: int = _remesh_region_option.get_selected_id()
	var selected_faces: PackedInt32Array = PackedInt32Array()
	var source_mesh: GMSMeshData
	if region_mode == REMESH_REGION_SELECTED_FACES:
		if _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
			_remesh_progress_label.text = "Enter Face mode and select the area to remesh."
			return
		if not object.modifiers.is_empty():
			_remesh_progress_label.text = "Apply the modifier stack before using Selected Faces remeshing so the face selection matches the source topology."
			return
		if object.mesh_data == null:
			_remesh_progress_label.text = "The source mesh is unavailable."
			return
		selected_faces = _selection.face_indices.duplicate()
		source_mesh = object.mesh_data
	else:
		var evaluated: GMSMeshData = object.get_evaluated_mesh_data()
		if evaluated == null:
			_remesh_progress_label.text = "The evaluated mesh is unavailable."
			return
		source_mesh = evaluated
	var remesh_warnings: PackedStringArray = _get_remesh_warnings(object, source_mesh)
	if not skip_warning and not remesh_warnings.is_empty():
		_remesh_warning_dialog.dialog_text = "\n\n".join(remesh_warnings)
		if not _remesh_window.visible:
			_show_window_centered(_remesh_window)
		_show_window_centered(_remesh_warning_dialog)
		return
	var source: GMSMeshData = source_mesh.duplicate_mesh_data_validated()
	var guides: Array[GMSRemeshGuide] = []
	for guide: GMSRemeshGuide in _get_remesh_guides(object.object_id):
		guides.append(guide.duplicate_guide())
	var resolution: int = int(_remesh_resolution_spin.value)
	var smooth_iterations: int = int(_remesh_smooth_iterations_spin.value)
	var smooth_strength: float = float(_remesh_smooth_strength_spin.value)
	var projection_strength: float = float(_remesh_projection_spin.value)
	var density_levels: int = int(_remesh_density_levels_spin.value)
	var boundary_padding: int = int(_remesh_boundary_padding_spin.value)
	var local_remesh: bool = region_mode == REMESH_REGION_SELECTED_FACES
	_remesh_output_duplicate = _remesh_output_option.get_selected_id() == 0
	_remesh_source_object_id = object.object_id
	_remesh_source_signature = _get_remesh_object_signature(object)
	_remesh_job = GMSRemeshJob.new()
	_remesh_result_holder = {}
	var holder: Dictionary = _remesh_result_holder
	var job: GMSRemeshJob = _remesh_job
	var action: Callable = func() -> void:
		if local_remesh:
			holder["result"] = GMSLocalVoxelRemesher.remesh_selected_faces(
				source,
				selected_faces,
				boundary_padding,
				resolution,
				smooth_iterations,
				smooth_strength,
				projection_strength,
				density_levels,
				guides,
				job,
				true
			)
		else:
			holder["result"] = GMSVoxelRemesher.remesh(
				source,
				resolution,
				smooth_iterations,
				smooth_strength,
				projection_strength,
				density_levels,
				guides,
				job,
				true
			)
	_remesh_task_id = WorkerThreadPool.add_task(
		action, false, "Gator Model Studio guided voxel remesh"
	)
	_remesh_progress.value = 0.0
	_remesh_progress_label.text = "Preparing remesh..."
	_remesh_poll_timer.start()
	if not _remesh_window.visible:
		_show_window_centered(_remesh_window)
	_update_remesh_controls()


func _get_remesh_warnings(object: GMSModelObject, mesh: GMSMeshData) -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if mesh == null:
		return warnings
	var local_remesh: bool = (
		_remesh_region_option != null
		and _remesh_region_option.get_selected_id() == REMESH_REGION_SELECTED_FACES
	)
	if local_remesh:
		warnings.append(
			"Selected Faces remeshing replaces the current face selection plus %d padding rings. The outer padded boundary is preserved and stitched back into the untouched mesh. Use Duplicate output until the result is verified." % int(_remesh_boundary_padding_spin.value)
		)
	if mesh.has_uv_map or not mesh.seam_edges.is_empty():
		warnings.append(
			"This mesh contains UV coordinates or marked seams. Remeshing creates new topology and permanently clears that UV data from the remeshed result."
		)
	if object != null and object.rig_data != null and object.rig_data.has_bones():
		warnings.append(
			"This object has an armature. The bones are preserved, but the new topology invalidates its vertex weights. Generate automatic weights again after remeshing."
		)
	var triangle_count: int = _estimate_triangle_count(mesh)
	var resolution: int = int(_remesh_resolution_spin.value)
	if resolution >= 128 or triangle_count >= REMESH_HEAVY_TRIANGLE_WARNING or (
		resolution >= 56 and triangle_count >= 50000
	):
		warnings.append(
			"This is a heavy remesh (%d source triangles at resolution %d). It will run in the background and can be cancelled, but may use substantial memory and processing time." % [
				triangle_count,
				resolution,
			]
		)
	return warnings


func _estimate_triangle_count(mesh: GMSMeshData) -> int:
	if mesh == null:
		return 0
	var triangle_count: int = 0
	for face: PackedInt32Array in mesh.faces:
		triangle_count += maxi(face.size() - 2, 0)
	return triangle_count


func _on_remesh_cancel_pressed() -> void:
	if _remesh_job == null or _remesh_task_id < 0:
		return
	_remesh_job.request_cancel()
	_remesh_cancel_button.disabled = true
	_remesh_progress_label.text = "Cancelling after the current remesh step..."


func _poll_remesh_job() -> void:
	if _remesh_task_id < 0 or _remesh_job == null:
		_remesh_poll_timer.stop()
		return
	var state: Dictionary = _remesh_job.get_state()
	_remesh_progress.value = float(state.get("progress", 0.0)) * 100.0
	_remesh_progress_label.text = str(state.get("stage", "Remeshing"))
	if not WorkerThreadPool.is_task_completed(_remesh_task_id):
		return
	WorkerThreadPool.wait_for_task_completion(_remesh_task_id)
	var result: Dictionary = _remesh_result_holder.get("result", {})
	_remesh_task_id = -1
	_remesh_job = null
	_remesh_result_holder = {}
	_remesh_poll_timer.stop()
	_finish_remesh_job(result)


func _finish_remesh_job(result: Dictionary) -> void:
	_update_remesh_controls()
	if bool(result.get("cancelled", false)):
		_remesh_progress_label.text = "Remesh cancelled."
		_remesh_progress.value = 0.0
		return
	var error: String = str(result.get("error", ""))
	if not error.is_empty():
		_remesh_progress_label.text = error
		_remesh_progress.value = 0.0
		return
	var new_mesh: GMSMeshData = result.get("mesh") as GMSMeshData
	if new_mesh == null or not new_mesh.is_valid():
		_remesh_progress_label.text = "Remesh failed to produce valid geometry."
		_remesh_progress.value = 0.0
		return
	var object: GMSModelObject = _document.get_object(_remesh_source_object_id) if _document != null else null
	if object == null:
		_remesh_progress_label.text = "Remesh result was discarded because the source object no longer exists."
		return
	if _get_remesh_object_signature(object) != _remesh_source_signature:
		_remesh_progress_label.text = "Remesh result was discarded because the source mesh changed while processing."
		return

	if _remesh_output_duplicate:
		var copy: GMSModelObject = object.duplicate_object()
		copy.display_name = "%s Remesh" % object.display_name
		copy.mesh_data = new_mesh
		copy.modifiers.clear()
		copy.ensure_defaults()
		_history.add_object(_document, copy)
		_selection.select_object(copy.object_id)
		_selection.set_mode(GMSSelection.Mode.OBJECT)
	else:
		var no_modifiers: Array[GMSModifier] = []
		var local_result: bool = bool(result.get("local", false))
		_history.set_mesh_and_modifiers(
			_document,
			object.object_id,
			new_mesh,
			no_modifiers,
			"Selected Faces Remesh" if local_result else "Guided Voxel Remesh"
		)
		var local_faces: PackedInt32Array = result.get(
			"face_indices", PackedInt32Array()
		)
		if local_result and not local_faces.is_empty():
			_selection.set_mode(GMSSelection.Mode.FACE)
			_selection.set_component_indices(local_faces, GMSSelection.Operation.SET)
		else:
			_selection.clear_components()
	_mark_dirty()
	_remesh_progress.value = 100.0
	var requested_resolution: int = int(result.get("requested_resolution", 0))
	var effective_resolution: int = int(result.get("resolution", requested_resolution))
	var resolution_description: String = str(effective_resolution)
	if requested_resolution > 0 and effective_resolution != requested_resolution:
		resolution_description = "%d, reduced from %d by the voxel-grid safety limit" % [
			effective_resolution,
			requested_resolution,
		]
	if bool(result.get("local", false)):
		_remesh_progress_label.text = "Selected-face remesh complete at local resolution %s: %d vertices, %d faces, %d padded source faces replaced. UV data was cleared." % [
			resolution_description,
			new_mesh.vertices.size(),
			new_mesh.faces.size(),
			int(result.get("region_face_count", 0)),
		]
	else:
		_remesh_progress_label.text = "Complete at resolution %s: %d vertices, %d faces. UV data was cleared." % [
			resolution_description,
			new_mesh.vertices.size(),
			new_mesh.faces.size(),
		]
	_status_label.text = _remesh_progress_label.text
	_refresh_remesh_guide_list()
	_refresh_remesh_guides_for_selection()
	if is_instance_valid(_remesh_window):
		_remesh_window.hide()


func _get_remesh_guides(object_id: String) -> Array[GMSRemeshGuide]:
	var result: Array[GMSRemeshGuide] = []
	var stored: Variant = _remesh_guides_by_object.get(object_id, [])
	if stored is Array:
		for value: Variant in stored:
			var guide: GMSRemeshGuide = value as GMSRemeshGuide
			if guide != null:
				result.append(guide)
	return result


func _refresh_remesh_guide_list() -> void:
	if _remesh_guide_list == null:
		return
	_remesh_guide_list.clear()
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		return
	var guides: Array[GMSRemeshGuide] = _get_remesh_guides(object.object_id)
	for guide_index: int in guides.size():
		var guide: GMSRemeshGuide = guides[guide_index]
		_remesh_guide_list.add_item(
			"%d. %s — %d points, radius %.3f" % [
				guide_index + 1,
				guide.get_mode_name(),
				guide.points.size(),
				guide.radius,
			]
		)
		_remesh_guide_list.set_item_tooltip(
			guide_index,
			"Strength %.2f" % guide.strength
		)


func _refresh_remesh_guides_for_selection() -> void:
	if _viewport == null:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		_viewport.clear_remesh_guides()
		return
	_viewport.set_remesh_guides(object.object_id, _get_remesh_guides(object.object_id))


func _update_remesh_controls() -> void:
	if _remesh_apply_button == null:
		return
	var running: bool = _remesh_task_id >= 0
	var preparing_surface: bool = not _remesh_waiting_for_surface_index_object_id.is_empty()
	var object: GMSModelObject = _get_editable_object()
	var has_object: bool = object != null
	_remesh_resolution_spin.editable = not running
	_remesh_smooth_iterations_spin.editable = not running
	_remesh_smooth_strength_spin.editable = not running
	_remesh_projection_spin.editable = not running
	_remesh_density_levels_spin.editable = not running
	_remesh_region_option.disabled = running
	var selected_region: bool = (
		_remesh_region_option.get_selected_id() == REMESH_REGION_SELECTED_FACES
	)
	_remesh_boundary_padding_spin.editable = not running and selected_region
	_remesh_output_option.disabled = running
	_remesh_guide_mode_option.disabled = running
	_remesh_guide_radius_spin.editable = not running
	_remesh_guide_strength_spin.editable = not running
	_remesh_draw_guide_button.disabled = running or preparing_surface or not has_object
	var selected_guides: PackedInt32Array = _remesh_guide_list.get_selected_items()
	_remesh_remove_guide_button.disabled = running or selected_guides.is_empty()
	var guide_count: int = _get_remesh_guides(object.object_id).size() if has_object else 0
	_remesh_clear_guides_button.disabled = running or guide_count == 0
	var valid_face_region: bool = (
		not selected_region
		or (
			_selection.mode == GMSSelection.Mode.FACE
			and not _selection.face_indices.is_empty()
			and has_object
			and object.modifiers.is_empty()
		)
	)
	_remesh_apply_button.disabled = (
		running or preparing_surface or not has_object or not valid_face_region
	)
	_remesh_cancel_button.disabled = not running
	_remesh_cancel_button.visible = running
	_remesh_progress.visible = running or preparing_surface


func _get_remesh_object_signature(object: GMSModelObject) -> int:
	if object == null or object.mesh_data == null:
		return 0
	var values: Array[Variant] = [object.mesh_data.get_change_revision()]
	for modifier: GMSModifier in object.modifiers:
		values.append(modifier.get_cache_signature() if modifier != null else 0)
	return hash(values)


func _on_select_all_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null or _selection.mode == GMSSelection.Mode.OBJECT:
		return
	_selection.select_all(object.mesh_data)


func _on_clear_selection_pressed() -> void:
	if _selection.mode == GMSSelection.Mode.OBJECT:
		_selection.clear()
	else:
		_selection.clear_components()


func _on_new_pressed() -> void:
	_request_document_action(PendingDocumentAction.NEW_DOCUMENT)


func _on_open_pressed() -> void:
	_request_document_action(PendingDocumentAction.OPEN_DOCUMENT)


func _request_document_action(action: PendingDocumentAction) -> void:
	_cancel_active_transform()
	if not _is_dirty:
		_perform_document_action(action, false)
		return
	_pending_document_action = action
	_unsaved_changes_dialog.dialog_text = (
		"The current model has unsaved changes. Save them before creating a new model?"
		if action == PendingDocumentAction.NEW_DOCUMENT
		else "The current model has unsaved changes. Save them before opening another model?"
	)
	_show_window_centered(_unsaved_changes_dialog)


func _perform_document_action(action: PendingDocumentAction, discard_current: bool) -> void:
	match action:
		PendingDocumentAction.NEW_DOCUMENT:
			if discard_current:
				_clear_recovery()
			_create_new_document()
		PendingDocumentAction.OPEN_DOCUMENT:
			_open_discards_current_document = discard_current
			_show_window_centered_ratio(_open_dialog, 0.62)
	_pending_document_action = PendingDocumentAction.NONE


func _on_unsaved_save_confirmed() -> void:
	var action: PendingDocumentAction = _pending_document_action
	if action == PendingDocumentAction.NONE:
		return
	if _current_path.is_empty():
		_save_continuation_action = action
		_show_save_dialog(false)
		return
	if _save_document(_current_path):
		_perform_document_action(action, false)


func _on_unsaved_custom_action(action: StringName) -> void:
	if action != &"discard":
		return
	_unsaved_changes_dialog.hide()
	var pending: PendingDocumentAction = _pending_document_action
	if pending != PendingDocumentAction.NONE:
		_perform_document_action(pending, true)


func _on_unsaved_cancelled() -> void:
	_pending_document_action = PendingDocumentAction.NONE


func _on_save_dialog_cancelled() -> void:
	_save_continuation_action = PendingDocumentAction.NONE
	_pending_document_action = PendingDocumentAction.NONE
	_save_dialog_is_save_as = false


func _on_open_dialog_cancelled() -> void:
	_open_discards_current_document = false


func _on_save_pressed() -> void:
	request_save()


func _on_save_as_pressed() -> void:
	_cancel_active_transform()
	_save_continuation_action = PendingDocumentAction.NONE
	_show_save_dialog(true)


func _show_save_dialog(save_as: bool) -> void:
	if _save_dialog == null:
		return
	_save_dialog_is_save_as = save_as
	_save_dialog.title = "Save Gator Model Document As" if save_as else "Save Gator Model Document"
	if not _current_path.is_empty():
		_save_dialog.current_dir = _current_path.get_base_dir()
		_save_dialog.current_file = _current_path.get_file()
	elif _document != null:
		_save_dialog.current_file = "%s.tres" % _safe_file_stem(_document.document_name)
	_show_window_centered_ratio(_save_dialog, 0.62)


func _on_import_pressed() -> void:
	_cancel_active_transform()
	_show_window_centered_ratio(_import_dialog, 0.62)


func _on_import_selected_pressed() -> void:
	_cancel_active_transform()
	if _background_operation_is_running() or _remesh_task_id >= 0:
		_status_label.text = "Another background operation is already running."
		return
	var editor_selection: EditorSelection = EditorInterface.get_selection()
	if editor_selection == null:
		_status_label.text = "The editor scene selection is unavailable."
		return
	var selected_nodes: Array[Node] = editor_selection.get_top_selected_nodes()
	if selected_nodes.is_empty():
		_status_label.text = "Select one or more MeshInstance3D nodes in the Scene dock first."
		return
	var entries: Array[Dictionary] = GMSMeshImporter.capture_editor_nodes(selected_nodes)
	if entries.is_empty():
		_status_label.text = "No MeshInstance3D nodes were found in the editor selection."
		return
	_start_background_operation(
		"Import Selected Meshes",
		Callable(self, "_run_import_entries_operation").bind(entries),
		Callable(self, "_finish_import_operation").bind(_document, "editor selection")
	)


func _on_export_pressed() -> void:
	_cancel_active_transform()
	_show_window_centered_ratio(_export_dialog, 0.62)


func _on_export_mesh_pressed() -> void:
	_cancel_active_transform()
	if _export_mesh_menu == null:
		return
	var popup_position: Vector2 = get_screen_position() + get_local_mouse_position()
	_export_mesh_menu.position = Vector2i(popup_position)
	_export_mesh_menu.popup()


func _on_export_mesh_menu_id_pressed(id: int) -> void:
	_mesh_export_mode = id
	var active: GMSModelObject = _get_selected_object()
	if id == MeshExportMode.ACTIVE_OBJECT:
		if active == null or active.mesh_data == null:
			_status_label.text = "Select an object before exporting its mesh."
			return
		_mesh_export_dialog.title = "Export Active Object Mesh"
		_mesh_export_dialog.current_file = "%s_mesh.tres" % _safe_file_stem(active.display_name)
	else:
		var selected_objects: Array[GMSModelObject] = _get_selected_objects()
		if selected_objects.is_empty():
			_status_label.text = "Select one or more objects before exporting a combined mesh."
			return
		_mesh_export_dialog.title = "Export Selected Objects as Combined Mesh"
		_mesh_export_dialog.current_file = "combined_mesh.tres"
	_show_window_centered_ratio(_mesh_export_dialog, 0.62)


func _on_open_file_selected(path: String) -> void:
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded is GMSDocument:
		if _open_discards_current_document:
			_clear_recovery()
		_open_discards_current_document = false
		_set_document(loaded as GMSDocument, path)
		_is_dirty = false
		_update_document_label()
	else:
		_open_discards_current_document = false
		_status_label.text = "The selected resource is not a Gator Model document."


func _on_import_file_selected(path: String) -> void:
	_start_background_operation(
		"Import %s" % path.get_file(),
		Callable(self, "_run_import_path_operation").bind(path),
		Callable(self, "_finish_import_operation").bind(_document, path.get_file())
	)


func _run_import_path_operation(job: GMSBackgroundJob, path: String) -> Variant:
	var extension_result: Dictionary = GMSImporterRegistry.import_path(path, job)
	if bool(extension_result.get("handled", false)):
		return extension_result
	var objects: Array[GMSModelObject] = GMSMeshImporter.import_path(path, job)
	return {
		"handled": false,
		"objects": objects,
		"cancelled": job.is_cancelled(),
	}


func _run_import_entries_operation(
	job: GMSBackgroundJob,
	entries: Array[Dictionary]
) -> Variant:
	return {
		"handled": false,
		"objects": GMSMeshImporter.import_captured_entries(entries, job),
		"cancelled": job.is_cancelled(),
	}


func _finish_import_operation(
	result: Variant,
	cancelled: bool,
	target_document: GMSDocument,
	source_description: String
) -> void:
	if cancelled:
		_status_label.text = "Import cancelled. No objects were added."
		return
	if target_document == null or target_document != _document:
		_status_label.text = "Import result discarded because the active document changed."
		return
	if not result is Dictionary:
		_status_label.text = "Import failed before producing a result."
		return
	var import_result: Dictionary = result as Dictionary
	var objects: Array[GMSModelObject] = []
	var object_values: Variant = import_result.get("objects", [])
	if object_values is Array:
		var object_array: Array = object_values as Array
		for value: Variant in object_array:
			if value is GMSModelObject:
				objects.append(value as GMSModelObject)
	_import_objects(objects, source_description)


func _on_save_file_selected(path: String) -> void:
	var continuation: PendingDocumentAction = _save_continuation_action
	var save_as: bool = _save_dialog_is_save_as
	_save_continuation_action = PendingDocumentAction.NONE
	_save_dialog_is_save_as = false
	if _save_document(path, save_as) and continuation != PendingDocumentAction.NONE:
		_perform_document_action(continuation, false)
	else:
		_pending_document_action = PendingDocumentAction.NONE


func _document_copy_for_storage(source_document: GMSDocument = null) -> GMSDocument:
	var document_to_copy: GMSDocument = source_document if source_document != null else _document
	if document_to_copy == null:
		return null
	var storage_copy: GMSDocument = document_to_copy.duplicate(true) as GMSDocument
	if storage_copy == null:
		return null
	# Rig and Animate poses are viewport previews. Clips store their own keys, so
	# temporary unkeyed bone offsets must not become the document's startup pose.
	for object: GMSModelObject in storage_copy.objects:
		if object != null and object.rig_data != null:
			object.rig_data.reset_pose()
	return storage_copy


func _save_document(path: String, reset_export_association: bool = false) -> bool:
	if _document == null:
		return false
	if not path.ends_with(".tres"):
		path += ".tres"
	var previous_export_path: String = _document.last_export_path
	var previous_auto_export: bool = _document.auto_export_on_save
	var creates_new_copy: bool = (
		reset_export_association
		and (_current_path.is_empty() or path.simplify_path() != _current_path.simplify_path())
	)
	if creates_new_copy:
		# A Save As copy must not silently overwrite the original copy's export target.
		_document.last_export_path = ""
		_document.auto_export_on_save = false
	var storage_copy: GMSDocument = _document_copy_for_storage()
	if storage_copy == null:
		if creates_new_copy:
			_document.last_export_path = previous_export_path
			_document.auto_export_on_save = previous_auto_export
		return false
	var error: Error = ResourceSaver.save(storage_copy, path)
	if error == OK:
		_current_path = path
		_is_dirty = false
		_clear_recovery()
		_status_label.text = (
			"Saved new document copy. Export association was cleared for the copy."
			if creates_new_copy and not previous_export_path.is_empty()
			else "Saved model document."
		)
		_update_document_label()
		_sync_auto_export_control()
		_request_auto_export_after_save()
		return true
	if creates_new_copy:
		_document.last_export_path = previous_export_path
		_document.auto_export_on_save = previous_auto_export
		_sync_auto_export_control()
	_status_label.text = "Save failed with error %d." % error
	_update_document_label()
	return false


func _on_export_file_selected(path: String) -> void:
	_start_document_export(path, false, _document)


func _start_document_export(
	path: String,
	automatic: bool,
	source_document: GMSDocument
) -> bool:
	if source_document == null:
		return false
	var custom_exporter: bool = GMSExporterRegistry.can_export_document(path)
	var extension: String = path.get_extension().to_lower()
	if not custom_exporter and extension not in ["tscn", "gltf", "glb", "obj"]:
		path += ".tscn"
		extension = "tscn"
	if not custom_exporter and extension in ["tscn", "gltf", "glb"]:
		var invalid_rigs: PackedStringArray = _get_objects_with_invalid_rig_weights(source_document.objects)
		if not invalid_rigs.is_empty():
			_status_label.text = "%sRig export stopped. Regenerate weights for: %s" % [
				"Saved, but automatic export failed. " if automatic else "",
				", ".join(invalid_rigs),
			]
			return false

	var snapshot: GMSDocument = _create_export_document_snapshot(source_document)
	if snapshot == null:
		_status_label.text = "%sExport could not create a stable document snapshot." % (
			"Saved, but automatic export failed. " if automatic else ""
		)
		return false
	var operation_path: String = path
	if automatic and not custom_exporter and path.begins_with("res://") and extension == "glb":
		operation_path = _create_auto_export_staging_path(path)
		if operation_path.is_empty():
			_status_label.text = "Saved, but automatic export could not create its staging file."
			return false
	var title_prefix: String = "Auto Export" if automatic else "Export"
	var operation_title: String = "%s %s" % [title_prefix, path.get_file()]
	var export_worker: Callable = Callable(self, "_run_document_export_operation").bind(
		snapshot,
		operation_path,
		path
	)
	var export_completion: Callable = Callable(
		self,
		"_finish_document_export_operation"
	).bind(
		automatic,
		source_document
	)
	# Godot's glTF pipeline creates scene nodes, ArrayMesh resources, materials,
	# images, GLTFState, and GLTFDocument objects. Running that pipeline in the
	# WorkerThreadPool caused intermittent native editor crashes during repeated
	# automatic exports. Keep these engine-facing formats on the main thread.
	if not custom_exporter and extension in ["gltf", "glb"]:
		return _start_main_thread_operation(
			operation_title,
			export_worker,
			export_completion
		)
	return _start_background_operation(
		operation_title,
		export_worker,
		export_completion
	)


func _on_mesh_export_file_selected(path: String) -> void:
	var source_objects: Array[GMSModelObject] = []
	var combined: bool = _mesh_export_mode == MeshExportMode.SELECTED_COMBINED
	if combined:
		source_objects = _get_selected_objects()
	else:
		var active_object: GMSModelObject = _get_selected_object()
		if active_object != null:
			source_objects.append(active_object)
	if source_objects.is_empty():
		_status_label.text = "No mesh objects are available for export."
		return

	var custom_exporter: bool = GMSExporterRegistry.can_export_mesh(path)
	var extension: String = path.get_extension().to_lower()
	if not custom_exporter and extension not in ["tres", "res", "gltf", "glb", "obj"]:
		path += ".tres"
		extension = "tres"
	if not custom_exporter and extension in ["gltf", "glb"]:
		if combined:
			for source_object: GMSModelObject in source_objects:
				if source_object != null and source_object.rig_data != null and source_object.rig_data.has_bones():
					_status_label.text = "Combined mesh export does not preserve skeletons. Use Export Scene or export one active rigged object."
					return
		else:
			var invalid_rigs: PackedStringArray = _get_objects_with_invalid_rig_weights(source_objects)
			if not invalid_rigs.is_empty():
				_status_label.text = "Rig export stopped. Regenerate weights for: %s" % ", ".join(invalid_rigs)
				return

	var snapshots: Array[GMSModelObject] = _create_export_object_snapshots(source_objects)
	if snapshots.is_empty():
		_status_label.text = "Export could not create stable mesh snapshots."
		return
	var operation_title: String = "Export %s" % path.get_file()
	var export_worker: Callable = Callable(
		self,
		"_run_mesh_export_operation"
	).bind(snapshots, path, combined)
	var export_completion: Callable = Callable(self, "_finish_mesh_export_operation")
	if not custom_exporter and extension in ["gltf", "glb"]:
		_start_main_thread_operation(
			operation_title,
			export_worker,
			export_completion
		)
	else:
		_start_background_operation(
			operation_title,
			export_worker,
			export_completion
		)


func _create_export_document_snapshot(source_document: GMSDocument = null) -> GMSDocument:
	return _document_copy_for_storage(source_document)


func _create_export_object_snapshots(
	source_objects: Array[GMSModelObject]
) -> Array[GMSModelObject]:
	var snapshots: Array[GMSModelObject] = []
	for source_object: GMSModelObject in source_objects:
		if source_object == null or source_object.mesh_data == null:
			continue
		var snapshot_object: GMSModelObject = source_object.duplicate(true) as GMSModelObject
		if snapshot_object == null:
			continue
		if snapshot_object.rig_data != null:
			snapshot_object.rig_data.reset_pose()
		snapshot_object.ensure_defaults()
		snapshots.append(snapshot_object)
	return snapshots


func _run_document_export_operation(
	job: GMSBackgroundJob,
	snapshot: GMSDocument,
	operation_path: String,
	final_path: String
) -> Variant:
	var extension_result: Dictionary = GMSExporterRegistry.export_document(
		snapshot,
		operation_path,
		job
	)
	if bool(extension_result.get("handled", false)):
		extension_result["path"] = final_path
		if operation_path != final_path:
			extension_result["staging_path"] = operation_path
		return extension_result
	var error: Error = GMSSceneExporter.export_document(snapshot, operation_path, job)
	return {
		"handled": false,
		"error": int(error),
		"path": final_path,
		"staging_path": operation_path if operation_path != final_path else "",
		"cancelled": job.is_cancelled(),
	}


func _run_mesh_export_operation(
	job: GMSBackgroundJob,
	objects: Array[GMSModelObject],
	path: String,
	combined: bool
) -> Variant:
	var extension_result: Dictionary = GMSExporterRegistry.export_mesh(objects, path, combined, job)
	if bool(extension_result.get("handled", false)):
		extension_result["path"] = path
		return extension_result
	var error: Error
	if combined:
		error = GMSSceneExporter.export_combined_mesh(objects, path, job)
	else:
		error = GMSSceneExporter.export_object_mesh(objects[0], path, job)
	return {
		"handled": false,
		"error": int(error),
		"path": path,
		"cancelled": job.is_cancelled(),
	}


func _finish_document_export_operation(
	result: Variant,
	cancelled: bool,
	automatic: bool,
	source_document: GMSDocument
) -> void:
	var source_is_current: bool = source_document != null and source_document == _document
	var export_result: Dictionary = {}
	if result is Dictionary:
		export_result = result as Dictionary
	var staging_path: String = str(export_result.get("staging_path", ""))
	if cancelled:
		_cleanup_auto_export_staging_file(staging_path)
		if source_is_current:
			_status_label.text = (
				"Saved, but automatic export was cancelled."
				if automatic
				else "Document export cancelled. Generated files were cleaned up where possible."
			)
		return
	if not result is Dictionary:
		if source_is_current:
			_status_label.text = (
				"Saved, but automatic export failed before producing a result."
				if automatic
				else "Document export failed before producing a result."
			)
		return
	var error_code: int = int(export_result.get("error", ERR_CANT_CREATE))
	if error_code != OK:
		_cleanup_auto_export_staging_file(staging_path)
		if source_is_current:
			_status_label.text = (
				"Saved, but automatic export failed with error %d." % error_code
				if automatic
				else "Document export failed with error %d." % error_code
			)
		return
	var path: String = str(export_result.get("path", ""))
	if not staging_path.is_empty():
		var commit_error: Error = _commit_auto_export_staging_file(staging_path, path)
		if commit_error != OK:
			if source_is_current:
				_status_label.text = "Saved, but automatic export could not replace %s (error %d)." % [
					path.get_file(),
					commit_error,
				]
			return
	if source_document != null and not path.is_empty():
		var export_path_changed: bool = source_document.last_export_path != path
		source_document.last_export_path = path
		if export_path_changed and source_is_current and not automatic:
			_mark_dirty()
	if not source_is_current:
		_queue_filesystem_refresh(path)
		return
	_sync_auto_export_control()
	if automatic:
		_status_label.text = "Saved model document and automatically exported %s." % path.get_file()
	elif bool(export_result.get("handled", false)):
		_status_label.text = "Exported with %s." % str(export_result.get("exporter", "extension exporter"))
	else:
		match path.get_extension().to_lower():
			"tscn":
				_status_label.text = "Exported Godot scene with configured collision."
			"obj":
				_status_label.text = "Exported OBJ and MTL files."
			"gltf":
				_status_label.text = "Exported glTF model and sidecar files."
			_:
				_status_label.text = "Exported binary GLB model."
	_queue_filesystem_refresh(path)


func _finish_mesh_export_operation(result: Variant, cancelled: bool) -> void:
	if cancelled:
		_status_label.text = "Mesh export cancelled. Generated files were cleaned up where possible."
		return
	if not result is Dictionary:
		_status_label.text = "Mesh export failed before producing a result."
		return
	var export_result: Dictionary = result as Dictionary
	var error_code: int = int(export_result.get("error", ERR_CANT_CREATE))
	if error_code != OK:
		_status_label.text = "Mesh export failed with error %d." % error_code
		return
	var path: String = str(export_result.get("path", ""))
	if bool(export_result.get("handled", false)):
		_status_label.text = "Exported with %s." % str(export_result.get("exporter", "extension exporter"))
	else:
		match path.get_extension().to_lower():
			"tres", "res":
				_status_label.text = "Exported standalone mesh resource."
			"obj":
				_status_label.text = "Exported OBJ and MTL files."
			"gltf":
				_status_label.text = "Exported glTF mesh and sidecar files."
			_:
				_status_label.text = "Exported binary GLB mesh."
	_queue_filesystem_refresh(path)


func _on_auto_export_on_save_toggled(enabled: bool) -> void:
	if _suppress_ui_signals or _document == null:
		return
	if enabled and _document.last_export_path.is_empty():
		_auto_export_on_save_check.set_pressed_no_signal(false)
		_status_label.text = "Export the document once before enabling automatic export on save."
		return
	if _document.auto_export_on_save == enabled:
		return
	_document.auto_export_on_save = enabled
	_mark_dirty()
	_status_label.text = (
		"Automatic export on save enabled for %s." % _document.last_export_path.get_file()
		if enabled
		else "Automatic export on save disabled."
	)
	_sync_auto_export_control()


func _sync_auto_export_control() -> void:
	if _auto_export_on_save_check == null:
		return
	var has_export_path: bool = _document != null and not _document.last_export_path.is_empty()
	_auto_export_on_save_check.disabled = not has_export_path
	_auto_export_on_save_check.set_pressed_no_signal(
		_document.auto_export_on_save if has_export_path else false
	)
	if has_export_path:
		_auto_export_on_save_check.tooltip_text = (
			"Automatically export to %s whenever this document is saved"
			% _document.last_export_path
		)
	else:
		_auto_export_on_save_check.tooltip_text = (
			"Export Scene once to establish the automatic export destination"
		)


func _request_auto_export_after_save() -> void:
	if (
		_document == null
		or not _document.auto_export_on_save
		or _document.last_export_path.is_empty()
	):
		_cancel_pending_auto_export()
		return
	var export_path: String = _document.last_export_path.strip_edges().simplify_path()
	var extension: String = export_path.get_extension().to_lower()
	var supported_builtin: bool = extension in ["tscn", "gltf", "glb", "obj"]
	if not supported_builtin and not GMSExporterRegistry.can_export_document(export_path):
		_document.auto_export_on_save = false
		_sync_auto_export_control()
		_status_label.text = "Saved model document, but automatic export was disabled because the remembered export format is no longer available."
		_cancel_pending_auto_export()
		return
	_auto_export_request_serial += 1
	_auto_export_pending_path = export_path
	_auto_export_pending_document = _document
	call_deferred("_flush_pending_auto_export", _auto_export_request_serial)


func _flush_pending_auto_export(request_serial: int) -> void:
	if request_serial != _auto_export_request_serial:
		return
	var source_document: GMSDocument = _auto_export_pending_document
	var export_path: String = _auto_export_pending_path
	if (
		source_document == null
		or source_document != _document
		or not source_document.auto_export_on_save
		or export_path.is_empty()
		or source_document.last_export_path.strip_edges().simplify_path() != export_path
	):
		_cancel_pending_auto_export()
		return
	if (
		_filesystem_refresh_paths.has(export_path)
		or _filesystem_memory_refresh_paths.has(export_path)
		or _editor_filesystem_is_busy()
	):
		_status_label.text = "Saved model document. Automatic export is waiting for the editor filesystem to become idle."
		_schedule_pending_auto_export_retry()
		return
	if _background_operation_is_running() or _remesh_task_id >= 0:
		_status_label.text = "Saved model document. Automatic export is waiting for the current operation to finish."
		_schedule_pending_auto_export_retry()
		return

	var started: bool = _start_document_export(export_path, true, source_document)
	if started:
		_auto_export_pending_document = null
		_auto_export_pending_path = ""
		if _auto_export_retry_timer != null:
			_auto_export_retry_timer.stop()
		return

	_auto_export_pending_document = null
	_auto_export_pending_path = ""
	_status_label.text = "Saved model document, but automatic export could not be started."


func _schedule_pending_auto_export_retry() -> void:
	if _auto_export_pending_document == null or _auto_export_pending_path.is_empty():
		return
	if _auto_export_retry_timer != null:
		_auto_export_retry_timer.start(AUTO_EXPORT_RETRY_SECONDS)


func _on_auto_export_retry_timeout() -> void:
	if _auto_export_pending_document == null or _auto_export_pending_path.is_empty():
		return
	call_deferred("_flush_pending_auto_export", _auto_export_request_serial)


func _cancel_pending_auto_export() -> void:
	_auto_export_request_serial += 1
	_auto_export_pending_path = ""
	_auto_export_pending_document = null
	if _auto_export_retry_timer != null:
		_auto_export_retry_timer.stop()


func _get_objects_with_invalid_rig_weights(objects: Array[GMSModelObject]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for object: GMSModelObject in objects:
		if object == null or object.rig_data == null or not object.rig_data.has_bones():
			continue
		object.finish_async_evaluation()
		var evaluated_mesh: GMSMeshData = object.get_evaluated_mesh_data()
		if evaluated_mesh == null or not object.rig_data.is_compatible(evaluated_mesh.vertices.size()):
			result.append(object.display_name)
	return result


func _create_auto_export_staging_path(final_path: String) -> String:
	var absolute_directory: String = ProjectSettings.globalize_path(
		AUTO_EXPORT_STAGING_DIRECTORY
	)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return ""
	var safe_base_name: String = final_path.get_file().get_basename().validate_filename()
	if safe_base_name.is_empty():
		safe_base_name = "model"
	return "%s/%s_%d_%d.glb" % [
		AUTO_EXPORT_STAGING_DIRECTORY,
		safe_base_name,
		absi(final_path.hash()),
		Time.get_ticks_usec(),
	]


func _commit_auto_export_staging_file(staging_path: String, final_path: String) -> Error:
	if staging_path.is_empty() or final_path.is_empty() or not FileAccess.file_exists(staging_path):
		return ERR_FILE_NOT_FOUND
	var final_directory: String = final_path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(final_directory)
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_cleanup_auto_export_staging_file(staging_path)
		return directory_error
	var pending_path: String = final_path + ".gms_pending"
	var backup_path: String = final_path + ".gms_previous"
	var absolute_final_path: String = ProjectSettings.globalize_path(final_path)
	var absolute_pending_path: String = ProjectSettings.globalize_path(pending_path)
	var absolute_backup_path: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path) or FileAccess.file_exists(absolute_backup_path):
		if not FileAccess.file_exists(final_path) and not FileAccess.file_exists(absolute_final_path):
			DirAccess.rename_absolute(absolute_backup_path, absolute_final_path)
		else:
			DirAccess.remove_absolute(absolute_backup_path)
	var source_bytes: PackedByteArray = FileAccess.get_file_as_bytes(staging_path)
	var source_file: FileAccess = FileAccess.open(staging_path, FileAccess.READ)
	if source_file == null:
		_cleanup_auto_export_staging_file(staging_path)
		return FileAccess.get_open_error()
	var source_length: int = source_file.get_length()
	source_file.close()
	if source_length <= 0 or source_bytes.size() != source_length:
		_cleanup_auto_export_staging_file(staging_path)
		return ERR_FILE_CORRUPT
	var pending_file: FileAccess = FileAccess.open(pending_path, FileAccess.WRITE)
	if pending_file == null:
		_cleanup_auto_export_staging_file(staging_path)
		return FileAccess.get_open_error()
	pending_file.store_buffer(source_bytes)
	pending_file.flush()
	pending_file.close()
	var had_previous_file: bool = (
		FileAccess.file_exists(final_path)
		or FileAccess.file_exists(absolute_final_path)
	)
	if had_previous_file:
		var backup_error: Error = DirAccess.rename_absolute(
			absolute_final_path,
			absolute_backup_path
		)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_pending_path)
			_cleanup_auto_export_staging_file(staging_path)
			return backup_error
	var rename_error: Error = DirAccess.rename_absolute(
		absolute_pending_path,
		absolute_final_path
	)
	if rename_error != OK:
		DirAccess.remove_absolute(absolute_pending_path)
		if had_previous_file and (
			FileAccess.file_exists(backup_path)
			or FileAccess.file_exists(absolute_backup_path)
		):
			DirAccess.rename_absolute(absolute_backup_path, absolute_final_path)
		_cleanup_auto_export_staging_file(staging_path)
		return rename_error
	if had_previous_file and (
		FileAccess.file_exists(backup_path)
		or FileAccess.file_exists(absolute_backup_path)
	):
		DirAccess.remove_absolute(absolute_backup_path)
	_cleanup_auto_export_staging_file(staging_path)
	return OK


func _cleanup_auto_export_staging_file(staging_path: String) -> void:
	if staging_path.is_empty():
		return
	var absolute_path: String = ProjectSettings.globalize_path(staging_path)
	if FileAccess.file_exists(staging_path) or FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _editor_filesystem_is_busy() -> bool:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file_system == null:
		return false
	var busy: bool = _filesystem_reimporting or file_system.is_scanning()
	if file_system.has_method("is_importing"):
		busy = busy or bool(file_system.call("is_importing"))
	return busy


func _queue_filesystem_refresh(path: String = "") -> void:
	# Do not force a blocking reimport from plugin code. EditorFileSystem.reimport_files()
	# runs main-loop iterations while blocked, which can re-enter timers and editor
	# callbacks. Queue a normal source scan and wait for Godot's completion signals.
	var normalized_path: String = path.strip_edges().simplify_path()
	if normalized_path.begins_with("res://"):
		_filesystem_refresh_paths[normalized_path] = true
	_filesystem_refresh_pending = true
	_filesystem_scan_requested = false
	_filesystem_scan_requested_msec = 0
	_filesystem_scan_attempts = 0
	_filesystem_idle_since_msec = 0
	_filesystem_refresh_not_before_msec = (
		Time.get_ticks_msec()
		+ int(FILESYSTEM_REFRESH_INITIAL_DELAY_SECONDS * 1000.0)
	)
	if _filesystem_refresh_timer != null:
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_INITIAL_DELAY_SECONDS)


func _connect_editor_filesystem_signals() -> void:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file_system == null:
		return
	var reimporting_callable: Callable = Callable(self, "_on_editor_resources_reimporting")
	var reimported_callable: Callable = Callable(self, "_on_editor_resources_reimported")
	var reload_callable: Callable = Callable(self, "_on_editor_resources_reload")
	if not file_system.resources_reimporting.is_connected(reimporting_callable):
		file_system.resources_reimporting.connect(reimporting_callable)
	if not file_system.resources_reimported.is_connected(reimported_callable):
		file_system.resources_reimported.connect(reimported_callable)
	if not file_system.resources_reload.is_connected(reload_callable):
		file_system.resources_reload.connect(reload_callable)


func _disconnect_editor_filesystem_signals() -> void:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file_system == null:
		return
	var reimporting_callable: Callable = Callable(self, "_on_editor_resources_reimporting")
	var reimported_callable: Callable = Callable(self, "_on_editor_resources_reimported")
	var reload_callable: Callable = Callable(self, "_on_editor_resources_reload")
	if file_system.resources_reimporting.is_connected(reimporting_callable):
		file_system.resources_reimporting.disconnect(reimporting_callable)
	if file_system.resources_reimported.is_connected(reimported_callable):
		file_system.resources_reimported.disconnect(reimported_callable)
	if file_system.resources_reload.is_connected(reload_callable):
		file_system.resources_reload.disconnect(reload_callable)


func _on_editor_resources_reimporting(_resources: PackedStringArray) -> void:
	_filesystem_reimporting = true
	_filesystem_idle_since_msec = 0


func _on_editor_resources_reimported(resources: PackedStringArray) -> void:
	_filesystem_reimporting = false
	_filesystem_idle_since_msec = 0
	_complete_matching_filesystem_refreshes(resources)
	if not _filesystem_refresh_paths.is_empty() and _filesystem_refresh_timer != null:
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)


func _on_editor_resources_reload(resources: PackedStringArray) -> void:
	_complete_matching_filesystem_refreshes(resources)


func _complete_matching_filesystem_refreshes(resources: PackedStringArray) -> void:
	var completed_paths: PackedStringArray = PackedStringArray()
	for resource_path: String in resources:
		var normalized_path: String = resource_path.simplify_path()
		if not _filesystem_refresh_paths.has(normalized_path):
			continue
		_filesystem_refresh_paths.erase(normalized_path)
		completed_paths.append(normalized_path)
	for completed_path: String in completed_paths:
		# The import is complete, but refresh the cached PackedScene and its
		# subresources on the next main-loop turn. Keep the path locked until that
		# refresh finishes so another auto export cannot race it.
		_filesystem_memory_refresh_paths[completed_path] = true
		call_deferred("_refresh_exported_resource_in_memory", completed_path)
	if _filesystem_refresh_paths.is_empty():
		_filesystem_refresh_pending = false
		_filesystem_scan_requested = false
		_filesystem_scan_requested_msec = 0
		_filesystem_scan_attempts = 0
		if _filesystem_memory_refresh_paths.is_empty():
			_resume_pending_auto_export_after_refresh()


func _try_refresh_editor_filesystem() -> void:
	if not _filesystem_refresh_pending and _filesystem_refresh_paths.is_empty():
		return
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file_system == null:
		_filesystem_refresh_pending = false
		_filesystem_refresh_paths.clear()
		_filesystem_scan_requested = false
		_filesystem_scan_requested_msec = 0
		_filesystem_scan_attempts = 0
		_resume_pending_auto_export_after_refresh()
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec < _filesystem_refresh_not_before_msec:
		var remaining_seconds: float = float(
			_filesystem_refresh_not_before_msec - now_msec
		) / 1000.0
		_filesystem_refresh_timer.start(maxf(
			FILESYSTEM_REFRESH_RETRY_SECONDS,
			remaining_seconds
		))
		return

	if _editor_filesystem_is_busy():
		_filesystem_idle_since_msec = 0
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)
		return

	if _filesystem_idle_since_msec == 0:
		_filesystem_idle_since_msec = now_msec
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)
		return
	if now_msec - _filesystem_idle_since_msec < FILESYSTEM_REFRESH_IDLE_GRACE_MSEC:
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)
		return

	var existing_paths: PackedStringArray = PackedStringArray()
	for path_variant: Variant in _filesystem_refresh_paths.keys():
		var path: String = str(path_variant).simplify_path()
		if path.begins_with("res://") and FileAccess.file_exists(path):
			existing_paths.append(path)
		else:
			_filesystem_refresh_paths.erase(path_variant)
	if existing_paths.is_empty():
		_filesystem_refresh_pending = false
		_filesystem_scan_requested = false
		_filesystem_scan_requested_msec = 0
		_filesystem_scan_attempts = 0
		_resume_pending_auto_export_after_refresh()
		return

	if not _filesystem_scan_requested:
		_filesystem_scan_requested = true
		_filesystem_scan_requested_msec = now_msec
		_filesystem_scan_attempts += 1
		_filesystem_refresh_pending = false
		var all_paths_are_imported_sources: bool = true
		for existing_path: String in existing_paths:
			if not FileAccess.file_exists(existing_path + ".import"):
				all_paths_are_imported_sources = false
				break
		# Existing GLB/GLTF/OBJ files are imported source assets. scan_sources()
		# detects their changed modification time immediately; scan() is retained
		# for a newly created export that has no .import metadata yet. Both avoid
		# the blocking and re-entrant reimport_files() call.
		if all_paths_are_imported_sources:
			file_system.scan_sources()
		else:
			file_system.scan()
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)
		return

	if now_msec - _filesystem_scan_requested_msec < FILESYSTEM_REFRESH_SIGNAL_TIMEOUT_MSEC:
		_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)
		return

	if _filesystem_scan_attempts >= 2:
		# Do not leave automatic export permanently locked if an editor build does
		# not emit a completion signal for this resource type. The normal scan has
		# already had two chances to reload it.
		var unresolved_paths: PackedStringArray = PackedStringArray()
		for path_variant: Variant in _filesystem_refresh_paths.keys():
			unresolved_paths.append(str(path_variant).simplify_path())
		_filesystem_refresh_paths.clear()
		_filesystem_refresh_pending = false
		_filesystem_scan_requested = false
		_filesystem_scan_requested_msec = 0
		_filesystem_scan_attempts = 0
		for unresolved_path: String in unresolved_paths:
			_filesystem_memory_refresh_paths[unresolved_path] = true
			call_deferred("_refresh_exported_resource_in_memory", unresolved_path)
		if _filesystem_memory_refresh_paths.is_empty():
			_resume_pending_auto_export_after_refresh()
		return

	# If no completion signal arrived, request one more normal scan. Keep the
	# auto-export target locked so a second write cannot overlap the import.
	_filesystem_scan_requested = false
	_filesystem_scan_requested_msec = 0
	_filesystem_refresh_pending = true
	_filesystem_idle_since_msec = now_msec
	_filesystem_refresh_timer.start(FILESYSTEM_REFRESH_RETRY_SECONDS)


func _refresh_exported_resource_in_memory(path: String) -> void:
	var normalized_path: String = path.strip_edges().simplify_path()
	if normalized_path.is_empty() or not normalized_path.begins_with("res://"):
		_finish_exported_resource_memory_refresh(normalized_path)
		return

	# The filesystem has completed the import before this deferred call runs.
	# CACHE_MODE_REPLACE refreshes the cached source resource and its own
	# subresources in place, so MeshInstance3D nodes in open parent scenes keep
	# their references while receiving the newly exported mesh and materials. It
	# deliberately does not recurse into unrelated external dependencies.
	var refreshed_resource: Resource = ResourceLoader.load(
		normalized_path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if refreshed_resource == null:
		push_warning("Gator Model Studio could not refresh exported resource: %s" % normalized_path)

	# If the imported GLB/GLTF itself is open as a scene tab, explicitly reload
	# that tab after import. This prevents Godot from leaving a stale
	# 'Reload from Disk' prompt for the exported scene. Parent scenes are not
	# reloaded, so their unsaved changes are preserved.
	for open_scene_path: String in EditorInterface.get_open_scenes():
		if open_scene_path.simplify_path() == normalized_path:
			EditorInterface.reload_scene_from_path(normalized_path)

	_refresh_open_scene_meshes(normalized_path)
	if (
		_status_label != null
		and _document != null
		and _document.last_export_path.simplify_path() == normalized_path
	):
		_status_label.text = "Exported, reimported, and refreshed %s in open scenes." % normalized_path.get_file()
	_finish_exported_resource_memory_refresh(normalized_path)


func _finish_exported_resource_memory_refresh(path: String) -> void:
	if not path.is_empty():
		_filesystem_memory_refresh_paths.erase(path)
	if _filesystem_refresh_paths.is_empty() and _filesystem_memory_refresh_paths.is_empty():
		_resume_pending_auto_export_after_refresh()


func _refresh_open_scene_meshes(export_path: String) -> void:
	var open_scene_roots: Array[Node] = EditorInterface.get_open_scene_roots()
	for scene_root: Node in open_scene_roots:
		_refresh_scene_node_resources(scene_root, export_path)
	var editor_base: Control = EditorInterface.get_base_control()
	if editor_base != null:
		editor_base.queue_redraw()


func _refresh_scene_node_resources(node: Node, export_path: String) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null and _resource_belongs_to_export(mesh, export_path):
			for surface_index: int in mesh.get_surface_count():
				var surface_material: Material = mesh.surface_get_material(surface_index)
				if surface_material != null and _resource_belongs_to_export(surface_material, export_path):
					surface_material.emit_changed()
			mesh.emit_changed()
			mesh_instance.notify_property_list_changed()
	for child: Node in node.get_children():
		_refresh_scene_node_resources(child, export_path)


func _resource_belongs_to_export(resource: Resource, export_path: String) -> bool:
	if resource == null:
		return false
	var resource_path: String = resource.resource_path.simplify_path()
	return resource_path == export_path or resource_path.begins_with(export_path + "::")


func _resume_pending_auto_export_after_refresh() -> void:
	if _auto_export_pending_document == null or _auto_export_pending_path.is_empty():
		return
	if (
		not _filesystem_refresh_paths.is_empty()
		or not _filesystem_memory_refresh_paths.is_empty()
		or _editor_filesystem_is_busy()
	):
		_schedule_pending_auto_export_retry()
		return
	call_deferred("_flush_pending_auto_export", _auto_export_request_serial)


func _import_objects(objects: Array[GMSModelObject], source_description: String) -> void:
	if _document == null:
		return
	var valid_objects: Array[GMSModelObject] = []
	for object: GMSModelObject in objects:
		if object != null and object.mesh_data != null and object.mesh_data.is_valid():
			valid_objects.append(object)
	if valid_objects.is_empty():
		_status_label.text = "No supported triangle Mesh surfaces were found in %s." % source_description
		return
	var reserved_names: Dictionary = {}
	for existing: GMSModelObject in _document.objects:
		if existing != null:
			reserved_names[existing.display_name] = true
	for object: GMSModelObject in valid_objects:
		object.ensure_defaults()
		object.display_name = _unique_reserved_name(object.display_name, reserved_names)
		reserved_names[object.display_name] = true
	_history.add_objects(_document, valid_objects, "Import Godot Meshes")
	var active: GMSModelObject = valid_objects[valid_objects.size() - 1]
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_selection.select_object(active.object_id)
	_mark_dirty()
	_status_label.text = "Imported %d editable mesh object%s from %s." % [
		valid_objects.size(),
		"" if valid_objects.size() == 1 else "s",
		source_description,
	]


func _unique_reserved_name(base_name: String, reserved_names: Dictionary) -> String:
	var cleaned: String = base_name.strip_edges()
	if cleaned.is_empty():
		cleaned = "Imported Mesh"
	if not reserved_names.has(cleaned):
		return cleaned
	var suffix: int = 2
	while reserved_names.has("%s %d" % [cleaned, suffix]):
		suffix += 1
	return "%s %d" % [cleaned, suffix]


func _safe_file_stem(source: String) -> String:
	var cleaned: String = source.strip_edges().to_snake_case()
	if cleaned.is_empty():
		return "model"
	return cleaned.replace("/", "_").replace("\\", "_")


func _get_selected_objects() -> Array[GMSModelObject]:
	var result: Array[GMSModelObject] = []
	if _document == null:
		return result
	for object_id: String in _selection.object_ids:
		var object: GMSModelObject = _document.get_object(object_id)
		if object != null and object.mesh_data != null:
			result.append(object)
	if result.is_empty():
		var active: GMSModelObject = _get_selected_object()
		if active != null and active.mesh_data != null:
			result.append(active)
	return result


func _cancel_active_transform() -> void:
	if _viewport == null:
		return
	_viewport.cancel_box_select()
	if _scalar_tool_active:
		_viewport.cancel_scalar_adjust()
	if _transform_active or _animation_transform_bone_index >= 0:
		_viewport.cancel_transform()


func _on_undo_pressed() -> void:
	_cancel_active_transform()
	if not _history.has_undo():
		return
	_history.undo()
	_mark_dirty()
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_apply_animation_frame(true)


func _on_redo_pressed() -> void:
	_cancel_active_transform()
	if not _history.has_redo():
		return
	_history.redo()
	_mark_dirty()
	if _workspace_mode == WorkspaceMode.ANIMATE:
		_apply_animation_frame(true)


func _on_duplicate_pressed() -> void:
	if _transform_active:
		return
	if _selection.mode != GMSSelection.Mode.OBJECT:
		var editable_object: GMSModelObject = _get_editable_object()
		if editable_object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
			_status_label.text = "Edit-mode duplication currently requires one or more selected faces."
			return
		var duplicate_result: Dictionary = GMSMeshOperations.duplicate_faces(
			editable_object.mesh_data,
			_selection.face_indices
		)
		var duplicated_mesh: GMSMeshData = duplicate_result["mesh"]
		var duplicated_faces: PackedInt32Array = duplicate_result["face_indices"]
		if duplicated_faces.is_empty():
			return
		_history.set_mesh(_document, editable_object.object_id, duplicated_mesh, "Duplicate Faces")
		_selection.set_component_indices(duplicated_faces, GMSSelection.Operation.SET)
		_mark_dirty()
		_begin_modal_transform(GMSModelViewport.TransformKind.MOVE)
		return
	if _selection.object_ids.is_empty():
		return

	var copies: Array[GMSModelObject] = []
	var copy_ids: PackedStringArray = PackedStringArray()
	var reserved_names: Dictionary = {}
	for source_id: String in _selection.object_ids:
		var source_object: GMSModelObject = _document.get_object(source_id)
		if source_object == null:
			continue
		var copy: GMSModelObject = source_object.duplicate_object()
		copy.display_name = _unique_name_reserved(source_object.display_name, reserved_names)
		reserved_names[copy.display_name] = true
		var copy_transform: Transform3D = copy.transform
		copy_transform.origin += Vector3(0.5, 0.0, 0.5)
		copy.transform = copy_transform
		copies.append(copy)
		copy_ids.append(copy.object_id)

	if copies.is_empty():
		return
	_history.add_objects(
		_document,
		copies,
		"Duplicate Objects" if copies.size() > 1 else "Duplicate Object"
	)
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_selection.select_objects(copy_ids, GMSSelection.Operation.SET)
	_mark_dirty()


func _on_delete_pressed() -> void:
	if _transform_active:
		return
	if _selection.mode == GMSSelection.Mode.OBJECT:
		if _selection.object_ids.is_empty():
			return
		_history.remove_objects(_document, _selection.object_ids.duplicate())
		_selection.clear()
		_mark_dirty()
		return

	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.get_component_count() == 0:
		return

	var new_mesh: GMSMeshData
	var action_name: String
	match _selection.mode:
		GMSSelection.Mode.VERTEX:
			new_mesh = GMSMeshOperations.delete_vertices(object.mesh_data, _selection.vertex_indices)
			action_name = "Delete Vertices"
		GMSSelection.Mode.EDGE:
			new_mesh = GMSMeshOperations.delete_edges(object.mesh_data, _selection.edge_indices)
			action_name = "Delete Edges"
		GMSSelection.Mode.FACE:
			new_mesh = GMSMeshOperations.delete_faces(object.mesh_data, _selection.face_indices)
			action_name = "Delete Faces"
		_:
			return

	if _mesh_data_equal(object.mesh_data, new_mesh):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_selection.clear_components()
	_mark_dirty()


func _on_frame_pressed() -> void:
	_viewport.frame_selected()


func _on_name_submitted(new_name: String) -> void:
	_apply_name(new_name)


func _on_name_focus_exited() -> void:
	_apply_name(_name_edit.text)


func _apply_name(new_name: String) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		return
	_history.set_name(_document, object.object_id, new_name)
	_mark_dirty()


func _on_visible_toggled(is_visible: bool) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object != null:
		_history.set_visibility(_document, object.object_id, is_visible)
		_mark_dirty()


func _on_locked_toggled(is_locked: bool) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object != null:
		_history.set_locked(_document, object.object_id, is_locked)
		_mark_dirty()


func _on_apply_transform_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked:
		return

	var position: Vector3 = _get_vector_fields(_position_fields)
	var rotation_degrees: Vector3 = _get_vector_fields(_rotation_fields)
	var scale: Vector3 = _get_vector_fields(_scale_fields)
	var new_transform: Transform3D = Transform3D(
		Basis.from_euler(rotation_degrees * PI / 180.0).scaled(scale),
		position
	)
	_history.set_transform(_document, object.object_id, new_transform)
	_mark_dirty()


func _on_apply_collision_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked:
		return
	_history.set_collision(
		_document,
		object.object_id,
		_collision_type_option.get_selected_id(),
		int(_collision_layer_spin.value),
		int(_collision_mask_spin.value)
	)
	_mark_dirty()
	_status_label.text = "Collision settings saved. Export Scene will generate the configured StaticBody3D."


func _on_join_objects_pressed() -> void:
	if _selection.mode != GMSSelection.Mode.OBJECT or _selection.object_ids.size() < 2:
		_status_label.text = "Object mode: Shift-click at least two objects in the viewport, then press Join or Ctrl+J. The last selected object is the active target."
		return
	var active: GMSModelObject = _get_selected_object()
	if active == null or active.locked or active.mesh_data == null:
		return
	var joined_mesh: GMSMeshData = active.get_evaluated_mesh_data()
	if joined_mesh == null:
		return
	joined_mesh = joined_mesh.duplicate_mesh_data()
	var joined_materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(active.materials)
	var removed_ids: PackedStringArray = PackedStringArray()
	var active_inverse: Transform3D = active.transform.affine_inverse()
	for object_id: String in _selection.object_ids:
		if object_id == active.object_id:
			continue
		var other: GMSModelObject = _document.get_object(object_id)
		if other == null or other.locked or other.mesh_data == null:
			continue
		var evaluated: GMSMeshData = other.get_evaluated_mesh_data()
		if evaluated == null:
			continue
		evaluated = evaluated.duplicate_mesh_data()
		var material_offset: int = joined_materials.size()
		evaluated.offset_face_material_indices(material_offset)
		joined_materials.append_array(GMSModelObject.duplicate_materials(other.materials))
		joined_mesh = GMSAdvancedMeshOperations.append_mesh(
			joined_mesh,
			evaluated,
			active_inverse * other.transform
		)
		removed_ids.append(other.object_id)
	if removed_ids.is_empty():
		_status_label.text = "No additional unlocked mesh objects could be joined."
		return
	_history.join_objects(
		_document, active.object_id, joined_mesh, joined_materials, active.active_material_index, [], removed_ids
	)
	_selection.select_object(active.object_id)
	_mark_dirty()
	_status_label.text = "Joined %d objects into %s. Return to Edge mode to bridge loops inside the combined mesh." % [
		removed_ids.size() + 1,
		active.display_name,
	]


func _on_origin_to_geometry_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or object.mesh_data.vertices.is_empty():
		return
	var center: Vector3 = _mesh_vertex_center(object.mesh_data)
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(object.mesh_data.vertices.size())
	for index: int in indices.size():
		indices[index] = index
	var new_mesh: GMSMeshData = GMSMeshOperations.translate_vertices(
		object.mesh_data,
		indices,
		-center
	)
	var new_transform: Transform3D = object.transform
	new_transform.origin = object.transform * center
	var new_rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else null
	if new_rig != null:
		new_rig.transform_rest(Transform3D(Basis.IDENTITY, -center))
	_history.set_mesh_transform_and_rig(
		_document,
		object.object_id,
		new_mesh,
		new_transform,
		new_rig,
		"Origin to Geometry"
	)
	_mark_dirty()


func _on_geometry_to_origin_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or object.mesh_data.vertices.is_empty():
		return
	var center: Vector3 = _mesh_vertex_center(object.mesh_data)
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(object.mesh_data.vertices.size())
	for index: int in indices.size():
		indices[index] = index
	var new_mesh: GMSMeshData = GMSMeshOperations.translate_vertices(
		object.mesh_data,
		indices,
		-center
	)
	var new_rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else null
	if new_rig != null:
		new_rig.transform_rest(Transform3D(Basis.IDENTITY, -center))
	_history.set_mesh_transform_and_rig(
		_document,
		object.object_id,
		new_mesh,
		object.transform,
		new_rig,
		"Geometry to Origin"
	)
	_mark_dirty()


func _on_apply_rotation_scale_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or object.mesh_data.vertices.is_empty():
		return
	if object.transform.basis.is_equal_approx(Basis.IDENTITY):
		_status_label.text = "Rotation and scale are already applied. The model is unchanged."
		return
	var new_mesh: GMSMeshData = object.mesh_data.duplicate_mesh_data()
	for vertex_index: int in new_mesh.vertices.size():
		new_mesh.vertices[vertex_index] = object.transform.basis * new_mesh.vertices[vertex_index]
	new_mesh.invalidate_custom_normals()
	new_mesh.emit_changed()
	var new_transform: Transform3D = Transform3D(Basis.IDENTITY, object.transform.origin)
	var new_rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else null
	if new_rig != null:
		new_rig.transform_rest(Transform3D(object.transform.basis, Vector3.ZERO))
	_history.set_mesh_transform_and_rig(
		_document,
		object.object_id,
		new_mesh,
		new_transform,
		new_rig,
		"Apply Rotation and Scale"
	)
	_mark_dirty()
	_update_properties()
	_status_label.text = "Applied rotation and scale. The model intentionally looks unchanged; Rotation is now 0 and Scale is 1."


func _mesh_vertex_center(mesh: GMSMeshData) -> Vector3:
	if mesh == null or mesh.vertices.is_empty():
		return Vector3.ZERO
	var center: Vector3 = Vector3.ZERO
	for vertex: Vector3 in mesh.vertices:
		center += vertex
	return center / float(mesh.vertices.size())


func _connect_modifier_live_signals() -> void:
	_modifier_name_edit.text_submitted.connect(_on_modifier_live_changed)
	_modifier_name_edit.focus_exited.connect(_on_modifier_live_changed)
	_modifier_enabled_check.toggled.connect(_on_modifier_live_changed)
	_modifier_mirror_x.toggled.connect(_on_modifier_live_changed)
	_modifier_mirror_y.toggled.connect(_on_modifier_live_changed)
	_modifier_mirror_z.toggled.connect(_on_modifier_live_changed)
	_modifier_merge_check.toggled.connect(_on_modifier_live_changed)
	_modifier_clipping_check.toggled.connect(_on_modifier_live_changed)
	_modifier_merge_distance.value_changed.connect(_on_modifier_live_changed)
	_modifier_array_count.value_changed.connect(_on_modifier_live_changed)
	for field: SpinBox in _modifier_array_offset_fields:
		field.value_changed.connect(_on_modifier_live_changed)
	_modifier_thickness.value_changed.connect(_on_modifier_live_changed)
	_modifier_solidify_offset.value_changed.connect(_on_modifier_live_changed)
	_modifier_subdivision_levels.value_changed.connect(_on_modifier_live_changed)
	_modifier_bevel_width.value_changed.connect(_on_modifier_live_changed)
	_modifier_bevel_segments.value_changed.connect(_on_modifier_live_changed)
	_modifier_decimate_ratio.value_changed.connect(_on_modifier_live_changed)
	_modifier_weighted_normal_strength.value_changed.connect(_on_modifier_live_changed)
	_modifier_weighted_normal_power.value_changed.connect(_on_modifier_live_changed)
	_modifier_weighted_normal_keep_sharp.toggled.connect(_on_modifier_live_changed)
	_modifier_displace_strength.value_changed.connect(_on_modifier_live_changed)
	_modifier_displace_scale.value_changed.connect(_on_modifier_live_changed)
	_modifier_displace_seed.value_changed.connect(_on_modifier_live_changed)
	_modifier_displace_noise.toggled.connect(_on_modifier_live_changed)
	_modifier_displace_direction.item_selected.connect(_on_modifier_live_changed)
	_modifier_bend_angle.value_changed.connect(_on_modifier_live_changed)
	_modifier_bend_axis.item_selected.connect(_on_modifier_live_changed)
	_modifier_smooth_factor.value_changed.connect(_on_modifier_live_changed)
	_modifier_smooth_iterations.value_changed.connect(_on_modifier_live_changed)
	_modifier_smooth_preserve_boundary.toggled.connect(_on_modifier_live_changed)


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for item_index: int in option.item_count:
		if option.get_item_id(item_index) == item_id:
			option.select(item_index)
			return


func _on_modifier_selected(index: int) -> void:
	if _suppress_ui_signals:
		return
	_flush_modifier_live_change()
	_selected_modifier_index = index
	_update_properties()


func _on_modifier_add_type_selected(index: int) -> void:
	var option_id: int = _modifier_add_option.get_item_id(index)
	var help_text: String
	if _modifier_custom_option_ids.has(option_id):
		help_text = GMSModifierRegistry.get_tooltip(str(_modifier_custom_option_ids[option_id]))
	else:
		help_text = GMSModifier.kind_to_tooltip(option_id)
	_modifier_add_option.tooltip_text = help_text
	_modifier_type_help_label.text = help_text


func _on_add_modifier_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked:
		return
	var modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var option_id: int = _modifier_add_option.get_selected_id()
	var new_modifier: GMSModifier
	var display_name: String
	if _modifier_custom_option_ids.has(option_id):
		var custom_id: String = str(_modifier_custom_option_ids[option_id])
		new_modifier = GMSModifierRegistry.create_modifier(custom_id)
		display_name = str(GMSModifierRegistry.get_modifier(custom_id).get("name", "Custom"))
	else:
		new_modifier = GMSModifier.create(option_id)
		display_name = GMSModifier.kind_to_name(option_id)
	if new_modifier == null:
		_status_label.text = "The selected modifier extension is unavailable."
		return
	if new_modifier.kind in [
		GMSModifier.Kind.SIMPLE_SUBDIVIDE,
		GMSModifier.Kind.SUBDIVISION_SURFACE,
	]:
		var estimated_faces: int = _estimate_modifier_stack_faces(
			object,
			modifiers.size(),
			new_modifier
		)
		if estimated_faces >= SUBDIVISION_WARNING_FACES:
			_status_label.text = (
				"High-density subdivision: approximately %d faces. Evaluation runs in the background."
				% estimated_faces
			)
	modifiers.append(new_modifier)
	_selected_modifier_index = modifiers.size() - 1
	_history.set_modifiers(
		_document,
		object.object_id,
		modifiers,
		"Add %s Modifier" % display_name
	)
	_mark_dirty()


func _on_modifier_update_pressed() -> void:
	_modifier_preview_pending = false
	if _modifier_preview_timer != null:
		_modifier_preview_timer.stop()
	_commit_modifier_fields(false)


func _on_modifier_live_changed(_value: Variant = null) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if not _has_editable_modifier(object):
		return
	_modifier_preview_pending = true
	_pending_modifier_object_id = object.object_id
	_pending_modifier_index = _selected_modifier_index
	if _modifier_preview_timer.is_stopped():
		_modifier_preview_timer.start()


func _flush_modifier_live_change() -> void:
	if not _modifier_preview_pending:
		return
	_modifier_preview_pending = false
	var object: GMSModelObject = _get_selected_object()
	if (
		object == null
		or object.object_id != _pending_modifier_object_id
		or _selected_modifier_index != _pending_modifier_index
	):
		return
	_commit_modifier_fields(true)


func _commit_modifier_fields(merge_history: bool) -> void:
	var object: GMSModelObject = _get_selected_object()
	if not _has_editable_modifier(object):
		return
	var modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var modifier: GMSModifier = modifiers[_selected_modifier_index]
	var cleaned_name: String = _modifier_name_edit.text.strip_edges()
	if not cleaned_name.is_empty():
		modifier.modifier_name = cleaned_name
	elif modifier.is_custom():
		modifier.modifier_name = str(
			GMSModifierRegistry.get_modifier(modifier.custom_id).get("name", "Custom Modifier")
		)
	else:
		modifier.modifier_name = GMSModifier.kind_to_name(modifier.kind)
	modifier.enabled = _modifier_enabled_check.button_pressed
	if modifier.is_custom() and GMSModifierRegistry.has_modifier(modifier.custom_id):
		modifier.custom_parameters = _read_extension_parameters(
			GMSModifierRegistry.get_parameters(modifier.custom_id),
			_modifier_custom_controls
		)
	modifier.mirror_x = _modifier_mirror_x.button_pressed
	modifier.mirror_y = _modifier_mirror_y.button_pressed
	modifier.mirror_z = _modifier_mirror_z.button_pressed
	modifier.merge = _modifier_merge_check.button_pressed
	modifier.clipping = _modifier_clipping_check.button_pressed
	modifier.merge_distance = maxf(float(_modifier_merge_distance.value), 0.000001)
	modifier.array_count = maxi(1, int(round(_modifier_array_count.value)))
	modifier.array_offset = _get_vector_fields(_modifier_array_offset_fields)
	modifier.thickness = float(_modifier_thickness.value)
	modifier.solidify_offset = clampf(float(_modifier_solidify_offset.value), -1.0, 1.0)
	modifier.subdivision_levels = clampi(int(round(_modifier_subdivision_levels.value)), 1, 4)
	modifier.bevel_width = maxf(float(_modifier_bevel_width.value), 0.0001)
	modifier.bevel_segments = clampi(int(round(_modifier_bevel_segments.value)), 1, 4)
	modifier.decimate_ratio = clampf(float(_modifier_decimate_ratio.value), 0.01, 1.0)
	modifier.weighted_normal_strength = clampf(float(_modifier_weighted_normal_strength.value), 0.0, 1.0)
	modifier.weighted_normal_power = clampf(float(_modifier_weighted_normal_power.value), 0.0, 4.0)
	modifier.weighted_normal_keep_sharp = _modifier_weighted_normal_keep_sharp.button_pressed
	modifier.displace_strength = float(_modifier_displace_strength.value)
	modifier.displace_scale = maxf(float(_modifier_displace_scale.value), 0.001)
	modifier.displace_seed = int(round(_modifier_displace_seed.value))
	modifier.displace_noise = _modifier_displace_noise.button_pressed
	modifier.displace_direction = _modifier_displace_direction.get_selected_id()
	modifier.bend_angle_degrees = float(_modifier_bend_angle.value)
	modifier.bend_axis = _modifier_bend_axis.get_selected_id()
	modifier.smooth_factor = clampf(float(_modifier_smooth_factor.value), 0.0, 1.0)
	modifier.smooth_iterations = clampi(int(round(_modifier_smooth_iterations.value)), 1, 50)
	modifier.smooth_preserve_boundary = _modifier_smooth_preserve_boundary.button_pressed
	if modifier.kind in [
		GMSModifier.Kind.SIMPLE_SUBDIVIDE,
		GMSModifier.Kind.SUBDIVISION_SURFACE,
	]:
		var estimated_faces: int = _estimate_modifier_stack_faces(
			object,
			_selected_modifier_index,
			modifier
		)
		if estimated_faces >= SUBDIVISION_WARNING_FACES:
			_status_label.text = "High-density subdivision: approximately %d faces. Evaluation runs in the background." % estimated_faces
	_modifier_live_commit_active = merge_history
	_history.set_modifiers(
		_document,
		object.object_id,
		modifiers,
		"Edit Modifier",
		merge_history
	)
	_modifier_live_commit_active = false
	_mark_dirty()


func _estimate_modifier_stack_faces(
	object: GMSModelObject,
	replacement_index: int,
	replacement: GMSModifier
) -> int:
	if object == null or object.mesh_data == null:
		return 0
	var estimated_faces: int = maxi(object.mesh_data.faces.size(), 1)
	var modifier_count: int = maxi(object.modifiers.size(), replacement_index + 1)
	for modifier_index: int in modifier_count:
		var modifier: GMSModifier = null
		if modifier_index == replacement_index:
			modifier = replacement
		elif modifier_index < object.modifiers.size():
			modifier = object.modifiers[modifier_index]
		if modifier == null or not modifier.enabled:
			continue
		match modifier.kind:
			GMSModifier.Kind.SIMPLE_SUBDIVIDE, GMSModifier.Kind.SUBDIVISION_SURFACE:
				for _level: int in clampi(modifier.subdivision_levels, 1, 4):
					estimated_faces *= 4
			GMSModifier.Kind.ARRAY:
				estimated_faces *= maxi(modifier.array_count, 1)
			GMSModifier.Kind.SOLIDIFY:
				estimated_faces *= 3
			GMSModifier.Kind.BEVEL:
				estimated_faces *= 1 + clampi(modifier.bevel_segments, 1, 4) * 2
			GMSModifier.Kind.TRIANGULATE:
				estimated_faces *= 2
	return estimated_faces


func _on_modifier_remove_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if not _has_editable_modifier(object):
		return
	var modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var removed_name: String = modifiers[_selected_modifier_index].get_display_name()
	modifiers.remove_at(_selected_modifier_index)
	_selected_modifier_index = mini(_selected_modifier_index, modifiers.size() - 1)
	_history.set_modifiers(_document, object.object_id, modifiers, "Remove %s" % removed_name)
	_mark_dirty()


func _on_modifier_up_pressed() -> void:
	_move_selected_modifier(-1)


func _on_modifier_down_pressed() -> void:
	_move_selected_modifier(1)


func _move_selected_modifier(direction: int) -> void:
	var object: GMSModelObject = _get_selected_object()
	if not _has_editable_modifier(object):
		return
	var target_index: int = _selected_modifier_index + direction
	if target_index < 0 or target_index >= object.modifiers.size():
		return
	var modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var temporary: GMSModifier = modifiers[_selected_modifier_index]
	modifiers[_selected_modifier_index] = modifiers[target_index]
	modifiers[target_index] = temporary
	_selected_modifier_index = target_index
	_history.set_modifiers(_document, object.object_id, modifiers, "Reorder Modifiers")
	_mark_dirty()


func _on_modifier_apply_pressed() -> void:
	_flush_modifier_live_change()
	var object: GMSModelObject = _get_selected_object()
	if not _has_editable_modifier(object):
		return
	if _selection.mode != GMSSelection.Mode.OBJECT:
		_status_label.text = "Apply modifiers in Object mode."
		return
	object.poll_async_evaluation()
	var baked_mesh: GMSMeshData = object.get_cached_evaluated_mesh_through(
		_selected_modifier_index
	)
	if baked_mesh == null:
		object.retry_async_evaluation()
		object.get_evaluated_mesh_data()
		baked_mesh = object.get_cached_evaluated_mesh_through(_selected_modifier_index)
	if baked_mesh == null and object.is_async_evaluation_pending():
		_queued_modifier_apply_object_id = object.object_id
		_queued_modifier_apply_index = _selected_modifier_index
		_queued_modifier_apply_signature = object.modifiers[_selected_modifier_index].get_cache_signature()
		_status_label.text = "Modifier preview is evaluating. It will apply automatically when ready."
		_monitor_modifier_evaluation(object.object_id)
		return
	_apply_modifier_result(object, _selected_modifier_index, baked_mesh)


func _apply_queued_modifier() -> void:
	if _queued_modifier_apply_object_id.is_empty():
		return
	var object: GMSModelObject = _document.get_object(_queued_modifier_apply_object_id) if _document != null else null
	var modifier_index: int = _queued_modifier_apply_index
	var expected_signature: int = _queued_modifier_apply_signature
	_queued_modifier_apply_object_id = ""
	_queued_modifier_apply_index = -1
	_queued_modifier_apply_signature = 0
	if object == null or object.locked:
		return
	if modifier_index < 0 or modifier_index >= object.modifiers.size():
		return
	var modifier: GMSModifier = object.modifiers[modifier_index]
	if modifier == null or modifier.get_cache_signature() != expected_signature:
		_status_label.text = "Queued modifier apply was cancelled because the modifier changed."
		return
	object.poll_async_evaluation()
	var baked_mesh: GMSMeshData = object.get_cached_evaluated_mesh_through(modifier_index)
	if baked_mesh == null:
		_status_label.text = "The completed modifier preview was unavailable. Apply again."
		return
	_apply_modifier_result(object, modifier_index, baked_mesh)


func _apply_modifier_result(
	object: GMSModelObject,
	modifier_index: int,
	baked_mesh: GMSMeshData
) -> void:
	var used_cached_result: bool = baked_mesh != null
	if baked_mesh == null:
		baked_mesh = GMSModifierEvaluator.evaluate_through(
			object.mesh_data,
			object.modifiers,
			modifier_index
		)
	if baked_mesh == null or (not used_cached_result and not baked_mesh.is_valid()):
		_status_label.text = "The selected modifier stack could not produce a valid mesh."
		return
	var remaining: Array[GMSModifier] = []
	for remaining_index: int in range(modifier_index + 1, object.modifiers.size()):
		var remaining_modifier: GMSModifier = object.modifiers[remaining_index]
		if remaining_modifier != null:
			remaining.append(remaining_modifier.duplicate_modifier())
	var preserved_array_mesh: ArrayMesh = null
	if used_cached_result and remaining.is_empty():
		preserved_array_mesh = object.get_evaluated_array_mesh()
	var applied_name: String = object.modifiers[modifier_index].get_display_name()
	_selected_modifier_index = 0 if not remaining.is_empty() else -1
	_history.set_mesh_and_modifiers(
		_document,
		object.object_id,
		baked_mesh,
		remaining,
		"Apply Through %s" % applied_name,
		preserved_array_mesh
	)
	_selection.clear_components()
	_mark_dirty()


func _has_editable_modifier(object: GMSModelObject) -> bool:
	return (
		object != null
		and not object.locked
		and _selected_modifier_index >= 0
		and _selected_modifier_index < object.modifiers.size()
		and object.modifiers[_selected_modifier_index] != null
	)


func _on_material_slot_selected(material_index: int) -> void:
	if _suppress_ui_signals:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or material_index < 0 or material_index >= object.materials.size():
		return
	_document.set_object_active_material_index(object.object_id, material_index)
	_update_properties()


func _on_add_material_slot_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	var new_index: int = materials.size()
	materials.append(GMSModelObject.create_default_material("Material %d" % (new_index + 1)))
	_history.set_material_state(
		_document,
		object.object_id,
		materials,
		new_index,
		null,
		"Add Material Slot"
	)
	_mark_dirty()
	_status_label.text = "Added material slot %d." % (new_index + 1)


func _on_remove_material_slot_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or object.materials.size() <= 1:
		return
	var removed_index: int = clampi(object.active_material_index, 0, object.materials.size() - 1)
	var materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	materials.remove_at(removed_index)
	var remapped_mesh: GMSMeshData = object.mesh_data.duplicate_mesh_data()
	remapped_mesh.remap_removed_material_slot(removed_index)
	var new_active_index: int = mini(removed_index, materials.size() - 1)
	_history.set_material_state(
		_document,
		object.object_id,
		materials,
		new_active_index,
		remapped_mesh,
		"Remove Material Slot"
	)
	_mark_dirty()
	_status_label.text = "Removed material slot. Its faces now use slot 1."


func _on_assign_material_to_faces_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if (
		object == null
		or _selection.mode != GMSSelection.Mode.FACE
		or _selection.face_indices.is_empty()
	):
		_status_label.text = "Select faces in Face mode before assigning a material."
		return
	var new_mesh: GMSMeshData = object.mesh_data.duplicate_mesh_data()
	new_mesh.assign_material_to_faces(_selection.face_indices, object.active_material_index)
	_history.set_mesh(_document, object.object_id, new_mesh, "Assign Material to Faces")
	_mark_dirty()
	_status_label.text = "Assigned material slot %d to %d faces." % [
		object.active_material_index + 1,
		_selection.face_indices.size()
	]


func _on_apply_material_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var active_index: int = clampi(object.active_material_index, 0, object.materials.size() - 1)
	var materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	var active_material: StandardMaterial3D = materials[active_index]
	if active_material == null:
		active_material = GMSModelObject.create_default_material("Material %d" % (active_index + 1))
	var cleaned_name: String = _material_name_edit.text.strip_edges()
	active_material.resource_name = cleaned_name if not cleaned_name.is_empty() else "Material %d" % (active_index + 1)
	active_material.albedo_color = _material_color.color
	active_material.metallic = float(_metallic_spin.value)
	active_material.roughness = float(_roughness_spin.value)
	active_material.cull_mode = BaseMaterial3D.CULL_BACK
	materials[active_index] = active_material
	_history.set_material_state(
		_document,
		object.object_id,
		materials,
		active_index,
		null,
		"Change Material"
	)
	_mark_dirty()


func _on_load_texture_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	_texture_target_object_id = object.object_id
	_texture_target_material_index = object.active_material_index
	_show_window_centered_ratio(_texture_dialog, 0.62)


func _on_texture_file_selected(path: String) -> void:
	var object: GMSModelObject = null
	if _document != null:
		object = _document.get_object(_texture_target_object_id)
	var target_material_index: int = _texture_target_material_index
	_texture_target_object_id = ""
	_texture_target_material_index = -1
	if object == null or target_material_index < 0 or target_material_index >= object.materials.size():
		return
	var loaded: Resource = ResourceLoader.load(path)
	if not loaded is Texture2D:
		_status_label.text = "The selected resource is not a Texture2D."
		return
	var materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	var active_material: StandardMaterial3D = materials[target_material_index]
	if active_material == null:
		active_material = GMSModelObject.create_default_material("Material %d" % (target_material_index + 1))
	active_material.albedo_texture = loaded as Texture2D
	active_material.cull_mode = BaseMaterial3D.CULL_BACK
	materials[target_material_index] = active_material
	_history.set_material_state(
		_document,
		object.object_id,
		materials,
		target_material_index,
		null,
		"Assign Material Texture"
	)
	_mark_dirty()
	_status_label.text = "Assigned the albedo texture to material slot %d." % (target_material_index + 1)


func _on_clear_texture_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var active_index: int = clampi(object.active_material_index, 0, object.materials.size() - 1)
	var current_material: StandardMaterial3D = object.materials[active_index]
	if current_material == null or current_material.albedo_texture == null:
		return
	var materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	materials[active_index].albedo_texture = null
	_history.set_material_state(
		_document,
		object.object_id,
		materials,
		active_index,
		null,
		"Clear Material Texture"
	)
	_mark_dirty()
	_status_label.text = "Cleared the active material's albedo texture."


func _on_open_uv_editor_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		return
	_ensure_imported_uv_seams(object)
	_uv_editor_window.set_data(
		object.mesh_data,
		_get_uv_editor_textures(object),
		_get_uv_editor_material_names(object),
		object.active_material_index
	)
	_uv_editor_window.open_editor()


func _on_uv_editor_face_selection_changed(face_indices: PackedInt32Array) -> void:
	if _suppress_ui_signals or _document == null:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		return
	if not face_indices.is_empty():
		var first_face_index: int = face_indices[0]
		if first_face_index >= 0 and first_face_index < object.mesh_data.faces.size():
			var selected_material_index: int = object.mesh_data.get_face_material(first_face_index)
			if selected_material_index != object.active_material_index:
				_document.set_object_active_material_index(
					object.object_id,
					selected_material_index
				)
	var object_ids: PackedStringArray = PackedStringArray()
	object_ids.append(object.object_id)
	_selection.restore_state(
		GMSSelection.Mode.FACE,
		object_ids,
		PackedInt32Array(),
		PackedInt32Array(),
		face_indices
	)


func _on_uv_editor_active_material_changed(material_index: int) -> void:
	if _suppress_ui_signals or _document == null:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null or material_index < 0 or material_index >= object.materials.size():
		return
	if object.active_material_index == material_index:
		return
	_document.set_object_active_material_index(object.object_id, material_index)
	_update_properties()


func _get_uv_editor_textures(object: GMSModelObject) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	if object == null:
		return result
	for material: StandardMaterial3D in object.materials:
		result.append(material.albedo_texture if material != null else null)
	return result


func _get_uv_editor_material_names(object: GMSModelObject) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if object == null:
		return result
	for material_index: int in object.materials.size():
		var material: StandardMaterial3D = object.materials[material_index]
		var material_name: String = material.resource_name.strip_edges() if material != null else ""
		if material_name.is_empty():
			material_name = "Material %d" % (material_index + 1)
		result.append(material_name)
	return result


func _ensure_imported_uv_seams(object: GMSModelObject) -> void:
	if object == null or object.mesh_data == null or not object.mesh_data.uv_seam_analysis_pending:
		return
	GMSMeshImporter.ensure_uv_seams(object.mesh_data)
	object.invalidate_geometry_cache()
	_document.set_object_mesh(object.object_id, object.mesh_data)


func _selected_model_edges(object: GMSModelObject) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if object == null or object.mesh_data == null or _selection.mode != GMSSelection.Mode.EDGE:
		return result
	var edges: Array[Vector2i] = object.mesh_data.get_edges()
	for edge_index: int in _selection.edge_indices:
		if edge_index < 0 or edge_index >= edges.size():
			continue
		if not result.has(edges[edge_index]):
			result.append(edges[edge_index])
	return result


func _on_mark_uv_seams_pressed(marked: bool) -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	_ensure_imported_uv_seams(object)
	var edges: Array[Vector2i] = _selected_model_edges(object)
	if edges.is_empty():
		_status_label.text = "Enter Edge mode and select one or more mesh edges first."
		return
	var new_mesh: GMSMeshData = GMSUVOperations.mark_edges_as_seams(object.mesh_data, edges, marked)
	_history.set_mesh(_document, object.object_id, new_mesh, "Mark UV Seams" if marked else "Clear UV Seams")
	_mark_dirty()
	_status_label.text = "%s %d UV seam edges." % ["Marked" if marked else "Cleared", edges.size()]


func _on_unwrap_from_seams_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	_ensure_imported_uv_seams(object)
	var target_faces: PackedInt32Array = _get_uv_target_faces(object)
	if target_faces.is_empty():
		_status_label.text = "No faces from material slot %d are selected for UV processing." % (object.active_material_index + 1)
		return
	_start_uv_background_operation(
		object,
		target_faces,
		"seams",
		0.0,
		"Unwrap From Seams",
		"Unwrapped selected faces from the marked seams and packed the resulting islands."
	)


func _on_auto_unwrap_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	_ensure_imported_uv_seams(object)
	var target_faces: PackedInt32Array = _get_uv_target_faces(object)
	if target_faces.is_empty():
		_status_label.text = "No faces from material slot %d are selected for UV processing." % (object.active_material_index + 1)
		return
	_start_uv_background_operation(
		object,
		target_faces,
		"smart",
		float(_uv_auto_angle_spin.value),
		"Smart UV Project",
		"Smart UV Project created angle-based UV islands and packed them without changing marked seams."
	)


func _on_pack_uv_islands_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or not object.mesh_data.has_uv_map:
		return
	var target_faces: PackedInt32Array = _get_uv_target_faces(object)
	if target_faces.is_empty():
		_status_label.text = "No faces from material slot %d are selected for UV processing." % (object.active_material_index + 1)
		return
	_start_uv_background_operation(
		object,
		target_faces,
		"pack",
		0.0,
		"Pack UV Islands",
		"Packed UV islands independently inside each material tile."
	)


func _start_uv_background_operation(
	object: GMSModelObject,
	target_faces: PackedInt32Array,
	operation: String,
	angle_degrees: float,
	history_name: String,
	success_message: String
) -> void:
	if object == null or object.mesh_data == null:
		return
	var source: GMSMeshData = object.mesh_data.duplicate_mesh_data_fast()
	var faces: PackedInt32Array = target_faces.duplicate()
	var completion: Callable = Callable(self, "_finish_uv_background_operation").bind(
		_document,
		object.object_id,
		object.mesh_data.get_change_revision(),
		history_name,
		success_message
	)
	_start_background_operation(
		history_name,
		Callable(self, "_run_uv_background_operation").bind(
			source,
			faces,
			operation,
			angle_degrees
		),
		completion
	)


func _run_uv_background_operation(
	job: GMSBackgroundJob,
	source: GMSMeshData,
	target_faces: PackedInt32Array,
	operation: String,
	angle_degrees: float
) -> Variant:
	var groups: Array[PackedInt32Array] = GMSUVOperations.group_faces_by_material(source, target_faces)
	if groups.is_empty():
		return source
	var result: GMSMeshData = source
	for group_index: int in groups.size():
		if job.is_cancelled():
			return null
		var group: PackedInt32Array = groups[group_index]
		var material_index: int = result.get_face_material(group[0])
		var proxy: GMSBackgroundProgressProxy = GMSBackgroundProgressProxy.new(
			job,
			float(group_index) / float(groups.size()),
			float(group_index + 1) / float(groups.size()),
			"Material %d" % (material_index + 1)
		)
		match operation:
			"seams":
				result = GMSUVOperations.unwrap_from_seams(result, group, 0.02, proxy)
			"smart":
				result = GMSUVOperations.smart_uv_project(
					result,
					group,
					angle_degrees,
					0.02,
					proxy
				)
			"pack":
				result = GMSUVOperations.pack_islands(result, group, 0.02, proxy)
		if result == null:
			return null
	return result


func _finish_uv_background_operation(
	result: Variant,
	cancelled: bool,
	target_document: GMSDocument,
	object_id: String,
	source_revision: int,
	history_name: String,
	success_message: String
) -> void:
	if cancelled:
		_status_label.text = "%s cancelled. The mesh was not changed." % history_name
		return
	if target_document == null or target_document != _document:
		_status_label.text = "%s result discarded because the active document changed." % history_name
		return
	var new_mesh: GMSMeshData = result as GMSMeshData
	if new_mesh == null:
		_status_label.text = "%s failed before producing UV data." % history_name
		return
	var object: GMSModelObject = _document.get_object(object_id) if _document != null else null
	if object == null or object.mesh_data == null:
		_status_label.text = "%s finished, but the source object no longer exists." % history_name
		return
	if object.mesh_data.get_change_revision() != source_revision:
		_status_label.text = "%s result discarded because the mesh changed while it was running." % history_name
		return
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "%s did not change the UV layout." % history_name
		return
	_history.set_mesh(_document, object_id, new_mesh, history_name)
	_mark_dirty()
	_status_label.text = success_message


func _on_uv_editor_mesh_preview_requested(preview_mesh: GMSMeshData) -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or preview_mesh == null or _document == null:
		return
	if _uv_live_preview_object_id.is_empty():
		_uv_live_preview_object_id = object.object_id
		_uv_live_preview_original_mesh = object.mesh_data
		_uv_live_preview_was_dirty = _is_dirty
	elif _uv_live_preview_object_id != object.object_id:
		_restore_uv_editor_live_preview()
		_uv_live_preview_object_id = object.object_id
		_uv_live_preview_original_mesh = object.mesh_data
		_uv_live_preview_was_dirty = _is_dirty
	_document.set_object_mesh(object.object_id, preview_mesh)


func _on_uv_editor_mesh_preview_cancelled() -> void:
	_restore_uv_editor_live_preview()
	_status_label.text = "UV transform cancelled."


func _restore_uv_editor_live_preview() -> void:
	if _uv_live_preview_object_id.is_empty():
		return
	var object_id: String = _uv_live_preview_object_id
	var original_mesh: GMSMeshData = _uv_live_preview_original_mesh
	var was_dirty: bool = _uv_live_preview_was_dirty
	if _document != null and original_mesh != null:
		_document.set_object_mesh(object_id, original_mesh)
	_uv_live_preview_object_id = ""
	_uv_live_preview_original_mesh = null
	_uv_live_preview_was_dirty = false
	_is_dirty = was_dirty
	_update_document_label()


func _on_uv_editor_mesh_commit_requested(new_mesh: GMSMeshData, action_name: String) -> void:
	if new_mesh == null:
		return
	var preview_object_id: String = _uv_live_preview_object_id
	_restore_uv_editor_live_preview()
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	if not preview_object_id.is_empty() and object.object_id != preview_object_id:
		_status_label.text = "%s cancelled because the selected object changed." % action_name
		return
	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_mark_dirty()
	_status_label.text = "%s applied." % action_name


func _on_uv_checker_preview_toggled(enabled: bool) -> void:
	if not _uv_checker_preview_object_id.is_empty():
		_viewport.clear_material_preview_override(_uv_checker_preview_object_id)
		_uv_checker_preview_object_id = ""
	if not enabled:
		return
	var object: GMSModelObject = _get_selected_object()
	if object == null:
		return
	var preview: StandardMaterial3D
	if object.get_active_material() != null:
		preview = object.get_active_material().duplicate(true) as StandardMaterial3D
	else:
		preview = GMSModelObject.create_default_material("UV Checker")
	preview.albedo_color = Color.WHITE
	preview.albedo_texture = GMSUVOperations.create_checker_texture(256, 8)
	preview.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	preview.texture_repeat = true
	preview.cull_mode = BaseMaterial3D.CULL_BACK
	_uv_checker_preview_object_id = object.object_id
	_viewport.set_material_preview_override(object.object_id, preview)


func _on_project_uv_pressed() -> void:
	_apply_uv_projection(_uv_projection_option.get_selected_id())


func _apply_uv_projection(projection_id: int) -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var target_faces: PackedInt32Array = _get_uv_target_faces(object)
	if target_faces.is_empty():
		_status_label.text = "Use Object mode for all faces or select faces in Face mode."
		return

	var new_mesh: GMSMeshData
	var action_name: String
	match projection_id:
		1:
			new_mesh = GMSUVOperations.project_planar(object.mesh_data, target_faces, GMSUVOperations.ProjectionAxis.X)
			action_name = "Planar UV Projection X"
		2:
			new_mesh = GMSUVOperations.project_planar(object.mesh_data, target_faces, GMSUVOperations.ProjectionAxis.Y)
			action_name = "Planar UV Projection Y"
		3:
			new_mesh = GMSUVOperations.project_planar(object.mesh_data, target_faces, GMSUVOperations.ProjectionAxis.Z)
			action_name = "Planar UV Projection Z"
		4:
			new_mesh = GMSUVOperations.project_cylindrical(object.mesh_data, target_faces)
			action_name = "Cylindrical UV Projection"
		5:
			new_mesh = GMSUVOperations.project_spherical(object.mesh_data, target_faces)
			action_name = "Spherical UV Projection"
		_:
			new_mesh = GMSUVOperations.project_box(object.mesh_data, target_faces)
			action_name = "Cube UV Projection"

	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_mark_dirty()
	_status_label.text = "%s applied to %d faces." % [action_name, target_faces.size()]


func _on_transform_uv_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or not object.mesh_data.has_uv_map:
		return
	var target_faces: PackedInt32Array = _get_uv_target_faces(object)
	if target_faces.is_empty():
		_status_label.text = "Use Object mode for all faces or select faces in Face mode."
		return
	var new_mesh: GMSMeshData = GMSUVOperations.transform_uvs(
		object.mesh_data,
		target_faces,
		Vector2(float(_uv_offset_u.value), float(_uv_offset_v.value)),
		Vector2(float(_uv_scale_u.value), float(_uv_scale_v.value)),
		float(_uv_rotation_spin.value)
	)
	_history.set_mesh(_document, object.object_id, new_mesh, "Transform UVs")
	_uv_offset_u.value = 0.0
	_uv_offset_v.value = 0.0
	_uv_scale_u.value = 1.0
	_uv_scale_v.value = 1.0
	_uv_rotation_spin.value = 0.0
	_mark_dirty()


func _on_clear_uv_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or not object.mesh_data.has_uv_map:
		return
	var new_mesh: GMSMeshData = GMSUVOperations.clear_uv_map(object.mesh_data)
	_history.set_mesh(_document, object.object_id, new_mesh, "Clear UV Map")
	_mark_dirty()
	_status_label.text = "Cleared the object's UV map."


func _get_uv_target_faces(object: GMSModelObject) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if object == null or object.mesh_data == null:
		return result
	var mesh: GMSMeshData = object.mesh_data
	var active_material_index: int = clampi(
		object.active_material_index,
		0,
		maxi(object.materials.size() - 1, 0)
	)
	var candidates: PackedInt32Array = PackedInt32Array()
	match _selection.mode:
		GMSSelection.Mode.OBJECT:
			candidates = GMSUVOperations.all_faces(mesh)
		GMSSelection.Mode.FACE:
			candidates = _selection.face_indices.duplicate()
		GMSSelection.Mode.EDGE:
			var topology: GMSTopology = mesh.get_topology()
			var seen_edge_faces: Dictionary = {}
			for edge: Vector2i in _selected_model_edges(object):
				for face_index: int in topology.get_edge_faces(
					GMSMeshData.canonical_edge(edge.x, edge.y)
				):
					if not seen_edge_faces.has(face_index):
						seen_edge_faces[face_index] = true
						candidates.append(face_index)
		GMSSelection.Mode.VERTEX:
			var selected_vertices: Dictionary = {}
			for vertex_index: int in _selection.vertex_indices:
				selected_vertices[vertex_index] = true
			for face_index: int in mesh.faces.size():
				for vertex_index: int in mesh.faces[face_index]:
					if selected_vertices.has(vertex_index):
						candidates.append(face_index)
						break
	for face_index: int in candidates:
		if face_index < 0 or face_index >= mesh.faces.size():
			continue
		if mesh.get_face_material(face_index) == active_material_index:
			result.append(face_index)
	return result


func _on_make_face_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.size() < 3:
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.make_face(
		object.mesh_data,
		_selection.vertex_indices
	)
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "A face requires three or more unique coplanar vertices and must not duplicate an existing face."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Make Face")
	_mark_dirty()


func _on_merge_vertices_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.size() < 2:
		return
	var selected: PackedInt32Array = _selection.vertex_indices.duplicate()
	selected.sort()
	var merged_index: int = selected[0]
	var new_mesh: GMSMeshData = GMSMeshOperations.merge_vertices(object.mesh_data, selected)
	if _mesh_data_equal(object.mesh_data, new_mesh):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Merge Vertices at Centre")
	_selection.select_vertex(merged_index)
	_mark_dirty()


func _on_remove_unused_vertices_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.remove_unused_vertices(object.mesh_data)
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "No unused vertices were found."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Remove Unused Vertices")
	_selection.clear_components()
	_mark_dirty()


func _on_flip_normals_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.flip_faces(
		object.mesh_data,
		_selection.face_indices
	)
	_history.set_mesh(_document, object.object_id, new_mesh, "Flip Face Normals")
	_mark_dirty()


func _on_move_selection_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var vertex_indices: PackedInt32Array = _get_selected_mesh_vertices()
	if vertex_indices.is_empty():
		return
	vertex_indices.sort()
	var old_positions: PackedVector3Array = object.mesh_data.get_vertex_positions(vertex_indices)
	var new_positions: PackedVector3Array = old_positions.duplicate()
	var offset: Vector3 = _get_vector_fields(_move_fields)
	for index: int in new_positions.size():
		new_positions[index] += offset
	_history.set_vertex_positions(
		_document, object.object_id, vertex_indices, old_positions, new_positions, "Move Mesh Selection"
	)
	_set_vector_fields(_move_fields, Vector3.ZERO)
	_mark_dirty()


func _on_scale_selection_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var vertex_indices: PackedInt32Array = _get_selected_mesh_vertices()
	if vertex_indices.is_empty():
		return
	vertex_indices.sort()
	var pivot: Vector3 = GMSMeshOperations.get_vertices_center(object.mesh_data, vertex_indices)
	var scale_value: Vector3 = _get_vector_fields(_component_scale_fields)
	var old_positions: PackedVector3Array = object.mesh_data.get_vertex_positions(vertex_indices)
	var new_positions: PackedVector3Array = old_positions.duplicate()
	for index: int in new_positions.size():
		new_positions[index] = pivot + (new_positions[index] - pivot) * scale_value
	_history.set_vertex_positions(
		_document, object.object_id, vertex_indices, old_positions, new_positions, "Scale Mesh Selection"
	)
	_set_vector_fields(_component_scale_fields, Vector3.ONE)
	_mark_dirty()


func _on_extrude_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	var distance: float = float(_extrude_distance_spin.value)
	match _selection.mode:
		GMSSelection.Mode.VERTEX:
			if _selection.vertex_indices.is_empty():
				return
			var conversion: Dictionary = GMSAdvancedMeshOperations.extrude_vertices(
				object.mesh_data,
				_selection.vertex_indices,
				distance
			)
			var new_mesh: GMSMeshData = conversion["mesh"]
			if _reject_non_manifold_result(new_mesh, "Vertex extrusion"):
				return
			if _mesh_data_equal(object.mesh_data, new_mesh):
				return
			_history.set_mesh(_document, object.object_id, new_mesh, "Extrude Vertices")
			_selection.set_component_indices(conversion["vertex_indices"], GMSSelection.Operation.SET)
		GMSSelection.Mode.EDGE:
			if _selection.edge_indices.is_empty():
				return
			var conversion: Dictionary = GMSAdvancedMeshOperations.extrude_edges(
				object.mesh_data,
				_selection.edge_indices,
				distance
			)
			var new_mesh: GMSMeshData = conversion["mesh"]
			if _reject_non_manifold_result(new_mesh, "Edge extrusion"):
				return
			if _mesh_data_equal(object.mesh_data, new_mesh):
				_status_label.text = "Edge extrusion requires selected boundary or loose edges."
				return
			_history.set_mesh(_document, object.object_id, new_mesh, "Extrude Edges")
			_selection.set_component_indices(conversion["edge_indices"], GMSSelection.Operation.SET)
		GMSSelection.Mode.FACE:
			_on_extrude_face_pressed()
			return
		_:
			return
	_mark_dirty()


func _on_extrude_face_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.extrude_faces(
		object.mesh_data,
		_selection.face_indices,
		float(_extrude_distance_spin.value)
	)
	var action_name: String = "Extrude Face" if _selection.face_indices.size() == 1 else "Extrude Face Region"
	if _reject_non_manifold_result(new_mesh, action_name):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_mark_dirty()
	_status_label.text = "%s applied. Existing face UVs were preserved and new side faces were box-projected." % action_name


func _begin_bevel_adjust(vertex_bevel: bool) -> void:
	if _transform_active or _scalar_tool_active:
		return
	var object: GMSModelObject = _get_editable_object()
	if object == null:
		return
	if vertex_bevel:
		if _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.is_empty():
			_status_label.text = "Select vertices before beveling."
			return
	else:
		if _selection.mode != GMSSelection.Mode.EDGE or _selection.edge_indices.is_empty():
			_status_label.text = "Select edges before beveling."
			return

	_scalar_tool_active = true
	_scalar_tool_kind = "bevel_vertices" if vertex_bevel else "bevel_edges"
	_scalar_tool_object_id = object.object_id
	_scalar_tool_original_mesh = object.mesh_data.duplicate_mesh_data()
	_scalar_tool_component_indices = (
		_selection.vertex_indices.duplicate()
		if vertex_bevel
		else _selection.edge_indices.duplicate()
	)
	_scalar_tool_was_dirty = _is_dirty
	var maximum_width: float = maxf(object.mesh_data.get_aabb().size.length() * 0.45, 0.01)
	var sensitivity: float = maxf(object.mesh_data.get_aabb().size.length() / 700.0, 0.0001)
	if not _viewport.begin_scalar_adjust(
		float(_bevel_width_spin.value),
		0.0001,
		maximum_width,
		sensitivity,
		"Vertex Bevel Width" if vertex_bevel else "Edge Bevel Width"
	):
		_clear_scalar_tool_context()
		_status_label.text = "Bevel adjustment could not start."


func _on_viewport_scalar_adjust_preview(value: float) -> void:
	if not _scalar_tool_active or _document == null:
		return
	var object: GMSModelObject = _document.get_object(_scalar_tool_object_id)
	if object == null or _scalar_tool_original_mesh == null:
		return
	var conversion: Dictionary
	if _scalar_tool_kind == "bevel_vertices":
		conversion = GMSAdvancedMeshOperations.bevel_vertices(
			_scalar_tool_original_mesh,
			_scalar_tool_component_indices,
			value
		)
	else:
		conversion = GMSAdvancedMeshOperations.bevel_edges(
			_scalar_tool_original_mesh,
			_scalar_tool_component_indices,
			value
		)
	var preview_mesh: GMSMeshData = conversion["mesh"]
	if preview_mesh == null or not preview_mesh.is_valid():
		return
	if _non_manifold_edge_count(preview_mesh) > 0:
		return
	_document.set_object_mesh(object.object_id, preview_mesh)
	_suppress_ui_signals = true
	_bevel_width_spin.value = value
	_suppress_ui_signals = false


func _on_viewport_scalar_adjust_committed() -> void:
	if not _scalar_tool_active or _document == null:
		return
	var object: GMSModelObject = _document.get_object(_scalar_tool_object_id)
	if object == null or _scalar_tool_original_mesh == null:
		_clear_scalar_tool_context()
		return
	var final_mesh: GMSMeshData = object.mesh_data
	var changed: bool = (
		final_mesh != null
		and not _mesh_data_equal(_scalar_tool_original_mesh, final_mesh)
	)
	_document.set_object_mesh(object.object_id, _scalar_tool_original_mesh)
	var action_name: String = (
		"Bevel Vertices"
		if _scalar_tool_kind == "bevel_vertices"
		else "Bevel Edges"
	)
	var was_dirty: bool = _scalar_tool_was_dirty
	_clear_scalar_tool_context()
	if changed:
		_history.set_mesh(_document, object.object_id, final_mesh, action_name)
		_selection.clear_components()
		_mark_dirty()
		_status_label.text = "%s applied. Existing UVs were retained where possible; bevel faces were box-projected." % action_name
	else:
		_is_dirty = was_dirty
		_update_document_label()
		_status_label.text = "Bevel cancelled because the selected topology could not produce a valid result."


func _on_viewport_scalar_adjust_cancelled() -> void:
	if not _scalar_tool_active or _document == null:
		return
	var object: GMSModelObject = _document.get_object(_scalar_tool_object_id)
	if object != null and _scalar_tool_original_mesh != null:
		_document.set_object_mesh(object.object_id, _scalar_tool_original_mesh)
	var was_dirty: bool = _scalar_tool_was_dirty
	_clear_scalar_tool_context()
	_is_dirty = was_dirty
	_update_document_label()
	_update_properties()
	_update_status()


func _clear_scalar_tool_context() -> void:
	_scalar_tool_active = false
	_scalar_tool_kind = ""
	_scalar_tool_object_id = ""
	_scalar_tool_original_mesh = null
	_scalar_tool_component_indices.clear()
	_scalar_tool_was_dirty = false


func _non_manifold_edge_count(mesh: GMSMeshData) -> int:
	if mesh == null:
		return 0
	return mesh.get_topology().non_manifold_edges.size()


func _reject_non_manifold_result(mesh: GMSMeshData, operation_name: String) -> bool:
	var count: int = _non_manifold_edge_count(mesh)
	if count <= 0:
		return false
	_status_label.text = "%s cancelled: it would create %d non-manifold edge%s." % [
		operation_name,
		count,
		"" if count == 1 else "s",
	]
	return true


func _on_validate_topology_pressed() -> void:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		_status_label.text = "Select a mesh object to validate."
		return
	var topology: GMSTopology = object.mesh_data.get_topology()
	var boundary_count: int = topology.get_boundary_loops().size()
	var non_manifold_count: int = topology.non_manifold_edges.size()
	if non_manifold_count > 0:
		_status_label.text = "Topology check: %d boundary loop%s, %d non-manifold edge%s. Non-manifold edges are shared by more than two faces and should be repaired." % [
			boundary_count,
			"" if boundary_count == 1 else "s",
			non_manifold_count,
			"" if non_manifold_count == 1 else "s",
		]
	elif boundary_count > 0:
		_status_label.text = "Topology check: %d open boundary loop%s, 0 non-manifold edges. Boundaries are valid for open surfaces; fill them for a closed solid." % [
			boundary_count,
			"" if boundary_count == 1 else "s",
		]
	else:
		_status_label.text = "Topology check passed: closed manifold mesh with 0 boundary loops and 0 non-manifold edges."


func _on_bevel_tool_pressed() -> void:
	if _selection.mode == GMSSelection.Mode.VERTEX:
		_begin_bevel_adjust(true)
	else:
		_begin_bevel_adjust(false)


func _on_bevel_edges_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.EDGE or _selection.edge_indices.is_empty():
		_status_label.text = "Select edges before beveling."
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.bevel_edges(
		object.mesh_data,
		_selection.edge_indices,
		float(_bevel_width_spin.value)
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _reject_non_manifold_result(new_mesh, "Edge bevel"):
		return
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "The selected edges could not be beveled with this width."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Bevel Edges")
	_selection.clear_components()
	_mark_dirty()


func _on_bevel_vertices_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.VERTEX or _selection.vertex_indices.is_empty():
		_status_label.text = "Select vertices before beveling."
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.bevel_vertices(
		object.mesh_data,
		_selection.vertex_indices,
		float(_bevel_width_spin.value)
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _reject_non_manifold_result(new_mesh, "Vertex bevel"):
		return
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "The selected vertices could not be beveled with this width."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Bevel Vertices")
	_selection.clear_components()
	_mark_dirty()


func _on_set_crease_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.EDGE or _selection.edge_indices.is_empty():
		_status_label.text = "Select edges before setting a crease."
		return
	var new_mesh: GMSMeshData = GMSAdvancedMeshOperations.set_edge_crease(
		object.mesh_data,
		_selection.edge_indices,
		float(_crease_weight_spin.value)
	)
	_history.set_mesh(_document, object.object_id, new_mesh, "Set Edge Crease")
	_mark_dirty()


func _on_dissolve_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.get_component_count() == 0:
		return
	var conversion: Dictionary
	var action_name: String
	match _selection.mode:
		GMSSelection.Mode.VERTEX:
			conversion = GMSAdvancedMeshOperations.dissolve_vertices(
				object.mesh_data, _selection.vertex_indices
			)
			action_name = "Dissolve Vertices"
		GMSSelection.Mode.EDGE:
			conversion = GMSAdvancedMeshOperations.dissolve_edges(
				object.mesh_data, _selection.edge_indices
			)
			action_name = "Dissolve Edges"
		GMSSelection.Mode.FACE:
			conversion = GMSAdvancedMeshOperations.dissolve_faces(
				object.mesh_data, _selection.face_indices
			)
			action_name = "Dissolve Faces"
		_:
			return
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "The selection cannot be dissolved without invalid topology."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_selection.clear_components()
	_mark_dirty()


func _on_bridge_loops_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.EDGE or _selection.edge_indices.is_empty():
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.bridge_edge_loops(
		object.mesh_data,
		_selection.edge_indices
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = str(conversion.get(
			"reason",
			"Bridge requires two separate loops or open chains with matching vertex counts. Both must belong to the same joined object."
		))
		return
	if _reject_non_manifold_result(new_mesh, "Bridge"):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Bridge Edge Loops")
	_selection.set_mode(GMSSelection.Mode.FACE)
	_selection.set_component_indices(conversion["face_indices"], GMSSelection.Operation.SET)
	_mark_dirty()


func _on_fill_holes_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.EDGE:
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.fill_holes(
		object.mesh_data,
		_selection.edge_indices
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "No complete selected boundary loop was found. Select the hole's boundary edges."
		return
	if _reject_non_manifold_result(new_mesh, "Fill Hole"):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Fill Holes")
	_selection.set_mode(GMSSelection.Mode.FACE)
	_selection.set_component_indices(conversion["face_indices"], GMSSelection.Operation.SET)
	_mark_dirty()


func _on_knife_pressed() -> void:
	if _selection.mode != GMSSelection.Mode.FACE or _selection.object_ids.is_empty():
		_status_label.text = "Knife requires Face mode and a selected object."
		return
	if not _viewport.begin_knife():
		_status_label.text = "Knife could not start. Finish the active transform or box selection first."


func _on_viewport_knife_cut_requested(
	object_id: String,
	face_index: int,
	start_local: Vector3,
	end_local: Vector3
) -> void:
	var object: GMSModelObject = _document.get_object(object_id)
	if object == null or object.locked or object.mesh_data == null:
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.knife_cut_face(
		object.mesh_data,
		face_index,
		start_local,
		end_local
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "Knife points must lie on two different edges of the same face."
		return
	if _reject_non_manifold_result(new_mesh, "Knife Cut"):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Knife Cut")
	_selection.set_mode(GMSSelection.Mode.FACE)
	_selection.set_component_indices(conversion["face_indices"], GMSSelection.Operation.SET)
	_mark_dirty()
	_status_label.text = "Knife cut applied. Existing UVs on the split face were interpolated."


func _on_separate_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		_status_label.text = "Select faces before separating them."
		return
	if _selection.face_indices.size() >= object.mesh_data.faces.size():
		_status_label.text = "Leave at least one face on the source object when separating."
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.separate_faces(
		object.mesh_data,
		_selection.face_indices
	)
	var separated_mesh: GMSMeshData = conversion["separated_mesh"]
	if separated_mesh == null or not separated_mesh.is_valid():
		_status_label.text = "The selected faces could not be separated."
		return
	var new_object: GMSModelObject = GMSModelObject.new()
	new_object.ensure_defaults()
	new_object.display_name = _unique_name("%s Separated" % object.display_name)
	new_object.transform = object.transform
	new_object.mesh_data = separated_mesh
	new_object.materials = GMSModelObject.duplicate_materials(object.materials)
	new_object.active_material_index = object.active_material_index
	new_object.material = new_object.materials[0] if not new_object.materials.is_empty() else null
	new_object.modifiers = []
	new_object.collision_type = object.collision_type
	new_object.collision_layer = object.collision_layer
	new_object.collision_mask = object.collision_mask
	_history.separate_faces(
		_document,
		object.object_id,
		conversion["source_mesh"],
		new_object
	)
	_selection.set_mode(GMSSelection.Mode.OBJECT)
	_selection.select_object(new_object.object_id)
	_mark_dirty()


func _on_inset_face_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.face_indices.size() != 1:
		return
	var face_index: int = _selection.face_indices[0]
	var new_mesh: GMSMeshData = GMSMeshOperations.inset_face(
		object.mesh_data,
		face_index,
		float(_inset_amount_spin.value)
	)
	_history.set_mesh(_document, object.object_id, new_mesh, "Inset Face")
	_mark_dirty()


func _on_loop_cut_pressed(prefer_hovered: bool = false) -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.EDGE:
		return
	var edge_index: int = -1
	if prefer_hovered:
		var hovered: Dictionary = _viewport.get_hovered_edge()
		if str(hovered.get("object_id", "")) == object.object_id:
			edge_index = int(hovered.get("component_index", -1))
	if edge_index < 0 and not _selection.edge_indices.is_empty():
		edge_index = _selection.edge_indices[0]
	if edge_index < 0:
		_status_label.text = "Select or hover an edge before creating a loop cut."
		return
	var conversion: Dictionary = GMSAdvancedMeshOperations.loop_cut_multiple(
		object.mesh_data,
		edge_index,
		int(_loop_cut_count_spin.value),
		float(_loop_cut_slide_spin.value)
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	var new_edges: PackedInt32Array = conversion["edge_indices"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "Loop Cut requires a continuous ring of opposite edges through quad faces."
		return
	if _reject_non_manifold_result(new_mesh, "Loop Cut"):
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Loop Cut")
	_selection.set_component_indices(new_edges, GMSSelection.Operation.SET)
	_mark_dirty()
	if object.mesh_data.has_uv_map:
		_status_label.text = "Loop cut applied. The mesh was box-projected to keep the texture visible; refine the unwrap as needed."


func _on_subdivide_faces_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		return
	var estimated_faces: int = object.mesh_data.faces.size() - _selection.face_indices.size()
	for face_index: int in _selection.face_indices:
		if face_index >= 0 and face_index < object.mesh_data.faces.size():
			estimated_faces += object.mesh_data.faces[face_index].size()
	var operation_title: String = "Subdivide Faces"
	if estimated_faces >= SUBDIVISION_WARNING_FACES:
		operation_title = "Large Subdivision"

	var source: GMSMeshData = object.mesh_data.duplicate_mesh_data_fast()
	var selected_faces: PackedInt32Array = _selection.face_indices.duplicate()
	var completion: Callable = Callable(self, "_finish_subdivide_faces_operation").bind(
		_document,
		object.object_id,
		object.mesh_data.get_change_revision(),
		object.mesh_data.has_uv_map
	)
	_start_background_operation(
		operation_title,
		Callable(self, "_run_subdivide_faces_operation").bind(source, selected_faces),
		completion
	)


func _run_subdivide_faces_operation(
	job: GMSBackgroundJob,
	source: GMSMeshData,
	selected_faces: PackedInt32Array
) -> Variant:
	return GMSMeshOperations.subdivide_faces(source, selected_faces, job)


func _finish_subdivide_faces_operation(
	result: Variant,
	cancelled: bool,
	target_document: GMSDocument,
	object_id: String,
	source_revision: int,
	had_uv_map: bool
) -> void:
	if cancelled:
		_status_label.text = "Subdivision cancelled. The mesh was not changed."
		return
	if target_document == null or target_document != _document:
		_status_label.text = "Subdivision result discarded because the active document changed."
		return
	if not result is Dictionary:
		_status_label.text = "Subdivision failed before producing a result."
		return
	var conversion: Dictionary = result as Dictionary
	var new_mesh: GMSMeshData = conversion.get("mesh") as GMSMeshData
	var new_faces: PackedInt32Array = conversion.get("face_indices", PackedInt32Array())
	if new_mesh == null:
		_status_label.text = "Subdivision failed before producing a mesh."
		return
	var non_manifold_count: int = int(conversion.get("non_manifold_count", 0))
	if non_manifold_count > 0:
		_status_label.text = "Subdivide Faces stopped because the result contains %d non-manifold edges." % non_manifold_count
		return
	var object: GMSModelObject = _document.get_object(object_id) if _document != null else null
	if object == null or object.mesh_data == null:
		_status_label.text = "Subdivision finished, but the source object no longer exists."
		return
	if object.mesh_data.get_change_revision() != source_revision:
		_status_label.text = "Subdivision result discarded because the source mesh changed while it was running."
		return
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "Subdivision did not change the selected faces."
		return
	_history.set_mesh(_document, object_id, new_mesh, "Subdivide Faces")
	_selection.set_component_indices(new_faces, GMSSelection.Operation.SET)
	_mark_dirty()
	if had_uv_map:
		_status_label.text = "Faces subdivided. UVs were preserved and adjusted for the new topology."
	else:
		_status_label.text = "Faces subdivided."


func _on_triangulate_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		return
	var conversion: Dictionary = GMSMeshOperations.triangulate_faces(
		object.mesh_data,
		_selection.face_indices
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	var new_faces: PackedInt32Array = conversion["face_indices"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "The selected faces are already triangles."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Triangulate Faces")
	_selection.set_component_indices(new_faces, GMSSelection.Operation.SET)
	_mark_dirty()


func _on_tris_to_quads_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.size() < 2:
		return
	var conversion: Dictionary = GMSMeshOperations.triangles_to_quads(
		object.mesh_data,
		_selection.face_indices
	)
	var new_mesh: GMSMeshData = conversion["mesh"]
	var new_faces: PackedInt32Array = conversion["face_indices"]
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "No compatible selected triangle pairs could be joined."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Tris to Quads")
	_selection.set_component_indices(new_faces, GMSSelection.Operation.SET)
	_mark_dirty()


func _on_recalculate_normals_pressed() -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.mode != GMSSelection.Mode.FACE or _selection.face_indices.is_empty():
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.recalculate_normals_outside(
		object.mesh_data,
		_selection.face_indices
	)
	if _mesh_data_equal(object.mesh_data, new_mesh):
		_status_label.text = "Selected face normals are already consistently oriented."
		return
	_history.set_mesh(_document, object.object_id, new_mesh, "Recalculate Normals Outside")
	_mark_dirty()


func _on_shade_smooth_pressed() -> void:
	_set_selected_faces_smooth(true)


func _on_shade_flat_pressed() -> void:
	_set_selected_faces_smooth(false)


func _set_selected_faces_smooth(is_smooth: bool) -> void:
	var object: GMSModelObject = _get_editable_object()
	if object == null or _selection.face_indices.is_empty():
		return
	var new_mesh: GMSMeshData = GMSMeshOperations.set_faces_smooth(
		object.mesh_data,
		_selection.face_indices,
		is_smooth
	)
	var action_name: String = "Shade Faces Smooth" if is_smooth else "Shade Faces Flat"
	_history.set_mesh(_document, object.object_id, new_mesh, action_name)
	_mark_dirty()


func _get_selected_mesh_vertices() -> PackedInt32Array:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.mesh_data == null:
		return PackedInt32Array()
	return GMSMeshOperations.get_selected_vertex_indices(
		object.mesh_data,
		_selection.mode,
		_selection.vertex_indices,
		_selection.edge_indices,
		_selection.face_indices
	)


func _get_selected_object() -> GMSModelObject:
	if _document == null:
		return null
	return _document.get_object(_selection.get_primary_object_id())


func _get_editable_object() -> GMSModelObject:
	var object: GMSModelObject = _get_selected_object()
	if object == null or object.locked or object.mesh_data == null:
		return null
	return object


func _ensure_recovery_directory() -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(RECOVERY_DIRECTORY)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if error != OK and error != ERR_ALREADY_EXISTS:
		if _status_label != null:
			_status_label.text = "Could not create the GMS recovery directory (error %d)." % error
		return false
	return true


func _on_autosave_timeout() -> void:
	if not _is_dirty or _document == null:
		return
	if _transform_active or _scalar_tool_active or _remesh_task_id >= 0:
		return
	_write_recovery_copy(false)


func _write_recovery_copy(force: bool) -> bool:
	if _document == null or not _is_dirty:
		return false
	if not force and (_transform_active or _scalar_tool_active or _remesh_task_id >= 0):
		return false
	if not _ensure_recovery_directory():
		return false
	var recovery_copy: GMSDocument = _document_copy_for_storage()
	if recovery_copy == null:
		return false
	var save_error: Error = ResourceSaver.save(recovery_copy, RECOVERY_TEMP_PATH)
	if save_error != OK:
		if _status_label != null:
			_status_label.text = "Recovery autosave failed with error %d." % save_error
		return false
	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(RECOVERY_TEMP_PATH),
		ProjectSettings.globalize_path(RECOVERY_DOCUMENT_PATH)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_TEMP_PATH))
		if _status_label != null:
			_status_label.text = "Recovery autosave could not replace the previous copy (error %d)." % rename_error
		return false
	var metadata: ConfigFile = ConfigFile.new()
	metadata.set_value("recovery", "original_path", _current_path)
	metadata.set_value("recovery", "document_name", _document.document_name)
	metadata.set_value("recovery", "saved_unix_time", Time.get_unix_time_from_system())
	var metadata_error: Error = metadata.save(RECOVERY_METADATA_PATH)
	if metadata_error != OK and _status_label != null:
		_status_label.text = "Model recovery saved, but its metadata failed with error %d." % metadata_error
	elif _status_label != null and not force:
		_status_label.text = "Recovery copy saved."
	return true


func _load_recovery_metadata() -> Dictionary:
	var result: Dictionary = {}
	var metadata: ConfigFile = ConfigFile.new()
	if metadata.load(RECOVERY_METADATA_PATH) != OK:
		return result
	result["original_path"] = str(metadata.get_value("recovery", "original_path", ""))
	result["document_name"] = str(metadata.get_value("recovery", "document_name", "Unsaved Model"))
	result["saved_unix_time"] = int(metadata.get_value("recovery", "saved_unix_time", 0))
	return result


func _offer_recovery_if_available() -> void:
	if not FileAccess.file_exists(RECOVERY_DOCUMENT_PATH) or _recovery_dialog == null:
		return
	_recovery_metadata = _load_recovery_metadata()
	var original_path: String = str(_recovery_metadata.get("original_path", ""))
	if not original_path.is_empty() and FileAccess.file_exists(original_path):
		var recovery_time: int = FileAccess.get_modified_time(RECOVERY_DOCUMENT_PATH)
		var manual_time: int = FileAccess.get_modified_time(original_path)
		if recovery_time <= manual_time:
			_clear_recovery()
			return
	var document_name: String = str(_recovery_metadata.get("document_name", "Unsaved Model"))
	var source_text: String = "an unsaved document" if original_path.is_empty() else original_path
	_recovery_dialog.dialog_text = (
		"A newer recovery copy was found for %s.\n\nSource: %s\n\nRecover it now?"
		% [document_name, source_text]
	)
	_show_window_centered(_recovery_dialog)


func _on_recovery_confirmed() -> void:
	call_deferred("_show_first_activation_notice_if_ready")
	var loaded: Resource = ResourceLoader.load(
		RECOVERY_DOCUMENT_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if not loaded is GMSDocument:
		_status_label.text = "The recovery copy is invalid and could not be opened."
		_clear_recovery()
		return
	var recovered_document: GMSDocument = (loaded as GMSDocument).duplicate(true) as GMSDocument
	if recovered_document == null:
		_status_label.text = "The recovery copy could not be duplicated safely."
		return
	var original_path: String = str(_recovery_metadata.get("original_path", ""))
	_set_document(recovered_document, original_path)
	_is_dirty = true
	_update_document_label()
	_status_label.text = "Recovered autosaved model. Save it manually to clear the recovery copy."


func _on_recovery_discarded() -> void:
	call_deferred("_show_first_activation_notice_if_ready")
	_clear_recovery()
	_status_label.text = "Recovery copy discarded."


func _clear_recovery() -> void:
	for path: String in [RECOVERY_DOCUMENT_PATH, RECOVERY_TEMP_PATH, RECOVERY_METADATA_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_recovery_metadata.clear()


func _mark_dirty() -> void:
	_is_dirty = true
	_update_document_label()
	_update_history_buttons()


func _outliner_object_label(object: GMSModelObject) -> String:
	if object == null:
		return "Object"
	if object.has_bone_attachment():
		return "%s  →  %s" % [object.display_name, object.attachment_bone_name]
	return object.display_name


func _object_summary(object: GMSModelObject) -> String:
	if object.mesh_data == null:
		return object.display_name
	var summary: String = "%s\nBase: %d vertices, %d faces" % [
		object.display_name,
		object.mesh_data.vertices.size(),
		object.mesh_data.faces.size(),
	]
	if object.has_bone_attachment():
		var rig_owner: GMSModelObject = _document.get_object(object.attachment_rig_object_id) if _document != null else null
		var owner_name: String = rig_owner.display_name if rig_owner != null else "Missing Rig"
		summary += "\nAttached: %s / %s" % [owner_name, object.attachment_bone_name]
	if object.rig_data != null and object.rig_data.has_bones():
		summary += "\nRig: %d bones%s" % [
			object.rig_data.bones.size(),
			" with weights" if object.rig_data.is_compatible(object.mesh_data.vertices.size()) else "; weights need regeneration",
		]
	if not object.modifiers.is_empty():
		var evaluated: GMSMeshData = object.get_evaluated_mesh_data()
		if evaluated != null:
			summary += "\nEvaluated: %d vertices, %d faces\n%d modifiers" % [
				evaluated.vertices.size(),
				evaluated.faces.size(),
				object.modifiers.size(),
			]
	return summary


func _rebuild_custom_modifier_controls(modifier: GMSModifier, can_edit: bool) -> void:
	if _modifier_custom_settings == null:
		return
	for child: Node in _modifier_custom_settings.get_children():
		_modifier_custom_settings.remove_child(child)
		child.free()
	_modifier_custom_controls.clear()
	_modifier_custom_active_id = modifier.custom_id
	var schema: Array[Dictionary] = GMSModifierRegistry.get_parameters(modifier.custom_id)
	if not GMSModifierRegistry.has_modifier(modifier.custom_id):
		var missing_label: Label = Label.new()
		missing_label.text = "This extension modifier is unavailable. Its saved data is preserved but it cannot be evaluated."
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_modifier_custom_settings.add_child(missing_label)
		return
	if schema.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "This extension modifier has no adjustable settings."
		_modifier_custom_settings.add_child(empty_label)
		return
	for parameter: Dictionary in schema:
		var parameter_id: String = str(parameter.get("id", ""))
		var initial_value: Variant = modifier.custom_parameters.get(
			parameter_id,
			parameter.get("default", 0.0)
		)
		var input: Control = _create_extension_parameter_input(
			parameter,
			initial_value,
			_on_modifier_live_changed
		)
		if input == null:
			continue
		_set_extension_parameter_enabled(input, can_edit)
		_modifier_custom_controls[parameter_id] = input
		_modifier_custom_settings.add_child(_wrap_extension_parameter(parameter, input))


func _create_extension_parameter_input(
	parameter: Dictionary,
	initial_value: Variant,
	changed_callback: Callable = Callable()
) -> Control:
	var parameter_type: String = str(parameter.get("type", "float")).to_lower()
	var input: Control
	match parameter_type:
		"int", "float":
			var spin: SpinBox = _make_spin_box(
				float(parameter.get("min", -100000.0)),
				float(parameter.get("max", 100000.0)),
				float(parameter.get("step", 1.0 if parameter_type == "int" else 0.01))
			)
			spin.rounded = parameter_type == "int"
			spin.value = float(initial_value)
			if changed_callback.is_valid():
				spin.value_changed.connect(changed_callback)
			input = spin
		"bool":
			var check: CheckBox = CheckBox.new()
			check.button_pressed = bool(initial_value)
			if changed_callback.is_valid():
				check.toggled.connect(changed_callback)
			input = check
		"enum":
			var option: OptionButton = OptionButton.new()
			var options: Variant = parameter.get("options", [])
			if options is Array or options is PackedStringArray:
				for option_index: int in options.size():
					option.add_item(str(options[option_index]), option_index)
			option.select(clampi(int(initial_value), 0, maxi(option.item_count - 1, 0)))
			if changed_callback.is_valid():
				option.item_selected.connect(changed_callback)
			input = option
		"string":
			var edit: LineEdit = LineEdit.new()
			edit.text = str(initial_value)
			if changed_callback.is_valid():
				edit.text_changed.connect(changed_callback)
			input = edit
		_:
			return null
	input.tooltip_text = str(parameter.get("tooltip", ""))
	return input


func _wrap_extension_parameter(parameter: Dictionary, input: Control) -> Control:
	var label_text: String = str(parameter.get("label", parameter.get("id", "Parameter")))
	if input is CheckBox:
		(input as CheckBox).text = label_text
		return input
	return _labelled_control(label_text, input)


func _read_extension_parameters(schema_value: Variant, controls: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if not schema_value is Array:
		return result
	for value: Variant in schema_value:
		if not value is Dictionary:
			continue
		var parameter: Dictionary = value
		var parameter_id: String = str(parameter.get("id", ""))
		var input: Control = controls.get(parameter_id) as Control
		if input == null:
			result[parameter_id] = parameter.get("default", 0.0)
			continue
		match str(parameter.get("type", "float")).to_lower():
			"int":
				result[parameter_id] = int(round((input as SpinBox).value))
			"float":
				result[parameter_id] = float((input as SpinBox).value)
			"bool":
				result[parameter_id] = (input as CheckBox).button_pressed
			"enum":
				result[parameter_id] = (input as OptionButton).get_selected_id()
			"string":
				result[parameter_id] = (input as LineEdit).text
			_:
				result[parameter_id] = parameter.get("default", 0.0)
	return result


func _set_extension_parameter_enabled(input: Control, enabled: bool) -> void:
	if input is SpinBox:
		(input as SpinBox).editable = enabled
	elif input is CheckBox:
		(input as CheckBox).disabled = not enabled
	elif input is OptionButton:
		(input as OptionButton).disabled = not enabled
	elif input is LineEdit:
		(input as LineEdit).editable = enabled


func _add_toolbar_button(
	parent: Control,
	text: String,
	callback: Callable,
	tooltip: String
) -> Button:
	var button: Button = _make_button(text, callback)
	button.tooltip_text = tooltip
	parent.add_child(button)
	return button


func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _labelled_control(label_text: String, control: Control) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92.0
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _make_vector_editor(
	parent: Control,
	label_text: String,
	minimum: float,
	maximum: float,
	step: float
) -> Array[SpinBox]:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var result: Array[SpinBox] = []
	for axis: String in ["X", "Y", "Z"]:
		var axis_label: Label = Label.new()
		axis_label.text = axis
		row.add_child(axis_label)
		var spin: SpinBox = _make_spin_box(minimum, maximum, step)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spin)
		result.append(spin)
	return result


func _make_spin_box(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	return spin


func _set_vector_editor_enabled(fields: Array[SpinBox], is_enabled: bool) -> void:
	for field: SpinBox in fields:
		field.editable = is_enabled


func _set_vector_fields(fields: Array[SpinBox], value: Vector3) -> void:
	if fields.size() < 3:
		return
	fields[0].value = value.x
	fields[1].value = value.y
	fields[2].value = value.z


func _get_vector_fields(fields: Array[SpinBox]) -> Vector3:
	if fields.size() < 3:
		return Vector3.ZERO
	return Vector3(fields[0].value, fields[1].value, fields[2].value)
