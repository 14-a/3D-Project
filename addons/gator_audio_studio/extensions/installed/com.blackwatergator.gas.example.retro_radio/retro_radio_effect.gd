@tool
extends GASEditorEffectExtension

const EFFECT_ID: StringName = &"com.blackwatergator.gas.example.retro_radio.effect"
const MIN_CUTOFF_HZ: float = 20.0
const MAX_CUTOFF_HZ: float = 20000.0
const MIN_BITS: int = 4
const MAX_BITS: int = 16


func get_effect_id() -> StringName:
	return EFFECT_ID


func get_display_name() -> String:
	return "Retro Radio (Example Extension)"


func get_description() -> String:
	return "Stateless band-limited radio coloration with saturation, bit reduction and deterministic static noise."


func get_default_params() -> Dictionary:
	return {
		"high_pass_hz": 300.0,
		"low_pass_hz": 3200.0,
		"drive": 1.75,
		"bit_depth": 12,
		"noise_amount": 0.004,
		"output_gain_db": -1.0,
		"noise_seed": 1337,
	}


func get_parameter_specs() -> Array[Dictionary]:
	return [
		number_spec("High Pass Hz", "high_pass_hz", 20.0, 4000.0, 10.0),
		number_spec("Low Pass Hz", "low_pass_hz", 500.0, 20000.0, 50.0),
		number_spec("Drive", "drive", 1.0, 8.0, 0.05),
		number_spec("Bit Depth", "bit_depth", 4.0, 16.0, 1.0, true),
		number_spec("Noise Amount", "noise_amount", 0.0, 0.15, 0.001),
		number_spec("Output Gain dB", "output_gain_db", -24.0, 12.0, 0.1),
		number_spec("Noise Seed", "noise_seed", 1.0, 2147483646.0, 1.0, true),
	]


func get_presets() -> PackedStringArray:
	return PackedStringArray(["Default", "Telephone", "Walkie-Talkie", "Broken Speaker"])


func apply_preset(params: Dictionary, preset_name: String) -> Dictionary:
	var output: Dictionary = get_default_params()
	var preserved_seed: int = int(params.get("noise_seed", 1337))
	output["noise_seed"] = preserved_seed
	match preset_name:
		"Telephone":
			output["high_pass_hz"] = 350.0
			output["low_pass_hz"] = 3200.0
			output["drive"] = 1.55
			output["bit_depth"] = 12
			output["noise_amount"] = 0.002
			output["output_gain_db"] = -1.0
		"Walkie-Talkie":
			output["high_pass_hz"] = 300.0
			output["low_pass_hz"] = 3200.0
			output["drive"] = 2.4
			output["bit_depth"] = 10
			output["noise_amount"] = 0.003
			output["output_gain_db"] = -2.0
		"Broken Speaker":
			output["high_pass_hz"] = 180.0
			output["low_pass_hz"] = 4500.0
			output["drive"] = 4.8
			output["bit_depth"] = 8
			output["noise_amount"] = 0.004
			output["output_gain_db"] = -4.0
		_:
			pass
	return output


func is_stack_safe() -> bool:
	return true


func outputs_stereo() -> bool:
	# The effect preserves stereo input but does not create stereo from mono input.
	return false


func process(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	if pcm == null or pcm.left.is_empty():
		return pcm

	# Convert the dynamic extension boundary once. The hot loop below uses only
	# typed scalars and packed arrays. This implementation is deliberately
	# stateless: every call derives a fresh output only from PCM + params.
	var sample_rate: int = maxi(1, pcm.sample_rate)
	var high_limit: float = float(sample_rate) * 0.45
	var low_limit: float = minf(MAX_CUTOFF_HZ, float(sample_rate) * 0.49)
	var high_pass_hz: float = clampf(float(params.get("high_pass_hz", 300.0)), MIN_CUTOFF_HZ, high_limit)
	var low_pass_hz: float = clampf(float(params.get("low_pass_hz", 3200.0)), high_pass_hz + 20.0, low_limit)
	var drive: float = maxf(1.0, float(params.get("drive", 1.75)))
	var bit_depth: int = clampi(int(params.get("bit_depth", 12)), MIN_BITS, MAX_BITS)
	var noise_amount: float = clampf(float(params.get("noise_amount", 0.004)), 0.0, 0.25)
	var output_gain_db: float = float(params.get("output_gain_db", -1.0))
	var output_gain: float = pow(10.0, output_gain_db / 20.0)
	var noise_state_left: int = maxi(1, int(params.get("noise_seed", 1337))) & 0x7fffffff
	var noise_state_right: int = (noise_state_left ^ 0x5bd1e995) & 0x7fffffff
	var dt: float = 1.0 / float(sample_rate)
	var high_rc: float = 1.0 / (TAU * high_pass_hz)
	var low_rc: float = 1.0 / (TAU * low_pass_hz)
	var high_alpha: float = high_rc / (high_rc + dt)
	var low_alpha: float = dt / (low_rc + dt)
	var quant_levels: float = float((1 << (bit_depth - 1)) - 1)
	var source_left: PackedFloat32Array = pcm.left
	var source_right: PackedFloat32Array = pcm.right
	var stereo: bool = pcm.is_stereo()
	var frame_count: int = pcm.frame_count()

	var output: GASPCMData = GASPCMData.new()
	output.sample_rate = sample_rate
	output.channels = 2 if stereo else 1
	output.left.resize(frame_count)
	if stereo:
		output.right.resize(frame_count)
	var output_left: PackedFloat32Array = output.left
	var output_right: PackedFloat32Array = output.right

	# Two cascaded high-pass and two cascaded low-pass stages make the radio band
	# restriction immediately audible while remaining cheap enough for long clips.
	var hp1_previous_input_left: float = 0.0
	var hp1_state_left: float = 0.0
	var hp2_previous_input_left: float = 0.0
	var hp2_state_left: float = 0.0
	var lp1_state_left: float = 0.0
	var lp2_state_left: float = 0.0
	var hp1_previous_input_right: float = 0.0
	var hp1_state_right: float = 0.0
	var hp2_previous_input_right: float = 0.0
	var hp2_state_right: float = 0.0
	var lp1_state_right: float = 0.0
	var lp2_state_right: float = 0.0

	for frame: int in range(frame_count):
		var input_left: float = source_left[frame]
		var hp1_left: float = high_alpha * (hp1_state_left + input_left - hp1_previous_input_left)
		hp1_previous_input_left = input_left
		hp1_state_left = hp1_left
		var hp2_left: float = high_alpha * (hp2_state_left + hp1_left - hp2_previous_input_left)
		hp2_previous_input_left = hp1_left
		hp2_state_left = hp2_left
		lp1_state_left += low_alpha * (hp2_left - lp1_state_left)
		lp2_state_left += low_alpha * (lp1_state_left - lp2_state_left)
		noise_state_left = (noise_state_left * 1103515245 + 12345) & 0x7fffffff
		var noise_left: float = (float(noise_state_left) / 1073741823.5 - 1.0) * noise_amount
		var shaped_left: float = tanh((lp2_state_left + noise_left) * drive)
		shaped_left = round(shaped_left * quant_levels) / quant_levels
		output_left[frame] = clampf(shaped_left * output_gain, -1.0, 1.0)

		if stereo:
			var input_right: float = source_right[frame]
			var hp1_right: float = high_alpha * (hp1_state_right + input_right - hp1_previous_input_right)
			hp1_previous_input_right = input_right
			hp1_state_right = hp1_right
			var hp2_right: float = high_alpha * (hp2_state_right + hp1_right - hp2_previous_input_right)
			hp2_previous_input_right = hp1_right
			hp2_state_right = hp2_right
			lp1_state_right += low_alpha * (hp2_right - lp1_state_right)
			lp2_state_right += low_alpha * (lp1_state_right - lp2_state_right)
			noise_state_right = (noise_state_right * 1103515245 + 12345) & 0x7fffffff
			var noise_right: float = (float(noise_state_right) / 1073741823.5 - 1.0) * noise_amount
			var shaped_right: float = tanh((lp2_state_right + noise_right) * drive)
			shaped_right = round(shaped_right * quant_levels) / quant_levels
			output_right[frame] = clampf(shaped_right * output_gain, -1.0, 1.0)

	# Commit local packed-array references explicitly. This keeps the extension
	# contract independent from PackedArray copy-on-write details.
	output.left = output_left
	if stereo:
		output.right = output_right
	return output
