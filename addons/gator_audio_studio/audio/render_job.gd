@tool
class_name GASAudioRenderJob
extends RefCounted

# Typed background render/export job. The editor captures an isolated render
# snapshot before start(), so worker code never traverses the live editor model.

const ExportEngine := preload("res://addons/gator_audio_studio/audio/export_engine.gd")
const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")

enum JobType {
	NONE,
	TRACK_TO_WAV,
	TRACK_TO_FILE,
	MIX_TO_FILE,
	BATCH_TO_DIRECTORY,
}

var task_id: int = -1
var job_type: int = JobType.NONE
var output_path: String = ""
var error: Error = OK
var wav_result: AudioStreamWAV
var completed: bool = false
var files_exported: int = 0
var exported_paths: PackedStringArray = PackedStringArray()

var _progress_mutex: Mutex = Mutex.new()
var _progress: float = 0.0

var _snapshot: GASEditorModel
var _bit_depth: int = 16
var _mono: bool = false
var _sample_rate: int = 0
var _normalize: bool = false
var _metadata: Dictionary = {}
var _loop_start: int = 0
var _loop_end: int = 0
var _loop_mode: int = AudioStreamWAV.LOOP_DISABLED
var _slice_start: int = -1
var _slice_end: int = -1
var _batch_mode: int = 0
var _batch_selected_clip_ids: PackedInt32Array = PackedInt32Array()
var _batch_pattern: String = "{track}_{label}_{index}"
var _use_track_rate: bool = true
var _batch_total_units: int = 1
var _batch_completed_units: int = 0


func progress() -> float:
	_progress_mutex.lock()
	var value: float = _progress
	_progress_mutex.unlock()
	return value


func _set_progress(value: float) -> void:
	_progress_mutex.lock()
	_progress = clampf(value, 0.0, 1.0)
	_progress_mutex.unlock()


func _set_scaled_progress(value: float, base: float, span: float) -> void:
	_set_progress(base + clampf(value, 0.0, 1.0) * span)


func start_track_to_wav(snapshot: GASEditorModel) -> bool:
	if not _prepare(snapshot, JobType.TRACK_TO_WAV):
		return false
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_track_to_wav"), false, "GAS track render")
	return task_id >= 0


func start_track_to_file(
	snapshot: GASEditorModel,
	path: String,
	bit_depth: int = 16,
	mono: bool = false,
	sample_rate: int = 0,
	normalize: bool = false,
	metadata: Dictionary = {},
	loop_start: int = 0,
	loop_end: int = 0,
	loop_mode: int = AudioStreamWAV.LOOP_DISABLED
) -> bool:
	if not _prepare(snapshot, JobType.TRACK_TO_FILE):
		return false
	output_path = path if path.to_lower().ends_with(".wav") else path + ".wav"
	_bit_depth = 8 if bit_depth <= 8 else 16
	_mono = mono
	_sample_rate = sample_rate
	_normalize = normalize
	_metadata = metadata.duplicate(true)
	_loop_start = loop_start
	_loop_end = loop_end
	_loop_mode = loop_mode
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_track_to_file"), false, "GAS track export")
	return task_id >= 0


func start_mix_to_file(
	snapshot: GASEditorModel,
	path: String,
	bit_depth: int = 16,
	mono: bool = false,
	sample_rate: int = 0,
	normalize: bool = false,
	metadata: Dictionary = {},
	loop_start: int = 0,
	loop_end: int = 0,
	loop_mode: int = AudioStreamWAV.LOOP_DISABLED,
	slice_start: int = -1,
	slice_end: int = -1
) -> bool:
	if not _prepare(snapshot, JobType.MIX_TO_FILE):
		return false
	output_path = path if path.to_lower().ends_with(".wav") else path + ".wav"
	_bit_depth = 8 if bit_depth <= 8 else 16
	_mono = mono
	_sample_rate = sample_rate
	_normalize = normalize
	_metadata = metadata.duplicate(true)
	_loop_start = loop_start
	_loop_end = loop_end
	_loop_mode = loop_mode
	_slice_start = slice_start
	_slice_end = slice_end
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_mix_to_file"), false, "GAS mixdown export")
	return task_id >= 0


func start_batch_to_directory(
	snapshot: GASEditorModel,
	folder: String,
	mode: int,
	selected_clip_ids: PackedInt32Array,
	pattern: String,
	bit_depth: int,
	mono: bool,
	sample_rate: int,
	use_track_rate: bool,
	normalize: bool,
	metadata: Dictionary = {}
) -> bool:
	if not _prepare(snapshot, JobType.BATCH_TO_DIRECTORY):
		return false
	output_path = folder
	_batch_mode = mode
	_batch_selected_clip_ids = selected_clip_ids.duplicate()
	_batch_pattern = pattern
	_bit_depth = 8 if bit_depth <= 8 else 16
	_mono = mono
	_sample_rate = sample_rate
	_use_track_rate = use_track_rate
	_normalize = normalize
	_metadata = metadata.duplicate(true)
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_batch_to_directory"), false, "GAS batch export")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	completed = true
	_snapshot = null


func wait_to_finish() -> void:
	if task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
	completed = true
	_snapshot = null


func _prepare(snapshot: GASEditorModel, type: int) -> bool:
	if task_id >= 0 or snapshot == null:
		return false
	_snapshot = snapshot
	job_type = type
	output_path = ""
	error = OK
	wav_result = null
	completed = false
	files_exported = 0
	exported_paths = PackedStringArray()
	_slice_start = -1
	_slice_end = -1
	_set_progress(0.0)
	return true


func _worker_track_to_wav() -> void:
	_set_progress(0.02)
	var render_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.02, 0.88)
	var pcm: GASPCMData = _snapshot.render_track_with_progress(0, render_progress) if _snapshot != null else null
	if pcm == null or pcm.frame_count() <= 0:
		error = ERR_INVALID_DATA
		return
	_set_progress(0.92)
	wav_result = pcm.to_wav()
	if wav_result == null:
		error = ERR_CANT_CREATE
		return
	_set_progress(1.0)


func _worker_track_to_file() -> void:
	_set_progress(0.01)
	var render_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.01, 0.64)
	var pcm: GASPCMData = _snapshot.render_track_with_progress(0, render_progress) if _snapshot != null else null
	if pcm == null or pcm.frame_count() <= 0:
		error = ERR_INVALID_DATA
		return
	var export_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.65, 0.35)
	error = ExportEngine.save_wav(
		output_path,
		pcm,
		_mono,
		_sample_rate,
		_normalize,
		_bit_depth,
		_metadata,
		_loop_start,
		_loop_end,
		_loop_mode,
		export_progress
	)
	if error == OK:
		_set_progress(1.0)


func _worker_mix_to_file() -> void:
	_set_progress(0.01)
	var render_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.01, 0.64)
	var pcm: GASPCMData = _snapshot.mixdown_with_progress(render_progress) if _snapshot != null else null
	if pcm == null or pcm.frame_count() <= 0:
		error = ERR_INVALID_DATA
		return
	if _slice_start >= 0:
		var start_frame: int = clampi(_slice_start, 0, pcm.frame_count())
		var end_frame: int = clampi(_slice_end if _slice_end >= 0 else pcm.frame_count(), start_frame, pcm.frame_count())
		pcm = pcm.slice_frames(start_frame, end_frame)
	if pcm == null or pcm.frame_count() <= 0:
		error = ERR_INVALID_DATA
		return
	var export_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.65, 0.35)
	error = ExportEngine.save_wav(
		output_path,
		pcm,
		_mono,
		_sample_rate,
		_normalize,
		_bit_depth,
		_metadata,
		_loop_start,
		_loop_end,
		_loop_mode,
		export_progress
	)
	if error == OK:
		_set_progress(1.0)

func _worker_batch_to_directory() -> void:
	if _snapshot == null:
		error = ERR_INVALID_DATA
		return
	_set_progress(0.0)
	_batch_total_units = maxi(1, _count_batch_units())
	_batch_completed_units = 0
	var index: int = 1
	match _batch_mode:
		3:
			for clip_id: int in _batch_selected_clip_ids:
				var location: Vector2i = _snapshot.find_clip_location(clip_id)
				var clip: GASEditorClip = _snapshot.find_clip(clip_id)
				if clip == null or clip.pcm == null or location.x < 0 or location.x >= _snapshot.tracks.size():
					continue
				var track: GASEditorTrack = _snapshot.tracks[location.x]
				var pcm: GASPCMData = _clip_pcm_for_export(clip)
				var name: String = ExportEngine.apply_naming_pattern(_batch_pattern, track.name, "", index, clip.name)
				var rate: int = track.sample_rate if _use_track_rate else _sample_rate
				_save_batch_file(name, pcm, rate)
				index += 1
		4:
			for track: GASEditorTrack in _snapshot.tracks:
				for clip: GASEditorClip in track.clips:
					if clip.pcm == null:
						continue
					var pcm: GASPCMData = _clip_pcm_for_export(clip)
					var name: String = ExportEngine.apply_naming_pattern(_batch_pattern, track.name, "", index, clip.name)
					var rate: int = track.sample_rate if _use_track_rate else _sample_rate
					_save_batch_file(name, pcm, rate)
					index += 1
		5:
			for track_index: int in range(_snapshot.tracks.size()):
				var track: GASEditorTrack = _snapshot.tracks[track_index]
				var pcm: GASPCMData = _snapshot.render_track(track_index)
				if pcm == null:
					continue
				var name: String = ExportEngine.apply_naming_pattern(_batch_pattern, track.name, "", index)
				var rate: int = track.sample_rate if _use_track_rate else _sample_rate
				_save_batch_file(name, pcm, rate)
				index += 1
		6:
			var mix: GASPCMData = _snapshot.mixdown()
			if mix != null:
				for marker: Dictionary in _snapshot.markers:
					var region_start: int = int(marker.get("frame", 0))
					var region_end: int = int(marker.get("end_frame", region_start))
					if region_end <= region_start:
						continue
					var pcm: GASPCMData = mix.slice_frames(region_start, region_end)
					var name: String = ExportEngine.apply_naming_pattern(_batch_pattern, "mix", str(marker.get("name", "Region")), index)
					_save_batch_file(name, pcm, _sample_rate)
					index += 1
		_:
			error = ERR_INVALID_PARAMETER
	if error == OK and files_exported == 0:
		error = ERR_INVALID_DATA
	elif error == OK:
		_set_progress(1.0)


func _save_batch_file(name: String, pcm: GASPCMData, sample_rate: int) -> void:
	if pcm == null or pcm.frame_count() <= 0:
		_batch_completed_units += 1
		_set_progress(float(_batch_completed_units) / float(maxi(1, _batch_total_units)))
		return
	var path: String = output_path.path_join(name + ".wav")
	var base: float = float(_batch_completed_units) / float(maxi(1, _batch_total_units))
	var span: float = 1.0 / float(maxi(1, _batch_total_units))
	var file_progress: Callable = Callable(self, "_set_scaled_progress").bind(base, span)
	var save_error: Error = ExportEngine.save_wav(path, pcm, _mono, sample_rate, _normalize, _bit_depth, _metadata, 0, 0, AudioStreamWAV.LOOP_DISABLED, file_progress)
	_batch_completed_units += 1
	_set_progress(float(_batch_completed_units) / float(maxi(1, _batch_total_units)))
	if save_error == OK:
		files_exported += 1
		exported_paths.append(path)
	elif error == OK:
		error = save_error


func _count_batch_units() -> int:
	if _snapshot == null:
		return 0
	match _batch_mode:
		3:
			return _batch_selected_clip_ids.size()
		4:
			var clip_count: int = 0
			for track: GASEditorTrack in _snapshot.tracks:
				clip_count += track.clips.size()
			return clip_count
		5:
			return _snapshot.tracks.size()
		6:
			var region_count: int = 0
			for marker: Dictionary in _snapshot.markers:
				if int(marker.get("end_frame", int(marker.get("frame", 0)))) > int(marker.get("frame", 0)):
					region_count += 1
			return region_count
		_:
			return 0


func _clip_pcm_for_export(clip: GASEditorClip) -> GASPCMData:
	if clip == null or clip.pcm == null:
		return null
	var pcm: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
	if not clip.effect_stack.is_empty():
		pcm = EffectEngine.process_stack(pcm, clip.effect_stack)
	var gain: float = db_to_linear(clip.gain_db)
	var pan_value: float = clampf(clip.pan, -1.0, 1.0)
	var needs_stereo: bool = pcm.is_stereo() or absf(pan_value) > 0.0001
	if needs_stereo and not pcm.is_stereo():
		var stereo_pcm: GASPCMData = GASPCMData.new()
		stereo_pcm.sample_rate = pcm.sample_rate
		stereo_pcm.channels = 2
		stereo_pcm.left = pcm.left.duplicate()
		stereo_pcm.right = pcm.left.duplicate()
		pcm = stereo_pcm
	var left_pan: float = 1.0 if pan_value <= 0.0 else 1.0 - pan_value
	var right_pan: float = 1.0 if pan_value >= 0.0 else 1.0 + pan_value
	for frame: int in range(pcm.frame_count()):
		pcm.left[frame] = clampf(pcm.left[frame] * gain * left_pan, -1.0, 1.0)
		if pcm.is_stereo():
			pcm.right[frame] = clampf(pcm.right[frame] * gain * right_pan, -1.0, 1.0)
	return pcm

