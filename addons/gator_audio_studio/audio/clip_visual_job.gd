@tool
class_name GASClipVisualJob
extends RefCounted

const AnalyzerEngine := preload("res://addons/gator_audio_studio/audio/analyzer_engine.gd")
const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")

const TYPE_NONE: int = 0
const TYPE_WAVEFORM_CACHE: int = 1
const TYPE_SPECTROGRAM: int = 2
const PAGED_PCM_THRESHOLD_FRAMES: int = 4_000_000

var task_id: int = -1
var job_type: int = TYPE_NONE
var clip_id: int = 0
var source_pcm: GASPCMData
var source_path: String = ""
var source_start_frame: int = 0
var source_end_frame: int = 0
var cache_result: GASWaveformCache
var paged_store_result: GASPagedPCMStore
var paged_cache_path_result: String = ""
var spectrogram_bytes: PackedByteArray = PackedByteArray()
var spectrogram_columns: int = 0
var spectrogram_rows: int = 0
var failed: bool = false


func start_waveform_cache(id: int, pcm: GASPCMData, path: String) -> bool:
	if task_id >= 0 or pcm == null:
		return false
	clip_id = id
	source_pcm = pcm
	source_path = path
	source_start_frame = 0
	source_end_frame = pcm.frame_count()
	job_type = TYPE_WAVEFORM_CACHE
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_waveform_cache"), false, "GAS waveform cache")
	return task_id >= 0


func start_spectrogram(id: int, pcm: GASPCMData, start_frame: int, end_frame: int) -> bool:
	if task_id >= 0 or pcm == null:
		return false
	clip_id = id
	source_pcm = pcm
	source_path = ""
	source_start_frame = clampi(start_frame, 0, pcm.frame_count())
	source_end_frame = clampi(end_frame, source_start_frame, pcm.frame_count())
	job_type = TYPE_SPECTROGRAM
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_spectrogram"), false, "GAS clip spectrogram")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1


func _worker_waveform_cache() -> void:
	var pcm: GASPCMData = source_pcm
	if pcm == null or pcm.frame_count() <= 0:
		failed = true
		return
	var built_cache: GASWaveformCache = GASWaveformCache.new()
	if pcm.frame_count() >= PAGED_PCM_THRESHOLD_FRAMES and _can_use_paged_cache(source_path):
		var cache_dir: String = "user://gator_audio_studio/pcm_cache"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
		var source_key: int = absi(source_path.hash())
		var cache_path: String = cache_dir.path_join("clip_%d_%d_%d.gaspcm" % [clip_id, source_key, pcm.frame_count()])
		var store: GASPagedPCMStore = GASPagedPCMStore.new()
		var create_error: Error = store.create_from_pcm(pcm, cache_path)
		if create_error == OK and built_cache.build_from_paged(store):
			cache_result = built_cache
			paged_store_result = store
			paged_cache_path_result = cache_path
			return
	built_cache.build(pcm)
	cache_result = built_cache


func _worker_spectrogram() -> void:
	var pcm: GASPCMData = source_pcm
	if pcm == null or source_end_frame <= source_start_frame:
		failed = true
		return
	var nyquist: float = float(maxi(1, pcm.sample_rate)) * 0.5
	var data: Dictionary = AnalyzerEngine.build_spectrogram(
		pcm,
		source_start_frame,
		source_end_frame,
		512,
		FFTEngine.WINDOW_HANN,
		20.0,
		minf(20000.0, nyquist),
		112,
		56,
		true
	)
	var columns: int = int(data.get("columns", 0))
	var rows: int = int(data.get("rows", 0))
	var values_value: Variant = data.get("values", PackedFloat32Array())
	var values: PackedFloat32Array = values_value as PackedFloat32Array
	if columns <= 0 or rows <= 0 or values.size() < columns * rows:
		failed = true
		return
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(columns * rows * 4)
	for row: int in range(rows):
		var image_y: int = rows - 1 - row
		var row_source: int = row * columns
		var row_dest: int = image_y * columns * 4
		for column: int in range(columns):
			var db_value: float = values[row_source + column]
			var t: float = clampf((db_value + 90.0) / 90.0, 0.0, 1.0)
			var r: float = 0.0
			var g: float = 0.0
			var b: float = 0.0
			if t < 0.33:
				var segment_a: float = t / 0.33
				r = 0.03
				g = 0.04 + segment_a * 0.12
				b = 0.10 + segment_a * 0.38
			elif t < 0.66:
				var segment_b: float = (t - 0.33) / 0.33
				r = 0.03 + segment_b * 0.45
				g = 0.16 + segment_b * 0.48
				b = 0.48 + segment_b * 0.10
			else:
				var segment_c: float = (t - 0.66) / 0.34
				r = 0.48 + segment_c * 0.48
				g = 0.64 + segment_c * 0.28
				b = 0.58 - segment_c * 0.42
			var offset: int = row_dest + column * 4
			bytes[offset] = clampi(int(round(r * 255.0)), 0, 255)
			bytes[offset + 1] = clampi(int(round(g * 255.0)), 0, 255)
			bytes[offset + 2] = clampi(int(round(b * 255.0)), 0, 255)
			bytes[offset + 3] = 245
	spectrogram_columns = columns
	spectrogram_rows = rows
	spectrogram_bytes = bytes


static func _can_use_paged_cache(path: String) -> bool:
	return not path.begins_with("generated://") and not path.begins_with("effect://") and not path.begins_with("clipboard://")
