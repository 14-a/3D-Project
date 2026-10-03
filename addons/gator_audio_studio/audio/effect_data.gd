@tool
class_name GASEffectData
extends RefCounted

var effect_type: String = "Amplify"
var enabled: bool = true
var wet: float = 1.0
var preset_name: String = "Default"
var params: Dictionary = {}


func duplicate_effect() -> GASEffectData:
	var out: GASEffectData = GASEffectData.new()
	out.effect_type = effect_type
	out.enabled = enabled
	out.wet = wet
	out.preset_name = preset_name
	out.params = params.duplicate(true)
	return out
