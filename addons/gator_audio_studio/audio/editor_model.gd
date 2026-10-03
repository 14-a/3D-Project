@tool
class_name GASEditorModel
extends RefCounted

const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")
const EffectData := preload("res://addons/gator_audio_studio/audio/effect_data.gd")
const AutomationEngine := preload("res://addons/gator_audio_studio/audio/automation_engine.gd")

var sample_rate: int = 44100
var tracks: Array[GASEditorTrack] = []
var selected_track: int = -1
var selected_track_indices: PackedInt32Array = PackedInt32Array()
var selected_clip_ids: PackedInt32Array = PackedInt32Array()
var cursor_frame: int = 0
var selection_start: int = 0
var selection_end: int = 0
var clipboard: GASPCMData
var clip_clipboard: Array[Dictionary] = []
var markers: Array[Dictionary] = []
var master_gain_db: float = 0.0
var master_effect_stack: Array[GASEffectData] = []
var master_limiter_enabled: bool = true
var master_limiter_ceiling_db: float = -1.0
var change_revision: int = 0
var dirty: bool = false:
	set(value):
		if value:
			change_revision += 1
		dirty = value
var project_bpm: float = 120.0
var time_signature_numerator: int = 4
var time_signature_denominator: int = 4
var playback_speed: float = 1.0
var metadata: Dictionary = {}
var loop_start_frame: int = 0
var loop_end_frame: int = 0
var loop_mode: int = AudioStreamWAV.LOOP_DISABLED
var grid_snap_mode: String = "Clips"
var frame_rate: float = 30.0
var shortcut_overrides: Dictionary = {}
var accessibility_settings: Dictionary = {"ui_scale": 1.0, "high_contrast": false, "strong_focus": true, "meter_text": true}

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _next_clip_id: int = 1
const MAX_HISTORY: int = 80


func clear() -> void:
	tracks.clear()
	selected_track = -1
	selected_track_indices = PackedInt32Array()
	selected_clip_ids = PackedInt32Array()
	cursor_frame = 0
	selection_start = 0
	selection_end = 0
	clipboard = null
	clip_clipboard.clear()
	markers.clear()
	master_gain_db = 0.0
	master_effect_stack.clear()
	master_limiter_enabled = true
	master_limiter_ceiling_db = -1.0
	dirty = false
	project_bpm = 120.0
	time_signature_numerator = 4
	time_signature_denominator = 4
	playback_speed = 1.0
	metadata.clear()
	loop_start_frame = 0
	loop_end_frame = 0
	loop_mode = AudioStreamWAV.LOOP_DISABLED
	grid_snap_mode = "Clips"
	frame_rate = 30.0
	shortcut_overrides.clear()
	accessibility_settings = {"ui_scale": 1.0, "high_contrast": false, "strong_focus": true, "meter_text": true}
	_undo_stack.clear()
	_redo_stack.clear()
	_next_clip_id = 1


func create_persistence_snapshot() -> GASEditorModel:
	# Full editor-state snapshot for background save. PCM arrays remain shared
	# copy-on-write references; mutable track/effect metadata is duplicated.
	var snapshot: GASEditorModel = GASEditorModel.new()
	snapshot.sample_rate = sample_rate
	for track: GASEditorTrack in tracks:
		snapshot.tracks.append(track.duplicate_shallow())
	snapshot.selected_track = selected_track
	snapshot.selected_track_indices = selected_track_indices.duplicate()
	snapshot.selected_clip_ids = selected_clip_ids.duplicate()
	snapshot.cursor_frame = cursor_frame
	snapshot.selection_start = selection_start
	snapshot.selection_end = selection_end
	snapshot.markers = markers.duplicate(true)
	snapshot.master_gain_db = master_gain_db
	for effect: GASEffectData in master_effect_stack:
		snapshot.master_effect_stack.append(effect.duplicate_effect())
	snapshot.master_limiter_enabled = master_limiter_enabled
	snapshot.master_limiter_ceiling_db = master_limiter_ceiling_db
	snapshot.project_bpm = project_bpm
	snapshot.time_signature_numerator = time_signature_numerator
	snapshot.time_signature_denominator = time_signature_denominator
	snapshot.playback_speed = playback_speed
	snapshot.metadata = metadata.duplicate(true)
	snapshot.loop_start_frame = loop_start_frame
	snapshot.loop_end_frame = loop_end_frame
	snapshot.loop_mode = loop_mode
	snapshot.grid_snap_mode = grid_snap_mode
	snapshot.frame_rate = frame_rate
	snapshot.shortcut_overrides = shortcut_overrides.duplicate(true)
	snapshot.accessibility_settings = accessibility_settings.duplicate(true)
	snapshot._next_clip_id = _next_clip_id
	return snapshot


func commit_background_snapshot(snapshot: GASEditorModel, undo_label: String, copy_clipboard: bool = false) -> bool:
	if snapshot == null:
		return false
	push_undo(undo_label)
	tracks = snapshot.tracks
	selected_track = snapshot.selected_track
	selected_track_indices = snapshot.selected_track_indices.duplicate()
	selected_clip_ids = snapshot.selected_clip_ids.duplicate()
	cursor_frame = snapshot.cursor_frame
	selection_start = snapshot.selection_start
	selection_end = snapshot.selection_end
	_next_clip_id = snapshot._next_clip_id
	if copy_clipboard:
		clipboard = snapshot.clipboard
		clip_clipboard = snapshot.clip_clipboard.duplicate(true)
	sanitize_track_selection()
	dirty = true
	return true


func commit_background_clipboard(snapshot: GASEditorModel) -> bool:
	if snapshot == null or snapshot.clipboard == null:
		return false
	clipboard = snapshot.clipboard
	clip_clipboard = snapshot.clip_clipboard.duplicate(true)
	return true


func create_render_snapshot() -> GASEditorModel:
	# Capture immutable render state on the editor thread before background DSP.
	# Track/clip metadata and effect parameters are duplicated, while PackedFloat32Array
	# sample buffers remain copy-on-write references so song-sized PCM is not copied.
	var snapshot: GASEditorModel = GASEditorModel.new()
	snapshot.sample_rate = sample_rate
	for track: GASEditorTrack in tracks:
		snapshot.tracks.append(track.duplicate_shallow())
	snapshot.master_gain_db = master_gain_db
	for effect: GASEffectData in master_effect_stack:
		snapshot.master_effect_stack.append(effect.duplicate_effect())
	snapshot.master_limiter_enabled = master_limiter_enabled
	snapshot.master_limiter_ceiling_db = master_limiter_ceiling_db
	snapshot.metadata = metadata.duplicate(true)
	snapshot.markers = markers.duplicate(true)
	snapshot.loop_start_frame = loop_start_frame
	snapshot.loop_end_frame = loop_end_frame
	snapshot.loop_mode = loop_mode
	snapshot.project_bpm = project_bpm
	snapshot.time_signature_numerator = time_signature_numerator
	snapshot.time_signature_denominator = time_signature_denominator
	snapshot.playback_speed = playback_speed
	return snapshot


func create_track_render_snapshot(track_index: int) -> GASEditorModel:
	if track_index < 0 or track_index >= tracks.size():
		return null
	var snapshot: GASEditorModel = GASEditorModel.new()
	snapshot.sample_rate = sample_rate
	snapshot.tracks.append(tracks[track_index].duplicate_shallow())
	snapshot.metadata = metadata.duplicate(true)
	snapshot.loop_start_frame = loop_start_frame
	snapshot.loop_end_frame = loop_end_frame
	snapshot.loop_mode = loop_mode
	return snapshot


func project_end_frame() -> int:
	var result: int = 0
	for track: GASEditorTrack in tracks:
		result = maxi(result, track.end_frame())
	for marker: Dictionary in markers:
		result = maxi(result, int(marker.get("frame", 0)))
	return result


func has_selection() -> bool:
	return selection_end > selection_start


func selection_length() -> int:
	return maxi(0, selection_end - selection_start)


func set_selection(a: int, b: int) -> void:
	selection_start = maxi(0, mini(a, b))
	selection_end = maxi(0, maxi(a, b))
	cursor_frame = selection_start


func clear_time_selection() -> void:
	selection_start = cursor_frame
	selection_end = cursor_frame


func add_track(name: String = "Audio Track", record_undo: bool = true) -> int:
	if record_undo:
		push_undo("Add Track")
	var track: GASEditorTrack = GASEditorTrack.new()
	track.name = name
	track.sample_rate = sample_rate
	tracks.append(track)
	selected_track = tracks.size() - 1
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return selected_track


func add_pcm_as_track(pcm: GASPCMData, clip_name: String, source_path: String, waveform_cache: GASWaveformCache = null) -> int:
	if pcm == null:
		return -1
	if tracks.is_empty():
		sample_rate = pcm.sample_rate
	elif sample_rate != pcm.sample_rate:
		return -1
	push_undo("Import Audio")
	var track: GASEditorTrack = GASEditorTrack.new()
	track.name = clip_name
	track.sample_rate = pcm.sample_rate
	var clip: GASEditorClip = _make_clip(pcm, clip_name, source_path, 0, waveform_cache)
	track.clips.append(clip)
	tracks.append(track)
	selected_track = tracks.size() - 1
	selected_track_indices = PackedInt32Array([selected_track])
	select_clip(clip.clip_id, false, false)
	selection_start = 0
	selection_end = 0
	cursor_frame = 0
	dirty = true
	return selected_track


func add_pcm_as_new_track_at(pcm: GASPCMData, clip_name: String, source_path: String, at_frame: int, undo_label: String = "Record Audio", waveform_cache: GASWaveformCache = null) -> int:
	if pcm == null:
		return -1
	if tracks.is_empty():
		sample_rate = pcm.sample_rate
	elif sample_rate != pcm.sample_rate:
		return -1
	push_undo(undo_label)
	var track: GASEditorTrack = GASEditorTrack.new()
	track.name = clip_name
	track.sample_rate = pcm.sample_rate
	var clip: GASEditorClip = _make_clip(pcm, clip_name, source_path, maxi(0, at_frame), waveform_cache)
	track.clips.append(clip)
	tracks.append(track)
	selected_track = tracks.size() - 1
	selected_track_indices = PackedInt32Array([selected_track])
	select_clip(clip.clip_id, false, false)
	cursor_frame = clip.timeline_start
	clear_time_selection()
	dirty = true
	return selected_track


func add_pcm_to_track(pcm: GASPCMData, clip_name: String, source_path: String, track_index: int, at_frame: int, waveform_cache: GASWaveformCache = null) -> int:
	if pcm == null:
		return -1
	if tracks.is_empty():
		sample_rate = pcm.sample_rate
	if pcm.sample_rate != sample_rate:
		return -1
	push_undo("Insert Audio Clip")
	var target_track: int = track_index
	if target_track < 0 or target_track >= tracks.size():
		target_track = add_track("Audio Track %d" % (tracks.size() + 1), false)
	if not is_track_editable(target_track):
		return -1
	var clip: GASEditorClip = _make_clip(pcm, clip_name, source_path, maxi(0, at_frame), waveform_cache)
	tracks[target_track].clips.append(clip)
	_sort_track_clips(target_track)
	selected_track = target_track
	selected_track_indices = PackedInt32Array([selected_track])
	select_clip(clip.clip_id, false, false)
	cursor_frame = clip.timeline_start
	clear_time_selection()
	dirty = true
	return target_track



func add_typed_track(track_type: int, name: String) -> int:
	push_undo("Add Track")
	var track: GASEditorTrack = GASEditorTrack.new()
	track.sample_rate = sample_rate
	track.track_type = clampi(track_type, GASEditorTrack.TYPE_AUDIO, GASEditorTrack.TYPE_REFERENCE)
	track.name = name
	track.reference_read_only = track.track_type == GASEditorTrack.TYPE_REFERENCE
	tracks.append(track)
	selected_track = tracks.size() - 1
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return selected_track


func select_track(index: int, toggle: bool = false, extend_range: bool = false) -> void:
	if index < 0 or index >= tracks.size():
		return
	if extend_range and selected_track >= 0:
		var first: int = mini(selected_track, index)
		var last: int = maxi(selected_track, index)
		selected_track_indices = PackedInt32Array()
		for i: int in range(first, last + 1):
			selected_track_indices.append(i)
	elif toggle:
		if selected_track_indices.has(index):
			var next: PackedInt32Array = PackedInt32Array()
			for existing: int in selected_track_indices:
				if existing != index:
					next.append(existing)
			selected_track_indices = next
		else:
			selected_track_indices.append(index)
	else:
		selected_track_indices = PackedInt32Array([index])
	selected_track = index


func is_track_selected(index: int) -> bool:
	return selected_track_indices.has(index) or (selected_track_indices.is_empty() and selected_track == index)


func selected_tracks() -> PackedInt32Array:
	if selected_track_indices.is_empty() and selected_track >= 0:
		return PackedInt32Array([selected_track])
	return selected_track_indices.duplicate()


func primary_selected_track() -> int:
	# Keep a single authoritative primary track even if an older project/state
	# only restored the multi-track or clip selection arrays.
	if selected_track >= 0 and selected_track < tracks.size():
		if selected_track_indices.is_empty():
			selected_track_indices = PackedInt32Array([selected_track])
		return selected_track
	for index: int in selected_track_indices:
		if index >= 0 and index < tracks.size():
			selected_track = index
			return selected_track
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x >= 0 and location.x < tracks.size():
			selected_track = location.x
			if selected_track_indices.is_empty():
				selected_track_indices = PackedInt32Array([selected_track])
			elif not selected_track_indices.has(selected_track):
				selected_track_indices.append(selected_track)
			return selected_track
	selected_track = -1
	return -1


func sanitize_track_selection() -> void:
	selected_track = clampi(selected_track, -1, tracks.size() - 1)
	var clean: PackedInt32Array = PackedInt32Array()
	for index: int in selected_track_indices:
		if index >= 0 and index < tracks.size() and not clean.has(index):
			clean.append(index)
	if clean.is_empty() and selected_track >= 0:
		clean.append(selected_track)
	selected_track_indices = clean


func duplicate_selected_track() -> bool:
	if not _valid_selected_track():
		return false
	push_undo("Duplicate Track")
	var copy: GASEditorTrack = tracks[selected_track].duplicate_shallow()
	copy.name += " Copy"
	for clip: GASEditorClip in copy.clips:
		clip.clip_id = _allocate_clip_id()
	tracks.insert(selected_track + 1, copy)
	selected_track += 1
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return true


func move_selected_track(direction: int) -> bool:
	if not _valid_selected_track() or direction == 0:
		return false
	var step: int = 1 if direction > 0 else -1
	var target: int = clampi(selected_track + step, 0, tracks.size() - 1)
	if target == selected_track:
		return false
	push_undo("Reorder Track")
	var item: GASEditorTrack = tracks[selected_track]
	tracks.remove_at(selected_track)
	tracks.insert(target, item)
	selected_track = target
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return true


func reorder_track(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= tracks.size() or to_index < 0 or to_index >= tracks.size() or from_index == to_index:
		return false
	push_undo("Reorder Track")
	var moving: GASEditorTrack = tracks[from_index]
	tracks.remove_at(from_index)
	var insert_index: int = clampi(to_index, 0, tracks.size())
	tracks.insert(insert_index, moving)
	selected_track = insert_index
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return true


func sort_tracks_by_name() -> void:
	if tracks.size() < 2:
		return
	push_undo("Sort Tracks")
	tracks.sort_custom(_track_name_less_than)
	selected_track = clampi(selected_track, -1, tracks.size() - 1)
	selected_track_indices = PackedInt32Array([selected_track]) if selected_track >= 0 else PackedInt32Array()
	dirty = true


func _track_name_less_than(a: GASEditorTrack, b: GASEditorTrack) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0


func merge_selected_track_down() -> bool:
	if not _valid_selected_track() or selected_track >= tracks.size() - 1 or not is_track_editable(selected_track) or not is_track_editable(selected_track + 1):
		return false
	var a: GASPCMData = render_track(selected_track)
	var b: GASPCMData = render_track(selected_track + 1)
	if a == null and b == null:
		return false
	push_undo("Merge Tracks")
	var merged: GASPCMData = _mix_pair(a, b)
	_replace_track_with_pcm(selected_track, merged, 0, tracks[selected_track].name + " + " + tracks[selected_track + 1].name)
	tracks.remove_at(selected_track + 1)
	dirty = true
	return true


func render_selected_track_to_new_track() -> bool:
	if not _valid_selected_track():
		return false
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return false
	add_pcm_as_new_track_at(rendered, tracks[selected_track].name + " Render", "generated://rendered_track", 0, "Render Track")
	return true


func mix_selected_track_to_mono() -> bool:
	if not _valid_selected_track() or not is_track_editable(selected_track):
		return false
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return false
	push_undo("Mix Track to Mono")
	_replace_track_with_pcm(selected_track, rendered.force_mono(), 0, tracks[selected_track].name + " Mono")
	tracks[selected_track].channel_mode = GASEditorTrack.CHANNEL_MONO
	dirty = true
	return true


func mix_selected_track_to_stereo() -> bool:
	if not _valid_selected_track() or not is_track_editable(selected_track):
		return false
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return false
	var stereo: GASPCMData = rendered.duplicate_pcm()
	if not stereo.is_stereo():
		stereo.channels = 2
		stereo.right = stereo.left.duplicate()
	push_undo("Mix Track to Stereo")
	_replace_track_with_pcm(selected_track, stereo, 0, tracks[selected_track].name + " Stereo")
	tracks[selected_track].channel_mode = GASEditorTrack.CHANNEL_STEREO
	dirty = true
	return true


func set_automation_lane(track_index: int, parameter: String, points: Array[Dictionary]) -> bool:
	if track_index < 0 or track_index >= tracks.size() or parameter.is_empty() or not is_track_editable(track_index):
		return false
	push_undo("Edit Automation")
	tracks[track_index].automation_lanes[parameter] = AutomationEngine.sorted_points(points)
	dirty = true
	return true


func add_automation_point(track_index: int, parameter: String, frame: int, value: float, curve: String = "linear") -> bool:
	if track_index < 0 or track_index >= tracks.size():
		return false
	var points: Array[Dictionary] = []
	var existing: Variant = tracks[track_index].automation_lanes.get(parameter, [])
	if existing is Array:
		var existing_array: Array = existing as Array
		for item: Variant in existing_array:
			if item is Dictionary:
				points.append((item as Dictionary).duplicate(true))
	points.append({"frame": maxi(0, frame), "value": value, "curve": curve})
	return set_automation_lane(track_index, parameter, points)


func clear_automation_lane(track_index: int, parameter: String) -> bool:
	if track_index < 0 or track_index >= tracks.size() or not is_track_editable(track_index) or not tracks[track_index].automation_lanes.has(parameter):
		return false
	push_undo("Clear Automation")
	tracks[track_index].automation_lanes.erase(parameter)
	dirty = true
	return true


func add_region(start_frame: int, end_frame: int, name: String, kind: String = "Region", color: Color = Color(0.92, 0.67, 0.20, 1.0)) -> void:
	push_undo("Add Region")
	markers.append({
		"frame": maxi(0, mini(start_frame, end_frame)),
		"end_frame": maxi(0, maxi(start_frame, end_frame)),
		"name": name,
		"kind": kind,
		"color": color.to_html(),
	})
	dirty = true


func update_marker(index: int, name: String, start_frame: int, end_frame: int, kind: String, color: Color) -> bool:
	if index < 0 or index >= markers.size():
		return false
	push_undo("Edit Label")
	markers[index] = {
		"frame": maxi(0, mini(start_frame, end_frame)),
		"end_frame": maxi(0, maxi(start_frame, end_frame)),
		"name": name,
		"kind": kind,
		"color": color.to_html(),
	}
	dirty = true
	return true


func remove_marker(index: int) -> bool:
	if index < 0 or index >= markers.size():
		return false
	push_undo("Delete Label")
	markers.remove_at(index)
	dirty = true
	return true


func sample_edit_set(clip_id: int, local_frame: int, amplitude: float, channel: int = 0, record_undo: bool = true, rebuild_cache: bool = true) -> bool:
	var clip: GASEditorClip = find_clip(clip_id)
	if clip == null or clip.pcm == null:
		return false
	var location: Vector2i = find_clip_location(clip_id)
	if location.x >= 0 and not is_track_editable(location.x):
		return false
	var source_frame: int = clip.source_start_frame + local_frame
	if source_frame < clip.source_start_frame or source_frame >= clip.source_end():
		return false
	if record_undo:
		push_undo("Draw Sample")
	_make_clip_pcm_writable(clip)
	source_frame = clip.source_start_frame + local_frame
	if channel == 1 and clip.pcm.is_stereo():
		clip.pcm.right[source_frame] = clampf(amplitude, -1.0, 1.0)
	else:
		clip.pcm.left[source_frame] = clampf(amplitude, -1.0, 1.0)
	clip.source_path = "generated://sample_edit"
	if rebuild_cache:
		clip.rebuild_cache()
	dirty = true
	return true


func finalize_sample_edit(clip_id: int) -> void:
	var clip: GASEditorClip = find_clip(clip_id)
	if clip != null:
		clip.rebuild_cache()


func sample_edit_selection(mode: String) -> bool:
	if selected_clip_ids.is_empty() or not has_selection():
		return false
	push_undo("Sample " + mode)
	var changed: bool = false
	for clip_id: int in selected_clip_ids:
		var clip: GASEditorClip = find_clip(clip_id)
		if clip == null or clip.pcm == null:
			continue
		var location: Vector2i = find_clip_location(clip_id)
		if location.x >= 0 and not is_track_editable(location.x):
			continue
		var local_start: int = clampi(selection_start - clip.timeline_start, 0, clip.frame_count())
		var local_end: int = clampi(selection_end - clip.timeline_start, local_start, clip.frame_count())
		if local_end <= local_start:
			continue
		_make_clip_pcm_writable(clip)
		var a: int = clip.source_start_frame + local_start
		var b: int = clip.source_start_frame + local_end
		match mode:
			"Zero":
				for i: int in range(a, b):
					clip.pcm.left[i] = 0.0
					if clip.pcm.is_stereo():
						clip.pcm.right[i] = 0.0
			"Interpolate":
				_interpolate_pcm_region(clip.pcm, a, b)
			"Smooth":
				_smooth_pcm_region(clip.pcm, a, b)
			"Repair":
				_interpolate_pcm_region(clip.pcm, a, b)
				_smooth_pcm_region(clip.pcm, maxi(a, a - 2), mini(clip.pcm.frame_count(), b + 2))
			_:
				continue
		clip.source_path = "generated://sample_edit"
		clip.rebuild_cache()
		changed = true
	if changed:
		dirty = true
	return changed


func history_labels() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _undo_stack:
		result.append(str(entry.get("label", "Edit")))
	return result


func jump_history_back(steps: int) -> String:
	var count: int = clampi(steps, 0, _undo_stack.size())
	var last: String = ""
	for _i: int in range(count):
		last = undo()
	return last


func _make_clip_pcm_writable(clip: GASEditorClip) -> void:
	if clip.source_path == "generated://sample_edit" and clip.source_start_frame == 0 and clip.source_end() == clip.pcm.frame_count():
		return
	var sliced: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
	clip.pcm = sliced
	clip.source_start_frame = 0
	clip.source_end_frame = sliced.frame_count()


func _interpolate_pcm_region(pcm: GASPCMData, start_frame: int, end_frame: int) -> void:
	var a: int = clampi(start_frame, 0, pcm.frame_count())
	var b: int = clampi(end_frame, a, pcm.frame_count())
	if b <= a:
		return
	var left_a: float = pcm.left[maxi(0, a - 1)]
	var left_b: float = pcm.left[mini(pcm.frame_count() - 1, b)]
	var right_a: float = pcm.right[maxi(0, a - 1)] if pcm.is_stereo() else left_a
	var right_b: float = pcm.right[mini(pcm.frame_count() - 1, b)] if pcm.is_stereo() else left_b
	for i: int in range(a, b):
		var t: float = float(i - a + 1) / float(b - a + 1)
		pcm.left[i] = lerpf(left_a, left_b, t)
		if pcm.is_stereo():
			pcm.right[i] = lerpf(right_a, right_b, t)


func _smooth_pcm_region(pcm: GASPCMData, start_frame: int, end_frame: int) -> void:
	var a: int = clampi(start_frame, 1, maxi(1, pcm.frame_count() - 1))
	var b: int = clampi(end_frame, a, maxi(a, pcm.frame_count() - 1))
	var source_left: PackedFloat32Array = pcm.left.duplicate()
	var source_right: PackedFloat32Array = pcm.right.duplicate() if pcm.is_stereo() else PackedFloat32Array()
	for i: int in range(a, b):
		pcm.left[i] = (source_left[i - 1] + source_left[i] * 2.0 + source_left[i + 1]) * 0.25
		if pcm.is_stereo():
			pcm.right[i] = (source_right[i - 1] + source_right[i] * 2.0 + source_right[i + 1]) * 0.25


func _mix_pair(a: GASPCMData, b: GASPCMData) -> GASPCMData:
	if a == null:
		return b.duplicate_pcm() if b != null else null
	if b == null:
		return a.duplicate_pcm()
	var count: int = maxi(a.frame_count(), b.frame_count())
	var stereo: bool = a.is_stereo() or b.is_stereo()
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = 2 if stereo else 1
	out.left.resize(count)
	if stereo:
		out.right.resize(count)
	for i: int in range(count):
		var al: float = a.left[i] if i < a.frame_count() else 0.0
		var ar: float = a.right[i] if a.is_stereo() and i < a.frame_count() else al
		var bl: float = b.left[i] if i < b.frame_count() else 0.0
		var br: float = b.right[i] if b.is_stereo() and i < b.frame_count() else bl
		out.left[i] = clampf(al + bl, -1.0, 1.0)
		if stereo:
			out.right[i] = clampf(ar + br, -1.0, 1.0)
	return out


func remove_selected_track() -> void:
	if selected_track < 0 or selected_track >= tracks.size():
		return
	push_undo("Remove Track")
	tracks.remove_at(selected_track)
	selected_track = mini(selected_track, tracks.size() - 1)
	selected_track_indices = PackedInt32Array([selected_track]) if selected_track >= 0 else PackedInt32Array()
	_prune_clip_selection()
	dirty = true


func select_clip(clip_id: int, additive: bool, toggle: bool) -> void:
	if clip_id <= 0:
		if not additive:
			selected_clip_ids = PackedInt32Array()
		return
	var location: Vector2i = find_clip_location(clip_id)
	if location.x < 0:
		return
	var exists: bool = selected_clip_ids.has(clip_id)
	var remains_selected: bool = true
	if toggle:
		if exists:
			_remove_selected_clip_id(clip_id)
			remains_selected = false
		else:
			selected_clip_ids.append(clip_id)
	elif additive:
		if not exists:
			selected_clip_ids.append(clip_id)
	else:
		selected_clip_ids = PackedInt32Array([clip_id])
	if remains_selected:
		selected_track = location.x
		if additive or toggle:
			if not selected_track_indices.has(location.x):
				selected_track_indices.append(location.x)
		else:
			selected_track_indices = PackedInt32Array([location.x])


func select_clips_in_time_range(track_index: int, start_frame: int, end_frame: int, additive: bool = false) -> void:
	if track_index < 0 or track_index >= tracks.size():
		return
	if not additive:
		selected_clip_ids = PackedInt32Array()
	var a: int = mini(start_frame, end_frame)
	var b: int = maxi(start_frame, end_frame)
	for clip: GASEditorClip in tracks[track_index].clips:
		if clip.end_frame() > a and clip.timeline_start < b and not selected_clip_ids.has(clip.clip_id):
			selected_clip_ids.append(clip.clip_id)


func clear_clip_selection() -> void:
	selected_clip_ids = PackedInt32Array()


func is_clip_selected(clip_id: int) -> bool:
	return selected_clip_ids.has(clip_id)


func selected_clip_count() -> int:
	return selected_clip_ids.size()


func find_clip(clip_id: int) -> GASEditorClip:
	for track: GASEditorTrack in tracks:
		for clip: GASEditorClip in track.clips:
			if clip.clip_id == clip_id:
				return clip
	return null


func find_clip_location(clip_id: int) -> Vector2i:
	for track_index: int in range(tracks.size()):
		var track: GASEditorTrack = tracks[track_index]
		for clip_index: int in range(track.clips.size()):
			if track.clips[clip_index].clip_id == clip_id:
				return Vector2i(track_index, clip_index)
	return Vector2i(-1, -1)


func selected_clip_locations() -> Dictionary:
	var result: Dictionary = {}
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0:
			continue
		var clip: GASEditorClip = tracks[location.x].clips[location.y]
		result[clip_id] = {"track": location.x, "start": clip.timeline_start}
	return result


func delete_selected_clips() -> bool:
	if selected_clip_ids.is_empty():
		return false
	push_undo("Delete Clips")
	var changed: bool = false
	for track_index: int in range(tracks.size()):
		if not is_track_editable(track_index):
			continue
		var track: GASEditorTrack = tracks[track_index]
		for index: int in range(track.clips.size() - 1, -1, -1):
			if selected_clip_ids.has(track.clips[index].clip_id):
				track.clips.remove_at(index)
				changed = true
	selected_clip_ids = PackedInt32Array()
	if changed:
		dirty = true
	return changed


func duplicate_selected_clips(offset_frames: int = -1) -> bool:
	if selected_clip_ids.is_empty():
		return false
	push_undo("Duplicate Clips")
	var offset: int = offset_frames
	if offset < 0:
		offset = maxi(1, int(round(float(sample_rate) * 0.05)))
	var new_ids: PackedInt32Array = PackedInt32Array()
	var originals: Array[Dictionary] = []
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0 or not is_track_editable(location.x):
			continue
		originals.append({"track": location.x, "clip": tracks[location.x].clips[location.y]})
	for item: Dictionary in originals:
		var source_clip: GASEditorClip = item["clip"] as GASEditorClip
		var copy: GASEditorClip = source_clip.duplicate_with_new_id(_allocate_clip_id())
		copy.timeline_start = maxi(0, source_clip.timeline_start + offset)
		copy.name = source_clip.name + " Copy"
		var track_index: int = int(item["track"])
		tracks[track_index].clips.append(copy)
		new_ids.append(copy.clip_id)
		_sort_track_clips(track_index)
	selected_clip_ids = new_ids
	dirty = true
	return not new_ids.is_empty()


func copy_selected_clips() -> bool:
	clipboard = null
	if selected_clip_ids.is_empty():
		return false
	clip_clipboard.clear()
	var min_frame: int = 2147483647
	var min_track: int = 2147483647
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0:
			continue
		var clip: GASEditorClip = tracks[location.x].clips[location.y]
		min_frame = mini(min_frame, clip.timeline_start)
		min_track = mini(min_track, location.x)
	if min_frame == 2147483647:
		return false
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0:
			continue
		var clip: GASEditorClip = tracks[location.x].clips[location.y]
		clip_clipboard.append({
			"clip": clip.duplicate_shallow(),
			"frame_offset": clip.timeline_start - min_frame,
			"track_offset": location.x - min_track,
		})
	return not clip_clipboard.is_empty()


func cut_selected_clips() -> bool:
	if not copy_selected_clips():
		return false
	return delete_selected_clips()


func paste_clips_at_cursor() -> bool:
	if clip_clipboard.is_empty():
		return false
	push_undo("Paste Clips")
	var base_track: int = selected_track
	if base_track < 0 or not is_track_editable(base_track):
		base_track = add_track("Pasted Audio", false)
	var max_offset: int = 0
	for item: Dictionary in clip_clipboard:
		max_offset = maxi(max_offset, int(item.get("track_offset", 0)))
	while tracks.size() <= base_track + max_offset:
		add_track("Audio Track %d" % (tracks.size() + 1), false)
	var new_ids: PackedInt32Array = PackedInt32Array()
	for item: Dictionary in clip_clipboard:
		var source_clip: GASEditorClip = item["clip"] as GASEditorClip
		var copy: GASEditorClip = source_clip.duplicate_with_new_id(_allocate_clip_id())
		copy.timeline_start = maxi(0, cursor_frame + int(item.get("frame_offset", 0)))
		var target_track: int = base_track + int(item.get("track_offset", 0))
		tracks[target_track].clips.append(copy)
		_sort_track_clips(target_track)
		new_ids.append(copy.clip_id)
	selected_clip_ids = new_ids
	dirty = true
	return true


func move_selected_clips(original_locations: Dictionary, delta_frames: int, track_delta: int, snap_enabled: bool = true, snap_tolerance_frames: int = 0) -> bool:
	if selected_clip_ids.is_empty() or original_locations.is_empty():
		return false
	var min_track: int = 2147483647
	var max_track: int = -1
	var min_start: int = 2147483647
	for clip_id: int in selected_clip_ids:
		if not original_locations.has(clip_id):
			continue
		var info: Dictionary = original_locations[clip_id] as Dictionary
		min_track = mini(min_track, int(info["track"]))
		max_track = maxi(max_track, int(info["track"]))
		min_start = mini(min_start, int(info["start"]))
	if min_track == 2147483647:
		return false
	for clip_id: int in selected_clip_ids:
		var locked_location: Vector2i = find_clip_location(clip_id)
		if locked_location.x >= 0 and not is_track_editable(locked_location.x):
			return false
	var clamped_track_delta: int = clampi(track_delta, -min_track, tracks.size() - 1 - max_track)
	var clamped_frame_delta: int = maxi(-min_start, delta_frames)
	for clip_id: int in selected_clip_ids:
		if not original_locations.has(clip_id):
			continue
		var destination_info: Dictionary = original_locations[clip_id] as Dictionary
		var destination_track: int = int(destination_info.get("track", 0)) + clamped_track_delta
		if not is_track_editable(destination_track):
			return false
	if snap_enabled:
		var primary_id: int = selected_clip_ids[0]
		if original_locations.has(primary_id):
			var primary_info: Dictionary = original_locations[primary_id] as Dictionary
			var primary_clip: GASEditorClip = find_clip(primary_id)
			if primary_clip != null:
				var target_track: int = int(primary_info["track"]) + clamped_track_delta
				var candidate_start: int = int(primary_info["start"]) + clamped_frame_delta
				var tolerance: int = snap_tolerance_frames if snap_tolerance_frames > 0 else maxi(1, int(round(float(sample_rate) * 0.015)))
				var snapped_start: int = snap_frame(candidate_start, target_track, selected_clip_ids, tolerance, false)
				var start_adjust: int = snapped_start - candidate_start
				var candidate_end: int = candidate_start + primary_clip.frame_count()
				var snapped_end: int = snap_frame(candidate_end, target_track, selected_clip_ids, tolerance, false)
				var end_adjust: int = snapped_end - candidate_end
				if abs(start_adjust) <= abs(end_adjust):
					clamped_frame_delta += start_adjust
				else:
					clamped_frame_delta += end_adjust
				clamped_frame_delta = maxi(-min_start, clamped_frame_delta)
	push_undo("Move Clips")
	var sync_group_thresholds: Dictionary = {}
	if clamped_frame_delta != 0:
		for clip_id: int in selected_clip_ids:
			if not original_locations.has(clip_id):
				continue
			var sync_info: Dictionary = original_locations[clip_id] as Dictionary
			var sync_track_index: int = int(sync_info.get("track", -1))
			if sync_track_index < 0 or sync_track_index >= tracks.size():
				continue
			var sync_group: int = tracks[sync_track_index].sync_group
			if sync_group <= 0:
				continue
			var sync_start: int = int(sync_info.get("start", 0))
			if not sync_group_thresholds.has(sync_group) or sync_start < int(sync_group_thresholds[sync_group]):
				sync_group_thresholds[sync_group] = sync_start
	var moves: Array[Dictionary] = []
	for clip_id: int in selected_clip_ids:
		if not original_locations.has(clip_id):
			continue
		var current_location: Vector2i = find_clip_location(clip_id)
		if current_location.x < 0:
			continue
		var original: Dictionary = original_locations[clip_id] as Dictionary
		moves.append({
			"clip": tracks[current_location.x].clips[current_location.y],
			"from_track": current_location.x,
			"to_track": int(original["track"]) + clamped_track_delta,
			"new_start": maxi(0, int(original["start"]) + clamped_frame_delta),
		})
	for move: Dictionary in moves:
		var moving_clip: GASEditorClip = move["clip"] as GASEditorClip
		var from_track: int = int(move["from_track"])
		_remove_clip_reference_from_track(from_track, moving_clip)
	for move: Dictionary in moves:
		var moving_clip: GASEditorClip = move["clip"] as GASEditorClip
		var to_track: int = int(move["to_track"])
		moving_clip.timeline_start = int(move["new_start"])
		tracks[to_track].clips.append(moving_clip)
		_sort_track_clips(to_track)
	if clamped_frame_delta != 0 and not sync_group_thresholds.is_empty():
		for sync_track_index: int in range(tracks.size()):
			var sync_track: GASEditorTrack = tracks[sync_track_index]
			if sync_track.sync_group <= 0 or not sync_group_thresholds.has(sync_track.sync_group) or sync_track.locked or sync_track.reference_read_only:
				continue
			var threshold: int = int(sync_group_thresholds[sync_track.sync_group])
			for sync_clip: GASEditorClip in sync_track.clips:
				if selected_clip_ids.has(sync_clip.clip_id):
					continue
				if sync_clip.timeline_start >= threshold:
					sync_clip.timeline_start = maxi(0, sync_clip.timeline_start + clamped_frame_delta)
			_sort_track_clips(sync_track_index)
	selected_track = clampi(selected_track + clamped_track_delta, 0, tracks.size() - 1)
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return true


func trim_clip_edge(clip_id: int, edge: String, target_frame: int, snap_enabled: bool = true, snap_tolerance_frames: int = 0) -> bool:
	var location: Vector2i = find_clip_location(clip_id)
	if location.x < 0 or not is_track_editable(location.x):
		return false
	var clip: GASEditorClip = tracks[location.x].clips[location.y]
	if clip.pcm == null or clip.frame_count() <= 0:
		return false
	var tolerance: int = snap_tolerance_frames if snap_tolerance_frames > 0 else maxi(1, int(round(float(sample_rate) * 0.01)))
	var frame: int = target_frame
	if snap_enabled:
		frame = snap_frame(frame, location.x, PackedInt32Array([clip_id]), tolerance, true)
	if edge == "left":
		var minimum_global: int = maxi(0, clip.timeline_start - clip.source_start_frame)
		var maximum_global: int = clip.end_frame() - 1
		frame = clampi(frame, minimum_global, maximum_global)
		var delta: int = frame - clip.timeline_start
		if delta == 0:
			return false
		push_undo("Trim Clip Start")
		clip.source_start_frame = clampi(clip.source_start_frame + delta, 0, clip.source_end() - 1)
		clip.timeline_start = frame
	else:
		var minimum_end: int = clip.timeline_start + 1
		var maximum_end: int = clip.timeline_start + (clip.pcm.frame_count() - clip.source_start_frame)
		frame = clampi(frame, minimum_end, maximum_end)
		var new_count: int = frame - clip.timeline_start
		var new_source_end: int = clip.source_start_frame + new_count
		if new_source_end == clip.source_end():
			return false
		push_undo("Trim Clip End")
		clip.source_end_frame = clampi(new_source_end, clip.source_start_frame + 1, clip.pcm.frame_count())
	dirty = true
	return true


func split_selected_at_cursor() -> bool:
	var targets: PackedInt32Array = selected_clip_ids.duplicate()
	if targets.is_empty() and _valid_selected_track():
		for clip: GASEditorClip in tracks[selected_track].clips:
			if cursor_frame > clip.timeline_start and cursor_frame < clip.end_frame():
				targets.append(clip.clip_id)
				break
	if targets.is_empty():
		return false
	var can_split: bool = false
	for clip_id: int in targets:
		var candidate_location: Vector2i = find_clip_location(clip_id)
		var candidate: GASEditorClip = find_clip(clip_id)
		if candidate_location.x >= 0 and is_track_editable(candidate_location.x) and candidate != null and cursor_frame > candidate.timeline_start and cursor_frame < candidate.end_frame():
			can_split = true
			break
	if not can_split:
		return false
	push_undo("Split Clips")
	var new_selection: PackedInt32Array = PackedInt32Array()
	var changed: bool = false
	for clip_id: int in targets:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0 or not is_track_editable(location.x):
			continue
		var clip: GASEditorClip = tracks[location.x].clips[location.y]
		if cursor_frame <= clip.timeline_start or cursor_frame >= clip.end_frame():
			new_selection.append(clip.clip_id)
			continue
		var split_offset: int = cursor_frame - clip.timeline_start
		var source_split: int = clip.source_start_frame + split_offset
		var left_clip: GASEditorClip = clip.duplicate_shallow()
		left_clip.source_end_frame = source_split
		var right_clip: GASEditorClip = clip.duplicate_with_new_id(_allocate_clip_id())
		right_clip.timeline_start = cursor_frame
		right_clip.source_start_frame = source_split
		tracks[location.x].clips[location.y] = left_clip
		tracks[location.x].clips.insert(location.y + 1, right_clip)
		new_selection.append(left_clip.clip_id)
		new_selection.append(right_clip.clip_id)
		changed = true
	if changed:
		selected_clip_ids = new_selection
		dirty = true
	return changed


func split_selected_at_selection() -> bool:
	if not has_selection():
		return split_selected_at_cursor()
	var targets: PackedInt32Array = selected_clip_ids.duplicate()
	if targets.is_empty() and _valid_selected_track():
		for clip: GASEditorClip in tracks[selected_track].clips:
			if clip.end_frame() > selection_start and clip.timeline_start < selection_end:
				targets.append(clip.clip_id)
	if targets.is_empty():
		return false
	var can_split: bool = false
	for clip_id: int in targets:
		var candidate_location: Vector2i = find_clip_location(clip_id)
		var candidate: GASEditorClip = find_clip(clip_id)
		if candidate == null or candidate_location.x < 0 or not is_track_editable(candidate_location.x):
			continue
		if (selection_start > candidate.timeline_start and selection_start < candidate.end_frame()) or (selection_end > candidate.timeline_start and selection_end < candidate.end_frame()):
			can_split = true
			break
	if not can_split:
		return false
	push_undo("Split Clips at Selection")
	var new_selection: PackedInt32Array = PackedInt32Array()
	for clip_id: int in targets:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0 or not is_track_editable(location.x):
			continue
		var clip: GASEditorClip = tracks[location.x].clips[location.y]
		var boundaries: PackedInt32Array = PackedInt32Array()
		if selection_start > clip.timeline_start and selection_start < clip.end_frame():
			boundaries.append(selection_start)
		if selection_end > clip.timeline_start and selection_end < clip.end_frame() and selection_end != selection_start:
			boundaries.append(selection_end)
		if boundaries.is_empty():
			new_selection.append(clip.clip_id)
			continue
		boundaries.sort()
		var pieces: Array[GASEditorClip] = []
		var segment_start_global: int = clip.timeline_start
		var segment_source_start: int = clip.source_start_frame
		for boundary: int in boundaries:
			var split_source: int = clip.source_start_frame + (boundary - clip.timeline_start)
			var piece: GASEditorClip = clip.duplicate_shallow() if pieces.is_empty() else clip.duplicate_with_new_id(_allocate_clip_id())
			piece.timeline_start = segment_start_global
			piece.source_start_frame = segment_source_start
			piece.source_end_frame = split_source
			pieces.append(piece)
			segment_start_global = boundary
			segment_source_start = split_source
		var final_piece: GASEditorClip = clip.duplicate_with_new_id(_allocate_clip_id())
		final_piece.timeline_start = segment_start_global
		final_piece.source_start_frame = segment_source_start
		final_piece.source_end_frame = clip.source_end()
		pieces.append(final_piece)
		tracks[location.x].clips.remove_at(location.y)
		for offset: int in range(pieces.size()):
			tracks[location.x].clips.insert(location.y + offset, pieces[offset])
			new_selection.append(pieces[offset].clip_id)
	selected_clip_ids = new_selection
	dirty = true
	return true


func rename_clip(clip_id: int, new_name: String) -> bool:
	var clip: GASEditorClip = find_clip(clip_id)
	var location: Vector2i = find_clip_location(clip_id)
	var clean_name: String = new_name.strip_edges()
	if clip == null or location.x < 0 or not is_track_editable(location.x) or clean_name.is_empty() or clean_name == clip.name:
		return false
	push_undo("Rename Clip")
	clip.name = clean_name
	dirty = true
	return true


func join_selected_clips() -> bool:
	if selected_clip_ids.size() < 2:
		return false
	var target_track: int = -1
	var selected: Array[GASEditorClip] = []
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x < 0:
			continue
		if target_track < 0:
			target_track = location.x
		elif target_track != location.x:
			return false
		selected.append(tracks[location.x].clips[location.y])
	if selected.size() < 2 or target_track < 0 or not is_track_editable(target_track):
		return false
	var start_frame: int = 2147483647
	var end_frame: int = 0
	var stereo: bool = false
	for clip: GASEditorClip in selected:
		start_frame = mini(start_frame, clip.timeline_start)
		end_frame = maxi(end_frame, clip.end_frame())
		stereo = stereo or (clip.pcm != null and (clip.pcm.is_stereo() or absf(clip.pan) > 0.0001))
	var joined: GASPCMData = GASPCMData.new()
	joined.sample_rate = sample_rate
	joined.channels = 2 if stereo else 1
	joined.left.resize(end_frame - start_frame)
	if stereo:
		joined.right.resize(end_frame - start_frame)
	for clip: GASEditorClip in selected:
		if clip.pcm == null:
			continue
		var clip_gain: float = db_to_linear(clip.gain_db)
		var pan_value: float = clampf(clip.pan, -1.0, 1.0)
		var left_pan: float = 1.0 if pan_value <= 0.0 else 1.0 - pan_value
		var right_pan: float = 1.0 if pan_value >= 0.0 else 1.0 + pan_value
		var clip_count: int = clip.frame_count()
		var source_start: int = clip.source_start_frame
		for local: int in range(clip_count):
			var source_index: int = source_start + local
			var dst: int = clip.timeline_start - start_frame + local
			var left_value: float = clip.pcm.left[source_index] * clip_gain
			var right_value: float = clip.pcm.right[source_index] if clip.pcm.is_stereo() else clip.pcm.left[source_index]
			joined.left[dst] += left_value * left_pan
			if stereo:
				joined.right[dst] += right_value * clip_gain * right_pan
	for i: int in range(joined.frame_count()):
		joined.left[i] = clampf(joined.left[i], -1.0, 1.0)
		if stereo:
			joined.right[i] = clampf(joined.right[i], -1.0, 1.0)
	push_undo("Join Clips")
	for index: int in range(tracks[target_track].clips.size() - 1, -1, -1):
		if selected_clip_ids.has(tracks[target_track].clips[index].clip_id):
			tracks[target_track].clips.remove_at(index)
	var merged: GASEditorClip = _make_clip(joined, "Joined Clip", "joined://", start_frame)
	tracks[target_track].clips.append(merged)
	_sort_track_clips(target_track)
	selected_clip_ids = PackedInt32Array([merged.clip_id])
	dirty = true
	return true


func detach_selected_to_new_tracks() -> bool:
	if selected_clip_ids.is_empty():
		return false
	for clip_id: int in selected_clip_ids:
		var source_location: Vector2i = find_clip_location(clip_id)
		if source_location.x >= 0 and not is_track_editable(source_location.x):
			return false
	push_undo("Separate Clips to Tracks")
	var selected: Array[GASEditorClip] = []
	for clip_id: int in selected_clip_ids:
		var location: Vector2i = find_clip_location(clip_id)
		if location.x >= 0:
			selected.append(tracks[location.x].clips[location.y])
	for clip: GASEditorClip in selected:
		var location: Vector2i = find_clip_location(clip.clip_id)
		if location.x < 0:
			continue
		_remove_clip_reference_from_track(location.x, clip)
		var new_track: GASEditorTrack = GASEditorTrack.new()
		new_track.name = clip.name
		new_track.clips.append(clip)
		tracks.append(new_track)
	selected_track = tracks.size() - 1
	selected_track_indices = PackedInt32Array([selected_track])
	dirty = true
	return true


func split_delete_selection() -> bool:
	if not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return false
	var track: GASEditorTrack = tracks[selected_track]
	var affected: bool = false
	for clip: GASEditorClip in track.clips:
		if clip.end_frame() > selection_start and clip.timeline_start < selection_end:
			affected = true
			break
	if not affected:
		return false
	push_undo("Split Delete")
	var output: Array[GASEditorClip] = []
	for clip: GASEditorClip in track.clips:
		if clip.end_frame() <= selection_start or clip.timeline_start >= selection_end:
			output.append(clip)
			continue
		var overlap_start: int = maxi(selection_start, clip.timeline_start)
		var overlap_end: int = mini(selection_end, clip.end_frame())
		if overlap_start > clip.timeline_start:
			var left: GASEditorClip = clip.duplicate_shallow()
			left.source_end_frame = clip.source_start_frame + (overlap_start - clip.timeline_start)
			if left.frame_count() > 0:
				output.append(left)
		if overlap_end < clip.end_frame():
			var right: GASEditorClip = clip.duplicate_with_new_id(_allocate_clip_id())
			right.source_start_frame = clip.source_start_frame + (overlap_end - clip.timeline_start)
			right.timeline_start = overlap_end
			if right.frame_count() > 0:
				output.append(right)
	track.clips = output
	selected_clip_ids = PackedInt32Array()
	cursor_frame = selection_start
	clear_time_selection()
	dirty = true
	return true


func split_cut_selection() -> bool:
	if not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return false
	copy_selection()
	return split_delete_selection()


func add_marker(frame: int, name: String = "Marker") -> void:
	push_undo("Add Marker")
	markers.append({"frame": maxi(0, frame), "name": name})
	markers.sort_custom(_sort_markers)
	dirty = true


func add_markers_batch(frames: PackedInt32Array, prefix: String = "Marker") -> void:
	if frames.is_empty():
		return
	push_undo("Add %s Markers" % prefix)
	var serial: int = 1
	for frame: int in frames:
		markers.append({"frame": maxi(0, frame), "name": "%s %d" % [prefix, serial]})
		serial += 1
	markers.sort_custom(_sort_markers)
	dirty = true


func snap_frame(candidate_frame: int, track_index: int, exclude_clip_ids: PackedInt32Array, tolerance_frames: int, include_zero_crossing: bool) -> int:
	var candidate: int = maxi(0, candidate_frame)
	var best: int = candidate
	var best_distance: int = tolerance_frames + 1
	var targets: PackedInt32Array = PackedInt32Array()
	if grid_snap_mode == "Beats" or grid_snap_mode == "Bars":
		var beat_frames: float = float(sample_rate) * 60.0 / maxf(1.0, project_bpm)
		var grid_frames: float = beat_frames * float(maxi(1, time_signature_numerator)) if grid_snap_mode == "Bars" else beat_frames
		var beat_target: int = maxi(0, int(round(float(candidate) / grid_frames) * grid_frames))
		targets.append(beat_target)
	elif grid_snap_mode == "Milliseconds":
		var ms_frames: float = float(sample_rate) / 1000.0
		targets.append(maxi(0, int(round(float(candidate) / ms_frames) * ms_frames)))
	elif grid_snap_mode == "Frames":
		var video_frame_samples: float = float(sample_rate) / maxf(1.0, frame_rate)
		targets.append(maxi(0, int(round(float(candidate) / video_frame_samples) * video_frame_samples)))
	targets.append(cursor_frame)
	if has_selection():
		targets.append(selection_start)
		targets.append(selection_end)
	for marker: Dictionary in markers:
		targets.append(int(marker.get("frame", 0)))
	if track_index >= 0 and track_index < tracks.size():
		for clip: GASEditorClip in tracks[track_index].clips:
			if exclude_clip_ids.has(clip.clip_id):
				continue
			targets.append(clip.timeline_start)
			targets.append(clip.end_frame())
	for target: int in targets:
		var distance: int = abs(target - candidate)
		if distance < best_distance:
			best_distance = distance
			best = target
	if include_zero_crossing and track_index >= 0 and track_index < tracks.size():
		var zero: int = nearest_zero_crossing_on_track(track_index, candidate, tolerance_frames)
		var zero_distance: int = abs(zero - candidate)
		if zero_distance < best_distance:
			best = zero
	return best


func nearest_zero_crossing(frame: int, search_radius: int = 2048) -> int:
	return zero_crossing(frame, 0, search_radius, true)


func zero_crossing(frame: int, direction: int = 0, search_radius: int = 2048, stereo_aware: bool = true) -> int:
	if not _valid_selected_track():
		return maxi(0, frame)
	var track: GASEditorTrack = tracks[selected_track]
	var best: int = maxi(0, frame)
	var best_distance: int = search_radius + 1
	for clip: GASEditorClip in track.clips:
		if clip.pcm == null or frame < clip.timeline_start - search_radius or frame >= clip.end_frame() + search_radius:
			continue
		var local_center: int = clampi(frame - clip.timeline_start + clip.source_start_frame, clip.source_start_frame + 1, clip.source_end() - 1)
		var local_min: int = maxi(clip.source_start_frame + 1, local_center - search_radius)
		var local_max: int = mini(clip.source_end() - 1, local_center + search_radius)
		for source_index: int in range(local_min, local_max + 1):
			var global_candidate: int = clip.timeline_start + source_index - clip.source_start_frame
			if direction < 0 and global_candidate >= frame:
				continue
			if direction > 0 and global_candidate <= frame:
				continue
			var left_cross: bool = (clip.pcm.left[source_index - 1] <= 0.0 and clip.pcm.left[source_index] >= 0.0) or (clip.pcm.left[source_index - 1] >= 0.0 and clip.pcm.left[source_index] <= 0.0)
			var right_cross: bool = true
			if stereo_aware and clip.pcm.is_stereo():
				right_cross = (clip.pcm.right[source_index - 1] <= 0.0 and clip.pcm.right[source_index] >= 0.0) or (clip.pcm.right[source_index - 1] >= 0.0 and clip.pcm.right[source_index] <= 0.0)
			if not left_cross or not right_cross:
				continue
			var distance: int = abs(global_candidate - frame)
			if distance < best_distance:
				best_distance = distance
				best = global_candidate
	return best


func snap_selection_endpoints_to_zero_crossings(search_radius: int = 2048, stereo_aware: bool = true) -> bool:
	if not has_selection():
		return false
	var start_snapped: int = zero_crossing(selection_start, 0, search_radius, stereo_aware)
	var end_snapped: int = zero_crossing(selection_end, 0, search_radius, stereo_aware)
	if end_snapped < start_snapped:
		var temp: int = start_snapped
		start_snapped = end_snapped
		end_snapped = temp
	selection_start = start_snapped
	selection_end = end_snapped
	cursor_frame = selection_start
	return true


func nearest_zero_crossing_on_track(track_index: int, frame: int, search_radius: int = 2048) -> int:
	if track_index < 0 or track_index >= tracks.size():
		return frame
	var track: GASEditorTrack = tracks[track_index]
	if track.clips.is_empty():
		return frame
	# Zero-cross snapping only needs a local source neighborhood. Rendering an
	# entire track here would make edge trimming scale with project duration.
	var radius: int = clampi(search_radius, 1, 4096)
	var center: int = maxi(0, frame)
	var best_frame: int = center
	var best_score: float = INF
	for clip: GASEditorClip in track.clips:
		if clip.pcm == null or clip.frame_count() < 2:
			continue
		var global_start: int = maxi(clip.timeline_start + 1, center - radius)
		var global_end: int = mini(clip.end_frame() - 1, center + radius)
		if global_end < global_start:
			continue
		var source_start: int = clip.source_start_frame
		var stereo: bool = clip.pcm.is_stereo()
		for global_frame: int in range(global_start, global_end + 1):
			var local_frame: int = global_frame - clip.timeline_start
			var source_index: int = source_start + local_frame
			var previous_index: int = source_index - 1
			var a: float = clip.pcm.left[previous_index]
			var b: float = clip.pcm.left[source_index]
			if stereo:
				a = (a + clip.pcm.right[previous_index]) * 0.5
				b = (b + clip.pcm.right[source_index]) * 0.5
			if (a <= 0.0 and b >= 0.0) or (a >= 0.0 and b <= 0.0):
				var score: float = absf(a) + absf(b) + float(abs(global_frame - center)) * 0.000001
				if score < best_score:
					best_score = score
					best_frame = global_frame
	return best_frame


func split_at_cursor() -> void:
	split_selected_at_cursor()


func trim_to_selection() -> void:
	if not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return
	push_undo("Trim")
	var trimmed: GASPCMData = rendered.slice_frames(selection_start, mini(selection_end, rendered.frame_count()))
	_replace_track_with_pcm(selected_track, trimmed, selection_start, "Trimmed")
	cursor_frame = selection_start
	selection_end = selection_start + trimmed.frame_count()
	dirty = true


func silence_selection() -> void:
	if not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return
	push_undo("Silence")
	var silenced: GASPCMData = rendered.with_silence(selection_start, mini(selection_end, rendered.frame_count()))
	_replace_track_with_pcm(selected_track, silenced, 0, "Silenced")
	dirty = true


func delete_selection() -> void:
	if not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return
	var empty: GASPCMData = GASPCMData.new()
	empty.sample_rate = sample_rate
	empty.channels = 1
	push_undo("Delete")
	_replace_time_region_with_pcm(selected_track, selection_start, selection_end, empty, "Deleted")
	cursor_frame = selection_start
	selection_end = selection_start
	dirty = true


func copy_selection() -> void:
	clip_clipboard.clear()
	if not _valid_selected_track() or not has_selection():
		return
	var rendered: GASPCMData = render_track(selected_track)
	if rendered == null:
		return
	clipboard = rendered.slice_frames(selection_start, mini(selection_end, rendered.frame_count()))


func cut_selection() -> void:
	copy_selection()
	delete_selection()


func paste_at_cursor() -> void:
	if clipboard == null or clipboard.frame_count() == 0:
		return
	if selected_track < 0 or not is_track_editable(selected_track):
		add_track("Pasted Audio")
	if not _valid_selected_track() or not is_track_editable(selected_track):
		return
	push_undo("Paste")
	_replace_time_region_with_pcm(selected_track, cursor_frame, cursor_frame, clipboard.duplicate_pcm(), "Pasted")
	selection_start = cursor_frame
	selection_end = cursor_frame + clipboard.frame_count()
	cursor_frame = selection_end
	dirty = true


func render_track(track_index: int) -> GASPCMData:
	return _render_track_internal(track_index, true)


func render_track_with_progress(track_index: int, progress_callback: Callable = Callable()) -> GASPCMData:
	return _render_track_internal(track_index, true, progress_callback)


func render_track_dry(track_index: int) -> GASPCMData:
	return _render_track_internal(track_index, false)


func _render_track_internal(track_index: int, include_effects: bool, progress_callback: Callable = Callable()) -> GASPCMData:
	if track_index < 0 or track_index >= tracks.size():
		return null
	var track: GASEditorTrack = tracks[track_index]
	var total_frames: int = track.end_frame()
	if include_effects:
		for tail_clip: GASEditorClip in track.clips:
			if tail_clip.pcm != null and not tail_clip.effect_stack.is_empty():
				total_frames = maxi(total_frames, tail_clip.timeline_start + tail_clip.frame_count() + EffectEngine.stack_tail_frames(tail_clip.effect_stack, sample_rate))
	var report_progress: bool = progress_callback.is_valid()
	if report_progress:
		progress_callback.call(0.0)
	var estimated_clip_frames: int = 0
	for progress_clip: GASEditorClip in track.clips:
		if progress_clip.pcm != null and not progress_clip.muted:
			estimated_clip_frames += maxi(0, progress_clip.frame_count())
	var processed_clip_frames: int = 0
	var stereo: bool = absf(track.pan) > 0.0001
	if not stereo:
		for clip: GASEditorClip in track.clips:
			if clip.pcm != null and (clip.pcm.is_stereo() or absf(clip.pan) > 0.0001 or EffectEngine.stack_outputs_stereo(clip.effect_stack)):
				stereo = true
				break
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = 2 if stereo else 1
	out.left.resize(total_frames)
	if stereo:
		out.right.resize(total_frames)
	for clip: GASEditorClip in track.clips:
		if clip.pcm == null or clip.muted:
			continue
		var clip_source: GASPCMData = null
		var source_offset: int = clip.source_start_frame
		if include_effects and not clip.effect_stack.is_empty():
			var raw_clip: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
			clip_source = EffectEngine.process_stack(raw_clip, clip.effect_stack)
			source_offset = 0
		else:
			clip_source = clip.pcm
		var clip_gain: float = db_to_linear(clip.gain_db + track.gain_db)
		var pan_value: float = clampf(clip.pan + track.pan, -1.0, 1.0)
		var left_pan: float = 1.0 if pan_value <= 0.0 else 1.0 - pan_value
		var right_pan: float = 1.0 if pan_value >= 0.0 else 1.0 + pan_value
		var clip_count: int = clip_source.frame_count() if include_effects and not clip.effect_stack.is_empty() else mini(clip.frame_count(), clip_source.frame_count() - source_offset)
		for i: int in range(maxi(0, clip_count)):
			var source_i: int = source_offset + i
			var dst: int = clip.timeline_start + i
			if dst >= 0 and dst < total_frames:
				var raw_left: float = clip_source.left[source_i]
				var raw_right: float = clip_source.right[source_i] if clip_source.is_stereo() else raw_left
				var fade_gain: float = _clip_fade_gain(clip, i, clip_count)
				out.left[dst] += raw_left * clip_gain * left_pan * fade_gain
				if stereo:
					out.right[dst] += raw_right * clip_gain * right_pan * fade_gain
			if report_progress and (i & 16383) == 0:
				var clip_fraction: float = float(processed_clip_frames + i) / float(maxi(1, estimated_clip_frames))
				progress_callback.call(clampf(clip_fraction, 0.0, 1.0) * 0.72)
		processed_clip_frames += maxi(0, clip_count)
	if report_progress:
		progress_callback.call(0.72)
	if include_effects and not track.effect_stack.is_empty():
		var has_fx_automation: bool = false
		for effect_index: int in range(track.effect_stack.size()):
			if AutomationEngine.has_effect_automation(track.automation_lanes, effect_index):
				has_fx_automation = true
				break
		if not has_fx_automation:
			out = EffectEngine.process_stack(out, track.effect_stack)
		else:
			for effect_index: int in range(track.effect_stack.size()):
				var dry_before_effect: GASPCMData = out
				var processed_effect: GASPCMData = AutomationEngine.process_effect_parameter_automation(out, track.effect_stack[effect_index], effect_index, track.automation_lanes, 0)
				var rack_wet_points: Array[Dictionary] = AutomationEngine.lane_points(track.automation_lanes, "fx:%d:wet" % effect_index)
				out = AutomationEngine.apply_wet_automation(dry_before_effect, processed_effect, rack_wet_points, 0) if not rack_wet_points.is_empty() else processed_effect
	if report_progress:
		progress_callback.call(0.82)
	if not track.automation_lanes.is_empty():
		out = AutomationEngine.apply_track_automation(out, track.automation_lanes, 0)
	if report_progress:
		progress_callback.call(0.88)
	if track.channel_mode == GASEditorTrack.CHANNEL_MONO and out.is_stereo():
		out = out.force_mono()
	elif track.channel_mode == GASEditorTrack.CHANNEL_STEREO and not out.is_stereo():
		out.channels = 2
		out.right = out.left.duplicate()
	var clamp_count: int = out.frame_count()
	for i: int in range(clamp_count):
		out.left[i] = clampf(out.left[i], -1.0, 1.0)
		if out.is_stereo():
			out.right[i] = clampf(out.right[i], -1.0, 1.0)
		if report_progress and (i & 16383) == 0:
			progress_callback.call(0.88 + 0.12 * float(i) / float(maxi(1, clamp_count)))
	if report_progress:
		progress_callback.call(1.0)
	return out


func _clip_fade_curve(u: float, curve: int) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	match curve:
		1:
			return log(1.0 + 9.0 * t) / log(10.0)
		2:
			return t * t
		3:
			return t * t * (3.0 - 2.0 * t)
		4:
			return sin(t * PI * 0.5)
		_:
			return t


func _clip_fade_gain(clip: GASEditorClip, local_frame: int, total_frames: int) -> float:
	var gain: float = 1.0
	if clip.fade_in_samples > 0 and local_frame < clip.fade_in_samples:
		gain *= _clip_fade_curve(float(local_frame) / float(maxi(1, clip.fade_in_samples)), clip.fade_curve)
	if clip.fade_out_samples > 0 and local_frame >= total_frames - clip.fade_out_samples:
		var remaining: int = maxi(0, total_frames - 1 - local_frame)
		gain *= _clip_fade_curve(float(remaining) / float(maxi(1, clip.fade_out_samples)), clip.fade_curve)
	return gain


func crossfade_selected_clips(duration_ms: float = 50.0, curve: int = 4) -> bool:
	if selected_clip_ids.size() != 2:
		return false
	var first: GASEditorClip = find_clip(selected_clip_ids[0])
	var second: GASEditorClip = find_clip(selected_clip_ids[1])
	if first == null or second == null:
		return false
	var first_location: Vector2i = find_clip_location(first.clip_id)
	var second_location: Vector2i = find_clip_location(second.clip_id)
	if first_location.x < 0 or second_location.x < 0 or not is_track_editable(first_location.x) or not is_track_editable(second_location.x):
		return false
	if first_location.x != second_location.x:
		return false
	var earlier: GASEditorClip = first if first.timeline_start <= second.timeline_start else second
	var later: GASEditorClip = second if earlier == first else first
	var later_location: Vector2i = second_location if later == second else first_location
	var requested: int = maxi(1, int(round(maxf(1.0, duration_ms) * float(sample_rate) / 1000.0)))
	var overlap: int = earlier.end_frame() - later.timeline_start
	push_undo("Crossfade Clips")
	if overlap <= 0:
		var available: int = mini(requested, mini(earlier.frame_count(), later.frame_count()))
		later.timeline_start = maxi(0, earlier.end_frame() - available)
		overlap = earlier.end_frame() - later.timeline_start
		_sort_track_clips(later_location.x)
	overlap = mini(overlap, mini(earlier.frame_count(), later.frame_count()))
	if overlap <= 0:
		return false
	earlier.fade_out_samples = overlap
	later.fade_in_samples = overlap
	earlier.fade_curve = clampi(curve, 0, 4)
	later.fade_curve = clampi(curve, 0, 4)
	dirty = true
	return true


func mixdown_without_master() -> GASPCMData:
	return _mixdown_internal(false)


func mixdown() -> GASPCMData:
	return _mixdown_internal(true)


func mixdown_with_progress(progress_callback: Callable = Callable()) -> GASPCMData:
	return _mixdown_internal(true, progress_callback)


func _forward_progress(value: float, callback: Callable, base: float, span: float) -> void:
	if callback.is_valid():
		callback.call(base + clampf(value, 0.0, 1.0) * span)


func _mixdown_internal(include_master: bool, progress_callback: Callable = Callable()) -> GASPCMData:
	if tracks.is_empty():
		return null
	var report_progress: bool = progress_callback.is_valid()
	if report_progress:
		progress_callback.call(0.0)
	var rendered_tracks: Array[GASPCMData] = []
	var any_stereo: bool = false
	var has_solo: bool = false
	var total_frames: int = project_end_frame()
	for track: GASEditorTrack in tracks:
		if track.solo:
			has_solo = true
			break
	var active_track_indices: PackedInt32Array = PackedInt32Array()
	for track_index: int in range(tracks.size()):
		var active_track: GASEditorTrack = tracks[track_index]
		if not active_track.mute and (not has_solo or active_track.solo):
			active_track_indices.append(track_index)
	var active_track_count: int = active_track_indices.size()
	for active_index: int in range(active_track_count):
		var track_index: int = active_track_indices[active_index]
		var track_span: float = 0.64 / float(maxi(1, active_track_count))
		var track_base: float = float(active_index) * track_span
		var track_progress: Callable = Callable(self, "_forward_progress").bind(progress_callback, track_base, track_span) if report_progress else Callable()
		var rendered: GASPCMData = _render_track_internal(track_index, true, track_progress)
		rendered_tracks.append(rendered)
		if rendered != null:
			total_frames = maxi(total_frames, rendered.frame_count())
			if rendered.is_stereo():
				any_stereo = true
	if total_frames <= 0:
		return null
	if report_progress:
		progress_callback.call(0.64)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = 2 if any_stereo else 1
	out.left.resize(total_frames)
	if any_stereo:
		out.right.resize(total_frames)
	var total_mix_frames: int = 0
	for rendered_count_pcm: GASPCMData in rendered_tracks:
		if rendered_count_pcm != null:
			total_mix_frames += mini(total_frames, rendered_count_pcm.frame_count())
	var mixed_frames: int = 0
	for rendered: GASPCMData in rendered_tracks:
		if rendered == null:
			continue
		var count: int = mini(total_frames, rendered.frame_count())
		var rendered_stereo: bool = rendered.is_stereo()
		var rendered_left: PackedFloat32Array = rendered.left
		var rendered_right: PackedFloat32Array = rendered.right
		for i: int in range(count):
			var left_value: float = rendered_left[i]
			var right_value: float = rendered_right[i] if rendered_stereo else left_value
			out.left[i] += left_value
			if any_stereo:
				out.right[i] += right_value
			if report_progress and (i & 16383) == 0:
				progress_callback.call(0.64 + 0.18 * float(mixed_frames + i) / float(maxi(1, total_mix_frames)))
		mixed_frames += count
	if report_progress:
		progress_callback.call(0.82)
	if include_master:
		if not master_effect_stack.is_empty():
			out = EffectEngine.process_stack(out, master_effect_stack)
		var master_gain: float = db_to_linear(master_gain_db)
		var master_count: int = out.frame_count()
		for i: int in range(master_count):
			out.left[i] *= master_gain
			if out.is_stereo():
				out.right[i] *= master_gain
			if report_progress and (i & 16383) == 0:
				progress_callback.call(0.82 + 0.08 * float(i) / float(maxi(1, master_count)))
		if master_limiter_enabled:
			var limiter: GASEffectData = EffectEngine.create_default("Limiter")
			limiter.params["ceiling_db"] = master_limiter_ceiling_db
			limiter.params["input_gain_db"] = 0.0
			out = EffectEngine.process(out, limiter)
	if report_progress:
		progress_callback.call(0.92)
	var clamp_count: int = out.frame_count()
	for i: int in range(clamp_count):
		out.left[i] = clampf(out.left[i], -1.0, 1.0)
		if out.is_stereo():
			out.right[i] = clampf(out.right[i], -1.0, 1.0)
		if report_progress and (i & 16383) == 0:
			progress_callback.call(0.92 + 0.08 * float(i) / float(maxi(1, clamp_count)))
	if report_progress:
		progress_callback.call(1.0)
	return out


func add_effect_to_master(effect: GASEffectData) -> bool:
	if effect == null or not EffectEngine.is_stack_safe(effect.effect_type):
		return false
	push_undo("Add Master Effect")
	master_effect_stack.append(effect.duplicate_effect())
	dirty = true
	return true


func replace_master_effect_stack(stack: Array[GASEffectData], undo_label: String) -> bool:
	push_undo(undo_label)
	master_effect_stack.clear()
	for effect: GASEffectData in stack:
		master_effect_stack.append(effect.duplicate_effect())
	dirty = true
	return true


func replace_track_region_with_pcm(track_index: int, start_frame: int, end_frame: int, replacement: GASPCMData, clip_name: String, undo_label: String) -> bool:
	if track_index < 0 or track_index >= tracks.size() or replacement == null or not is_track_editable(track_index):
		return false
	push_undo(undo_label)
	_replace_time_region_with_pcm(track_index, maxi(0, start_frame), maxi(start_frame, end_frame), replacement, clip_name)
	selected_track = track_index
	selected_track_indices = PackedInt32Array([selected_track])
	cursor_frame = maxi(0, start_frame)
	selection_start = cursor_frame
	selection_end = cursor_frame + replacement.frame_count()
	dirty = true
	return true


func add_effect_to_selected_clips(effect: GASEffectData) -> bool:
	if effect == null or selected_clip_ids.is_empty() or not EffectEngine.is_stack_safe(effect.effect_type):
		return false
	push_undo("Add Clip Effect")
	var changed: bool = false
	for clip_id: int in selected_clip_ids:
		var clip: GASEditorClip = find_clip(clip_id)
		var location: Vector2i = find_clip_location(clip_id)
		if clip == null or location.x < 0 or not is_track_editable(location.x):
			continue
		clip.effect_stack.append(effect.duplicate_effect())
		changed = true
	dirty = dirty or changed
	return changed


func add_effect_to_selected_track(effect: GASEffectData) -> bool:
	if effect == null or not _valid_selected_track() or not is_track_editable(selected_track) or not EffectEngine.is_stack_safe(effect.effect_type):
		return false
	push_undo("Add Track Effect")
	tracks[selected_track].effect_stack.append(effect.duplicate_effect())
	dirty = true
	return true


func replace_clip_effect_stack(clip_ids: PackedInt32Array, stack: Array[GASEffectData], undo_label: String) -> bool:
	if clip_ids.is_empty():
		return false
	push_undo(undo_label)
	var changed: bool = false
	for clip_id: int in clip_ids:
		var clip: GASEditorClip = find_clip(clip_id)
		var location: Vector2i = find_clip_location(clip_id)
		if clip == null or location.x < 0 or not is_track_editable(location.x):
			continue
		clip.effect_stack.clear()
		for effect: GASEffectData in stack:
			clip.effect_stack.append(effect.duplicate_effect())
		changed = true
	dirty = dirty or changed
	return changed


func replace_track_effect_stack(track_index: int, stack: Array[GASEffectData], undo_label: String) -> bool:
	if track_index < 0 or track_index >= tracks.size() or not is_track_editable(track_index):
		return false
	push_undo(undo_label)
	tracks[track_index].effect_stack.clear()
	for effect: GASEffectData in stack:
		tracks[track_index].effect_stack.append(effect.duplicate_effect())
	dirty = true
	return true


func preview_selected_clip_pcm() -> GASPCMData:
	if selected_clip_ids.is_empty():
		return null
	var clip: GASEditorClip = find_clip(selected_clip_ids[0])
	if clip == null or clip.pcm == null:
		return null
	var raw: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
	if clip.effect_stack.is_empty():
		return raw
	return EffectEngine.process_stack(raw, clip.effect_stack)


func apply_effect_to_selected_clips_destructive(effect: GASEffectData) -> bool:
	if effect == null or selected_clip_ids.is_empty():
		return false
	push_undo("Apply %s" % effect.effect_type)
	var changed: bool = false
	for clip_id: int in selected_clip_ids:
		var clip: GASEditorClip = find_clip(clip_id)
		var location: Vector2i = find_clip_location(clip_id)
		if clip == null or clip.pcm == null or location.x < 0 or not is_track_editable(location.x):
			continue
		var raw: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
		var processed: GASPCMData = EffectEngine.process(raw, effect)
		if processed == null:
			continue
		clip.pcm = processed
		clip.source_start_frame = 0
		clip.source_end_frame = processed.frame_count()
		clip.source_path = "effect://" + effect.effect_type
		clip.rebuild_cache()
		changed = true
	dirty = dirty or changed
	return changed


func apply_effect_to_track_selection_destructive(effect: GASEffectData) -> bool:
	if effect == null or not _valid_selected_track() or not is_track_editable(selected_track) or not has_selection():
		return false
	var rendered: GASPCMData = render_track_dry(selected_track)
	if rendered == null:
		return false
	var start_frame: int = clampi(selection_start, 0, rendered.frame_count())
	var end_frame: int = clampi(selection_end, start_frame, rendered.frame_count())
	if end_frame <= start_frame:
		return false
	var region: GASPCMData = rendered.slice_frames(start_frame, end_frame)
	var processed_region: GASPCMData = EffectEngine.process(region, effect)
	if processed_region == null:
		return false
	push_undo("Apply %s" % effect.effect_type)
	_replace_time_region_with_pcm(selected_track, start_frame, end_frame, processed_region, effect.effect_type)
	selection_start = start_frame
	selection_end = start_frame + processed_region.frame_count()
	cursor_frame = selection_start
	dirty = true
	return true


func apply_effect_to_selected_tracks_destructive(effect: GASEffectData) -> bool:
	if effect == null or not has_selection():
		return false
	var targets: PackedInt32Array = selected_tracks()
	if targets.is_empty():
		return false
	# Sync groups apply the same destructive operation to every editable member.
	# This intentionally applies to duration-changing effects too; companion tracks
	# that contain no audio in the selected region still receive a single ripple.
	var sync_groups: Dictionary = {}
	for target_index: int in targets:
		if target_index >= 0 and target_index < tracks.size():
			var group_id: int = tracks[target_index].sync_group
			if group_id > 0:
				sync_groups[group_id] = true
	if not sync_groups.is_empty():
		for index: int in range(tracks.size()):
			if sync_groups.has(tracks[index].sync_group) and not targets.has(index):
				targets.append(index)
	var rendered: Array[Dictionary] = []
	var processed_tracks: Dictionary = {}
	var group_deltas: Dictionary = {}
	var group_end_frames: Dictionary = {}
	for index: int in targets:
		if not is_track_editable(index):
			continue
		var dry: GASPCMData = render_track_dry(index)
		if dry == null:
			continue
		var start_frame: int = clampi(selection_start, 0, dry.frame_count())
		var end_frame: int = clampi(selection_end, start_frame, dry.frame_count())
		if end_frame <= start_frame:
			continue
		var processed: GASPCMData = EffectEngine.process(dry.slice_frames(start_frame, end_frame), effect)
		if processed == null:
			continue
		var delta: int = processed.frame_count() - (end_frame - start_frame)
		var group_id: int = tracks[index].sync_group
		rendered.append({"track": index, "start": start_frame, "end": end_frame, "pcm": processed, "delta": delta, "group": group_id})
		processed_tracks[index] = true
		if group_id > 0 and not group_deltas.has(group_id):
			group_deltas[group_id] = delta
			group_end_frames[group_id] = end_frame
	if rendered.is_empty():
		return false
	push_undo("Apply %s to Tracks" % effect.effect_type)
	for item: Dictionary in rendered:
		_replace_time_region_with_pcm(int(item["track"]), int(item["start"]), int(item["end"]), item["pcm"] as GASPCMData, effect.effect_type, false)
	# A processed track already ripples its own post-selection clips. Only move
	# unprocessed members of each sync group here, exactly once.
	for group_key: Variant in group_deltas.keys():
		var group_id: int = int(group_key)
		var timeline_delta: int = int(group_deltas[group_id])
		if timeline_delta == 0:
			continue
		var end_frame: int = int(group_end_frames[group_id])
		for other_index: int in range(tracks.size()):
			if processed_tracks.has(other_index):
				continue
			var other_track: GASEditorTrack = tracks[other_index]
			if other_track.sync_group != group_id or other_track.locked or other_track.reference_read_only:
				continue
			for other_clip: GASEditorClip in other_track.clips:
				if other_clip.timeline_start >= end_frame:
					other_clip.timeline_start = maxi(0, other_clip.timeline_start + timeline_delta)
			_sort_track_clips(other_index)
	dirty = true
	return true


func _replace_time_region_with_pcm(track_index: int, start_frame: int, end_frame: int, replacement: GASPCMData, clip_name: String, ripple_sync_group: bool = true) -> void:
	var track: GASEditorTrack = tracks[track_index]
	var rebuilt: Array[GASEditorClip] = []
	var original_length: int = maxi(0, end_frame - start_frame)
	var replacement_length: int = replacement.frame_count()
	var timeline_delta: int = replacement_length - original_length
	for clip: GASEditorClip in track.clips:
		if clip.end_frame() <= start_frame:
			rebuilt.append(clip)
			continue
		if clip.timeline_start >= end_frame:
			# Duration-changing effects ripple everything after the processed region.
			clip.timeline_start = maxi(0, clip.timeline_start + timeline_delta)
			rebuilt.append(clip)
			continue
		if clip.timeline_start < start_frame:
			var left_piece: GASEditorClip = clip.duplicate_with_new_id(_allocate_clip_id())
			left_piece.source_end_frame = clip.source_start_frame + (start_frame - clip.timeline_start)
			rebuilt.append(left_piece)
		if clip.end_frame() > end_frame:
			var right_piece: GASEditorClip = clip.duplicate_with_new_id(_allocate_clip_id())
			right_piece.source_start_frame = clip.source_start_frame + (end_frame - clip.timeline_start)
			right_piece.timeline_start = start_frame + replacement_length
			rebuilt.append(right_piece)
	if ripple_sync_group and timeline_delta != 0 and track.sync_group > 0:
		for other_index: int in range(tracks.size()):
			if other_index == track_index:
				continue
			var other_track: GASEditorTrack = tracks[other_index]
			if other_track.sync_group != track.sync_group or other_track.locked or other_track.reference_read_only:
				continue
			for other_clip: GASEditorClip in other_track.clips:
				if other_clip.timeline_start >= end_frame:
					other_clip.timeline_start = maxi(0, other_clip.timeline_start + timeline_delta)
			_sort_track_clips(other_index)
	var new_clip: GASEditorClip = _make_clip(replacement, clip_name, "effect://" + clip_name, start_frame)
	rebuilt.append(new_clip)
	track.clips = rebuilt
	_sort_track_clips(track_index)
	selected_clip_ids = PackedInt32Array([new_clip.clip_id])


func push_undo(label: String) -> void:
	_undo_stack.append({"label": label, "state": _snapshot()})
	if _undo_stack.size() > MAX_HISTORY:
		_undo_stack.pop_front()
	_redo_stack.clear()


func undo() -> String:
	if _undo_stack.is_empty():
		return ""
	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append({"label": str(entry["label"]), "state": _snapshot()})
	_restore(entry["state"] as Dictionary)
	return str(entry["label"])


func redo() -> String:
	if _redo_stack.is_empty():
		return ""
	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append({"label": str(entry["label"]), "state": _snapshot()})
	_restore(entry["state"] as Dictionary)
	return str(entry["label"])


func _snapshot() -> Dictionary:
	var snapshot_tracks: Array[GASEditorTrack] = []
	for track: GASEditorTrack in tracks:
		snapshot_tracks.append(track.duplicate_shallow())
	return {
		"tracks": snapshot_tracks,
		"selected_track": selected_track,
		"selected_track_indices": selected_track_indices.duplicate(),
		"selected_clip_ids": selected_clip_ids.duplicate(),
		"cursor_frame": cursor_frame,
		"selection_start": selection_start,
		"selection_end": selection_end,
		"markers": markers.duplicate(true),
		"master_gain_db": master_gain_db,
		"master_effect_stack": _duplicate_effect_stack(master_effect_stack),
		"master_limiter_enabled": master_limiter_enabled,
		"master_limiter_ceiling_db": master_limiter_ceiling_db,
		"project_bpm": project_bpm,
		"time_signature_numerator": time_signature_numerator,
		"time_signature_denominator": time_signature_denominator,
		"playback_speed": playback_speed,
		"metadata": metadata.duplicate(true),
		"loop_start_frame": loop_start_frame,
		"loop_end_frame": loop_end_frame,
		"loop_mode": loop_mode,
		"grid_snap_mode": grid_snap_mode,
		"frame_rate": frame_rate,
		"shortcut_overrides": shortcut_overrides.duplicate(true),
		"accessibility_settings": accessibility_settings.duplicate(true),
		"dirty": dirty,
		"next_clip_id": _next_clip_id,
	}


func _restore(state: Dictionary) -> void:
	tracks.clear()
	var restored_tracks: Array = state.get("tracks", []) as Array
	for item: Variant in restored_tracks:
		var track: GASEditorTrack = item as GASEditorTrack
		if track != null:
			tracks.append(track.duplicate_shallow())
	selected_track = int(state.get("selected_track", -1))
	var selected_tracks_value: Variant = state.get("selected_track_indices", PackedInt32Array([selected_track]) if selected_track >= 0 else PackedInt32Array())
	selected_track_indices = selected_tracks_value as PackedInt32Array if selected_tracks_value is PackedInt32Array else PackedInt32Array([selected_track]) if selected_track >= 0 else PackedInt32Array()
	sanitize_track_selection()
	var selected_value: Variant = state.get("selected_clip_ids", PackedInt32Array())
	selected_clip_ids = selected_value as PackedInt32Array if selected_value is PackedInt32Array else PackedInt32Array()
	cursor_frame = int(state.get("cursor_frame", 0))
	selection_start = int(state.get("selection_start", 0))
	selection_end = int(state.get("selection_end", 0))
	markers.clear()
	var marker_value: Variant = state.get("markers", [])
	if marker_value is Array:
		var marker_array: Array = marker_value as Array
		for marker_item: Variant in marker_array:
			if marker_item is Dictionary:
				markers.append((marker_item as Dictionary).duplicate(true))
	master_gain_db = float(state.get("master_gain_db", 0.0))
	master_effect_stack.clear()
	var master_stack_value: Variant = state.get("master_effect_stack", [])
	if master_stack_value is Array:
		var master_array: Array = master_stack_value as Array
		for master_item: Variant in master_array:
			var master_fx: GASEffectData = master_item as GASEffectData
			if master_fx != null:
				master_effect_stack.append(master_fx.duplicate_effect())
	master_limiter_enabled = bool(state.get("master_limiter_enabled", true))
	master_limiter_ceiling_db = float(state.get("master_limiter_ceiling_db", -1.0))
	project_bpm = float(state.get("project_bpm", 120.0))
	time_signature_numerator = maxi(1, int(state.get("time_signature_numerator", 4)))
	time_signature_denominator = maxi(1, int(state.get("time_signature_denominator", 4)))
	playback_speed = clampf(float(state.get("playback_speed", 1.0)), 0.25, 4.0)
	var metadata_value: Variant = state.get("metadata", {})
	metadata = (metadata_value as Dictionary).duplicate(true) if metadata_value is Dictionary else {}
	loop_start_frame = maxi(0, int(state.get("loop_start_frame", 0)))
	loop_end_frame = maxi(loop_start_frame, int(state.get("loop_end_frame", loop_start_frame)))
	loop_mode = int(state.get("loop_mode", AudioStreamWAV.LOOP_DISABLED))
	grid_snap_mode = str(state.get("grid_snap_mode", "Clips"))
	frame_rate = maxf(1.0, float(state.get("frame_rate", 30.0)))
	var shortcut_value: Variant = state.get("shortcut_overrides", {})
	shortcut_overrides = (shortcut_value as Dictionary).duplicate(true) if shortcut_value is Dictionary else {}
	var accessibility_value: Variant = state.get("accessibility_settings", {})
	accessibility_settings = (accessibility_value as Dictionary).duplicate(true) if accessibility_value is Dictionary else {"ui_scale": 1.0, "high_contrast": false, "strong_focus": true, "meter_text": true}
	dirty = bool(state.get("dirty", false))
	_next_clip_id = int(state.get("next_clip_id", 1))
	_prune_clip_selection()


func next_clip_id_for_persistence() -> int:
	return _next_clip_id


func finalize_project_load(next_clip_id: int) -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_next_clip_id = maxi(maxi(1, next_clip_id), _highest_clip_id() + 1)
	_prune_clip_selection()
	dirty = false


func _highest_clip_id() -> int:
	var highest: int = 0
	for track: GASEditorTrack in tracks:
		for clip: GASEditorClip in track.clips:
			highest = maxi(highest, clip.clip_id)
	return highest


func _duplicate_effect_stack(stack: Array[GASEffectData]) -> Array[GASEffectData]:
	var result: Array[GASEffectData] = []
	for effect: GASEffectData in stack:
		result.append(effect.duplicate_effect())
	return result


func _replace_track_with_pcm(track_index: int, pcm: GASPCMData, timeline_start: int, clip_name: String) -> void:
	var track: GASEditorTrack = tracks[track_index]
	track.clips.clear()
	selected_clip_ids = PackedInt32Array()
	if pcm == null or pcm.frame_count() == 0:
		return
	var clip: GASEditorClip = _make_clip(pcm, clip_name, "edited://", timeline_start)
	track.clips.append(clip)
	selected_clip_ids.append(clip.clip_id)


func is_track_editable(track_index: int) -> bool:
	if track_index < 0 or track_index >= tracks.size():
		return false
	var track: GASEditorTrack = tracks[track_index]
	return not track.locked and not track.reference_read_only


func _valid_selected_track() -> bool:
	return selected_track >= 0 and selected_track < tracks.size()


func _make_clip(pcm: GASPCMData, clip_name: String, source_path: String, timeline_start: int, waveform_cache: GASWaveformCache = null) -> GASEditorClip:
	var clip: GASEditorClip = GASEditorClip.new()
	clip.clip_id = _allocate_clip_id()
	clip.name = clip_name
	clip.source_path = source_path
	clip.timeline_start = maxi(0, timeline_start)
	clip.pcm = pcm
	clip.source_start_frame = 0
	clip.source_end_frame = pcm.frame_count()
	clip.offline_frame_count = pcm.frame_count()
	if waveform_cache != null:
		clip.cache = waveform_cache
	else:
		clip.rebuild_cache()
	return clip


func _allocate_clip_id() -> int:
	var result: int = _next_clip_id
	_next_clip_id += 1
	return result


func _remove_selected_clip_id(clip_id: int) -> void:
	var rebuilt: PackedInt32Array = PackedInt32Array()
	for item: int in selected_clip_ids:
		if item != clip_id:
			rebuilt.append(item)
	selected_clip_ids = rebuilt


func _prune_clip_selection() -> void:
	var rebuilt: PackedInt32Array = PackedInt32Array()
	for clip_id: int in selected_clip_ids:
		if find_clip(clip_id) != null:
			rebuilt.append(clip_id)
	selected_clip_ids = rebuilt


func _remove_clip_reference_from_track(track_index: int, clip: GASEditorClip) -> void:
	if track_index < 0 or track_index >= tracks.size():
		return
	var track: GASEditorTrack = tracks[track_index]
	for index: int in range(track.clips.size() - 1, -1, -1):
		if track.clips[index] == clip:
			track.clips.remove_at(index)
			return


func _sort_track_clips(track_index: int) -> void:
	if track_index < 0 or track_index >= tracks.size():
		return
	tracks[track_index].clips.sort_custom(_clip_start_less)


static func _clip_start_less(a: GASEditorClip, b: GASEditorClip) -> bool:
	if a.timeline_start == b.timeline_start:
		return a.clip_id < b.clip_id
	return a.timeline_start < b.timeline_start


static func _sort_markers(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("frame", 0)) < int(b.get("frame", 0))
