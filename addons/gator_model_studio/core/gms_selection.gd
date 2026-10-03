@tool
class_name GMSSelection
extends RefCounted

enum Mode {
	OBJECT,
	VERTEX,
	EDGE,
	FACE,
}

enum Operation {
	SET,
	ADD,
	SUBTRACT,
}

signal changed

var mode: Mode = Mode.OBJECT
var object_ids: PackedStringArray = PackedStringArray()
var vertex_indices: PackedInt32Array = PackedInt32Array()
var edge_indices: PackedInt32Array = PackedInt32Array()
var face_indices: PackedInt32Array = PackedInt32Array()


func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	_clear_components_without_signal()
	changed.emit()


func clear() -> void:
	object_ids.clear()
	_clear_components_without_signal()
	changed.emit()


func clear_components() -> void:
	_clear_components_without_signal()
	changed.emit()


func restore_state(
	new_mode: Mode,
	new_object_ids: PackedStringArray,
	new_vertex_indices: PackedInt32Array,
	new_edge_indices: PackedInt32Array,
	new_face_indices: PackedInt32Array
) -> void:
	mode = new_mode
	object_ids = new_object_ids.duplicate()
	vertex_indices = new_vertex_indices.duplicate()
	edge_indices = new_edge_indices.duplicate()
	face_indices = new_face_indices.duplicate()
	changed.emit()


func select_object(object_id: String, additive: bool = false) -> void:
	if object_id.is_empty():
		clear()
		return

	if not additive:
		object_ids.clear()
		_clear_components_without_signal()

	var existing_index: int = object_ids.find(object_id)
	if additive and existing_index >= 0:
		object_ids.remove_at(existing_index)
	elif existing_index < 0:
		object_ids.append(object_id)
	changed.emit()


func select_objects(ids: PackedStringArray, operation: int = Operation.SET) -> void:
	match operation:
		Operation.SET:
			object_ids.clear()
			for object_id: String in ids:
				if not object_id.is_empty() and not object_ids.has(object_id):
					object_ids.append(object_id)
			_clear_components_without_signal()
		Operation.ADD:
			for object_id: String in ids:
				if not object_id.is_empty() and not object_ids.has(object_id):
					object_ids.append(object_id)
		Operation.SUBTRACT:
			for object_id: String in ids:
				var found_index: int = object_ids.find(object_id)
				if found_index >= 0:
					object_ids.remove_at(found_index)
	changed.emit()


func select_vertex(vertex_index: int, additive: bool = false) -> void:
	if not additive:
		vertex_indices.clear()
	vertex_indices = _toggled_component(vertex_indices, vertex_index, additive)
	edge_indices.clear()
	face_indices.clear()
	changed.emit()


func select_edge(edge_index: int, additive: bool = false) -> void:
	if not additive:
		edge_indices.clear()
	edge_indices = _toggled_component(edge_indices, edge_index, additive)
	vertex_indices.clear()
	face_indices.clear()
	changed.emit()


func select_face(face_index: int, additive: bool = false) -> void:
	if not additive:
		face_indices.clear()
	face_indices = _toggled_component(face_indices, face_index, additive)
	vertex_indices.clear()
	edge_indices.clear()
	changed.emit()


func set_component_indices(
	indices: PackedInt32Array,
	operation: int = Operation.SET
) -> void:
	match mode:
		Mode.VERTEX:
			vertex_indices = _apply_operation(vertex_indices, indices, operation)
			edge_indices.clear()
			face_indices.clear()
		Mode.EDGE:
			edge_indices = _apply_operation(edge_indices, indices, operation)
			vertex_indices.clear()
			face_indices.clear()
		Mode.FACE:
			face_indices = _apply_operation(face_indices, indices, operation)
			vertex_indices.clear()
			edge_indices.clear()
	changed.emit()


func select_all(mesh: GMSMeshData) -> void:
	if mesh == null:
		return

	_clear_components_without_signal()
	match mode:
		Mode.VERTEX:
			vertex_indices = _range_array(mesh.vertices.size())
		Mode.EDGE:
			edge_indices = _range_array(mesh.get_edges().size())
		Mode.FACE:
			face_indices = _range_array(mesh.faces.size())
	changed.emit()


func invert(mesh: GMSMeshData) -> void:
	if mesh == null:
		return
	match mode:
		Mode.VERTEX:
			vertex_indices = _inverted_range(vertex_indices, mesh.vertices.size())
		Mode.EDGE:
			edge_indices = _inverted_range(edge_indices, mesh.get_edges().size())
		Mode.FACE:
			face_indices = _inverted_range(face_indices, mesh.faces.size())
	changed.emit()


func sanitize(mesh: GMSMeshData) -> void:
	if mesh == null:
		if not vertex_indices.is_empty() or not edge_indices.is_empty() or not face_indices.is_empty():
			clear_components()
		return

	var old_vertices: PackedInt32Array = vertex_indices.duplicate()
	var old_edges: PackedInt32Array = edge_indices.duplicate()
	var old_faces: PackedInt32Array = face_indices.duplicate()

	if not vertex_indices.is_empty():
		vertex_indices = _filter_range(vertex_indices, mesh.vertices.size())
	if not edge_indices.is_empty():
		edge_indices = _filter_range(edge_indices, mesh.get_edges().size())
	if not face_indices.is_empty():
		face_indices = _filter_range(face_indices, mesh.faces.size())

	if old_vertices != vertex_indices or old_edges != edge_indices or old_faces != face_indices:
		changed.emit()


func get_primary_object_id() -> String:
	if object_ids.is_empty():
		return ""


	return object_ids[object_ids.size() - 1]


func get_component_count() -> int:
	match mode:
		Mode.VERTEX:
			return vertex_indices.size()
		Mode.EDGE:
			return edge_indices.size()
		Mode.FACE:
			return face_indices.size()
		_:
			return object_ids.size()


func _toggled_component(
	indices: PackedInt32Array,
	index: int,
	additive: bool
) -> PackedInt32Array:
	var result: PackedInt32Array = indices.duplicate()
	if index < 0:
		return result

	var existing_index: int = result.find(index)
	if additive and existing_index >= 0:
		result.remove_at(existing_index)
	elif existing_index < 0:
		result.append(index)
	return result


func _clear_components_without_signal() -> void:
	vertex_indices.clear()
	edge_indices.clear()
	face_indices.clear()


static func _apply_operation(
	current: PackedInt32Array,
	incoming: PackedInt32Array,
	operation: int
) -> PackedInt32Array:
	var membership: Dictionary = {}
	if operation != Operation.SET:
		for index: int in current:
			if index >= 0:
				membership[index] = true
	for index: int in incoming:
		if index < 0:
			continue
		if operation == Operation.SUBTRACT:
			membership.erase(index)
		else:
			membership[index] = true
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(membership.size())
	var write_index: int = 0
	for index_value: Variant in membership.keys():
		result[write_index] = int(index_value)
		write_index += 1
	result.sort()
	return result


static func _range_array(count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(maxi(count, 0))
	for index: int in result.size():
		result[index] = index
	return result


static func _inverted_range(source: PackedInt32Array, count: int) -> PackedInt32Array:
	var safe_count: int = maxi(count, 0)
	var selected: PackedByteArray = PackedByteArray()
	selected.resize(safe_count)
	for index: int in source:
		if index >= 0 and index < safe_count:
			selected[index] = 1
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(safe_count)
	var write_index: int = 0
	for index: int in safe_count:
		if selected[index] == 0:
			if write_index >= result.size():
				result.append(index)
			else:
				result[write_index] = index
			write_index += 1
	result.resize(write_index)
	return result


static func _filter_range(source: PackedInt32Array, count: int) -> PackedInt32Array:
	var safe_count: int = maxi(count, 0)
	var known: PackedByteArray = PackedByteArray()
	known.resize(safe_count)
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(mini(source.size(), safe_count))
	var write_index: int = 0
	for index: int in source:
		if index < 0 or index >= safe_count or known[index] != 0:
			continue
		known[index] = 1
		result[write_index] = index
		write_index += 1
	result.resize(write_index)
	return result

