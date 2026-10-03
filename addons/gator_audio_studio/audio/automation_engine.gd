@tool
class_name GASAutomationEngine
extends RefCounted

const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")

const CURVE_LINEAR: String = "linear"
const CURVE_SMOOTH: String = "smooth"
const CURVE_EXPONENTIAL: String = "exponential"
const CURVE_STEPPED: String = "stepped"

const PARAM_VOLUME_DB: String = "volume_db"
const PARAM_PAN: String = "pan"
const PARAM_PITCH: String = "pitch_semitones"
const PARAM_LOW_PASS: String = "low_pass_hz"
const PARAM_HIGH_PASS: String = "high_pass_hz"
const PARAM_SEND_DB: String = "send_db"

class EffectAutomationSpec:
	extends RefCounted
	var key: String = ""
	var points: Array[Dictionary] = []
	var fallback: float = 0.0


static func default_value(parameter: String, sample_rate: int = 44100) -> float:
	match parameter:
		PARAM_VOLUME_DB:
			return 0.0
		PARAM_PAN:
			return 0.0
		PARAM_PITCH:
			return 0.0
		PARAM_LOW_PASS:
			return minf(20000.0, float(sample_rate) * 0.45)
		PARAM_HIGH_PASS:
			return 20.0
		PARAM_SEND_DB:
			return -12.0
		_:
			return 0.0


static func value_at(points: Array[Dictionary], frame: int, fallback: float) -> float:
	if points.is_empty():
		return fallback
	if points.size() == 1:
		return float(points[0].get("value", fallback))
	var target: int = maxi(0, frame)
	var first_frame: int = int(points[0].get("frame", 0))
	if target <= first_frame:
		return float(points[0].get("value", fallback))
	for index: int in range(points.size() - 1):
		var a: Dictionary = points[index]
		var b: Dictionary = points[index + 1]
		var a_frame: int = int(a.get("frame", 0))
		var b_frame: int = int(b.get("frame", a_frame))
		if target > b_frame:
			continue
		var a_value: float = float(a.get("value", fallback))
		var b_value: float = float(b.get("value", a_value))
		if b_frame <= a_frame:
			return b_value
		var t: float = clampf(float(target - a_frame) / float(b_frame - a_frame), 0.0, 1.0)
		var curve: String = str(a.get("curve", CURVE_LINEAR))
		match curve:
			CURVE_STEPPED:
				return a_value
			CURVE_SMOOTH:
				t = t * t * (3.0 - 2.0 * t)
			CURVE_EXPONENTIAL:
				if absf(a_value) > 0.000001 and absf(b_value) > 0.000001 and signf(a_value) == signf(b_value):
					return a_value * pow(b_value / a_value, t)
				return lerpf(a_value, b_value, t * t)
			_:
				pass
		return lerpf(a_value, b_value, t)
	return float(points[points.size() - 1].get("value", fallback))


static func sorted_points(points: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for point: Dictionary in points:
		result.append(point.duplicate(true))
	result.sort_custom(_point_less_than)
	return result


static func _point_less_than(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("frame", 0)) < int(b.get("frame", 0))


static func apply_track_automation(pcm: GASPCMData, lanes: Dictionary, timeline_start_frame: int = 0) -> GASPCMData:
	if pcm == null or pcm.frame_count() <= 0 or lanes.is_empty():
		return pcm
	var out: GASPCMData = pcm.duplicate_pcm()
	var volume_points: Array[Dictionary] = _lane_points(lanes, PARAM_VOLUME_DB)
	var pan_points: Array[Dictionary] = _lane_points(lanes, PARAM_PAN)
	var pitch_points: Array[Dictionary] = _lane_points(lanes, PARAM_PITCH)
	var low_points: Array[Dictionary] = _lane_points(lanes, PARAM_LOW_PASS)
	var high_points: Array[Dictionary] = _lane_points(lanes, PARAM_HIGH_PASS)
	if not pan_points.is_empty() and not out.is_stereo():
		out.channels = 2
		out.right = out.left.duplicate()
	if not pitch_points.is_empty():
		out = _apply_pitch(out, pitch_points, timeline_start_frame)
	_apply_gain_pan_filters(out, volume_points, pan_points, low_points, high_points, timeline_start_frame)
	return out


static func _lane_points(lanes: Dictionary, parameter: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = lanes.get(parameter, [])
	if value is Array:
		var array_value: Array = value as Array
		for item: Variant in array_value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	result.sort_custom(_point_less_than)
	return result


static func _apply_pitch(pcm: GASPCMData, points: Array[Dictionary], timeline_start_frame: int) -> GASPCMData:
	var count: int = pcm.frame_count()
	if count <= 1:
		return pcm
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	out.left.resize(count)
	if pcm.is_stereo():
		out.right.resize(count)
	var source_position: float = 0.0
	var source_last: int = count - 1
	for frame: int in range(count):
		var semitones: float = value_at(points, timeline_start_frame + frame, 0.0)
		var ratio: float = pow(2.0, semitones / 12.0)
		var a: int = clampi(int(floor(source_position)), 0, source_last)
		var b: int = mini(a + 1, source_last)
		var t: float = source_position - float(a)
		out.left[frame] = lerpf(pcm.left[a], pcm.left[b], t)
		if pcm.is_stereo():
			out.right[frame] = lerpf(pcm.right[a], pcm.right[b], t)
		source_position += ratio
		if source_position > float(source_last):
			source_position = float(source_last)
	return out


static func _apply_gain_pan_filters(
	pcm: GASPCMData,
	volume_points: Array[Dictionary],
	pan_points: Array[Dictionary],
	low_points: Array[Dictionary],
	high_points: Array[Dictionary],
	timeline_start_frame: int
) -> void:
	var stereo: bool = pcm.is_stereo()
	var sr: float = float(maxi(1, pcm.sample_rate))
	var low_l: float = 0.0
	var low_r: float = 0.0
	var high_prev_in_l: float = 0.0
	var high_prev_in_r: float = 0.0
	var high_prev_out_l: float = 0.0
	var high_prev_out_r: float = 0.0
	for frame: int in range(pcm.frame_count()):
		var absolute_frame: int = timeline_start_frame + frame
		var gain_db: float = value_at(volume_points, absolute_frame, 0.0) if not volume_points.is_empty() else 0.0
		var gain: float = db_to_linear(gain_db)
		var pan: float = clampf(value_at(pan_points, absolute_frame, 0.0), -1.0, 1.0) if not pan_points.is_empty() else 0.0
		var left_gain: float = gain * sqrt(0.5 * (1.0 - pan)) * 1.41421356237
		var right_gain: float = gain * sqrt(0.5 * (1.0 + pan)) * 1.41421356237
		var left_sample: float = pcm.left[frame]
		var right_sample: float = pcm.right[frame] if stereo else left_sample
		if not low_points.is_empty():
			var low_hz: float = clampf(value_at(low_points, absolute_frame, minf(20000.0, sr * 0.45)), 20.0, sr * 0.49)
			var low_alpha: float = 1.0 - exp(-6.28318530718 * low_hz / sr)
			low_l += low_alpha * (left_sample - low_l)
			low_r += low_alpha * (right_sample - low_r)
			left_sample = low_l
			right_sample = low_r
		if not high_points.is_empty():
			var high_hz: float = clampf(value_at(high_points, absolute_frame, 20.0), 5.0, sr * 0.45)
			var rc: float = 1.0 / (6.28318530718 * high_hz)
			var dt: float = 1.0 / sr
			var high_alpha: float = rc / (rc + dt)
			var high_l: float = high_alpha * (high_prev_out_l + left_sample - high_prev_in_l)
			var high_r: float = high_alpha * (high_prev_out_r + right_sample - high_prev_in_r)
			high_prev_in_l = left_sample
			high_prev_in_r = right_sample
			high_prev_out_l = high_l
			high_prev_out_r = high_r
			left_sample = high_l
			right_sample = high_r
		pcm.left[frame] = left_sample * left_gain
		if stereo:
			pcm.right[frame] = right_sample * right_gain


static func lane_points(lanes: Dictionary, parameter: String) -> Array[Dictionary]:
	return _lane_points(lanes, parameter)


static func apply_wet_automation(dry: GASPCMData, wet: GASPCMData, points: Array[Dictionary], timeline_start_frame: int = 0) -> GASPCMData:
	if wet == null or points.is_empty():
		return wet
	if dry == null:
		return wet
	var count: int = maxi(dry.frame_count(), wet.frame_count())
	var stereo: bool = dry.is_stereo() or wet.is_stereo()
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = wet.sample_rate
	out.channels = 2 if stereo else 1
	out.left.resize(count)
	if stereo:
		out.right.resize(count)
	for frame: int in range(count):
		var mix: float = clampf(value_at(points, timeline_start_frame + frame, 1.0), 0.0, 1.0)
		var dry_left: float = dry.left[frame] if frame < dry.frame_count() else 0.0
		var wet_left: float = wet.left[frame] if frame < wet.frame_count() else 0.0
		out.left[frame] = lerpf(dry_left, wet_left, mix)
		if stereo:
			var dry_right: float = 0.0
			if frame < dry.frame_count():
				dry_right = dry.right[frame] if dry.is_stereo() else dry.left[frame]
			var wet_right: float = 0.0
			if frame < wet.frame_count():
				wet_right = wet.right[frame] if wet.is_stereo() else wet.left[frame]
			out.right[frame] = lerpf(dry_right, wet_right, mix)
	return out


static func effect_parameter_lane_key(effect_index: int, parameter_key: String) -> String:
	return "fx:%d:param:%s" % [effect_index, parameter_key]


static func has_effect_automation(lanes: Dictionary, effect_index: int) -> bool:
	if lanes.has("fx:%d:wet" % effect_index):
		return true
	var prefix: String = "fx:%d:param:" % effect_index
	for key_value: Variant in lanes.keys():
		if str(key_value).begins_with(prefix):
			return true
	return false


static func effect_parameter_lane_keys(lanes: Dictionary, effect_index: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var prefix: String = "fx:%d:param:" % effect_index
	for key_value: Variant in lanes.keys():
		var key: String = str(key_value)
		if key.begins_with(prefix):
			result.append(key.trim_prefix(prefix))
	return result


static func process_effect_parameter_automation(input: GASPCMData, effect: GASEffectData, effect_index: int, lanes: Dictionary, timeline_start_frame: int = 0) -> GASPCMData:
	if input == null or effect == null:
		return input
	var parameter_keys: PackedStringArray = effect_parameter_lane_keys(lanes, effect_index)
	if parameter_keys.is_empty():
		return EffectEngine.process(input, effect)
	# Resolve and sort automation lanes once. The block renderer below is intentionally
	# free of Dictionary lane lookups/sorts so animated FX stay practical on long clips.
	var automation_specs: Array[EffectAutomationSpec] = []
	for parameter_key: String in parameter_keys:
		var resolved_points: Array[Dictionary] = lane_points(lanes, effect_parameter_lane_key(effect_index, parameter_key))
		if resolved_points.is_empty():
			continue
		var automation_spec: EffectAutomationSpec = EffectAutomationSpec.new()
		automation_spec.key = parameter_key
		automation_spec.points = resolved_points
		automation_spec.fallback = float(effect.params.get(parameter_key, 0.0))
		automation_specs.append(automation_spec)
	if automation_specs.is_empty():
		return EffectEngine.process(input, effect)
	var last_frame: int = maxi(0, input.frame_count() - 1)
	var final_effect: GASEffectData = effect.duplicate_effect()
	for spec: EffectAutomationSpec in automation_specs:
		final_effect.params[spec.key] = value_at(spec.points, timeline_start_frame + last_frame, spec.fallback)
	var out: GASPCMData = EffectEngine.process(input, final_effect)
	if out == null or input.frame_count() <= 0:
		return out
	var block_size: int = 2048
	var tail_context: int = EffectEngine.tail_frames(effect, input.sample_rate)
	var context_frames: int = mini(maxi(block_size, tail_context), maxi(block_size, input.sample_rate * 2))
	var block_start: int = 0
	while block_start < input.frame_count():
		var block_end: int = mini(input.frame_count(), block_start + block_size)
		var context_start: int = maxi(0, block_start - context_frames)
		var context_pcm: GASPCMData = input.slice_frames(context_start, block_end)
		var animated_effect: GASEffectData = effect.duplicate_effect()
		var evaluation_frame: int = timeline_start_frame + int((block_start + block_end) / 2)
		for spec: EffectAutomationSpec in automation_specs:
			animated_effect.params[spec.key] = value_at(spec.points, evaluation_frame, spec.fallback)
		var rendered: GASPCMData = EffectEngine.process(context_pcm, animated_effect)
		if rendered != null:
			var source_offset: int = block_start - context_start
			var copy_count: int = mini(block_end - block_start, maxi(0, rendered.frame_count() - source_offset))
			for frame_offset: int in range(copy_count):
				var destination: int = block_start + frame_offset
				var source_frame: int = source_offset + frame_offset
				if destination >= out.frame_count():
					break
				out.left[destination] = rendered.left[source_frame]
				if out.is_stereo():
					out.right[destination] = rendered.right[source_frame] if rendered.is_stereo() else rendered.left[source_frame]
		block_start = block_end
	return out
