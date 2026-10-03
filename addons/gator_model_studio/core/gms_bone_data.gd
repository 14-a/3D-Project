@tool
class_name GMSBoneData
extends Resource

@export var bone_id: String = ""
@export var display_name: String = "Bone"
@export var parent_index: int = -1
@export var head: Vector3 = Vector3.ZERO
@export var tail: Vector3 = Vector3.UP
@export var roll: float = 0.0
@export var locked: bool = false


func ensure_defaults(index: int = 0) -> void:
	if bone_id.is_empty():
		bone_id = "%d_%d" % [Time.get_ticks_usec(), index]
	display_name = display_name.strip_edges().replace(":", "_").replace("/", "_")
	if display_name.is_empty():
		display_name = "Bone %d" % (index + 1)
	if head.is_equal_approx(tail):
		tail = head + Vector3.UP
	if parent_index >= index:
		parent_index = -1


func duplicate_bone() -> GMSBoneData:
	var copy: GMSBoneData = GMSBoneData.new()
	copy.bone_id = bone_id
	copy.display_name = display_name
	copy.parent_index = parent_index
	copy.head = head
	copy.tail = tail
	copy.roll = roll
	copy.locked = locked
	return copy


func get_length() -> float:
	return maxf(head.distance_to(tail), 0.0001)


func get_direction() -> Vector3:
	var direction: Vector3 = tail - head
	return Vector3.UP if direction.is_zero_approx() else direction.normalized()


func get_base_basis() -> Basis:
	var y_axis: Vector3 = get_direction()
	var helper: Vector3 = Vector3.UP
	if absf(y_axis.dot(helper)) > 0.98:
		helper = Vector3.RIGHT
	var x_axis: Vector3 = y_axis.cross(helper).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func get_global_rest() -> Transform3D:
	var y_axis: Vector3 = get_direction()
	var basis: Basis = get_base_basis()
	if not is_zero_approx(roll):
		basis = Basis(y_axis, roll) * basis
	return Transform3D(basis.orthonormalized(), head)
