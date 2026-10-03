@tool
class_name GASSynthEngine
extends RefCounted

const RetroProfiles = preload("res://addons/gator_audio_studio/audio/retro_profiles.gd")
const HardwareRules = preload("res://addons/gator_audio_studio/audio/hardware_rules.gd")
const AdvancedDSP = preload("res://addons/gator_audio_studio/audio/advanced_dsp.gd")

const NOISE_WHITE := 0
const NOISE_PINK := 1
const NOISE_BROWN := 2
const NOISE_BLUE := 3
const NOISE_VIOLET := 4
const NOISE_DIGITAL := 5
const NOISE_PERIODIC := 6
const NOISE_METALLIC := 7
const NOISE_IMPULSE := 8
const NOISE_CRACKLE := 9


class FMRuntime:
	var ratio_0: float = 1.0
	var ratio_1: float = 2.0
	var ratio_2: float = 3.0
	var ratio_3: float = 4.0
	var level_0: float = 1.0
	var level_1: float = 0.8
	var level_2: float = 0.5
	var level_3: float = 0.35
	var env_0: PackedFloat32Array = PackedFloat32Array()
	var env_1: PackedFloat32Array = PackedFloat32Array()
	var env_2: PackedFloat32Array = PackedFloat32Array()
	var env_3: PackedFloat32Array = PackedFloat32Array()
	var algorithm: int = 0
	var opl_waveform: int = 0


static func render(params: Dictionary) -> Dictionary:
	# Stable public API. Keep this one-argument contract: the editor, batch worker,
	# and regression checks all depend on it.
	var profile_name: String = str(params.get("profile", RetroProfiles.MODERN))
	var profile: Dictionary = RetroProfiles.get_profile(profile_name)
	var sample_rate: int = int(profile.get("sample_rate", 44100))
	var default_accuracy: String = HardwareRules.MODE_HARDWARE if bool(params.get("hardware_limits", true)) else HardwareRules.MODE_STYLE
	var accuracy_mode: String = str(params.get("accuracy_mode", default_accuracy))
	if accuracy_mode == HardwareRules.MODE_STYLE and profile_name != RetroProfiles.MODERN:
		sample_rate = 48000
	if profile_name == RetroProfiles.FANTASY_RETRO and params.has("fantasy_sample_rate"):
		sample_rate = clampi(int(params.get("fantasy_sample_rate", sample_rate)), 4000, 48000)

	var layers: Array[Dictionary] = _collect_layers(params)
	if layers.size() == 1:
		return _render_single_result(layers[0], params, profile_name, sample_rate)
	return _render_layered_result(layers, params, profile_name, sample_rate)


static func _collect_layers(params: Dictionary) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var layers_value: Variant = params.get("layers", [])
	if layers_value is Array:
		var source_layers: Array = layers_value as Array
		for layer_value: Variant in source_layers:
			if layer_value is Dictionary:
				layers.append(layer_value as Dictionary)
	if layers.is_empty():
		layers.append(params)
	return layers


static func _render_single_result(
	layer: Dictionary,
	root_params: Dictionary,
	profile_name: String,
	sample_rate: int
) -> Dictionary:
	# Hot path for the common Primary-only case. No layered mixer allocation.
	var mono_samples: PackedFloat32Array = _render_layer_samples(layer, root_params, profile_name, sample_rate, 0)
	_fade_edges(mono_samples, sample_rate)
	_normalize_soft(mono_samples)
	var output_wav: AudioStreamWAV
	var delay_mode: String = str(layer.get("delay_mode", root_params.get("delay_mode", "Mono")))
	var layer_pan: float = clampf(float(layer.get("pan", 0.0)), -1.0, 1.0)
	if delay_mode == "Ping-Pong" and float(layer.get("echo_mix", 0.0)) > 0.00001:
		var ping_pong_data: Dictionary = AdvancedDSP.make_ping_pong_stereo(mono_samples, sample_rate, layer)
		var ping_left: PackedFloat32Array = ping_pong_data["left"] as PackedFloat32Array
		var ping_right: PackedFloat32Array = ping_pong_data["right"] as PackedFloat32Array
		output_wav = _samples_to_wav_stereo(ping_left, ping_right, sample_rate)
	elif absf(layer_pan) > 0.00001:
		var pan_data: Dictionary = AdvancedDSP.pan_to_stereo(mono_samples, layer_pan)
		var pan_left: PackedFloat32Array = pan_data["left"] as PackedFloat32Array
		var pan_right: PackedFloat32Array = pan_data["right"] as PackedFloat32Array
		output_wav = _samples_to_wav_stereo(pan_left, pan_right, sample_rate)
	else:
		output_wav = _samples_to_wav(mono_samples, sample_rate)
	return {
		"stream": output_wav,
		"samples": mono_samples,
		"sample_rate": sample_rate,
		"params": root_params
	}


static func _render_layered_result(
	layers: Array[Dictionary],
	root_params: Dictionary,
	profile_name: String,
	sample_rate: int
) -> Dictionary:
	var frame_count: int = _layered_frame_count(layers, root_params, sample_rate)
	var use_stereo: bool = _layers_require_stereo(layers)
	var mono_mix: PackedFloat32Array = PackedFloat32Array()
	mono_mix.resize(frame_count)

	if not use_stereo:
		_mix_layers_mono(mono_mix, layers, root_params, profile_name, sample_rate)
		_fade_edges(mono_mix, sample_rate)
		_normalize_soft(mono_mix)
		var mono_wav: AudioStreamWAV
		var root_delay_mode: String = str(root_params.get("delay_mode", "Mono"))
		if root_delay_mode == "Ping-Pong" and float(root_params.get("echo_mix", 0.0)) > 0.00001:
			var root_ping_data: Dictionary = AdvancedDSP.make_ping_pong_stereo(mono_mix, sample_rate, root_params)
			var root_ping_left: PackedFloat32Array = root_ping_data["left"] as PackedFloat32Array
			var root_ping_right: PackedFloat32Array = root_ping_data["right"] as PackedFloat32Array
			mono_wav = _samples_to_wav_stereo(root_ping_left, root_ping_right, sample_rate)
		else:
			mono_wav = _samples_to_wav(mono_mix, sample_rate)
		return {
			"stream": mono_wav,
			"samples": mono_mix,
			"sample_rate": sample_rate,
			"params": root_params
		}

	var left_mix: PackedFloat32Array = PackedFloat32Array()
	var right_mix: PackedFloat32Array = PackedFloat32Array()
	left_mix.resize(frame_count)
	right_mix.resize(frame_count)
	_mix_layers_stereo(left_mix, right_mix, layers, root_params, profile_name, sample_rate)
	_fade_edges(left_mix, sample_rate)
	_fade_edges(right_mix, sample_rate)
	_normalize_stereo_soft(left_mix, right_mix)
	for frame_index: int in range(frame_count):
		mono_mix[frame_index] = (left_mix[frame_index] + right_mix[frame_index]) * 0.5
	var stereo_wav: AudioStreamWAV = _samples_to_wav_stereo(left_mix, right_mix, sample_rate)
	return {
		"stream": stereo_wav,
		"samples": mono_mix,
		"sample_rate": sample_rate,
		"params": root_params
	}


static func _layered_frame_count(layers: Array[Dictionary], root_params: Dictionary, sample_rate: int) -> int:
	var max_frames: int = 1
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var duration: float = clampf(float(layer.get("duration", root_params.get("duration", 0.3))), 0.005, 8.0)
		var delay_seconds: float = maxf(0.0, float(layer.get("delay", 0.0)))
		var required_frames: int = int(ceil((duration + delay_seconds) * float(sample_rate)))
		max_frames = maxi(max_frames, required_frames)
	return max_frames


static func _layers_require_stereo(layers: Array[Dictionary]) -> bool:
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		if absf(float(layer.get("pan", 0.0))) > 0.00001:
			return true
		if str(layer.get("delay_mode", "Mono")) == "Ping-Pong" and float(layer.get("echo_mix", 0.0)) > 0.00001:
			return true
	return false


static func _mix_layers_mono(
	destination: PackedFloat32Array,
	layers: Array[Dictionary],
	root_params: Dictionary,
	profile_name: String,
	sample_rate: int
) -> void:
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		if float(layer.get("gain", 1.0)) <= 0.00001 or bool(layer.get("muted", false)):
			continue
		var layer_samples: PackedFloat32Array = _render_layer_samples(layer, root_params, profile_name, sample_rate, layer_index)
		var delay_frames: int = maxi(0, int(round(float(layer.get("delay", 0.0)) * float(sample_rate))))
		var available_frames: int = mini(layer_samples.size(), destination.size() - delay_frames)
		for frame_index: int in range(available_frames):
			destination[frame_index + delay_frames] += layer_samples[frame_index]


static func _mix_layers_stereo(
	left_destination: PackedFloat32Array,
	right_destination: PackedFloat32Array,
	layers: Array[Dictionary],
	root_params: Dictionary,
	profile_name: String,
	sample_rate: int
) -> void:
	for layer_index: int in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		if float(layer.get("gain", 1.0)) <= 0.00001 or bool(layer.get("muted", false)):
			continue
		var layer_samples: PackedFloat32Array = _render_layer_samples(layer, root_params, profile_name, sample_rate, layer_index)
		var delay_frames: int = maxi(0, int(round(float(layer.get("delay", 0.0)) * float(sample_rate))))
		var available_frames: int = mini(layer_samples.size(), left_destination.size() - delay_frames)
		var layer_pan: float = clampf(float(layer.get("pan", 0.0)), -1.0, 1.0)
		var pan_angle: float = (layer_pan + 1.0) * PI * 0.25
		var left_gain: float = cos(pan_angle)
		var right_gain: float = sin(pan_angle)
		var delay_mode: String = str(layer.get("delay_mode", "Mono"))
		if delay_mode == "Ping-Pong" and float(layer.get("echo_mix", 0.0)) > 0.00001:
			var ping_data: Dictionary = AdvancedDSP.make_ping_pong_stereo(layer_samples, sample_rate, layer)
			var ping_left: PackedFloat32Array = ping_data["left"] as PackedFloat32Array
			var ping_right: PackedFloat32Array = ping_data["right"] as PackedFloat32Array
			available_frames = mini(available_frames, mini(ping_left.size(), ping_right.size()))
			for frame_index: int in range(available_frames):
				var ping_destination_index: int = frame_index + delay_frames
				left_destination[ping_destination_index] += ping_left[frame_index] * left_gain
				right_destination[ping_destination_index] += ping_right[frame_index] * right_gain
		else:
			for frame_index: int in range(available_frames):
				var mono_destination_index: int = frame_index + delay_frames
				var sample_value: float = layer_samples[frame_index]
				left_destination[mono_destination_index] += sample_value * left_gain
				right_destination[mono_destination_index] += sample_value * right_gain


static func _render_layer_samples(
	layer: Dictionary,
	root_params: Dictionary,
	profile_name: String,
	sample_rate: int,
	layer_index: int
) -> PackedFloat32Array:
	var duration: float = clampf(float(layer.get("duration", root_params.get("duration", 0.3))), 0.005, 8.0)
	var frame_count: int = maxi(1, int(ceil(duration * float(sample_rate))))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(frame_count)

	var root_seed: int = int(root_params.get("seed", 1))
	var seed: int = int(layer.get("seed", root_seed + layer_index * 7919))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed

	var wave: String = str(layer.get("wave", root_params.get("wave", "Sine")))
	var start_hz: float = maxf(0.001, float(layer.get("start_hz", root_params.get("start_hz", 440.0))))
	var end_hz: float = maxf(0.001, float(layer.get("end_hz", root_params.get("end_hz", start_hz))))
	var pitch_slide: float = float(layer.get("pitch_slide", root_params.get("pitch_slide", 0.0)))
	var pitch_accel: float = float(layer.get("pitch_accel", root_params.get("pitch_accel", 0.0)))
	var vibrato_depth: float = float(layer.get("vibrato_depth", root_params.get("vibrato_depth", 0.0)))
	var vibrato_hz: float = float(layer.get("vibrato_hz", root_params.get("vibrato_hz", 6.0)))
	var tremolo_depth: float = float(layer.get("tremolo_depth", root_params.get("tremolo_depth", 0.0)))
	var tremolo_hz: float = float(layer.get("tremolo_hz", root_params.get("tremolo_hz", 7.0)))
	var am_depth: float = clampf(float(layer.get("am_depth", root_params.get("am_depth", 0.0))), 0.0, 1.0)
	var am_hz: float = float(layer.get("am_hz", root_params.get("am_hz", 12.0)))
	var ring_mod_depth: float = clampf(float(layer.get("ring_mod_depth", root_params.get("ring_mod_depth", 0.0))), 0.0, 1.0)
	var ring_mod_hz: float = float(layer.get("ring_mod_hz", root_params.get("ring_mod_hz", 220.0)))
	var fm_mod_depth: float = clampf(float(layer.get("fm_mod_depth", root_params.get("fm_mod_depth", 0.0))), 0.0, 1.0)
	var fm_mod_hz: float = float(layer.get("fm_mod_hz", root_params.get("fm_mod_hz", 80.0)))
	var pitch_mod_depth: float = clampf(float(layer.get("pitch_mod_depth", root_params.get("pitch_mod_depth", 0.0))), 0.0, 1.0)
	var osc_sync: bool = bool(layer.get("osc_sync", root_params.get("osc_sync", false)))
	var sync_hz: float = maxf(0.1, float(layer.get("sync_hz", root_params.get("sync_hz", start_hz * 0.5))))
	var ay_envelope_shape: int = int(layer.get("ay_envelope_shape", -1))
	var duty: float = float(layer.get("duty", root_params.get("duty", 0.5)))
	var duty_sweep: float = float(layer.get("duty_sweep", root_params.get("duty_sweep", 0.0)))
	var fm_ratio: float = float(layer.get("fm_ratio", root_params.get("fm_ratio", 2.0)))
	var fm_index: float = float(layer.get("fm_index", root_params.get("fm_index", 1.5)))
	var feedback: float = float(layer.get("feedback", root_params.get("feedback", 0.0)))
	var noise_mix: float = clampf(float(layer.get("noise_mix", root_params.get("noise_mix", 0.0))), 0.0, 1.0)
	var noise_density: float = clampf(float(layer.get("noise_density", root_params.get("noise_density", 1.0))), 0.0, 1.0)
	var drive: float = maxf(0.01, float(layer.get("drive", root_params.get("drive", 1.0))))
	var lowpass_hz: float = float(layer.get("lowpass_hz", root_params.get("lowpass_hz", 18000.0)))
	var highpass_hz: float = float(layer.get("highpass_hz", root_params.get("highpass_hz", 0.0)))
	var bandpass_hz: float = float(layer.get("bandpass_hz", root_params.get("bandpass_hz", 0.0)))
	var resonance: float = float(layer.get("resonance", root_params.get("resonance", 0.0)))
	var output_gain: float = float(layer.get("output_gain", root_params.get("output_gain", 0.78))) * float(layer.get("gain", 1.0))
	var quantize_bits: int = clampi(int(layer.get("quantize_bits", root_params.get("quantize_bits", 16))), 1, 16)
	var bitcrush_hz: float = float(layer.get("bitcrush_hz", root_params.get("bitcrush_hz", 0.0)))
	var sample_rate_reduce_hz: float = float(layer.get("sample_rate_reduce_hz", root_params.get("sample_rate_reduce_hz", 0.0)))
	if sample_rate_reduce_hz > 0.0 and (bitcrush_hz <= 0.0 or sample_rate_reduce_hz < bitcrush_hz):
		bitcrush_hz = sample_rate_reduce_hz
	var hardware_limits: bool = bool(root_params.get("hardware_limits", true))
	var attack: float = maxf(0.0, float(layer.get("attack", root_params.get("attack", 0.002))))
	var decay: float = maxf(0.0, float(layer.get("decay", root_params.get("decay", 0.08))))
	var sustain: float = clampf(float(layer.get("sustain", root_params.get("sustain", 0.35))), 0.0, 1.0)
	var release: float = maxf(0.001, float(layer.get("release", root_params.get("release", 0.08))))
	var filter_mode: String = str(layer.get("filter_mode", root_params.get("filter_mode", "Lowpass")))
	var noise_mode_id: int = _noise_mode_id(str(layer.get("noise_mode", root_params.get("noise_mode", "white"))))
	var noise_frequency: float = float(layer.get("noise_frequency", root_params.get("noise_frequency", 1000.0)))

	# Sample playback has its own compact path so sample-loop state does not bloat
	# the normal oscillator hot loop or its compiler register footprint.
	if wave == "Sample PCM":
		return _render_sample_pcm_layer(layer, root_params, sample_rate, frame_count)

	var arp: PackedFloat32Array = PackedFloat32Array()
	var arp_value: Variant = layer.get("arp", root_params.get("arp", []))
	if arp_value is PackedFloat32Array:
		arp = arp_value as PackedFloat32Array
	elif arp_value is Array:
		arp = PackedFloat32Array(arp_value as Array)
	var arp_count: int = arp.size()
	var note_sequence: PackedFloat32Array = PackedFloat32Array()
	var note_sequence_value: Variant = layer.get("note_sequence", [])
	if note_sequence_value is PackedFloat32Array:
		note_sequence = note_sequence_value as PackedFloat32Array
	elif note_sequence_value is Array:
		note_sequence = PackedFloat32Array(note_sequence_value as Array)
	var note_rate_hz: float = maxf(0.1, float(layer.get("note_rate_hz", 12.0)))
	var pokey_joined: bool = bool(layer.get("pokey_joined", false))
	var ay_shared_noise: bool = bool(layer.get("ay_shared_noise", false))

	var wavetable: PackedFloat32Array = PackedFloat32Array()
	var wavetable_value: Variant = layer.get("sample_data", PackedFloat32Array()) if wave == "Sample PCM" else layer.get("wavetable", PackedFloat32Array())
	if wavetable_value is PackedFloat32Array:
		wavetable = wavetable_value as PackedFloat32Array
	elif wavetable_value is Array:
		wavetable = PackedFloat32Array(wavetable_value as Array)

	# FM setup is isolated in a small typed runtime object. This keeps the main
	# oscillator function below the GDScript compiler complexity that caused the
	# 0.4.x renderer regression while preserving per-operator envelopes.
	var fm_runtime: FMRuntime = _build_fm_runtime(layer, root_params, frame_count, sample_rate, wave, fm_ratio)
	if wave == "FM2" or wave == "OPL Half-Sine" or wave == "OPL Abs-Sine" or wave == "FM4" or wave == "FM4 Advanced":
		fm_ratio = fm_runtime.ratio_1

	var inv_sample_rate: float = 1.0 / float(sample_rate)
	var inv_last_frame: float = 1.0 / float(maxi(1, frame_count - 1))
	var pitch_step: float = 1.0
	if frame_count > 1 and start_hz > 0.0 and end_hz > 0.0:
		pitch_step = pow(end_hz / start_hz, inv_last_frame)
	var base_hz: float = start_hz
	var slide_multiplier: float = pow(2.0, pitch_slide / (12.0 * float(sample_rate)))
	var accel_multiplier: float = pow(2.0, pitch_accel / (12.0 * float(sample_rate) * float(sample_rate)))
	var duty_step: float = duty_sweep / float(sample_rate)

	var apply_frequency_quantization: bool = hardware_limits and profile_name != RetroProfiles.MODERN
	var apply_amplitude_quantization: bool = quantize_bits < 16 and (hardware_limits or profile_name == RetroProfiles.FANTASY_RETRO)
	var is_fm2: bool = wave == "FM2" or wave == "OPL Half-Sine" or wave == "OPL Abs-Sine"
	var is_fm4: bool = wave == "FM4" or wave == "FM4 Advanced"
	var is_fm: bool = is_fm2 or is_fm4
	var is_lfsr_wave: bool = _is_lfsr_wave(wave)
	var needs_noise: bool = wave == "Noise" or noise_mix > 0.00001
	var needs_periodic_noise_phase: bool = needs_noise and (noise_mode_id == NOISE_PERIODIC or noise_mode_id == NOISE_METALLIC or noise_mode_id == NOISE_BLUE)
	var drive_enabled: bool = absf(drive - 1.0) > 0.00001
	var drive_normalizer: float = 1.0
	if drive_enabled:
		drive_normalizer = 1.0 / maxf(0.001, tanh(drive))

	# Filter coefficients are invariant for a layer, so calculate them once.
	var nyquist_limit: float = float(sample_rate) * 0.49
	var lp_enabled: bool = lowpass_hz > 0.0 and lowpass_hz < nyquist_limit
	var hp_enabled: bool = highpass_hz > 0.0 and highpass_hz < nyquist_limit
	var lp_alpha: float = 1.0
	if lp_enabled:
		lp_alpha = 1.0 - exp(-TAU * lowpass_hz * inv_sample_rate)
	var hp_alpha: float = 0.0
	if hp_enabled:
		var hp_rc: float = 1.0 / (TAU * highpass_hz)
		hp_alpha = hp_rc / (hp_rc + inv_sample_rate)

	var band_cutoff: float = bandpass_hz if bandpass_hz > 0.0 else lowpass_hz
	band_cutoff = clampf(band_cutoff, 20.0, nyquist_limit)
	var band_lp_alpha: float = 1.0 - exp(-TAU * band_cutoff * inv_sample_rate)
	var band_hp_hz: float = maxf(20.0, band_cutoff * 0.6)
	var band_rc: float = 1.0 / (TAU * band_hp_hz)
	var band_hp_alpha: float = band_rc / (band_rc + inv_sample_rate)
	var band_gain: float = 1.0 + resonance * 2.0

	var crush_enabled: bool = bitcrush_hz > 0.0 and bitcrush_hz < float(sample_rate)
	var hold_frames: int = 1
	if crush_enabled:
		hold_frames = maxi(1, int(round(float(sample_rate) / bitcrush_hz)))

	# Envelope boundaries in samples avoid a function call + divisions per frame.
	var attack_frames: int = clampi(int(round(attack * float(sample_rate))), 0, frame_count)
	var decay_frames: int = clampi(int(round(decay * float(sample_rate))), 0, frame_count)
	var release_frames: int = clampi(int(round(release * float(sample_rate))), 1, frame_count)
	var decay_end: int = mini(frame_count, attack_frames + decay_frames)
	var release_start: int = maxi(decay_end, frame_count - release_frames)
	var inv_attack_frames: float = 1.0 / float(maxi(1, attack_frames))
	var inv_decay_frames: float = 1.0 / float(maxi(1, decay_frames))
	var inv_release_frames: float = 1.0 / float(maxi(1, frame_count - release_start))

	var phase: float = 0.0
	var mod_phase: float = 0.0
	var mod2_phase: float = 0.0
	var vibrato_phase: float = 0.0
	var tremolo_phase: float = 0.0
	var am_phase: float = 0.0
	var ring_phase: float = 0.0
	var fm_lfo_phase: float = 0.0
	var sync_phase: float = 0.0
	var periodic_phase: float = 0.0
	var feedback_state: float = 0.0
	var noise_seed: int = root_seed if ay_shared_noise else seed
	var noise_state: int = 0x1FFFF & int(maxi(1, noise_seed * 1315423911))
	var noise_hold: float = 0.0
	var brown_state: float = 0.0
	var crackle_cooldown: int = 0
	var lowpass_state: float = 0.0
	var highpass_state: float = 0.0
	var highpass_input: float = 0.0
	var crush_hold: float = 0.0
	var crush_counter: int = 0

	var vibrato_phase_inc: float = vibrato_hz * inv_sample_rate
	var tremolo_phase_inc: float = tremolo_hz * inv_sample_rate
	var am_phase_inc: float = am_hz * inv_sample_rate
	var ring_phase_inc: float = ring_mod_hz * inv_sample_rate
	var fm_lfo_phase_inc: float = fm_mod_hz * inv_sample_rate
	var sync_phase_inc: float = sync_hz * inv_sample_rate
	var periodic_phase_inc: float = noise_frequency * inv_sample_rate
	var lfsr_bits: int = _lfsr_bits_for_wave(wave) if is_lfsr_wave else 15
	var lfsr_short: bool = _short_noise_for_wave(wave) if is_lfsr_wave else false

	for i: int in range(frame_count):
		var hz: float = base_hz
		base_hz *= pitch_step * slide_multiplier
		slide_multiplier *= accel_multiplier
		if duty_sweep != 0.0:
			duty = clampf(duty + duty_step, 0.01, 0.99)

		if arp_count > 0:
			var arp_index: int = mini(arp_count - 1, int(float(i) * float(arp_count) / float(frame_count)))
			hz *= float(arp[arp_index])

		if not note_sequence.is_empty():
			var note_index: int = int(floor(float(i) * inv_sample_rate * note_rate_hz)) % note_sequence.size()
			hz *= float(note_sequence[note_index])

		if fm_mod_depth > 0.00001 or pitch_mod_depth > 0.00001:
			var pitch_lfo: float = sin(TAU * fm_lfo_phase)
			hz *= 1.0 + pitch_lfo * maxf(fm_mod_depth, pitch_mod_depth)
			fm_lfo_phase += fm_lfo_phase_inc
			if fm_lfo_phase >= 1.0:
				fm_lfo_phase -= floor(fm_lfo_phase)

		if vibrato_depth != 0.0:
			hz *= 1.0 + sin(TAU * vibrato_phase) * vibrato_depth
			vibrato_phase += vibrato_phase_inc
			if vibrato_phase >= 1.0:
				vibrato_phase -= floor(vibrato_phase)

		if apply_frequency_quantization:
			if profile_name == RetroProfiles.POKEY and pokey_joined:
				hz = _quantize_pokey_joined(hz)
			else:
				hz = RetroProfiles.quantize_frequency(profile_name, hz, wave)

		var phase_inc: float = hz * inv_sample_rate
		var next_phase: float = phase + phase_inc
		var phase_wrapped: bool = next_phase >= 1.0
		phase = next_phase
		if phase >= 1.0:
			phase -= floor(phase)

		if is_fm:
			mod_phase += phase_inc * fm_ratio
			if mod_phase >= 1.0:
				mod_phase -= floor(mod_phase)
			if is_fm4:
				mod2_phase += phase_inc * (fm_ratio * 1.5 + 0.5)
				if mod2_phase >= 1.0:
					mod2_phase -= floor(mod2_phase)

		if needs_periodic_noise_phase:
			periodic_phase += periodic_phase_inc
			if periodic_phase >= 1.0:
				periodic_phase -= floor(periodic_phase)

		if osc_sync:
			sync_phase += sync_phase_inc
			if sync_phase >= 1.0:
				sync_phase -= floor(sync_phase)
				phase = 0.0

		var raw: float = _oscillator_fast(
			wave,
			phase,
			mod_phase,
			mod2_phase,
			duty,
			fm_index,
			feedback_state,
			noise_state,
			rng,
			wavetable,
			fm_runtime,
			i
		)

		if is_lfsr_wave:
			if phase_wrapped or i == 0:
				noise_state = _next_lfsr(noise_state, lfsr_bits, lfsr_short)
				noise_hold = 1.0 if (noise_state & 1) == 1 else -1.0
			raw = noise_hold

		if needs_noise:
			var noise_value: float = _noise_sample_fast(noise_mode_id, rng, periodic_phase, brown_state, crackle_cooldown, noise_density)
			if noise_mode_id == NOISE_BROWN:
				brown_state = noise_value
			if crackle_cooldown > 0:
				crackle_cooldown -= 1
			if noise_mode_id == NOISE_CRACKLE and absf(noise_value) > 0.9:
				crackle_cooldown = int(float(sample_rate) * 0.001)
			if wave == "Noise":
				raw = noise_value
			else:
				raw += (noise_value - raw) * noise_mix

		if ring_mod_depth > 0.00001:
			var ring_value: float = sin(TAU * ring_phase)
			raw *= lerpf(1.0, ring_value, ring_mod_depth)
			ring_phase += ring_phase_inc
			if ring_phase >= 1.0:
				ring_phase -= floor(ring_phase)

		if am_depth > 0.00001:
			var am_value: float = 0.5 + 0.5 * sin(TAU * am_phase)
			raw *= lerpf(1.0, am_value, am_depth)
			am_phase += am_phase_inc
			if am_phase >= 1.0:
				am_phase -= floor(am_phase)

		feedback_state = raw * feedback

		var env: float
		if attack_frames > 0 and i < attack_frames:
			env = float(i) * inv_attack_frames
		elif decay_frames > 0 and i < decay_end:
			env = 1.0 + (sustain - 1.0) * float(i - attack_frames) * inv_decay_frames
		elif i >= release_start:
			env = sustain * float(frame_count - i) * inv_release_frames
		else:
			env = sustain

		if ay_envelope_shape >= 0:
			var ay_u: float = float(i) / float(maxi(1, frame_count - 1))
			match ay_envelope_shape & 3:
				0: env *= 1.0 - ay_u
				1: env *= ay_u
				2: env *= absf(1.0 - fposmod(ay_u * 4.0, 2.0))
				3: env *= 1.0 if fposmod(ay_u * 8.0, 2.0) < 1.0 else 0.25

		if tremolo_depth > 0.0:
			env *= 1.0 - tremolo_depth * (0.5 + 0.5 * sin(TAU * tremolo_phase))
			tremolo_phase += tremolo_phase_inc
			if tremolo_phase >= 1.0:
				tremolo_phase -= 1.0

		raw *= env

		if drive_enabled:
			raw = tanh(raw * drive) * drive_normalizer

		var filtered: float = raw
		match filter_mode:
			"Lowpass":
				if lp_enabled:
					lowpass_state += (filtered - lowpass_state) * lp_alpha
					filtered = lowpass_state
			"Highpass":
				if hp_enabled:
					highpass_state = hp_alpha * (highpass_state + filtered - highpass_input)
					highpass_input = filtered
					filtered = highpass_state
			"Bandpass":
				lowpass_state += (filtered - lowpass_state) * band_lp_alpha
				highpass_state = band_hp_alpha * (highpass_state + lowpass_state - highpass_input)
				highpass_input = lowpass_state
				filtered = highpass_state * band_gain
			"Low+High":
				if lp_enabled:
					lowpass_state += (filtered - lowpass_state) * lp_alpha
					filtered = lowpass_state
				if hp_enabled:
					highpass_state = hp_alpha * (highpass_state + filtered - highpass_input)
					highpass_input = filtered
					filtered = highpass_state
			_:
				pass

		if crush_enabled:
			if crush_counter <= 0:
				crush_hold = filtered
				crush_counter = hold_frames
			crush_counter -= 1
			filtered = crush_hold

		if apply_amplitude_quantization:
			filtered = _quantize_amplitude(filtered, quantize_bits)

		samples[i] = filtered * output_gain

	AdvancedDSP.process_mono(samples, sample_rate, layer)
	return samples


static func _render_sample_pcm_layer(
	layer: Dictionary,
	root_params: Dictionary,
	sample_rate: int,
	frame_count: int
) -> PackedFloat32Array:
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(frame_count)
	var sample_data: PackedFloat32Array = PackedFloat32Array()
	var source_value: Variant = layer.get("sample_data", root_params.get("sample_data", PackedFloat32Array()))
	if source_value is PackedFloat32Array:
		sample_data = source_value as PackedFloat32Array
	elif source_value is Array:
		sample_data = PackedFloat32Array(source_value as Array)
	if sample_data.is_empty():
		return output
	if sample_data.size() == 1:
		var constant_gain: float = float(layer.get("output_gain", root_params.get("output_gain", 0.78))) * float(layer.get("gain", 1.0))
		for frame_index: int in range(frame_count):
			output[frame_index] = sample_data[0] * constant_gain
		AdvancedDSP.process_mono(output, sample_rate, layer)
		return output

	var source_rate: int = maxi(1, int(layer.get("sample_source_rate", root_params.get("sample_source_rate", 44100))))
	var playback_rate: float = clampf(float(layer.get("sample_playback_rate", root_params.get("sample_playback_rate", 1.0))), 0.01, 16.0)
	var reverse_playback: bool = bool(layer.get("sample_reverse", root_params.get("sample_reverse", false)))
	var loop_enabled: bool = bool(layer.get("sample_loop", root_params.get("sample_loop", false)))
	var loop_start_ratio: float = clampf(float(layer.get("sample_loop_start", root_params.get("sample_loop_start", 0.0))), 0.0, 0.999)
	var loop_end_ratio: float = clampf(float(layer.get("sample_loop_end", root_params.get("sample_loop_end", 1.0))), loop_start_ratio + 0.001, 1.0)
	var source_last_index: int = sample_data.size() - 1
	var loop_start_index: int = clampi(int(round(loop_start_ratio * float(source_last_index))), 0, source_last_index)
	var loop_end_index: int = clampi(int(round(loop_end_ratio * float(source_last_index))), loop_start_index + 1, source_last_index)
	var source_position: float = float(loop_end_index) if reverse_playback else float(loop_start_index)
	var source_step: float = playback_rate * float(source_rate) / float(sample_rate)
	if reverse_playback:
		source_step = -source_step

	var attack_seconds: float = maxf(0.0, float(layer.get("attack", root_params.get("attack", 0.0))))
	var decay_seconds: float = maxf(0.0, float(layer.get("decay", root_params.get("decay", 0.08))))
	var sustain_level: float = clampf(float(layer.get("sustain", root_params.get("sustain", 0.8))), 0.0, 1.0)
	var release_seconds: float = maxf(0.001, float(layer.get("release", root_params.get("release", 0.08))))
	var attack_frames: int = clampi(int(round(attack_seconds * float(sample_rate))), 0, frame_count)
	var decay_frames: int = clampi(int(round(decay_seconds * float(sample_rate))), 0, frame_count)
	var release_frames: int = clampi(int(round(release_seconds * float(sample_rate))), 1, frame_count)
	var decay_end: int = mini(frame_count, attack_frames + decay_frames)
	var release_start: int = maxi(decay_end, frame_count - release_frames)
	var inv_attack: float = 1.0 / float(maxi(1, attack_frames))
	var inv_decay: float = 1.0 / float(maxi(1, decay_frames))
	var inv_release: float = 1.0 / float(maxi(1, frame_count - release_start))

	var output_gain: float = float(layer.get("output_gain", root_params.get("output_gain", 0.78))) * float(layer.get("gain", 1.0))
	var bitcrush_hz: float = float(layer.get("bitcrush_hz", root_params.get("bitcrush_hz", 0.0)))
	var rate_reduce_hz: float = float(layer.get("sample_rate_reduce_hz", root_params.get("sample_rate_reduce_hz", 0.0)))
	if rate_reduce_hz > 0.0 and (bitcrush_hz <= 0.0 or rate_reduce_hz < bitcrush_hz):
		bitcrush_hz = rate_reduce_hz
	var crush_enabled: bool = bitcrush_hz > 0.0 and bitcrush_hz < float(sample_rate)
	var hold_frames: int = maxi(1, int(round(float(sample_rate) / maxf(1.0, bitcrush_hz)))) if crush_enabled else 1
	var hold_counter: int = 0
	var held_sample: float = 0.0

	var lowpass_hz: float = float(layer.get("lowpass_hz", root_params.get("lowpass_hz", 18000.0)))
	var highpass_hz: float = float(layer.get("highpass_hz", root_params.get("highpass_hz", 0.0)))
	var inv_sample_rate: float = 1.0 / float(sample_rate)
	var lowpass_enabled: bool = lowpass_hz > 0.0 and lowpass_hz < float(sample_rate) * 0.49
	var highpass_enabled: bool = highpass_hz > 0.0 and highpass_hz < float(sample_rate) * 0.49
	var lowpass_alpha: float = 1.0 - exp(-TAU * lowpass_hz * inv_sample_rate) if lowpass_enabled else 1.0
	var highpass_alpha: float = 0.0
	if highpass_enabled:
		var highpass_rc: float = 1.0 / (TAU * highpass_hz)
		highpass_alpha = highpass_rc / (highpass_rc + inv_sample_rate)
	var lowpass_state: float = 0.0
	var highpass_state: float = 0.0
	var highpass_input: float = 0.0

	var finished: bool = false
	for frame_index: int in range(frame_count):
		var source_index: int = clampi(int(source_position), 0, source_last_index)
		var next_index: int = source_index + (1 if source_step >= 0.0 else -1)
		next_index = clampi(next_index, 0, source_last_index)
		var fraction: float = absf(source_position - float(source_index))
		var sample_value: float = lerpf(sample_data[source_index], sample_data[next_index], fraction)
		if finished:
			sample_value = 0.0

		var envelope_value: float = sustain_level
		if attack_frames > 0 and frame_index < attack_frames:
			envelope_value = float(frame_index) * inv_attack
		elif decay_frames > 0 and frame_index < decay_end:
			envelope_value = 1.0 + (sustain_level - 1.0) * float(frame_index - attack_frames) * inv_decay
		elif frame_index >= release_start:
			envelope_value = sustain_level * float(frame_count - frame_index) * inv_release
		sample_value *= envelope_value

		if lowpass_enabled:
			lowpass_state += (sample_value - lowpass_state) * lowpass_alpha
			sample_value = lowpass_state
		if highpass_enabled:
			highpass_state = highpass_alpha * (highpass_state + sample_value - highpass_input)
			highpass_input = sample_value
			sample_value = highpass_state
		if crush_enabled:
			if hold_counter <= 0:
				held_sample = sample_value
				hold_counter = hold_frames
			hold_counter -= 1
			sample_value = held_sample
		output[frame_index] = sample_value * output_gain

		if not finished:
			source_position += source_step
			if source_step >= 0.0 and source_position >= float(loop_end_index):
				if loop_enabled:
					source_position = float(loop_start_index) + fposmod(source_position - float(loop_start_index), float(maxi(1, loop_end_index - loop_start_index)))
				else:
					finished = true
			elif source_step < 0.0 and source_position <= float(loop_start_index):
				if loop_enabled:
					var loop_length: float = float(maxi(1, loop_end_index - loop_start_index))
					source_position = float(loop_end_index) - fposmod(float(loop_start_index) - source_position, loop_length)
				else:
					finished = true

	AdvancedDSP.process_mono(output, sample_rate, layer)
	return output


static func _build_fm_runtime(
	layer: Dictionary,
	root_params: Dictionary,
	frame_count: int,
	sample_rate: int,
	wave: String,
	default_fm_ratio: float
) -> FMRuntime:
	var state: FMRuntime = FMRuntime.new()
	state.ratio_1 = default_fm_ratio
	state.algorithm = clampi(int(layer.get("fm_algorithm", root_params.get("fm_algorithm", 0))), 0, 7)
	state.opl_waveform = clampi(int(layer.get("opl_waveform", root_params.get("opl_waveform", 0))), 0, 3)
	var fm_enabled: bool = wave == "FM2" or wave == "OPL Half-Sine" or wave == "OPL Abs-Sine" or wave == "FM4" or wave == "FM4 Advanced"
	if not fm_enabled:
		return state
	var operators: Array[Dictionary] = []
	var operators_value: Variant = layer.get("fm_ops", root_params.get("fm_ops", []))
	if operators_value is Array:
		var operator_source: Array = operators_value as Array
		for operator_value: Variant in operator_source:
			if operator_value is Dictionary:
				operators.append(operator_value as Dictionary)
	if operators.size() >= 1:
		var operator_0: Dictionary = operators[0]
		state.ratio_0 = _operator_ratio(operator_0, state.ratio_0)
		state.level_0 = _operator_level(operator_0, state.level_0)
		state.env_0 = _build_operator_envelope(frame_count, sample_rate, operator_0)
	if operators.size() >= 2:
		var operator_1: Dictionary = operators[1]
		state.ratio_1 = _operator_ratio(operator_1, state.ratio_1)
		state.level_1 = _operator_level(operator_1, state.level_1)
		state.env_1 = _build_operator_envelope(frame_count, sample_rate, operator_1)
	if operators.size() >= 3:
		var operator_2: Dictionary = operators[2]
		state.ratio_2 = _operator_ratio(operator_2, state.ratio_2)
		state.level_2 = _operator_level(operator_2, state.level_2)
		state.env_2 = _build_operator_envelope(frame_count, sample_rate, operator_2)
	if operators.size() >= 4:
		var operator_3: Dictionary = operators[3]
		state.ratio_3 = _operator_ratio(operator_3, state.ratio_3)
		state.level_3 = _operator_level(operator_3, state.level_3)
		state.env_3 = _build_operator_envelope(frame_count, sample_rate, operator_3)
	return state


static func _operator_ratio(operator_data: Dictionary, fallback: float) -> float:
	var ratio: float = float(operator_data.get("ratio", fallback))
	var detune_cents: float = float(operator_data.get("detune", 0.0))
	return ratio * pow(2.0, detune_cents / 1200.0)


static func _operator_level(operator_data: Dictionary, fallback: float) -> float:
	var level: float = float(operator_data.get("level", fallback))
	var velocity: float = clampf(float(operator_data.get("velocity", 1.0)), 0.0, 1.0)
	return level * velocity


static func _build_operator_envelope(frame_count: int, sample_rate: int, operator_data: Dictionary) -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(frame_count)
	var attack_frames: int = clampi(int(round(float(operator_data.get("attack", 0.002)) * float(sample_rate))), 0, frame_count)
	var decay_frames: int = clampi(int(round(float(operator_data.get("decay", 0.08)) * float(sample_rate))), 0, frame_count)
	var release_frames: int = clampi(int(round(float(operator_data.get("release", 0.08)) * float(sample_rate))), 1, frame_count)
	var sustain_level: float = clampf(float(operator_data.get("sustain", 0.7)), 0.0, 1.0)
	var decay_end: int = mini(frame_count, attack_frames + decay_frames)
	var release_start: int = maxi(decay_end, frame_count - release_frames)
	var inv_attack: float = 1.0 / float(maxi(1, attack_frames))
	var inv_decay: float = 1.0 / float(maxi(1, decay_frames))
	var inv_release: float = 1.0 / float(maxi(1, frame_count - release_start))
	for frame_index: int in range(frame_count):
		if attack_frames > 0 and frame_index < attack_frames:
			values[frame_index] = float(frame_index) * inv_attack
		elif decay_frames > 0 and frame_index < decay_end:
			values[frame_index] = 1.0 + (sustain_level - 1.0) * float(frame_index - attack_frames) * inv_decay
		elif frame_index >= release_start:
			values[frame_index] = sustain_level * float(frame_count - frame_index) * inv_release
		else:
			values[frame_index] = sustain_level
	return values


static func _fm_level_at(base_level: float, envelope: PackedFloat32Array, frame_index: int) -> float:
	if envelope.is_empty():
		return base_level
	return base_level * envelope[frame_index]


static func _fm4_value(
	phase: float,
	mod_phase: float,
	mod2_phase: float,
	fm_index: float,
	feedback_state: float,
	state: FMRuntime,
	frame_index: int
) -> float:
	var level_0: float = _fm_level_at(state.level_0, state.env_0, frame_index)
	var level_1: float = _fm_level_at(state.level_1, state.env_1, frame_index)
	var level_2: float = _fm_level_at(state.level_2, state.env_2, frame_index)
	var level_3: float = _fm_level_at(state.level_3, state.env_3, frame_index)
	var raw4: float = sin(TAU * mod2_phase * state.ratio_3 + feedback_state * 1.5) * level_3
	var raw3: float = sin(TAU * mod_phase * state.ratio_2) * level_2
	var raw2: float = sin(TAU * phase * state.ratio_1) * level_1
	var raw1: float = sin(TAU * phase * state.ratio_0) * level_0
	match state.algorithm:
		0:
			var chain_3: float = sin(TAU * mod_phase * state.ratio_2 + raw4 * fm_index) * level_2
			var chain_2: float = sin(TAU * phase * state.ratio_1 + chain_3 * fm_index) * level_1
			return sin(TAU * phase * state.ratio_0 + chain_2 * fm_index) * level_0
		1:
			var pair_3: float = sin(TAU * mod_phase * state.ratio_2 + raw4 * fm_index) * level_2
			var pair_1: float = sin(TAU * phase * state.ratio_0 + raw2 * fm_index) * level_0
			return clampf((pair_1 + pair_3) * 0.62, -1.0, 1.0)
		2:
			var merge_3: float = sin(TAU * mod_phase * state.ratio_2 + raw4 * fm_index) * level_2
			var merge_mod: float = (merge_3 + raw2) * 0.5
			return sin(TAU * phase * state.ratio_0 + merge_mod * fm_index) * level_0
		3:
			var carrier_3: float = sin(TAU * mod_phase * state.ratio_2 + raw4 * fm_index) * level_2
			return clampf((raw1 + raw2 + carrier_3) * 0.45, -1.0, 1.0)
		4:
			var branch_2: float = sin(TAU * phase * state.ratio_1 + raw4 * fm_index) * level_1
			var branch_1: float = sin(TAU * phase * state.ratio_0 + branch_2 * fm_index) * level_0
			return clampf((branch_1 + raw3) * 0.6, -1.0, 1.0)
		5:
			var parallel_2: float = sin(TAU * phase * state.ratio_1 + raw4 * fm_index) * level_1
			var parallel_mod: float = (parallel_2 + raw3) * 0.5
			return sin(TAU * phase * state.ratio_0 + parallel_mod * fm_index) * level_0
		6:
			var upper_mod: float = (raw4 + raw3) * 0.5
			var upper_2: float = sin(TAU * phase * state.ratio_1 + upper_mod * fm_index) * level_1
			return sin(TAU * phase * state.ratio_0 + upper_2 * fm_index) * level_0
		_:
			return clampf((raw1 + raw2 + raw3 + raw4) * 0.35, -1.0, 1.0)


static func _oscillator_fast(
	wave: String,
	phase: float,
	mod_phase: float,
	mod2_phase: float,
	duty: float,
	fm_index: float,
	feedback_state: float,
	noise_state: int,
	rng: RandomNumberGenerator,
	wavetable: PackedFloat32Array,
	fm_runtime: FMRuntime,
	frame_index: int
) -> float:
	match wave:
		"Sine", "Sample Sine":
			return sin(TAU * phase)
		"Triangle", "SID Triangle":
			return 1.0 - 4.0 * absf(phase - 0.5)
		"NES Triangle":
			var step: int = int(phase * 32.0) & 31
			var tri: int = step if step < 16 else 31 - step
			return float(tri) / 7.5 - 1.0
		"Saw", "SID Saw", "Sample Saw":
			return phase * 2.0 - 1.0
		"Square", "TIA Tone", "POKEY Tone", "AY Square", "PSG Square":
			return 1.0 if phase < 0.5 else -1.0
		"Pulse", "NES Pulse", "GB Pulse", "SID Pulse":
			return 1.0 if phase < duty else -1.0
		"GB Wave", "Sample Wavetable", "Custom Wavetable", "Sample PCM", "NES DPCM":
			if wavetable.is_empty():
				var fallback_index: int = int(phase * 32.0) & 31
				var fallback_phase: float = TAU * float(fallback_index) / 32.0
				return clampf(sin(fallback_phase) * 0.62 + sin(fallback_phase * 3.0) * 0.24, -1.0, 1.0)
			var index: int = mini(wavetable.size() - 1, int(phase * float(wavetable.size())))
			return wavetable[index]
		"FM2", "OPL Half-Sine", "OPL Abs-Sine":
			var mod_level: float = _fm_level_at(fm_runtime.level_1, fm_runtime.env_1, frame_index)
			var carrier_level: float = _fm_level_at(fm_runtime.level_0, fm_runtime.env_0, frame_index)
			var modulator: float = _opl_wave(sin(TAU * mod_phase + feedback_state * 2.0), fm_runtime.opl_waveform) * mod_level
			var value: float = _opl_wave(sin(TAU * phase * fm_runtime.ratio_0 + modulator * fm_index), fm_runtime.opl_waveform) * carrier_level
			if wave == "OPL Half-Sine":
				return maxf(0.0, value) * 2.0 - 1.0
			if wave == "OPL Abs-Sine":
				return absf(value) * 2.0 - 1.0
			return value
		"FM4", "FM4 Advanced":
			return _fm4_value(phase, mod_phase, mod2_phase, fm_index, feedback_state, fm_runtime, frame_index)
		"Noise":
			return rng.randf() * 2.0 - 1.0
		_:
			return 1.0 if (noise_state & 1) == 1 else -1.0


static func _opl_wave(value: float, waveform: int) -> float:
	match waveform:
		1: return maxf(0.0, value)
		2: return absf(value) * 2.0 - 1.0
		3: return value if value >= 0.0 else 0.0
		_: return value


static func _quantize_pokey_joined(hz: float) -> float:
	var target: float = clampf(hz, 1.0, 20000.0)
	var divider: int = clampi(int(round(1789790.0 / (28.0 * target) - 1.0)), 0, 65535)
	return 1789790.0 / (28.0 * float(divider + 1))


static func _noise_mode_id(mode: String) -> int:
	match mode.to_lower():
		"pink": return NOISE_PINK
		"brown": return NOISE_BROWN
		"blue": return NOISE_BLUE
		"violet": return NOISE_VIOLET
		"digital": return NOISE_DIGITAL
		"periodic": return NOISE_PERIODIC
		"metallic": return NOISE_METALLIC
		"impulse": return NOISE_IMPULSE
		"crackle": return NOISE_CRACKLE
		_: return NOISE_WHITE


static func _noise_sample_fast(
	noise_mode_id: int,
	rng: RandomNumberGenerator,
	periodic_phase: float,
	brown_state: float,
	crackle_cooldown: int,
	density: float
) -> float:
	var d: float = clampf(density, 0.0, 1.0)
	var density_gate_allowed: bool = not (noise_mode_id in [NOISE_BROWN, NOISE_PERIODIC, NOISE_METALLIC])
	if d < 0.9999 and density_gate_allowed and rng.randf() > d:
		return 0.0
	match noise_mode_id:
		NOISE_PINK:
			var a: float = rng.randf() * 2.0 - 1.0
			var b: float = rng.randf() * 2.0 - 1.0
			var c: float = rng.randf() * 2.0 - 1.0
			return (a + b * 0.5 + c * 0.25) / 1.75
		NOISE_BROWN:
			return clampf(brown_state * 0.92 + (rng.randf() * 2.0 - 1.0) * 0.08 * maxf(0.05, d), -1.0, 1.0)
		NOISE_BLUE:
			return clampf((rng.randf() * 2.0 - 1.0) - sin(TAU * periodic_phase) * 0.25, -1.0, 1.0)
		NOISE_VIOLET:
			return clampf(((rng.randf() * 2.0 - 1.0) - (rng.randf() * 2.0 - 1.0)) * 0.7, -1.0, 1.0)
		NOISE_DIGITAL:
			return 1.0 if rng.randf() > 0.5 else -1.0
		NOISE_PERIODIC:
			return sin(TAU * periodic_phase) * d
		NOISE_METALLIC:
			return clampf((sin(TAU * periodic_phase * 7.0) * 0.6 + sin(TAU * periodic_phase * 11.0) * 0.4 + (rng.randf() * 0.3 - 0.15)) * d, -1.0, 1.0)
		NOISE_IMPULSE:
			return 1.0 if rng.randf() > (0.999 - d * 0.08) else 0.0
		NOISE_CRACKLE:
			if crackle_cooldown > 0:
				return 0.0
			return (rng.randf() * 2.0 - 1.0) if rng.randf() > (0.999 - d * 0.18) else 0.0
		_:
			return rng.randf() * 2.0 - 1.0


static func _is_lfsr_wave(wave: String) -> bool:
	match wave:
		"TIA Poly4", "TIA Poly5", "TIA Poly9", "NES Noise", "GB Noise", "PSG Noise", "SID Noise", "POKEY Poly4", "POKEY Poly5", "POKEY Poly17", "AY Noise", "Sample Noise":
			return true
		_:
			return false


static func _quantize_amplitude(value: float, bits: int) -> float:
	if bits >= 16:
		return value
	if bits <= 1:
		return 1.0 if value >= 0.0 else -1.0
	var levels: int = (1 << bits) - 1
	var normalized: float = value * 0.5 + 0.5
	var q: float = round(normalized * float(levels)) / float(levels)
	return q * 2.0 - 1.0


static func _next_lfsr(state: int, bits: int, short_mode: bool) -> int:
	var s: int = state
	if s == 0:
		s = 1
	var tap: int = 1 if not short_mode else 6
	var feedback_bit: int = (s ^ (s >> tap)) & 1
	s = (s >> 1) | (feedback_bit << (bits - 1))
	return s & ((1 << bits) - 1)


static func _lfsr_bits_for_wave(wave: String) -> int:
	match wave:
		"TIA Poly4", "POKEY Poly4": return 4
		"TIA Poly5", "POKEY Poly5": return 5
		"TIA Poly9": return 9
		"NES Noise": return 15
		"GB Noise": return 15
		"PSG Noise": return 15
		"SID Noise": return 17
		"POKEY Poly17": return 17
		"AY Noise": return 17
		_: return 15


static func _short_noise_for_wave(wave: String) -> bool:
	return wave == "GB Noise"


static func _apply_echo(samples: PackedFloat32Array, sample_rate: int, mix: float, delay_seconds: float) -> void:
	var wet: float = clampf(mix, 0.0, 0.75)
	if wet <= 0.0:
		return
	var delay_frames: int = maxi(1, int(round(delay_seconds * float(sample_rate))))
	for i: int in range(delay_frames, samples.size()):
		samples[i] += samples[i - delay_frames] * wet


static func _apply_reverb_like_tail(samples: PackedFloat32Array, sample_rate: int, mix: float) -> void:
	var wet: float = clampf(mix, 0.0, 0.6)
	if wet <= 0.0:
		return
	var tap_0: int = maxi(1, int(round(0.011 * float(sample_rate))))
	var tap_1: int = maxi(1, int(round(0.019 * float(sample_rate))))
	var tap_2: int = maxi(1, int(round(0.031 * float(sample_rate))))
	var tap_3: int = maxi(1, int(round(0.047 * float(sample_rate))))
	_apply_reverb_tap(samples, tap_0, wet * 0.55)
	_apply_reverb_tap(samples, tap_1, wet * 0.45)
	_apply_reverb_tap(samples, tap_2, wet * 0.35)
	_apply_reverb_tap(samples, tap_3, wet * 0.25)


static func _apply_reverb_tap(samples: PackedFloat32Array, delay_frames: int, gain: float) -> void:
	for i: int in range(delay_frames, samples.size()):
		samples[i] += samples[i - delay_frames] * gain


static func _normalize_soft(samples: PackedFloat32Array) -> void:
	var peak: float = 0.0
	for i: int in range(samples.size()):
		var magnitude: float = absf(samples[i])
		if magnitude > peak:
			peak = magnitude
	if peak <= 0.001:
		return
	var gain: float = minf(0.96 / peak, 1.2)
	if absf(gain - 1.0) <= 0.00001:
		return
	for i: int in range(samples.size()):
		samples[i] *= gain


static func _normalize_stereo_soft(left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	var count: int = mini(left.size(), right.size())
	var peak: float = 0.0
	for frame_index: int in range(count):
		var left_magnitude: float = absf(left[frame_index])
		var right_magnitude: float = absf(right[frame_index])
		peak = maxf(peak, maxf(left_magnitude, right_magnitude))
	if peak <= 0.001:
		return
	var gain: float = minf(0.96 / peak, 1.2)
	if absf(gain - 1.0) <= 0.00001:
		return
	for frame_index: int in range(count):
		left[frame_index] *= gain
		right[frame_index] *= gain


static func _fade_edges(samples: PackedFloat32Array, sample_rate: int) -> void:
	var half_size: int = int(samples.size() / 2)
	var edge: int = mini(half_size, maxi(1, int(float(sample_rate) * 0.0015)))
	var inv_edge: float = 1.0 / float(maxi(1, edge))
	for i: int in range(edge):
		var k: float = float(i) * inv_edge
		samples[i] *= k
		samples[samples.size() - 1 - i] *= k


static func _samples_to_wav(samples: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		var sample: float = clampf(samples[i], -1.0, 1.0)
		var value: int = clampi(int(round(sample * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, value)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


static func _samples_to_wav_stereo(left: PackedFloat32Array, right: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	var frame_count: int = mini(left.size(), right.size())
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frame_count * 4)
	for i: int in range(frame_count):
		var lv: int = clampi(int(round(left[i] * 32767.0)), -32768, 32767)
		var rv: int = clampi(int(round(right[i] * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 4, lv)
		bytes.encode_s16(i * 4 + 2, rv)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = true
	wav.data = bytes
	return wav


static func make_stream(samples: PackedFloat32Array, sample_rate: int) -> AudioStreamWAV:
	return _samples_to_wav(samples, sample_rate)
