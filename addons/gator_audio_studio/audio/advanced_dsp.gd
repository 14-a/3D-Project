@tool
class_name GASAdvancedDSP
extends RefCounted

const DISTORTION_SOFT_CLIP: int = 0
const DISTORTION_HARD_CLIP: int = 1
const DISTORTION_SATURATION: int = 2
const DISTORTION_DIGITAL: int = 3
const DISTORTION_RECTIFIER: int = 4
const DISTORTION_FOLDBACK: int = 5



static func process_mono(samples: PackedFloat32Array, sample_rate: int, params: Dictionary) -> void:
	if samples.is_empty():
		return
	var distortion_mix: float = clampf(float(params.get("distortion_mix", 0.0)), 0.0, 1.0)
	if distortion_mix > 0.00001:
		_apply_distortion(samples, _distortion_mode_id(str(params.get("distortion_mode", "Soft Clip"))), float(params.get("drive", 1.5)), distortion_mix)
	var crush_bits: int = clampi(int(params.get("crush_bits", 16)), 1, 16)
	if crush_bits < 16:
		_apply_bit_depth(samples, crush_bits)
	var chorus_mix: float = clampf(float(params.get("chorus_mix", 0.0)), 0.0, 1.0)
	if chorus_mix > 0.00001:
		_apply_modulated_delay(samples, sample_rate, chorus_mix, float(params.get("chorus_rate", 0.8)), float(params.get("chorus_depth_ms", 8.0)), 16.0)
	var flanger_mix: float = clampf(float(params.get("flanger_mix", 0.0)), 0.0, 1.0)
	if flanger_mix > 0.00001:
		_apply_modulated_delay(samples, sample_rate, flanger_mix, float(params.get("flanger_rate", 0.35)), float(params.get("flanger_depth_ms", 2.0)), 2.5)
	var phaser_mix: float = clampf(float(params.get("phaser_mix", 0.0)), 0.0, 1.0)
	if phaser_mix > 0.00001:
		_apply_phaser(samples, sample_rate, phaser_mix, float(params.get("phaser_rate", 0.45)), float(params.get("phaser_depth", 0.7)))
	var delay_mix: float = clampf(float(params.get("echo_mix", 0.0)), 0.0, 0.9)
	if delay_mix > 0.00001 and str(params.get("delay_mode", "Mono")) != "Ping-Pong":
		_apply_feedback_delay(samples, sample_rate, delay_mix, float(params.get("echo_delay", 0.12)), float(params.get("delay_feedback", 0.25)), int(params.get("delay_taps", 4)))
	var reverb_mix: float = clampf(float(params.get("reverb_mix", 0.0)), 0.0, 0.8)
	if reverb_mix > 0.00001:
		_apply_reverb(samples, sample_rate, reverb_mix, float(params.get("reverb_size", 0.5)), float(params.get("reverb_damping", 0.4)))
	var brr_amount: float = clampf(float(params.get("brr_amount", 0.0)), 0.0, 1.0)
	if brr_amount > 0.00001:
		_apply_brr_inspired(samples, brr_amount)


static func make_ping_pong_stereo(samples: PackedFloat32Array, sample_rate: int, params: Dictionary) -> Dictionary:
	var left: PackedFloat32Array = samples.duplicate()
	var right: PackedFloat32Array = samples.duplicate()
	var mix: float = clampf(float(params.get("echo_mix", 0.0)), 0.0, 0.85)
	if mix <= 0.00001:
		return {"left": left, "right": right}
	var delay_frames: int = maxi(1, int(round(float(params.get("echo_delay", 0.12)) * float(sample_rate))))
	var feedback: float = clampf(float(params.get("delay_feedback", 0.3)), 0.0, 0.88)
	var taps: int = clampi(int(params.get("delay_taps", 5)), 1, 12)
	var tap_gain: float = mix
	for tap: int in range(1, taps + 1):
		var offset: int = delay_frames * tap
		if offset >= samples.size():
			break
		var count: int = samples.size() - offset
		if (tap & 1) == 1:
			for i: int in range(count):
				right[i + offset] = clampf(right[i + offset] + samples[i] * tap_gain, -1.0, 1.0)
		else:
			for i: int in range(count):
				left[i + offset] = clampf(left[i + offset] + samples[i] * tap_gain, -1.0, 1.0)
		tap_gain *= feedback
	return {"left": left, "right": right}


static func pan_to_stereo(samples: PackedFloat32Array, pan: float) -> Dictionary:
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	left.resize(samples.size())
	right.resize(samples.size())
	var p: float = clampf(pan, -1.0, 1.0)
	var angle: float = (p + 1.0) * PI * 0.25
	var left_gain: float = cos(angle)
	var right_gain: float = sin(angle)
	for i: int in range(samples.size()):
		var sample: float = samples[i]
		left[i] = sample * left_gain
		right[i] = sample * right_gain
	return {"left": left, "right": right}


static func _distortion_mode_id(mode: String) -> int:
	match mode:
		"Hard Clip": return DISTORTION_HARD_CLIP
		"Saturation": return DISTORTION_SATURATION
		"Digital": return DISTORTION_DIGITAL
		"Rectifier": return DISTORTION_RECTIFIER
		"Foldback": return DISTORTION_FOLDBACK
		_: return DISTORTION_SOFT_CLIP


static func _apply_distortion(samples: PackedFloat32Array, mode_id: int, drive: float, mix: float) -> void:
	var d: float = maxf(0.01, drive)
	var soft_norm: float = 1.0 / maxf(0.001, tanh(d))
	for i: int in range(samples.size()):
		var dry: float = samples[i]
		var wet: float = dry
		match mode_id:
			DISTORTION_HARD_CLIP: wet = clampf(dry * d, -0.6, 0.6) * 1.666666667
			DISTORTION_SOFT_CLIP: wet = tanh(dry * d) * soft_norm
			DISTORTION_SATURATION: wet = (2.0 / PI) * atan(dry * d * 2.0)
			DISTORTION_DIGITAL: wet = round(clampf(dry * d, -1.0, 1.0) * 31.0) * 0.0322580645
			DISTORTION_RECTIFIER: wet = absf(dry * d) * 2.0 - 1.0
			DISTORTION_FOLDBACK:
				var x: float = dry * d
				wet = absf(fposmod(x + 1.0, 4.0) - 2.0) - 1.0
			_: wet = tanh(dry * d) * soft_norm
		samples[i] = lerpf(dry, clampf(wet, -1.0, 1.0), mix)


static func _apply_bit_depth(samples: PackedFloat32Array, bits: int) -> void:
	var levels: float = float((1 << bits) - 1)
	var inv_levels: float = 1.0 / levels
	for i: int in range(samples.size()):
		var normalized: float = samples[i] * 0.5 + 0.5
		samples[i] = (round(normalized * levels) * inv_levels) * 2.0 - 1.0


static func _apply_feedback_delay(samples: PackedFloat32Array, sample_rate: int, mix: float, delay_seconds: float, feedback: float, taps: int) -> void:
	var delay_frames: int = maxi(1, int(round(delay_seconds * float(sample_rate))))
	var feedback_gain: float = clampf(feedback, 0.0, 0.9)
	var tap_gain: float = mix
	var tap_count: int = clampi(taps, 1, 12)
	for tap: int in range(1, tap_count + 1):
		var offset: int = delay_frames * tap
		if offset >= samples.size():
			break
		var count: int = samples.size() - offset
		for i: int in range(count):
			samples[i + offset] = clampf(samples[i + offset] + samples[i] * tap_gain, -1.0, 1.0)
		tap_gain *= feedback_gain


static func _apply_reverb(samples: PackedFloat32Array, sample_rate: int, mix: float, size: float, damping: float) -> void:
	var room: float = clampf(size, 0.0, 1.0)
	var damp: float = clampf(damping, 0.0, 1.0)
	_apply_reverb_tap(samples, sample_rate, 0.011 + room * 0.017, mix * 0.48, damp)
	_apply_reverb_tap(samples, sample_rate, 0.019 + room * 0.029, mix * 0.415, damp)
	_apply_reverb_tap(samples, sample_rate, 0.031 + room * 0.041, mix * 0.35, damp)
	_apply_reverb_tap(samples, sample_rate, 0.043 + room * 0.067, mix * 0.285, damp)
	_apply_reverb_tap(samples, sample_rate, 0.071 + room * 0.089, mix * 0.22, damp)


static func _apply_reverb_tap(samples: PackedFloat32Array, sample_rate: int, delay_seconds: float, gain: float, damping: float) -> void:
	var offset: int = maxi(1, int(round(delay_seconds * float(sample_rate))))
	if offset >= samples.size():
		return
	var damp_state: float = 0.0
	var count: int = samples.size() - offset
	for i: int in range(count):
		damp_state = lerpf(samples[i], damp_state, damping)
		samples[i + offset] = clampf(samples[i + offset] + damp_state * gain, -1.0, 1.0)


static func _apply_modulated_delay(samples: PackedFloat32Array, sample_rate: int, mix: float, rate_hz: float, depth_ms: float, base_ms: float) -> void:
	var source: PackedFloat32Array = samples.duplicate()
	var sample_rate_ms: float = float(sample_rate) * 0.001
	var phase: float = 0.0
	var phase_step: float = TAU * rate_hz / float(sample_rate)
	for i: int in range(samples.size()):
		var delay_ms: float = base_ms + sin(phase) * depth_ms
		phase += phase_step
		if phase >= TAU:
			phase -= TAU
		var offset: int = maxi(1, int(round(delay_ms * sample_rate_ms)))
		var source_index: int = i - offset
		if source_index >= 0:
			samples[i] = lerpf(source[i], clampf(source[i] + source[source_index] * 0.72, -1.0, 1.0), mix)


static func _apply_phaser(samples: PackedFloat32Array, sample_rate: int, mix: float, rate_hz: float, depth: float) -> void:
	var source: PackedFloat32Array = samples.duplicate()
	var x1: float = 0.0
	var y1: float = 0.0
	var phase_step: float = TAU * rate_hz / float(sample_rate)
	var phase: float = 0.0
	for i: int in range(samples.size()):
		var lfo: float = 0.5 + 0.5 * sin(phase)
		phase += phase_step
		if phase >= TAU:
			phase -= TAU
		var coefficient: float = clampf(0.05 + lfo * depth * 0.9, 0.01, 0.95)
		var input_sample: float = source[i]
		var filtered: float = -coefficient * input_sample + x1 + coefficient * y1
		x1 = input_sample
		y1 = filtered
		samples[i] = lerpf(input_sample, clampf(input_sample + filtered * 0.7, -1.0, 1.0), mix)


static func _apply_brr_inspired(samples: PackedFloat32Array, amount: float) -> void:
	var a: float = clampf(amount, 0.0, 1.0)
	var previous: float = 0.0
	var predictor_gain: float = 0.35 + a * 0.45
	for i: int in range(samples.size()):
		var predicted: float = previous * predictor_gain
		var residual: float = samples[i] - predicted
		var quantized: float = round(clampf(residual, -1.0, 1.0) * 7.0) * 0.142857143
		var reconstructed: float = clampf(predicted + quantized, -1.0, 1.0)
		samples[i] = lerpf(samples[i], reconstructed, a)
		previous = reconstructed
