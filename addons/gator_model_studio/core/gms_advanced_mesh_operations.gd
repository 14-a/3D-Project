@tool
class_name GMSAdvancedMeshOperations
extends RefCounted





enum ProportionalFalloff {
	SMOOTH,
	SPHERE,
	ROOT,
	LINEAR,
	CONSTANT,
	SHARP,
}


static func set_edge_crease(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array,
	weight: float
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var edges: Array[Vector2i] = mesh.get_edges()
	for edge_index: int in _unique_valid_indices(edge_indices, edges.size()):
		var edge: Vector2i = edges[edge_index]
		result.set_edge_crease_by_vertices(edge.x, edge.y, weight)
	return result


static func extrude_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	distance: float
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var new_vertices: PackedInt32Array = PackedInt32Array()
	var new_edge_keys: Dictionary = {}
	if selected.is_empty():
		return {"mesh": result, "vertex_indices": new_vertices, "edge_indices": PackedInt32Array()}

	var normal: Vector3 = _average_vertex_normal(mesh, selected)
	if normal.is_zero_approx():
		normal = Vector3.UP
	var remap: Dictionary = {}
	for vertex_index: int in selected:
		var duplicate_index: int = result.vertices.size()
		result.vertices.append(mesh.vertices[vertex_index] + normal * distance)
		result.loose_edges.append(GMSMeshData.canonical_edge(vertex_index, duplicate_index))
		remap[vertex_index] = duplicate_index
		new_vertices.append(duplicate_index)
		new_edge_keys[GMSMeshData.canonical_edge(vertex_index, duplicate_index)] = true


	for edge: Vector2i in mesh.get_edges():
		if remap.has(edge.x) and remap.has(edge.y):
			var duplicate_edge: Vector2i = GMSMeshData.canonical_edge(int(remap[edge.x]), int(remap[edge.y]))
			result.loose_edges.append(duplicate_edge)
			new_edge_keys[duplicate_edge] = true
	result.set_geometry(
		result.vertices,
		result.faces,
		result.smooth_faces,
		result.uv_faces,
		result.has_uv_map,
		result.corner_normals,
		result.has_custom_normals,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		result.face_materials
	)
	return {
		"mesh": result,
		"vertex_indices": new_vertices,
		"edge_indices": _edge_indices_from_keys(result, new_edge_keys),
	}


static func extrude_edges(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array,
	distance: float
) -> Dictionary:
	var source_edges: Array[Vector2i] = mesh.get_edges()
	var selected_indices: PackedInt32Array = _unique_valid_indices(edge_indices, source_edges.size())
	var edge_faces: Dictionary = _build_edge_faces(mesh)
	var selected_edges: Array[Vector2i] = []
	for edge_index: int in selected_indices:
		var edge: Vector2i = source_edges[edge_index]
		var attached: PackedInt32Array = edge_faces.get(edge, PackedInt32Array())
		if attached.size() <= 1:
			selected_edges.append(edge)

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var new_faces: PackedInt32Array = PackedInt32Array()
	var new_vertices: PackedInt32Array = PackedInt32Array()
	var new_edge_keys: Dictionary = {}
	if selected_edges.is_empty():
		return {
			"mesh": result,
			"face_indices": new_faces,
			"vertex_indices": new_vertices,
			"edge_indices": PackedInt32Array(),
		}

	var selected_vertex_set: Dictionary = {}
	for edge: Vector2i in selected_edges:
		selected_vertex_set[edge.x] = true
		selected_vertex_set[edge.y] = true
	var selected_vertices: PackedInt32Array = PackedInt32Array()
	for key: Variant in selected_vertex_set.keys():
		selected_vertices.append(int(key))
	var normal: Vector3 = _average_vertex_normal(mesh, selected_vertices)
	if normal.is_zero_approx():
		normal = Vector3.UP

	var remap: Dictionary = {}
	for vertex_index: int in selected_vertices:
		var duplicate_index: int = result.vertices.size()
		result.vertices.append(mesh.vertices[vertex_index] + normal * distance)
		remap[vertex_index] = duplicate_index
		new_vertices.append(duplicate_index)

	for edge: Vector2i in selected_edges:
		var duplicate_a: int = int(remap[edge.x])
		var duplicate_b: int = int(remap[edge.y])
		var face: PackedInt32Array = PackedInt32Array([edge.x, edge.y, duplicate_b, duplicate_a])
		var adjacent: PackedInt32Array = edge_faces.get(edge, PackedInt32Array())
		if not adjacent.is_empty():
			var target_normal: Vector3 = mesh.get_face_normal(adjacent[0]).cross(
				(mesh.vertices[edge.y] - mesh.vertices[edge.x]).normalized()
			)
			if _polygon_normal(result.vertices, face).dot(target_normal) < 0.0:
				face.reverse()
		new_faces.append(result.faces.size())
		result.faces.append(face)
		result.face_materials.append(mesh.get_face_material(adjacent[0]) if not adjacent.is_empty() else 0)
		result.smooth_faces.append(0)
		new_edge_keys[GMSMeshData.canonical_edge(duplicate_a, duplicate_b)] = true


	for selected_edge: Vector2i in selected_edges:
		var loose_index: int = result.loose_edges.find(selected_edge)
		if loose_index >= 0:
			result.loose_edges.remove_at(loose_index)
	result.invalidate_custom_normals()
	result.set_geometry(
		result.vertices,
		result.faces,
		result.smooth_faces,
		result.uv_faces,
		mesh.has_uv_map,
		result.corner_normals,
		false,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		result.face_materials
	)
	if mesh.has_uv_map and not new_faces.is_empty():
		result = GMSUVOperations.project_box(result, new_faces)
	return {
		"mesh": result,
		"face_indices": new_faces,
		"vertex_indices": new_vertices,
		"edge_indices": _edge_indices_from_keys(result, new_edge_keys),
	}


static func bevel_edges(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array,
	width: float
) -> Dictionary:
	var edges: Array[Vector2i] = mesh.get_edges()
	var selected: PackedInt32Array = _unique_valid_indices(edge_indices, edges.size())
	var selected_keys: Dictionary = {}
	var edge_faces: Dictionary = _build_edge_faces(mesh)
	for edge_index: int in selected:
		var edge: Vector2i = edges[edge_index]
		if edge_faces.has(edge):
			selected_keys[edge] = true
	if selected_keys.is_empty() or width <= 0.0:
		return {"mesh": mesh.duplicate_mesh_data(), "face_indices": PackedInt32Array()}




	var output_vertices: PackedVector3Array = mesh.vertices.duplicate()
	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_materials: PackedInt32Array = PackedInt32Array()
	var side_records: Dictionary = {}
	var vertex_points: Dictionary = {}
	var selected_incident_counts: Dictionary = {}
	var shared_edge_points: Dictionary = {}

	for edge_value: Variant in selected_keys.keys():
		var selected_edge: Vector2i = edge_value
		selected_incident_counts[selected_edge.x] = int(
			selected_incident_counts.get(selected_edge.x, 0)
		) + 1
		selected_incident_counts[selected_edge.y] = int(
			selected_incident_counts.get(selected_edge.y, 0)
		) + 1

	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		var rebuilt: PackedInt32Array = PackedInt32Array()
		var corner_outputs: PackedInt32Array = PackedInt32Array()
		corner_outputs.resize(face.size())

		for corner_index: int in face.size():
			var previous: int = face[(corner_index - 1 + face.size()) % face.size()]
			var current: int = face[corner_index]
			var next: int = face[(corner_index + 1) % face.size()]
			var previous_selected: bool = selected_keys.has(
				GMSMeshData.canonical_edge(previous, current)
			)
			var next_selected: bool = selected_keys.has(
				GMSMeshData.canonical_edge(current, next)
			)
			var output_index: int = current

			if previous_selected and next_selected:
				output_index = output_vertices.size()
				output_vertices.append(_bevel_face_corner_point(
					mesh.vertices[current],
					mesh.vertices[previous],
					mesh.vertices[next],
					width
				))
			elif previous_selected:
				var previous_key: Vector2i = Vector2i(current, next)
				if shared_edge_points.has(previous_key):
					output_index = int(shared_edge_points[previous_key])
				else:
					output_index = output_vertices.size()
					output_vertices.append(_point_along_edge(
						mesh.vertices[current],
						mesh.vertices[next],
						width
					))
					shared_edge_points[previous_key] = output_index
			elif next_selected:
				var next_key: Vector2i = Vector2i(current, previous)
				if shared_edge_points.has(next_key):
					output_index = int(shared_edge_points[next_key])
				else:
					output_index = output_vertices.size()
					output_vertices.append(_point_along_edge(
						mesh.vertices[current],
						mesh.vertices[previous],
						width
					))
					shared_edge_points[next_key] = output_index

			rebuilt.append(output_index)
			corner_outputs[corner_index] = output_index
			if previous_selected or next_selected:
				_append_dictionary_array(vertex_points, current, output_index)

		if _unique_vertex_count(rebuilt) >= 3:
			output_faces.append(rebuilt)
			output_smooth.append(mesh.smooth_faces[face_index])
			output_materials.append(mesh.get_face_material(face_index))

		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var edge: Vector2i = GMSMeshData.canonical_edge(a, b)
			if not selected_keys.has(edge):
				continue
			var records: Array = side_records.get(edge, [])
			records.append({
				"face": face_index,
				"a": corner_outputs[corner_index] if a == edge.x else corner_outputs[(corner_index + 1) % face.size()],
				"b": corner_outputs[(corner_index + 1) % face.size()] if b == edge.y else corner_outputs[corner_index],
			})
			side_records[edge] = records

	var created_faces: PackedInt32Array = PackedInt32Array()
	for edge_value: Variant in selected_keys.keys():
		var edge: Vector2i = edge_value
		var records: Array = side_records.get(edge, [])
		if records.is_empty():
			continue
		var first: Dictionary = records[0]
		var bevel_face: PackedInt32Array = PackedInt32Array()
		if records.size() >= 2:
			var second: Dictionary = records[1]
			bevel_face = PackedInt32Array([
				int(first["a"]),
				int(first["b"]),
				int(second["b"]),
				int(second["a"]),
			])
			var target_normal: Vector3 = (
				mesh.get_face_normal(int(first["face"]))
				+ mesh.get_face_normal(int(second["face"]))
			)
			if _polygon_normal(output_vertices, bevel_face).dot(target_normal) < 0.0:
				bevel_face.reverse()
		else:
			bevel_face = PackedInt32Array([
				edge.x,
				edge.y,
				int(first["b"]),
				int(first["a"]),
			])
		if _unique_vertex_count(bevel_face) >= 3:
			created_faces.append(output_faces.size())
			output_faces.append(bevel_face)
			output_smooth.append(1)
			output_materials.append(mesh.get_face_material(int(first["face"])))



	for vertex_value: Variant in vertex_points.keys():
		var vertex_index: int = int(vertex_value)
		var points: PackedInt32Array = _unique_packed(vertex_points[vertex_index])
		var selected_incident: int = int(selected_incident_counts.get(vertex_index, 0))
		if selected_incident == 1:
			points.append(vertex_index)
			points = _unique_packed(points)
		if points.size() < 3:
			continue
		var cap_normal: Vector3 = _average_incident_face_normal(mesh, vertex_index)
		var cap: PackedInt32Array = _sort_vertices_around_point(
			output_vertices,
			points,
			mesh.vertices[vertex_index],
			cap_normal
		)
		if _polygon_normal(output_vertices, cap).dot(cap_normal) < 0.0:
			cap.reverse()
		created_faces.append(output_faces.size())
		output_faces.append(cap)
		output_smooth.append(1)
		var cap_material: int = 0
		for source_face_index: int in mesh.faces.size():
			if mesh.faces[source_face_index].has(vertex_index):
				cap_material = mesh.get_face_material(source_face_index)
				break
		output_materials.append(cap_material)

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		[],
		false,
		[],
		false,
		mesh.loose_edges,
		_filter_crease_edges(mesh, selected_keys),
		_filter_crease_weights(mesh, selected_keys),
		_filter_seam_edges(mesh, selected_keys),
		output_materials
	)
	result = _compact_mesh(result)
	if mesh.has_uv_map:
		result = GMSUVOperations.project_box(result, GMSUVOperations.all_faces(result))
	return {"mesh": result, "face_indices": created_faces}


static func bevel_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array,
	width: float
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	var selected_set: Dictionary = {}
	for vertex_index: int in selected:
		selected_set[vertex_index] = true
	if selected.is_empty() or width <= 0.0:
		return {"mesh": mesh.duplicate_mesh_data(), "face_indices": PackedInt32Array()}

	var output_vertices: PackedVector3Array = mesh.vertices.duplicate()
	var offset_vertices: Dictionary = {}
	var cap_points: Dictionary = {}


	for face: PackedInt32Array in mesh.faces:
		for corner_index: int in face.size():
			var current: int = face[corner_index]
			if not selected_set.has(current):
				continue
			for neighbor: int in PackedInt32Array([
				face[(corner_index - 1 + face.size()) % face.size()],
				face[(corner_index + 1) % face.size()],
			]):
				var key: Vector2i = Vector2i(current, neighbor)
				if offset_vertices.has(key):
					continue
				var output_index: int = output_vertices.size()
				output_vertices.append(_point_along_edge(
					mesh.vertices[current], mesh.vertices[neighbor], width
				))
				offset_vertices[key] = output_index
				_append_dictionary_array(cap_points, current, output_index)

	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		var rebuilt: PackedInt32Array = PackedInt32Array()
		for corner_index: int in face.size():
			var current: int = face[corner_index]
			if not selected_set.has(current):
				rebuilt.append(current)
				continue
			var previous: int = face[(corner_index - 1 + face.size()) % face.size()]
			var next: int = face[(corner_index + 1) % face.size()]
			rebuilt.append(int(offset_vertices[Vector2i(current, previous)]))
			rebuilt.append(int(offset_vertices[Vector2i(current, next)]))
		if _unique_vertex_count(rebuilt) >= 3:
			output_faces.append(rebuilt)
			output_smooth.append(mesh.smooth_faces[face_index])
			output_materials.append(mesh.get_face_material(face_index))

	var created_faces: PackedInt32Array = PackedInt32Array()
	for vertex_index: int in selected:
		var points: PackedInt32Array = _unique_packed(cap_points.get(vertex_index, PackedInt32Array()))
		if points.size() < 3:
			continue
		var target_normal: Vector3 = _average_incident_face_normal(mesh, vertex_index)
		var cap: PackedInt32Array = _sort_vertices_around_point(
			output_vertices,
			points,
			mesh.vertices[vertex_index],
			target_normal
		)
		if _polygon_normal(output_vertices, cap).dot(target_normal) < 0.0:
			cap.reverse()
		created_faces.append(output_faces.size())
		output_faces.append(cap)
		output_smooth.append(1)
		var cap_material: int = 0
		for source_face_index: int in mesh.faces.size():
			if mesh.faces[source_face_index].has(vertex_index):
				cap_material = mesh.get_face_material(source_face_index)
				break
		output_materials.append(cap_material)

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		[],
		false,
		[],
		false,
		mesh.loose_edges,
		[],
		PackedFloat32Array(),
		[],
		output_materials
	)
	result = _compact_mesh(result)
	if mesh.has_uv_map:
		result = GMSUVOperations.project_box(result, GMSUVOperations.all_faces(result))
	return {"mesh": result, "face_indices": created_faces}


static func dissolve_edges(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array
) -> Dictionary:
	var source_edges: Array[Vector2i] = mesh.get_edges()
	var selected: PackedInt32Array = _unique_valid_indices(edge_indices, source_edges.size())
	var selected_pairs: Array[Vector2i] = []
	for edge_index: int in selected:
		selected_pairs.append(source_edges[edge_index])
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var changed: bool = false

	for edge: Vector2i in selected_pairs:
		var loose_index: int = result.loose_edges.find(edge)
		if loose_index >= 0:
			result.loose_edges.remove_at(loose_index)
			changed = true
			continue
		var adjacent: PackedInt32Array = _build_edge_faces(result).get(edge, PackedInt32Array())
		if adjacent.size() != 2:
			continue
		var merged: PackedInt32Array = _merge_face_boundaries(
			result.faces[adjacent[0]],
			result.faces[adjacent[1]],
			edge
		)
		if merged.size() < 3:
			continue
		var first: int = mini(adjacent[0], adjacent[1])
		var second: int = maxi(adjacent[0], adjacent[1])
		result.faces[first] = merged
		result.smooth_faces[first] = (
			1 if result.smooth_faces[first] != 0 and result.smooth_faces[second] != 0 else 0
		)
		result.faces.remove_at(second)
		result.smooth_faces.remove_at(second)
		result.face_materials.remove_at(second)
		changed = true

	if changed:
		result.invalidate_uvs()
		result.invalidate_custom_normals()
		result.crease_edges.clear()
		result.crease_weights.clear()
		result = _compact_mesh(result)
	return {"mesh": result, "changed": changed}


static func dissolve_vertices(
	mesh: GMSMeshData,
	vertex_indices: PackedInt32Array
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(vertex_indices, mesh.vertices.size())
	selected.sort()
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var changed: bool = false


	for vertex_index: int in selected:
		if vertex_index < 0 or vertex_index >= result.vertices.size():
			continue
		var incident: PackedInt32Array = PackedInt32Array()
		for face_index: int in result.faces.size():
			if result.faces[face_index].has(vertex_index):
				incident.append(face_index)
		if incident.size() >= 2:
			var boundary_edges: Array[Vector2i] = []
			var counts: Dictionary = {}
			for face_index: int in incident:
				var face: PackedInt32Array = result.faces[face_index]
				for corner_index: int in face.size():
					var a: int = face[corner_index]
					var b: int = face[(corner_index + 1) % face.size()]
					if a == vertex_index or b == vertex_index:
						continue
					var edge: Vector2i = GMSMeshData.canonical_edge(a, b)
					counts[edge] = int(counts.get(edge, 0)) + 1
			for edge_value: Variant in counts.keys():
				if int(counts[edge_value]) == 1:
					boundary_edges.append(edge_value)
			var loops: Array[PackedInt32Array] = _build_edge_chains(boundary_edges, true)
			if loops.size() == 1 and loops[0].size() >= 3:
				var remove_set: Dictionary = {}
				for face_index: int in incident:
					remove_set[face_index] = true
				var rebuilt_faces: Array[PackedInt32Array] = []
				var rebuilt_smooth: PackedByteArray = PackedByteArray()
				var rebuilt_materials: PackedInt32Array = PackedInt32Array()
				for face_index: int in result.faces.size():
					if remove_set.has(face_index):
						continue
					rebuilt_faces.append(result.faces[face_index].duplicate())
					rebuilt_smooth.append(result.smooth_faces[face_index])
					rebuilt_materials.append(result.get_face_material(face_index))
				rebuilt_faces.append(loops[0])
				rebuilt_smooth.append(0)
				rebuilt_materials.append(result.get_face_material(incident[0]))
				result.faces = rebuilt_faces
				result.smooth_faces = rebuilt_smooth
				result.face_materials = rebuilt_materials
				changed = true
				continue

		for face_index: int in range(result.faces.size() - 1, -1, -1):
			var face: PackedInt32Array = result.faces[face_index]
			var position: int = face.find(vertex_index)
			if position < 0:
				continue
			if face.size() <= 3:
				result.faces.remove_at(face_index)
				result.smooth_faces.remove_at(face_index)
				result.face_materials.remove_at(face_index)
			else:
				face.remove_at(position)
				result.faces[face_index] = face
			changed = true
		var loose_neighbors: PackedInt32Array = PackedInt32Array()
		for edge_index: int in range(result.loose_edges.size() - 1, -1, -1):
			var edge: Vector2i = result.loose_edges[edge_index]
			if edge.x == vertex_index:
				loose_neighbors.append(edge.y)
				result.loose_edges.remove_at(edge_index)
			elif edge.y == vertex_index:
				loose_neighbors.append(edge.x)
				result.loose_edges.remove_at(edge_index)
		if loose_neighbors.size() == 2:
			result.loose_edges.append(GMSMeshData.canonical_edge(loose_neighbors[0], loose_neighbors[1]))
			changed = true

	if changed:
		result.invalidate_uvs()
		result.invalidate_custom_normals()
		result.crease_edges.clear()
		result.crease_weights.clear()
		result = _compact_mesh(result)
	return {"mesh": result, "changed": changed}


static func dissolve_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	var selected_set: Dictionary = {}
	for face_index: int in selected:
		selected_set[face_index] = true
	if selected.is_empty():
		return {"mesh": mesh.duplicate_mesh_data(), "face_indices": PackedInt32Array()}

	var edge_counts: Dictionary = {}
	var directed_edges: Array[Vector2i] = []
	for face_index: int in selected:
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var directed: Vector2i = Vector2i(face[corner_index], face[(corner_index + 1) % face.size()])
			var key: Vector2i = GMSMeshData.canonical_edge(directed.x, directed.y)
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
			directed_edges.append(directed)
	var boundary_directed: Array[Vector2i] = []
	for directed: Vector2i in directed_edges:
		if int(edge_counts[GMSMeshData.canonical_edge(directed.x, directed.y)]) == 1:
			boundary_directed.append(directed)
	var loops: Array[PackedInt32Array] = _build_directed_loops(boundary_directed)
	if loops.is_empty():
		return {"mesh": mesh.duplicate_mesh_data(), "face_indices": PackedInt32Array()}

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var rebuilt_faces: Array[PackedInt32Array] = []
	var rebuilt_smooth: PackedByteArray = PackedByteArray()
	var rebuilt_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		if selected_set.has(face_index):
			continue
		rebuilt_faces.append(mesh.faces[face_index].duplicate())
		rebuilt_smooth.append(mesh.smooth_faces[face_index])
		rebuilt_materials.append(mesh.get_face_material(face_index))
	var new_faces: PackedInt32Array = PackedInt32Array()
	for loop: PackedInt32Array in loops:
		if loop.size() < 3:
			continue
		new_faces.append(rebuilt_faces.size())
		rebuilt_faces.append(loop)
		rebuilt_smooth.append(0)
		rebuilt_materials.append(mesh.get_face_material(selected[0]))
	result.faces = rebuilt_faces
	result.smooth_faces = rebuilt_smooth
	result.face_materials = rebuilt_materials
	result.invalidate_uvs()
	result.invalidate_custom_normals()
	result.crease_edges.clear()
	result.crease_weights.clear()
	result = _compact_mesh(result)
	return {"mesh": result, "face_indices": new_faces}


static func bridge_edge_loops(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array
) -> Dictionary:
	var edges: Array[Vector2i] = mesh.get_edges()
	var selected: PackedInt32Array = _unique_valid_indices(edge_indices, edges.size())
	var selected_edges: Array[Vector2i] = []
	for edge_index: int in selected:
		selected_edges.append(edges[edge_index])

	var loops: Array[PackedInt32Array] = _build_edge_chains(selected_edges, false)
	if loops.size() != 2 or loops[0].size() < 2 or loops[0].size() != loops[1].size():
		return {
			"mesh": mesh.duplicate_mesh_data(),
			"face_indices": PackedInt32Array(),
			"reason": "Bridge requires exactly two separate edge loops or chains with matching vertex counts.",
		}

	var first_closed: bool = _chain_is_closed(selected_edges, loops[0])
	var second_closed: bool = _chain_is_closed(selected_edges, loops[1])
	if first_closed != second_closed:
		return {
			"mesh": mesh.duplicate_mesh_data(),
			"face_indices": PackedInt32Array(),
			"reason": "Both bridge selections must be either closed loops or open chains.",
		}

	var first: PackedInt32Array = loops[0]
	var second: PackedInt32Array = _best_loop_alignment(
		mesh.vertices, first, loops[1], first_closed
	)
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var edge_faces: Dictionary = _build_edge_faces(mesh)
	var new_faces: PackedInt32Array = PackedInt32Array()
	var combined_center: Vector3 = Vector3.ZERO
	for vertex_index: int in first:
		combined_center += mesh.vertices[vertex_index]
	for vertex_index: int in second:
		combined_center += mesh.vertices[vertex_index]
	combined_center /= float(first.size() + second.size())

	var segment_count: int = first.size() if first_closed else first.size() - 1
	for index: int in segment_count:
		var next: int = (index + 1) % first.size()
		var quad: PackedInt32Array = PackedInt32Array([
			first[index], first[next], second[next], second[index],
		])
		var quad_center: Vector3 = Vector3.ZERO
		for vertex_index: int in quad:
			quad_center += result.vertices[vertex_index]
		quad_center /= 4.0
		if _polygon_normal(result.vertices, quad).dot(quad_center - combined_center) < 0.0:
			quad.reverse()
		new_faces.append(result.faces.size())
		result.faces.append(quad)
		var source_edge: Vector2i = GMSMeshData.canonical_edge(first[index], first[next])
		var attached_faces: PackedInt32Array = edge_faces.get(source_edge, PackedInt32Array())
		if attached_faces.is_empty():
			source_edge = GMSMeshData.canonical_edge(second[index], second[next])
			attached_faces = edge_faces.get(source_edge, PackedInt32Array())
		var bridge_material: int = mesh.get_face_material(attached_faces[0]) if not attached_faces.is_empty() else 0
		result.face_materials.append(bridge_material)
		result.smooth_faces.append(1)

	result.invalidate_custom_normals()
	result.set_geometry(
		result.vertices,
		result.faces,
		result.smooth_faces,
		result.uv_faces,
		result.has_uv_map,
		result.corner_normals,
		false,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		result.face_materials
	)
	if mesh.has_uv_map and not new_faces.is_empty():
		result = GMSUVOperations.project_box(result, new_faces)
	return {
		"mesh": result,
		"face_indices": new_faces,
		"reason": "",
	}


static func fill_holes(
	mesh: GMSMeshData,
	edge_indices: PackedInt32Array = PackedInt32Array()
) -> Dictionary:
	var topology: GMSTopology = mesh.get_topology()
	var all_edges: Array[Vector2i] = mesh.get_edges()
	var selected_edges: Dictionary = {}
	for edge_index: int in _unique_valid_indices(edge_indices, all_edges.size()):
		selected_edges[all_edges[edge_index]] = true
	var boundary_loops: Array[PackedInt32Array] = topology.get_boundary_loops()
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var new_faces: PackedInt32Array = PackedInt32Array()
	for loop: PackedInt32Array in boundary_loops:
		if loop.size() < 3:
			continue
		if not selected_edges.is_empty():
			var complete_selection: bool = true
			for index: int in loop.size():
				var edge: Vector2i = GMSMeshData.canonical_edge(
					loop[index], loop[(index + 1) % loop.size()]
				)
				if not selected_edges.has(edge):
					complete_selection = false
					break
			if not complete_selection:
				continue
		var fill_material: int = 0
		var boundary_edge: Vector2i = GMSMeshData.canonical_edge(loop[0], loop[1])
		var boundary_faces: PackedInt32Array = topology.get_edge_faces(boundary_edge)
		if not boundary_faces.is_empty():
			fill_material = mesh.get_face_material(boundary_faces[0])
		var center: Vector3 = Vector3.ZERO
		for vertex_index: int in loop:
			center += result.vertices[vertex_index]
		center /= float(loop.size())
		var center_index: int = result.vertices.size()
		result.vertices.append(center)
		for index: int in loop.size():
			var next: int = (index + 1) % loop.size()
			new_faces.append(result.faces.size())
			result.faces.append(PackedInt32Array([loop[index], loop[next], center_index]))
			result.face_materials.append(fill_material)
			result.smooth_faces.append(0)
	result.invalidate_custom_normals()
	result.set_geometry(
		result.vertices,
		result.faces,
		result.smooth_faces,
		result.uv_faces,
		mesh.has_uv_map,
		[],
		false,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		result.face_materials
	)
	if mesh.has_uv_map and not new_faces.is_empty():
		result = GMSUVOperations.project_box(result, new_faces)
	return {"mesh": result, "face_indices": new_faces}


static func knife_cut_face(
	mesh: GMSMeshData,
	face_index: int,
	start_point: Vector3,
	end_point: Vector3
) -> Dictionary:
	var unchanged: Dictionary = {
		"mesh": mesh.duplicate_mesh_data(),
		"face_indices": PackedInt32Array(),
		"vertex_indices": PackedInt32Array(),
	}
	if face_index < 0 or face_index >= mesh.faces.size():
		return unchanged
	var face: PackedInt32Array = mesh.faces[face_index]
	if face.size() < 3:
		return unchanged
	var start_data: Dictionary = _closest_face_edge_point(mesh, face_index, start_point)
	var end_data: Dictionary = _closest_face_edge_point(mesh, face_index, end_point)
	if start_data.is_empty() or end_data.is_empty():
		return unchanged
	if int(start_data["edge_position"]) == int(end_data["edge_position"]):
		return unchanged

	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var source_uvs: PackedVector2Array = PackedVector2Array()
	if mesh.has_uv_map:
		source_uvs = mesh.uv_faces[face_index].duplicate()
	var insert_data: Dictionary = {}
	var insert_uv_data: Dictionary = {}
	var new_vertices: PackedInt32Array = PackedInt32Array()
	for data_value: Variant in [start_data, end_data]:
		var data: Dictionary = data_value
		var edge_position: int = int(data["edge_position"])
		var t: float = float(data["t"])
		var vertex_index: int
		var point_uv: Vector2 = Vector2.ZERO
		if mesh.has_uv_map:
			point_uv = source_uvs[edge_position].lerp(
				source_uvs[(edge_position + 1) % source_uvs.size()],
				t
			)
		if t <= 0.0001:
			vertex_index = face[edge_position]
		elif t >= 0.9999:
			vertex_index = face[(edge_position + 1) % face.size()]
		else:
			vertex_index = result.vertices.size()
			result.vertices.append(data["point"])
			new_vertices.append(vertex_index)
		insert_data[edge_position] = vertex_index
		insert_uv_data[edge_position] = point_uv

	var augmented: PackedInt32Array = PackedInt32Array()
	var augmented_uv: PackedVector2Array = PackedVector2Array()
	for corner_index: int in face.size():
		augmented.append(face[corner_index])
		if mesh.has_uv_map:
			augmented_uv.append(source_uvs[corner_index])
		if insert_data.has(corner_index):
			var inserted: int = int(insert_data[corner_index])
			if inserted != face[corner_index] and inserted != face[(corner_index + 1) % face.size()]:
				augmented.append(inserted)
				if mesh.has_uv_map:
					augmented_uv.append(insert_uv_data[corner_index])
	var first_vertex: int = int(insert_data[int(start_data["edge_position"])])
	var second_vertex: int = int(insert_data[int(end_data["edge_position"])])
	if first_vertex == second_vertex:
		return unchanged
	var first_position: int = augmented.find(first_vertex)
	var second_position: int = augmented.find(second_vertex)
	if first_position < 0 or second_position < 0:
		return unchanged
	var first_loop: PackedInt32Array = _loop_slice(augmented, first_position, second_position)
	var second_loop: PackedInt32Array = _loop_slice(augmented, second_position, first_position)
	if _unique_vertex_count(first_loop) < 3 or _unique_vertex_count(second_loop) < 3:
		return unchanged

	result.faces[face_index] = first_loop
	result.faces.insert(face_index + 1, second_loop)
	result.face_materials.insert(face_index + 1, result.get_face_material(face_index))
	var smooth_value: int = result.smooth_faces[face_index]
	result.smooth_faces.insert(face_index + 1, smooth_value)
	if mesh.has_uv_map:
		var first_uv: PackedVector2Array = _loop_slice_uv(
			augmented_uv, first_position, second_position
		)
		var second_uv: PackedVector2Array = _loop_slice_uv(
			augmented_uv, second_position, first_position
		)
		result.uv_faces[face_index] = first_uv
		result.uv_faces.insert(face_index + 1, second_uv)
		result.has_uv_map = true
	else:
		result.invalidate_uvs()
	result.invalidate_custom_normals()
	result.crease_edges.clear()
	result.crease_weights.clear()
	return {
		"mesh": result,
		"face_indices": PackedInt32Array([face_index, face_index + 1]),
		"vertex_indices": new_vertices,
	}


static func loop_cut_multiple(
	mesh: GMSMeshData,
	edge_index: int,
	cuts: int,
	slide: float
) -> Dictionary:
	var unchanged: Dictionary = {
		"mesh": mesh.duplicate_mesh_data(),
		"edge_indices": PackedInt32Array(),
	}
	var edges: Array[Vector2i] = mesh.get_edges()
	if edge_index < 0 or edge_index >= edges.size():
		return unchanged
	var ring_indices: PackedInt32Array = GMSMeshOperations.get_edge_ring(mesh, edge_index)
	if ring_indices.is_empty():
		return unchanged
	var cut_count: int = clampi(cuts, 1, 16)
	var ring_keys: Dictionary = {}
	for ring_index: int in ring_indices:
		if ring_index >= 0 and ring_index < edges.size():
			ring_keys[edges[ring_index]] = true

	for face: PackedInt32Array in mesh.faces:
		var positions: PackedInt32Array = PackedInt32Array()
		for corner_index: int in face.size():
			if ring_keys.has(GMSMeshData.canonical_edge(
				face[corner_index], face[(corner_index + 1) % face.size()]
			)):
				positions.append(corner_index)
		if positions.is_empty():
			continue
		if face.size() != 4 or positions.size() != 2:
			return unchanged
		if (positions[0] + 2) % 4 != positions[1]:
			return unchanged

	var parameters: PackedFloat32Array = PackedFloat32Array()
	var spacing: float = 1.0 / float(cut_count + 1)
	for cut_index: int in cut_count:
		parameters.append(clampf(
			float(cut_index + 1) * spacing + clampf(slide, -0.95, 0.95) * spacing,
			0.001,
			0.999
		))
	parameters.sort()

	var output_vertices: PackedVector3Array = mesh.vertices.duplicate()
	var edge_cut_vertices: Dictionary = {}
	for ring_index: int in ring_indices:
		var edge: Vector2i = edges[ring_index]
		var cuts_for_edge: PackedInt32Array = PackedInt32Array()
		for parameter: float in parameters:
			cuts_for_edge.append(output_vertices.size())
			output_vertices.append(mesh.vertices[edge.x].lerp(mesh.vertices[edge.y], parameter))
		edge_cut_vertices[edge] = cuts_for_edge

	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_materials: PackedInt32Array = PackedInt32Array()
	var selected_keys: Dictionary = {}
	for face_index: int in mesh.faces.size():
		var face: PackedInt32Array = mesh.faces[face_index]
		var positions: PackedInt32Array = PackedInt32Array()
		for corner_index: int in face.size():
			if edge_cut_vertices.has(GMSMeshData.canonical_edge(
				face[corner_index], face[(corner_index + 1) % face.size()]
			)):
				positions.append(corner_index)
		if positions.is_empty():
			output_faces.append(face.duplicate())
			output_smooth.append(mesh.smooth_faces[face_index])
			output_materials.append(mesh.get_face_material(face_index))
			continue
		var start: int = positions[0]
		if (start + 2) % 4 != positions[1]:
			start = positions[1]
		var v0: int = face[start]
		var v1: int = face[(start + 1) % 4]
		var v2: int = face[(start + 2) % 4]
		var v3: int = face[(start + 3) % 4]
		var edge_a: Vector2i = GMSMeshData.canonical_edge(v0, v1)
		var edge_b: Vector2i = GMSMeshData.canonical_edge(v2, v3)
		var cuts_a: PackedInt32Array = _ordered_edge_cuts(edge_cut_vertices[edge_a], edge_a, v0, v1)
		var cuts_b: PackedInt32Array = _ordered_edge_cuts(edge_cut_vertices[edge_b], edge_b, v3, v2)
		var side_a: PackedInt32Array = PackedInt32Array([v0])
		side_a.append_array(cuts_a)
		side_a.append(v1)
		var side_b: PackedInt32Array = PackedInt32Array([v3])
		side_b.append_array(cuts_b)
		side_b.append(v2)
		for strip_index: int in range(side_a.size() - 1):
			output_faces.append(PackedInt32Array([
				side_a[strip_index],
				side_a[strip_index + 1],
				side_b[strip_index + 1],
				side_b[strip_index],
			]))
			output_smooth.append(mesh.smooth_faces[face_index])
			output_materials.append(mesh.get_face_material(face_index))
		if cuts_a.size() == cuts_b.size():
			for cut_index: int in cuts_a.size():
				selected_keys[GMSMeshData.canonical_edge(cuts_a[cut_index], cuts_b[cut_index])] = true

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		[],
		false,
		[],
		false,
		mesh.loose_edges,
		mesh.crease_edges,
		mesh.crease_weights,
		mesh.seam_edges,
		output_materials
	)
	if mesh.has_uv_map:
		result = GMSUVOperations.project_box(result, GMSUVOperations.all_faces(result))
	return {"mesh": result, "edge_indices": _edge_indices_from_keys(result, selected_keys)}


static func separate_faces(
	mesh: GMSMeshData,
	face_indices: PackedInt32Array
) -> Dictionary:
	var selected: PackedInt32Array = _unique_valid_indices(face_indices, mesh.faces.size())
	var selected_set: Dictionary = {}
	for face_index: int in selected:
		selected_set[face_index] = true
	if selected.is_empty():
		return {"source_mesh": mesh.duplicate_mesh_data(), "separated_mesh": null}

	var source_faces: Array[PackedInt32Array] = []
	var source_smooth: PackedByteArray = PackedByteArray()
	var source_uvs: Array[PackedVector2Array] = []
	var source_normals: Array[PackedVector3Array] = []
	var source_materials: PackedInt32Array = PackedInt32Array()
	var separated_faces: Array[PackedInt32Array] = []
	var separated_smooth: PackedByteArray = PackedByteArray()
	var separated_uvs: Array[PackedVector2Array] = []
	var separated_normals: Array[PackedVector3Array] = []
	var separated_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		if selected_set.has(face_index):
			separated_faces.append(mesh.faces[face_index].duplicate())
			separated_smooth.append(mesh.smooth_faces[face_index])
			separated_uvs.append(mesh.uv_faces[face_index].duplicate())
			separated_normals.append(mesh.corner_normals[face_index].duplicate())
			separated_materials.append(mesh.get_face_material(face_index))
		else:
			source_faces.append(mesh.faces[face_index].duplicate())
			source_smooth.append(mesh.smooth_faces[face_index])
			source_uvs.append(mesh.uv_faces[face_index].duplicate())
			source_normals.append(mesh.corner_normals[face_index].duplicate())
			source_materials.append(mesh.get_face_material(face_index))

	var source: GMSMeshData = GMSMeshData.new()
	source.set_geometry(
		mesh.vertices,
		source_faces,
		source_smooth,
		source_uvs,
		mesh.has_uv_map,
		source_normals,
		mesh.has_custom_normals,
		mesh.loose_edges,
		mesh.crease_edges,
		mesh.crease_weights,
		mesh.seam_edges,
		source_materials
	)
	source = _compact_mesh(source)

	var separated: GMSMeshData = GMSMeshData.new()
	separated.set_geometry(
		mesh.vertices,
		separated_faces,
		separated_smooth,
		separated_uvs,
		mesh.has_uv_map,
		separated_normals,
		mesh.has_custom_normals,
		[],
		mesh.crease_edges,
		mesh.crease_weights,
		mesh.seam_edges,
		separated_materials
	)
	separated = _compact_mesh(separated)
	return {"source_mesh": source, "separated_mesh": separated}


static func append_mesh(
	base: GMSMeshData,
	other: GMSMeshData,
	other_to_base: Transform3D
) -> GMSMeshData:
	var result: GMSMeshData = base.duplicate_mesh_data()
	var preserve_uvs: bool = base.has_uv_map and other.has_uv_map
	var preserve_normals: bool = base.has_custom_normals and other.has_custom_normals
	var offset: int = result.vertices.size()
	var normal_basis: Basis = other_to_base.basis.inverse().transposed()
	var reverse_winding: bool = other_to_base.basis.determinant() < 0.0
	for vertex: Vector3 in other.vertices:
		result.vertices.append(other_to_base * vertex)
	for face_index: int in other.faces.size():
		var face: PackedInt32Array = PackedInt32Array()
		for vertex_index: int in other.faces[face_index]:
			face.append(vertex_index + offset)
		if reverse_winding:
			face.reverse()
		result.faces.append(face)
		result.smooth_faces.append(other.smooth_faces[face_index])
		result.face_materials.append(other.get_face_material(face_index))
		if preserve_uvs:
			var joined_uvs: PackedVector2Array = other.uv_faces[face_index].duplicate()
			if reverse_winding:
				joined_uvs.reverse()
			result.uv_faces.append(joined_uvs)
		if preserve_normals:
			var transformed_normals: PackedVector3Array = PackedVector3Array()
			for normal: Vector3 in other.corner_normals[face_index]:
				transformed_normals.append((normal_basis * normal).normalized())
			if reverse_winding:
				transformed_normals.reverse()
			result.corner_normals.append(transformed_normals)
	for edge: Vector2i in other.loose_edges:
		result.loose_edges.append(Vector2i(edge.x + offset, edge.y + offset))
	for crease_index: int in other.crease_edges.size():
		var crease: Vector2i = other.crease_edges[crease_index]
		result.crease_edges.append(Vector2i(crease.x + offset, crease.y + offset))
		result.crease_weights.append(other.crease_weights[crease_index])
	for seam: Vector2i in other.seam_edges:
		result.seam_edges.append(Vector2i(seam.x + offset, seam.y + offset))
	if not preserve_uvs:
		result.invalidate_uvs()
	if not preserve_normals:
		result.invalidate_custom_normals()
	result.set_geometry(
		result.vertices,
		result.faces,
		result.smooth_faces,
		result.uv_faces,
		preserve_uvs,
		result.corner_normals,
		preserve_normals,
		result.loose_edges,
		result.crease_edges,
		result.crease_weights,
		result.seam_edges,
		result.face_materials
	)
	return result


static func calculate_proportional_weights(
	mesh: GMSMeshData,
	selected_vertices: PackedInt32Array,
	radius: float,
	falloff: int
) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	weights.resize(mesh.vertices.size())
	var selected: PackedInt32Array = _unique_valid_indices(selected_vertices, mesh.vertices.size())
	if selected.is_empty():
		return weights
	var actual_radius: float = maxf(radius, 0.000001)
	for vertex_index: int in mesh.vertices.size():
		if selected.has(vertex_index):
			weights[vertex_index] = 1.0
			continue
		var distance: float = INF
		for selected_index: int in selected:
			distance = minf(distance, mesh.vertices[vertex_index].distance_to(mesh.vertices[selected_index]))
		if distance >= actual_radius:
			weights[vertex_index] = 0.0
			continue
		var influence: float = clampf(1.0 - distance / actual_radius, 0.0, 1.0)
		weights[vertex_index] = _falloff_value(influence, falloff)
	return weights


static func translate_vertices_world_weighted(
	mesh: GMSMeshData,
	weights: PackedFloat32Array,
	object_transform: Transform3D,
	offset_world: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in mini(result.vertices.size(), weights.size()):
		var weight: float = weights[vertex_index]
		if weight <= 0.0:
			continue
		var world: Vector3 = object_transform * result.vertices[vertex_index]
		result.vertices[vertex_index] = inverse * (world + offset_world * weight)
	return result


static func rotate_vertices_world_weighted(
	mesh: GMSMeshData,
	weights: PackedFloat32Array,
	object_transform: Transform3D,
	pivot_world: Vector3,
	axis_world: Vector3,
	angle_radians: float
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	if axis_world.is_zero_approx():
		return result
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in mini(result.vertices.size(), weights.size()):
		var weight: float = weights[vertex_index]
		if weight <= 0.0:
			continue
		var rotation: Basis = Basis(axis_world.normalized(), angle_radians * weight)
		var world: Vector3 = object_transform * result.vertices[vertex_index]
		world = pivot_world + rotation * (world - pivot_world)
		result.vertices[vertex_index] = inverse * world
	return result


static func scale_vertices_world_weighted(
	mesh: GMSMeshData,
	weights: PackedFloat32Array,
	object_transform: Transform3D,
	pivot_world: Vector3,
	scale_world: Vector3
) -> GMSMeshData:
	var result: GMSMeshData = mesh.duplicate_mesh_data()
	var inverse: Transform3D = object_transform.affine_inverse()
	for vertex_index: int in mini(result.vertices.size(), weights.size()):
		var weight: float = weights[vertex_index]
		if weight <= 0.0:
			continue
		var effective: Vector3 = Vector3(
			lerpf(1.0, scale_world.x, weight),
			lerpf(1.0, scale_world.y, weight),
			lerpf(1.0, scale_world.z, weight)
		)
		var world: Vector3 = object_transform * result.vertices[vertex_index]
		world = pivot_world + (world - pivot_world) * effective
		result.vertices[vertex_index] = inverse * world
	return result


static func scale_vertices_world_axis_weighted(
	mesh: GMSMeshData,
	weights: PackedFloat32Array,
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
	for vertex_index: int in mini(result.vertices.size(), weights.size()):
		var weight: float = weights[vertex_index]
		if weight <= 0.0:
			continue
		var effective_factor: float = lerpf(1.0, factor, weight)
		var world: Vector3 = object_transform * result.vertices[vertex_index]
		var relative: Vector3 = world - pivot_world
		relative += axis * relative.dot(axis) * (effective_factor - 1.0)
		result.vertices[vertex_index] = inverse * (pivot_world + relative)
	return result


static func _falloff_value(value: float, falloff: int) -> float:
	match falloff:
		ProportionalFalloff.SPHERE:
			return sqrt(maxf(0.0, 2.0 * value - value * value))
		ProportionalFalloff.ROOT:
			return sqrt(value)
		ProportionalFalloff.LINEAR:
			return value
		ProportionalFalloff.CONSTANT:
			return 1.0
		ProportionalFalloff.SHARP:
			return value * value
		_:
			return value * value * (3.0 - 2.0 * value)


static func _average_vertex_normal(mesh: GMSMeshData, vertices: PackedInt32Array) -> Vector3:
	var selected_set: Dictionary = {}
	for vertex_index: int in vertices:
		selected_set[vertex_index] = true
	var normal: Vector3 = Vector3.ZERO
	for face_index: int in mesh.faces.size():
		for vertex_index: int in mesh.faces[face_index]:
			if selected_set.has(vertex_index):
				normal += mesh.get_face_normal(face_index)
				break
	return normal.normalized() if not normal.is_zero_approx() else Vector3.ZERO


static func _average_incident_face_normal(mesh: GMSMeshData, vertex_index: int) -> Vector3:
	var normal: Vector3 = Vector3.ZERO
	for face_index: int in mesh.faces.size():
		if mesh.faces[face_index].has(vertex_index):
			normal += mesh.get_face_normal(face_index)
	return normal.normalized() if not normal.is_zero_approx() else Vector3.UP


static func _face_edge_offset_point(
	point: Vector3,
	other: Vector3,
	face_normal: Vector3,
	width: float
) -> Vector3:
	var edge_direction: Vector3 = (other - point).normalized()
	var inward: Vector3 = edge_direction.cross(face_normal).normalized()
	var maximum: float = point.distance_to(other) * 0.45
	return point + inward * minf(width, maximum)


static func _bevel_face_corner_point(
	point: Vector3,
	previous: Vector3,
	next: Vector3,
	width: float
) -> Vector3:
	var previous_point: Vector3 = _point_along_edge(point, previous, width)
	var next_point: Vector3 = _point_along_edge(point, next, width)
	return point + (previous_point - point) + (next_point - point)


static func _chain_is_closed(
	edges: Array[Vector2i],
	chain: PackedInt32Array
) -> bool:
	if chain.size() < 3:
		return false
	var degree: Dictionary = {}
	var chain_set: Dictionary = {}
	for vertex_index: int in chain:
		chain_set[vertex_index] = true
	for source_edge: Vector2i in edges:
		if not chain_set.has(source_edge.x) or not chain_set.has(source_edge.y):
			continue
		degree[source_edge.x] = int(degree.get(source_edge.x, 0)) + 1
		degree[source_edge.y] = int(degree.get(source_edge.y, 0)) + 1
	for vertex_index: int in chain:
		if int(degree.get(vertex_index, 0)) != 2:
			return false
	return true


static func _point_along_edge(point: Vector3, other: Vector3, width: float) -> Vector3:
	var length: float = point.distance_to(other)
	if length <= 0.000001:
		return point
	return point.lerp(other, minf(width / length, 0.45))


static func _append_dictionary_array(dictionary: Dictionary, key: Variant, value: int) -> void:
	var values: PackedInt32Array = dictionary.get(key, PackedInt32Array())
	values.append(value)
	dictionary[key] = values


static func _append_edge_record(
	dictionary: Dictionary,
	edge: Vector2i,
	face_index: int,
	source_vertex: int,
	output_vertex: int
) -> void:
	var records: Array = dictionary.get(edge, [])
	var record_index: int = -1
	for index: int in records.size():
		if int(records[index]["face"]) == face_index:
			record_index = index
			break
	if record_index < 0:
		records.append({"face": face_index, "a": -1, "b": -1})
		record_index = records.size() - 1
	var record: Dictionary = records[record_index]
	if source_vertex == edge.x:
		record["a"] = output_vertex
	else:
		record["b"] = output_vertex
	records[record_index] = record
	dictionary[edge] = records


static func _record_endpoints_for_edge(
	records: Array,
	edge: Vector2i,
	record_index: int
) -> Vector2i:
	if record_index < 0 or record_index >= records.size():
		return Vector2i(-1, -1)
	var record: Dictionary = records[record_index]
	return Vector2i(int(record.get("a", -1)), int(record.get("b", -1)))


static func _sort_vertices_around_point(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	normal: Vector3
) -> PackedInt32Array:
	var tangent: Vector3 = normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.000001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	var result: PackedInt32Array = indices.duplicate()
	for first: int in result.size():
		var best: int = first
		var best_angle: float = _angle_around(vertices[result[first]] - center, tangent, bitangent)
		for candidate: int in range(first + 1, result.size()):
			var angle: float = _angle_around(vertices[result[candidate]] - center, tangent, bitangent)
			if angle < best_angle:
				best = candidate
				best_angle = angle
		if best != first:
			var temporary: int = result[first]
			result[first] = result[best]
			result[best] = temporary
	return result


static func _angle_around(relative: Vector3, tangent: Vector3, bitangent: Vector3) -> float:
	return atan2(relative.dot(bitangent), relative.dot(tangent))


static func _polygon_normal(vertices: PackedVector3Array, face: PackedInt32Array) -> Vector3:
	var normal: Vector3 = Vector3.ZERO
	for index: int in face.size():
		var current: Vector3 = vertices[face[index]]
		var next: Vector3 = vertices[face[(index + 1) % face.size()]]
		normal.x += (current.y - next.y) * (current.z + next.z)
		normal.y += (current.z - next.z) * (current.x + next.x)
		normal.z += (current.x - next.x) * (current.y + next.y)
	return normal.normalized() if not normal.is_zero_approx() else Vector3.UP


static func _build_edge_faces(mesh: GMSMeshData) -> Dictionary:
	var topology: GMSTopology = mesh.get_topology()
	var result: Dictionary = {}
	for edge_value: Variant in topology.edge_half_edges.keys():
		var edge: Vector2i = edge_value
		result[edge] = topology.get_edge_faces(edge)
	return result


static func _merge_face_boundaries(
	first: PackedInt32Array,
	second: PackedInt32Array,
	shared: Vector2i
) -> PackedInt32Array:
	var directed: Array[Vector2i] = []
	for face_value: Variant in [first, second]:
		var face: PackedInt32Array = face_value
		for corner_index: int in face.size():
			var edge: Vector2i = Vector2i(face[corner_index], face[(corner_index + 1) % face.size()])
			if GMSMeshData.canonical_edge(edge.x, edge.y) == shared:
				continue
			directed.append(edge)
	var loops: Array[PackedInt32Array] = _build_directed_loops(directed)
	if loops.size() != 1:
		return PackedInt32Array()
	return loops[0]


static func _build_directed_loops(edges: Array[Vector2i]) -> Array[PackedInt32Array]:
	var remaining: Array[Vector2i] = edges.duplicate()
	var loops: Array[PackedInt32Array] = []
	while not remaining.is_empty():
		var first: Vector2i = remaining.pop_back()
		var loop: PackedInt32Array = PackedInt32Array([first.x, first.y])
		var current: int = first.y
		var closed: bool = false
		while not remaining.is_empty():
			var found: int = -1
			for index: int in remaining.size():
				if remaining[index].x == current:
					found = index
					break
			if found < 0:
				break
			var next_edge: Vector2i = remaining[found]
			remaining.remove_at(found)
			if next_edge.y == loop[0]:
				closed = true
				break
			loop.append(next_edge.y)
			current = next_edge.y
		if closed and loop.size() >= 3:
			loops.append(loop)
	return loops


static func _build_edge_chains(
	edges: Array[Vector2i],
	require_closed: bool
) -> Array[PackedInt32Array]:
	var adjacency: Dictionary = {}
	var remaining: Dictionary = {}
	for source_edge: Vector2i in edges:
		if source_edge.x == source_edge.y:
			continue
		var edge: Vector2i = GMSMeshData.canonical_edge(source_edge.x, source_edge.y)
		remaining[edge] = true
		var a_values: PackedInt32Array = adjacency.get(edge.x, PackedInt32Array())
		if not a_values.has(edge.y):
			a_values.append(edge.y)
		adjacency[edge.x] = a_values
		var b_values: PackedInt32Array = adjacency.get(edge.y, PackedInt32Array())
		if not b_values.has(edge.x):
			b_values.append(edge.x)
		adjacency[edge.y] = b_values

	var chains: Array[PackedInt32Array] = []
	while not remaining.is_empty():
		var seed: Vector2i = Vector2i(remaining.keys()[0])
		var component_edges: Dictionary = {}
		var component_vertices: Dictionary = {}
		var pending: PackedInt32Array = PackedInt32Array([seed.x, seed.y])
		while not pending.is_empty():
			var current_vertex: int = pending[pending.size() - 1]
			pending.resize(pending.size() - 1)
			if component_vertices.has(current_vertex):
				continue
			component_vertices[current_vertex] = true
			var neighbors: PackedInt32Array = adjacency.get(
				current_vertex, PackedInt32Array()
			)
			for neighbor: int in neighbors:
				var edge: Vector2i = GMSMeshData.canonical_edge(current_vertex, neighbor)
				if not remaining.has(edge):
					continue
				component_edges[edge] = true
				if not component_vertices.has(neighbor):
					pending.append(neighbor)

		var degree: Dictionary = {}
		var branched: bool = false
		for edge_value: Variant in component_edges.keys():
			var edge: Vector2i = edge_value
			degree[edge.x] = int(degree.get(edge.x, 0)) + 1
			degree[edge.y] = int(degree.get(edge.y, 0)) + 1
		for vertex_value: Variant in component_vertices.keys():
			if int(degree.get(vertex_value, 0)) > 2:
				branched = true
				break



		for edge_value: Variant in component_edges.keys():
			remaining.erase(edge_value)
		if branched or component_edges.is_empty():
			continue

		var start_vertex: int = seed.x
		var endpoint_count: int = 0
		for vertex_value: Variant in component_vertices.keys():
			var vertex_index: int = int(vertex_value)
			if int(degree.get(vertex_index, 0)) == 1:
				endpoint_count += 1
				start_vertex = vertex_index
		var closed: bool = endpoint_count == 0
		if require_closed and not closed:
			continue
		if not closed and endpoint_count != 2:
			continue

		var local_remaining: Dictionary = component_edges.duplicate()
		var chain: PackedInt32Array = PackedInt32Array([start_vertex])
		var current: int = start_vertex
		while not local_remaining.is_empty():
			var next_vertex: int = -1
			var neighbors: PackedInt32Array = adjacency.get(current, PackedInt32Array())
			for candidate: int in neighbors:
				var edge: Vector2i = GMSMeshData.canonical_edge(current, candidate)
				if local_remaining.has(edge):
					next_vertex = candidate
					local_remaining.erase(edge)
					break
			if next_vertex < 0:
				break
			if next_vertex == start_vertex:
				break
			chain.append(next_vertex)
			current = next_vertex

		if not local_remaining.is_empty():
			continue
		if closed and chain.size() >= 3:
			chains.append(chain)
		elif not closed and not require_closed and chain.size() >= 2:
			chains.append(chain)
	return chains


static func _best_loop_alignment(
	vertices: PackedVector3Array,
	first: PackedInt32Array,
	second: PackedInt32Array,
	allow_cyclic_offset: bool = true
) -> PackedInt32Array:
	var best: PackedInt32Array = second.duplicate()
	var best_score: float = INF
	for reverse_value: Variant in [false, true]:
		var candidate: PackedInt32Array = second.duplicate()
		if bool(reverse_value):
			candidate.reverse()
		var offset_count: int = candidate.size() if allow_cyclic_offset else 1
		for offset: int in offset_count:
			var score: float = 0.0
			for index: int in first.size():
				score += vertices[first[index]].distance_squared_to(
					vertices[candidate[(index + offset) % candidate.size()]]
				)
			if score < best_score:
				best_score = score
				best.clear()
				for index: int in candidate.size():
					best.append(candidate[(index + offset) % candidate.size()])
	return best


static func _closest_face_edge_point(
	mesh: GMSMeshData,
	face_index: int,
	point: Vector3
) -> Dictionary:
	var face: PackedInt32Array = mesh.faces[face_index]
	var best_distance: float = INF
	var best: Dictionary = {}
	for corner_index: int in face.size():
		var a: Vector3 = mesh.vertices[face[corner_index]]
		var b: Vector3 = mesh.vertices[face[(corner_index + 1) % face.size()]]
		var direction: Vector3 = b - a
		var denominator: float = direction.length_squared()
		var t: float = 0.0
		if denominator > 0.000001:
			t = clampf((point - a).dot(direction) / denominator, 0.0, 1.0)
		var projected: Vector3 = a + direction * t
		var distance: float = projected.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = {
				"edge_position": corner_index,
				"t": t,
				"point": projected,
			}
	return best


static func _loop_slice(
	loop: PackedInt32Array,
	start: int,
	end: int
) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if loop.is_empty() or start < 0 or end < 0 or start >= loop.size() or end >= loop.size():
		return result
	var index: int = start
	while true:
		result.append(loop[index])
		if index == end:
			break
		index = (index + 1) % loop.size()
		if index == start:
			return PackedInt32Array()
	return result


static func _loop_slice_uv(
	loop: PackedVector2Array,
	start: int,
	end: int
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if loop.is_empty() or start < 0 or end < 0 or start >= loop.size() or end >= loop.size():
		return result
	var index: int = start
	while true:
		result.append(loop[index])
		if index == end:
			break
		index = (index + 1) % loop.size()
		if index == start:
			return PackedVector2Array()
	return result


static func _ordered_edge_cuts(
	cuts: PackedInt32Array,
	canonical_edge: Vector2i,
	start_vertex: int,
	end_vertex: int
) -> PackedInt32Array:
	var result: PackedInt32Array = cuts.duplicate()
	if canonical_edge.x != start_vertex or canonical_edge.y != end_vertex:
		result.reverse()
	return result


static func _compact_mesh(mesh: GMSMeshData) -> GMSMeshData:
	var used: Dictionary = {}
	for face: PackedInt32Array in mesh.faces:
		for vertex_index: int in face:
			used[vertex_index] = true
	for edge: Vector2i in mesh.loose_edges:
		used[edge.x] = true
		used[edge.y] = true
	var mapping: PackedInt32Array = PackedInt32Array()
	mapping.resize(mesh.vertices.size())
	mapping.fill(-1)
	var vertices: PackedVector3Array = PackedVector3Array()
	for old_index: int in mesh.vertices.size():
		if used.has(old_index):
			mapping[old_index] = vertices.size()
			vertices.append(mesh.vertices[old_index])
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var uv_faces: Array[PackedVector2Array] = []
	var normal_faces: Array[PackedVector3Array] = []
	var face_materials: PackedInt32Array = PackedInt32Array()
	for source_face_index: int in mesh.faces.size():
		var source_face: PackedInt32Array = mesh.faces[source_face_index]
		var face: PackedInt32Array = PackedInt32Array()
		for old_index: int in source_face:
			if old_index < 0 or old_index >= mapping.size() or mapping[old_index] < 0:
				face.clear()
				break
			face.append(mapping[old_index])
		if _unique_vertex_count(face) >= 3:
			faces.append(face)
			smooth.append(
				mesh.smooth_faces[source_face_index]
				if source_face_index < mesh.smooth_faces.size()
				else 0
			)
			if mesh.has_uv_map and source_face_index < mesh.uv_faces.size():
				uv_faces.append(mesh.uv_faces[source_face_index].duplicate())
			if mesh.has_custom_normals and source_face_index < mesh.corner_normals.size():
				normal_faces.append(mesh.corner_normals[source_face_index].duplicate())
			face_materials.append(mesh.get_face_material(source_face_index))
	var loose: Array[Vector2i] = []
	for edge: Vector2i in mesh.loose_edges:
		if (
			edge.x >= 0 and edge.x < mapping.size()
			and edge.y >= 0 and edge.y < mapping.size()
			and mapping[edge.x] >= 0 and mapping[edge.y] >= 0
		):
			loose.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
	var creases: Array[Vector2i] = []
	var crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in mesh.crease_edges.size():
		var edge: Vector2i = mesh.crease_edges[crease_index]
		if (
			edge.x >= 0 and edge.x < mapping.size()
			and edge.y >= 0 and edge.y < mapping.size()
			and mapping[edge.x] >= 0 and mapping[edge.y] >= 0
			and crease_index < mesh.crease_weights.size()
		):
			creases.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
			crease_weights.append(mesh.crease_weights[crease_index])
	var seams: Array[Vector2i] = []
	for edge: Vector2i in mesh.seam_edges:
		if (
			edge.x >= 0 and edge.x < mapping.size()
			and edge.y >= 0 and edge.y < mapping.size()
			and mapping[edge.x] >= 0 and mapping[edge.y] >= 0
		):
			seams.append(GMSMeshData.canonical_edge(mapping[edge.x], mapping[edge.y]))
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		vertices,
		faces,
		smooth,
		uv_faces,
		mesh.has_uv_map,
		normal_faces,
		mesh.has_custom_normals,
		loose,
		creases,
		crease_weights,
		seams,
		face_materials
	)
	return result


static func _filter_seam_edges(mesh: GMSMeshData, removed: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge: Vector2i in mesh.seam_edges:
		if not removed.has(edge):
			result.append(edge)
	return result


static func _filter_crease_edges(mesh: GMSMeshData, removed: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge: Vector2i in mesh.crease_edges:
		if not removed.has(edge):
			result.append(edge)
	return result


static func _filter_crease_weights(mesh: GMSMeshData, removed: Dictionary) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	for index: int in mesh.crease_edges.size():
		if not removed.has(mesh.crease_edges[index]):
			result.append(mesh.crease_weights[index])
	return result


static func _edge_indices_from_keys(mesh: GMSMeshData, keys: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var edges: Array[Vector2i] = mesh.get_edges()
	for edge_index: int in edges.size():
		if keys.has(edges[edge_index]):
			result.append(edge_index)
	return result


static func _unique_packed(source: Variant) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for value_variant: Variant in source:
		var value: int = int(value_variant)
		if not result.has(value):
			result.append(value)
	return result


static func _unique_valid_indices(source: PackedInt32Array, count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for index: int in source:
		if index >= 0 and index < count and not result.has(index):
			result.append(index)
	return result


static func _unique_vertex_count(face: PackedInt32Array) -> int:
	var unique: Dictionary = {}
	for vertex_index: int in face:
		unique[vertex_index] = true
	return unique.size()
