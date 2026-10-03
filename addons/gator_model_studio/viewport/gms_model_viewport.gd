@tool
class_name GMSModelViewport
extends SubViewportContainer

const VIEW_ORIENTATION_GIZMO_SCRIPT: Script = preload("res://addons/gator_model_studio/viewport/gms_view_orientation_gizmo.gd")
const RIG_OVERLAY_SCRIPT: Script = preload("res://addons/gator_model_studio/viewport/gms_rig_overlay.gd")

signal selection_clicked(object_id: String, component_index: int, additive: bool, edge_pattern: int)
signal box_selection_requested(
	object_id: String,
	component_indices: PackedInt32Array,
	operation: int
)
signal box_object_selection_requested(object_ids: PackedStringArray, operation: int)
signal shortcut_requested(action: String)
signal transform_preview(kind: int, value: Vector3, axis: Vector3, pivot_world: Vector3)
signal transform_committed
signal transform_cancelled
signal transform_status_changed(text: String)
signal snap_toggled(enabled: bool)
signal gizmo_transform_requested(kind: int, axis: Vector3, mouse_position: Vector2)
signal knife_cut_requested(
	object_id: String,
	face_index: int,
	start_local: Vector3,
	end_local: Vector3
)
signal remesh_guide_stroke_completed(object_id: String, local_points: PackedVector3Array)
signal remesh_guide_drawing_cancelled
signal xray_toggled(enabled: bool)
signal scalar_adjust_preview(value: float)
signal scalar_adjust_committed
signal scalar_adjust_cancelled
signal async_evaluation_completed(object_id: String)
signal rig_bone_clicked(bone_index: int)
signal rig_bone_endpoint_dragged(
	object_id: String,
	bone_index: int,
	move_tail: bool,
	local_position: Vector3,
	phase: int
)
signal rig_weight_brush_requested(object_id: String, local_point: Vector3, radius: float, strength: float, mode: int)
signal animation_bone_transform_preview(kind: int, value: Vector3, axis: Vector3, pivot_world: Vector3)
signal animation_bone_transform_committed
signal animation_bone_transform_cancelled
signal animation_ik_target_transform_preview(world_delta: Vector3)
signal animation_ik_target_transform_committed
signal animation_ik_target_transform_cancelled
signal animation_ik_control_selected(control: int)

enum TransformKind {
	NONE,
	MOVE,
	ROTATE,
	SCALE,
}

enum EdgeSelectionPattern {
	SINGLE,
	LOOP,
	RING,
}

enum SnapElement {
	INCREMENT,
	VERTEX,
}

enum PivotMode {
	MEDIAN,
	ACTIVE,
	OBJECT_ORIGIN,
	INDIVIDUAL_ORIGINS,
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


enum AnimationIKControl {
	NONE,
	TARGET,
	POLE,
}

const VERTEX_PICK_RADIUS: float = 12.0
const EDGE_PICK_RADIUS: float = 9.0
const SNAP_VERTEX_RADIUS: float = 28.0
const PICK_GRID_CELL_SIZE: float = 32.0
const LARGE_MESH_VERTEX_THRESHOLD: int = 10000
const FULL_VERTEX_MARKER_THRESHOLD: int = 5000
const MAX_WIRE_OVERLAY_EDGES: int = 120000
const MAX_RIG_WEIGHT_OVERLAY_POINTS: int = 1800
const RIG_BRUSH_EDGE_SNAP_PIXELS: float = 14.0
const RIG_BRUSH_EDGE_SNAP_MESH_RATIO: float = 0.01
const LARGE_MESH_EDGE_THRESHOLD: int = 400000
const DENSE_LOCAL_PICK_VERTEX_THRESHOLD: int = 12000
const DENSE_SPATIAL_INDEX_FACE_THRESHOLD: int = 20000
const DYNAMIC_TRANSFORM_VERTEX_THRESHOLD: int = 2000
const POSITION_REBUILD_DELAY_MSEC: int = 4000

var document: GMSDocument
var selected_object_id: String = ""
var selected_object_ids: PackedStringArray = PackedStringArray()
var selection_mode: int = GMSSelection.Mode.OBJECT
var selected_vertex_indices: PackedInt32Array = PackedInt32Array()
var selected_edge_indices: PackedInt32Array = PackedInt32Array()
var selected_face_indices: PackedInt32Array = PackedInt32Array()

var snap_enabled: bool = false
var snap_element: int = SnapElement.INCREMENT
var snap_base: int = GMSSnapMath.BaseMode.CLOSEST
var move_increment: float = 1.0
var rotate_increment_degrees: float = 5.0
var scale_increment: float = 0.1
var gizmo_mode: int = TransformKind.MOVE
var gizmo_orientation: int = GMSTransformGizmo.Orientation.GLOBAL
var gizmo_visible: bool = true
var pivot_mode: int = PivotMode.MEDIAN
var xray_enabled: bool = false
var workspace_mode: int = WorkspaceMode.MODEL
var rig_submode: int = RigSubmode.EDIT
var selected_bone_index: int = -1
var rig_brush_radius: float = 0.01
var rig_brush_strength: float = 0.5
var rig_brush_mode: int = GMSRigData.BrushMode.ADD
var rig_vertex_select: bool = false
var _rig_weight_cache_object_id: String = ""
var _rig_weight_cache_bone_index: int = -1
var _rig_weight_cache_vertex_count: int = -1
var _rig_weight_cache_points: PackedVector3Array = PackedVector3Array()
var _rig_weight_cache_values: PackedFloat32Array = PackedFloat32Array()

var _subviewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _mesh_nodes: Dictionary = {}
var _skeleton_nodes: Dictionary = {}
var _material_preview_overrides: Dictionary = {}
var _selection_overlay: StandardMaterial3D
var _edit_edge_cache: Dictionary = {}
var _wire_mesh_cache: Dictionary = {}
var _seam_mesh_cache: Dictionary = {}
var _vertex_multimesh_cache: Dictionary = {}
var _vertex_point_mesh_cache: Dictionary = {}
var _surface_vertex_map_cache: Dictionary = {}
var _spatial_index_cache: Dictionary = {}
var _spatial_index_tasks: Dictionary = {}
var _projection_cache: Dictionary = {}
var _visibility_depth_cache: Dictionary = {}
var _camera_revision: int = 0
var _overlay_suppressed: bool = false
var _overlay_restore_timer: Timer
var _evaluation_poll_timer: Timer
var _position_rebuild_deadlines: Dictionary = {}
var _position_mesh_tasks: Dictionary = {}
var _dynamic_preview_object_id: String = ""
var _dynamic_preview_array_mesh: ArrayMesh
var _dynamic_preview_vertex_count: int = 0
var _dynamic_preview_original_vertices: PackedVector3Array = PackedVector3Array()
var _dynamic_preview_work_vertices: PackedVector3Array = PackedVector3Array()
var _dynamic_preview_pending_indices: PackedInt32Array = PackedInt32Array()
var _dynamic_preview_pending_positions: PackedVector3Array = PackedVector3Array()
var _dynamic_preview_surface_maps: Array = []
var _dynamic_preview_flush_queued: bool = false

var _edit_overlay_root: Node3D
var _wire_overlay: MeshInstance3D
var _seam_edge_overlay: MeshInstance3D
var _selected_edge_overlay: MeshInstance3D
var _face_overlay: MeshInstance3D
var _vertex_markers: MultiMeshInstance3D
var _vertex_point_overlay: MeshInstance3D
var _selected_vertex_markers: MultiMeshInstance3D
var _wire_material: StandardMaterial3D
var _seam_edge_material: StandardMaterial3D
var _selected_edge_material: StandardMaterial3D
var _selected_face_material: StandardMaterial3D
var _vertex_material: StandardMaterial3D
var _vertex_point_material: StandardMaterial3D
var _selected_vertex_material: StandardMaterial3D
var _snap_marker: MeshInstance3D
var _remesh_guide_overlay: MeshInstance3D
var _remesh_guide_material: StandardMaterial3D
var _remesh_guide_object_id: String = ""
var _remesh_guides: Array[GMSRemeshGuide] = []
var _transform_gizmo: GMSTransformGizmo
var _view_orientation_gizmo: GMSViewOrientationGizmo
var _rig_overlay: GMSRigOverlay

var _camera_target: Vector3 = Vector3.ZERO
var _camera_yaw: float = deg_to_rad(38.0)
var _camera_pitch: float = deg_to_rad(24.0)
var _camera_distance: float = 8.0
var _orbiting: bool = false
var _panning: bool = false
var _zooming: bool = false
var _left_press_position: Vector2 = Vector2.ZERO
var _left_dragged: bool = false
var _last_pointer_position: Vector2 = Vector2.ZERO
var _box_select_active: bool = false
var _box_select_dragging: bool = false
var _box_select_start: Vector2 = Vector2.ZERO
var _box_select_panel: Panel

var _transform_kind: int = TransformKind.NONE
var _transform_axis: Vector3 = Vector3.ZERO
var _transform_custom_axis: Vector3 = Vector3.ZERO
var _transform_axis_key: Vector3 = Vector3.ZERO
var _transform_axis_is_local: bool = false
var _transform_start_mouse: Vector2 = Vector2.ZERO
var _transform_pivot_world: Vector3 = Vector3.ZERO
var _transform_source_points: PackedVector3Array = PackedVector3Array()
var _transform_active_source_index: int = -1
var _transform_active_point_world: Vector3 = Vector3.ZERO
var _transform_start_plane_point: Vector3 = Vector3.ZERO
var _transform_start_screen_distance: float = 1.0
var _transform_start_screen_angle: float = 0.0
var _transform_confirm_on_release: bool = false
var _animation_bone_transform: bool = false
var _animation_bone_object_id: String = ""
var _animation_bone_index: int = -1
var _animation_bone_basis: Basis = Basis.IDENTITY
var _animation_ik_target_transform: bool = false
var _animation_ik_target_object_id: String = ""
var _animation_guide_object_id: String = ""
var _animation_guide_chain_points: PackedVector3Array = PackedVector3Array()
var _animation_guide_target_position: Vector3 = Vector3.ZERO
var _animation_guide_pole_position: Vector3 = Vector3.ZERO
var _animation_guide_show_ik: bool = false
var _animation_ik_control: int = AnimationIKControl.NONE
var _animation_guide_root_path: PackedVector3Array = PackedVector3Array()
var _knife_active: bool = false
var _knife_first_hit: Dictionary = {}
var _remesh_guide_draw_active: bool = false
var _remesh_guide_stroking: bool = false
var _remesh_guide_draw_object_id: String = ""
var _remesh_guide_draw_points: PackedVector3Array = PackedVector3Array()
var _remesh_guide_last_screen_position: Vector2 = Vector2.ZERO
var _scalar_adjust_active: bool = false
var _scalar_adjust_start_mouse: Vector2 = Vector2.ZERO
var _scalar_adjust_initial: float = 0.0
var _scalar_adjust_minimum: float = 0.0
var _scalar_adjust_maximum: float = 1.0
var _scalar_adjust_sensitivity: float = 0.01
var _scalar_adjust_label: String = "Adjust"
var _scalar_adjust_value: float = 0.0
var _rig_weight_brushing: bool = false
var _rig_drag_bone_index: int = -1
var _rig_drag_tail: bool = false
var _rig_drag_plane: Plane = Plane(Vector3.FORWARD, 0.0)
var _rig_last_brush_screen: Vector2 = Vector2(INF, INF)
var _rig_last_brush_usec: int = 0
var _rig_brush_hit_screen: Vector2 = Vector2(INF, INF)
var _rig_brush_hit_cache: Dictionary = {}
var _rig_brush_last_world_distance: float = 0.0
var _rig_brush_has_last_hit: bool = false


func _ready() -> void:
	stretch = true
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_entered.connect(_restore_viewport_cursor)
	mouse_exited.connect(_clear_rig_brush_preview)
	custom_minimum_size = Vector2(280.0, 96.0)
	_build_viewport()
	_overlay_restore_timer = Timer.new()
	_overlay_restore_timer.one_shot = true
	_overlay_restore_timer.wait_time = 0.08
	_overlay_restore_timer.timeout.connect(_restore_interaction_overlays)
	add_child(_overlay_restore_timer)
	_evaluation_poll_timer = Timer.new()
	_evaluation_poll_timer.wait_time = 0.05
	_evaluation_poll_timer.timeout.connect(_poll_async_evaluations)
	add_child(_evaluation_poll_timer)
	_evaluation_poll_timer.start()
	_update_camera()


func _restore_viewport_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func prepare_remesh_guide_surface(object_id: String) -> bool:
	if document == null or object_id.is_empty():
		return false
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.locked or object.mesh_data == null:
		return false
	var mesh: GMSMeshData = object.get_evaluated_mesh_data()
	if mesh == null or mesh.faces.is_empty():
		return false
	var cached: GMSMeshSpatialIndex = _spatial_index_cache.get(object_id) as GMSMeshSpatialIndex
	if cached != null and cached.is_current(mesh):
		return true
	if mesh.faces.size() >= DENSE_SPATIAL_INDEX_FACE_THRESHOLD:
		_request_spatial_index_build(object_id, mesh)
		transform_status_changed.emit("Preparing the complete surface for guide drawing...")
		return false
	return _get_spatial_index(object_id, mesh) != null


func begin_remesh_guide_draw(object_id: String) -> bool:
	if document == null or object_id.is_empty():
		return false
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.locked or object.mesh_data == null:
		return false
	cancel_box_select()
	cancel_knife()
	if is_transforming():
		cancel_transform()
	_remesh_guide_draw_active = true
	_remesh_guide_stroking = false
	_remesh_guide_draw_object_id = object_id
	_remesh_guide_draw_points.clear()
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	transform_status_changed.emit("Remesh guide: drag across the selected surface. Right-click or Esc cancels.")
	_refresh_remesh_guide_overlay()
	return true


func cancel_remesh_guide_draw(emit_cancelled: bool = true) -> void:
	if not _remesh_guide_draw_active and not _remesh_guide_stroking:
		return
	_remesh_guide_draw_active = false
	_remesh_guide_stroking = false
	_remesh_guide_draw_object_id = ""
	_remesh_guide_draw_points.clear()
	_restore_viewport_cursor()
	_refresh_remesh_guide_overlay()
	transform_status_changed.emit("")
	if emit_cancelled:
		remesh_guide_drawing_cancelled.emit()


func set_remesh_guides(object_id: String, guides: Array[GMSRemeshGuide]) -> void:
	_remesh_guide_object_id = object_id
	_remesh_guides.clear()
	for guide: GMSRemeshGuide in guides:
		if guide != null and guide.is_valid():
			_remesh_guides.append(guide.duplicate_guide())
	_refresh_remesh_guide_overlay()


func clear_remesh_guides() -> void:
	_remesh_guide_object_id = ""
	_remesh_guides.clear()
	_refresh_remesh_guide_overlay()


func set_document(new_document: GMSDocument) -> void:
	_finish_document_async_tasks()
	_disconnect_document()
	_invalidate_rig_weight_overlay_cache()
	document = new_document
	_connect_document()
	_rebuild_objects()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func can_use_dynamic_vertex_preview(
	object_id: String,
	source_mesh: GMSMeshData
) -> bool:
	if source_mesh == null or source_mesh.vertices.size() < DYNAMIC_TRANSFORM_VERTEX_THRESHOLD:
		return false
	var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
	var array_mesh: ArrayMesh
	if mesh_node != null:
		array_mesh = mesh_node.mesh as ArrayMesh
	if array_mesh == null or array_mesh.get_surface_count() <= 0:
		return false
	var surface_maps: Array = _get_surface_vertex_maps(
		object_id, source_mesh, array_mesh.get_surface_count()
	)
	if surface_maps.size() != array_mesh.get_surface_count():
		return false
	for surface_index: int in array_mesh.get_surface_count():
		var surface_map: Dictionary = surface_maps[surface_index]
		if int(surface_map.get("render_vertex_count", -1)) != array_mesh.surface_get_array_len(surface_index):
			return false
	return true


func begin_dynamic_vertex_preview(
	object_id: String,
	source_mesh: GMSMeshData,
	source_bounds: AABB
) -> bool:
	if not can_use_dynamic_vertex_preview(object_id, source_mesh):
		return false
	var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
	_dynamic_preview_object_id = object_id
	_dynamic_preview_array_mesh = mesh_node.mesh as ArrayMesh
	_dynamic_preview_vertex_count = source_mesh.vertices.size()
	_dynamic_preview_original_vertices = source_mesh.vertices.duplicate()
	_dynamic_preview_work_vertices = source_mesh.vertices.duplicate()
	_dynamic_preview_surface_maps = _get_surface_vertex_maps(
		object_id, source_mesh, _dynamic_preview_array_mesh.get_surface_count()
	).duplicate(true)
	_dynamic_preview_array_mesh.set_meta(
		"_gms_surface_vertex_maps", _dynamic_preview_surface_maps
	)
	_dynamic_preview_pending_indices = PackedInt32Array()
	_dynamic_preview_pending_positions = PackedVector3Array()
	_dynamic_preview_flush_queued = false
	_position_rebuild_deadlines.erase(object_id)
	var margin: float = maxf(source_bounds.size.length() * 4.0, 1.0)
	_dynamic_preview_array_mesh.custom_aabb = source_bounds.grow(margin)
	return true


func update_dynamic_vertex_preview(
	vertex_indices: PackedInt32Array,
	positions: PackedVector3Array
) -> bool:
	if (
		_dynamic_preview_array_mesh == null
		or vertex_indices.is_empty()
		or vertex_indices.size() != positions.size()
	):
		return false
	_dynamic_preview_pending_indices = vertex_indices.duplicate()
	_dynamic_preview_pending_positions = positions.duplicate()
	if not _dynamic_preview_flush_queued:
		_dynamic_preview_flush_queued = true
		call_deferred("_flush_dynamic_vertex_preview")
	return true


func _flush_dynamic_vertex_preview() -> void:
	_dynamic_preview_flush_queued = false
	if (
		_dynamic_preview_array_mesh == null
		or _dynamic_preview_pending_indices.is_empty()
		or _dynamic_preview_pending_indices.size() != _dynamic_preview_pending_positions.size()
	):
		return
	var vertex_indices: PackedInt32Array = _dynamic_preview_pending_indices
	var positions: PackedVector3Array = _dynamic_preview_pending_positions
	for index: int in vertex_indices.size():
		var vertex_index: int = vertex_indices[index]
		if vertex_index >= 0 and vertex_index < _dynamic_preview_work_vertices.size():
			_dynamic_preview_work_vertices[vertex_index] = positions[index]
	GMSMeshData.update_array_mesh_vertex_positions_mapped(
		_dynamic_preview_array_mesh,
		_dynamic_preview_work_vertices,
		vertex_indices,
		_dynamic_preview_surface_maps
	)


func _update_array_mesh_positions(
	array_mesh: ArrayMesh,
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> bool:
	if mesh == null:
		return false
	return mesh.update_array_mesh_vertex_positions(array_mesh, vertex_indices)


func finish_dynamic_vertex_preview(keep_positions: bool = true) -> ArrayMesh:
	if keep_positions:
		_flush_dynamic_vertex_preview()
	else:
		_dynamic_preview_pending_indices = PackedInt32Array()
		_dynamic_preview_pending_positions = PackedVector3Array()
	var result: ArrayMesh = _dynamic_preview_array_mesh if keep_positions else null
	if not keep_positions and _dynamic_preview_array_mesh != null:
		GMSMeshData.update_array_mesh_all_vertex_positions_mapped(
			_dynamic_preview_array_mesh,
			_dynamic_preview_original_vertices,
			_dynamic_preview_surface_maps
		)
		_dynamic_preview_array_mesh.custom_aabb = AABB()
	_dynamic_preview_object_id = ""
	_dynamic_preview_array_mesh = null
	_dynamic_preview_vertex_count = 0
	_dynamic_preview_original_vertices = PackedVector3Array()
	_dynamic_preview_work_vertices = PackedVector3Array()
	_dynamic_preview_pending_indices = PackedInt32Array()
	_dynamic_preview_pending_positions = PackedVector3Array()
	_dynamic_preview_surface_maps = []
	_dynamic_preview_flush_queued = false
	return result


func queue_position_mesh_rebuild(object_id: String) -> void:
	_position_rebuild_deadlines[object_id] = Time.get_ticks_msec() + POSITION_REBUILD_DELAY_MSEC


func _exit_tree() -> void:
	_finish_document_async_tasks()


func _finish_document_async_tasks() -> void:
	if document != null:
		for object: GMSModelObject in document.objects:
			if object != null:
				object.finish_async_evaluation()
	for task_value: Variant in _spatial_index_tasks.values():
		var task: Dictionary = task_value
		var task_id: int = int(task.get("task_id", -1))
		if task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(task_id)
	_spatial_index_tasks.clear()
	for task_value: Variant in _position_mesh_tasks.values():
		var task: Dictionary = task_value
		var task_id: int = int(task.get("task_id", -1))
		if task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(task_id)
	_position_mesh_tasks.clear()


func set_material_preview_override(object_id: String, material: StandardMaterial3D) -> void:
	if object_id.is_empty():
		return
	if material == null:
		_material_preview_overrides.erase(object_id)
	else:
		_material_preview_overrides[object_id] = material
	_update_object_node(object_id, 0)


func clear_material_preview_override(object_id: String) -> void:
	if object_id.is_empty():
		return
	_material_preview_overrides.erase(object_id)
	_update_object_node(object_id, 0)


func restore_selection_overlay() -> void:
	if _overlay_restore_timer != null:
		_overlay_restore_timer.stop()
	_restore_interaction_overlays()
	_refresh_transform_gizmo()


func set_selection_state(
	new_mode: int,
	object_ids: PackedStringArray,
	vertex_indices: PackedInt32Array,
	edge_indices: PackedInt32Array,
	face_indices: PackedInt32Array
) -> void:
	selection_mode = new_mode
	selected_object_ids = object_ids.duplicate()
	selected_object_id = (
		""
		if selected_object_ids.is_empty()
		else selected_object_ids[selected_object_ids.size() - 1]
	)
	selected_vertex_indices = vertex_indices.duplicate()
	selected_edge_indices = edge_indices.duplicate()
	selected_face_indices = face_indices.duplicate()
	_refresh_all_attachment_previews()
	_update_selection_materials()
	_refresh_edit_overlay()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func set_rig_state(
	enabled: bool,
	new_submode: int,
	new_selected_bone: int,
	brush_radius: float,
	brush_strength: float,
	brush_mode: int,
	vertex_select: bool = false
) -> void:
	var resolved_workspace_mode: int = WorkspaceMode.RIG if enabled else WorkspaceMode.MODEL
	var resolved_submode: int = clampi(new_submode, RigSubmode.EDIT, RigSubmode.POSE)
	var visual_state_changed: bool = (
		workspace_mode != resolved_workspace_mode
		or rig_submode != resolved_submode
		or selected_bone_index != new_selected_bone
		or rig_vertex_select != vertex_select
	)
	workspace_mode = resolved_workspace_mode
	rig_submode = resolved_submode
	selected_bone_index = new_selected_bone
	rig_brush_radius = maxf(brush_radius, 0.0001)
	rig_brush_strength = clampf(brush_strength, 0.0, 1.0)
	rig_brush_mode = clampi(brush_mode, GMSRigData.BrushMode.ADD, GMSRigData.BrushMode.SMOOTH)
	rig_vertex_select = vertex_select
	if visual_state_changed:
		_reset_rig_brush_hit_cache()
	if not visual_state_changed:
		return
	_refresh_edit_overlay()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func set_animation_state(enabled: bool, new_selected_bone: int) -> void:
	var resolved_workspace_mode: int = WorkspaceMode.ANIMATE if enabled else WorkspaceMode.MODEL
	var visual_state_changed: bool = (
		workspace_mode != resolved_workspace_mode
		or selected_bone_index != new_selected_bone
	)
	workspace_mode = resolved_workspace_mode
	rig_submode = RigSubmode.POSE
	selected_bone_index = new_selected_bone
	rig_vertex_select = false
	if not visual_state_changed:
		return
	_refresh_edit_overlay()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func set_snap_settings(
	is_enabled: bool,
	element: int,
	base_mode: int,
	translation_increment: float,
	rotation_increment: float,
	resize_increment: float
) -> void:
	snap_enabled = is_enabled
	snap_element = element
	snap_base = base_mode
	move_increment = maxf(translation_increment, 0.0001)
	rotate_increment_degrees = maxf(rotation_increment, 0.0001)
	scale_increment = maxf(resize_increment, 0.0001)


func set_gizmo_settings(new_mode: int, new_orientation: int, is_visible: bool) -> void:
	gizmo_mode = new_mode
	gizmo_orientation = new_orientation
	gizmo_visible = is_visible
	if _transform_gizmo != null:
		_transform_gizmo.set_mode(gizmo_mode)
		_transform_gizmo.set_orientation(gizmo_orientation)
	_refresh_transform_gizmo()


func set_pivot_mode(new_mode: int) -> void:
	pivot_mode = clampi(new_mode, PivotMode.MEDIAN, PivotMode.INDIVIDUAL_ORIGINS)
	_refresh_transform_gizmo()


func set_xray_enabled(enabled: bool) -> void:
	xray_enabled = enabled
	_refresh_edit_overlay()


func begin_knife() -> bool:
	if is_transforming() or _box_select_active or document == null:
		return false
	if selection_mode != GMSSelection.Mode.FACE or selected_object_id.is_empty():
		return false
	_knife_active = true
	_knife_first_hit.clear()
	grab_focus()
	transform_status_changed.emit(
		"Knife | Click two boundary points on one face | RMB/Esc cancels"
	)
	return true


func cancel_knife() -> void:
	if not _knife_active:
		return
	_knife_active = false
	_knife_first_hit.clear()
	transform_status_changed.emit("")


func is_scalar_adjusting() -> bool:
	return _scalar_adjust_active


func begin_scalar_adjust(
	initial_value: float,
	minimum_value: float,
	maximum_value: float,
	sensitivity: float,
	label: String
) -> bool:
	if (
		_scalar_adjust_active
		or is_transforming()
		or _box_select_active
		or _knife_active
		or document == null
	):
		return false
	_scalar_adjust_active = true
	_scalar_adjust_start_mouse = get_local_mouse_position()
	_scalar_adjust_initial = initial_value
	_scalar_adjust_minimum = minimum_value
	_scalar_adjust_maximum = maximum_value
	_scalar_adjust_sensitivity = maxf(sensitivity, 0.000001)
	_scalar_adjust_label = label
	_scalar_adjust_value = clampf(initial_value, minimum_value, maximum_value)
	grab_focus()
	scalar_adjust_preview.emit(_scalar_adjust_value)
	_emit_scalar_adjust_status()
	return true


func cancel_scalar_adjust() -> void:
	if not _scalar_adjust_active:
		return
	_scalar_adjust_active = false
	transform_status_changed.emit("")
	scalar_adjust_cancelled.emit()


func _finish_scalar_adjust() -> void:
	if not _scalar_adjust_active:
		return
	_scalar_adjust_active = false
	transform_status_changed.emit("")
	scalar_adjust_committed.emit()


func _emit_scalar_adjust_status() -> void:
	transform_status_changed.emit(
		"%s: %.4f | Move mouse to adjust | LMB/Enter confirm | RMB/Esc cancel | Shift precision"
		% [_scalar_adjust_label, _scalar_adjust_value]
	)


func is_transforming() -> bool:
	return _transform_kind != TransformKind.NONE


func begin_box_select() -> bool:
	if is_transforming() or _scalar_adjust_active or _box_select_active:
		return false
	_box_select_active = true
	_box_select_dragging = false
	_box_select_panel.visible = false
	grab_focus()
	transform_status_changed.emit(
		"Box Select%s | Drag LMB | Shift add | Ctrl subtract | RMB/Esc cancel" % (
			" (through)" if xray_enabled else " (visible only)"
		)
	)
	return true


func cancel_box_select() -> void:
	if not _box_select_active:
		return
	_box_select_active = false
	_box_select_dragging = false
	_box_select_panel.visible = false
	transform_status_changed.emit("")


func begin_transform(
	kind: int,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false,
	source_points_override: PackedVector3Array = PackedVector3Array(),
	object_id_override: String = ""
) -> bool:
	if document == null:
		return false
	if _scalar_adjust_active:
		cancel_scalar_adjust()
	if _box_select_active:
		cancel_box_select()
	if is_transforming():
		_clear_transform_state()
	if not object_id_override.is_empty():
		selected_object_id = object_id_override

	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.locked:
		return false

	_transform_source_points = (
		source_points_override.duplicate()
		if not source_points_override.is_empty()
		else _get_transform_source_points(object)
	)
	if _transform_source_points.is_empty():
		return false

	_animation_bone_transform = false
	_animation_bone_object_id = ""
	_animation_bone_index = -1
	_animation_bone_basis = Basis.IDENTITY
	_animation_ik_target_transform = false
	_animation_ik_target_object_id = ""
	_transform_kind = kind
	_transform_custom_axis = custom_axis.normalized() if not custom_axis.is_zero_approx() else Vector3.ZERO
	_transform_axis = _transform_custom_axis
	_transform_axis_key = Vector3.ZERO
	_transform_axis_is_local = false
	_transform_pivot_world = _get_transform_pivot(object)
	_transform_active_source_index = _get_active_source_index(object)
	_transform_active_point_world = _calculate_active_snap_point(object)
	_transform_start_mouse = start_mouse_position if start_mouse_position.x >= 0.0 else get_local_mouse_position()
	_transform_confirm_on_release = confirm_on_release
	_transform_start_plane_point = _ray_plane_intersection(
		_transform_start_mouse,
		_transform_pivot_world,
		_get_move_plane_normal()
	)

	var pivot_screen: Vector2 = _camera.unproject_position(_transform_pivot_world)
	var start_vector: Vector2 = _transform_start_mouse - pivot_screen
	_transform_start_screen_distance = maxf(start_vector.length(), 1.0)
	_transform_start_screen_angle = atan2(start_vector.y, start_vector.x)
	if object.mesh_data != null and object.mesh_data.vertices.size() >= LARGE_MESH_VERTEX_THRESHOLD:
		_suppress_interaction_overlays()
	_update_transform(_transform_start_mouse, false, false)
	_emit_transform_status(false)
	return true


func begin_animation_bone_transform(
	kind: int,
	object_id: String,
	bone_index: int,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false
) -> bool:
	if document == null or workspace_mode != WorkspaceMode.ANIMATE:
		return false
	var object: GMSModelObject = document.get_object(object_id)
	var skeleton: Skeleton3D = _skeleton_nodes.get(object_id) as Skeleton3D
	if (
		object == null
		or object.locked
		or object.rig_data == null
		or skeleton == null
		or bone_index < 0
		or bone_index >= skeleton.get_bone_count()
	):
		return false
	if _scalar_adjust_active:
		cancel_scalar_adjust()
	if _box_select_active:
		cancel_box_select()
	if is_transforming():
		_clear_transform_state()
	selected_object_id = object_id
	selected_bone_index = bone_index
	var bone_global: Transform3D = skeleton.get_bone_global_pose(bone_index)
	var bone_world: Transform3D = skeleton.global_transform * bone_global
	_animation_bone_transform = true
	_animation_bone_object_id = object_id
	_animation_bone_index = bone_index
	_animation_bone_basis = bone_world.basis.orthonormalized()
	_transform_source_points = PackedVector3Array([bone_world.origin])
	_transform_kind = kind
	_transform_custom_axis = custom_axis.normalized() if not custom_axis.is_zero_approx() else Vector3.ZERO
	_transform_axis = _transform_custom_axis
	_transform_axis_key = Vector3.ZERO
	_transform_axis_is_local = false
	_transform_pivot_world = bone_world.origin
	_transform_active_source_index = 0
	_transform_active_point_world = bone_world.origin
	_transform_start_mouse = start_mouse_position if start_mouse_position.x >= 0.0 else get_local_mouse_position()
	_transform_confirm_on_release = confirm_on_release
	_transform_start_plane_point = _ray_plane_intersection(
		_transform_start_mouse,
		_transform_pivot_world,
		_get_move_plane_normal()
	)
	var pivot_screen: Vector2 = _camera.unproject_position(_transform_pivot_world)
	var start_vector: Vector2 = _transform_start_mouse - pivot_screen
	_transform_start_screen_distance = maxf(start_vector.length(), 1.0)
	_transform_start_screen_angle = atan2(start_vector.y, start_vector.x)
	_update_transform(_transform_start_mouse, false, false)
	_emit_transform_status(false)
	return true


func begin_animation_ik_target_transform(
	object_id: String,
	target_local_position: Vector3,
	custom_axis: Vector3 = Vector3.ZERO,
	start_mouse_position: Vector2 = Vector2(-1.0, -1.0),
	confirm_on_release: bool = false
) -> bool:
	if document == null or workspace_mode != WorkspaceMode.ANIMATE:
		return false
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.locked or object.rig_data == null:
		return false
	if _scalar_adjust_active:
		cancel_scalar_adjust()
	if _box_select_active:
		cancel_box_select()
	if is_transforming():
		_clear_transform_state()
	selected_object_id = object_id
	var target_world: Vector3 = object.transform * target_local_position
	_animation_bone_transform = false
	_animation_bone_object_id = ""
	_animation_bone_index = -1
	_animation_bone_basis = Basis.IDENTITY
	_animation_ik_target_transform = true
	_animation_ik_target_object_id = object_id
	_transform_source_points = PackedVector3Array([target_world])
	_transform_kind = TransformKind.MOVE
	_transform_custom_axis = custom_axis.normalized() if not custom_axis.is_zero_approx() else Vector3.ZERO
	_transform_axis = _transform_custom_axis
	_transform_axis_key = Vector3.ZERO
	_transform_axis_is_local = false
	_transform_pivot_world = target_world
	_transform_active_source_index = 0
	_transform_active_point_world = target_world
	_transform_start_mouse = start_mouse_position if start_mouse_position.x >= 0.0 else get_local_mouse_position()
	_transform_confirm_on_release = confirm_on_release
	_transform_start_plane_point = _ray_plane_intersection(
		_transform_start_mouse,
		_transform_pivot_world,
		_get_move_plane_normal()
	)
	var pivot_screen: Vector2 = _camera.unproject_position(_transform_pivot_world)
	var start_vector: Vector2 = _transform_start_mouse - pivot_screen
	_transform_start_screen_distance = maxf(start_vector.length(), 1.0)
	_transform_start_screen_angle = atan2(start_vector.y, start_vector.x)
	_update_transform(_transform_start_mouse, false, false)
	_emit_transform_status(false)
	return true


func set_animation_authoring_guides(
	object_id: String,
	chain_points: PackedVector3Array,
	target_position: Vector3,
	pole_position: Vector3,
	show_ik: bool,
	root_motion_path: PackedVector3Array
) -> void:
	_animation_guide_object_id = object_id
	_animation_guide_chain_points = chain_points.duplicate()
	_animation_guide_target_position = target_position
	_animation_guide_pole_position = pole_position
	_animation_guide_show_ik = show_ik
	if not show_ik:
		_animation_ik_control = AnimationIKControl.NONE
	_animation_guide_root_path = root_motion_path.duplicate()
	_refresh_rig_overlay()
	_refresh_transform_gizmo()


func clear_animation_authoring_guides() -> void:
	_animation_guide_object_id = ""
	_animation_guide_chain_points.clear()
	_animation_guide_target_position = Vector3.ZERO
	_animation_guide_pole_position = Vector3.ZERO
	_animation_guide_show_ik = false
	_animation_ik_control = AnimationIKControl.NONE
	_animation_guide_root_path.clear()
	if _rig_overlay != null:
		_rig_overlay.clear_animation_guides()
	_refresh_transform_gizmo()


func set_animation_ik_control(control: int) -> void:
	var resolved_control: int = clampi(control, AnimationIKControl.NONE, AnimationIKControl.POLE)
	if not _animation_guide_show_ik:
		resolved_control = AnimationIKControl.NONE
	_animation_ik_control = resolved_control
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func get_animation_ik_control() -> int:
	return _animation_ik_control


func _pick_animation_ik_control(screen_position: Vector2) -> int:
	if (
		workspace_mode != WorkspaceMode.ANIMATE
		or not _animation_guide_show_ik
		or document == null
		or _camera == null
		or _animation_guide_object_id != selected_object_id
	):
		return AnimationIKControl.NONE
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null:
		return AnimationIKControl.NONE
	var target_world: Vector3 = object.transform * _animation_guide_target_position
	var pole_world: Vector3 = object.transform * _animation_guide_pole_position
	var best_control: int = AnimationIKControl.NONE
	var best_distance_squared: float = 18.0 * 18.0
	if not _camera.is_position_behind(target_world):
		var target_distance_squared: float = screen_position.distance_squared_to(
			_camera.unproject_position(target_world)
		)
		if target_distance_squared <= best_distance_squared:
			best_distance_squared = target_distance_squared
			best_control = AnimationIKControl.TARGET
	if not _camera.is_position_behind(pole_world):
		var pole_distance_squared: float = screen_position.distance_squared_to(
			_camera.unproject_position(pole_world)
		)
		if pole_distance_squared <= best_distance_squared:
			best_control = AnimationIKControl.POLE
	return best_control


func cancel_transform() -> void:
	if not is_transforming():
		return
	var was_animation_bone_transform: bool = _animation_bone_transform
	var was_animation_ik_transform: bool = _animation_ik_target_transform
	_clear_transform_state()
	if was_animation_bone_transform:
		animation_bone_transform_cancelled.emit()
	elif was_animation_ik_transform:
		animation_ik_target_transform_cancelled.emit()
	else:
		transform_cancelled.emit()


func frame_all() -> void:
	if document == null:
		return
	var points: PackedVector3Array = PackedVector3Array()
	for object: GMSModelObject in document.objects:
		if object == null or not object.visible:
			continue
		var display_mesh: GMSMeshData = object.get_evaluated_mesh_data()
		if display_mesh == null or display_mesh.vertices.is_empty():
			points.append(object.transform.origin)
			continue
		for vertex: Vector3 in display_mesh.vertices:
			points.append(object.transform * vertex)
	if points.is_empty():
		_camera_target = Vector3.ZERO
		_camera_distance = 8.0
		_update_camera()
		return

	var bounds: AABB = AABB(points[0], Vector3.ZERO)
	for point_index: int in range(1, points.size()):
		bounds = bounds.expand(points[point_index])
	_camera_target = bounds.get_center()
	_camera_distance = maxf(2.0, bounds.size.length() * 1.75)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = maxf(2.0, bounds.size.length() * 1.35)
	_update_camera()


func frame_selected() -> void:
	var object: GMSModelObject = null
	if document != null:
		object = document.get_object(selected_object_id)
	if object == null or object.mesh_data == null:
		_camera_target = Vector3.ZERO
		_camera_distance = 8.0
		_update_camera()
		return

	var points: PackedVector3Array = PackedVector3Array()
	if selection_mode == GMSSelection.Mode.OBJECT:
		var display_mesh: GMSMeshData = object.get_evaluated_mesh_data()
		if display_mesh != null:
			for vertex: Vector3 in display_mesh.vertices:
				points.append(object.transform * vertex)
	else:
		var indices: PackedInt32Array = GMSMeshOperations.get_selected_vertex_indices(
			object.mesh_data,
			selection_mode,
			selected_vertex_indices,
			selected_edge_indices,
			selected_face_indices
		)
		for vertex_index: int in indices:
			points.append(object.transform * object.mesh_data.vertices[vertex_index])

	if points.is_empty():
		points.append(object.transform.origin)

	var bounds: AABB = AABB(points[0], Vector3.ZERO)
	for point_index: int in range(1, points.size()):
		bounds = bounds.expand(points[point_index])
	_camera_target = bounds.get_center()
	_camera_distance = maxf(2.0, bounds.size.length() * 1.75)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = maxf(2.0, bounds.size.length() * 1.35)
	_update_camera()


func _build_viewport() -> void:
	_subviewport = SubViewport.new()
	_subviewport.name = "ModelViewport"
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.world_3d = World3D.new()
	add_child(_subviewport)

	_world_root = Node3D.new()
	_world_root.name = "World"
	_subviewport.add_child(_world_root)

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.075, 0.082, 0.095)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.84)
	environment.ambient_light_energy = 0.58
	environment_node.environment = environment
	_world_root.add_child(environment_node)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	key_light.light_energy = 1.15
	key_light.shadow_enabled = true
	_world_root.add_child(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(35.0, 145.0, 0.0)
	fill_light.light_energy = 0.32
	fill_light.light_color = Color(0.55, 0.66, 0.9)
	_world_root.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.near = 0.05
	_camera.far = 5000.0
	_world_root.add_child(_camera)

	_build_view_orientation_gizmo()
	_build_rig_overlay()

	_world_root.add_child(_create_grid())
	_world_root.add_child(_create_axis_lines())

	_selection_overlay = _make_unshaded_material(
		Color(0.16, 0.62, 1.0, 0.18),
		true,
		BaseMaterial3D.CULL_BACK
	)
	_wire_material = _make_unshaded_material(Color(0.62, 0.72, 0.86, 0.82), true)
	_seam_edge_material = _make_unshaded_material(Color(1.0, 0.16, 0.18), false)
	_selected_edge_material = _make_unshaded_material(Color(1.0, 0.56, 0.12), false)
	_selected_face_material = _make_unshaded_material(Color(1.0, 0.48, 0.08, 0.44), true)
	_vertex_material = _make_unshaded_material(Color(0.74, 0.82, 0.94), false)
	_vertex_point_material = _make_unshaded_material(Color(0.74, 0.82, 0.94), false)
	_selected_vertex_material = _make_unshaded_material(Color(1.0, 0.48, 0.08), false)
	_vertex_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_vertex_point_material.use_point_size = true
	_vertex_point_material.point_size = 4.0
	_selected_vertex_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	_edit_overlay_root = Node3D.new()
	_edit_overlay_root.name = "EditOverlay"
	_world_root.add_child(_edit_overlay_root)

	_wire_overlay = MeshInstance3D.new()
	_wire_overlay.name = "TopologyEdges"
	_wire_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edit_overlay_root.add_child(_wire_overlay)

	_seam_edge_overlay = MeshInstance3D.new()
	_seam_edge_overlay.name = "UVSeams"
	_seam_edge_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edit_overlay_root.add_child(_seam_edge_overlay)

	_selected_edge_overlay = MeshInstance3D.new()
	_selected_edge_overlay.name = "SelectedEdges"
	_selected_edge_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edit_overlay_root.add_child(_selected_edge_overlay)

	_face_overlay = MeshInstance3D.new()
	_face_overlay.name = "SelectedFaces"
	_face_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_edit_overlay_root.add_child(_face_overlay)

	_vertex_markers = MultiMeshInstance3D.new()
	_vertex_markers.name = "TopologyVertices"
	_vertex_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vertex_markers.material_override = _vertex_material
	_edit_overlay_root.add_child(_vertex_markers)

	_vertex_point_overlay = MeshInstance3D.new()
	_vertex_point_overlay.name = "DenseTopologyVertices"
	_vertex_point_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vertex_point_overlay.material_override = _vertex_point_material
	_edit_overlay_root.add_child(_vertex_point_overlay)

	_selected_vertex_markers = MultiMeshInstance3D.new()
	_selected_vertex_markers.name = "SelectedVertices"
	_selected_vertex_markers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selected_vertex_markers.material_override = _selected_vertex_material
	_edit_overlay_root.add_child(_selected_vertex_markers)

	_snap_marker = MeshInstance3D.new()
	_snap_marker.name = "SnapTarget"
	_snap_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var marker_mesh: SphereMesh = SphereMesh.new()
	marker_mesh.radius = 0.07
	marker_mesh.height = 0.14
	marker_mesh.radial_segments = 12
	_snap_marker.mesh = marker_mesh
	_snap_marker.material_override = _make_unshaded_material(Color(0.1, 0.95, 1.0), false)
	_snap_marker.visible = false
	_world_root.add_child(_snap_marker)

	_remesh_guide_material = StandardMaterial3D.new()
	_remesh_guide_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_remesh_guide_material.vertex_color_use_as_albedo = true
	_remesh_guide_material.no_depth_test = true
	_remesh_guide_overlay = MeshInstance3D.new()
	_remesh_guide_overlay.name = "RemeshGuides"
	_remesh_guide_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_remesh_guide_overlay.material_override = _remesh_guide_material
	_world_root.add_child(_remesh_guide_overlay)

	_transform_gizmo = GMSTransformGizmo.new()
	_world_root.add_child(_transform_gizmo)
	_transform_gizmo.set_mode(gizmo_mode)
	_transform_gizmo.set_orientation(gizmo_orientation)

	_box_select_panel = Panel.new()
	_box_select_panel.name = "BoxSelection"
	_box_select_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_select_panel.visible = false
	var box_style: StyleBoxFlat = StyleBoxFlat.new()
	box_style.bg_color = Color(0.12, 0.52, 1.0, 0.16)
	box_style.border_color = Color(0.25, 0.7, 1.0, 0.95)
	box_style.set_border_width_all(1)
	_box_select_panel.add_theme_stylebox_override("panel", box_style)
	add_child(_box_select_panel)

	_edit_overlay_root.visible = false
	_refresh_transform_gizmo()


func _make_unshaded_material(
	colour: Color,
	transparent: bool,
	cull_mode: BaseMaterial3D.CullMode = BaseMaterial3D.CULL_DISABLED
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = cull_mode
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _create_grid() -> MeshInstance3D:
	var immediate: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var extent: int = 20
	for index: int in range(-extent, extent + 1):
		var alpha: float = 0.14
		if index == 0:
			alpha = 0.34
		var colour: Color = Color(0.62, 0.66, 0.74, alpha)
		immediate.surface_set_color(colour)
		immediate.surface_add_vertex(Vector3(float(index), 0.0, float(-extent)))
		immediate.surface_set_color(colour)
		immediate.surface_add_vertex(Vector3(float(index), 0.0, float(extent)))
		immediate.surface_set_color(colour)
		immediate.surface_add_vertex(Vector3(float(-extent), 0.0, float(index)))
		immediate.surface_set_color(colour)
		immediate.surface_add_vertex(Vector3(float(extent), 0.0, float(index)))
	immediate.surface_end()

	var grid: MeshInstance3D = MeshInstance3D.new()
	grid.name = "Grid"
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.mesh = immediate
	return grid



func _build_view_orientation_gizmo() -> void:
	_view_orientation_gizmo = VIEW_ORIENTATION_GIZMO_SCRIPT.new() as GMSViewOrientationGizmo
	if _view_orientation_gizmo == null:
		push_error("Gator Model Studio could not create the viewport orientation gizmo.")
		return
	_view_orientation_gizmo.name = "ViewOrientationGizmo"
	add_child(_view_orientation_gizmo)
	_view_orientation_gizmo.set_anchor(SIDE_LEFT, 1.0)
	_view_orientation_gizmo.set_anchor(SIDE_RIGHT, 1.0)
	_view_orientation_gizmo.set_anchor(SIDE_TOP, 0.0)
	_view_orientation_gizmo.set_anchor(SIDE_BOTTOM, 0.0)
	_view_orientation_gizmo.offset_left = -102.0
	_view_orientation_gizmo.offset_right = -10.0
	_view_orientation_gizmo.offset_top = 10.0
	_view_orientation_gizmo.offset_bottom = 102.0
	_view_orientation_gizmo.axis_view_requested.connect(_set_axis_view)


func _build_rig_overlay() -> void:
	_rig_overlay = RIG_OVERLAY_SCRIPT.new() as GMSRigOverlay
	if _rig_overlay == null:
		push_error("Gator Model Studio could not create the rig overlay.")
		return
	_rig_overlay.name = "RigOverlay"
	add_child(_rig_overlay)
	_rig_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rig_overlay.clear()

func _create_axis_lines() -> MeshInstance3D:
	var immediate: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true

	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate.surface_set_color(Color(0.9, 0.2, 0.2))
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_set_color(Color(0.9, 0.2, 0.2))
	immediate.surface_add_vertex(Vector3.RIGHT * 2.0)
	immediate.surface_set_color(Color(0.25, 0.9, 0.35))
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_set_color(Color(0.25, 0.9, 0.35))
	immediate.surface_add_vertex(Vector3.UP * 2.0)
	immediate.surface_set_color(Color(0.25, 0.45, 1.0))
	immediate.surface_add_vertex(Vector3.ZERO)
	immediate.surface_set_color(Color(0.25, 0.45, 1.0))
	immediate.surface_add_vertex(Vector3.BACK * 2.0)
	immediate.surface_end()

	var axes: MeshInstance3D = MeshInstance3D.new()
	axes.name = "Axes"
	axes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	axes.mesh = immediate
	return axes


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if _remesh_guide_draw_active:
			mouse_default_cursor_shape = Control.CURSOR_CROSS
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		else:
			_restore_viewport_cursor()

	if event is InputEventMouseButton:
		_last_pointer_position = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion:
		_last_pointer_position = (event as InputEventMouseMotion).position

	if _scalar_adjust_active:
		_handle_scalar_adjust_input(event)
		return

	if _remesh_guide_draw_active:
		_handle_remesh_guide_input(event)
		return

	if _knife_active:
		_handle_knife_input(event)
		return

	if _box_select_active:
		_handle_box_select_input(event)
		return

	if is_transforming():
		_handle_transform_input(event)
		return

	if workspace_mode in [WorkspaceMode.RIG, WorkspaceMode.ANIMATE] and _handle_rig_input(event):
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if _handle_shortcut(key_event):
				accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_button.pressed:
				_panning = mouse_button.shift_pressed
				_zooming = mouse_button.ctrl_pressed
				_orbiting = not _panning and not _zooming
				_suppress_interaction_overlays()
			else:
				_orbiting = false
				_panning = false
				_zooming = false
				_restore_interaction_overlays()
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_suppress_interaction_overlays(true)
			_zoom_camera(0.88)
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_suppress_interaction_overlays(true)
			_zoom_camera(1.14)
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				grab_focus()
				var gizmo_axis: int = _pick_gizmo_axis(mouse_button.position)
				if gizmo_axis >= 0:
					var world_axis: Vector3 = _transform_gizmo.get_axis_world(gizmo_axis)
					gizmo_transform_requested.emit(gizmo_mode, world_axis, mouse_button.position)
					accept_event()
					return
				_left_press_position = mouse_button.position
				_left_dragged = false
			else:
				if not _left_dragged:
					var edge_pattern: int = EdgeSelectionPattern.SINGLE
					if mouse_button.alt_pressed and mouse_button.ctrl_pressed:
						edge_pattern = EdgeSelectionPattern.RING
					elif mouse_button.alt_pressed:
						edge_pattern = EdgeSelectionPattern.LOOP
					_pick_selection(
						mouse_button.position,
						mouse_button.shift_pressed,
						edge_pattern
					)
			accept_event()
			return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if motion.position.distance_to(_left_press_position) > 4.0:
				_left_dragged = true
		if _orbiting:
			_camera_yaw -= motion.relative.x * 0.008
			_camera_pitch = clampf(
				_camera_pitch - motion.relative.y * 0.008,
				deg_to_rad(-88.0),
				deg_to_rad(88.0)
			)
			_update_camera()
			accept_event()
		elif _panning:
			var pan_scale: float = _camera_distance * 0.0018
			var right: Vector3 = _camera.global_transform.basis.x.normalized()
			var up: Vector3 = _camera.global_transform.basis.y.normalized()
			_camera_target += (-right * motion.relative.x + up * motion.relative.y) * pan_scale
			_update_camera()
			accept_event()
		elif _zooming:
			_zoom_camera(1.0 + motion.relative.y * 0.01)
			accept_event()
		else:
			_update_gizmo_hover(motion.position)


func _handle_rig_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			_rig_weight_brushing = false
			if _rig_drag_bone_index >= 0:
				rig_bone_endpoint_dragged.emit(
					selected_object_id,
					_rig_drag_bone_index,
					_rig_drag_tail,
					Vector3.ZERO,
					3
				)
				_rig_drag_bone_index = -1
			return true
		return false
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if workspace_mode == WorkspaceMode.ANIMATE:
			if mouse_button.pressed and _pick_gizmo_axis(mouse_button.position) >= 0:
				return false
			if mouse_button.pressed:
				var ik_control: int = _pick_animation_ik_control(mouse_button.position)
				if ik_control != AnimationIKControl.NONE:
					_animation_ik_control = ik_control
					animation_ik_control_selected.emit(ik_control)
					_refresh_transform_gizmo()
					accept_event()
					return true
				if _animation_ik_control != AnimationIKControl.NONE:
					_animation_ik_control = AnimationIKControl.NONE
					animation_ik_control_selected.emit(AnimationIKControl.NONE)
					_refresh_transform_gizmo()
				var animate_bone_index: int = _pick_rig_bone(mouse_button.position)
				rig_bone_clicked.emit(animate_bone_index)
				accept_event()
				return true
			return true
		if rig_submode == RigSubmode.WEIGHTS:
			if rig_vertex_select:
				_clear_rig_brush_preview()
				return false
			_rig_weight_brushing = mouse_button.pressed
			_update_rig_brush_preview(mouse_button.position)
			if mouse_button.pressed:
				_rig_last_brush_screen = Vector2(INF, INF)
				_emit_rig_weight_brush(mouse_button.position, true)
			accept_event()
			return true
		if rig_submode == RigSubmode.EDIT:
			if mouse_button.pressed:
				var endpoint: Dictionary = _pick_rig_endpoint(mouse_button.position)
				if not endpoint.is_empty():
					_start_rig_endpoint_drag(int(endpoint["bone_index"]), bool(endpoint["move_tail"]))
					accept_event()
					return true
				var bone_index: int = _pick_rig_bone(mouse_button.position)
				rig_bone_clicked.emit(bone_index)
				accept_event()
				return true
			if _rig_drag_bone_index >= 0:
				var local_position_value: Variant = _rig_drag_local_position(mouse_button.position)
				if local_position_value != null:
					var local_position: Vector3 = local_position_value
					rig_bone_endpoint_dragged.emit(
						selected_object_id,
						_rig_drag_bone_index,
						_rig_drag_tail,
						local_position,
						2
					)
				else:
					rig_bone_endpoint_dragged.emit(
						selected_object_id,
						_rig_drag_bone_index,
						_rig_drag_tail,
						Vector3.ZERO,
						3
					)
				_rig_drag_bone_index = -1
				accept_event()
				return true
		if mouse_button.pressed:
			var bone_index: int = _pick_rig_bone(mouse_button.position)
			rig_bone_clicked.emit(bone_index)
			accept_event()
			return true
		return true
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if rig_submode == RigSubmode.WEIGHTS:
			if rig_vertex_select:
				_clear_rig_brush_preview()
				return false
			_update_rig_brush_preview(motion.position)
			if _rig_weight_brushing and bool(motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
				_emit_rig_weight_brush(motion.position)
				accept_event()
				return true
		elif rig_submode == RigSubmode.EDIT and _rig_drag_bone_index >= 0:
			var local_position_value: Variant = _rig_drag_local_position(motion.position)
			if local_position_value != null:
				var local_position: Vector3 = local_position_value
				rig_bone_endpoint_dragged.emit(
					selected_object_id,
					_rig_drag_bone_index,
					_rig_drag_tail,
					local_position,
					1
				)
			accept_event()
			return true
	return false



func _update_rig_brush_preview(screen_position: Vector2) -> void:
	if _rig_overlay == null:
		return
	if (
		workspace_mode != WorkspaceMode.RIG
		or rig_submode != RigSubmode.WEIGHTS
		or rig_vertex_select
		or _overlay_suppressed
		or document == null
		or selected_object_id.is_empty()
		or _camera == null
	):
		_clear_rig_brush_preview()
		return
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.mesh_data == null:
		_clear_rig_brush_preview()
		return
	var hit: Dictionary = _pick_rig_brush_hit(screen_position)
	if hit.is_empty():
		_clear_rig_brush_preview()
		return
	var local_hit: Vector3 = hit.get("local_hit", Vector3.ZERO)
	var world_center: Vector3 = object.transform * local_hit
	if _camera.is_position_behind(world_center):
		_clear_rig_brush_preview()
		return
	var local_camera_right: Vector3 = object.transform.basis.inverse() * _camera.global_transform.basis.x.normalized()
	if local_camera_right.is_zero_approx():
		local_camera_right = Vector3.RIGHT
	else:
		local_camera_right = local_camera_right.normalized()
	var local_edge: Vector3 = local_hit + local_camera_right * rig_brush_radius
	var world_edge: Vector3 = object.transform * local_edge
	var screen_center: Vector2 = _camera.unproject_position(world_center)
	var screen_radius: float = screen_center.distance_to(_camera.unproject_position(world_edge))
	_rig_overlay.set_brush_preview(screen_center, maxf(screen_radius, 6.0), rig_brush_mode, rig_brush_strength)


func _pick_rig_brush_hit(screen_position: Vector2) -> Dictionary:
	if document == null or _camera == null or selected_object_id.is_empty():
		return {}
	if (
		not _rig_brush_hit_cache.is_empty()
		and screen_position.distance_squared_to(_rig_brush_hit_screen) <= 0.01
	):
		return _rig_brush_hit_cache.duplicate()
	_rig_brush_hit_screen = screen_position
	_rig_brush_hit_cache.clear()

	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.mesh_data == null or object.mesh_data.faces.is_empty():
		return {}

	# Weight painting must target only the active skinned mesh. Separate eyes,
	# spikes, armour, and other rigid objects should not block the brush ray.
	var direct_hit: Dictionary = _pick_face_on_object(screen_position, object)
	if not direct_hit.is_empty():
		_store_rig_brush_hit(direct_hit)
		return direct_hit

	# Thin toes, claws, eyelids, and silhouettes can fall between triangles by a
	# few pixels. Snap a missed ray to a nearby point on the active mesh instead
	# of making the brush disappear.
	var mesh: GMSMeshData = object.mesh_data
	var spatial_index: GMSMeshSpatialIndex = _get_spatial_index(object.object_id, mesh)
	if spatial_index == null:
		return {}
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position).normalized()
	var inverse: Transform3D = object.transform.affine_inverse()
	var local_origin: Vector3 = inverse * ray_origin
	var local_direction: Vector3 = inverse.basis * ray_direction
	if local_direction.is_zero_approx():
		return {}
	local_direction = local_direction.normalized()

	var local_probe: Vector3
	if _rig_brush_has_last_hit:
		var world_probe: Vector3 = ray_origin + ray_direction * _rig_brush_last_world_distance
		local_probe = inverse * world_probe
	else:
		var bounds_center: Vector3 = mesh.get_aabb().get_center()
		var center_distance: float = maxf((bounds_center - local_origin).dot(local_direction), 0.0)
		local_probe = local_origin + local_direction * center_distance

	var mesh_size: float = maxf(mesh.get_aabb().size.length(), 0.0001)
	var snap_distance: float = maxf(
		rig_brush_radius * 1.5,
		mesh_size * RIG_BRUSH_EDGE_SNAP_MESH_RATIO
	)
	var closest: Dictionary = spatial_index.closest_point(local_probe, snap_distance)
	if closest.is_empty():
		return {}
	var local_hit: Vector3 = closest.get("position", Vector3.ZERO)
	var world_hit: Vector3 = object.transform * local_hit
	if _camera.is_position_behind(world_hit):
		return {}
	var projected_hit: Vector2 = _camera.unproject_position(world_hit)
	if projected_hit.distance_to(screen_position) > RIG_BRUSH_EDGE_SNAP_PIXELS:
		return {}
	var fallback_hit: Dictionary = {
		"object_id": object.object_id,
		"component_index": int(closest.get("face_index", -1)),
		"distance": ray_origin.distance_to(world_hit),
		"local_hit": local_hit,
		"world_hit": world_hit,
		"edge_snap": true,
	}
	_store_rig_brush_hit(fallback_hit)
	return fallback_hit


func _pick_face_on_object(screen_position: Vector2, object: GMSModelObject) -> Dictionary:
	if object == null or object.mesh_data == null or _camera == null:
		return {}
	var mesh: GMSMeshData = object.mesh_data
	var spatial_index: GMSMeshSpatialIndex = _get_spatial_index(object.object_id, mesh)
	if spatial_index == null:
		return {}
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position).normalized()
	var inverse: Transform3D = object.transform.affine_inverse()
	var local_origin: Vector3 = inverse * ray_origin
	var local_direction: Vector3 = inverse.basis * ray_direction
	if local_direction.is_zero_approx():
		return {}
	var hit: Dictionary = spatial_index.raycast(local_origin, local_direction)
	if hit.is_empty():
		return {}
	var local_hit: Vector3 = hit.get("position", Vector3.ZERO)
	var world_hit: Vector3 = object.transform * local_hit
	return {
		"object_id": object.object_id,
		"component_index": int(hit.get("face_index", -1)),
		"distance": ray_origin.distance_to(world_hit),
		"local_hit": local_hit,
		"world_hit": world_hit,
	}


func _store_rig_brush_hit(hit: Dictionary) -> void:
	_rig_brush_hit_cache = hit.duplicate()
	_rig_brush_last_world_distance = float(hit.get("distance", 0.0))
	_rig_brush_has_last_hit = _rig_brush_last_world_distance > 0.0


func _reset_rig_brush_hit_cache() -> void:
	_rig_brush_hit_screen = Vector2(INF, INF)
	_rig_brush_hit_cache.clear()
	_rig_brush_last_world_distance = 0.0
	_rig_brush_has_last_hit = false


func _clear_rig_brush_preview() -> void:
	if _rig_overlay != null:
		_rig_overlay.clear_brush_preview()


func _emit_rig_weight_brush(screen_position: Vector2, force: bool = false) -> void:
	if document == null or selected_object_id.is_empty():
		return
	var now_usec: int = Time.get_ticks_usec()
	if not force and screen_position.distance_squared_to(_rig_last_brush_screen) < 9.0 and now_usec - _rig_last_brush_usec < 30000:
		return
	_rig_last_brush_screen = screen_position
	_rig_last_brush_usec = now_usec
	var hit: Dictionary = _pick_rig_brush_hit(screen_position)
	if hit.is_empty():
		return
	rig_weight_brush_requested.emit(
		selected_object_id,
		hit.get("local_hit", Vector3.ZERO),
		rig_brush_radius,
		rig_brush_strength,
		rig_brush_mode
	)


func _pick_rig_endpoint(screen_position: Vector2) -> Dictionary:
	if document == null or selected_object_id.is_empty() or _camera == null:
		return {}
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.rig_data == null:
		return {}
	var best: Dictionary = {}
	var best_distance: float = 11.0 * 11.0
	for bone_index: int in object.rig_data.bones.size():
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		for move_tail_value: Variant in [false, true]:
			var move_tail: bool = bool(move_tail_value)
			var local_point: Vector3 = bone.tail if move_tail else bone.head
			var world_point: Vector3 = object.transform * local_point
			if _camera.is_position_behind(world_point):
				continue
			var distance: float = screen_position.distance_squared_to(_camera.unproject_position(world_point))
			if distance < best_distance:
				best_distance = distance
				best = {"bone_index": bone_index, "move_tail": move_tail, "world_point": world_point}
	return best


func _start_rig_endpoint_drag(bone_index: int, move_tail: bool) -> void:
	if document == null or _camera == null:
		return
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.rig_data == null or bone_index < 0 or bone_index >= object.rig_data.bones.size():
		return
	var bone: GMSBoneData = object.rig_data.bones[bone_index]
	var local_point: Vector3 = bone.tail if move_tail else bone.head
	var world_point: Vector3 = object.transform * local_point
	_rig_drag_bone_index = bone_index
	_rig_drag_tail = move_tail
	_rig_drag_plane = Plane(_camera.global_transform.basis.z.normalized(), world_point)
	rig_bone_clicked.emit(bone_index)
	rig_bone_endpoint_dragged.emit(selected_object_id, bone_index, move_tail, local_point, 0)


func _rig_drag_local_position(screen_position: Vector2) -> Variant:
	if document == null or _camera == null or _rig_drag_bone_index < 0:
		return null
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null:
		return null
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	var world_hit_value: Variant = _rig_drag_plane.intersects_ray(ray_origin, ray_direction)
	if world_hit_value == null:
		return null
	var world_hit: Vector3 = world_hit_value
	return object.transform.affine_inverse() * world_hit


func _pick_rig_bone(screen_position: Vector2) -> int:
	if document == null or selected_object_id.is_empty() or _camera == null:
		return -1
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.rig_data == null:
		return -1
	var best_index: int = -1
	var best_distance: float = 14.0 * 14.0
	var skeleton: Skeleton3D = _skeleton_nodes.get(selected_object_id) as Skeleton3D
	for bone_index: int in object.rig_data.bones.size():
		var world_head: Vector3
		var world_tail: Vector3
		if skeleton != null and bone_index < skeleton.get_bone_count():
			var pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
			var length: float = object.rig_data.bones[bone_index].get_length()
			world_head = skeleton.global_transform * pose.origin
			world_tail = skeleton.global_transform * (pose * Vector3(0.0, length, 0.0))
		else:
			world_head = object.transform * object.rig_data.bones[bone_index].head
			world_tail = object.transform * object.rig_data.bones[bone_index].tail
		if _camera.is_position_behind(world_head) and _camera.is_position_behind(world_tail):
			continue
		var head_screen: Vector2 = _camera.unproject_position(world_head)
		var tail_screen: Vector2 = _camera.unproject_position(world_tail)
		var distance: float = _point_segment_distance_squared(screen_position, head_screen, tail_screen)
		if distance < best_distance:
			best_distance = distance
			best_index = bone_index
	return best_index


func _handle_scalar_adjust_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var precision: float = 0.1 if motion.shift_pressed else 1.0
		var offset: float = (
			motion.position.x - _scalar_adjust_start_mouse.x
		) * _scalar_adjust_sensitivity * precision
		_scalar_adjust_value = clampf(
			_scalar_adjust_initial + offset,
			_scalar_adjust_minimum,
			_scalar_adjust_maximum
		)
		scalar_adjust_preview.emit(_scalar_adjust_value)
		_emit_scalar_adjust_status()
		accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_finish_scalar_adjust()
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			cancel_scalar_adjust()
			accept_event()
			return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_ESCAPE:
				cancel_scalar_adjust()
			KEY_ENTER, KEY_KP_ENTER:
				_finish_scalar_adjust()
			_:
				return
		accept_event()


func _handle_remesh_guide_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			cancel_remesh_guide_draw()
			accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			cancel_remesh_guide_draw()
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_zoom_camera(0.88)
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_zoom_camera(1.14)
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_button.pressed:
				_panning = mouse_button.shift_pressed
				_zooming = mouse_button.ctrl_pressed
				_orbiting = not _panning and not _zooming
			else:
				_orbiting = false
				_panning = false
				_zooming = false
			accept_event()
			return
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			grab_focus()
			var hit: Dictionary = _pick_remesh_guide_hit(mouse_button.position)
			if hit.is_empty():
				transform_status_changed.emit("Remesh guide: begin the stroke on the selected surface.")
				accept_event()
				return
			_remesh_guide_stroking = true
			_remesh_guide_draw_points = PackedVector3Array([hit["local_hit"]])
			_remesh_guide_last_screen_position = mouse_button.position
			_refresh_remesh_guide_overlay()
		else:
			if _remesh_guide_stroking and _remesh_guide_draw_points.size() >= 2:
				var object_id: String = _remesh_guide_draw_object_id
				var completed_points: PackedVector3Array = _resample_remesh_guide_points(
					_remesh_guide_draw_points
				)
				_remesh_guide_draw_active = false
				_remesh_guide_stroking = false
				_remesh_guide_draw_object_id = ""
				_remesh_guide_draw_points.clear()
				_restore_viewport_cursor()
				_refresh_remesh_guide_overlay()
				transform_status_changed.emit("")
				remesh_guide_stroke_completed.emit(object_id, completed_points)
			else:
				_remesh_guide_stroking = false
				_remesh_guide_draw_points.clear()
				_refresh_remesh_guide_overlay()
		accept_event()
		return

	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _orbiting:
			_camera_yaw -= motion.relative.x * 0.008
			_camera_pitch = clampf(
				_camera_pitch - motion.relative.y * 0.008,
				deg_to_rad(-88.0),
				deg_to_rad(88.0)
			)
			_update_camera()
			accept_event()
			return
		if _panning:
			var pan_scale: float = _camera_distance * 0.0018
			var right: Vector3 = _camera.global_transform.basis.x.normalized()
			var up: Vector3 = _camera.global_transform.basis.y.normalized()
			_camera_target += (-right * motion.relative.x + up * motion.relative.y) * pan_scale
			_update_camera()
			accept_event()
			return
		if _zooming:
			_zoom_camera(1.0 + motion.relative.y * 0.01)
			accept_event()
			return
		if not _remesh_guide_stroking or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		if motion.position.distance_to(_remesh_guide_last_screen_position) < 3.0:
			return
		var hit: Dictionary = _pick_remesh_guide_hit(motion.position)
		if hit.is_empty():
			return
		var local_hit: Vector3 = hit["local_hit"]
		if _remesh_guide_draw_points[_remesh_guide_draw_points.size() - 1].distance_squared_to(local_hit) <= 0.00000001:
			return
		_remesh_guide_draw_points.append(local_hit)
		_remesh_guide_last_screen_position = motion.position
		_refresh_remesh_guide_overlay()
		accept_event()


func _pick_remesh_guide_hit(screen_position: Vector2) -> Dictionary:
	if _camera == null or document == null or _remesh_guide_draw_object_id.is_empty():
		return {}
	var object: GMSModelObject = document.get_object(_remesh_guide_draw_object_id)
	if not _is_object_pickable(object):
		return {}
	var mesh: GMSMeshData = object.get_evaluated_mesh_data()
	if mesh == null or mesh.faces.is_empty():
		return {}
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position).normalized()
	var inverse: Transform3D = object.transform.affine_inverse()
	var local_origin: Vector3 = inverse * ray_origin
	var local_direction: Vector3 = inverse.basis * ray_direction
	var spatial_index: GMSMeshSpatialIndex = _get_spatial_index(object.object_id, mesh)
	if spatial_index == null:
		return {}
	var hit: Dictionary = spatial_index.raycast(local_origin, local_direction)
	if hit.is_empty():
		return {}
	return {
		"local_hit": hit["position"],
		"face_index": hit["face_index"],
	}


func _resample_remesh_guide_points(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() <= 2:
		return points.duplicate()
	var total_length: float = 0.0
	for point_index: int in range(points.size() - 1):
		total_length += points[point_index].distance_to(points[point_index + 1])
	var spacing: float = maxf(total_length / 64.0, 0.000001)
	var result: PackedVector3Array = PackedVector3Array([points[0]])
	for point_index: int in range(1, points.size() - 1):
		var last_index: int = result.size() - 1
		var incoming: Vector3 = (points[point_index] - result[last_index]).normalized()
		var outgoing: Vector3 = (points[point_index + 1] - points[point_index]).normalized()
		if incoming.dot(outgoing) < 0.998 or result[last_index].distance_to(points[point_index]) >= spacing:
			result.append(points[point_index])
	result.append(points[points.size() - 1])
	return result


func _refresh_remesh_guide_overlay() -> void:
	if _remesh_guide_overlay == null or document == null:
		return
	var line_vertices: PackedVector3Array = PackedVector3Array()
	var line_colours: PackedColorArray = PackedColorArray()
	var display_object: GMSModelObject = document.get_object(_remesh_guide_object_id)
	if display_object != null:
		for guide: GMSRemeshGuide in _remesh_guides:
			if guide == null or guide.points.size() < 2:
				continue
			var colour: Color = _remesh_guide_colour(guide.mode)
			for point_index: int in range(guide.points.size() - 1):
				line_vertices.append(display_object.transform * guide.points[point_index])
				line_colours.append(colour)
				line_vertices.append(display_object.transform * guide.points[point_index + 1])
				line_colours.append(colour)
	var drawing_object: GMSModelObject = document.get_object(_remesh_guide_draw_object_id)
	if drawing_object != null and _remesh_guide_draw_points.size() >= 2:
		for point_index: int in range(_remesh_guide_draw_points.size() - 1):
			line_vertices.append(drawing_object.transform * _remesh_guide_draw_points[point_index])
			line_colours.append(Color(1.0, 1.0, 1.0, 1.0))
			line_vertices.append(drawing_object.transform * _remesh_guide_draw_points[point_index + 1])
			line_colours.append(Color(1.0, 1.0, 1.0, 1.0))
	if line_vertices.is_empty():
		_remesh_guide_overlay.mesh = null
		return
	var immediate: ImmediateMesh = ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, _remesh_guide_material)
	for vertex_index: int in line_vertices.size():
		immediate.surface_set_color(line_colours[vertex_index])
		immediate.surface_add_vertex(line_vertices[vertex_index])
	immediate.surface_end()
	_remesh_guide_overlay.mesh = immediate


func _remesh_guide_colour(mode: int) -> Color:
	match mode:
		GMSRemeshGuide.GuideMode.PRESERVE_SHAPE:
			return Color(1.0, 0.72, 0.1, 1.0)
		GMSRemeshGuide.GuideMode.DENSITY:
			return Color(0.95, 0.25, 0.85, 1.0)
		_:
			return Color(0.1, 0.9, 1.0, 1.0)


func _handle_knife_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			cancel_knife()
			accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
		cancel_knife()
		accept_event()
		return
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	var hit: Dictionary = _pick_face(mouse_button.position)
	if hit.is_empty() or str(hit.get("object_id", "")) != selected_object_id:
		transform_status_changed.emit("Knife: click the selected object's visible face boundary.")
		accept_event()
		return
	if _knife_first_hit.is_empty():
		_knife_first_hit = hit
		transform_status_changed.emit("Knife: choose the second point on the same face.")
	else:
		if (
			str(hit.get("object_id", "")) != str(_knife_first_hit.get("object_id", ""))
			or int(hit.get("component_index", -1)) != int(_knife_first_hit.get("component_index", -1))
		):
			transform_status_changed.emit("Knife: both points must be on the same face.")
			accept_event()
			return
		knife_cut_requested.emit(
			selected_object_id,
			int(hit.get("component_index", -1)),
			_knife_first_hit.get("local_hit", Vector3.ZERO),
			hit.get("local_hit", Vector3.ZERO)
		)
		cancel_knife()
	accept_event()


func _handle_box_select_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			cancel_box_select()
			accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			cancel_box_select()
			accept_event()
			return
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_box_select_dragging = true
				_box_select_start = mouse_button.position
				_update_box_select_panel(mouse_button.position)
			else:
				if _box_select_dragging:
					_update_box_select_panel(mouse_button.position)
					_apply_box_selection(
						_get_box_rect(_box_select_start, mouse_button.position),
						mouse_button.shift_pressed,
						mouse_button.ctrl_pressed
					)
				cancel_box_select()
			accept_event()
			return

	if event is InputEventMouseMotion and _box_select_dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_box_select_panel(motion.position)
		accept_event()


func _update_box_select_panel(current_position: Vector2) -> void:
	var box_rect: Rect2 = _get_box_rect(_box_select_start, current_position)
	_box_select_panel.position = box_rect.position
	_box_select_panel.size = box_rect.size
	_box_select_panel.visible = true


func _apply_box_selection(box_rect: Rect2, additive: bool, subtractive: bool) -> void:
	if document == null or box_rect.size.length_squared() < 4.0:
		return
	var operation: int = GMSSelection.Operation.SET
	if subtractive:
		operation = GMSSelection.Operation.SUBTRACT
	elif additive:
		operation = GMSSelection.Operation.ADD

	if selection_mode == GMSSelection.Mode.OBJECT:
		var object_ids: PackedStringArray = PackedStringArray()
		for object: GMSModelObject in document.objects:
			if not _is_object_pickable(object) or object.mesh_data == null:
				continue
			if _object_intersects_screen_rect(object, box_rect):
				object_ids.append(object.object_id)
		box_object_selection_requested.emit(object_ids, operation)
		return

	var object: GMSModelObject = document.get_object(selected_object_id)
	if not _is_object_pickable(object) or object.mesh_data == null:
		return
	var indices: PackedInt32Array = PackedInt32Array()
	match selection_mode:
		GMSSelection.Mode.VERTEX:
			indices = _vertices_in_screen_rect(object, box_rect)
		GMSSelection.Mode.EDGE:
			indices = _edges_in_screen_rect(object, box_rect)
		GMSSelection.Mode.FACE:
			indices = _faces_in_screen_rect(object, box_rect)
	box_selection_requested.emit(object.object_id, indices, operation)


func _object_intersects_screen_rect(object: GMSModelObject, box_rect: Rect2) -> bool:
	var display_mesh: GMSMeshData = object.get_evaluated_mesh_data()
	if display_mesh == null or display_mesh.vertices.is_empty():
		return box_rect.has_point(_camera.unproject_position(object.transform.origin))
	var projection: Dictionary = _get_projection_data(object, display_mesh)
	var candidates: PackedInt32Array = _get_grid_candidates_in_rect(projection["vertex_grid"], box_rect)
	var screens: PackedVector2Array = projection["screen_positions"]
	var behind: PackedByteArray = projection["behind"]
	for vertex_index: int in candidates:
		if behind[vertex_index] == 0 and box_rect.has_point(screens[vertex_index]):
			return true
	return false


func _vertices_in_screen_rect(object: GMSModelObject, box_rect: Rect2) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var projection: Dictionary = _get_projection_data(object, object.mesh_data)
	var candidates: PackedInt32Array = _get_grid_candidates_in_rect(projection["vertex_grid"], box_rect)
	var screens: PackedVector2Array = projection["screen_positions"]
	var depths: PackedFloat32Array = projection["depths"]
	var behind: PackedByteArray = projection["behind"]
	for vertex_index: int in candidates:
		if behind[vertex_index] != 0 or not box_rect.has_point(screens[vertex_index]):
			continue
		if xray_enabled or _is_screen_depth_visible(screens[vertex_index], depths[vertex_index]):
			result.append(vertex_index)
	return result


func _edges_in_screen_rect(object: GMSModelObject, box_rect: Rect2) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var mesh: GMSMeshData = object.mesh_data
	var projection: Dictionary = _get_projection_data(object, mesh)
	var candidates: PackedInt32Array = _get_grid_candidates_in_rect(
		_get_edge_grid(object, mesh, projection), box_rect
	)
	var edges: Array[Vector2i] = mesh.get_edges()
	var screens: PackedVector2Array = projection["screen_positions"]
	var depths: PackedFloat32Array = projection["depths"]
	var behind: PackedByteArray = projection["behind"]
	for edge_index: int in candidates:
		if edge_index < 0 or edge_index >= edges.size():
			continue
		var edge: Vector2i = edges[edge_index]
		if behind[edge.x] != 0 and behind[edge.y] != 0:
			continue
		var screen_a: Vector2 = screens[edge.x]
		var screen_b: Vector2 = screens[edge.y]
		if not _segment_intersects_rect(screen_a, screen_b, box_rect):
			continue
		var midpoint: Vector2 = screen_a.lerp(screen_b, 0.5)
		var depth: float = lerpf(depths[edge.x], depths[edge.y], 0.5)
		if xray_enabled or _is_screen_depth_visible(midpoint, depth):
			result.append(edge_index)
	return result


func _faces_in_screen_rect(object: GMSModelObject, box_rect: Rect2) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var mesh: GMSMeshData = object.mesh_data
	var projection: Dictionary = _get_projection_data(object, mesh)
	projection = _ensure_face_projection_data(object, mesh, projection)
	var screens: PackedVector2Array = projection["screen_positions"]
	var depths: PackedFloat32Array = projection["depths"]
	var behind: PackedByteArray = projection["behind"]
	var face_screens: PackedVector2Array = projection["face_screen_positions"]
	var face_depths: PackedFloat32Array = projection["face_depths"]
	var face_behind: PackedByteArray = projection["face_behind"]
	var candidates: Dictionary = {}
	for face_index: int in _get_grid_candidates_in_rect(projection["face_grid"], box_rect):
		candidates[face_index] = true
	var topology: GMSTopology = mesh.get_topology()
	for vertex_index: int in _get_grid_candidates_in_rect(projection["vertex_grid"], box_rect):
		for face_index: int in topology.get_vertex_faces(vertex_index):
			candidates[face_index] = true
	for face_value: Variant in candidates.keys():
		var face_index: int = int(face_value)
		if face_index < 0 or face_index >= mesh.faces.size():
			continue
		if face_behind[face_index] == 0 and box_rect.has_point(face_screens[face_index]):
			if xray_enabled or _is_screen_depth_visible(face_screens[face_index], face_depths[face_index]):
				result.append(face_index)
				continue
		for vertex_index: int in mesh.faces[face_index]:
			if behind[vertex_index] != 0 or not box_rect.has_point(screens[vertex_index]):
				continue
			if xray_enabled or _is_screen_depth_visible(screens[vertex_index], depths[vertex_index]):
				result.append(face_index)
				break
	return result


func _get_grid_candidates_in_rect(grid: Dictionary, box_rect: Rect2) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var known: Dictionary = {}
	var minimum: Vector2i = _screen_cell(box_rect.position)
	var maximum: Vector2i = _screen_cell(box_rect.end)
	for y: int in range(minimum.y, maximum.y + 1):
		for x: int in range(minimum.x, maximum.x + 1):
			var values: Array = grid.get(Vector2i(x, y), [])
			for index: int in values:
				if not known.has(index):
					known[index] = true
					result.append(index)
	return result


static func _get_box_rect(a: Vector2, b: Vector2) -> Rect2:
	var minimum: Vector2 = Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var maximum: Vector2 = Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(minimum, maximum - minimum)


static func _segment_intersects_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var top_left: Vector2 = rect.position
	var top_right: Vector2 = Vector2(rect.end.x, rect.position.y)
	var bottom_left: Vector2 = Vector2(rect.position.x, rect.end.y)
	var bottom_right: Vector2 = rect.end
	return (
		_segments_intersect(a, b, top_left, top_right)
		or _segments_intersect(a, b, top_right, bottom_right)
		or _segments_intersect(a, b, bottom_right, bottom_left)
		or _segments_intersect(a, b, bottom_left, top_left)
	)


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var denominator: float = ab.cross(cd)
	if absf(denominator) <= 0.000001:
		return false
	var relative: Vector2 = c - a
	var t: float = relative.cross(cd) / denominator
	var u: float = relative.cross(ab) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


func _handle_shortcut(event: InputEventKey) -> bool:
	if event.keycode == KEY_BACKTAB or (event.shift_pressed and event.keycode == KEY_TAB):
		snap_enabled = not snap_enabled
		snap_toggled.emit(snap_enabled)
		return true

	if event.ctrl_pressed and event.keycode == KEY_S:
		shortcut_requested.emit("save_as" if event.shift_pressed else "save")
		return true
	if event.ctrl_pressed and event.keycode == KEY_Z:
		shortcut_requested.emit("redo" if event.shift_pressed else "undo")
		return true

	if workspace_mode == WorkspaceMode.ANIMATE:
		if event.ctrl_pressed and event.keycode == KEY_C:
			shortcut_requested.emit("copy_animation_keys")
			return true
		if event.ctrl_pressed and event.keycode == KEY_V:
			shortcut_requested.emit("paste_animation_keys_mirrored" if event.shift_pressed else "paste_animation_keys")
			return true
		if event.keycode == KEY_K:
			if event.ctrl_pressed:
				shortcut_requested.emit("key_full_pose")
			elif event.shift_pressed:
				shortcut_requested.emit("key_changed_bones")
			else:
				shortcut_requested.emit("key_selected_bone")
			return true
		match event.keycode:
			KEY_SPACE:
				shortcut_requested.emit("animation_play_pause")
			KEY_LEFT:
				shortcut_requested.emit("animation_previous_frame")
			KEY_RIGHT:
				shortcut_requested.emit("animation_next_frame")
			KEY_UP:
				shortcut_requested.emit("animation_previous_key")
			KEY_DOWN:
				shortcut_requested.emit("animation_next_key")
			KEY_G:
				shortcut_requested.emit("move")
			KEY_R:
				shortcut_requested.emit("rotate")
			KEY_S:
				shortcut_requested.emit("scale")
			KEY_X, KEY_DELETE:
				shortcut_requested.emit("delete_animation_keys")
			KEY_F1:
				shortcut_requested.emit("hotkeys")
			_:
				pass
		if event.keycode in [
			KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
			KEY_G, KEY_R, KEY_S, KEY_X, KEY_DELETE, KEY_F1
		]:
			return true
	if event.shift_pressed and event.keycode == KEY_A:
		shortcut_requested.emit("add_menu")
		return true
	if event.shift_pressed and event.keycode == KEY_D:
		shortcut_requested.emit("duplicate")
		return true
	if event.alt_pressed and event.keycode == KEY_A:
		shortcut_requested.emit("clear_selection")
		return true
	if event.ctrl_pressed and event.keycode == KEY_I:
		shortcut_requested.emit("invert_selection")
		return true
	if event.ctrl_pressed and event.keycode == KEY_R:
		shortcut_requested.emit("loop_cut")
		return true
	if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_B:
		shortcut_requested.emit("bevel_vertices")
		return true
	if event.ctrl_pressed and event.keycode == KEY_B:
		shortcut_requested.emit("bevel_edges")
		return true
	if event.shift_pressed and event.keycode == KEY_E:
		shortcut_requested.emit("crease")
		return true
	if event.ctrl_pressed and event.keycode == KEY_J:
		shortcut_requested.emit("join_objects")
		return true
	if event.alt_pressed and event.keycode == KEY_Z:
		xray_enabled = not xray_enabled
		xray_toggled.emit(xray_enabled)
		return true
	if event.ctrl_pressed and event.keycode == KEY_T:
		shortcut_requested.emit("triangulate")
		return true
	if event.alt_pressed and event.keycode == KEY_J:
		shortcut_requested.emit("tris_to_quads")
		return true
	if event.shift_pressed and event.keycode == KEY_N:
		shortcut_requested.emit("recalculate_normals")
		return true
	if event.ctrl_pressed and event.keycode == KEY_KP_ADD:
		shortcut_requested.emit("grow_selection")
		return true
	if event.ctrl_pressed and event.keycode == KEY_KP_SUBTRACT:
		shortcut_requested.emit("shrink_selection")
		return true
	if event.ctrl_pressed:
		match event.keycode:
			KEY_1, KEY_KP_1:
				_set_axis_view(Vector3(0.0, 0.0, -1.0), Vector3.UP)
				return true
			KEY_3, KEY_KP_3:
				_set_axis_view(Vector3(-1.0, 0.0, 0.0), Vector3.UP)
				return true
			KEY_7, KEY_KP_7:
				_set_axis_view(Vector3(0.0, -1.0, 0.0), Vector3.BACK)
				return true

	match event.keycode:
		KEY_TAB:
			shortcut_requested.emit("toggle_edit_mode")
		KEY_1:
			shortcut_requested.emit("vertex_mode")
		KEY_2:
			shortcut_requested.emit("edge_mode")
		KEY_3:
			shortcut_requested.emit("face_mode")
		KEY_G:
			shortcut_requested.emit("move")
		KEY_R:
			shortcut_requested.emit("rotate")
		KEY_S:
			shortcut_requested.emit("scale")
		KEY_A:
			shortcut_requested.emit("select_all")
		KEY_B:
			begin_box_select()
		KEY_L:
			shortcut_requested.emit("select_linked")
		KEY_K:
			begin_knife()
		KEY_O:
			shortcut_requested.emit("toggle_proportional")
		KEY_P:
			shortcut_requested.emit("separate")
		KEY_F:
			shortcut_requested.emit("make_face")
		KEY_M:
			shortcut_requested.emit("merge")
		KEY_U:
			shortcut_requested.emit("uv_menu")
		KEY_E:
			shortcut_requested.emit("extrude")
		KEY_I:
			shortcut_requested.emit("inset")
		KEY_X, KEY_DELETE:
			shortcut_requested.emit("delete")
		KEY_F1:
			shortcut_requested.emit("hotkeys")
		KEY_KP_1:
			_set_axis_view(Vector3(0.0, 0.0, 1.0), Vector3.UP)
		KEY_KP_3:
			_set_axis_view(Vector3(1.0, 0.0, 0.0), Vector3.UP)
		KEY_KP_7:
			_set_axis_view(Vector3(0.0, 1.0, 0.0), Vector3.BACK)
		KEY_KP_5:
			_toggle_projection()
		KEY_KP_PERIOD:
			frame_selected()
		KEY_HOME:
			frame_all()
		_:
			return false
	return true


func _handle_transform_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_transform(motion.position, motion.ctrl_pressed, motion.shift_pressed)
		accept_event()
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if (_transform_confirm_on_release and not mouse_button.pressed) or (not _transform_confirm_on_release and mouse_button.pressed):
				_finish_transform()
				accept_event()
				return
		if mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			cancel_transform()
			accept_event()
			return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_ESCAPE:
				cancel_transform()
			KEY_ENTER, KEY_KP_ENTER:
				_finish_transform()
			KEY_X:
				_set_transform_axis(Vector3.RIGHT)
			KEY_Y:
				_set_transform_axis(Vector3.UP)
			KEY_Z:
				_set_transform_axis(Vector3.BACK)
			_:
				_update_transform(get_local_mouse_position(), key_event.ctrl_pressed, key_event.shift_pressed)
		accept_event()


func _finish_transform() -> void:
	if not is_transforming():
		return
	var was_animation_bone_transform: bool = _animation_bone_transform
	var was_animation_ik_transform: bool = _animation_ik_target_transform
	_clear_transform_state()
	if was_animation_bone_transform:
		animation_bone_transform_committed.emit()
	elif was_animation_ik_transform:
		animation_ik_target_transform_committed.emit()
	else:
		transform_committed.emit()


func _clear_transform_state() -> void:
	_transform_kind = TransformKind.NONE
	_transform_axis = Vector3.ZERO
	_transform_custom_axis = Vector3.ZERO
	_transform_axis_key = Vector3.ZERO
	_transform_axis_is_local = false
	_transform_source_points.clear()
	_transform_active_source_index = -1
	_transform_active_point_world = Vector3.ZERO
	_transform_confirm_on_release = false
	_animation_bone_transform = false
	_animation_bone_object_id = ""
	_animation_bone_index = -1
	_animation_bone_basis = Basis.IDENTITY
	_animation_ik_target_transform = false
	_animation_ik_target_object_id = ""
	_snap_marker.visible = false
	transform_status_changed.emit("")
	if _overlay_suppressed and _overlay_restore_timer != null:
		_overlay_restore_timer.start()
	_refresh_transform_gizmo()


func _set_transform_axis(axis: Vector3) -> void:
	var normalized_axis: Vector3 = axis.normalized()
	if _transform_axis_key.is_equal_approx(normalized_axis):
		if not _transform_axis_is_local:
			_transform_axis_is_local = true
			_transform_axis = _get_local_constraint_axis(normalized_axis)
		else:
			_transform_axis_key = Vector3.ZERO
			_transform_axis_is_local = false
			_transform_axis = _transform_custom_axis
	else:
		_transform_axis_key = normalized_axis
		_transform_axis_is_local = false
		_transform_axis = normalized_axis

	_transform_start_plane_point = _ray_plane_intersection(
		_transform_start_mouse,
		_transform_pivot_world,
		_get_move_plane_normal()
	)
	_update_transform(get_local_mouse_position(), false, false)
	_emit_transform_status(false)


func _get_local_constraint_axis(global_axis: Vector3) -> Vector3:
	if _animation_bone_transform:
		if global_axis.abs().is_equal_approx(Vector3.RIGHT):
			return _animation_bone_basis.x.normalized()
		if global_axis.abs().is_equal_approx(Vector3.UP):
			return _animation_bone_basis.y.normalized()
		return _animation_bone_basis.z.normalized()
	if document == null:
		return global_axis
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null:
		return global_axis
	var local_basis: Basis = object.transform.basis.orthonormalized()
	if global_axis.abs().is_equal_approx(Vector3.RIGHT):
		return local_basis.x.normalized()
	if global_axis.abs().is_equal_approx(Vector3.UP):
		return local_basis.y.normalized()
	return local_basis.z.normalized()


func _update_transform(screen_position: Vector2, ctrl_pressed: bool, shift_pressed: bool) -> void:
	if not is_transforming():
		return

	var effective_snap: bool = snap_enabled != ctrl_pressed
	_snap_marker.visible = false

	match _transform_kind:
		TransformKind.MOVE:
			var move_value: Vector3 = _calculate_move(screen_position, effective_snap, shift_pressed)
			_update_transform_gizmo_preview(_transform_kind, move_value, _transform_pivot_world)
			if _animation_bone_transform:
				animation_bone_transform_preview.emit(
					_transform_kind, move_value, _transform_axis, _transform_pivot_world
				)
			elif _animation_ik_target_transform:
				animation_ik_target_transform_preview.emit(move_value)
			else:
				transform_preview.emit(
					_transform_kind, move_value, _transform_axis, _transform_pivot_world
				)
		TransformKind.ROTATE:
			var rotation_axis: Vector3 = _get_rotation_axis()
			var angle: float = _calculate_rotation(screen_position, rotation_axis, effective_snap, shift_pressed)
			_update_transform_gizmo_preview(
				_transform_kind, Vector3(angle, 0.0, 0.0), _transform_pivot_world
			)
			if _animation_bone_transform:
				animation_bone_transform_preview.emit(
					_transform_kind, Vector3(angle, 0.0, 0.0), rotation_axis, _transform_pivot_world
				)
			else:
				transform_preview.emit(
					_transform_kind, Vector3(angle, 0.0, 0.0), rotation_axis, _transform_pivot_world
				)
		TransformKind.SCALE:
			var scale_value: Vector3 = _calculate_scale(screen_position, effective_snap, shift_pressed)
			_update_transform_gizmo_preview(_transform_kind, scale_value, _transform_pivot_world)
			if _animation_bone_transform:
				animation_bone_transform_preview.emit(
					_transform_kind, scale_value, _transform_axis, _transform_pivot_world
				)
			else:
				transform_preview.emit(
					_transform_kind, scale_value, _transform_axis, _transform_pivot_world
				)
	_emit_transform_status(effective_snap)


func _update_transform_gizmo_preview(
	kind: int,
	value: Vector3,
	pivot_world: Vector3
) -> void:
	if _transform_gizmo == null or not _transform_gizmo.visible:
		return
	var preview_pivot: Vector3 = pivot_world
	if kind == TransformKind.MOVE:
		preview_pivot += value
	_transform_gizmo.update_preview_pivot(_camera, size.y, preview_pivot)


func _calculate_move(
	screen_position: Vector2,
	effective_snap: bool,
	precision: bool
) -> Vector3:
	if effective_snap and snap_element == SnapElement.VERTEX:
		var snap_result: Dictionary = _pick_snap_vertex(screen_position)
		if not snap_result.is_empty():
			var target: Vector3 = snap_result["position"]
			var source: Vector3 = _get_snap_base_point(target)
			var snapped_offset: Vector3 = GMSSnapMath.constrain_vector(target - source, _transform_axis)
			_snap_marker.position = target
			_snap_marker.visible = true
			return snapped_offset

	var current_plane_point: Vector3 = _ray_plane_intersection(
		screen_position,
		_transform_pivot_world,
		_get_move_plane_normal()
	)
	var offset: Vector3 = current_plane_point - _transform_start_plane_point
	offset = GMSSnapMath.constrain_vector(offset, _transform_axis)
	if precision:
		offset *= 0.1
	if effective_snap and snap_element == SnapElement.INCREMENT:
		if _transform_axis.is_zero_approx():
			offset = GMSSnapMath.snap_vector(offset, move_increment)
		else:
			var axis: Vector3 = _transform_axis.normalized()
			var amount: float = GMSSnapMath.snap_scalar(offset.dot(axis), move_increment)
			offset = axis * amount
	return offset


func _calculate_rotation(
	screen_position: Vector2,
	axis: Vector3,
	effective_snap: bool,
	precision: bool
) -> float:
	if effective_snap and snap_element == SnapElement.VERTEX:
		var snap_result: Dictionary = _pick_snap_vertex(screen_position)
		if not snap_result.is_empty():
			var target: Vector3 = snap_result["position"]
			var source: Vector3 = _get_snap_base_point(target)
			var source_vector: Vector3 = source - _transform_pivot_world
			var target_vector: Vector3 = target - _transform_pivot_world
			source_vector -= axis * source_vector.dot(axis)
			target_vector -= axis * target_vector.dot(axis)
			if source_vector.length_squared() > 0.000001 and target_vector.length_squared() > 0.000001:
				_snap_marker.position = target
				_snap_marker.visible = true
				return source_vector.signed_angle_to(target_vector, axis)

	var pivot_screen: Vector2 = _camera.unproject_position(_transform_pivot_world)
	var current_vector: Vector2 = screen_position - pivot_screen
	var current_angle: float = atan2(current_vector.y, current_vector.x)
	var angle: float = current_angle - _transform_start_screen_angle
	if precision:
		angle *= 0.1
	if effective_snap and snap_element == SnapElement.INCREMENT:
		var degrees: float = GMSSnapMath.snap_scalar(rad_to_deg(angle), rotate_increment_degrees)
		angle = deg_to_rad(degrees)
	return angle


func _calculate_scale(
	screen_position: Vector2,
	effective_snap: bool,
	precision: bool
) -> Vector3:
	var factor: float = 1.0
	if effective_snap and snap_element == SnapElement.VERTEX:
		var snap_result: Dictionary = _pick_snap_vertex(screen_position)
		if not snap_result.is_empty():
			var target: Vector3 = snap_result["position"]
			var source: Vector3 = _get_snap_base_point(target)
			factor = GMSSnapMath.axis_scale_to_target(
				_transform_pivot_world,
				source,
				target,
				_transform_axis
			)
			_snap_marker.position = target
			_snap_marker.visible = true
		else:
			factor = _mouse_scale_factor(screen_position)
	else:
		factor = _mouse_scale_factor(screen_position)

	if precision:
		factor = 1.0 + (factor - 1.0) * 0.1
	if effective_snap and snap_element == SnapElement.INCREMENT:
		factor = 1.0 + GMSSnapMath.snap_scalar(factor - 1.0, scale_increment)

	if _transform_axis.is_zero_approx():
		return Vector3.ONE * factor




	return Vector3.ONE * factor


func _mouse_scale_factor(screen_position: Vector2) -> float:
	var pivot_screen: Vector2 = _camera.unproject_position(_transform_pivot_world)
	var current_distance: float = (screen_position - pivot_screen).length()
	return current_distance / _transform_start_screen_distance


func _emit_transform_status(effective_snap: bool) -> void:
	if not is_transforming():
		return
	var operation: String = "Move"
	match _transform_kind:
		TransformKind.ROTATE:
			operation = "Rotate"
		TransformKind.SCALE:
			operation = "Scale"

	var axis_text: String = "Free"
	if not _transform_axis_key.is_zero_approx():
		axis_text = "%s %s" % [
			"Local" if _transform_axis_is_local else "Global",
			_axis_name(_transform_axis_key),
		]
	elif not _transform_axis.is_zero_approx():
		axis_text = _axis_name(_transform_axis)

	var snap_text: String = "Snap Off"
	if effective_snap:
		snap_text = "Vertex Snap" if snap_element == SnapElement.VERTEX else "Increment Snap"
	transform_status_changed.emit(
		"%s | %s | %s | X/Y/Z global, press twice for local | Ctrl invert snap | Shift precision | LMB/Enter confirm | RMB/Esc cancel" % [
			operation,
			axis_text,
			snap_text,
		]
	)


func _axis_name(axis: Vector3) -> String:
	var normalized: Vector3 = axis.normalized()
	if normalized.abs().is_equal_approx(Vector3.RIGHT):
		return "X"
	if normalized.abs().is_equal_approx(Vector3.UP):
		return "Y"
	if normalized.abs().is_equal_approx(Vector3.BACK):
		return "Z"
	return "Custom Axis"


func _get_rotation_axis() -> Vector3:
	if not _transform_axis.is_zero_approx():
		return _transform_axis.normalized()
	return -_camera.global_transform.basis.z.normalized()


func _get_move_plane_normal() -> Vector3:
	if not _transform_axis.is_zero_approx():
		var axis: Vector3 = _transform_axis.normalized()
		var camera_forward: Vector3 = -_camera.global_transform.basis.z.normalized()
		var side: Vector3 = axis.cross(camera_forward)
		if side.length_squared() > 0.000001:
			return side.cross(axis).normalized()
	return -_camera.global_transform.basis.z.normalized()


func _ray_plane_intersection(
	screen_position: Vector2,
	plane_point: Vector3,
	plane_normal: Vector3
) -> Vector3:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position).normalized()
	var denominator: float = plane_normal.dot(ray_direction)
	if absf(denominator) <= 0.000001:
		return plane_point
	var distance: float = plane_normal.dot(plane_point - ray_origin) / denominator
	return ray_origin + ray_direction * distance


func _get_transform_source_points(object: GMSModelObject) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	if selection_mode == GMSSelection.Mode.OBJECT:
		for object_id: String in selected_object_ids:
			var selected_object: GMSModelObject = document.get_object(object_id)
			if selected_object == null or selected_object.mesh_data == null:
				continue
			for vertex: Vector3 in selected_object.mesh_data.vertices:
				points.append(selected_object.transform * vertex)
			if selected_object.mesh_data.vertices.is_empty():
				points.append(selected_object.transform.origin)
		if points.is_empty():
			points.append(object.transform.origin)
		return points

	if object.mesh_data == null:
		points.append(object.transform.origin)
		return points
	var indices: PackedInt32Array = GMSMeshOperations.get_selected_vertex_indices(
		object.mesh_data,
		selection_mode,
		selected_vertex_indices,
		selected_edge_indices,
		selected_face_indices
	)
	for vertex_index: int in indices:
		points.append(object.transform * object.mesh_data.vertices[vertex_index])
	return points


func _get_snap_base_point(target: Vector3) -> Vector3:
	if selection_mode == GMSSelection.Mode.OBJECT and snap_base != GMSSnapMath.BaseMode.CLOSEST:
		return _transform_pivot_world
	if snap_base == GMSSnapMath.BaseMode.CENTER:
		return _transform_pivot_world
	if snap_base == GMSSnapMath.BaseMode.ACTIVE:
		return _get_active_snap_point()
	return GMSSnapMath.get_base_point(
		_transform_source_points,
		target,
		snap_base,
		_transform_active_source_index
	)


func _get_active_snap_point() -> Vector3:
	return _transform_active_point_world


func _calculate_active_snap_point(object: GMSModelObject) -> Vector3:
	if object == null or selection_mode == GMSSelection.Mode.OBJECT or object.mesh_data == null:
		return _transform_pivot_world

	match selection_mode:
		GMSSelection.Mode.VERTEX:
			if not selected_vertex_indices.is_empty():
				var vertex_index: int = selected_vertex_indices[selected_vertex_indices.size() - 1]
				if vertex_index >= 0 and vertex_index < object.mesh_data.vertices.size():
					return object.transform * object.mesh_data.vertices[vertex_index]
		GMSSelection.Mode.EDGE:
			if not selected_edge_indices.is_empty():
				var edges: Array[Vector2i] = object.mesh_data.get_edges()
				var edge_index: int = selected_edge_indices[selected_edge_indices.size() - 1]
				if edge_index >= 0 and edge_index < edges.size():
					var edge: Vector2i = edges[edge_index]
					var a: Vector3 = object.transform * object.mesh_data.vertices[edge.x]
					var b: Vector3 = object.transform * object.mesh_data.vertices[edge.y]
					return a.lerp(b, 0.5)
		GMSSelection.Mode.FACE:
			if not selected_face_indices.is_empty():
				var face_index: int = selected_face_indices[selected_face_indices.size() - 1]
				if face_index >= 0 and face_index < object.mesh_data.faces.size():
					return object.transform * object.mesh_data.get_face_center(face_index)

	return _transform_pivot_world


func _get_transform_pivot(object: GMSModelObject) -> Vector3:
	if pivot_mode == PivotMode.OBJECT_ORIGIN:
		return object.transform.origin
	if pivot_mode == PivotMode.ACTIVE:
		if selection_mode == GMSSelection.Mode.OBJECT:
			return object.transform.origin
		return _calculate_active_snap_point(object)
	if selection_mode == GMSSelection.Mode.OBJECT and document != null:
		var origin_pivot: Vector3 = Vector3.ZERO
		var origin_count: int = 0
		for object_id: String in selected_object_ids:
			var selected_object: GMSModelObject = document.get_object(object_id)
			if selected_object == null:
				continue
			origin_pivot += selected_object.transform.origin
			origin_count += 1
		if origin_count > 0:
			return origin_pivot / float(origin_count)
	if _transform_source_points.is_empty():
		return object.transform.origin
	var pivot: Vector3 = Vector3.ZERO
	for point: Vector3 in _transform_source_points:
		pivot += point
	return pivot / float(_transform_source_points.size())


func _get_active_source_index(object: GMSModelObject) -> int:
	if selection_mode == GMSSelection.Mode.OBJECT:
		return -1
	if object.mesh_data == null or _transform_source_points.is_empty():
		return -1
	return _transform_source_points.size() - 1


func _pick_snap_vertex(screen_position: Vector2) -> Dictionary:
	if document == null:
		return {}
	var best_screen_distance: float = SNAP_VERTEX_RADIUS * SNAP_VERTEX_RADIUS
	var best_depth: float = INF
	var best_result: Dictionary = {}
	var selected_mesh_vertices: PackedInt32Array = PackedInt32Array()
	var selected_object: GMSModelObject = document.get_object(selected_object_id)
	if selected_object != null and selected_object.mesh_data != null and selection_mode != GMSSelection.Mode.OBJECT:
		selected_mesh_vertices = GMSMeshOperations.get_selected_vertex_indices(
			selected_object.mesh_data,
			selection_mode,
			selected_vertex_indices,
			selected_edge_indices,
			selected_face_indices
		)
	var occlusion_depth: float = INF
	if not xray_enabled:
		var face_hit: Dictionary = _pick_face(screen_position)
		occlusion_depth = float(face_hit.get("distance", INF))
	for object: GMSModelObject in document.objects:
		if object == null or not object.visible or object.mesh_data == null:
			continue
		if selection_mode == GMSSelection.Mode.OBJECT and object.object_id == selected_object_id:
			continue
		var projection: Dictionary = _get_projection_data(object, object.mesh_data)
		var candidates: PackedInt32Array = _get_grid_candidates(
			projection["vertex_grid"], screen_position, SNAP_VERTEX_RADIUS
		)
		var screens: PackedVector2Array = projection["screen_positions"]
		var depths: PackedFloat32Array = projection["depths"]
		var behind: PackedByteArray = projection["behind"]
		var worlds: PackedVector3Array = projection["world_positions"]
		for vertex_index: int in candidates:
			if object.object_id == selected_object_id and selected_mesh_vertices.has(vertex_index):
				continue
			if behind[vertex_index] != 0:
				continue
			var screen_distance: float = screens[vertex_index].distance_squared_to(screen_position)
			if screen_distance > best_screen_distance:
				continue
			var depth: float = depths[vertex_index]
			if not xray_enabled and not _depth_is_visible(depth, occlusion_depth):
				continue
			if screen_distance < best_screen_distance or (
				is_equal_approx(screen_distance, best_screen_distance) and depth < best_depth
			):
				best_screen_distance = screen_distance
				best_depth = depth
				best_result = {
					"object_id": object.object_id,
					"vertex_index": vertex_index,
					"position": worlds[vertex_index],
				}
	return best_result


func _zoom_camera(factor: float) -> void:
	factor = maxf(factor, 0.05)
	if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		_camera.size = clampf(_camera.size * factor, 0.05, 5000.0)
	else:
		_camera_distance = clampf(_camera_distance * factor, 0.4, 500.0)
	_update_camera()


func _set_axis_view(direction: Vector3, up: Vector3) -> void:
	var normalized_direction: Vector3 = direction.normalized()
	_camera.position = _camera_target + normalized_direction * _camera_distance
	_camera.look_at(_camera_target, up)
	_update_view_orientation_gizmo()
	if absf(normalized_direction.z) > 0.999:
		_camera_yaw = 0.0 if normalized_direction.z > 0.0 else PI
		_camera_pitch = 0.0
	elif absf(normalized_direction.x) > 0.999:
		_camera_yaw = PI * 0.5 if normalized_direction.x > 0.0 else -PI * 0.5
		_camera_pitch = 0.0
	else:
		_camera_pitch = deg_to_rad(88.0) if normalized_direction.y > 0.0 else deg_to_rad(-88.0)
	_invalidate_view_caches()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()
	if not _overlay_suppressed and selection_mode == GMSSelection.Mode.FACE:
		_refresh_edit_overlay()


func _toggle_projection() -> void:
	if _camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = maxf(2.0, _camera_distance)
	else:
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return
	var horizontal: float = cos(_camera_pitch) * _camera_distance
	var offset: Vector3 = Vector3(
		sin(_camera_yaw) * horizontal,
		sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal
	)
	_camera.position = _camera_target + offset
	_camera.look_at(_camera_target, Vector3.UP)
	_reset_rig_brush_hit_cache()
	_update_view_orientation_gizmo()
	_invalidate_view_caches()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()
	if not _overlay_suppressed and selection_mode == GMSSelection.Mode.FACE:
		_refresh_edit_overlay()



func _update_view_orientation_gizmo() -> void:
	if _view_orientation_gizmo == null or _camera == null:
		return
	_view_orientation_gizmo.set_camera_basis(_camera.global_transform.basis)

func _invalidate_view_caches() -> void:
	_camera_revision += 1
	_projection_cache.clear()
	_visibility_depth_cache.clear()


func _clear_spatial_caches() -> void:
	_spatial_index_cache.clear()
	_surface_vertex_map_cache.clear()
	_projection_cache.clear()
	_visibility_depth_cache.clear()


func _invalidate_object_projection_cache(object_id: String) -> void:
	_projection_cache.erase(object_id)
	_visibility_depth_cache.clear()


func _invalidate_object_spatial_caches(object_id: String) -> void:
	_spatial_index_cache.erase(object_id)
	_surface_vertex_map_cache.erase(object_id)
	_invalidate_object_projection_cache(object_id)


func _suppress_interaction_overlays(restore_soon: bool = false) -> void:
	_overlay_suppressed = true
	if _edit_overlay_root != null:
		_edit_overlay_root.visible = false
	if _rig_overlay != null:
		_rig_overlay.visible = false
	if restore_soon and _overlay_restore_timer != null:
		_overlay_restore_timer.start()


func _restore_interaction_overlays() -> void:
	_overlay_suppressed = false
	_refresh_edit_overlay()
	_refresh_rig_overlay()


func _poll_async_evaluations() -> void:
	_poll_spatial_index_tasks()
	_poll_position_mesh_tasks()
	_poll_position_mesh_rebuilds()
	if document == null:
		return
	for object: GMSModelObject in document.objects:
		if object == null or not object.poll_async_evaluation():
			continue
		_invalidate_object_spatial_caches(object.object_id)
		_update_object_node(
			object.object_id,
			GMSDocument.ChangeFlags.GEOMETRY | GMSDocument.ChangeFlags.MODIFIERS
		)
		if object.object_id == selected_object_id:
			_refresh_transform_gizmo()
		async_evaluation_completed.emit(object.object_id)


func _poll_position_mesh_rebuilds() -> void:
	if document == null or _position_rebuild_deadlines.is_empty() or is_transforming():
		return
	var now: int = Time.get_ticks_msec()
	var completed: PackedStringArray = PackedStringArray()
	for object_id_value: Variant in _position_rebuild_deadlines.keys():
		var object_id: String = str(object_id_value)
		if now < int(_position_rebuild_deadlines[object_id]):
			continue
		if _position_mesh_tasks.has(object_id):
			continue
		var object: GMSModelObject = document.get_object(object_id)
		var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
		if object == null or mesh_node == null:
			completed.append(object_id)
			continue
		if object.supports_dynamic_vertex_preview():
			_request_position_mesh_task(object)
		else:
			mesh_node.mesh = object.force_rebuild_array_mesh()
			completed.append(object_id)
	for object_id: String in completed:
		_position_rebuild_deadlines.erase(object_id)


func _request_position_mesh_task(object: GMSModelObject) -> void:
	if object == null or object.mesh_data == null or _position_mesh_tasks.has(object.object_id):
		return
	var source_mesh: GMSMeshData = object.mesh_data
	var source_vertices: PackedVector3Array = source_mesh.vertices
	var source_faces: Array[PackedInt32Array] = []
	source_faces.resize(source_mesh.faces.size())
	for face_index: int in source_mesh.faces.size():
		source_faces[face_index] = source_mesh.faces[face_index]
	var source_materials: PackedInt32Array = source_mesh.face_materials
	var material_count: int = maxi(object.materials.size(), 1)
	var revision: int = source_mesh.get_change_revision()
	var holder: Dictionary = {}
	var action: Callable = func() -> void:
		holder["surfaces"] = GMSMeshData.build_indexed_smooth_surface_arrays(
			source_vertices, source_faces, source_materials, material_count
		)
	var task_id: int = WorkerThreadPool.add_task(
		action, false, "Gator Model Studio dense position mesh rebuild"
	)
	_position_mesh_tasks[object.object_id] = {
		"task_id": task_id,
		"holder": holder,
		"revision": revision,
	}


func _poll_position_mesh_tasks() -> void:
	if document == null or _position_mesh_tasks.is_empty():
		return
	var completed: PackedStringArray = PackedStringArray()
	for object_id_value: Variant in _position_mesh_tasks.keys():
		var object_id: String = str(object_id_value)
		if object_id == _dynamic_preview_object_id:
			continue
		var task: Dictionary = _position_mesh_tasks[object_id]
		var task_id: int = int(task.get("task_id", -1))
		if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		var object: GMSModelObject = document.get_object(object_id)
		var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
		var revision: int = int(task.get("revision", -1))
		if (
			object != null
			and object.mesh_data != null
			and object.mesh_data.get_change_revision() == revision
			and mesh_node != null
		):
			var holder: Dictionary = task["holder"]
			var surfaces: Array = holder.get("surfaces", [])
			var rebuilt: ArrayMesh = ArrayMesh.new()
			for surface_value: Variant in surfaces:
				var surface: Dictionary = surface_value
				var arrays: Array = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = surface["vertices"]
				arrays[Mesh.ARRAY_NORMAL] = surface["normals"]
				arrays[Mesh.ARRAY_INDEX] = surface["indices"]
				rebuilt.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
				)
				var slot_index: int = int(surface["slot"])
				if slot_index >= 0 and slot_index < object.materials.size():
					rebuilt.surface_set_material(
						rebuilt.get_surface_count() - 1, object.materials[slot_index]
					)
			var direct_maps: Array[Dictionary] = []
			for surface_index: int in rebuilt.get_surface_count():
				direct_maps.append({
					"direct": true,
					"render_vertex_count": object.mesh_data.vertices.size(),
					"render_to_model": PackedInt32Array(),
					"offsets": PackedInt32Array(),
					"occurrences": PackedInt32Array(),
				})
			rebuilt.set_meta("_gms_surface_vertex_maps", direct_maps)
			_surface_vertex_map_cache[object_id] = {
				"mesh": object.mesh_data,
				"maps": direct_maps,
			}
			object.adopt_rebuilt_array_mesh(rebuilt)
			mesh_node.mesh = rebuilt
			_position_rebuild_deadlines.erase(object_id)
		else:
			_position_rebuild_deadlines[object_id] = Time.get_ticks_msec() + POSITION_REBUILD_DELAY_MSEC
		completed.append(object_id)
	for object_id: String in completed:
		_position_mesh_tasks.erase(object_id)


func get_hovered_edge() -> Dictionary:
	if selection_mode != GMSSelection.Mode.EDGE or _camera == null:
		return {}
	return _pick_edge(_last_pointer_position)


func _pick_selection(
	screen_position: Vector2,
	additive: bool,
	edge_pattern: int = EdgeSelectionPattern.SINGLE
) -> void:
	if _camera == null or document == null:
		return

	var result: Dictionary = {}
	match selection_mode:
		GMSSelection.Mode.VERTEX:
			result = _pick_vertex(screen_position)
		GMSSelection.Mode.EDGE:
			result = _pick_edge(screen_position)
		GMSSelection.Mode.FACE:
			result = _pick_face(screen_position)
		_:
			result = _pick_face(screen_position)

	if result.is_empty():
		selection_clicked.emit("", -1, additive, EdgeSelectionPattern.SINGLE)
		return

	var component_index: int = -1
	if selection_mode != GMSSelection.Mode.OBJECT:
		component_index = int(result.get("component_index", -1))
	selection_clicked.emit(
		str(result.get("object_id", "")),
		component_index,
		additive,
		edge_pattern if selection_mode == GMSSelection.Mode.EDGE else EdgeSelectionPattern.SINGLE
	)


func _pick_face(screen_position: Vector2) -> Dictionary:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position).normalized()
	var best_distance: float = INF
	var best_result: Dictionary = {}
	for object: GMSModelObject in document.objects:
		if not _is_object_pickable(object) or object.mesh_data == null:
			continue
		var mesh: GMSMeshData = object.mesh_data
		if selection_mode == GMSSelection.Mode.OBJECT:
			mesh = object.get_evaluated_mesh_data()
		if mesh == null or mesh.faces.is_empty():
			continue
		var inverse: Transform3D = object.transform.affine_inverse()
		var local_origin: Vector3 = inverse * ray_origin
		var local_direction: Vector3 = inverse.basis * ray_direction
		var spatial_index: GMSMeshSpatialIndex = _get_spatial_index(object.object_id, mesh)
		if spatial_index == null:
			continue
		var hit: Dictionary = spatial_index.raycast(local_origin, local_direction)
		if hit.is_empty():
			continue
		var local_hit: Vector3 = hit["position"]
		var world_hit: Vector3 = object.transform * local_hit
		var world_distance: float = ray_origin.distance_to(world_hit)
		if world_distance < best_distance:
			best_distance = world_distance
			best_result = {
				"object_id": object.object_id,
				"component_index": int(hit["face_index"]),
				"distance": world_distance,
				"local_hit": local_hit,
				"world_hit": world_hit,
			}
	return best_result


func _pick_vertex(screen_position: Vector2) -> Dictionary:
	var best_screen_distance: float = VERTEX_PICK_RADIUS * VERTEX_PICK_RADIUS
	var best_depth: float = INF
	var best_result: Dictionary = {}
	var face_hit: Dictionary = {}
	var occlusion_depth: float = INF
	if not xray_enabled:
		face_hit = _pick_face(screen_position)
		occlusion_depth = float(face_hit.get("distance", INF))
		var dense_object: GMSModelObject = document.get_object(
			str(face_hit.get("object_id", ""))
		) if document != null else null
		if (
			dense_object != null
			and dense_object.mesh_data != null
			and dense_object.mesh_data.vertices.size() >= DENSE_LOCAL_PICK_VERTEX_THRESHOLD
		):
			return _pick_vertex_from_hit_face(
				dense_object,
				int(face_hit.get("component_index", -1)),
				screen_position
			)
		var selected_dense_object: GMSModelObject = document.get_object(selected_object_id)
		if (
			face_hit.is_empty()
			and selected_dense_object != null
			and selected_dense_object.mesh_data != null
			and selected_dense_object.mesh_data.vertices.size() >= DENSE_LOCAL_PICK_VERTEX_THRESHOLD
		):
			return {}
	for object: GMSModelObject in document.objects:
		if not _is_object_pickable(object) or object.mesh_data == null:
			continue
		var projection: Dictionary = _get_projection_data(object, object.mesh_data)
		var candidates: PackedInt32Array = _get_grid_candidates(
			projection["vertex_grid"], screen_position, VERTEX_PICK_RADIUS
		)
		var screen_positions: PackedVector2Array = projection["screen_positions"]
		var depths: PackedFloat32Array = projection["depths"]
		var behind: PackedByteArray = projection["behind"]
		for vertex_index: int in candidates:
			if behind[vertex_index] != 0:
				continue
			var projected: Vector2 = screen_positions[vertex_index]
			var screen_distance: float = projected.distance_squared_to(screen_position)
			if screen_distance > best_screen_distance:
				continue
			var depth: float = depths[vertex_index]
			if not xray_enabled and not _depth_is_visible(depth, occlusion_depth):
				continue
			if screen_distance < best_screen_distance or (
				is_equal_approx(screen_distance, best_screen_distance) and depth < best_depth
			):
				best_screen_distance = screen_distance
				best_depth = depth
				best_result = {
					"object_id": object.object_id,
					"component_index": vertex_index,
					"distance": depth,
				}
	return best_result


func _pick_vertex_from_hit_face(
	object: GMSModelObject,
	face_index: int,
	screen_position: Vector2
) -> Dictionary:
	var mesh: GMSMeshData = object.mesh_data
	if mesh == null or face_index < 0 or face_index >= mesh.faces.size():
		return {}
	var best_distance: float = VERTEX_PICK_RADIUS * VERTEX_PICK_RADIUS
	var best_depth: float = INF
	var best_vertex: int = -1
	for vertex_index: int in mesh.faces[face_index]:
		var world_position: Vector3 = object.transform * mesh.vertices[vertex_index]
		if _camera.is_position_behind(world_position):
			continue
		var projected: Vector2 = _camera.unproject_position(world_position)
		var distance: float = projected.distance_squared_to(screen_position)
		var depth: float = _camera.global_position.distance_to(world_position)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and depth < best_depth):
			best_distance = distance
			best_depth = depth
			best_vertex = vertex_index
	if best_vertex < 0:
		return {}
	return {
		"object_id": object.object_id,
		"component_index": best_vertex,
		"distance": best_depth,
	}


func _pick_edge(screen_position: Vector2) -> Dictionary:
	var best_screen_distance: float = EDGE_PICK_RADIUS * EDGE_PICK_RADIUS
	var best_depth: float = INF
	var best_result: Dictionary = {}
	var face_hit: Dictionary = {}
	var occlusion_depth: float = INF
	if not xray_enabled:
		face_hit = _pick_face(screen_position)
		occlusion_depth = float(face_hit.get("distance", INF))
		var dense_object: GMSModelObject = document.get_object(
			str(face_hit.get("object_id", ""))
		) if document != null else null
		if (
			dense_object != null
			and dense_object.mesh_data != null
			and dense_object.mesh_data.vertices.size() >= DENSE_LOCAL_PICK_VERTEX_THRESHOLD
		):
			return _pick_edge_from_hit_face(
				dense_object,
				int(face_hit.get("component_index", -1)),
				screen_position
			)
		var selected_dense_object: GMSModelObject = document.get_object(selected_object_id)
		if (
			face_hit.is_empty()
			and selected_dense_object != null
			and selected_dense_object.mesh_data != null
			and selected_dense_object.mesh_data.vertices.size() >= DENSE_LOCAL_PICK_VERTEX_THRESHOLD
		):
			return {}
	for object: GMSModelObject in document.objects:
		if not _is_object_pickable(object) or object.mesh_data == null:
			continue
		var mesh: GMSMeshData = object.mesh_data
		var projection: Dictionary = _get_projection_data(object, mesh)
		var candidates: PackedInt32Array = _get_grid_candidates(
			_get_edge_grid(object, mesh, projection), screen_position, EDGE_PICK_RADIUS
		)
		var edges: Array[Vector2i] = mesh.get_edges()
		var screens: PackedVector2Array = projection["screen_positions"]
		var depths: PackedFloat32Array = projection["depths"]
		var behind: PackedByteArray = projection["behind"]
		for edge_index: int in candidates:
			if edge_index < 0 or edge_index >= edges.size():
				continue
			var edge: Vector2i = edges[edge_index]
			if behind[edge.x] != 0 and behind[edge.y] != 0:
				continue
			var screen_a: Vector2 = screens[edge.x]
			var screen_b: Vector2 = screens[edge.y]
			var parameter: float = _point_segment_parameter(screen_position, screen_a, screen_b)
			var screen_distance: float = screen_position.distance_squared_to(screen_a.lerp(screen_b, parameter))
			if screen_distance > best_screen_distance:
				continue
			var depth: float = lerpf(depths[edge.x], depths[edge.y], parameter)
			if not xray_enabled and not _depth_is_visible(depth, occlusion_depth):
				continue
			if screen_distance < best_screen_distance or (
				is_equal_approx(screen_distance, best_screen_distance) and depth < best_depth
			):
				best_screen_distance = screen_distance
				best_depth = depth
				best_result = {
					"object_id": object.object_id,
					"component_index": edge_index,
					"distance": depth,
				}
	return best_result


func _pick_edge_from_hit_face(
	object: GMSModelObject,
	face_index: int,
	screen_position: Vector2
) -> Dictionary:
	var mesh: GMSMeshData = object.mesh_data
	if mesh == null or face_index < 0 or face_index >= mesh.faces.size():
		return {}
	var face: PackedInt32Array = mesh.faces[face_index]
	var best_distance: float = EDGE_PICK_RADIUS * EDGE_PICK_RADIUS
	var best_depth: float = INF
	var best_edge_index: int = -1
	for corner_index: int in face.size():
		var vertex_a: int = face[corner_index]
		var vertex_b: int = face[(corner_index + 1) % face.size()]
		var world_a: Vector3 = object.transform * mesh.vertices[vertex_a]
		var world_b: Vector3 = object.transform * mesh.vertices[vertex_b]
		if _camera.is_position_behind(world_a) and _camera.is_position_behind(world_b):
			continue
		var screen_a: Vector2 = _camera.unproject_position(world_a)
		var screen_b: Vector2 = _camera.unproject_position(world_b)
		var parameter: float = _point_segment_parameter(screen_position, screen_a, screen_b)
		var distance: float = screen_position.distance_squared_to(screen_a.lerp(screen_b, parameter))
		var depth: float = lerpf(
			_camera.global_position.distance_to(world_a),
			_camera.global_position.distance_to(world_b),
			parameter
		)
		if distance < best_distance or (is_equal_approx(distance, best_distance) and depth < best_depth):
			best_distance = distance
			best_depth = depth
			best_edge_index = mesh.get_edge_index(vertex_a, vertex_b)
	if best_edge_index < 0:
		return {}
	return {
		"object_id": object.object_id,
		"component_index": best_edge_index,
		"distance": best_depth,
	}


func _get_surface_vertex_maps(
	object_id: String,
	mesh: GMSMeshData,
	surface_count: int
) -> Array:
	var cached: Dictionary = _surface_vertex_map_cache.get(object_id, {})
	if cached.get("mesh") == mesh:
		var cached_maps: Array = cached.get("maps", [])
		if cached_maps.size() == surface_count:
			return cached_maps
	var object: GMSModelObject = document.get_object(object_id) if document != null else null
	var material_count: int = maxi(object.materials.size(), 1) if object != null else 1
	var maps: Array[Dictionary] = GMSMeshData.build_surface_vertex_maps(
		mesh, material_count
	)
	if maps.size() == surface_count:
		_surface_vertex_map_cache[object_id] = {
			"mesh": mesh,
			"maps": maps,
		}
	return maps


func _get_spatial_index(object_id: String, mesh: GMSMeshData) -> GMSMeshSpatialIndex:
	var cached: GMSMeshSpatialIndex = _spatial_index_cache.get(object_id) as GMSMeshSpatialIndex
	if cached != null and cached.is_current(mesh):
		return cached
	if mesh.faces.size() >= DENSE_SPATIAL_INDEX_FACE_THRESHOLD:
		_request_spatial_index_build(object_id, mesh)
		transform_status_changed.emit("Preparing dense mesh selection data in the background...")
		return null
	cached = GMSMeshSpatialIndex.new(mesh)
	mesh.install_precomputed_edges(
		cached.face_edges, cached.all_edges, cached.edge_lookup, cached.mesh_revision
	)
	_spatial_index_cache[object_id] = cached
	return cached


func _request_spatial_index_build(object_id: String, mesh: GMSMeshData) -> void:
	if mesh == null:
		return
	var cached: GMSMeshSpatialIndex = _spatial_index_cache.get(object_id) as GMSMeshSpatialIndex
	if cached != null and cached.is_current(mesh):
		return
	var task_key: String = "%s:%d:%d" % [
		object_id, mesh.get_instance_id(), mesh.get_change_revision()
	]
	if _spatial_index_tasks.has(task_key):
		return
	var holder: Dictionary = {}
	var source_mesh: GMSMeshData = mesh
	var source_object: GMSModelObject = document.get_object(object_id) if document != null else null
	var material_count: int = maxi(source_object.materials.size(), 1) if source_object != null else 1
	var action: Callable = func() -> void:
		holder["index"] = GMSMeshSpatialIndex.new(source_mesh)
		holder["surface_maps"] = GMSMeshData.build_surface_vertex_maps(
			source_mesh, material_count
		)
	var task_id: int = WorkerThreadPool.add_task(
		action, false, "Gator Model Studio dense mesh selection index"
	)
	_spatial_index_tasks[task_key] = {
		"task_id": task_id,
		"holder": holder,
		"mesh": mesh,
		"object_id": object_id,
	}


func _poll_spatial_index_tasks() -> void:
	var completed_keys: Array[String] = []
	for task_key_value: Variant in _spatial_index_tasks.keys():
		var task_key: String = str(task_key_value)
		var task: Dictionary = _spatial_index_tasks[task_key]
		var task_id: int = int(task.get("task_id", -1))
		if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
			continue
		WorkerThreadPool.wait_for_task_completion(task_id)
		var holder: Dictionary = task["holder"]
		var index: GMSMeshSpatialIndex = holder.get("index") as GMSMeshSpatialIndex
		var source_mesh: GMSMeshData = task["mesh"] as GMSMeshData
		var object_id: String = str(task["object_id"])
		if index != null and source_mesh != null and index.is_current(source_mesh):
			source_mesh.install_precomputed_edges(
				index.face_edges, index.all_edges, index.edge_lookup, index.mesh_revision
			)
			var object: GMSModelObject = document.get_object(object_id) if document != null else null
			var current_mesh: GMSMeshData = object.get_evaluated_mesh_data() if object != null else null
			if object != null and current_mesh == source_mesh:
				_spatial_index_cache[object_id] = index
				var surface_maps: Array = holder.get("surface_maps", [])
				if not surface_maps.is_empty():
					_surface_vertex_map_cache[object_id] = {
						"mesh": source_mesh,
						"maps": surface_maps,
					}
				async_evaluation_completed.emit(object_id)
				transform_status_changed.emit("Dense mesh selection data is ready.")
		completed_keys.append(task_key)
	for task_key: String in completed_keys:
		_spatial_index_tasks.erase(task_key)


func _get_projection_data(object: GMSModelObject, mesh: GMSMeshData) -> Dictionary:
	var cached: Dictionary = _projection_cache.get(object.object_id, {})
	if (
		not cached.is_empty()
		and cached.get("mesh") == mesh
		and int(cached.get("mesh_revision", -1)) == mesh.get_change_revision()
		and int(cached.get("camera_revision", -1)) == _camera_revision
		and cached.get("transform") == object.transform
	):
		return cached
	var world_positions: PackedVector3Array = PackedVector3Array()
	var screen_positions: PackedVector2Array = PackedVector2Array()
	var depths: PackedFloat32Array = PackedFloat32Array()
	var behind: PackedByteArray = PackedByteArray()
	world_positions.resize(mesh.vertices.size())
	screen_positions.resize(mesh.vertices.size())
	depths.resize(mesh.vertices.size())
	behind.resize(mesh.vertices.size())
	var vertex_grid: Dictionary = {}
	for vertex_index: int in mesh.vertices.size():
		var world_position: Vector3 = object.transform * mesh.vertices[vertex_index]
		world_positions[vertex_index] = world_position
		var is_behind: bool = _camera.is_position_behind(world_position)
		behind[vertex_index] = 1 if is_behind else 0
		if is_behind:
			continue
		var screen_position: Vector2 = _camera.unproject_position(world_position)
		screen_positions[vertex_index] = screen_position
		depths[vertex_index] = _camera.global_position.distance_to(world_position)
		_append_grid_index(vertex_grid, _screen_cell(screen_position), vertex_index)
	var face_screen_positions: PackedVector2Array = PackedVector2Array()
	var face_depths: PackedFloat32Array = PackedFloat32Array()
	var face_behind: PackedByteArray = PackedByteArray()
	var face_grid: Dictionary = {}
	var edge_grid: Dictionary = {}
	cached = {
		"mesh": mesh,
		"mesh_revision": mesh.get_change_revision(),
		"camera_revision": _camera_revision,
		"transform": object.transform,
		"world_positions": world_positions,
		"screen_positions": screen_positions,
		"depths": depths,
		"behind": behind,
		"vertex_grid": vertex_grid,
		"face_screen_positions": face_screen_positions,
		"face_depths": face_depths,
		"face_behind": face_behind,
		"face_grid": face_grid,
		"face_grid_ready": false,
		"edge_grid": edge_grid,
		"edge_grid_ready": false,
	}
	_projection_cache[object.object_id] = cached
	return cached


func _ensure_face_projection_data(
	object: GMSModelObject,
	mesh: GMSMeshData,
	projection: Dictionary
) -> Dictionary:
	if bool(projection.get("face_grid_ready", false)):
		return projection
	var face_screen_positions: PackedVector2Array = PackedVector2Array()
	var face_depths: PackedFloat32Array = PackedFloat32Array()
	var face_behind: PackedByteArray = PackedByteArray()
	face_screen_positions.resize(mesh.faces.size())
	face_depths.resize(mesh.faces.size())
	face_behind.resize(mesh.faces.size())
	var face_grid: Dictionary = {}
	for face_index: int in mesh.faces.size():
		var world_center: Vector3 = object.transform * mesh.get_face_center(face_index)
		var center_behind: bool = _camera.is_position_behind(world_center)
		face_behind[face_index] = 1 if center_behind else 0
		if center_behind:
			continue
		var center_screen: Vector2 = _camera.unproject_position(world_center)
		face_screen_positions[face_index] = center_screen
		face_depths[face_index] = _camera.global_position.distance_to(world_center)
		_append_grid_index(face_grid, _screen_cell(center_screen), face_index)
	projection["face_screen_positions"] = face_screen_positions
	projection["face_depths"] = face_depths
	projection["face_behind"] = face_behind
	projection["face_grid"] = face_grid
	projection["face_grid_ready"] = true
	_projection_cache[object.object_id] = projection
	return projection


func _get_edge_grid(object: GMSModelObject, mesh: GMSMeshData, projection: Dictionary) -> Dictionary:
	if bool(projection.get("edge_grid_ready", false)):
		return projection["edge_grid"]
	var edge_grid: Dictionary = {}
	var edges: Array[Vector2i] = mesh.get_edges()
	var screen_positions: PackedVector2Array = projection["screen_positions"]
	var behind: PackedByteArray = projection["behind"]
	for edge_index: int in edges.size():
		var edge: Vector2i = edges[edge_index]
		if behind[edge.x] != 0 or behind[edge.y] != 0:
			continue
		var a: Vector2 = screen_positions[edge.x]
		var b: Vector2 = screen_positions[edge.y]
		var steps: int = clampi(int(ceil(a.distance_to(b) / PICK_GRID_CELL_SIZE)), 1, 256)
		for step: int in range(steps + 1):
			_append_grid_index(
				edge_grid,
				_screen_cell(a.lerp(b, float(step) / float(steps))),
				edge_index
			)
	projection["edge_grid"] = edge_grid
	projection["edge_grid_ready"] = true
	_projection_cache[object.object_id] = projection
	return edge_grid


func _append_grid_index(grid: Dictionary, cell: Vector2i, index: int) -> void:
	var values: Array = grid.get(cell, [])
	if values.is_empty() or int(values[values.size() - 1]) != index:
		values.append(index)
	grid[cell] = values


func _get_grid_candidates(grid: Dictionary, screen_position: Vector2, radius: float) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var known: Dictionary = {}
	var center: Vector2i = _screen_cell(screen_position)
	var cell_radius: int = maxi(1, int(ceil(radius / PICK_GRID_CELL_SIZE)))
	for y: int in range(center.y - cell_radius, center.y + cell_radius + 1):
		for x: int in range(center.x - cell_radius, center.x + cell_radius + 1):
			var values: Array = grid.get(Vector2i(x, y), [])
			for index: int in values:
				if not known.has(index):
					known[index] = true
					result.append(index)
	return result


func _screen_cell(screen_position: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(screen_position.x / PICK_GRID_CELL_SIZE)),
		int(floor(screen_position.y / PICK_GRID_CELL_SIZE))
	)


func _is_world_point_visible(world_position: Vector3) -> bool:
	if xray_enabled or _camera == null:
		return true
	if _camera.is_position_behind(world_position):
		return false
	var screen_position: Vector2 = _camera.unproject_position(world_position)
	var candidate_depth: float = _camera.global_position.distance_to(world_position)
	return _is_screen_depth_visible(screen_position, candidate_depth)


func _is_screen_depth_visible(screen_position: Vector2, candidate_depth: float) -> bool:
	if xray_enabled:
		return true
	var cell: Vector2i = Vector2i(
		int(floor(screen_position.x / 12.0)),
		int(floor(screen_position.y / 12.0))
	)
	var cache_key: Vector3i = Vector3i(_camera_revision, cell.x, cell.y)
	var hit_depth: float
	if _visibility_depth_cache.has(cache_key):
		hit_depth = float(_visibility_depth_cache[cache_key])
	else:
		var hit: Dictionary = _pick_face(screen_position)
		hit_depth = float(hit.get("distance", INF))
		_visibility_depth_cache[cache_key] = hit_depth
	return _depth_is_visible(candidate_depth, hit_depth)


func _depth_is_visible(candidate_depth: float, hit_depth: float) -> bool:
	if is_inf(hit_depth):
		return true
	var tolerance: float = maxf(0.002, candidate_depth * 0.002)
	return candidate_depth <= hit_depth + tolerance


func _is_object_pickable(object: GMSModelObject) -> bool:
	return object != null and object.visible and not object.locked


static func _point_segment_parameter(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment: Vector2 = b - a
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return 0.0
	return clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)


static func _point_segment_distance_squared(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_squared_to(a.lerp(b, _point_segment_parameter(point, a, b)))


func _pick_gizmo_axis(screen_position: Vector2) -> int:
	if workspace_mode == WorkspaceMode.RIG or _transform_gizmo == null or is_transforming():
		return -1
	return _transform_gizmo.pick_axis(_camera, screen_position)


func _update_gizmo_hover(screen_position: Vector2) -> void:
	if _transform_gizmo == null:
		return
	_transform_gizmo.set_hovered_axis(_pick_gizmo_axis(screen_position))


func _refresh_transform_gizmo() -> void:
	if _transform_gizmo == null or _camera == null:
		return

	var object: GMSModelObject = null
	if document != null:
		object = document.get_object(selected_object_id)
	var can_show: bool = gizmo_visible and object != null and object.visible and not object.locked
	var pivot: Vector3 = Vector3.ZERO
	var basis: Basis = Basis.IDENTITY

	var displayed_gizmo_mode: int = gizmo_mode
	if can_show and workspace_mode == WorkspaceMode.ANIMATE:
		var has_active_ik_control: bool = (
			_animation_guide_show_ik
			and _animation_guide_object_id == selected_object_id
			and _animation_ik_control != AnimationIKControl.NONE
		)
		if has_active_ik_control:
			var local_control_position: Vector3 = (
				_animation_guide_pole_position
				if _animation_ik_control == AnimationIKControl.POLE
				else _animation_guide_target_position
			)
			pivot = object.transform * local_control_position
			basis = object.transform.basis.orthonormalized()
			displayed_gizmo_mode = GMSTransformGizmo.Mode.MOVE
		else:
			var skeleton: Skeleton3D = _skeleton_nodes.get(selected_object_id) as Skeleton3D
			if skeleton == null or selected_bone_index < 0 or selected_bone_index >= skeleton.get_bone_count():
				can_show = false
			else:
				var bone_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(selected_bone_index)
				pivot = bone_world.origin
				basis = bone_world.basis.orthonormalized()
	elif can_show and workspace_mode == WorkspaceMode.MODEL:
		if selection_mode == GMSSelection.Mode.OBJECT:
			pivot = object.transform.origin
		else:
			var selected_indices: PackedInt32Array = GMSMeshOperations.get_selected_vertex_indices(
				object.mesh_data,
				selection_mode,
				selected_vertex_indices,
				selected_edge_indices,
				selected_face_indices
			)
			if selected_indices.is_empty():
				can_show = false
			else:
				for vertex_index: int in selected_indices:
					pivot += object.transform * object.mesh_data.vertices[vertex_index]
				pivot /= float(selected_indices.size())

		if gizmo_orientation == GMSTransformGizmo.Orientation.LOCAL:
			basis = object.transform.basis.orthonormalized()

	_transform_gizmo.set_mode(displayed_gizmo_mode)
	_transform_gizmo.set_orientation(gizmo_orientation)
	_transform_gizmo.update_state(_camera, size.y, pivot, basis, can_show)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_view_caches()
		_refresh_transform_gizmo()
		_refresh_rig_overlay()


func _connect_document() -> void:
	if document == null:
		return
	document.object_updated.connect(_on_document_object_updated)
	document.structure_changed.connect(_on_document_structure_changed)


func _disconnect_document() -> void:
	if document == null:
		return
	if document.object_updated.is_connected(_on_document_object_updated):
		document.object_updated.disconnect(_on_document_object_updated)
	if document.structure_changed.is_connected(_on_document_structure_changed):
		document.structure_changed.disconnect(_on_document_structure_changed)


func _on_document_structure_changed() -> void:
	_invalidate_rig_weight_overlay_cache()
	_rebuild_objects()
	_refresh_remesh_guide_overlay()


func _on_document_object_updated(object_id: String, change_flags: int) -> void:
	var geometry_changed: bool = bool(change_flags & (GMSDocument.ChangeFlags.GEOMETRY | GMSDocument.ChangeFlags.MODIFIERS))
	var position_changed: bool = bool(change_flags & GMSDocument.ChangeFlags.POSITIONS)
	var transform_changed: bool = bool(change_flags & GMSDocument.ChangeFlags.TRANSFORM)
	var attachment_changed: bool = bool(change_flags & GMSDocument.ChangeFlags.ATTACHMENT)
	if bool(change_flags & (GMSDocument.ChangeFlags.GEOMETRY | GMSDocument.ChangeFlags.POSITIONS | GMSDocument.ChangeFlags.RIG)):
		_invalidate_rig_weight_overlay_cache(object_id)
	if geometry_changed:
		_invalidate_edit_overlay_cache(object_id)
		_invalidate_object_spatial_caches(object_id)
	elif position_changed:
		_invalidate_object_projection_cache(object_id)
		var object: GMSModelObject = document.get_object(object_id)
		var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
		if object != null and mesh_node != null:
			if object.has_preserved_position_array_mesh():
				mesh_node.mesh = object.get_evaluated_array_mesh()
			elif object.supports_dynamic_vertex_preview():
				var current_array_mesh: ArrayMesh = mesh_node.mesh as ArrayMesh
				var changed_vertices: PackedInt32Array = object.mesh_data.get_last_position_change_indices()
				if _update_array_mesh_positions(
					current_array_mesh, object.mesh_data, changed_vertices
				):
					object.adopt_position_edit_array_mesh(current_array_mesh)
		var index: GMSMeshSpatialIndex = _spatial_index_cache.get(object_id) as GMSMeshSpatialIndex
		if object != null and object.mesh_data != null and index != null:
			if not index.refit_vertices(
				object.mesh_data, object.mesh_data.get_last_position_change_indices()
			):
				_spatial_index_cache.erase(object_id)
		queue_position_mesh_rebuild(object_id)
	elif transform_changed or attachment_changed:
		_invalidate_object_projection_cache(object_id)
	_update_object_node(object_id, change_flags)
	if bool(change_flags & (GMSDocument.ChangeFlags.TRANSFORM | GMSDocument.ChangeFlags.RIG | GMSDocument.ChangeFlags.ATTACHMENT)):
		_refresh_all_attachment_previews()
	if (object_id == _remesh_guide_object_id or object_id == _remesh_guide_draw_object_id) and (geometry_changed or position_changed or transform_changed):
		_refresh_remesh_guide_overlay()
	if object_id == selected_object_id:
		if transform_changed and _edit_overlay_root != null:
			var selected_object: GMSModelObject = document.get_object(object_id)
			if selected_object != null:
				_edit_overlay_root.transform = selected_object.transform
		if geometry_changed:
			_refresh_edit_overlay()
		elif position_changed:
			var updated_object: GMSModelObject = document.get_object(object_id)
			if updated_object != null and updated_object.mesh_data != null:
				_update_cached_position_overlay_buffers(
					object_id,
					updated_object.mesh_data,
					updated_object.mesh_data.get_last_position_change_indices()
				)
			_refresh_edit_overlay()
		_refresh_transform_gizmo()
		_refresh_rig_overlay()


func _rebuild_objects() -> void:
	_clear_edit_overlay_cache()
	_clear_spatial_caches()
	for mesh_node_value: Variant in _mesh_nodes.values():
		var mesh_node: MeshInstance3D = mesh_node_value as MeshInstance3D
		if is_instance_valid(mesh_node):
			mesh_node.queue_free()
	for skeleton_value: Variant in _skeleton_nodes.values():
		var skeleton: Skeleton3D = skeleton_value as Skeleton3D
		if is_instance_valid(skeleton):
			skeleton.queue_free()
	_mesh_nodes.clear()
	_skeleton_nodes.clear()

	if document == null:
		_refresh_edit_overlay()
		return

	for object: GMSModelObject in document.objects:
		if object == null:
			continue
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.name = object.display_name
		mesh_node.set_meta("gms_object_id", object.object_id)
		_world_root.add_child(mesh_node)
		_mesh_nodes[object.object_id] = mesh_node
		_update_object_node(
			object.object_id,
			GMSDocument.ChangeFlags.GEOMETRY
			| GMSDocument.ChangeFlags.TRANSFORM
			| GMSDocument.ChangeFlags.MATERIAL
			| GMSDocument.ChangeFlags.METADATA
			| GMSDocument.ChangeFlags.ATTACHMENT
		)

	_refresh_all_attachment_previews()
	_update_selection_materials()
	_refresh_edit_overlay()
	_refresh_remesh_guide_overlay()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func _update_object_node(object_id: String, change_flags: int = 63) -> void:
	if document == null:
		return
	var object: GMSModelObject = document.get_object(object_id)
	var mesh_node: MeshInstance3D = _mesh_nodes.get(object_id) as MeshInstance3D
	if object == null or mesh_node == null:
		return
	if bool(change_flags & GMSDocument.ChangeFlags.METADATA):
		mesh_node.name = object.display_name
		mesh_node.visible = object.visible
	if bool(change_flags & (GMSDocument.ChangeFlags.TRANSFORM | GMSDocument.ChangeFlags.ATTACHMENT)):
		var preview_transform: Transform3D = _get_object_preview_transform(object)
		mesh_node.transform = preview_transform
		var existing_skeleton: Skeleton3D = _skeleton_nodes.get(object_id) as Skeleton3D
		if existing_skeleton != null:
			existing_skeleton.transform = preview_transform
	if bool(change_flags & (GMSDocument.ChangeFlags.GEOMETRY | GMSDocument.ChangeFlags.MODIFIERS | GMSDocument.ChangeFlags.MATERIAL | GMSDocument.ChangeFlags.RIG)):
		mesh_node.mesh = object.get_evaluated_array_mesh()
		_refresh_object_rig_preview(object, mesh_node)
	if (
		bool(change_flags & GMSDocument.ChangeFlags.GEOMETRY)
		and object.mesh_data != null
		and object.mesh_data.faces.size() >= DENSE_SPATIAL_INDEX_FACE_THRESHOLD
	):
		_request_spatial_index_build(object.object_id, object.mesh_data)
	if bool(change_flags & (GMSDocument.ChangeFlags.TRANSFORM | GMSDocument.ChangeFlags.RIG | GMSDocument.ChangeFlags.ATTACHMENT)):
		_refresh_all_attachment_previews()
	var preview_material: StandardMaterial3D = _material_preview_overrides.get(object_id) as StandardMaterial3D
	mesh_node.material_override = preview_material
	if workspace_mode == WorkspaceMode.MODEL and selection_mode == GMSSelection.Mode.OBJECT and selected_object_ids.has(object_id):
		mesh_node.material_overlay = _selection_overlay
	else:
		mesh_node.material_overlay = null


func _get_object_preview_transform(
	object: GMSModelObject,
	visited: Dictionary = {}
) -> Transform3D:
	if object == null or not object.has_bone_attachment() or document == null:
		return object.transform if object != null else Transform3D.IDENTITY
	if visited.has(object.object_id):
		return object.transform
	var next_visited: Dictionary = visited.duplicate()
	next_visited[object.object_id] = true
	var rig_object: GMSModelObject = document.get_object(object.attachment_rig_object_id)
	if rig_object == null or rig_object.rig_data == null:
		return object.transform
	var bone_index: int = rig_object.rig_data.resolve_bone(
		object.attachment_bone_id, object.attachment_bone_name
	)
	if bone_index < 0:
		return object.transform
	var skeleton: Skeleton3D = _skeleton_nodes.get(rig_object.object_id) as Skeleton3D
	var bone_world: Transform3D
	if skeleton != null and bone_index < skeleton.get_bone_count():
		bone_world = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
	else:
		bone_world = (
			_get_object_preview_transform(rig_object, next_visited)
			* rig_object.rig_data.get_bone_global_rest(bone_index)
		)
	return bone_world * object.attachment_offset


func _refresh_all_attachment_previews() -> void:
	if document == null:
		return
	# Repeat to support a short chain of rigid attachments without requiring a
	# particular object order in the document. Cycles fall back to stored transforms.
	for _pass_index: int in maxi(document.objects.size(), 1):
		for object: GMSModelObject in document.objects:
			if object == null or not object.has_bone_attachment():
				continue
			var preview_transform: Transform3D = _get_object_preview_transform(object)
			var mesh_node: MeshInstance3D = _mesh_nodes.get(object.object_id) as MeshInstance3D
			if mesh_node != null:
				mesh_node.transform = preview_transform
			var skeleton: Skeleton3D = _skeleton_nodes.get(object.object_id) as Skeleton3D
			if skeleton != null:
				skeleton.transform = preview_transform


func _refresh_object_rig_preview(object: GMSModelObject, mesh_node: MeshInstance3D) -> void:
	var old_skeleton: Skeleton3D = _skeleton_nodes.get(object.object_id) as Skeleton3D
	if old_skeleton != null:
		old_skeleton.queue_free()
		_skeleton_nodes.erase(object.object_id)
	mesh_node.skeleton = NodePath("")
	mesh_node.skin = null
	var evaluated_mesh: GMSMeshData = object.get_evaluated_mesh_data()
	var rig: GMSRigData = object.get_compatible_rig(evaluated_mesh)
	if rig == null:
		return
	var skeleton: Skeleton3D = rig.build_skeleton()
	skeleton.name = "%s_Skeleton" % object.object_id
	skeleton.transform = _get_object_preview_transform(object)
	_world_root.add_child(skeleton)
	_skeleton_nodes[object.object_id] = skeleton
	mesh_node.skeleton = mesh_node.get_path_to(skeleton)
	mesh_node.skin = skeleton.create_skin_from_rest_transforms()


func refresh_rig_preview(object_id: String = "") -> void:
	var target_id: String = selected_object_id if object_id.is_empty() else object_id
	if document == null or target_id.is_empty():
		_refresh_rig_overlay()
		return
	var object: GMSModelObject = document.get_object(target_id)
	var mesh_node: MeshInstance3D = _mesh_nodes.get(target_id) as MeshInstance3D
	if object != null and mesh_node != null:
		var evaluated_mesh: GMSMeshData = object.get_evaluated_mesh_data()
		var rig: GMSRigData = object.get_compatible_rig(evaluated_mesh)
		var skeleton: Skeleton3D = _skeleton_nodes.get(target_id) as Skeleton3D
		if (
			rig != null
			and is_instance_valid(skeleton)
			and skeleton.get_bone_count() == rig.bones.size()
		):
			rig.apply_pose_to_skeleton(skeleton)
			skeleton.force_update_all_bone_transforms()
		else:
			mesh_node.mesh = object.get_evaluated_array_mesh()
			_refresh_object_rig_preview(object, mesh_node)
	_refresh_all_attachment_previews()
	_refresh_transform_gizmo()
	_refresh_rig_overlay()


func _invalidate_rig_weight_overlay_cache(object_id: String = "") -> void:
	if not object_id.is_empty() and object_id != _rig_weight_cache_object_id:
		return
	_rig_weight_cache_object_id = ""
	_rig_weight_cache_bone_index = -1
	_rig_weight_cache_vertex_count = -1
	_rig_weight_cache_points.clear()
	_rig_weight_cache_values.clear()


func _ensure_rig_weight_overlay_cache(object: GMSModelObject) -> void:
	if object == null or object.mesh_data == null or object.rig_data == null:
		_invalidate_rig_weight_overlay_cache()
		return
	var vertex_count: int = object.mesh_data.vertices.size()
	if (
		_rig_weight_cache_object_id == object.object_id
		and _rig_weight_cache_bone_index == selected_bone_index
		and _rig_weight_cache_vertex_count == vertex_count
	):
		return
	_rig_weight_cache_object_id = object.object_id
	_rig_weight_cache_bone_index = selected_bone_index
	_rig_weight_cache_vertex_count = vertex_count
	_rig_weight_cache_points.clear()
	_rig_weight_cache_values.clear()
	if selected_bone_index < 0 or not object.rig_data.is_compatible(vertex_count):
		return
	var stride: int = maxi(ceili(float(vertex_count) / float(MAX_RIG_WEIGHT_OVERLAY_POINTS)), 1)
	for vertex_index: int in range(0, vertex_count, stride):
		_rig_weight_cache_points.append(object.mesh_data.vertices[vertex_index])
		_rig_weight_cache_values.append(
			object.rig_data.get_vertex_weight(vertex_index, selected_bone_index)
		)


func _refresh_rig_overlay() -> void:
	if _rig_overlay == null:
		return
	if _overlay_suppressed:
		_clear_rig_brush_preview()
		_rig_overlay.visible = false
		return
	if workspace_mode == WorkspaceMode.MODEL or document == null or _camera == null:
		_rig_overlay.clear()
		return
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.rig_data == null or object.rig_data.bones.is_empty():
		_rig_overlay.clear()
		return
	var heads: PackedVector2Array = PackedVector2Array()
	var tails: PackedVector2Array = PackedVector2Array()
	var depths: PackedFloat32Array = PackedFloat32Array()
	var names: PackedStringArray = PackedStringArray()
	var skeleton: Skeleton3D = _skeleton_nodes.get(selected_object_id) as Skeleton3D
	for bone_index: int in object.rig_data.bones.size():
		var bone: GMSBoneData = object.rig_data.bones[bone_index]
		var world_head: Vector3
		var world_tail: Vector3
		if skeleton != null and bone_index < skeleton.get_bone_count():
			var pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
			world_head = skeleton.global_transform * pose.origin
			world_tail = skeleton.global_transform * (pose * Vector3(0.0, bone.get_length(), 0.0))
		else:
			world_head = object.transform * bone.head
			world_tail = object.transform * bone.tail
		heads.append(_camera.unproject_position(world_head))
		tails.append(_camera.unproject_position(world_tail))
		depths.append(_camera.global_position.distance_to(world_head))
		names.append(bone.display_name)
	_rig_overlay.set_bone_projection(heads, tails, depths, names, selected_bone_index)
	if _animation_guide_object_id == selected_object_id:
		var projected_chain: PackedVector2Array = PackedVector2Array()
		for local_point: Vector3 in _animation_guide_chain_points:
			var world_point: Vector3 = object.transform * local_point
			if not _camera.is_position_behind(world_point):
				projected_chain.append(_camera.unproject_position(world_point))
		var projected_root_path: PackedVector2Array = PackedVector2Array()
		for local_point: Vector3 in _animation_guide_root_path:
			var root_world_point: Vector3 = object.transform * local_point
			if not _camera.is_position_behind(root_world_point):
				projected_root_path.append(_camera.unproject_position(root_world_point))
		var target_world: Vector3 = object.transform * _animation_guide_target_position
		var pole_world: Vector3 = object.transform * _animation_guide_pole_position
		_rig_overlay.set_animation_guides(
			projected_chain,
			_camera.unproject_position(target_world),
			_camera.unproject_position(pole_world),
			_animation_guide_show_ik,
			projected_root_path
		)
	else:
		_rig_overlay.clear_animation_guides()
	if (
		workspace_mode != WorkspaceMode.RIG
		or rig_submode != RigSubmode.WEIGHTS
		or selected_bone_index < 0
		or object.mesh_data == null
		or not object.rig_data.is_compatible(object.mesh_data.vertices.size())
	):
		_clear_rig_brush_preview()
		_rig_overlay.clear_weights()
		return
	_ensure_rig_weight_overlay_cache(object)
	var weight_points: PackedVector2Array = PackedVector2Array()
	var visible_weights: PackedFloat32Array = PackedFloat32Array()
	for point_index: int in _rig_weight_cache_points.size():
		var world_vertex: Vector3 = object.transform * _rig_weight_cache_points[point_index]
		if _camera.is_position_behind(world_vertex):
			continue
		weight_points.append(_camera.unproject_position(world_vertex))
		visible_weights.append(_rig_weight_cache_values[point_index])
	_rig_overlay.set_weight_projection(weight_points, visible_weights)
	if rig_vertex_select:
		_clear_rig_brush_preview()
	elif is_finite(_last_pointer_position.x) and is_finite(_last_pointer_position.y):
		_update_rig_brush_preview(_last_pointer_position)


func _update_selection_materials() -> void:
	for object_id: String in _mesh_nodes.keys():
		var mesh_node: MeshInstance3D = _mesh_nodes[object_id] as MeshInstance3D
		if mesh_node == null:
			continue
		if workspace_mode == WorkspaceMode.MODEL and selection_mode == GMSSelection.Mode.OBJECT and selected_object_ids.has(object_id):
			mesh_node.material_overlay = _selection_overlay
		else:
			mesh_node.material_overlay = null


func _refresh_edit_overlay() -> void:
	if _edit_overlay_root == null:
		return
	_clear_edit_overlay()
	if (workspace_mode != WorkspaceMode.MODEL and not (workspace_mode == WorkspaceMode.RIG and rig_submode == RigSubmode.WEIGHTS and rig_vertex_select)) or _overlay_suppressed or selection_mode == GMSSelection.Mode.OBJECT or document == null:
		_edit_overlay_root.visible = false
		return
	var object: GMSModelObject = document.get_object(selected_object_id)
	if object == null or object.mesh_data == null or not object.visible:
		_edit_overlay_root.visible = false
		return
	var mesh: GMSMeshData = object.mesh_data
	_edit_overlay_root.transform = object.transform
	_edit_overlay_root.visible = true
	var all_edges: Array[Vector2i] = _get_cached_edit_edges(object.object_id, mesh)
	if all_edges.size() <= LARGE_MESH_EDGE_THRESHOLD:
		_wire_overlay.mesh = _get_cached_wire_mesh(object.object_id, mesh, all_edges)
		_seam_edge_overlay.mesh = _get_cached_seam_mesh(object.object_id, mesh)
	if selection_mode == GMSSelection.Mode.VERTEX:
		if mesh.vertices.size() <= FULL_VERTEX_MARKER_THRESHOLD:
			_vertex_markers.multimesh = _get_cached_vertex_multimesh(object.object_id, mesh)
		else:
			_vertex_point_overlay.mesh = _get_cached_vertex_point_mesh(object.object_id, mesh)
		_selected_vertex_markers.multimesh = _build_vertex_multimesh(
			mesh,
			selected_vertex_indices,
			_calculate_marker_radius(mesh) * 1.5
		)
	elif selection_mode == GMSSelection.Mode.EDGE:
		var selected_edges: Array[Vector2i] = []
		for edge_index: int in selected_edge_indices:
			if edge_index >= 0 and edge_index < all_edges.size():
				selected_edges.append(all_edges[edge_index])
		_selected_edge_overlay.mesh = _build_edge_mesh(mesh, selected_edges, _selected_edge_material)
	elif selection_mode == GMSSelection.Mode.FACE:
		var local_camera_position: Vector3 = _edit_overlay_root.to_local(
			_camera.global_position
		)
		_face_overlay.mesh = _build_face_overlay_mesh(
			mesh,
			selected_face_indices,
			local_camera_position
		)


func _clear_edit_overlay_cache() -> void:
	_edit_edge_cache.clear()
	_wire_mesh_cache.clear()
	_seam_mesh_cache.clear()
	_vertex_multimesh_cache.clear()
	_vertex_point_mesh_cache.clear()


func _invalidate_edit_overlay_cache(object_id: String) -> void:
	_edit_edge_cache.erase(object_id)
	_wire_mesh_cache.erase(object_id)
	_seam_mesh_cache.erase(object_id)
	_vertex_multimesh_cache.erase(object_id)
	_vertex_point_mesh_cache.erase(object_id)


func _update_cached_position_overlay_buffers(
	object_id: String,
	mesh: GMSMeshData,
	changed_vertices: PackedInt32Array
) -> void:
	if mesh == null or changed_vertices.is_empty():
		return
	var caches: Array[Dictionary] = [
		_wire_mesh_cache,
		_seam_mesh_cache,
		_vertex_point_mesh_cache,
	]
	for cache: Dictionary in caches:
		var entry: Dictionary = cache.get(object_id, {})
		var cached_mesh: ArrayMesh = entry.get("value") as ArrayMesh
		if cached_mesh == null:
			continue
		if mesh.update_array_mesh_vertex_positions(cached_mesh, changed_vertices):
			entry["position_revision"] = mesh.get_position_revision()
			cache[object_id] = entry
	if mesh.vertices.size() <= FULL_VERTEX_MARKER_THRESHOLD:
		_vertex_multimesh_cache.erase(object_id)


func _get_cached_edit_edges(object_id: String, mesh: GMSMeshData) -> Array[Vector2i]:
	var cached: Dictionary = _edit_edge_cache.get(object_id, {})
	if int(cached.get("revision", -1)) == mesh.get_topology_revision():
		return cached["value"]
	var edges: Array[Vector2i] = mesh.get_edges()
	_edit_edge_cache[object_id] = {"revision": mesh.get_topology_revision(), "value": edges}
	return edges


func _get_cached_wire_mesh(
	object_id: String,
	mesh: GMSMeshData,
	edges: Array[Vector2i]
) -> Mesh:
	var cached: Dictionary = _wire_mesh_cache.get(object_id, {})
	var topology_revision: int = mesh.get_topology_revision()
	var position_revision: int = mesh.get_position_revision()
	if int(cached.get("topology_revision", -1)) == topology_revision:
		var cached_mesh: ArrayMesh = cached.get("value") as ArrayMesh
		if cached_mesh != null and int(cached.get("position_revision", -1)) != position_revision:
			cached_mesh.surface_update_vertex_region(0, 0, mesh.vertices.to_byte_array())
			cached["position_revision"] = position_revision
			_wire_mesh_cache[object_id] = cached
		return cached_mesh
	var wire_mesh: ArrayMesh = _build_indexed_edge_mesh(
		mesh, edges, _wire_material, MAX_WIRE_OVERLAY_EDGES
	)
	_wire_mesh_cache[object_id] = {
		"topology_revision": topology_revision,
		"position_revision": position_revision,
		"value": wire_mesh,
	}
	return wire_mesh


func _get_cached_seam_mesh(object_id: String, mesh: GMSMeshData) -> Mesh:
	var cached: Dictionary = _seam_mesh_cache.get(object_id, {})
	var topology_revision: int = mesh.get_topology_revision()
	var position_revision: int = mesh.get_position_revision()
	var seam_signature: int = hash(mesh.seam_edges)
	if (
		int(cached.get("topology_revision", -1)) == topology_revision
		and int(cached.get("seam_signature", 0)) == seam_signature
	):
		var cached_mesh: ArrayMesh = cached.get("value") as ArrayMesh
		if cached_mesh != null and int(cached.get("position_revision", -1)) != position_revision:
			cached_mesh.surface_update_vertex_region(0, 0, mesh.vertices.to_byte_array())
			cached["position_revision"] = position_revision
			_seam_mesh_cache[object_id] = cached
		return cached_mesh
	var seam_mesh: ArrayMesh = _build_indexed_edge_mesh(
		mesh, mesh.seam_edges, _seam_edge_material, mesh.seam_edges.size()
	)
	_seam_mesh_cache[object_id] = {
		"topology_revision": topology_revision,
		"position_revision": position_revision,
		"seam_signature": seam_signature,
		"value": seam_mesh,
	}
	return seam_mesh


func _get_cached_vertex_multimesh(object_id: String, mesh: GMSMeshData) -> MultiMesh:
	var cached: Dictionary = _vertex_multimesh_cache.get(object_id, {})
	if int(cached.get("revision", -1)) == mesh.get_change_revision():
		return cached["value"] as MultiMesh
	var markers: MultiMesh = _build_vertex_multimesh(
		mesh,
		GMSMeshOperations.all_vertex_indices(mesh),
		_calculate_marker_radius(mesh)
	)
	_vertex_multimesh_cache[object_id] = {"revision": mesh.get_change_revision(), "value": markers}
	return markers


func _get_cached_vertex_point_mesh(object_id: String, mesh: GMSMeshData) -> Mesh:
	var cached: Dictionary = _vertex_point_mesh_cache.get(object_id, {})
	var topology_revision: int = mesh.get_topology_revision()
	var position_revision: int = mesh.get_position_revision()
	if int(cached.get("topology_revision", -1)) == topology_revision:
		var cached_mesh: ArrayMesh = cached.get("value") as ArrayMesh
		if cached_mesh != null and int(cached.get("position_revision", -1)) != position_revision:
			cached_mesh.surface_update_vertex_region(0, 0, mesh.vertices.to_byte_array())
			cached["position_revision"] = position_revision
			_vertex_point_mesh_cache[object_id] = cached
		return cached_mesh
	var point_mesh: ArrayMesh = ArrayMesh.new()
	if not mesh.vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = mesh.vertices
		point_mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_POINTS,
			arrays,
			[],
			{},
			Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
		)
	_vertex_point_mesh_cache[object_id] = {
		"topology_revision": topology_revision,
		"position_revision": position_revision,
		"value": point_mesh,
	}
	return point_mesh


func _clear_edit_overlay() -> void:
	_wire_overlay.mesh = null
	_seam_edge_overlay.mesh = null
	_selected_edge_overlay.mesh = null
	_face_overlay.mesh = null
	_vertex_markers.multimesh = null
	_vertex_point_overlay.mesh = null
	_selected_vertex_markers.multimesh = null


func _build_indexed_edge_mesh(
	mesh: GMSMeshData,
	edges: Array[Vector2i],
	material: StandardMaterial3D,
	maximum_edges: int
) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	if mesh == null or mesh.vertices.is_empty() or edges.is_empty() or maximum_edges <= 0:
		return result
	var safe_count: int = mini(edges.size(), maximum_edges)
	var step: float = float(edges.size()) / float(safe_count)
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(safe_count * 2)
	for sample_index: int in safe_count:
		var edge_index: int = mini(int(floor(float(sample_index) * step)), edges.size() - 1)
		var edge: Vector2i = edges[edge_index]
		indices[sample_index * 2] = edge.x
		indices[sample_index * 2 + 1] = edge.y
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh.vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	result.add_surface_from_arrays(
		Mesh.PRIMITIVE_LINES,
		arrays,
		[],
		{},
		Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	)
	result.surface_set_material(0, material)
	return result


func _build_edge_mesh(
	mesh: GMSMeshData,
	edges: Array[Vector2i],
	material: StandardMaterial3D
) -> Mesh:
	var immediate: ImmediateMesh = ImmediateMesh.new()
	if edges.is_empty():
		return immediate
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for edge: Vector2i in edges:
		if edge.x < 0 or edge.x >= mesh.vertices.size():
			continue
		if edge.y < 0 or edge.y >= mesh.vertices.size():
			continue
		immediate.surface_add_vertex(mesh.vertices[edge.x])
		immediate.surface_add_vertex(mesh.vertices[edge.y])
	immediate.surface_end()
	return immediate


func _build_face_overlay_mesh(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array,
	local_camera_position: Vector3
) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	if mesh == null or mesh.vertices.is_empty() or face_indices.is_empty():
		return result

	# Move the overlay slightly toward the camera instead of along face normals.
	# Imported or converted meshes can contain inconsistent winding, which caused
	# some selected faces to be pushed inside the source mesh and disappear.
	var bounds: AABB = mesh.get_aabb()
	var bias_direction: Vector3 = local_camera_position - bounds.get_center()
	if bias_direction.length_squared() <= 0.000001:
		bias_direction = Vector3.BACK
	else:
		bias_direction = bias_direction.normalized()
	var offset_amount: float = maxf(0.0005, bounds.size.length() * 0.0008)
	var biased_vertices: PackedVector3Array = mesh.vertices.duplicate()
	for vertex_index: int in biased_vertices.size():
		biased_vertices[vertex_index] += bias_direction * offset_amount

	var triangle_indices: PackedInt32Array = PackedInt32Array()
	for face_index: int in face_indices:
		if face_index < 0 or face_index >= mesh.faces.size():
			continue
		var face: PackedInt32Array = mesh.faces[face_index]
		if face.size() < 3:
			continue
		var root_index: int = face[0]
		if root_index < 0 or root_index >= biased_vertices.size():
			continue
		for triangle_index: int in range(1, face.size() - 1):
			var second_index: int = face[triangle_index]
			var third_index: int = face[triangle_index + 1]
			if second_index < 0 or second_index >= biased_vertices.size():
				continue
			if third_index < 0 or third_index >= biased_vertices.size():
				continue
			triangle_indices.append(root_index)
			triangle_indices.append(second_index)
			triangle_indices.append(third_index)

	if triangle_indices.is_empty():
		return result
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = biased_vertices
	arrays[Mesh.ARRAY_INDEX] = triangle_indices
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, _selected_face_material)
	return result


func _build_vertex_multimesh(
	mesh: GMSMeshData,
	indices: PackedInt32Array,
	radius: float
) -> MultiMesh:
	var marker: QuadMesh = QuadMesh.new()
	marker.size = Vector2.ONE * radius * 2.0
	var valid_indices: PackedInt32Array = PackedInt32Array()
	for vertex_index: int in indices:
		if vertex_index >= 0 and vertex_index < mesh.vertices.size():
			valid_indices.append(vertex_index)
	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = marker
	multi_mesh.instance_count = valid_indices.size()
	for instance_index: int in valid_indices.size():
		var vertex_index: int = valid_indices[instance_index]
		multi_mesh.set_instance_transform(
			instance_index,
			Transform3D(Basis.IDENTITY, mesh.vertices[vertex_index])
		)
	return multi_mesh


func _calculate_marker_radius(mesh: GMSMeshData) -> float:
	return maxf(0.018, mesh.get_aabb().size.length() * 0.012)
