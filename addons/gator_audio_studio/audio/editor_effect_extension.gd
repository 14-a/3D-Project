@tool
class_name GASEditorEffectExtension
extends RefCounted


func get_effect_id() -> StringName:
	return &""


func get_display_name() -> String:
	return "Custom Effect"


func get_description() -> String:
	return ""


func get_default_params() -> Dictionary:
	return {}


func get_parameter_specs() -> Array[Dictionary]:
	return []


func get_presets() -> PackedStringArray:
	return PackedStringArray(["Default"])


func apply_preset(params: Dictionary, preset_name: String) -> Dictionary:
	var output: Dictionary = get_default_params()
	if preset_name != "Default":
		output.merge(params, true)
	return output


func is_stack_safe() -> bool:
	return true


func outputs_stereo() -> bool:
	return false


func get_tail_frames(_params: Dictionary, _sample_rate: int) -> int:
	return 0


func process(pcm: GASPCMData, _params: Dictionary) -> GASPCMData:
	return pcm


static func number_spec(label: String, key: String, minimum: float, maximum: float, step: float, integer: bool = false) -> Dictionary:
	return {
		"type": "int" if integer else "float",
		"label": label,
		"key": key,
		"min": minimum,
		"max": maximum,
		"step": step,
	}


static func bool_spec(label: String, key: String) -> Dictionary:
	return {"type": "bool", "label": label, "key": key}


static func enum_spec(label: String, key: String, options: PackedStringArray) -> Dictionary:
	return {"type": "enum", "label": label, "key": key, "options": options}
