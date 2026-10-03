@tool
class_name GMSAnimationKey
extends Resource

enum Interpolation {
	CONSTANT,
	LINEAR,
	SMOOTH,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	CUSTOM,
}

@export var frame: int = 0
@export var position: Vector3 = Vector3.ZERO
@export var rotation: Quaternion = Quaternion.IDENTITY
@export var scale: Vector3 = Vector3.ONE
@export_enum("Constant", "Linear", "Smooth", "Ease In", "Ease Out", "Ease In/Out", "Custom Curve") var interpolation: int = Interpolation.SMOOTH
@export var position_control_1: Vector2 = Vector2(0.33, 0.0)
@export var position_control_2: Vector2 = Vector2(0.67, 1.0)
@export var rotation_control_1: Vector2 = Vector2(0.33, 0.0)
@export var rotation_control_2: Vector2 = Vector2(0.67, 1.0)
@export var scale_control_1: Vector2 = Vector2(0.33, 0.0)
@export var scale_control_2: Vector2 = Vector2(0.67, 1.0)


func duplicate_key() -> GMSAnimationKey:
	var copy: GMSAnimationKey = GMSAnimationKey.new()
	copy.frame = frame
	copy.position = position
	copy.rotation = rotation
	copy.scale = scale
	copy.interpolation = interpolation
	copy.position_control_1 = position_control_1
	copy.position_control_2 = position_control_2
	copy.rotation_control_1 = rotation_control_1
	copy.rotation_control_2 = rotation_control_2
	copy.scale_control_1 = scale_control_1
	copy.scale_control_2 = scale_control_2
	return copy


func get_offset_transform() -> Transform3D:
	return Transform3D(Basis(rotation.normalized()).scaled(scale), position)


func set_offset_transform(value: Transform3D) -> void:
	position = value.origin
	var clean_basis: Basis = value.basis
	scale = clean_basis.get_scale()
	if absf(scale.x) <= 0.000001:
		scale.x = 1.0
	if absf(scale.y) <= 0.000001:
		scale.y = 1.0
	if absf(scale.z) <= 0.000001:
		scale.z = 1.0
	clean_basis = clean_basis.scaled(Vector3(
		1.0 / scale.x,
		1.0 / scale.y,
		1.0 / scale.z
	)).orthonormalized()
	rotation = clean_basis.get_rotation_quaternion().normalized()


func get_curve_controls(channel: int) -> Array[Vector2]:
	match channel:
		0:
			return [position_control_1, position_control_2]
		1:
			return [rotation_control_1, rotation_control_2]
		2:
			return [scale_control_1, scale_control_2]
		_:
			return [position_control_1, position_control_2]


func set_curve_controls(channel: int, control_1: Vector2, control_2: Vector2) -> void:
	var first: Vector2 = _sanitize_curve_control(control_1)
	var second: Vector2 = _sanitize_curve_control(control_2)
	first.x = clampf(first.x, 0.0, 0.999)
	second.x = clampf(second.x, 0.001, 1.0)
	if first.x >= second.x:
		var midpoint: float = clampf((first.x + second.x) * 0.5, 0.001, 0.999)
		first.x = midpoint - 0.0005
		second.x = midpoint + 0.0005
	match channel:
		0:
			position_control_1 = first
			position_control_2 = second
		1:
			rotation_control_1 = first
			rotation_control_2 = second
		2:
			scale_control_1 = first
			scale_control_2 = second
	interpolation = Interpolation.CUSTOM


func apply_interpolation_preset(value: int) -> void:
	interpolation = clampi(value, Interpolation.CONSTANT, Interpolation.CUSTOM)
	if interpolation == Interpolation.CUSTOM:
		return
	var controls: Array[Vector2] = preset_curve_controls(interpolation)
	position_control_1 = controls[0]
	position_control_2 = controls[1]
	rotation_control_1 = controls[0]
	rotation_control_2 = controls[1]
	scale_control_1 = controls[0]
	scale_control_2 = controls[1]


static func preset_curve_controls(value: int) -> Array[Vector2]:
	match value:
		Interpolation.LINEAR:
			return [Vector2(0.333333, 0.333333), Vector2(0.666667, 0.666667)]
		Interpolation.SMOOTH:
			return [Vector2(0.333333, 0.0), Vector2(0.666667, 1.0)]
		Interpolation.EASE_IN:
			return [Vector2(0.42, 0.0), Vector2(1.0, 1.0)]
		Interpolation.EASE_OUT:
			return [Vector2(0.0, 0.0), Vector2(0.58, 1.0)]
		Interpolation.EASE_IN_OUT:
			return [Vector2(0.42, 0.0), Vector2(0.58, 1.0)]
		_:
			return [Vector2(0.0, 0.0), Vector2(1.0, 1.0)]


static func _sanitize_curve_control(value: Vector2) -> Vector2:
	return Vector2(clampf(value.x, 0.0, 1.0), clampf(value.y, -0.5, 1.5))
