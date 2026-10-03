@tool
class_name GMSMeshData
extends Resource








@export var vertices: PackedVector3Array = PackedVector3Array()
@export var faces: Array[PackedInt32Array] = []
@export var loose_edges: Array[Vector2i] = []
@export var smooth_faces: PackedByteArray = PackedByteArray()
@export var uv_faces: Array[PackedVector2Array] = []
@export var has_uv_map: bool = false
@export var corner_normals: Array[PackedVector3Array] = []
@export var has_custom_normals: bool = false
@export var crease_edges: Array[Vector2i] = []
@export var crease_weights: PackedFloat32Array = PackedFloat32Array()
@export var seam_edges: Array[Vector2i] = []
@export var face_materials: PackedInt32Array = PackedInt32Array()
@export var uv_seam_analysis_pending: bool = false

var _change_revision: int = 1
var _position_revision: int = 1
var _topology_revision: int = 1
var _last_position_change_indices: PackedInt32Array = PackedInt32Array()
var _cache_enabled: bool = true
var _cached_aabb_revision: int = -1
var _cached_aabb: AABB = AABB()
var _cached_face_data_revision: int = -1
var _cached_face_centers: PackedVector3Array = PackedVector3Array()
var _cached_face_normals: PackedVector3Array = PackedVector3Array()
var _cached_face_edges_revision: int = -1
var _cached_face_edges: Array[Vector2i] = []
var _cached_edges_revision: int = -1
var _cached_edges: Array[Vector2i] = []
var _cached_edge_lookup_revision: int = -1
var _cached_edge_lookup: Dictionary = {}
var _cached_topology_revision: int = -1
var _cached_topology: GMSTopology


func set_geometry(
	new_vertices: PackedVector3Array,
	new_faces: Array[PackedInt32Array],
	new_smooth_faces: PackedByteArray = PackedByteArray(),
	new_uv_faces: Array[PackedVector2Array] = [],
	new_has_uv_map: bool = false,
	new_corner_normals: Array[PackedVector3Array] = [],
	new_has_custom_normals: bool = false,
	new_loose_edges: Array[Vector2i] = [],
	new_crease_edges: Array[Vector2i] = [],
	new_crease_weights: PackedFloat32Array = PackedFloat32Array(),
	new_seam_edges: Array[Vector2i] = [],
	new_face_materials: PackedInt32Array = PackedInt32Array()
) -> void:
	var previous_faces: Array[PackedInt32Array] = _duplicate_faces(faces)
	var previous_materials: PackedInt32Array = face_materials.duplicate()
	vertices = new_vertices
	faces = _duplicate_faces(new_faces)
	loose_edges = new_loose_edges.duplicate()
	smooth_faces = new_smooth_faces.duplicate()
	uv_faces = _duplicate_uv_faces(new_uv_faces)
	has_uv_map = new_has_uv_map
	corner_normals = _duplicate_normal_faces(new_corner_normals)
	has_custom_normals = new_has_custom_normals
	crease_edges = new_crease_edges.duplicate()
	crease_weights = new_crease_weights.duplicate()
	seam_edges = new_seam_edges.duplicate()
	face_materials = _remap_or_copy_face_materials(previous_faces, previous_materials, new_faces, new_face_materials)
	_reset_derived_caches()
	_normalize_smooth_flags()
	_normalize_uv_layout()
	_normalize_normal_layout()
	_normalize_loose_edges()
	_normalize_creases()
	_normalize_seams()
	_normalize_face_materials()
	mark_changed()


func set_geometry_internal(
	new_vertices: PackedVector3Array,
	new_faces: Array[PackedInt32Array],
	new_smooth_faces: PackedByteArray = PackedByteArray(),
	new_uv_faces: Array[PackedVector2Array] = [],
	new_has_uv_map: bool = false,
	new_corner_normals: Array[PackedVector3Array] = [],
	new_has_custom_normals: bool = false,
	new_loose_edges: Array[Vector2i] = [],
	new_crease_edges: Array[Vector2i] = [],
	new_crease_weights: PackedFloat32Array = PackedFloat32Array(),
	new_seam_edges: Array[Vector2i] = [],
	new_face_materials: PackedInt32Array = PackedInt32Array()
) -> void:
	vertices = new_vertices
	faces = new_faces
	loose_edges = new_loose_edges
	smooth_faces = new_smooth_faces
	uv_faces = new_uv_faces
	has_uv_map = new_has_uv_map
	corner_normals = new_corner_normals
	has_custom_normals = new_has_custom_normals
	crease_edges = new_crease_edges
	crease_weights = new_crease_weights
	seam_edges = new_seam_edges
	face_materials = new_face_materials
	_change_revision += 1
	_position_revision += 1
	_topology_revision += 1
	_last_position_change_indices.clear()
	_cache_enabled = false
	_reset_derived_caches()


func duplicate_mesh_data() -> GMSMeshData:
	return duplicate_mesh_data_fast()


func duplicate_mesh_data_fast() -> GMSMeshData:
	var copy: GMSMeshData = GMSMeshData.new()
	copy.vertices = vertices.duplicate()
	copy.faces = _duplicate_faces(faces)
	copy.loose_edges = loose_edges.duplicate()
	copy.smooth_faces = smooth_faces.duplicate()
	copy.uv_faces = _duplicate_uv_faces(uv_faces)
	copy.has_uv_map = has_uv_map
	copy.corner_normals = _duplicate_normal_faces(corner_normals)
	copy.has_custom_normals = has_custom_normals
	copy.crease_edges = crease_edges.duplicate()
	copy.crease_weights = crease_weights.duplicate()
	copy.seam_edges = seam_edges.duplicate()
	copy.face_materials = face_materials.duplicate()
	copy.uv_seam_analysis_pending = uv_seam_analysis_pending
	copy._change_revision = 1
	copy._position_revision = 1
	copy._topology_revision = 1
	copy._last_position_change_indices.clear()
	copy._cache_enabled = false
	return copy


func duplicate_mesh_data_validated() -> GMSMeshData:
	var copy: GMSMeshData = duplicate_mesh_data_fast()
	copy._normalize_smooth_flags()
	copy._normalize_uv_layout()
	copy._normalize_normal_layout()
	copy._normalize_loose_edges()
	copy._normalize_creases()
	copy._normalize_seams()
	copy._normalize_face_materials()
	copy.prepare_for_use()
	return copy


func get_change_revision() -> int:
	return _change_revision


func get_position_revision() -> int:
	return _position_revision


func get_topology_revision() -> int:
	return _topology_revision


func get_last_position_change_indices() -> PackedInt32Array:
	return _last_position_change_indices


func get_vertex_positions(indices: PackedInt32Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	result.resize(indices.size())
	for index: int in indices.size():
		var vertex_index: int = indices[index]
		result[index] = vertices[vertex_index] if vertex_index >= 0 and vertex_index < vertices.size() else Vector3.ZERO
	return result


func set_vertex_positions(indices: PackedInt32Array, positions: PackedVector3Array) -> void:
	var count: int = mini(indices.size(), positions.size())
	if count <= 0:
		return
	var changed_indices: PackedInt32Array = PackedInt32Array()
	changed_indices.resize(count)
	var changed_count: int = 0
	for index: int in count:
		var vertex_index: int = indices[index]
		if vertex_index < 0 or vertex_index >= vertices.size():
			continue
		var new_position: Vector3 = positions[index]
		if vertices[vertex_index].is_equal_approx(new_position):
			continue
		vertices[vertex_index] = new_position
		changed_indices[changed_count] = vertex_index
		changed_count += 1
	if changed_count <= 0:
		return
	changed_indices.resize(changed_count)
	mark_positions_changed(changed_indices)


func mark_changed() -> void:
	_change_revision += 1
	_position_revision += 1
	_topology_revision += 1
	_last_position_change_indices.clear()
	_reset_derived_caches()
	emit_changed()


func mark_positions_changed(indices: PackedInt32Array = PackedInt32Array()) -> void:
	var previous_revision: int = _change_revision
	_change_revision += 1
	_position_revision += 1
	_last_position_change_indices = indices.duplicate()
	_cached_aabb_revision = -1
	_cached_face_data_revision = -1
	_cached_face_centers = PackedVector3Array()
	_cached_face_normals = PackedVector3Array()
	if _cached_face_edges_revision == previous_revision:
		_cached_face_edges_revision = _change_revision
	if _cached_edges_revision == previous_revision:
		_cached_edges_revision = _change_revision
	if _cached_edge_lookup_revision == previous_revision:
		_cached_edge_lookup_revision = _change_revision
	if _cached_topology_revision == previous_revision:
		_cached_topology_revision = _change_revision
	emit_changed()


func prepare_for_use() -> void:
	if _cache_enabled:
		return
	_cache_enabled = true
	_change_revision += 1
	_position_revision += 1
	_topology_revision += 1
	_last_position_change_indices.clear()
	_reset_derived_caches()


func _reset_derived_caches() -> void:
	_cached_aabb_revision = -1
	_cached_face_data_revision = -1
	_cached_face_edges_revision = -1
	_cached_edges_revision = -1
	_cached_edge_lookup_revision = -1
	_cached_topology_revision = -1
	_cached_face_centers = PackedVector3Array()
	_cached_face_normals = PackedVector3Array()
	_cached_face_edges.clear()
	_cached_edges.clear()
	_cached_edge_lookup.clear()
	_cached_topology = null


func is_valid() -> bool:
	_normalize_face_materials()
	if vertices.is_empty() or (faces.is_empty() and loose_edges.is_empty()):
		return false

	for face_index: int in faces.size():
		var face: PackedInt32Array = faces[face_index]
		if face.size() < 3:
			return false
		if face.size() == 3:
			if face[0] == face[1] or face[1] == face[2] or face[2] == face[0]:
				return false
			for vertex_index: int in face:
				if vertex_index < 0 or vertex_index >= vertices.size():
					return false
		else:
			var unique: Dictionary = {}
			for vertex_index: int in face:
				if vertex_index < 0 or vertex_index >= vertices.size():
					return false
				unique[vertex_index] = true
			if unique.size() < 3:
				return false
		if has_uv_map:
			if face_index >= uv_faces.size() or uv_faces[face_index].size() != face.size():
				return false
		if has_custom_normals:
			if face_index >= corner_normals.size() or corner_normals[face_index].size() != face.size():
				return false
		if face_index >= face_materials.size() or face_materials[face_index] < 0:
			return false

	for edge: Vector2i in loose_edges:
		if edge.x < 0 or edge.y < 0 or edge.x >= vertices.size() or edge.y >= vertices.size():
			return false
		if edge.x == edge.y:
			return false

	return true


func get_aabb() -> AABB:
	if _cache_enabled and _cached_aabb_revision == _change_revision:
		return _cached_aabb
	if vertices.is_empty():
		_cached_aabb = AABB()
	else:
		var bounds: AABB = AABB(vertices[0], Vector3.ZERO)
		for vertex_index: int in range(1, vertices.size()):
			bounds = bounds.expand(vertices[vertex_index])
		_cached_aabb = bounds
	if _cache_enabled:
		_cached_aabb_revision = _change_revision
	return _cached_aabb


func _ensure_face_data_cache() -> void:
	if _cache_enabled and _cached_face_data_revision == _change_revision:
		return
	_cached_face_centers.resize(faces.size())
	_cached_face_normals.resize(faces.size())
	for face_index: int in faces.size():
		var face: PackedInt32Array = faces[face_index]
		if face.is_empty():
			_cached_face_centers[face_index] = Vector3.ZERO
			_cached_face_normals[face_index] = Vector3.UP
			continue
		var center: Vector3 = Vector3.ZERO
		var normal: Vector3 = Vector3.ZERO
		for corner_index: int in face.size():
			var current: Vector3 = vertices[face[corner_index]]
			var next: Vector3 = vertices[face[(corner_index + 1) % face.size()]]
			center += current
			normal.x += (current.y - next.y) * (current.z + next.z)
			normal.y += (current.z - next.z) * (current.x + next.x)
			normal.z += (current.x - next.x) * (current.y + next.y)
		_cached_face_centers[face_index] = center / float(face.size())
		_cached_face_normals[face_index] = Vector3.UP if normal.is_zero_approx() else normal.normalized()
	if _cache_enabled:
		_cached_face_data_revision = _change_revision


func get_face_center(face_index: int) -> Vector3:
	if face_index < 0 or face_index >= faces.size():
		return Vector3.ZERO
	_ensure_face_data_cache()
	return _cached_face_centers[face_index]


func get_face_normal(face_index: int) -> Vector3:
	if face_index < 0 or face_index >= faces.size():
		return Vector3.UP
	_ensure_face_data_cache()
	return _cached_face_normals[face_index]


func get_face_edges() -> Array[Vector2i]:
	if _cache_enabled and _cached_face_edges_revision == _change_revision:
		return _cached_face_edges
	_cached_face_edges = []
	var known: Dictionary = {}
	for face: PackedInt32Array in faces:
		for corner_index: int in face.size():
			var edge: Vector2i = canonical_edge(
				face[corner_index],
				face[(corner_index + 1) % face.size()]
			)
			if not known.has(edge):
				known[edge] = true
				_cached_face_edges.append(edge)
	if _cache_enabled:
		_cached_face_edges_revision = _change_revision
	return _cached_face_edges


func get_edges() -> Array[Vector2i]:
	if _cache_enabled and _cached_edges_revision == _change_revision:
		return _cached_edges
	_cached_edges = get_face_edges().duplicate()
	var known: Dictionary = {}
	for edge: Vector2i in _cached_edges:
		known[edge] = true
	for source_edge: Vector2i in loose_edges:
		var edge: Vector2i = canonical_edge(source_edge.x, source_edge.y)
		if not known.has(edge):
			known[edge] = true
			_cached_edges.append(edge)
	if _cache_enabled:
		_cached_edges_revision = _change_revision
	return _cached_edges


func get_edge_count() -> int:
	return get_edges().size()


func has_cached_edges() -> bool:
	return _cache_enabled and _cached_edges_revision == _change_revision


func get_cached_edge_count() -> int:
	return _cached_edges.size() if has_cached_edges() else -1


func install_precomputed_edges(
	face_edges: Array[Vector2i],
	all_edges: Array[Vector2i],
	edge_lookup: Dictionary,
	source_revision: int
) -> void:
	if not _cache_enabled or source_revision != _change_revision:
		return
	_cached_face_edges = face_edges
	_cached_edges = all_edges
	_cached_edge_lookup = edge_lookup
	_cached_face_edges_revision = _change_revision
	_cached_edges_revision = _change_revision
	_cached_edge_lookup_revision = _change_revision


func get_edge_index(a: int, b: int) -> int:
	if not _cache_enabled:
		return get_edges().find(canonical_edge(a, b))
	if _cached_edge_lookup_revision != _change_revision:
		_cached_edge_lookup.clear()
		var edges: Array[Vector2i] = get_edges()
		for edge_index: int in edges.size():
			_cached_edge_lookup[edges[edge_index]] = edge_index
		_cached_edge_lookup_revision = _change_revision
	return int(_cached_edge_lookup.get(canonical_edge(a, b), -1))


func get_topology() -> GMSTopology:
	if not _cache_enabled:
		return GMSTopology.new(self)
	if _cached_topology_revision != _change_revision or _cached_topology == null:
		_cached_topology = GMSTopology.new(self)
		_cached_topology_revision = _change_revision
	return _cached_topology


func is_loose_edge(edge: Vector2i) -> bool:
	var canonical: Vector2i = canonical_edge(edge.x, edge.y)
	return loose_edges.has(canonical)


func get_edge_crease_by_vertices(a: int, b: int) -> float:
	_normalize_creases()
	var index: int = crease_edges.find(canonical_edge(a, b))
	if index < 0 or index >= crease_weights.size():
		return 0.0
	return crease_weights[index]


func get_edge_crease(edge_index: int) -> float:
	var edges: Array[Vector2i] = get_edges()
	if edge_index < 0 or edge_index >= edges.size():
		return 0.0
	return get_edge_crease_by_vertices(edges[edge_index].x, edges[edge_index].y)


func set_edge_crease_by_vertices(a: int, b: int, weight: float) -> void:
	var edge: Vector2i = canonical_edge(a, b)
	var clamped: float = clampf(weight, 0.0, 1.0)
	var index: int = crease_edges.find(edge)
	if clamped <= 0.000001:
		if index >= 0:
			crease_edges.remove_at(index)
			crease_weights.remove_at(index)
	else:
		if index < 0:
			crease_edges.append(edge)
			crease_weights.append(clamped)
		else:
			crease_weights[index] = clamped
	mark_changed()


func is_edge_seam_by_vertices(a: int, b: int) -> bool:
	_normalize_seams()
	return seam_edges.has(canonical_edge(a, b))


func set_edge_seam_by_vertices(a: int, b: int, marked: bool) -> void:
	var edge: Vector2i = canonical_edge(a, b)
	var index: int = seam_edges.find(edge)
	if marked:
		if index < 0 and get_edges().has(edge):
			seam_edges.append(edge)
	else:
		if index >= 0:
			seam_edges.remove_at(index)
	_normalize_seams()
	mark_changed()


func clear_seams() -> void:
	seam_edges.clear()
	mark_changed()


func get_face_uvs(face_index: int) -> PackedVector2Array:
	_normalize_uv_layout()
	if face_index < 0 or face_index >= uv_faces.size():
		return PackedVector2Array()
	return uv_faces[face_index].duplicate()


func set_face_uvs(face_index: int, values: PackedVector2Array) -> void:
	if face_index < 0 or face_index >= faces.size():
		return
	if values.size() != faces[face_index].size():
		return
	_normalize_uv_layout()
	uv_faces[face_index] = values.duplicate()
	has_uv_map = true
	mark_changed()


func get_face_material(face_index: int) -> int:
	if face_materials.size() != faces.size():
		_normalize_face_materials()
	if face_index < 0 or face_index >= face_materials.size():
		return 0
	var material_index: int = face_materials[face_index]
	if material_index < 0:
		face_materials[face_index] = 0
		return 0
	return material_index


func set_face_material(face_index: int, material_index: int) -> void:
	if face_index < 0 or face_index >= faces.size():
		return
	_normalize_face_materials()
	face_materials[face_index] = maxi(material_index, 0)
	mark_changed()


func assign_material_to_faces(face_indices: PackedInt32Array, material_index: int) -> void:
	_normalize_face_materials()
	var safe_index: int = maxi(material_index, 0)
	for face_index: int in face_indices:
		if face_index >= 0 and face_index < face_materials.size():
			face_materials[face_index] = safe_index
	mark_changed()


func remap_removed_material_slot(removed_index: int) -> void:
	_normalize_face_materials()
	for face_index: int in face_materials.size():
		var current: int = face_materials[face_index]
		if current == removed_index:
			face_materials[face_index] = 0
		elif current > removed_index:
			face_materials[face_index] = current - 1
	mark_changed()


func offset_face_material_indices(offset: int) -> void:
	if offset == 0:
		return
	_normalize_face_materials()
	for face_index: int in face_materials.size():
		face_materials[face_index] = maxi(face_materials[face_index] + offset, 0)
	mark_changed()


func invalidate_uvs() -> void:
	has_uv_map = false
	uv_faces.clear()
	_normalize_uv_layout()
	mark_changed()


func invalidate_custom_normals() -> void:
	has_custom_normals = false
	corner_normals.clear()
	_normalize_normal_layout()
	mark_changed()


func update_array_mesh_vertex_positions(
	array_mesh: ArrayMesh,
	vertex_indices: PackedInt32Array
) -> bool:
	if array_mesh == null or vertex_indices.is_empty():
		return false
	var surface_maps: Array = array_mesh.get_meta("_gms_surface_vertex_maps", [])
	if surface_maps.size() == array_mesh.get_surface_count():
		return update_array_mesh_vertex_positions_mapped(
			array_mesh, vertices, vertex_indices, surface_maps
		)
	for surface_index: int in array_mesh.get_surface_count():
		if array_mesh.surface_get_array_len(surface_index) != vertices.size():
			return false
	var sorted_indices: PackedInt32Array = vertex_indices.duplicate()
	sorted_indices.sort()
	if sorted_indices.size() * 10 >= vertices.size():
		var full_data: PackedByteArray = vertices.to_byte_array()
		for surface_index: int in array_mesh.get_surface_count():
			array_mesh.surface_update_vertex_region(surface_index, 0, full_data)
		return true
	var cursor: int = 0
	while cursor < sorted_indices.size():
		var run_start: int = cursor
		var first_vertex: int = sorted_indices[cursor]
		cursor += 1
		while cursor < sorted_indices.size() and sorted_indices[cursor] == sorted_indices[cursor - 1] + 1:
			cursor += 1
		var run_size: int = cursor - run_start
		var run_positions: PackedVector3Array = PackedVector3Array()
		run_positions.resize(run_size)
		for run_index: int in run_size:
			run_positions[run_index] = vertices[sorted_indices[run_start + run_index]]
		var run_data: PackedByteArray = run_positions.to_byte_array()
		for surface_index: int in array_mesh.get_surface_count():
			array_mesh.surface_update_vertex_region(
				surface_index, first_vertex * 12, run_data
			)
	return true


static func build_surface_vertex_maps(
	mesh: GMSMeshData,
	material_count: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if mesh == null or mesh.vertices.is_empty() or mesh.faces.is_empty():
		return result
	var safe_material_count: int = maxi(material_count, 1)
	var slot_faces: Array[PackedInt32Array] = []
	slot_faces.resize(safe_material_count)
	for slot_index: int in safe_material_count:
		slot_faces[slot_index] = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		var slot_index: int = 0
		if face_index < mesh.face_materials.size():
			slot_index = clampi(mesh.face_materials[face_index], 0, safe_material_count - 1)
		slot_faces[slot_index].append(face_index)
	for slot_index: int in safe_material_count:
		var selected_faces: PackedInt32Array = slot_faces[slot_index]
		if selected_faces.is_empty():
			continue
		var triangle_count: int = 0
		for face_index: int in selected_faces:
			triangle_count += maxi(mesh.faces[face_index].size() - 2, 0)
		if triangle_count == 0:
			continue
		var direct: bool = not mesh.has_uv_map and not mesh.has_custom_normals
		if direct:
			for face_index: int in selected_faces:
				if face_index >= mesh.smooth_faces.size() or mesh.smooth_faces[face_index] == 0:
					direct = false
					break
		if direct:
			result.append({
				"direct": true,
				"render_vertex_count": mesh.vertices.size(),
				"render_to_model": PackedInt32Array(),
				"offsets": PackedInt32Array(),
				"occurrences": PackedInt32Array(),
			})
			continue
		var render_to_model: PackedInt32Array = PackedInt32Array()
		render_to_model.resize(triangle_count * 3)
		var write_index: int = 0
		for face_index: int in selected_faces:
			var face: PackedInt32Array = mesh.faces[face_index]
			for triangle_index: int in range(1, face.size() - 1):
				render_to_model[write_index] = face[0]
				render_to_model[write_index + 1] = face[triangle_index + 1]
				render_to_model[write_index + 2] = face[triangle_index]
				write_index += 3
		var counts: PackedInt32Array = PackedInt32Array()
		counts.resize(mesh.vertices.size())
		for model_vertex: int in render_to_model:
			if model_vertex >= 0 and model_vertex < counts.size():
				counts[model_vertex] += 1
		var offsets: PackedInt32Array = PackedInt32Array()
		offsets.resize(mesh.vertices.size() + 1)
		for vertex_index: int in mesh.vertices.size():
			offsets[vertex_index + 1] = offsets[vertex_index] + counts[vertex_index]
		var occurrences: PackedInt32Array = PackedInt32Array()
		occurrences.resize(render_to_model.size())
		var cursors: PackedInt32Array = PackedInt32Array()
		cursors.resize(mesh.vertices.size())
		for vertex_index: int in mesh.vertices.size():
			cursors[vertex_index] = offsets[vertex_index]
		for render_index: int in render_to_model.size():
			var model_vertex: int = render_to_model[render_index]
			if model_vertex < 0 or model_vertex >= mesh.vertices.size():
				continue
			var occurrence_index: int = cursors[model_vertex]
			occurrences[occurrence_index] = render_index
			cursors[model_vertex] += 1
		result.append({
			"direct": false,
			"render_vertex_count": render_to_model.size(),
			"render_to_model": render_to_model,
			"offsets": offsets,
			"occurrences": occurrences,
		})
	return result


static func update_array_mesh_vertex_positions_mapped(
	array_mesh: ArrayMesh,
	source_vertices: PackedVector3Array,
	vertex_indices: PackedInt32Array,
	surface_maps: Array
) -> bool:
	if (
		array_mesh == null
		or vertex_indices.is_empty()
		or surface_maps.size() != array_mesh.get_surface_count()
	):
		return false
	var sorted_indices: PackedInt32Array = vertex_indices.duplicate()
	sorted_indices.sort()
	for surface_index: int in array_mesh.get_surface_count():
		var surface_map: Dictionary = surface_maps[surface_index]
		var render_vertex_count: int = int(surface_map.get("render_vertex_count", -1))
		if render_vertex_count != array_mesh.surface_get_array_len(surface_index):
			return false
		if bool(surface_map.get("direct", false)):
			if sorted_indices.size() * 10 >= source_vertices.size():
				array_mesh.surface_update_vertex_region(
					surface_index, 0, source_vertices.to_byte_array()
				)
				continue
			_update_direct_vertex_runs(
				array_mesh, surface_index, source_vertices, sorted_indices
			)
			continue
		var render_to_model: PackedInt32Array = surface_map.get(
			"render_to_model", PackedInt32Array()
		)
		var offsets: PackedInt32Array = surface_map.get("offsets", PackedInt32Array())
		var occurrences: PackedInt32Array = surface_map.get(
			"occurrences", PackedInt32Array()
		)
		if (
			render_to_model.size() != render_vertex_count
			or offsets.size() != source_vertices.size() + 1
			or occurrences.size() != render_vertex_count
		):
			return false
		var changed_render_indices: PackedInt32Array = PackedInt32Array()
		for model_vertex: int in sorted_indices:
			if model_vertex < 0 or model_vertex >= source_vertices.size():
				continue
			for occurrence_index: int in range(offsets[model_vertex], offsets[model_vertex + 1]):
				changed_render_indices.append(occurrences[occurrence_index])
		if changed_render_indices.is_empty():
			continue
		if changed_render_indices.size() * 10 >= render_vertex_count:
			var full_positions: PackedVector3Array = PackedVector3Array()
			full_positions.resize(render_vertex_count)
			for render_index: int in render_vertex_count:
				full_positions[render_index] = source_vertices[render_to_model[render_index]]
			array_mesh.surface_update_vertex_region(
				surface_index, 0, full_positions.to_byte_array()
			)
			continue
		changed_render_indices.sort()
		var cursor: int = 0
		while cursor < changed_render_indices.size():
			var run_start: int = cursor
			var first_render_vertex: int = changed_render_indices[cursor]
			cursor += 1
			while (
				cursor < changed_render_indices.size()
				and changed_render_indices[cursor] == changed_render_indices[cursor - 1] + 1
			):
				cursor += 1
			var run_size: int = cursor - run_start
			var run_positions: PackedVector3Array = PackedVector3Array()
			run_positions.resize(run_size)
			for run_index: int in run_size:
				var render_index: int = changed_render_indices[run_start + run_index]
				run_positions[run_index] = source_vertices[render_to_model[render_index]]
			array_mesh.surface_update_vertex_region(
				surface_index,
				first_render_vertex * 12,
				run_positions.to_byte_array()
			)
	return true


static func update_array_mesh_all_vertex_positions_mapped(
	array_mesh: ArrayMesh,
	source_vertices: PackedVector3Array,
	surface_maps: Array
) -> bool:
	if array_mesh == null or surface_maps.size() != array_mesh.get_surface_count():
		return false
	for surface_index: int in array_mesh.get_surface_count():
		var surface_map: Dictionary = surface_maps[surface_index]
		var render_vertex_count: int = int(surface_map.get("render_vertex_count", -1))
		if render_vertex_count != array_mesh.surface_get_array_len(surface_index):
			return false
		if bool(surface_map.get("direct", false)):
			if render_vertex_count != source_vertices.size():
				return false
			array_mesh.surface_update_vertex_region(
				surface_index, 0, source_vertices.to_byte_array()
			)
			continue
		var render_to_model: PackedInt32Array = surface_map.get(
			"render_to_model", PackedInt32Array()
		)
		if render_to_model.size() != render_vertex_count:
			return false
		var full_positions: PackedVector3Array = PackedVector3Array()
		full_positions.resize(render_vertex_count)
		for render_index: int in render_vertex_count:
			var model_vertex: int = render_to_model[render_index]
			if model_vertex < 0 or model_vertex >= source_vertices.size():
				return false
			full_positions[render_index] = source_vertices[model_vertex]
		array_mesh.surface_update_vertex_region(
			surface_index, 0, full_positions.to_byte_array()
		)
	return true


static func _update_direct_vertex_runs(
	array_mesh: ArrayMesh,
	surface_index: int,
	source_vertices: PackedVector3Array,
	sorted_indices: PackedInt32Array
) -> void:
	var cursor: int = 0
	while cursor < sorted_indices.size():
		var run_start: int = cursor
		var first_vertex: int = sorted_indices[cursor]
		cursor += 1
		while cursor < sorted_indices.size() and sorted_indices[cursor] == sorted_indices[cursor - 1] + 1:
			cursor += 1
		var run_size: int = cursor - run_start
		var run_positions: PackedVector3Array = PackedVector3Array()
		run_positions.resize(run_size)
		for run_index: int in run_size:
			run_positions[run_index] = source_vertices[sorted_indices[run_start + run_index]]
		array_mesh.surface_update_vertex_region(
			surface_index, first_vertex * 12, run_positions.to_byte_array()
		)


func to_array_mesh(
	material_slots: Array[StandardMaterial3D] = [],
	validate_geometry: bool = true,
	rig_data: GMSRigData = null
) -> ArrayMesh:
	var output: ArrayMesh = ArrayMesh.new()
	_normalize_smooth_flags()
	_normalize_uv_layout()
	_normalize_normal_layout()
	_normalize_face_materials()
	if vertices.is_empty() or faces.is_empty():
		return output
	if validate_geometry and not is_valid():
		return output

	var vertex_normals: PackedVector3Array = PackedVector3Array()
	if _needs_smooth_vertex_normals():
		vertex_normals = _build_smooth_vertex_normals()
	var material_count: int = maxi(material_slots.size(), 1)
	var slot_faces: Array[PackedInt32Array] = []
	slot_faces.resize(material_count)
	for slot_index: int in material_count:
		slot_faces[slot_index] = PackedInt32Array()
	for face_index: int in faces.size():
		var slot_index: int = clampi(face_materials[face_index], 0, material_count - 1)
		slot_faces[slot_index].append(face_index)

	for slot_index: int in material_count:
		var selected_faces: PackedInt32Array = slot_faces[slot_index]
		if selected_faces.is_empty():
			continue
		var triangle_count: int = 0
		for face_index: int in selected_faces:
			triangle_count += maxi(faces[face_index].size() - 2, 0)
		if triangle_count == 0:
			continue
		var can_use_indexed_smooth: bool = not has_uv_map and not has_custom_normals
		if can_use_indexed_smooth:
			for face_index: int in selected_faces:
				if smooth_faces[face_index] == 0:
					can_use_indexed_smooth = false
					break
		if can_use_indexed_smooth:
			var render_indices: PackedInt32Array = PackedInt32Array()
			render_indices.resize(triangle_count * 3)
			var index_write: int = 0
			for face_index: int in selected_faces:
				var face: PackedInt32Array = faces[face_index]
				for triangle_index: int in range(1, face.size() - 1):
					render_indices[index_write] = face[0]
					render_indices[index_write + 1] = face[triangle_index + 1]
					render_indices[index_write + 2] = face[triangle_index]
					index_write += 3
			var indexed_arrays: Array = []
			indexed_arrays.resize(Mesh.ARRAY_MAX)
			indexed_arrays[Mesh.ARRAY_VERTEX] = vertices
			indexed_arrays[Mesh.ARRAY_NORMAL] = vertex_normals
			if rig_data != null and rig_data.is_compatible(vertices.size()):
				indexed_arrays[Mesh.ARRAY_BONES] = rig_data.vertex_bones
				indexed_arrays[Mesh.ARRAY_WEIGHTS] = rig_data.vertex_weights
			indexed_arrays[Mesh.ARRAY_INDEX] = render_indices
			output.add_surface_from_arrays(
				Mesh.PRIMITIVE_TRIANGLES, indexed_arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
			)
			var indexed_surface: int = output.get_surface_count() - 1
			if indexed_surface >= 0 and slot_index < material_slots.size():
				output.surface_set_material(indexed_surface, material_slots[slot_index])
			continue
		var render_vertex_count: int = triangle_count * 3
		var render_vertices: PackedVector3Array = PackedVector3Array()
		var render_normals: PackedVector3Array = PackedVector3Array()
		var render_uvs: PackedVector2Array = PackedVector2Array()
		var render_bones: PackedInt32Array = PackedInt32Array()
		var render_weights: PackedFloat32Array = PackedFloat32Array()
		var has_compatible_rig: bool = rig_data != null and rig_data.is_compatible(vertices.size())
		render_vertices.resize(render_vertex_count)
		render_normals.resize(render_vertex_count)
		if has_uv_map:
			render_uvs.resize(render_vertex_count)
		if has_compatible_rig:
			render_bones.resize(render_vertex_count * GMSRigData.MAX_INFLUENCES)
			render_weights.resize(render_vertex_count * GMSRigData.MAX_INFLUENCES)
		var write_index: int = 0
		for face_index: int in selected_faces:
			var face: PackedInt32Array = faces[face_index]
			var face_uvs: PackedVector2Array = uv_faces[face_index]
			var is_smooth: bool = smooth_faces[face_index] != 0
			var face_normal: Vector3 = Vector3.UP
			if not is_smooth or has_custom_normals:
				face_normal = get_face_normal(face_index)
			for triangle_index: int in range(1, face.size() - 1):
				for corner_pass: int in 3:
					var corner_index: int = 0
					if corner_pass == 1:
						corner_index = triangle_index + 1
					elif corner_pass == 2:
						corner_index = triangle_index
					var model_vertex_index: int = face[corner_index]
					render_vertices[write_index] = vertices[model_vertex_index]
					render_normals[write_index] = _get_corner_render_normal(
						face_index,
						corner_index,
						face_normal,
						is_smooth,
						vertex_normals
					)
					if has_uv_map:
						render_uvs[write_index] = face_uvs[corner_index]
					if has_compatible_rig:
						var source_weight_offset: int = model_vertex_index * GMSRigData.MAX_INFLUENCES
						var render_weight_offset: int = write_index * GMSRigData.MAX_INFLUENCES
						for influence_slot: int in GMSRigData.MAX_INFLUENCES:
							render_bones[render_weight_offset + influence_slot] = rig_data.vertex_bones[source_weight_offset + influence_slot]
							render_weights[render_weight_offset + influence_slot] = rig_data.vertex_weights[source_weight_offset + influence_slot]
					write_index += 1
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = render_vertices
		arrays[Mesh.ARRAY_NORMAL] = render_normals
		if has_uv_map:
			arrays[Mesh.ARRAY_TEX_UV] = render_uvs
		if has_compatible_rig:
			arrays[Mesh.ARRAY_BONES] = render_bones
			arrays[Mesh.ARRAY_WEIGHTS] = render_weights
		output.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
		)
		var surface_index: int = output.get_surface_count() - 1
		if surface_index >= 0 and slot_index < material_slots.size():
			output.surface_set_material(surface_index, material_slots[slot_index])

	return output


static func build_indexed_smooth_surface_arrays(
	source_vertices: PackedVector3Array,
	source_faces: Array[PackedInt32Array],
	source_face_materials: PackedInt32Array,
	material_count: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source_vertices.is_empty() or source_faces.is_empty():
		return result
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(source_vertices.size())
	var safe_material_count: int = maxi(material_count, 1)
	var triangle_counts: PackedInt32Array = PackedInt32Array()
	triangle_counts.resize(safe_material_count)
	for face_index: int in source_faces.size():
		var face: PackedInt32Array = source_faces[face_index]
		if face.size() < 3:
			continue
		var normal: Vector3 = Vector3.ZERO
		for corner_index: int in face.size():
			var current: Vector3 = source_vertices[face[corner_index]]
			var next: Vector3 = source_vertices[face[(corner_index + 1) % face.size()]]
			normal.x += (current.y - next.y) * (current.z + next.z)
			normal.y += (current.z - next.z) * (current.x + next.x)
			normal.z += (current.x - next.x) * (current.y + next.y)
		if normal.is_zero_approx():
			normal = Vector3.UP
		else:
			normal = normal.normalized()
		for vertex_index: int in face:
			normals[vertex_index] += normal
		var slot_index: int = 0
		if face_index < source_face_materials.size():
			slot_index = clampi(source_face_materials[face_index], 0, safe_material_count - 1)
		triangle_counts[slot_index] += face.size() - 2
	for vertex_index: int in normals.size():
		if normals[vertex_index].is_zero_approx():
			normals[vertex_index] = Vector3.UP
		else:
			normals[vertex_index] = normals[vertex_index].normalized()
	var slot_indices: Array[PackedInt32Array] = []
	slot_indices.resize(safe_material_count)
	var write_indices: PackedInt32Array = PackedInt32Array()
	write_indices.resize(safe_material_count)
	for slot_index: int in safe_material_count:
		var indices: PackedInt32Array = PackedInt32Array()
		indices.resize(triangle_counts[slot_index] * 3)
		slot_indices[slot_index] = indices
	for face_index: int in source_faces.size():
		var face: PackedInt32Array = source_faces[face_index]
		if face.size() < 3:
			continue
		var slot_index: int = 0
		if face_index < source_face_materials.size():
			slot_index = clampi(source_face_materials[face_index], 0, safe_material_count - 1)
		var indices: PackedInt32Array = slot_indices[slot_index]
		var write_index: int = write_indices[slot_index]
		for triangle_index: int in range(1, face.size() - 1):
			indices[write_index] = face[0]
			indices[write_index + 1] = face[triangle_index + 1]
			indices[write_index + 2] = face[triangle_index]
			write_index += 3
		slot_indices[slot_index] = indices
		write_indices[slot_index] = write_index
	for slot_index: int in safe_material_count:
		if slot_indices[slot_index].is_empty():
			continue
		result.append({
			"slot": slot_index,
			"vertices": source_vertices,
			"normals": normals,
			"indices": slot_indices[slot_index],
		})
	return result


func _needs_smooth_vertex_normals() -> bool:
	for face_index: int in faces.size():
		if smooth_faces[face_index] == 0:
			continue
		if not _has_complete_custom_normals(face_index):
			return true
	return false


func _has_complete_custom_normals(face_index: int) -> bool:
	if not has_custom_normals or face_index < 0 or face_index >= corner_normals.size():
		return false
	if corner_normals[face_index].size() != faces[face_index].size():
		return false
	for normal: Vector3 in corner_normals[face_index]:
		if normal.is_zero_approx():
			return false
	return true


func _get_corner_render_normal(
	face_index: int,
	corner_index: int,
	face_normal: Vector3,
	is_smooth: bool,
	vertex_normals: PackedVector3Array
) -> Vector3:
	if has_custom_normals:
		var custom: Vector3 = corner_normals[face_index][corner_index]
		if not custom.is_zero_approx():
			return custom.normalized()
	if is_smooth:
		return vertex_normals[faces[face_index][corner_index]]
	return face_normal


func _add_render_vertex(
	surface_tool: SurfaceTool,
	vertex_index: int,
	uv: Vector2,
	normal: Vector3
) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_uv(uv)
	surface_tool.add_vertex(vertices[vertex_index])


func _build_smooth_vertex_normals() -> PackedVector3Array:
	var accumulated: PackedVector3Array = PackedVector3Array()
	accumulated.resize(vertices.size())

	for face_index: int in faces.size():
		if smooth_faces[face_index] == 0:
			continue
		var normal: Vector3 = get_face_normal(face_index)
		for vertex_index: int in faces[face_index]:
			accumulated[vertex_index] += normal

	for vertex_index: int in accumulated.size():
		if accumulated[vertex_index].is_zero_approx():
			accumulated[vertex_index] = Vector3.UP
		else:
			accumulated[vertex_index] = accumulated[vertex_index].normalized()

	return accumulated


func _normalize_smooth_flags() -> void:
	if smooth_faces.size() == faces.size():
		return

	var normalized: PackedByteArray = PackedByteArray()
	normalized.resize(faces.size())
	for face_index: int in mini(smooth_faces.size(), faces.size()):
		normalized[face_index] = smooth_faces[face_index]
	smooth_faces = normalized


func _normalize_uv_layout() -> void:
	if uv_faces.size() == faces.size():
		var layout_valid: bool = true
		for face_index: int in faces.size():
			if uv_faces[face_index].size() != faces[face_index].size():
				layout_valid = false
				break
		if layout_valid:
			return
	var normalized: Array[PackedVector2Array] = []
	for face_index: int in faces.size():
		var face_uvs: PackedVector2Array = PackedVector2Array()
		face_uvs.resize(faces[face_index].size())
		if face_index < uv_faces.size() and uv_faces[face_index].size() == faces[face_index].size():
			face_uvs = uv_faces[face_index].duplicate()
		normalized.append(face_uvs)
	uv_faces = normalized


func _normalize_normal_layout() -> void:
	if corner_normals.size() == faces.size():
		var layout_valid: bool = true
		for face_index: int in faces.size():
			if corner_normals[face_index].size() != faces[face_index].size():
				layout_valid = false
				break
		if layout_valid:
			return
	var normalized: Array[PackedVector3Array] = []
	for face_index: int in faces.size():
		var values: PackedVector3Array = PackedVector3Array()
		values.resize(faces[face_index].size())
		if (
			face_index < corner_normals.size()
			and corner_normals[face_index].size() == faces[face_index].size()
		):
			values = corner_normals[face_index].duplicate()
		normalized.append(values)
	corner_normals = normalized


func _normalize_loose_edges() -> void:
	if loose_edges.is_empty():
		return
	var normalized: Array[Vector2i] = []
	var known: Dictionary = {}
	var face_edges: Dictionary = {}
	for edge: Vector2i in get_face_edges():
		face_edges[edge] = true
	for source_edge: Vector2i in loose_edges:
		var edge: Vector2i = canonical_edge(source_edge.x, source_edge.y)
		if (
			edge.x < 0 or edge.y < 0
			or edge.x >= vertices.size() or edge.y >= vertices.size()
			or edge.x == edge.y
			or known.has(edge)
			or face_edges.has(edge)
		):
			continue
		known[edge] = true
		normalized.append(edge)
	loose_edges = normalized


func _normalize_creases() -> void:
	if crease_edges.is_empty():
		crease_weights.clear()
		return
	var normalized_edges: Array[Vector2i] = []
	var normalized_weights: PackedFloat32Array = PackedFloat32Array()
	var known: Dictionary = {}
	var valid_edges: Dictionary = {}
	for edge: Vector2i in get_edges():
		valid_edges[edge] = true
	for index: int in crease_edges.size():
		if index >= crease_weights.size():
			break
		var edge: Vector2i = canonical_edge(crease_edges[index].x, crease_edges[index].y)
		var weight: float = clampf(crease_weights[index], 0.0, 1.0)
		if weight <= 0.000001 or known.has(edge) or not valid_edges.has(edge):
			continue
		known[edge] = true
		normalized_edges.append(edge)
		normalized_weights.append(weight)
	crease_edges = normalized_edges
	crease_weights = normalized_weights


func _normalize_seams() -> void:
	if seam_edges.is_empty():
		return
	var normalized: Array[Vector2i] = []
	var known: Dictionary = {}
	var valid_edges: Dictionary = {}
	for edge: Vector2i in get_face_edges():
		valid_edges[edge] = true
	for source_edge: Vector2i in seam_edges:
		var edge: Vector2i = canonical_edge(source_edge.x, source_edge.y)
		if known.has(edge) or not valid_edges.has(edge):
			continue
		known[edge] = true
		normalized.append(edge)
	seam_edges = normalized


func _normalize_face_materials() -> void:
	if face_materials.size() == faces.size():
		for face_index: int in face_materials.size():
			face_materials[face_index] = maxi(face_materials[face_index], 0)
		return
	var normalized: PackedInt32Array = PackedInt32Array()
	normalized.resize(faces.size())
	for face_index: int in mini(face_materials.size(), faces.size()):
		normalized[face_index] = maxi(face_materials[face_index], 0)
	face_materials = normalized


static func _remap_or_copy_face_materials(
	old_faces: Array[PackedInt32Array],
	old_materials: PackedInt32Array,
	new_faces: Array[PackedInt32Array],
	explicit_materials: PackedInt32Array
) -> PackedInt32Array:
	if explicit_materials.size() == new_faces.size():
		return explicit_materials.duplicate()

	var result: PackedInt32Array = PackedInt32Array()
	result.resize(new_faces.size())
	if old_materials.is_empty() or old_faces.is_empty():
		return result

	var old_lookup: Dictionary = {}
	for old_index: int in mini(old_faces.size(), old_materials.size()):
		old_lookup[_face_vertex_key(old_faces[old_index])] = maxi(old_materials[old_index], 0)
	for new_index: int in new_faces.size():
		var key: String = _face_vertex_key(new_faces[new_index])
		if old_lookup.has(key):
			result[new_index] = int(old_lookup[key])
	return result


static func _face_vertex_key(face: PackedInt32Array) -> String:
	var values: Array[int] = []
	for vertex_index: int in face:
		values.append(vertex_index)
	values.sort()
	var parts: PackedStringArray = PackedStringArray()
	for value: int in values:
		parts.append(str(value))
	return ",".join(parts)


static func canonical_edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _duplicate_faces(source: Array[PackedInt32Array]) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for face: PackedInt32Array in source:
		result.append(face.duplicate())
	return result


static func _duplicate_uv_faces(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for face_uvs: PackedVector2Array in source:
		result.append(face_uvs.duplicate())
	return result


static func _duplicate_normal_faces(source: Array[PackedVector3Array]) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	for face_normals: PackedVector3Array in source:
		result.append(face_normals.duplicate())
	return result
