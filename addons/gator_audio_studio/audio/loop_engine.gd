@tool
class_name GASLoopEngine
extends RefCounted

const MODE_FORWARD: int = AudioStreamWAV.LOOP_FORWARD
const MODE_PINGPONG: int = AudioStreamWAV.LOOP_PINGPONG
const MODE_BACKWARD: int = AudioStreamWAV.LOOP_BACKWARD

static func apply_loop_metadata(wav: AudioStreamWAV, loop_start: int, loop_end: int, loop_mode: int) -> AudioStreamWAV:
	if wav == null:
		return null
	var max_frames: int = _wav_frame_count(wav)
	wav.loop_begin = clampi(loop_start, 0, maxi(0, max_frames - 1))
	wav.loop_end = clampi(loop_end, wav.loop_begin + 1, maxi(1, max_frames))
	wav.loop_mode = clampi(loop_mode, AudioStreamWAV.LOOP_DISABLED, AudioStreamWAV.LOOP_BACKWARD)
	return wav


static func crossfade_loop(pcm: GASPCMData, loop_start: int, loop_end: int, crossfade_frames: int) -> GASPCMData:
	if pcm == null or pcm.frame_count() <= 1:
		return pcm
	var start: int = clampi(loop_start, 0, pcm.frame_count() - 1)
	var end: int = clampi(loop_end, start + 1, pcm.frame_count())
	var length: int = mini(maxi(0, crossfade_frames), mini(end - start, start))
	if length <= 0:
		return pcm.duplicate_pcm()
	var out: GASPCMData = pcm.duplicate_pcm()
	var stereo: bool = out.is_stereo()
	for i: int in range(length):
		var t: float = float(i + 1) / float(length + 1)
		var a_index: int = end - length + i
		var b_index: int = start + i
		var a_gain: float = cos(t * 1.57079632679)
		var b_gain: float = sin(t * 1.57079632679)
		var mixed_l: float = out.left[a_index] * a_gain + out.left[b_index] * b_gain
		out.left[a_index] = mixed_l
		out.left[b_index] = mixed_l
		if stereo:
			var mixed_r: float = out.right[a_index] * a_gain + out.right[b_index] * b_gain
			out.right[a_index] = mixed_r
			out.right[b_index] = mixed_r
	return out


static func find_candidates(pcm: GASPCMData, start_hint: int, end_hint: int, search_radius: int, candidate_count: int = 8) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if pcm == null or pcm.frame_count() < 64:
		return result
	var radius: int = clampi(search_radius, 8, maxi(8, pcm.frame_count() / 3))
	var start_min: int = clampi(start_hint - radius, 1, pcm.frame_count() - 3)
	var start_max: int = clampi(start_hint + radius, start_min, pcm.frame_count() - 3)
	var end_min: int = clampi(end_hint - radius, start_min + 2, pcm.frame_count() - 1)
	var end_max: int = clampi(end_hint + radius, end_min, pcm.frame_count() - 1)
	var stride: int = maxi(1, int(ceil(float(radius * 2 + 1) / 48.0)))
	for start_frame: int in range(start_min, start_max + 1, stride):
		for end_frame: int in range(end_min, end_max + 1, stride):
			if end_frame - start_frame < 32:
				continue
			var score: float = _seam_score(pcm, start_frame, end_frame)
			result.append({"start": start_frame, "end": end_frame, "score": score})
	result.sort_custom(_candidate_less_than)
	if result.size() > candidate_count:
		result.resize(candidate_count)
	return result


static func _candidate_less_than(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 999999.0)) < float(b.get("score", 999999.0))


static func _seam_score(pcm: GASPCMData, start_frame: int, end_frame: int) -> float:
	var stereo: bool = pcm.is_stereo()
	var amp_a: float = pcm.left[start_frame]
	var amp_b: float = pcm.left[end_frame]
	if stereo:
		amp_a = (amp_a + pcm.right[start_frame]) * 0.5
		amp_b = (amp_b + pcm.right[end_frame]) * 0.5
	var prev_a: int = maxi(0, start_frame - 1)
	var prev_b: int = maxi(0, end_frame - 1)
	var slope_a: float = pcm.left[start_frame] - pcm.left[prev_a]
	var slope_b: float = pcm.left[end_frame] - pcm.left[prev_b]
	var frequency_score: float = 0.0
	var compare: int = mini(96, mini(start_frame + 1, end_frame - start_frame))
	for i: int in range(compare):
		var ai: int = maxi(0, start_frame - i)
		var bi: int = maxi(0, end_frame - i)
		frequency_score += absf(pcm.left[ai] - pcm.left[bi])
	frequency_score /= float(maxi(1, compare))
	return absf(amp_a - amp_b) * 4.0 + absf(slope_a - slope_b) * 2.0 + frequency_score


static func _wav_frame_count(wav: AudioStreamWAV) -> int:
	if wav == null:
		return 0
	var channel_count: int = 2 if wav.stereo else 1
	var bytes_per_sample: int = 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
	if wav.format != AudioStreamWAV.FORMAT_8_BITS and wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return 0
	return int(wav.data.size() / maxi(1, bytes_per_sample * channel_count))
