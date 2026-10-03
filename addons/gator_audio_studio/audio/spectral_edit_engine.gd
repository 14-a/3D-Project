@tool
class_name GASSpectralEditEngine
extends RefCounted

const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")

const ACTION_ATTENUATE: String = "Attenuate"
const ACTION_AMPLIFY: String = "Amplify"
const ACTION_DELETE: String = "Delete"
const ACTION_SILENCE: String = "Silence"
const ACTION_ISOLATE: String = "Isolate"
const ACTION_REPAIR: String = "Repair"
const ACTION_EQ: String = "Spectral EQ"

static func actions() -> PackedStringArray:
	return PackedStringArray([
		ACTION_ATTENUATE,
		ACTION_AMPLIFY,
		ACTION_DELETE,
		ACTION_SILENCE,
		ACTION_ISOLATE,
		ACTION_REPAIR,
		ACTION_EQ,
	])


static func process_region(
	pcm: GASPCMData,
	start_frame: int,
	end_frame: int,
	low_hz: float,
	high_hz: float,
	action: String,
	amount_db: float = -18.0,
	fft_size: int = 2048,
	progress: Callable = Callable()
) -> GASPCMData:
	if pcm == null or pcm.frame_count() <= 0:
		return pcm
	var start: int = clampi(start_frame, 0, pcm.frame_count())
	var end: int = clampi(end_frame, start, pcm.frame_count())
	if end <= start:
		start = 0
		end = pcm.frame_count()
	var nyquist: float = float(pcm.sample_rate) * 0.5
	var low: float = clampf(minf(low_hz, high_hz), 0.0, nyquist)
	var high: float = clampf(maxf(low_hz, high_hz), low, nyquist)
	var out: GASPCMData = pcm.duplicate_pcm()
	var size: int = FFTEngine.clamp_fft_size(fft_size)
	var left_region: PackedFloat32Array = pcm.left.slice(start, end)
	var left_span: float = 0.5 if pcm.is_stereo() else 1.0
	var processed_left: PackedFloat32Array = _process_channel(left_region, pcm.sample_rate, low, high, action, amount_db, size, progress, 0.0, left_span)
	for i: int in range(processed_left.size()):
		out.left[start + i] = processed_left[i]
	if pcm.is_stereo():
		var right_region: PackedFloat32Array = pcm.right.slice(start, end)
		var processed_right: PackedFloat32Array = _process_channel(right_region, pcm.sample_rate, low, high, action, amount_db, size, progress, 0.5, 0.5)
		for i: int in range(processed_right.size()):
			out.right[start + i] = processed_right[i]
	return out


static func _process_channel(
	source: PackedFloat32Array,
	sample_rate: int,
	low_hz: float,
	high_hz: float,
	action: String,
	amount_db: float,
	fft_size: int,
	progress: Callable = Callable(),
	progress_base: float = 0.0,
	progress_span: float = 1.0
) -> PackedFloat32Array:
	var count: int = source.size()
	if count <= 0:
		return source
	var hop: int = maxi(1, fft_size / 4)
	var window: PackedFloat32Array = FFTEngine.build_window(fft_size, FFTEngine.WINDOW_HANN)
	var output: PackedFloat32Array = PackedFloat32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	output.resize(count + fft_size)
	weights.resize(count + fft_size)
	var frame_start: int = -fft_size + hop
	var frame_index: int = 0
	var estimated_frames: int = maxi(1, int(ceil(float(count + fft_size) / float(hop))))
	while frame_start < count:
		var real: PackedFloat32Array = PackedFloat32Array()
		var imag: PackedFloat32Array = PackedFloat32Array()
		real.resize(fft_size)
		imag.resize(fft_size)
		for i: int in range(fft_size):
			var source_index: int = frame_start + i
			if source_index >= 0 and source_index < count:
				real[i] = source[source_index] * window[i]
		FFTEngine.complex_transform(real, imag, false)
		_apply_bins(real, imag, sample_rate, low_hz, high_hz, action, amount_db)
		FFTEngine.complex_transform(real, imag, true)
		for i: int in range(fft_size):
			var dest: int = frame_start + i
			if dest < 0 or dest >= count:
				continue
			var weight: float = window[i]
			output[dest] += real[i] * weight
			weights[dest] += weight * weight
		frame_start += hop
		frame_index += 1
		if progress.is_valid() and (frame_index % 4 == 0 or frame_start >= count):
			progress.call(progress_base + progress_span * clampf(float(frame_index) / float(estimated_frames), 0.0, 1.0))
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	for i: int in range(count):
		result[i] = output[i] / maxf(0.000001, weights[i])
	return result


static func _apply_bins(
	real: PackedFloat32Array,
	imag: PackedFloat32Array,
	sample_rate: int,
	low_hz: float,
	high_hz: float,
	action: String,
	amount_db: float
) -> void:
	var size: int = real.size()
	var half: int = size / 2
	var bin_hz: float = float(sample_rate) / float(size)
	var low_bin: int = clampi(int(floor(low_hz / bin_hz)), 0, half)
	var high_bin: int = clampi(int(ceil(high_hz / bin_hz)), low_bin, half)
	var band_gain: float = db_to_linear(amount_db)
	if action == ACTION_AMPLIFY or action == ACTION_EQ:
		band_gain = db_to_linear(absf(amount_db))
	elif action == ACTION_ATTENUATE:
		band_gain = db_to_linear(-absf(amount_db))
	for bin: int in range(half + 1):
		var inside: bool = bin >= low_bin and bin <= high_bin
		var factor: float = 1.0
		match action:
			ACTION_ISOLATE:
				factor = 1.0 if inside else 0.0
			ACTION_DELETE, ACTION_SILENCE:
				factor = 0.0 if inside else 1.0
			ACTION_ATTENUATE, ACTION_AMPLIFY, ACTION_EQ:
				factor = band_gain if inside else 1.0
			ACTION_REPAIR:
				if inside:
					_repair_bin(real, imag, bin, low_bin, high_bin, half)
					continue
			_:
				pass
		if factor != 1.0:
			real[bin] *= factor
			imag[bin] *= factor
			if bin > 0 and bin < half:
				var mirror: int = size - bin
				real[mirror] *= factor
				imag[mirror] *= factor


static func _repair_bin(real: PackedFloat32Array, imag: PackedFloat32Array, bin: int, low_bin: int, high_bin: int, half: int) -> void:
	var left_bin: int = maxi(0, low_bin - 1)
	var right_bin: int = mini(half, high_bin + 1)
	var span: int = maxi(1, right_bin - left_bin)
	var t: float = clampf(float(bin - left_bin) / float(span), 0.0, 1.0)
	var repaired_real: float = lerpf(real[left_bin], real[right_bin], t)
	var repaired_imag: float = lerpf(imag[left_bin], imag[right_bin], t)
	real[bin] = repaired_real
	imag[bin] = repaired_imag
	if bin > 0 and bin < half:
		var mirror: int = real.size() - bin
		real[mirror] = repaired_real
		imag[mirror] = -repaired_imag
