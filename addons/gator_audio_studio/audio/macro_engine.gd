@tool
class_name GASMacroEngine
extends RefCounted

const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")
const EffectData := preload("res://addons/gator_audio_studio/audio/effect_data.gd")

static func apply_steps(pcm: GASPCMData, steps: Array[Dictionary]) -> GASPCMData:
	if pcm == null:
		return null
	var current: GASPCMData = pcm.duplicate_pcm()
	for step: Dictionary in steps:
		if not bool(step.get("enabled", true)):
			continue
		var command: String = str(step.get("command", ""))
		match command:
			"Effect":
				var effect_data_value: Variant = step.get("effect", {})
				if effect_data_value is Dictionary:
					var effect: GASEffectData = _effect_from_dictionary(effect_data_value as Dictionary)
					current = EffectEngine.process(current, effect)
			"Normalize":
				current = _normalize(current, float(step.get("target_db", -1.0)))
			"Trim Silence":
				current = _trim_silence(current, float(step.get("threshold_db", -50.0)))
			"Mono":
				current = current.force_mono()
			"Resample":
				current = current.resample_to_rate(maxi(4000, int(step.get("sample_rate", current.sample_rate))))
			"Export WAV":
				# Export is intentionally handled by the macro batch/output layer after processing.
				pass
			_:
				pass
	return current


static func save_macro(path: String, name: String, steps: Array[Dictionary]) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"format": "GAS Macro", "version": 1, "name": name, "steps": steps}, "\t"))
	file.close()
	return OK


static func load_macro(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}


static func effect_to_dictionary(effect: GASEffectData) -> Dictionary:
	if effect == null:
		return {}
	return {
		"effect_type": effect.effect_type,
		"enabled": effect.enabled,
		"wet": effect.wet,
		"params": effect.params.duplicate(true),
	}


static func _effect_from_dictionary(data: Dictionary) -> GASEffectData:
	var effect: GASEffectData = EffectData.new() as GASEffectData
	effect.effect_type = str(data.get("effect_type", "Amplify"))
	effect.enabled = bool(data.get("enabled", true))
	effect.wet = clampf(float(data.get("wet", 1.0)), 0.0, 1.0)
	var params_value: Variant = data.get("params", {})
	if params_value is Dictionary:
		effect.params = (params_value as Dictionary).duplicate(true)
	return effect


static func _normalize(pcm: GASPCMData, target_db: float) -> GASPCMData:
	var peak: float = 0.0
	for value: float in pcm.left:
		peak = maxf(peak, absf(value))
	if pcm.is_stereo():
		for value: float in pcm.right:
			peak = maxf(peak, absf(value))
	if peak <= 0.0000001:
		return pcm
	var scale: float = db_to_linear(target_db) / peak
	var out: GASPCMData = pcm.duplicate_pcm()
	for i: int in range(out.frame_count()):
		out.left[i] *= scale
		if out.is_stereo():
			out.right[i] *= scale
	return out


static func _trim_silence(pcm: GASPCMData, threshold_db: float) -> GASPCMData:
	var threshold: float = db_to_linear(threshold_db)
	var start: int = 0
	var end: int = pcm.frame_count()
	while start < end and _frame_level(pcm, start) <= threshold:
		start += 1
	while end > start and _frame_level(pcm, end - 1) <= threshold:
		end -= 1
	return pcm.slice_frames(start, end)


static func _frame_level(pcm: GASPCMData, frame: int) -> float:
	var value: float = absf(pcm.left[frame])
	if pcm.is_stereo():
		value = maxf(value, absf(pcm.right[frame]))
	return value
