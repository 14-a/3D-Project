@tool
class_name GMSAnimationClip
extends Resource

@export var clip_id: String = ""
@export var display_name: String = "Animation"
@export_range(1.0, 240.0, 1.0) var fps: float = 24.0
@export_range(1, 100000, 1) var frame_count: int = 24
@export var loop: bool = true
@export var tracks: Array[GMSBoneAnimationTrack] = []
@export var root_motion_bone_id: String = ""
@export var root_motion_bone_name: String = ""
@export var root_motion_axes: Vector3 = Vector3(1.0, 0.0, 1.0)


func ensure_defaults(rig: GMSRigData = null) -> void:
	if clip_id.is_empty():
		clip_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
	display_name = display_name.strip_edges().replace("/", "_").replace(":", "_")
	if display_name.is_empty():
		display_name = "Animation"
	fps = clampf(fps, 1.0, 240.0)
	frame_count = clampi(frame_count, 1, 100000)
	var sanitized: Array[GMSBoneAnimationTrack] = []
	var used_bones: Dictionary = {}
	for track: GMSBoneAnimationTrack in tracks:
		if track == null:
			continue
		track.ensure_defaults(frame_count)
		if rig != null:
			var bone_index: int = rig.resolve_bone(track.bone_id, track.bone_name)
			if bone_index < 0:
				continue
			var bone: GMSBoneData = rig.bones[bone_index]
			track.bone_id = bone.bone_id
			track.bone_name = bone.display_name
		if track.bone_id.is_empty() and track.bone_name.is_empty():
			continue
		var identity: String = track.bone_id if not track.bone_id.is_empty() else track.bone_name
		if used_bones.has(identity):
			continue
		used_bones[identity] = true
		sanitized.append(track)
	tracks = sanitized
	root_motion_bone_id = root_motion_bone_id.strip_edges()
	root_motion_bone_name = root_motion_bone_name.strip_edges()
	root_motion_axes = Vector3(1.0 if absf(root_motion_axes.x) >= 0.5 else 0.0, 1.0 if absf(root_motion_axes.y) >= 0.5 else 0.0, 1.0 if absf(root_motion_axes.z) >= 0.5 else 0.0)
	if rig != null and (not root_motion_bone_id.is_empty() or not root_motion_bone_name.is_empty()):
		var root_index: int = rig.resolve_bone(root_motion_bone_id, root_motion_bone_name)
		if root_index >= 0:
			root_motion_bone_id = rig.bones[root_index].bone_id
			root_motion_bone_name = rig.bones[root_index].display_name
		else:
			root_motion_bone_id = ""
			root_motion_bone_name = ""


func duplicate_clip() -> GMSAnimationClip:
	var copy: GMSAnimationClip = GMSAnimationClip.new()
	copy.clip_id = clip_id
	copy.display_name = display_name
	copy.fps = fps
	copy.frame_count = frame_count
	copy.loop = loop
	copy.root_motion_bone_id = root_motion_bone_id
	copy.root_motion_bone_name = root_motion_bone_name
	copy.root_motion_axes = root_motion_axes
	for track: GMSBoneAnimationTrack in tracks:
		if track != null:
			copy.tracks.append(track.duplicate_track())
	copy.ensure_defaults()
	return copy


func find_track(bone_id: String, bone_name: String = "") -> GMSBoneAnimationTrack:
	for track: GMSBoneAnimationTrack in tracks:
		if track == null:
			continue
		if not bone_id.is_empty() and track.bone_id == bone_id:
			return track
		if bone_id.is_empty() and not bone_name.is_empty() and track.bone_name == bone_name:
			return track
	return null


func ensure_track(bone: GMSBoneData) -> GMSBoneAnimationTrack:
	if bone == null:
		return null
	var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
	if track == null:
		track = GMSBoneAnimationTrack.new()
		track.bone_id = bone.bone_id
		track.bone_name = bone.display_name
		tracks.append(track)
	else:
		track.bone_id = bone.bone_id
		track.bone_name = bone.display_name
	return track


func set_bone_key(
	bone: GMSBoneData,
	frame: int,
	transform_offset: Transform3D,
	interpolation: int
) -> bool:
	var track: GMSBoneAnimationTrack = ensure_track(bone)
	if track == null:
		return false
	track.set_key(clampi(frame, 0, frame_count), transform_offset, interpolation)
	emit_changed()
	return true


func remove_bone_key(bone_id: String, bone_name: String, frame: int) -> bool:
	var track: GMSBoneAnimationTrack = find_track(bone_id, bone_name)
	if track == null or not track.remove_key(frame):
		return false
	if track.keys.is_empty():
		tracks.erase(track)
	emit_changed()
	return true


func move_bone_key(
	bone_id: String,
	bone_name: String,
	old_frame: int,
	new_frame: int
) -> bool:
	var track: GMSBoneAnimationTrack = find_track(bone_id, bone_name)
	if track == null:
		return false
	var result: bool = track.move_key(old_frame, new_frame, frame_count)
	if result:
		emit_changed()
	return result


func set_key_interpolation(
	bone_id: String,
	bone_name: String,
	frame: int,
	interpolation: int
) -> bool:
	var track: GMSBoneAnimationTrack = find_track(bone_id, bone_name)
	var key: GMSAnimationKey = track.get_key(frame) if track != null else null
	if key == null:
		return false
	key.apply_interpolation_preset(interpolation)
	emit_changed()
	return true


func sample_pose(rig: GMSRigData, frame_value: float, preview_in_place: bool = false) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if rig == null:
		return result
	result.resize(rig.bones.size())
	for bone_index: int in rig.bones.size():
		var bone: GMSBoneData = rig.bones[bone_index]
		var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
		result[bone_index] = track.sample(frame_value) if track != null else Transform3D.IDENTITY
	if preview_in_place:
		_apply_in_place_preview(rig, result)
	return result


func get_key_frames_for_bone(bone: GMSBoneData) -> PackedInt32Array:
	if bone == null:
		return PackedInt32Array()
	var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
	return track.get_frames() if track != null else PackedInt32Array()


func get_all_key_frames() -> PackedInt32Array:
	var seen: Dictionary = {}
	for track: GMSBoneAnimationTrack in tracks:
		if track == null:
			continue
		for frame: int in track.get_frames():
			seen[frame] = true
	var result: PackedInt32Array = PackedInt32Array()
	var frames: Array = seen.keys()
	frames.sort()
	for frame_value: Variant in frames:
		result.append(int(frame_value))
	return result


func resolve_root_motion_bone(rig: GMSRigData) -> int:
	if rig == null:
		return -1
	return rig.resolve_bone(root_motion_bone_id, root_motion_bone_name)


func set_root_motion_bone(bone: GMSBoneData) -> void:
	if bone == null:
		root_motion_bone_id = ""
		root_motion_bone_name = ""
	else:
		root_motion_bone_id = bone.bone_id
		root_motion_bone_name = bone.display_name
	emit_changed()


func clear_root_motion_bone() -> void:
	set_root_motion_bone(null)


func set_custom_curve(
	bone_id: String,
	bone_name: String,
	frame: int,
	channel: int,
	control_1: Vector2,
	control_2: Vector2
) -> bool:
	var track: GMSBoneAnimationTrack = find_track(bone_id, bone_name)
	var key: GMSAnimationKey = track.get_key(frame) if track != null else null
	if key == null:
		return false
	key.set_curve_controls(channel, control_1, control_2)
	emit_changed()
	return true


func get_root_motion_path(rig: GMSRigData, samples: int = -1) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var root_index: int = resolve_root_motion_bone(rig)
	if root_index < 0:
		return result
	var sample_count: int = frame_count + 1 if samples < 0 else maxi(samples, 2)
	for sample_index: int in sample_count:
		var frame_value: float = (
			float(sample_index)
			if samples < 0
			else float(sample_index) / float(sample_count - 1) * float(frame_count)
		)
		var offsets: Array[Transform3D] = sample_pose(rig, frame_value, false)
		var globals: Array[Transform3D] = rig.get_pose_global_transforms(offsets)
		result.append(globals[root_index].origin)
	return result


func convert_root_motion_to_in_place(rig: GMSRigData) -> bool:
	var root_index: int = resolve_root_motion_bone(rig)
	if root_index < 0:
		return false
	var bone: GMSBoneData = rig.bones[root_index]
	var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
	if track == null or track.keys.is_empty():
		return false
	var reference: Vector3 = track.sample(0.0).origin
	for key: GMSAnimationKey in track.keys:
		if key == null:
			continue
		if root_motion_axes.x > 0.5:
			key.position.x = reference.x
		if root_motion_axes.y > 0.5:
			key.position.y = reference.y
		if root_motion_axes.z > 0.5:
			key.position.z = reference.z
	emit_changed()
	return true


func remove_root_motion_loop_drift(rig: GMSRigData) -> bool:
	var root_index: int = resolve_root_motion_bone(rig)
	if root_index < 0:
		return false
	var bone: GMSBoneData = rig.bones[root_index]
	var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
	if track == null or track.keys.size() < 2:
		return false
	var start_position: Vector3 = track.sample(0.0).origin
	var end_position: Vector3 = track.sample(float(frame_count)).origin
	var drift: Vector3 = end_position - start_position
	drift = Vector3(
		drift.x * root_motion_axes.x,
		drift.y * root_motion_axes.y,
		drift.z * root_motion_axes.z
	)
	if drift.is_zero_approx():
		return false
	for key: GMSAnimationKey in track.keys:
		if key == null:
			continue
		var amount: float = float(key.frame) / float(maxi(frame_count, 1))
		key.position -= drift * amount
	emit_changed()
	return true


func _apply_in_place_preview(rig: GMSRigData, offsets: Array[Transform3D]) -> void:
	var root_index: int = resolve_root_motion_bone(rig)
	if root_index < 0 or root_index >= offsets.size():
		return
	var bone: GMSBoneData = rig.bones[root_index]
	var track: GMSBoneAnimationTrack = find_track(bone.bone_id, bone.display_name)
	if track == null:
		return
	var reference: Vector3 = track.sample(0.0).origin
	var root_offset: Transform3D = offsets[root_index]
	if root_motion_axes.x > 0.5:
		root_offset.origin.x = reference.x
	if root_motion_axes.y > 0.5:
		root_offset.origin.y = reference.y
	if root_motion_axes.z > 0.5:
		root_offset.origin.z = reference.z
	offsets[root_index] = root_offset
