@tool
class_name GASPresetBank
extends RefCounted

const RetroProfiles := preload("res://addons/gator_audio_studio/audio/retro_profiles.gd")
const HardwareRules := preload("res://addons/gator_audio_studio/audio/hardware_rules.gd")

const CATEGORY_ORDER: PackedStringArray = [
	"UI Confirm", "UI Cancel", "UI Hover", "UI Select", "UI Error", "Notification", "UI Popup",
	"Achievement", "Purchase", "Menu Open", "Menu Close", "Coin",
	"Pickup", "Jump", "Land", "Dash", "Hurt", "Heal", "Death", "Respawn", "Powerup", "Level Up",
	"Laser", "Plasma", "Projectile", "Gunshot", "Cannon", "Charge", "Fire", "Reload", "Empty", "Ricochet",
	"Light Impact", "Heavy Impact", "Metal Impact", "Wood Impact", "Stone Impact", "Glass Impact", "Flesh Impact", "Shield Impact",
	"Small Explosion", "Explosion", "Large Explosion", "Energy Explosion", "Retro Explosion", "Debris Explosion",
	"Footstep", "Slide", "Roll", "Whoosh", "Swing",
	"Wind", "Rain", "Fire Environment", "Water", "Electricity", "Machine", "Engine", "Hum",
	"Magic Cast", "Charge Magic", "Teleport", "Heal Magic", "Curse", "Aura",
	"Speech Blip", "Robot Blip", "Creature", "Chirp", "Growl", "Synthetic Voice", "Alarm",
	"Kick", "Snare", "Clap", "Hi-Hat", "Tom", "Cymbal", "Retro Percussion"
]

const PARAM_SPECS := {
	"duration": {"min": 0.02, "max": 8.0, "default": 0.32},
	"start_hz": {"min": 20.0, "max": 12000.0, "default": 440.0},
	"end_hz": {"min": 20.0, "max": 12000.0, "default": 440.0},
	"attack": {"min": 0.0, "max": 2.0, "default": 0.004},
	"decay": {"min": 0.0, "max": 3.0, "default": 0.08},
	"sustain": {"min": 0.0, "max": 1.0, "default": 0.35},
	"release": {"min": 0.001, "max": 4.0, "default": 0.08},
	"duty": {"min": 0.05, "max": 0.95, "default": 0.5},
	"vibrato_depth": {"min": 0.0, "max": 1.0, "default": 0.0},
	"vibrato_hz": {"min": 0.0, "max": 60.0, "default": 6.0},
	"noise_mix": {"min": 0.0, "max": 1.0, "default": 0.0},
	"drive": {"min": 0.1, "max": 6.0, "default": 1.0},
	"lowpass_hz": {"min": 50.0, "max": 22000.0, "default": 18000.0},
	"highpass_hz": {"min": 0.0, "max": 12000.0, "default": 0.0},
	"bandpass_hz": {"min": 0.0, "max": 12000.0, "default": 0.0},
	"resonance": {"min": 0.0, "max": 1.0, "default": 0.0},
	"fm_ratio": {"min": 0.1, "max": 12.0, "default": 2.0},
	"fm_index": {"min": 0.0, "max": 12.0, "default": 1.5},
	"feedback": {"min": 0.0, "max": 1.0, "default": 0.0},
	"echo_mix": {"min": 0.0, "max": 0.7, "default": 0.0},
	"reverb_mix": {"min": 0.0, "max": 0.6, "default": 0.0},
	"bitcrush_hz": {"min": 0.0, "max": 48000.0, "default": 0.0},
	"noise_frequency": {"min": 10.0, "max": 12000.0, "default": 1000.0},
	"output_gain": {"min": 0.05, "max": 1.5, "default": 0.78},
	"gain": {"min": 0.0, "max": 2.0, "default": 1.0},
	"delay": {"min": 0.0, "max": 2.0, "default": 0.0},
	"tremolo_depth": {"min": 0.0, "max": 1.0, "default": 0.0},
	"tremolo_hz": {"min": 0.1, "max": 60.0, "default": 7.0},
	"am_depth": {"min": 0.0, "max": 1.0, "default": 0.0},
	"am_hz": {"min": 0.1, "max": 2000.0, "default": 12.0},
	"ring_mod_depth": {"min": 0.0, "max": 1.0, "default": 0.0},
	"ring_mod_hz": {"min": 1.0, "max": 12000.0, "default": 220.0},
	"fm_mod_depth": {"min": 0.0, "max": 1.0, "default": 0.0},
	"fm_mod_hz": {"min": 0.1, "max": 2000.0, "default": 80.0},
	"distortion_mix": {"min": 0.0, "max": 1.0, "default": 0.0},
	"delay_feedback": {"min": 0.0, "max": 0.9, "default": 0.25},
	"chorus_mix": {"min": 0.0, "max": 1.0, "default": 0.0},
	"flanger_mix": {"min": 0.0, "max": 1.0, "default": 0.0},
	"phaser_mix": {"min": 0.0, "max": 1.0, "default": 0.0},
	"brr_amount": {"min": 0.0, "max": 1.0, "default": 0.0},
	"pitch_slide": {"min": -96.0, "max": 96.0, "default": 0.0},
	"pitch_accel": {"min": -192.0, "max": 192.0, "default": 0.0},
	"duty_sweep": {"min": -4.0, "max": 4.0, "default": 0.0},
	"noise_density": {"min": 0.0, "max": 1.0, "default": 1.0},
	"pan": {"min": -1.0, "max": 1.0, "default": 0.0},
	"sample_playback_rate": {"min": 0.05, "max": 8.0, "default": 1.0},
	"sample_rate_reduce_hz": {"min": 0.0, "max": 48000.0, "default": 0.0},
}

const MUTABLE_KEYS: PackedStringArray = [
	"duration", "start_hz", "end_hz", "attack", "decay", "sustain", "release",
	"duty", "vibrato_depth", "vibrato_hz", "noise_mix", "drive", "lowpass_hz", "highpass_hz",
	"bandpass_hz", "resonance", "fm_ratio", "fm_index", "feedback", "echo_mix", "reverb_mix",
	"bitcrush_hz", "noise_frequency", "output_gain", "gain", "delay",
	"tremolo_depth", "tremolo_hz", "am_depth", "am_hz", "ring_mod_depth", "ring_mod_hz",
	"fm_mod_depth", "fm_mod_hz", "distortion_mix", "delay_feedback", "chorus_mix", "flanger_mix",
	"phaser_mix", "brr_amount", "pitch_slide", "pitch_accel", "duty_sweep", "noise_density",
	"pan", "sample_playback_rate", "sample_rate_reduce_hz"
]


static func _set_default(target: Dictionary, key: String, value: Variant) -> void:
	if not target.has(key):
		target[key] = value


static func make_preset(profile_name: String, category: String, seed: int, hardware_limits: bool) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var p: Dictionary = _modern_base(category)
	p["profile"] = profile_name
	p["category"] = category
	p["seed"] = seed
	p["hardware_limits"] = hardware_limits
	p["accuracy_mode"] = HardwareRules.MODE_HARDWARE if hardware_limits else HardwareRules.MODE_STYLE
	_set_default(p, "quantize_bits", 16)
	_set_default(p, "crush_bits", 16)
	_set_default(p, "tremolo_hz", 7.0)
	_set_default(p, "am_depth", 0.0)
	_set_default(p, "am_hz", 12.0)
	_set_default(p, "ring_mod_depth", 0.0)
	_set_default(p, "ring_mod_hz", 220.0)
	_set_default(p, "fm_mod_depth", 0.0)
	_set_default(p, "fm_mod_hz", 80.0)
	_set_default(p, "distortion_mode", "Soft Clip")
	_set_default(p, "distortion_mix", 0.0)
	_set_default(p, "delay_mode", "Mono")
	_set_default(p, "delay_feedback", 0.25)
	_set_default(p, "delay_taps", 4)
	_set_default(p, "reverb_size", 0.5)
	_set_default(p, "reverb_damping", 0.4)
	_set_default(p, "chorus_mix", 0.0)
	_set_default(p, "chorus_rate", 0.8)
	_set_default(p, "chorus_depth_ms", 8.0)
	_set_default(p, "flanger_mix", 0.0)
	_set_default(p, "flanger_rate", 0.35)
	_set_default(p, "flanger_depth_ms", 2.0)
	_set_default(p, "phaser_mix", 0.0)
	_set_default(p, "phaser_rate", 0.45)
	_set_default(p, "phaser_depth", 0.7)
	_set_default(p, "brr_amount", 0.0)
	_set_default(p, "pitch_slide", 0.0)
	_set_default(p, "pitch_accel", 0.0)
	_set_default(p, "duty_sweep", 0.0)
	_set_default(p, "noise_density", 1.0)
	_set_default(p, "pan", 0.0)
	_set_default(p, "sample_playback_rate", 1.0)
	_set_default(p, "sample_rate_reduce_hz", 0.0)
	_set_default(p, "sample_loop", false)
	_set_default(p, "sample_reverse", false)
	_set_default(p, "sample_loop_start", 0.0)
	_set_default(p, "sample_loop_end", 1.0)
	p["metadata"] = {"generator_version": "0.4.1", "profile": profile_name, "category": category, "seed": seed}
	_set_default(p, "filter_mode", "Lowpass")
	_set_default(p, "noise_mode", "white")
	_set_default(p, "reverb_mix", 0.0)
	_set_default(p, "bandpass_hz", 0.0)
	_set_default(p, "resonance", 0.0)
	p["generation_ranges"] = _default_generation_ranges()
	p["locks"] = {}
	p["fm_ops"] = _default_fm_ops()
	p["wavetable"] = _default_wavetable(32, "sine")
	p["layers"] = _build_modern_layers(p, category, rng)

	if profile_name != RetroProfiles.MODERN:
		_apply_retro_profile(p, profile_name, category, rng, hardware_limits)
		if not p.has("layers") or (p["layers"] as Array).is_empty():
			p["layers"] = [_make_layer_from_params(p, "Primary")]
		if hardware_limits:
			p = HardwareRules.apply_constraints(p, profile_name, HardwareRules.MODE_HARDWARE)

	return p


static func make_preset_with_mode(profile_name: String, category: String, seed: int, accuracy_mode: String) -> Dictionary:
	var p: Dictionary = make_preset(profile_name, category, seed, accuracy_mode == HardwareRules.MODE_HARDWARE)
	p["accuracy_mode"] = accuracy_mode
	if profile_name != RetroProfiles.MODERN:
		p = HardwareRules.apply_constraints(p, profile_name, accuracy_mode)
	return p


static func make_generated_preset(profile_name: String, category: String, seed: int, hardware_limits: bool, ranges: Dictionary = {}, locks: Dictionary = {}) -> Dictionary:
	var p: Dictionary = make_preset(profile_name, category, seed, hardware_limits)
	p["generation_ranges"] = ranges.duplicate(true) if not ranges.is_empty() else _default_generation_ranges()
	p["locks"] = locks.duplicate(true)
	return mutate(p, seed, 0.45)


static func mutate(source: Dictionary, seed: int, amount: float) -> Dictionary:
	var out: Dictionary = source.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var a: float = clampf(amount, 0.0, 1.0)
	var ranges: Dictionary = out.get("generation_ranges", _default_generation_ranges())
	var locks: Dictionary = out.get("locks", {})
	var profile_name: String = str(out.get("profile", RetroProfiles.MODERN))
	for key: String in MUTABLE_KEYS:
		if not out.has(key):
			continue
		if bool(locks.get(key, false)):
			continue
		if profile_name == RetroProfiles.MODERN and key == "noise_mix" and float(source.get("noise_mix", 0.0)) <= 0.00001 and str(source.get("wave", "")) != "Noise":
			out[key] = 0.0
			continue
		out[key] = _mutate_value(float(out[key]), key, a * _system_mutation_scale(profile_name, key), rng, ranges)
	if out.has("layers"):
		var new_layers: Array[Dictionary] = []
		for layer: Variant in out["layers"]:
			var ld: Dictionary = (layer as Dictionary).duplicate(true)
			for key: String in MUTABLE_KEYS:
				if not ld.has(key):
					continue
				if bool(locks.get("layer_" + key, false)):
					continue
				if profile_name == RetroProfiles.MODERN and key == "noise_mix" and float(ld.get("noise_mix", 0.0)) <= 0.00001 and str(ld.get("wave", "")) != "Noise":
					ld[key] = 0.0
					continue
				ld[key] = _mutate_value(float(ld[key]), key, a * _system_mutation_scale(profile_name, key), rng, ranges)
			if a > 0.6 and rng.randf() < a * 0.2 and ld.has("noise_mode"):
				ld["noise_mode"] = _random_noise_mode(rng)
			new_layers.append(ld)
		out["layers"] = new_layers
	if out.has("fm_ops"):
		var ops: Array[Dictionary] = []
		for op: Variant in out["fm_ops"]:
			var opd: Dictionary = (op as Dictionary).duplicate(true)
			opd["ratio"] = clampf(float(opd.get("ratio", 1.0)) + rng.randf_range(-a * 1.5, a * 1.5), 0.1, 12.0)
			opd["detune"] = clampf(float(opd.get("detune", 0.0)) + rng.randf_range(-a * 40.0, a * 40.0), -100.0, 100.0)
			opd["level"] = clampf(float(opd.get("level", 1.0)) + rng.randf_range(-a * 0.4, a * 0.4), 0.0, 1.5)
			opd["attack"] = clampf(float(opd.get("attack", 0.002)) + rng.randf_range(-a * 0.05, a * 0.05), 0.0, 2.0)
			opd["decay"] = clampf(float(opd.get("decay", 0.08)) + rng.randf_range(-a * 0.12, a * 0.12), 0.0, 3.0)
			opd["sustain"] = clampf(float(opd.get("sustain", 0.7)) + rng.randf_range(-a * 0.25, a * 0.25), 0.0, 1.0)
			opd["release"] = clampf(float(opd.get("release", 0.08)) + rng.randf_range(-a * 0.12, a * 0.12), 0.001, 4.0)
			opd["velocity"] = clampf(float(opd.get("velocity", 1.0)) + rng.randf_range(-a * 0.25, a * 0.25), 0.0, 1.0)
			ops.append(opd)
		out["fm_ops"] = ops
	out["seed"] = seed
	if out.has("metadata") and out["metadata"] is Dictionary:
		var meta: Dictionary = out["metadata"]
		meta["seed"] = seed
		out["metadata"] = meta
	if str(out.get("accuracy_mode", HardwareRules.MODE_STYLE)) == HardwareRules.MODE_HARDWARE and profile_name != RetroProfiles.MODERN:
		out = HardwareRules.apply_constraints(out, profile_name, HardwareRules.MODE_HARDWARE)
	return out


static func randomize_parameters(source: Dictionary, seed: int) -> Dictionary:
	var out: Dictionary = source.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var ranges: Dictionary = out.get("generation_ranges", _default_generation_ranges())
	var locks: Dictionary = out.get("locks", {})
	for key: String in MUTABLE_KEYS:
		if not out.has(key) or bool(locks.get(key, false)):
			continue
		var spec: Dictionary = PARAM_SPECS.get(key, {"min": 0.0, "max": 1.0})
		var rule: Dictionary = ranges.get(key, spec)
		var low: float = float(rule.get("min", spec.get("min", 0.0)))
		var high: float = float(rule.get("max", spec.get("max", 1.0)))
		if high < low:
			var temp: float = low
			low = high
			high = temp
		out[key] = rng.randf_range(low, high)
	if out.has("layers"):
		var new_layers: Array[Dictionary] = []
		for layer: Dictionary in _dictionary_array(out["layers"]):
			var copy: Dictionary = layer.duplicate(true)
			for key: String in MUTABLE_KEYS:
				if not copy.has(key) or bool(locks.get("layer_" + key, false)):
					continue
				var spec: Dictionary = PARAM_SPECS.get(key, {"min": 0.0, "max": 1.0})
				var rule: Dictionary = ranges.get(key, spec)
				copy[key] = rng.randf_range(float(rule.get("min", spec.get("min", 0.0))), float(rule.get("max", spec.get("max", 1.0))))
			new_layers.append(copy)
		out["layers"] = new_layers
	out["seed"] = seed
	return out


static func breed(parent_a: Dictionary, parent_b: Dictionary, seed: int, bias: float) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var out: Dictionary = parent_a.duplicate(true)
	var b: float = clampf(bias, 0.0, 1.0)
	for key: String in MUTABLE_KEYS:
		if parent_a.has(key) and parent_b.has(key):
			var av: float = float(parent_a[key])
			var bv: float = float(parent_b[key])
			var t: float = clampf(0.5 + (b - 0.5) * 0.9 + rng.randf_range(-0.18, 0.18), 0.0, 1.0)
			out[key] = lerpf(av, bv, t)
	if parent_a.has("wave") and parent_b.has("wave"):
		out["wave"] = parent_a["wave"] if rng.randf() > b else parent_b["wave"]
	if parent_a.has("noise_mode") and parent_b.has("noise_mode"):
		out["noise_mode"] = parent_a["noise_mode"] if rng.randf() > b else parent_b["noise_mode"]
	if parent_a.has("layers") and parent_b.has("layers"):
		var layers_a: Array[Dictionary] = _dictionary_array(parent_a.get("layers", []))
		var layers_b: Array[Dictionary] = _dictionary_array(parent_b.get("layers", []))
		var count: int = mini(maxi(layers_a.size(), 1), maxi(layers_b.size(), 1))
		var out_layers: Array[Dictionary] = []
		for i: int in range(count):
			var la: Dictionary = layers_a[mini(i, layers_a.size() - 1)]
			var lb: Dictionary = layers_b[mini(i, layers_b.size() - 1)]
			var child: Dictionary = la.duplicate(true)
			for key: String in MUTABLE_KEYS:
				if la.has(key) and lb.has(key):
					child[key] = lerpf(float(la[key]), float(lb[key]), clampf(b + rng.randf_range(-0.15, 0.15), 0.0, 1.0))
			child["wave"] = la.get("wave", child.get("wave", "Sine")) if rng.randf() > b else lb.get("wave", child.get("wave", "Sine"))
			out_layers.append(child)
		out["layers"] = out_layers
	out["seed"] = seed
	return out


static func make_workspace_preset(workspace: String, subtype: String, seed: int) -> Dictionary:
	var p: Dictionary = make_preset(RetroProfiles.MODERN, "UI Confirm", seed, false)
	match workspace:
		"Noise":
			p["category"] = "Noise Generator"
			p["wave"] = "Noise"
			p["noise_mode"] = subtype.to_lower()
			p["duration"] = 0.6
			p["attack"] = 0.0
			p["decay"] = 0.08
			p["sustain"] = 0.55
			p["release"] = 0.18
			p["filter_mode"] = "Bandpass"
			p["bandpass_hz"] = 2400.0
			p["resonance"] = 0.25
			p["layers"] = [_make_layer_from_params(p, subtype + " Noise")]
		"Drum":
			p = _drum_preset(subtype, seed)
		"Voice":
			p = _voice_preset(subtype, seed)
		"Foley":
			p = _foley_preset(subtype, seed)
		"Sample":
			p["category"] = "Sample Synth"
			p["wave"] = "Sample PCM"
			p["duration"] = 0.5
			p["sample_playback_rate"] = 1.0
			p["sample_loop"] = false
			p["sample_reverse"] = false
			p["sample_loop_start"] = 0.0
			p["sample_loop_end"] = 1.0
			p["layers"] = [_make_layer_from_params(p, "Sample Voice")]
	return p


static func _mutate_value(old: float, key: String, amount: float, rng: RandomNumberGenerator, ranges: Dictionary) -> float:
	var spec: Dictionary = PARAM_SPECS.get(key, {"min": 0.0, "max": 1.0, "default": 0.0})
	var rule: Dictionary = ranges.get(key, {"min": spec["min"], "max": spec["max"]})
	var low: float = float(rule.get("min", spec["min"]))
	var high: float = float(rule.get("max", spec["max"]))
	if high < low:
		var tmp: float = low
		low = high
		high = tmp
	if absf(old) <= 0.00001:
		return clampf(lerpf(low, high, rng.randf() * amount), low, high)
	var span: float = high - low
	var delta: float = rng.randf_range(-1.0, 1.0) * maxf(span * 0.42 * amount, absf(old) * 0.55 * amount)
	return clampf(old + delta, low, high)


static func _default_generation_ranges() -> Dictionary:
	var d: Dictionary = {}
	for key_value: Variant in PARAM_SPECS.keys():
		var key: String = str(key_value)
		var spec: Dictionary = PARAM_SPECS[key]
		d[key] = {"min": spec["min"], "max": spec["max"]}
	return d


static func _default_fm_ops() -> Array[Dictionary]:
	return [
		{"ratio": 1.0, "detune": 0.0, "level": 1.0, "attack": 0.002, "decay": 0.08, "sustain": 0.8, "release": 0.08, "velocity": 1.0},
		{"ratio": 2.0, "detune": 0.0, "level": 0.8, "attack": 0.002, "decay": 0.10, "sustain": 0.65, "release": 0.09, "velocity": 1.0},
		{"ratio": 3.0, "detune": 0.0, "level": 0.5, "attack": 0.002, "decay": 0.12, "sustain": 0.5, "release": 0.10, "velocity": 1.0},
		{"ratio": 4.0, "detune": 0.0, "level": 0.35, "attack": 0.002, "decay": 0.14, "sustain": 0.4, "release": 0.12, "velocity": 1.0},
	]


static func _default_wavetable(size: int, mode: String) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(size)
	for i: int in range(size):
		var u: float = float(i) / float(size)
		match mode:
			"triangle": out[i] = 1.0 - 4.0 * absf(u - 0.5)
			"saw": out[i] = u * 2.0 - 1.0
			"square": out[i] = 1.0 if u < 0.5 else -1.0
			_: out[i] = sin(TAU * u)
	return out


static func _modern_base(category: String) -> Dictionary:
	var requested_category: String = category
	category = _canonical_category(category)
	var p: Dictionary = {
		"duration": 0.32,
		"wave": "Sine",
		"start_hz": 440.0,
		"end_hz": 440.0,
		"attack": 0.004,
		"decay": 0.08,
		"sustain": 0.35,
		"release": 0.08,
		"duty": 0.5,
		"duty_sweep": 0.0,
		"vibrato_depth": 0.0,
		"vibrato_hz": 6.0,
		"tremolo_depth": 0.0,
		"tremolo_hz": 7.0,
		"am_depth": 0.0,
		"am_hz": 12.0,
		"ring_mod_depth": 0.0,
		"ring_mod_hz": 220.0,
		"fm_mod_depth": 0.0,
		"fm_mod_hz": 80.0,
		"noise_mix": 0.0,
		"noise_density": 1.0,
		"drive": 1.0,
		"distortion_mode": "Soft Clip",
		"distortion_mix": 0.0,
		"lowpass_hz": 18000.0,
		"highpass_hz": 0.0,
		"output_gain": 0.78,
		"fm_ratio": 2.0,
		"fm_index": 1.5,
		"feedback": 0.0,
		"echo_mix": 0.0,
		"echo_delay": 0.12,
		"delay_mode": "Mono",
		"delay_feedback": 0.25,
		"delay_taps": 4,
		"reverb_mix": 0.0,
		"reverb_size": 0.5,
		"reverb_damping": 0.4,
		"chorus_mix": 0.0,
		"chorus_rate": 0.8,
		"chorus_depth_ms": 8.0,
		"flanger_mix": 0.0,
		"flanger_rate": 0.35,
		"flanger_depth_ms": 2.0,
		"phaser_mix": 0.0,
		"phaser_rate": 0.45,
		"phaser_depth": 0.7,
		"bitcrush_hz": 0.0,
		"crush_bits": 16,
		"quantize_bits": 16,
		"brr_amount": 0.0,
		"noise_mode": "white",
		"filter_mode": "Lowpass",
		"arp": [],
	}
	match category:
		"UI Confirm": p.merge({"duration": 0.14, "wave": "Sine", "start_hz": 660.0, "end_hz": 980.0, "attack": 0.001, "decay": 0.05, "sustain": 0.15, "release": 0.04}, true)
		"UI Cancel": p.merge({"duration": 0.16, "wave": "Triangle", "start_hz": 420.0, "end_hz": 220.0, "release": 0.05}, true)
		"UI Hover": p.merge({"duration": 0.055, "wave": "Sine", "start_hz": 900.0, "end_hz": 1050.0, "attack": 0.0, "decay": 0.02, "sustain": 0.15, "release": 0.02}, true)
		"UI Error": p.merge({"duration": 0.22, "wave": "Square", "start_hz": 190.0, "end_hz": 145.0, "drive": 1.5, "release": 0.07}, true)
		"Notification": p.merge({"duration": 0.32, "wave": "Sine", "start_hz": 520.0, "end_hz": 780.0, "arp": [1.0, 1.25, 1.5], "release": 0.09}, true)
		"Achievement": p.merge({"duration": 0.58, "wave": "Triangle", "start_hz": 440.0, "end_hz": 660.0, "arp": [1.0, 1.25, 1.5, 2.0], "echo_mix": 0.15, "reverb_mix": 0.18, "release": 0.16}, true)
		"Coin": p.merge({"duration": 0.18, "wave": "Square", "start_hz": 880.0, "end_hz": 1320.0, "arp": [1.0, 1.5], "release": 0.04}, true)
		"Pickup": p.merge({"duration": 0.16, "wave": "Triangle", "start_hz": 500.0, "end_hz": 1100.0, "release": 0.04}, true)
		"Jump": p.merge({"duration": 0.24, "wave": "Square", "start_hz": 280.0, "end_hz": 720.0, "duty": 0.25, "release": 0.055}, true)
		"Land": p.merge({"duration": 0.18, "wave": "Noise", "start_hz": 110.0, "end_hz": 70.0, "noise_mix": 0.75, "lowpass_hz": 900.0, "release": 0.08}, true)
		"Hurt": p.merge({"duration": 0.28, "wave": "Saw", "start_hz": 340.0, "end_hz": 95.0, "drive": 1.35, "vibrato_depth": 0.05, "vibrato_hz": 18.0, "release": 0.08}, true)
		"Powerup": p.merge({"duration": 0.64, "wave": "Square", "start_hz": 220.0, "end_hz": 1000.0, "arp": [1.0, 1.25, 1.5, 2.0], "vibrato_depth": 0.025, "release": 0.12}, true)
		"Level Up": p.merge({"duration": 0.8, "wave": "Triangle", "start_hz": 330.0, "end_hz": 660.0, "arp": [1.0, 1.25, 1.5, 2.0, 2.5], "echo_mix": 0.1, "reverb_mix": 0.15, "release": 0.18}, true)
		"Laser": p.merge({"duration": 0.3, "wave": "Saw", "start_hz": 1500.0, "end_hz": 180.0, "drive": 1.25, "release": 0.05}, true)
		"Plasma": p.merge({"duration": 0.42, "wave": "FM2", "start_hz": 1100.0, "end_hz": 160.0, "fm_ratio": 3.1, "fm_index": 3.4, "drive": 1.2, "release": 0.1}, true)
		"Gunshot": p.merge({"duration": 0.42, "wave": "Noise", "start_hz": 180.0, "end_hz": 70.0, "noise_mix": 1.0, "attack": 0.0, "decay": 0.045, "sustain": 0.08, "release": 0.22, "drive": 2.1, "lowpass_hz": 5500.0}, true)
		"Cannon": p.merge({"duration": 0.75, "wave": "Noise", "start_hz": 120.0, "end_hz": 42.0, "noise_mix": 0.8, "drive": 2.0, "lowpass_hz": 1800.0, "release": 0.45}, true)
		"Reload": p.merge({"duration": 0.22, "wave": "Noise", "start_hz": 1600.0, "end_hz": 900.0, "noise_mix": 0.45, "lowpass_hz": 6500.0, "release": 0.06}, true)
		"Ricochet": p.merge({"duration": 0.34, "wave": "Sine", "start_hz": 1600.0, "end_hz": 630.0, "vibrato_depth": 0.08, "vibrato_hz": 30.0, "release": 0.13}, true)
		"Light Impact": p.merge({"duration": 0.16, "wave": "Noise", "start_hz": 500.0, "end_hz": 120.0, "noise_mix": 0.65, "lowpass_hz": 2800.0, "release": 0.055}, true)
		"Heavy Impact": p.merge({"duration": 0.44, "wave": "Noise", "start_hz": 170.0, "end_hz": 45.0, "noise_mix": 0.55, "drive": 1.5, "lowpass_hz": 1400.0, "release": 0.23}, true)
		"Explosion": p.merge({"duration": 0.85, "wave": "Noise", "start_hz": 220.0, "end_hz": 38.0, "noise_mix": 1.0, "drive": 1.8, "lowpass_hz": 2400.0, "release": 0.52}, true)
		"Engine": p.merge({"duration": 0.75, "wave": "Saw", "start_hz": 72.0, "end_hz": 110.0, "vibrato_depth": 0.14, "vibrato_hz": 18.0, "drive": 1.4, "release": 0.12}, true)
		"Whoosh": p.merge({"duration": 0.48, "wave": "Noise", "start_hz": 180.0, "end_hz": 900.0, "noise_mix": 1.0, "lowpass_hz": 4300.0, "release": 0.16}, true)
		"Magic Cast": p.merge({"duration": 0.62, "wave": "FM2", "start_hz": 260.0, "end_hz": 980.0, "fm_ratio": 2.65, "fm_index": 2.5, "vibrato_depth": 0.04, "echo_mix": 0.18, "reverb_mix": 0.22, "release": 0.2}, true)
		"Teleport": p.merge({"duration": 0.72, "wave": "FM2", "start_hz": 120.0, "end_hz": 1700.0, "fm_ratio": 1.414, "fm_index": 4.0, "echo_mix": 0.16, "reverb_mix": 0.18, "release": 0.2}, true)
		"Heal": p.merge({"duration": 0.6, "wave": "Sine", "start_hz": 360.0, "end_hz": 760.0, "arp": [1.0, 1.25, 1.5, 2.0], "echo_mix": 0.12, "reverb_mix": 0.18, "release": 0.2}, true)
		"Speech Blip": p.merge({"duration": 0.08, "wave": "Square", "start_hz": 240.0, "end_hz": 255.0, "duty": 0.25, "release": 0.03}, true)
		"Robot Blip": p.merge({"duration": 0.11, "wave": "FM2", "start_hz": 210.0, "end_hz": 220.0, "fm_ratio": 2.0, "fm_index": 2.0, "bitcrush_hz": 8000.0, "release": 0.04}, true)
		"Alarm": p.merge({"duration": 0.65, "wave": "Square", "start_hz": 720.0, "end_hz": 720.0, "arp": [1.0, 0.666, 1.0, 0.666], "release": 0.08}, true)
		"Kick": p.merge({"duration": 0.38, "wave": "Sine", "start_hz": 120.0, "end_hz": 38.0, "attack": 0.0, "decay": 0.06, "sustain": 0.1, "release": 0.18, "drive": 1.35}, true)
		"Snare": p.merge({"duration": 0.22, "wave": "Noise", "start_hz": 260.0, "end_hz": 140.0, "noise_mix": 1.0, "lowpass_hz": 5500.0, "release": 0.08}, true)
		"Hi-Hat": p.merge({"duration": 0.09, "wave": "Noise", "noise_mix": 1.0, "lowpass_hz": 11000.0, "highpass_hz": 4500.0, "filter_mode": "Bandpass", "bandpass_hz": 8000.0, "release": 0.04}, true)
	_apply_category_specialization(p, requested_category)
	return p


static func _canonical_category(category: String) -> String:
	match category:
		"UI Select": return "UI Confirm"
		"UI Popup": return "Notification"
		"Purchase": return "Coin"
		"Menu Open": return "UI Confirm"
		"Menu Close": return "UI Cancel"
		"Dash": return "Jump"
		"Death": return "Hurt"
		"Respawn": return "Powerup"
		"Projectile": return "Laser"
		"Charge": return "Powerup"
		"Fire": return "Plasma"
		"Empty": return "UI Error"
		"Metal Impact", "Glass Impact", "Shield Impact": return "Light Impact"
		"Wood Impact", "Stone Impact", "Flesh Impact": return "Heavy Impact"
		"Small Explosion", "Large Explosion", "Energy Explosion", "Retro Explosion", "Debris Explosion": return "Explosion"
		"Footstep": return "Land"
		"Slide", "Roll", "Swing": return "Whoosh"
		"Wind", "Rain", "Fire Environment", "Water": return "Whoosh"
		"Electricity": return "Plasma"
		"Machine", "Hum": return "Engine"
		"Charge Magic": return "Magic Cast"
		"Heal Magic": return "Heal"
		"Curse", "Aura": return "Magic Cast"
		"Creature", "Chirp", "Growl", "Synthetic Voice": return category
		_: return category


static func _apply_category_specialization(p: Dictionary, category: String) -> void:
	match category:
		"UI Select": p.merge({"duration": 0.09, "start_hz": 720.0, "end_hz": 860.0}, true)
		"UI Popup": p.merge({"duration": 0.18, "start_hz": 480.0, "end_hz": 690.0}, true)
		"Purchase": p.merge({"duration": 0.28, "start_hz": 680.0, "end_hz": 1280.0, "arp": [1.0, 1.25, 1.6]}, true)
		"Menu Open": p.merge({"duration": 0.16, "start_hz": 380.0, "end_hz": 720.0}, true)
		"Menu Close": p.merge({"duration": 0.16, "start_hz": 720.0, "end_hz": 330.0}, true)
		"Dash": p.merge({"duration": 0.22, "wave": "Noise", "noise_mode": "pink", "noise_mix": 1.0, "bandpass_hz": 3200.0, "filter_mode": "Bandpass"}, true)
		"Death": p.merge({"duration": 0.7, "start_hz": 310.0, "end_hz": 55.0, "release": 0.3, "drive": 1.5}, true)
		"Respawn": p.merge({"duration": 0.7, "start_hz": 180.0, "end_hz": 920.0, "release": 0.2}, true)
		"Projectile": p.merge({"duration": 0.18, "start_hz": 980.0, "end_hz": 360.0}, true)
		"Charge": p.merge({"duration": 0.82, "start_hz": 120.0, "end_hz": 1250.0, "vibrato_depth": 0.025}, true)
		"Fire": p.merge({"duration": 0.42, "wave": "Noise", "noise_mode": "crackle", "noise_mix": 1.0, "bandpass_hz": 1100.0, "filter_mode": "Bandpass"}, true)
		"Empty": p.merge({"duration": 0.055, "wave": "Noise", "noise_mode": "metallic", "noise_mix": 1.0, "bandpass_hz": 5200.0, "filter_mode": "Bandpass"}, true)
		"Metal Impact": p.merge({"bandpass_hz": 4200.0, "resonance": 0.65, "release": 0.18}, true)
		"Wood Impact": p.merge({"bandpass_hz": 950.0, "lowpass_hz": 2800.0}, true)
		"Stone Impact": p.merge({"bandpass_hz": 1300.0, "drive": 1.6}, true)
		"Glass Impact": p.merge({"bandpass_hz": 7200.0, "resonance": 0.72, "release": 0.26}, true)
		"Flesh Impact": p.merge({"bandpass_hz": 620.0, "lowpass_hz": 1800.0, "drive": 1.2}, true)
		"Shield Impact": p.merge({"bandpass_hz": 2600.0, "resonance": 0.8, "fm_index": 2.8}, true)
		"Small Explosion": p.merge({"duration": 0.42, "lowpass_hz": 3600.0, "release": 0.25}, true)
		"Large Explosion": p.merge({"duration": 1.4, "lowpass_hz": 1600.0, "release": 0.9}, true)
		"Energy Explosion": p.merge({"wave": "FM2", "fm_ratio": 2.6, "fm_index": 4.8, "duration": 0.92}, true)
		"Retro Explosion": p.merge({"crush_bits": 5, "bitcrush_hz": 11025.0}, true)
		"Debris Explosion": p.merge({"noise_mode": "crackle", "noise_density": 0.62}, true)
		"Footstep": p.merge({"duration": 0.16, "lowpass_hz": 1500.0}, true)
		"Slide": p.merge({"duration": 0.55, "noise_mode": "pink", "bandpass_hz": 1800.0}, true)
		"Roll": p.merge({"duration": 0.48, "noise_mode": "brown", "bandpass_hz": 900.0}, true)
		"Swing": p.merge({"duration": 0.3, "bandpass_hz": 2600.0}, true)
		"Wind": p.merge({"duration": 1.2, "noise_mode": "pink", "bandpass_hz": 900.0}, true)
		"Rain": p.merge({"duration": 1.2, "noise_mode": "crackle", "noise_density": 0.48, "bandpass_hz": 3800.0}, true)
		"Fire Environment": p.merge({"duration": 1.1, "noise_mode": "crackle", "noise_density": 0.58, "bandpass_hz": 800.0}, true)
		"Water": p.merge({"duration": 0.75, "noise_mode": "white", "bandpass_hz": 2300.0}, true)
		"Electricity": p.merge({"duration": 0.45, "fm_index": 5.0, "ring_mod_depth": 0.42, "ring_mod_hz": 730.0}, true)
		"Machine": p.merge({"duration": 1.0, "start_hz": 90.0, "end_hz": 94.0, "vibrato_depth": 0.05}, true)
		"Hum": p.merge({"duration": 1.0, "wave": "Sine", "start_hz": 60.0, "end_hz": 60.0, "sustain": 0.45}, true)
		"Charge Magic": p.merge({"duration": 1.0, "start_hz": 180.0, "end_hz": 1500.0, "fm_index": 3.4}, true)
		"Heal Magic": p.merge({"duration": 0.82, "start_hz": 420.0, "end_hz": 940.0}, true)
		"Curse": p.merge({"duration": 0.86, "start_hz": 420.0, "end_hz": 88.0, "ring_mod_depth": 0.25, "drive": 1.4}, true)
		"Aura": p.merge({"duration": 1.1, "start_hz": 240.0, "end_hz": 310.0, "chorus_mix": 0.28, "reverb_mix": 0.25}, true)
		"Creature": p.merge({"duration": 0.14, "wave": "Saw", "start_hz": 170.0, "end_hz": 120.0, "drive": 1.35}, true)
		"Chirp": p.merge({"duration": 0.085, "wave": "Sine", "start_hz": 520.0, "end_hz": 1450.0}, true)
		"Growl": p.merge({"duration": 0.18, "wave": "Saw", "start_hz": 115.0, "end_hz": 72.0, "drive": 1.8}, true)
		"Synthetic Voice": p.merge({"duration": 0.12, "wave": "FM2", "start_hz": 190.0, "end_hz": 230.0, "fm_index": 2.8}, true)
		"Clap": p.merge({"duration": 0.18, "wave": "Noise", "noise_mix": 1.0, "bandpass_hz": 1900.0}, true)
		"Tom": p.merge({"duration": 0.36, "wave": "Sine", "start_hz": 210.0, "end_hz": 92.0}, true)
		"Cymbal": p.merge({"duration": 0.85, "wave": "Noise", "noise_mode": "metallic", "noise_mix": 1.0, "bandpass_hz": 7600.0}, true)
		"Retro Percussion": p.merge({"duration": 0.14, "wave": "Noise", "noise_mode": "digital", "noise_mix": 1.0, "crush_bits": 4, "bitcrush_hz": 8000.0}, true)
		_:
			pass


static func _specialize_layers(layers: Array[Dictionary], category: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	if category in ["Clap", "Tom", "Cymbal", "Retro Percussion"]:
		return _build_drum_layers(category)
	if category in ["Creature", "Chirp", "Growl", "Synthetic Voice"]:
		return _build_voice_layers(category)
	if category in ["Metal Impact", "Wood Impact", "Stone Impact", "Glass Impact", "Flesh Impact", "Shield Impact"]:
		var material_hz: float = 3000.0
		match category:
			"Metal Impact": material_hz = 4200.0
			"Wood Impact": material_hz = 950.0
			"Stone Impact": material_hz = 1400.0
			"Glass Impact": material_hz = 7600.0
			"Flesh Impact": material_hz = 560.0
			"Shield Impact": material_hz = 2700.0
		for layer: Dictionary in layers:
			if str(layer.get("wave", "")) == "Noise":
				layer["filter_mode"] = "Bandpass"
				layer["bandpass_hz"] = material_hz
				layer["resonance"] = 0.55 if category in ["Metal Impact", "Glass Impact", "Shield Impact"] else 0.18
		if category == "Glass Impact":
			layers.append(_layer({"role": "Glass Ring", "wave": "Sine", "duration": 0.32, "start_hz": 3100.0, "end_hz": 2450.0, "attack": 0.0, "decay": 0.025, "sustain": 0.0, "release": 0.24, "gain": 0.28, "pan": rng.randf_range(-0.35, 0.35)}))
	elif category in ["Small Explosion", "Large Explosion", "Energy Explosion", "Retro Explosion", "Debris Explosion"]:
		if category == "Small Explosion":
			for layer: Dictionary in layers:
				layer["duration"] = float(layer.get("duration", 0.3)) * 0.62
		elif category == "Large Explosion":
			for layer: Dictionary in layers:
				layer["duration"] = minf(2.0, float(layer.get("duration", 0.5)) * 1.55)
				layer["gain"] = float(layer.get("gain", 1.0)) * 0.86
		elif category == "Energy Explosion":
			layers.append(_layer({"role": "Energy Arc", "wave": "FM2", "duration": 0.66, "start_hz": 1700.0, "end_hz": 120.0, "fm_ratio": 2.7, "fm_index": 5.0, "ring_mod_depth": 0.36, "ring_mod_hz": 720.0, "gain": 0.4}))
		elif category == "Retro Explosion":
			for layer: Dictionary in layers:
				layer["crush_bits"] = 5
				layer["bitcrush_hz"] = 11025.0
		elif category == "Debris Explosion":
			layers.append(_layer({"role": "Extra Debris", "wave": "Noise", "duration": 0.65, "delay": 0.08, "noise_mode": "crackle", "noise_density": 0.48, "filter_mode": "Bandpass", "bandpass_hz": 2600.0, "gain": 0.3, "pan": rng.randf_range(-0.6, 0.6)}))
	elif category in ["Dash", "Slide", "Roll", "Swing", "Wind", "Rain", "Fire Environment", "Water"]:
		for layer: Dictionary in layers:
			if str(layer.get("wave", "")) == "Noise":
				layer["noise_density"] = 0.78
				layer["pan"] = rng.randf_range(-0.2, 0.2)
	return layers


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		var source: Array = value as Array
		for item_value: Variant in source:
			if item_value is Dictionary:
				output.append(item_value as Dictionary)
	return output


static func _apply_retro_profile(p: Dictionary, profile_name: String, category: String, rng: RandomNumberGenerator, hardware_limits: bool) -> void:
	var profile: Dictionary = RetroProfiles.get_profile(profile_name)
	p["quantize_bits"] = int(profile.get("output_bits", 8))
	var waves: PackedStringArray = PackedStringArray(profile.get("waveforms", []))
	if not waves.is_empty():
		p["wave"] = _choose_profile_wave(profile_name, category, waves)
	p["output_gain"] = 0.86
	p["reverb_mix"] = 0.0 if hardware_limits else 0.08
	p["echo_mix"] = minf(float(p.get("echo_mix", 0.0)), 0.2)
	if profile_name in [RetroProfiles.GAME_BOY, RetroProfiles.NES, RetroProfiles.MASTER_SYSTEM, RetroProfiles.AY, RetroProfiles.PC_SPEAKER, RetroProfiles.GENERIC_1BIT]:
		p["bitcrush_hz"] = float(profile.get("sample_rate", 22050))
	if profile_name in [RetroProfiles.AMIGA, RetroProfiles.SNES]:
		p["wavetable"] = _default_wavetable(32, "saw")
		p["wave"] = "Sample Wavetable" if profile_name == RetroProfiles.AMIGA else "GB Wave"
	if profile_name == RetroProfiles.OPL:
		p["wave"] = "FM2"
		p["fm_ops"] = _default_fm_ops()
	if profile_name == RetroProfiles.GENESIS or profile_name == RetroProfiles.ARCADE_FM:
		p["wave"] = "FM4"
		p["fm_ops"] = _default_fm_ops()
	if profile_name == RetroProfiles.SID:
		p["filter_mode"] = "Bandpass"
		p["bandpass_hz"] = 1200.0
		p["resonance"] = 0.45
	if profile_name == RetroProfiles.SNES:
		p["brr_amount"] = 0.4
	if profile_name == RetroProfiles.FANTASY_RETRO:
		p["fantasy_bits"] = 6
		p["fantasy_sample_rate"] = 22050
		p["fantasy_channels"] = 4
	p["layers"] = HardwareRules.make_profile_layers(profile_name, category, int(p.get("seed", 1)), p)


static func _choose_profile_wave(profile_name: String, category: String, waves: PackedStringArray) -> String:
	match profile_name:
		RetroProfiles.NES:
			if category in ["Explosion", "Land", "Whoosh", "Snare"]: return "NES Noise"
			if category in ["Coin", "Jump", "Laser", "Powerup", "Alarm"]: return "NES Pulse"
			return "NES Triangle"
		RetroProfiles.GAME_BOY:
			if category in ["Explosion", "Snare", "Land"]: return "GB Noise"
			if category in ["Coin", "Pickup"]: return "GB Wave"
			return "GB Pulse"
		RetroProfiles.MASTER_SYSTEM, RetroProfiles.AY:
			return "PSG Noise" if category in ["Explosion", "Snare", "Whoosh"] else "PSG Square"
		RetroProfiles.GENESIS:
			return "PSG Noise" if category in ["Explosion", "Snare"] else "FM4"
		RetroProfiles.SID:
			if category in ["Explosion", "Snare"]: return "SID Noise"
			if category in ["Laser", "Plasma"]: return "SID Saw"
			return "SID Pulse"
		RetroProfiles.POKEY:
			return "POKEY Poly17" if category in ["Explosion", "Snare"] else "POKEY Tone"
		RetroProfiles.ATARI_2600:
			return "TIA Poly9" if category in ["Explosion", "Snare"] else "TIA Tone"
		RetroProfiles.PC_SPEAKER, RetroProfiles.GENERIC_1BIT:
			return "Square"
		RetroProfiles.OPL:
			return "FM2"
		RetroProfiles.ARCADE_FM:
			return "FM4"
		_: return str(waves[0])


static func _build_modern_layers(base: Dictionary, category: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var requested_category: String = category
	category = _canonical_category(category)
	var layers: Array[Dictionary] = []
	match category:
		"Gunshot":
			layers.append(_layer({"role": "Transient Crack", "wave": "Noise", "duration": 0.02, "attack": 0.0, "decay": 0.006, "sustain": 0.0, "release": 0.012, "noise_mode": "white", "filter_mode": "Bandpass", "bandpass_hz": 8500.0, "resonance": 0.2, "gain": 0.75, "drive": 2.6}))
			layers.append(_layer({"role": "Blast Body", "wave": "Noise", "duration": 0.16, "attack": 0.0, "decay": 0.025, "sustain": 0.12, "release": 0.09, "noise_mode": "white", "filter_mode": "Bandpass", "bandpass_hz": 3600.0, "resonance": 0.25, "gain": 0.7, "drive": 1.8}))
			layers.append(_layer({"role": "Low Boom", "wave": "Sine", "duration": 0.22, "start_hz": 110.0, "end_hz": 50.0, "attack": 0.0, "decay": 0.04, "sustain": 0.0, "release": 0.18, "gain": 0.52, "drive": 1.2}))
			layers.append(_layer({"role": "Environment Tail", "wave": "Noise", "duration": 0.28, "attack": 0.0, "decay": 0.05, "sustain": 0.0, "release": 0.22, "noise_mode": "pink", "filter_mode": "Bandpass", "bandpass_hz": 1800.0, "reverb_mix": 0.18, "delay": 0.012, "gain": 0.24}))
		"Explosion":
			layers.append(_layer({"role": "Crack", "wave": "Noise", "duration": 0.06, "attack": 0.0, "decay": 0.018, "sustain": 0.0, "release": 0.04, "noise_mode": "white", "filter_mode": "Bandpass", "bandpass_hz": 5200.0, "gain": 0.48, "drive": 2.0}))
			layers.append(_layer({"role": "Body", "wave": "Noise", "duration": 0.48, "attack": 0.0, "decay": 0.09, "sustain": 0.18, "release": 0.28, "noise_mode": "brown", "filter_mode": "Bandpass", "bandpass_hz": 700.0, "resonance": 0.2, "gain": 0.82, "drive": 1.55}))
			layers.append(_layer({"role": "Boom", "wave": "Sine", "duration": 0.62, "start_hz": 82.0, "end_hz": 34.0, "attack": 0.0, "decay": 0.08, "sustain": 0.0, "release": 0.44, "gain": 0.6}))
			layers.append(_layer({"role": "Debris", "wave": "Noise", "duration": 0.42, "attack": 0.0, "decay": 0.05, "sustain": 0.0, "release": 0.32, "noise_mode": "crackle", "filter_mode": "Bandpass", "bandpass_hz": 3000.0, "delay": 0.04, "gain": 0.34}))
		"Light Impact", "Heavy Impact":
			layers.append(_layer({"role": "Click", "wave": "Noise", "duration": 0.02, "attack": 0.0, "decay": 0.008, "sustain": 0.0, "release": 0.01, "filter_mode": "Bandpass", "bandpass_hz": 6000.0, "gain": 0.42}))
			layers.append(_layer({"role": "Body", "wave": "Noise", "duration": 0.16 if category == "Light Impact" else 0.28, "attack": 0.0, "decay": 0.03, "sustain": 0.08, "release": 0.08 if category == "Light Impact" else 0.16, "filter_mode": "Bandpass", "bandpass_hz": 1800.0 if category == "Light Impact" else 900.0, "gain": 0.8, "drive": 1.4}))
			layers.append(_layer({"role": "Thump", "wave": "Sine", "duration": 0.11 if category == "Light Impact" else 0.18, "start_hz": 120.0 if category == "Light Impact" else 85.0, "end_hz": 60.0 if category == "Light Impact" else 42.0, "attack": 0.0, "decay": 0.03, "sustain": 0.0, "release": 0.08 if category == "Light Impact" else 0.12, "gain": 0.42}))
		"Whoosh":
			layers.append(_layer({"role": "Air", "wave": "Noise", "duration": 0.38, "attack": 0.0, "decay": 0.03, "sustain": 0.24, "release": 0.12, "noise_mode": "pink", "filter_mode": "Bandpass", "bandpass_hz": 2500.0, "gain": 0.75}))
			layers.append(_layer({"role": "Tone", "wave": "Sine", "duration": 0.24, "start_hz": 440.0, "end_hz": 1100.0, "attack": 0.0, "decay": 0.04, "sustain": 0.08, "release": 0.08, "gain": 0.2}))
		"Engine":
			layers.append(_layer({"role": "Low Hum", "wave": "Saw", "duration": 0.72, "start_hz": 72.0, "end_hz": 110.0, "vibrato_depth": 0.08, "vibrato_hz": 12.0, "gain": 0.64, "drive": 1.2}))
			layers.append(_layer({"role": "Buzz", "wave": "Noise", "duration": 0.72, "attack": 0.0, "decay": 0.04, "sustain": 0.34, "release": 0.08, "noise_mode": "metallic", "filter_mode": "Bandpass", "bandpass_hz": 1200.0, "gain": 0.24}))
			layers.append(_layer({"role": "Mechanical", "wave": "FM2", "duration": 0.72, "start_hz": 140.0, "end_hz": 160.0, "fm_ratio": 2.0, "fm_index": 1.4, "gain": 0.22}))
		"Magic Cast", "Teleport", "Heal", "Plasma", "Laser":
			layers.append(_layer(_make_layer_from_params(base, "Primary")))
			layers.append(_layer({"role": "Body", "wave": "FM2", "duration": float(base.get("duration", 0.4)), "start_hz": float(base.get("start_hz", 440.0)) * 0.5, "end_hz": float(base.get("end_hz", 440.0)) * 1.1, "attack": 0.0, "decay": 0.06, "sustain": 0.12, "release": 0.16, "fm_ratio": 1.618, "fm_index": 2.2, "gain": 0.35, "reverb_mix": 0.12}))
		"Kick", "Snare", "Clap", "Hi-Hat", "Tom", "Cymbal", "Retro Percussion":
			return _build_drum_layers(category)
		"Speech Blip", "Robot Blip", "Creature", "Chirp", "Growl", "Synthetic Voice":
			return _build_voice_layers(category)
		"Alarm":
			layers.append(_layer(_make_layer_from_params(base, "Primary")))
			layers.append(_layer({"role": "Sub", "wave": "Sine", "duration": 0.55, "start_hz": 180.0, "end_hz": 180.0, "attack": 0.0, "decay": 0.03, "sustain": 0.22, "release": 0.08, "gain": 0.2}))
		_:
			layers.append(_layer(_make_layer_from_params(base, "Primary")))
			if category in ["UI Confirm", "Notification", "Achievement", "Coin", "Pickup", "Jump", "Powerup", "Level Up", "UI Hover"]:
				layers.append(_layer({"role": "Sparkle", "wave": "Sine", "duration": float(base.get("duration", 0.18)), "start_hz": float(base.get("start_hz", 440.0)) * 2.0, "end_hz": float(base.get("end_hz", 440.0)) * 2.2, "attack": 0.0, "decay": 0.02, "sustain": 0.0, "release": 0.03, "gain": 0.18}))
	return _specialize_layers(layers, requested_category, rng)


static func _build_drum_layers(category: String) -> Array[Dictionary]:
	match category:
		"Kick":
			return [
				_layer({"role": "Click", "wave": "Noise", "duration": 0.014, "attack": 0.0, "decay": 0.004, "sustain": 0.0, "release": 0.008, "filter_mode": "Bandpass", "bandpass_hz": 5000.0, "gain": 0.25}),
				_layer({"role": "Body", "wave": "Sine", "duration": 0.38, "start_hz": 120.0, "end_hz": 38.0, "pitch_slide": -36.0, "attack": 0.0, "decay": 0.05, "sustain": 0.1, "release": 0.18, "gain": 0.92, "drive": 1.35}),
			]
		"Snare":
			return [
				_layer({"role": "Tone", "wave": "Sine", "duration": 0.18, "start_hz": 190.0, "end_hz": 120.0, "attack": 0.0, "decay": 0.04, "sustain": 0.0, "release": 0.08, "gain": 0.4}),
				_layer({"role": "Noise", "wave": "Noise", "duration": 0.22, "noise_mode": "white", "noise_density": 0.9, "attack": 0.0, "decay": 0.02, "sustain": 0.0, "release": 0.08, "filter_mode": "Bandpass", "bandpass_hz": 4800.0, "gain": 0.82}),
			]
		"Clap":
			return [
				_layer({"role": "Clap 1", "wave": "Noise", "duration": 0.11, "noise_mode": "white", "noise_density": 0.78, "attack": 0.0, "decay": 0.018, "sustain": 0.0, "release": 0.055, "filter_mode": "Bandpass", "bandpass_hz": 1800.0, "gain": 0.65}),
				_layer({"role": "Clap 2", "wave": "Noise", "duration": 0.10, "delay": 0.018, "noise_mode": "white", "noise_density": 0.72, "attack": 0.0, "decay": 0.014, "sustain": 0.0, "release": 0.045, "filter_mode": "Bandpass", "bandpass_hz": 2400.0, "gain": 0.48}),
				_layer({"role": "Tail", "wave": "Noise", "duration": 0.18, "delay": 0.035, "noise_mode": "pink", "noise_density": 0.55, "attack": 0.0, "decay": 0.03, "sustain": 0.0, "release": 0.12, "filter_mode": "Bandpass", "bandpass_hz": 1500.0, "gain": 0.28}),
			]
		"Tom":
			return [
				_layer({"role": "Tom Body", "wave": "Sine", "duration": 0.36, "start_hz": 210.0, "end_hz": 92.0, "pitch_slide": -22.0, "attack": 0.0, "decay": 0.055, "sustain": 0.04, "release": 0.23, "gain": 0.9, "drive": 1.15}),
				_layer({"role": "Stick", "wave": "Noise", "duration": 0.025, "noise_density": 0.8, "attack": 0.0, "decay": 0.008, "sustain": 0.0, "release": 0.012, "filter_mode": "Bandpass", "bandpass_hz": 4200.0, "gain": 0.22}),
			]
		"Cymbal":
			return [
				_layer({"role": "Metal", "wave": "Noise", "duration": 0.85, "noise_mode": "metallic", "noise_density": 0.92, "attack": 0.0, "decay": 0.06, "sustain": 0.08, "release": 0.68, "filter_mode": "Bandpass", "bandpass_hz": 7600.0, "resonance": 0.35, "gain": 0.72}),
				_layer({"role": "Shimmer", "wave": "FM2", "duration": 0.62, "start_hz": 3400.0, "end_hz": 2900.0, "fm_ratio": 1.414, "fm_index": 5.2, "attack": 0.0, "decay": 0.08, "sustain": 0.02, "release": 0.48, "gain": 0.22}),
			]
		"Retro Percussion":
			return [
				_layer({"role": "Retro Noise", "wave": "Noise", "duration": 0.12, "noise_mode": "digital", "noise_density": 0.72, "attack": 0.0, "decay": 0.018, "sustain": 0.0, "release": 0.06, "bitcrush_hz": 8000.0, "crush_bits": 4, "gain": 0.82}),
				_layer({"role": "Retro Tone", "wave": "Square", "duration": 0.09, "start_hz": 190.0, "end_hz": 75.0, "attack": 0.0, "decay": 0.02, "sustain": 0.0, "release": 0.04, "crush_bits": 5, "gain": 0.36}),
			]
		_:
			return [
				_layer({"role": "Hat Noise", "wave": "Noise", "duration": 0.08, "noise_mode": "metallic", "noise_density": 0.94, "attack": 0.0, "decay": 0.01, "sustain": 0.0, "release": 0.03, "filter_mode": "Bandpass", "bandpass_hz": 8000.0, "highpass_hz": 4000.0, "gain": 0.82}),
			]


static func _build_voice_layers(category: String) -> Array[Dictionary]:
	var style: String = category
	var wave: String = "Square"
	var start_hz: float = 240.0
	var end_hz: float = 255.0
	var duty: float = 0.25
	var fm_index: float = 0.0
	var drive: float = 1.0
	match style:
		"Robot Blip", "Synthetic Voice":
			wave = "FM2"
			start_hz = 180.0
			end_hz = 230.0
			fm_index = 2.4
		"Chirp":
			wave = "Sine"
			start_hz = 480.0
			end_hz = 1350.0
		"Creature":
			wave = "Saw"
			start_hz = 150.0
			end_hz = 110.0
			drive = 1.35
		"Growl":
			wave = "Saw"
			start_hz = 105.0
			end_hz = 68.0
			drive = 1.7
		_:
			pass
	return [
		_layer({"role": "Voice", "wave": wave, "duration": 0.09, "start_hz": start_hz, "end_hz": end_hz, "attack": 0.0, "decay": 0.02, "sustain": 0.0, "release": 0.035, "duty": duty, "gain": 0.88, "fm_ratio": 2.0, "fm_index": fm_index, "drive": drive}),
	]


static func _drum_preset(subtype: String, seed: int) -> Dictionary:
	var p: Dictionary = make_preset(RetroProfiles.MODERN, subtype if subtype in ["Kick", "Snare", "Clap", "Hi-Hat", "Tom", "Cymbal", "Retro Percussion"] else "Kick", seed, false)
	p["category"] = subtype
	p["layers"] = _build_drum_layers(subtype)
	return p


static func _voice_preset(subtype: String, seed: int) -> Dictionary:
	var category: String = "Speech Blip"
	match subtype:
		"Sine": category = "Speech Blip"
		"Square": category = "Speech Blip"
		"Robot": category = "Robot Blip"
		"Chirp": category = "Chirp"
		"Animal": category = "Creature"
		"Growl": category = "Growl"
		"Synthetic": category = "Synthetic Voice"
		"Retro": category = "Speech Blip"
		"Soft": category = "Speech Blip"
		"Harsh": category = "Growl"
		_: category = "Speech Blip"
	var p: Dictionary = make_preset(RetroProfiles.MODERN, category, seed, false)
	p["category"] = subtype + " Voice"
	p["voice_style"] = subtype
	p["character_seed"] = seed
	p["voice_pitch_min"] = 160.0
	p["voice_pitch_max"] = 520.0
	p["voice_random_pitch"] = 0.18
	p["layers"] = _build_voice_layers(category)
	if subtype == "Sine":
		for layer: Dictionary in _dictionary_array(p["layers"]):
			layer["wave"] = "Sine"
	elif subtype == "Square":
		for layer: Dictionary in _dictionary_array(p["layers"]):
			layer["wave"] = "Square"
	elif subtype == "Retro":
		for layer: Dictionary in _dictionary_array(p["layers"]):
			layer["crush_bits"] = 5
			layer["bitcrush_hz"] = 11025.0
	elif subtype == "Soft":
		for layer: Dictionary in _dictionary_array(p["layers"]):
			layer["wave"] = "Sine"
			layer["drive"] = 0.8
	elif subtype == "Harsh":
		for layer: Dictionary in _dictionary_array(p["layers"]):
			layer["drive"] = 2.0
	return p


static func _foley_preset(subtype: String, seed: int) -> Dictionary:
	var p: Dictionary = make_preset(RetroProfiles.MODERN, "Whoosh", seed, false)
	p["category"] = subtype + " Foley"
	var foley_type: String = "Footsteps" if subtype.begins_with("Footsteps") else subtype
	match foley_type:
		"Footsteps":
			p["layers"] = [
				_layer({"role": "Heel", "wave": "Noise", "duration": 0.08, "attack": 0.0, "decay": 0.012, "sustain": 0.0, "release": 0.03, "filter_mode": "Bandpass", "bandpass_hz": 1100.0, "gain": 0.7}),
				_layer({"role": "Scuff", "wave": "Noise", "duration": 0.12, "attack": 0.0, "decay": 0.02, "sustain": 0.0, "release": 0.05, "noise_mode": "pink", "filter_mode": "Bandpass", "bandpass_hz": 2500.0, "delay": 0.02, "gain": 0.28}),
			]
		"Cloth":
			p["layers"] = [_layer({"role": "Rustle", "wave": "Noise", "duration": 0.22, "attack": 0.0, "decay": 0.03, "sustain": 0.1, "release": 0.08, "noise_mode": "pink", "filter_mode": "Bandpass", "bandpass_hz": 1600.0, "gain": 0.62})]
		"Metal":
			p["layers"] = [_layer({"role": "Clink", "wave": "FM2", "duration": 0.18, "start_hz": 1200.0, "end_hz": 400.0, "fm_ratio": 2.8, "fm_index": 2.6, "attack": 0.0, "decay": 0.04, "sustain": 0.0, "release": 0.08, "gain": 0.78})]
		"Rain":
			p["layers"] = [_layer({"role": "Drops", "wave": "Noise", "duration": 0.7, "noise_mode": "crackle", "attack": 0.0, "decay": 0.1, "sustain": 0.2, "release": 0.2, "filter_mode": "Bandpass", "bandpass_hz": 3500.0, "gain": 0.72})]
		"Fire":
			p["layers"] = [_layer({"role": "Flame", "wave": "Noise", "duration": 0.7, "noise_mode": "crackle", "attack": 0.0, "decay": 0.1, "sustain": 0.3, "release": 0.2, "filter_mode": "Bandpass", "bandpass_hz": 900.0, "gain": 0.74})]
		"Wind":
			p["layers"] = [_layer({"role": "Wind", "wave": "Noise", "duration": 0.7, "noise_mode": "pink", "attack": 0.0, "decay": 0.06, "sustain": 0.3, "release": 0.2, "filter_mode": "Bandpass", "bandpass_hz": 1200.0, "gain": 0.74})]
		"Water":
			p["layers"] = [_layer({"role": "Splash", "wave": "Noise", "duration": 0.34, "noise_mode": "white", "attack": 0.0, "decay": 0.04, "sustain": 0.1, "release": 0.12, "filter_mode": "Bandpass", "bandpass_hz": 2200.0, "gain": 0.7})]
		"Machinery":
			p["layers"] = [
				_layer({"role": "Hum", "wave": "Saw", "duration": 0.72, "start_hz": 85.0, "end_hz": 95.0, "gain": 0.45, "vibrato_depth": 0.04, "vibrato_hz": 8.0}),
				_layer({"role": "Rattle", "wave": "Noise", "duration": 0.72, "noise_mode": "metallic", "filter_mode": "Bandpass", "bandpass_hz": 1400.0, "gain": 0.24}),
			]
	if subtype.begins_with("Footsteps"):
		var surface: String = subtype.trim_prefix("Footsteps").strip_edges()
		for layer: Dictionary in _dictionary_array(p.get("layers", [])):
			match surface:
				"Wood":
					layer["bandpass_hz"] = 1100.0
					layer["resonance"] = 0.22
				"Metal":
					layer["bandpass_hz"] = 3200.0
					layer["resonance"] = 0.62
					layer["noise_mode"] = "metallic"
				"Stone":
					layer["bandpass_hz"] = 1500.0
					layer["drive"] = 1.35
				"Gravel":
					layer["noise_mode"] = "crackle"
					layer["noise_density"] = 0.68
					layer["bandpass_hz"] = 2400.0
				_:
					pass
	return p


static func _make_layer_from_params(source: Dictionary, role: String) -> Dictionary:
	var d: Dictionary = {}
	for key: String in ["wave", "duration", "start_hz", "end_hz", "pitch_slide", "pitch_accel", "attack", "decay", "sustain", "release", "duty", "duty_sweep", "vibrato_depth", "vibrato_hz", "tremolo_depth", "tremolo_hz", "am_depth", "am_hz", "ring_mod_depth", "ring_mod_hz", "fm_mod_depth", "fm_mod_hz", "noise_mix", "noise_density", "drive", "distortion_mode", "distortion_mix", "lowpass_hz", "highpass_hz", "bandpass_hz", "resonance", "output_gain", "fm_ratio", "fm_index", "feedback", "echo_mix", "echo_delay", "delay_mode", "delay_feedback", "delay_taps", "reverb_mix", "reverb_size", "reverb_damping", "chorus_mix", "chorus_rate", "chorus_depth_ms", "flanger_mix", "flanger_rate", "flanger_depth_ms", "phaser_mix", "phaser_rate", "phaser_depth", "bitcrush_hz", "crush_bits", "quantize_bits", "brr_amount", "noise_mode", "filter_mode", "arp", "wavetable", "fm_ops", "fm_algorithm", "opl_waveform", "osc_sync", "sync_hz", "note_sequence", "note_rate_hz", "pitch_mod_depth", "pan", "sample_data", "sample_source_rate", "sample_playback_rate", "sample_rate_reduce_hz", "sample_loop", "sample_reverse", "sample_loop_start", "sample_loop_end"]:
		if source.has(key):
			d[key] = source[key]
	d["role"] = role
	d["gain"] = 1.0
	d["delay"] = 0.0
	return d


static func _layer(values: Dictionary) -> Dictionary:
	var d: Dictionary = {
		"role": "Layer",
		"wave": "Sine",
		"duration": 0.2,
		"start_hz": 440.0,
		"end_hz": 440.0,
		"pitch_slide": 0.0,
		"pitch_accel": 0.0,
		"attack": 0.0,
		"decay": 0.05,
		"sustain": 0.1,
		"release": 0.08,
		"duty": 0.5,
		"duty_sweep": 0.0,
		"vibrato_depth": 0.0,
		"vibrato_hz": 6.0,
		"tremolo_depth": 0.0,
		"tremolo_hz": 7.0,
		"am_depth": 0.0,
		"am_hz": 12.0,
		"ring_mod_depth": 0.0,
		"ring_mod_hz": 220.0,
		"fm_mod_depth": 0.0,
		"fm_mod_hz": 80.0,
		"pitch_mod_depth": 0.0,
		"osc_sync": false,
		"sync_hz": 220.0,
		"noise_mix": 0.0,
		"noise_density": 1.0,
		"drive": 1.0,
		"distortion_mode": "Soft Clip",
		"distortion_mix": 0.0,
		"lowpass_hz": 18000.0,
		"highpass_hz": 0.0,
		"bandpass_hz": 0.0,
		"resonance": 0.0,
		"output_gain": 0.78,
		"gain": 1.0,
		"pan": 0.0,
		"delay": 0.0,
		"fm_ratio": 2.0,
		"fm_index": 1.5,
		"feedback": 0.0,
		"echo_mix": 0.0,
		"echo_delay": 0.12,
		"delay_mode": "Mono",
		"delay_feedback": 0.25,
		"delay_taps": 4,
		"reverb_mix": 0.0,
		"reverb_size": 0.5,
		"reverb_damping": 0.4,
		"chorus_mix": 0.0,
		"chorus_rate": 0.8,
		"chorus_depth_ms": 8.0,
		"flanger_mix": 0.0,
		"flanger_rate": 0.35,
		"flanger_depth_ms": 2.0,
		"phaser_mix": 0.0,
		"phaser_rate": 0.45,
		"phaser_depth": 0.7,
		"bitcrush_hz": 0.0,
		"crush_bits": 16,
		"quantize_bits": 16,
		"brr_amount": 0.0,
		"noise_mode": "white",
		"filter_mode": "Lowpass",
		"noise_frequency": 1000.0,
		"sample_playback_rate": 1.0,
		"sample_rate_reduce_hz": 0.0,
		"sample_source_rate": 44100,
		"sample_loop": false,
		"sample_reverse": false,
		"sample_loop_start": 0.0,
		"sample_loop_end": 1.0,
		"arp": [],
	}
	d.merge(values, true)
	return d


static func _system_mutation_scale(profile_name: String, key: String) -> float:
	match profile_name:
		RetroProfiles.NES, RetroProfiles.GAME_BOY, RetroProfiles.MASTER_SYSTEM, RetroProfiles.AY:
			return 0.45 if key in ["start_hz", "end_hz", "duty", "attack", "decay", "release"] else 0.7
		RetroProfiles.PC_SPEAKER, RetroProfiles.GENERIC_1BIT:
			return 0.35 if key not in ["start_hz", "end_hz", "duration"] else 0.6
		RetroProfiles.SID, RetroProfiles.GENESIS, RetroProfiles.OPL, RetroProfiles.ARCADE_FM:
			return 0.85
		RetroProfiles.AMIGA, RetroProfiles.SNES:
			return 0.7
		_:
			return 1.0


static func run_generator_qa() -> Dictionary:
	var failures: PackedStringArray = PackedStringArray()
	var checked: int = 0
	for profile_name: String in RetroProfiles.PROFILE_ORDER:
		for category: String in CATEGORY_ORDER:
			var seed: int = 1234567 + checked
			var mode: String = HardwareRules.MODE_HARDWARE if profile_name != RetroProfiles.MODERN else HardwareRules.MODE_STYLE
			var p: Dictionary = make_preset_with_mode(profile_name, category, seed, mode)
			var repeat: Dictionary = make_preset_with_mode(profile_name, category, seed, mode)
			checked += 1
			var layers: Array[Dictionary] = _dictionary_array(p.get("layers", []))
			var repeat_layers: Array[Dictionary] = _dictionary_array(repeat.get("layers", []))
			if layers.is_empty():
				failures.append("%s / %s has no layers." % [profile_name, category])
				continue
			if layers.size() != repeat_layers.size():
				failures.append("%s / %s is not deterministic: layer count changed for identical seed." % [profile_name, category])
			elif not repeat_layers.is_empty():
				var first: Dictionary = layers[0]
				var first_repeat: Dictionary = repeat_layers[0]
				if str(first.get("wave", "")) != str(first_repeat.get("wave", "")) or not is_equal_approx(float(first.get("start_hz", 0.0)), float(first_repeat.get("start_hz", 0.0))) or not is_equal_approx(float(first.get("end_hz", 0.0)), float(first_repeat.get("end_hz", 0.0))):
					failures.append("%s / %s is not deterministic for identical seed." % [profile_name, category])
			for layer_index: int in range(layers.size()):
				var layer: Dictionary = layers[layer_index]
				var duration: float = float(layer.get("duration", 0.0))
				var gain: float = float(layer.get("gain", 1.0))
				var start_hz: float = float(layer.get("start_hz", 440.0))
				var end_hz: float = float(layer.get("end_hz", start_hz))
				var pan: float = float(layer.get("pan", 0.0))
				if duration <= 0.0 or duration > 8.0:
					failures.append("%s / %s layer %d has invalid duration %.3f." % [profile_name, category, layer_index + 1, duration])
				if gain < 0.0 or gain > 4.0:
					failures.append("%s / %s layer %d has invalid gain %.3f." % [profile_name, category, layer_index + 1, gain])
				if start_hz <= 0.0 or end_hz <= 0.0 or start_hz > 24000.0 or end_hz > 24000.0:
					failures.append("%s / %s layer %d has invalid pitch range." % [profile_name, category, layer_index + 1])
				if pan < -1.0 or pan > 1.0:
					failures.append("%s / %s layer %d has invalid pan %.3f." % [profile_name, category, layer_index + 1, pan])
			var issues: PackedStringArray = HardwareRules.validate(p, profile_name)
			for issue: String in issues:
				failures.append("%s / %s: %s" % [profile_name, category, issue])
	return {"checked": checked, "categories": CATEGORY_ORDER.size(), "profiles": RetroProfiles.PROFILE_ORDER.size(), "failures": failures, "passed": failures.is_empty()}


static func _random_noise_mode(rng: RandomNumberGenerator) -> String:
	var modes: PackedStringArray = PackedStringArray(["white", "pink", "brown", "blue", "violet", "digital", "periodic", "metallic", "impulse", "crackle"])
	return modes[rng.randi_range(0, modes.size() - 1)]
