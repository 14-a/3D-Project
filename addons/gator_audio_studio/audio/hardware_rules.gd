@tool
class_name GASHardwareRules
extends RefCounted

const RetroProfiles = preload("res://addons/gator_audio_studio/audio/retro_profiles.gd")

const MODE_STYLE := "Style"
const MODE_HARDWARE := "Hardware"


static func get_rules(profile_name: String) -> Dictionary:
	match profile_name:
		RetroProfiles.MODERN:
			return {"min_hz": 20.0, "max_hz": 20000.0, "bits": 16, "sample_rate": 48000, "channels": 16, "env_step": 0.0, "duties": []}
		RetroProfiles.GENERIC_1BIT:
			return {"min_hz": 30.0, "max_hz": 8000.0, "bits": 1, "sample_rate": 22050, "channels": 1, "env_step": 0.02, "duties": [0.5]}
		RetroProfiles.PC_SPEAKER:
			return {"min_hz": 18.2, "max_hz": 12000.0, "bits": 1, "sample_rate": 22050, "channels": 1, "env_step": 0.02, "duties": [0.5]}
		RetroProfiles.ATARI_2600:
			return {"min_hz": 30.0, "max_hz": 8000.0, "bits": 4, "sample_rate": 31440, "channels": 2, "env_step": 1.0 / 60.0, "duties": [0.5]}
		RetroProfiles.NES:
			return {"min_hz": 27.0, "max_hz": 12500.0, "bits": 7, "sample_rate": 44100, "channels": 5, "env_step": 1.0 / 240.0, "duties": [0.125, 0.25, 0.5, 0.75]}
		RetroProfiles.GAME_BOY:
			return {"min_hz": 64.0, "max_hz": 13100.0, "bits": 4, "sample_rate": 44100, "channels": 4, "env_step": 1.0 / 64.0, "duties": [0.125, 0.25, 0.5, 0.75]}
		RetroProfiles.MASTER_SYSTEM:
			return {"min_hz": 55.0, "max_hz": 11000.0, "bits": 4, "sample_rate": 44100, "channels": 4, "env_step": 1.0 / 60.0, "duties": [0.5]}
		RetroProfiles.GENESIS:
			return {"min_hz": 20.0, "max_hz": 15000.0, "bits": 9, "sample_rate": 53267, "channels": 10, "env_step": 1.0 / 60.0, "duties": [0.5]}
		RetroProfiles.SID:
			return {"min_hz": 16.0, "max_hz": 12000.0, "bits": 12, "sample_rate": 44100, "channels": 3, "env_step": 1.0 / 60.0, "duties": []}
		RetroProfiles.POKEY:
			return {"min_hz": 28.0, "max_hz": 12000.0, "bits": 4, "sample_rate": 44100, "channels": 4, "env_step": 1.0 / 64.0, "duties": [0.5]}
		RetroProfiles.AY:
			return {"min_hz": 27.0, "max_hz": 11000.0, "bits": 4, "sample_rate": 44100, "channels": 3, "env_step": 1.0 / 64.0, "duties": [0.5]}
		RetroProfiles.AMIGA:
			return {"min_hz": 28.0, "max_hz": 12000.0, "bits": 8, "sample_rate": 28604, "channels": 4, "env_step": 0.0, "duties": []}
		RetroProfiles.SNES:
			return {"min_hz": 16.0, "max_hz": 16000.0, "bits": 16, "sample_rate": 32000, "channels": 8, "env_step": 1.0 / 64.0, "duties": []}
		RetroProfiles.OPL:
			return {"min_hz": 20.0, "max_hz": 12000.0, "bits": 13, "sample_rate": 49716, "channels": 9, "env_step": 1.0 / 72.0, "duties": []}
		RetroProfiles.ARCADE_FM:
			return {"min_hz": 20.0, "max_hz": 16000.0, "bits": 14, "sample_rate": 55466, "channels": 8, "env_step": 1.0 / 120.0, "duties": []}
		RetroProfiles.FANTASY_RETRO:
			return {"min_hz": 30.0, "max_hz": 9000.0, "bits": 6, "sample_rate": 22050, "channels": 4, "env_step": 1.0 / 60.0, "duties": [0.125, 0.25, 0.5, 0.75]}
		_:
			return get_rules(RetroProfiles.MODERN)


static func apply_constraints(params: Dictionary, profile_name: String, mode: String) -> Dictionary:
	var out: Dictionary = params.duplicate(true)
	if mode != MODE_HARDWARE or profile_name == RetroProfiles.MODERN:
		out["accuracy_mode"] = mode
		return out
	var rules: Dictionary = get_rules(profile_name)
	if profile_name == RetroProfiles.FANTASY_RETRO:
		rules["bits"] = clampi(int(out.get("fantasy_bits", rules["bits"])), 1, 16)
		rules["sample_rate"] = clampi(int(out.get("fantasy_sample_rate", rules["sample_rate"])), 4000, 48000)
		rules["channels"] = clampi(int(out.get("fantasy_channels", rules["channels"])), 1, 8)
	out["accuracy_mode"] = MODE_HARDWARE
	out["hardware_limits"] = true
	out["quantize_bits"] = int(rules["bits"])
	var layers: Array[Dictionary] = _dictionary_array(out.get("layers", []))
	if layers.is_empty():
		layers.append(out)
	var max_channels: int = int(rules["channels"])
	if layers.size() > max_channels:
		layers.resize(max_channels)
	for i: int in range(layers.size()):
		var layer: Dictionary = layers[i]
		layer["start_hz"] = clampf(float(layer.get("start_hz", 440.0)), float(rules["min_hz"]), float(rules["max_hz"]))
		layer["end_hz"] = clampf(float(layer.get("end_hz", layer["start_hz"])), float(rules["min_hz"]), float(rules["max_hz"]))
		layer["quantize_bits"] = int(rules["bits"])
		var env_step: float = float(rules["env_step"])
		if env_step > 0.0:
			for key: String in ["attack", "decay", "release"]:
				layer[key] = maxf(0.0, snappedf(float(layer.get(key, 0.0)), env_step))
			layer["sustain"] = snappedf(clampf(float(layer.get("sustain", 0.35)), 0.0, 1.0), 1.0 / 15.0)
		var duties: PackedFloat32Array = _float_array(rules.get("duties", []))
		if not duties.is_empty() and str(layer.get("wave", "")).contains("Pulse"):
			layer["duty"] = _nearest_value(float(layer.get("duty", 0.5)), duties)
		_apply_profile_layer_rules(layer, profile_name, i)
		layers[i] = layer
	out["layers"] = layers
	return out


static func validate(params: Dictionary, profile_name: String) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var rules: Dictionary = get_rules(profile_name)
	if profile_name == RetroProfiles.FANTASY_RETRO:
		rules["bits"] = clampi(int(params.get("fantasy_bits", rules["bits"])), 1, 16)
		rules["sample_rate"] = clampi(int(params.get("fantasy_sample_rate", rules["sample_rate"])), 4000, 48000)
		rules["channels"] = clampi(int(params.get("fantasy_channels", rules["channels"])), 1, 8)
	var layers: Array[Dictionary] = _dictionary_array(params.get("layers", []))
	if layers.size() > int(rules["channels"]):
		issues.append("Too many active voices: %d > %d" % [layers.size(), int(rules["channels"])])
	for i: int in range(layers.size()):
		var layer: Dictionary = layers[i]
		var start_hz: float = float(layer.get("start_hz", 440.0))
		var end_hz: float = float(layer.get("end_hz", start_hz))
		if start_hz < float(rules["min_hz"]) or start_hz > float(rules["max_hz"]):
			issues.append("Voice %d start frequency is outside hardware range." % (i + 1))
		if end_hz < float(rules["min_hz"]) or end_hz > float(rules["max_hz"]):
			issues.append("Voice %d end frequency is outside hardware range." % (i + 1))
	return issues


static func make_profile_layers(profile_name: String, category: String, seed: int, base: Dictionary) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var tuned_base: Dictionary = _tune_base_for_profile(base, profile_name, category, rng)
	base = tuned_base
	var layer_category: String = _canonical_retro_category(category)
	match profile_name:
		RetroProfiles.NES:
			return _nes_layers(layer_category, base, rng)
		RetroProfiles.GAME_BOY:
			return _gb_layers(layer_category, base, rng)
		RetroProfiles.MASTER_SYSTEM:
			return _psg_layers(layer_category, base, 4, "PSG Square", "PSG Noise", rng)
		RetroProfiles.GENESIS:
			return _genesis_layers(layer_category, base, rng)
		RetroProfiles.SID:
			return _sid_layers(layer_category, base, rng)
		RetroProfiles.POKEY:
			return _pokey_layers(layer_category, base, rng)
		RetroProfiles.AY:
			return _ay_layers(layer_category, base, rng)
		RetroProfiles.ATARI_2600:
			return _tia_layers(layer_category, base, rng)
		RetroProfiles.AMIGA:
			return _sample_layers(layer_category, base, 4, "Sample Wavetable", rng, false)
		RetroProfiles.SNES:
			return _sample_layers(layer_category, base, 4, "Sample Wavetable", rng, true)
		RetroProfiles.PC_SPEAKER:
			return _pc_speaker_layers(layer_category, base)
		RetroProfiles.OPL:
			return _opl_layers(layer_category, base, false)
		RetroProfiles.ARCADE_FM:
			return _opl_layers(layer_category, base, true)
		RetroProfiles.FANTASY_RETRO:
			return _fantasy_layers(layer_category, base, rng)
		_:
			return [_layer_from_base(base, "Primary", 1.0)]


static func _canonical_retro_category(category: String) -> String:
	match category:
		"Small Explosion", "Large Explosion", "Energy Explosion", "Retro Explosion", "Debris Explosion": return "Explosion"
		"Metal Impact", "Wood Impact", "Stone Impact", "Glass Impact", "Flesh Impact", "Shield Impact": return "Heavy Impact"
		"UI Select", "UI Popup", "Purchase", "Menu Open", "Menu Close": return "UI Confirm"
		"Projectile", "Charge", "Fire", "Empty": return "Laser"
		"Dash", "Slide", "Roll", "Swing": return "Whoosh"
		"Footstep": return "Land"
		"Wind", "Rain", "Fire Environment", "Water": return "Whoosh"
		"Electricity": return "Plasma"
		"Machine", "Hum": return "Engine"
		"Charge Magic", "Heal Magic", "Curse", "Aura": return "Magic Cast"
		"Creature", "Chirp", "Growl", "Synthetic Voice": return "Speech Blip"
		"Clap", "Tom", "Cymbal", "Retro Percussion": return "Snare"
		"Death": return "Hurt"
		"Respawn": return "Powerup"
		_: return category


static func _tune_base_for_profile(base: Dictionary, profile_name: String, category: String, rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	var pitch_scale: float = 1.0
	var duration_scale: float = 1.0
	var duty_bias: float = float(out.get("duty", 0.5))
	match profile_name:
		RetroProfiles.ATARI_2600:
			pitch_scale = rng.randf_range(0.82, 1.12)
			duration_scale = 0.82
		RetroProfiles.NES:
			pitch_scale = rng.randf_range(0.96, 1.08)
			duty_bias = [0.125, 0.25, 0.5, 0.75][rng.randi_range(0, 3)]
		RetroProfiles.GAME_BOY:
			pitch_scale = rng.randf_range(0.92, 1.06)
			duty_bias = [0.125, 0.25, 0.5, 0.75][rng.randi_range(0, 3)]
		RetroProfiles.MASTER_SYSTEM:
			pitch_scale = rng.randf_range(0.88, 1.04)
		RetroProfiles.GENESIS:
			pitch_scale = rng.randf_range(0.98, 1.12)
		RetroProfiles.SID:
			pitch_scale = rng.randf_range(0.74, 1.08)
			duration_scale = 1.08
		RetroProfiles.POKEY:
			pitch_scale = rng.randf_range(0.78, 1.12)
		RetroProfiles.AY:
			pitch_scale = rng.randf_range(0.9, 1.1)
		RetroProfiles.AMIGA:
			pitch_scale = rng.randf_range(0.94, 1.04)
			duration_scale = 1.15
		RetroProfiles.SNES:
			pitch_scale = rng.randf_range(0.96, 1.05)
			duration_scale = 1.18
		RetroProfiles.OPL, RetroProfiles.ARCADE_FM:
			pitch_scale = rng.randf_range(0.97, 1.08)
		_:
			pass
	if category in ["Explosion", "Large Explosion", "Cannon", "Heavy Impact", "Death", "Growl"]:
		pitch_scale *= 0.72
		duration_scale *= 1.25
	elif category in ["Coin", "Pickup", "UI Confirm", "UI Select", "Chirp", "Achievement"]:
		pitch_scale *= 1.18
		duration_scale *= 0.82
	elif category in ["Engine", "Machine", "Hum"]:
		pitch_scale *= 0.55
		duration_scale *= 1.4
	out["start_hz"] = float(out.get("start_hz", 440.0)) * pitch_scale
	out["end_hz"] = float(out.get("end_hz", 440.0)) * pitch_scale
	out["duration"] = clampf(float(out.get("duration", 0.3)) * duration_scale, 0.02, 8.0)
	out["duty"] = duty_bias
	return out


static func _apply_profile_layer_rules(layer: Dictionary, profile_name: String, index: int) -> void:
	match profile_name:
		RetroProfiles.NES:
			if str(layer.get("wave", "")) == "NES Pulse":
				layer["duty"] = _nearest_value(float(layer.get("duty", 0.5)), PackedFloat32Array([0.125, 0.25, 0.5, 0.75]))
			elif str(layer.get("wave", "")) == "NES DPCM":
				layer["quantize_bits"] = mini(7, int(layer.get("quantize_bits", 7)))
				layer["bitcrush_hz"] = minf(33144.0, maxf(4181.0, float(layer.get("bitcrush_hz", 16000.0))))
		RetroProfiles.GAME_BOY:
			if str(layer.get("wave", "")) == "GB Pulse":
				layer["duty"] = _nearest_value(float(layer.get("duty", 0.5)), PackedFloat32Array([0.125, 0.25, 0.5, 0.75]))
			if str(layer.get("wave", "")) == "GB Wave":
				layer["quantize_bits"] = 4
				var table_value: Variant = layer.get("wavetable", PackedFloat32Array())
				var table: PackedFloat32Array = PackedFloat32Array()
				if table_value is PackedFloat32Array:
					table = (table_value as PackedFloat32Array).duplicate()
				elif table_value is Array:
					table = PackedFloat32Array(table_value as Array)
				if not table.is_empty():
					var resized: PackedFloat32Array = PackedFloat32Array()
					resized.resize(32)
					for table_i: int in range(32):
						var src_i: int = clampi(int(floor(float(table_i) * float(table.size()) / 32.0)), 0, table.size() - 1)
						var value: float = clampf(table[src_i], -1.0, 1.0)
						resized[table_i] = round((value * 0.5 + 0.5) * 15.0) / 15.0 * 2.0 - 1.0
					layer["wavetable"] = resized
		RetroProfiles.SID:
			layer["sid_voice_index"] = index
			layer["filter_mode"] = str(layer.get("filter_mode", "Lowpass"))
			layer["resonance"] = clampf(float(layer.get("resonance", 0.3)), 0.0, 1.0)
		RetroProfiles.AY:
			layer["ay_shared_noise"] = true
		RetroProfiles.SNES:
			layer["sample_rate_reduce_hz"] = 32000.0
			layer["brr_amount"] = clampf(float(layer.get("brr_amount", 0.35)), 0.0, 1.0)
		RetroProfiles.AMIGA:
			layer["sample_rate_reduce_hz"] = 28604.0
			layer["quantize_bits"] = 8
		RetroProfiles.OPL:
			layer["opl_mode"] = int(layer.get("opl_mode", 2))
		RetroProfiles.ARCADE_FM:
			layer["opl_mode"] = 4


static func _nes_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if category in ["Explosion", "Gunshot", "Snare", "Land", "Whoosh", "Cannon"]:
		layers.append(_layer_from_base(base, "Noise", 0.72, "NES Noise"))
		layers.append(_layer_from_base(base, "Triangle Body", 0.38, "NES Triangle"))
		if category in ["Explosion", "Gunshot", "Cannon"]:
			var dpcm: Dictionary = _layer_from_base(base, "DPCM Sample", 0.34, "NES DPCM")
			dpcm["quantize_bits"] = 7
			dpcm["bitcrush_hz"] = 16000.0
			dpcm["wavetable"] = _dpcm_table(category)
			layers.append(dpcm)
	else:
		layers.append(_layer_from_base(base, "Pulse 1", 0.72, "NES Pulse"))
		layers.append(_layer_from_base(base, "Pulse 2", 0.38, "NES Pulse"))
		layers[1]["start_hz"] = float(base.get("start_hz", 440.0)) * 1.5
		layers[1]["end_hz"] = float(base.get("end_hz", 440.0)) * 1.5
		layers[1]["duty"] = 0.25
		if category in ["Powerup", "Level Up", "Achievement"]:
			layers.append(_layer_from_base(base, "Triangle", 0.3, "NES Triangle"))
	return layers


static func _gb_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if category in ["Explosion", "Snare", "Land"]:
		layers.append(_layer_from_base(base, "Noise", 0.86, "GB Noise"))
	else:
		layers.append(_layer_from_base(base, "Pulse A", 0.7, "GB Pulse"))
		layers.append(_layer_from_base(base, "Pulse B", 0.34, "GB Pulse"))
		layers[1]["start_hz"] = float(base.get("start_hz", 440.0)) * 1.25
		layers[1]["end_hz"] = float(base.get("end_hz", 440.0)) * 1.25
		if category in ["Coin", "Pickup", "Powerup", "Magic Cast"]:
			var wave: Dictionary = _layer_from_base(base, "Wave Channel", 0.42, "GB Wave")
			wave["quantize_bits"] = 4
			layers.append(wave)
	return layers


static func _psg_layers(category: String, base: Dictionary, count: int, tone_wave: String, noise_wave: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var tone_count: int = mini(3, count)
	for i: int in range(tone_count):
		var layer: Dictionary = _layer_from_base(base, "Tone %d" % (i + 1), 0.62 / float(i + 1), tone_wave)
		layer["start_hz"] = float(base.get("start_hz", 440.0)) * (1.0 + float(i) * 0.25)
		layer["end_hz"] = float(base.get("end_hz", 440.0)) * (1.0 + float(i) * 0.25)
		layers.append(layer)
	if category in ["Explosion", "Gunshot", "Snare", "Whoosh", "Land"]:
		layers.append(_layer_from_base(base, "Noise", 0.55, noise_wave))
	return layers


static func _genesis_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var fm: Dictionary = _layer_from_base(base, "YM2612 FM", 0.72, "FM4")
	fm["fm_algorithm"] = rng.randi_range(0, 7)
	fm["feedback"] = 0.28
	fm["fm_ops"] = _fm_ops_for_category(category, 4)
	layers.append(fm)
	if category in ["Coin", "Pickup", "Jump", "UI Confirm", "Alarm"]:
		layers.append(_layer_from_base(base, "PSG Tone", 0.28, "PSG Square"))
	elif category in ["Explosion", "Gunshot", "Snare"]:
		layers.append(_layer_from_base(base, "PSG Noise", 0.4, "PSG Noise"))
	return layers


static func _sid_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var waves: PackedStringArray = PackedStringArray(["SID Pulse", "SID Saw", "SID Triangle"])
	for i: int in range(3):
		var layer: Dictionary = _layer_from_base(base, "SID Voice %d" % (i + 1), 0.55 if i == 0 else 0.28, waves[i])
		layer["start_hz"] = float(base.get("start_hz", 440.0)) * [1.0, 1.5, 0.5][i]
		layer["end_hz"] = float(base.get("end_hz", 440.0)) * [1.0, 1.5, 0.5][i]
		layer["duty"] = [0.25, 0.5, 0.75][i]
		layer["ring_mod_depth"] = 0.32 if i == 1 else 0.0
		layer["osc_sync"] = i == 2
		layer["filter_mode"] = "Lowpass"
		layer["lowpass_hz"] = 4200.0
		layer["resonance"] = 0.52
		layers.append(layer)
	if category in ["Explosion", "Snare"]:
		layers[2]["wave"] = "SID Noise"
	return layers


static func _pokey_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var waves: PackedStringArray = PackedStringArray(["POKEY Tone", "POKEY Tone", "POKEY Poly5", "POKEY Poly17"])
	for i: int in range(4):
		var layer: Dictionary = _layer_from_base(base, "POKEY %d" % (i + 1), 0.52 / (1.0 + float(i) * 0.25), waves[i])
		layer["pokey_joined"] = i < 2 and category in ["Engine", "Alarm", "Powerup"]
		layers.append(layer)
	return layers


static func _ay_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	for i: int in range(3):
		var layer: Dictionary = _layer_from_base(base, "AY Tone %d" % (i + 1), 0.58 / float(i + 1), "AY Square")
		layer["start_hz"] = float(base.get("start_hz", 440.0)) * [1.0, 1.25, 1.5][i]
		layer["end_hz"] = float(base.get("end_hz", 440.0)) * [1.0, 1.25, 1.5][i]
		layer["ay_envelope_shape"] = i % 4
		layer["noise_mix"] = 0.25 if category in ["Explosion", "Snare", "Land"] else 0.0
		layer["noise_mode"] = "digital"
		layers.append(layer)
	return layers


static func _tia_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var modes: PackedStringArray = PackedStringArray(["TIA Tone", "TIA Poly4", "TIA Poly5", "TIA Poly9"])
	var a: Dictionary = _layer_from_base(base, "TIA Channel 1", 0.72, modes[rng.randi_range(0, modes.size() - 1)])
	var b: Dictionary = _layer_from_base(base, "TIA Channel 2", 0.46, modes[rng.randi_range(0, modes.size() - 1)])
	if category in ["Explosion", "Snare"]:
		a["wave"] = "TIA Poly9"
		b["wave"] = "TIA Poly5"
	return [a, b]


static func _sample_layers(category: String, base: Dictionary, count: int, wave: String, rng: RandomNumberGenerator, snes: bool) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	var actual_count: int = 2 if category in ["UI Confirm", "Coin", "Pickup", "Jump"] else count
	for i: int in range(actual_count):
		var layer: Dictionary = _layer_from_base(base, ("SNES" if snes else "Paula") + " Sample %d" % (i + 1), 0.62 / float(i + 1), wave)
		layer["start_hz"] = float(base.get("start_hz", 440.0)) * (1.0 + float(i) * 0.25)
		layer["end_hz"] = float(base.get("end_hz", 440.0)) * (1.0 + float(i) * 0.25)
		layer["sample_loop"] = true
		if snes:
			layer["brr_amount"] = 0.45
			layer["pitch_mod_depth"] = 0.08 if i > 0 else 0.0
			layer["reverb_mix"] = 0.16
			layer["echo_mix"] = 0.12
			layer["echo_delay"] = 0.075
			layer["delay_feedback"] = 0.22
		else:
			layer["quantize_bits"] = 8
		layers.append(layer)
	return layers


static func _pc_speaker_layers(category: String, base: Dictionary) -> Array[Dictionary]:
	var layer: Dictionary = _layer_from_base(base, "PC Speaker", 0.9, "Square")
	if category in ["Achievement", "Level Up", "Alarm", "Powerup"]:
		layer["note_sequence"] = [1.0, 1.25, 1.5, 2.0, 1.5, 2.0]
		layer["note_rate_hz"] = 12.0
	else:
		layer["note_sequence"] = [1.0, 1.5]
		layer["note_rate_hz"] = 18.0
	return [layer]


static func _opl_layers(category: String, base: Dictionary, four_op: bool) -> Array[Dictionary]:
	var layer: Dictionary = _layer_from_base(base, "4-Op FM" if four_op else "2-Op OPL", 0.82, "FM4" if four_op else "FM2")
	layer["fm_ops"] = _fm_ops_for_category(category, 4 if four_op else 2)
	layer["opl_mode"] = 4 if four_op else 2
	layer["feedback"] = 0.34
	layer["opl_waveform"] = 0
	return [layer]


static func _fantasy_layers(category: String, base: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var rules: Dictionary = get_rules(RetroProfiles.FANTASY_RETRO)
	var count: int = mini(3, int(rules["channels"]))
	var waves: PackedStringArray = PackedStringArray(["Square", "Triangle", "Saw", "Pulse", "Noise", "FM2"])
	var layers: Array[Dictionary] = []
	for i: int in range(count):
		var layer: Dictionary = _layer_from_base(base, "Fantasy Voice %d" % (i + 1), 0.62 / float(i + 1), waves[rng.randi_range(0, waves.size() - 1)])
		layer["quantize_bits"] = int(rules["bits"])
		layer["bitcrush_hz"] = float(rules["sample_rate"])
		layers.append(layer)
	return layers


static func _layer_from_base(base: Dictionary, role: String, gain: float, wave: String = "") -> Dictionary:
	var layer: Dictionary = base.duplicate(true)
	layer.erase("layers")
	layer.erase("generation_ranges")
	layer.erase("locks")
	layer["role"] = role
	layer["gain"] = gain
	layer["delay"] = 0.0
	if not wave.is_empty():
		layer["wave"] = wave
	return layer


static func _fm_ops_for_category(category: String, count: int) -> Array[Dictionary]:
	var ops: Array[Dictionary] = []
	var ratios: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	if category in ["Bell", "Coin", "Achievement", "Metal", "Ricochet"]:
		ratios = PackedFloat32Array([1.0, 2.71, 4.08, 6.13])
	elif category in ["Explosion", "Gunshot", "Heavy Impact"]:
		ratios = PackedFloat32Array([1.0, 0.5, 1.37, 2.13])
	elif category in ["Engine", "Alarm"]:
		ratios = PackedFloat32Array([1.0, 1.01, 2.0, 3.0])
	for i: int in range(count):
		ops.append({"ratio": ratios[i], "level": [1.0, 0.78, 0.52, 0.34][i], "detune": 0.0, "attack": 0.01, "decay": 0.12, "sustain": 0.5, "release": 0.15, "velocity": 1.0})
	return ops


static func _dpcm_table(category: String) -> PackedFloat32Array:
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(64)
	var state: float = 0.0
	for i: int in range(table.size()):
		var direction: float = 1.0 if ((i * 17 + category.length() * 13) & 7) < 4 else -1.0
		state = clampf(state + direction * 0.125, -1.0, 1.0)
		table[i] = state
	return table


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		var source: Array = value as Array
		for item_value: Variant in source:
			if item_value is Dictionary:
				output.append(item_value as Dictionary)
	return output


static func _float_array(value: Variant) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return value as PackedFloat32Array
	if value is Array:
		return PackedFloat32Array(value as Array)
	return PackedFloat32Array()


static func _nearest_value(value: float, values: PackedFloat32Array) -> float:
	var best: float = float(values[0])
	var best_error: float = absf(value - best)
	for candidate: float in values:
		var error: float = absf(value - candidate)
		if error < best_error:
			best = candidate
			best_error = error
	return best
