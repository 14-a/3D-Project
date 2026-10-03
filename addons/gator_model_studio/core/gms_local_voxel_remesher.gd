@tool
class_name GMSLocalVoxelRemesher
extends RefCounted


const MIN_BOUNDARY_VERTICES: int = 3
const SHELL_THICKNESS_CELLS: float = 6.0
const OUTER_DISTANCE_CELLS: float = 3.0
const OUTER_NORMAL_DOT_MINIMUM: float = 0.05
const MAX_ALIGNMENT_SAMPLES: int = 32
const SHELL_OUTER_MATERIAL: int = 1000001
const SHELL_INNER_MATERIAL: int = 1000002
const SHELL_SIDE_MATERIAL: int = 1000003


static func remesh_selected_faces(
	source_mesh: GMSMeshData,
	selected_faces: PackedInt32Array,
	padding_rings: int,
	resolution: int,
	smooth_iterations: int,
	smooth_strength: float,
	projection_strength: float,
	density_subdivisions: int,
	guides: Array[GMSRemeshGuide] = [],
	job: GMSRemeshJob = null,
	source_is_detached: bool = false
) -> Dictionary:
	if source_mesh == null or source_mesh.vertices.is_empty() or source_mesh.faces.is_empty():
		return _failure("The selected object has no polygon mesh.")
	if _cancelled(job):
		return _cancelled_result()

	_update(job, 0.01, "Preparing selected remesh region")
	var source: GMSMeshData = (
		source_mesh if source_is_detached else source_mesh.duplicate_mesh_data_validated()
	)
	source.prepare_for_use()
	var core_faces: PackedInt32Array = _sanitize_face_indices(selected_faces, source.faces.size())
	if core_faces.is_empty():
		return _failure("Select one or more faces before using Selected Faces remeshing.")
	var region_faces: PackedInt32Array = _grow_face_region(
		source,
		core_faces,
		clampi(padding_rings, 0, 4)
	)
	if region_faces.is_empty():
		return _failure("The selected remesh region is empty.")
	if region_faces.size() == source.faces.size():
		var whole_proxy: GMSRemeshProgressProxy = GMSRemeshProgressProxy.new(
			job, 0.02, 1.0, "Selected region covers the full object"
		)
		var whole_result: Dictionary = GMSVoxelRemesher.remesh(
			source,
			resolution,
			smooth_iterations,
			smooth_strength,
			projection_strength,
			density_subdivisions,
			guides,
			whole_proxy,
			true
		)
		whole_result["local"] = false
		whole_result["region_face_count"] = region_faces.size()
		whole_result["padding_rings"] = clampi(padding_rings, 0, 4)
		return whole_result

	var boundary_data: Dictionary = _build_region_boundary(source, region_faces)
	var boundary_error: String = str(boundary_data.get("error", ""))
	if not boundary_error.is_empty():
		return _failure(boundary_error)
	var source_boundary_loops: Array[PackedInt32Array] = _dictionary_loop_array(
		boundary_data, "loops"
	)
	if source_boundary_loops.is_empty():
		return _failure(
			"The selected region has no boundary to stitch. Select a smaller area, or remesh the complete disconnected component as its own object."
		)
	var extraction: Dictionary = _extract_patch(source, region_faces, source_boundary_loops)
	var patch: GMSMeshData = extraction.get("mesh") as GMSMeshData
	if patch == null or patch.faces.is_empty():
		return _failure("The selected faces could not be extracted for local remeshing.")
	var patch_boundary_loops: Array[PackedInt32Array] = _dictionary_loop_array(
		extraction, "boundary_loops"
	)

	var safe_resolution: int = clampi(
		resolution,
		GMSVoxelRemesher.MIN_RESOLUTION,
		GMSVoxelRemesher.MAX_RESOLUTION
	)
	var patch_bounds: AABB = patch.get_aabb()
	var longest_axis: float = maxf(
		patch_bounds.size.x,
		maxf(patch_bounds.size.y, patch_bounds.size.z)
	)
	if longest_axis <= 0.000001:
		return _failure("The selected faces have no measurable size.")
	var estimated_cell_size: float = longest_axis / float(safe_resolution)
	var shell_data: Dictionary = _build_closed_shell(
		patch,
		patch_boundary_loops,
		estimated_cell_size
	)
	var shell: GMSMeshData = shell_data.get("mesh") as GMSMeshData
	var shell_thickness: float = float(shell_data.get("thickness", 0.0))
	if shell == null or not shell.is_valid():
		return _failure("The selected region could not be closed for local voxel remeshing.")
	if _cancelled(job):
		return _cancelled_result()

	var voxel_proxy: GMSRemeshProgressProxy = GMSRemeshProgressProxy.new(
		job, 0.05, 0.82, "Voxel remeshing selected faces"
	)
	var voxel_result: Dictionary = GMSVoxelRemesher.remesh(
		shell,
		safe_resolution,
		smooth_iterations,
		smooth_strength,
		0.0,
		density_subdivisions,
		guides,
		voxel_proxy,
		true
	)
	if bool(voxel_result.get("cancelled", false)):
		return _cancelled_result()
	var voxel_error: String = str(voxel_result.get("error", ""))
	if not voxel_error.is_empty():
		return _failure(voxel_error)
	var closed_result: GMSMeshData = voxel_result.get("mesh") as GMSMeshData
	if closed_result == null or not closed_result.is_valid():
		return _failure("Local voxel remeshing did not produce valid geometry.")
	var effective_cell_size: float = float(
		voxel_result.get("cell_size", estimated_cell_size)
	)

	_update(job, 0.83, "Extracting the outer remeshed surface")
	var outer_data: Dictionary = _extract_outer_surface(
		closed_result,
		patch,
		effective_cell_size,
		shell_thickness,
		clampf(projection_strength, 0.0, 1.0),
		job
	)
	if bool(outer_data.get("cancelled", false)):
		return _cancelled_result()
	var outer_error: String = str(outer_data.get("error", ""))
	if not outer_error.is_empty():
		return _failure(outer_error)
	var outer_patch: GMSMeshData = outer_data.get("mesh") as GMSMeshData
	if outer_patch == null or not outer_patch.is_valid():
		return _failure("The remeshed outer surface could not be reconstructed.")
	var generated_boundary_loops: Array[PackedInt32Array] = outer_patch.get_topology().get_boundary_loops()
	if source_boundary_loops.size() != generated_boundary_loops.size():
		return _failure(
			"Local remeshing produced %d boundary loops for %d source boundaries. Increase Boundary Padding or Resolution and try again." % [
				generated_boundary_loops.size(),
				source_boundary_loops.size(),
			]
		)

	_update(job, 0.93, "Matching preserved boundaries")
	var loop_matches: Dictionary = _match_boundary_loops(
		source.vertices,
		source_boundary_loops,
		outer_patch.vertices,
		generated_boundary_loops
	)
	var match_error: String = str(loop_matches.get("error", ""))
	if not match_error.is_empty():
		return _failure(match_error)
	var matched_generated_loops: Array[PackedInt32Array] = _dictionary_loop_array(
		loop_matches, "generated_loops"
	)
	if _cancelled(job):
		return _cancelled_result()

	_update(job, 0.95, "Stitching remeshed region to the original mesh")
	var stitched: Dictionary = _stitch_region(
		source,
		region_faces,
		patch,
		outer_patch,
		source_boundary_loops,
		matched_generated_loops,
		job
	)
	if bool(stitched.get("cancelled", false)):
		return _cancelled_result()
	var stitch_error: String = str(stitched.get("error", ""))
	if not stitch_error.is_empty():
		return _failure(stitch_error)
	var result: GMSMeshData = stitched.get("mesh") as GMSMeshData
	if result == null or not result.is_valid():
		return _failure("The stitched local remesh is invalid.")

	var source_topology: GMSTopology = source.get_topology()
	var result_topology: GMSTopology = result.get_topology()
	if not result_topology.non_manifold_edges.is_empty():
		return _failure(
			"Local remeshing created non-manifold boundary stitching. Increase Boundary Padding or select a simpler connected region."
		)
	var source_open_loops: int = source_topology.get_boundary_loops().size()
	var result_open_loops: int = result_topology.get_boundary_loops().size()
	if source_open_loops != result_open_loops:
		return _failure(
			"Local remeshing left an open seam at the preserved boundary. Increase Boundary Padding or Resolution and try again."
		)

	result.has_uv_map = false
	result.uv_faces.clear()
	result.seam_edges.clear()
	result.crease_edges.clear()
	result.crease_weights.clear()
	result.corner_normals.clear()
	result.has_custom_normals = false
	result.mark_changed()
	result.prepare_for_use()
	_update(job, 1.0, "Selected-face remesh complete")
	return {
		"mesh": result,
		"error": "",
		"cancelled": false,
		"local": true,
		"requested_resolution": int(voxel_result.get("requested_resolution", safe_resolution)),
		"resolution": int(voxel_result.get("resolution", safe_resolution)),
		"grid_samples": int(voxel_result.get("grid_samples", 0)),
		"cell_size": effective_cell_size,
		"vertex_count": result.vertices.size(),
		"face_count": result.faces.size(),
		"region_face_count": region_faces.size(),
		"padding_rings": clampi(padding_rings, 0, 4),
		"face_indices": stitched.get("face_indices", PackedInt32Array()),
	}


static func _sanitize_face_indices(indices: PackedInt32Array, face_count: int) -> PackedInt32Array:
	var seen: Dictionary = {}
	var result: PackedInt32Array = PackedInt32Array()
	for face_index: int in indices:
		if face_index < 0 or face_index >= face_count or seen.has(face_index):
			continue
		seen[face_index] = true
		result.append(face_index)
	result.sort()
	return result


static func _grow_face_region(
	mesh: GMSMeshData,
	seed_faces: PackedInt32Array,
	padding_rings: int
) -> PackedInt32Array:
	var topology: GMSTopology = mesh.get_topology()
	var region: Dictionary = {}
	var frontier: PackedInt32Array = seed_faces.duplicate()
	for face_index: int in seed_faces:
		region[face_index] = true
	for _ring_index: int in padding_rings:
		var next_frontier: PackedInt32Array = PackedInt32Array()
		for face_index: int in frontier:
			var face: PackedInt32Array = mesh.faces[face_index]
			for corner_index: int in face.size():
				var edge: Vector2i = GMSMeshData.canonical_edge(
					face[corner_index],
					face[(corner_index + 1) % face.size()]
				)
				for neighbour: int in topology.get_edge_faces(edge):
					if region.has(neighbour):
						continue
					region[neighbour] = true
					next_frontier.append(neighbour)
		frontier = next_frontier
		if frontier.is_empty():
			break
	var result: PackedInt32Array = PackedInt32Array()
	for face_value: Variant in region.keys():
		result.append(int(face_value))
	result.sort()
	return result


static func _build_region_boundary(
	mesh: GMSMeshData,
	region_faces: PackedInt32Array
) -> Dictionary:
	var region: Dictionary = {}
	for face_index: int in region_faces:
		region[face_index] = true
	var topology: GMSTopology = mesh.get_topology()
	var directed_edges: Array[Vector2i] = []
	for face_index: int in region_faces:
		var face: PackedInt32Array = mesh.faces[face_index]
		for corner_index: int in face.size():
			var origin: int = face[corner_index]
			var destination: int = face[(corner_index + 1) % face.size()]
			var attached: PackedInt32Array = topology.get_edge_faces(
				GMSMeshData.canonical_edge(origin, destination)
			)
			var selected_count: int = 0
			for attached_face: int in attached:
				if region.has(attached_face):
					selected_count += 1
			if attached.size() == 1 and selected_count == 1:
				return {
					"error": "Selected Faces remeshing cannot currently touch an existing open mesh boundary. Add surrounding faces or close the source boundary first.",
					"loops": [],
				}
			if selected_count == 1 and attached.size() >= 2:
				directed_edges.append(Vector2i(origin, destination))
	if directed_edges.is_empty():
		return {"error": "", "loops": []}

	var outgoing: Dictionary = {}
	var remaining: Dictionary = {}
	for edge: Vector2i in directed_edges:
		var destinations: PackedInt32Array = outgoing.get(edge.x, PackedInt32Array())
		destinations.append(edge.y)
		outgoing[edge.x] = destinations
		remaining[edge] = true
	var loops: Array[PackedInt32Array] = []
	while not remaining.is_empty():
		var first_value: Variant = remaining.keys()[0]
		var first: Vector2i = first_value
		remaining.erase(first)
		var loop: PackedInt32Array = PackedInt32Array([first.x, first.y])
		var current: int = first.y
		var guard: int = 0
		while current != first.x and guard <= directed_edges.size() + 1:
			guard += 1
			var candidates: PackedInt32Array = outgoing.get(current, PackedInt32Array())
			var next_vertex: int = -1
			for candidate: int in candidates:
				var edge_key: Vector2i = Vector2i(current, candidate)
				if remaining.has(edge_key):
					next_vertex = candidate
					remaining.erase(edge_key)
					break
			if next_vertex < 0:
				return {
					"error": "The selected faces do not form a stitchable manifold boundary. Select a simpler connected surface region.",
					"loops": [],
				}
			if next_vertex == first.x:
				current = next_vertex
				break
			loop.append(next_vertex)
			current = next_vertex
		if current != first.x or loop.size() < MIN_BOUNDARY_VERTICES:
			return {
				"error": "The selected faces contain an incomplete or degenerate boundary loop.",
				"loops": [],
			}
		loops.append(loop)
	return {"error": "", "loops": loops}


static func _extract_patch(
	source: GMSMeshData,
	region_faces: PackedInt32Array,
	source_boundary_loops: Array[PackedInt32Array]
) -> Dictionary:
	var vertex_map: Dictionary = {}
	var reverse_map: PackedInt32Array = PackedInt32Array()
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in region_faces:
		var source_face: PackedInt32Array = source.faces[face_index]
		var patch_face: PackedInt32Array = PackedInt32Array()
		for source_vertex: int in source_face:
			if not vertex_map.has(source_vertex):
				vertex_map[source_vertex] = vertices.size()
				vertices.append(source.vertices[source_vertex])
				reverse_map.append(source_vertex)
			patch_face.append(int(vertex_map[source_vertex]))
		faces.append(patch_face)
		smooth.append(
			int(source.smooth_faces[face_index])
			if face_index < source.smooth_faces.size()
			else 1
		)
		materials.append(source.get_face_material(face_index))
	var patch: GMSMeshData = GMSMeshData.new()
	patch.set_geometry(vertices, faces, smooth, [], false, [], false, [], [], PackedFloat32Array(), [], materials)
	var patch_loops: Array[PackedInt32Array] = []
	for source_loop: PackedInt32Array in source_boundary_loops:
		var patch_loop: PackedInt32Array = PackedInt32Array()
		for source_vertex: int in source_loop:
			if vertex_map.has(source_vertex):
				patch_loop.append(int(vertex_map[source_vertex]))
		patch_loops.append(patch_loop)
	return {
		"mesh": patch,
		"boundary_loops": patch_loops,
		"source_vertices": reverse_map,
	}


static func _build_closed_shell(
	patch: GMSMeshData,
	boundary_loops: Array[PackedInt32Array],
	cell_size: float
) -> Dictionary:
	var vertex_normals: PackedVector3Array = PackedVector3Array()
	vertex_normals.resize(patch.vertices.size())
	vertex_normals.fill(Vector3.ZERO)
	for face_index: int in patch.faces.size():
		var normal: Vector3 = patch.get_face_normal(face_index)
		for vertex_index: int in patch.faces[face_index]:
			vertex_normals[vertex_index] += normal
	for vertex_index: int in vertex_normals.size():
		if vertex_normals[vertex_index].is_zero_approx():
			vertex_normals[vertex_index] = Vector3.UP
		else:
			vertex_normals[vertex_index] = vertex_normals[vertex_index].normalized()
	var bounds_length: float = patch.get_aabb().size.length()
	var thickness: float = maxf(
		cell_size * SHELL_THICKNESS_CELLS,
		maxf(bounds_length * 0.005, 0.00001)
	)
	var vertices: PackedVector3Array = patch.vertices.duplicate()
	var outer_count: int = patch.vertices.size()
	for vertex_index: int in outer_count:
		vertices.append(
			patch.vertices[vertex_index] - vertex_normals[vertex_index] * thickness
		)
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in patch.faces.size():
		faces.append(patch.faces[face_index].duplicate())
		smooth.append(1)
		materials.append(SHELL_OUTER_MATERIAL)
		var inner_face: PackedInt32Array = PackedInt32Array()
		for source_vertex: int in patch.faces[face_index]:
			inner_face.append(source_vertex + outer_count)
		inner_face.reverse()
		faces.append(inner_face)
		smooth.append(1)
		materials.append(SHELL_INNER_MATERIAL)
	for loop: PackedInt32Array in boundary_loops:
		for corner_index: int in loop.size():
			var a: int = loop[corner_index]
			var b: int = loop[(corner_index + 1) % loop.size()]
			faces.append(PackedInt32Array([
				a,
				a + outer_count,
				b + outer_count,
				b,
			]))
			smooth.append(1)
			materials.append(SHELL_SIDE_MATERIAL)
	var shell: GMSMeshData = GMSMeshData.new()
	shell.set_geometry(vertices, faces, smooth, [], false, [], false, [], [], PackedFloat32Array(), [], materials)
	return {"mesh": shell, "thickness": thickness}


static func _extract_outer_surface(
	closed_result: GMSMeshData,
	patch: GMSMeshData,
	cell_size: float,
	shell_thickness: float,
	projection_strength: float,
	job: GMSRemeshJob
) -> Dictionary:
	var patch_index: GMSMeshSpatialIndex = GMSMeshSpatialIndex.new(patch)
	var kept_faces: Array[PackedInt32Array] = []
	var kept_smooth: PackedByteArray = PackedByteArray()
	var kept_materials: PackedInt32Array = PackedInt32Array()
	var distance_limit: float = maxf(
		cell_size * OUTER_DISTANCE_CELLS,
		shell_thickness * 0.35
	)
	for face_index: int in closed_result.faces.size():
		if face_index % 256 == 0:
			if _cancelled(job):
				return {"cancelled": true, "error": "", "mesh": null}
			_update(
				job,
				0.83 + 0.04 * float(face_index) / float(maxi(closed_result.faces.size(), 1)),
				"Extracting the outer remeshed surface"
			)
		if closed_result.get_face_material(face_index) != SHELL_OUTER_MATERIAL:
			continue
		var center: Vector3 = closed_result.get_face_center(face_index)
		var nearest: Dictionary = patch_index.closest_point(center, distance_limit)
		if nearest.is_empty():
			continue
		var source_face: int = int(nearest.get("face_index", -1))
		if source_face < 0:
			continue
		var generated_normal: Vector3 = closed_result.get_face_normal(face_index)
		var source_normal: Vector3 = patch.get_face_normal(source_face)
		if generated_normal.dot(source_normal) <= OUTER_NORMAL_DOT_MINIMUM:
			continue
		kept_faces.append(closed_result.faces[face_index].duplicate())
		kept_smooth.append(1)
		kept_materials.append(patch.get_face_material(source_face))
	if kept_faces.is_empty():
		return {
			"cancelled": false,
			"error": "The local voxel shell did not expose an outer surface. Increase Resolution or Boundary Padding.",
			"mesh": null,
		}
	var raw_patch: GMSMeshData = GMSMeshData.new()
	raw_patch.set_geometry(
		closed_result.vertices.duplicate(),
		kept_faces,
		kept_smooth,
		[],
		false,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		[],
		kept_materials
	)
	var compact: GMSMeshData = _compact_mesh(raw_patch)
	var projected: PackedVector3Array = compact.vertices.duplicate()
	for vertex_index: int in projected.size():
		if vertex_index % 256 == 0:
			if _cancelled(job):
				return {"cancelled": true, "error": "", "mesh": null}
			_update(
				job,
				0.87 + 0.05 * float(vertex_index) / float(maxi(projected.size(), 1)),
				"Projecting the selected remesh onto its source surface"
			)
		var nearest: Dictionary = patch_index.closest_point(projected[vertex_index])
		if nearest.is_empty():
			continue
		projected[vertex_index] = projected[vertex_index].lerp(
			nearest["position"],
			projection_strength
		)
	compact.vertices = projected
	compact.mark_positions_changed()
	compact.prepare_for_use()
	return {"cancelled": false, "error": "", "mesh": compact}


static func _match_boundary_loops(
	source_vertices: PackedVector3Array,
	source_loops: Array[PackedInt32Array],
	generated_vertices: PackedVector3Array,
	generated_loops: Array[PackedInt32Array]
) -> Dictionary:
	if source_loops.size() != generated_loops.size():
		return {
			"error": "The generated local boundary count does not match the selected source region.",
			"generated_loops": [],
		}
	var available: Dictionary = {}
	for generated_index: int in generated_loops.size():
		available[generated_index] = true
	var matched: Array[PackedInt32Array] = []
	for source_loop: PackedInt32Array in source_loops:
		var source_center: Vector3 = _loop_center(source_vertices, source_loop)
		var source_perimeter: float = _loop_perimeter(source_vertices, source_loop)
		var best_generated: int = -1
		var best_score: float = INF
		for generated_value: Variant in available.keys():
			var generated_index: int = int(generated_value)
			var generated_loop: PackedInt32Array = generated_loops[generated_index]
			var generated_center: Vector3 = _loop_center(generated_vertices, generated_loop)
			var generated_perimeter: float = _loop_perimeter(
				generated_vertices, generated_loop
			)
			var score: float = source_center.distance_to(generated_center)
			score += absf(source_perimeter - generated_perimeter) * 0.25
			if score < best_score:
				best_score = score
				best_generated = generated_index
		if best_generated < 0:
			return {
				"error": "A generated boundary could not be matched to the selected region.",
				"generated_loops": [],
			}
		available.erase(best_generated)
		matched.append(_align_loop(
			source_vertices,
			source_loop,
			generated_vertices,
			generated_loops[best_generated]
		))
	return {"error": "", "generated_loops": matched}


static func _align_loop(
	source_vertices: PackedVector3Array,
	source_loop: PackedInt32Array,
	generated_vertices: PackedVector3Array,
	generated_loop: PackedInt32Array
) -> PackedInt32Array:
	var generated_count: int = generated_loop.size()
	if generated_count <= 1:
		return generated_loop.duplicate()
	var sample_count: int = mini(
		MAX_ALIGNMENT_SAMPLES,
		maxi(source_loop.size(), generated_loop.size())
	)
	var best_offset: int = 0
	var best_direction: int = 1
	var best_score: float = INF
	for direction: int in PackedInt32Array([1, -1]):
		for offset: int in generated_count:
			var score: float = 0.0
			for sample_index: int in sample_count:
				var source_position: int = floori(
					float(sample_index) * float(source_loop.size()) / float(sample_count)
				)
				var generated_position: int = floori(
					float(sample_index) * float(generated_count) / float(sample_count)
				)
				var generated_sequence_index: int = posmod(
					offset + direction * generated_position,
					generated_count
				)
				score += source_vertices[source_loop[source_position]].distance_squared_to(
					generated_vertices[generated_loop[generated_sequence_index]]
				)
			if score < best_score:
				best_score = score
				best_offset = offset
				best_direction = direction
	var aligned: PackedInt32Array = PackedInt32Array()
	for generated_position: int in generated_count:
		aligned.append(generated_loop[posmod(
			best_offset + best_direction * generated_position,
			generated_count
		)])
	return aligned


static func _stitch_region(
	source: GMSMeshData,
	region_faces: PackedInt32Array,
	patch: GMSMeshData,
	outer_patch: GMSMeshData,
	source_loops: Array[PackedInt32Array],
	generated_loops: Array[PackedInt32Array],
	job: GMSRemeshJob
) -> Dictionary:
	var region: Dictionary = {}
	for face_index: int in region_faces:
		region[face_index] = true
	var output_vertices: PackedVector3Array = source.vertices.duplicate()
	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in source.faces.size():
		if region.has(face_index):
			continue
		output_faces.append(source.faces[face_index].duplicate())
		output_smooth.append(
			int(source.smooth_faces[face_index])
			if face_index < source.smooth_faces.size()
			else 1
		)
		output_materials.append(source.get_face_material(face_index))
	var generated_vertex_offset: int = output_vertices.size()
	for vertex: Vector3 in outer_patch.vertices:
		output_vertices.append(vertex)
	var remeshed_face_indices: PackedInt32Array = PackedInt32Array()
	for face_index: int in outer_patch.faces.size():
		if face_index % 256 == 0 and _cancelled(job):
			return {"cancelled": true, "error": "", "mesh": null}
		var output_face: PackedInt32Array = PackedInt32Array()
		for vertex_index: int in outer_patch.faces[face_index]:
			output_face.append(generated_vertex_offset + vertex_index)
		remeshed_face_indices.append(output_faces.size())
		output_faces.append(output_face)
		output_smooth.append(1)
		output_materials.append(outer_patch.get_face_material(face_index))

	var patch_index: GMSMeshSpatialIndex = GMSMeshSpatialIndex.new(patch)
	for loop_index: int in source_loops.size():
		var source_loop: PackedInt32Array = source_loops[loop_index]
		var local_generated_loop: PackedInt32Array = generated_loops[loop_index]
		var generated_loop: PackedInt32Array = PackedInt32Array()
		for local_vertex: int in local_generated_loop:
			generated_loop.append(generated_vertex_offset + local_vertex)
		var bridge_faces: Array[PackedInt32Array] = _bridge_loops(
			source_loop,
			generated_loop
		)
		for bridge_face: PackedInt32Array in bridge_faces:
			var center: Vector3 = _face_center(output_vertices, bridge_face)
			var nearest: Dictionary = patch_index.closest_point(center)
			var source_face: int = int(nearest.get("face_index", -1))
			var target_normal: Vector3 = (
				patch.get_face_normal(source_face)
				if source_face >= 0
				else Vector3.UP
			)
			if _polygon_normal(output_vertices, bridge_face).dot(target_normal) < 0.0:
				bridge_face.reverse()
			if _unique_vertex_count(bridge_face) < 3:
				continue
			remeshed_face_indices.append(output_faces.size())
			output_faces.append(bridge_face)
			output_smooth.append(1)
			output_materials.append(
				patch.get_face_material(source_face) if source_face >= 0 else 0
			)

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		[],
		false,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		[],
		output_materials
	)
	result = _compact_mesh(result)
	return {
		"cancelled": false,
		"error": "",
		"mesh": result,
		"face_indices": remeshed_face_indices,
	}


static func _bridge_loops(
	source_loop: PackedInt32Array,
	generated_loop: PackedInt32Array
) -> Array[PackedInt32Array]:
	var faces: Array[PackedInt32Array] = []
	var source_count: int = source_loop.size()
	var generated_count: int = generated_loop.size()
	if source_count < 3 or generated_count < 3:
		return faces
	var source_step: int = 0
	var generated_step: int = 0
	while source_step < source_count or generated_step < generated_count:
		var source_current: int = source_loop[source_step % source_count]
		var generated_current: int = generated_loop[generated_step % generated_count]
		var next_source_t: float = (
			float(source_step + 1) / float(source_count)
			if source_step < source_count
			else INF
		)
		var next_generated_t: float = (
			float(generated_step + 1) / float(generated_count)
			if generated_step < generated_count
			else INF
		)
		if absf(next_source_t - next_generated_t) <= 0.000001:
			faces.append(PackedInt32Array([
				source_current,
				source_loop[(source_step + 1) % source_count],
				generated_loop[(generated_step + 1) % generated_count],
				generated_current,
			]))
			source_step += 1
			generated_step += 1
		elif next_source_t < next_generated_t:
			faces.append(PackedInt32Array([
				source_current,
				source_loop[(source_step + 1) % source_count],
				generated_current,
			]))
			source_step += 1
		else:
			faces.append(PackedInt32Array([
				source_current,
				generated_loop[(generated_step + 1) % generated_count],
				generated_current,
			]))
			generated_step += 1
	return faces


static func _compact_mesh(mesh: GMSMeshData) -> GMSMeshData:
	var used: Dictionary = {}
	for face: PackedInt32Array in mesh.faces:
		for vertex_index: int in face:
			used[vertex_index] = true
	var old_indices: Array[int] = []
	for vertex_value: Variant in used.keys():
		old_indices.append(int(vertex_value))
	old_indices.sort()
	var remap: Dictionary = {}
	var vertices: PackedVector3Array = PackedVector3Array()
	for old_index: int in old_indices:
		remap[old_index] = vertices.size()
		vertices.append(mesh.vertices[old_index])
	var faces: Array[PackedInt32Array] = []
	for source_face: PackedInt32Array in mesh.faces:
		var face: PackedInt32Array = PackedInt32Array()
		for old_index: int in source_face:
			face.append(int(remap[old_index]))
		faces.append(face)
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		vertices,
		faces,
		mesh.smooth_faces,
		[],
		false,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		[],
		mesh.face_materials
	)
	return result


static func _dictionary_loop_array(
	dictionary: Dictionary,
	key: String
) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	var value: Variant = dictionary.get(key, [])
	if value is Array:
		for loop_value: Variant in value:
			if loop_value is PackedInt32Array:
				var packed_loop: PackedInt32Array = loop_value
				result.append(packed_loop.duplicate())
	return result


static func _loop_center(
	vertices: PackedVector3Array,
	loop: PackedInt32Array
) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	for vertex_index: int in loop:
		center += vertices[vertex_index]
	return center / float(maxi(loop.size(), 1))


static func _loop_perimeter(
	vertices: PackedVector3Array,
	loop: PackedInt32Array
) -> float:
	var perimeter: float = 0.0
	for vertex_index: int in loop.size():
		perimeter += vertices[loop[vertex_index]].distance_to(
			vertices[loop[(vertex_index + 1) % loop.size()]]
		)
	return perimeter


static func _face_center(
	vertices: PackedVector3Array,
	face: PackedInt32Array
) -> Vector3:
	var center: Vector3 = Vector3.ZERO
	for vertex_index: int in face:
		center += vertices[vertex_index]
	return center / float(maxi(face.size(), 1))


static func _polygon_normal(
	vertices: PackedVector3Array,
	face: PackedInt32Array
) -> Vector3:
	var normal: Vector3 = Vector3.ZERO
	for corner_index: int in face.size():
		var current: Vector3 = vertices[face[corner_index]]
		var next: Vector3 = vertices[face[(corner_index + 1) % face.size()]]
		normal.x += (current.y - next.y) * (current.z + next.z)
		normal.y += (current.z - next.z) * (current.x + next.x)
		normal.z += (current.x - next.x) * (current.y + next.y)
	return normal.normalized() if not normal.is_zero_approx() else Vector3.ZERO


static func _unique_vertex_count(face: PackedInt32Array) -> int:
	var unique: Dictionary = {}
	for vertex_index: int in face:
		unique[vertex_index] = true
	return unique.size()


static func _cancelled(job: GMSRemeshJob) -> bool:
	return job != null and job.is_cancelled()


static func _update(job: GMSRemeshJob, progress: float, stage: String) -> void:
	if job != null:
		job.update_progress(progress, stage)


static func _failure(message: String) -> Dictionary:
	return {"mesh": null, "error": message, "cancelled": false, "local": true}


static func _cancelled_result() -> Dictionary:
	return {"mesh": null, "error": "", "cancelled": true, "local": true}
