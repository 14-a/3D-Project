@tool
class_name GASAnalyzerBackgroundJob
extends RefCounted

const AnalyzerEngine := preload("res://addons/gator_audio_studio/audio/analyzer_engine.gd")
const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")
const ExtensionAPI: GDScript = preload("res://addons/gator_audio_studio/audio/extension_api.gd")

const KIND_ANALYSIS: int = 1
const KIND_BEATS: int = 2
const KIND_LIVE: int = 3
const KIND_EXTENSION: int = 4

var task_id: int = -1
var kind: int = 0
var _mutex: Mutex = Mutex.new()
var _result: Dictionary = {}


func start_analysis(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, fft_size: int, window_type: int, min_hz: float, max_hz: float, log_scale: bool, include_spectrogram: bool) -> bool:
	if task_id >= 0 or snapshot == null:
		return false
	kind = KIND_ANALYSIS
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_analysis").bind(snapshot, use_mixdown, requested_start, requested_end, fft_size, window_type, min_hz, max_hz, log_scale, include_spectrogram), false, "GAS Audio Analysis")
	return task_id >= 0


func start_beats(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, threshold: float, spacing: float) -> bool:
	if task_id >= 0 or snapshot == null:
		return false
	kind = KIND_BEATS
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_beats").bind(snapshot, use_mixdown, requested_start, requested_end, threshold, spacing), false, "GAS Beat Detection")
	return task_id >= 0


func start_live(pcm_window: GASPCMData, fft_size: int, window_type: int) -> bool:
	if task_id >= 0 or pcm_window == null:
		return false
	kind = KIND_LIVE
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_live").bind(pcm_window, fft_size, window_type), false, "GAS Live Spectrum")
	return task_id >= 0


func start_extension(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, analyzer_id: StringName) -> bool:
	if task_id >= 0 or snapshot == null or str(analyzer_id).is_empty():
		return false
	kind = KIND_EXTENSION
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_extension").bind(snapshot, use_mixdown, requested_start, requested_end, analyzer_id), false, "GAS Extension Analyzer")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func finish() -> Dictionary:
	if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
		return {}
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	_mutex.lock()
	var result: Dictionary = _result
	_result = {}
	_mutex.unlock()
	return result


func _worker_analysis(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, fft_size: int, window_type: int, min_hz: float, max_hz: float, log_scale: bool, include_spectrogram: bool) -> void:
	var source: GASPCMData = snapshot.mixdown() if use_mixdown else snapshot.render_track(0)
	if source == null or source.frame_count() <= 0:
		_store({"error": "Analyzer could not render the selected audio source."})
		return
	var analysis_range: Vector2i = _analysis_range(source, requested_start, requested_end)
	if analysis_range.y <= analysis_range.x:
		_store({"error": "The active time selection contains no audio in this source."})
		return
	var analysis: Dictionary = AnalyzerEngine.analyze(source, analysis_range.x, analysis_range.y, fft_size, window_type)
	var result: Dictionary = {"analysis": analysis}
	if include_spectrogram:
		result["spectrogram"] = AnalyzerEngine.build_spectrogram(source, analysis_range.x, analysis_range.y, mini(4096, fft_size), window_type, min_hz, max_hz, 420, 192, log_scale)
	_store(result)


func _worker_beats(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, threshold: float, spacing: float) -> void:
	var source: GASPCMData = snapshot.mixdown() if use_mixdown else snapshot.render_track(0)
	if source == null or source.frame_count() <= 0:
		_store({"error": "Beat detection could not render the selected audio source."})
		return
	var analysis_range: Vector2i = _analysis_range(source, requested_start, requested_end)
	if analysis_range.y <= analysis_range.x:
		_store({"error": "The active time selection contains no audio in this source."})
		return
	_store(AnalyzerEngine.detect_beats(source, analysis_range.x, analysis_range.y, threshold, spacing))


func _worker_live(pcm_window: GASPCMData, fft_size: int, window_type: int) -> void:
	if pcm_window == null or pcm_window.frame_count() <= 0:
		_store({})
		return
	_store(FFTEngine.averaged_spectrum(pcm_window, 0, pcm_window.frame_count(), fft_size, window_type, 1))


func _worker_extension(snapshot: GASEditorModel, use_mixdown: bool, requested_start: int, requested_end: int, analyzer_id: StringName) -> void:
	var source: GASPCMData = snapshot.mixdown() if use_mixdown else snapshot.render_track(0)
	if source == null or source.frame_count() <= 0:
		_store({"error": "Extension analyzer could not render the selected audio source."})
		return
	var analysis_range: Vector2i = _analysis_range(source, requested_start, requested_end)
	if analysis_range.y <= analysis_range.x:
		_store({"error": "The active time selection contains no audio in this source."})
		return
	var analyzer: GASAnalyzerExtension = ExtensionAPI.create_analyzer_extension(analyzer_id)
	if analyzer == null:
		_store({"error": "The selected extension analyzer is no longer registered."})
		return
	var custom_result: Dictionary = analyzer.analyze(source, analysis_range.x, analysis_range.y)
	_store({"extension_id": str(analyzer_id), "extension_result": custom_result})


func _analysis_range(source: GASPCMData, requested_start: int, requested_end: int) -> Vector2i:
	if requested_start >= 0 and requested_end >= 0:
		var start_frame: int = clampi(requested_start, 0, source.frame_count())
		var end_frame: int = clampi(requested_end, start_frame, source.frame_count())
		return Vector2i(start_frame, end_frame)
	return Vector2i(0, source.frame_count())


func _store(result: Dictionary) -> void:
	_mutex.lock()
	_result = result
	_mutex.unlock()
