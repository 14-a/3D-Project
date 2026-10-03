@tool
class_name GMSPoseData
extends Resource

@export var pose_id: String = ""
@export var display_name: String = "Pose"
@export var bone_ids: PackedStringArray = PackedStringArray()
@export var bone_names: PackedStringArray = PackedStringArray()
@export var positions: Array[Vector3] = []
@export var rotations: Array[Quaternion] = []
@export var scales: Array[Vector3] = []


func ensure_defaults() -> void:
	if pose_id.is_empty():
		pose_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	display_name = display_name.strip_edges()
	if display_name.is_empty():
		display_name = "Pose"
	var count: int = mini(
		mini(bone_ids.size(), bone_names.size()),
		mini(positions.size(), mini(rotations.size(), scales.size()))
	)
	bone_ids.resize(count)
	bone_names.resize(count)
	positions.resize(count)
	rotations.resize(count)
	scales.resize(count)
	for index: int in count:
		rotations[index] = rotations[index].normalized()
		if scales[index].is_zero_approx():
			scales[index] = Vector3.ONE


func duplicate_pose() -> GMSPoseData:
	var copy: GMSPoseData = GMSPoseData.new()
	copy.pose_id = pose_id
	copy.display_name = display_name
	copy.bone_ids = bone_ids.duplicate()
	copy.bone_names = bone_names.duplicate()
	copy.positions = positions.duplicate()
	copy.rotations = rotations.duplicate()
	copy.scales = scales.duplicate()
	copy.ensure_defaults()
	return copy


func capture(rig: GMSRigData) -> void:
	bone_ids.clear()
	bone_names.clear()
	positions.clear()
	rotations.clear()
	scales.clear()
	if rig == null:
		return
	rig.ensure_defaults()
	for bone_index: int in rig.bones.size():
		var bone: GMSBoneData = rig.bones[bone_index]
		bone_ids.append(bone.bone_id)
		bone_names.append(bone.display_name)
		positions.append(rig.pose_positions[bone_index])
		rotations.append(rig.pose_rotations[bone_index])
		scales.append(rig.pose_scales[bone_index])


func get_offset_for_bone(rig: GMSRigData, bone_index: int) -> Transform3D:
	if rig == null or bone_index < 0 or bone_index >= rig.bones.size():
		return Transform3D.IDENTITY
	var bone: GMSBoneData = rig.bones[bone_index]
	for index: int in bone_ids.size():
		if bone_ids[index] == bone.bone_id or (bone_ids[index].is_empty() and bone_names[index] == bone.display_name):
			return Transform3D(Basis(rotations[index]).scaled(scales[index]), positions[index])
	return Transform3D.IDENTITY
