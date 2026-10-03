@tool
class_name GMSModelObject
extends Resource

enum CollisionType {
	NONE,
	TRIMESH,
	CONVEX,
	BOX,
	SPHERE,
	CAPSULE,
}

@export var object_id: String = ""
@export var display_name: String = "Object"
@export var visible: bool = true
@export var locked: bool = false
@export var transform: Transform3D = Transform3D.IDENTITY
@export var mesh_data: GMSMeshData
@export var rig_data: GMSRigData
@export var animation_data: GMSAnimationData
@export var attachment_rig_object_id: String = ""
@export var attachment_bone_id: String = ""
@export var attachment_bone_name: String = ""
@export var attachment_offset: Transform3D = Transform3D.IDENTITY


@export var material: StandardMaterial3D
@export var materials: Array[StandardMaterial3D] = []
@export var active_material_index: int = 0
@export var modifiers: Array[GMSModifier] = []
@export var collision_type: int = CollisionType.NONE
@export_range(1, 32, 1) var collision_layer: int = 1
@export_range(1, 32, 1) var collision_mask: int = 1

var _cached_source_revision: int = -1
var _cached_modifier_signatures: Array[int] = []
var _cached_modifier_stages: Array[GMSMeshData] = []
var _cached_evaluated_mesh: GMSMeshData
var _evaluation_revision: int = 0
var _cached_array_mesh: ArrayMesh
var _cached_array_mesh_evaluation_revision: int = -1
var _cached_material_signature: int = 0
var _async_task_id: int = -1
var _async_result_holder: Dictionary = {}
var _async_task_generation: int = -1
var _async_generation: int = 0
var _async_restart_pending: bool = false
var _async_job: GMSBackgroundJob
var _async_last_cancelled: bool = false
var _async_user_cancel_requested: bool = false
var _async_cancelled_source_revision: int = -1
var _async_cancelled_modifier_signatures: Array[int] = []
var _position_array_mesh_preserved: bool = false


func ensure_defaults() -> void:
	if object_id.is_empty():
		object_id = _generate_id()
	if mesh_data == null:
		mesh_data = GMSPrimitiveFactory.create_cube()
	else:
		mesh_data.prepare_for_use()

	if rig_data != null:
		rig_data.ensure_defaults()
	if animation_data != null:
		animation_data.ensure_defaults(rig_data)
	attachment_rig_object_id = attachment_rig_object_id.strip_edges()
	attachment_bone_id = attachment_bone_id.strip_edges()
	attachment_bone_name = attachment_bone_name.strip_edges()
	if attachment_rig_object_id.is_empty() or (attachment_bone_id.is_empty() and attachment_bone_name.is_empty()):
		clear_attachment()

	if materials.is_empty():
		materials.append(material if material != null else create_default_material("Material 1"))
	else:
		materials = duplicate_materials(materials)
	_normalize_material_slots()
	active_material_index = clampi(active_material_index, 0, materials.size() - 1)
	_sync_legacy_material()
	modifiers = duplicate_modifiers(modifiers)
	collision_type = clampi(collision_type, CollisionType.NONE, CollisionType.CAPSULE)
	collision_layer = clampi(collision_layer, 1, 32)
	collision_mask = clampi(collision_mask, 1, 32)
	invalidate_all_caches()


func duplicate_object() -> GMSModelObject:
	var copy: GMSModelObject = GMSModelObject.new()
	copy.object_id = _generate_id()
	copy.display_name = display_name + " Copy"
	copy.visible = visible
	copy.locked = locked
	copy.transform = transform
	copy.mesh_data = mesh_data.duplicate_mesh_data() if mesh_data != null else null
	copy.rig_data = rig_data.duplicate_rig() if rig_data != null else null
	copy.animation_data = animation_data.duplicate_data() if animation_data != null else null
	copy.attachment_rig_object_id = attachment_rig_object_id
	copy.attachment_bone_id = attachment_bone_id
	copy.attachment_bone_name = attachment_bone_name
	copy.attachment_offset = attachment_offset
	copy.materials = duplicate_materials(materials)
	if copy.materials.is_empty():
		copy.materials.append(create_default_material("Material 1"))
	copy.active_material_index = clampi(active_material_index, 0, copy.materials.size() - 1)
	copy._sync_legacy_material()
	copy.modifiers = duplicate_modifiers(modifiers)
	copy.collision_type = collision_type
	copy.collision_layer = collision_layer
	copy.collision_mask = collision_mask
	return copy


func has_bone_attachment() -> bool:
	return (
		not attachment_rig_object_id.is_empty()
		and (not attachment_bone_id.is_empty() or not attachment_bone_name.is_empty())
	)


func set_attachment(
	rig_object_id: String,
	bone_id: String,
	bone_name: String,
	offset: Transform3D
) -> void:
	attachment_rig_object_id = rig_object_id.strip_edges()
	attachment_bone_id = bone_id.strip_edges()
	attachment_bone_name = bone_name.strip_edges()
	attachment_offset = offset
	if attachment_rig_object_id.is_empty() or (attachment_bone_id.is_empty() and attachment_bone_name.is_empty()):
		clear_attachment()


func clear_attachment() -> void:
	attachment_rig_object_id = ""
	attachment_bone_id = ""
	attachment_bone_name = ""
	attachment_offset = Transform3D.IDENTITY


func get_evaluated_mesh_data() -> GMSMeshData:
	if mesh_data == null:
		return null
	poll_async_evaluation()
	var source_revision: int = mesh_data.get_change_revision()
	var signatures: Array[int] = _get_modifier_signatures()
	if _is_evaluation_cache_current(source_revision, signatures):
		return _cached_evaluated_mesh
	if _should_evaluate_async():
		if _is_async_evaluation_suppressed(source_revision, signatures):
			if _cached_evaluated_mesh == null:
				_cached_evaluated_mesh = mesh_data
			return _cached_evaluated_mesh
		if _cached_evaluated_mesh == null:
			_cached_evaluated_mesh = mesh_data
		_request_async_evaluation()
		return _cached_evaluated_mesh
	return _evaluate_synchronously(source_revision, signatures)


func _is_evaluation_cache_current(
	source_revision: int = -1,
	signatures: Array[int] = []
) -> bool:
	if mesh_data == null or _cached_evaluated_mesh == null:
		return false
	var current_source_revision: int = source_revision
	if current_source_revision < 0:
		current_source_revision = mesh_data.get_change_revision()
	var current_signatures: Array[int] = signatures
	if current_signatures.is_empty() and not modifiers.is_empty():
		current_signatures = _get_modifier_signatures()
	return (
		_cached_source_revision == current_source_revision
		and _cached_modifier_signatures == current_signatures
	)


func _is_async_evaluation_suppressed(
	source_revision: int,
	signatures: Array[int]
) -> bool:
	return (
		_async_cancelled_source_revision == source_revision
		and _async_cancelled_modifier_signatures == signatures
	)


func _evaluate_synchronously(source_revision: int, signatures: Array[int]) -> GMSMeshData:
	var first_changed: int = 0
	if _cached_source_revision == source_revision:
		first_changed = mini(signatures.size(), _cached_modifier_signatures.size())
		for modifier_index: int in first_changed:
			if signatures[modifier_index] != _cached_modifier_signatures[modifier_index]:
				first_changed = modifier_index
				break
	else:
		first_changed = 0
	var current: GMSMeshData = mesh_data
	if first_changed > 0 and first_changed <= _cached_modifier_stages.size():
		current = _cached_modifier_stages[first_changed - 1]
	else:
		first_changed = 0
	_cached_modifier_stages.resize(signatures.size())
	for modifier_index: int in range(first_changed, modifiers.size()):
		var previous: GMSMeshData = current
		current = GMSModifierEvaluator.evaluate_single(current, modifiers[modifier_index])
		if current != null and current != mesh_data and current != previous:
			current.prepare_for_use()
		_cached_modifier_stages[modifier_index] = current
	_cached_source_revision = source_revision
	_cached_modifier_signatures = signatures
	_cached_evaluated_mesh = current
	_evaluation_revision += 1
	_cached_array_mesh = null
	return current


func _get_modifier_signatures() -> Array[int]:
	var signatures: Array[int] = []
	for modifier: GMSModifier in modifiers:
		signatures.append(modifier.get_cache_signature() if modifier != null else 0)
	return signatures


func _should_evaluate_async() -> bool:
	if mesh_data == null or modifiers.is_empty():
		return false
	var estimated_faces: int = mesh_data.faces.size()
	var estimated_vertices: int = mesh_data.vertices.size()
	for modifier: GMSModifier in modifiers:
		if modifier == null or not modifier.enabled:
			continue
		if modifier.is_custom():
			return false
		match modifier.kind:
			GMSModifier.Kind.SIMPLE_SUBDIVIDE, GMSModifier.Kind.SUBDIVISION_SURFACE:
				for _level: int in clampi(modifier.subdivision_levels, 1, 4):
					estimated_faces *= 4
					estimated_vertices *= 4
			GMSModifier.Kind.ARRAY:
				var count: int = maxi(modifier.array_count, 1)
				estimated_faces *= count
				estimated_vertices *= count
			GMSModifier.Kind.SOLIDIFY:
				estimated_faces *= 3
				estimated_vertices *= 2
			GMSModifier.Kind.BEVEL:
				var multiplier: int = 1 + clampi(modifier.bevel_segments, 1, 4) * 2
				estimated_faces *= multiplier
				estimated_vertices *= multiplier
			GMSModifier.Kind.TRIANGULATE:
				estimated_faces *= 2
		if estimated_faces >= 20000 or estimated_vertices >= 30000:
			return true
	return false


func _request_async_evaluation() -> void:
	if mesh_data == null:
		return
	if _async_task_id >= 0:
		if _async_task_generation != _async_generation:
			_async_restart_pending = true
			if _async_job != null:
				_async_job.request_cancel()
		return
	var source_revision: int = mesh_data.get_change_revision()
	var signatures: Array[int] = _get_modifier_signatures()
	var first_changed: int = 0
	if _cached_source_revision == source_revision:
		first_changed = mini(signatures.size(), _cached_modifier_signatures.size())
		for modifier_index: int in first_changed:
			if signatures[modifier_index] != _cached_modifier_signatures[modifier_index]:
				first_changed = modifier_index
				break
	var evaluation_source: GMSMeshData
	if first_changed > 0 and first_changed <= _cached_modifier_stages.size():
		evaluation_source = _cached_modifier_stages[first_changed - 1]
	else:
		first_changed = 0
		evaluation_source = mesh_data.duplicate_mesh_data_fast()
	var modifier_copies: Array[GMSModifier] = duplicate_modifiers(modifiers)
	var holder: Dictionary = {}
	var generation: int = _async_generation
	var job: GMSBackgroundJob = GMSBackgroundJob.new()
	job.update_progress(0.0, "Preparing modifier evaluation")
	var action: Callable = func() -> void:
		var evaluated: Dictionary = GMSModifierEvaluator.evaluate_from(
			evaluation_source,
			modifier_copies,
			first_changed,
			job
		)
		holder["mesh"] = evaluated.get("mesh")
		holder["stages"] = evaluated.get("stages", [])
		holder["start_index"] = first_changed
		holder["source_revision"] = source_revision
		holder["signatures"] = signatures
		holder["cancelled"] = bool(evaluated.get("cancelled", false)) or job.is_cancelled()
	_async_result_holder = holder
	_async_task_generation = generation
	_async_restart_pending = false
	_async_job = job
	_async_last_cancelled = false
	_async_user_cancel_requested = false
	_async_task_id = WorkerThreadPool.add_task(action, false, "Gator Model Studio modifier evaluation")

func poll_async_evaluation() -> bool:
	if _async_task_id < 0 or not WorkerThreadPool.is_task_completed(_async_task_id):
		return false
	WorkerThreadPool.wait_for_task_completion(_async_task_id)
	var completed_generation: int = _async_task_generation
	var holder: Dictionary = _async_result_holder
	_async_task_id = -1
	_async_task_generation = -1
	_async_result_holder = {}
	_async_job = null
	return _accept_async_evaluation(holder, completed_generation)

func finish_async_evaluation() -> void:
	if _async_task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_async_task_id)
	var completed_generation: int = _async_task_generation
	var holder: Dictionary = _async_result_holder
	_async_task_id = -1
	_async_task_generation = -1
	_async_result_holder = {}
	_async_job = null
	_accept_async_evaluation(holder, completed_generation)

func _accept_async_evaluation(holder: Dictionary, completed_generation: int) -> bool:
	if _async_user_cancel_requested:
		_async_user_cancel_requested = false
		_async_restart_pending = false
		_async_last_cancelled = true
		_async_cancelled_source_revision = int(holder.get("source_revision", -1))
		_async_cancelled_modifier_signatures.clear()
		var cancelled_signature_values: Variant = holder.get("signatures", [])
		if cancelled_signature_values is Array:
			var cancelled_signature_array: Array = cancelled_signature_values
			for signature_value: Variant in cancelled_signature_array:
				_async_cancelled_modifier_signatures.append(int(signature_value))
		return false
	if completed_generation != _async_generation or _async_restart_pending:
		_async_restart_pending = false
		if (
			not _is_evaluation_cache_current()
			and _should_evaluate_async()
			and _cached_evaluated_mesh != null
		):
			_request_async_evaluation()
		return false
	if bool(holder.get("cancelled", false)):
		_async_last_cancelled = true
		return false
	var result: GMSMeshData = holder.get("mesh") as GMSMeshData
	if result == null or mesh_data == null:
		return false
	var completed_source_revision: int = int(holder.get("source_revision", -1))
	var completed_signatures: Array[int] = []
	for signature_value: Variant in holder.get("signatures", []):
		completed_signatures.append(int(signature_value))
	if (
		completed_source_revision != mesh_data.get_change_revision()
		or completed_signatures != _get_modifier_signatures()
	):
		_request_async_evaluation()
		return false
	var start_index: int = int(holder.get("start_index", 0))
	var completed_stages: Array = holder.get("stages", [])
	_cached_modifier_stages.resize(completed_signatures.size())
	for stage_offset: int in completed_stages.size():
		var target_index: int = start_index + stage_offset
		if target_index < 0 or target_index >= _cached_modifier_stages.size():
			continue
		var stage: GMSMeshData = completed_stages[stage_offset] as GMSMeshData
		if stage != null:
			stage.prepare_for_use()
			_cached_modifier_stages[target_index] = stage
	result.prepare_for_use()
	_cached_source_revision = completed_source_revision
	_cached_modifier_signatures = completed_signatures
	_cached_evaluated_mesh = result
	_evaluation_revision += 1
	_cached_array_mesh = null
	_async_last_cancelled = false
	return true

func get_evaluated_array_mesh() -> ArrayMesh:
	var evaluated: GMSMeshData = get_evaluated_mesh_data()
	if evaluated == null:
		return null
	var material_signature: int = _get_material_signature()
	if (
		_cached_array_mesh != null
		and _cached_array_mesh_evaluation_revision == _evaluation_revision
		and _cached_material_signature == material_signature
	):
		return _cached_array_mesh
	var compatible_rig: GMSRigData = null
	if rig_data != null and rig_data.is_compatible(evaluated.vertices.size()):
		compatible_rig = rig_data
	_cached_array_mesh = evaluated.to_array_mesh(materials, false, compatible_rig)
	_cached_array_mesh_evaluation_revision = _evaluation_revision
	_cached_material_signature = material_signature
	return _cached_array_mesh


func set_rig_data(new_rig: GMSRigData) -> void:
	var old_bones: PackedInt32Array = PackedInt32Array()
	var old_weights: PackedFloat32Array = PackedFloat32Array()
	if rig_data != null:
		old_bones = rig_data.vertex_bones
		old_weights = rig_data.vertex_weights
	rig_data = new_rig.duplicate_rig() if new_rig != null else null
	if rig_data != null:
		rig_data.ensure_defaults()
	if animation_data != null:
		animation_data.ensure_defaults(rig_data)
	var new_bones: PackedInt32Array = PackedInt32Array()
	var new_weights: PackedFloat32Array = PackedFloat32Array()
	if rig_data != null:
		new_bones = rig_data.vertex_bones
		new_weights = rig_data.vertex_weights
	if old_bones != new_bones or old_weights != new_weights:
		invalidate_geometry_cache()



func set_animation_data(new_data: GMSAnimationData) -> void:
	animation_data = new_data.duplicate_data() if new_data != null else null
	if animation_data != null:
		animation_data.ensure_defaults(rig_data)


func get_animation_data(create_if_missing: bool = false) -> GMSAnimationData:
	if animation_data == null and create_if_missing:
		animation_data = GMSAnimationData.new()
		animation_data.ensure_defaults(rig_data)
	return animation_data


func get_compatible_rig(evaluated_mesh: GMSMeshData = null) -> GMSRigData:
	if rig_data == null:
		return null
	var target_mesh: GMSMeshData = evaluated_mesh if evaluated_mesh != null else get_evaluated_mesh_data()
	if target_mesh == null or not rig_data.is_compatible(target_mesh.vertices.size()):
		return null
	return rig_data


func supports_dynamic_vertex_preview() -> bool:
	if mesh_data == null:
		return false
	for modifier: GMSModifier in modifiers:
		if modifier != null and modifier.enabled:
			return false
	return true


func adopt_position_edit_array_mesh(preserved_array_mesh: ArrayMesh) -> void:
	_mark_async_evaluation_changed(_should_evaluate_async())
	_cached_modifier_stages.clear()
	_cached_source_revision = mesh_data.get_change_revision() if mesh_data != null else -1
	_cached_modifier_signatures = _get_modifier_signatures()
	_cached_evaluated_mesh = mesh_data
	_evaluation_revision += 1
	_cached_array_mesh = preserved_array_mesh
	_cached_array_mesh_evaluation_revision = _evaluation_revision if preserved_array_mesh != null else -1
	_cached_material_signature = _get_material_signature() if preserved_array_mesh != null else 0
	_position_array_mesh_preserved = preserved_array_mesh != null


func adopt_rebuilt_array_mesh(rebuilt_array_mesh: ArrayMesh) -> void:
	adopt_position_edit_array_mesh(rebuilt_array_mesh)
	_position_array_mesh_preserved = false


func has_preserved_position_array_mesh() -> bool:
	return _position_array_mesh_preserved and _cached_array_mesh != null


func force_rebuild_array_mesh() -> ArrayMesh:
	_position_array_mesh_preserved = false
	_cached_array_mesh = null
	_cached_array_mesh_evaluation_revision = -1
	return get_evaluated_array_mesh()


func get_evaluated_counts() -> Vector2i:
	var evaluated: GMSMeshData = get_evaluated_mesh_data()
	if evaluated == null:
		return Vector2i.ZERO
	return Vector2i(evaluated.vertices.size(), evaluated.faces.size())


func is_async_evaluation_pending() -> bool:
	poll_async_evaluation()
	if _async_task_id < 0:
		return false
	if _async_task_generation == _async_generation:
		return true
	return _async_restart_pending and _should_evaluate_async()


func get_async_evaluation_state() -> Dictionary:
	var state: Dictionary = {
		"running": _async_task_id >= 0,
		"completed": false,
		"cancelled": _async_last_cancelled,
		"progress": 0.0,
		"stage": "",
	}
	if _async_task_id < 0:
		return state
	state["completed"] = WorkerThreadPool.is_task_completed(_async_task_id)
	if _async_job != null:
		var job_state: Dictionary = _async_job.get_state()
		state["cancelled"] = bool(job_state.get("cancelled", false))
		state["progress"] = float(job_state.get("progress", 0.0))
		state["stage"] = str(job_state.get("stage", "Evaluating modifiers"))
	return state


func cancel_async_evaluation() -> void:
	if _async_task_id < 0 or _async_job == null:
		return
	_async_restart_pending = false
	_async_user_cancel_requested = true
	_async_job.request_cancel()


func retry_async_evaluation() -> void:
	_async_cancelled_source_revision = -1
	_async_cancelled_modifier_signatures.clear()
	_async_last_cancelled = false
	if _async_task_id < 0 and _should_evaluate_async():
		_request_async_evaluation()


func get_cached_evaluated_mesh_through(modifier_index: int) -> GMSMeshData:
	poll_async_evaluation()
	if mesh_data == null or modifier_index < 0 or modifier_index >= modifiers.size():
		return null
	var source_revision: int = mesh_data.get_change_revision()
	var signatures: Array[int] = _get_modifier_signatures()
	if not _is_evaluation_cache_current(source_revision, signatures):
		return null
	if modifier_index == modifiers.size() - 1:
		return _cached_evaluated_mesh
	if modifier_index < _cached_modifier_stages.size():
		return _cached_modifier_stages[modifier_index]
	return null


func adopt_mesh_and_modifiers(
	new_mesh: GMSMeshData,
	new_modifiers: Array[GMSModifier],
	preserved_array_mesh: ArrayMesh = null
) -> void:
	mesh_data = new_mesh
	modifiers = duplicate_modifiers(new_modifiers)
	_mark_async_evaluation_changed(_should_evaluate_async())
	_cached_modifier_stages.clear()
	_cached_source_revision = mesh_data.get_change_revision() if mesh_data != null else -1
	_cached_modifier_signatures = _get_modifier_signatures()
	_cached_evaluated_mesh = mesh_data if modifiers.is_empty() else null
	_evaluation_revision += 1
	_cached_array_mesh = preserved_array_mesh if modifiers.is_empty() else null
	_cached_array_mesh_evaluation_revision = _evaluation_revision if _cached_array_mesh != null else -1
	_cached_material_signature = _get_material_signature() if _cached_array_mesh != null else 0


func invalidate_geometry_cache() -> void:
	_position_array_mesh_preserved = false
	_mark_async_evaluation_changed(_should_evaluate_async())
	_cached_source_revision = -1
	_cached_modifier_signatures.clear()
	_cached_modifier_stages.clear()
	_cached_evaluated_mesh = null
	_cached_array_mesh = null
	_cached_array_mesh_evaluation_revision = -1


func invalidate_modifier_cache() -> void:
	_mark_async_evaluation_changed(_should_evaluate_async())
	_cached_array_mesh = null
	_cached_array_mesh_evaluation_revision = -1


func _mark_async_evaluation_changed(restart_when_ready: bool) -> void:
	_async_generation += 1
	_async_restart_pending = _async_task_id >= 0 and restart_when_ready
	_async_last_cancelled = false
	_async_cancelled_source_revision = -1
	_async_cancelled_modifier_signatures.clear()
	_async_user_cancel_requested = false
	if _async_task_id >= 0 and _async_job != null:
		_async_job.request_cancel()


func invalidate_material_cache() -> void:
	_position_array_mesh_preserved = false
	_cached_array_mesh = null
	_cached_array_mesh_evaluation_revision = -1
	_cached_material_signature = 0


func invalidate_all_caches() -> void:
	invalidate_geometry_cache()
	invalidate_material_cache()


func _get_material_signature() -> int:
	var values: Array = []
	for source_material: StandardMaterial3D in materials:
		if source_material == null:
			values.append(0)
			continue
		values.append([
			source_material.get_instance_id(),
			source_material.resource_name,
			source_material.albedo_color,
			source_material.albedo_texture.get_instance_id() if source_material.albedo_texture != null else 0,
			source_material.metallic,
			source_material.roughness,
			source_material.cull_mode,
			source_material.transparency,
		])
	return hash(values)


func get_active_material() -> StandardMaterial3D:
	if materials.is_empty():
		return material
	return materials[clampi(active_material_index, 0, materials.size() - 1)]


func get_material_at(index: int) -> StandardMaterial3D:
	if index < 0 or index >= materials.size():
		return null
	return materials[index]


func set_material_slots(new_materials: Array[StandardMaterial3D], new_active_index: int = 0) -> void:
	materials = duplicate_materials(new_materials)
	_normalize_material_slots()
	active_material_index = clampi(new_active_index, 0, materials.size() - 1)
	_sync_legacy_material()
	invalidate_material_cache()


func set_active_material_index(index: int) -> void:
	if materials.is_empty():
		active_material_index = 0
		return
	active_material_index = clampi(index, 0, materials.size() - 1)


func _normalize_material_slots() -> void:
	if materials.is_empty():
		materials.append(create_default_material("Material 1"))
	for index: int in materials.size():
		if materials[index] == null:
			materials[index] = create_default_material("Material %d" % (index + 1))
		if materials[index].resource_name.is_empty():
			materials[index].resource_name = "Material %d" % (index + 1)
		if materials[index].cull_mode == BaseMaterial3D.CULL_DISABLED:
			materials[index].cull_mode = BaseMaterial3D.CULL_BACK


func _sync_legacy_material() -> void:
	material = materials[0] if not materials.is_empty() else null


static func duplicate_materials(source: Array[StandardMaterial3D]) -> Array[StandardMaterial3D]:
	var result: Array[StandardMaterial3D] = []
	for source_material: StandardMaterial3D in source:
		if source_material != null:
			result.append(source_material.duplicate(true) as StandardMaterial3D)
		else:
			result.append(null)
	return result


static func duplicate_modifiers(source: Array[GMSModifier]) -> Array[GMSModifier]:
	var result: Array[GMSModifier] = []
	for modifier: GMSModifier in source:
		if modifier != null:
			result.append(modifier.duplicate_modifier())
	return result


static func create_default_material(material_name: String = "Material") -> StandardMaterial3D:
	var new_material: StandardMaterial3D = StandardMaterial3D.new()
	new_material.resource_name = material_name
	new_material.albedo_color = Color(0.58, 0.62, 0.68)
	new_material.roughness = 0.72
	new_material.cull_mode = BaseMaterial3D.CULL_BACK
	return new_material


static func _generate_id() -> String:
	return "%s_%s" % [str(Time.get_ticks_usec()), str(randi())]
