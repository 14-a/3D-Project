@tool
class_name GMSBoneConstraintData
extends Resource

enum Type {
	LIMIT_ROTATION,
	COPY_ROTATION,
	COPY_TRANSFORM,
	LOOK_AT,
}

@export var constraint_id: String = ""
@export var display_name: String = "Constraint"
@export_enum("Limit Rotation", "Copy Rotation", "Copy Transform", "Look At") var type: int = Type.LIMIT_ROTATION
@export var bone_id: String = ""
@export var bone_name: String = ""
@export var target_bone_id: String = ""
@export var target_bone_name: String = ""
@export var minimum_rotation_degrees: Vector3 = Vector3(-180.0, -180.0, -180.0)
@export var maximum_rotation_degrees: Vector3 = Vector3(180.0, 180.0, 180.0)
@export var aim_axis: Vector3 = Vector3.UP
@export_range(0.0, 1.0, 0.01) var influence: float = 1.0
@export var enabled: bool = true


func ensure_defaults(rig: GMSRigData = null) -> void:
	if constraint_id.is_empty():
		constraint_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	display_name = display_name.strip_edges()
	if display_name.is_empty():
		display_name = "Constraint"
	type = clampi(type, Type.LIMIT_ROTATION, Type.LOOK_AT)
	influence = clampf(influence, 0.0, 1.0)
	bone_id = bone_id.strip_edges()
	bone_name = bone_name.strip_edges()
	target_bone_id = target_bone_id.strip_edges()
	target_bone_name = target_bone_name.strip_edges()
	var minimum: Vector3 = Vector3(
		minf(minimum_rotation_degrees.x, maximum_rotation_degrees.x),
		minf(minimum_rotation_degrees.y, maximum_rotation_degrees.y),
		minf(minimum_rotation_degrees.z, maximum_rotation_degrees.z)
	)
	var maximum: Vector3 = Vector3(
		maxf(minimum_rotation_degrees.x, maximum_rotation_degrees.x),
		maxf(minimum_rotation_degrees.y, maximum_rotation_degrees.y),
		maxf(minimum_rotation_degrees.z, maximum_rotation_degrees.z)
	)
	minimum_rotation_degrees = minimum
	maximum_rotation_degrees = maximum
	if aim_axis.is_zero_approx():
		aim_axis = Vector3.UP
	else:
		aim_axis = aim_axis.normalized()
	if rig == null:
		return
	var bone_index: int = rig.resolve_bone(bone_id, bone_name)
	if bone_index >= 0:
		bone_id = rig.bones[bone_index].bone_id
		bone_name = rig.bones[bone_index].display_name
	var target_index: int = rig.resolve_bone(target_bone_id, target_bone_name)
	if target_index >= 0:
		target_bone_id = rig.bones[target_index].bone_id
		target_bone_name = rig.bones[target_index].display_name


func duplicate_constraint() -> GMSBoneConstraintData:
	var copy: GMSBoneConstraintData = GMSBoneConstraintData.new()
	copy.constraint_id = constraint_id
	copy.display_name = display_name
	copy.type = type
	copy.bone_id = bone_id
	copy.bone_name = bone_name
	copy.target_bone_id = target_bone_id
	copy.target_bone_name = target_bone_name
	copy.minimum_rotation_degrees = minimum_rotation_degrees
	copy.maximum_rotation_degrees = maximum_rotation_degrees
	copy.aim_axis = aim_axis
	copy.influence = influence
	copy.enabled = enabled
	copy.ensure_defaults()
	return copy


func resolve_bone(rig: GMSRigData) -> int:
	return rig.resolve_bone(bone_id, bone_name) if rig != null else -1


func resolve_target(rig: GMSRigData) -> int:
	return rig.resolve_bone(target_bone_id, target_bone_name) if rig != null else -1


func requires_target() -> bool:
	return type != Type.LIMIT_ROTATION
