@tool
class_name GMSSnapMath
extends RefCounted

enum BaseMode {
	CLOSEST,
	CENTER,
	MEDIAN,
	ACTIVE,
}


static func snap_scalar(value: float, increment: float) -> float:
	if increment <= 0.0:
		return value
	return roundf(value / increment) * increment


static func snap_vector(value: Vector3, increment: float) -> Vector3:
	if increment <= 0.0:
		return value
	return Vector3(
		snap_scalar(value.x, increment),
		snap_scalar(value.y, increment),
		snap_scalar(value.z, increment)
	)


static func constrain_vector(value: Vector3, axis: Vector3) -> Vector3:
	if axis.is_zero_approx():
		return value
	var normalized_axis: Vector3 = axis.normalized()
	return normalized_axis * value.dot(normalized_axis)


static func get_base_point(
	points: PackedVector3Array,
	target: Vector3,
	mode: int,
	active_index: int = -1
) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO

	match mode:
		BaseMode.CENTER, BaseMode.MEDIAN:
			var median: Vector3 = Vector3.ZERO
			for point: Vector3 in points:
				median += point
			return median / float(points.size())
		BaseMode.ACTIVE:
			if active_index >= 0 and active_index < points.size():
				return points[active_index]
			return points[points.size() - 1]
		_:
			var closest: Vector3 = points[0]
			var closest_distance: float = closest.distance_squared_to(target)
			for point_index: int in range(1, points.size()):
				var point: Vector3 = points[point_index]
				var distance: float = point.distance_squared_to(target)
				if distance < closest_distance:
					closest = point
					closest_distance = distance
			return closest


static func uniform_scale_to_target(
	pivot: Vector3,
	source: Vector3,
	target: Vector3
) -> float:
	var source_offset: Vector3 = source - pivot
	var target_offset: Vector3 = target - pivot
	var source_length: float = source_offset.length()
	if source_length <= 0.000001:
		return 1.0
	var factor: float = target_offset.length() / source_length
	if source_offset.dot(target_offset) < 0.0:
		factor = -factor
	return factor


static func axis_scale_to_target(
	pivot: Vector3,
	source: Vector3,
	target: Vector3,
	axis: Vector3
) -> float:
	if axis.is_zero_approx():
		return uniform_scale_to_target(pivot, source, target)
	var normalized_axis: Vector3 = axis.normalized()
	var source_amount: float = (source - pivot).dot(normalized_axis)
	if absf(source_amount) <= 0.000001:
		return 1.0
	return (target - pivot).dot(normalized_axis) / source_amount
