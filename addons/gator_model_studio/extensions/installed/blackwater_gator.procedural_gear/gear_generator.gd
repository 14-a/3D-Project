@tool
extends RefCounted


static func create_gear(parameters: Dictionary) -> GMSMeshData:
	var teeth: int = clampi(int(parameters.get("teeth", 16)), 3, 128)
	var outer_radius: float = maxf(float(parameters.get("outer_radius", 1.0)), 0.05)
	var root_radius: float = clampf(
		float(parameters.get("root_radius", outer_radius * 0.78)),
		outer_radius * 0.05,
		outer_radius * 0.98
	)
	var bore_radius: float = clampf(
		float(parameters.get("bore_radius", outer_radius * 0.3)),
		0.0,
		root_radius * 0.9
	)
	var thickness: float = maxf(float(parameters.get("thickness", 0.25)), 0.01)
	var inner_radius: float = maxf(bore_radius, outer_radius * 0.001)
	var segment_count: int = teeth * 4
	var half_height: float = thickness * 0.5
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()

	for segment: int in segment_count:
		var angle: float = TAU * float(segment) / float(segment_count)
		var phase: int = segment % 4
		var outer: float = outer_radius if phase == 1 or phase == 2 else root_radius
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * outer + Vector3.UP * half_height)
		vertices.append(direction * outer - Vector3.UP * half_height)
		vertices.append(direction * inner_radius + Vector3.UP * half_height)
		vertices.append(direction * inner_radius - Vector3.UP * half_height)

	for segment: int in segment_count:
		var next: int = (segment + 1) % segment_count
		var top_outer: int = segment * 4
		var bottom_outer: int = top_outer + 1
		var top_inner: int = top_outer + 2
		var bottom_inner: int = top_outer + 3
		var next_top_outer: int = next * 4
		var next_bottom_outer: int = next_top_outer + 1
		var next_top_inner: int = next_top_outer + 2
		var next_bottom_inner: int = next_top_outer + 3


		faces.append(PackedInt32Array([top_inner, next_top_inner, next_top_outer, top_outer]))
		faces.append(PackedInt32Array([bottom_inner, bottom_outer, next_bottom_outer, next_bottom_inner]))
		faces.append(PackedInt32Array([top_outer, next_top_outer, next_bottom_outer, bottom_outer]))
		faces.append(PackedInt32Array([top_inner, bottom_inner, next_bottom_inner, next_top_inner]))
		smooth.append(0)
		smooth.append(0)
		smooth.append(0)
		smooth.append(1)

	var mesh: GMSMeshData = GMSMeshData.new()
	mesh.set_geometry(vertices, faces, smooth)
	mesh = GMSUVOperations.project_box(mesh, GMSUVOperations.all_faces(mesh))
	return mesh


static func apply_radial_scale(source: GMSMeshData, parameters: Dictionary) -> GMSMeshData:
	if source == null:
		return null
	var result: GMSMeshData = source.duplicate_mesh_data()
	var factor: float = maxf(float(parameters.get("factor", 1.1)), 0.0)
	for vertex_index: int in result.vertices.size():
		var vertex: Vector3 = result.vertices[vertex_index]
		vertex.x *= factor
		vertex.z *= factor
		result.vertices[vertex_index] = vertex
	result.emit_changed()
	return result
