@tool
class_name GMSSceneExporter
extends RefCounted


static func export_document(
	document: GMSDocument,
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if document == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	if job != null:
		job.update_progress(0.01, "Preparing document export")
		if job.is_cancelled():
			return ERR_SKIP
	match path.get_extension().to_lower():
		"tscn":
			return export_scene(document, path, job)
		"gltf", "glb":
			var root: Node3D = _build_document_root(document, false, true, job, 0.04, 0.62)
			if root == null:
				return ERR_SKIP if job != null and job.is_cancelled() else ERR_INVALID_DATA
			return _export_gltf_root(root, path, job, 0.62, 1.0)
		"obj":
			var entries: Array[Dictionary] = _document_obj_entries(document, job, 0.04, 0.42)
			if job != null and job.is_cancelled():
				return ERR_SKIP
			return _export_obj_entries(entries, path, job, 0.42, 1.0)
		_:
			return ERR_INVALID_PARAMETER


static func export_scene(
	document: GMSDocument,
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if document == null or path.is_empty():
		return ERR_INVALID_PARAMETER

	var root: Node3D = _build_document_root(document, true, false, job, 0.04, 0.70)
	if root == null:
		return ERR_SKIP if job != null and job.is_cancelled() else ERR_INVALID_DATA
	if job != null:
		job.update_progress(0.72, "Packing Godot scene")
		if job.is_cancelled():
			root.free()
			return ERR_SKIP
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(root)
	if pack_error != OK:
		root.free()
		return pack_error
	if job != null:
		job.update_progress(0.86, "Writing Godot scene")
		if job.is_cancelled():
			root.free()
			return ERR_SKIP
	var save_error: Error = ResourceSaver.save(packed_scene, path)
	root.free()
	if job != null:
		if job.is_cancelled():
			_remove_export_file(path)
			return ERR_SKIP
		job.update_progress(1.0, "Godot scene export complete")
	return save_error


static func export_object_mesh(
	object: GMSModelObject,
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if object == null or path.is_empty():
		return ERR_INVALID_PARAMETER
	if job != null:
		job.update_progress(0.03, "Evaluating object mesh")
		if job.is_cancelled():
			return ERR_SKIP
	var evaluated_mesh: GMSMeshData = _evaluate_object_mesh(object, job, 0.03, 0.38)
	if job != null and job.is_cancelled():
		return ERR_SKIP
	if evaluated_mesh == null or not evaluated_mesh.is_valid():
		return ERR_INVALID_DATA
	if job != null:
		job.update_progress(0.40, "Building export mesh")
		if job.is_cancelled():
			return ERR_SKIP
	var compatible_rig: GMSRigData = object.get_compatible_rig(evaluated_mesh)
	var mesh: ArrayMesh = evaluated_mesh.to_array_mesh(object.materials, false, compatible_rig)
	mesh.resource_name = object.display_name
	match path.get_extension().to_lower():
		"tres", "res":
			if job != null:
				job.update_progress(0.72, "Writing mesh resource")
			var save_error: Error = ResourceSaver.save(mesh, path)
			if job != null:
				if job.is_cancelled():
					_remove_export_file(path)
					return ERR_SKIP
				job.update_progress(1.0, "Mesh resource export complete")
			return save_error
		"gltf", "glb":
			return _export_model_object_as_gltf(object, evaluated_mesh, path, job)
		"obj":
			return _export_obj_entries([{
				"name": object.display_name,
				"mesh": mesh,
				"transform": Transform3D.IDENTITY,
			}], path, job, 0.40, 1.0)
		_:
			return ERR_INVALID_PARAMETER


static func export_combined_mesh(
	objects: Array[GMSModelObject],
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if objects.is_empty() or path.is_empty():
		return ERR_INVALID_PARAMETER
	var output: ArrayMesh = _create_combined_mesh(objects, job, 0.03, 0.62)
	if job != null and job.is_cancelled():
		return ERR_SKIP
	if output.get_surface_count() <= 0:
		return ERR_INVALID_DATA
	match path.get_extension().to_lower():
		"tres", "res":
			if job != null:
				job.update_progress(0.72, "Writing combined mesh resource")
			var save_error: Error = ResourceSaver.save(output, path)
			if job != null:
				if job.is_cancelled():
					_remove_export_file(path)
					return ERR_SKIP
				job.update_progress(1.0, "Combined mesh export complete")
			return save_error
		"gltf", "glb":
			return _export_array_mesh_as_gltf(output, "Combined Mesh", path, job)
		"obj":
			return _export_obj_entries([{
				"name": "Combined Mesh",
				"mesh": output,
				"transform": Transform3D.IDENTITY,
			}], path, job, 0.62, 1.0)
		_:
			return ERR_INVALID_PARAMETER


static func _build_document_root(
	document: GMSDocument,
	include_collision: bool,
	use_gltf_loop_hints: bool = false,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = _safe_node_name(document.document_name)
	var rig_contexts: Dictionary = {}
	var attached_objects: Array[GMSModelObject] = []
	var object_count: int = maxi(document.objects.size(), 1)
	var processed_objects: int = 0

	# Build standalone and rig-owner objects first so rigid attachments can resolve
	# their target Skeleton3D and bone regardless of document order.
	for object: GMSModelObject in document.objects:
		if job != null:
			if job.is_cancelled():
				root.free()
				return null
			job.update_progress(
				lerpf(progress_start, progress_end, float(processed_objects) / float(object_count)),
				"Building export scene objects"
			)
		if object == null or object.mesh_data == null:
			processed_objects += 1
			continue
		if object.has_bone_attachment():
			attached_objects.append(object)
			continue
		var object_progress_start: float = lerpf(
			progress_start,
			progress_end,
			float(processed_objects) / float(object_count)
		)
		var object_progress_end: float = lerpf(
			progress_start,
			progress_end,
			float(processed_objects + 1) / float(object_count)
		)
		var evaluated_mesh: GMSMeshData = _evaluate_object_mesh(
			object,
			job,
			object_progress_start,
			lerpf(object_progress_start, object_progress_end, 0.78)
		)
		if job != null and job.is_cancelled():
			root.free()
			return null
		if evaluated_mesh == null or not evaluated_mesh.is_valid():
			processed_objects += 1
			continue
		if job != null:
			job.update_progress(object_progress_end, "Adding export scene object")
		var context: Dictionary = _add_model_object_to_root(
			root,
			object,
			evaluated_mesh,
			include_collision,
			use_gltf_loop_hints,
			job
		)
		if job != null and job.is_cancelled():
			root.free()
			return null
		if not context.is_empty():
			rig_contexts[object.object_id] = context
		processed_objects += 1

	for attached_object: GMSModelObject in attached_objects:
		if job != null:
			if job.is_cancelled():
				root.free()
				return null
			job.update_progress(
				lerpf(progress_start, progress_end, float(processed_objects) / float(object_count)),
				"Building attached export objects"
			)
		var attached_progress_start: float = lerpf(
			progress_start,
			progress_end,
			float(processed_objects) / float(object_count)
		)
		var attached_progress_end: float = lerpf(
			progress_start,
			progress_end,
			float(processed_objects + 1) / float(object_count)
		)
		var attached_mesh: GMSMeshData = _evaluate_object_mesh(
			attached_object,
			job,
			attached_progress_start,
			lerpf(attached_progress_start, attached_progress_end, 0.78)
		)
		if job != null and job.is_cancelled():
			root.free()
			return null
		if attached_mesh == null or not attached_mesh.is_valid():
			processed_objects += 1
			continue
		if job != null:
			job.update_progress(attached_progress_end, "Adding attached export object")
		if not _add_attached_object_to_root(
			root,
			document,
			attached_object,
			attached_mesh,
			include_collision,
			rig_contexts,
			job
		):
			if job != null and job.is_cancelled():
				root.free()
				return null
			# Invalid or missing attachment targets degrade safely to a standalone
			# object at the stored rest-world transform.
			var attached_context: Dictionary = _add_model_object_to_root(
				root,
				attached_object,
				attached_mesh,
				include_collision,
				use_gltf_loop_hints,
				job
			)
			if not attached_context.is_empty():
				rig_contexts[attached_object.object_id] = attached_context
		processed_objects += 1
	if job != null:
		job.update_progress(progress_end, "Export scene built")
	return root


static func _add_model_object_to_root(
	root: Node3D,
	object: GMSModelObject,
	evaluated_mesh: GMSMeshData,
	include_collision: bool,
	use_gltf_loop_hints: bool = false,
	job: GMSBackgroundJob = null
) -> Dictionary:
	if job != null and job.is_cancelled():
		return {}
	var compatible_rig: GMSRigData = object.get_compatible_rig(evaluated_mesh)
	if compatible_rig == null:
		var mesh_instance: MeshInstance3D = MeshInstance3D.new()
		mesh_instance.name = _safe_node_name(object.display_name)
		mesh_instance.mesh = evaluated_mesh.to_array_mesh(object.materials, false)
		mesh_instance.transform = object.transform
		mesh_instance.visible = object.visible
		root.add_child(mesh_instance)
		mesh_instance.owner = root
		if include_collision:
			_add_collision_to_parent(root, mesh_instance, object, evaluated_mesh)
		return {"node": mesh_instance, "skeleton": null}

	var object_root: Node3D = Node3D.new()
	object_root.name = _safe_node_name(object.display_name)
	object_root.transform = object.transform
	object_root.visible = object.visible
	root.add_child(object_root)
	object_root.owner = root

	var skeleton: Skeleton3D = compatible_rig.build_skeleton(false)
	object_root.add_child(skeleton)
	skeleton.owner = root
	skeleton.force_update_all_bone_transforms()

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = evaluated_mesh.to_array_mesh(object.materials, false, compatible_rig)
	object_root.add_child(mesh_instance)
	mesh_instance.owner = root
	mesh_instance.skeleton = mesh_instance.get_path_to(skeleton)
	var skin: Skin = skeleton.create_skin_from_rest_transforms()
	if skin != null and skin.get_bind_count() == skeleton.get_bone_count():
		mesh_instance.skin = skin
	else:
		push_error(
			"Gator Model Studio could not create a complete skin for %s (%d binds, %d bones)." % [
				object.display_name,
				0 if skin == null else skin.get_bind_count(),
				skeleton.get_bone_count(),
			]
		)

	var animation_player: AnimationPlayer = _add_animation_player(
		root,
		object_root,
		skeleton,
		compatible_rig,
		object.animation_data,
		use_gltf_loop_hints,
		job
	)

	if include_collision:
		_add_collision_to_parent(root, object_root, object, evaluated_mesh)
	return {
		"node": object_root,
		"skeleton": skeleton,
		"animation_player": animation_player,
	}


static func _add_animation_player(
	owner_root: Node3D,
	object_root: Node3D,
	skeleton: Skeleton3D,
	rig: GMSRigData,
	animation_data: GMSAnimationData,
	use_gltf_loop_hints: bool = false,
	job: GMSBackgroundJob = null
) -> AnimationPlayer:
	if (
		owner_root == null
		or object_root == null
		or skeleton == null
		or rig == null
		or animation_data == null
		or animation_data.clips.is_empty()
	):
		return null
	animation_data.ensure_defaults(rig)
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	object_root.add_child(player)
	player.owner = owner_root

	var library: AnimationLibrary
	if player.has_animation_library(&""):
		library = player.get_animation_library(&"")
	else:
		library = AnimationLibrary.new()
		if player.add_animation_library(&"", library) != OK:
			player.free()
			return null

	var used_names: Dictionary = {}
	for clip: GMSAnimationClip in animation_data.clips:
		if job != null and job.is_cancelled():
			player.free()
			return null
		if clip == null:
			continue
		clip.ensure_defaults(rig)
		var animation: Animation = _build_animation_resource(clip, rig, skeleton, job)
		if animation == null:
			continue
		var requested_name: String = clip.display_name
		if use_gltf_loop_hints:
			requested_name = _gltf_animation_name(clip.display_name, clip.loop)
		var animation_name: String = _safe_animation_name(requested_name, used_names)
		used_names[animation_name] = true
		animation.resource_name = animation_name
		if library.add_animation(StringName(animation_name), animation) != OK:
			push_error("Gator Model Studio could not add exported animation: %s" % animation_name)
	if library.get_animation_list_size() <= 0:
		player.free()
		return null
	return player


static func _build_animation_resource(
	clip: GMSAnimationClip,
	rig: GMSRigData,
	skeleton: Skeleton3D,
	job: GMSBackgroundJob = null
) -> Animation:
	if clip == null or rig == null or skeleton == null:
		return null
	var animation: Animation = Animation.new()
	animation.length = maxf(float(clip.frame_count) / maxf(clip.fps, 1.0), 0.000001)
	animation.step = 1.0 / maxf(clip.fps, 1.0)
	animation.loop_mode = Animation.LOOP_LINEAR if clip.loop else Animation.LOOP_NONE
	for track: GMSBoneAnimationTrack in clip.tracks:
		if job != null and job.is_cancelled():
			return null
		if track == null or track.keys.is_empty():
			continue
		var bone_index: int = rig.resolve_bone(track.bone_id, track.bone_name)
		if bone_index < 0 or bone_index >= skeleton.get_bone_count():
			continue
		var track_path: NodePath = NodePath("%s:%s" % [
			skeleton.name,
			skeleton.get_bone_name(bone_index),
		])
		var position_track: int = animation.add_track(Animation.TYPE_POSITION_3D)
		var rotation_track: int = animation.add_track(Animation.TYPE_ROTATION_3D)
		var scale_track: int = animation.add_track(Animation.TYPE_SCALE_3D)
		for track_index: int in [position_track, rotation_track, scale_track]:
			animation.track_set_path(track_index, track_path)
			animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
			animation.track_set_interpolation_loop_wrap(track_index, clip.loop)
		var local_rest: Transform3D = rig.get_bone_local_rest(bone_index)
		for frame: int in range(0, clip.frame_count + 1):
			if job != null and frame % 128 == 0 and job.is_cancelled():
				return null
			var time: float = float(frame) / maxf(clip.fps, 1.0)
			var local_pose: Transform3D = local_rest * track.sample(float(frame))
			var pose_scale: Vector3 = local_pose.basis.get_scale()
			if absf(pose_scale.x) <= 0.000001:
				pose_scale.x = 1.0
			if absf(pose_scale.y) <= 0.000001:
				pose_scale.y = 1.0
			if absf(pose_scale.z) <= 0.000001:
				pose_scale.z = 1.0
			var rotation_basis: Basis = local_pose.basis.scaled(Vector3(
				1.0 / pose_scale.x,
				1.0 / pose_scale.y,
				1.0 / pose_scale.z
			)).orthonormalized()
			animation.position_track_insert_key(position_track, time, local_pose.origin)
			animation.rotation_track_insert_key(
				rotation_track, time, rotation_basis.get_rotation_quaternion().normalized()
			)
			animation.scale_track_insert_key(scale_track, time, pose_scale)
	return animation


static func _gltf_animation_name(display_name: String, should_loop: bool) -> String:
	# glTF 2.0 has no standard animation-loop metadata. Godot's importer
	# recognizes a trailing "-loop" name hint and restores LOOP_LINEAR. The
	# importer normally removes the hint from the displayed animation name.
	var result: String = display_name.strip_edges()
	if should_loop:
		if not result.to_lower().ends_with("-loop"):
			result += "-loop"
	elif result.to_lower().ends_with("-loop"):
		# Prevent a non-looping clip whose user-facing name already ends in
		# "-loop" from being imported as looping by mistake.
		result += "-oneshot"
	return result


static func _safe_animation_name(display_name: String, used_names: Dictionary) -> String:
	var base: String = display_name.strip_edges().replace("/", "_").replace(":", "_")
	if base.is_empty():
		base = "Animation"
	if not used_names.has(base):
		return base
	var suffix: int = 2
	while used_names.has("%s %d" % [base, suffix]):
		suffix += 1
	return "%s %d" % [base, suffix]


static func _add_attached_object_to_root(
	owner_root: Node3D,
	document: GMSDocument,
	object: GMSModelObject,
	evaluated_mesh: GMSMeshData,
	include_collision: bool,
	rig_contexts: Dictionary,
	job: GMSBackgroundJob = null
) -> bool:
	if job != null and job.is_cancelled():
		return false
	if object == null or not object.has_bone_attachment():
		return false
	var rig_object: GMSModelObject = document.get_object(object.attachment_rig_object_id)
	var context: Dictionary = rig_contexts.get(object.attachment_rig_object_id, {})
	var skeleton: Skeleton3D = context.get("skeleton") as Skeleton3D
	if rig_object == null or rig_object.rig_data == null or skeleton == null:
		return false
	var bone_index: int = rig_object.rig_data.resolve_bone(
		object.attachment_bone_id, object.attachment_bone_name
	)
	if bone_index < 0 or bone_index >= skeleton.get_bone_count():
		return false

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "%s_Attachment" % _safe_node_name(object.display_name)
	attachment.bone_name = skeleton.get_bone_name(bone_index)
	attachment.bone_idx = bone_index
	skeleton.add_child(attachment)
	attachment.owner = owner_root

	var object_root: Node3D = Node3D.new()
	object_root.name = _safe_node_name(object.display_name)
	object_root.transform = object.attachment_offset
	object_root.visible = object.visible
	attachment.add_child(object_root)
	object_root.owner = owner_root

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = evaluated_mesh.to_array_mesh(object.materials, false)
	object_root.add_child(mesh_instance)
	mesh_instance.owner = owner_root

	if include_collision:
		_add_collision_to_parent(owner_root, object_root, object, evaluated_mesh)
	return true


static func _add_collision_to_parent(
	owner_root: Node3D,
	parent: Node3D,
	object: GMSModelObject,
	evaluated_mesh: GMSMeshData
) -> void:
	var collision_body: StaticBody3D = GMSCollisionGenerator.create_static_body(object, evaluated_mesh)
	if collision_body == null:
		return
	parent.add_child(collision_body)
	collision_body.owner = owner_root
	for collision_child: Node in collision_body.get_children():
		collision_child.owner = owner_root


static func _evaluate_object_mesh(
	object: GMSModelObject,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> GMSMeshData:
	if object == null or object.mesh_data == null:
		return null
	var current: GMSMeshData = object.mesh_data
	var modifier_count: int = maxi(object.modifiers.size(), 1)
	if object.modifiers.is_empty():
		if job != null:
			job.update_progress(progress_end, "Object mesh ready for export")
		return current
	for modifier_index: int in object.modifiers.size():
		if job != null and job.is_cancelled():
			return null
		var modifier_start: float = lerpf(
			progress_start,
			progress_end,
			float(modifier_index) / float(modifier_count)
		)
		var modifier_end: float = lerpf(
			progress_start,
			progress_end,
			float(modifier_index + 1) / float(modifier_count)
		)
		current = GMSModifierEvaluator.evaluate_single(
			current,
			object.modifiers[modifier_index],
			job,
			modifier_start,
			modifier_end
		)
		if current == null:
			return null
	if job != null:
		job.update_progress(progress_end, "Object modifiers evaluated for export")
	return current


static func _create_combined_mesh(
	objects: Array[GMSModelObject],
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> ArrayMesh:
	var output: ArrayMesh = ArrayMesh.new()
	output.resource_name = "Combined Mesh"
	var surface_count: int = 0
	var object_count: int = maxi(objects.size(), 1)

	for object_index: int in objects.size():
		if job != null:
			if job.is_cancelled():
				return output
			job.update_progress(
				lerpf(progress_start, progress_end, float(object_index) / float(object_count)),
				"Combining mesh objects"
			)
		var object: GMSModelObject = objects[object_index]
		if object == null or object.mesh_data == null:
			continue
		var object_progress_start: float = lerpf(
			progress_start,
			progress_end,
			float(object_index) / float(object_count)
		)
		var object_progress_end: float = lerpf(
			progress_start,
			progress_end,
			float(object_index + 1) / float(object_count)
		)
		var evaluated_mesh: GMSMeshData = _evaluate_object_mesh(
			object,
			job,
			object_progress_start,
			lerpf(object_progress_start, object_progress_end, 0.72)
		)
		if job != null and job.is_cancelled():
			return output
		if evaluated_mesh == null or not evaluated_mesh.is_valid():
			continue
		var source: ArrayMesh = evaluated_mesh.to_array_mesh(object.materials, false)
		for source_surface: int in source.get_surface_count():
			if job != null and job.is_cancelled():
				return output
			var arrays: Array = source.surface_get_arrays(source_surface)
			_transform_surface_arrays(arrays, object.transform)
			output.add_surface_from_arrays(
				source.surface_get_primitive_type(source_surface),
				arrays
			)
			var material: Material = source.surface_get_material(source_surface)
			if material != null:
				output.surface_set_material(surface_count, material)
			var surface_name: String = source.surface_get_name(source_surface)
			if surface_name.is_empty():
				surface_name = "%s_%d" % [_safe_node_name(object.display_name), source_surface + 1]
			output.surface_set_name(surface_count, surface_name)
			surface_count += 1
	if job != null:
		job.update_progress(progress_end, "Combined mesh built")
	return output


static func _export_model_object_as_gltf(
	object: GMSModelObject,
	evaluated_mesh: GMSMeshData,
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if object == null or evaluated_mesh == null:
		return ERR_INVALID_PARAMETER
	if job != null:
		job.update_progress(0.42, "Building glTF object scene")
		if job.is_cancelled():
			return ERR_SKIP
	var root: Node3D = Node3D.new()
	root.name = _safe_node_name(object.display_name)
	var export_copy: GMSModelObject = object.duplicate_object()
	export_copy.display_name = object.display_name
	export_copy.transform = Transform3D.IDENTITY
	_add_model_object_to_root(root, export_copy, evaluated_mesh, false, true, job)
	if job != null and job.is_cancelled():
		root.free()
		return ERR_SKIP
	return _export_gltf_root(root, path, job, 0.56, 1.0)


static func _export_array_mesh_as_gltf(
	mesh: ArrayMesh,
	mesh_name: String,
	path: String,
	job: GMSBackgroundJob = null
) -> Error:
	if mesh == null or mesh.get_surface_count() <= 0:
		return ERR_INVALID_DATA
	if job != null:
		job.update_progress(0.66, "Building glTF mesh scene")
		if job.is_cancelled():
			return ERR_SKIP
	var root: Node3D = Node3D.new()
	root.name = _safe_node_name(mesh_name)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = _safe_node_name(mesh_name)
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	return _export_gltf_root(root, path, job, 0.72, 1.0)


static func _export_gltf_root(
	root: Node3D,
	path: String,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Error:
	if root == null or path.get_extension().to_lower() not in ["gltf", "glb"]:
		if root != null:
			root.free()
		return ERR_INVALID_PARAMETER
	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.05), "Serializing glTF scene")
		if job.is_cancelled():
			root.free()
			return ERR_SKIP
	var document: GLTFDocument = GLTFDocument.new()
	document.root_node_mode = GLTFDocument.ROOT_NODE_MODE_SINGLE_ROOT
	document.image_format = "PNG"
	var state: GLTFState = GLTFState.new()
	var append_error: Error = document.append_from_scene(root, state)
	if append_error != OK:
		root.free()
		return append_error
	if job != null:
		job.update_progress(lerpf(progress_start, progress_end, 0.58), "Writing glTF files")
		if job.is_cancelled():
			root.free()
			return ERR_SKIP
	var write_error: Error = document.write_to_filesystem(state, path)
	root.free()
	if job != null:
		if job.is_cancelled():
			_remove_gltf_outputs(path)
			return ERR_SKIP
		job.update_progress(progress_end, "glTF export complete")
	return write_error


static func _document_obj_entries(
	document: GMSDocument,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if document == null:
		return entries
	var object_count: int = maxi(document.objects.size(), 1)
	for object_index: int in document.objects.size():
		if job != null:
			if job.is_cancelled():
				return entries
			job.update_progress(
				lerpf(progress_start, progress_end, float(object_index) / float(object_count)),
				"Preparing OBJ mesh objects"
			)
		var object: GMSModelObject = document.objects[object_index]
		if object == null or object.mesh_data == null:
			continue
		var object_progress_start: float = lerpf(
			progress_start,
			progress_end,
			float(object_index) / float(object_count)
		)
		var object_progress_end: float = lerpf(
			progress_start,
			progress_end,
			float(object_index + 1) / float(object_count)
		)
		var evaluated_mesh: GMSMeshData = _evaluate_object_mesh(
			object,
			job,
			object_progress_start,
			lerpf(object_progress_start, object_progress_end, 0.82)
		)
		if job != null and job.is_cancelled():
			return entries
		if evaluated_mesh == null or not evaluated_mesh.is_valid():
			continue
		entries.append({
			"name": object.display_name,
			"mesh": evaluated_mesh.to_array_mesh(object.materials, false),
			"transform": object.transform,
		})
	if job != null:
		job.update_progress(progress_end, "OBJ meshes prepared")
	return entries


static func _export_obj_entries(
	entries: Array[Dictionary],
	path: String,
	job: GMSBackgroundJob = null,
	progress_start: float = 0.0,
	progress_end: float = 1.0
) -> Error:
	if entries.is_empty() or path.get_extension().to_lower() != "obj":
		return ERR_INVALID_PARAMETER
	if job != null:
		job.update_progress(progress_start, "Opening OBJ output files")
		if job.is_cancelled():
			return ERR_SKIP
	var obj_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if obj_file == null:
		return FileAccess.get_open_error()
	var mtl_path: String = path.get_basename() + ".mtl"
	var mtl_file: FileAccess = FileAccess.open(mtl_path, FileAccess.WRITE)
	if mtl_file == null:
		obj_file.close()
		_remove_export_file(path)
		return FileAccess.get_open_error()
	var created_texture_paths: PackedStringArray = PackedStringArray()

	obj_file.store_line("# Gator Model Studio Wavefront OBJ export")
	obj_file.store_line("mtllib %s" % mtl_path.get_file())
	mtl_file.store_line("# Gator Model Studio material library")

	var vertex_offset: int = 1
	var uv_offset: int = 1
	var normal_offset: int = 1
	var used_material_names: Dictionary = {}
	var wrote_surface: bool = false
	var total_surfaces: int = 0
	for entry: Dictionary in entries:
		var counted_mesh: ArrayMesh = entry.get("mesh") as ArrayMesh
		if counted_mesh != null:
			total_surfaces += counted_mesh.get_surface_count()
	total_surfaces = maxi(total_surfaces, 1)
	var completed_surfaces: int = 0

	for entry_index: int in entries.size():
		if job != null and job.is_cancelled():
			obj_file.close()
			mtl_file.close()
			_remove_obj_outputs(path, mtl_path, created_texture_paths)
			return ERR_SKIP
		var entry: Dictionary = entries[entry_index]
		var mesh: ArrayMesh = entry.get("mesh") as ArrayMesh
		if mesh == null or mesh.get_surface_count() <= 0:
			continue
		var object_name: String = _safe_obj_name(str(entry.get("name", "Object %d" % (entry_index + 1))))
		var object_transform: Transform3D = Transform3D.IDENTITY
		var transform_value: Variant = entry.get("transform", Transform3D.IDENTITY)
		if transform_value is Transform3D:
			object_transform = transform_value
		obj_file.store_line("")
		obj_file.store_line("o %s" % object_name)

		for surface_index: int in mesh.get_surface_count():
			if job != null:
				if job.is_cancelled():
					obj_file.close()
					mtl_file.close()
					_remove_obj_outputs(path, mtl_path, created_texture_paths)
					return ERR_SKIP
				job.update_progress(
					lerpf(progress_start, progress_end, float(completed_surfaces) / float(total_surfaces)),
					"Writing OBJ surface %d of %d" % [completed_surfaces + 1, total_surfaces]
				)
			if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				completed_surfaces += 1
				continue
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			if arrays.size() <= Mesh.ARRAY_VERTEX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
				completed_surfaces += 1
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if vertices.size() < 3:
				completed_surfaces += 1
				continue
			var uvs: PackedVector2Array = PackedVector2Array()
			if arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				uvs = arrays[Mesh.ARRAY_TEX_UV]
			var normals: PackedVector3Array = PackedVector3Array()
			if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				normals = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = PackedInt32Array()
			if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = arrays[Mesh.ARRAY_INDEX]

			var has_uvs: bool = uvs.size() == vertices.size()
			var has_normals: bool = normals.size() == vertices.size()
			var normal_basis: Basis = object_transform.basis.inverse().transposed()
			for vertex_index: int in vertices.size():
				if job != null and vertex_index % 4096 == 0 and job.is_cancelled():
					obj_file.close()
					mtl_file.close()
					_remove_obj_outputs(path, mtl_path, created_texture_paths)
					return ERR_SKIP
				var transformed: Vector3 = object_transform * vertices[vertex_index]
				obj_file.store_line("v %s %s %s" % [
					_float_text(transformed.x),
					_float_text(transformed.y),
					_float_text(transformed.z),
				])
			if has_uvs:
				for uv_index: int in uvs.size():
					if job != null and uv_index % 4096 == 0 and job.is_cancelled():
						obj_file.close()
						mtl_file.close()
						_remove_obj_outputs(path, mtl_path, created_texture_paths)
						return ERR_SKIP
					var uv: Vector2 = uvs[uv_index]
					obj_file.store_line("vt %s %s" % [
						_float_text(uv.x),
						_float_text(1.0 - uv.y),
					])
			if has_normals:
				for normal_index: int in normals.size():
					if job != null and normal_index % 4096 == 0 and job.is_cancelled():
						obj_file.close()
						mtl_file.close()
						_remove_obj_outputs(path, mtl_path, created_texture_paths)
						return ERR_SKIP
					var transformed_normal: Vector3 = (normal_basis * normals[normal_index]).normalized()
					obj_file.store_line("vn %s %s %s" % [
						_float_text(transformed_normal.x),
						_float_text(transformed_normal.y),
						_float_text(transformed_normal.z),
					])

			var surface_name: String = mesh.surface_get_name(surface_index)
			if surface_name.is_empty():
				surface_name = "Surface %d" % (surface_index + 1)
			obj_file.store_line("g %s_%s" % [object_name, _safe_obj_name(surface_name)])
			var material: Material = mesh.surface_get_material(surface_index)
			var material_name: String = _unique_obj_material_name(
				"%s_%s" % [object_name, _material_display_name(material, surface_index)],
				used_material_names
			)
			obj_file.store_line("usemtl %s" % material_name)
			var created_texture: String = _write_mtl_material(
				mtl_file,
				material_name,
				material,
				path.get_base_dir()
			)
			if not created_texture.is_empty():
				created_texture_paths.append(created_texture)

			var triangle_indices: PackedInt32Array = indices
			if triangle_indices.is_empty():
				triangle_indices.resize(vertices.size())
				for index: int in vertices.size():
					triangle_indices[index] = index
			var reverse_winding: bool = object_transform.basis.determinant() >= 0.0
			var triangle_position: int = 0
			for triangle_start: int in range(0, triangle_indices.size() - 2, 3):
				if job != null and triangle_position % 2048 == 0 and job.is_cancelled():
					obj_file.close()
					mtl_file.close()
					_remove_obj_outputs(path, mtl_path, created_texture_paths)
					return ERR_SKIP
				var a: int = triangle_indices[triangle_start]
				var b: int = triangle_indices[triangle_start + 1]
				var c: int = triangle_indices[triangle_start + 2]
				if reverse_winding:
					var swap: int = b
					b = c
					c = swap
				if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
					triangle_position += 1
					continue
				obj_file.store_line("f %s %s %s" % [
					_obj_corner(a, vertex_offset, uv_offset, normal_offset, has_uvs, has_normals),
					_obj_corner(b, vertex_offset, uv_offset, normal_offset, has_uvs, has_normals),
					_obj_corner(c, vertex_offset, uv_offset, normal_offset, has_uvs, has_normals),
				])
				triangle_position += 1
			wrote_surface = true
			vertex_offset += vertices.size()
			if has_uvs:
				uv_offset += uvs.size()
			if has_normals:
				normal_offset += normals.size()
			completed_surfaces += 1

	obj_file.close()
	mtl_file.close()
	if job != null and job.is_cancelled():
		_remove_obj_outputs(path, mtl_path, created_texture_paths)
		return ERR_SKIP
	if not wrote_surface:
		_remove_obj_outputs(path, mtl_path, created_texture_paths)
		return ERR_INVALID_DATA
	if job != null:
		job.update_progress(progress_end, "OBJ export complete")
	return OK


static func _obj_corner(
	index: int,
	vertex_offset: int,
	uv_offset: int,
	normal_offset: int,
	has_uvs: bool,
	has_normals: bool
) -> String:
	var vertex_index: int = vertex_offset + index
	if has_uvs and has_normals:
		return "%d/%d/%d" % [vertex_index, uv_offset + index, normal_offset + index]
	if has_uvs:
		return "%d/%d" % [vertex_index, uv_offset + index]
	if has_normals:
		return "%d//%d" % [vertex_index, normal_offset + index]
	return str(vertex_index)


static func _write_mtl_material(
	file: FileAccess,
	material_name: String,
	material: Material,
	obj_directory: String
) -> String:
	var albedo: Color = Color.WHITE
	var metallic: float = 0.0
	var roughness: float = 1.0
	var albedo_texture: Texture2D
	if material is StandardMaterial3D:
		var standard: StandardMaterial3D = material as StandardMaterial3D
		albedo = standard.albedo_color
		metallic = standard.metallic
		roughness = standard.roughness
		albedo_texture = standard.albedo_texture
	var specular: Color = Color(0.04, 0.04, 0.04).lerp(Color(albedo.r, albedo.g, albedo.b), metallic)
	var shininess: float = pow(1.0 - clampf(roughness, 0.0, 1.0), 4.0) * 1000.0
	file.store_line("")
	file.store_line("newmtl %s" % material_name)
	file.store_line("Ka 0 0 0")
	file.store_line("Kd %s %s %s" % [_float_text(albedo.r), _float_text(albedo.g), _float_text(albedo.b)])
	file.store_line("Ks %s %s %s" % [_float_text(specular.r), _float_text(specular.g), _float_text(specular.b)])
	file.store_line("Ns %s" % _float_text(shininess))
	file.store_line("d %s" % _float_text(albedo.a))
	file.store_line("illum 2")
	file.store_line("Pm %s" % _float_text(metallic))
	file.store_line("Pr %s" % _float_text(roughness))
	if albedo_texture != null:
		var image: Image = albedo_texture.get_image()
		if image != null and not image.is_empty():
			var texture_file_name: String = "%s_albedo.png" % _safe_obj_name(material_name)
			var texture_output_path: String = obj_directory.path_join(texture_file_name)
			var save_error: Error = image.save_png(texture_output_path)
			if save_error == OK:
				file.store_line("map_Kd %s" % texture_file_name)
				return texture_output_path
	return ""


static func _material_display_name(material: Material, surface_index: int) -> String:
	if material != null and not material.resource_name.is_empty():
		return material.resource_name
	return "Material %d" % (surface_index + 1)


static func _unique_obj_material_name(source: String, used_names: Dictionary) -> String:
	var base_name: String = _safe_obj_name(source)
	var candidate: String = base_name
	var suffix: int = 2
	while used_names.has(candidate):
		candidate = "%s_%d" % [base_name, suffix]
		suffix += 1
	used_names[candidate] = true
	return candidate


static func _safe_obj_name(source: String) -> String:
	var cleaned: String = source.strip_edges()
	if cleaned.is_empty():
		return "Model"
	for character: String in [" ", "\t", "#", "/", "\\", ":", ";", "\"", "'"]:
		cleaned = cleaned.replace(character, "_")
	return cleaned


static func _float_text(value: float) -> String:
	if is_zero_approx(value):
		return "0"
	var text: String = "%.9f" % value
	while text.contains(".") and text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _transform_surface_arrays(arrays: Array, transform: Transform3D) -> void:
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return
	if arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for vertex_index: int in vertices.size():
			vertices[vertex_index] = transform * vertices[vertex_index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
	if arrays.size() > Mesh.ARRAY_NORMAL and arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
		var normal_basis: Basis = transform.basis.inverse().transposed()
		for normal_index: int in normals.size():
			normals[normal_index] = (normal_basis * normals[normal_index]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays.size() > Mesh.ARRAY_TANGENT and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT].duplicate()
		var tangent_basis: Basis = transform.basis.orthonormalized()
		for tangent_index: int in range(0, tangents.size() - 3, 4):
			var tangent: Vector3 = Vector3(
				tangents[tangent_index],
				tangents[tangent_index + 1],
				tangents[tangent_index + 2]
			)
			tangent = (tangent_basis * tangent).normalized()
			tangents[tangent_index] = tangent.x
			tangents[tangent_index + 1] = tangent.y
			tangents[tangent_index + 2] = tangent.z
		arrays[Mesh.ARRAY_TANGENT] = tangents


static func _remove_obj_outputs(
	obj_path: String,
	mtl_path: String,
	texture_paths: PackedStringArray
) -> void:
	_remove_export_file(obj_path)
	_remove_export_file(mtl_path)
	for texture_path: String in texture_paths:
		_remove_export_file(texture_path)


static func _remove_gltf_outputs(path: String) -> void:
	_remove_export_file(path)
	if path.get_extension().to_lower() == "gltf":
		_remove_export_file(path.get_basename() + ".bin")


static func _remove_export_file(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


static func _safe_node_name(source: String) -> String:
	var cleaned: String = source.strip_edges()
	if cleaned.is_empty():
		return "Model"
	return cleaned.replace(".", "_").replace("/", "_").replace("\\", "_")
