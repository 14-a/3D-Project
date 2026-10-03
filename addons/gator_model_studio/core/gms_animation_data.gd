@tool
class_name GMSAnimationData
extends Resource

@export var format_version: int = 1
@export var clips: Array[GMSAnimationClip] = []
@export var poses: Array[GMSPoseData] = []


func ensure_defaults(rig: GMSRigData = null) -> void:
	var clean_clips: Array[GMSAnimationClip] = []
	var used_clip_ids: Dictionary = {}
	var used_clip_names: Dictionary = {}
	for clip: GMSAnimationClip in clips:
		if clip == null:
			continue
		clip.ensure_defaults(rig)
		while used_clip_ids.has(clip.clip_id):
			clip.clip_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
		clip.display_name = _unique_name(clip.display_name, used_clip_names)
		used_clip_ids[clip.clip_id] = true
		used_clip_names[clip.display_name] = true
		clean_clips.append(clip)
	clips = clean_clips

	var clean_poses: Array[GMSPoseData] = []
	var used_pose_ids: Dictionary = {}
	var used_pose_names: Dictionary = {}
	for pose: GMSPoseData in poses:
		if pose == null:
			continue
		pose.ensure_defaults()
		while used_pose_ids.has(pose.pose_id):
			pose.pose_id = "%d_%d" % [Time.get_ticks_usec(), randi()]
		pose.display_name = _unique_name(pose.display_name, used_pose_names)
		used_pose_ids[pose.pose_id] = true
		used_pose_names[pose.display_name] = true
		clean_poses.append(pose)
	poses = clean_poses


func duplicate_data() -> GMSAnimationData:
	var copy: GMSAnimationData = GMSAnimationData.new()
	copy.format_version = format_version
	for clip: GMSAnimationClip in clips:
		if clip != null:
			copy.clips.append(clip.duplicate_clip())
	for pose: GMSPoseData in poses:
		if pose != null:
			copy.poses.append(pose.duplicate_pose())
	copy.ensure_defaults()
	return copy


func create_clip(name_hint: String = "Animation") -> GMSAnimationClip:
	var used: Dictionary = {}
	for existing: GMSAnimationClip in clips:
		if existing != null:
			used[existing.display_name] = true
	var clip: GMSAnimationClip = GMSAnimationClip.new()
	clip.display_name = _unique_name(name_hint, used)
	clip.ensure_defaults()
	clips.append(clip)
	emit_changed()
	return clip


func find_clip(clip_id: String) -> GMSAnimationClip:
	for clip: GMSAnimationClip in clips:
		if clip != null and clip.clip_id == clip_id:
			return clip
	return null


func remove_clip(clip_id: String) -> bool:
	var clip: GMSAnimationClip = find_clip(clip_id)
	if clip == null:
		return false
	clips.erase(clip)
	emit_changed()
	return true


func create_pose(name_hint: String, rig: GMSRigData) -> GMSPoseData:
	var used: Dictionary = {}
	for existing: GMSPoseData in poses:
		if existing != null:
			used[existing.display_name] = true
	var pose: GMSPoseData = GMSPoseData.new()
	pose.display_name = _unique_name(name_hint, used)
	pose.capture(rig)
	pose.ensure_defaults()
	poses.append(pose)
	emit_changed()
	return pose


func find_pose(pose_id: String) -> GMSPoseData:
	for pose: GMSPoseData in poses:
		if pose != null and pose.pose_id == pose_id:
			return pose
	return null


func remove_pose(pose_id: String) -> bool:
	var pose: GMSPoseData = find_pose(pose_id)
	if pose == null:
		return false
	poses.erase(pose)
	emit_changed()
	return true


static func _unique_name(base_name: String, used: Dictionary) -> String:
	var base: String = base_name.strip_edges()
	if base.is_empty():
		base = "Item"
	if not used.has(base):
		return base
	var suffix: int = 2
	while used.has("%s %d" % [base, suffix]):
		suffix += 1
	return "%s %d" % [base, suffix]
