@tool
class_name GASRecorderController
extends RefCounted

const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const RecordingCapture := preload("res://addons/gator_audio_studio/audio/recording_capture.gd")

var recording: bool = false
var input_active: bool = false
var stereo: bool = true
var sample_rate: int = 44100
var total_frames: int = 0
var peak_left: float = 0.0
var peak_right: float = 0.0
var rms_left: float = 0.0
var rms_right: float = 0.0
var clipping: bool = false
var discarded_or_empty_polls: int = 0

var _chunks: Array[PackedVector2Array] = []


func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()


func audio_input_setting_enabled() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))


func enable_audio_input_setting() -> Error:
	ProjectSettings.set_setting("audio/driver/enable_input", true)
	return ProjectSettings.save()


func activate(device_name: String) -> Error:
	if not audio_input_setting_enabled():
		return ERR_UNAVAILABLE
	if not device_name.is_empty():
		AudioServer.input_device = device_name
	var result: Error = AudioServer.set_input_device_active(true)
	if result == OK:
		input_active = true
		sample_rate = maxi(1, int(round(AudioServer.get_input_mix_rate())))
		_discard_pending_input()
	return result


func deactivate() -> void:
	if recording:
		return
	if input_active:
		AudioServer.set_input_device_active(false)
	input_active = false
	_reset_meter()


func start_recording(device_name: String, record_stereo: bool) -> Error:
	var result: Error = activate(device_name)
	if result != OK:
		return result
	_chunks.clear()
	total_frames = 0
	stereo = record_stereo
	recording = true
	clipping = false
	discarded_or_empty_polls = 0
	_reset_meter()
	return OK


func poll() -> void:
	if not input_active:
		return
	var available: int = AudioServer.get_input_frames_available()
	if available <= 0:
		discarded_or_empty_polls += 1
		return
	var frames: PackedVector2Array = AudioServer.get_input_frames(available)
	if frames.is_empty():
		discarded_or_empty_polls += 1
		return
	_update_meter(frames)
	if recording:
		_chunks.append(frames)
		total_frames += frames.size()


func stop_recording_capture(keep_input_active: bool) -> GASRecordingCapture:
	if not recording:
		return null
	poll()
	recording = false
	var capture: GASRecordingCapture = RecordingCapture.new() as GASRecordingCapture
	capture.sample_rate = sample_rate
	capture.stereo = stereo
	capture.total_frames = total_frames
	capture.chunks = _chunks
	_chunks = []
	total_frames = 0
	if not keep_input_active:
		AudioServer.set_input_device_active(false)
		input_active = false
	return capture


func stop_recording(keep_input_active: bool) -> GASPCMData:
	var capture: GASRecordingCapture = stop_recording_capture(keep_input_active)
	return capture.flatten() if capture != null else null


func cancel_recording() -> void:
	recording = false
	_chunks.clear()
	total_frames = 0
	if input_active:
		AudioServer.set_input_device_active(false)
	input_active = false
	_reset_meter()


func duration_seconds() -> float:
	if sample_rate <= 0:
		return 0.0
	return float(total_frames) / float(sample_rate)


func _flatten_recording() -> GASPCMData:
	if total_frames <= 0:
		return null
	var out: GASPCMData = PCMData.new()
	out.sample_rate = sample_rate
	out.channels = 2 if stereo else 1
	out.left.resize(total_frames)
	if stereo:
		out.right.resize(total_frames)
	var dst: int = 0
	for chunk: PackedVector2Array in _chunks:
		for frame: Vector2 in chunk:
			if stereo:
				out.left[dst] = frame.x
				out.right[dst] = frame.y
			else:
				out.left[dst] = (frame.x + frame.y) * 0.5
			dst += 1
	return out


func _update_meter(frames: PackedVector2Array) -> void:
	var sum_left: float = 0.0
	var sum_right: float = 0.0
	var local_peak_left: float = 0.0
	var local_peak_right: float = 0.0
	for frame: Vector2 in frames:
		var abs_left: float = absf(frame.x)
		var abs_right: float = absf(frame.y)
		local_peak_left = maxf(local_peak_left, abs_left)
		local_peak_right = maxf(local_peak_right, abs_right)
		sum_left += frame.x * frame.x
		sum_right += frame.y * frame.y
	var count: float = float(maxi(1, frames.size()))
	peak_left = local_peak_left
	peak_right = local_peak_right
	rms_left = sqrt(sum_left / count)
	rms_right = sqrt(sum_right / count)
	clipping = clipping or local_peak_left >= 0.999 or local_peak_right >= 0.999


func _reset_meter() -> void:
	peak_left = 0.0
	peak_right = 0.0
	rms_left = 0.0
	rms_right = 0.0
	clipping = false


func _discard_pending_input() -> void:
	var available: int = AudioServer.get_input_frames_available()
	if available > 0:
		AudioServer.get_input_frames(available)
