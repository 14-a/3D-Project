@tool
class_name GMSIKChainData
extends Resource

@export var chain_id: String = ""
@export var display_name: String = "IK Chain"
@export var root_bone_id: String = ""
@export var root_bone_name: String = ""
@export var tip_bone_id: String = ""
@export var tip_bone_name: String = ""
@export var target_position: Vector3 = Vector3.ZERO
@export var pole_position: Vector3 = Vector3.FORWARD
@export_range(1, 64, 1) var iterations: int = 16
@export_range(0.000001, 1.0, 0.000001) var tolerance: float = 0.0005
@export_range(0.0, 1.0, 0.01) var pole_influence: float = 1.0
@export var enabled: bool = true


func ensure_defaults(rig: GMSRigData = null) -> void:
	if chain_id.is_empty():
		chain_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	display_name = display_name.strip_edges()
	if display_name.is_empty():
		display_name = "IK Chain"
	iterations = clampi(iterations, 1, 64)
	tolerance = clampf(tolerance, 0.000001, 1.0)
	pole_influence = clampf(pole_influence, 0.0, 1.0)
	root_bone_id = root_bone_id.strip_edges()
	root_bone_name = root_bone_name.strip_edges()
	tip_bone_id = tip_bone_id.strip_edges()
	tip_bone_name = tip_bone_name.strip_edges()
	if rig == null:
		return
	var root_index: int = rig.resolve_bone(root_bone_id, root_bone_name)
	var tip_index: int = rig.resolve_bone(tip_bone_id, tip_bone_name)
	if root_index >= 0:
		root_bone_id = rig.bones[root_index].bone_id
		root_bone_name = rig.bones[root_index].display_name
	if tip_index >= 0:
		tip_bone_id = rig.bones[tip_index].bone_id
		tip_bone_name = rig.bones[tip_index].display_name


func duplicate_chain() -> GMSIKChainData:
	var copy: GMSIKChainData = GMSIKChainData.new()
	copy.chain_id = chain_id
	copy.display_name = display_name
	copy.root_bone_id = root_bone_id
	copy.root_bone_name = root_bone_name
	copy.tip_bone_id = tip_bone_id
	copy.tip_bone_name = tip_bone_name
	copy.target_position = target_position
	copy.pole_position = pole_position
	copy.iterations = iterations
	copy.tolerance = tolerance
	copy.pole_influence = pole_influence
	copy.enabled = enabled
	copy.ensure_defaults()
	return copy


func resolve_root(rig: GMSRigData) -> int:
	return rig.resolve_bone(root_bone_id, root_bone_name) if rig != null else -1


func resolve_tip(rig: GMSRigData) -> int:
	return rig.resolve_bone(tip_bone_id, tip_bone_name) if rig != null else -1


func get_chain_indices(rig: GMSRigData) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if rig == null:
		return result
	var root_index: int = resolve_root(rig)
	var tip_index: int = resolve_tip(rig)
	if root_index < 0 or tip_index < 0:
		return result
	var reverse_chain: PackedInt32Array = PackedInt32Array()
	var cursor: int = tip_index
	while cursor >= 0 and cursor < rig.bones.size():
		reverse_chain.append(cursor)
		if cursor == root_index:
			break
		cursor = rig.bones[cursor].parent_index
	if reverse_chain.is_empty() or reverse_chain[reverse_chain.size() - 1] != root_index:
		return result
	for reverse_index: int in range(reverse_chain.size() - 1, -1, -1):
		result.append(reverse_chain[reverse_index])
	return result
