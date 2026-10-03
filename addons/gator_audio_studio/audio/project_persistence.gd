@tool
class_name GASProjectPersistence
extends RefCounted

const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const CompressedAudioDecoder := preload("res://addons/gator_audio_studio/audio/compressed_audio_decoder.gd")
const EditorModel := preload("res://addons/gator_audio_studio/audio/editor_model.gd")
const EditorTrack := preload("res://addons/gator_audio_studio/audio/editor_track.gd")
const EditorClip := preload("res://addons/gator_audio_studio/audio/editor_clip.gd")
const EffectData := preload("res://addons/gator_audio_studio/audio/effect_data.gd")

const FORMAT_NAME: String = "Gator Audio Studio Project"
const FORMAT_VERSION: int = 2
const MIN_SUPPORTED_FORMAT_VERSION: int = 1
const APP_VERSION: String = "1.0.0"
const PROJECT_EXTENSION: String = ".gasproj"
const DATA_SUFFIX: String = ".gasdata"
const RECOVERY_ROOT: String = "user://gator_audio_studio/recovery"
const RECOVERY_MANIFEST: String = "user://gator_audio_studio/recovery/latest_recovery.json"


static func normalize_project_path(path: String) -> String:
	var clean: String = path.strip_edges()
	if clean.is_empty():
		return clean
	if not clean.to_lower().ends_with(PROJECT_EXTENSION):
		clean += PROJECT_EXTENSION
	return clean


static func canonical_source_path(path: String) -> String:
	if path.is_empty() or _is_virtual_source(path):
		return path
	var absolute: String = _global_path(path)
	var localized: String = ProjectSettings.localize_path(absolute)
	if localized.begins_with("res://"):
		return localized
	return absolute


static func source_exists(path: String) -> bool:
	if path.is_empty() or _is_virtual_source(path):
		return true
	return FileAccess.file_exists(_global_path(path))


static func save_project(
	path: String,
	model: GASEditorModel,
	project_settings: Dictionary,
	editor_state: Dictionary,
	generator_state: Dictionary,
	workspace_state: Dictionary,
	source_project_path: String = "",
	is_autosave: bool = false
) -> Dictionary:
	if model == null:
		return {"ok": false, "error": "Editor model is unavailable."}
	var normalized: String = normalize_project_path(path)
	if normalized.is_empty():
		return {"ok": false, "error": "Project path is empty."}
	var global_project: String = _global_path(normalized)
	var project_dir: String = global_project.get_base_dir()
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(project_dir)
	if mkdir_error != OK:
		return {"ok": false, "error": "Could not create project folder: %s" % error_string(mkdir_error)}
	var data_dir: String = _data_dir_for_global_project(global_project)
	var data_error: Error = DirAccess.make_dir_recursive_absolute(data_dir.path_join("audio"))
	if data_error != OK:
		return {"ok": false, "error": "Could not create project audio cache: %s" % error_string(data_error)}
	DirAccess.make_dir_recursive_absolute(data_dir.path_join("generator"))
	DirAccess.make_dir_recursive_absolute(data_dir.path_join("generated_bin"))
	_ensure_gdignore(data_dir)

	# Every save writes new sidecar filenames and only removes the previous set after
	# the .gasproj commit succeeds. This keeps the last committed project fully valid
	# if a sidecar or JSON write is interrupted.
	var save_serial: String = "%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var pcm_paths: Dictionary = {}
	var used_audio_files: Dictionary = {}
	var pcm_counter: Array[int] = [0]
	var serialized_tracks: Array[Dictionary] = []
	for track: GASEditorTrack in model.tracks:
		var track_data: Dictionary = _serialize_track(track, data_dir, pcm_paths, used_audio_files, save_serial, pcm_counter)
		if bool(track_data.get("save_failed", false)):
			return {"ok": false, "error": str(track_data.get("error", "Could not cache project audio."))}
		serialized_tracks.append(track_data)

	var safe_editor_state: Dictionary = editor_state.duplicate(true)
	var used_generated_files: Dictionary = {}
	var bin_result: Dictionary = _externalize_generated_bin(safe_editor_state, data_dir, save_serial, used_generated_files)
	if not bool(bin_result.get("ok", false)):
		return bin_result

	var safe_generator_state: Dictionary = generator_state.duplicate(true)
	var generator_counter: Array[int] = [0]
	var used_generator_files: Dictionary = {}
	var generator_result: Dictionary = _externalize_generator_samples(safe_generator_state, data_dir, generator_counter, save_serial, used_generator_files)
	if not bool(generator_result.get("ok", false)):
		return generator_result

	var model_data: Dictionary = {
		"sample_rate": model.sample_rate,
		"selected_track": model.selected_track,
		"selected_track_indices": _packed_int_to_array(model.selected_track_indices),
		"selected_clip_ids": _packed_int_to_array(model.selected_clip_ids),
		"cursor_frame": model.cursor_frame,
		"selection_start": model.selection_start,
		"selection_end": model.selection_end,
		"markers": _json_safe(model.markers),
		"master_gain_db": model.master_gain_db,
		"master_effect_stack": _serialize_effect_stack(model.master_effect_stack),
		"master_limiter_enabled": model.master_limiter_enabled,
		"master_limiter_ceiling_db": model.master_limiter_ceiling_db,
		"project_bpm": model.project_bpm,
		"time_signature_numerator": model.time_signature_numerator,
		"time_signature_denominator": model.time_signature_denominator,
		"playback_speed": model.playback_speed,
		"metadata": _json_safe(model.metadata),
		"loop_start_frame": model.loop_start_frame,
		"loop_end_frame": model.loop_end_frame,
		"loop_mode": model.loop_mode,
		"grid_snap_mode": model.grid_snap_mode,
		"frame_rate": model.frame_rate,
		"shortcut_overrides": _json_safe(model.shortcut_overrides),
		"accessibility_settings": _json_safe(model.accessibility_settings),
		"next_clip_id": model.next_clip_id_for_persistence(),
		"tracks": serialized_tracks,
	}
	var source_path: String = source_project_path
	if source_path.is_empty() and not is_autosave:
		source_path = normalized
	var root: Dictionary = {
		"format": FORMAT_NAME,
		"format_version": FORMAT_VERSION,
		"saved_with": APP_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"autosave": is_autosave,
		"source_project_path": source_path,
		"project_settings": _json_safe(project_settings),
		"editor_state": _json_safe(safe_editor_state),
		"workspace_state": _json_safe(workspace_state),
		"generator_state": _json_safe(safe_generator_state),
		"model": model_data,
	}
	# Commit the JSON atomically. Sidecar audio is written first, so a failed save never
	# replaces the last valid .gasproj with a partially-written document.
	var temp_project: String = global_project + ".tmp"
	var file: FileAccess = FileAccess.open(temp_project, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not open project file for writing: %s" % normalized}
	file.store_string(JSON.stringify(root, "\t"))
	file.close()
	var commit_error: Error = DirAccess.rename_absolute(temp_project, global_project)
	if commit_error != OK:
		if FileAccess.file_exists(temp_project):
			DirAccess.remove_absolute(temp_project)
		return {"ok": false, "error": "Could not commit project file: %s" % error_string(commit_error)}
	_cleanup_unused_wav_files(data_dir.path_join("audio"), used_audio_files)
	_cleanup_unused_wav_files(data_dir.path_join("generated_bin"), used_generated_files)
	_cleanup_unused_wav_files(data_dir.path_join("generator"), used_generator_files)
	return {"ok": true, "path": normalized, "global_path": global_project, "data_dir": data_dir}


static func load_project(path: String) -> Dictionary:
	var normalized: String = normalize_project_path(path)
	var global_project: String = _global_path(normalized)
	if not FileAccess.file_exists(global_project):
		return {"ok": false, "error": "Project file does not exist: %s" % normalized}
	var file: FileAccess = FileAccess.open(global_project, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not open project file: %s" % normalized}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "Project file is not valid JSON."}
	var root: Dictionary = parsed as Dictionary
	if str(root.get("format", "")) != FORMAT_NAME:
		return {"ok": false, "error": "This is not a Gator Audio Studio project."}
	var version: int = int(root.get("format_version", 0))
	if version < MIN_SUPPORTED_FORMAT_VERSION or version > FORMAT_VERSION:
		return {"ok": false, "error": "Unsupported .gasproj version: %d" % version}
	if version < FORMAT_VERSION:
		root = _migrate_project_root(root, version)
		version = int(root.get("format_version", version))
	var model_value: Variant = root.get("model", {})
	if not (model_value is Dictionary):
		return {"ok": false, "error": "Project model data is missing."}
	var model_data: Dictionary = model_value as Dictionary
	var model: GASEditorModel = EditorModel.new() as GASEditorModel
	model.sample_rate = maxi(1, int(model_data.get("sample_rate", 44100)))
	var data_dir: String = _data_dir_for_global_project(global_project)
	var missing_map: Dictionary = {}
	var pcm_cache: Dictionary = {}
	var tracks_value: Variant = model_data.get("tracks", [])
	if tracks_value is Array:
		var track_array: Array = tracks_value as Array
		for track_value: Variant in track_array:
			if not (track_value is Dictionary):
				continue
			var loaded_track: GASEditorTrack = _deserialize_track(track_value as Dictionary, model.sample_rate, data_dir, pcm_cache, missing_map)
			model.tracks.append(loaded_track)
	var migrated_next_clip_id: int = _upgrade_legacy_compressed_reference_tracks(model, int(model_data.get("next_clip_id", 1)))
	model.selected_track = clampi(int(model_data.get("selected_track", -1)), -1, model.tracks.size() - 1)
	model.selected_track_indices = _array_to_packed_int(model_data.get("selected_track_indices", [model.selected_track] if model.selected_track >= 0 else []))
	model.sanitize_track_selection()
	model.selected_clip_ids = _array_to_packed_int(model_data.get("selected_clip_ids", []))
	model.cursor_frame = maxi(0, int(model_data.get("cursor_frame", 0)))
	model.selection_start = maxi(0, int(model_data.get("selection_start", model.cursor_frame)))
	model.selection_end = maxi(model.selection_start, int(model_data.get("selection_end", model.selection_start)))
	model.markers = _dictionary_array_copy(model_data.get("markers", []))
	model.master_gain_db = float(model_data.get("master_gain_db", 0.0))
	model.master_effect_stack = _deserialize_effect_stack(model_data.get("master_effect_stack", []))
	model.master_limiter_enabled = bool(model_data.get("master_limiter_enabled", true))
	model.master_limiter_ceiling_db = float(model_data.get("master_limiter_ceiling_db", -1.0))
	model.project_bpm = float(model_data.get("project_bpm", 120.0))
	model.time_signature_numerator = maxi(1, int(model_data.get("time_signature_numerator", 4)))
	model.time_signature_denominator = maxi(1, int(model_data.get("time_signature_denominator", 4)))
	model.playback_speed = clampf(float(model_data.get("playback_speed", 1.0)), 0.25, 4.0)
	model.metadata = _dictionary_copy(model_data.get("metadata", {}))
	model.loop_start_frame = maxi(0, int(model_data.get("loop_start_frame", 0)))
	model.loop_end_frame = maxi(model.loop_start_frame, int(model_data.get("loop_end_frame", model.loop_start_frame)))
	model.loop_mode = int(model_data.get("loop_mode", AudioStreamWAV.LOOP_DISABLED))
	model.grid_snap_mode = str(model_data.get("grid_snap_mode", "Clips"))
	model.frame_rate = maxf(1.0, float(model_data.get("frame_rate", 30.0)))
	model.shortcut_overrides = _dictionary_copy(model_data.get("shortcut_overrides", {}))
	model.accessibility_settings = _dictionary_copy(model_data.get("accessibility_settings", {"ui_scale": 1.0, "high_contrast": false, "strong_focus": true, "meter_text": true}))
	model.finalize_project_load(maxi(migrated_next_clip_id, int(model_data.get("next_clip_id", _max_clip_id(model) + 1))))
	var offline_clip_count: int = 0
	for loaded_track: GASEditorTrack in model.tracks:
		for loaded_clip: GASEditorClip in loaded_track.clips:
			if loaded_clip.pcm == null and loaded_clip.frame_count() > 0:
				offline_clip_count += 1

	var editor_state: Dictionary = _dictionary_copy(root.get("editor_state", {}))
	_rehydrate_generated_bin(editor_state, data_dir)
	var generator_state: Dictionary = _dictionary_copy(root.get("generator_state", {}))
	_rehydrate_generator_samples(generator_state, data_dir)
	var missing_sources: Array[Dictionary] = []
	for missing_key: Variant in missing_map.keys():
		var missing_path: String = str(missing_key)
		missing_sources.append({
			"source_path": missing_path,
			"clip_count": int(missing_map[missing_key]),
		})
	missing_sources.sort_custom(_missing_source_less_than)
	return {
		"ok": true,
		"path": normalized,
		"model": model,
		"project_settings": _dictionary_copy(root.get("project_settings", {})),
		"editor_state": editor_state,
		"workspace_state": _dictionary_copy(root.get("workspace_state", {})),
		"generator_state": generator_state,
		"missing_sources": missing_sources,
		"offline_clip_count": offline_clip_count,
		"is_autosave": bool(root.get("autosave", false)),
		"source_project_path": str(root.get("source_project_path", "")),
		"saved_at_unix": int(root.get("saved_at_unix", 0)),
		"format_version": version,
		"migrated_from_version": int(root.get("migrated_from_version", 0)),
	}


static func _migrate_project_root(source: Dictionary, from_version: int) -> Dictionary:
	var root: Dictionary = source.duplicate(true)
	var version: int = from_version
	var original_version: int = from_version
	while version < FORMAT_VERSION:
		match version:
			1:
				root = _migrate_v1_to_v2(root)
				version = 2
			_:
				break
	root["format_version"] = version
	if original_version != version:
		root["migrated_from_version"] = original_version
	return root


static func _migrate_v1_to_v2(source: Dictionary) -> Dictionary:
	var root: Dictionary = source.duplicate(true)
	var model_data: Dictionary = _dictionary_copy(root.get("model", {}))
	model_data["project_bpm"] = float(model_data.get("project_bpm", 120.0))
	model_data["time_signature_numerator"] = maxi(1, int(model_data.get("time_signature_numerator", 4)))
	model_data["time_signature_denominator"] = maxi(1, int(model_data.get("time_signature_denominator", 4)))
	model_data["playback_speed"] = clampf(float(model_data.get("playback_speed", 1.0)), 0.25, 4.0)
	model_data["metadata"] = _dictionary_copy(model_data.get("metadata", {}))
	model_data["loop_start_frame"] = maxi(0, int(model_data.get("loop_start_frame", 0)))
	model_data["loop_end_frame"] = maxi(int(model_data.get("loop_start_frame", 0)), int(model_data.get("loop_end_frame", model_data.get("loop_start_frame", 0))))
	model_data["loop_mode"] = int(model_data.get("loop_mode", AudioStreamWAV.LOOP_DISABLED))
	model_data["grid_snap_mode"] = str(model_data.get("grid_snap_mode", "Clips"))
	model_data["frame_rate"] = maxf(1.0, float(model_data.get("frame_rate", 30.0)))
	var tracks_value: Variant = model_data.get("tracks", [])
	if tracks_value is Array:
		var migrated_tracks: Array[Dictionary] = []
		var source_tracks: Array = tracks_value as Array
		for track_value: Variant in source_tracks:
			if not (track_value is Dictionary):
				continue
			var track_data: Dictionary = (track_value as Dictionary).duplicate(true)
			track_data["track_type"] = int(track_data.get("track_type", GASEditorTrack.TYPE_AUDIO))
			track_data["color"] = str(track_data.get("color", "347ac7"))
			track_data["channel_mode"] = int(track_data.get("channel_mode", GASEditorTrack.CHANNEL_AUTO))
			track_data["collapsed"] = bool(track_data.get("collapsed", false))
			track_data["sync_group"] = maxi(0, int(track_data.get("sync_group", 0)))
			track_data["automation_lanes"] = _dictionary_copy(track_data.get("automation_lanes", {}))
			track_data["generated_settings"] = _dictionary_copy(track_data.get("generated_settings", {}))
			track_data["reference_read_only"] = bool(track_data.get("reference_read_only", false))
			migrated_tracks.append(track_data)
		model_data["tracks"] = migrated_tracks
	root["model"] = model_data
	var editor_state: Dictionary = _dictionary_copy(root.get("editor_state", {}))
	editor_state["time_base_mode"] = str(editor_state.get("time_base_mode", "Seconds"))
	editor_state["sample_draw"] = bool(editor_state.get("sample_draw", false))
	editor_state["scrub"] = bool(editor_state.get("scrub", false))
	editor_state["transport_loop"] = bool(editor_state.get("transport_loop", false))
	editor_state["spectral_low_hz"] = maxf(0.0, float(editor_state.get("spectral_low_hz", 0.0)))
	editor_state["spectral_high_hz"] = maxf(float(editor_state["spectral_low_hz"]), float(editor_state.get("spectral_high_hz", 0.0)))
	root["editor_state"] = editor_state
	root["format_version"] = 2
	return root


static func _missing_source_less_than(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("source_path", "")) < str(b.get("source_path", ""))


static func relink_source(model: GASEditorModel, old_path: String, new_path: String) -> Dictionary:
	if model == null:
		return {"ok": false, "error": "Editor model is unavailable."}
	var canonical_new: String = canonical_source_path(new_path)
	var replacement: GASPCMData = _load_audio_pcm(canonical_new, model.sample_rate)
	if replacement == null:
		return {"ok": false, "error": "Replacement must be a supported WAV, MP3 or Ogg Vorbis audio file."}
	var count: int = 0
	for track: GASEditorTrack in model.tracks:
		for clip: GASEditorClip in track.clips:
			if clip.source_path != old_path:
				continue
			clip.source_path = canonical_new
			clip.source_missing = false
			if clip.pcm == null:
				clip.pcm = replacement
				clip.source_start_frame = clampi(clip.source_start_frame, 0, replacement.frame_count())
				if clip.source_end_frame < 0:
					clip.source_end_frame = replacement.frame_count()
				else:
					clip.source_end_frame = clampi(clip.source_end_frame, clip.source_start_frame, replacement.frame_count())
				clip.offline_frame_count = clip.frame_count()
				clip.rebuild_cache()
			count += 1
	if count > 0:
		model.dirty = true
	return {"ok": count > 0, "count": count, "path": canonical_new, "error": "No clips referenced that source." if count == 0 else ""}


static func current_missing_sources(model: GASEditorModel) -> Array[Dictionary]:
	var counts: Dictionary = {}
	if model == null:
		var empty_result: Array[Dictionary] = []
		return empty_result
	for track: GASEditorTrack in model.tracks:
		for clip: GASEditorClip in track.clips:
			if clip.source_path.is_empty() or _is_virtual_source(clip.source_path):
				continue
			clip.source_missing = not source_exists(clip.source_path)
			if clip.source_missing:
				counts[clip.source_path] = int(counts.get(clip.source_path, 0)) + 1
	var result: Array[Dictionary] = []
	for key: Variant in counts.keys():
		result.append({"source_path": str(key), "clip_count": int(counts[key])})
	return result


static func search_for_filename(folder: String, filename: String, max_depth: int = 6) -> String:
	var global_folder: String = _global_path(folder)
	if not DirAccess.dir_exists_absolute(global_folder):
		return ""
	return _search_folder_recursive(global_folder, filename, 0, maxi(0, max_depth))


static func autosave_path(source_project_path: String) -> String:
	var source: String = source_project_path if not source_project_path.is_empty() else "untitled"
	var name: String = source.get_file().get_basename()
	if name.is_empty():
		name = "untitled"
	name = _safe_filename(name)
	var hash_value: int = absi(source.hash())
	var serial: int = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_ROOT))
	# Each checkpoint gets its own project/data pair. The manifest is switched only after
	# the new checkpoint commits, so a crash during autosave leaves the previous recovery valid.
	return RECOVERY_ROOT.path_join("%s_%d_%d.autosave%s" % [name, hash_value, serial, PROJECT_EXTENSION])


static func write_recovery_manifest(autosave_project_path: String, source_project_path: String, project_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECOVERY_ROOT))
	var data: Dictionary = {
		"autosave_path": autosave_project_path,
		"source_project_path": source_project_path,
		"project_name": project_name,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
	}
	var global_manifest: String = ProjectSettings.globalize_path(RECOVERY_MANIFEST)
	var temp_manifest: String = global_manifest + ".tmp"
	var file: FileAccess = FileAccess.open(temp_manifest, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		var commit_error: Error = DirAccess.rename_absolute(temp_manifest, global_manifest)
		if commit_error != OK:
			if FileAccess.file_exists(temp_manifest):
				DirAccess.remove_absolute(temp_manifest)
			return
		_cleanup_recovery_orphans(autosave_project_path)


static func read_recovery_manifest() -> Dictionary:
	if not FileAccess.file_exists(RECOVERY_MANIFEST):
		return {}
	var file: FileAccess = FileAccess.open(RECOVERY_MANIFEST, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed as Dictionary
	var autosave: String = str(data.get("autosave_path", ""))
	if autosave.is_empty() or not FileAccess.file_exists(_global_path(autosave)):
		return {}
	return data


static func clear_recovery() -> void:
	if FileAccess.file_exists(RECOVERY_MANIFEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECOVERY_MANIFEST))
	_cleanup_recovery_orphans("")


static func _cleanup_recovery_orphans(keep_project_path: String) -> void:
	var root_global: String = ProjectSettings.globalize_path(RECOVERY_ROOT)
	var keep_global: String = _global_path(keep_project_path) if not keep_project_path.is_empty() else ""
	var dir: DirAccess = DirAccess.open(root_global)
	if dir == null:
		return
	var files_to_remove: Array[String] = []
	var data_dirs_to_remove: Array[String] = []
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var is_directory: bool = dir.current_is_dir()
		if not is_directory and name.ends_with(".autosave" + PROJECT_EXTENSION):
			var candidate: String = root_global.path_join(name)
			if keep_global.is_empty() or candidate != keep_global:
				files_to_remove.append(candidate)
				data_dirs_to_remove.append(_data_dir_for_global_project(candidate))
		elif not is_directory and name.ends_with(".tmp"):
			files_to_remove.append(root_global.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	for file_path: String in files_to_remove:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	for data_dir: String in data_dirs_to_remove:
		_remove_tree(data_dir)


static func _ensure_gdignore(data_dir: String) -> void:
	var ignore_path: String = data_dir.path_join(".gdignore")
	if FileAccess.file_exists(ignore_path):
		return
	var ignore_file: FileAccess = FileAccess.open(ignore_path, FileAccess.WRITE)
	if ignore_file != null:
		ignore_file.close()


static func _serialize_track(track: GASEditorTrack, data_dir: String, pcm_paths: Dictionary, used_audio_files: Dictionary, save_serial: String, pcm_counter: Array[int]) -> Dictionary:
	var clips: Array[Dictionary] = []
	for clip: GASEditorClip in track.clips:
		var clip_data: Dictionary = _serialize_clip(clip, data_dir, pcm_paths, used_audio_files, save_serial, pcm_counter)
		if bool(clip_data.get("save_failed", false)):
			return clip_data
		clips.append(clip_data)
	return {
		"name": track.name,
		"track_type": track.track_type,
		"color": track.color.to_html(),
		"channel_mode": track.channel_mode,
		"collapsed": track.collapsed,
		"sync_group": track.sync_group,
		"automation_lanes": _json_safe(track.automation_lanes),
		"generated_settings": _json_safe(track.generated_settings),
		"reference_read_only": track.reference_read_only,
		"gain_db": track.gain_db,
		"pan": track.pan,
		"mute": track.mute,
		"solo": track.solo,
		"locked": track.locked,
		"record_armed": track.record_armed,
		"output_bus": track.output_bus,
		"send_bus": track.send_bus,
		"send_db": track.send_db,
		"display_mode": track.display_mode,
		"sample_rate": track.sample_rate,
		"waveform_stereo_mode": track.waveform_stereo_mode,
		"waveform_amplitude_mode": track.waveform_amplitude_mode,
		"show_zero_line": track.show_zero_line,
		"show_clipping": track.show_clipping,
		"effect_stack": _serialize_effect_stack(track.effect_stack),
		"clips": clips,
	}


static func _serialize_clip(clip: GASEditorClip, data_dir: String, pcm_paths: Dictionary, used_audio_files: Dictionary, save_serial: String, pcm_counter: Array[int]) -> Dictionary:
	var pcm_ref: String = ""
	var frame_count: int = clip.frame_count()
	var pcm_rate: int = 0
	var pcm_channels: int = 0
	if clip.pcm != null:
		pcm_rate = clip.pcm.sample_rate
		pcm_channels = clip.pcm.channels
		# Clean imported sources are reconstructible from source_path and should not
		# be rewritten as song-sized WAV sidecars on every save/autosave/deactivation.
		# Virtual/edited/generated/recorded audio still receives a recovery sidecar.
		if _clip_requires_pcm_cache(clip):
			var object_id: int = clip.pcm.get_instance_id()
			if pcm_paths.has(object_id):
				pcm_ref = str(pcm_paths[object_id])
			else:
				pcm_counter[0] += 1
				pcm_ref = "audio/pcm_%s_%03d.wav" % [save_serial, pcm_counter[0]]
				var global_pcm: String = data_dir.path_join(pcm_ref)
				var save_error: Error = clip.pcm.to_wav().save_to_wav(global_pcm)
				if save_error != OK:
					return {"save_failed": true, "error": "Could not cache clip '%s': %s" % [clip.name, error_string(save_error)]}
				pcm_paths[object_id] = pcm_ref
			used_audio_files[pcm_ref.get_file()] = true
	return {
		"clip_id": clip.clip_id,
		"name": clip.name,
		"source_path": clip.source_path,
		"timeline_start": clip.timeline_start,
		"source_start_frame": clip.source_start_frame,
		"source_end_frame": clip.source_end_frame,
		"gain_db": clip.gain_db,
		"pan": clip.pan,
		"muted": clip.muted,
		"fade_in_samples": clip.fade_in_samples,
		"fade_out_samples": clip.fade_out_samples,
		"fade_curve": clip.fade_curve,
		"effect_stack": _serialize_effect_stack(clip.effect_stack),
		"pcm_ref": pcm_ref,
		"pcm_frame_count": frame_count,
		"pcm_sample_rate": pcm_rate,
		"pcm_channels": pcm_channels,
	}


static func _clip_requires_pcm_cache(clip: GASEditorClip) -> bool:
	if clip == null or clip.pcm == null:
		return false
	if clip.source_path.is_empty() or _is_virtual_source(clip.source_path):
		return true
	return not source_exists(clip.source_path)


static func _upgrade_legacy_compressed_reference_tracks(model: GASEditorModel, next_clip_id: int) -> int:
	var next_id: int = maxi(1, next_clip_id)
	for track: GASEditorTrack in model.tracks:
		if track.track_type != GASEditorTrack.TYPE_REFERENCE or not track.clips.is_empty():
			continue
		var source_path: String = str(track.generated_settings.get("compressed_reference_path", ""))
		if source_path.is_empty() or not CompressedAudioDecoder.is_compressed_path(source_path) or not source_exists(source_path):
			continue
		var pcm: GASPCMData = _load_audio_pcm(source_path, model.sample_rate)
		if pcm == null or pcm.frame_count() <= 0:
			continue
		var clip: GASEditorClip = EditorClip.new() as GASEditorClip
		clip.clip_id = next_id
		next_id += 1
		clip.name = track.name
		clip.source_path = source_path
		clip.timeline_start = 0
		clip.pcm = pcm
		clip.source_start_frame = 0
		clip.source_end_frame = pcm.frame_count()
		clip.offline_frame_count = pcm.frame_count()
		clip.rebuild_cache()
		track.track_type = GASEditorTrack.TYPE_AUDIO
		track.reference_read_only = false
		track.locked = false
		track.sample_rate = pcm.sample_rate
		track.clips.append(clip)
		track.generated_settings.erase("compressed_reference_path")
		track.generated_settings.erase("duration_seconds")
		track.generated_settings.erase("format")
	return next_id


static func _deserialize_track(data: Dictionary, project_rate: int, data_dir: String, pcm_cache: Dictionary, missing_map: Dictionary) -> GASEditorTrack:
	var track: GASEditorTrack = EditorTrack.new() as GASEditorTrack
	track.name = str(data.get("name", "Audio Track"))
	track.track_type = clampi(int(data.get("track_type", GASEditorTrack.TYPE_AUDIO)), GASEditorTrack.TYPE_AUDIO, GASEditorTrack.TYPE_REFERENCE)
	track.color = Color.from_string(str(data.get("color", "347ac7")), Color(0.20, 0.48, 0.78, 1.0))
	track.channel_mode = clampi(int(data.get("channel_mode", GASEditorTrack.CHANNEL_AUTO)), GASEditorTrack.CHANNEL_AUTO, GASEditorTrack.CHANNEL_STEREO)
	track.collapsed = bool(data.get("collapsed", false))
	track.sync_group = maxi(0, int(data.get("sync_group", 0)))
	track.automation_lanes = _dictionary_copy(data.get("automation_lanes", {}))
	track.generated_settings = _dictionary_copy(data.get("generated_settings", {}))
	track.reference_read_only = bool(data.get("reference_read_only", track.track_type == GASEditorTrack.TYPE_REFERENCE))
	track.gain_db = float(data.get("gain_db", 0.0))
	track.pan = float(data.get("pan", 0.0))
	track.mute = bool(data.get("mute", false))
	track.solo = bool(data.get("solo", false))
	track.locked = bool(data.get("locked", false))
	track.record_armed = bool(data.get("record_armed", false))
	track.output_bus = str(data.get("output_bus", "Master"))
	track.send_bus = str(data.get("send_bus", ""))
	track.send_db = float(data.get("send_db", -12.0))
	track.display_mode = clampi(int(data.get("display_mode", 0)), GASEditorTrack.DISPLAY_WAVEFORM, GASEditorTrack.DISPLAY_COMBINED)
	track.sample_rate = maxi(1, int(data.get("sample_rate", project_rate)))
	track.waveform_stereo_mode = clampi(int(data.get("waveform_stereo_mode", GASEditorTrack.WAVEFORM_SPLIT_STEREO)), GASEditorTrack.WAVEFORM_SPLIT_STEREO, GASEditorTrack.WAVEFORM_COMBINED_STEREO)
	track.waveform_amplitude_mode = clampi(int(data.get("waveform_amplitude_mode", GASEditorTrack.AMPLITUDE_LINEAR)), GASEditorTrack.AMPLITUDE_LINEAR, GASEditorTrack.AMPLITUDE_DB)
	track.show_zero_line = bool(data.get("show_zero_line", true))
	track.show_clipping = bool(data.get("show_clipping", true))
	track.effect_stack = _deserialize_effect_stack(data.get("effect_stack", []))
	var clips_value: Variant = data.get("clips", [])
	if clips_value is Array:
		var clip_array: Array = clips_value as Array
		for clip_value: Variant in clip_array:
			if clip_value is Dictionary:
				track.clips.append(_deserialize_clip(clip_value as Dictionary, project_rate, data_dir, pcm_cache, missing_map))
	return track


static func _deserialize_clip(data: Dictionary, project_rate: int, data_dir: String, pcm_cache: Dictionary, missing_map: Dictionary) -> GASEditorClip:
	var clip: GASEditorClip = EditorClip.new() as GASEditorClip
	clip.clip_id = int(data.get("clip_id", 0))
	clip.name = str(data.get("name", "Clip"))
	clip.source_path = str(data.get("source_path", ""))
	clip.timeline_start = maxi(0, int(data.get("timeline_start", 0)))
	clip.source_start_frame = maxi(0, int(data.get("source_start_frame", 0)))
	clip.source_end_frame = int(data.get("source_end_frame", -1))
	clip.gain_db = float(data.get("gain_db", 0.0))
	clip.pan = float(data.get("pan", 0.0))
	clip.muted = bool(data.get("muted", false))
	clip.fade_in_samples = maxi(0, int(data.get("fade_in_samples", 0)))
	clip.fade_out_samples = maxi(0, int(data.get("fade_out_samples", 0)))
	clip.fade_curve = clampi(int(data.get("fade_curve", 0)), 0, 4)
	clip.effect_stack = _deserialize_effect_stack(data.get("effect_stack", []))
	clip.offline_frame_count = maxi(0, int(data.get("pcm_frame_count", 0)))
	var source_is_missing: bool = not clip.source_path.is_empty() and not _is_virtual_source(clip.source_path) and not source_exists(clip.source_path)
	clip.source_missing = source_is_missing
	if source_is_missing:
		missing_map[clip.source_path] = int(missing_map.get(clip.source_path, 0)) + 1
	var pcm_ref: String = str(data.get("pcm_ref", ""))
	var pcm: GASPCMData = null
	if not pcm_ref.is_empty():
		var global_cache: String = data_dir.path_join(pcm_ref)
		if FileAccess.file_exists(global_cache):
			var cache_key: String = "cache:" + global_cache
			if pcm_cache.has(cache_key):
				pcm = pcm_cache[cache_key] as GASPCMData
			else:
				pcm = _load_wav_pcm(global_cache)
				if pcm != null:
					pcm_cache[cache_key] = pcm
	if pcm == null and not source_is_missing and not clip.source_path.is_empty() and not _is_virtual_source(clip.source_path):
		var source_key: String = "source:" + clip.source_path
		if pcm_cache.has(source_key):
			pcm = pcm_cache[source_key] as GASPCMData
		else:
			pcm = _load_audio_pcm(clip.source_path, project_rate)
			if pcm != null:
				pcm_cache[source_key] = pcm
	clip.pcm = pcm
	if clip.pcm != null:
		clip.offline_frame_count = clip.frame_count()
		clip.rebuild_cache()
	return clip


static func _serialize_effect_stack(stack: Array[GASEffectData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect: GASEffectData in stack:
		result.append({
			"effect_type": effect.effect_type,
			"enabled": effect.enabled,
			"wet": effect.wet,
			"preset_name": effect.preset_name,
			"params": _json_safe(effect.params),
		})
	return result


static func _deserialize_effect_stack(value: Variant) -> Array[GASEffectData]:
	var result: Array[GASEffectData] = []
	if not (value is Array):
		return result
	var source_array: Array = value as Array
	for item: Variant in source_array:
		if not (item is Dictionary):
			continue
		var data: Dictionary = item as Dictionary
		var effect: GASEffectData = EffectData.new() as GASEffectData
		effect.effect_type = str(data.get("effect_type", "Amplify"))
		effect.enabled = bool(data.get("enabled", true))
		effect.wet = clampf(float(data.get("wet", 1.0)), 0.0, 1.0)
		effect.preset_name = str(data.get("preset_name", "Default"))
		effect.params = _dictionary_copy(data.get("params", {}))
		result.append(effect)
	return result


static func _externalize_generated_bin(editor_state: Dictionary, data_dir: String, save_serial: String, used_files: Dictionary) -> Dictionary:
	var value: Variant = editor_state.get("generated_bin", [])
	if not (value is Array):
		return {"ok": true}
	var clean_entries: Array[Dictionary] = []
	var index: int = 0
	var source_array: Array = value as Array
	for item: Variant in source_array:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item as Dictionary
		var wav: AudioStreamWAV = entry.get("wav") as AudioStreamWAV
		if wav == null:
			continue
		index += 1
		var ref: String = "generated_bin/bin_%s_%03d.wav" % [save_serial, index]
		var error: Error = wav.save_to_wav(data_dir.path_join(ref))
		if error != OK:
			return {"ok": false, "error": "Could not save generated-bin audio: %s" % error_string(error)}
		used_files[ref.get_file()] = true
		clean_entries.append({"name": str(entry.get("name", "Generated")), "cache_ref": ref})
	editor_state["generated_bin"] = clean_entries
	return {"ok": true}


static func _rehydrate_generated_bin(editor_state: Dictionary, data_dir: String) -> void:
	var value: Variant = editor_state.get("generated_bin", [])
	if not (value is Array):
		return
	var restored: Array[Dictionary] = []
	var source_array: Array = value as Array
	for item: Variant in source_array:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item as Dictionary
		var ref: String = str(entry.get("cache_ref", ""))
		if ref.is_empty():
			continue
		var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(data_dir.path_join(ref))
		if wav != null:
			restored.append({"name": str(entry.get("name", "Generated")), "wav": wav})
	editor_state["generated_bin"] = restored


static func _externalize_generator_samples(value: Variant, data_dir: String, counter: Array[int], save_serial: String, used_files: Dictionary) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		if dictionary.has("sample_data"):
			var samples: PackedFloat32Array = _to_float_array(dictionary.get("sample_data", []))
			if not samples.is_empty():
				counter[0] += 1
				var rate: int = maxi(1, int(dictionary.get("sample_source_rate", 44100)))
				var pcm: GASPCMData = PCMData.new() as GASPCMData
				pcm.sample_rate = rate
				pcm.channels = 1
				pcm.left = samples
				var ref: String = "generator/sample_%s_%03d.wav" % [save_serial, counter[0]]
				var save_error: Error = pcm.to_wav().save_to_wav(data_dir.path_join(ref))
				if save_error != OK:
					return {"ok": false, "error": "Could not save generator sample source: %s" % error_string(save_error)}
				used_files[ref.get_file()] = true
				dictionary["sample_data"] = []
				dictionary["sample_cache_ref"] = ref
		var keys: Array = dictionary.keys()
		for key: Variant in keys:
			var child: Variant = dictionary[key]
			if child is Dictionary or child is Array:
				var child_result: Dictionary = _externalize_generator_samples(child, data_dir, counter, save_serial, used_files)
				if not bool(child_result.get("ok", false)):
					return child_result
	elif value is Array:
		var source_array: Array = value as Array
		for child_value: Variant in source_array:
			if child_value is Dictionary or child_value is Array:
				var child_result: Dictionary = _externalize_generator_samples(child_value, data_dir, counter, save_serial, used_files)
				if not bool(child_result.get("ok", false)):
					return child_result
	return {"ok": true}


static func _rehydrate_generator_samples(value: Variant, data_dir: String) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		var ref: String = str(dictionary.get("sample_cache_ref", ""))
		if not ref.is_empty():
			var pcm: GASPCMData = _load_wav_pcm(data_dir.path_join(ref))
			if pcm != null:
				dictionary["sample_data"] = Array(pcm.left)
				dictionary["sample_source_rate"] = pcm.sample_rate
		var keys: Array = dictionary.keys()
		for key: Variant in keys:
			var child: Variant = dictionary[key]
			if child is Dictionary or child is Array:
				_rehydrate_generator_samples(child, data_dir)
	elif value is Array:
		var source_array: Array = value as Array
		for child_value: Variant in source_array:
			if child_value is Dictionary or child_value is Array:
				_rehydrate_generator_samples(child_value, data_dir)


static func _json_safe(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	if value is Dictionary:
		var result_dict: Dictionary = {}
		var source_dict: Dictionary = value as Dictionary
		for key: Variant in source_dict.keys():
			var child: Variant = source_dict[key]
			if child is Object:
				continue
			result_dict[str(key)] = _json_safe(child)
		return result_dict
	if value is Array:
		var result_array: Array = []
		var source_array: Array = value as Array
		for child: Variant in source_array:
			if child is Object:
				continue
			result_array.append(_json_safe(child))
		return result_array
	if value is PackedFloat32Array:
		return Array(value as PackedFloat32Array)
	if value is PackedFloat64Array:
		return Array(value as PackedFloat64Array)
	if value is PackedInt32Array:
		return Array(value as PackedInt32Array)
	if value is PackedInt64Array:
		return Array(value as PackedInt64Array)
	if value is PackedByteArray:
		return Array(value as PackedByteArray)
	if value is PackedStringArray:
		return Array(value as PackedStringArray)
	if value is Vector2:
		var vector2: Vector2 = value as Vector2
		return {"__type": "Vector2", "x": vector2.x, "y": vector2.y}
	if value is Vector2i:
		var vector2i: Vector2i = value as Vector2i
		return {"__type": "Vector2i", "x": vector2i.x, "y": vector2i.y}
	return str(value)


static func _dictionary_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _dictionary_array_copy(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		var source_array: Array = value as Array
		for item: Variant in source_array:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


static func _packed_int_to_array(values: PackedInt32Array) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		result.append(value)
	return result


static func _array_to_packed_int(value: Variant) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if value is Array:
		var source_array: Array = value as Array
		for item: Variant in source_array:
			result.append(int(item))
	return result


static func _to_float_array(value: Variant) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value as PackedFloat32Array
	if value is Array:
		return PackedFloat32Array(value as Array)
	return PackedFloat32Array()


static func _load_audio_pcm(path: String, target_rate: int) -> GASPCMData:
	var extension: String = path.get_extension().to_lower()
	if extension == "wav":
		var wav_pcm: GASPCMData = _load_wav_pcm(path)
		if wav_pcm != null and target_rate > 0 and wav_pcm.sample_rate != target_rate:
			return wav_pcm.resample_to_rate(target_rate)
		return wav_pcm
	if extension == "mp3" or extension == "ogg":
		return CompressedAudioDecoder.decode_file(path, target_rate)
	return null


static func _load_wav_pcm(path: String) -> GASPCMData:
	var global_path: String = _global_path(path)
	if not FileAccess.file_exists(global_path):
		return null
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(global_path)
	if wav == null:
		return null
	return PCMData.from_wav(wav)


static func _global_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _data_dir_for_global_project(global_project: String) -> String:
	var without_extension: String = global_project.left(global_project.length() - PROJECT_EXTENSION.length()) if global_project.to_lower().ends_with(PROJECT_EXTENSION) else global_project
	return without_extension + DATA_SUFFIX


static func _is_virtual_source(path: String) -> bool:
	return path.begins_with("generated://") or path.begins_with("recorded://") or path.begins_with("effect://") or path.begins_with("joined://") or path.begins_with("clipboard://")


static func _max_clip_id(model: GASEditorModel) -> int:
	var result: int = 0
	for track: GASEditorTrack in model.tracks:
		for clip: GASEditorClip in track.clips:
			result = maxi(result, clip.clip_id)
	return result


static func _safe_filename(value: String) -> String:
	var result: String = value
	for invalid: String in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(invalid, "_")
	return result


static func _cleanup_unused_wav_files(audio_dir: String, used_files: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(audio_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.to_lower().ends_with(".wav") and not used_files.has(name):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


static func _search_folder_recursive(folder: String, filename: String, depth: int, max_depth: int) -> String:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var subdirs: PackedStringArray = PackedStringArray()
	var name: String = dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			if dir.current_is_dir():
				subdirs.append(name)
			elif name == filename:
				dir.list_dir_end()
				return folder.path_join(name)
		name = dir.get_next()
	dir.list_dir_end()
	if depth >= max_depth:
		return ""
	for subdir: String in subdirs:
		var found: String = _search_folder_recursive(folder.path_join(subdir), filename, depth + 1, max_depth)
		if not found.is_empty():
			return found
	return ""


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child: String = path.path_join(name)
			if dir.current_is_dir():
				_remove_tree(child)
			else:
				DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
