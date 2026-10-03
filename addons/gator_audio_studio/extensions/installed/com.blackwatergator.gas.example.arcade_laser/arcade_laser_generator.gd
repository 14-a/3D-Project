@tool
extends GASGeneratorExtension

const GENERATOR_ID: StringName = &"com.blackwatergator.gas.example.arcade_laser.generator"
const SAMPLE_RATE: int = 44100
const CATEGORY_LASER: String = "Arcade Laser"
const CATEGORY_PLASMA: String = "Heavy Plasma"
const CATEGORY_UI: String = "UI Zap"


func get_generator_id() -> StringName:
	return GENERATOR_ID


func get_display_name() -> String:
	return "Arcade Laser (Example Extension)"


func get_description() -> String:
	return "Seeded one-voice arcade laser synth used as the GAS Generator extension reference implementation."


func get_categories() -> PackedStringArray:
	return PackedStringArray([CATEGORY_LASER, CATEGORY_PLASMA, CATEGORY_UI])


func get_default_params(category: String, seed: int) -> Dictionary:
	var params: Dictionary = {
		"category": category,
		"seed": seed,
		"waveform": "Pulse",
		"start_frequency": 1550.0,
		"end_frequency": 180.0,
		"duration": 0.28,
		"sweep_curve": "Ease In",
		"pulse_width": 0.34,
		"fm_amount": 85.0,
		"fm_frequency": 48.0,
		"noise_amount": 0.015,
		"drive": 1.8,
		"attack": 0.002,
		"release": 0.08,
		"output_gain_db": -3.0,
	}
	match category:
		CATEGORY_PLASMA:
			params["waveform"] = "Saw"
			params["start_frequency"] = 900.0
			params["end_frequency"] = 85.0
			params["duration"] = 0.55
			params["sweep_curve"] = "Ease Out"
			params["fm_amount"] = 145.0
			params["fm_frequency"] = 31.0
			params["noise_amount"] = 0.055
			params["drive"] = 2.7
			params["release"] = 0.18
			params["output_gain_db"] = -5.0
		CATEGORY_UI:
			params["waveform"] = "Square"
			params["start_frequency"] = 1050.0
			params["end_frequency"] = 1650.0
			params["duration"] = 0.09
			params["sweep_curve"] = "Linear"
			params["pulse_width"] = 0.5
			params["fm_amount"] = 20.0
			params["fm_frequency"] = 95.0
			params["noise_amount"] = 0.0
			params["drive"] = 1.15
			params["release"] = 0.025
			params["output_gain_db"] = -2.0
		_:
			pass
	return params


func get_parameter_specs(_category: String) -> Array[Dictionary]:
	return [
		enum_spec("Waveform", "waveform", PackedStringArray(["Pulse", "Square", "Saw", "Triangle", "Sine"])),
		number_spec("Start Frequency", "start_frequency", 40.0, 6000.0, 1.0),
		number_spec("End Frequency", "end_frequency", 40.0, 6000.0, 1.0),
		number_spec("Duration", "duration", 0.02, 2.0, 0.01),
		enum_spec("Sweep Curve", "sweep_curve", PackedStringArray(["Linear", "Ease In", "Ease Out"])),
		number_spec("Pulse Width", "pulse_width", 0.05, 0.95, 0.01),
		number_spec("FM Amount Hz", "fm_amount", 0.0, 800.0, 1.0),
		number_spec("FM Frequency", "fm_frequency", 0.0, 500.0, 1.0),
		number_spec("Noise Amount", "noise_amount", 0.0, 0.25, 0.001),
		number_spec("Drive", "drive", 1.0, 8.0, 0.05),
		number_spec("Attack", "attack", 0.0, 0.25, 0.001),
		number_spec("Release", "release", 0.001, 0.75, 0.001),
		number_spec("Output Gain dB", "output_gain_db", -18.0, 6.0, 0.1),
	]


func get_presets(_category: String) -> PackedStringArray:
	return PackedStringArray(["Default", "Arcade Pew", "Retro Zap", "Charge Shot", "Boss Laser"])


func apply_preset(category: String, seed: int, preset_name: String) -> Dictionary:
	var params: Dictionary = get_default_params(category, seed)
	match preset_name:
		"Arcade Pew":
			params["waveform"] = "Pulse"
			params["start_frequency"] = 2200.0
			params["end_frequency"] = 260.0
			params["duration"] = 0.18
			params["sweep_curve"] = "Ease In"
			params["fm_amount"] = 35.0
			params["noise_amount"] = 0.008
			params["drive"] = 1.55
		"Retro Zap":
			params["waveform"] = "Square"
			params["start_frequency"] = 760.0
			params["end_frequency"] = 3200.0
			params["duration"] = 0.12
			params["sweep_curve"] = "Ease Out"
			params["fm_amount"] = 125.0
			params["fm_frequency"] = 120.0
			params["drive"] = 2.1
		"Charge Shot":
			params["waveform"] = "Saw"
			params["start_frequency"] = 120.0
			params["end_frequency"] = 2800.0
			params["duration"] = 0.72
			params["sweep_curve"] = "Ease In"
			params["fm_amount"] = 210.0
			params["fm_frequency"] = 22.0
			params["noise_amount"] = 0.03
			params["drive"] = 2.3
			params["attack"] = 0.08
			params["release"] = 0.12
		"Boss Laser":
			params["waveform"] = "Triangle"
			params["start_frequency"] = 480.0
			params["end_frequency"] = 55.0
			params["duration"] = 1.1
			params["sweep_curve"] = "Ease Out"
			params["fm_amount"] = 330.0
			params["fm_frequency"] = 17.0
			params["noise_amount"] = 0.08
			params["drive"] = 3.6
			params["release"] = 0.3
			params["output_gain_db"] = -6.0
		_:
			pass
	params["preset"] = preset_name
	return params


func randomize_params(params: Dictionary, seed: int) -> Dictionary:
	var output: Dictionary = params.duplicate(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var category: String = str(output.get("category", CATEGORY_LASER))
	output["seed"] = seed
	output["waveform"] = PackedStringArray(["Pulse", "Square", "Saw", "Triangle", "Sine"])[rng.randi_range(0, 4)]
	var low_frequency: float = rng.randf_range(55.0, 900.0)
	var high_frequency: float = rng.randf_range(900.0, 4200.0)
	var rising: bool = category == CATEGORY_UI or rng.randf() < 0.28
	output["start_frequency"] = low_frequency if rising else high_frequency
	output["end_frequency"] = high_frequency if rising else low_frequency
	output["duration"] = rng.randf_range(0.05, 0.32) if category == CATEGORY_UI else rng.randf_range(0.12, 0.85)
	output["sweep_curve"] = PackedStringArray(["Linear", "Ease In", "Ease Out"])[rng.randi_range(0, 2)]
	output["pulse_width"] = rng.randf_range(0.15, 0.75)
	output["fm_amount"] = rng.randf_range(0.0, 280.0)
	output["fm_frequency"] = rng.randf_range(8.0, 180.0)
	output["noise_amount"] = rng.randf_range(0.0, 0.035) if category == CATEGORY_UI else rng.randf_range(0.0, 0.11)
	output["drive"] = rng.randf_range(1.0, 3.8)
	output["attack"] = rng.randf_range(0.0, minf(0.08, float(output["duration"]) * 0.25))
	output["release"] = rng.randf_range(0.015, minf(0.3, float(output["duration"]) * 0.55))
	output["output_gain_db"] = rng.randf_range(-7.0, -1.0)
	return output


func mutate_params(params: Dictionary, seed: int, amount: float) -> Dictionary:
	# The base implementation demonstrates generic spec-driven mutation. Clamp the two
	# envelope times afterward so mutations cannot exceed the generated sound length.
	var output: Dictionary = super.mutate_params(params, seed, amount)
	var duration: float = maxf(0.02, float(output.get("duration", 0.28)))
	output["attack"] = clampf(float(output.get("attack", 0.002)), 0.0, duration * 0.45)
	output["release"] = clampf(float(output.get("release", 0.08)), 0.001, duration * 0.75)
	return output


func generate(params: Dictionary) -> GASPCMData:
	# Convert the dynamic parameter dictionary once. The synthesis loop below is fully typed.
	var duration: float = clampf(float(params.get("duration", 0.28)), 0.02, 2.0)
	var start_frequency: float = clampf(float(params.get("start_frequency", 1550.0)), 20.0, 12000.0)
	var end_frequency: float = clampf(float(params.get("end_frequency", 180.0)), 20.0, 12000.0)
	var waveform: String = str(params.get("waveform", "Pulse"))
	var sweep_curve: String = str(params.get("sweep_curve", "Ease In"))
	var pulse_width: float = clampf(float(params.get("pulse_width", 0.34)), 0.02, 0.98)
	var fm_amount: float = maxf(0.0, float(params.get("fm_amount", 85.0)))
	var fm_frequency: float = maxf(0.0, float(params.get("fm_frequency", 48.0)))
	var noise_amount: float = clampf(float(params.get("noise_amount", 0.015)), 0.0, 0.5)
	var drive: float = maxf(1.0, float(params.get("drive", 1.8)))
	var attack: float = clampf(float(params.get("attack", 0.002)), 0.0, duration * 0.45)
	var release: float = clampf(float(params.get("release", 0.08)), 0.001, duration * 0.75)
	var output_gain: float = pow(10.0, float(params.get("output_gain_db", -3.0)) / 20.0)
	var seed: int = maxi(1, int(params.get("seed", 1))) & 0x7fffffff
	var frame_count: int = maxi(1, int(round(duration * float(SAMPLE_RATE))))
	var pcm: GASPCMData = GASPCMData.new()
	pcm.sample_rate = SAMPLE_RATE
	pcm.channels = 1
	pcm.left.resize(frame_count)
	var samples: PackedFloat32Array = pcm.left
	var phase: float = 0.0
	var inverse_rate: float = 1.0 / float(SAMPLE_RATE)
	var inverse_frames: float = 1.0 / float(maxi(1, frame_count - 1))
	var drive_norm: float = 1.0 / maxf(0.000001, tanh(drive))
	var noise_state: int = seed
	var attack_frames: int = maxi(1, int(round(attack * float(SAMPLE_RATE)))) if attack > 0.0 else 0
	var release_frames: int = maxi(1, int(round(release * float(SAMPLE_RATE))))
	var release_start: int = maxi(0, frame_count - release_frames)

	for frame: int in range(frame_count):
		var normalized_time: float = float(frame) * inverse_frames
		var sweep_t: float = normalized_time
		if sweep_curve == "Ease In":
			sweep_t *= sweep_t
		elif sweep_curve == "Ease Out":
			var inverse_t: float = 1.0 - sweep_t
			sweep_t = 1.0 - inverse_t * inverse_t

		var base_frequency: float = lerpf(start_frequency, end_frequency, sweep_t)
		var time_seconds: float = float(frame) * inverse_rate
		var modulated_frequency: float = maxf(20.0, base_frequency + sin(TAU * fm_frequency * time_seconds) * fm_amount)
		phase += modulated_frequency * inverse_rate
		phase -= floor(phase)

		var oscillator: float = 0.0
		match waveform:
			"Square":
				oscillator = 1.0 if phase < 0.5 else -1.0
			"Saw":
				oscillator = phase * 2.0 - 1.0
			"Triangle":
				oscillator = 1.0 - 4.0 * absf(phase - 0.5)
			"Sine":
				oscillator = sin(TAU * phase)
			_:
				oscillator = 1.0 if phase < pulse_width else -1.0

		noise_state = (noise_state * 1103515245 + 12345) & 0x7fffffff
		var noise: float = (float(noise_state) / 1073741823.5 - 1.0) * noise_amount
		var envelope: float = 1.0
		if attack_frames > 0 and frame < attack_frames:
			envelope = float(frame) / float(attack_frames)
		if frame >= release_start:
			var remaining: int = frame_count - frame - 1
			envelope = minf(envelope, float(maxi(0, remaining)) / float(release_frames))
		var driven: float = tanh((oscillator * 0.7 + noise) * drive) * drive_norm
		samples[frame] = clampf(driven * envelope * output_gain, -1.0, 1.0)

	return pcm
