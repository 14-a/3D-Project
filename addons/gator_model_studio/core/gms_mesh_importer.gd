@tool
class_name GMSMeshImporter
extends RefCounted







static func import_path(
	path: String,
	job: GMSBackgroundJob = null
) -> Array[GMSModelObject]:
	var result: Array[GMSModelObject] = []
	if path.is_empty():
		return result
	if job != null:
		job.update_progress(0.01, "Loading import resource")
		if job.is_cancelled():
			return result
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded == null or (job != null and job.is_cancelled()):
		return result
	if job != null:
		job.update_progress(0.12, "Converting imported resource")
	return import_resource(loaded, path.get_file().get_basename(), job)


static func import_resource(
	resource: Resource,
	fallback_name: String = "Imported Mesh",
	job: GMSBackgroundJob = null
) -> Array[GMSModelObject]:
	var result: Array[GMSModelObject] = []
	if resource == null or (job != null and job.is_cancelled()):
		return result
	if resource is Mesh:
		var mesh_object: GMSModelObject = mesh_to_object(
			resource as Mesh,
			fallback_name,
			Transform3D.IDENTITY,
			null,
			job,
			0.12,
			1.0
		)
		if mesh_object != null:
			result.append(mesh_object)
		return result
	if resource is ImporterMesh:
		var imported_mesh: ArrayMesh = (resource as ImporterMesh).get_mesh()
		var importer_object: GMSModelObject = mesh_to_object(
			imported_mesh,
			fallback_name,
			Transform3D.IDENTITY,
			null,
			job,
			0.12,
			1.0
		)
		if importer_object != null:
			result.append(importer_object)
		return result
	if resource is PackedScene:
		if job != null:
			job.update_progress(0.14, "Instantiating imported scene")
		var instance: Node = (resource as PackedScene).instantiate()
		if instance == null:
			return result
		var entries: Array[Dictionary] = []
		_capture_mesh_instances(instance, Transform3D.IDENTITY, entries)
		instance.free()
		if job != null and job.is_cancelled():
			return result
		return import_captured_entries(entries, job, 0.16, 1.0)
	if job != null and not job.is_cancelled():
		job.update_progress(1.0, "Import conversion complete")
	return result


static func import_editor_nodes(
	nodes: Array[Node],
	job: GMSBackgroundJob = null
) -> Array[GMSModelObject]:
	return import_captured_entries(capture_editor_nodes(nodes), job)


static func capture_editor_nodes(nodes: Array[Node]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for node: Node in nodes:
		if node == null:
			continue
		var parent_transform: Transform3D = Transform3D.IDENTITY
		if node.get_parent() is Node3D:
			parent_transform = (node.get_parent() as Node3D).global_transform
		_capture_mesh_instances(node, parent_transform, entries)
	return entries


static func import_captured_entries(
	entries: Array[Dictionary],
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Array[GMSModelObject]:
	var result: Array[GMSModelObject] = []
	var entry_count: int = maxi(entries.size(), 1)
	for entry_index: int in entries.size():
		if job != null:
			if job.is_cancelled():
				return result
			job.update_progress(
				lerpf(
					progress_start,
					progress_end,
					float(entry_index) / float(entry_count)
				),
				"Converting selected scene meshes"
			)
		var entry: Dictionary = entries[entry_index]
		var mesh: Mesh = entry.get("mesh") as Mesh
		if mesh == null:
			continue
		var conversion_start: float = lerpf(
			progress_start,
			progress_end,
			float(entry_index) / float(entry_count)
		)
		var conversion_end: float = lerpf(
			progress_start,
			progress_end,
			float(entry_index + 1) / float(entry_count)
		)
		var conversion: Dictionary = mesh_to_mesh_data(mesh, job, conversion_start, conversion_end)
		if job != null and job.is_cancelled():
			return result
		var mesh_data: GMSMeshData = conversion.get("mesh") as GMSMeshData
		if mesh_data == null or not mesh_data.is_valid():
			continue
		var object: GMSModelObject = GMSModelObject.new()
		object.display_name = str(entry.get("name", "Imported Mesh"))
		var transform_value: Variant = entry.get("transform", Transform3D.IDENTITY)
		if transform_value is Transform3D:
			object.transform = transform_value
		else:
			object.transform = Transform3D.IDENTITY
		object.visible = bool(entry.get("visible", true))
		object.mesh_data = mesh_data
		var captured_materials: Array[StandardMaterial3D] = []
		var material_values: Variant = entry.get("materials", [])
		if material_values is Array:
			var material_array: Array = material_values as Array
			for material_value: Variant in material_array:
				if material_value is StandardMaterial3D:
					captured_materials.append(material_value as StandardMaterial3D)
		object.materials = GMSModelObject.duplicate_materials(captured_materials)
		object.active_material_index = 0
		object.ensure_defaults()
		result.append(object)
	if job != null:
		job.update_progress(progress_end, "Scene mesh import complete")
	return result


static func mesh_to_object(
	mesh: Mesh,
	display_name: String,
	object_transform: Transform3D = Transform3D.IDENTITY,
	mesh_instance: MeshInstance3D = null,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> GMSModelObject:
	if mesh == null or mesh.get_surface_count() <= 0:
		return null
	var conversion: Dictionary = mesh_to_mesh_data(mesh, job, progress_start, progress_end)
	var mesh_data: GMSMeshData = conversion.get("mesh") as GMSMeshData
	if mesh_data == null or not mesh_data.is_valid() or (job != null and job.is_cancelled()):
		return null

	var object: GMSModelObject = GMSModelObject.new()
	object.display_name = display_name if not display_name.strip_edges().is_empty() else "Imported Mesh"
	object.transform = object_transform
	object.mesh_data = mesh_data
	object.materials = _extract_materials(mesh, mesh_instance)
	object.active_material_index = 0
	object.ensure_defaults()
	return object


static func mesh_to_mesh_data(
	mesh: Mesh,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Dictionary:
	var result: Dictionary = {"mesh": null, "surface_count": 0, "cancelled": false}
	if mesh == null:
		return result

	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var smooth_faces: PackedByteArray = PackedByteArray()
	var uv_faces: Array[PackedVector2Array] = []
	var normal_faces: Array[PackedVector3Array] = []
	var face_materials: PackedInt32Array = PackedInt32Array()
	var vertex_lookup: Dictionary = {}
	var has_any_uv: bool = false
	var has_any_normal: bool = false
	var imported_surface_count: int = 0
	var surface_count: int = maxi(mesh.get_surface_count(), 1)

	for surface_index: int in mesh.get_surface_count():
		if job != null:
			if job.is_cancelled():
				result["cancelled"] = true
				return result
			job.update_progress(
				lerpf(progress_start, progress_end, float(surface_index) / float(surface_count)),
				"Converting mesh surface %d of %d" % [surface_index + 1, surface_count]
			)
		var primitive: int = mesh.surface_get_primitive_type(surface_index)
		if primitive not in [Mesh.PRIMITIVE_TRIANGLES, Mesh.PRIMITIVE_TRIANGLE_STRIP]:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			continue
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if source_vertices.is_empty():
			continue
		var source_indices: PackedInt32Array = PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		var source_uvs: PackedVector2Array = PackedVector2Array()
		if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
			source_uvs = arrays[Mesh.ARRAY_TEX_UV]
		var source_normals: PackedVector3Array = PackedVector3Array()
		if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			source_normals = arrays[Mesh.ARRAY_NORMAL]

		var order: PackedInt32Array = source_indices.duplicate()
		if order.is_empty():
			order.resize(source_vertices.size())
			for vertex_index: int in source_vertices.size():
				order[vertex_index] = vertex_index

		var imported_any_face: bool = false
		var triangle_count: int = maxi(int(order.size() / 3) if primitive == Mesh.PRIMITIVE_TRIANGLES else order.size() - 2, 1)
		match primitive:
			Mesh.PRIMITIVE_TRIANGLES:
				var triangle_position: int = 0
				for triangle_start: int in range(0, order.size() - 2, 3):
					if job != null and triangle_position % 2048 == 0:
						if job.is_cancelled():
							result["cancelled"] = true
							return result
						var surface_fraction: float = float(triangle_position) / float(triangle_count)
						job.update_progress(
							lerpf(progress_start, progress_end, (float(surface_index) + surface_fraction) / float(surface_count)),
							"Converting mesh triangles"
						)
					imported_any_face = _append_imported_triangle(
						order[triangle_start],
						order[triangle_start + 1],
						order[triangle_start + 2],
						surface_index,
						source_vertices,
						source_uvs,
						source_normals,
						vertex_lookup,
						vertices,
						faces,
						uv_faces,
						normal_faces,
						smooth_faces,
						face_materials
					) or imported_any_face
					triangle_position += 1
			Mesh.PRIMITIVE_TRIANGLE_STRIP:
				for triangle_start: int in range(0, order.size() - 2):
					if job != null and triangle_start % 2048 == 0:
						if job.is_cancelled():
							result["cancelled"] = true
							return result
						var surface_fraction: float = float(triangle_start) / float(triangle_count)
						job.update_progress(
							lerpf(progress_start, progress_end, (float(surface_index) + surface_fraction) / float(surface_count)),
							"Converting triangle strip"
						)
					var a: int = order[triangle_start]
					var b: int = order[triangle_start + 1]
					var c: int = order[triangle_start + 2]
					if triangle_start % 2 != 0:
						var swap: int = a
						a = b
						b = swap
					imported_any_face = _append_imported_triangle(
						a, b, c,
						surface_index,
						source_vertices,
						source_uvs,
						source_normals,
						vertex_lookup,
						vertices,
						faces,
						uv_faces,
						normal_faces,
						smooth_faces,
						face_materials
					) or imported_any_face

		if imported_any_face:
			imported_surface_count += 1
			has_any_uv = has_any_uv or not source_uvs.is_empty()
			has_any_normal = has_any_normal or not source_normals.is_empty()

	if faces.is_empty():
		return result
	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.96), "Finalizing imported mesh")
		if job.is_cancelled():
			result["cancelled"] = true
			return result
	var editable_mesh: GMSMeshData = GMSMeshData.new()
	editable_mesh.set_geometry(
		vertices,
		faces,
		smooth_faces,
		uv_faces,
		has_any_uv,
		normal_faces,
		has_any_normal,
		[],
		[],
		PackedFloat32Array(),
		[],
		face_materials
	)
	editable_mesh.uv_seam_analysis_pending = has_any_uv
	result["mesh"] = editable_mesh
	result["surface_count"] = imported_surface_count
	if job != null:
		job.update_progress(progress_end, "Imported mesh converted")
	return result


static func _append_imported_triangle(
	a: int,
	b: int,
	c: int,
	surface_index: int,
	source_vertices: PackedVector3Array,
	source_uvs: PackedVector2Array,
	source_normals: PackedVector3Array,
	vertex_lookup: Dictionary,
	vertices: PackedVector3Array,
	faces: Array[PackedInt32Array],
	uv_faces: Array[PackedVector2Array],
	normal_faces: Array[PackedVector3Array],
	smooth_faces: PackedByteArray,
	face_materials: PackedInt32Array
) -> bool:
	if (
		a < 0 or b < 0 or c < 0
		or a >= source_vertices.size()
		or b >= source_vertices.size()
		or c >= source_vertices.size()
		or a == b or b == c or c == a
	):
		return false



	var source_order: PackedInt32Array = PackedInt32Array([a, c, b])
	var face: PackedInt32Array = PackedInt32Array()
	var face_uv: PackedVector2Array = PackedVector2Array()
	var face_normals: PackedVector3Array = PackedVector3Array()
	for source_index: int in source_order:
		var position: Vector3 = source_vertices[source_index]
		var editable_index: int
		if vertex_lookup.has(position):
			editable_index = int(vertex_lookup[position])
		else:
			editable_index = vertices.size()
			vertices.append(position)
			vertex_lookup[position] = editable_index
		face.append(editable_index)
		face_uv.append(source_uvs[source_index] if source_index < source_uvs.size() else Vector2.ZERO)
		face_normals.append(
			source_normals[source_index].normalized()
			if source_index < source_normals.size() and not source_normals[source_index].is_zero_approx()
			else Vector3.ZERO
		)

	if face[0] == face[1] or face[1] == face[2] or face[2] == face[0]:
		return false
	faces.append(face)
	uv_faces.append(face_uv)
	normal_faces.append(face_normals)
	smooth_faces.append(1 if not source_normals.is_empty() else 0)
	face_materials.append(surface_index)
	return true


static func ensure_uv_seams(mesh_data: GMSMeshData) -> void:
	if mesh_data == null or not mesh_data.has_uv_map:
		return
	var topology: GMSTopology = mesh_data.get_topology()
	var seams: Array[Vector2i] = []
	for edge_value: Variant in topology.edge_half_edges.keys():
		var edge: Vector2i = edge_value
		var half_edges: PackedInt32Array = topology.edge_half_edges[edge]
		if half_edges.size() != 2:
			continue
		var first_face: int = topology.half_edge_face[half_edges[0]]
		var second_face: int = topology.half_edge_face[half_edges[1]]
		if not _edge_uv_continuous(mesh_data, edge, first_face, second_face):
			seams.append(edge)
	mesh_data.seam_edges = seams
	mesh_data.uv_seam_analysis_pending = false
	mesh_data.mark_changed()


static func _edge_uv_continuous(
	mesh_data: GMSMeshData,
	edge: Vector2i,
	first_face: int,
	second_face: int
) -> bool:
	for vertex_index: int in PackedInt32Array([edge.x, edge.y]):
		var first_uv: Vector2
		var second_uv: Vector2
		var found_first: bool = false
		var found_second: bool = false
		for corner_index: int in mesh_data.faces[first_face].size():
			if mesh_data.faces[first_face][corner_index] == vertex_index:
				first_uv = mesh_data.uv_faces[first_face][corner_index]
				found_first = true
				break
		for corner_index: int in mesh_data.faces[second_face].size():
			if mesh_data.faces[second_face][corner_index] == vertex_index:
				second_uv = mesh_data.uv_faces[second_face][corner_index]
				found_second = true
				break
		if not found_first or not found_second:
			return false
		if first_uv.distance_squared_to(second_uv) > 0.0000000001:
			return false
	return true


static func _collect_mesh_instances(
	node: Node,
	parent_transform: Transform3D,
	result: Array[GMSModelObject],
	job: GMSBackgroundJob = null
) -> void:
	if node == null or (job != null and job.is_cancelled()):
		return
	var accumulated: Transform3D = parent_transform
	if node is Node3D:
		accumulated = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			if job != null:
				job.update_progress(0.20, "Converting scene mesh %s" % mesh_instance.name)
			var imported: GMSModelObject = mesh_to_object(
				mesh_instance.mesh,
				mesh_instance.name,
				accumulated,
				mesh_instance,
				job,
				0.20,
				0.96
			)
			if imported != null:
				imported.visible = mesh_instance.visible
				result.append(imported)
	for child: Node in node.get_children():
		if job != null and job.is_cancelled():
			return
		_collect_mesh_instances(child, accumulated, result, job)


static func _capture_mesh_instances(
	node: Node,
	parent_transform: Transform3D,
	entries: Array[Dictionary]
) -> void:
	if node == null:
		return
	var accumulated: Transform3D = parent_transform
	if node is Node3D:
		accumulated = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			entries.append({
				"mesh": mesh_instance.mesh,
				"name": mesh_instance.name,
				"transform": accumulated,
				"visible": mesh_instance.visible,
				"materials": _extract_materials(mesh_instance.mesh, mesh_instance),
			})
	for child: Node in node.get_children():
		_capture_mesh_instances(child, accumulated, entries)


static func _extract_materials(
	mesh: Mesh,
	mesh_instance: MeshInstance3D = null
) -> Array[StandardMaterial3D]:
	var result: Array[StandardMaterial3D] = []
	for surface_index: int in mesh.get_surface_count():
		var source_material: Material = null
		if mesh_instance != null:
			source_material = mesh_instance.get_active_material(surface_index)
		if source_material == null:
			source_material = mesh.surface_get_material(surface_index)
		var fallback_name: String = mesh.surface_get_name(surface_index).strip_edges()
		if fallback_name.is_empty():
			fallback_name = "Material %d" % (surface_index + 1)
		result.append(_convert_material(source_material, fallback_name))
	if result.is_empty():
		result.append(GMSModelObject.create_default_material("Material 1"))
	return result


static func _convert_material(source: Material, fallback_name: String) -> StandardMaterial3D:
	if source is StandardMaterial3D:
		var duplicated: StandardMaterial3D = source.duplicate(true) as StandardMaterial3D
		if duplicated.resource_name.is_empty():
			duplicated.resource_name = fallback_name
		return duplicated

	var result: StandardMaterial3D = GMSModelObject.create_default_material(fallback_name)
	if source == null:
		return result
	result.resource_name = source.resource_name if not source.resource_name.is_empty() else fallback_name
	if source is BaseMaterial3D:
		var base: BaseMaterial3D = source as BaseMaterial3D
		result.albedo_color = base.albedo_color
		result.albedo_texture = base.albedo_texture
		result.metallic = base.metallic
		result.roughness = base.roughness
		result.cull_mode = base.cull_mode
	return result


static func _build_surface_triangles(
	primitive: int,
	source_indices: PackedInt32Array,
	vertex_count: int
) -> Array[PackedInt32Array]:
	var triangles: Array[PackedInt32Array] = []
	var order: PackedInt32Array = source_indices.duplicate()
	if order.is_empty():
		order.resize(vertex_count)
		for vertex_index: int in vertex_count:
			order[vertex_index] = vertex_index

	match primitive:
		Mesh.PRIMITIVE_TRIANGLES:
			for index: int in range(0, order.size() - 2, 3):
				triangles.append(PackedInt32Array([order[index], order[index + 1], order[index + 2]]))
		Mesh.PRIMITIVE_TRIANGLE_STRIP:
			for index: int in range(0, order.size() - 2):
				var triangle: PackedInt32Array
				if index % 2 == 0:
					triangle = PackedInt32Array([order[index], order[index + 1], order[index + 2]])
				else:
					triangle = PackedInt32Array([order[index + 1], order[index], order[index + 2]])
				if triangle[0] != triangle[1] and triangle[1] != triangle[2] and triangle[2] != triangle[0]:
					triangles.append(triangle)
	return triangles


static func _triangle_indices_valid(triangle: PackedInt32Array, vertex_count: int) -> bool:
	for vertex_index: int in triangle:
		if vertex_index < 0 or vertex_index >= vertex_count:
			return false
	return true
