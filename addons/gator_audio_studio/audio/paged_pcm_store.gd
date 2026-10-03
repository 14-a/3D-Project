@tool
class_name GASPagedPCMStore
extends RefCounted

const FORMAT_MAGIC: String = "GASPCM1"
const DEFAULT_CHUNK_FRAMES: int = 262144

var cache_path: String = ""
var sample_rate: int = 44100
var channels: int = 1
var total_frames: int = 0
var chunk_frames: int = DEFAULT_CHUNK_FRAMES
var _chunk_offsets: PackedInt64Array = PackedInt64Array()


func create_from_pcm(pcm: GASPCMData, path: String, frames_per_chunk: int = DEFAULT_CHUNK_FRAMES, progress: Callable = Callable()) -> Error:
	if pcm == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	cache_path = path
	sample_rate = pcm.sample_rate
	channels = 2 if pcm.is_stereo() else 1
	total_frames = pcm.frame_count()
	chunk_frames = maxi(4096, frames_per_chunk)
	_chunk_offsets = PackedInt64Array()
	var parent: String = cache_path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_pascal_string(FORMAT_MAGIC)
	file.store_32(sample_rate)
	file.store_32(channels)
	file.store_64(total_frames)
	file.store_32(chunk_frames)
	var chunks: int = chunk_count()
	var source_left: PackedFloat32Array = pcm.left
	var source_right: PackedFloat32Array = pcm.right
	for chunk_index: int in range(chunks):
		_chunk_offsets.append(file.get_position())
		var start: int = chunk_index * chunk_frames
		var end: int = mini(total_frames, start + chunk_frames)
		var count: int = end - start
		file.store_32(count)
		var packed_samples: PackedFloat32Array
		if channels == 1:
			packed_samples = source_left.slice(start, end)
		else:
			packed_samples = PackedFloat32Array()
			packed_samples.resize(count * 2)
			for local_frame: int in range(count):
				var source_frame: int = start + local_frame
				var sample_offset: int = local_frame * 2
				packed_samples[sample_offset] = source_left[source_frame]
				packed_samples[sample_offset + 1] = source_right[source_frame]
		file.store_buffer(packed_samples.to_byte_array())
		if progress.is_valid():
			progress.call(float(chunk_index + 1) / float(maxi(1, chunks)))
	file.close()
	return OK


func open(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	if file.get_pascal_string() != FORMAT_MAGIC:
		file.close()
		return ERR_FILE_CORRUPT
	cache_path = path
	sample_rate = int(file.get_32())
	channels = clampi(int(file.get_32()), 1, 2)
	total_frames = int(file.get_64())
	chunk_frames = maxi(1, int(file.get_32()))
	var indexed: bool = _index_chunks(file)
	file.close()
	return OK if indexed else ERR_FILE_CORRUPT


func chunk_count() -> int:
	return int(ceil(float(total_frames) / float(maxi(1, chunk_frames)))) if total_frames > 0 else 0


func read_chunk(chunk_index: int) -> GASPCMData:
	if chunk_index < 0 or chunk_index >= chunk_count():
		return null
	if not _ensure_index():
		return null
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return null
	file.seek(_chunk_offsets[chunk_index])
	var count: int = int(file.get_32())
	if count < 0 or count > chunk_frames:
		file.close()
		return null
	var byte_count: int = count * channels * 4
	var raw: PackedByteArray = file.get_buffer(byte_count)
	file.close()
	if raw.size() != byte_count:
		return null
	var packed_samples: PackedFloat32Array = raw.to_float32_array()
	if packed_samples.size() != count * channels:
		return null
	var output: GASPCMData = GASPCMData.new()
	output.sample_rate = sample_rate
	output.channels = channels
	if channels == 1:
		output.left = packed_samples
		return output
	output.left.resize(count)
	output.right.resize(count)
	for frame: int in range(count):
		var sample_offset: int = frame * 2
		output.left[frame] = packed_samples[sample_offset]
		output.right[frame] = packed_samples[sample_offset + 1]
	return output


func read_frames(start_frame: int, end_frame: int) -> GASPCMData:
	var start: int = clampi(start_frame, 0, total_frames)
	var end: int = clampi(end_frame, start, total_frames)
	var output: GASPCMData = GASPCMData.new()
	output.sample_rate = sample_rate
	output.channels = channels
	var count: int = end - start
	output.left.resize(count)
	if channels == 2:
		output.right.resize(count)
	if count <= 0:
		return output
	var first_chunk: int = int(start / chunk_frames)
	var last_chunk: int = int((end - 1) / chunk_frames)
	var destination: int = 0
	for chunk_index: int in range(first_chunk, last_chunk + 1):
		var chunk: GASPCMData = read_chunk(chunk_index)
		if chunk == null:
			return null
		var chunk_start_global: int = chunk_index * chunk_frames
		var local_start: int = maxi(0, start - chunk_start_global)
		var local_end: int = mini(chunk.frame_count(), end - chunk_start_global)
		for frame: int in range(local_start, local_end):
			output.left[destination] = chunk.left[frame]
			if channels == 2:
				output.right[destination] = chunk.right[frame]
			destination += 1
	return output


func process_chunks(processor: Callable, progress: Callable = Callable()) -> bool:
	if not processor.is_valid():
		return false
	var count: int = chunk_count()
	for chunk_index: int in range(count):
		var chunk: GASPCMData = read_chunk(chunk_index)
		if chunk == null:
			return false
		processor.call(chunk, chunk_index)
		if progress.is_valid():
			progress.call(float(chunk_index + 1) / float(maxi(1, count)))
	return true


func materialize(progress: Callable = Callable()) -> GASPCMData:
	var output: GASPCMData = GASPCMData.new()
	output.sample_rate = sample_rate
	output.channels = channels
	output.left.resize(total_frames)
	if channels == 2:
		output.right.resize(total_frames)
	var destination: int = 0
	var count: int = chunk_count()
	for chunk_index: int in range(count):
		var chunk: GASPCMData = read_chunk(chunk_index)
		if chunk == null:
			return null
		for frame: int in range(chunk.frame_count()):
			output.left[destination] = chunk.left[frame]
			if channels == 2:
				output.right[destination] = chunk.right[frame]
			destination += 1
		if progress.is_valid():
			progress.call(float(chunk_index + 1) / float(maxi(1, count)))
	return output


func _ensure_index() -> bool:
	if _chunk_offsets.size() == chunk_count():
		return true
	var file: FileAccess = _open_data()
	if file == null:
		return false
	var valid: bool = _index_chunks(file)
	file.close()
	return valid


func _index_chunks(file: FileAccess) -> bool:
	_chunk_offsets = PackedInt64Array()
	var expected: int = chunk_count()
	for _index: int in range(expected):
		if file.eof_reached():
			_chunk_offsets = PackedInt64Array()
			return false
		_chunk_offsets.append(file.get_position())
		var count: int = int(file.get_32())
		if count < 0 or count > chunk_frames:
			_chunk_offsets = PackedInt64Array()
			return false
		var bytes_to_skip: int = count * channels * 4
		if file.get_position() + bytes_to_skip > file.get_length():
			_chunk_offsets = PackedInt64Array()
			return false
		file.seek(file.get_position() + bytes_to_skip)
	return _chunk_offsets.size() == expected


func _open_data() -> FileAccess:
	var file: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		return null
	if file.get_pascal_string() != FORMAT_MAGIC:
		file.close()
		return null
	file.get_32()
	file.get_32()
	file.get_64()
	file.get_32()
	return file
