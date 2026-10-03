@tool
class_name GASAdvancedBackgroundJob
extends RefCounted

const SpectralEditEngine := preload("res://addons/gator_audio_studio/audio/spectral_edit_engine.gd")
const LoopEngine := preload("res://addons/gator_audio_studio/audio/loop_engine.gd")
const MacroEngine := preload("res://addons/gator_audio_studio/audio/macro_engine.gd")
const AssetOptimizer := preload("res://addons/gator_audio_studio/audio/asset_optimizer.gd")
const RestorationEngine := preload("res://addons/gator_audio_studio/audio/restoration_engine.gd")
const AdvancedEffectsEngine := preload("res://addons/gator_audio_studio/audio/advanced_effects_engine.gd")
const ExportEngine := preload("res://addons/gator_audio_studio/audio/export_engine.gd")

var task_id: int = -1
var _mutex: Mutex = Mutex.new()
var _result: Dictionary = {}
var _progress: float = 0.0
var _cancel_requested: bool = false


func start(task: Callable, description: String) -> void:
	if task_id >= 0:
		return
	_mutex.lock()
	_result.clear()
	_progress = 0.0
	_cancel_requested = false
	_mutex.unlock()
	task_id = WorkerThreadPool.add_task(task, false, "GAS " + description)


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func finish() -> Dictionary:
	if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
		return {}
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	_mutex.lock()
	var finished: Dictionary = _result.duplicate(false)
	_result.clear()
	_mutex.unlock()
	return finished


func progress() -> float:
	_mutex.lock()
	var value: float = _progress
	_mutex.unlock()
	return value


func cancel() -> void:
	_mutex.lock()
	_cancel_requested = true
	_mutex.unlock()


func is_cancel_requested() -> bool:
	_mutex.lock()
	var value: bool = _cancel_requested
	_mutex.unlock()
	return value


func _set_progress(value: float) -> void:
	_mutex.lock()
	_progress = clampf(value, 0.0, 1.0)
	_mutex.unlock()


func _set_scaled_progress(value: float, base: float, span: float) -> void:
	_set_progress(base + clampf(value, 0.0, 1.0) * span)


func _store_result(result: Dictionary) -> void:
	_mutex.lock()
	_result = result
	_progress = 1.0
	_mutex.unlock()


func _region(snapshot: GASEditorModel, dry: bool, requested_start: int, requested_end: int) -> Dictionary:
	if snapshot == null:
		return {}
	var source: GASPCMData = snapshot.render_track_dry(0) if dry else snapshot.render_track(0)
	if source == null or source.frame_count() <= 0:
		return {}
	var start_frame: int = clampi(requested_start, 0, source.frame_count())
	var end_frame: int = source.frame_count() if requested_end < 0 else clampi(requested_end, start_frame, source.frame_count())
	if end_frame <= start_frame:
		return {}
	return {"region": source.slice_frames(start_frame, end_frame), "start": start_frame, "end": end_frame}


func spectral(snapshot: GASEditorModel, start_frame: int, end_frame: int, low_hz: float, high_hz: float, action: String, amount_db: float, fft_size: int) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, true, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.15, 0.85)
	var processed: GASPCMData = SpectralEditEngine.process_region(region, 0, region.frame_count(), low_hz, high_hz, action, amount_db, fft_size, progress_callback)
	_store_result({"processed": processed, "start_frame": int(info.get("start", 0)), "end_frame": int(info.get("end", 0))})


func noise_profile(snapshot: GASEditorModel, start_frame: int, end_frame: int, fft_size: int) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, true, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"profile": {}})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.15, 0.85)
	var profile: Dictionary = RestorationEngine.capture_noise_profile(region, 0, region.frame_count(), fft_size, progress_callback)
	_store_result({"profile": profile, "duration": region.duration_seconds()})


func noise_reduce(snapshot: GASEditorModel, start_frame: int, end_frame: int, profile: Dictionary, reduction: float, sensitivity: float, smoothing_bins: int, floor_db: float) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, true, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.15, 0.85)
	var processed: GASPCMData = RestorationEngine.reduce_noise(region, profile, reduction, sensitivity, smoothing_bins, floor_db, progress_callback)
	_store_result({"processed": processed, "start_frame": int(info.get("start", 0)), "end_frame": int(info.get("end", 0))})


func stretch(snapshot: GASEditorModel, start_frame: int, end_frame: int, factor: float, extreme: bool) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, false, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.15, 0.85)
	var processed: GASPCMData = RestorationEngine.time_stretch(region, factor, extreme, progress_callback)
	_store_result({"processed": processed, "start_frame": int(info.get("start", 0)), "end_frame": int(info.get("end", 0))})


func curve_eq(snapshot: GASEditorModel, start_frame: int, end_frame: int, gains: PackedFloat32Array) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, false, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.15, 0.85)
	var processed: GASPCMData = AdvancedEffectsEngine.filter_curve_eq(region, gains, progress_callback)
	_store_result({"processed": processed, "start_frame": int(info.get("start", 0)), "end_frame": int(info.get("end", 0))})


func auto_duck(target_snapshot: GASEditorModel, source_snapshot: GASEditorModel, start_frame: int, end_frame: int, threshold_db: float, reduction_db: float, attack_ms: float, release_ms: float) -> void:
	_set_progress(0.05)
	var target_info: Dictionary = _region(target_snapshot, false, start_frame, end_frame)
	var source_info: Dictionary = _region(source_snapshot, false, start_frame, end_frame)
	var target: GASPCMData = target_info.get("region") as GASPCMData
	var control: GASPCMData = source_info.get("region") as GASPCMData
	if target == null or control == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.20, 0.80)
	var processed: GASPCMData = AdvancedEffectsEngine.auto_duck(target, control, threshold_db, reduction_db, attack_ms, release_ms, progress_callback)
	_store_result({"processed": processed, "start_frame": int(target_info.get("start", 0)), "end_frame": int(target_info.get("end", 0))})


func vocoder(modulator_snapshot: GASEditorModel, carrier_snapshot: GASEditorModel, start_frame: int, end_frame: int, bands: int, attack_ms: float, release_ms: float) -> void:
	_set_progress(0.05)
	var modulator_info: Dictionary = _region(modulator_snapshot, false, start_frame, end_frame)
	var carrier_info: Dictionary = _region(carrier_snapshot, false, start_frame, end_frame)
	var modulator: GASPCMData = modulator_info.get("region") as GASPCMData
	var carrier: GASPCMData = carrier_info.get("region") as GASPCMData
	if modulator == null or carrier == null:
		_store_result({"processed": null})
		return
	var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.20, 0.80)
	var processed: GASPCMData = AdvancedEffectsEngine.vocoder(modulator, carrier, bands, attack_ms, release_ms, progress_callback)
	_store_result({"processed": processed, "start_frame": int(modulator_info.get("start", 0)), "end_frame": int(modulator_info.get("end", 0))})


func restore_clicks(snapshot: GASEditorModel, start_frame: int, end_frame: int) -> void:
	_set_progress(0.05)
	var info: Dictionary = _region(snapshot, true, start_frame, end_frame)
	var region: GASPCMData = info.get("region") as GASPCMData
	if region == null:
		_store_result({"processed": null})
		return
	_set_progress(0.20)
	var processed: GASPCMData = RestorationEngine.repair_clicks(region, 0.35, 3)
	_store_result({"processed": processed, "start_frame": int(info.get("start", 0)), "end_frame": int(info.get("end", 0))})


func loop_crossfade(snapshot: GASEditorModel, loop_start: int, loop_end: int, crossfade_frames: int) -> void:
	_set_progress(0.10)
	var source: GASPCMData = snapshot.render_track_dry(0) if snapshot != null else null
	if source == null or source.frame_count() <= 0:
		_store_result({"processed": null})
		return
	_set_progress(0.45)
	var processed: GASPCMData = LoopEngine.crossfade_loop(source, loop_start, loop_end, crossfade_frames)
	_store_result({"processed": processed, "original_frames": source.frame_count()})


func loop_find(snapshot: GASEditorModel, loop_start: int, loop_end: int, radius: int, count: int) -> void:
	_set_progress(0.10)
	var source: GASPCMData = snapshot.render_track_dry(0) if snapshot != null else null
	if source == null or source.frame_count() <= 0:
		_store_result({"candidates": []})
		return
	_set_progress(0.35)
	var candidates: Array[Dictionary] = LoopEngine.find_candidates(source, loop_start, loop_end, radius, count)
	_store_result({"candidates": candidates})


func loop_preview(snapshot: GASEditorModel, requested_start: int, requested_end: int, loop_mode: int) -> void:
	_set_progress(0.10)
	var source: GASPCMData = snapshot.render_track(0) if snapshot != null else null
	if source == null:
		_store_result({"wav": null})
		return
	var start_frame: int = clampi(requested_start, 0, maxi(0, source.frame_count() - 1))
	var end_frame: int = clampi(requested_end, start_frame + 1, source.frame_count())
	_set_progress(0.55)
	var wav: AudioStreamWAV = source.to_wav()
	if wav != null:
		LoopEngine.apply_loop_metadata(wav, start_frame, end_frame, loop_mode)
	_store_result({"wav": wav, "start_seconds": float(start_frame) / float(maxi(1, source.sample_rate))})


func macro_track(snapshot: GASEditorModel, steps: Array[Dictionary]) -> void:
	_set_progress(0.05)
	var source: GASPCMData = snapshot.render_track_dry(0) if snapshot != null else null
	if source == null or source.frame_count() <= 0:
		_store_result({"processed": null})
		return
	_set_progress(0.30)
	var processed: GASPCMData = MacroEngine.apply_steps(source, steps)
	_store_result({"processed": processed, "original_frames": source.frame_count()})


func compare_capture(snapshot: GASEditorModel) -> void:
	_set_progress(0.10)
	var original: GASPCMData = snapshot.render_track_dry(0) if snapshot != null else null
	_set_progress(0.55)
	var edited: GASPCMData = snapshot.render_track(0) if snapshot != null else null
	_store_result({"original": original, "edited": edited})


func optimizer_track(snapshot: GASEditorModel, source_name: String) -> void:
	_set_progress(0.10)
	var source: GASPCMData = snapshot.render_track(0) if snapshot != null else null
	if source == null:
		_store_result({"analysis": {}})
		return
	_set_progress(0.25)
	var analysis_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.25, 0.75)
	_store_result({"analysis": AssetOptimizer.analyze_pcm(source, source_name, analysis_progress)})


func optimizer_mix(snapshot: GASEditorModel) -> void:
	_set_progress(0.10)
	var source: GASPCMData = snapshot.mixdown() if snapshot != null else null
	if source == null:
		_store_result({"analysis": {}})
		return
	_set_progress(0.25)
	var analysis_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.25, 0.75)
	_store_result({"analysis": AssetOptimizer.analyze_pcm(source, "Mixdown", analysis_progress)})


func optimizer_resample(snapshot: GASEditorModel, low_rate: int, project_rate: int) -> void:
	_set_progress(0.05)
	var pcm: GASPCMData = snapshot.render_track(0) if snapshot != null else null
	if pcm == null or pcm.frame_count() <= 0:
		_store_result({"processed": null, "original_frames": 0})
		return
	var original_frames: int = pcm.frame_count()
	var down_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.25, 0.30)
	var reduced: GASPCMData = pcm.resample_to_rate(low_rate, down_progress)
	var up_progress: Callable = Callable(self, "_set_scaled_progress").bind(0.55, 0.45)
	var restored_rate: GASPCMData = reduced.resample_to_rate(project_rate, up_progress) if reduced != null else null
	_store_result({"processed": restored_rate, "original_frames": original_frames})


func optimizer_mono(snapshot: GASEditorModel) -> void:
	_set_progress(0.05)
	var pcm: GASPCMData = snapshot.render_track(0) if snapshot != null else null
	if pcm == null or pcm.frame_count() <= 0:
		_store_result({"processed": null, "original_frames": 0})
		return
	var original_frames: int = pcm.frame_count()
	_set_progress(0.35)
	var processed: GASPCMData = pcm.force_mono()
	_store_result({"processed": processed, "original_frames": original_frames})


func macro_batch(paths: PackedStringArray, output_dir: String, steps: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var count: int = 0
	var total: int = maxi(1, paths.size())
	for index: int in range(paths.size()):
		if is_cancel_requested():
			_store_result({"cancelled": true, "count": count, "total": paths.size(), "output_dir": output_dir})
			return
		var path: String = paths[index]
		if path.get_extension().to_lower() == "wav":
			var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
			var pcm: GASPCMData = GASPCMData.from_wav(wav)
			if pcm != null:
				var edited: GASPCMData = MacroEngine.apply_steps(pcm, steps)
				if edited != null:
					var output_path: String = output_dir.path_join(path.get_file())
					if ExportEngine.save_wav(output_path, edited, false, edited.sample_rate, false, 16) == OK:
						count += 1
		_set_progress(float(index + 1) / float(total))
	_store_result({"count": count, "total": paths.size(), "output_dir": output_dir})


func optimizer_folder(folder: String, fix: bool) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		_store_result({"error": "Could not open optimization folder."})
		return
	var names: PackedStringArray = PackedStringArray()
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.to_lower().ends_with(".wav"):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	var total: int = maxi(1, names.size())
	if fix:
		var output_dir: String = folder.path_join("gas_optimized")
		DirAccess.make_dir_recursive_absolute(output_dir)
		var processed: int = 0
		var changed: int = 0
		for index: int in range(names.size()):
			if is_cancel_requested():
				_store_result({"cancelled": true, "processed": processed, "changed": changed, "output_dir": output_dir})
				return
			var file_name: String = names[index]
			var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(folder.path_join(file_name))
			var pcm: GASPCMData = GASPCMData.from_wav(wav)
			if pcm != null:
				var analysis: Dictionary = AssetOptimizer.analyze_pcm(pcm, file_name)
				var optimized: GASPCMData = pcm.duplicate_pcm()
				var did_change: bool = false
				if optimized.is_stereo() and float(analysis.get("stereo_difference", 1.0)) < 0.015:
					optimized = optimized.force_mono()
					did_change = true
				if float(analysis.get("silence_ratio", 0.0)) > 0.20:
					optimized = _trim_silence(optimized, -55.0)
					did_change = true
				if optimized.sample_rate > 44100:
					optimized = optimized.resample_to_rate(44100)
					did_change = true
				if ExportEngine.save_wav(output_dir.path_join(file_name), optimized, false, optimized.sample_rate, false, 16) == OK:
					processed += 1
					if did_change:
						changed += 1
			_set_progress(float(index + 1) / float(total))
		_store_result({"processed": processed, "changed": changed, "output_dir": output_dir, "fix": true})
		return
	var report: String = "[b]Batch Game Audio Scan[/b]\n"
	var count: int = 0
	for index: int in range(names.size()):
		if is_cancel_requested():
			_store_result({"cancelled": true, "report": report, "count": count})
			return
		var file_name: String = names[index]
		var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(folder.path_join(file_name))
		var pcm: GASPCMData = GASPCMData.from_wav(wav)
		if pcm != null:
			var analysis: Dictionary = AssetOptimizer.analyze_pcm(pcm, file_name)
			var recs: PackedStringArray = analysis.get("recommendations", PackedStringArray()) as PackedStringArray
			report += "\n[b]%s[/b] — %.2fs, %d Hz, %dch" % [file_name, float(analysis.get("duration", 0.0)), int(analysis.get("sample_rate", 0)), int(analysis.get("channels", 1))]
			for rec: String in recs:
				report += "\n  • %s" % rec
			count += 1
		_set_progress(float(index + 1) / float(total))
	_store_result({"report": report + "\n\nScanned %d WAV files." % count, "count": count, "fix": false})


func _trim_silence(pcm: GASPCMData, threshold_db: float) -> GASPCMData:
	if pcm == null or pcm.frame_count() <= 0:
		return pcm
	var threshold: float = db_to_linear(threshold_db)
	var start_frame: int = 0
	var end_frame: int = pcm.frame_count()
	var stereo: bool = pcm.is_stereo()
	while start_frame < end_frame:
		var value: float = absf(pcm.left[start_frame])
		if stereo:
			value = maxf(value, absf(pcm.right[start_frame]))
		if value > threshold:
			break
		start_frame += 1
	while end_frame > start_frame:
		var index: int = end_frame - 1
		var value: float = absf(pcm.left[index])
		if stereo:
			value = maxf(value, absf(pcm.right[index]))
		if value > threshold:
			break
		end_frame -= 1
	return pcm.slice_frames(start_frame, end_frame)


func compare_prepare(original: GASPCMData, edited: GASPCMData, mode: int) -> void:
	if original == null or edited == null:
		_store_result({"wav": null})
		return
	_set_progress(0.05)
	var out: GASPCMData
	if mode == 0:
		out = original
	elif mode == 1:
		var a_rms: float = _rms(original)
		var b_rms: float = _rms(edited)
		out = original.duplicate_pcm()
		var gain: float = b_rms / maxf(0.000001, a_rms)
		var out_left: PackedFloat32Array = out.left
		var out_right: PackedFloat32Array = out.right
		var stereo: bool = out.is_stereo()
		var count: int = out.frame_count()
		for i: int in range(count):
			out_left[i] *= gain
			if stereo:
				out_right[i] *= gain
			if (i & 16383) == 0:
				_set_progress(0.10 + 0.65 * float(i) / float(maxi(1, count)))
	else:
		var count: int = mini(original.frame_count(), edited.frame_count())
		var stereo: bool = original.is_stereo() or edited.is_stereo()
		out = GASPCMData.new()
		out.sample_rate = edited.sample_rate
		out.channels = 2 if stereo else 1
		out.left.resize(count)
		if stereo:
			out.right.resize(count)
		var original_left: PackedFloat32Array = original.left
		var original_right: PackedFloat32Array = original.right
		var edited_left: PackedFloat32Array = edited.left
		var edited_right: PackedFloat32Array = edited.right
		var original_stereo: bool = original.is_stereo()
		var edited_stereo: bool = edited.is_stereo()
		for i: int in range(count):
			var al: float = original_left[i]
			var ar: float = original_right[i] if original_stereo else al
			var bl: float = edited_left[i]
			var br: float = edited_right[i] if edited_stereo else bl
			out.left[i] = clampf(bl - al, -1.0, 1.0)
			if stereo:
				out.right[i] = clampf(br - ar, -1.0, 1.0)
			if (i & 16383) == 0:
				_set_progress(0.10 + 0.65 * float(i) / float(maxi(1, count)))
	_set_progress(0.80)
	var wav: AudioStreamWAV = out.to_wav() if out != null else null
	_store_result({"wav": wav})


func _rms(pcm: GASPCMData) -> float:
	var sum: float = 0.0
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	for value: float in left:
		sum += value * value
	if pcm.is_stereo():
		for value: float in right:
			sum += value * value
	var divisor: int = pcm.frame_count() * (2 if pcm.is_stereo() else 1)
	return sqrt(sum / float(maxi(1, divisor)))


func project_audio_scan(root: String) -> void:
	var paths: PackedStringArray = PackedStringArray()
	_scan_audio_directory(root, paths)
	paths.sort()
	var entries: Array[Dictionary] = []
	var total: int = maxi(1, paths.size())
	for index: int in range(paths.size()):
		if is_cancel_requested():
			_store_result({"cancelled": true, "entries": entries})
			return
		var path: String = paths[index]
		var entry: Dictionary = {"path": path, "bytes": _file_size(path), "extension": path.get_extension().to_lower()}
		if str(entry["extension"]) == "wav":
			var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
			var pcm: GASPCMData = GASPCMData.from_wav(wav)
			if pcm != null:
				entry["duration"] = pcm.duration_seconds()
				entry["rate"] = pcm.sample_rate
				entry["channels"] = pcm.channels
				entry["thumbnail_rgba"] = _wav_thumbnail_rgba(wav, 112, 28)
		entries.append(entry)
		_set_progress(float(index + 1) / float(total))
	_store_result({"entries": entries})


func _scan_audio_directory(path: String, paths: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child: String = path.path_join(entry)
			if dir.current_is_dir():
				if entry != ".godot" and not entry.begins_with("."):
					_scan_audio_directory(child, paths)
			else:
				var extension: String = entry.get_extension().to_lower()
				if extension == "wav" or extension == "mp3" or extension == "ogg":
					paths.append(child)
		entry = dir.get_next()
	dir.list_dir_end()


func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length: int = file.get_length()
	file.close()
	return length


func _wav_thumbnail_rgba(wav: AudioStreamWAV, width: int, height: int) -> PackedByteArray:
	var rgba: PackedByteArray = PackedByteArray()
	rgba.resize(width * height * 4)
	# Opaque dark background.
	for pixel: int in range(width * height):
		var base: int = pixel * 4
		rgba[base] = 14
		rgba[base + 1] = 17
		rgba[base + 2] = 20
		rgba[base + 3] = 255
	if wav == null or (wav.format != AudioStreamWAV.FORMAT_8_BITS and wav.format != AudioStreamWAV.FORMAT_16_BITS):
		return rgba
	var channels: int = 2 if wav.stereo else 1
	var bytes_per_sample: int = 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var bytes_per_frame: int = bytes_per_sample * channels
	var frames: int = int(wav.data.size() / maxi(1, bytes_per_frame))
	if frames <= 0:
		return rgba
	var center: int = height / 2
	for x: int in range(width):
		var start_frame: int = int(float(frames) * float(x) / float(width))
		var end_frame: int = maxi(start_frame + 1, int(float(frames) * float(x + 1) / float(width)))
		var step: int = maxi(1, int((end_frame - start_frame) / 48))
		var lo: float = 1.0
		var hi: float = -1.0
		var frame: int = start_frame
		while frame < end_frame and frame < frames:
			var offset: int = frame * bytes_per_frame
			var sample: float = 0.0
			if wav.format == AudioStreamWAV.FORMAT_16_BITS:
				sample = float(wav.data.decode_s16(offset)) / 32768.0
			else:
				var byte_value: int = int(wav.data[offset])
				if byte_value > 127:
					byte_value -= 256
				sample = float(byte_value) / 128.0
			lo = minf(lo, sample)
			hi = maxf(hi, sample)
			frame += step
		var y0: int = clampi(center - int(round(hi * float(center - 1))), 0, height - 1)
		var y1: int = clampi(center - int(round(lo * float(center - 1))), 0, height - 1)
		for y: int in range(mini(y0, y1), maxi(y0, y1) + 1):
			var pixel_base: int = (y * width + x) * 4
			rgba[pixel_base] = 107
			rgba[pixel_base + 1] = 209
			rgba[pixel_base + 2] = 235
			rgba[pixel_base + 3] = 255
	return rgba


func project_audio_load_wav(path: String, target_rate: int) -> void:
	_set_progress(0.10)
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
	var pcm: GASPCMData = GASPCMData.from_wav(wav)
	if pcm == null:
		_store_result({"pcm": null, "path": path})
		return
	_set_progress(0.45)
	if target_rate > 0 and pcm.sample_rate != target_rate:
		var progress_callback: Callable = Callable(self, "_set_scaled_progress").bind(0.45, 0.50)
		pcm = pcm.resample_to_rate(target_rate, progress_callback)
	_store_result({"pcm": pcm, "path": path})
