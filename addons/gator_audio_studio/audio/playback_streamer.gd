@tool
class_name GASPlaybackStreamer
extends RefCounted

# Low-latency playback mixer. configure() snapshots all hot-path clip state so
# the producer thread never walks mutable editor objects while playback runs.

class ClipMixState:
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	var stereo: bool = false
	var timeline_start: int = 0
	var timeline_end: int = 0
	var source_start: int = 0
	var clip_frames: int = 0
	var left_gain: float = 1.0
	var right_gain: float = 1.0
	var fade_in_samples: int = 0
	var fade_out_samples: int = 0
	var fade_curve: int = 0

var _clips: Array[ClipMixState] = []
var _frame_position: int = 0
var _end_frame: int = 0
var _master_gain: float = 1.0
var _limiter_enabled: bool = false
var _limiter_ceiling: float = 1.0
var _limiter_release: float = 0.0
var _limiter_gain_l: float = 1.0
var _limiter_gain_r: float = 1.0


func configure(model: GASEditorModel, start_frame: int, end_frame: int = -1) -> void:
	_clips.clear()
	_frame_position = maxi(0, start_frame)
	var project_end: int = model.project_end_frame() if model != null else 0
	_end_frame = project_end if end_frame < 0 else mini(project_end, maxi(_frame_position, end_frame))
	_master_gain = 1.0
	_limiter_enabled = false
	_limiter_ceiling = 1.0
	_limiter_release = 0.0
	_limiter_gain_l = 1.0
	_limiter_gain_r = 1.0
	if model == null:
		return
	var has_solo: bool = false
	for track: GASEditorTrack in model.tracks:
		if track.solo:
			has_solo = true
			break
	for track: GASEditorTrack in model.tracks:
		if track.mute or (has_solo and not track.solo):
			continue
		if track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION:
			continue
		var track_gain: float = db_to_linear(track.gain_db)
		for clip: GASEditorClip in track.clips:
			if clip.pcm == null or clip.muted or clip.frame_count() <= 0:
				continue
			var state: ClipMixState = ClipMixState.new()
			# Packed arrays are copy-on-write; retaining the arrays themselves gives
			# playback a stable snapshot without duplicating a song-sized PCM buffer.
			state.left = clip.pcm.left
			state.right = clip.pcm.right
			state.stereo = clip.pcm.is_stereo()
			state.timeline_start = clip.timeline_start
			state.clip_frames = clip.frame_count()
			state.timeline_end = clip.timeline_start + state.clip_frames
			state.source_start = clip.source_start_frame
			var pan_value: float = clampf(track.pan + clip.pan, -1.0, 1.0)
			var gain: float = track_gain * db_to_linear(clip.gain_db)
			state.left_gain = gain * (1.0 if pan_value <= 0.0 else 1.0 - pan_value)
			state.right_gain = gain * (1.0 if pan_value >= 0.0 else 1.0 + pan_value)
			state.fade_in_samples = clip.fade_in_samples
			state.fade_out_samples = clip.fade_out_samples
			state.fade_curve = clip.fade_curve
			_clips.append(state)
	_master_gain = db_to_linear(model.master_gain_db)
	_limiter_enabled = model.master_limiter_enabled
	if _limiter_enabled:
		_limiter_ceiling = db_to_linear(model.master_limiter_ceiling_db)
		var seconds: float = 0.060
		_limiter_release = exp(-1.0 / (seconds * float(maxi(1, model.sample_rate))))


func supports_model(model: GASEditorModel) -> bool:
	if model == null or model.tracks.is_empty():
		return false
	# Stateful/offline FX still use the background render path. The fast path
	# handles clips + gain/pan/fades with no project-length pre-render.
	if not model.master_effect_stack.is_empty():
		return false
	var has_pcm: bool = false
	for track: GASEditorTrack in model.tracks:
		if track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION:
			continue
		if not track.effect_stack.is_empty() or not track.automation_lanes.is_empty():
			return false
		if track.channel_mode != GASEditorTrack.CHANNEL_AUTO:
			return false
		for clip: GASEditorClip in track.clips:
			if clip.muted:
				continue
			if not clip.effect_stack.is_empty():
				return false
			if clip.pcm == null:
				if clip.frame_count() > 0:
					return false
				continue
			has_pcm = true
	return has_pcm


func current_frame() -> int:
	return _frame_position


func end_frame() -> int:
	return _end_frame


func remaining_frames() -> int:
	return maxi(0, _end_frame - _frame_position)


func render_frames(requested_frames: int) -> PackedVector2Array:
	var output: PackedVector2Array = PackedVector2Array()
	if requested_frames <= 0 or _frame_position >= _end_frame:
		return output
	var count: int = mini(requested_frames, _end_frame - _frame_position)
	if count <= 0:
		return output
	var chunk_start: int = _frame_position
	var chunk_end: int = chunk_start + count
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	left.resize(count)
	right.resize(count)

	for clip: ClipMixState in _clips:
		var mix_start: int = maxi(chunk_start, clip.timeline_start)
		var mix_end: int = mini(chunk_end, clip.timeline_end)
		if mix_end <= mix_start:
			continue
		var source_start: int = clip.source_start + (mix_start - clip.timeline_start)
		var destination_start: int = mix_start - chunk_start
		var frames_to_mix: int = mix_end - mix_start
		var has_fades: bool = clip.fade_in_samples > 0 or clip.fade_out_samples > 0
		if clip.stereo:
			for offset: int in range(frames_to_mix):
				var source_index: int = source_start + offset
				if source_index < 0 or source_index >= clip.left.size() or source_index >= clip.right.size():
					continue
				var local_frame: int = (mix_start - clip.timeline_start) + offset
				var fade_gain: float = _clip_fade_gain(clip, local_frame) if has_fades else 1.0
				var destination: int = destination_start + offset
				left[destination] += clip.left[source_index] * clip.left_gain * fade_gain
				right[destination] += clip.right[source_index] * clip.right_gain * fade_gain
		else:
			for offset: int in range(frames_to_mix):
				var source_index: int = source_start + offset
				if source_index < 0 or source_index >= clip.left.size():
					continue
				var local_frame: int = (mix_start - clip.timeline_start) + offset
				var fade_gain: float = _clip_fade_gain(clip, local_frame) if has_fades else 1.0
				var sample_value: float = clip.left[source_index] * fade_gain
				var destination: int = destination_start + offset
				left[destination] += sample_value * clip.left_gain
				right[destination] += sample_value * clip.right_gain

	output.resize(count)
	if _limiter_enabled:
		for index: int in range(count):
			var left_value: float = _limit_sample(left[index] * _master_gain, true)
			var right_value: float = _limit_sample(right[index] * _master_gain, false)
			output[index] = Vector2(clampf(left_value, -1.0, 1.0), clampf(right_value, -1.0, 1.0))
	else:
		for index: int in range(count):
			output[index] = Vector2(
				clampf(left[index] * _master_gain, -1.0, 1.0),
				clampf(right[index] * _master_gain, -1.0, 1.0)
			)
	_frame_position = chunk_end
	return output


func _limit_sample(value: float, left_channel: bool) -> float:
	var current_gain: float = _limiter_gain_l if left_channel else _limiter_gain_r
	var level: float = absf(value)
	var target_gain: float = minf(1.0, _limiter_ceiling / maxf(level, 0.000001))
	if target_gain < current_gain:
		current_gain = target_gain
	else:
		current_gain = target_gain + _limiter_release * (current_gain - target_gain)
	if left_channel:
		_limiter_gain_l = current_gain
	else:
		_limiter_gain_r = current_gain
	return clampf(value * current_gain, -_limiter_ceiling, _limiter_ceiling)


func _clip_fade_gain(clip: ClipMixState, local_frame: int) -> float:
	var gain: float = 1.0
	if clip.fade_in_samples > 0 and local_frame < clip.fade_in_samples:
		gain *= _fade_curve(float(local_frame) / float(maxi(1, clip.fade_in_samples)), clip.fade_curve)
	if clip.fade_out_samples > 0 and local_frame >= clip.clip_frames - clip.fade_out_samples:
		var remaining: int = maxi(0, clip.clip_frames - 1 - local_frame)
		gain *= _fade_curve(float(remaining) / float(maxi(1, clip.fade_out_samples)), clip.fade_curve)
	return gain


func _fade_curve(value: float, curve: int) -> float:
	var t: float = clampf(value, 0.0, 1.0)
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
