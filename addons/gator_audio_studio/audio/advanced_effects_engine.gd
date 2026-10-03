@tool
class_name GASAdvancedEffectsEngine
extends RefCounted

const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")


static func filter_curve_eq(input: GASPCMData, band_gains_db: PackedFloat32Array, progress: Callable = Callable()) -> GASPCMData:
	if input == null:
		return null
	var gains: PackedFloat32Array = band_gains_db
	if gains.size() < 5:
		gains = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var current: GASPCMData = input.duplicate_pcm()
	var effect: GASEffectData = EffectEngine.create_default("Low Shelf")
	effect.params["frequency_hz"] = 80.0
	effect.params["gain_db"] = float(gains[0])
	current = EffectEngine.process(current, effect)
	_report_progress(progress, 0.2)
	var frequencies: PackedFloat32Array = PackedFloat32Array([250.0, 1000.0, 4000.0])
	for index: int in range(3):
		effect = EffectEngine.create_default("Parametric EQ")
		effect.params["frequency_hz"] = float(frequencies[index])
		effect.params["gain_db"] = float(gains[index + 1])
		effect.params["q"] = 0.85
		current = EffectEngine.process(current, effect)
		_report_progress(progress, 0.4 + float(index) * 0.2)
	effect = EffectEngine.create_default("High Shelf")
	effect.params["frequency_hz"] = 12000.0
	effect.params["gain_db"] = float(gains[4])
	var result: GASPCMData = EffectEngine.process(current, effect)
	_report_progress(progress, 1.0)
	return result


static func auto_duck(target: GASPCMData, sidechain: GASPCMData, threshold_db: float, reduction_db: float, attack_ms: float, release_ms: float, progress: Callable = Callable()) -> GASPCMData:
	if target == null or sidechain == null:
		return target
	var control: GASPCMData = sidechain
	if control.sample_rate != target.sample_rate:
		control = control.resample_to_rate(target.sample_rate)
	var out: GASPCMData = target.duplicate_pcm()
	var threshold: float = db_to_linear(threshold_db)
	var reduction_gain: float = db_to_linear(-absf(reduction_db))
	var sample_rate: float = float(maxi(1, target.sample_rate))
	var attack_seconds: float = maxf(0.0001, attack_ms * 0.001)
	var release_seconds: float = maxf(0.0001, release_ms * 0.001)
	var attack_alpha: float = 1.0 - exp(-1.0 / (attack_seconds * sample_rate))
	var release_alpha: float = 1.0 - exp(-1.0 / (release_seconds * sample_rate))
	var envelope: float = 1.0
	for frame: int in range(out.frame_count()):
		var control_level: float = 0.0
		if frame < control.frame_count():
			control_level = absf(control.left[frame])
			if control.is_stereo():
				control_level = maxf(control_level, absf(control.right[frame]))
		var desired: float = reduction_gain if control_level >= threshold else 1.0
		var alpha: float = attack_alpha if desired < envelope else release_alpha
		envelope += (desired - envelope) * alpha
		out.left[frame] *= envelope
		if out.is_stereo():
			out.right[frame] *= envelope
		if progress.is_valid() and (frame % 16384 == 0 or frame == out.frame_count() - 1):
			progress.call(float(frame + 1) / float(maxi(1, out.frame_count())))
	return out


static func vocoder(modulator: GASPCMData, carrier: GASPCMData, band_count: int = 12, attack_ms: float = 8.0, release_ms: float = 70.0, progress: Callable = Callable()) -> GASPCMData:
	if modulator == null or carrier == null:
		return null
	var car: GASPCMData = carrier
	if car.sample_rate != modulator.sample_rate:
		car = car.resample_to_rate(modulator.sample_rate)
	var count: int = mini(modulator.frame_count(), car.frame_count())
	if count <= 0:
		return null
	var bands: int = clampi(band_count, 4, 24)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = modulator.sample_rate
	out.channels = 2 if car.is_stereo() else 1
	out.left.resize(count)
	if out.is_stereo():
		out.right.resize(count)
	var low_states_mod: PackedFloat32Array = PackedFloat32Array()
	var high_states_mod: PackedFloat32Array = PackedFloat32Array()
	var low_states_car_l: PackedFloat32Array = PackedFloat32Array()
	var high_states_car_l: PackedFloat32Array = PackedFloat32Array()
	var low_states_car_r: PackedFloat32Array = PackedFloat32Array()
	var high_states_car_r: PackedFloat32Array = PackedFloat32Array()
	var envelopes: PackedFloat32Array = PackedFloat32Array()
	var low_alpha: PackedFloat32Array = PackedFloat32Array()
	var high_alpha: PackedFloat32Array = PackedFloat32Array()
	low_states_mod.resize(bands)
	high_states_mod.resize(bands)
	low_states_car_l.resize(bands)
	high_states_car_l.resize(bands)
	low_states_car_r.resize(bands)
	high_states_car_r.resize(bands)
	envelopes.resize(bands)
	low_alpha.resize(bands)
	high_alpha.resize(bands)
	var sample_rate: float = float(maxi(1, modulator.sample_rate))
	var min_hz: float = 100.0
	var max_hz: float = minf(9000.0, sample_rate * 0.45)
	for band: int in range(bands):
		var t0: float = float(band) / float(bands)
		var t1: float = float(band + 1) / float(bands)
		var lower_hz: float = min_hz * pow(max_hz / min_hz, t0)
		var upper_hz: float = min_hz * pow(max_hz / min_hz, t1)
		low_alpha[band] = 1.0 - exp(-6.28318530718 * lower_hz / sample_rate)
		high_alpha[band] = 1.0 - exp(-6.28318530718 * upper_hz / sample_rate)
	var attack_alpha: float = 1.0 - exp(-1.0 / (maxf(0.0001, attack_ms * 0.001) * sample_rate))
	var release_alpha: float = 1.0 - exp(-1.0 / (maxf(0.0001, release_ms * 0.001) * sample_rate))
	var scale: float = 2.25 / float(bands)
	for frame: int in range(count):
		var mod_sample: float = modulator.left[frame]
		if modulator.is_stereo():
			mod_sample = 0.5 * (mod_sample + modulator.right[frame])
		var car_left: float = car.left[frame]
		var car_right: float = car.right[frame] if car.is_stereo() else car_left
		var sum_left: float = 0.0
		var sum_right: float = 0.0
		for band: int in range(bands):
			low_states_mod[band] += low_alpha[band] * (mod_sample - low_states_mod[band])
			high_states_mod[band] += high_alpha[band] * (mod_sample - high_states_mod[band])
			var mod_band: float = high_states_mod[band] - low_states_mod[band]
			var desired_env: float = minf(2.0, absf(mod_band) * 5.0)
			var env_alpha: float = attack_alpha if desired_env > envelopes[band] else release_alpha
			envelopes[band] += (desired_env - envelopes[band]) * env_alpha
			low_states_car_l[band] += low_alpha[band] * (car_left - low_states_car_l[band])
			high_states_car_l[band] += high_alpha[band] * (car_left - high_states_car_l[band])
			var carrier_band_l: float = high_states_car_l[band] - low_states_car_l[band]
			sum_left += carrier_band_l * envelopes[band]
			if out.is_stereo():
				low_states_car_r[band] += low_alpha[band] * (car_right - low_states_car_r[band])
				high_states_car_r[band] += high_alpha[band] * (car_right - high_states_car_r[band])
				var carrier_band_r: float = high_states_car_r[band] - low_states_car_r[band]
				sum_right += carrier_band_r * envelopes[band]
		out.left[frame] = clampf(sum_left * scale, -1.0, 1.0)
		if out.is_stereo():
			out.right[frame] = clampf(sum_right * scale, -1.0, 1.0)
		if progress.is_valid() and (frame % 4096 == 0 or frame == count - 1):
			progress.call(float(frame + 1) / float(maxi(1, count)))
	return out


static func _report_progress(progress: Callable, value: float) -> void:
	if progress.is_valid():
		progress.call(clampf(value, 0.0, 1.0))
