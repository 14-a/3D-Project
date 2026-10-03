@tool
class_name GMSModifierRegistry
extends RefCounted

static var _modifiers: Dictionary = {}


static func register_modifier(owner: String, source: Dictionary) -> Error:
	var descriptor: Dictionary = source.duplicate()
	var modifier_id: String = str(descriptor.get("id", "")).strip_edges().to_lower()
	var display_name: String = str(descriptor.get("name", "")).strip_edges()
	var evaluate_callback: Callable = descriptor.get("evaluate", Callable())
	if owner.is_empty() or modifier_id.is_empty() or display_name.is_empty() or not evaluate_callback.is_valid():
		return ERR_INVALID_PARAMETER
	if _modifiers.has(modifier_id):
		push_error("Gator Model Studio modifier ID is already registered: %s" % modifier_id)
		return ERR_ALREADY_EXISTS
	descriptor["id"] = modifier_id
	descriptor["name"] = display_name
	descriptor["owner"] = owner
	descriptor["tooltip"] = str(descriptor.get("tooltip", ""))
	descriptor["order"] = int(descriptor.get("order", 0))
	descriptor["parameters"] = GMSExtensionSchema.normalize_parameters(descriptor.get("parameters", []))
	_modifiers[modifier_id] = descriptor
	return OK


static func unregister_owner(owner: String) -> void:
	for modifier_id: Variant in _modifiers.keys():
		var descriptor: Dictionary = _modifiers[modifier_id]
		if str(descriptor.get("owner", "")) == owner:
			_modifiers.erase(modifier_id)


static func has_modifier(modifier_id: String) -> bool:
	return _modifiers.has(modifier_id.to_lower())


static func get_modifier(modifier_id: String) -> Dictionary:
	return (_modifiers.get(modifier_id.to_lower(), {}) as Dictionary).duplicate()


static func get_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in _modifiers.values():
		result.append((value as Dictionary).duplicate())
	result.sort_custom(_sort_descriptors)
	return result


static func create_modifier(modifier_id: String) -> GMSModifier:
	var descriptor: Dictionary = get_modifier(modifier_id)
	if descriptor.is_empty():
		return null
	var defaults: Dictionary = {}
	for value: Variant in descriptor.get("parameters", []):
		if value is Dictionary:
			var parameter: Dictionary = value
			defaults[str(parameter.get("id", ""))] = parameter.get("default", 0.0)
	return GMSModifier.create_custom(modifier_id, str(descriptor.get("name", "Custom Modifier")), defaults)


static func evaluate(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or modifier == null:
		return source
	var descriptor: Dictionary = get_modifier(modifier.custom_id)
	if descriptor.is_empty():
		return source
	var callback: Callable = descriptor.get("evaluate", Callable())
	if not callback.is_valid():
		return source
	var value: Variant = callback.call(source, modifier.custom_parameters.duplicate(true))
	if value is GMSMeshData:
		var mesh: GMSMeshData = value as GMSMeshData
		return mesh if mesh.is_valid() else source
	return source


static func get_tooltip(modifier_id: String) -> String:
	return str(get_modifier(modifier_id).get("tooltip", "Custom extension modifier."))


static func get_parameters(modifier_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in get_modifier(modifier_id).get("parameters", []):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


static func _sort_descriptors(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
