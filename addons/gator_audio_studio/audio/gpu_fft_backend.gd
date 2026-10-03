@tool
class_name GASGPUFFTBackend
extends RefCounted

const SHADER_PATH: String = "res://addons/gator_audio_studio/audio/gpu_fft_radix2.glsl"
const LOCAL_SIZE: int = 256
const DB_FLOOR: float = -160.0


static func transform_batch(windows: Array, fft_size: int, window: PackedFloat32Array) -> Array:
	var results: Array = []
	if windows.is_empty() or fft_size <= 1 or window.size() != fft_size:
		return results
	var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
	if rd == null:
		return results
	var shader_file: RDShaderFile = load(SHADER_PATH) as RDShaderFile
	if shader_file == null:
		rd.free()
		return results
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	if shader_spirv == null:
		rd.free()
		return results
	var shader: RID = rd.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		rd.free()
		return results
	var window_count: int = windows.size()
	var interleaved: PackedFloat32Array = PackedFloat32Array()
	interleaved.resize(window_count * fft_size * 2)
	var bits: int = _bit_count(fft_size)
	for window_index: int in range(window_count):
		var source_value: Variant = windows[window_index]
		var source: PackedFloat32Array = source_value as PackedFloat32Array
		var source_count: int = mini(source.size(), fft_size)
		var base: int = window_index * fft_size * 2
		for index: int in range(fft_size):
			var reversed: int = _bit_reverse(index, bits)
			var value: float = source[index] * window[index] if index < source_count else 0.0
			interleaved[base + reversed * 2] = value
			interleaved[base + reversed * 2 + 1] = 0.0
	var input_bytes: PackedByteArray = interleaved.to_byte_array()
	var buffer: RID = rd.storage_buffer_create(input_bytes.size(), input_bytes)
	if not buffer.is_valid():
		rd.free_rid(shader)
		rd.free()
		return results
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(buffer)
	var uniform_set: RID = rd.uniform_set_create([uniform], shader, 0)
	var pipeline: RID = rd.compute_pipeline_create(shader)
	if not uniform_set.is_valid() or not pipeline.is_valid():
		if uniform_set.is_valid():
			rd.free_rid(uniform_set)
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		rd.free_rid(buffer)
		rd.free_rid(shader)
		rd.free()
		return results
	var butterflies: int = window_count * (fft_size / 2)
	var groups: int = maxi(1, int(ceil(float(butterflies) / float(LOCAL_SIZE))))
	var compute_list: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	var stage_size: int = 2
	while stage_size <= fft_size:
		var push: PackedByteArray = PackedByteArray()
		push.resize(16)
		push.encode_u32(0, fft_size)
		push.encode_u32(4, stage_size)
		push.encode_u32(8, window_count)
		push.encode_u32(12, 0)
		rd.compute_list_set_push_constant(compute_list, push, push.size())
		rd.compute_list_dispatch(compute_list, groups, 1, 1)
		rd.compute_list_add_barrier(compute_list)
		stage_size = stage_size << 1
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var output_bytes: PackedByteArray = rd.buffer_get_data(buffer)
	var output: PackedFloat32Array = output_bytes.to_float32_array()
	if output.size() == interleaved.size():
		var half: int = fft_size / 2
		var window_sum: float = 0.0
		for value: float in window:
			window_sum += value
		var scale: float = 2.0 / maxf(0.000001, window_sum)
		for window_index: int in range(window_count):
			var linear: PackedFloat32Array = PackedFloat32Array()
			var db: PackedFloat32Array = PackedFloat32Array()
			linear.resize(half + 1)
			db.resize(half + 1)
			var base: int = window_index * fft_size * 2
			for bin: int in range(half + 1):
				var real_value: float = output[base + bin * 2]
				var imag_value: float = output[base + bin * 2 + 1]
				var magnitude: float = sqrt(real_value * real_value + imag_value * imag_value) * scale
				if bin == 0 or bin == half:
					magnitude *= 0.5
				linear[bin] = magnitude
				db[bin] = linear_to_db(maxf(0.00000001, magnitude))
			results.append({"size": fft_size, "linear": linear, "db": db, "backend": "GPU"})
	rd.free_rid(uniform_set)
	rd.free_rid(pipeline)
	rd.free_rid(buffer)
	rd.free_rid(shader)
	rd.free()
	return results


static func _bit_count(size: int) -> int:
	var bits: int = 0
	var value: int = size
	while value > 1:
		bits += 1
		value = value >> 1
	return bits


static func _bit_reverse(value: int, bits: int) -> int:
	var result: int = 0
	var input: int = value
	for _index: int in range(bits):
		result = (result << 1) | (input & 1)
		input = input >> 1
	return result
