@tool
class_name GMSModelToolRegistry
extends RefCounted

static var _tools: Dictionary = {}


static func register_tool(owner: String, source: Dictionary) -> Error:
	var descriptor: Dictionary = source.duplicate()
	var tool_id: String = str(descriptor.get("id", "")).strip_edges().to_lower()
	var display_name: String = str(descriptor.get("name", "")).strip_edges()
	var generate: Callable = descriptor.get("generate", Callable())
	if owner.is_empty() or tool_id.is_empty() or display_name.is_empty() or not generate.is_valid():
		return ERR_INVALID_PARAMETER
	if _tools.has(tool_id):
		push_error("Gator Model Studio tool ID is already registered: %s" % tool_id)
		return ERR_ALREADY_EXISTS
	descriptor["id"] = tool_id
	descriptor["name"] = display_name
	descriptor["owner"] = owner
	descriptor["tooltip"] = str(descriptor.get("tooltip", ""))
	descriptor["object_name"] = str(descriptor.get("object_name", display_name))
	descriptor["category"] = str(descriptor.get("category", "Extensions"))
	descriptor["order"] = int(descriptor.get("order", 0))
	descriptor["parameters"] = GMSExtensionSchema.normalize_parameters(descriptor.get("parameters", []))
	_tools[tool_id] = descriptor
	return OK


static func unregister_owner(owner: String) -> void:
	for tool_id: Variant in _tools.keys():
		var descriptor: Dictionary = _tools[tool_id]
		if str(descriptor.get("owner", "")) == owner:
			_tools.erase(tool_id)


static func has_tool(tool_id: String) -> bool:
	return _tools.has(tool_id.to_lower())


static func get_tool(tool_id: String) -> Dictionary:
	return (_tools.get(tool_id.to_lower(), {}) as Dictionary).duplicate()


static func get_tools() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in _tools.values():
		result.append((value as Dictionary).duplicate())
	result.sort_custom(_sort_descriptors)
	return result


static func get_default_parameters(tool_id: String) -> Dictionary:
	return GMSExtensionSchema.default_parameters(get_tool(tool_id).get("parameters", []))


static func generate(tool_id: String, parameters: Dictionary) -> GMSMeshData:
	var descriptor: Dictionary = get_tool(tool_id)
	if descriptor.is_empty():
		return null
	var callback: Callable = descriptor.get("generate", Callable())
	if not callback.is_valid():
		return null
	var merged: Dictionary = get_default_parameters(tool_id)
	for key: Variant in parameters.keys():
		merged[key] = parameters[key]
	var value: Variant = callback.call(merged)
	if value is GMSMeshData:
		var mesh: GMSMeshData = value as GMSMeshData
		return mesh if mesh.is_valid() else null
	return null


static func _sort_descriptors(a: Dictionary, b: Dictionary) -> bool:
	var category_a: String = str(a.get("category", ""))
	var category_b: String = str(b.get("category", ""))
	if category_a != category_b:
		return category_a.naturalnocasecmp_to(category_b) < 0
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
