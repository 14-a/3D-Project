@tool
class_name GASPCMData
extends RefCounted

var sample_rate: int = 44100
var channels: int = 1
var left: PackedFloat32Array = PackedFloat32Array()
var right: PackedFloat32Array = PackedFloat32Array()


func frame_count() -> int:
	return left.size()


func duration_seconds() -> float:
	if sample_rate <= 0:
		return 0.0
	return float(frame_count()) / float(sample_rate)


func is_stereo() -> bool:
	return channels == 2 and right.size() == left.size()


func duplicate_pcm() -> GASPCMData:
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = channels
	out.left = left.duplicate()
	out.right = right.duplicate()
	return out


func slice_frames(start_frame: int, end_frame: int) -> GASPCMData:
	var start_clamped: int = clampi(start_frame, 0, frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, frame_count())
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = channels
	out.left = left.slice(start_clamped, end_clamped)
	if is_stereo():
		out.right = right.slice(start_clamped, end_clamped)
	return out


func with_silence(start_frame: int, end_frame: int) -> GASPCMData:
	var out: GASPCMData = duplicate_pcm()
	var start_clamped: int = clampi(start_frame, 0, frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, frame_count())
	for i: int in range(start_clamped, end_clamped):
		out.left[i] = 0.0
		if out.is_stereo():
			out.right[i] = 0.0
	return out


func remove_frames(start_frame: int, end_frame: int) -> GASPCMData:
	var start_clamped: int = clampi(start_frame, 0, frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, frame_count())
	var remove_count: int = end_clamped - start_clamped
	if remove_count <= 0:
		return duplicate_pcm()
	var new_count: int = frame_count() - remove_count
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = channels
	out.left.resize(new_count)
	if is_stereo():
		out.right.resize(new_count)
	var dst: int = 0
	for i: int in range(frame_count()):
		if i >= start_clamped and i < end_clamped:
			continue
		out.left[dst] = left[i]
		if is_stereo():
			out.right[dst] = right[i]
		dst += 1
	return out


func insert_pcm(at_frame: int, insert: GASPCMData) -> GASPCMData:
	if insert == null or insert.frame_count() == 0:
		return duplicate_pcm()
	if insert.sample_rate != sample_rate:
		return duplicate_pcm()
	var pos: int = clampi(at_frame, 0, frame_count())
	var new_channels: int = maxi(channels, insert.channels)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = new_channels
	var new_count: int = frame_count() + insert.frame_count()
	out.left.resize(new_count)
	if new_channels == 2:
		out.right.resize(new_count)
	var dst: int = 0
	for i: int in range(pos):
		out.left[dst] = left[i]
		if new_channels == 2:
			out.right[dst] = right[i] if is_stereo() else left[i]
		dst += 1
	for i: int in range(insert.frame_count()):
		out.left[dst] = insert.left[i]
		if new_channels == 2:
			out.right[dst] = insert.right[i] if insert.is_stereo() else insert.left[i]
		dst += 1
	for i: int in range(pos, frame_count()):
		out.left[dst] = left[i]
		if new_channels == 2:
			out.right[dst] = right[i] if is_stereo() else left[i]
		dst += 1
	return out


func to_wav() -> AudioStreamWAV:
	var stereo_output: bool = is_stereo()
	var stride: int = 4 if stereo_output else 2
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frame_count() * stride)
	for i: int in range(frame_count()):
		var left_i: int = clampi(int(round(left[i] * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * stride, left_i)
		if stereo_output:
			var right_i: int = clampi(int(round(right[i] * 32767.0)), -32768, 32767)
			bytes.encode_s16(i * stride + 2, right_i)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = stereo_output
	wav.data = bytes
	return wav


static func from_wav(wav: AudioStreamWAV) -> GASPCMData:
	if wav == null:
		return null
	if wav.format != AudioStreamWAV.FORMAT_8_BITS and wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return null
	var data: PackedByteArray = wav.data
	var channel_count: int = 2 if wav.stereo else 1
	var bytes_per_sample: int = 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var bytes_per_frame: int = bytes_per_sample * channel_count
	if bytes_per_frame <= 0 or data.size() < bytes_per_frame:
		return null
	var frames: int = int(data.size() / bytes_per_frame)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = wav.mix_rate
	out.channels = channel_count
	out.left.resize(frames)
	if channel_count == 2:
		out.right.resize(frames)
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		for i: int in range(frames):
			var offset: int = i * bytes_per_frame
			out.left[i] = float(data.decode_s16(offset)) / 32768.0
			if channel_count == 2:
				out.right[i] = float(data.decode_s16(offset + 2)) / 32768.0
	else:
		for i: int in range(frames):
			var offset: int = i * bytes_per_frame
			var left_byte: int = int(data[offset])
			if left_byte > 127:
				left_byte -= 256
			out.left[i] = float(left_byte) / 128.0
			if channel_count == 2:
				var right_byte: int = int(data[offset + 1])
				if right_byte > 127:
					right_byte -= 256
				out.right[i] = float(right_byte) / 128.0
	return out


func resample_to_rate(target_rate: int, progress_callback: Callable = Callable()) -> GASPCMData:
	if target_rate <= 0 or sample_rate <= 0 or target_rate == sample_rate:
		if progress_callback.is_valid():
			progress_callback.call(1.0)
		return duplicate_pcm()
	var source_left: PackedFloat32Array = left
	var source_right: PackedFloat32Array = right
	var source_count: int = source_left.size()
	var stereo_source: bool = channels > 1 and source_right.size() == source_count
	var ratio: float = float(target_rate) / float(sample_rate)
	var new_count: int = maxi(1, int(round(float(source_count) * ratio)))
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = target_rate
	out.channels = 2 if stereo_source else 1
	out.left.resize(new_count)
	if stereo_source:
		out.right.resize(new_count)
	if source_count <= 1:
		var single_left: float = source_left[0] if source_count == 1 else 0.0
		var single_right: float = source_right[0] if stereo_source else single_left
		for i: int in range(new_count):
			out.left[i] = single_left
			if stereo_source:
				out.right[i] = single_right
		if progress_callback.is_valid():
			progress_callback.call(1.0)
		return out
	var source_step: float = float(sample_rate) / float(target_rate)
	var source_last: int = source_count - 1
	var output_left: PackedFloat32Array = out.left
	var output_right: PackedFloat32Array = out.right
	var next_progress_frame: int = 16384
	for i: int in range(new_count):
		var source_pos: float = minf(float(source_last), float(i) * source_step)
		var a: int = clampi(int(source_pos), 0, source_last)
		var b: int = mini(a + 1, source_last)
		var t: float = source_pos - float(a)
		output_left[i] = source_left[a] + (source_left[b] - source_left[a]) * t
		if stereo_source:
			output_right[i] = source_right[a] + (source_right[b] - source_right[a]) * t
		if progress_callback.is_valid() and i >= next_progress_frame:
			progress_callback.call(float(i) / float(maxi(1, new_count)))
			next_progress_frame += 16384
	if progress_callback.is_valid():
		progress_callback.call(1.0)
	return out


func force_mono() -> GASPCMData:
	if not is_stereo():
		return duplicate_pcm()
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = 1
	out.left.resize(frame_count())
	for i: int in range(frame_count()):
		out.left[i] = (left[i] + right[i]) * 0.5
	return out


func fit_frames(target_frames: int) -> GASPCMData:
	var count: int = maxi(0, target_frames)
	if count == frame_count():
		return duplicate_pcm()
	if count < frame_count():
		return slice_frames(0, count)
	var out: GASPCMData = duplicate_pcm()
	out.left.resize(count)
	if out.is_stereo():
		out.right.resize(count)
	return out
