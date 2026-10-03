@tool
class_name GMSVoxelRemesher
extends RefCounted


const MIN_RESOLUTION: int = 12
const MAX_RESOLUTION: int = 256
const MAX_GRID_SAMPLES: int = 8000000
const SURFACE_DISTANCE_SCALE: float = 0.95

const CUBE_CORNERS: Array[Vector3i] = [
	Vector3i(0, 0, 0),
	Vector3i(1, 0, 0),
	Vector3i(1, 1, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, 0, 1),
	Vector3i(1, 0, 1),
	Vector3i(1, 1, 1),
	Vector3i(0, 1, 1),
]

const CUBE_EDGES: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(1, 2),
	Vector2i(2, 3),
	Vector2i(3, 0),
	Vector2i(4, 5),
	Vector2i(5, 6),
	Vector2i(6, 7),
	Vector2i(7, 4),
	Vector2i(0, 4),
	Vector2i(1, 5),
	Vector2i(2, 6),
	Vector2i(3, 7),
]


static func remesh(
	source_mesh: GMSMeshData,
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

	_update(job, 0.01, "Preparing source triangles")
	var source: GMSMeshData
	if source_is_detached:
		source = source_mesh
	else:
		source = source_mesh.duplicate_mesh_data_validated()
	source.prepare_for_use()
	var triangle_data: Dictionary = _build_triangles(source)
	var triangle_vertices: PackedVector3Array = triangle_data["vertices"]
	var triangle_faces: PackedInt32Array = triangle_data["faces"]
	if triangle_faces.is_empty():
		return _failure(
			"The selected object contains no usable triangles (%d source faces, %d rejected triangles, %d invalid vertex indices)." % [
				source.faces.size(),
				int(triangle_data.get("rejected_triangle_count", 0)),
				int(triangle_data.get("invalid_index_count", 0)),
			]
		)

	var requested_resolution: int = clampi(resolution, MIN_RESOLUTION, MAX_RESOLUTION)
	var safe_resolution: int = requested_resolution
	var source_bounds: AABB = source.get_aabb()
	var longest_axis: float = maxf(source_bounds.size.x, maxf(source_bounds.size.y, source_bounds.size.z))
	if longest_axis <= 0.000001:
		return _failure("The selected object has no measurable volume.")
	var cell_size: float = longest_axis / float(safe_resolution)
	var grid_bounds: AABB = source_bounds.grow(cell_size * 2.5)
	var sample_size: Vector3i = Vector3i(
		maxi(4, ceili(grid_bounds.size.x / cell_size)),
		maxi(4, ceili(grid_bounds.size.y / cell_size)),
		maxi(4, ceili(grid_bounds.size.z / cell_size))
	)
	var sample_count: int = sample_size.x * sample_size.y * sample_size.z
	if sample_count > MAX_GRID_SAMPLES:
		var reduction: float = pow(float(MAX_GRID_SAMPLES) / float(sample_count), 1.0 / 3.0)
		safe_resolution = maxi(MIN_RESOLUTION, floori(float(safe_resolution) * reduction))
		cell_size = longest_axis / float(safe_resolution)
		grid_bounds = source_bounds.grow(cell_size * 2.5)
		sample_size = Vector3i(
			maxi(4, ceili(grid_bounds.size.x / cell_size)),
			maxi(4, ceili(grid_bounds.size.y / cell_size)),
			maxi(4, ceili(grid_bounds.size.z / cell_size))
		)
		sample_count = sample_size.x * sample_size.y * sample_size.z

	var occupied: PackedByteArray = PackedByteArray()
	occupied.resize(sample_count)
	var surface_distance: float = cell_size * SURFACE_DISTANCE_SCALE
	var surface_distance_squared: float = surface_distance * surface_distance
	_update(job, 0.04, "Voxelising source surface")
	for triangle_index: int in triangle_faces.size():
		if triangle_index % 64 == 0:
			if _cancelled(job):
				return _cancelled_result()
			_update(
				job,
				0.04 + 0.34 * float(triangle_index) / float(maxi(triangle_faces.size(), 1)),
				"Voxelising source surface"
			)
		var vertex_offset: int = triangle_index * 3
		var a: Vector3 = triangle_vertices[vertex_offset]
		var b: Vector3 = triangle_vertices[vertex_offset + 1]
		var c: Vector3 = triangle_vertices[vertex_offset + 2]
		_rasterize_triangle(
			a,
			b,
			c,
			grid_bounds.position,
			cell_size,
			sample_size,
			surface_distance,
			surface_distance_squared,
			occupied
		)

	if _cancelled(job):
		return _cancelled_result()
	_update(job, 0.39, "Filling voxel volume")
	_fill_volume_from_surface(occupied, sample_size, job)
	if _cancelled(job):
		return _cancelled_result()
	_update(job, 0.43, "Resolving voxel topology")
	_resolve_voxel_ambiguities(occupied, sample_size, job)
	if _cancelled(job):
		return _cancelled_result()

	_update(job, 0.50, "Extracting quad surface")
	var surface: Dictionary = _extract_surface_nets(
		occupied,
		sample_size,
		grid_bounds.position,
		cell_size,
		job
	)
	if bool(surface.get("cancelled", false)):
		return _cancelled_result()
	var vertices: PackedVector3Array = surface.get("vertices", PackedVector3Array())
	var faces: Array[PackedInt32Array] = surface.get("faces", [])
	if vertices.is_empty() or faces.is_empty():
		return _failure("The voxel grid did not produce a surface. Increase resolution or repair the source mesh.")

	var result: GMSMeshData = GMSMeshData.new()
	var smooth_flags: PackedByteArray = PackedByteArray()
	smooth_flags.resize(faces.size())
	smooth_flags.fill(1)
	result.set_geometry(vertices, faces, smooth_flags)
	var generated_topology: GMSTopology = result.get_topology()
	if not generated_topology.non_manifold_edges.is_empty():
		return _failure(
			"Voxel topology remained non-manifold. Try a different resolution or reduce thin overlapping details."
		)
	if not generated_topology.get_boundary_loops().is_empty():
		return _failure(
			"Voxel topology produced an open boundary. Try a different resolution or repair extreme source geometry."
		)

	var valid_guides: Array[GMSRemeshGuide] = _duplicate_valid_guides(guides)
	var safe_density_levels: int = clampi(density_subdivisions, 0, 2)
	if safe_density_levels > 0 and _has_guide_mode(valid_guides, GMSRemeshGuide.GuideMode.DENSITY):
		_update(job, 0.66, "Applying density guides")
		for density_level: int in safe_density_levels:
			if _cancelled(job):
				return _cancelled_result()
			var level_start: float = lerpf(
				0.66,
				0.71,
				float(density_level) / float(safe_density_levels)
			)
			var level_end: float = lerpf(
				0.66,
				0.71,
				float(density_level + 1) / float(safe_density_levels)
			)
			var subdivision_start: float = lerpf(level_start, level_end, 0.15)
			_update(job, level_start, "Locating density guide faces")
			var density_faces: PackedInt32Array = _faces_near_density_guides(
				result, valid_guides, job
			)
			if _cancelled(job):
				return _cancelled_result()
			if density_faces.is_empty():
				break
			var subdivision: Dictionary = GMSMeshOperations.subdivide_faces(
				result,
				density_faces,
				job,
				subdivision_start,
				level_end
			)
			if bool(subdivision.get("cancelled", false)):
				return _cancelled_result()
			var subdivided: GMSMeshData = subdivision.get("mesh") as GMSMeshData
			if subdivided == null or subdivided.faces.size() == result.faces.size():
				break
			result = subdivided

	if _cancelled(job):
		return _cancelled_result()
	_update(job, 0.72, "Relaxing remeshed vertices")
	_smooth_with_guides(
		result,
		clampi(smooth_iterations, 0, 12),
		clampf(smooth_strength, 0.0, 1.0),
		valid_guides,
		job
	)
	if _cancelled(job):
		return _cancelled_result()

	_update(job, 0.82, "Projecting onto source surface")
	var source_index: GMSMeshSpatialIndex = GMSMeshSpatialIndex.new(source)
	_project_to_source(
		result,
		source_index,
		clampf(projection_strength, 0.0, 1.0),
		valid_guides,
		job
	)
	if _cancelled(job):
		return _cancelled_result()

	_update(job, 0.94, "Restoring material regions")
	_assign_source_materials(result, source, source_index, job)
	if _cancelled(job):
		return _cancelled_result()
	result.has_uv_map = false
	result.uv_faces.clear()
	result.seam_edges.clear()
	result.crease_edges.clear()
	result.crease_weights.clear()
	result.corner_normals.clear()
	result.has_custom_normals = false
	result.mark_changed()
	result.prepare_for_use()

	_update(job, 1.0, "Remesh complete")
	return {
		"mesh": result,
		"error": "",
		"cancelled": false,
		"requested_resolution": requested_resolution,
		"resolution": safe_resolution,
		"grid_samples": sample_count,
		"cell_size": cell_size,
		"vertex_count": result.vertices.size(),
		"face_count": result.faces.size(),
	}


static func _build_triangles(source: GMSMeshData) -> Dictionary:
	var triangle_vertices: PackedVector3Array = PackedVector3Array()
	var triangle_faces: PackedInt32Array = PackedInt32Array()
	var invalid_index_count: int = 0
	var rejected_triangle_count: int = 0
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		if face.size() < 3:
			rejected_triangle_count += 1
			continue
		var first_vertex_index: int = face[0]
		if first_vertex_index < 0 or first_vertex_index >= source.vertices.size():
			invalid_index_count += 1
			continue
		var a: Vector3 = source.vertices[first_vertex_index]
		for triangle_index: int in range(1, face.size() - 1):
			var second_vertex_index: int = face[triangle_index]
			var third_vertex_index: int = face[triangle_index + 1]
			if (
				second_vertex_index < 0
				or second_vertex_index >= source.vertices.size()
				or third_vertex_index < 0
				or third_vertex_index >= source.vertices.size()
			):
				invalid_index_count += 1
				continue
			var b: Vector3 = source.vertices[second_vertex_index]
			var c: Vector3 = source.vertices[third_vertex_index]
			if not a.is_finite() or not b.is_finite() or not c.is_finite():
				rejected_triangle_count += 1
				continue
			var edge_ab: Vector3 = b - a
			var edge_ac: Vector3 = c - a
			var edge_bc: Vector3 = c - b
			var maximum_edge_squared: float = maxf(
				edge_ab.length_squared(),
				maxf(edge_ac.length_squared(), edge_bc.length_squared())
			)
			if maximum_edge_squared <= 0.0:
				rejected_triangle_count += 1
				continue
			var cross_squared: float = edge_ab.cross(edge_ac).length_squared()
			var scale_relative_epsilon: float = maxf(
				maximum_edge_squared * maximum_edge_squared * 0.0000000000000001,
				0.000000000000000000000000000001
			)
			if cross_squared <= scale_relative_epsilon:
				rejected_triangle_count += 1
				continue
			triangle_vertices.append(a)
			triangle_vertices.append(b)
			triangle_vertices.append(c)
			triangle_faces.append(face_index)
	return {
		"vertices": triangle_vertices,
		"faces": triangle_faces,
		"invalid_index_count": invalid_index_count,
		"rejected_triangle_count": rejected_triangle_count,
	}


static func _rasterize_triangle(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	origin: Vector3,
	cell_size: float,
	sample_size: Vector3i,
	surface_distance: float,
	surface_distance_squared: float,
	occupied: PackedByteArray
) -> void:
	var triangle_min: Vector3 = Vector3(
		minf(a.x, minf(b.x, c.x)),
		minf(a.y, minf(b.y, c.y)),
		minf(a.z, minf(b.z, c.z))
	) - Vector3.ONE * surface_distance
	var triangle_max: Vector3 = Vector3(
		maxf(a.x, maxf(b.x, c.x)),
		maxf(a.y, maxf(b.y, c.y)),
		maxf(a.z, maxf(b.z, c.z))
	) + Vector3.ONE * surface_distance
	var minimum: Vector3i = Vector3i(
		clampi(floori((triangle_min.x - origin.x) / cell_size - 0.5), 0, sample_size.x - 1),
		clampi(floori((triangle_min.y - origin.y) / cell_size - 0.5), 0, sample_size.y - 1),
		clampi(floori((triangle_min.z - origin.z) / cell_size - 0.5), 0, sample_size.z - 1)
	)
	var maximum: Vector3i = Vector3i(
		clampi(ceili((triangle_max.x - origin.x) / cell_size - 0.5), 0, sample_size.x - 1),
		clampi(ceili((triangle_max.y - origin.y) / cell_size - 0.5), 0, sample_size.y - 1),
		clampi(ceili((triangle_max.z - origin.z) / cell_size - 0.5), 0, sample_size.z - 1)
	)
	for z: int in range(minimum.z, maximum.z + 1):
		for y: int in range(minimum.y, maximum.y + 1):
			for x: int in range(minimum.x, maximum.x + 1):
				var sample_position: Vector3 = origin + Vector3(
					float(x) + 0.5,
					float(y) + 0.5,
					float(z) + 0.5
				) * cell_size
				if _point_triangle_distance_squared(sample_position, a, b, c) <= surface_distance_squared:
					occupied[_sample_index(x, y, z, sample_size)] = 1


static func _fill_volume_from_surface(
	occupied: PackedByteArray,
	sample_size: Vector3i,
	job: GMSRemeshJob
) -> void:
	var exterior: PackedByteArray = PackedByteArray()
	exterior.resize(occupied.size())
	var queue: PackedInt32Array = PackedInt32Array()
	for z: int in sample_size.z:
		for y: int in sample_size.y:
			_enqueue_exterior(0, y, z, sample_size, occupied, exterior, queue)
			_enqueue_exterior(sample_size.x - 1, y, z, sample_size, occupied, exterior, queue)
	for z: int in sample_size.z:
		for x: int in sample_size.x:
			_enqueue_exterior(x, 0, z, sample_size, occupied, exterior, queue)
			_enqueue_exterior(x, sample_size.y - 1, z, sample_size, occupied, exterior, queue)
	for y: int in sample_size.y:
		for x: int in sample_size.x:
			_enqueue_exterior(x, y, 0, sample_size, occupied, exterior, queue)
			_enqueue_exterior(x, y, sample_size.z - 1, sample_size, occupied, exterior, queue)

	var head: int = 0
	while head < queue.size():
		if head % 16384 == 0 and _cancelled(job):
			return
		var index: int = queue[head]
		head += 1
		var x: int = index % sample_size.x
		var yz: int = int(index / sample_size.x)
		var y: int = yz % sample_size.y
		var z: int = int(yz / sample_size.y)
		_enqueue_exterior(x - 1, y, z, sample_size, occupied, exterior, queue)
		_enqueue_exterior(x + 1, y, z, sample_size, occupied, exterior, queue)
		_enqueue_exterior(x, y - 1, z, sample_size, occupied, exterior, queue)
		_enqueue_exterior(x, y + 1, z, sample_size, occupied, exterior, queue)
		_enqueue_exterior(x, y, z - 1, sample_size, occupied, exterior, queue)
		_enqueue_exterior(x, y, z + 1, sample_size, occupied, exterior, queue)

	for index: int in occupied.size():
		if exterior[index] == 0:
			occupied[index] = 1


static func _resolve_voxel_ambiguities(
	occupied: PackedByteArray,
	sample_size: Vector3i,
	job: GMSRemeshJob,
	maximum_passes: int = 8
) -> void:
	var plane_size: int = sample_size.x * sample_size.y
	for pass_index: int in maximum_passes:
		if _cancelled(job):
			return
		var votes: Dictionary = {}

		for z: int in sample_size.z:
			if z % 4 == 0:
				if _cancelled(job):
					return
				_update(
					job,
					0.43 + 0.02 * float(pass_index) / float(maxi(maximum_passes, 1)),
					"Resolving voxel topology"
				)
			for y: int in range(sample_size.y - 1):
				var row_start: int = _sample_index(0, y, z, sample_size)
				for x: int in range(sample_size.x - 1):
					var a: int = row_start + x
					var b: int = a + 1
					var d: int = a + sample_size.x
					var c: int = d + 1
					_record_ambiguity_vote(a, b, c, d, occupied, sample_size, votes)

		for x: int in sample_size.x:
			for z: int in range(sample_size.z - 1):
				for y: int in range(sample_size.y - 1):
					var a: int = _sample_index(x, y, z, sample_size)
					var b: int = a + sample_size.x
					var d: int = a + plane_size
					var c: int = b + plane_size
					_record_ambiguity_vote(a, b, c, d, occupied, sample_size, votes)

		for y: int in sample_size.y:
			for z: int in range(sample_size.z - 1):
				for x: int in range(sample_size.x - 1):
					var a: int = _sample_index(x, y, z, sample_size)
					var b: int = a + 1
					var d: int = a + plane_size
					var c: int = b + plane_size
					_record_ambiguity_vote(a, b, c, d, occupied, sample_size, votes)

		if votes.is_empty():
			return
		for index_value: Variant in votes.keys():
			var index: int = int(index_value)
			var counts: Vector2i = votes[index]
			occupied[index] = 1 if counts.y >= counts.x else 0


static func _record_ambiguity_vote(
	a: int,
	b: int,
	c: int,
	d: int,
	occupied: PackedByteArray,
	sample_size: Vector3i,
	votes: Dictionary
) -> void:
	var value_a: int = occupied[a]
	var value_b: int = occupied[b]
	if value_a == value_b or value_a != occupied[c] or value_b != occupied[d]:
		return
	var candidates: PackedInt32Array = PackedInt32Array([a, b, c, d])
	var best_index: int = -1
	var best_confidence: int = 2147483647
	var best_value: int = 1
	for index: int in candidates:
		var coordinates: Vector3i = _sample_coordinates(index, sample_size)
		var support: Vector2i = _sample_neighbour_support(
			coordinates.x, coordinates.y, coordinates.z, occupied, sample_size
		)
		var value: int = occupied[index]
		var confidence: int = support.x if value != 0 else support.y - support.x
		if (
			confidence < best_confidence
			or (confidence == best_confidence and value < best_value)
			or (confidence == best_confidence and value == best_value and index < best_index)
		):
			best_index = index
			best_confidence = confidence
			best_value = value
	if best_index < 0:
		return
	var desired_value: int = 0 if occupied[best_index] != 0 else 1
	var counts: Vector2i = votes.get(best_index, Vector2i.ZERO)
	if desired_value == 0:
		counts.x += 1
	else:
		counts.y += 1
	votes[best_index] = counts


static func _sample_neighbour_support(
	x: int,
	y: int,
	z: int,
	occupied: PackedByteArray,
	sample_size: Vector3i
) -> Vector2i:
	var occupied_count: int = 0
	var neighbour_count: int = 0
	for neighbour_z: int in range(maxi(0, z - 1), mini(sample_size.z, z + 2)):
		for neighbour_y: int in range(maxi(0, y - 1), mini(sample_size.y, y + 2)):
			for neighbour_x: int in range(maxi(0, x - 1), mini(sample_size.x, x + 2)):
				if neighbour_x == x and neighbour_y == y and neighbour_z == z:
					continue
				neighbour_count += 1
				occupied_count += occupied[
					_sample_index(neighbour_x, neighbour_y, neighbour_z, sample_size)
				]
	return Vector2i(occupied_count, neighbour_count)


static func _sample_coordinates(index: int, sample_size: Vector3i) -> Vector3i:
	var x: int = index % sample_size.x
	var yz: int = int(index / sample_size.x)
	var y: int = yz % sample_size.y
	var z: int = int(yz / sample_size.y)
	return Vector3i(x, y, z)


static func _enqueue_exterior(
	x: int,
	y: int,
	z: int,
	sample_size: Vector3i,
	occupied: PackedByteArray,
	exterior: PackedByteArray,
	queue: PackedInt32Array
) -> void:
	if x < 0 or y < 0 or z < 0 or x >= sample_size.x or y >= sample_size.y or z >= sample_size.z:
		return
	var index: int = _sample_index(x, y, z, sample_size)
	if occupied[index] != 0 or exterior[index] != 0:
		return
	exterior[index] = 1
	queue.append(index)


static func _extract_surface_nets(
	occupied: PackedByteArray,
	sample_size: Vector3i,
	origin: Vector3,
	cell_size: float,
	job: GMSRemeshJob
) -> Dictionary:
	var cube_size: Vector3i = Vector3i(sample_size.x - 1, sample_size.y - 1, sample_size.z - 1)
	var cube_vertices: PackedInt32Array = PackedInt32Array()
	cube_vertices.resize(cube_size.x * cube_size.y * cube_size.z)
	cube_vertices.fill(-1)
	var vertices: PackedVector3Array = PackedVector3Array()
	var corner_values: PackedByteArray = PackedByteArray()
	corner_values.resize(8)
	for z: int in cube_size.z:
		if z % 4 == 0:
			if _cancelled(job):
				return {"cancelled": true}
			_update(job, 0.50 + 0.12 * float(z) / float(maxi(cube_size.z, 1)), "Extracting quad surface")
		for y: int in cube_size.y:
			for x: int in cube_size.x:
				var inside_count: int = 0
				for corner_index: int in 8:
					var corner: Vector3i = CUBE_CORNERS[corner_index]
					var value: int = occupied[_sample_index(x + corner.x, y + corner.y, z + corner.z, sample_size)]
					corner_values[corner_index] = value
					inside_count += value
				if inside_count == 0 or inside_count == 8:
					continue
				var position_sum: Vector3 = Vector3.ZERO
				var crossing_count: int = 0
				for edge: Vector2i in CUBE_EDGES:
					if corner_values[edge.x] == corner_values[edge.y]:
						continue
					var first: Vector3i = CUBE_CORNERS[edge.x]
					var second: Vector3i = CUBE_CORNERS[edge.y]
					position_sum += origin + Vector3(
						float(x) + 0.5 + (float(first.x + second.x) * 0.5),
						float(y) + 0.5 + (float(first.y + second.y) * 0.5),
						float(z) + 0.5 + (float(first.z + second.z) * 0.5)
					) * cell_size
					crossing_count += 1
				if crossing_count <= 0:
					continue
				var vertex_index: int = vertices.size()
				vertices.append(position_sum / float(crossing_count))
				cube_vertices[_cube_index(x, y, z, cube_size)] = vertex_index

	var faces: Array[PackedInt32Array] = []
	for z: int in range(1, sample_size.z - 1):
		for y: int in range(1, sample_size.y - 1):
			for x: int in range(0, sample_size.x - 1):
				var first_value: int = occupied[_sample_index(x, y, z, sample_size)]
				var second_value: int = occupied[_sample_index(x + 1, y, z, sample_size)]
				if first_value == second_value:
					continue
				_append_surface_quad(
					faces,
					cube_vertices,
					cube_size,
					Vector3i(x, y - 1, z - 1),
					Vector3i(x, y, z - 1),
					Vector3i(x, y, z),
					Vector3i(x, y - 1, z),
					first_value != 0
				)
	for z: int in range(1, sample_size.z - 1):
		for y: int in range(0, sample_size.y - 1):
			for x: int in range(1, sample_size.x - 1):
				var first_value: int = occupied[_sample_index(x, y, z, sample_size)]
				var second_value: int = occupied[_sample_index(x, y + 1, z, sample_size)]
				if first_value == second_value:
					continue
				_append_surface_quad(
					faces,
					cube_vertices,
					cube_size,
					Vector3i(x - 1, y, z - 1),
					Vector3i(x - 1, y, z),
					Vector3i(x, y, z),
					Vector3i(x, y, z - 1),
					first_value != 0
				)
	for z: int in range(0, sample_size.z - 1):
		for y: int in range(1, sample_size.y - 1):
			for x: int in range(1, sample_size.x - 1):
				var first_value: int = occupied[_sample_index(x, y, z, sample_size)]
				var second_value: int = occupied[_sample_index(x, y, z + 1, sample_size)]
				if first_value == second_value:
					continue
				_append_surface_quad(
					faces,
					cube_vertices,
					cube_size,
					Vector3i(x - 1, y - 1, z),
					Vector3i(x, y - 1, z),
					Vector3i(x, y, z),
					Vector3i(x - 1, y, z),
					first_value != 0
				)
	return {
		"vertices": vertices,
		"faces": faces,
		"cancelled": false,
	}


static func _append_surface_quad(
	faces: Array[PackedInt32Array],
	cube_vertices: PackedInt32Array,
	cube_size: Vector3i,
	corner_a: Vector3i,
	corner_b: Vector3i,
	corner_c: Vector3i,
	corner_d: Vector3i,
	forward: bool
) -> void:
	var a: int = cube_vertices[_cube_index(corner_a.x, corner_a.y, corner_a.z, cube_size)]
	var b: int = cube_vertices[_cube_index(corner_b.x, corner_b.y, corner_b.z, cube_size)]
	var c: int = cube_vertices[_cube_index(corner_c.x, corner_c.y, corner_c.z, cube_size)]
	var d: int = cube_vertices[_cube_index(corner_d.x, corner_d.y, corner_d.z, cube_size)]
	if a < 0 or b < 0 or c < 0 or d < 0:
		return
	if a == b or a == c or a == d or b == c or b == d or c == d:
		return
	if forward:
		faces.append(PackedInt32Array([a, b, c, d]))
	else:
		faces.append(PackedInt32Array([d, c, b, a]))


static func _smooth_with_guides(
	mesh: GMSMeshData,
	iterations: int,
	strength: float,
	guides: Array[GMSRemeshGuide],
	job: GMSRemeshJob
) -> void:
	if iterations <= 0 or strength <= 0.0 or mesh.vertices.is_empty():
		return
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(mesh.vertices.size())
	for vertex_index: int in adjacency.size():
		adjacency[vertex_index] = PackedInt32Array()
	for edge: Vector2i in mesh.get_edges():
		adjacency[edge.x].append(edge.y)
		adjacency[edge.y].append(edge.x)

	var current: PackedVector3Array = mesh.vertices.duplicate()
	for iteration: int in iterations:
		if _cancelled(job):
			return
		var next: PackedVector3Array = current.duplicate()
		for vertex_index: int in current.size():
			if vertex_index % 1024 == 0:
				if _cancelled(job):
					return
				var iteration_progress: float = (
					float(iteration) + float(vertex_index) / float(maxi(current.size(), 1))
				) / float(maxi(iterations, 1))
				_update(job, 0.72 + 0.09 * iteration_progress, "Relaxing remeshed vertices")
			var neighbours: PackedInt32Array = adjacency[vertex_index]
			if neighbours.is_empty():
				continue
			var average: Vector3 = Vector3.ZERO
			for neighbour_index: int in neighbours:
				average += current[neighbour_index]
			average /= float(neighbours.size())
			var displacement: Vector3 = (average - current[vertex_index]) * strength
			displacement = _apply_guide_displacement(
				current[vertex_index],
				displacement,
				neighbours,
				current,
				strength,
				guides
			)
			next[vertex_index] = current[vertex_index] + displacement
		current = next
		_update(
			job,
			0.72 + 0.09 * float(iteration + 1) / float(maxi(iterations, 1)),
			"Relaxing remeshed vertices"
		)
	mesh.vertices = current
	mesh.mark_positions_changed()


static func _project_to_source(
	mesh: GMSMeshData,
	source_index: GMSMeshSpatialIndex,
	projection_strength: float,
	guides: Array[GMSRemeshGuide],
	job: GMSRemeshJob
) -> void:
	if projection_strength <= 0.0:
		return
	var projected: PackedVector3Array = mesh.vertices.duplicate()
	for vertex_index: int in projected.size():
		if vertex_index % 256 == 0:
			if _cancelled(job):
				return
			_update(
				job,
				0.82 + 0.11 * float(vertex_index) / float(maxi(projected.size(), 1)),
				"Projecting onto source surface"
			)
		var point: Vector3 = projected[vertex_index]
		var nearest: Dictionary = source_index.closest_point(point)
		if nearest.is_empty():
			continue
		var amount: float = projection_strength
		var preserve_weight: float = _maximum_guide_weight(
			point, guides, GMSRemeshGuide.GuideMode.PRESERVE_SHAPE
		)
		amount = lerpf(amount, 1.0, preserve_weight)
		projected[vertex_index] = point.lerp(nearest["position"], amount)
	mesh.vertices = projected
	mesh.mark_positions_changed()


static func _assign_source_materials(
	mesh: GMSMeshData,
	source: GMSMeshData,
	source_index: GMSMeshSpatialIndex,
	job: GMSRemeshJob
) -> void:
	var materials: PackedInt32Array = PackedInt32Array()
	materials.resize(mesh.faces.size())
	for face_index: int in mesh.faces.size():
		if face_index % 256 == 0:
			if _cancelled(job):
				return
			_update(
				job,
				0.94 + 0.05 * float(face_index) / float(maxi(mesh.faces.size(), 1)),
				"Restoring material regions"
			)
		var face: PackedInt32Array = mesh.faces[face_index]
		var center: Vector3 = Vector3.ZERO
		for vertex_index: int in face:
			center += mesh.vertices[vertex_index]
		center /= float(maxi(face.size(), 1))
		var nearest: Dictionary = source_index.closest_point(center)
		var source_face: int = int(nearest.get("face_index", -1))
		materials[face_index] = source.get_face_material(source_face) if source_face >= 0 else 0
	mesh.face_materials = materials


static func _faces_near_density_guides(
	mesh: GMSMeshData,
	guides: Array[GMSRemeshGuide],
	job: GMSRemeshJob
) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for face_index: int in mesh.faces.size():
		if face_index % 512 == 0 and _cancelled(job):
			return PackedInt32Array()
		var center: Vector3 = mesh.get_face_center(face_index)
		if _maximum_guide_weight(center, guides, GMSRemeshGuide.GuideMode.DENSITY) > 0.05:
			result.append(face_index)
	return result


static func _apply_guide_displacement(
	point: Vector3,
	displacement: Vector3,
	neighbours: PackedInt32Array,
	positions: PackedVector3Array,
	smooth_strength: float,
	guides: Array[GMSRemeshGuide]
) -> Vector3:
	var result: Vector3 = displacement
	for guide: GMSRemeshGuide in guides:
		if guide == null or not guide.is_valid() or guide.mode == GMSRemeshGuide.GuideMode.DENSITY:
			continue
		var influence: Dictionary = _guide_influence(point, guide)
		var weight: float = float(influence.get("weight", 0.0))
		if weight <= 0.0:
			continue
		match guide.mode:
			GMSRemeshGuide.GuideMode.PRESERVE_SHAPE:
				result *= 1.0 - weight
			GMSRemeshGuide.GuideMode.FLOW:
				var tangent: Vector3 = influence.get("tangent", Vector3.ZERO)
				if tangent.is_zero_approx():
					continue
				var positive_index: int = -1
				var negative_index: int = -1
				var positive_alignment: float = 0.0
				var negative_alignment: float = 0.0
				for neighbour_index: int in neighbours:
					var neighbour_delta: Vector3 = positions[neighbour_index] - point
					if neighbour_delta.is_zero_approx():
						continue
					var alignment: float = neighbour_delta.normalized().dot(tangent)
					if alignment > positive_alignment:
						positive_alignment = alignment
						positive_index = neighbour_index
					elif alignment < negative_alignment:
						negative_alignment = alignment
						negative_index = neighbour_index
				if positive_index >= 0 and negative_index >= 0:
					var flow_target: Vector3 = (
						positions[positive_index] + positions[negative_index]
					) * 0.5
					var flow_displacement: Vector3 = (flow_target - point) * smooth_strength
					result = result.lerp(flow_displacement, weight)
				var along: Vector3 = tangent * result.dot(tangent)
				var across: Vector3 = result - along
				result = along + across * (1.0 - weight)
	return result


static func _maximum_guide_weight(
	point: Vector3,
	guides: Array[GMSRemeshGuide],
	mode: int
) -> float:
	var maximum_weight: float = 0.0
	for guide: GMSRemeshGuide in guides:
		if guide == null or guide.mode != mode or not guide.is_valid():
			continue
		maximum_weight = maxf(maximum_weight, float(_guide_influence(point, guide).get("weight", 0.0)))
	return maximum_weight


static func _guide_influence(point: Vector3, guide: GMSRemeshGuide) -> Dictionary:
	var nearest_distance_squared: float = guide.radius * guide.radius
	var nearest_tangent: Vector3 = Vector3.ZERO
	var found: bool = false
	for segment_index: int in range(guide.points.size() - 1):
		var a: Vector3 = guide.points[segment_index]
		var b: Vector3 = guide.points[segment_index + 1]
		var segment: Vector3 = b - a
		var length_squared: float = segment.length_squared()
		if length_squared <= 0.0000000001:
			continue
		var amount: float = clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
		var closest: Vector3 = a + segment * amount
		var distance_squared: float = point.distance_squared_to(closest)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_tangent = segment.normalized()
			found = true
	if not found:
		return {}
	var distance: float = sqrt(nearest_distance_squared)
	var linear_weight: float = clampf(1.0 - distance / guide.radius, 0.0, 1.0)
	var smooth_weight: float = linear_weight * linear_weight * (3.0 - 2.0 * linear_weight)
	return {
		"weight": smooth_weight * guide.strength,
		"tangent": nearest_tangent,
	}


static func _duplicate_valid_guides(guides: Array[GMSRemeshGuide]) -> Array[GMSRemeshGuide]:
	var result: Array[GMSRemeshGuide] = []
	for guide: GMSRemeshGuide in guides:
		if guide != null and guide.is_valid():
			result.append(guide.duplicate_guide())
	return result


static func _has_guide_mode(guides: Array[GMSRemeshGuide], mode: int) -> bool:
	for guide: GMSRemeshGuide in guides:
		if guide != null and guide.mode == mode and guide.is_valid():
			return true
	return false


static func _point_triangle_distance_squared(
	point: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> float:
	return point.distance_squared_to(_closest_point_on_triangle(point, a, b, c))


static func _closest_point_on_triangle(
	point: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = point - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = point - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = point - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denominator: float = va + vb + vc
	if absf(denominator) <= 0.0000001:
		return (a + b + c) / 3.0
	var inverse_denominator: float = 1.0 / denominator
	return a + ab * (vb * inverse_denominator) + ac * (vc * inverse_denominator)


static func _sample_index(x: int, y: int, z: int, size: Vector3i) -> int:
	return x + size.x * (y + size.y * z)


static func _cube_index(x: int, y: int, z: int, size: Vector3i) -> int:
	return x + size.x * (y + size.y * z)


static func _update(job: GMSRemeshJob, progress: float, stage: String) -> void:
	if job != null:
		job.update_progress(progress, stage)


static func _cancelled(job: GMSRemeshJob) -> bool:
	return job != null and job.is_cancelled()


static func _failure(message: String) -> Dictionary:
	return {
		"mesh": null,
		"error": message,
		"cancelled": false,
	}


static func _cancelled_result() -> Dictionary:
	return {
		"mesh": null,
		"error": "",
		"cancelled": true,
	}
