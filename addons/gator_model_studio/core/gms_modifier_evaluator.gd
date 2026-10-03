@tool
class_name GMSModifierEvaluator
extends RefCounted


static func evaluate(source: GMSMeshData, modifiers: Array[GMSModifier]) -> GMSMeshData:
	if source == null:
		return null
	var has_enabled_modifier: bool = false
	for candidate_modifier: GMSModifier in modifiers:
		if candidate_modifier != null and candidate_modifier.enabled:
			has_enabled_modifier = true
			break
	if not has_enabled_modifier:
		return source
	var result: GMSMeshData = source
	for modifier: GMSModifier in modifiers:
		if modifier == null or not modifier.enabled:
			continue
		if modifier.is_custom():
			result = GMSModifierRegistry.evaluate(result, modifier)
			continue
		match modifier.kind:
			GMSModifier.Kind.MIRROR:
				result = apply_mirror(result, modifier)
			GMSModifier.Kind.ARRAY:
				result = apply_array(result, modifier)
			GMSModifier.Kind.SOLIDIFY:
				result = apply_solidify(result, modifier)
			GMSModifier.Kind.SIMPLE_SUBDIVIDE:
				result = apply_simple_subdivide(result, modifier)
			GMSModifier.Kind.SUBDIVISION_SURFACE:
				result = apply_subdivision_surface(result, modifier)
			GMSModifier.Kind.BEVEL:
				result = apply_bevel(result, modifier)
			GMSModifier.Kind.DECIMATE:
				result = apply_decimate(result, modifier)
			GMSModifier.Kind.TRIANGULATE:
				result = apply_triangulate(result, modifier)
			GMSModifier.Kind.WEIGHTED_NORMAL:
				result = apply_weighted_normal(result, modifier)
			GMSModifier.Kind.DISPLACE:
				result = apply_displace(result, modifier)
			GMSModifier.Kind.BEND:
				result = apply_bend(result, modifier)
			GMSModifier.Kind.SMOOTH:
				result = apply_smooth(result, modifier)
	return result


static func evaluate_from(
	source: GMSMeshData,
	modifiers: Array[GMSModifier],
	start_index: int,
	job: GMSBackgroundJob = null
) -> Dictionary:
	var current: GMSMeshData = source
	var stages: Array[GMSMeshData] = []
	var safe_start: int = clampi(start_index, 0, modifiers.size())
	var modifier_count: int = modifiers.size() - safe_start
	stages.resize(modifier_count)
	if job != null:
		job.update_progress(0.0, "Preparing modifier evaluation")
	for modifier_index: int in range(safe_start, modifiers.size()):
		if job != null and job.is_cancelled():
			return {
				"mesh": null,
				"stages": stages,
				"start_index": safe_start,
				"cancelled": true,
			}
		var stage_offset: int = modifier_index - safe_start
		var progress_start: float = float(stage_offset) / float(maxi(modifier_count, 1))
		var progress_end: float = float(stage_offset + 1) / float(maxi(modifier_count, 1))
		current = evaluate_single(
			current,
			modifiers[modifier_index],
			job,
			progress_start,
			progress_end
		)
		if job != null and job.is_cancelled():
			return {
				"mesh": null,
				"stages": stages,
				"start_index": safe_start,
				"cancelled": true,
			}
		stages[stage_offset] = current
	if job != null:
		job.update_progress(1.0, "Modifier evaluation complete")
	return {
		"mesh": current,
		"stages": stages,
		"start_index": safe_start,
		"cancelled": false,
	}

static func evaluate_through(
	source: GMSMeshData,
	modifiers: Array[GMSModifier],
	last_index: int
) -> GMSMeshData:
	if source == null:
		return null
	var end_index: int = mini(last_index, modifiers.size() - 1)
	var has_enabled_modifier: bool = false
	for candidate_index: int in range(end_index + 1):
		var candidate_modifier: GMSModifier = modifiers[candidate_index]
		if candidate_modifier != null and candidate_modifier.enabled:
			has_enabled_modifier = true
			break
	if not has_enabled_modifier:
		return source
	var result: GMSMeshData = source
	for modifier_index: int in range(end_index + 1):
		var modifier: GMSModifier = modifiers[modifier_index]
		if modifier == null or not modifier.enabled:
			continue
		if modifier.is_custom():
			result = GMSModifierRegistry.evaluate(result, modifier)
			continue
		match modifier.kind:
			GMSModifier.Kind.MIRROR:
				result = apply_mirror(result, modifier)
			GMSModifier.Kind.ARRAY:
				result = apply_array(result, modifier)
			GMSModifier.Kind.SOLIDIFY:
				result = apply_solidify(result, modifier)
			GMSModifier.Kind.SIMPLE_SUBDIVIDE:
				result = apply_simple_subdivide(result, modifier)
			GMSModifier.Kind.SUBDIVISION_SURFACE:
				result = apply_subdivision_surface(result, modifier)
			GMSModifier.Kind.BEVEL:
				result = apply_bevel(result, modifier)
			GMSModifier.Kind.DECIMATE:
				result = apply_decimate(result, modifier)
			GMSModifier.Kind.TRIANGULATE:
				result = apply_triangulate(result, modifier)
			GMSModifier.Kind.WEIGHTED_NORMAL:
				result = apply_weighted_normal(result, modifier)
			GMSModifier.Kind.DISPLACE:
				result = apply_displace(result, modifier)
			GMSModifier.Kind.BEND:
				result = apply_bend(result, modifier)
			GMSModifier.Kind.SMOOTH:
				result = apply_smooth(result, modifier)
	return result


static func evaluate_single(
	source: GMSMeshData,
	modifier: GMSModifier,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> GMSMeshData:
	if source == null:
		return null
	if modifier == null or not modifier.enabled:
		if job != null:
			job.update_progress(progress_end, "Skipping disabled modifier")
		return source
	if job != null and job.is_cancelled():
		return null
	var stage_name: String = "Evaluating %s" % modifier.get_display_name()
	if job != null:
		job.update_progress(progress_start, stage_name)
	var result: GMSMeshData = source
	if modifier.is_custom():
		result = GMSModifierRegistry.evaluate(source, modifier)
	else:
		match modifier.kind:
			GMSModifier.Kind.MIRROR:
				result = apply_mirror(source, modifier)
			GMSModifier.Kind.ARRAY:
				result = apply_array(source, modifier)
			GMSModifier.Kind.SOLIDIFY:
				result = apply_solidify(source, modifier)
			GMSModifier.Kind.SIMPLE_SUBDIVIDE:
				result = apply_simple_subdivide(
					source, modifier, job, progress_start, progress_end
				)
			GMSModifier.Kind.SUBDIVISION_SURFACE:
				result = apply_subdivision_surface(
					source, modifier, job, progress_start, progress_end
				)
			GMSModifier.Kind.BEVEL:
				result = apply_bevel(source, modifier)
			GMSModifier.Kind.DECIMATE:
				result = apply_decimate(source, modifier)
			GMSModifier.Kind.TRIANGULATE:
				result = apply_triangulate(source, modifier)
			GMSModifier.Kind.WEIGHTED_NORMAL:
				result = apply_weighted_normal(source, modifier)
			GMSModifier.Kind.DISPLACE:
				result = apply_displace(source, modifier)
			GMSModifier.Kind.BEND:
				result = apply_bend(source, modifier)
			GMSModifier.Kind.SMOOTH:
				result = apply_smooth(source, modifier)
	if job != null and not job.is_cancelled():
		job.update_progress(progress_end, "%s complete" % modifier.get_display_name())
	return result

static func apply_array(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	var count: int = maxi(1, modifier.array_count)
	if count == 1:
		return source.duplicate_mesh_data()

	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var uv_faces: Array[PackedVector2Array] = []
	var corner_normals: Array[PackedVector3Array] = []
	var loose_edges: Array[Vector2i] = []
	var crease_edges: Array[Vector2i] = []
	var crease_weights: PackedFloat32Array = PackedFloat32Array()
	var seam_edges: Array[Vector2i] = []
	var face_materials: PackedInt32Array = PackedInt32Array()
	var source_vertex_count: int = source.vertices.size()

	for copy_index: int in count:
		var offset: Vector3 = modifier.array_offset * float(copy_index)
		for vertex: Vector3 in source.vertices:
			vertices.append(vertex + offset)
		for face_index: int in source.faces.size():
			var source_face: PackedInt32Array = source.faces[face_index]
			var face: PackedInt32Array = PackedInt32Array()
			for vertex_index: int in source_face:
				face.append(vertex_index + copy_index * source_vertex_count)
			faces.append(face)
			face_materials.append(source.get_face_material(face_index))
			smooth.append(source.smooth_faces[face_index] if face_index < source.smooth_faces.size() else 0)
			if source.has_uv_map and face_index < source.uv_faces.size():
				uv_faces.append(source.uv_faces[face_index].duplicate())
			else:
				var blank_uv: PackedVector2Array = PackedVector2Array()
				blank_uv.resize(face.size())
				uv_faces.append(blank_uv)
			if source.has_custom_normals and face_index < source.corner_normals.size():
				corner_normals.append(source.corner_normals[face_index].duplicate())
			else:
				var blank_normals: PackedVector3Array = PackedVector3Array()
				blank_normals.resize(face.size())
				corner_normals.append(blank_normals)
		var vertex_offset: int = copy_index * source_vertex_count
		for edge: Vector2i in source.loose_edges:
			loose_edges.append(GMSMeshData.canonical_edge(edge.x + vertex_offset, edge.y + vertex_offset))
		for crease_index: int in source.crease_edges.size():
			var crease: Vector2i = source.crease_edges[crease_index]
			crease_edges.append(GMSMeshData.canonical_edge(crease.x + vertex_offset, crease.y + vertex_offset))
			crease_weights.append(source.crease_weights[crease_index])
		for seam: Vector2i in source.seam_edges:
			seam_edges.append(GMSMeshData.canonical_edge(seam.x + vertex_offset, seam.y + vertex_offset))

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		vertices,
		faces,
		smooth,
		uv_faces,
		source.has_uv_map,
		corner_normals,
		source.has_custom_normals,
		loose_edges,
		crease_edges,
		crease_weights,
		seam_edges,
		face_materials
	)
	return result


static func apply_mirror(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty():
		return source.duplicate_mesh_data() if source != null else null

	var axis_bits: Array[int] = []
	if modifier.mirror_x:
		axis_bits.append(1)
	if modifier.mirror_y:
		axis_bits.append(2)
	if modifier.mirror_z:
		axis_bits.append(4)
	if axis_bits.is_empty():
		return source.duplicate_mesh_data()

	var masks: Array[int] = [0]
	for axis_bit: int in axis_bits:
		var existing_count: int = masks.size()
		for mask_index: int in existing_count:
			masks.append(masks[mask_index] | axis_bit)

	var vertices: PackedVector3Array = PackedVector3Array()
	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var uv_faces: Array[PackedVector2Array] = []
	var corner_normals: Array[PackedVector3Array] = []
	var face_materials: PackedInt32Array = PackedInt32Array()
	var remaps: Array[PackedInt32Array] = []
	var merge_lookup: Dictionary = {}
	var threshold: float = maxf(modifier.merge_distance, 0.000001)

	for mask: int in masks:
		var remap: PackedInt32Array = PackedInt32Array()
		remap.resize(source.vertices.size())
		for vertex_index: int in source.vertices.size():
			var vertex: Vector3 = _mirrored_vertex(source.vertices[vertex_index], mask)
			var output_index: int = -1
			if modifier.merge and _is_near_enabled_plane(vertex, modifier, threshold):
				var key: Vector3i = _quantized_key(vertex, threshold)
				if merge_lookup.has(key):
					output_index = int(merge_lookup[key])
				else:
					output_index = vertices.size()
					vertices.append(vertex)
					merge_lookup[key] = output_index
			else:
				output_index = vertices.size()
				vertices.append(vertex)
			remap[vertex_index] = output_index
		remaps.append(remap)

	for mask_index: int in masks.size():
		var mask: int = masks[mask_index]
		var reverse_winding: bool = _bit_count(mask) % 2 == 1
		var remap: PackedInt32Array = remaps[mask_index]
		for face_index: int in source.faces.size():
			var source_face: PackedInt32Array = source.faces[face_index]
			var face: PackedInt32Array = PackedInt32Array()
			var face_uv: PackedVector2Array = PackedVector2Array()
			var face_normals: PackedVector3Array = PackedVector3Array()
			for corner_index: int in source_face.size():
				var source_corner: int = source_face.size() - 1 - corner_index if reverse_winding else corner_index
				face.append(remap[source_face[source_corner]])
				if source.has_uv_map and face_index < source.uv_faces.size():
					face_uv.append(source.uv_faces[face_index][source_corner])
				else:
					face_uv.append(Vector2.ZERO)
				if source.has_custom_normals and face_index < source.corner_normals.size():
					face_normals.append(_mirrored_vertex(source.corner_normals[face_index][source_corner], mask).normalized())
				else:
					face_normals.append(Vector3.ZERO)
			if _face_has_three_unique_vertices(face):
				faces.append(face)
				face_materials.append(source.get_face_material(face_index))
				smooth.append(source.smooth_faces[face_index] if face_index < source.smooth_faces.size() else 0)
				uv_faces.append(face_uv)
				corner_normals.append(face_normals)

	var loose_edges: Array[Vector2i] = []
	var crease_edges: Array[Vector2i] = []
	var crease_weights: PackedFloat32Array = PackedFloat32Array()
	var seam_edges: Array[Vector2i] = []
	for mask_index: int in masks.size():
		var remap: PackedInt32Array = remaps[mask_index]
		for edge: Vector2i in source.loose_edges:
			var mapped: Vector2i = GMSMeshData.canonical_edge(remap[edge.x], remap[edge.y])
			if mapped.x != mapped.y and not loose_edges.has(mapped):
				loose_edges.append(mapped)
		for crease_index: int in source.crease_edges.size():
			var source_edge: Vector2i = source.crease_edges[crease_index]
			var mapped: Vector2i = GMSMeshData.canonical_edge(remap[source_edge.x], remap[source_edge.y])
			if mapped.x == mapped.y or crease_edges.has(mapped):
				continue
			crease_edges.append(mapped)
			crease_weights.append(source.crease_weights[crease_index])
		for source_edge: Vector2i in source.seam_edges:
			var mapped: Vector2i = GMSMeshData.canonical_edge(remap[source_edge.x], remap[source_edge.y])
			if mapped.x != mapped.y and not seam_edges.has(mapped):
				seam_edges.append(mapped)

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		vertices,
		faces,
		smooth,
		uv_faces,
		source.has_uv_map,
		corner_normals,
		source.has_custom_normals,
		loose_edges,
		crease_edges,
		crease_weights,
		seam_edges,
		face_materials
	)
	return result


static func apply_solidify(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty() or source.faces.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	if is_zero_approx(modifier.thickness):
		return source.duplicate_mesh_data()

	var normals: PackedVector3Array = _build_vertex_normals(source)
	var front_distance: float = modifier.thickness * (modifier.solidify_offset + 1.0) * 0.5
	var back_distance: float = modifier.thickness * (modifier.solidify_offset - 1.0) * 0.5
	var vertices: PackedVector3Array = PackedVector3Array()
	var source_vertex_count: int = source.vertices.size()

	for vertex_index: int in source_vertex_count:
		vertices.append(source.vertices[vertex_index] + normals[vertex_index] * front_distance)
	for vertex_index: int in source_vertex_count:
		vertices.append(source.vertices[vertex_index] + normals[vertex_index] * back_distance)

	var faces: Array[PackedInt32Array] = []
	var smooth: PackedByteArray = PackedByteArray()
	var uv_faces: Array[PackedVector2Array] = []
	var face_materials: PackedInt32Array = PackedInt32Array()

	for face_index: int in source.faces.size():
		var source_face: PackedInt32Array = source.faces[face_index]
		faces.append(source_face.duplicate())
		face_materials.append(source.get_face_material(face_index))
		smooth.append(source.smooth_faces[face_index] if face_index < source.smooth_faces.size() else 0)
		uv_faces.append(_source_face_uv(source, face_index, false))

		var inner_face: PackedInt32Array = PackedInt32Array()
		for reverse_index: int in source_face.size():
			inner_face.append(source_face[source_face.size() - 1 - reverse_index] + source_vertex_count)
		faces.append(inner_face)
		face_materials.append(source.get_face_material(face_index))
		smooth.append(source.smooth_faces[face_index] if face_index < source.smooth_faces.size() else 0)
		uv_faces.append(_source_face_uv(source, face_index, true))

	var edge_use: Dictionary = {}
	var edge_direction: Dictionary = {}
	var edge_material: Dictionary = {}
	var seam_edges: Array[Vector2i] = []
	for edge: Vector2i in source.seam_edges:
		seam_edges.append(edge)
		seam_edges.append(GMSMeshData.canonical_edge(edge.x + source_vertex_count, edge.y + source_vertex_count))
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			edge_use[key] = int(edge_use.get(key, 0)) + 1
			if not edge_direction.has(key):
				edge_direction[key] = Vector2i(a, b)
				edge_material[key] = source.get_face_material(face_index)

	for key_variant: Variant in edge_use.keys():
		if int(edge_use[key_variant]) != 1:
			continue
		var edge: Vector2i = edge_direction[key_variant]
		var side: PackedInt32Array = PackedInt32Array([
			edge.x,
			edge.x + source_vertex_count,
			edge.y + source_vertex_count,
			edge.y,
		])
		faces.append(side)
		face_materials.append(int(edge_material.get(key_variant, 0)))
		smooth.append(0)
		var front_edge: Vector2i = GMSMeshData.canonical_edge(edge.x, edge.y)
		var back_edge: Vector2i = GMSMeshData.canonical_edge(edge.x + source_vertex_count, edge.y + source_vertex_count)
		if not seam_edges.has(front_edge):
			seam_edges.append(front_edge)
		if not seam_edges.has(back_edge):
			seam_edges.append(back_edge)
		uv_faces.append(PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(0.0, 1.0),
			Vector2(1.0, 1.0),
			Vector2(1.0, 0.0),
		]))

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		vertices,
		faces,
		smooth,
		uv_faces,
		source.has_uv_map,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		seam_edges,
		face_materials
	)
	return result


static func apply_simple_subdivide(
	source: GMSMeshData,
	modifier: GMSModifier,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> GMSMeshData:
	if source == null or source.faces.is_empty():
		return source.duplicate_mesh_data_fast() if source != null else null
	var result: GMSMeshData = source
	var levels: int = clampi(modifier.subdivision_levels, 1, 4)
	for level: int in levels:
		if job != null and job.is_cancelled():
			return null
		var level_start: float = lerpf(
			progress_start,
			progress_end,
			float(level) / float(levels)
		)
		var level_end: float = lerpf(
			progress_start,
			progress_end,
			float(level + 1) / float(levels)
		)
		result = _simple_subdivide_all_faces(
			result,
			job,
			level_start,
			level_end,
			"Simple Subdivide level %d of %d" % [level + 1, levels]
		)
		if result == null:
			if job != null and job.is_cancelled():
				return null
			return source.duplicate_mesh_data_fast()
	return result

static func _simple_subdivide_all_faces(
	source: GMSMeshData,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0,
	stage_name: String = "Simple Subdivide"
) -> GMSMeshData:
	var source_vertex_count: int = source.vertices.size()
	var source_face_count: int = source.faces.size()
	if source_vertex_count == 0 or source_face_count == 0:
		return source.duplicate_mesh_data_fast()

	_job_update_range(job, progress_start, progress_end, 0.0, stage_name)
	var total_corners: int = 0
	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		total_corners += source.faces[face_index].size()
		_job_update_loop(job, progress_start, progress_end, 0.0, 0.06, face_index, source_face_count, stage_name)

	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(source_vertex_count + total_corners + source_face_count)
	for vertex_index: int in source_vertex_count:
		if _job_should_cancel(job, vertex_index):
			return null
		vertices[vertex_index] = source.vertices[vertex_index]
		_job_update_loop(job, progress_start, progress_end, 0.06, 0.14, vertex_index, source_vertex_count, stage_name)

	var midpoint_indices: Dictionary = {}
	var next_vertex_index: int = source_vertex_count
	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		var face: PackedInt32Array = source.faces[face_index]
		var corner_count: int = face.size()
		for corner_index: int in corner_count:
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % corner_count]
			var key: int = _packed_edge_key(a, b)
			if midpoint_indices.has(key):
				continue
			midpoint_indices[key] = next_vertex_index
			vertices[next_vertex_index] = (source.vertices[a] + source.vertices[b]) * 0.5
			next_vertex_index += 1
		_job_update_loop(job, progress_start, progress_end, 0.14, 0.38, face_index, source_face_count, stage_name)

	var face_center_start: int = next_vertex_index
	vertices.resize(face_center_start + source_face_count)

	var faces: Array[PackedInt32Array] = []
	faces.resize(total_corners)
	var smooth_faces: PackedByteArray = PackedByteArray()
	smooth_faces.resize(total_corners)
	var face_materials: PackedInt32Array = PackedInt32Array()
	face_materials.resize(total_corners)
	var uv_faces: Array[PackedVector2Array] = []
	if source.has_uv_map:
		uv_faces.resize(total_corners)

	var output_face_index: int = 0
	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		var face: PackedInt32Array = source.faces[face_index]
		var corner_count: int = face.size()
		var center: Vector3 = Vector3.ZERO
		for vertex_index: int in face:
			center += source.vertices[vertex_index]
		center /= float(maxi(corner_count, 1))
		var center_index: int = face_center_start + face_index
		vertices[center_index] = center

		var smooth_value: int = int(source.smooth_faces[face_index]) if face_index < source.smooth_faces.size() else 0
		var material_index: int = int(source.face_materials[face_index]) if face_index < source.face_materials.size() else 0
		var source_uvs: PackedVector2Array = source.uv_faces[face_index] if source.has_uv_map and face_index < source.uv_faces.size() else PackedVector2Array()
		var center_uv: Vector2 = Vector2.ZERO
		if source.has_uv_map:
			for uv: Vector2 in source_uvs:
				center_uv += uv
			center_uv /= float(maxi(source_uvs.size(), 1))

		for corner_index: int in corner_count:
			var previous_corner: int = (corner_index - 1 + corner_count) % corner_count
			var next_corner: int = (corner_index + 1) % corner_count
			var previous_vertex: int = face[previous_corner]
			var current_vertex: int = face[corner_index]
			var next_vertex: int = face[next_corner]
			var previous_midpoint: int = int(midpoint_indices[_packed_edge_key(previous_vertex, current_vertex)])
			var next_midpoint: int = int(midpoint_indices[_packed_edge_key(current_vertex, next_vertex)])
			faces[output_face_index] = PackedInt32Array([
				current_vertex,
				next_midpoint,
				center_index,
				previous_midpoint,
			])
			smooth_faces[output_face_index] = smooth_value
			face_materials[output_face_index] = material_index
			if source.has_uv_map:
				var current_uv: Vector2 = source_uvs[corner_index]
				uv_faces[output_face_index] = PackedVector2Array([
					current_uv,
					(current_uv + source_uvs[next_corner]) * 0.5,
					center_uv,
					(source_uvs[previous_corner] + current_uv) * 0.5,
				])
			output_face_index += 1
		_job_update_loop(job, progress_start, progress_end, 0.38, 0.82, face_index, source_face_count, stage_name)

	var crease_edges: Array[Vector2i] = []
	var crease_weights: PackedFloat32Array = PackedFloat32Array()
	crease_edges.resize(source.crease_edges.size() * 2)
	crease_weights.resize(source.crease_edges.size() * 2)
	var crease_output_index: int = 0
	for crease_index: int in source.crease_edges.size():
		if _job_should_cancel(job, crease_index):
			return null
		var edge: Vector2i = source.crease_edges[crease_index]
		var midpoint_value: Variant = midpoint_indices.get(_packed_edge_key(edge.x, edge.y), null)
		var weight: float = source.crease_weights[crease_index] if crease_index < source.crease_weights.size() else 0.0
		if midpoint_value == null:
			crease_edges[crease_output_index] = edge
			crease_weights[crease_output_index] = weight
			crease_output_index += 1
		else:
			var midpoint: int = int(midpoint_value)
			crease_edges[crease_output_index] = GMSMeshData.canonical_edge(edge.x, midpoint)
			crease_weights[crease_output_index] = weight
			crease_output_index += 1
			crease_edges[crease_output_index] = GMSMeshData.canonical_edge(midpoint, edge.y)
			crease_weights[crease_output_index] = weight
			crease_output_index += 1
		_job_update_loop(job, progress_start, progress_end, 0.82, 0.89, crease_index, source.crease_edges.size(), stage_name)
	crease_edges.resize(crease_output_index)
	crease_weights.resize(crease_output_index)

	var seam_edges: Array[Vector2i] = []
	seam_edges.resize(source.seam_edges.size() * 2)
	var seam_output_index: int = 0
	for seam_index: int in source.seam_edges.size():
		if _job_should_cancel(job, seam_index):
			return null
		var edge: Vector2i = source.seam_edges[seam_index]
		var midpoint_value: Variant = midpoint_indices.get(_packed_edge_key(edge.x, edge.y), null)
		if midpoint_value == null:
			seam_edges[seam_output_index] = edge
			seam_output_index += 1
		else:
			var midpoint: int = int(midpoint_value)
			seam_edges[seam_output_index] = GMSMeshData.canonical_edge(edge.x, midpoint)
			seam_output_index += 1
			seam_edges[seam_output_index] = GMSMeshData.canonical_edge(midpoint, edge.y)
			seam_output_index += 1
		_job_update_loop(job, progress_start, progress_end, 0.89, 0.95, seam_index, source.seam_edges.size(), stage_name)
	seam_edges.resize(seam_output_index)

	if job != null and job.is_cancelled():
		return null
	_job_update_range(job, progress_start, progress_end, 0.97, "%s: finalizing geometry" % stage_name)
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry_internal(
		vertices,
		faces,
		smooth_faces,
		uv_faces,
		source.has_uv_map,
		[],
		false,
		source.loose_edges.duplicate(),
		crease_edges,
		crease_weights,
		seam_edges,
		face_materials
	)
	_job_update_range(job, progress_start, progress_end, 1.0, stage_name)
	return result

static func _packed_edge_key(a: int, b: int) -> int:
	var minimum: int = mini(a, b)
	var maximum: int = maxi(a, b)
	return (minimum << 32) | maximum


static func apply_subdivision_surface(
	source: GMSMeshData,
	modifier: GMSModifier,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> GMSMeshData:
	if source == null or source.faces.is_empty():
		return source.duplicate_mesh_data_fast() if source != null else null
	var result: GMSMeshData = source
	var levels: int = clampi(modifier.subdivision_levels, 1, 4)
	for level: int in levels:
		if job != null and job.is_cancelled():
			return null
		var level_start: float = lerpf(
			progress_start,
			progress_end,
			float(level) / float(levels)
		)
		var level_end: float = lerpf(
			progress_start,
			progress_end,
			float(level + 1) / float(levels)
		)
		result = _catmull_clark_level(
			result,
			job,
			level_start,
			level_end,
			"Subdivision Surface level %d of %d" % [level + 1, levels]
		)
		if result == null:
			if job != null and job.is_cancelled():
				return null
			return source.duplicate_mesh_data_fast()
	return result

static func _catmull_clark_level(
	source: GMSMeshData,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0,
	stage_name: String = "Subdivision Surface"
) -> GMSMeshData:
	var source_vertex_count: int = source.vertices.size()
	var source_face_count: int = source.faces.size()
	if source_vertex_count == 0 or source_face_count == 0:
		return source.duplicate_mesh_data_fast()

	_job_update_range(job, progress_start, progress_end, 0.0, stage_name)
	var face_points: PackedVector3Array = PackedVector3Array()
	face_points.resize(source_face_count)
	var vertex_faces: Array[PackedInt32Array] = []
	var vertex_edges: Array[PackedInt32Array] = []
	vertex_faces.resize(source_vertex_count)
	vertex_edges.resize(source_vertex_count)
	for vertex_index: int in source_vertex_count:
		if _job_should_cancel(job, vertex_index):
			return null
		vertex_faces[vertex_index] = PackedInt32Array()
		vertex_edges[vertex_index] = PackedInt32Array()
		_job_update_loop(job, progress_start, progress_end, 0.0, 0.04, vertex_index, source_vertex_count, stage_name)

	var edge_lookup: Dictionary = {}
	var edge_vertices: Array[Vector2i] = []
	var edge_face_a: PackedInt32Array = PackedInt32Array()
	var edge_face_b: PackedInt32Array = PackedInt32Array()
	var edge_face_count: PackedInt32Array = PackedInt32Array()
	var output_face_count: int = 0
	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		var face: PackedInt32Array = source.faces[face_index]
		output_face_count += face.size()
		var face_point: Vector3 = Vector3.ZERO
		for vertex_index: int in face:
			face_point += source.vertices[vertex_index]
			vertex_faces[vertex_index].append(face_index)
		face_points[face_index] = face_point / float(face.size())
		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var low: int = mini(a, b)
			var high: int = maxi(a, b)
			var key: int = (low << 32) | high
			var edge_index: int
			if edge_lookup.has(key):
				edge_index = int(edge_lookup[key])
				edge_face_count[edge_index] += 1
				if edge_face_count[edge_index] == 2:
					edge_face_b[edge_index] = face_index
			else:
				edge_index = edge_vertices.size()
				edge_lookup[key] = edge_index
				edge_vertices.append(Vector2i(low, high))
				edge_face_a.append(face_index)
				edge_face_b.append(-1)
				edge_face_count.append(1)
				vertex_edges[low].append(edge_index)
				vertex_edges[high].append(edge_index)
		_job_update_loop(job, progress_start, progress_end, 0.04, 0.24, face_index, source_face_count, "%s: building topology" % stage_name)

	var crease_lookup: Dictionary = {}
	for crease_index: int in source.crease_edges.size():
		if _job_should_cancel(job, crease_index):
			return null
		var crease_edge: Vector2i = source.crease_edges[crease_index]
		var crease_low: int = mini(crease_edge.x, crease_edge.y)
		var crease_high: int = maxi(crease_edge.x, crease_edge.y)
		crease_lookup[(crease_low << 32) | crease_high] = source.crease_weights[crease_index]
		_job_update_loop(job, progress_start, progress_end, 0.24, 0.27, crease_index, source.crease_edges.size(), stage_name)

	var edge_count: int = edge_vertices.size()
	var output_vertices: PackedVector3Array = PackedVector3Array()
	output_vertices.resize(source_vertex_count + edge_count + source_face_count)
	for vertex_index: int in source_vertex_count:
		if _job_should_cancel(job, vertex_index):
			return null
		var position: Vector3 = source.vertices[vertex_index]
		var adjacent_edges: PackedInt32Array = vertex_edges[vertex_index]
		var adjacent_faces: PackedInt32Array = vertex_faces[vertex_index]
		var boundary_count: int = 0
		var boundary_sum: Vector3 = Vector3.ZERO
		for edge_index: int in adjacent_edges:
			if edge_face_count[edge_index] != 1:
				continue
			var edge: Vector2i = edge_vertices[edge_index]
			var neighbor_index: int = edge.y if edge.x == vertex_index else edge.x
			boundary_count += 1
			boundary_sum += source.vertices[neighbor_index]

		var smooth_position: Vector3 = position
		if boundary_count >= 2:
			smooth_position = (position * 6.0 + boundary_sum) / float(6 + boundary_count)
		elif boundary_count == 1:
			smooth_position = (position * 3.0 + boundary_sum) * 0.25
		elif not adjacent_edges.is_empty() and not adjacent_faces.is_empty():
			var face_average: Vector3 = Vector3.ZERO
			for face_index: int in adjacent_faces:
				face_average += face_points[face_index]
			face_average /= float(adjacent_faces.size())
			var edge_midpoint_average: Vector3 = Vector3.ZERO
			for edge_index: int in adjacent_edges:
				var edge: Vector2i = edge_vertices[edge_index]
				var neighbor_index: int = edge.y if edge.x == vertex_index else edge.x
				edge_midpoint_average += (position + source.vertices[neighbor_index]) * 0.5
			edge_midpoint_average /= float(adjacent_edges.size())
			var valence: int = adjacent_edges.size()
			smooth_position = (
				face_average
				+ edge_midpoint_average * 2.0
				+ position * float(valence - 3)
			) / float(valence)

		var crease_count: int = 0
		var first_crease_neighbor: int = -1
		var second_crease_neighbor: int = -1
		var first_crease_strength: float = 0.0
		var second_crease_strength: float = 0.0
		var maximum_crease_strength: float = 0.0
		for edge_index: int in adjacent_edges:
			var edge: Vector2i = edge_vertices[edge_index]
			var key: int = (edge.x << 32) | edge.y
			var strength: float = 1.0 if edge_face_count[edge_index] == 1 else float(crease_lookup.get(key, 0.0))
			if strength <= 0.000001:
				continue
			var neighbor_index: int = edge.y if edge.x == vertex_index else edge.x
			if crease_count == 0:
				first_crease_neighbor = neighbor_index
				first_crease_strength = strength
			elif crease_count == 1:
				second_crease_neighbor = neighbor_index
				second_crease_strength = strength
			crease_count += 1
			maximum_crease_strength = maxf(maximum_crease_strength, strength)

		var final_position: Vector3 = smooth_position
		if crease_count >= 3:
			final_position = smooth_position.lerp(position, maximum_crease_strength)
		elif crease_count == 2:
			var crease_position: Vector3 = (
				position * 6.0
				+ source.vertices[first_crease_neighbor]
				+ source.vertices[second_crease_neighbor]
			) * 0.125
			final_position = smooth_position.lerp(
				crease_position,
				minf(first_crease_strength, second_crease_strength)
			)
		elif crease_count == 1:
			final_position = smooth_position.lerp(position, first_crease_strength * 0.5)
		output_vertices[vertex_index] = final_position
		_job_update_loop(job, progress_start, progress_end, 0.27, 0.54, vertex_index, source_vertex_count, "%s: updating vertices" % stage_name)

	for edge_index: int in edge_count:
		if _job_should_cancel(job, edge_index):
			return null
		var edge: Vector2i = edge_vertices[edge_index]
		var sharp_point: Vector3 = (source.vertices[edge.x] + source.vertices[edge.y]) * 0.5
		var smooth_point: Vector3 = sharp_point
		if edge_face_count[edge_index] == 2:
			smooth_point = (
				source.vertices[edge.x]
				+ source.vertices[edge.y]
				+ face_points[edge_face_a[edge_index]]
				+ face_points[edge_face_b[edge_index]]
			) * 0.25
		var key: int = (edge.x << 32) | edge.y
		var crease: float = 1.0 if edge_face_count[edge_index] == 1 else float(crease_lookup.get(key, 0.0))
		output_vertices[source_vertex_count + edge_index] = smooth_point.lerp(sharp_point, crease)
		_job_update_loop(job, progress_start, progress_end, 0.54, 0.64, edge_index, edge_count, "%s: creating edge points" % stage_name)

	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		output_vertices[source_vertex_count + edge_count + face_index] = face_points[face_index]
		_job_update_loop(job, progress_start, progress_end, 0.64, 0.68, face_index, source_face_count, stage_name)

	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_uv_faces: Array[PackedVector2Array] = []
	var output_face_materials: PackedInt32Array = PackedInt32Array()
	output_faces.resize(output_face_count)
	output_smooth.resize(output_face_count)
	output_face_materials.resize(output_face_count)
	if source.has_uv_map:
		output_uv_faces.resize(output_face_count)
	var output_face_index: int = 0
	for face_index: int in source_face_count:
		if _job_should_cancel(job, face_index):
			return null
		var face: PackedInt32Array = source.faces[face_index]
		var face_uvs: PackedVector2Array = source.uv_faces[face_index] if source.has_uv_map else PackedVector2Array()
		var face_uv_point: Vector2 = Vector2.ZERO
		if source.has_uv_map:
			for uv: Vector2 in face_uvs:
				face_uv_point += uv
			face_uv_point /= float(face_uvs.size())
		var material_index: int = source.face_materials[face_index] if face_index < source.face_materials.size() else 0
		for corner_index: int in face.size():
			var previous_corner: int = (corner_index - 1 + face.size()) % face.size()
			var next_corner: int = (corner_index + 1) % face.size()
			var current_vertex: int = face[corner_index]
			var previous_vertex: int = face[previous_corner]
			var next_vertex: int = face[next_corner]
			var previous_low: int = mini(previous_vertex, current_vertex)
			var previous_high: int = maxi(previous_vertex, current_vertex)
			var next_low: int = mini(current_vertex, next_vertex)
			var next_high: int = maxi(current_vertex, next_vertex)
			var previous_edge_index: int = int(edge_lookup[(previous_low << 32) | previous_high])
			var next_edge_index: int = int(edge_lookup[(next_low << 32) | next_high])
			output_faces[output_face_index] = PackedInt32Array([
				current_vertex,
				source_vertex_count + next_edge_index,
				source_vertex_count + edge_count + face_index,
				source_vertex_count + previous_edge_index,
			])
			output_smooth[output_face_index] = 1
			output_face_materials[output_face_index] = material_index
			if source.has_uv_map:
				var current_uv: Vector2 = face_uvs[corner_index]
				output_uv_faces[output_face_index] = PackedVector2Array([
					current_uv,
					(current_uv + face_uvs[next_corner]) * 0.5,
					face_uv_point,
					(face_uvs[previous_corner] + current_uv) * 0.5,
				])
			output_face_index += 1
		_job_update_loop(job, progress_start, progress_end, 0.68, 0.91, face_index, source_face_count, "%s: rebuilding faces" % stage_name)

	var output_creases: Array[Vector2i] = []
	var output_crease_weights: PackedFloat32Array = PackedFloat32Array()
	for crease_index: int in source.crease_edges.size():
		if _job_should_cancel(job, crease_index):
			return null
		var edge: Vector2i = source.crease_edges[crease_index]
		var low: int = mini(edge.x, edge.y)
		var high: int = maxi(edge.x, edge.y)
		var key: int = (low << 32) | high
		if edge_lookup.has(key):
			var edge_point_index: int = source_vertex_count + int(edge_lookup[key])
			var strength: float = source.crease_weights[crease_index]
			output_creases.append(GMSMeshData.canonical_edge(edge.x, edge_point_index))
			output_crease_weights.append(strength)
			output_creases.append(GMSMeshData.canonical_edge(edge_point_index, edge.y))
			output_crease_weights.append(strength)
		_job_update_loop(job, progress_start, progress_end, 0.91, 0.95, crease_index, source.crease_edges.size(), stage_name)

	var output_seams: Array[Vector2i] = []
	for seam_index: int in source.seam_edges.size():
		if _job_should_cancel(job, seam_index):
			return null
		var edge: Vector2i = source.seam_edges[seam_index]
		var low: int = mini(edge.x, edge.y)
		var high: int = maxi(edge.x, edge.y)
		var key: int = (low << 32) | high
		if edge_lookup.has(key):
			var edge_point_index: int = source_vertex_count + int(edge_lookup[key])
			output_seams.append(GMSMeshData.canonical_edge(edge.x, edge_point_index))
			output_seams.append(GMSMeshData.canonical_edge(edge_point_index, edge.y))
		_job_update_loop(job, progress_start, progress_end, 0.95, 0.98, seam_index, source.seam_edges.size(), stage_name)

	if job != null and job.is_cancelled():
		return null
	_job_update_range(job, progress_start, progress_end, 0.99, "%s: finalizing geometry" % stage_name)
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry_internal(
		output_vertices,
		output_faces,
		output_smooth,
		output_uv_faces,
		source.has_uv_map,
		[],
		false,
		source.loose_edges.duplicate(),
		output_creases,
		output_crease_weights,
		output_seams,
		output_face_materials
	)
	_job_update_range(job, progress_start, progress_end, 1.0, stage_name)
	return result

static func apply_bevel(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.faces.is_empty() or modifier.bevel_width <= 0.0:
		return source.duplicate_mesh_data() if source != null else null
	var result: GMSMeshData = source.duplicate_mesh_data()
	var segments: int = clampi(modifier.bevel_segments, 1, 4)
	var step_width: float = modifier.bevel_width / float(segments)
	for _segment: int in segments:
		result = _bevel_once(result, step_width)
		if result == null or not result.is_valid():
			return source.duplicate_mesh_data()
	return result


static func _bevel_once(source: GMSMeshData, width: float) -> GMSMeshData:
	var output_vertices: PackedVector3Array = PackedVector3Array()
	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_uv_faces: Array[PackedVector2Array] = []
	var output_face_materials: PackedInt32Array = PackedInt32Array()
	var incident_corners: Array[PackedInt32Array] = []
	var incident_faces: Array[PackedInt32Array] = []
	incident_corners.resize(source.vertices.size())
	incident_faces.resize(source.vertices.size())
	for vertex_index: int in source.vertices.size():
		incident_corners[vertex_index] = PackedInt32Array()
		incident_faces[vertex_index] = PackedInt32Array()

	var edge_records: Dictionary = {}
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		var inset_face: PackedInt32Array = PackedInt32Array()
		var inset_uv: PackedVector2Array = PackedVector2Array()
		for corner_index: int in face.size():
			var previous_index: int = face[(corner_index - 1 + face.size()) % face.size()]
			var vertex_index: int = face[corner_index]
			var next_index: int = face[(corner_index + 1) % face.size()]
			var point: Vector3 = source.vertices[vertex_index]
			var previous_direction: Vector3 = (source.vertices[previous_index] - point).normalized()
			var next_direction: Vector3 = (source.vertices[next_index] - point).normalized()
			var bisector: Vector3 = previous_direction + next_direction
			var inset_point: Vector3 = point
			if not bisector.is_zero_approx():
				bisector = bisector.normalized()
				var interior_cosine: float = clampf(previous_direction.dot(next_direction), -1.0, 1.0)
				var half_sine: float = sqrt(maxf((1.0 - interior_cosine) * 0.5, 0.000001))
				var requested_distance: float = width / half_sine
				var max_distance: float = minf(
					point.distance_to(source.vertices[previous_index]),
					point.distance_to(source.vertices[next_index])
				) * 0.45
				inset_point += bisector * minf(requested_distance, max_distance)

			var output_index: int = output_vertices.size()
			output_vertices.append(inset_point)
			inset_face.append(output_index)
			incident_corners[vertex_index].append(output_index)
			incident_faces[vertex_index].append(face_index)
			if source.has_uv_map:
				inset_uv.append(source.uv_faces[face_index][corner_index])
			else:
				inset_uv.append(Vector2.ZERO)

		output_faces.append(inset_face)
		output_smooth.append(source.smooth_faces[face_index])
		output_uv_faces.append(inset_uv)
		output_face_materials.append(source.get_face_material(face_index))

		for corner_index: int in face.size():
			var a: int = face[corner_index]
			var b: int = face[(corner_index + 1) % face.size()]
			var edge: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			var record: PackedInt32Array = PackedInt32Array([
				a,
				b,
				inset_face[corner_index],
				inset_face[(corner_index + 1) % face.size()],
				face_index,
			])
			var records: Array = edge_records.get(edge, [])
			records.append(record)
			edge_records[edge] = records

	for edge_variant: Variant in edge_records.keys():
		var edge: Vector2i = edge_variant
		var records: Array = edge_records[edge]
		if records.size() != 2:
			continue
		var first: PackedInt32Array = records[0]
		var second: PackedInt32Array = records[1]
		var first_min: int = first[2] if first[0] == edge.x else first[3]
		var first_max: int = first[3] if first[1] == edge.y else first[2]
		var second_min: int = second[2] if second[0] == edge.x else second[3]
		var second_max: int = second[3] if second[1] == edge.y else second[2]
		var bridge: PackedInt32Array = PackedInt32Array([first_min, first_max, second_max, second_min])
		var target_normal: Vector3 = source.get_face_normal(first[4]) + source.get_face_normal(second[4])
		if _polygon_normal(output_vertices, bridge).dot(target_normal) < 0.0:
			bridge.reverse()
		output_faces.append(bridge)
		output_smooth.append(1)
		output_uv_faces.append(_blank_uv(4))
		output_face_materials.append(source.get_face_material(first[4]))

	for source_vertex_index: int in source.vertices.size():
		var corners: PackedInt32Array = incident_corners[source_vertex_index]
		if corners.size() < 3:
			continue
		var normal_sum: Vector3 = Vector3.ZERO
		for face_index: int in incident_faces[source_vertex_index]:
			normal_sum += source.get_face_normal(face_index)
		if normal_sum.is_zero_approx():
			continue
		var cap_normal: Vector3 = normal_sum.normalized()
		var tangent: Vector3 = cap_normal.cross(Vector3.UP)
		if tangent.length_squared() < 0.000001:
			tangent = cap_normal.cross(Vector3.RIGHT)
		tangent = tangent.normalized()
		var bitangent: Vector3 = cap_normal.cross(tangent).normalized()
		var sorted_corners: PackedInt32Array = corners.duplicate()
		for first_index: int in sorted_corners.size():
			var smallest_index: int = first_index
			var smallest_angle: float = _corner_angle_about_vertex(
				output_vertices[sorted_corners[first_index]],
				source.vertices[source_vertex_index],
				tangent,
				bitangent
			)
			for candidate_index: int in range(first_index + 1, sorted_corners.size()):
				var candidate_angle: float = _corner_angle_about_vertex(
					output_vertices[sorted_corners[candidate_index]],
					source.vertices[source_vertex_index],
					tangent,
					bitangent
				)
				if candidate_angle < smallest_angle:
					smallest_angle = candidate_angle
					smallest_index = candidate_index
			if smallest_index != first_index:
				var temporary: int = sorted_corners[first_index]
				sorted_corners[first_index] = sorted_corners[smallest_index]
				sorted_corners[smallest_index] = temporary
		if _polygon_normal(output_vertices, sorted_corners).dot(cap_normal) < 0.0:
			sorted_corners.reverse()
		output_faces.append(sorted_corners)
		output_smooth.append(1)
		output_uv_faces.append(_blank_uv(sorted_corners.size()))
		var cap_material: int = 0
		if not incident_faces[source_vertex_index].is_empty():
			cap_material = source.get_face_material(incident_faces[source_vertex_index][0])
		output_face_materials.append(cap_material)

	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		output_uv_faces,
		source.has_uv_map,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		[],
		output_face_materials
	)
	return result


static func apply_decimate(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.size() < 5:
		return source.duplicate_mesh_data() if source != null else null
	var ratio: float = clampf(modifier.decimate_ratio, 0.01, 1.0)
	var target_count: int = maxi(4, roundi(float(source.vertices.size()) * ratio))
	if target_count >= source.vertices.size():
		return source.duplicate_mesh_data()

	var bounds: AABB = source.get_aabb()
	var best_resolution: int = 1
	var best_difference: int = 2147483647
	for resolution: int in range(1, 65):
		var unique: Dictionary = {}
		for vertex: Vector3 in source.vertices:
			unique[_decimate_key(vertex, bounds, resolution)] = true
		var difference: int = absi(unique.size() - target_count)
		if difference < best_difference:
			best_difference = difference
			best_resolution = resolution
		if unique.size() == target_count:
			break

	var key_to_index: Dictionary = {}
	var sums: PackedVector3Array = PackedVector3Array()
	var counts: PackedInt32Array = PackedInt32Array()
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(source.vertices.size())
	for vertex_index: int in source.vertices.size():
		var key: Vector3i = _decimate_key(source.vertices[vertex_index], bounds, best_resolution)
		var output_index: int
		if key_to_index.has(key):
			output_index = int(key_to_index[key])
			sums[output_index] += source.vertices[vertex_index]
			counts[output_index] += 1
		else:
			output_index = sums.size()
			key_to_index[key] = output_index
			sums.append(source.vertices[vertex_index])
			counts.append(1)
		remap[vertex_index] = output_index

	var output_vertices: PackedVector3Array = PackedVector3Array()
	for output_index: int in sums.size():
		output_vertices.append(sums[output_index] / float(counts[output_index]))

	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_uv_faces: Array[PackedVector2Array] = []
	var output_face_materials: PackedInt32Array = PackedInt32Array()
	var known_faces: Dictionary = {}
	for face_index: int in source.faces.size():
		var source_face: PackedInt32Array = source.faces[face_index]
		var source_uv: PackedVector2Array = source.uv_faces[face_index]
		var face: PackedInt32Array = PackedInt32Array()
		var face_uv: PackedVector2Array = PackedVector2Array()
		for corner_index: int in source_face.size():
			var mapped: int = remap[source_face[corner_index]]
			if face.is_empty() or face[face.size() - 1] != mapped:
				face.append(mapped)
				face_uv.append(source_uv[corner_index] if source.has_uv_map else Vector2.ZERO)
		if face.size() > 1 and face[0] == face[face.size() - 1]:
			face.resize(face.size() - 1)
			face_uv.resize(face_uv.size() - 1)
		if _unique_vertex_count(face) < 3:
			continue
		var face_key: String = _canonical_face_key(face)
		if known_faces.has(face_key):
			continue
		known_faces[face_key] = true
		output_faces.append(face)
		output_face_materials.append(source.get_face_material(face_index))
		output_smooth.append(source.smooth_faces[face_index])
		output_uv_faces.append(face_uv)

	if output_faces.is_empty():
		return source.duplicate_mesh_data()
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		output_vertices,
		output_faces,
		output_smooth,
		output_uv_faces,
		source.has_uv_map,
		[],
		false,
		[],
		[],
		PackedFloat32Array(),
		[],
		output_face_materials
	)
	return GMSMeshOperations.remove_unused_vertices(result)


static func apply_triangulate(source: GMSMeshData, _modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.faces.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	var output_faces: Array[PackedInt32Array] = []
	var output_smooth: PackedByteArray = PackedByteArray()
	var output_uv_faces: Array[PackedVector2Array] = []
	var output_corner_normals: Array[PackedVector3Array] = []
	var output_face_materials: PackedInt32Array = PackedInt32Array()
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		if face.size() <= 3:
			output_faces.append(face.duplicate())
			output_smooth.append(source.smooth_faces[face_index])
			output_uv_faces.append(source.uv_faces[face_index].duplicate())
			output_corner_normals.append(source.corner_normals[face_index].duplicate())
			output_face_materials.append(source.get_face_material(face_index))
			continue
		for triangle_index: int in range(1, face.size() - 1):
			output_faces.append(PackedInt32Array([
				face[0],
				face[triangle_index],
				face[triangle_index + 1],
			]))
			output_smooth.append(source.smooth_faces[face_index])
			output_uv_faces.append(PackedVector2Array([
				source.uv_faces[face_index][0],
				source.uv_faces[face_index][triangle_index],
				source.uv_faces[face_index][triangle_index + 1],
			]))
			output_face_materials.append(source.get_face_material(face_index))
			output_corner_normals.append(PackedVector3Array([
				source.corner_normals[face_index][0],
				source.corner_normals[face_index][triangle_index],
				source.corner_normals[face_index][triangle_index + 1],
			]))
	var result: GMSMeshData = GMSMeshData.new()
	result.set_geometry(
		source.vertices.duplicate(),
		output_faces,
		output_smooth,
		output_uv_faces,
		source.has_uv_map,
		output_corner_normals,
		source.has_custom_normals,
		source.loose_edges,
		source.crease_edges,
		source.crease_weights,
		source.seam_edges,
		output_face_materials
	)
	return result


static func apply_weighted_normal(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.faces.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	var face_normals: PackedVector3Array = PackedVector3Array()
	var face_areas: PackedFloat32Array = PackedFloat32Array()
	face_normals.resize(source.faces.size())
	face_areas.resize(source.faces.size())
	for face_index: int in source.faces.size():
		face_normals[face_index] = source.get_face_normal(face_index)
		face_areas[face_index] = maxf(_face_area(source, face_index), 0.000001)

	var accumulated: PackedVector3Array = PackedVector3Array()
	accumulated.resize(source.vertices.size())
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		var area_weight: float = pow(face_areas[face_index], modifier.weighted_normal_power)
		for corner_index: int in face.size():
			var angle_weight: float = _face_corner_angle(source, face_index, corner_index)
			accumulated[face[corner_index]] += face_normals[face_index] * area_weight * angle_weight

	for vertex_index: int in accumulated.size():
		if accumulated[vertex_index].is_zero_approx():
			accumulated[vertex_index] = Vector3.UP
		else:
			accumulated[vertex_index] = accumulated[vertex_index].normalized()

	var custom_normals: Array[PackedVector3Array] = []
	var strength: float = clampf(modifier.weighted_normal_strength, 0.0, 1.0)
	for face_index: int in source.faces.size():
		var face: PackedInt32Array = source.faces[face_index]
		var values: PackedVector3Array = PackedVector3Array()
		for vertex_index: int in face:
			var target: Vector3 = accumulated[vertex_index]
			if modifier.weighted_normal_keep_sharp and source.smooth_faces[face_index] == 0:
				target = face_normals[face_index]
			var blended: Vector3 = face_normals[face_index].lerp(target, strength)
			values.append(blended.normalized() if not blended.is_zero_approx() else face_normals[face_index])
		custom_normals.append(values)

	var result: GMSMeshData = source.duplicate_mesh_data()
	result.corner_normals = custom_normals
	result.has_custom_normals = true
	result.emit_changed()
	return result


static func apply_displace(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty() or is_zero_approx(modifier.displace_strength):
		return source.duplicate_mesh_data() if source != null else null
	var normals: PackedVector3Array = _build_vertex_normals(source)
	var result: GMSMeshData = source.duplicate_mesh_data()
	for vertex_index: int in result.vertices.size():
		var direction: Vector3 = Vector3.ZERO
		match modifier.displace_direction:
			GMSModifier.Axis.X:
				direction = Vector3.RIGHT
			GMSModifier.Axis.Y:
				direction = Vector3.UP
			GMSModifier.Axis.Z:
				direction = Vector3.BACK
			_:
				direction = normals[vertex_index]
		var sample: float = 1.0
		if modifier.displace_noise:
			sample = _value_noise_3d(
				source.vertices[vertex_index] * maxf(modifier.displace_scale, 0.001),
				modifier.displace_seed
			)
		result.vertices[vertex_index] += direction * modifier.displace_strength * sample
	result.invalidate_custom_normals()
	result.emit_changed()
	return result


static func apply_bend(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	var angle: float = deg_to_rad(modifier.bend_angle_degrees)
	if absf(angle) < 0.000001:
		return source.duplicate_mesh_data()
	var bounds: AABB = source.get_aabb()
	var center: Vector3 = bounds.get_center()
	var length: float
	match modifier.bend_axis:
		GMSModifier.Axis.X:
			length = bounds.size.x
		GMSModifier.Axis.Z:
			length = bounds.size.z
		_:
			length = bounds.size.y
	if length < 0.000001:
		return source.duplicate_mesh_data()
	var radius: float = length / angle
	var result: GMSMeshData = source.duplicate_mesh_data()
	for vertex_index: int in result.vertices.size():
		var point: Vector3 = source.vertices[vertex_index]
		match modifier.bend_axis:
			GMSModifier.Axis.X:
				var theta_x: float = (point.x - center.x) / radius
				var radial_x: float = radius + point.y - center.y
				point.x = center.x + sin(theta_x) * radial_x
				point.y = center.y + cos(theta_x) * radial_x - radius
			GMSModifier.Axis.Z:
				var theta_z: float = (point.z - center.z) / radius
				var radial_z: float = radius + point.y - center.y
				point.z = center.z + sin(theta_z) * radial_z
				point.y = center.y + cos(theta_z) * radial_z - radius
			_:
				var theta_y: float = (point.y - center.y) / radius
				var radial_y: float = radius + point.x - center.x
				point.y = center.y + sin(theta_y) * radial_y
				point.x = center.x + cos(theta_y) * radial_y - radius
		result.vertices[vertex_index] = point
	result.invalidate_custom_normals()
	result.emit_changed()
	return result


static func apply_smooth(source: GMSMeshData, modifier: GMSModifier) -> GMSMeshData:
	if source == null or source.vertices.is_empty():
		return source.duplicate_mesh_data() if source != null else null
	var topology: GMSTopology = source.get_topology()
	var neighbors: Array[PackedInt32Array] = topology.vertex_neighbors
	var boundary_vertices: Dictionary = {}
	for boundary_edge: Vector2i in topology.get_boundary_edges():
		boundary_vertices[boundary_edge.x] = true
		boundary_vertices[boundary_edge.y] = true

	var positions: PackedVector3Array = source.vertices.duplicate()
	var factor: float = clampf(modifier.smooth_factor, 0.0, 1.0)
	var iterations: int = clampi(modifier.smooth_iterations, 1, 50)
	for _iteration: int in iterations:
		var next_positions: PackedVector3Array = positions.duplicate()
		for vertex_index: int in positions.size():
			if modifier.smooth_preserve_boundary and boundary_vertices.has(vertex_index):
				continue
			var vertex_neighbors: PackedInt32Array = neighbors[vertex_index]
			if vertex_neighbors.is_empty():
				continue
			var average: Vector3 = Vector3.ZERO
			for neighbor_index: int in vertex_neighbors:
				average += positions[neighbor_index]
			average /= float(vertex_neighbors.size())
			next_positions[vertex_index] = positions[vertex_index].lerp(average, factor)
		positions = next_positions

	var result: GMSMeshData = source.duplicate_mesh_data()
	result.vertices = positions
	result.invalidate_custom_normals()
	result.emit_changed()
	return result


static func _job_should_cancel(job: GMSBackgroundJob, iteration: int) -> bool:
	return job != null and iteration % 64 == 0 and job.is_cancelled()


static func _job_update_loop(
	job: GMSBackgroundJob,
	progress_start: float,
	progress_end: float,
	local_start: float,
	local_end: float,
	iteration: int,
	count: int,
	stage: String
) -> void:
	if job == null or iteration % 64 != 0:
		return
	var fraction: float = float(iteration) / float(maxi(count, 1))
	var local_progress: float = lerpf(local_start, local_end, fraction)
	_job_update_range(job, progress_start, progress_end, local_progress, stage)


static func _job_update_range(
	job: GMSBackgroundJob,
	progress_start: float,
	progress_end: float,
	local_progress: float,
	stage: String
) -> void:
	if job == null:
		return
	job.update_progress(
		lerpf(progress_start, progress_end, clampf(local_progress, 0.0, 1.0)),
		stage
	)


static func _blank_uv(size: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	result.resize(size)
	return result


static func _corner_angle_about_vertex(
	point: Vector3,
	origin: Vector3,
	tangent: Vector3,
	bitangent: Vector3
) -> float:
	var direction: Vector3 = point - origin
	return atan2(direction.dot(bitangent), direction.dot(tangent))


static func _polygon_normal(vertices: PackedVector3Array, face: PackedInt32Array) -> Vector3:
	if face.size() < 3:
		return Vector3.ZERO
	var origin: Vector3 = vertices[face[0]]
	for triangle_index: int in range(1, face.size() - 1):
		var normal: Vector3 = (vertices[face[triangle_index]] - origin).cross(
			vertices[face[triangle_index + 1]] - origin
		)
		if not normal.is_zero_approx():
			return normal.normalized()
	return Vector3.ZERO


static func _decimate_key(point: Vector3, bounds: AABB, resolution: int) -> Vector3i:
	var relative: Vector3 = point - bounds.position
	var normalized: Vector3 = Vector3.ZERO
	normalized.x = relative.x / bounds.size.x if bounds.size.x > 0.000001 else 0.0
	normalized.y = relative.y / bounds.size.y if bounds.size.y > 0.000001 else 0.0
	normalized.z = relative.z / bounds.size.z if bounds.size.z > 0.000001 else 0.0
	return Vector3i(
		clampi(floori(normalized.x * float(resolution)), 0, resolution - 1),
		clampi(floori(normalized.y * float(resolution)), 0, resolution - 1),
		clampi(floori(normalized.z * float(resolution)), 0, resolution - 1)
	)


static func _unique_vertex_count(face: PackedInt32Array) -> int:
	var unique: Dictionary = {}
	for vertex_index: int in face:
		unique[vertex_index] = true
	return unique.size()


static func _canonical_face_key(face: PackedInt32Array) -> String:
	var values: Array[int] = []
	for vertex_index: int in face:
		values.append(vertex_index)
	values.sort()
	var parts: PackedStringArray = PackedStringArray()
	for vertex_index: int in values:
		parts.append(str(vertex_index))
	return ",".join(parts)


static func _face_area(source: GMSMeshData, face_index: int) -> float:
	var face: PackedInt32Array = source.faces[face_index]
	var origin: Vector3 = source.vertices[face[0]]
	var area: float = 0.0
	for triangle_index: int in range(1, face.size() - 1):
		area += (source.vertices[face[triangle_index]] - origin).cross(
			source.vertices[face[triangle_index + 1]] - origin
		).length() * 0.5
	return area


static func _face_corner_angle(source: GMSMeshData, face_index: int, corner_index: int) -> float:
	var face: PackedInt32Array = source.faces[face_index]
	var point: Vector3 = source.vertices[face[corner_index]]
	var previous: Vector3 = source.vertices[face[(corner_index - 1 + face.size()) % face.size()]]
	var next: Vector3 = source.vertices[face[(corner_index + 1) % face.size()]]
	var first: Vector3 = (previous - point).normalized()
	var second: Vector3 = (next - point).normalized()
	return acos(clampf(first.dot(second), -1.0, 1.0))


static func _value_noise_3d(point: Vector3, seed: int) -> float:
	var x0: int = floori(point.x)
	var y0: int = floori(point.y)
	var z0: int = floori(point.z)
	var tx: float = _smooth_noise_fraction(point.x - float(x0))
	var ty: float = _smooth_noise_fraction(point.y - float(y0))
	var tz: float = _smooth_noise_fraction(point.z - float(z0))
	var x00: float = lerpf(_noise_hash(x0, y0, z0, seed), _noise_hash(x0 + 1, y0, z0, seed), tx)
	var x10: float = lerpf(_noise_hash(x0, y0 + 1, z0, seed), _noise_hash(x0 + 1, y0 + 1, z0, seed), tx)
	var x01: float = lerpf(_noise_hash(x0, y0, z0 + 1, seed), _noise_hash(x0 + 1, y0, z0 + 1, seed), tx)
	var x11: float = lerpf(_noise_hash(x0, y0 + 1, z0 + 1, seed), _noise_hash(x0 + 1, y0 + 1, z0 + 1, seed), tx)
	var y0_value: float = lerpf(x00, x10, ty)
	var y1_value: float = lerpf(x01, x11, ty)
	return lerpf(y0_value, y1_value, tz)


static func _smooth_noise_fraction(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)


static func _noise_hash(x: int, y: int, z: int, seed: int) -> float:
	var value: float = sin(float(x * 127 + y * 311 + z * 74 + seed * 19)) * 43758.5453123
	return (value - floor(value)) * 2.0 - 1.0


static func _build_vertex_normals(source: GMSMeshData) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	result.resize(source.vertices.size())
	for face_index: int in source.faces.size():
		var normal: Vector3 = source.get_face_normal(face_index)
		for vertex_index: int in source.faces[face_index]:
			result[vertex_index] += normal
	for vertex_index: int in result.size():
		if result[vertex_index].is_zero_approx():
			result[vertex_index] = Vector3.UP
		else:
			result[vertex_index] = result[vertex_index].normalized()
	return result


static func _source_face_uv(source: GMSMeshData, face_index: int, reverse_order: bool) -> PackedVector2Array:
	var source_face: PackedInt32Array = source.faces[face_index]
	var values: PackedVector2Array = PackedVector2Array()
	for corner_index: int in source_face.size():
		var source_corner: int = source_face.size() - 1 - corner_index if reverse_order else corner_index
		if source.has_uv_map and face_index < source.uv_faces.size():
			values.append(source.uv_faces[face_index][source_corner])
		else:
			values.append(Vector2.ZERO)
	return values


static func _mirrored_vertex(vertex: Vector3, mask: int) -> Vector3:
	var result: Vector3 = vertex
	if (mask & 1) != 0:
		result.x = -result.x
	if (mask & 2) != 0:
		result.y = -result.y
	if (mask & 4) != 0:
		result.z = -result.z
	return result


static func _is_near_enabled_plane(vertex: Vector3, modifier: GMSModifier, threshold: float) -> bool:
	return (
		(modifier.mirror_x and absf(vertex.x) <= threshold)
		or (modifier.mirror_y and absf(vertex.y) <= threshold)
		or (modifier.mirror_z and absf(vertex.z) <= threshold)
	)


static func _quantized_key(vertex: Vector3, threshold: float) -> Vector3i:
	return Vector3i(
		roundi(vertex.x / threshold),
		roundi(vertex.y / threshold),
		roundi(vertex.z / threshold)
	)


static func _bit_count(value: int) -> int:
	var result: int = 0
	var remaining: int = value
	while remaining != 0:
		result += remaining & 1
		remaining >>= 1
	return result


static func _face_has_three_unique_vertices(face: PackedInt32Array) -> bool:
	var unique: Dictionary = {}
	for vertex_index: int in face:
		unique[vertex_index] = true
	return unique.size() >= 3
