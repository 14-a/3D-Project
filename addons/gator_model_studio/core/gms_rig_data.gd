@tool
class_name GMSRigData
extends Resource

enum BrushMode {
	ADD,
	SUBTRACT,
	REPLACE,
	SMOOTH,
}

const MAX_INFLUENCES: int = 4
const MIN_WEIGHT: float = 0.00001

@export var format_version: int = 1
@export var bones: Array[GMSBoneData] = []
@export var vertex_bones: PackedInt32Array = PackedInt32Array()
@export var vertex_weights: PackedFloat32Array = PackedFloat32Array()
@export var ik_chains: Array[GMSIKChainData] = []
@export var constraints: Array[GMSBoneConstraintData] = []

var pose_positions: Array[Vector3] = []
var pose_rotations: Array[Quaternion] = []
var pose_scales: Array[Vector3] = []
var _weight_validation_dirty: bool = true
var _cached_weights_valid: bool = false
var _cached_validation_vertex_count: int = -1
var _cached_validation_bone_count: int = -1


func ensure_defaults(vertex_count: int = -1) -> void:
	var original_bones: Array[GMSBoneData] = bones
	var old_to_new: Dictionary = {}
	var old_parents: PackedInt32Array = PackedInt32Array()
	var sanitized: Array[GMSBoneData] = []
	var used_names: Dictionary = {}
	for old_index: int in original_bones.size():
		var bone: GMSBoneData = original_bones[old_index]
		if bone == null:
			continue
		old_to_new[old_index] = sanitized.size()
		old_parents.append(bone.parent_index)
		bone.parent_index = -1
		bone.ensure_defaults(sanitized.size())
		bone.display_name = _unique_name_from_used(bone.display_name, used_names)
		used_names[bone.display_name] = true
		sanitized.append(bone)

	for new_index: int in sanitized.size():
		var old_parent: int = old_parents[new_index]
		if old_to_new.has(old_parent):
			var new_parent: int = int(old_to_new[old_parent])
			if new_parent >= 0 and new_parent < new_index:
				sanitized[new_index].parent_index = new_parent

	var removed_bones: bool = sanitized.size() != original_bones.size()
	bones = sanitized
	if removed_bones and not vertex_bones.is_empty():
		_remap_weight_bone_indices(old_to_new)
	_ensure_pose_arrays(removed_bones)
	_sanitize_animation_helpers()
	if vertex_count >= 0:
		ensure_weight_layout(vertex_count)
	elif removed_bones and not vertex_weights.is_empty():
		_sanitize_weights()


func duplicate_rig() -> GMSRigData:
	var copy: GMSRigData = GMSRigData.new()
	copy.format_version = format_version
	for bone: GMSBoneData in bones:
		if bone != null:
			copy.bones.append(bone.duplicate_bone())
	copy.vertex_bones = vertex_bones.duplicate()
	copy.vertex_weights = vertex_weights.duplicate()
	for chain: GMSIKChainData in ik_chains:
		if chain != null:
			copy.ik_chains.append(chain.duplicate_chain())
	for constraint: GMSBoneConstraintData in constraints:
		if constraint != null:
			copy.constraints.append(constraint.duplicate_constraint())
	copy.pose_positions = pose_positions.duplicate()
	copy.pose_rotations = pose_rotations.duplicate()
	copy.pose_scales = pose_scales.duplicate()
	copy.ensure_defaults(get_vertex_count())
	return copy


func find_bone_by_id(bone_id: String) -> int:
	if bone_id.is_empty():
		return -1
	for bone_index: int in bones.size():
		var bone: GMSBoneData = bones[bone_index]
		if bone != null and bone.bone_id == bone_id:
			return bone_index
	return -1


func find_bone_by_name(bone_name: String) -> int:
	if bone_name.is_empty():
		return -1
	for bone_index: int in bones.size():
		var bone: GMSBoneData = bones[bone_index]
		if bone != null and bone.display_name == bone_name:
			return bone_index
	return -1


func resolve_bone(bone_id: String, bone_name: String = "") -> int:
	var bone_index: int = find_bone_by_id(bone_id)
	if bone_index >= 0:
		return bone_index
	return find_bone_by_name(bone_name)


func has_bones() -> bool:
	return not bones.is_empty()


func has_weights() -> bool:
	return has_bones() and not vertex_weights.is_empty() and vertex_weights.size() == vertex_bones.size()


func get_vertex_count() -> int:
	if vertex_bones.size() % MAX_INFLUENCES != 0:
		return 0
	return int(vertex_bones.size() / MAX_INFLUENCES)


func is_compatible(vertex_count: int) -> bool:
	# Repair legacy duplicate names and invalid parent references before the rig
	# is considered for viewport skinning or export.
	ensure_defaults()
	if (
		not has_bones()
		or get_vertex_count() != vertex_count
		or vertex_weights.size() != vertex_count * MAX_INFLUENCES
		or not _is_skeleton_layout_valid()
	):
		return false
	if (
		_weight_validation_dirty
		or _cached_validation_vertex_count != vertex_count
		or _cached_validation_bone_count != bones.size()
	):
		_cached_weights_valid = _weights_reference_valid_bones()
		_cached_validation_vertex_count = vertex_count
		_cached_validation_bone_count = bones.size()
		_weight_validation_dirty = false
	return _cached_weights_valid


func ensure_weight_layout(vertex_count: int) -> void:
	_weight_validation_dirty = true
	var safe_count: int = maxi(vertex_count, 0)
	var expected: int = safe_count * MAX_INFLUENCES
	if vertex_bones.size() == expected and vertex_weights.size() == expected:
		_sanitize_weights()
		return
	vertex_bones.resize(expected)
	vertex_bones.fill(0)
	vertex_weights.resize(expected)
	vertex_weights.fill(0.0)
	if safe_count > 0 and not bones.is_empty():
		for vertex_index: int in safe_count:
			vertex_weights[vertex_index * MAX_INFLUENCES] = 1.0


func clear_weights(vertex_count: int = -1) -> void:
	_weight_validation_dirty = true
	var count: int = vertex_count if vertex_count >= 0 else get_vertex_count()
	vertex_bones.resize(maxi(count, 0) * MAX_INFLUENCES)
	vertex_bones.fill(0)
	vertex_weights.resize(maxi(count, 0) * MAX_INFLUENCES)
	vertex_weights.fill(0.0)


func add_root_bone(head_position: Vector3, tail_position: Vector3, name_hint: String = "Root") -> int:
	var bone: GMSBoneData = GMSBoneData.new()
	bone.display_name = _unique_bone_name(name_hint)
	bone.parent_index = -1
	bone.head = head_position
	bone.tail = tail_position
	bone.ensure_defaults(bones.size())
	bones.append(bone)
	_ensure_pose_arrays()
	emit_changed()
	return bones.size() - 1


func extrude_bone(parent_index: int) -> int:
	if parent_index < 0 or parent_index >= bones.size():
		return -1
	var parent: GMSBoneData = bones[parent_index]
	var direction: Vector3 = parent.get_direction()
	var length: float = parent.get_length()
	var bone: GMSBoneData = GMSBoneData.new()
	bone.display_name = _unique_bone_name("%s Child" % parent.display_name)
	bone.parent_index = parent_index
	bone.head = parent.tail
	bone.tail = parent.tail + direction * length
	bone.roll = parent.roll
	bone.ensure_defaults(bones.size())
	bones.append(bone)
	_ensure_pose_arrays()
	emit_changed()
	return bones.size() - 1


func delete_bone(bone_index: int) -> bool:
	_weight_validation_dirty = true
	if bone_index < 0 or bone_index >= bones.size():
		return false
	var removed_parent: int = bones[bone_index].parent_index
	bones.remove_at(bone_index)
	for bone: GMSBoneData in bones:
		if bone.parent_index == bone_index:
			bone.parent_index = removed_parent
		elif bone.parent_index > bone_index:
			bone.parent_index -= 1
	for influence_index: int in vertex_bones.size():
		var mapped: int = vertex_bones[influence_index]
		if mapped == bone_index:
			vertex_weights[influence_index] = 0.0
			vertex_bones[influence_index] = 0
		elif mapped > bone_index:
			vertex_bones[influence_index] = mapped - 1
	_normalize_all_vertices()
	_ensure_pose_arrays(true)
	_sanitize_animation_helpers()
	emit_changed()
	return true


func mirror_bone_x(bone_index: int) -> int:
	var mirrored_indices: PackedInt32Array = mirror_bone_subtree_x(bone_index)
	return mirrored_indices[0] if not mirrored_indices.is_empty() else -1


func mirror_bone_subtree_x(bone_index: int) -> PackedInt32Array:
	_weight_validation_dirty = true
	var result: PackedInt32Array = PackedInt32Array()
	if bone_index < 0 or bone_index >= bones.size():
		return result
	ensure_defaults()

	var source_indices: Array[int] = []
	var source_set: Dictionary = {}
	for candidate_index: int in bones.size():
		if candidate_index == bone_index or _is_descendant_of(candidate_index, bone_index):
			source_indices.append(candidate_index)
			source_set[candidate_index] = true

	var existing_by_name: Dictionary = {}
	for candidate_index: int in bones.size():
		if source_set.has(candidate_index):
			continue
		existing_by_name[bones[candidate_index].display_name] = candidate_index

	var source_to_target: Dictionary = {}
	for source_index: int in source_indices:
		var source: GMSBoneData = bones[source_index]
		var target_name: String = _mirrored_name(source.display_name)
		var target_index: int = int(existing_by_name.get(target_name, -1))
		var target: GMSBoneData
		if target_index >= 0 and target_index < bones.size():
			target = bones[target_index]
		else:
			target = source.duplicate_bone()
			target.bone_id = ""
			target.display_name = _unique_bone_name(target_name)
			target.parent_index = -1
			target.ensure_defaults(bones.size())
			bones.append(target)
			target_index = bones.size() - 1
			existing_by_name[target.display_name] = target_index

		target.display_name = _unique_bone_name(target_name, target_index)
		target.head = Vector3(-source.head.x, source.head.y, source.head.z)
		target.tail = Vector3(-source.tail.x, source.tail.y, source.tail.z)
		target.roll = -source.roll
		target.locked = source.locked

		var target_parent: int = -1
		if source.parent_index >= 0:
			if source_to_target.has(source.parent_index):
				target_parent = int(source_to_target[source.parent_index])
			else:
				var source_parent_name: String = bones[source.parent_index].display_name
				if _has_explicit_side_name(source_parent_name):
					target_parent = find_mirrored_bone(source.parent_index)
				if target_parent < 0 or source_set.has(target_parent):
					target_parent = source.parent_index
		target.parent_index = target_parent

		if source.parent_index >= 0 and target_parent >= 0:
			var source_parent: GMSBoneData = bones[source.parent_index]
			if source.head.distance_squared_to(source_parent.tail) <= 0.000001:
				target.head = bones[target_parent].tail
		if target.head.is_equal_approx(target.tail):
			target.tail = target.head + Vector3.UP * 0.001
		source_to_target[source_index] = target_index

	var old_to_new: Dictionary = _reorder_bones_parent_first()
	for source_index: int in source_indices:
		var old_target_index: int = int(source_to_target[source_index])
		if old_to_new.has(old_target_index):
			result.append(int(old_to_new[old_target_index]))
	_ensure_pose_arrays(true)
	if not vertex_weights.is_empty():
		_sanitize_weights()
	emit_changed()
	return result


func can_parent_bone(bone_index: int, new_parent_index: int) -> bool:
	if bone_index < 0 or bone_index >= bones.size():
		return false
	if new_parent_index < 0:
		return true
	if new_parent_index >= bones.size() or new_parent_index == bone_index:
		return false
	return not _is_descendant_of(new_parent_index, bone_index)


func set_bone_parent(bone_index: int, new_parent_index: int) -> bool:
	if not can_parent_bone(bone_index, new_parent_index):
		return false
	if bones[bone_index].parent_index == new_parent_index:
		return false
	bones[bone_index].parent_index = new_parent_index
	_reorder_bones_parent_first()
	_sanitize_animation_helpers()
	emit_changed()
	return true


func move_bone_endpoint(
	bone_index: int,
	move_tail: bool,
	new_position: Vector3,
	propagate_connected: bool = true
) -> bool:
	if bone_index < 0 or bone_index >= bones.size() or bones[bone_index].locked:
		return false
	var bone: GMSBoneData = bones[bone_index]
	var old_position: Vector3 = bone.tail if move_tail else bone.head
	var safe_position: Vector3 = new_position
	if move_tail and safe_position.is_equal_approx(bone.head):
		safe_position = bone.head + bone.get_direction() * 0.001
	elif not move_tail and safe_position.is_equal_approx(bone.tail):
		safe_position = bone.tail - bone.get_direction() * 0.001
	if move_tail:
		bone.tail = safe_position
	else:
		bone.head = safe_position
	if propagate_connected:
		if move_tail:
			_move_child_heads_at_joint(bone_index, old_position, safe_position)
		else:
			var parent_index: int = bone.parent_index
			if parent_index >= 0 and bones[parent_index].tail.distance_squared_to(old_position) <= 0.000001:
				bones[parent_index].tail = safe_position
				_move_child_heads_at_joint(parent_index, old_position, safe_position)
	emit_changed()
	return true


func _move_child_heads_at_joint(parent_index: int, old_position: Vector3, new_position: Vector3) -> void:
	for child_index: int in bones.size():
		var child: GMSBoneData = bones[child_index]
		if child.parent_index == parent_index and child.head.distance_squared_to(old_position) <= 0.000001:
			child.head = new_position


func set_bone_name(bone_index: int, new_name: String) -> void:
	if bone_index < 0 or bone_index >= bones.size():
		return
	var cleaned: String = new_name.strip_edges().replace(":", "_").replace("/", "_")
	if cleaned.is_empty():
		cleaned = "Bone %d" % (bone_index + 1)
	bones[bone_index].display_name = _unique_bone_name(cleaned, bone_index)
	_sanitize_animation_helpers()
	emit_changed()


func set_bone_rest(bone_index: int, head_position: Vector3, tail_position: Vector3, roll_value: float) -> void:
	if bone_index < 0 or bone_index >= bones.size():
		return
	var bone: GMSBoneData = bones[bone_index]
	if bone.locked:
		return
	bone.head = head_position
	bone.tail = tail_position if not tail_position.is_equal_approx(head_position) else head_position + Vector3.UP * 0.001
	bone.roll = roll_value
	emit_changed()


func transform_rest(local_transform: Transform3D) -> void:
	for bone: GMSBoneData in bones:
		var old_rest: Transform3D = bone.get_global_rest()
		var transformed_basis: Basis = (local_transform.basis * old_rest.basis).orthonormalized()
		bone.head = local_transform * bone.head
		bone.tail = local_transform * bone.tail
		if bone.head.is_equal_approx(bone.tail):
			bone.tail = bone.head + transformed_basis.y * 0.001
		var base_basis: Basis = bone.get_base_basis()
		var y_axis: Vector3 = bone.get_direction()
		var base_x: Vector3 = (base_basis.x - y_axis * base_basis.x.dot(y_axis)).normalized()
		var desired_x: Vector3 = (transformed_basis.x - y_axis * transformed_basis.x.dot(y_axis)).normalized()
		if base_x.is_zero_approx() or desired_x.is_zero_approx():
			bone.roll = 0.0
		else:
			bone.roll = atan2(y_axis.dot(base_x.cross(desired_x)), base_x.dot(desired_x))
	reset_pose()
	emit_changed()


func get_bone_global_rest(bone_index: int) -> Transform3D:
	if bone_index < 0 or bone_index >= bones.size():
		return Transform3D.IDENTITY
	return bones[bone_index].get_global_rest()


func get_bone_local_rest(bone_index: int) -> Transform3D:
	if bone_index < 0 or bone_index >= bones.size():
		return Transform3D.IDENTITY
	var global_rest: Transform3D = get_bone_global_rest(bone_index)
	var parent_index: int = bones[bone_index].parent_index
	if parent_index < 0:
		return global_rest
	return get_bone_global_rest(parent_index).affine_inverse() * global_rest


func build_skeleton(include_pose: bool = true) -> Skeleton3D:
	ensure_defaults()
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	var used_names: Dictionary = {}
	for bone_index: int in bones.size():
		var bone: GMSBoneData = bones[bone_index]
		var safe_name: String = _unique_name_from_used(bone.display_name, used_names)
		used_names[safe_name] = true
		skeleton.add_bone(safe_name)
		if skeleton.get_bone_count() <= bone_index:
			continue
		if bone.parent_index >= 0 and bone.parent_index < bone_index:
			skeleton.set_bone_parent(bone_index, bone.parent_index)
		var local_rest: Transform3D = get_bone_local_rest(bone_index)
		skeleton.set_bone_rest(bone_index, local_rest)
		# Skeleton3D's current pose is independent from the stored rest transform.
		# Initialize every bone at rest so an exported, non-preview skeleton does
		# not leave all bone poses as identity at the skeleton origin.
		skeleton.set_bone_pose(bone_index, local_rest)
	if include_pose:
		_apply_pose_to_skeleton(skeleton)
	skeleton.force_update_all_bone_transforms()
	return skeleton



func get_pose_offset(bone_index: int) -> Transform3D:
	if bone_index < 0 or bone_index >= bones.size():
		return Transform3D.IDENTITY
	_ensure_pose_arrays()
	return Transform3D(
		Basis(pose_rotations[bone_index]).scaled(pose_scales[bone_index]),
		pose_positions[bone_index]
	)


func set_pose_offset(bone_index: int, offset: Transform3D) -> void:
	if bone_index < 0 or bone_index >= bones.size():
		return
	_ensure_pose_arrays()
	pose_positions[bone_index] = offset.origin
	var scale: Vector3 = offset.basis.get_scale()
	if absf(scale.x) <= 0.000001:
		scale.x = 1.0
	if absf(scale.y) <= 0.000001:
		scale.y = 1.0
	if absf(scale.z) <= 0.000001:
		scale.z = 1.0
	var rotation_basis: Basis = offset.basis.scaled(Vector3(
		1.0 / scale.x,
		1.0 / scale.y,
		1.0 / scale.z
	)).orthonormalized()
	pose_rotations[bone_index] = rotation_basis.get_rotation_quaternion().normalized()
	pose_scales[bone_index] = scale


func apply_pose_offsets(offsets: Array[Transform3D]) -> void:
	_ensure_pose_arrays()
	for bone_index: int in mini(offsets.size(), bones.size()):
		set_pose_offset(bone_index, offsets[bone_index])


func get_pose_offsets() -> Array[Transform3D]:
	_ensure_pose_arrays()
	var result: Array[Transform3D] = []
	result.resize(bones.size())
	for bone_index: int in bones.size():
		result[bone_index] = get_pose_offset(bone_index)
	return result


func reset_pose(bone_index: int = -1) -> void:
	_ensure_pose_arrays()
	if bone_index >= 0 and bone_index < bones.size():
		pose_positions[bone_index] = Vector3.ZERO
		pose_rotations[bone_index] = Quaternion.IDENTITY
		pose_scales[bone_index] = Vector3.ONE
	else:
		for index: int in bones.size():
			pose_positions[index] = Vector3.ZERO
			pose_rotations[index] = Quaternion.IDENTITY
			pose_scales[index] = Vector3.ONE


func set_pose_rotation_degrees(bone_index: int, euler_degrees: Vector3) -> void:
	if bone_index < 0 or bone_index >= bones.size():
		return
	_ensure_pose_arrays()
	pose_rotations[bone_index] = Quaternion.from_euler(Vector3(
		deg_to_rad(euler_degrees.x),
		deg_to_rad(euler_degrees.y),
		deg_to_rad(euler_degrees.z)
	))


func get_pose_rotation_degrees(bone_index: int) -> Vector3:
	if bone_index < 0 or bone_index >= bones.size():
		return Vector3.ZERO
	_ensure_pose_arrays()
	var euler: Vector3 = pose_rotations[bone_index].get_euler()
	return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


func apply_pose_to_skeleton(skeleton: Skeleton3D) -> void:
	_apply_pose_to_skeleton(skeleton)


func _sanitize_animation_helpers() -> void:
	var clean_chains: Array[GMSIKChainData] = []
	var used_chain_ids: Dictionary = {}
	var used_chain_names: Dictionary = {}
	for chain: GMSIKChainData in ik_chains:
		if chain == null:
			continue
		chain.ensure_defaults(self)
		var chain_indices: PackedInt32Array = chain.get_chain_indices(self)
		if chain_indices.size() < 2:
			continue
		while used_chain_ids.has(chain.chain_id):
			chain.chain_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
		chain.display_name = _unique_name_from_used(chain.display_name, used_chain_names)
		used_chain_ids[chain.chain_id] = true
		used_chain_names[chain.display_name] = true
		clean_chains.append(chain)
	ik_chains = clean_chains

	var clean_constraints: Array[GMSBoneConstraintData] = []
	var used_constraint_ids: Dictionary = {}
	var used_constraint_names: Dictionary = {}
	for constraint: GMSBoneConstraintData in constraints:
		if constraint == null:
			continue
		constraint.ensure_defaults(self)
		if constraint.resolve_bone(self) < 0:
			continue
		if constraint.requires_target() and constraint.resolve_target(self) < 0:
			continue
		while used_constraint_ids.has(constraint.constraint_id):
			constraint.constraint_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
		constraint.display_name = _unique_name_from_used(constraint.display_name, used_constraint_names)
		used_constraint_ids[constraint.constraint_id] = true
		used_constraint_names[constraint.display_name] = true
		clean_constraints.append(constraint)
	constraints = clean_constraints


func find_ik_chain(chain_id: String) -> GMSIKChainData:
	for chain: GMSIKChainData in ik_chains:
		if chain != null and chain.chain_id == chain_id:
			return chain
	return null


func create_ik_chain(root_index: int, tip_index: int, name_hint: String = "IK Chain") -> GMSIKChainData:
	if root_index < 0 or tip_index < 0 or root_index >= bones.size() or tip_index >= bones.size():
		return null
	var chain: GMSIKChainData = GMSIKChainData.new()
	chain.display_name = name_hint
	chain.root_bone_id = bones[root_index].bone_id
	chain.root_bone_name = bones[root_index].display_name
	chain.tip_bone_id = bones[tip_index].bone_id
	chain.tip_bone_name = bones[tip_index].display_name
	chain.target_position = get_bone_tail_pose_position(tip_index)
	var indices: PackedInt32Array = chain.get_chain_indices(self)
	if indices.size() < 2:
		return null
	var globals: Array[Transform3D] = get_pose_global_transforms()
	var middle_index: int = indices[int(indices.size() / 2)]
	var root_position: Vector3 = globals[root_index].origin
	var middle_position: Vector3 = globals[middle_index].origin
	var chain_length: float = maxf(root_position.distance_to(chain.target_position), 0.1)
	var bend_direction: Vector3 = middle_position - root_position
	if bend_direction.is_zero_approx():
		bend_direction = globals[root_index].basis.z
	chain.pole_position = middle_position + bend_direction.normalized() * chain_length
	chain.ensure_defaults(self)
	ik_chains.append(chain)
	_sanitize_animation_helpers()
	emit_changed()
	return find_ik_chain(chain.chain_id)


func remove_ik_chain(chain_id: String) -> bool:
	var chain: GMSIKChainData = find_ik_chain(chain_id)
	if chain == null:
		return false
	ik_chains.erase(chain)
	emit_changed()
	return true


func find_constraint(constraint_id: String) -> GMSBoneConstraintData:
	for constraint: GMSBoneConstraintData in constraints:
		if constraint != null and constraint.constraint_id == constraint_id:
			return constraint
	return null


func create_constraint(bone_index: int, constraint_type: int = GMSBoneConstraintData.Type.LIMIT_ROTATION) -> GMSBoneConstraintData:
	if bone_index < 0 or bone_index >= bones.size():
		return null
	var constraint: GMSBoneConstraintData = GMSBoneConstraintData.new()
	constraint.type = clampi(
		constraint_type,
		GMSBoneConstraintData.Type.LIMIT_ROTATION,
		GMSBoneConstraintData.Type.LOOK_AT
	)
	constraint.bone_id = bones[bone_index].bone_id
	constraint.bone_name = bones[bone_index].display_name
	constraint.display_name = "%s Constraint" % bones[bone_index].display_name
	var target_index: int = bones[bone_index].parent_index
	if target_index < 0 and bones.size() > 1:
		target_index = 0 if bone_index != 0 else 1
	if target_index >= 0:
		constraint.target_bone_id = bones[target_index].bone_id
		constraint.target_bone_name = bones[target_index].display_name
	constraint.ensure_defaults(self)
	constraints.append(constraint)
	_sanitize_animation_helpers()
	emit_changed()
	return find_constraint(constraint.constraint_id)


func remove_constraint(constraint_id: String) -> bool:
	var constraint: GMSBoneConstraintData = find_constraint(constraint_id)
	if constraint == null:
		return false
	constraints.erase(constraint)
	emit_changed()
	return true


func get_pose_global_transforms(offsets: Array[Transform3D] = []) -> Array[Transform3D]:
	var source_offsets: Array[Transform3D] = offsets
	if source_offsets.is_empty():
		source_offsets = get_pose_offsets()
	var result: Array[Transform3D] = []
	result.resize(bones.size())
	for bone_index: int in bones.size():
		var offset: Transform3D = (
			source_offsets[bone_index]
			if bone_index < source_offsets.size()
			else Transform3D.IDENTITY
		)
		var local_pose: Transform3D = get_bone_local_rest(bone_index) * offset
		var parent_index: int = bones[bone_index].parent_index
		result[bone_index] = result[parent_index] * local_pose if parent_index >= 0 else local_pose
	return result


func get_bone_tail_pose_position(bone_index: int, offsets: Array[Transform3D] = []) -> Vector3:
	if bone_index < 0 or bone_index >= bones.size():
		return Vector3.ZERO
	var globals: Array[Transform3D] = get_pose_global_transforms(offsets)
	return globals[bone_index] * Vector3(0.0, bones[bone_index].get_length(), 0.0)


func solve_ik(chain_id: String, apply_live_constraints: bool = true) -> PackedInt32Array:
	var changed: PackedInt32Array = PackedInt32Array()
	var chain: GMSIKChainData = find_ik_chain(chain_id)
	if chain == null or not chain.enabled:
		return changed
	var chain_indices: PackedInt32Array = chain.get_chain_indices(self)
	if chain_indices.size() < 2:
		return changed
	var before: Array[Transform3D] = get_pose_offsets()
	var tip_index: int = chain_indices[chain_indices.size() - 1]
	for _iteration: int in chain.iterations:
		var tip_position: Vector3 = get_bone_tail_pose_position(tip_index)
		if tip_position.distance_to(chain.target_position) <= chain.tolerance:
			break
		for reverse_index: int in range(chain_indices.size() - 1, -1, -1):
			var joint_index: int = chain_indices[reverse_index]
			if bones[joint_index].locked:
				continue
			var globals: Array[Transform3D] = get_pose_global_transforms()
			var joint_position: Vector3 = globals[joint_index].origin
			var current_vector: Vector3 = get_bone_tail_pose_position(tip_index) - joint_position
			var target_vector: Vector3 = chain.target_position - joint_position
			if current_vector.length_squared() <= 0.0000000001 or target_vector.length_squared() <= 0.0000000001:
				continue
			var delta_rotation: Quaternion = Quaternion(current_vector.normalized(), target_vector.normalized())
			var desired_global: Transform3D = globals[joint_index]
			desired_global.basis = Basis(delta_rotation) * desired_global.basis
			_set_pose_from_global_transform(joint_index, desired_global)
	_apply_ik_pole(chain, chain_indices)
	if apply_live_constraints:
		apply_constraints()
	var after: Array[Transform3D] = get_pose_offsets()
	for bone_index: int in mini(before.size(), after.size()):
		if not _transform_approximately_equal(before[bone_index], after[bone_index]):
			changed.append(bone_index)
	return changed


func _apply_ik_pole(chain: GMSIKChainData, chain_indices: PackedInt32Array) -> void:
	if chain == null or chain.pole_influence <= 0.0 or chain_indices.size() < 3:
		return
	var globals: Array[Transform3D] = get_pose_global_transforms()
	var root_index: int = chain_indices[0]
	var middle_index: int = chain_indices[1]
	var tip_index: int = chain_indices[chain_indices.size() - 1]
	if bones[root_index].locked:
		return
	var root_position: Vector3 = globals[root_index].origin
	var tip_position: Vector3 = get_bone_tail_pose_position(tip_index)
	var axis: Vector3 = tip_position - root_position
	if axis.length_squared() <= 0.0000000001:
		return
	axis = axis.normalized()
	var current: Vector3 = globals[middle_index].origin - root_position
	var desired: Vector3 = chain.pole_position - root_position
	current -= axis * current.dot(axis)
	desired -= axis * desired.dot(axis)
	if current.length_squared() <= 0.0000000001 or desired.length_squared() <= 0.0000000001:
		return
	current = current.normalized()
	desired = desired.normalized()
	var angle: float = atan2(axis.dot(current.cross(desired)), current.dot(desired))
	angle *= chain.pole_influence
	var root_global: Transform3D = globals[root_index]
	root_global.basis = Basis(axis, angle) * root_global.basis
	_set_pose_from_global_transform(root_index, root_global)


func apply_constraints(maximum_passes: int = 4) -> PackedInt32Array:
	var changed: PackedInt32Array = PackedInt32Array()
	if constraints.is_empty():
		return changed
	var before: Array[Transform3D] = get_pose_offsets()
	for _pass_index: int in clampi(maximum_passes, 1, 8):
		for constraint: GMSBoneConstraintData in constraints:
			if constraint == null or not constraint.enabled or constraint.influence <= 0.0:
				continue
			_apply_constraint(constraint)
	var after: Array[Transform3D] = get_pose_offsets()
	for bone_index: int in mini(before.size(), after.size()):
		if not _transform_approximately_equal(before[bone_index], after[bone_index]):
			changed.append(bone_index)
	return changed


func _apply_constraint(constraint: GMSBoneConstraintData) -> void:
	var bone_index: int = constraint.resolve_bone(self)
	if bone_index < 0 or bone_index >= bones.size() or bones[bone_index].locked:
		return
	var influence: float = clampf(constraint.influence, 0.0, 1.0)
	var current: Transform3D = get_pose_offset(bone_index)
	match constraint.type:
		GMSBoneConstraintData.Type.LIMIT_ROTATION:
			var scale: Vector3 = current.basis.get_scale()
			var rotation: Quaternion = _rotation_without_scale(current.basis)
			var degrees: Vector3 = rotation.get_euler() * 180.0 / PI
			var limited: Vector3 = Vector3(
				clampf(degrees.x, constraint.minimum_rotation_degrees.x, constraint.maximum_rotation_degrees.x),
				clampf(degrees.y, constraint.minimum_rotation_degrees.y, constraint.maximum_rotation_degrees.y),
				clampf(degrees.z, constraint.minimum_rotation_degrees.z, constraint.maximum_rotation_degrees.z)
			)
			var target_rotation: Quaternion = Quaternion.from_euler(limited * PI / 180.0)
			var blended: Quaternion = rotation.slerp(target_rotation, influence).normalized()
			set_pose_offset(bone_index, Transform3D(Basis(blended).scaled(scale), current.origin))
		GMSBoneConstraintData.Type.COPY_ROTATION, GMSBoneConstraintData.Type.COPY_TRANSFORM:
			var target_index: int = constraint.resolve_target(self)
			if target_index < 0 or target_index == bone_index:
				return
			var target: Transform3D = get_pose_offset(target_index)
			var current_rotation: Quaternion = _rotation_without_scale(current.basis)
			var target_rotation: Quaternion = _rotation_without_scale(target.basis)
			var current_scale: Vector3 = current.basis.get_scale()
			var target_scale: Vector3 = target.basis.get_scale()
			var output_position: Vector3 = current.origin
			var output_scale: Vector3 = current_scale
			if constraint.type == GMSBoneConstraintData.Type.COPY_TRANSFORM:
				output_position = current.origin.lerp(target.origin, influence)
				output_scale = current_scale.lerp(target_scale, influence)
			set_pose_offset(bone_index, Transform3D(
				Basis(current_rotation.slerp(target_rotation, influence).normalized()).scaled(output_scale),
				output_position
			))
		GMSBoneConstraintData.Type.LOOK_AT:
			var target_index: int = constraint.resolve_target(self)
			if target_index < 0 or target_index == bone_index:
				return
			var globals: Array[Transform3D] = get_pose_global_transforms()
			var source_global: Transform3D = globals[bone_index]
			var target_direction: Vector3 = globals[target_index].origin - source_global.origin
			if target_direction.length_squared() <= 0.0000000001:
				return
			var current_aim: Vector3 = source_global.basis * constraint.aim_axis.normalized()
			if current_aim.length_squared() <= 0.0000000001:
				return
			var delta: Quaternion = Quaternion(current_aim.normalized(), target_direction.normalized())
			var current_global_rotation: Quaternion = _rotation_without_scale(source_global.basis)
			var target_global_basis: Basis = Basis(delta) * source_global.basis
			var target_global_rotation: Quaternion = _rotation_without_scale(target_global_basis)
			var global_scale: Vector3 = source_global.basis.get_scale()
			source_global.basis = Basis(
				current_global_rotation.slerp(target_global_rotation, influence).normalized()
			).scaled(global_scale)
			_set_pose_from_global_transform(bone_index, source_global)


func _set_pose_from_global_transform(bone_index: int, desired_global: Transform3D) -> void:
	if bone_index < 0 or bone_index >= bones.size():
		return
	var globals: Array[Transform3D] = get_pose_global_transforms()
	var parent_index: int = bones[bone_index].parent_index
	var desired_local: Transform3D = (
		globals[parent_index].affine_inverse() * desired_global
		if parent_index >= 0
		else desired_global
	)
	var offset: Transform3D = get_bone_local_rest(bone_index).affine_inverse() * desired_local
	set_pose_offset(bone_index, offset)


static func _rotation_without_scale(basis: Basis) -> Quaternion:
	var scale: Vector3 = basis.get_scale()
	for axis: int in 3:
		if absf(scale[axis]) <= 0.000001:
			scale[axis] = 1.0
	var rotation_basis: Basis = basis.scaled(Vector3(1.0 / scale.x, 1.0 / scale.y, 1.0 / scale.z)).orthonormalized()
	return rotation_basis.get_rotation_quaternion().normalized()


static func _transform_approximately_equal(a: Transform3D, b: Transform3D) -> bool:
	return (
		a.origin.is_equal_approx(b.origin)
		and a.basis.x.is_equal_approx(b.basis.x)
		and a.basis.y.is_equal_approx(b.basis.y)
		and a.basis.z.is_equal_approx(b.basis.z)
	)


func automatic_weights(mesh: GMSMeshData, smooth_iterations: int = 3) -> bool:
	_weight_validation_dirty = true
	if mesh == null or mesh.vertices.is_empty() or bones.is_empty():
		return false
	ensure_defaults(mesh.vertices.size())
	if not _is_skeleton_layout_valid():
		return false
	for vertex_index: int in mesh.vertices.size():
		var point: Vector3 = mesh.vertices[vertex_index]
		var scores: Dictionary = {}
		var nearest_bone: int = 0
		var nearest_distance: float = INF
		for bone_index: int in bones.size():
			var bone: GMSBoneData = bones[bone_index]
			var distance: float = _point_segment_distance(point, bone.head, bone.tail)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_bone = bone_index
			var influence_radius: float = maxf(bone.get_length() * 0.75, 0.0001)
			var normalized_distance: float = distance / influence_radius
			var score: float = exp(-normalized_distance * normalized_distance * 2.0)
			if score > MIN_WEIGHT:
				scores[bone_index] = score
		if scores.is_empty():
			scores[nearest_bone] = 1.0
		_set_vertex_scores(vertex_index, scores)
	for _iteration: int in clampi(smooth_iterations, 0, 8):
		_smooth_all_weights(mesh, 0.38)
	_normalize_all_vertices()
	if not _weights_reference_valid_bones():
		clear_weights(mesh.vertices.size())
		return false
	emit_changed()
	return true


func apply_weight_brush(
	mesh: GMSMeshData,
	bone_index: int,
	local_point: Vector3,
	radius: float,
	strength: float,
	mode: int
) -> int:
	_weight_validation_dirty = true
	if mesh == null or bone_index < 0 or bone_index >= bones.size() or radius <= 0.0:
		return 0
	if not is_compatible(mesh.vertices.size()):
		return 0
	var affected: PackedInt32Array = PackedInt32Array()
	var factors: PackedFloat32Array = PackedFloat32Array()
	for vertex_index: int in mesh.vertices.size():
		var distance: float = mesh.vertices[vertex_index].distance_to(local_point)
		if distance > radius:
			continue
		var normalized: float = clampf(1.0 - distance / radius, 0.0, 1.0)
		var falloff: float = normalized * normalized * (3.0 - 2.0 * normalized)
		affected.append(vertex_index)
		factors.append(falloff * clampf(strength, 0.0, 1.0))
	if affected.is_empty():
		return 0
	if mode == BrushMode.SMOOTH:
		var topology: GMSTopology = mesh.get_topology()
		var old_bones: PackedInt32Array = vertex_bones.duplicate()
		var old_weights: PackedFloat32Array = vertex_weights.duplicate()
		for affected_index: int in affected.size():
			var vertex_index: int = affected[affected_index]
			var neighbors: PackedInt32Array = topology.get_vertex_neighbors(vertex_index)
			if neighbors.is_empty():
				continue
			var average: float = 0.0
			for neighbor: int in neighbors:
				average += _weight_from_arrays(old_bones, old_weights, neighbor, bone_index)
			average /= float(neighbors.size())
			var current: float = get_vertex_weight(vertex_index, bone_index)
			set_vertex_weight(vertex_index, bone_index, lerpf(current, average, factors[affected_index]), false)
	else:
		for affected_index: int in affected.size():
			var vertex_index: int = affected[affected_index]
			var factor: float = factors[affected_index]
			var current: float = get_vertex_weight(vertex_index, bone_index)
			var target: float = current
			match mode:
				BrushMode.ADD:
					target = current + (1.0 - current) * factor
				BrushMode.SUBTRACT:
					target = current * (1.0 - factor)
				BrushMode.REPLACE:
					target = lerpf(current, clampf(strength, 0.0, 1.0), factor)
			set_vertex_weight(vertex_index, bone_index, target, false)
	for vertex_index: int in affected:
		_normalize_vertex(vertex_index, bone_index)
	emit_changed()
	return affected.size()


func assign_weight(vertex_indices: PackedInt32Array, bone_index: int, weight: float) -> void:
	_weight_validation_dirty = true
	if bone_index < 0 or bone_index >= bones.size():
		return
	for vertex_index: int in vertex_indices:
		if vertex_index < 0 or vertex_index >= get_vertex_count():
			continue
		_set_vertex_weight_exact(vertex_index, bone_index, clampf(weight, 0.0, 1.0))
	emit_changed()


func remove_weight(vertex_indices: PackedInt32Array, bone_index: int) -> void:
	_weight_validation_dirty = true
	if bone_index < 0 or bone_index >= bones.size():
		return
	for vertex_index: int in vertex_indices:
		if vertex_index < 0 or vertex_index >= get_vertex_count():
			continue
		set_vertex_weight(vertex_index, bone_index, 0.0, false)
		_normalize_vertex(vertex_index)
	emit_changed()


func smooth_selected_weights(mesh: GMSMeshData, vertex_indices: PackedInt32Array, factor: float = 0.5) -> void:
	_weight_validation_dirty = true
	if mesh == null or vertex_indices.is_empty() or not is_compatible(mesh.vertices.size()):
		return
	var topology: GMSTopology = mesh.get_topology()
	var old_bones: PackedInt32Array = vertex_bones.duplicate()
	var old_weights: PackedFloat32Array = vertex_weights.duplicate()
	for vertex_index: int in vertex_indices:
		if vertex_index < 0 or vertex_index >= mesh.vertices.size():
			continue
		var neighbors: PackedInt32Array = topology.get_vertex_neighbors(vertex_index)
		if neighbors.is_empty():
			continue
		var scores: Dictionary = _scores_from_arrays(old_bones, old_weights, vertex_index, 1.0 - factor)
		var neighbor_factor: float = factor / float(neighbors.size())
		for neighbor: int in neighbors:
			_accumulate_scores(scores, _scores_from_arrays(old_bones, old_weights, neighbor, neighbor_factor))
		_set_vertex_scores(vertex_index, scores)
	emit_changed()


func mirror_weights_x(mesh: GMSMeshData, tolerance: float = 0.001) -> int:
	_weight_validation_dirty = true
	if mesh == null or not is_compatible(mesh.vertices.size()):
		return 0
	var cell_size: float = maxf(tolerance, mesh.get_aabb().size.length() * 0.0005)
	var spatial: Dictionary = {}
	for vertex_index: int in mesh.vertices.size():
		var key: Vector3i = _quantize_point(mesh.vertices[vertex_index], cell_size)
		var values: PackedInt32Array = spatial.get(key, PackedInt32Array())
		values.append(vertex_index)
		spatial[key] = values
	var old_bones: PackedInt32Array = vertex_bones.duplicate()
	var old_weights: PackedFloat32Array = vertex_weights.duplicate()
	var mirrored_count: int = 0
	for vertex_index: int in mesh.vertices.size():
		var point: Vector3 = mesh.vertices[vertex_index]
		if point.x < -cell_size:
			continue
		var mirror_point: Vector3 = Vector3(-point.x, point.y, point.z)
		var best_index: int = _find_spatial_vertex(mesh, spatial, mirror_point, cell_size)
		if best_index < 0:
			continue
		var scores: Dictionary = {}
		for slot: int in MAX_INFLUENCES:
			var source_offset: int = vertex_index * MAX_INFLUENCES + slot
			var source_bone: int = old_bones[source_offset]
			var source_weight: float = old_weights[source_offset]
			if source_weight <= MIN_WEIGHT:
				continue
			var mirrored_bone: int = find_mirrored_bone(source_bone)
			scores[mirrored_bone if mirrored_bone >= 0 else source_bone] = source_weight
		_set_vertex_scores(best_index, scores)
		mirrored_count += 1
	emit_changed()
	return mirrored_count


func find_mirrored_bone(bone_index: int) -> int:
	if bone_index < 0 or bone_index >= bones.size():
		return -1
	var target_name: String = _mirrored_name(bones[bone_index].display_name)
	for index: int in bones.size():
		if bones[index].display_name == target_name:
			return index
	return -1


func get_vertex_weight(vertex_index: int, bone_index: int) -> float:
	if vertex_index < 0 or vertex_index >= get_vertex_count():
		return 0.0
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		if vertex_bones[offset + slot] == bone_index:
			return vertex_weights[offset + slot]
	return 0.0


func set_vertex_weight(vertex_index: int, bone_index: int, weight: float, normalize: bool = true) -> void:
	_weight_validation_dirty = true
	if vertex_index < 0 or vertex_index >= get_vertex_count() or bone_index < 0 or bone_index >= bones.size():
		return
	var offset: int = vertex_index * MAX_INFLUENCES
	var free_slot: int = -1
	var weakest_slot: int = 0
	for slot: int in MAX_INFLUENCES:
		var influence_offset: int = offset + slot
		if vertex_bones[influence_offset] == bone_index:
			vertex_weights[influence_offset] = clampf(weight, 0.0, 1.0)
			if normalize:
				_normalize_vertex(vertex_index, bone_index)
			return
		if vertex_weights[influence_offset] <= MIN_WEIGHT and free_slot < 0:
			free_slot = slot
		if vertex_weights[influence_offset] < vertex_weights[offset + weakest_slot]:
			weakest_slot = slot
	var target_slot: int = free_slot if free_slot >= 0 else weakest_slot
	vertex_bones[offset + target_slot] = bone_index
	vertex_weights[offset + target_slot] = clampf(weight, 0.0, 1.0)
	if normalize:
		_normalize_vertex(vertex_index, bone_index)


func _set_vertex_weight_exact(vertex_index: int, bone_index: int, target_weight: float) -> void:
	if vertex_index < 0 or vertex_index >= get_vertex_count() or bone_index < 0 or bone_index >= bones.size():
		return
	var target: float = clampf(target_weight, 0.0, 1.0)
	set_vertex_weight(vertex_index, bone_index, target, false)
	var offset: int = vertex_index * MAX_INFLUENCES
	var target_slot: int = -1
	var other_total: float = 0.0
	for slot: int in MAX_INFLUENCES:
		if vertex_bones[offset + slot] == bone_index:
			target_slot = slot
		else:
			other_total += maxf(vertex_weights[offset + slot], 0.0)
	if target_slot < 0:
		return
	vertex_weights[offset + target_slot] = target
	var remaining: float = 1.0 - target
	if other_total <= MIN_WEIGHT:
		for slot: int in MAX_INFLUENCES:
			if slot != target_slot:
				vertex_weights[offset + slot] = 0.0
		if target < 1.0 and bones.size() > 1:
			var fallback_bone: int = 0 if bone_index != 0 else 1
			var fallback_slot: int = 0 if target_slot != 0 else 1
			vertex_bones[offset + fallback_slot] = fallback_bone
			vertex_weights[offset + fallback_slot] = remaining
		elif target <= MIN_WEIGHT:
			vertex_weights[offset + target_slot] = 1.0
		return
	for slot: int in MAX_INFLUENCES:
		if slot == target_slot:
			continue
		vertex_weights[offset + slot] = maxf(vertex_weights[offset + slot], 0.0) / other_total * remaining


func get_render_bones_for_model_vertex(vertex_index: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(MAX_INFLUENCES)
	if vertex_index < 0 or vertex_index >= get_vertex_count():
		return result
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		var bone_index: int = vertex_bones[offset + slot]
		result[slot] = bone_index if bone_index >= 0 and bone_index < bones.size() else 0
	return result


func get_render_weights_for_model_vertex(vertex_index: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(MAX_INFLUENCES)
	if vertex_index < 0 or vertex_index >= get_vertex_count():
		return result
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		result[slot] = vertex_weights[offset + slot]
	return result


func _ensure_pose_arrays(force_reset: bool = false) -> void:
	if force_reset or pose_positions.size() != bones.size():
		pose_positions.resize(bones.size())
		for index: int in pose_positions.size():
			pose_positions[index] = Vector3.ZERO
	if force_reset or pose_rotations.size() != bones.size():
		pose_rotations.resize(bones.size())
		for index: int in pose_rotations.size():
			pose_rotations[index] = Quaternion.IDENTITY
	if force_reset or pose_scales.size() != bones.size():
		pose_scales.resize(bones.size())
		for index: int in pose_scales.size():
			pose_scales[index] = Vector3.ONE


func _apply_pose_to_skeleton(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	_ensure_pose_arrays()
	for bone_index: int in mini(bones.size(), skeleton.get_bone_count()):
		# Godot 4 stores each bone pose as an absolute local transform. GMS keeps
		# pose preview values as offsets from the rest pose, so compose the offset
		# onto the local rest before assigning the Skeleton3D pose.
		var pose_basis: Basis = Basis(pose_rotations[bone_index]).scaled(pose_scales[bone_index])
		var pose_offset: Transform3D = Transform3D(pose_basis, pose_positions[bone_index])
		var local_pose: Transform3D = get_bone_local_rest(bone_index) * pose_offset
		skeleton.set_bone_pose(bone_index, local_pose)


func _smooth_all_weights(mesh: GMSMeshData, factor: float) -> void:
	var topology: GMSTopology = mesh.get_topology()
	var old_bones: PackedInt32Array = vertex_bones.duplicate()
	var old_weights: PackedFloat32Array = vertex_weights.duplicate()
	for vertex_index: int in mesh.vertices.size():
		var neighbors: PackedInt32Array = topology.get_vertex_neighbors(vertex_index)
		if neighbors.is_empty():
			continue
		var scores: Dictionary = _scores_from_arrays(old_bones, old_weights, vertex_index, 1.0 - factor)
		var neighbor_factor: float = factor / float(neighbors.size())
		for neighbor: int in neighbors:
			_accumulate_scores(scores, _scores_from_arrays(old_bones, old_weights, neighbor, neighbor_factor))
		_set_vertex_scores(vertex_index, scores)


func _set_vertex_scores(vertex_index: int, scores: Dictionary) -> void:
	_weight_validation_dirty = true
	if vertex_index < 0 or vertex_index >= get_vertex_count():
		return
	var entries: Array[Vector2] = []
	for bone_value: Variant in scores.keys():
		var bone_index: int = int(bone_value)
		var score: float = maxf(float(scores[bone_value]), 0.0)
		if bone_index >= 0 and bone_index < bones.size() and score > MIN_WEIGHT:
			entries.append(Vector2(float(bone_index), score))
	entries.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		vertex_bones[offset + slot] = 0
		vertex_weights[offset + slot] = 0.0
	var total: float = 0.0
	for slot: int in mini(entries.size(), MAX_INFLUENCES):
		vertex_bones[offset + slot] = int(entries[slot].x)
		vertex_weights[offset + slot] = entries[slot].y
		total += entries[slot].y
	if total <= MIN_WEIGHT:
		vertex_bones[offset] = 0
		vertex_weights[offset] = 1.0 if not bones.is_empty() else 0.0
		return
	for slot: int in MAX_INFLUENCES:
		vertex_weights[offset + slot] /= total


func _normalize_all_vertices() -> void:
	for vertex_index: int in get_vertex_count():
		_normalize_vertex(vertex_index)


func _normalize_vertex(vertex_index: int, preferred_bone: int = -1) -> void:
	if vertex_index < 0 or vertex_index >= get_vertex_count():
		return
	var offset: int = vertex_index * MAX_INFLUENCES
	var total: float = 0.0
	for slot: int in MAX_INFLUENCES:
		var influence_offset: int = offset + slot
		if vertex_bones[influence_offset] < 0 or vertex_bones[influence_offset] >= bones.size():
			vertex_bones[influence_offset] = 0
			vertex_weights[influence_offset] = 0.0
		vertex_weights[influence_offset] = clampf(vertex_weights[influence_offset], 0.0, 1.0)
		total += vertex_weights[influence_offset]
	if total <= MIN_WEIGHT:
		var fallback: int = preferred_bone if preferred_bone >= 0 and preferred_bone < bones.size() else 0
		vertex_bones[offset] = fallback
		vertex_weights[offset] = 1.0 if not bones.is_empty() else 0.0
		for slot: int in range(1, MAX_INFLUENCES):
			vertex_bones[offset + slot] = 0
			vertex_weights[offset + slot] = 0.0
		return
	for slot: int in MAX_INFLUENCES:
		vertex_weights[offset + slot] /= total


func _sanitize_weights() -> void:
	for vertex_index: int in get_vertex_count():
		_normalize_vertex(vertex_index)


func _scores_from_arrays(
	bones_array: PackedInt32Array,
	weights_array: PackedFloat32Array,
	vertex_index: int,
	factor: float
) -> Dictionary:
	var scores: Dictionary = {}
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		var bone_index: int = bones_array[offset + slot]
		var weight: float = weights_array[offset + slot] * factor
		if weight > MIN_WEIGHT:
			scores[bone_index] = float(scores.get(bone_index, 0.0)) + weight
	return scores


func _accumulate_scores(target: Dictionary, source: Dictionary) -> void:
	for bone_value: Variant in source.keys():
		target[bone_value] = float(target.get(bone_value, 0.0)) + float(source[bone_value])


func _weight_from_arrays(bones_array: PackedInt32Array, weights_array: PackedFloat32Array, vertex_index: int, bone_index: int) -> float:
	var offset: int = vertex_index * MAX_INFLUENCES
	for slot: int in MAX_INFLUENCES:
		if bones_array[offset + slot] == bone_index:
			return weights_array[offset + slot]
	return 0.0


func _is_skeleton_layout_valid() -> bool:
	var used_names: Dictionary = {}
	for bone_index: int in bones.size():
		var bone: GMSBoneData = bones[bone_index]
		if bone == null or bone.display_name.is_empty() or used_names.has(bone.display_name):
			return false
		used_names[bone.display_name] = true
		if bone.parent_index >= bone_index or bone.parent_index < -1:
			return false
	return true


func _weights_reference_valid_bones() -> bool:
	if vertex_bones.size() != vertex_weights.size() or vertex_bones.size() % MAX_INFLUENCES != 0:
		return false
	for vertex_index: int in get_vertex_count():
		var offset: int = vertex_index * MAX_INFLUENCES
		var total: float = 0.0
		for slot: int in MAX_INFLUENCES:
			var influence_offset: int = offset + slot
			var bone_index: int = vertex_bones[influence_offset]
			var weight: float = vertex_weights[influence_offset]
			if bone_index < 0 or bone_index >= bones.size() or is_nan(weight) or is_inf(weight) or weight < 0.0:
				return false
			total += weight
		if total <= MIN_WEIGHT:
			return false
	return true


func _unique_name_from_used(source: String, used_names: Dictionary) -> String:
	var base: String = source.strip_edges().replace(":", "_").replace("/", "_")
	if base.is_empty():
		base = "Bone"
	var candidate: String = base
	var suffix: int = 2
	while used_names.has(candidate):
		candidate = "%s %d" % [base, suffix]
		suffix += 1
	return candidate


func _is_descendant_of(candidate_index: int, ancestor_index: int) -> bool:
	if candidate_index < 0 or candidate_index >= bones.size():
		return false
	var parent_index: int = bones[candidate_index].parent_index
	var guard: int = 0
	while parent_index >= 0 and parent_index < bones.size() and guard <= bones.size():
		if parent_index == ancestor_index:
			return true
		parent_index = bones[parent_index].parent_index
		guard += 1
	return false


func _reorder_bones_parent_first() -> Dictionary:
	var old_count: int = bones.size()
	var children: Array[PackedInt32Array] = []
	children.resize(old_count)
	for index: int in old_count:
		children[index] = PackedInt32Array()
	for child_index: int in old_count:
		var parent_index: int = bones[child_index].parent_index
		if parent_index < 0 or parent_index >= old_count or parent_index == child_index:
			bones[child_index].parent_index = -1
		else:
			children[parent_index].append(child_index)

	var order: PackedInt32Array = PackedInt32Array()
	var visited: Dictionary = {}
	for root_index: int in old_count:
		if bones[root_index].parent_index < 0:
			_append_bone_subtree_order(root_index, children, visited, order)
	for leftover_index: int in old_count:
		if not visited.has(leftover_index):
			bones[leftover_index].parent_index = -1
			_append_bone_subtree_order(leftover_index, children, visited, order)

	var old_to_new: Dictionary = {}
	for new_index: int in order.size():
		old_to_new[order[new_index]] = new_index
	var reordered: Array[GMSBoneData] = []
	reordered.resize(old_count)
	for new_index: int in order.size():
		var old_index: int = order[new_index]
		var bone: GMSBoneData = bones[old_index]
		var old_parent: int = bone.parent_index
		bone.parent_index = int(old_to_new.get(old_parent, -1))
		reordered[new_index] = bone
	bones = reordered
	_remap_weight_bone_indices(old_to_new)
	_remap_pose_arrays(old_to_new, old_count)
	return old_to_new


func _append_bone_subtree_order(
	bone_index: int,
	children: Array[PackedInt32Array],
	visited: Dictionary,
	order: PackedInt32Array
) -> void:
	if visited.has(bone_index):
		return
	visited[bone_index] = true
	order.append(bone_index)
	for child_index: int in children[bone_index]:
		_append_bone_subtree_order(child_index, children, visited, order)


func _remap_weight_bone_indices(old_to_new: Dictionary) -> void:
	_weight_validation_dirty = true
	for influence_index: int in vertex_bones.size():
		var old_bone_index: int = vertex_bones[influence_index]
		if old_to_new.has(old_bone_index):
			vertex_bones[influence_index] = int(old_to_new[old_bone_index])
		else:
			vertex_bones[influence_index] = 0
			vertex_weights[influence_index] = 0.0


func _remap_pose_arrays(old_to_new: Dictionary, old_count: int) -> void:
	var old_positions: Array[Vector3] = pose_positions.duplicate()
	var old_rotations: Array[Quaternion] = pose_rotations.duplicate()
	var old_scales: Array[Vector3] = pose_scales.duplicate()
	pose_positions.resize(bones.size())
	pose_rotations.resize(bones.size())
	pose_scales.resize(bones.size())
	for new_index: int in bones.size():
		pose_positions[new_index] = Vector3.ZERO
		pose_rotations[new_index] = Quaternion.IDENTITY
		pose_scales[new_index] = Vector3.ONE
	for old_index: int in old_count:
		if not old_to_new.has(old_index):
			continue
		var new_index: int = int(old_to_new[old_index])
		if old_index < old_positions.size():
			pose_positions[new_index] = old_positions[old_index]
		if old_index < old_rotations.size():
			pose_rotations[new_index] = old_rotations[old_index]
		if old_index < old_scales.size():
			pose_scales[new_index] = old_scales[old_index]


func _point_segment_distance(point: Vector3, a: Vector3, b: Vector3) -> float:
	var segment: Vector3 = b - a
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0000001:
		return point.distance_to(a)
	var parameter: float = clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(a + segment * parameter)


func _unique_bone_name(source: String, ignored_index: int = -1) -> String:
	var base: String = source.strip_edges().replace(":", "_").replace("/", "_")
	if base.is_empty():
		base = "Bone"
	var candidate: String = base
	var suffix: int = 2
	while _bone_name_exists(candidate, ignored_index):
		candidate = "%s %d" % [base, suffix]
		suffix += 1
	return candidate


func _bone_name_exists(name_to_find: String, ignored_index: int) -> bool:
	for bone_index: int in bones.size():
		if bone_index != ignored_index and bones[bone_index].display_name == name_to_find:
			return true
	return false


func _has_explicit_side_name(source: String) -> bool:
	return (
		source.ends_with(".L")
		or source.ends_with(".R")
		or source.ends_with("_L")
		or source.ends_with("_R")
		or source.begins_with("Left ")
		or source.begins_with("Right ")
	)


func _mirrored_name(source: String) -> String:
	if source.ends_with(".L"):
		return source.trim_suffix(".L") + ".R"
	if source.ends_with(".R"):
		return source.trim_suffix(".R") + ".L"
	if source.ends_with("_L"):
		return source.trim_suffix("_L") + "_R"
	if source.ends_with("_R"):
		return source.trim_suffix("_R") + "_L"
	if source.begins_with("Left "):
		return "Right " + source.trim_prefix("Left ")
	if source.begins_with("Right "):
		return "Left " + source.trim_prefix("Right ")
	return source + ".R"


func _quantize_point(point: Vector3, cell_size: float) -> Vector3i:
	return Vector3i(
		roundi(point.x / cell_size),
		roundi(point.y / cell_size),
		roundi(point.z / cell_size)
	)


func _find_spatial_vertex(
	mesh: GMSMeshData,
	spatial: Dictionary,
	point: Vector3,
	cell_size: float
) -> int:
	var center: Vector3i = _quantize_point(point, cell_size)
	var best_index: int = -1
	var best_distance: float = cell_size * 2.5
	for x_offset: int in range(-1, 2):
		for y_offset: int in range(-1, 2):
			for z_offset: int in range(-1, 2):
				var key: Vector3i = center + Vector3i(x_offset, y_offset, z_offset)
				var candidates: PackedInt32Array = spatial.get(key, PackedInt32Array())
				for candidate: int in candidates:
					var distance: float = mesh.vertices[candidate].distance_to(point)
					if distance < best_distance:
						best_distance = distance
						best_index = candidate
	return best_index
