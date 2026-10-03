@tool
class_name GASExportEngine
extends RefCounted

const LoopEngine := preload("res://addons/gator_audio_studio/audio/loop_engine.gd")

static func prepare_pcm(pcm: GASPCMData, mono: bool, sample_rate: int, normalize: bool, normalize_db: float = -1.0, progress_callback: Callable = Callable()) -> GASPCMData:
	if pcm == null:
		return null
	var report_progress: bool = progress_callback.is_valid()
	if report_progress:
		progress_callback.call(0.0)
	# Fast path: normal 16-bit/project-rate exports can encode directly from the
	# rendered PCM instead of cloning a song-sized pair of PackedFloat32Arrays.
	var out: GASPCMData = pcm
	if mono and pcm.is_stereo():
		out = pcm.force_mono()
	if report_progress:
		progress_callback.call(0.15)
	if sample_rate > 0 and sample_rate != out.sample_rate:
		var resample_progress: Callable = func(value: float) -> void:
			if report_progress:
				progress_callback.call(0.15 + clampf(value, 0.0, 1.0) * 0.40)
		out = out.resample_to_rate(sample_rate, resample_progress)
	elif report_progress:
		progress_callback.call(0.55)
	if normalize:
		if out == pcm:
			out = pcm.duplicate_pcm()
		var peak: float = 0.0
		var left: PackedFloat32Array = out.left
		var right: PackedFloat32Array = out.right
		var stereo: bool = out.is_stereo()
		var frame_count: int = left.size()
		for i: int in range(frame_count):
			peak = maxf(peak, absf(left[i]))
			if stereo:
				peak = maxf(peak, absf(right[i]))
			if report_progress and (i & 16383) == 0:
				progress_callback.call(0.55 + 0.20 * float(i) / float(maxi(1, frame_count)))
		if peak > 0.0000001:
			var gain: float = db_to_linear(normalize_db) / peak
			for i: int in range(frame_count):
				left[i] = clampf(left[i] * gain, -1.0, 1.0)
				if stereo:
					right[i] = clampf(right[i] * gain, -1.0, 1.0)
				if report_progress and (i & 16383) == 0:
					progress_callback.call(0.75 + 0.25 * float(i) / float(maxi(1, frame_count)))
	if report_progress:
		progress_callback.call(1.0)
	return out


static func to_wav(pcm: GASPCMData, bit_depth: int, tags: Dictionary = {}, loop_start: int = 0, loop_end: int = 0, loop_mode: int = AudioStreamWAV.LOOP_DISABLED) -> AudioStreamWAV:
	if pcm == null:
		return null
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.mix_rate = pcm.sample_rate
	wav.stereo = pcm.is_stereo()
	wav.tags = tags.duplicate(true)
	if bit_depth <= 8:
		wav.format = AudioStreamWAV.FORMAT_8_BITS
		var stride8: int = 2 if pcm.is_stereo() else 1
		var bytes8: PackedByteArray = PackedByteArray()
		bytes8.resize(pcm.frame_count() * stride8)
		for i: int in range(pcm.frame_count()):
			var left_i8: int = clampi(int(round(pcm.left[i] * 127.0)), -128, 127)
			bytes8[i * stride8] = left_i8 & 0xff
			if pcm.is_stereo():
				var right_i8: int = clampi(int(round(pcm.right[i] * 127.0)), -128, 127)
				bytes8[i * stride8 + 1] = right_i8 & 0xff
		wav.data = bytes8
	else:
		wav = pcm.to_wav()
		wav.tags = tags.duplicate(true)
	if loop_mode != AudioStreamWAV.LOOP_DISABLED and loop_end > loop_start:
		LoopEngine.apply_loop_metadata(wav, loop_start, loop_end, loop_mode)
	return wav


static func save_wav(path: String, pcm: GASPCMData, mono: bool, sample_rate: int, normalize: bool, bit_depth: int, tags: Dictionary = {}, loop_start: int = 0, loop_end: int = 0, loop_mode: int = AudioStreamWAV.LOOP_DISABLED, progress_callback: Callable = Callable()) -> Error:
	var report_progress: bool = progress_callback.is_valid()
	var prepare_progress: Callable = Callable()
	if report_progress:
		prepare_progress = func(value: float) -> void:
			progress_callback.call(clampf(value, 0.0, 1.0) * 0.58)
	var prepared: GASPCMData = prepare_pcm(pcm, mono, sample_rate, normalize, -1.0, prepare_progress)
	if prepared == null or prepared.frame_count() <= 0:
		return ERR_INVALID_DATA
	var scale: float = float(prepared.sample_rate) / float(maxi(1, pcm.sample_rate))
	var scaled_loop_start: int = int(round(float(loop_start) * scale))
	var scaled_loop_end: int = int(round(float(loop_end) * scale))
	var final_path: String = path if path.to_lower().ends_with(".wav") else path + ".wav"
	var write_progress: Callable = Callable()
	if report_progress:
		write_progress = func(value: float) -> void:
			progress_callback.call(0.58 + clampf(value, 0.0, 1.0) * 0.42)
	var save_error: Error = _save_pcm_wav_atomic(final_path, prepared, 8 if bit_depth <= 8 else 16, tags, scaled_loop_start, scaled_loop_end, loop_mode, write_progress)
	if save_error == OK and report_progress:
		progress_callback.call(1.0)
	return save_error


# Export workers must never expose a partially-written .wav to Godot's editor
# filesystem watcher. Write to an unrecognized sibling temporary file first,
# close it, then rename it into place. This also avoids constructing/saving a
# Resource from a worker thread; only typed PCM + FileAccess are used here.
static func _save_pcm_wav_atomic(path: String, pcm: GASPCMData, bit_depth: int, tags: Dictionary, loop_start: int, loop_end: int, loop_mode: int, progress_callback: Callable = Callable()) -> Error:
	if pcm == null or pcm.frame_count() <= 0 or pcm.sample_rate <= 0:
		return ERR_INVALID_DATA
	var temporary_path: String = path + ".gas_tmp"
	var backup_path: String = path + ".gas_backup"
	_remove_file_if_exists(temporary_path)
	_remove_file_if_exists(backup_path)
	var write_error: Error = _write_pcm_wav_file(temporary_path, pcm, bit_depth, tags, loop_start, loop_end, loop_mode, progress_callback)
	if write_error != OK:
		_remove_file_if_exists(temporary_path)
		return write_error

	var target_exists: bool = FileAccess.file_exists(path)
	if target_exists:
		var backup_error: Error = DirAccess.rename_absolute(_absolute_path(path), _absolute_path(backup_path))
		if backup_error != OK:
			_remove_file_if_exists(temporary_path)
			return backup_error

	var rename_error: Error = DirAccess.rename_absolute(_absolute_path(temporary_path), _absolute_path(path))
	if rename_error != OK:
		if target_exists and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(_absolute_path(backup_path), _absolute_path(path))
		_remove_file_if_exists(temporary_path)
		return rename_error
	_remove_file_if_exists(backup_path)
	return OK


static func _write_pcm_wav_file(path: String, pcm: GASPCMData, bit_depth: int, tags: Dictionary, loop_start: int, loop_end: int, loop_mode: int, progress_callback: Callable = Callable()) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.big_endian = false

	_write_fourcc(file, "RIFF")
	file.store_32(0) # Patched after all chunks are written.
	_write_fourcc(file, "WAVE")

	var stereo: bool = pcm.is_stereo()
	var channel_count: int = 2 if stereo else 1
	var bytes_per_sample: int = 1 if bit_depth <= 8 else 2
	var block_align: int = channel_count * bytes_per_sample
	var byte_rate: int = pcm.sample_rate * block_align

	_write_fourcc(file, "fmt ")
	file.store_32(16)
	file.store_16(1) # PCM
	file.store_16(channel_count)
	file.store_32(pcm.sample_rate)
	file.store_32(byte_rate)
	file.store_16(block_align)
	file.store_16(bit_depth)

	if loop_mode != AudioStreamWAV.LOOP_DISABLED and loop_end > loop_start:
		_write_smpl_chunk(file, pcm.sample_rate, loop_start, loop_end, loop_mode, pcm.frame_count())
	if not tags.is_empty():
		_write_info_chunk(file, tags)

	var data_size: int = pcm.frame_count() * block_align
	_write_fourcc(file, "data")
	file.store_32(data_size)
	var pcm_error: Error = _write_pcm_data(file, pcm, bit_depth, progress_callback)
	if pcm_error != OK:
		file.close()
		return pcm_error
	if (data_size & 1) != 0:
		file.store_8(0)

	var final_length: int = file.get_position()
	file.seek(4)
	file.store_32(maxi(0, final_length - 8))
	file.flush()
	var io_error: Error = file.get_error()
	file.close()
	return io_error


static func _write_pcm_data(file: FileAccess, pcm: GASPCMData, bit_depth: int, progress_callback: Callable = Callable()) -> Error:
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	var stereo: bool = pcm.is_stereo()
	var frame_count: int = left.size()
	var bytes_per_sample: int = 1 if bit_depth <= 8 else 2
	var stride: int = bytes_per_sample * (2 if stereo else 1)
	var frames_per_block: int = 16384
	var bytes: PackedByteArray = PackedByteArray()
	var start_frame: int = 0
	while start_frame < frame_count:
		var count: int = mini(frames_per_block, frame_count - start_frame)
		bytes.resize(count * stride)
		if bit_depth <= 8:
			for local_frame: int in range(count):
				var source_frame: int = start_frame + local_frame
				var offset: int = local_frame * stride
				bytes[offset] = clampi(int(round((clampf(left[source_frame], -1.0, 1.0) * 0.5 + 0.5) * 255.0)), 0, 255)
				if stereo:
					bytes[offset + 1] = clampi(int(round((clampf(right[source_frame], -1.0, 1.0) * 0.5 + 0.5) * 255.0)), 0, 255)
		else:
			for local_frame: int in range(count):
				var source_frame: int = start_frame + local_frame
				var offset: int = local_frame * stride
				var left_sample: int = clampi(int(round(left[source_frame] * 32767.0)), -32768, 32767)
				bytes.encode_s16(offset, left_sample)
				if stereo:
					var right_sample: int = clampi(int(round(right[source_frame] * 32767.0)), -32768, 32767)
					bytes.encode_s16(offset + 2, right_sample)
		file.store_buffer(bytes)
		if file.get_error() != OK:
			return file.get_error()
		start_frame += count
		if progress_callback.is_valid():
			progress_callback.call(float(start_frame) / float(maxi(1, frame_count)))
	if progress_callback.is_valid():
		progress_callback.call(1.0)
	return OK


static func _write_smpl_chunk(file: FileAccess, sample_rate: int, loop_start: int, loop_end: int, loop_mode: int, frame_count: int) -> void:
	var start_frame: int = clampi(loop_start, 0, maxi(0, frame_count - 1))
	var end_frame_exclusive: int = clampi(loop_end, start_frame + 1, frame_count)
	var wav_loop_type: int = 0
	if loop_mode == AudioStreamWAV.LOOP_PINGPONG:
		wav_loop_type = 1
	elif loop_mode == AudioStreamWAV.LOOP_BACKWARD:
		wav_loop_type = 2
	_write_fourcc(file, "smpl")
	file.store_32(60)
	file.store_32(0) # Manufacturer
	file.store_32(0) # Product
	file.store_32(int(round(1000000000.0 / float(maxi(1, sample_rate)))))
	file.store_32(60) # MIDI unity note
	file.store_32(0) # MIDI pitch fraction
	file.store_32(0) # SMPTE format
	file.store_32(0) # SMPTE offset
	file.store_32(1) # Loop count
	file.store_32(0) # Sampler data
	file.store_32(0) # Cue point ID
	file.store_32(wav_loop_type)
	file.store_32(start_frame)
	file.store_32(maxi(start_frame, end_frame_exclusive - 1))
	file.store_32(0) # Fraction
	file.store_32(0) # Infinite play count


static func _write_info_chunk(file: FileAccess, tags: Dictionary) -> void:
	var entries: Array[PackedStringArray] = []
	var mappings: Array[PackedStringArray] = [
		PackedStringArray(["title", "INAM"]),
		PackedStringArray(["artist", "IART"]),
		PackedStringArray(["album", "IPRD"]),
		PackedStringArray(["track", "ITRK"]),
		PackedStringArray(["tracknumber", "ITRK"]),
		PackedStringArray(["genre", "IGNR"]),
		PackedStringArray(["year", "ICRD"]),
		PackedStringArray(["date", "ICRD"]),
		PackedStringArray(["comments", "ICMT"]),
		PackedStringArray(["comment", "ICMT"]),
	]
	var used_codes: Dictionary = {}
	for mapping: PackedStringArray in mappings:
		var key: String = mapping[0]
		var code: String = mapping[1]
		if used_codes.has(code) or not tags.has(key):
			continue
		var value: String = str(tags[key]).strip_edges()
		if value.is_empty():
			continue
		entries.append(PackedStringArray([code, value]))
		used_codes[code] = true
	if entries.is_empty():
		return

	_write_fourcc(file, "LIST")
	var size_position: int = file.get_position()
	file.store_32(0)
	var payload_start: int = file.get_position()
	_write_fourcc(file, "INFO")
	for entry: PackedStringArray in entries:
		_write_fourcc(file, entry[0])
		var text_bytes: PackedByteArray = entry[1].to_utf8_buffer()
		var value_size: int = text_bytes.size() + 1
		file.store_32(value_size)
		file.store_buffer(text_bytes)
		file.store_8(0)
		if (value_size & 1) != 0:
			file.store_8(0)
	var payload_end: int = file.get_position()
	file.seek(size_position)
	file.store_32(payload_end - payload_start)
	file.seek(payload_end)


static func _write_fourcc(file: FileAccess, text: String) -> void:
	file.store_buffer(text.to_ascii_buffer())


static func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _remove_file_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute_path(path))


static func safe_name(text: String) -> String:
	var result: String = text.strip_edges()
	for bad: String in PackedStringArray(["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]):
		result = result.replace(bad, "_")
	return result if not result.is_empty() else "audio"


static func apply_naming_pattern(pattern: String, track: String, label: String, index: int, clip: String = "") -> String:
	var result: String = pattern
	result = result.replace("{track}", safe_name(track))
	result = result.replace("{label}", safe_name(label))
	result = result.replace("{clip}", safe_name(clip))
	result = result.replace("{index}", "%02d" % index)
	return safe_name(result)
