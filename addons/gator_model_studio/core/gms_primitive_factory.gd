@tool
class_name GMSPrimitiveFactory
extends RefCounted


static func create_cube(size: Vector3 = Vector3.ONE) -> GMSMeshData:
	var half: Vector3 = size * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z),
		Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z),
		Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z),
		Vector3(-half.x, half.y, half.z),
	])
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([4, 5, 6, 7]),
		PackedInt32Array([1, 0, 3, 2]),
		PackedInt32Array([5, 1, 2, 6]),
		PackedInt32Array([0, 4, 7, 3]),
		PackedInt32Array([7, 6, 2, 3]),
		PackedInt32Array([0, 1, 5, 4]),
	]
	return _make_mesh(vertices, faces)


static func create_plane(size: Vector2 = Vector2(2.0, 2.0)) -> GMSMeshData:
	var half: Vector2 = size * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, half.y),
		Vector3(-half.x, 0.0, half.y),
	])
	var faces: Array[PackedInt32Array] = [PackedInt32Array([3, 2, 1, 0])]
	return _make_mesh(vertices, faces)


static func create_circle(
	radius: float = 0.5,
	segments: int = 32
) -> GMSMeshData:
	segments = maxi(segments, 3)
	var vertices: PackedVector3Array = PackedVector3Array()
	var face: PackedInt32Array = PackedInt32Array()
	for segment: int in segments:
		var angle: float = TAU * float(segment) / float(segments)
		vertices.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	for segment: int in range(segments - 1, -1, -1):
		face.append(segment)
	var faces: Array[PackedInt32Array] = [face]
	return _make_mesh(vertices, faces)


static func create_uv_sphere(
	radius: float = 0.5,
	segments: int = 32,
	rings: int = 16
) -> GMSMeshData:
	segments = maxi(segments, 6)
	rings = maxi(rings, 3)
	var vertices: PackedVector3Array = PackedVector3Array([Vector3.UP * radius])
	var faces: Array[PackedInt32Array] = []
	for ring: int in range(1, rings):
		var polar: float = PI * float(ring) / float(rings)
		var ring_radius: float = sin(polar) * radius
		var y: float = cos(polar) * radius
		for segment: int in segments:
			var azimuth: float = TAU * float(segment) / float(segments)
			vertices.append(Vector3(cos(azimuth) * ring_radius, y, sin(azimuth) * ring_radius))
	var bottom_index: int = vertices.size()
	vertices.append(Vector3.DOWN * radius)
	for segment: int in segments:
		var next: int = (segment + 1) % segments
		faces.append(_oriented_face(vertices, PackedInt32Array([0, 1 + segment, 1 + next])))
	for ring: int in range(rings - 2):
		var current_start: int = 1 + ring * segments
		var next_start: int = current_start + segments
		for segment: int in segments:
			var next: int = (segment + 1) % segments
			faces.append(_oriented_face(vertices, PackedInt32Array([
				current_start + segment,
				current_start + next,
				next_start + next,
				next_start + segment,
			])))
	var last_ring_start: int = 1 + (rings - 2) * segments
	for segment: int in segments:
		var next: int = (segment + 1) % segments
		faces.append(_oriented_face(vertices, PackedInt32Array([
			last_ring_start + segment,
			bottom_index,
			last_ring_start + next,
		])))
	var mesh: GMSMeshData = _make_mesh(vertices, faces)
	mesh.smooth_faces.resize(mesh.faces.size())
	mesh.smooth_faces.fill(1)
	return mesh


static func create_sphere(
	radius: float = 0.5,
	segments: int = 32,
	rings: int = 16
) -> GMSMeshData:
	return create_uv_sphere(radius, segments, rings)


static func create_icosphere(
	radius: float = 0.5,
	subdivisions: int = 2
) -> GMSMeshData:
	subdivisions = maxi(subdivisions, 1)
	var golden_ratio: float = (1.0 + sqrt(5.0)) * 0.5
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-1.0, golden_ratio, 0.0),
		Vector3(1.0, golden_ratio, 0.0),
		Vector3(-1.0, -golden_ratio, 0.0),
		Vector3(1.0, -golden_ratio, 0.0),
		Vector3(0.0, -1.0, golden_ratio),
		Vector3(0.0, 1.0, golden_ratio),
		Vector3(0.0, -1.0, -golden_ratio),
		Vector3(0.0, 1.0, -golden_ratio),
		Vector3(golden_ratio, 0.0, -1.0),
		Vector3(golden_ratio, 0.0, 1.0),
		Vector3(-golden_ratio, 0.0, -1.0),
		Vector3(-golden_ratio, 0.0, 1.0),
	])
	for vertex_index: int in vertices.size():
		vertices[vertex_index] = vertices[vertex_index].normalized() * radius
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 11, 5]),
		PackedInt32Array([0, 5, 1]),
		PackedInt32Array([0, 1, 7]),
		PackedInt32Array([0, 7, 10]),
		PackedInt32Array([0, 10, 11]),
		PackedInt32Array([1, 5, 9]),
		PackedInt32Array([5, 11, 4]),
		PackedInt32Array([11, 10, 2]),
		PackedInt32Array([10, 7, 6]),
		PackedInt32Array([7, 1, 8]),
		PackedInt32Array([3, 9, 4]),
		PackedInt32Array([3, 4, 2]),
		PackedInt32Array([3, 2, 6]),
		PackedInt32Array([3, 6, 8]),
		PackedInt32Array([3, 8, 9]),
		PackedInt32Array([4, 9, 5]),
		PackedInt32Array([2, 4, 11]),
		PackedInt32Array([6, 2, 10]),
		PackedInt32Array([8, 6, 7]),
		PackedInt32Array([9, 8, 1]),
	]
	for level: int in range(subdivisions - 1):
		var midpoint_cache: Dictionary = {}
		var subdivided: Array[PackedInt32Array] = []
		for face: PackedInt32Array in faces:
			var ab: int = _icosphere_midpoint(vertices, face[0], face[1], radius, midpoint_cache)
			var bc: int = _icosphere_midpoint(vertices, face[1], face[2], radius, midpoint_cache)
			var ca: int = _icosphere_midpoint(vertices, face[2], face[0], radius, midpoint_cache)
			subdivided.append(PackedInt32Array([face[0], ab, ca]))
			subdivided.append(PackedInt32Array([face[1], bc, ab]))
			subdivided.append(PackedInt32Array([face[2], ca, bc]))
			subdivided.append(PackedInt32Array([ab, bc, ca]))
		faces = subdivided
	for face_index: int in faces.size():
		faces[face_index] = _oriented_face(vertices, faces[face_index])
	var mesh: GMSMeshData = _make_mesh(vertices, faces)
	mesh.smooth_faces.resize(mesh.faces.size())
	mesh.smooth_faces.fill(1)
	return mesh


static func create_cylinder(
	radius: float = 0.5,
	height: float = 1.0,
	segments: int = 32
) -> GMSMeshData:
	segments = maxi(segments, 3)
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var half_height: float = height * 0.5
	for segment: int in segments:
		var angle: float = TAU * float(segment) / float(segments)
		vertices.append(Vector3(cos(angle) * radius, -half_height, sin(angle) * radius))
	for segment: int in segments:
		var angle: float = TAU * float(segment) / float(segments)
		vertices.append(Vector3(cos(angle) * radius, half_height, sin(angle) * radius))
	for segment: int in segments:
		var next: int = (segment + 1) % segments
		faces.append(_oriented_face(
			vertices,
			PackedInt32Array([segment, next, segments + next, segments + segment])
		))
	var bottom: PackedInt32Array = PackedInt32Array()
	var top: PackedInt32Array = PackedInt32Array()
	for segment: int in segments:
		bottom.append(segments - 1 - segment)
		top.append(segments + segment)
	faces.append(_oriented_face(vertices, bottom))
	faces.append(_oriented_face(vertices, top))
	return _make_mesh(vertices, faces)


static func create_cone(
	radius: float = 0.5,
	height: float = 1.0,
	segments: int = 32
) -> GMSMeshData:
	segments = maxi(segments, 3)
	var half_height: float = height * 0.5
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	for segment: int in segments:
		var angle: float = TAU * float(segment) / float(segments)
		vertices.append(Vector3(cos(angle) * radius, -half_height, sin(angle) * radius))
	var tip_index: int = vertices.size()
	vertices.append(Vector3(0.0, half_height, 0.0))
	for segment: int in segments:
		var next: int = (segment + 1) % segments
		faces.append(_oriented_face(vertices, PackedInt32Array([segment, tip_index, next])))
	var bottom: PackedInt32Array = PackedInt32Array()
	for segment: int in segments:
		bottom.append(segments - 1 - segment)
	faces.append(_oriented_face(vertices, bottom))
	return _make_mesh(vertices, faces)


static func create_torus(
	major_radius: float = 0.65,
	minor_radius: float = 0.2,
	major_segments: int = 48,
	minor_segments: int = 12
) -> GMSMeshData:
	major_segments = maxi(major_segments, 3)
	minor_segments = maxi(minor_segments, 3)
	major_radius = maxf(major_radius, 0.001)
	minor_radius = clampf(minor_radius, 0.001, major_radius * 0.999)
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	for major_index: int in major_segments:
		var major_angle: float = TAU * float(major_index) / float(major_segments)
		var major_cos: float = cos(major_angle)
		var major_sin: float = sin(major_angle)
		for minor_index: int in minor_segments:
			var minor_angle: float = TAU * float(minor_index) / float(minor_segments)
			var radial: float = major_radius + minor_radius * cos(minor_angle)
			vertices.append(Vector3(
				radial * major_cos,
				minor_radius * sin(minor_angle),
				radial * major_sin
			))
	for major_index: int in major_segments:
		var next_major: int = (major_index + 1) % major_segments
		for minor_index: int in minor_segments:
			var next_minor: int = (minor_index + 1) % minor_segments
			var current: int = major_index * minor_segments + minor_index
			var current_minor_next: int = major_index * minor_segments + next_minor
			var next_both: int = next_major * minor_segments + next_minor
			var current_major_next: int = next_major * minor_segments + minor_index
			faces.append(PackedInt32Array([
				current,
				current_minor_next,
				next_both,
				current_major_next,
			]))
	var mesh: GMSMeshData = _make_mesh(vertices, faces)
	mesh.smooth_faces.resize(mesh.faces.size())
	mesh.smooth_faces.fill(1)
	return mesh


static func create_grid(
	size: Vector2 = Vector2(2.0, 2.0),
	x_vertices: int = 10,
	y_vertices: int = 10
) -> GMSMeshData:
	x_vertices = maxi(x_vertices, 2)
	y_vertices = maxi(y_vertices, 2)
	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var half: Vector2 = size * 0.5
	for y_index: int in y_vertices:
		var z: float = lerpf(-half.y, half.y, float(y_index) / float(y_vertices - 1))
		for x_index: int in x_vertices:
			var x: float = lerpf(-half.x, half.x, float(x_index) / float(x_vertices - 1))
			vertices.append(Vector3(x, 0.0, z))
	for y_index: int in range(y_vertices - 1):
		for x_index: int in range(x_vertices - 1):
			var a: int = y_index * x_vertices + x_index
			var b: int = a + 1
			var d: int = (y_index + 1) * x_vertices + x_index
			var c: int = d + 1
			faces.append(PackedInt32Array([a, d, c, b]))
	return _make_mesh(vertices, faces)


static func _make_mesh(
	vertices: PackedVector3Array,
	faces: Array[PackedInt32Array]
) -> GMSMeshData:
	var mesh: GMSMeshData = GMSMeshData.new()
	var smooth_faces: PackedByteArray = PackedByteArray()
	smooth_faces.resize(faces.size())
	mesh.set_geometry(vertices, faces, smooth_faces)
	return mesh


static func _icosphere_midpoint(
	vertices: PackedVector3Array,
	a: int,
	b: int,
	radius: float,
	cache: Dictionary
) -> int:
	var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
	if cache.has(edge):
		return int(cache[edge])
	var midpoint: Vector3 = (vertices[a] + vertices[b]).normalized() * radius
	var index: int = vertices.size()
	vertices.append(midpoint)
	cache[edge] = index
	return index


static func _oriented_face(
	vertices: PackedVector3Array,
	face: PackedInt32Array
) -> PackedInt32Array:
	if face.size() < 3:
		return face
	var a: Vector3 = vertices[face[0]]
	var b: Vector3 = vertices[face[1]]
	var c: Vector3 = vertices[face[2]]
	var normal: Vector3 = (b - a).cross(c - a)
	var center: Vector3 = Vector3.ZERO
	for vertex_index: int in face:
		center += vertices[vertex_index]
	center /= float(face.size())
	if normal.dot(center) < 0.0:
		var reversed: PackedInt32Array = PackedInt32Array()
		for index: int in range(face.size() - 1, -1, -1):
			reversed.append(face[index])
		return reversed
	return face
