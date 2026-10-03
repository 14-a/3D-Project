@tool
class_name GASGeneratorExtension
extends RefCounted


func get_generator_id() -> StringName:
	return &""


func get_display_name() -> String:
	return "Custom Generator"


func get_description() -> String:
	return ""


func get_categories() -> PackedStringArray:
	return PackedStringArray(["Custom"])


func get_parameter_specs(_category: String) -> Array[Dictionary]:
	return []


func get_default_params(category: String, seed: int) -> Dictionary:
	return {"category": category, "seed": seed}


func get_presets(_category: String) -> PackedStringArray:
	return PackedStringArray(["Default"])


func apply_preset(category: String, seed: int, preset_name: String) -> Dictionary:
	var params: Dictionary = get_default_params(category, seed)
	params["preset"] = preset_name
	return params


func randomize_params(params: Dictionary, seed: int) -> Dictionary:
	var output: Dictionary = params.duplicate(true)
	output["seed"] = seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var category: String = str(output.get("category", "Custom"))
	for spec: Dictionary in get_parameter_specs(category):
		var key: String = str(spec.get("key", ""))
		if key.is_empty():
			continue
		var type_name: String = str(spec.get("type", "float"))
		match type_name:
			"bool":
				output[key] = rng.randf() >= 0.5
			"enum":
				var options: PackedStringArray = _spec_options(spec)
				if not options.is_empty():
					output[key] = options[rng.randi_range(0, options.size() - 1)]
			"int":
				var min_i: int = int(round(float(spec.get("min", 0.0))))
				var max_i: int = int(round(float(spec.get("max", 1.0))))
				output[key] = rng.randi_range(min_i, maxi(min_i, max_i))
			_:
				var minimum: float = float(spec.get("min", 0.0))
				var maximum: float = maxf(minimum, float(spec.get("max", 1.0)))
				output[key] = rng.randf_range(minimum, maximum)
	return output


func mutate_params(params: Dictionary, seed: int, amount: float) -> Dictionary:
	var output: Dictionary = params.duplicate(true)
	output["seed"] = seed
	var strength: float = clampf(amount, 0.0, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var category: String = str(output.get("category", "Custom"))
	for spec: Dictionary in get_parameter_specs(category):
		var key: String = str(spec.get("key", ""))
		if key.is_empty() or not output.has(key):
			continue
		var type_name: String = str(spec.get("type", "float"))
		match type_name:
			"bool":
				if rng.randf() < strength * 0.35:
					output[key] = not bool(output[key])
			"enum":
				if rng.randf() < strength * 0.45:
					var options: PackedStringArray = _spec_options(spec)
					if not options.is_empty():
						output[key] = options[rng.randi_range(0, options.size() - 1)]
			"int":
				var min_i: int = int(round(float(spec.get("min", 0.0))))
				var max_i: int = int(round(float(spec.get("max", 1.0))))
				var span_i: int = maxi(1, max_i - min_i)
				var current_i: int = int(output[key])
				var delta_i: int = int(round(rng.randf_range(-1.0, 1.0) * float(span_i) * strength * 0.35))
				output[key] = clampi(current_i + delta_i, min_i, max_i)
			_:
				var minimum: float = float(spec.get("min", 0.0))
				var maximum: float = maxf(minimum, float(spec.get("max", 1.0)))
				var span: float = maximum - minimum
				var current: float = float(output[key])
				output[key] = clampf(current + rng.randf_range(-1.0, 1.0) * span * strength * 0.35, minimum, maximum)
	return output


func generate(_params: Dictionary) -> GASPCMData:
	return null


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


static func _spec_options(spec: Dictionary) -> PackedStringArray:
	var value: Variant = spec.get("options", PackedStringArray())
	if value is PackedStringArray:
		return value as PackedStringArray
	if value is Array:
		return PackedStringArray(value as Array)
	return PackedStringArray()
