@tool
class_name GMSExporterRegistry
extends RefCounted

static var _exporters: Dictionary = {}


static func register_exporter(owner: String, source: Dictionary) -> Error:
	var descriptor: Dictionary = source.duplicate()
	var exporter_id: String = str(descriptor.get("id", "")).strip_edges().to_lower()
	var display_name: String = str(descriptor.get("name", "")).strip_edges()
	var extensions: PackedStringArray = GMSExtensionSchema.normalize_extensions(descriptor.get("extensions", PackedStringArray()))
	var document_callback: Callable = descriptor.get("export_document", Callable())
	var mesh_callback: Callable = descriptor.get("export_mesh", Callable())
	if owner.is_empty() or exporter_id.is_empty() or display_name.is_empty() or extensions.is_empty():
		return ERR_INVALID_PARAMETER
	if not document_callback.is_valid() and not mesh_callback.is_valid():
		return ERR_INVALID_PARAMETER
	if _exporters.has(exporter_id):
		push_error("Gator Model Studio exporter ID is already registered: %s" % exporter_id)
		return ERR_ALREADY_EXISTS
	descriptor["id"] = exporter_id
	descriptor["name"] = display_name
	descriptor["owner"] = owner
	descriptor["extensions"] = extensions
	descriptor["filter"] = str(descriptor.get("filter", GMSExtensionSchema.build_filter(display_name, extensions)))
	descriptor["order"] = int(descriptor.get("order", 0))
	_exporters[exporter_id] = descriptor
	return OK


static func unregister_owner(owner: String) -> void:
	for exporter_id: Variant in _exporters.keys():
		var descriptor: Dictionary = _exporters[exporter_id]
		if str(descriptor.get("owner", "")) == owner:
			_exporters.erase(exporter_id)


static func get_document_filters() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for descriptor: Dictionary in get_exporters():
		var callback: Callable = descriptor.get("export_document", Callable())
		if callback.is_valid():
			result.append(str(descriptor.get("filter", "")))
	return result


static func get_mesh_filters() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for descriptor: Dictionary in get_exporters():
		var callback: Callable = descriptor.get("export_mesh", Callable())
		if callback.is_valid():
			result.append(str(descriptor.get("filter", "")))
	return result


static func can_export_document(path: String) -> bool:
	return not _find_for_extension(path.get_extension(), true).is_empty()


static func can_export_mesh(path: String) -> bool:
	return not _find_for_extension(path.get_extension(), false).is_empty()


static func export_document(
	document: GMSDocument,
	path: String,
	job: GMSBackgroundJob = null
) -> Dictionary:
	var descriptor: Dictionary = _find_for_extension(path.get_extension(), true)
	if descriptor.is_empty():
		return {"handled": false, "error": OK, "cancelled": false}
	if job != null:
		job.update_progress(0.02, "Running extension exporter")
		if job.is_cancelled():
			return {"handled": true, "error": ERR_SKIP, "cancelled": true}
	var callback: Callable = descriptor.get("export_document", Callable())
	var value: Variant
	if callback.get_argument_count() >= 3:
		value = callback.call(document, path, job)
	else:
		value = callback.call(document, path)
	if job != null:
		job.update_progress(1.0, "Extension export complete")
	return {
		"handled": true,
		"error": int(value) if value is int else OK,
		"exporter": str(descriptor.get("name", "Extension Exporter")),
		"cancelled": job != null and job.is_cancelled(),
	}


static func export_mesh(
	objects: Array[GMSModelObject],
	path: String,
	combined: bool,
	job: GMSBackgroundJob = null
) -> Dictionary:
	var descriptor: Dictionary = _find_for_extension(path.get_extension(), false)
	if descriptor.is_empty():
		return {"handled": false, "error": OK, "cancelled": false}
	if job != null:
		job.update_progress(0.02, "Running extension mesh exporter")
		if job.is_cancelled():
			return {"handled": true, "error": ERR_SKIP, "cancelled": true}
	var callback: Callable = descriptor.get("export_mesh", Callable())
	var value: Variant
	if callback.get_argument_count() >= 4:
		value = callback.call(objects, path, combined, job)
	else:
		value = callback.call(objects, path, combined)
	if job != null:
		job.update_progress(1.0, "Extension mesh export complete")
	return {
		"handled": true,
		"error": int(value) if value is int else OK,
		"exporter": str(descriptor.get("name", "Extension Exporter")),
		"cancelled": job != null and job.is_cancelled(),
	}


static func get_exporters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in _exporters.values():
		result.append((value as Dictionary).duplicate())
	result.sort_custom(_sort_descriptors)
	return result


static func _find_for_extension(extension: String, document_scope: bool) -> Dictionary:
	var cleaned: String = extension.to_lower().trim_prefix(".")
	for descriptor: Dictionary in get_exporters():
		var extensions: PackedStringArray = descriptor.get("extensions", PackedStringArray())
		if not extensions.has(cleaned):
			continue
		var callback: Callable = descriptor.get(
			"export_document" if document_scope else "export_mesh",
			Callable()
		)
		if callback.is_valid():
			return descriptor
	return {}


static func _sort_descriptors(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("order", 0))
	var order_b: int = int(b.get("order", 0))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0
