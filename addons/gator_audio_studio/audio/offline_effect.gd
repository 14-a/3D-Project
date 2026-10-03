@tool
class_name GASOfflineEffect
extends RefCounted


func get_effect_name() -> String:
	return "Custom Effect"


func process(left: PackedFloat32Array, right: PackedFloat32Array, sample_rate: int) -> void:
	pass
