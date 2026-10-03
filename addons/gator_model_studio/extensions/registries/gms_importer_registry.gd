@tool
class_name GMSImporterRegistry
extends RefCounted

static var _importers: Dictionary = {}


static func register_importer(owner: String, source: Dictionary) -> Error:
	var descriptor: Dictionary = source.duplicate()
	var importer_id: String = str(descriptor.get("id", "")).strip_edges().to_lower()
	var display_name: String = str(descriptor.get("name", "")).strip_edges()
	var callback: Callable = descriptor.get("import", Callable())
	var extensions: PackedStringArray = GMSExtensionSchema.normalize_extensions(descriptor.get("extensions", PackedStringArray()))
	if owner.is_empty() or importer_id.is_empty() or display_name.is_empty() or extensions.is_empty() or not callback.is_valid():
		return ERR_INVALID_PARAMETER
	if _importers.has(importer_id):
		push_error("Gator Model Studio importer ID is already registered: %s" % importer_id)
		return ERR_ALREADY_EXISTS
	descriptor["id"] = importer_id
	descriptor["name"] = display_name
	descriptor["owner"] = owner
	descriptor["extensions"] = extensions
	descriptor["filter"] = str(descriptor.get("filter", GMSExtensionSchema.build_filter(display_name, extensions)))
	descriptor["order"] = int(descriptor.get("order", 0))
	_importers[importer_id] = descriptor
	return OK


static func unregister_owner(owner: String) -> void:
	for importer_id: Variant in _importers.keys():
		var descriptor: Dictionary = _importers[importer_id]
		if str(descriptor.get("owner", "")) == owner:
			_importers.erase(importer_id)


static func get_filters() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for descriptor: Dictionary in get_importers():
		result.append(str(descriptor.get("filter", "")))
	return result


static func can_import(path: String) -> bool:
	return not _find_for_extension(path.get_extension()).is_empty()


static func import_path(
	path: String,
	job: GMSBackgroundJob = null
) -> Dictionary:
	var descriptor: Dictionary = _find_for_extension(path.get_extension())
	if descriptor.is_empty():
		return {"handled": false, "objects": [], "cancelled": false}
	if job != null:
		job.update_progress(0.02, "Running extension importer")
		if job.is_cancelled():
			return {"handled": true, "objects": [], "cancelled": true}
	var callback: Callable = descriptor.get("import", Callable())
	var imported_value: Variant
	if callback.get_argument_count() >= 2:
		imported_value = callback.call(path, job)
	else:
		imported_value = callback.call(path)
	var objects: Array[GMSModelObject] = []
	if imported_value is Array:
		var imported_array: Array = imported_value as Array
		for value: Variant in imported_array:
			if job != null and job.is_cancelled():
				return {"handled": true, "objects": [], "cancelled": true}
			if value is GMSModelObject:
				objects.append(value as GMSModelObject)
	if job != null:
		job.update_progress(1.0, "Extension import complete")
	return {
		"handled": true,
		"objects": objects,
		"importer": str(descriptor.get("name", "Extension Importer")),
		"cancelled": false,
	}


static func get_importers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in _importers.values():
		result.append((value as Dictionary).duplicate())
	result.sort_custom(_sort_descriptors)
	return result


static func _find_for_extension(extension: String) -> Dictionary:
	var cleaned: String = extension.to_lower().trim_prefix(".")
	for descriptor: Dictionary in get_importers():
		var extensions: PackedStringArray = descriptor.get("extensions", PackedStringArray())
		if extensions.has(cleaned):
			return descriptor
	return {}


static func _sort_descriptors(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
