@tool
class_name GASAnalyzerEngine
extends RefCounted

const FFTEngine := preload("res://addons/gator_audio_studio/audio/fft_engine.gd")

const DEFAULT_CLIP_THRESHOLD_DB: float = -0.1
const DEFAULT_SILENCE_DB: float = -50.0
const DEFAULT_SOUND_DB: float = -45.0
const EPSILON: float = 0.00000001


static func analyze(pcm: GASPCMData, start_frame: int, end_frame: int, fft_size: int = 8192, window_type: int = GASFFTEngine.WINDOW_HANN, silence_db: float = DEFAULT_SILENCE_DB) -> Dictionary:
	if pcm == null or pcm.frame_count() <= 0 or pcm.sample_rate <= 0:
		return {}
	var frame_total: int = pcm.frame_count()
	var start_clamped: int = clampi(start_frame, 0, frame_total)
	var end_clamped: int = clampi(end_frame, start_clamped, frame_total)
	if end_clamped <= start_clamped:
		start_clamped = 0
		end_clamped = frame_total
	var count: int = end_clamped - start_clamped
	var stereo: bool = pcm.is_stereo()
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	var sum_square: float = 0.0
	var sum_value: float = 0.0
	var peak: float = 0.0
	var clipped_samples: int = 0
	var clip_amp: float = db_to_linear(DEFAULT_CLIP_THRESHOLD_DB)
	var zero_crossings: int = 0
	var previous: float = 0.0
	var have_previous: bool = false
	var clipping_regions: Array[Vector2i] = []
	var clip_region_start: int = -1
	for frame: int in range(start_clamped, end_clamped):
		var left_sample: float = left[frame]
		var right_sample: float = right[frame] if stereo else left_sample
		var mono: float = (left_sample + right_sample) * 0.5 if stereo else left_sample
		var absolute: float = absf(mono)
		peak = maxf(peak, absolute)
		sum_square += mono * mono
		sum_value += mono
		var clipped: bool = absf(left_sample) >= clip_amp or (stereo and absf(right_sample) >= clip_amp)
		if clipped:
			clipped_samples += 1
			if clip_region_start < 0:
				clip_region_start = frame
		elif clip_region_start >= 0:
			clipping_regions.append(Vector2i(clip_region_start, frame))
			clip_region_start = -1
		if have_previous and ((previous < 0.0 and mono >= 0.0) or (previous > 0.0 and mono <= 0.0)):
			zero_crossings += 1
		previous = mono
		have_previous = true
	if clip_region_start >= 0:
		clipping_regions.append(Vector2i(clip_region_start, end_clamped))
	var rms: float = sqrt(sum_square / float(maxi(1, count)))
	var dc_offset: float = sum_value / float(maxi(1, count))
	var duration: float = float(count) / float(pcm.sample_rate)
	var block_db: PackedFloat32Array = _block_rms_db(pcm, start_clamped, end_clamped, maxi(64, int(round(float(pcm.sample_rate) * 0.02))))
	var dynamic_range_db: float = _percentile_range(block_db, 0.10, 0.95)
	var silence_regions: Array[Vector2i] = []
	var sound_regions: Array[Vector2i] = []
	_detect_signal_regions(pcm, start_clamped, end_clamped, silence_db, DEFAULT_SOUND_DB, silence_regions, sound_regions)
	var spectrum: Dictionary = FFTEngine.averaged_spectrum(pcm, start_clamped, end_clamped, fft_size, window_type, 24)
	var fundamental_hz: float = _estimate_fundamental_from_spectrum(spectrum, pcm.sample_rate)
	return {
		"start_frame": start_clamped,
		"end_frame": end_clamped,
		"sample_count": count,
		"duration_seconds": duration,
		"channels": pcm.channels,
		"sample_rate": pcm.sample_rate,
		"peak_linear": peak,
		"peak_db": linear_to_db(maxf(EPSILON, peak)),
		"rms_linear": rms,
		"rms_db": linear_to_db(maxf(EPSILON, rms)),
		"dc_offset": dc_offset,
		"zero_crossings": zero_crossings,
		"zero_crossing_rate": float(zero_crossings) / maxf(EPSILON, duration),
		"dynamic_range_db": dynamic_range_db,
		"clipped_samples": clipped_samples,
		"clipping_regions": clipping_regions,
		"silence_regions": silence_regions,
		"sound_regions": sound_regions,
		"fundamental_hz": fundamental_hz,
		"spectrum": spectrum,
	}


static func _detect_signal_regions(pcm: GASPCMData, start_frame: int, end_frame: int, silence_db: float, sound_db: float, silence_regions: Array[Vector2i], sound_regions: Array[Vector2i]) -> void:
	if pcm == null or pcm.sample_rate <= 0:
		return
	var frame_total: int = pcm.frame_count()
	var start_clamped: int = clampi(start_frame, 0, frame_total)
	var end_clamped: int = clampi(end_frame, start_clamped, frame_total)
	var block_size: int = maxi(32, int(round(float(pcm.sample_rate) * 0.01)))
	var silence_min_frames: int = maxi(block_size, int(round(0.10 * float(pcm.sample_rate))))
	var sound_min_frames: int = maxi(block_size, int(round(0.05 * float(pcm.sample_rate))))
	var silence_threshold: float = db_to_linear(silence_db)
	var sound_threshold: float = db_to_linear(sound_db)
	var stereo: bool = pcm.is_stereo()
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	var silence_start: int = -1
	var sound_start: int = -1
	var block_start: int = start_clamped
	while block_start < end_clamped:
		var block_end: int = mini(end_clamped, block_start + block_size)
		var energy: float = 0.0
		for frame: int in range(block_start, block_end):
			var left_sample: float = left[frame]
			var mono: float = (left_sample + right[frame]) * 0.5 if stereo else left_sample
			energy += mono * mono
		var block_rms: float = sqrt(energy / float(maxi(1, block_end - block_start)))
		var is_silence: bool = block_rms <= silence_threshold
		var is_sound: bool = block_rms >= sound_threshold
		if is_silence and silence_start < 0:
			silence_start = block_start
		elif not is_silence and silence_start >= 0:
			if block_start - silence_start >= silence_min_frames:
				silence_regions.append(Vector2i(silence_start, block_start))
			silence_start = -1
		if is_sound and sound_start < 0:
			sound_start = block_start
		elif not is_sound and sound_start >= 0:
			if block_start - sound_start >= sound_min_frames:
				sound_regions.append(Vector2i(sound_start, block_start))
			sound_start = -1
		block_start = block_end
	if silence_start >= 0 and end_clamped - silence_start >= silence_min_frames:
		silence_regions.append(Vector2i(silence_start, end_clamped))
	if sound_start >= 0 and end_clamped - sound_start >= sound_min_frames:
		sound_regions.append(Vector2i(sound_start, end_clamped))


static func detect_clipping(pcm: GASPCMData, start_frame: int, end_frame: int, threshold_db: float = DEFAULT_CLIP_THRESHOLD_DB) -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	if pcm == null:
		return output
	var threshold: float = db_to_linear(threshold_db)
	var start_clamped: int = clampi(start_frame, 0, pcm.frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, pcm.frame_count())
	var stereo: bool = pcm.is_stereo()
	var region_start: int = -1
	for frame: int in range(start_clamped, end_clamped):
		var clipped: bool = absf(pcm.left[frame]) >= threshold or (stereo and absf(pcm.right[frame]) >= threshold)
		if clipped and region_start < 0:
			region_start = frame
		elif not clipped and region_start >= 0:
			output.append(Vector2i(region_start, frame))
			region_start = -1
	if region_start >= 0:
		output.append(Vector2i(region_start, end_clamped))
	return output


static func detect_regions(pcm: GASPCMData, start_frame: int, end_frame: int, threshold_db: float, find_silence: bool, minimum_seconds: float) -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	if pcm == null or pcm.sample_rate <= 0:
		return output
	var start_clamped: int = clampi(start_frame, 0, pcm.frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, pcm.frame_count())
	var block_size: int = maxi(32, int(round(float(pcm.sample_rate) * 0.01)))
	var min_frames: int = maxi(block_size, int(round(minimum_seconds * float(pcm.sample_rate))))
	var threshold: float = db_to_linear(threshold_db)
	var stereo: bool = pcm.is_stereo()
	var active_start: int = -1
	var block_start: int = start_clamped
	while block_start < end_clamped:
		var block_end: int = mini(end_clamped, block_start + block_size)
		var energy: float = 0.0
		for frame: int in range(block_start, block_end):
			var mono: float = (pcm.left[frame] + pcm.right[frame]) * 0.5 if stereo else pcm.left[frame]
			energy += mono * mono
		var block_rms: float = sqrt(energy / float(maxi(1, block_end - block_start)))
		var matches: bool = block_rms <= threshold if find_silence else block_rms >= threshold
		if matches and active_start < 0:
			active_start = block_start
		elif not matches and active_start >= 0:
			if block_start - active_start >= min_frames:
				output.append(Vector2i(active_start, block_start))
			active_start = -1
		block_start = block_end
	if active_start >= 0 and end_clamped - active_start >= min_frames:
		output.append(Vector2i(active_start, end_clamped))
	return output


static func detect_beats(pcm: GASPCMData, start_frame: int, end_frame: int, threshold: float = 1.45, minimum_spacing_seconds: float = 0.18) -> Dictionary:
	if pcm == null or pcm.frame_count() <= 0 or pcm.sample_rate <= 0:
		return {}
	var start_clamped: int = clampi(start_frame, 0, pcm.frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, pcm.frame_count())
	if end_clamped <= start_clamped:
		start_clamped = 0
		end_clamped = pcm.frame_count()
	var block_size: int = 1024
	var hop: int = 512
	var block_count: int = maxi(0, 1 + int(maxi(0, end_clamped - start_clamped - block_size) / hop))
	if block_count < 4:
		return {"beats": PackedInt32Array(), "strengths": PackedFloat32Array(), "bpm": 0.0, "confidence": 0.0, "onset_strength": PackedFloat32Array(), "hop_frames": hop}
	var energy: PackedFloat32Array = PackedFloat32Array()
	energy.resize(block_count)
	var stereo: bool = pcm.is_stereo()
	for block: int in range(block_count):
		var frame_start: int = start_clamped + block * hop
		var frame_end: int = mini(end_clamped, frame_start + block_size)
		var sum_square: float = 0.0
		for frame: int in range(frame_start, frame_end):
			var mono: float = (pcm.left[frame] + pcm.right[frame]) * 0.5 if stereo else pcm.left[frame]
			sum_square += mono * mono
		energy[block] = sqrt(sum_square / float(maxi(1, frame_end - frame_start)))
	var onset: PackedFloat32Array = PackedFloat32Array()
	onset.resize(block_count)
	for block: int in range(1, block_count):
		onset[block] = maxf(0.0, energy[block] - energy[block - 1])
	var local_radius: int = maxi(2, int(round(float(pcm.sample_rate) / float(hop) * 0.50)))
	var min_spacing_blocks: int = maxi(1, int(round(minimum_spacing_seconds * float(pcm.sample_rate) / float(hop))))
	var beat_frames: PackedInt32Array = PackedInt32Array()
	var strengths: PackedFloat32Array = PackedFloat32Array()
	var last_beat_block: int = -min_spacing_blocks
	for block: int in range(1, block_count - 1):
		var local_start: int = maxi(0, block - local_radius)
		var local_end: int = mini(block_count, block + local_radius + 1)
		var local_sum: float = 0.0
		for neighbor: int in range(local_start, local_end):
			local_sum += onset[neighbor]
		var local_mean: float = local_sum / float(maxi(1, local_end - local_start))
		var required: float = maxf(0.000001, local_mean * threshold)
		if onset[block] >= required and onset[block] >= onset[block - 1] and onset[block] >= onset[block + 1] and block - last_beat_block >= min_spacing_blocks:
			beat_frames.append(start_clamped + block * hop)
			strengths.append(onset[block] / required)
			last_beat_block = block
	var tempo: Dictionary = _estimate_tempo_autocorrelation(onset, pcm.sample_rate, hop)
	return {
		"beats": beat_frames,
		"strengths": strengths,
		"bpm": float(tempo.get("bpm", 0.0)),
		"confidence": float(tempo.get("confidence", 0.0)),
		"onset_strength": onset,
		"hop_frames": hop,
	}


static func build_spectrogram(pcm: GASPCMData, start_frame: int, end_frame: int, fft_size: int, window_type: int, min_frequency: float, max_frequency: float, max_columns: int = 420, frequency_rows: int = 192, log_frequency: bool = true) -> Dictionary:
	if pcm == null or pcm.frame_count() <= 0 or pcm.sample_rate <= 0:
		return {}
	var size: int = FFTEngine.clamp_fft_size(fft_size)
	var start_clamped: int = clampi(start_frame, 0, pcm.frame_count())
	var end_clamped: int = clampi(end_frame, start_clamped, pcm.frame_count())
	if end_clamped <= start_clamped:
		start_clamped = 0
		end_clamped = pcm.frame_count()
	var region: int = end_clamped - start_clamped
	var columns: int = clampi(max_columns, 32, 768)
	if region < size:
		columns = mini(columns, maxi(1, region))
	var rows: int = clampi(frequency_rows, 48, 320)
	var nyquist: float = float(pcm.sample_rate) * 0.5
	var min_hz: float = clampf(min_frequency, 0.0, nyquist)
	var max_hz: float = clampf(max_frequency, maxf(min_hz + 1.0, 1.0), nyquist)
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(columns * rows)
	var stereo: bool = pcm.is_stereo()
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	var max_offset: int = maxi(0, region - size)
	var windows: Array = []
	for column: int in range(columns):
		var source_offset: int = start_clamped
		if columns > 1:
			source_offset += int(round(float(max_offset) * float(column) / float(columns - 1)))
		var samples: PackedFloat32Array = PackedFloat32Array()
		samples.resize(size)
		for index: int in range(size):
			var frame: int = source_offset + index
			if frame >= start_clamped and frame < end_clamped:
				var left_sample: float = left[frame]
				samples[index] = (left_sample + right[frame]) * 0.5 if stereo else left_sample
			else:
				samples[index] = 0.0
		windows.append(samples)
	var spectra: Array = FFTEngine.real_fft_batch_accelerated(windows, size, window_type, columns >= 4)
	for column: int in range(mini(columns, spectra.size())):
		var one: Dictionary = spectra[column] as Dictionary
		var db_value: Variant = one.get("db", PackedFloat32Array())
		var db_bins: PackedFloat32Array = db_value as PackedFloat32Array
		var bin_hz: float = float(pcm.sample_rate) / float(size)
		for row: int in range(rows):
			var fraction: float = float(row) / float(maxi(1, rows - 1))
			var frequency: float = 0.0
			if log_frequency:
				var low_log: float = log(maxf(20.0, min_hz + 1.0))
				var high_log: float = log(maxf(21.0, max_hz))
				frequency = exp(lerpf(low_log, high_log, fraction))
			else:
				frequency = lerpf(min_hz, max_hz, fraction)
			var bin: int = clampi(int(round(frequency / maxf(0.0001, bin_hz))), 0, db_bins.size() - 1)
			values[row * columns + column] = db_bins[bin]
	return {
		"columns": columns,
		"rows": rows,
		"values": values,
		"start_frame": start_clamped,
		"end_frame": end_clamped,
		"sample_rate": pcm.sample_rate,
		"min_frequency": min_hz,
		"max_frequency": max_hz,
		"log_frequency": log_frequency,
	}


static func _block_rms_db(pcm: GASPCMData, start_frame: int, end_frame: int, block_size: int) -> PackedFloat32Array:
	var count: int = maxi(1, int(ceil(float(end_frame - start_frame) / float(maxi(1, block_size)))))
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(count)
	var stereo: bool = pcm.is_stereo()
	var left: PackedFloat32Array = pcm.left
	var right: PackedFloat32Array = pcm.right
	for block: int in range(count):
		var block_start: int = start_frame + block * block_size
		var block_end: int = mini(end_frame, block_start + block_size)
		var energy: float = 0.0
		for frame: int in range(block_start, block_end):
			var left_sample: float = left[frame]
			var mono: float = (left_sample + right[frame]) * 0.5 if stereo else left_sample
			energy += mono * mono
		var rms: float = sqrt(energy / float(maxi(1, block_end - block_start)))
		values[block] = linear_to_db(maxf(EPSILON, rms))
	return values


static func _percentile_range(values: PackedFloat32Array, low_fraction: float, high_fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = []
	sorted.resize(values.size())
	for index: int in range(values.size()):
		sorted[index] = values[index]
	sorted.sort()
	var low_index: int = clampi(int(round(float(sorted.size() - 1) * low_fraction)), 0, sorted.size() - 1)
	var high_index: int = clampi(int(round(float(sorted.size() - 1) * high_fraction)), low_index, sorted.size() - 1)
	return maxf(0.0, sorted[high_index] - sorted[low_index])


static func _estimate_fundamental_from_spectrum(spectrum: Dictionary, sample_rate: int) -> float:
	if spectrum.is_empty() or sample_rate <= 0:
		return 0.0
	var linear_value: Variant = spectrum.get("linear", PackedFloat32Array())
	var linear: PackedFloat32Array = linear_value as PackedFloat32Array
	var bin_hz: float = float(spectrum.get("bin_hz", 0.0))
	if linear.size() < 4 or bin_hz <= 0.0:
		return 0.0
	var min_bin: int = maxi(1, int(ceil(40.0 / bin_hz)))
	var max_bin: int = mini(linear.size() - 1, int(floor(minf(4000.0, float(sample_rate) * 0.45) / bin_hz)))
	var best_bin: int = 0
	var best_score: float = -1000000.0
	for bin: int in range(min_bin, max_bin + 1):
		var score: float = linear_to_db(maxf(EPSILON, linear[bin]))
		for harmonic: int in range(2, 5):
			var harmonic_bin: int = bin * harmonic
			if harmonic_bin >= linear.size():
				break
			score += linear_to_db(maxf(EPSILON, linear[harmonic_bin])) * (0.55 / float(harmonic))
		if score > best_score:
			best_score = score
			best_bin = bin
	if best_bin <= 0:
		return 0.0
	var refined_bin: float = float(best_bin)
	if best_bin > 0 and best_bin + 1 < linear.size():
		var a: float = log(maxf(EPSILON, linear[best_bin - 1]))
		var b: float = log(maxf(EPSILON, linear[best_bin]))
		var c: float = log(maxf(EPSILON, linear[best_bin + 1]))
		var denominator: float = a - 2.0 * b + c
		if absf(denominator) > 0.000001:
			refined_bin += 0.5 * (a - c) / denominator
	return refined_bin * bin_hz


static func _estimate_tempo_autocorrelation(onset: PackedFloat32Array, sample_rate: int, hop: int) -> Dictionary:
	if onset.size() < 8 or sample_rate <= 0 or hop <= 0:
		return {"bpm": 0.0, "confidence": 0.0}
	var frames_per_second: float = float(sample_rate) / float(hop)
	var min_lag: int = maxi(1, int(floor(frames_per_second * 60.0 / 200.0)))
	var max_lag: int = mini(onset.size() - 2, int(ceil(frames_per_second * 60.0 / 60.0)))
	var best_lag: int = 0
	var best_score: float = 0.0
	var total_energy: float = 0.0
	for value: float in onset:
		total_energy += value * value
	if total_energy <= EPSILON:
		return {"bpm": 0.0, "confidence": 0.0}
	for lag: int in range(min_lag, max_lag + 1):
		var score: float = 0.0
		for index: int in range(lag, onset.size()):
			score += onset[index] * onset[index - lag]
		if score > best_score:
			best_score = score
			best_lag = lag
	if best_lag <= 0:
		return {"bpm": 0.0, "confidence": 0.0}
	var bpm: float = 60.0 * frames_per_second / float(best_lag)
	while bpm < 60.0:
		bpm *= 2.0
	while bpm > 200.0:
		bpm *= 0.5
	var confidence: float = clampf(best_score / total_energy, 0.0, 1.0)
	return {"bpm": bpm, "confidence": confidence}
