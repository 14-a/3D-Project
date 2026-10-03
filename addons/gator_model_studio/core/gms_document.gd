@tool
class_name GMSDocument
extends Resource

signal object_added(object: GMSModelObject, index: int)
signal object_removed(object_id: String)
signal object_changed(object_id: String)
signal object_updated(object_id: String, change_flags: int)
signal structure_changed

enum ChangeFlags {
	GEOMETRY = 1,
	TRANSFORM = 2,
	MATERIAL = 4,
	MODIFIERS = 8,
	METADATA = 16,
	COLLISION = 32,
	POSITIONS = 64,
	RIG = 128,
	ATTACHMENT = 256,
	ANIMATION = 512,
}

@export var format_version: int = 12
@export var document_name: String = "Untitled Model"
@export var objects: Array[GMSModelObject] = []
@export var last_export_path: String = ""
@export var auto_export_on_save: bool = false


func add_object(object: GMSModelObject, index: int = -1) -> void:
	if object == null:
		return
	object.ensure_defaults()
	if get_object(object.object_id) != null:
		return

	var actual_index: int = objects.size()
	if index >= 0 and index <= objects.size():
		actual_index = index
		objects.insert(index, object)
	else:
		objects.append(object)

	object_added.emit(object, actual_index)
	structure_changed.emit()
	emit_changed()


func add_objects(
	new_objects: Array[GMSModelObject],
	indices: PackedInt32Array = PackedInt32Array()
) -> void:
	for object_index: int in new_objects.size():
		var insert_index: int = -1
		if object_index < indices.size():
			insert_index = indices[object_index]
		add_object(new_objects[object_index], insert_index)


func remove_objects(object_ids: PackedStringArray) -> void:
	for object_id: String in object_ids:
		remove_object(object_id)


func remove_object(object_id: String) -> void:
	var index: int = get_object_index(object_id)
	if index < 0:
		return
	objects.remove_at(index)
	object_removed.emit(object_id)
	structure_changed.emit()
	emit_changed()


func get_object(object_id: String) -> GMSModelObject:
	for object: GMSModelObject in objects:
		if object != null and object.object_id == object_id:
			return object
	return null


func get_object_index(object_id: String) -> int:
	for index: int in objects.size():
		var object: GMSModelObject = objects[index]
		if object != null and object.object_id == object_id:
			return index
	return -1


func set_object_transform(object_id: String, new_transform: Transform3D) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	if object.has_bone_attachment():
		var bone_world_result: Dictionary = _get_attachment_bone_rest_world(object)
		if bool(bone_world_result.get("valid", false)):
			var bone_world: Transform3D = bone_world_result.get("transform", Transform3D.IDENTITY)
			object.attachment_offset = bone_world.affine_inverse() * new_transform
	object.transform = new_transform
	_notify_object_changed(
		object_id,
		ChangeFlags.TRANSFORM | (ChangeFlags.ATTACHMENT if object.has_bone_attachment() else 0)
	)
	_update_attachment_rest_transforms_for_rig(object_id)


func set_object_name(object_id: String, new_name: String) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	var cleaned_name: String = new_name.strip_edges()
	if cleaned_name.is_empty():
		cleaned_name = "Object"
	object.display_name = cleaned_name
	_notify_object_changed(object_id, ChangeFlags.METADATA)


func set_object_visible(object_id: String, is_visible: bool) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	object.visible = is_visible
	_notify_object_changed(object_id, ChangeFlags.METADATA)


func set_object_locked(object_id: String, is_locked: bool) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	object.locked = is_locked
	_notify_object_changed(object_id, ChangeFlags.METADATA)


func set_object_mesh(object_id: String, new_mesh: GMSMeshData) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	new_mesh.prepare_for_use()
	object.mesh_data = new_mesh
	object.invalidate_geometry_cache()
	_notify_object_changed(object_id, ChangeFlags.GEOMETRY)


func set_object_vertex_positions(
	object_id: String,
	vertex_indices: PackedInt32Array,
	positions: PackedVector3Array,
	preserved_array_mesh: ArrayMesh = null
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked or object.mesh_data == null:
		return
	var dynamic_array_mesh: ArrayMesh = preserved_array_mesh
	if dynamic_array_mesh == null and object.supports_dynamic_vertex_preview():
		dynamic_array_mesh = object.get_evaluated_array_mesh()
	var previous_revision: int = object.mesh_data.get_position_revision()
	object.mesh_data.set_vertex_positions(vertex_indices, positions)
	if object.mesh_data.get_position_revision() == previous_revision:
		return
	if (
		dynamic_array_mesh != null
		and object.supports_dynamic_vertex_preview()
		and object.mesh_data.update_array_mesh_vertex_positions(
			dynamic_array_mesh, vertex_indices
		)
	):
		object.adopt_position_edit_array_mesh(dynamic_array_mesh)
	else:
		object.invalidate_geometry_cache()
	_notify_object_changed(object_id, ChangeFlags.POSITIONS)


func set_object_rig(object_id: String, new_rig: GMSRigData) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	object.set_rig_data(new_rig)
	_notify_object_changed(object_id, ChangeFlags.RIG)
	_update_attachment_rest_transforms_for_rig(object_id)



func set_object_animation_data(object_id: String, new_data: GMSAnimationData) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	object.set_animation_data(new_data)
	_notify_object_changed(object_id, ChangeFlags.ANIMATION)


func _get_attachment_bone_rest_world(object: GMSModelObject) -> Dictionary:
	if object == null or not object.has_bone_attachment():
		return {"valid": false, "transform": Transform3D.IDENTITY, "bone_index": -1}
	var rig_object: GMSModelObject = get_object(object.attachment_rig_object_id)
	if rig_object == null or rig_object.rig_data == null:
		return {"valid": false, "transform": Transform3D.IDENTITY, "bone_index": -1}
	var bone_index: int = rig_object.rig_data.resolve_bone(
		object.attachment_bone_id, object.attachment_bone_name
	)
	if bone_index < 0:
		return {"valid": false, "transform": Transform3D.IDENTITY, "bone_index": -1}
	return {
		"valid": true,
		"transform": rig_object.transform * rig_object.rig_data.get_bone_global_rest(bone_index),
		"bone_index": bone_index,
	}


func _update_attachment_rest_transforms_for_rig(rig_object_id: String) -> void:
	var rig_object: GMSModelObject = get_object(rig_object_id)
	if rig_object == null or rig_object.rig_data == null:
		return
	for object: GMSModelObject in objects:
		if object == null or object.attachment_rig_object_id != rig_object_id:
			continue
		var bone_index: int = rig_object.rig_data.resolve_bone(
			object.attachment_bone_id, object.attachment_bone_name
		)
		if bone_index < 0:
			continue
		var bone: GMSBoneData = rig_object.rig_data.bones[bone_index]
		object.attachment_bone_id = bone.bone_id
		object.attachment_bone_name = bone.display_name
		object.transform = (
			rig_object.transform
			* rig_object.rig_data.get_bone_global_rest(bone_index)
			* object.attachment_offset
		)
		object_updated.emit(object.object_id, ChangeFlags.TRANSFORM | ChangeFlags.ATTACHMENT)
		object_changed.emit(object.object_id)


func set_object_attachment_state(
	object_id: String,
	rig_object_id: String,
	bone_id: String,
	bone_name: String,
	offset: Transform3D,
	world_transform: Transform3D
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	object.transform = world_transform
	if rig_object_id.is_empty() or (bone_id.is_empty() and bone_name.is_empty()):
		object.clear_attachment()
	else:
		object.set_attachment(rig_object_id, bone_id, bone_name, offset)
	_notify_object_changed(object_id, ChangeFlags.TRANSFORM | ChangeFlags.ATTACHMENT)


func get_object_rest_world_transform(object_id: String) -> Transform3D:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return Transform3D.IDENTITY
	var bone_world_result: Dictionary = _get_attachment_bone_rest_world(object)
	if not bool(bone_world_result.get("valid", false)):
		return object.transform
	var bone_world: Transform3D = bone_world_result.get("transform", Transform3D.IDENTITY)
	return bone_world * object.attachment_offset


func set_object_material(object_id: String, new_material: StandardMaterial3D) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or new_material == null:
		return
	var slots: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	if slots.is_empty():
		slots.append(new_material)
	else:
		slots[0] = new_material.duplicate(true) as StandardMaterial3D
	object.set_material_slots(slots, object.active_material_index)
	_notify_object_changed(object_id, ChangeFlags.MATERIAL)


func set_object_material_state(
	object_id: String,
	new_materials: Array[StandardMaterial3D],
	new_active_index: int,
	new_mesh: GMSMeshData = null
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	object.set_material_slots(new_materials, new_active_index)
	if new_mesh != null:
		new_mesh.prepare_for_use()
		object.mesh_data = new_mesh
		object.invalidate_geometry_cache()
	_notify_object_changed(object_id, ChangeFlags.MATERIAL | (ChangeFlags.GEOMETRY if new_mesh != null else 0))


func set_object_active_material_index(object_id: String, material_index: int) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	object.set_active_material_index(material_index)
	_notify_object_changed(object_id, ChangeFlags.METADATA)


func set_object_collision(
	object_id: String,
	new_collision_type: int,
	new_collision_layer: int,
	new_collision_mask: int
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null:
		return
	object.collision_type = clampi(
		new_collision_type,
		GMSModelObject.CollisionType.NONE,
		GMSModelObject.CollisionType.CAPSULE
	)
	object.collision_layer = clampi(new_collision_layer, 1, 32)
	object.collision_mask = clampi(new_collision_mask, 1, 32)
	_notify_object_changed(object_id, ChangeFlags.COLLISION)


func set_object_modifiers(object_id: String, new_modifiers: Array[GMSModifier]) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked:
		return
	object.modifiers = GMSModelObject.duplicate_modifiers(new_modifiers)
	object.invalidate_modifier_cache()
	_notify_object_changed(object_id, ChangeFlags.MODIFIERS)


func set_object_mesh_and_modifiers(
	object_id: String,
	new_mesh: GMSMeshData,
	new_modifiers: Array[GMSModifier],
	preserved_array_mesh: ArrayMesh = null
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked or new_mesh == null:
		return
	new_mesh.prepare_for_use()
	object.adopt_mesh_and_modifiers(new_mesh, new_modifiers, preserved_array_mesh)
	_notify_object_changed(object_id, ChangeFlags.GEOMETRY | ChangeFlags.MODIFIERS)


func _notify_object_changed(object_id: String, change_flags: int) -> void:
	object_updated.emit(object_id, change_flags)
	object_changed.emit(object_id)
	emit_changed()


func set_object_transforms(
	object_ids: PackedStringArray,
	transforms: Array[Transform3D]
) -> void:
	for index: int in mini(object_ids.size(), transforms.size()):
		var object: GMSModelObject = get_object(object_ids[index])
		if object == null or object.locked:
			continue
		var new_transform: Transform3D = transforms[index]
		if object.has_bone_attachment():
			var bone_world_result: Dictionary = _get_attachment_bone_rest_world(object)
			if bool(bone_world_result.get("valid", false)):
				var bone_world: Transform3D = bone_world_result.get("transform", Transform3D.IDENTITY)
				object.attachment_offset = bone_world.affine_inverse() * new_transform
		object.transform = new_transform
		var flags: int = ChangeFlags.TRANSFORM | (ChangeFlags.ATTACHMENT if object.has_bone_attachment() else 0)
		object_updated.emit(object.object_id, flags)
		object_changed.emit(object.object_id)
		_update_attachment_rest_transforms_for_rig(object.object_id)
	emit_changed()


func set_object_mesh_and_transform(
	object_id: String,
	new_mesh: GMSMeshData,
	new_transform: Transform3D
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked or new_mesh == null:
		return
	new_mesh.prepare_for_use()
	object.mesh_data = new_mesh
	object.transform = new_transform
	object.invalidate_geometry_cache()
	_notify_object_changed(object_id, ChangeFlags.GEOMETRY | ChangeFlags.TRANSFORM)
	_update_attachment_rest_transforms_for_rig(object_id)


func set_object_mesh_transform_and_rig(
	object_id: String,
	new_mesh: GMSMeshData,
	new_transform: Transform3D,
	new_rig: GMSRigData
) -> void:
	var object: GMSModelObject = get_object(object_id)
	if object == null or object.locked or new_mesh == null:
		return
	new_mesh.prepare_for_use()
	object.mesh_data = new_mesh
	object.transform = new_transform
	object.set_rig_data(new_rig)
	object.invalidate_geometry_cache()
	_notify_object_changed(
		object_id,
		ChangeFlags.GEOMETRY | ChangeFlags.TRANSFORM | ChangeFlags.RIG
	)
	_update_attachment_rest_transforms_for_rig(object_id)


func apply_separate(
	source_object_id: String,
	source_mesh: GMSMeshData,
	new_object: GMSModelObject
) -> void:
	set_object_mesh(source_object_id, source_mesh)
	add_object(new_object)


func restore_separate(
	source_object_id: String,
	original_mesh: GMSMeshData,
	new_object_id: String
) -> void:
	remove_object(new_object_id)
	set_object_mesh(source_object_id, original_mesh)


func apply_join(
	active_object_id: String,
	joined_mesh: GMSMeshData,
	joined_materials: Array[StandardMaterial3D],
	joined_active_material_index: int,
	joined_modifiers: Array[GMSModifier],
	removed_object_ids: PackedStringArray
) -> void:
	set_object_mesh_and_modifiers(active_object_id, joined_mesh, joined_modifiers)
	set_object_material_state(active_object_id, joined_materials, joined_active_material_index)
	remove_objects(removed_object_ids)


func restore_join(
	active_object_id: String,
	original_mesh: GMSMeshData,
	original_materials: Array[StandardMaterial3D],
	original_active_material_index: int,
	original_modifiers: Array[GMSModifier],
	removed_objects: Array[GMSModelObject],
	removed_indices: PackedInt32Array
) -> void:
	set_object_mesh_and_modifiers(active_object_id, original_mesh, original_modifiers)
	set_object_material_state(active_object_id, original_materials, original_active_material_index)
	add_objects(removed_objects, removed_indices)
