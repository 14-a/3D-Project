@tool
class_name GASFFTEngine
extends RefCounted

const GPUBackend := preload("res://addons/gator_audio_studio/audio/gpu_fft_backend.gd")

const WINDOW_RECTANGULAR: int = 0
const WINDOW_HANN: int = 1
const WINDOW_HAMMING: int = 2
const WINDOW_BLACKMAN: int = 3
const WINDOW_NAME_RECTANGULAR: String = "Rectangular"
const WINDOW_NAME_HANN: String = "Hann"
const WINDOW_NAME_HAMMING: String = "Hamming"
const WINDOW_NAME_BLACKMAN: String = "Blackman"
const MIN_FFT_SIZE: int = 256
const MAX_FFT_SIZE: int = 32768
const DB_FLOOR: float = -160.0
const TAU_F: float = 6.283185307179586


static func clamp_fft_size(requested: int) -> int:
	var value: int = clampi(requested, MIN_FFT_SIZE, MAX_FFT_SIZE)
	var power: int = 1
	while power < value:
		power = power << 1
	var lower: int = power >> 1
	if lower >= MIN_FFT_SIZE and value - lower < power - value:
		power = lower
	return clampi(power, MIN_FFT_SIZE, MAX_FFT_SIZE)


static func window_names() -> PackedStringArray:
	return PackedStringArray([
		WINDOW_NAME_RECTANGULAR,
		WINDOW_NAME_HANN,
		WINDOW_NAME_HAMMING,
		WINDOW_NAME_BLACKMAN,
	])


static func window_index_from_name(window_name: String) -> int:
	match window_name:
		WINDOW_NAME_RECTANGULAR:
			return WINDOW_RECTANGULAR
		WINDOW_NAME_HAMMING:
			return WINDOW_HAMMING
		WINDOW_NAME_BLACKMAN:
			return WINDOW_BLACKMAN
		_:
			return WINDOW_HANN


static func build_window(size: int, window_type: int) -> PackedFloat32Array:
	var count: int = maxi(1, size)
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(count)
	if count == 1:
		output[0] = 1.0
		return output
	var denom: float = float(count - 1)
	for index: int in range(count):
		var phase: float = TAU_F * float(index) / denom
		match window_type:
			WINDOW_RECTANGULAR:
				output[index] = 1.0
			WINDOW_HAMMING:
				output[index] = 0.54 - 0.46 * cos(phase)
			WINDOW_BLACKMAN:
				output[index] = 0.42 - 0.5 * cos(phase) + 0.08 * cos(2.0 * phase)
			_:
				output[index] = 0.5 - 0.5 * cos(phase)
	return output


static func real_fft(samples: PackedFloat32Array, fft_size: int, window_type: int = WINDOW_HANN) -> Dictionary:
	var size: int = clamp_fft_size(fft_size)
	var real: PackedFloat32Array = PackedFloat32Array()
	var imag: PackedFloat32Array = PackedFloat32Array()
	real.resize(size)
	imag.resize(size)
	var window: PackedFloat32Array = build_window(size, window_type)
	var copy_count: int = mini(size, samples.size())
	var window_sum: float = 0.0
	for index: int in range(size):
		window_sum += window[index]
		if index < copy_count:
			real[index] = samples[index] * window[index]
		else:
			real[index] = 0.0
		imag[index] = 0.0
	_fft_in_place(real, imag)
	var half: int = size / 2
	var linear: PackedFloat32Array = PackedFloat32Array()
	var db: PackedFloat32Array = PackedFloat32Array()
	linear.resize(half + 1)
	db.resize(half + 1)
	var scale: float = 2.0 / maxf(0.000001, window_sum)
	for bin: int in range(half + 1):
		var magnitude: float = sqrt(real[bin] * real[bin] + imag[bin] * imag[bin]) * scale
		if bin == 0 or bin == half:
			magnitude *= 0.5
		linear[bin] = magnitude
		db[bin] = linear_to_db(maxf(0.00000001, magnitude))
	return {
		"size": size,
		"linear": linear,
		"db": db,
	}


static func real_fft_batch_accelerated(windows: Array, fft_size: int, window_type: int = WINDOW_HANN, allow_gpu: bool = true) -> Array:
	var size: int = clamp_fft_size(fft_size)
	if windows.is_empty():
		return []
	var use_gpu: bool = allow_gpu and bool(ProjectSettings.get_setting("gator_audio_studio/performance/use_gpu_compute", true))
	if use_gpu:
		var gpu_results: Array = GPUBackend.transform_batch(windows, size, build_window(size, window_type))
		if gpu_results.size() == windows.size():
			return gpu_results
	var output: Array = []
	for window_value: Variant in windows:
		var window_samples: PackedFloat32Array = window_value as PackedFloat32Array
		var one: Dictionary = real_fft(window_samples, size, window_type)
		one["backend"] = "CPU"
		output.append(one)
	return output


static func averaged_spectrum(pcm: GASPCMData, start_frame: int, end_frame: int, fft_size: int, window_type: int, max_windows: int = 32) -> Dictionary:
	if pcm == null or pcm.frame_count() <= 0 or pcm.sample_rate <= 0:
		return {}
	var size: int = clamp_fft_size(fft_size)
	var start_clamped: int = clampi(start_frame, 0, pcm.frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, pcm.frame_count())
	if end_clamped <= start_clamped:
		start_clamped = 0
		end_clamped = pcm.frame_count()
	var region_frames: int = end_clamped - start_clamped
	var half: int = size / 2
	var accum: PackedFloat32Array = PackedFloat32Array()
	accum.resize(half + 1)
	var window_count: int = 1
	var hop: int = maxi(1, size / 2)
	if region_frames > size:
		window_count = mini(maxi(1, max_windows), 1 + int((region_frames - size) / hop))
	var windows: Array = []
	for window_index: int in range(window_count):
		var offset: int = start_clamped
		if window_count > 1:
			var available: int = maxi(0, region_frames - size)
			offset += int(round(float(available) * float(window_index) / float(window_count - 1)))
		var samples: PackedFloat32Array = PackedFloat32Array()
		samples.resize(size)
		_fill_mono_window(pcm, offset, samples)
		windows.append(samples)
	var spectra: Array = real_fft_batch_accelerated(windows, size, window_type, window_count >= 4)
	for spectrum_value: Variant in spectra:
		var one: Dictionary = spectrum_value as Dictionary
		var linear_value: Variant = one.get("linear", PackedFloat32Array())
		var linear: PackedFloat32Array = linear_value as PackedFloat32Array
		for bin: int in range(accum.size()):
			accum[bin] += linear[bin]
	var db: PackedFloat32Array = PackedFloat32Array()
	db.resize(accum.size())
	var peak_bin: int = 0
	var peak_value: float = 0.0
	var inv_count: float = 1.0 / float(maxi(1, window_count))
	for bin: int in range(accum.size()):
		accum[bin] *= inv_count
		db[bin] = linear_to_db(maxf(0.00000001, accum[bin]))
		if bin > 0 and accum[bin] > peak_value:
			peak_value = accum[bin]
			peak_bin = bin
	var bin_hz: float = float(pcm.sample_rate) / float(size)
	return {
		"size": size,
		"linear": accum,
		"db": db,
		"bin_hz": bin_hz,
		"peak_bin": peak_bin,
		"peak_hz": float(peak_bin) * bin_hz,
		"peak_db": db[peak_bin] if peak_bin < db.size() else DB_FLOOR,
		"windows": window_count,
	}


static func _fill_mono_window(pcm: GASPCMData, start_frame: int, output: PackedFloat32Array) -> void:
	var stereo: bool = pcm.is_stereo()
	var frame_total: int = pcm.frame_count()
	for index: int in range(output.size()):
		var source_index: int = start_frame + index
		if source_index < 0 or source_index >= frame_total:
			output[index] = 0.0
		elif stereo:
			output[index] = (pcm.left[source_index] + pcm.right[source_index]) * 0.5
		else:
			output[index] = pcm.left[source_index]


static func _fft_in_place(real: PackedFloat32Array, imag: PackedFloat32Array) -> void:
	var size: int = real.size()
	var j: int = 0
	for i: int in range(1, size):
		var bit: int = size >> 1
		while (j & bit) != 0:
			j = j ^ bit
			bit = bit >> 1
		j = j ^ bit
		if i < j:
			var temp_real: float = real[i]
			real[i] = real[j]
			real[j] = temp_real
			var temp_imag: float = imag[i]
			imag[i] = imag[j]
			imag[j] = temp_imag
	var length: int = 2
	while length <= size:
		var angle: float = -TAU_F / float(length)
		var step_real: float = cos(angle)
		var step_imag: float = sin(angle)
		var half_length: int = length >> 1
		var block_start: int = 0
		while block_start < size:
			var w_real: float = 1.0
			var w_imag: float = 0.0
			for offset: int in range(half_length):
				var even_index: int = block_start + offset
				var odd_index: int = even_index + half_length
				var odd_real: float = real[odd_index] * w_real - imag[odd_index] * w_imag
				var odd_imag: float = real[odd_index] * w_imag + imag[odd_index] * w_real
				var even_real: float = real[even_index]
				var even_imag: float = imag[even_index]
				real[even_index] = even_real + odd_real
				imag[even_index] = even_imag + odd_imag
				real[odd_index] = even_real - odd_real
				imag[odd_index] = even_imag - odd_imag
				var next_w_real: float = w_real * step_real - w_imag * step_imag
				w_imag = w_real * step_imag + w_imag * step_real
				w_real = next_w_real
			block_start += length
		length = length << 1


static func complex_transform(real: PackedFloat32Array, imag: PackedFloat32Array, inverse: bool = false) -> void:
	if real.size() != imag.size() or real.is_empty():
		return
	if (real.size() & (real.size() - 1)) != 0:
		return
	if not inverse:
		_fft_in_place(real, imag)
		return
	for index: int in range(imag.size()):
		imag[index] = -imag[index]
	_fft_in_place(real, imag)
	var inv_size: float = 1.0 / float(real.size())
	for index: int in range(real.size()):
		real[index] *= inv_size
		imag[index] = -imag[index] * inv_size
