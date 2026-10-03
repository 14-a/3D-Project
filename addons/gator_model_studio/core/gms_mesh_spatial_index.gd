@tool
class_name GMSMeshSpatialIndex
extends RefCounted

const LEAF_FACE_COUNT: int = 32

var mesh: GMSMeshData
var mesh_revision: int = -1
var topology_revision: int = -1
var position_revision: int = -1
var face_edges: Array[Vector2i] = []
var all_edges: Array[Vector2i] = []
var edge_lookup: Dictionary = {}

var _face_centers: PackedVector3Array = PackedVector3Array()
var _face_indices: PackedInt32Array = PackedInt32Array()
var _face_to_primitive: PackedInt32Array = PackedInt32Array()
var _face_bounds: Array[AABB] = []
var _vertex_faces: Array[PackedInt32Array] = []
var _primitive_leaf: PackedInt32Array = PackedInt32Array()
var _nodes: Array[Dictionary] = []
var _node_parents: PackedInt32Array = PackedInt32Array()
var _node_depths: PackedInt32Array = PackedInt32Array()
var _root_index: int = -1


func _init(source: GMSMeshData = null) -> void:
	if source != null:
		build(source)


func build(source: GMSMeshData) -> void:
	mesh = source
	mesh_revision = source.get_change_revision() if source != null else -1
	topology_revision = source.get_topology_revision() if source != null else -1
	position_revision = source.get_position_revision() if source != null else -1
	face_edges.clear()
	all_edges.clear()
	edge_lookup.clear()
	_face_centers.clear()
	_face_indices.clear()
	_face_to_primitive.clear()
	_face_bounds.clear()
	_vertex_faces.clear()
	_primitive_leaf.clear()
	_nodes.clear()
	_node_parents.clear()
	_node_depths.clear()
	_root_index = -1
	if source == null:
		return
	_face_to_primitive.resize(source.faces.size())
	_face_to_primitive.fill(-1)
	_vertex_faces.resize(source.vertices.size())
	for vertex_index: int in _vertex_faces.size():
		_vertex_faces[vertex_index] = PackedInt32Array()
	var edge_keys: Dictionary = {}
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		if face.size() < 3:
			continue
		var primitive_index: int = _face_indices.size()
		_face_to_primitive[face_index] = primitive_index
		var center: Vector3 = Vector3.ZERO
		var bounds: AABB = AABB(source.vertices[face[0]], Vector3.ZERO)
		for corner_index: int in face.size():
			var vertex_index: int = face[corner_index]
			var next_vertex_index: int = face[(corner_index + 1) % face.size()]
			var low: int = mini(vertex_index, next_vertex_index)
			var high: int = maxi(vertex_index, next_vertex_index)
			var key: int = (low << 32) | high
			if not edge_keys.has(key):
				edge_keys[key] = true
				face_edges.append(Vector2i(low, high))
			var position: Vector3 = source.vertices[vertex_index]
			center += position
			bounds = bounds.expand(position)
			var attached: PackedInt32Array = _vertex_faces[vertex_index]
			attached.append(face_index)
			_vertex_faces[vertex_index] = attached
		_face_centers.append(center / float(face.size()))
		_face_indices.append(face_index)
		_face_bounds.append(bounds.grow(0.000001))
	all_edges = face_edges if source.loose_edges.is_empty() else face_edges.duplicate()
	for source_edge: Vector2i in source.loose_edges:
		var loose_low: int = mini(source_edge.x, source_edge.y)
		var loose_high: int = maxi(source_edge.x, source_edge.y)
		var loose_key: int = (loose_low << 32) | loose_high
		if edge_keys.has(loose_key):
			continue
		edge_keys[loose_key] = true
		all_edges.append(Vector2i(loose_low, loose_high))
	for edge_index: int in all_edges.size():
		edge_lookup[all_edges[edge_index]] = edge_index
	if _face_indices.is_empty():
		return
	_primitive_leaf.resize(_face_indices.size())
	_primitive_leaf.fill(-1)
	var indices: Array[int] = []
	indices.resize(_face_indices.size())
	for index: int in indices.size():
		indices[index] = index
	_root_index = _build_node(indices, -1, 0)


func is_current(source: GMSMeshData) -> bool:
	return source == mesh and source != null and mesh_revision == source.get_change_revision()


func can_refit(source: GMSMeshData) -> bool:
	return source == mesh and source != null and topology_revision == source.get_topology_revision()


func refit_vertices(source: GMSMeshData, vertex_indices: PackedInt32Array) -> bool:
	if not can_refit(source):
		return false
	if vertex_indices.is_empty():
		return refit_all(source)
	if vertex_indices.size() * 4 >= source.vertices.size():
		return refit_all(source)
	var primitive_set: Dictionary = {}
	for vertex_index: int in vertex_indices:
		if vertex_index < 0 or vertex_index >= _vertex_faces.size():
			continue
		for face_index: int in _vertex_faces[vertex_index]:
			if face_index < 0 or face_index >= _face_to_primitive.size():
				continue
			var primitive_index: int = _face_to_primitive[face_index]
			if primitive_index >= 0:
				primitive_set[primitive_index] = true
	if primitive_set.is_empty():
		mesh_revision = source.get_change_revision()
		position_revision = source.get_position_revision()
		return true
	var node_set: Dictionary = {}
	for primitive_value: Variant in primitive_set.keys():
		var primitive_index: int = int(primitive_value)
		_update_primitive(source, primitive_index)
		var node_index: int = _primitive_leaf[primitive_index]
		while node_index >= 0:
			node_set[node_index] = true
			node_index = _node_parents[node_index]
	var affected_nodes: Array[int] = []
	for node_value: Variant in node_set.keys():
		affected_nodes.append(int(node_value))
	affected_nodes.sort_custom(_sort_nodes_deepest_first)
	for node_index: int in affected_nodes:
		_recompute_node_bounds(node_index)
	mesh_revision = source.get_change_revision()
	position_revision = source.get_position_revision()
	return true


func _sort_nodes_deepest_first(a: int, b: int) -> bool:
	return _node_depths[a] > _node_depths[b]


func refit_all(source: GMSMeshData) -> bool:
	if not can_refit(source):
		return false
	for primitive_index: int in _face_indices.size():
		_update_primitive(source, primitive_index)
	for node_index: int in range(_nodes.size() - 1, -1, -1):
		_recompute_node_bounds(node_index)
	mesh_revision = source.get_change_revision()
	position_revision = source.get_position_revision()
	return true


func raycast(ray_origin: Vector3, ray_direction: Vector3) -> Dictionary:
	if _root_index < 0 or ray_direction.is_zero_approx() or mesh == null:
		return {}
	var direction: Vector3 = ray_direction.normalized()
	var nearest_distance: float = INF
	var nearest_face: int = -1
	var stack: Array[int] = [_root_index]
	while not stack.is_empty():
		var node_index: int = stack.pop_back()
		var node: Dictionary = _nodes[node_index]
		if not _ray_intersects_aabb(ray_origin, direction, node["bounds"], nearest_distance):
			continue
		var primitives: PackedInt32Array = node["primitives"]
		if not primitives.is_empty():
			for primitive_index: int in primitives:
				var face_index: int = _face_indices[primitive_index]
				var distance: float = _ray_face_distance(
					ray_origin, direction, mesh, face_index, nearest_distance
				)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_face = face_index
			continue
		var left: int = int(node["left"])
		var right: int = int(node["right"])
		if left >= 0:
			stack.append(left)
		if right >= 0:
			stack.append(right)
	if nearest_face < 0:
		return {}
	return {
		"distance": nearest_distance,
		"face_index": nearest_face,
		"position": ray_origin + direction * nearest_distance,
	}


func closest_point(point: Vector3, maximum_distance: float = INF) -> Dictionary:
	if _root_index < 0 or mesh == null:
		return {}
	var nearest_distance_squared: float = maximum_distance * maximum_distance
	var nearest_position: Vector3 = Vector3.ZERO
	var nearest_face: int = -1
	var stack: Array[int] = [_root_index]
	while not stack.is_empty():
		var node_index: int = stack.pop_back()
		var node: Dictionary = _nodes[node_index]
		if _point_aabb_distance_squared(point, node["bounds"]) > nearest_distance_squared:
			continue
		var primitives: PackedInt32Array = node["primitives"]
		if not primitives.is_empty():
			for primitive_index: int in primitives:
				var face_index: int = _face_indices[primitive_index]
				var face_result: Dictionary = _closest_point_on_face(
					point, mesh, face_index, nearest_distance_squared
				)
				if face_result.is_empty():
					continue
				var distance_squared: float = float(face_result["distance_squared"])
				if distance_squared < nearest_distance_squared:
					nearest_distance_squared = distance_squared
					nearest_position = face_result["position"]
					nearest_face = face_index
			continue
		var left: int = int(node["left"])
		var right: int = int(node["right"])
		if left >= 0 and right >= 0:
			var left_distance: float = _point_aabb_distance_squared(point, _nodes[left]["bounds"])
			var right_distance: float = _point_aabb_distance_squared(point, _nodes[right]["bounds"])
			if left_distance < right_distance:
				if right_distance <= nearest_distance_squared:
					stack.append(right)
				if left_distance <= nearest_distance_squared:
					stack.append(left)
			else:
				if left_distance <= nearest_distance_squared:
					stack.append(left)
				if right_distance <= nearest_distance_squared:
					stack.append(right)
		elif left >= 0:
			stack.append(left)
		elif right >= 0:
			stack.append(right)
	if nearest_face < 0:
		return {}
	return {
		"position": nearest_position,
		"face_index": nearest_face,
		"distance": sqrt(nearest_distance_squared),
	}


func _build_node(indices: Array[int], parent: int, depth: int) -> int:
	var bounds: AABB = _face_bounds[indices[0]]
	var center_bounds: AABB = AABB(_face_centers[indices[0]], Vector3.ZERO)
	for list_index: int in range(1, indices.size()):
		var primitive_index: int = indices[list_index]
		bounds = bounds.merge(_face_bounds[primitive_index])
		center_bounds = center_bounds.expand(_face_centers[primitive_index])
	var node_index: int = _nodes.size()
	_nodes.append({
		"bounds": bounds,
		"left": -1,
		"right": -1,
		"primitives": PackedInt32Array(),
	})
	_node_parents.append(parent)
	_node_depths.append(depth)
	if indices.size() <= LEAF_FACE_COUNT:
		var leaf_primitives: PackedInt32Array = PackedInt32Array()
		for primitive_index: int in indices:
			leaf_primitives.append(primitive_index)
			_primitive_leaf[primitive_index] = node_index
		_nodes[node_index]["primitives"] = leaf_primitives
		return node_index
	var size: Vector3 = center_bounds.size
	var split_axis: int = 0
	if size.y > size.x and size.y >= size.z:
		split_axis = 1
	elif size.z > size.x and size.z > size.y:
		split_axis = 2
	var split_value: float = (
		_axis_value(center_bounds.position, split_axis)
		+ _axis_value(center_bounds.end, split_axis)
	) * 0.5
	var left_indices: Array[int] = []
	var right_indices: Array[int] = []
	for primitive_index: int in indices:
		if _axis_value(_face_centers[primitive_index], split_axis) < split_value:
			left_indices.append(primitive_index)
		else:
			right_indices.append(primitive_index)
	if left_indices.is_empty() or right_indices.is_empty():
		var fallback: PackedInt32Array = PackedInt32Array()
		for primitive_index: int in indices:
			fallback.append(primitive_index)
			_primitive_leaf[primitive_index] = node_index
		_nodes[node_index]["primitives"] = fallback
		return node_index
	_nodes[node_index]["left"] = _build_node(left_indices, node_index, depth + 1)
	_nodes[node_index]["right"] = _build_node(right_indices, node_index, depth + 1)
	return node_index


func _update_primitive(source: GMSMeshData, primitive_index: int) -> void:
	if primitive_index < 0 or primitive_index >= _face_indices.size():
		return
	var face_index: int = _face_indices[primitive_index]
	var face: PackedInt32Array = source.faces[face_index]
	if face.is_empty():
		return
	var center: Vector3 = Vector3.ZERO
	var bounds: AABB = AABB(source.vertices[face[0]], Vector3.ZERO)
	for vertex_index: int in face:
		var position: Vector3 = source.vertices[vertex_index]
		center += position
		bounds = bounds.expand(position)
	_face_centers[primitive_index] = center / float(face.size())
	_face_bounds[primitive_index] = bounds.grow(0.000001)


func _recompute_node_bounds(node_index: int) -> void:
	if node_index < 0 or node_index >= _nodes.size():
		return
	var node: Dictionary = _nodes[node_index]
	var primitives: PackedInt32Array = node["primitives"]
	if not primitives.is_empty():
		var bounds: AABB = _face_bounds[primitives[0]]
		for primitive_list_index: int in range(1, primitives.size()):
			bounds = bounds.merge(_face_bounds[primitives[primitive_list_index]])
		node["bounds"] = bounds
		_nodes[node_index] = node
		return
	var left: int = int(node["left"])
	var right: int = int(node["right"])
	if left >= 0 and right >= 0:
		var left_bounds: AABB = _nodes[left]["bounds"]
		var right_bounds: AABB = _nodes[right]["bounds"]
		node["bounds"] = left_bounds.merge(right_bounds)
	elif left >= 0:
		node["bounds"] = _nodes[left]["bounds"]
	elif right >= 0:
		node["bounds"] = _nodes[right]["bounds"]
	_nodes[node_index] = node


static func _ray_face_distance(
	ray_origin: Vector3,
	ray_direction: Vector3,
	source: GMSMeshData,
	face_index: int,
	maximum_distance: float
) -> float:
	var face: PackedInt32Array = source.faces[face_index]
	if face.size() < 3:
		return INF
	var nearest_distance: float = maximum_distance
	var a: Vector3 = source.vertices[face[0]]
	for triangle_index: int in range(1, face.size() - 1):
		var distance: float = _ray_triangle_distance(
			ray_origin,
			ray_direction,
			a,
			source.vertices[face[triangle_index]],
			source.vertices[face[triangle_index + 1]]
		)
		nearest_distance = minf(nearest_distance, distance)
	return nearest_distance


static func _axis_value(value: Vector3, axis: int) -> float:
	match axis:
		1:
			return value.y
		2:
			return value.z
		_:
			return value.x


static func _ray_intersects_aabb(
	ray_origin: Vector3,
	ray_direction: Vector3,
	bounds: AABB,
	maximum_distance: float
) -> bool:
	var minimum: Vector3 = bounds.position
	var maximum: Vector3 = bounds.end
	var near_distance: float = 0.0
	var far_distance: float = maximum_distance
	for axis: int in 3:
		var origin_value: float = _axis_value(ray_origin, axis)
		var direction_value: float = _axis_value(ray_direction, axis)
		var minimum_value: float = _axis_value(minimum, axis)
		var maximum_value: float = _axis_value(maximum, axis)
		if absf(direction_value) <= 0.0000001:
			if origin_value < minimum_value or origin_value > maximum_value:
				return false
			continue
		var inverse: float = 1.0 / direction_value
		var first: float = (minimum_value - origin_value) * inverse
		var second: float = (maximum_value - origin_value) * inverse
		if first > second:
			var swap: float = first
			first = second
			second = swap
		near_distance = maxf(near_distance, first)
		far_distance = minf(far_distance, second)
		if far_distance < near_distance:
			return false
	return far_distance >= 0.0


static func _ray_triangle_distance(
	ray_origin: Vector3,
	ray_direction: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> float:
	var edge_1: Vector3 = b - a
	var edge_2: Vector3 = c - a
	var p_vector: Vector3 = ray_direction.cross(edge_2)
	var determinant: float = edge_1.dot(p_vector)
	var determinant_scale: float = edge_1.length() * edge_2.length()
	var determinant_epsilon: float = maxf(determinant_scale * 0.0000000001, 0.000000000000001)
	if absf(determinant) <= determinant_epsilon:
		return INF
	var inverse_determinant: float = 1.0 / determinant
	var t_vector: Vector3 = ray_origin - a
	var barycentric_epsilon: float = 0.0000001
	var u: float = t_vector.dot(p_vector) * inverse_determinant
	if u < -barycentric_epsilon or u > 1.0 + barycentric_epsilon:
		return INF
	var q_vector: Vector3 = t_vector.cross(edge_1)
	var v: float = ray_direction.dot(q_vector) * inverse_determinant
	if v < -barycentric_epsilon or u + v > 1.0 + barycentric_epsilon:
		return INF
	var distance: float = edge_2.dot(q_vector) * inverse_determinant
	return distance if distance > 0.000000001 else INF

static func _closest_point_on_face(
	point: Vector3,
	source: GMSMeshData,
	face_index: int,
	maximum_distance_squared: float
) -> Dictionary:
	var face: PackedInt32Array = source.faces[face_index]
	if face.size() < 3:
		return {}
	var nearest_distance_squared: float = maximum_distance_squared
	var nearest_position: Vector3 = Vector3.ZERO
	var found: bool = false
	var a: Vector3 = source.vertices[face[0]]
	for triangle_index: int in range(1, face.size() - 1):
		var candidate: Vector3 = _closest_point_on_triangle(
			point,
			a,
			source.vertices[face[triangle_index]],
			source.vertices[face[triangle_index + 1]]
		)
		var distance_squared: float = point.distance_squared_to(candidate)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_position = candidate
			found = true
	if not found:
		return {}
	return {
		"position": nearest_position,
		"distance_squared": nearest_distance_squared,
	}


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
		var edge_amount: float = d1 / (d1 - d3)
		return a + ab * edge_amount

	var cp: Vector3 = point - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c

	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var edge_amount: float = d2 / (d2 - d6)
		return a + ac * edge_amount

	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var edge_amount: float = (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return b + (c - b) * edge_amount

	var denominator: float = va + vb + vc
	if absf(denominator) <= 0.0000001:
		return (a + b + c) / 3.0
	var inverse_denominator: float = 1.0 / denominator
	var v: float = vb * inverse_denominator
	var w: float = vc * inverse_denominator
	return a + ab * v + ac * w


static func _point_aabb_distance_squared(point: Vector3, bounds: AABB) -> float:
	var closest: Vector3 = Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		clampf(point.y, bounds.position.y, bounds.end.y),
		clampf(point.z, bounds.position.z, bounds.end.z)
	)
	return point.distance_squared_to(closest)

