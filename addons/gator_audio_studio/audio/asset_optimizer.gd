@tool
class_name GASAssetOptimizer
extends RefCounted

const AnalyzerEngine := preload("res://addons/gator_audio_studio/audio/analyzer_engine.gd")
const PROGRESS_BLOCK_FRAMES: int = 16384

static func analyze_pcm(pcm: GASPCMData, source_path: String = "", progress_callback: Callable = Callable()) -> Dictionary:
	if pcm == null:
		return {}
	var frames: int = pcm.frame_count()
	var stereo: bool = pcm.is_stereo()
	var channels: int = 2 if stereo else 1
	var duration: float = pcm.duration_seconds()
	var wav_bytes: int = frames * channels * 2 + 44
	var peak: float = 0.0
	var sum_sq: float = 0.0
	var silent_frames: int = 0
	var clipping_frames: int = 0
	var stereo_difference_sum: float = 0.0
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	var next_progress_frame: int = PROGRESS_BLOCK_FRAMES
	for i: int in range(frames):
		var left_sample: float = left[i]
		var right_sample: float = right[i] if stereo else left_sample
		var mono: float = (left_sample + right_sample) * 0.5
		peak = maxf(peak, maxf(absf(left_sample), absf(right_sample)))
		sum_sq += mono * mono
		if absf(mono) < 0.001:
			silent_frames += 1
		if absf(left_sample) >= 0.999 or absf(right_sample) >= 0.999:
			clipping_frames += 1
		if stereo:
			stereo_difference_sum += absf(left_sample - right_sample)
		if progress_callback.is_valid() and i >= next_progress_frame:
			progress_callback.call(float(i) / float(maxi(1, frames)))
			next_progress_frame += PROGRESS_BLOCK_FRAMES
	if progress_callback.is_valid():
		progress_callback.call(1.0)
	var rms: float = sqrt(sum_sq / float(maxi(1, frames)))
	var silence_ratio: float = float(silent_frames) / float(maxi(1, frames))
	var stereo_difference: float = stereo_difference_sum / float(maxi(1, frames))
	var recommendations: PackedStringArray = PackedStringArray()
	if stereo and stereo_difference < 0.015:
		recommendations.append("Stereo channels are nearly identical; consider mono.")
	if pcm.sample_rate > 44100 and duration < 10.0:
		recommendations.append("Sample rate exceeds 44.1 kHz; consider 44.1/32/22.05 kHz for game SFX.")
	if silence_ratio > 0.20:
		recommendations.append("More than 20% of frames are near-silent; trim unused silence.")
	if clipping_frames > 0:
		recommendations.append("Clipping detected; lower level or use a limiter.")
	if rms < 0.01 and peak < 0.1:
		recommendations.append("Audio is very quiet; consider normalization.")
	if duration > 20.0:
		recommendations.append("Long asset: consider compressed import (Ogg/MP3) instead of WAV.")
	elif duration < 5.0:
		recommendations.append("Short/repeated asset: WAV is appropriate for low-latency game playback.")
	return {
		"source_path": source_path,
		"duration": duration,
		"channels": channels,
		"sample_rate": pcm.sample_rate,
		"frames": frames,
		"estimated_memory_bytes": frames * channels * 4,
		"estimated_wav_bytes": wav_bytes,
		"peak_db": linear_to_db(maxf(0.00000001, peak)),
		"rms_db": linear_to_db(maxf(0.00000001, rms)),
		"silence_ratio": silence_ratio,
		"clipping_frames": clipping_frames,
		"stereo_difference": stereo_difference,
		"recommendations": recommendations,
	}


static func format_bytes(bytes: int) -> String:
	var value: float = float(maxi(0, bytes))
	if value >= 1073741824.0:
		return "%.2f GiB" % (value / 1073741824.0)
	if value >= 1048576.0:
		return "%.2f MiB" % (value / 1048576.0)
	if value >= 1024.0:
		return "%.1f KiB" % (value / 1024.0)
	return "%d B" % int(value)
