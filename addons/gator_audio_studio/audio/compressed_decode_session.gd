@tool
class_name GASCompressedDecodeSession
extends RefCounted

const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const WaveformCache := preload("res://addons/gator_audio_studio/audio/waveform_cache.gd")

const MIX_CHUNK_FRAMES: int = 8192
const MAX_UNKNOWN_DURATION_SECONDS: int = 3600
const INITIAL_RESERVE_SECONDS: int = 15
const MAX_FINE_LEVEL_BLOCKS: int = 262144

var path: String = ""
var output_rate: int = 44100
var channels: int = 2
var length_seconds: float = 0.0
var finished: bool = false
var failed: bool = false
var cancelled: bool = false
var error_message: String = ""

var _stream: AudioStream
var _playback: AudioStreamPlayback
var _mix_rate: int = 48000
var _maximum_source_frames: int = 0
var _source_frames_seen: int = 0
var _next_source_position: float = 0.0
var _source_step: float = 1.0
var _left: PackedFloat32Array = PackedFloat32Array()
var _right: PackedFloat32Array = PackedFloat32Array()
var _output_count: int = 0
var _previous_frame: Vector2 = Vector2.ZERO
var _has_previous: bool = false
var _wave_block_size: int = 4
var _wave_min_left: PackedFloat32Array = PackedFloat32Array()
var _wave_max_left: PackedFloat32Array = PackedFloat32Array()
var _wave_min_right: PackedFloat32Array = PackedFloat32Array()
var _wave_max_right: PackedFloat32Array = PackedFloat32Array()
var _wave_current_block: int = -1
var _wave_lo_l: float = 1.0
var _wave_hi_l: float = -1.0
var _wave_lo_r: float = 1.0
var _wave_hi_r: float = -1.0


func setup(stream: AudioStream, source_path: String, target_rate: int, mix_rate: int) -> bool:
	if stream == null:
		return false
	_stream = stream
	path = source_path
	_mix_rate = maxi(8000, mix_rate)
	output_rate = maxi(8000, target_rate if target_rate > 0 else _mix_rate)
	channels = 1 if stream.is_monophonic() else 2
	length_seconds = maxf(0.0, stream.get_length())
	_playback = stream.instantiate_playback()
	if _playback == null:
		error_message = "Could not instantiate compressed audio playback."
		failed = true
		finished = true
		return false
	var estimated_source_frames: int = int(ceil(length_seconds * float(_mix_rate)))
	if estimated_source_frames > 0:
		_maximum_source_frames = estimated_source_frames + MIX_CHUNK_FRAMES * 4
	else:
		_maximum_source_frames = _mix_rate * MAX_UNKNOWN_DURATION_SECONDS
	_source_step = float(_mix_rate) / float(output_rate)
	var estimated_output_frames: int = int(ceil(length_seconds * float(output_rate)))
	_wave_block_size = 4
	while estimated_output_frames > 0 and int(ceil(float(estimated_output_frames) / float(_wave_block_size))) > MAX_FINE_LEVEL_BLOCKS:
		_wave_block_size *= 2
	var initial_capacity: int = output_rate * INITIAL_RESERVE_SECONDS
	if estimated_output_frames > 0:
		initial_capacity = mini(estimated_output_frames + MIX_CHUNK_FRAMES, initial_capacity)
	initial_capacity = maxi(MIX_CHUNK_FRAMES, initial_capacity)
	_left.resize(initial_capacity)
	if channels == 2:
		_right.resize(initial_capacity)
	_playback.start(0.0)
	return true


func step(time_budget_usec: int = 5000) -> void:
	if finished:
		return
	if cancelled:
		_finish_decode(false, "Decode cancelled.")
		return
	var started_usec: int = Time.get_ticks_usec()
	while not finished and Time.get_ticks_usec() - started_usec < maxi(1000, time_budget_usec):
		if _source_frames_seen >= _maximum_source_frames:
			_flush_final_sample()
			_finish_decode(true)
			break
		var request_frames: int = mini(MIX_CHUNK_FRAMES, _maximum_source_frames - _source_frames_seen)
		var frames: PackedVector2Array = _playback.mix_audio(1.0, request_frames)
		var decoded_count: int = frames.size()
		if decoded_count <= 0:
			_flush_final_sample()
			_finish_decode(_output_count > 0, "Compressed decoder returned no PCM frames." if _output_count <= 0 else "")
			break
		_process_source_chunk(frames)
		_source_frames_seen += decoded_count
		_previous_frame = frames[decoded_count - 1]
		_has_previous = true
		if decoded_count < request_frames:
			_flush_final_sample()
			_finish_decode(true)
			break


func cancel() -> void:
	cancelled = true


func progress() -> float:
	if finished:
		return 1.0
	if length_seconds > 0.0:
		return clampf(float(_source_frames_seen) / maxf(1.0, length_seconds * float(_mix_rate)), 0.0, 0.999)
	return 0.0


func pcm_result() -> GASPCMData:
	if not finished or failed or _output_count <= 0:
		return null
	var pcm: GASPCMData = PCMData.new() as GASPCMData
	pcm.sample_rate = output_rate
	pcm.channels = channels
	_left.resize(_output_count)
	pcm.left = _left
	if channels == 2:
		_right.resize(_output_count)
		pcm.right = _right
	return pcm


func waveform_cache_result(pcm: GASPCMData) -> GASWaveformCache:
	if pcm == null or pcm.frame_count() <= 0:
		return null
	var cache: GASWaveformCache = WaveformCache.new() as GASWaveformCache
	cache.build_from_summary(pcm, _wave_block_size, _wave_min_left, _wave_max_left, _wave_min_right, _wave_max_right)
	return cache


func _process_source_chunk(frames: PackedVector2Array) -> void:
	var chunk_start: int = _source_frames_seen
	var chunk_end: int = chunk_start + frames.size() - 1
	while _next_source_position <= float(chunk_end):
		var a_index: int = int(floor(_next_source_position))
		var b_index: int = a_index + 1
		if b_index > chunk_end:
			break
		var a_frame: Vector2 = _source_frame_at(a_index, frames, chunk_start)
		var b_frame: Vector2 = _source_frame_at(b_index, frames, chunk_start)
		var fraction: float = _next_source_position - float(a_index)
		_append_output(lerpf(a_frame.x, b_frame.x, fraction), lerpf(a_frame.y, b_frame.y, fraction))
		_next_source_position += _source_step


func _source_frame_at(source_index: int, frames: PackedVector2Array, chunk_start: int) -> Vector2:
	if source_index < chunk_start:
		return _previous_frame if _has_previous else frames[0]
	var local_index: int = clampi(source_index - chunk_start, 0, frames.size() - 1)
	return frames[local_index]


func _flush_final_sample() -> void:
	if not _has_previous:
		return
	var final_source_index: int = maxi(0, _source_frames_seen - 1)
	while _next_source_position <= float(final_source_index) + 0.0001:
		_append_output(_previous_frame.x, _previous_frame.y)
		_next_source_position += _source_step


func _append_output(left_value: float, right_value: float) -> void:
	_ensure_capacity(_output_count + 1)
	var left_clamped: float = clampf(left_value, -1.0, 1.0)
	var right_clamped: float = clampf(right_value, -1.0, 1.0)
	_left[_output_count] = left_clamped
	if channels == 2:
		_right[_output_count] = right_clamped
	_accumulate_waveform(left_clamped, right_clamped)
	_output_count += 1


func _ensure_capacity(required: int) -> void:
	if required <= _left.size():
		return
	var next_size: int = maxi(required, maxi(output_rate * INITIAL_RESERVE_SECONDS, _left.size() * 2))
	_left.resize(next_size)
	if channels == 2:
		_right.resize(next_size)


func _accumulate_waveform(left_value: float, right_value: float) -> void:
	var block_index: int = int(_output_count / maxi(1, _wave_block_size))
	if _wave_current_block < 0:
		_wave_current_block = block_index
	if block_index != _wave_current_block:
		_flush_wave_block()
		_wave_current_block = block_index
	_wave_lo_l = minf(_wave_lo_l, left_value)
	_wave_hi_l = maxf(_wave_hi_l, left_value)
	if channels == 2:
		_wave_lo_r = minf(_wave_lo_r, right_value)
		_wave_hi_r = maxf(_wave_hi_r, right_value)


func _flush_wave_block() -> void:
	if _wave_current_block < 0:
		return
	_wave_min_left.append(_wave_lo_l)
	_wave_max_left.append(_wave_hi_l)
	if channels == 2:
		_wave_min_right.append(_wave_lo_r)
		_wave_max_right.append(_wave_hi_r)
	_wave_lo_l = 1.0
	_wave_hi_l = -1.0
	_wave_lo_r = 1.0
	_wave_hi_r = -1.0


func _finish_decode(success: bool, message: String = "") -> void:
	if finished:
		return
	_flush_wave_block()
	if _playback != null:
		_playback.stop()
	failed = not success
	error_message = message
	finished = true
