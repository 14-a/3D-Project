@tool
class_name GASRestorationEngine
extends RefCounted

const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")

const DEFAULT_FFT_SIZE: int = 2048
const MIN_GAIN_DB: float = -72.0


static func capture_noise_profile(pcm: GASPCMData, start_frame: int, end_frame: int, fft_size: int = DEFAULT_FFT_SIZE, progress: Callable = Callable()) -> Dictionary:
	if pcm == null or pcm.frame_count() <= 0:
		return {}
	var size: int = FFTEngine.clamp_fft_size(fft_size)
	var start: int = clampi(start_frame, 0, pcm.frame_count())
	var end: int = clampi(end_frame, start, pcm.frame_count())
	if end <= start:
		start = 0
		end = pcm.frame_count()
	var mono: PackedFloat32Array = _mono_region(pcm, start, end)
	var magnitudes: PackedFloat32Array = _average_magnitude(mono, size, progress)
	return {
		"fft_size": size,
		"sample_rate": pcm.sample_rate,
		"magnitudes": magnitudes,
		"source_frames": mono.size(),
	}


static func reduce_noise(pcm: GASPCMData, profile: Dictionary, reduction: float = 1.25, sensitivity: float = 1.0, smoothing_bins: int = 3, floor_db: float = -36.0, progress: Callable = Callable()) -> GASPCMData:
	if pcm == null or pcm.frame_count() <= 0 or profile.is_empty():
		return pcm
	var magnitude_value: Variant = profile.get("magnitudes", PackedFloat32Array())
	if not (magnitude_value is PackedFloat32Array):
		return pcm
	var noise_magnitude: PackedFloat32Array = magnitude_value as PackedFloat32Array
	var fft_size: int = int(profile.get("fft_size", DEFAULT_FFT_SIZE))
	if noise_magnitude.is_empty() or fft_size <= 0:
		return pcm
	var out: GASPCMData = pcm.duplicate_pcm()
	var left_span: float = 0.5 if pcm.is_stereo() else 1.0
	out.left = _reduce_channel(pcm.left, noise_magnitude, fft_size, reduction, sensitivity, smoothing_bins, floor_db, progress, 0.0, left_span)
	if pcm.is_stereo():
		out.right = _reduce_channel(pcm.right, noise_magnitude, fft_size, reduction, sensitivity, smoothing_bins, floor_db, progress, 0.5, 0.5)
	return out


static func repair_clicks(pcm: GASPCMData, threshold: float = 0.45, radius: int = 3) -> GASPCMData:
	if pcm == null or pcm.frame_count() < 5:
		return pcm
	var out: GASPCMData = pcm.duplicate_pcm()
	_repair_click_channel(out.left, threshold, radius)
	if out.is_stereo():
		_repair_click_channel(out.right, threshold, radius)
	return out


static func time_stretch(pcm: GASPCMData, factor: float, extreme: bool = false, progress: Callable = Callable()) -> GASPCMData:
	if pcm == null or pcm.frame_count() < 16:
		return pcm
	var stretch: float = clampf(factor, 0.25, 20.0 if extreme else 4.0)
	if absf(stretch - 1.0) < 0.0001:
		return pcm.duplicate_pcm()
	var grain: int = 4096 if extreme else 2048
	if pcm.frame_count() < grain * 2:
		grain = FFTEngine.clamp_fft_size(maxi(256, int(pow(2.0, floor(log(float(maxi(256, pcm.frame_count() / 2))) / log(2.0))))))
	grain = clampi(grain, 256, maxi(256, pcm.frame_count()))
	var analysis_hop: int = maxi(64, grain / 4)
	var synthesis_hop: int = maxi(1, int(round(float(analysis_hop) * stretch)))
	var search_radius: int = grain / (4 if extreme else 8)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	var left_span: float = 0.5 if pcm.is_stereo() else 1.0
	out.left = _wsola_channel(pcm.left, stretch, grain, analysis_hop, synthesis_hop, search_radius, progress, 0.0, left_span)
	if pcm.is_stereo():
		out.right = _wsola_channel(pcm.right, stretch, grain, analysis_hop, synthesis_hop, search_radius, progress, 0.5, 0.5)
		var common_count: int = mini(out.left.size(), out.right.size())
		out.left.resize(common_count)
		out.right.resize(common_count)
	return out


static func _mono_region(pcm: GASPCMData, start: int, end: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(maxi(0, end - start))
	var stereo: bool = pcm.is_stereo()
	for index: int in range(result.size()):
		var frame: int = start + index
		result[index] = (pcm.left[frame] + pcm.right[frame]) * 0.5 if stereo else pcm.left[frame]
	return result


static func _average_magnitude(source: PackedFloat32Array, fft_size: int, progress: Callable = Callable()) -> PackedFloat32Array:
	var bins: int = fft_size / 2 + 1
	var average: PackedFloat32Array = PackedFloat32Array()
	average.resize(bins)
	if source.is_empty():
		return average
	var window: PackedFloat32Array = FFTEngine.build_window(fft_size, FFTEngine.WINDOW_HANN)
	var hop: int = maxi(1, fft_size / 2)
	var windows: int = 0
	var estimated_windows: int = maxi(1, int(ceil(float(source.size()) / float(hop))))
	var start: int = 0
	while start < source.size():
		var real: PackedFloat32Array = PackedFloat32Array()
		var imag: PackedFloat32Array = PackedFloat32Array()
		real.resize(fft_size)
		imag.resize(fft_size)
		for index: int in range(fft_size):
			var source_index: int = start + index
			if source_index < source.size():
				real[index] = source[source_index] * window[index]
		FFTEngine.complex_transform(real, imag, false)
		for bin: int in range(bins):
			average[bin] += sqrt(real[bin] * real[bin] + imag[bin] * imag[bin])
		windows += 1
		start += hop
		if progress.is_valid() and (windows % 4 == 0 or start >= source.size()):
			progress.call(clampf(float(windows) / float(estimated_windows), 0.0, 1.0))
	var scale: float = 1.0 / float(maxi(1, windows))
	for bin: int in range(bins):
		average[bin] *= scale
	return average


static func _reduce_channel(source: PackedFloat32Array, noise_magnitude: PackedFloat32Array, fft_size: int, reduction: float, sensitivity: float, smoothing_bins: int, floor_db: float, progress: Callable = Callable(), progress_base: float = 0.0, progress_span: float = 1.0) -> PackedFloat32Array:
	var count: int = source.size()
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	if count <= 0:
		return result
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(count)
	var window: PackedFloat32Array = FFTEngine.build_window(fft_size, FFTEngine.WINDOW_HANN)
	var hop: int = maxi(1, fft_size / 4)
	var half: int = fft_size / 2
	var floor_gain: float = db_to_linear(clampf(floor_db, MIN_GAIN_DB, 0.0))
	var subtraction: float = clampf(reduction, 0.0, 4.0)
	var threshold_scale: float = clampf(sensitivity, 0.25, 4.0)
	var smooth_radius: int = clampi(smoothing_bins, 0, 16)
	var frame_start: int = -fft_size + hop
	var frame_index: int = 0
	var estimated_frames: int = maxi(1, int(ceil(float(count + fft_size) / float(hop))))
	while frame_start < count:
		var real: PackedFloat32Array = PackedFloat32Array()
		var imag: PackedFloat32Array = PackedFloat32Array()
		real.resize(fft_size)
		imag.resize(fft_size)
		for index: int in range(fft_size):
			var source_index: int = frame_start + index
			if source_index >= 0 and source_index < count:
				real[index] = source[source_index] * window[index]
		FFTEngine.complex_transform(real, imag, false)
		var gains: PackedFloat32Array = PackedFloat32Array()
		gains.resize(half + 1)
		for bin: int in range(half + 1):
			var magnitude: float = sqrt(real[bin] * real[bin] + imag[bin] * imag[bin])
			var noise_profile: float = noise_magnitude[mini(bin, noise_magnitude.size() - 1)]
			var noise: float = noise_profile * subtraction
			var below_gate: bool = magnitude <= noise_profile * threshold_scale
			var clean_magnitude: float = maxf(0.0, magnitude - noise) if below_gate else magnitude - minf(noise, magnitude * 0.35)
			gains[bin] = maxf(floor_gain, clean_magnitude / maxf(0.000000001, magnitude))
		if smooth_radius > 0:
			var unsmoothed: PackedFloat32Array = gains.duplicate()
			for bin: int in range(half + 1):
				var first: int = maxi(0, bin - smooth_radius)
				var last: int = mini(half, bin + smooth_radius)
				var sum_gain: float = 0.0
				for neighbor: int in range(first, last + 1):
					sum_gain += unsmoothed[neighbor]
				gains[bin] = sum_gain / float(last - first + 1)
		for bin: int in range(half + 1):
			var gain: float = gains[bin]
			real[bin] *= gain
			imag[bin] *= gain
			if bin > 0 and bin < half:
				var mirror: int = fft_size - bin
				real[mirror] *= gain
				imag[mirror] *= gain
		FFTEngine.complex_transform(real, imag, true)
		for index: int in range(fft_size):
			var destination: int = frame_start + index
			if destination < 0 or destination >= count:
				continue
			var window_value: float = window[index]
			result[destination] += real[index] * window_value
			weights[destination] += window_value * window_value
		frame_start += hop
		frame_index += 1
		if progress.is_valid() and (frame_index % 4 == 0 or frame_start >= count):
			progress.call(progress_base + progress_span * clampf(float(frame_index) / float(estimated_frames), 0.0, 1.0))
	for index: int in range(count):
		result[index] /= maxf(0.000001, weights[index])
	return result


static func _repair_click_channel(samples: PackedFloat32Array, threshold: float, radius: int) -> void:
	var count: int = samples.size()
	var safe_radius: int = clampi(radius, 1, 16)
	var trigger: float = clampf(threshold, 0.05, 1.5)
	var source: PackedFloat32Array = samples.duplicate()
	for index: int in range(safe_radius + 1, count - safe_radius - 1):
		var previous: float = source[index - 1]
		var next: float = source[index + 1]
		var expected: float = (previous + next) * 0.5
		if absf(source[index] - expected) < trigger:
			continue
		var left_index: int = index - safe_radius
		var right_index: int = index + safe_radius
		var t: float = 0.5
		samples[index] = lerpf(source[left_index], source[right_index], t)


static func _wsola_channel(source: PackedFloat32Array, stretch: float, grain: int, analysis_hop: int, synthesis_hop: int, search_radius: int, progress: Callable = Callable(), progress_base: float = 0.0, progress_span: float = 1.0) -> PackedFloat32Array:
	var source_count: int = source.size()
	var output_count: int = maxi(1, int(ceil(float(source_count) * stretch)))
	var output: PackedFloat32Array = PackedFloat32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	output.resize(output_count + grain)
	weights.resize(output_count + grain)
	var window: PackedFloat32Array = FFTEngine.build_window(grain, FFTEngine.WINDOW_HANN)
	var source_position: int = 0
	var output_position: int = 0
	var previous_source_position: int = -1
	while output_position < output_count and source_position < source_count:
		var chosen_source: int = source_position
		if previous_source_position >= 0 and source_position + grain < source_count:
			chosen_source = _best_wsola_offset(source, previous_source_position, source_position, grain, search_radius)
		for index: int in range(grain):
			var source_index: int = chosen_source + index
			var destination: int = output_position + index
			if source_index >= source_count or destination >= output.size():
				break
			var w: float = window[index]
			output[destination] += source[source_index] * w
			weights[destination] += w
		previous_source_position = chosen_source
		source_position = mini(source_count, source_position + analysis_hop)
		output_position += synthesis_hop
		if progress.is_valid() and (output_position % maxi(1, synthesis_hop * 8) == 0 or output_position >= output_count):
			progress.call(progress_base + progress_span * clampf(float(output_position) / float(maxi(1, output_count)), 0.0, 1.0))
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(output_count)
	for index: int in range(output_count):
		result[index] = output[index] / maxf(0.000001, weights[index])
	return result


static func _best_wsola_offset(source: PackedFloat32Array, previous_start: int, predicted_start: int, grain: int, search_radius: int) -> int:
	var source_count: int = source.size()
	var overlap: int = maxi(64, grain / 4)
	var previous_tail: int = previous_start + grain - overlap
	var minimum: int = maxi(0, predicted_start - search_radius)
	var maximum: int = mini(source_count - grain, predicted_start + search_radius)
	if maximum <= minimum or previous_tail < 0 or previous_tail + overlap >= source_count:
		return clampi(predicted_start, 0, maxi(0, source_count - grain))
	var stride: int = maxi(1, int(ceil(float(maximum - minimum + 1) / 48.0)))
	var compare_stride: int = 4
	var best_start: int = clampi(predicted_start, minimum, maximum)
	var best_score: float = -INF
	var candidate: int = minimum
	while candidate <= maximum:
		var dot: float = 0.0
		var energy_a: float = 0.000001
		var energy_b: float = 0.000001
		var offset: int = 0
		while offset < overlap:
			var a: float = source[previous_tail + offset]
			var b: float = source[candidate + offset]
			dot += a * b
			energy_a += a * a
			energy_b += b * b
			offset += compare_stride
		var score: float = dot / sqrt(energy_a * energy_b)
		if score > best_score:
			best_score = score
			best_start = candidate
		candidate += stride
	return best_start
