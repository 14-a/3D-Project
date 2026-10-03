@tool
class_name GMSMeshOperations
extends RefCounted


static func translate_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	offset: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			result.vertices[vertex_index] += offset
	return result


static func scale_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	pivot: Vector3,
	scale: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			var relative: Vector3 = result.vertices[vertex_index] - pivot
			result.vertices[vertex_index] = pivot + relative * scale
	return result


static func translate_vertices_world(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	object_transform: Transform3D,
	offset_world: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			var world_position: Vector3 = object_transform * result.vertices[vertex_index]
			result.vertices[vertex_index] = inverse * (world_position + offset_world)
	return result


static func rotate_vertices_world(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	object_transform: Transform3D,
	pivot_world: Vector3,
	axis_world: Vector3,
	angle_radians: float
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if axis_world.is_zero_approx() or is_zero_approx(angle_radians):
		return result
	var inverse: Transform3D = object_transform.affine_inverse()
	var rotation: Basis = Basis(axis_world.normalized(), angle_radians)
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			var world_position: Vector3 = object_transform * result.vertices[vertex_index]
			world_position = pivot_world + rotation * (world_position - pivot_world)
			result.vertices[vertex_index] = inverse * world_position
	return result


static func scale_vertices_world(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	object_transform: Transform3D,
	pivot_world: Vector3,
	scale_world: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			var world_position: Vector3 = object_transform * result.vertices[vertex_index]
			world_position = pivot_world + (world_position - pivot_world) * scale_world
			result.vertices[vertex_index] = inverse * world_position
	return result




static func scale_vertices_world_axis(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	object_transform: Transform3D,
	pivot_world: Vector3,
	axis_world: Vector3,
	factor: float
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if axis_world.is_zero_approx():
		return result

	var axis: Vector3 = axis_world.normalized()
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in vertex_indices:
		if vertex_index < 0 or vertex_index >= result.vertices.size():
			continue
		var world_position: Vector3 = object_transform * result.vertices[vertex_index]
		var relative: Vector3 = world_position - pivot_world
		relative += axis * relative.dot(axis) * (factor - 1.0)
		result.vertices[vertex_index] = inverse * (pivot_world + relative)
	return result


static func rotate_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	pivot: Vector3,
	axis: Vector3,
	angle_radians: float
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if axis.is_zero_approx() or is_zero_approx(angle_radians):
		return result

	var rotation: Basis = Basis(axis.normalized(), angle_radians)
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < result.vertices.size():
			var relative: Vector3 = result.vertices[vertex_index] - pivot
			result.vertices[vertex_index] = pivot + rotation * relative
	return result


static func extrude_face(
	mesh: GMSMeshData,
	face_index: int,
	distance: float
) -> GMSMeshData:
	if face_index < 0 or face_index >= mesh.faces.size():
		return mesh.duplicate_mesh_data()

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var source_face: PackedInt32Array = result.faces[face_index].duplicate()
	if source_face.size() < 3:
		return result

	var source_uvs: PackedVector2Array = PackedVector2Array()
	if result.has_uv_map:
		source_uvs = result.uv_faces[face_index].duplicate()

	var normal: Vector3 = result.get_face_normal(face_index)
	var source_material_index: int = result.get_face_material(face_index)
	var extruded_face: PackedInt32Array = PackedInt32Array()

	for source_vertex_index: int in source_face:
		var new_vertex_index: int = result.vertices.size()
		result.vertices.append(result.vertices[source_vertex_index] + normal * distance)
		extruded_face.append(new_vertex_index)

	result.faces[face_index] = extruded_face
	result.smooth_faces[face_index] = 0
	if result.has_uv_map:
		result.uv_faces[face_index] = source_uvs

	var new_side_faces: PackedInt32Array = PackedInt32Array()
	for corner_index: int in source_face.size():
		var next_corner: int = (corner_index + 1) % source_face.size()
		new_side_faces.append(result.faces.size())
		result.faces.append(PackedInt32Array([
			source_face[corner_index],
			source_face[next_corner],
			extruded_face[next_corner],
			extruded_face[corner_index],
		]))
		result.face_materials.append(source_material_index)
		result.smooth_faces.append(0)
		var blank_uv: PackedVector2Array = PackedVector2Array()
		blank_uv.resize(4)
		result.uv_faces.append(blank_uv)

	result.invalidate_custom_normals()
	if result.has_uv_map:
		result = GMSUVOperations.project_box(result, new_side_faces)
	else:
		result.invalidate_uvs()
	return result


static func inset_face(
	mesh: GMSMeshData,
	face_index: int,
	amount: float
) -> GMSMeshData:
	if face_index < 0 or face_index >= mesh.faces.size():
		return mesh.duplicate_mesh_data()

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var source_face: PackedInt32Array = result.faces[face_index].duplicate()
	if source_face.size() < 3:
		return result

	var inset_factor: float = clampf(amount, 0.0, 0.95)
	var source_material_index: int = result.get_face_material(face_index)
	var center: Vector3 = result.get_face_center(face_index)
	var inset_face_indices: PackedInt32Array = PackedInt32Array()

	for source_vertex_index: int in source_face:
		var new_vertex_index: int = result.vertices.size()
		var source_position: Vector3 = result.vertices[source_vertex_index]
		result.vertices.append(source_position.lerp(center, inset_factor))
		inset_face_indices.append(new_vertex_index)

	result.faces[face_index] = inset_face_indices
	result.smooth_faces[face_index] = 0

	for corner_index: int in source_face.size():
		var next_corner: int = (corner_index + 1) % source_face.size()
		result.faces.append(PackedInt32Array([
			source_face[corner_index],
			source_face[next_corner],
			inset_face_indices[next_corner],
			inset_face_indices[corner_index],
		]))
		result.face_materials.append(source_material_index)
		result.smooth_faces.append(0)

	result.invalidate_uvs()
	return result


static func extrude_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array,
	distance: float
) -> GMSMeshData:
	var valid_faces: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	if valid_faces.is_empty():
		return mesh.duplicate_mesh_data()
	if valid_faces.size() == 1:
		return extrude_face(mesh, valid_faces[0], distance)

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var selected_vertices: PackedInt32Array = PackedInt32Array()
	var region_normal: Vector3 = Vector3.ZERO
	var edge_counts: Dictionary = {}
	var edge_directions: Dictionary = {}
	var edge_materials: Dictionary = {}

	for face_index: int in valid_faces:
		var face: PackedInt32Array = result.faces[face_index]
		region_normal += result.get_face_normal(face_index)
		for vertex_index: int in face:
			if not selected_vertices.has(vertex_index):
				selected_vertices.append(vertex_index)
		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
			if not edge_directions.has(key):
				edge_directions[key] = Vector2i(a, b)
				edge_materials[key] = result.get_face_material(face_index)

	if region_normal.is_zero_approx():
		region_normal = result.get_face_normal(valid_faces[0])
	else:
		region_normal = region_normal.normalized()

	var duplicate_map: Dictionary = {}
	for vertex_index: int in selected_vertices:
		var duplicate_index: int = result.vertices.size()
		duplicate_map[vertex_index] = duplicate_index
		result.vertices.append(result.vertices[vertex_index] + region_normal * distance)

	for face_index: int in valid_faces:
		var cap: PackedInt32Array = PackedInt32Array()
		for vertex_index: int in result.faces[face_index]:
			cap.append(int(duplicate_map[vertex_index]))
		result.faces[face_index] = cap

	var new_side_faces: PackedInt32Array = PackedInt32Array()
	for edge_key_value: Variant in edge_counts.keys():
		var edge_key: Vector2i = edge_key_value
		if int(edge_counts[edge_key]) != 1:
			continue
		var edge: Vector2i = edge_directions[edge_key]
		new_side_faces.append(result.faces.size())
		result.faces.append(PackedInt32Array([
			edge.x,
			edge.y,
			int(duplicate_map[edge.y]),
			int(duplicate_map[edge.x]),
		]))
		result.face_materials.append(int(edge_materials.get(edge_key, 0)))
		result.smooth_faces.append(0)
		var blank_uv: PackedVector2Array = PackedVector2Array()
		blank_uv.resize(4)
		result.uv_faces.append(blank_uv)

	result.invalidate_custom_normals()
	if result.has_uv_map:
		result = GMSUVOperations.project_box(result, new_side_faces)
	else:
		result.invalidate_uvs()
	return result


static func make_face(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> GMSMeshData:
	var valid_vertices: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if valid_vertices.size() < 3:
		return result

	var origin: Vector3 = result.vertices[valid_vertices[0]]
	var face_normal: Vector3 = Vector3.ZERO
	for index: int in range(1, valid_vertices.size() - 1):
		var a: Vector3 = result.vertices[valid_vertices[index]] - origin
		var b: Vector3 = result.vertices[valid_vertices[index + 1]] - origin
		var candidate: Vector3 = a.cross(b)
		if candidate.length_squared() > 0.0000001:
			face_normal = candidate.normalized()
			break
	if face_normal.is_zero_approx():
		return result

	var tolerance: float = maxf(0.0001, result.get_aabb().size.length() * 0.0001)
	for vertex_index: int in valid_vertices:
		if absf((result.vertices[vertex_index] - origin).dot(face_normal)) > tolerance:
			return result

	for existing_face: PackedInt32Array in result.faces:
		if existing_face.size() != valid_vertices.size():
			continue
		var same_vertices: bool = true
		for vertex_index: int in valid_vertices:
			if not existing_face.has(vertex_index):
				same_vertices = false
				break
		if same_vertices:
			return result

	result.faces.append(valid_vertices.duplicate())
	result.face_materials.append(0)
	result.smooth_faces.append(0)
	result.invalidate_uvs()
	return result


static func merge_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> GMSMeshData:
	var selected: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if selected.size() < 2:
		return result
	selected.sort()

	var center: Vector3 = Vector3.ZERO
	for vertex_index: int in selected:
		center += result.vertices[vertex_index]
	center /= float(selected.size())

	var keep_index: int = selected[0]
	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(result.vertices.size())
	mapping.fill(-1)
	var rebuilt_vertices: PackedVector3Array = PackedVector3Array()
	var keep_new_index: int = -1

	for old_index: int in result.vertices.size():
		if old_index == keep_index:
			keep_new_index = rebuilt_vertices.size()
			mapping[old_index] = keep_new_index
			rebuilt_vertices.append(center)
		elif selected.has(old_index):
			continue
		else:
			mapping[old_index] = rebuilt_vertices.size()
			rebuilt_vertices.append(result.vertices[old_index])

	for removed_index: int in selected:
		mapping[removed_index] = keep_new_index

	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in result.faces.size():
		var remapped: PackedInt32Array = _remap_face(result.faces[face_index], mapping)
		if remapped.size() < 3:
			continue
		rebuilt_faces.append(remapped)
		rebuilt_smooth.append(result.smooth_faces[face_index])
		rebuilt_materials.append(result.get_face_material(face_index))

	var rebuilt_loose: Array[Vector2i] = []
	for edge: Vector2i in result.loose_edges:
		var remapped_edge: Vector2i = GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y])
		if remapped_edge.x >= 0 and remapped_edge.x != remapped_edge.y and not rebuilt_loose.has(remapped_edge):
			rebuilt_loose.append(remapped_edge)
	var rebuilt_creases: Array[Vector2i] = []
	var rebuilt_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in result.crease_edges.size():
		var edge: Vector2i = result.crease_edges[crease_index]
		var remapped_edge: Vector2i = GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y])
		if remapped_edge.x < 0 or remapped_edge.x == remapped_edge.y or rebuilt_creases.has(remapped_edge):
			continue
		rebuilt_creases.append(remapped_edge)
		rebuilt_crease_weights.append(result.crease_weights[crease_index])
	var rebuilt_seams: Array[Vector2i] = []
	for edge: Vector2i in result.seam_edges:
		var remapped_edge: Vector2i = GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y])
		if remapped_edge.x >= 0 and remapped_edge.x != remapped_edge.y and not rebuilt_seams.has(remapped_edge):
			rebuilt_seams.append(remapped_edge)

	result.set_geometry(
		rebuilt_vertices,
		rebuilt_faces,
		rebuilt_smooth,
		[],
		false,
		[],
		false,
		rebuilt_loose,
		rebuilt_creases,
		rebuilt_crease_weights,
		rebuilt_seams,
		rebuilt_materials
	)
	return result

static func delete_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> GMSMeshData:
	var selected: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if selected.is_empty():
		return result

	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(result.vertices.size())
	mapping.fill(-1)
	var rebuilt_vertices: PackedVector3Array = PackedVector3Array()
	for old_index: int in result.vertices.size():
		if selected.has(old_index):
			continue
		mapping[old_index] = rebuilt_vertices.size()
		rebuilt_vertices.append(result.vertices[old_index])

	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_uvs: Array[PackedVector2Array] = []
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in result.faces.size():
		var face: PackedInt32Array = result.faces[face_index]
		var touches_deleted_vertex: bool = false
		for vertex_index: int in face:
			if selected.has(vertex_index):
				touches_deleted_vertex = true
				break
		if touches_deleted_vertex:
			continue
		var remapped: PackedInt32Array = _remap_face(face, mapping)
		if remapped.size() < 3:
			continue
		rebuilt_faces.append(remapped)
		rebuilt_smooth.append(result.smooth_faces[face_index])
		rebuilt_uvs.append(result.uv_faces[face_index].duplicate())
		rebuilt_materials.append(result.get_face_material(face_index))

	var rebuilt_loose: Array[Vector2i] = []
	for edge: Vector2i in result.loose_edges:
		if selected.has(edge.x) or selected.has(edge.y):
			continue
		rebuilt_loose.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
	var rebuilt_creases: Array[Vector2i] = []
	var rebuilt_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in result.crease_edges.size():
		var edge: Vector2i = result.crease_edges[crease_index]
		if selected.has(edge.x) or selected.has(edge.y):
			continue
		rebuilt_creases.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
		rebuilt_crease_weights.append(result.crease_weights[crease_index])
	var rebuilt_seams: Array[Vector2i] = []
	for edge: Vector2i in result.seam_edges:
		if selected.has(edge.x) or selected.has(edge.y):
			continue
		var remapped_edge: Vector2i = GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y])
		if not rebuilt_seams.has(remapped_edge):
			rebuilt_seams.append(remapped_edge)

	result.set_geometry(
		rebuilt_vertices,
		rebuilt_faces,
		rebuilt_smooth,
		rebuilt_uvs,
		result.has_uv_map,
		[],
		false,
		rebuilt_loose,
		rebuilt_creases,
		rebuilt_crease_weights,
		rebuilt_seams,
		rebuilt_materials
	)
	return result

static func delete_edges(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var all_edges: Array[Vector2i] = result.get_edges()
	var valid_edges: PackedInt32Array = _unique_valid_indices(edge_indices, all_edges.size())
	if valid_edges.is_empty():
		return result

	var selected_edges: Array[Vector2i] = []
	for edge_index: int in valid_edges:
		selected_edges.append(all_edges[edge_index])

	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_uvs: Array[PackedVector2Array] = []
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in result.faces.size():
		var face: PackedInt32Array = result.faces[face_index]
		var remove_face: bool = false
		for corner_index: int in face.size():
			var edge: Vector2i = GMSMeshData.canonical_edge(
				face[corner_index], face[(corner_index + 1) % face.size()]
			)
			if selected_edges.has(edge):
				remove_face = true
				break
		if remove_face:
			continue
		rebuilt_faces.append(face.duplicate())
		rebuilt_smooth.append(result.smooth_faces[face_index])
		rebuilt_uvs.append(result.uv_faces[face_index].duplicate())
		rebuilt_materials.append(result.get_face_material(face_index))

	var rebuilt_loose: Array[Vector2i] = []
	for edge: Vector2i in result.loose_edges:
		if not selected_edges.has(edge):
			rebuilt_loose.append(edge)
	var rebuilt_creases: Array[Vector2i] = []
	var rebuilt_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in result.crease_edges.size():
		if selected_edges.has(result.crease_edges[crease_index]):
			continue
		rebuilt_creases.append(result.crease_edges[crease_index])
		rebuilt_crease_weights.append(result.crease_weights[crease_index])
	var rebuilt_seams: Array[Vector2i] = []
	for edge: Vector2i in result.seam_edges:
		if not selected_edges.has(edge):
			rebuilt_seams.append(edge)
	result.set_geometry(
		result.vertices,
		rebuilt_faces,
		rebuilt_smooth,
		rebuilt_uvs,
		result.has_uv_map,
		[],
		false,
		rebuilt_loose,
		rebuilt_creases,
		rebuilt_crease_weights,
		rebuilt_seams,
		rebuilt_materials
	)
	return result

static func delete_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, result.faces.size())
	if selected.is_empty():
		return result

	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_uvs: Array[PackedVector2Array] = []
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in result.faces.size():
		if selected.has(face_index):
			continue
		rebuilt_faces.append(result.faces[face_index].duplicate())
		rebuilt_smooth.append(result.smooth_faces[face_index])
		rebuilt_uvs.append(result.uv_faces[face_index].duplicate())
		rebuilt_materials.append(result.get_face_material(face_index))
	result.set_geometry(
		result.vertices,
		rebuilt_faces,
		rebuilt_smooth,
		rebuilt_uvs,
		result.has_uv_map,
		[],
		false,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		rebuilt_materials
	)
	return result

static func remove_unused_vertices(mesh: GMSMeshData) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var used: PackedInt32Array = PackedInt32Array()
	for face: PackedInt32Array in result.faces:
		for vertex_index: int in face:
			if not used.has(vertex_index):
				used.append(vertex_index)
	for edge: Vector2i in result.loose_edges:
		if not used.has(edge.x):
			used.append(edge.x)
		if not used.has(edge.y):
			used.append(edge.y)
	used.sort()

	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(result.vertices.size())
	mapping.fill(-1)
	var rebuilt_vertices: PackedVector3Array = PackedVector3Array()
	for old_index: int in result.vertices.size():
		if not used.has(old_index):
			continue
		mapping[old_index] = rebuilt_vertices.size()
		rebuilt_vertices.append(result.vertices[old_index])

	var rebuilt_faces: Array[PackedInt32Array] = []
	for face: PackedInt32Array in result.faces:
		rebuilt_faces.append(_remap_face(face, mapping))
	var rebuilt_loose: Array[Vector2i] = []
	for edge: Vector2i in result.loose_edges:
		rebuilt_loose.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
	var rebuilt_creases: Array[Vector2i] = []
	var rebuilt_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in result.crease_edges.size():
		var edge: Vector2i = result.crease_edges[crease_index]
		if mapping[edge.x] < 0 or mapping[edge.y] < 0:
			continue
		rebuilt_creases.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
		rebuilt_crease_weights.append(result.crease_weights[crease_index])
	var rebuilt_seams: Array[Vector2i] = []
	for edge: Vector2i in result.seam_edges:
		if mapping[edge.x] < 0 or mapping[edge.y] < 0:
			continue
		var remapped_edge: Vector2i = GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y])
		if not rebuilt_seams.has(remapped_edge):
			rebuilt_seams.append(remapped_edge)
	result.set_geometry(
		rebuilt_vertices,
		rebuilt_faces,
		result.smooth_faces,
		result.uv_faces,
		result.has_uv_map,
		result.corner_normals,
		result.has_custom_normals,
		rebuilt_loose,
		rebuilt_creases,
		rebuilt_crease_weights,
		rebuilt_seams,
		result.face_materials
	)
	return result

static func flip_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, result.faces.size())
	for face_index: int in selected:
		var source: PackedInt32Array = result.faces[face_index]
		var reversed: PackedInt32Array = PackedInt32Array()
		for index: int in range(source.size() - 1, -1, -1):
			reversed.append(source[index])
		result.faces[face_index] = reversed
		var source_uvs: PackedVector2Array = result.uv_faces[face_index]
		var reversed_uvs: PackedVector2Array = PackedVector2Array()
		for index: int in range(source_uvs.size() - 1, -1, -1):
			reversed_uvs.append(source_uvs[index])
		result.uv_faces[face_index] = reversed_uvs
	return result


static func set_faces_smooth(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array,
	is_smooth: bool
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var flag: int = 1 if is_smooth else 0
	for face_index: int in face_indices:
		if face_index >= 0 and face_index < result.smooth_faces.size():
			result.smooth_faces[face_index] = flag
	return result


static func get_selected_vertex_indices(
	mesh: GMSMeshData,
	mode: int,
	selected_vertices: PackedInt32Array,
	selected_edges: PackedInt32Array,
	selected_faces: PackedInt32Array
) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()

	match mode:
		GMSSelection.Mode.VERTEX:
			return _unique_valid_indices(selected_vertices, mesh.vertices.size())
		GMSSelection.Mode.EDGE:
			var edges: Array[Vector2i] = mesh.get_edges()
			var edge_vertices: PackedInt32Array = PackedInt32Array()
			if selected_edges.size() <= 1024:
				var edge_known_small: Dictionary = {}
				for edge_index: int in selected_edges:
					if edge_index < 0 or edge_index >= edges.size():
						continue
					var edge: Vector2i = edges[edge_index]
					if not edge_known_small.has(edge.x):
						edge_known_small[edge.x] = true
						edge_vertices.append(edge.x)
					if not edge_known_small.has(edge.y):
						edge_known_small[edge.y] = true
						edge_vertices.append(edge.y)
			else:
				var edge_known_dense: PackedByteArray = PackedByteArray()
				edge_known_dense.resize(mesh.vertices.size())
				for edge_index: int in selected_edges:
					if edge_index < 0 or edge_index >= edges.size():
						continue
					var edge: Vector2i = edges[edge_index]
					if edge_known_dense[edge.x] == 0:
						edge_known_dense[edge.x] = 1
						edge_vertices.append(edge.x)
					if edge_known_dense[edge.y] == 0:
						edge_known_dense[edge.y] = 1
						edge_vertices.append(edge.y)
			return edge_vertices
		GMSSelection.Mode.FACE:
			var face_vertices: PackedInt32Array = PackedInt32Array()
			if selected_faces.size() <= 1024:
				var face_known_small: Dictionary = {}
				for face_index: int in selected_faces:
					if face_index < 0 or face_index >= mesh.faces.size():
						continue
					for vertex_index: int in mesh.faces[face_index]:
						if not face_known_small.has(vertex_index):
							face_known_small[vertex_index] = true
							face_vertices.append(vertex_index)
			else:
				var face_known_dense: PackedByteArray = PackedByteArray()
				face_known_dense.resize(mesh.vertices.size())
				for face_index: int in selected_faces:
					if face_index < 0 or face_index >= mesh.faces.size():
						continue
					for vertex_index: int in mesh.faces[face_index]:
						if face_known_dense[vertex_index] == 0:
							face_known_dense[vertex_index] = 1
							face_vertices.append(vertex_index)
			return face_vertices
		_:
			return PackedInt32Array()


static func get_vertices_center(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> Vector3:
	if mesh == null or vertex_indices.is_empty():
		return Vector3.ZERO

	var center: Vector3 = Vector3.ZERO
	var valid_count: int = 0
	for vertex_index: int in vertex_indices:
		if vertex_index >= 0 and vertex_index < mesh.vertices.size():
			center += mesh.vertices[vertex_index]
			valid_count += 1

	if valid_count == 0:
		return Vector3.ZERO
	return center / float(valid_count)


static func all_vertex_indices(mesh: GMSMeshData) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(mesh.vertices.size())
	for index: int in indices.size():
		indices[index] = index
	return indices


static func get_edge_loop(mesh: GMSMeshData, edge_index: int) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	var edges: Array[Vector2i] = mesh.get_edges()
	if edge_index < 0 or edge_index >= edges.size():
		return PackedInt32Array()

	var topology: Dictionary = _build_edge_topology(mesh, edges)
	var edge_to_faces: Dictionary = topology["edge_to_faces"]
	var vertex_edges: Array[PackedInt32Array] = topology["vertex_edges"]
	var result: PackedInt32Array = PackedInt32Array([edge_index])
	var start_edge: Vector2i = edges[edge_index]

	_traverse_edge_loop_direction(
		edges,
		edge_to_faces,
		vertex_edges,
		edge_index,
		start_edge.x,
		result
	)
	_traverse_edge_loop_direction(
		edges,
		edge_to_faces,
		vertex_edges,
		edge_index,
		start_edge.y,
		result
	)
	result.sort()
	return result


static func get_edge_ring(mesh: GMSMeshData, edge_index: int) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	var edges: Array[Vector2i] = mesh.get_edges()
	if edge_index < 0 or edge_index >= edges.size():
		return PackedInt32Array()

	var topology: Dictionary = _build_edge_topology(mesh, edges)
	var edge_to_faces: Dictionary = topology["edge_to_faces"]
	var start_edge: Vector2i = edges[edge_index]
	var result: PackedInt32Array = PackedInt32Array([edge_index])
	var start_faces: Array = edge_to_faces.get(start_edge, [])
	for start_face_value: Variant in start_faces:
		result = _traverse_quad_edge_ring(
			mesh,
			edges,
			edge_to_faces,
			start_edge,
			int(start_face_value),
			result
		)
	result.sort()
	return result


static func loop_cut(mesh: GMSMeshData, edge_index: int) -> Dictionary:
	var unchanged: Dictionary = {
		"mesh": mesh.duplicate_mesh_data() if mesh != null else null,
		"edge_indices": PackedInt32Array(),
	}
	if mesh == null:
		return unchanged

	var edges: Array[Vector2i] = mesh.get_edges()
	if edge_index < 0 or edge_index >= edges.size():
		return unchanged
	var ring_indices: PackedInt32Array = get_edge_ring(mesh, edge_index)
	if ring_indices.is_empty():
		return unchanged

	var ring_keys: Dictionary = {}
	for ring_index: int in ring_indices:
		if ring_index >= 0 and ring_index < edges.size():
			ring_keys[edges[ring_index]] = true


	for face: PackedInt32Array in mesh.faces:
		var positions: PackedInt32Array = PackedInt32Array()
		for corner_index: int in face.size():
			var key: Vector2i = _edge_key(face[corner_index], face[(corner_index + 1) % face.size()])
			if ring_keys.has(key):
				positions.append(corner_index)
		if positions.is_empty():
			continue
		if face.size() != 4 or positions.size() != 2:
			return unchanged
		if (positions[0] + 2) % 4 != positions[1] and (positions[1] + 2) % 4 != positions[0]:
			return unchanged

	var new_vertices: PackedVector3Array = mesh.vertices.duplicate()
	var midpoint_indices: Dictionary = {}
	for ring_index: int in ring_indices:
		var edge: Vector2i = edges[ring_index]
		var midpoint_index: int = new_vertices.size()
		new_vertices.append((mesh.vertices[edge.x] + mesh.vertices[edge.y]) * 0.5)
		midpoint_indices[edge] = midpoint_index

	var new_faces: Array[PackedInt32Array] = []
	var new_smooth: PackedByteArray = PackedByteArray()
	var new_materials: PackedInt32Array = PackedInt32Array()
	var cut_edge_keys: Dictionary = {}
	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		var positions: PackedInt32Array = PackedInt32Array()
		for corner_index: int in face.size():
			var key: Vector2i = _edge_key(face[corner_index], face[(corner_index + 1) % face.size()])
			if midpoint_indices.has(key):
				positions.append(corner_index)

		var smooth_value: int = int(mesh.smooth_faces[face_index]) if face_index < mesh.smooth_faces.size() else 0
		if positions.is_empty():
			new_faces.append(face.duplicate())
			new_smooth.append(smooth_value)
			new_materials.append(mesh.get_face_material(face_index))
			continue

		var start_position: int = positions[0]
		if (start_position + 2) % 4 != positions[1]:
			start_position = positions[1]
		var v0: int = face[start_position]
		var v1: int = face[(start_position + 1) % 4]
		var v2: int = face[(start_position + 2) % 4]
		var v3: int = face[(start_position + 3) % 4]
		var cut_a: int = int(midpoint_indices[_edge_key(v0, v1)])
		var cut_b: int = int(midpoint_indices[_edge_key(v2, v3)])
		new_faces.append(PackedInt32Array([v0, cut_a, cut_b, v3]))
		new_smooth.append(smooth_value)
		new_materials.append(mesh.get_face_material(face_index))
		new_faces.append(PackedInt32Array([cut_a, v1, v2, cut_b]))
		new_smooth.append(smooth_value)
		new_materials.append(mesh.get_face_material(face_index))
		cut_edge_keys[_edge_key(cut_a, cut_b)] = true

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		new_vertices, new_faces, new_smooth, [], false, [], false, [], [], PackedFloat32Array(), [], new_materials
	)
	var selected_edges: PackedInt32Array = PackedInt32Array()
	var result_edges: Array[Vector2i] = result.get_edges()
	for result_edge_index: int in result_edges.size():
		if cut_edge_keys.has(result_edges[result_edge_index]):
			selected_edges.append(result_edge_index)
	return {
		"mesh": result,
		"edge_indices": selected_edges,
	}


static func subdivide_faces(
	mesh: GMSMeshData,
	selected_faces: PackedInt32Array,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Dictionary:
	var unchanged: Dictionary = {
		"mesh": mesh.duplicate_mesh_data() if mesh != null else null,
		"face_indices": PackedInt32Array(),
		"cancelled": false,
		"non_manifold_count": 0,
	}
	if mesh == null:
		return unchanged
	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.01), "Preparing subdivision")
		if job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
	var selected: PackedInt32Array = _unique_valid_indices(selected_faces, mesh.faces.size())
	if selected.is_empty():
		return unchanged

	var selected_set: Dictionary = {}
	var midpoint_indices: Dictionary = {}
	var new_vertices: PackedVector3Array = mesh.vertices.duplicate()
	var selected_count: int = maxi(selected.size(), 1)
	for selected_position: int in selected.size():
		if job != null and selected_position % 64 == 0:
			if job.is_cancelled():
				unchanged["cancelled"] = true
				return unchanged
			job.update_progress(
				lerpf(
					progress_start,
					progress_end,
					0.04 + 0.18 * float(selected_position) / float(selected_count)
				),
				"Creating subdivision edge points"
			)
		var face_index: int = selected[selected_position]
		selected_set[face_index] = true
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var key: Vector2i = _edge_key(a, b)
			if midpoint_indices.has(key):
				continue
			midpoint_indices[key] = new_vertices.size()
			new_vertices.append((mesh.vertices[a] + mesh.vertices[b]) * 0.5)

	var new_faces: Array[PackedInt32Array] = []
	var new_smooth: PackedByteArray = PackedByteArray()
	var new_materials: PackedInt32Array = PackedInt32Array()
	var new_uvs: Array[PackedVector2Array] = []
	var generated_faces: PackedInt32Array = PackedInt32Array()
	var face_count: int = maxi(mesh.faces.size(), 1)
	for face_index: int in mesh.faces.size():
		if job != null and face_index % 64 == 0:
			if job.is_cancelled():
				unchanged["cancelled"] = true
				return unchanged
			job.update_progress(
				lerpf(
					progress_start,
					progress_end,
					0.22 + 0.58 * float(face_index) / float(face_count)
				),
				"Building subdivided faces"
			)
		var face: PackedInt32Array = mesh.faces[face_index]
		var smooth_value: int = int(mesh.smooth_faces[face_index]) if face_index < mesh.smooth_faces.size() else 0
		var source_uvs: PackedVector2Array = mesh.uv_faces[face_index] if mesh.has_uv_map else PackedVector2Array()
		if selected_set.has(face_index):
			var center_index: int = new_vertices.size()
			new_vertices.append(mesh.get_face_center(face_index))
			var center_uv: Vector2 = Vector2.ZERO
			if mesh.has_uv_map:
				for uv: Vector2 in source_uvs:
					center_uv += uv
				center_uv /= float(maxi(source_uvs.size(), 1))
			for corner_index: int in face.size():
				var previous_corner: int = (corner_index - 1 + face.size()) % face.size()
				var next_corner: int = (corner_index + 1) % face.size()
				var previous_vertex: int = face[previous_corner]
				var current_vertex: int = face[corner_index]
				var next_vertex: int = face[next_corner]
				var previous_midpoint: int = int(midpoint_indices[_edge_key(previous_vertex, current_vertex)])
				var next_midpoint: int = int(midpoint_indices[_edge_key(current_vertex, next_vertex)])
				generated_faces.append(new_faces.size())
				new_faces.append(PackedInt32Array([
					current_vertex,
					next_midpoint,
					center_index,
					previous_midpoint,
				]))
				new_smooth.append(smooth_value)
				new_materials.append(mesh.get_face_material(face_index))
				if mesh.has_uv_map:
					var current_uv: Vector2 = source_uvs[corner_index]
					new_uvs.append(PackedVector2Array([
						current_uv,
						(current_uv + source_uvs[next_corner]) * 0.5,
						center_uv,
						(source_uvs[previous_corner] + current_uv) * 0.5,
					]))
			continue

		var expanded: PackedInt32Array = PackedInt32Array()
		var expanded_uvs: PackedVector2Array = PackedVector2Array()
		for corner_index: int in face.size():
			var current_vertex: int = face[corner_index]
			var next_corner: int = (corner_index + 1) % face.size()
			var next_vertex: int = face[next_corner]
			expanded.append(current_vertex)
			if mesh.has_uv_map:
				expanded_uvs.append(source_uvs[corner_index])
			var key: Vector2i = _edge_key(current_vertex, next_vertex)
			if midpoint_indices.has(key):
				expanded.append(int(midpoint_indices[key]))
				if mesh.has_uv_map:
					expanded_uvs.append((source_uvs[corner_index] + source_uvs[next_corner]) * 0.5)
		new_faces.append(expanded)
		new_smooth.append(smooth_value)
		new_materials.append(mesh.get_face_material(face_index))
		if mesh.has_uv_map:
			new_uvs.append(expanded_uvs)

	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.82), "Preserving crease and seam data")
		if job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
	var new_creases: Array[Vector2i] = []
	var new_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in mesh.crease_edges.size():
		if job != null and crease_index % 256 == 0 and job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
		var edge: Vector2i = mesh.crease_edges[crease_index]
		var weight: float = mesh.crease_weights[crease_index]
		if midpoint_indices.has(edge):
			var midpoint: int = int(midpoint_indices[edge])
			new_creases.append(GMSMeshData.canonical_edge(edge.x, midpoint))
			new_crease_weights.append(weight)
			new_creases.append(GMSMeshData.canonical_edge(midpoint, edge.y))
			new_crease_weights.append(weight)
		else:
			new_creases.append(edge)
			new_crease_weights.append(weight)

	var new_seams: Array[Vector2i] = []
	for seam_index: int in mesh.seam_edges.size():
		if job != null and seam_index % 256 == 0 and job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
		var edge: Vector2i = mesh.seam_edges[seam_index]
		if midpoint_indices.has(edge):
			var midpoint: int = int(midpoint_indices[edge])
			new_seams.append(GMSMeshData.canonical_edge(edge.x, midpoint))
			new_seams.append(GMSMeshData.canonical_edge(midpoint, edge.y))
		else:
			new_seams.append(edge)

	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.90), "Finalizing subdivided mesh")
		if job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		new_vertices,
		new_faces,
		new_smooth,
		new_uvs,
		mesh.has_uv_map,
		[],
		false,
		mesh.loose_edges,
		new_creases,
		new_crease_weights,
		new_seams,
		new_materials
	)
	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.96), "Validating subdivided topology")
		if job.is_cancelled():
			unchanged["cancelled"] = true
			return unchanged
	var non_manifold_count: int = result.get_topology().non_manifold_edges.size()
	if job != null:
		job.update_progress(progress_end, "Subdivision complete")
	return {
		"mesh": result,
		"face_indices": generated_faces,
		"cancelled": false,
		"non_manifold_count": non_manifold_count,
	}


static func get_linked_component_indices(
	mesh: GMSMeshData,
	mode: int,
	selected_vertices: PackedInt32Array,
	selected_edges: PackedInt32Array,
	selected_faces: PackedInt32Array
) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	var seed_vertices: PackedInt32Array = get_selected_vertex_indices(
		mesh,
		mode,
		selected_vertices,
		selected_edges,
		selected_faces
	)
	if seed_vertices.is_empty():
		return PackedInt32Array()

	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(mesh.vertices.size())
	for vertex_index: int in mesh.vertices.size():
		adjacency[vertex_index] = PackedInt32Array()
	for edge: Vector2i in mesh.get_edges():
		adjacency[edge.x].append(edge.y)
		adjacency[edge.y].append(edge.x)

	var linked: PackedInt32Array = PackedInt32Array()
	var queue: Array[int] = []
	for seed: int in seed_vertices:
		if not linked.has(seed):
			linked.append(seed)
			queue.append(seed)

	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbour: int in adjacency[current]:
			if linked.has(neighbour):
				continue
			linked.append(neighbour)
			queue.append(neighbour)
	linked.sort()

	match mode:
		GMSSelection.Mode.VERTEX:
			return linked
		GMSSelection.Mode.EDGE:
			var linked_edges: PackedInt32Array = PackedInt32Array()
			var edges: Array[Vector2i] = mesh.get_edges()
			for index: int in edges.size():
				if linked.has(edges[index].x) and linked.has(edges[index].y):
					linked_edges.append(index)
			return linked_edges
		GMSSelection.Mode.FACE:
			var linked_faces: PackedInt32Array = PackedInt32Array()
			for face_index: int in mesh.faces.size():
				var face: PackedInt32Array = mesh.faces[face_index]
				for vertex_index: int in face:
					if linked.has(vertex_index):
						linked_faces.append(face_index)
						break
			return linked_faces
	return PackedInt32Array()


static func grow_component_selection(
	mesh: GMSMeshData,
	mode: int,
	selected_vertices: PackedInt32Array,
	selected_edges: PackedInt32Array,
	selected_faces: PackedInt32Array
) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	match mode:
		GMSSelection.Mode.VERTEX:
			var grown_vertices: PackedInt32Array = selected_vertices.duplicate()
			for edge: Vector2i in mesh.get_edges():
				if selected_vertices.has(edge.x) and not grown_vertices.has(edge.y):
					grown_vertices.append(edge.y)
				if selected_vertices.has(edge.y) and not grown_vertices.has(edge.x):
					grown_vertices.append(edge.x)
			grown_vertices.sort()
			return grown_vertices
		GMSSelection.Mode.EDGE:
			var edges: Array[Vector2i] = mesh.get_edges()
			var selected_vertex_set: PackedInt32Array = PackedInt32Array()
			for edge_index: int in selected_edges:
				if edge_index < 0 or edge_index >= edges.size():
					continue
				if not selected_vertex_set.has(edges[edge_index].x):
					selected_vertex_set.append(edges[edge_index].x)
				if not selected_vertex_set.has(edges[edge_index].y):
					selected_vertex_set.append(edges[edge_index].y)
			var grown_edges: PackedInt32Array = selected_edges.duplicate()
			for edge_index: int in edges.size():
				if selected_vertex_set.has(edges[edge_index].x) or selected_vertex_set.has(edges[edge_index].y):
					if not grown_edges.has(edge_index):
						grown_edges.append(edge_index)
			grown_edges.sort()
			return grown_edges
		GMSSelection.Mode.FACE:
			var grown_faces: PackedInt32Array = selected_faces.duplicate()
			var face_neighbours: Array[PackedInt32Array] = _build_face_neighbours(mesh)
			for face_index: int in selected_faces:
				if face_index < 0 or face_index >= face_neighbours.size():
					continue
				for neighbour: int in face_neighbours[face_index]:
					if not grown_faces.has(neighbour):
						grown_faces.append(neighbour)
			grown_faces.sort()
			return grown_faces
	return PackedInt32Array()


static func shrink_component_selection(
	mesh: GMSMeshData,
	mode: int,
	selected_vertices: PackedInt32Array,
	selected_edges: PackedInt32Array,
	selected_faces: PackedInt32Array
) -> PackedInt32Array:
	if mesh == null:
		return PackedInt32Array()
	match mode:
		GMSSelection.Mode.VERTEX:
			var neighbours: Array[PackedInt32Array] = []
			neighbours.resize(mesh.vertices.size())
			for vertex_index: int in mesh.vertices.size():
				neighbours[vertex_index] = PackedInt32Array()
			for edge: Vector2i in mesh.get_edges():
				neighbours[edge.x].append(edge.y)
				neighbours[edge.y].append(edge.x)
			var shrunk_vertices: PackedInt32Array = PackedInt32Array()
			for vertex_index: int in selected_vertices:
				if vertex_index < 0 or vertex_index >= neighbours.size():
					continue
				var keep: bool = not neighbours[vertex_index].is_empty()
				for neighbour: int in neighbours[vertex_index]:
					if not selected_vertices.has(neighbour):
						keep = false
						break
				if keep:
					shrunk_vertices.append(vertex_index)
			return shrunk_vertices
		GMSSelection.Mode.EDGE:
			var edges: Array[Vector2i] = mesh.get_edges()
			var incident: Array[PackedInt32Array] = []
			incident.resize(mesh.vertices.size())
			for vertex_index: int in mesh.vertices.size():
				incident[vertex_index] = PackedInt32Array()
			for edge_index: int in edges.size():
				incident[edges[edge_index].x].append(edge_index)
				incident[edges[edge_index].y].append(edge_index)
			var shrunk_edges: PackedInt32Array = PackedInt32Array()
			for edge_index: int in selected_edges:
				if edge_index < 0 or edge_index >= edges.size():
					continue
				var edge: Vector2i = edges[edge_index]
				var keep: bool = true
				for endpoint: int in PackedInt32Array([edge.x, edge.y]):
					for neighbour_edge: int in incident[endpoint]:
						if not selected_edges.has(neighbour_edge):
							keep = false
							break
					if not keep:
						break
				if keep:
					shrunk_edges.append(edge_index)
			return shrunk_edges
		GMSSelection.Mode.FACE:
			var face_neighbours: Array[PackedInt32Array] = _build_face_neighbours(mesh)
			var shrunk_faces: PackedInt32Array = PackedInt32Array()
			for face_index: int in selected_faces:
				if face_index < 0 or face_index >= face_neighbours.size():
					continue
				var keep: bool = not face_neighbours[face_index].is_empty()
				for neighbour: int in face_neighbours[face_index]:
					if not selected_faces.has(neighbour):
						keep = false
						break
				if keep:
					shrunk_faces.append(face_index)
			return shrunk_faces
	return PackedInt32Array()


static func duplicate_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> Dictionary:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	var new_faces: PackedInt32Array = PackedInt32Array()
	var new_vertices: PackedInt32Array = PackedInt32Array()
	if selected.is_empty():
		return {"mesh": result, "face_indices": new_faces, "vertex_indices": new_vertices}

	var source_uv_faces: Array[PackedVector2Array] = []
	for face_uvs: PackedVector2Array in result.uv_faces:
		source_uv_faces.append(face_uvs.duplicate())

	var vertex_map: Dictionary = {}
	for face_index: int in selected:
		for source_vertex: int in mesh.faces[face_index]:
			if vertex_map.has(source_vertex):
				continue
			var duplicate_index: int = result.vertices.size()
			vertex_map[source_vertex] = duplicate_index
			result.vertices.append(mesh.vertices[source_vertex])
			new_vertices.append(duplicate_index)

	for face_index: int in selected:
		var duplicate_face: PackedInt32Array = PackedInt32Array()
		for source_vertex: int in mesh.faces[face_index]:
			duplicate_face.append(int(vertex_map[source_vertex]))
		new_faces.append(result.faces.size())
		result.faces.append(duplicate_face)
		result.face_materials.append(mesh.get_face_material(face_index))
		result.smooth_faces.append(mesh.smooth_faces[face_index])
		result.uv_faces.append(source_uv_faces[face_index].duplicate())

	return {"mesh": result, "face_indices": new_faces, "vertex_indices": new_vertices}


static func triangulate_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	var selected_set: Dictionary = {}
	for face_index: int in selected:
		selected_set[face_index] = true

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var source_uv_faces: Array[PackedVector2Array] = []
	for face_uvs: PackedVector2Array in result.uv_faces:
		source_uv_faces.append(face_uvs.duplicate())
	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_uvs: Array[PackedVector2Array] = []
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	var new_selection: PackedInt32Array = PackedInt32Array()

	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		if not selected_set.has(face_index) or face.size() <= 3:
			if selected_set.has(face_index):
				new_selection.append(rebuilt_faces.size())
			rebuilt_faces.append(face.duplicate())
			rebuilt_smooth.append(mesh.smooth_faces[face_index])
			rebuilt_uvs.append(source_uv_faces[face_index].duplicate())
			rebuilt_materials.append(mesh.get_face_material(face_index))
			continue
		for triangle_index: int in range(1, face.size() - 1):
			new_selection.append(rebuilt_faces.size())
			rebuilt_faces.append(PackedInt32Array([
				face[0],
				face[triangle_index],
				face[triangle_index + 1],
			]))
			rebuilt_smooth.append(mesh.smooth_faces[face_index])
			rebuilt_materials.append(mesh.get_face_material(face_index))
			rebuilt_uvs.append(PackedVector2Array([
				source_uv_faces[face_index][0],
				source_uv_faces[face_index][triangle_index],
				source_uv_faces[face_index][triangle_index + 1],
			]))

	result.faces = rebuilt_faces
	result.smooth_faces = rebuilt_smooth
	result.uv_faces = rebuilt_uvs
	result.face_materials = rebuilt_materials
	return {"mesh": result, "face_indices": new_selection}


static func triangles_to_quads(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array,
	angle_limit_degrees: float = 30.0
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	var selected_set: Dictionary = {}
	for face_index: int in selected:
		if mesh.faces[face_index].size() == 3:
			selected_set[face_index] = true

	var edge_to_faces: Dictionary = {}
	for face_key: Variant in selected_set.keys():
		var face_index: int = int(face_key)
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in 3:
			var key: Vector2i = Vector2i(
				mini(face[corner_index], face[(corner_index + 1) % 3]),
				maxi(face[corner_index], face[(corner_index + 1) % 3])
			)
			var connected: Array = edge_to_faces.get(key, [])
			connected.append(face_index)
			edge_to_faces[key] = connected

	var used_faces: Dictionary = {}
	var quad_for_face: Dictionary = {}
	var cosine_limit: float = cos(deg_to_rad(clampf(angle_limit_degrees, 0.0, 180.0)))
	var edge_keys: Array = edge_to_faces.keys()
	for edge_key_value: Variant in edge_keys:
		var connected_faces: Array = edge_to_faces[edge_key_value]
		if connected_faces.size() != 2:
			continue
		var first: int = int(connected_faces[0])
		var second: int = int(connected_faces[1])
		if used_faces.has(first) or used_faces.has(second):
			continue
		if mesh.get_face_normal(first).dot(mesh.get_face_normal(second)) < cosine_limit:
			continue
		var shared_edge: Vector2i = edge_key_value
		var quad: PackedInt32Array = _make_quad_from_triangles(
			mesh.faces[first],
			mesh.faces[second],
			shared_edge
		)
		if quad.size() != 4:
			continue
		var insertion_face: int = mini(first, second)
		quad_for_face[insertion_face] = {
			"quad": quad,
			"other": maxi(first, second),
			"material": mesh.get_face_material(first),
			"smooth": 1 if mesh.smooth_faces[first] != 0 and mesh.smooth_faces[second] != 0 else 0,
		}
		used_faces[first] = true
		used_faces[second] = true

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	var new_selection: PackedInt32Array = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		if quad_for_face.has(face_index):
			var quad_data: Dictionary = quad_for_face[face_index]
			new_selection.append(rebuilt_faces.size())
			var rebuilt_quad: PackedInt32Array = quad_data["quad"]
			rebuilt_faces.append(rebuilt_quad)
			rebuilt_smooth.append(int(quad_data["smooth"]))
			rebuilt_materials.append(int(quad_data["material"]))
			continue
		if used_faces.has(face_index):
			continue
		if selected_set.has(face_index):
			new_selection.append(rebuilt_faces.size())
		rebuilt_faces.append(mesh.faces[face_index].duplicate())
		rebuilt_smooth.append(mesh.smooth_faces[face_index])
		rebuilt_materials.append(mesh.get_face_material(face_index))

	result.faces = rebuilt_faces
	result.smooth_faces = rebuilt_smooth
	result.face_materials = rebuilt_materials
	result.invalidate_uvs()
	return {"mesh": result, "face_indices": new_selection}


static func recalculate_normals_outside(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	if selected.is_empty():
		return result
	var selected_set: Dictionary = {}
	for face_index: int in selected:
		selected_set[face_index] = true

	var edge_references: Dictionary = {}
	for face_index: int in selected:
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			var refs: Array = edge_references.get(key, [])
			refs.append({"face": face_index, "a": a, "b": b})
			edge_references[key] = refs

	var mesh_center: Vector3 = Vector3.ZERO
	for vertex: Vector3 in mesh.vertices:
		mesh_center += vertex
	if not mesh.vertices.is_empty():
		mesh_center /= float(mesh.vertices.size())

	var visited: Dictionary = {}
	var should_flip: Dictionary = {}
	for seed_face: int in selected:
		if visited.has(seed_face):
			continue
		var component: PackedInt32Array = PackedInt32Array()
		var queue: Array[int] = [seed_face]
		should_flip[seed_face] = false
		visited[seed_face] = true

		while not queue.is_empty():
			var current_face: int = queue.pop_front()
			component.append(current_face)
			var current_loop: PackedInt32Array = mesh.faces[current_face]
			for corner_index: int in current_loop.size():
				var current_a: int = current_loop[corner_index]
				var current_b: int = current_loop[(corner_index + 1) % current_loop.size()]
				var edge_key: Vector2i = Vector2i(mini(current_a, current_b), maxi(current_a, current_b))
				var refs: Array = edge_references.get(edge_key, [])
				for ref_value: Variant in refs:
					var ref: Dictionary = ref_value
					var other_face: int = int(ref["face"])
					if other_face == current_face or not selected_set.has(other_face):
						continue
					var same_direction: bool = int(ref["a"]) == current_a and int(ref["b"]) == current_b
					var current_flip: bool = bool(should_flip[current_face])
					var other_flip: bool = not current_flip if same_direction else current_flip
					if not visited.has(other_face):
						visited[other_face] = true
						should_flip[other_face] = other_flip
						queue.append(other_face)

		var outward_score: float = 0.0
		for face_index: int in component:
			var normal: Vector3 = mesh.get_face_normal(face_index)
			if bool(should_flip.get(face_index, false)):
				normal = -normal
			var face_center: Vector3 = mesh.get_face_center(face_index)
			outward_score += normal.dot(face_center - mesh_center)
		if outward_score < 0.0:
			for face_index: int in component:
				should_flip[face_index] = not bool(should_flip.get(face_index, false))

	for face_index: int in selected:
		if not bool(should_flip.get(face_index, false)):
			continue
		var source: PackedInt32Array = result.faces[face_index]
		var reversed: PackedInt32Array = PackedInt32Array()
		for index: int in range(source.size() - 1, -1, -1):
			reversed.append(source[index])
		result.faces[face_index] = reversed
		var source_uvs: PackedVector2Array = result.uv_faces[face_index]
		var reversed_uvs: PackedVector2Array = PackedVector2Array()
		for index: int in range(source_uvs.size() - 1, -1, -1):
			reversed_uvs.append(source_uvs[index])
		result.uv_faces[face_index] = reversed_uvs
	return result


static func _build_edge_topology(
	mesh: GMSMeshData,
	edges: Array[Vector2i]
) -> Dictionary:
	var edge_to_faces: Dictionary = {}
	var vertex_edges: Array[PackedInt32Array] = []
	vertex_edges.resize(mesh.vertices.size())
	for vertex_index: int in vertex_edges.size():
		vertex_edges[vertex_index] = PackedInt32Array()
	for edge_index: int in edges.size():
		var edge: Vector2i = edges[edge_index]
		vertex_edges[edge.x].append(edge_index)
		vertex_edges[edge.y].append(edge_index)
	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var key: Vector2i = _edge_key(face[corner_index], face[(corner_index + 1) % face.size()])
			var connected_faces: Array = edge_to_faces.get(key, [])
			connected_faces.append(face_index)
			edge_to_faces[key] = connected_faces
	return {
		"edge_to_faces": edge_to_faces,
		"vertex_edges": vertex_edges,
	}


static func _traverse_edge_loop_direction(
	edges: Array[Vector2i],
	edge_to_faces: Dictionary,
	vertex_edges: Array[PackedInt32Array],
	start_edge_index: int,
	start_vertex: int,
	result: PackedInt32Array
) -> void:
	var current_edge_index: int = start_edge_index
	var current_vertex: int = start_vertex
	var visited_vertices: Dictionary = {}
	while current_vertex >= 0 and current_vertex < vertex_edges.size():
		if visited_vertices.has(current_vertex):
			break
		visited_vertices[current_vertex] = true
		var incident_edges: PackedInt32Array = vertex_edges[current_vertex]


		if incident_edges.size() != 4:
			break

		var incoming_key: Vector2i = edges[current_edge_index]
		var incoming_faces: Array = edge_to_faces.get(incoming_key, [])
		var candidates: PackedInt32Array = PackedInt32Array()
		for candidate_index: int in incident_edges:
			if candidate_index == current_edge_index:
				continue
			var candidate_faces: Array = edge_to_faces.get(edges[candidate_index], [])
			var shares_face: bool = false
			for candidate_face: Variant in candidate_faces:
				if incoming_faces.has(candidate_face):
					shares_face = true
					break
			if not shares_face:
				candidates.append(candidate_index)
		if candidates.size() != 1:
			break

		var next_edge_index: int = candidates[0]
		if result.has(next_edge_index):
			break
		result.append(next_edge_index)
		var next_edge: Vector2i = edges[next_edge_index]
		current_vertex = next_edge.y if next_edge.x == current_vertex else next_edge.x
		current_edge_index = next_edge_index


static func _traverse_quad_edge_ring(
	mesh: GMSMeshData,
	edges: Array[Vector2i],
	edge_to_faces: Dictionary,
	start_edge: Vector2i,
	start_face: int,
	initial_result: PackedInt32Array
) -> PackedInt32Array:
	var result: PackedInt32Array = initial_result.duplicate()
	var current_edge: Vector2i = start_edge
	var current_face: int = start_face
	var visited_faces: Dictionary = {}

	while current_face >= 0 and not visited_faces.has(current_face):
		visited_faces[current_face] = true
		var face: PackedInt32Array = mesh.faces[current_face]
		if face.size() != 4:
			break
		var edge_position: int = _find_face_edge_position(face, current_edge)
		if edge_position < 0:
			break
		var opposite: Vector2i = _edge_key(
			face[(edge_position + 2) % 4],
			face[(edge_position + 3) % 4]
		)
		var opposite_index: int = edges.find(opposite)
		if opposite_index < 0 or result.has(opposite_index):
			break
		result.append(opposite_index)

		var next_face: int = -1
		var connected_faces: Array = edge_to_faces.get(opposite, [])
		for face_value: Variant in connected_faces:
			var candidate: int = int(face_value)
			if candidate != current_face:
				next_face = candidate
				break
		current_edge = opposite
		current_face = next_face
	return result


static func _edge_key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _find_face_edge_position(face: PackedInt32Array, edge: Vector2i) -> int:
	for corner_index: int in face.size():
		var key: Vector2i = Vector2i(
			mini(face[corner_index], face[(corner_index + 1) % face.size()]),
			maxi(face[corner_index], face[(corner_index + 1) % face.size()])
		)
		if key == edge:
			return corner_index
	return -1


static func _build_face_neighbours(mesh: GMSMeshData) -> Array[PackedInt32Array]:
	var neighbours: Array[PackedInt32Array] = []
	neighbours.resize(mesh.faces.size())
	for face_index: int in mesh.faces.size():
		neighbours[face_index] = PackedInt32Array()
	var edge_to_faces: Dictionary = {}
	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var key: Vector2i = Vector2i(
				mini(face[corner_index], face[(corner_index + 1) % face.size()]),
				maxi(face[corner_index], face[(corner_index + 1) % face.size()])
			)
			var connected_faces: Array = edge_to_faces.get(key, [])
			connected_faces.append(face_index)
			edge_to_faces[key] = connected_faces
	for connected_value: Variant in edge_to_faces.values():
		var connected: Array = connected_value
		for first_value: Variant in connected:
			for second_value: Variant in connected:
				var first: int = int(first_value)
				var second: int = int(second_value)
				if first != second and not neighbours[first].has(second):
					neighbours[first].append(second)
	return neighbours


static func _make_quad_from_triangles(
	first: PackedInt32Array,
	second: PackedInt32Array,
	shared_edge: Vector2i
) -> PackedInt32Array:
	var boundary_edges: Array[Vector2i] = []
	var source_faces: Array[PackedInt32Array] = [first, second]
	for face: PackedInt32Array in source_faces:
		for corner_index: int in 3:
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % 3]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			if key != shared_edge:
				boundary_edges.append(Vector2i(a, b))
	if boundary_edges.size() != 4:
		return PackedInt32Array()

	var ordered: PackedInt32Array = PackedInt32Array([boundary_edges[0].x, boundary_edges[0].y])
	boundary_edges.remove_at(0)
	while not boundary_edges.is_empty() and ordered.size() < 5:
		var current: int = ordered[ordered.size() - 1]
		var found: int = -1
		for edge_index: int in boundary_edges.size():
			if boundary_edges[edge_index].x == current:
				ordered.append(boundary_edges[edge_index].y)
				found = edge_index
				break
			if boundary_edges[edge_index].y == current:
				ordered.append(boundary_edges[edge_index].x)
				found = edge_index
				break
		if found < 0:
			return PackedInt32Array()
		boundary_edges.remove_at(found)
	if ordered.size() != 5 or ordered[0] != ordered[4]:
		return PackedInt32Array()
	ordered.remove_at(4)
	var unique: PackedInt32Array = PackedInt32Array()
	for vertex_index: int in ordered:
		if unique.has(vertex_index):
			return PackedInt32Array()
		unique.append(vertex_index)
	return ordered


static func _remap_face(face: PackedInt32Array, mapping: PackedInt32Array) -> PackedInt32Array:
	var remapped: PackedInt32Array = PackedInt32Array()
	for old_index: int in face:
		if old_index < 0 or old_index >= mapping.size():
			continue
		var new_index: int = mapping[old_index]
		if new_index < 0:
			continue
		if remapped.is_empty() or remapped[remapped.size() - 1] != new_index:
			remapped.append(new_index)
	if remapped.size() > 1 and remapped[0] == remapped[remapped.size() - 1]:
		remapped.remove_at(remapped.size() - 1)

	var unique: PackedInt32Array = PackedInt32Array()
	for vertex_index: int in remapped:
		if not unique.has(vertex_index):
			unique.append(vertex_index)
	if unique.size() < 3 or unique.size() != remapped.size():
		return PackedInt32Array()
	return remapped


static func _unique_valid_indices(source: PackedInt32Array, count: int) -> PackedInt32Array:
	var safe_count: int = maxi(count, 0)
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(mini(source.size(), safe_count))
	var write_index: int = 0
	if source.size() <= 1024:
		var known_small: Dictionary = {}
		for index: int in source:
			if index < 0 or index >= safe_count or known_small.has(index):
				continue
			known_small[index] = true
			result[write_index] = index
			write_index += 1
	else:
		var known_dense: PackedByteArray = PackedByteArray()
		known_dense.resize(safe_count)
		for index: int in source:
			if index < 0 or index >= safe_count or known_dense[index] != 0:
				continue
			known_dense[index] = 1
			result[write_index] = index
			write_index += 1
	result.resize(write_index)
	return result
