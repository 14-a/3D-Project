@tool
class_name GMSRemeshGuide
extends Resource


enum GuideMode {
	FLOW,
	PRESERVE_SHAPE,
	DENSITY,
}


@export var mode: int = GuideMode.FLOW
@export var points: PackedVector3Array = PackedVector3Array()
@export_range(0.0001, 100000.0, 0.01) var radius: float = 0.25
@export_range(0.0, 1.0, 0.05) var strength: float = 1.0


func is_valid() -> bool:
	return points.size() >= 2 and radius > 0.0 and strength > 0.0


func duplicate_guide() -> GMSRemeshGuide:
	var copy: GMSRemeshGuide = GMSRemeshGuide.new()
	copy.mode = mode
	copy.points = points.duplicate()
	copy.radius = radius
	copy.strength = strength
	return copy


func get_mode_name() -> String:
	match mode:
		GuideMode.FLOW:
			return "Flow"
		GuideMode.PRESERVE_SHAPE:
			return "Preserve Shape"
		GuideMode.DENSITY:
			return "Density"
		_:
			return "Guide"
