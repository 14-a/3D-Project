@tool
class_name GASGeneratorExportJob
extends RefCounted

const ExportEngine := preload("res://addons/gator_audio_studio/audio/export_engine.gd")
const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")

var task_id: int = -1
var exported_paths: PackedStringArray = PackedStringArray()
var exported_count: int = 0
var _mutex: Mutex = Mutex.new()


func start(results: Array[Dictionary], output_dir: String, filenames: PackedStringArray) -> bool:
	if task_id >= 0 or results.is_empty():
		return false
	var safe_results: Array[Dictionary] = results.duplicate(false)
	var safe_names: PackedStringArray = filenames
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker").bind(safe_results, output_dir, safe_names), false, "GAS generated WAV export")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func finish() -> PackedStringArray:
	if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
		return PackedStringArray()
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	_mutex.lock()
	var paths: PackedStringArray = exported_paths.duplicate()
	_mutex.unlock()
	return paths


func _worker(results: Array[Dictionary], output_dir: String, filenames: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var paths: PackedStringArray = PackedStringArray()
	var count: int = mini(results.size(), filenames.size())
	for index: int in range(count):
		var result: Dictionary = results[index]
		var source_wav: AudioStreamWAV = result.get("stream") as AudioStreamWAV
		if source_wav == null:
			continue
		var pcm: GASPCMData = PCMData.from_wav(source_wav)
		if pcm == null:
			continue
		var params: Dictionary = result.get("params", {}) as Dictionary
		var tags: Dictionary = {
			"title": str(params.get("category", "Generated Sound")),
			"artist": "Gator Audio Studio",
			"comment": "Profile=%s; Seed=%d; Accuracy=%s" % [str(params.get("profile", "Modern")), int(params.get("seed", 0)), str(params.get("accuracy_mode", "Style"))],
		}
		var path: String = output_dir.path_join(filenames[index])
		var bit_depth: int = 8 if source_wav.format == AudioStreamWAV.FORMAT_8_BITS else 16
		if ExportEngine.save_wav(path, pcm, false, source_wav.mix_rate, false, bit_depth, tags, source_wav.loop_begin, source_wav.loop_end, source_wav.loop_mode) != OK:
			continue
		_write_sidecar(path, params)
		paths.append(path)
	_mutex.lock()
	exported_paths = paths
	exported_count = paths.size()
	_mutex.unlock()


func _write_sidecar(wav_path: String, params: Dictionary) -> void:
	var layers_value: Variant = params.get("layers", [])
	var layer_count: int = (layers_value as Array).size() if layers_value is Array else 0
	var metadata: Dictionary = {
		"gator_audio_studio": "1.0.0",
		"profile": str(params.get("profile", "Modern")),
		"category": str(params.get("category", "Generated")),
		"seed": int(params.get("seed", 0)),
		"accuracy_mode": str(params.get("accuracy_mode", "Style")),
		"layer_count": layer_count,
		"generated_at": Time.get_datetime_string_from_system(),
		"source_wav": wav_path.get_file(),
	}
	var meta_path: String = wav_path.get_basename() + ".gasmeta.json"
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata, "\t"))
		file.close()
