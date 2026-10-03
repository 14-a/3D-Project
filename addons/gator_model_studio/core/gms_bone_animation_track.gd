@tool
class_name GMSBoneAnimationTrack
extends Resource

@export var bone_id: String = ""
@export var bone_name: String = ""
@export var keys: Array[GMSAnimationKey] = []


func duplicate_track() -> GMSBoneAnimationTrack:
	var copy: GMSBoneAnimationTrack = GMSBoneAnimationTrack.new()
	copy.bone_id = bone_id
	copy.bone_name = bone_name
	for key: GMSAnimationKey in keys:
		if key != null:
			copy.keys.append(key.duplicate_key())
	copy.ensure_defaults()
	return copy


func ensure_defaults(frame_count: int = -1) -> void:
	bone_id = bone_id.strip_edges()
	bone_name = bone_name.strip_edges()
	var by_frame: Dictionary = {}
	for key: GMSAnimationKey in keys:
		if key == null:
			continue
		key.frame = maxi(key.frame, 0)
		if frame_count >= 0:
			key.frame = mini(key.frame, frame_count)
		key.interpolation = clampi(
			key.interpolation,
			GMSAnimationKey.Interpolation.CONSTANT,
			GMSAnimationKey.Interpolation.CUSTOM
		)
		key.rotation = key.rotation.normalized()
		if key.scale.is_zero_approx():
			key.scale = Vector3.ONE
		by_frame[key.frame] = key
	keys.clear()
	var frames: Array = by_frame.keys()
	frames.sort()
	for frame_value: Variant in frames:
		keys.append(by_frame[frame_value] as GMSAnimationKey)


func has_key(frame: int) -> bool:
	return get_key_index(frame) >= 0


func get_key_index(frame: int) -> int:
	for key_index: int in keys.size():
		if keys[key_index] != null and keys[key_index].frame == frame:
			return key_index
	return -1


func get_key(frame: int) -> GMSAnimationKey:
	var key_index: int = get_key_index(frame)
	return keys[key_index] if key_index >= 0 else null


func set_key(frame: int, transform_offset: Transform3D, interpolation: int) -> GMSAnimationKey:
	var key: GMSAnimationKey = get_key(frame)
	if key == null:
		key = GMSAnimationKey.new()
		key.frame = maxi(frame, 0)
		keys.append(key)
	key.set_offset_transform(transform_offset)
	key.apply_interpolation_preset(interpolation)
	ensure_defaults()
	return key


func remove_key(frame: int) -> bool:
	var key_index: int = get_key_index(frame)
	if key_index < 0:
		return false
	keys.remove_at(key_index)
	return true


func move_key(old_frame: int, new_frame: int, frame_count: int) -> bool:
	var key: GMSAnimationKey = get_key(old_frame)
	if key == null:
		return false
	var target_frame: int = clampi(new_frame, 0, maxi(frame_count, 0))
	var existing_index: int = get_key_index(target_frame)
	if existing_index >= 0 and keys[existing_index] != key:
		keys.remove_at(existing_index)
	key.frame = target_frame
	ensure_defaults(frame_count)
	return true


func get_frames() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for key: GMSAnimationKey in keys:
		if key != null:
			result.append(key.frame)
	return result


func sample(frame_value: float) -> Transform3D:
	if keys.is_empty():
		return Transform3D.IDENTITY
	if keys.size() == 1 or frame_value <= float(keys[0].frame):
		return keys[0].get_offset_transform()
	var last_key: GMSAnimationKey = keys[keys.size() - 1]
	if frame_value >= float(last_key.frame):
		return last_key.get_offset_transform()
	for right_index: int in range(1, keys.size()):
		var right: GMSAnimationKey = keys[right_index]
		if frame_value > float(right.frame):
			continue
		var left: GMSAnimationKey = keys[right_index - 1]
		var frame_span: float = maxf(float(right.frame - left.frame), 1.0)
		var amount: float = clampf((frame_value - float(left.frame)) / frame_span, 0.0, 1.0)
		var position_amount: float = _apply_easing_channel(amount, left, 0)
		var rotation_amount: float = clampf(_apply_easing_channel(amount, left, 1), 0.0, 1.0)
		var scale_amount: float = _apply_easing_channel(amount, left, 2)
		return Transform3D(
			Basis(left.rotation.slerp(right.rotation, rotation_amount).normalized()).scaled(
				left.scale.lerp(right.scale, scale_amount)
			),
			left.position.lerp(right.position, position_amount)
		)
	return last_key.get_offset_transform()


static func _apply_easing_channel(amount: float, key: GMSAnimationKey, channel: int) -> float:
	if key != null and key.interpolation == GMSAnimationKey.Interpolation.CUSTOM:
		var controls: Array[Vector2] = key.get_curve_controls(channel)
		return _sample_cubic_bezier(amount, controls[0], controls[1])
	return _apply_easing(amount, key.interpolation if key != null else GMSAnimationKey.Interpolation.LINEAR)


static func _sample_cubic_bezier(amount: float, control_1: Vector2, control_2: Vector2) -> float:
	var target_x: float = clampf(amount, 0.0, 1.0)
	var low: float = 0.0
	var high: float = 1.0
	var t: float = target_x
	for _iteration: int in 14:
		t = (low + high) * 0.5
		var sampled_x: float = _cubic_component(t, 0.0, control_1.x, control_2.x, 1.0)
		if sampled_x < target_x:
			low = t
		else:
			high = t
	return _cubic_component(t, 0.0, control_1.y, control_2.y, 1.0)


static func _cubic_component(t: float, p0: float, p1: float, p2: float, p3: float) -> float:
	var one_minus: float = 1.0 - t
	return (
		p0 * one_minus * one_minus * one_minus
		+ 3.0 * p1 * one_minus * one_minus * t
		+ 3.0 * p2 * one_minus * t * t
		+ p3 * t * t * t
	)


static func _apply_easing(amount: float, interpolation: int) -> float:
	var t: float = clampf(amount, 0.0, 1.0)
	match interpolation:
		GMSAnimationKey.Interpolation.CONSTANT:
			return 0.0
		GMSAnimationKey.Interpolation.LINEAR:
			return t
		GMSAnimationKey.Interpolation.SMOOTH:
			return t * t * (3.0 - 2.0 * t)
		GMSAnimationKey.Interpolation.EASE_IN:
			return t * t
		GMSAnimationKey.Interpolation.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		GMSAnimationKey.Interpolation.EASE_IN_OUT:
			return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		_:
			return t
