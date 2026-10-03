@tool
class_name GMSExtensionSchema
extends RefCounted




static func normalize_parameters(source: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not source is Array:
		return result
	for value: Variant in source:
		if not value is Dictionary:
			continue
		var parameter: Dictionary = (value as Dictionary).duplicate(true)
		var parameter_id: String = str(parameter.get("id", "")).strip_edges()
		if parameter_id.is_empty():
			continue
		parameter["id"] = parameter_id
		parameter["label"] = str(parameter.get("label", parameter_id.capitalize()))
		parameter["type"] = str(parameter.get("type", "float")).to_lower()
		result.append(parameter)
	return result


static func default_parameters(source: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not source is Array:
		return result
	for value: Variant in source:
		if value is Dictionary:
			var parameter: Dictionary = value
			result[str(parameter.get("id", ""))] = parameter.get("default", 0.0)
	return result


static func normalize_extensions(source: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if source is PackedStringArray or source is Array:
		for value: Variant in source:
			var extension: String = str(value).to_lower().strip_edges().trim_prefix(".")
			if not extension.is_empty() and not result.has(extension):
				result.append(extension)
	return result


static func build_filter(display_name: String, extensions: PackedStringArray) -> String:
	var patterns: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		patterns.append("*.%s" % extension)
	return "%s ; %s" % [",".join(patterns), display_name]
