@tool
class_name GASPCMIOJob
extends RefCounted

const MODE_NONE: int = 0
const MODE_LOAD_WAVS: int = 1
const MODE_RESAMPLE_PCM: int = 2
const MODE_PCM_TO_WAV: int = 3
const MODE_RECORDING_CAPTURE: int = 4

var task_id: int = -1
var mode: int = MODE_NONE
var paths: PackedStringArray = PackedStringArray()
var target_rate: int = 44100
var pcm_results: Array[GASPCMData] = []
var loaded_paths: PackedStringArray = PackedStringArray()
var pcm_result: GASPCMData
var wav_result: AudioStreamWAV
var success: bool = false

var _source_pcm: GASPCMData
var _recording_capture: GASRecordingCapture
var _recording_compensation_ms: float = 0.0
var _recording_punch_target_frames: int = -1


func start_load_wavs(source_paths: PackedStringArray, rate: int) -> bool:
	if task_id >= 0 or source_paths.is_empty():
		return false
	paths = source_paths.duplicate()
	target_rate = maxi(1, rate)
	mode = MODE_LOAD_WAVS
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_load_wavs"), false, "GAS WAV decode")
	return task_id >= 0


func start_resample(pcm: GASPCMData, rate: int) -> bool:
	if task_id >= 0 or pcm == null:
		return false
	_source_pcm = pcm
	target_rate = maxi(1, rate)
	mode = MODE_RESAMPLE_PCM
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_resample"), false, "GAS PCM resample")
	return task_id >= 0


func start_recording_capture(capture: GASRecordingCapture, rate: int, compensation_ms: float = 0.0, punch_target_frames: int = -1) -> bool:
	if task_id >= 0 or capture == null:
		return false
	_recording_capture = capture
	target_rate = maxi(1, rate)
	_recording_compensation_ms = compensation_ms
	_recording_punch_target_frames = punch_target_frames
	mode = MODE_RECORDING_CAPTURE
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_recording_capture"), false, "GAS recording finalize")
	return task_id >= 0


func start_pcm_to_wav(pcm: GASPCMData) -> bool:
	if task_id >= 0 or pcm == null:
		return false
	_source_pcm = pcm
	mode = MODE_PCM_TO_WAV
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_pcm_to_wav"), false, "GAS WAV conversion")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	_source_pcm = null
	_recording_capture = null


func _worker_load_wavs() -> void:
	for path: String in paths:
		if path.get_extension().to_lower() != "wav":
			continue
		var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		var pcm: GASPCMData = GASPCMData.from_wav(wav)
		if pcm == null:
			continue
		if pcm.sample_rate != target_rate:
			pcm = pcm.resample_to_rate(target_rate)
		if pcm == null:
			continue
		pcm_results.append(pcm)
		loaded_paths.append(path)
	success = not pcm_results.is_empty()


func _worker_resample() -> void:
	if _source_pcm == null:
		return
	pcm_result = _source_pcm if _source_pcm.sample_rate == target_rate else _source_pcm.resample_to_rate(target_rate)
	success = pcm_result != null and pcm_result.frame_count() > 0


func _worker_pcm_to_wav() -> void:
	if _source_pcm == null:
		return
	wav_result = _source_pcm.to_wav()
	success = wav_result != null


func _worker_recording_capture() -> void:
	if _recording_capture == null:
		return
	var flattened: GASPCMData = _recording_capture.flatten()
	if flattened == null:
		return
	var finalized: GASPCMData = flattened if flattened.sample_rate == target_rate else flattened.resample_to_rate(target_rate)
	if finalized == null:
		return
	if _recording_punch_target_frames >= 0:
		var compensation_frames: int = int(round(_recording_compensation_ms * 0.001 * float(maxi(1, finalized.sample_rate))))
		finalized = _align_punch(finalized, compensation_frames, _recording_punch_target_frames)
	pcm_result = finalized
	success = pcm_result != null and pcm_result.frame_count() > 0


func _align_punch(pcm: GASPCMData, compensation_frames: int, target_frames: int) -> GASPCMData:
	var target: int = maxi(0, target_frames)
	if target == 0:
		return pcm.fit_frames(0)
	if compensation_frames >= 0:
		var source_start: int = mini(compensation_frames, pcm.frame_count())
		return pcm.slice_frames(source_start, pcm.frame_count()).fit_frames(target)
	var leading: int = mini(-compensation_frames, target)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	out.left.resize(target)
	if pcm.is_stereo():
		out.right.resize(target)
	var source_left: PackedFloat32Array = pcm.left
	var source_right: PackedFloat32Array = pcm.right
	var out_left: PackedFloat32Array = out.left
	var out_right: PackedFloat32Array = out.right
	var stereo: bool = pcm.is_stereo()
	var copy_count: int = mini(pcm.frame_count(), target - leading)
	for index: int in range(copy_count):
		var dst: int = leading + index
		out_left[dst] = source_left[index]
		if stereo:
			out_right[dst] = source_right[index]
	return out
