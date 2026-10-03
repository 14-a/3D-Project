@tool
class_name GMSHistory
extends RefCounted

signal changed

var _undo_redo: UndoRedo = UndoRedo.new()


func add_object(document: GMSDocument, object: GMSModelObject, index: int = -1) -> void:
	_undo_redo.create_action("Add %s" % object.display_name)
	_undo_redo.add_do_method(document.add_object.bind(object, index))
	_undo_redo.add_undo_method(document.remove_object.bind(object.object_id))
	_undo_redo.commit_action()
	changed.emit()


func add_objects(
	document: GMSDocument,
	objects: Array[GMSModelObject],
	action_name: String = "Add Objects"
) -> void:
	if objects.is_empty():
		return
	var object_ids: PackedStringArray = PackedStringArray()
	for object: GMSModelObject in objects:
		if object != null:
			object_ids.append(object.object_id)
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(document.add_objects.bind(objects))
	_undo_redo.add_undo_method(document.remove_objects.bind(object_ids))
	_undo_redo.commit_action()
	changed.emit()


func remove_objects(document: GMSDocument, object_ids: PackedStringArray) -> void:
	var objects: Array[GMSModelObject] = []
	var indices: PackedInt32Array = PackedInt32Array()
	var valid_ids: PackedStringArray = PackedStringArray()
	for object_id: String in object_ids:
		var object: GMSModelObject = document.get_object(object_id)
		var index: int = document.get_object_index(object_id)
		if object == null or index < 0:
			continue
		objects.append(object)
		indices.append(index)
		valid_ids.append(object_id)
	if objects.is_empty():
		return


	for first: int in objects.size():
		for second: int in range(first + 1, objects.size()):
			if indices[second] < indices[first]:
				var swap_index: int = indices[first]
				indices[first] = indices[second]
				indices[second] = swap_index
				var swap_object: GMSModelObject = objects[first]
				objects[first] = objects[second]
				objects[second] = swap_object
				var swap_id: String = valid_ids[first]
				valid_ids[first] = valid_ids[second]
				valid_ids[second] = swap_id

	_undo_redo.create_action("Delete Objects" if objects.size() > 1 else "Delete %s" % objects[0].display_name)
	_undo_redo.add_do_method(document.remove_objects.bind(valid_ids))
	_undo_redo.add_undo_method(document.add_objects.bind(objects, indices))
	_undo_redo.commit_action()
	changed.emit()


func remove_object(document: GMSDocument, object_id: String) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	var index: int = document.get_object_index(object_id)
	if object == null or index < 0:
		return

	_undo_redo.create_action("Delete %s" % object.display_name)
	_undo_redo.add_do_method(document.remove_object.bind(object_id))
	_undo_redo.add_undo_method(document.add_object.bind(object, index))
	_undo_redo.commit_action()
	changed.emit()


func set_transform(
	document: GMSDocument,
	object_id: String,
	new_transform: Transform3D
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.transform.is_equal_approx(new_transform):
		return
	var old_transform: Transform3D = object.transform

	_undo_redo.create_action("Transform %s" % object.display_name)
	_undo_redo.add_do_method(document.set_object_transform.bind(object_id, new_transform))
	_undo_redo.add_undo_method(document.set_object_transform.bind(object_id, old_transform))
	_undo_redo.commit_action()
	changed.emit()


func set_name(document: GMSDocument, object_id: String, new_name: String) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.display_name == new_name:
		return
	var old_name: String = object.display_name

	_undo_redo.create_action("Rename Object")
	_undo_redo.add_do_method(document.set_object_name.bind(object_id, new_name))
	_undo_redo.add_undo_method(document.set_object_name.bind(object_id, old_name))
	_undo_redo.commit_action()
	changed.emit()


func set_visibility(document: GMSDocument, object_id: String, is_visible: bool) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.visible == is_visible:
		return

	_undo_redo.create_action("Change Visibility")
	_undo_redo.add_do_method(document.set_object_visible.bind(object_id, is_visible))
	_undo_redo.add_undo_method(document.set_object_visible.bind(object_id, object.visible))
	_undo_redo.commit_action()
	changed.emit()


func set_locked(document: GMSDocument, object_id: String, is_locked: bool) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or object.locked == is_locked:
		return

	_undo_redo.create_action("Change Lock")
	_undo_redo.add_do_method(document.set_object_locked.bind(object_id, is_locked))
	_undo_redo.add_undo_method(document.set_object_locked.bind(object_id, object.locked))
	_undo_redo.commit_action()
	changed.emit()


func set_mesh(
	document: GMSDocument,
	object_id: String,
	new_mesh: GMSMeshData,
	action_name: String = "Edit Mesh"
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_mesh == null:
		return
	var old_mesh: GMSMeshData = object.mesh_data

	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(document.set_object_mesh.bind(object_id, new_mesh))
	_undo_redo.add_undo_method(document.set_object_mesh.bind(object_id, old_mesh))
	_undo_redo.commit_action()
	changed.emit()


func set_vertex_positions(
	document: GMSDocument,
	object_id: String,
	vertex_indices: PackedInt32Array,
	old_positions: PackedVector3Array,
	new_positions: PackedVector3Array,
	action_name: String = "Transform Mesh Selection",
	preserved_array_mesh: ArrayMesh = null
) -> void:
	if vertex_indices.is_empty() or old_positions.size() != new_positions.size():
		return
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(
		document.set_object_vertex_positions.bind(
			object_id, vertex_indices, new_positions, preserved_array_mesh
		)
	)
	_undo_redo.add_undo_method(
		document.set_object_vertex_positions.bind(
			object_id, vertex_indices, old_positions, preserved_array_mesh
		)
	)
	_undo_redo.commit_action()
	changed.emit()


func set_rig(
	document: GMSDocument,
	object_id: String,
	new_rig: GMSRigData,
	action_name: String = "Edit Rig",
	merge_ends: bool = false
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null:
		return
	var old_rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else null
	var do_rig: GMSRigData = new_rig.duplicate_rig() if new_rig != null else null
	_undo_redo.create_action(action_name, UndoRedo.MERGE_ENDS if merge_ends else UndoRedo.MERGE_DISABLE)
	_undo_redo.add_do_method(document.set_object_rig.bind(object_id, do_rig))
	_undo_redo.add_undo_method(document.set_object_rig.bind(object_id, old_rig))
	_undo_redo.commit_action()
	changed.emit()



func set_rig_states(
	document: GMSDocument,
	object_id: String,
	old_rig: GMSRigData,
	new_rig: GMSRigData,
	action_name: String = "Edit Rig",
	merge_ends: bool = false
) -> void:
	if document == null or document.get_object(object_id) == null:
		return
	var undo_rig: GMSRigData = old_rig.duplicate_rig() if old_rig != null else null
	var do_rig: GMSRigData = new_rig.duplicate_rig() if new_rig != null else null
	_undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS if merge_ends else UndoRedo.MERGE_DISABLE
	)
	_undo_redo.add_do_method(document.set_object_rig.bind(object_id, do_rig))
	_undo_redo.add_undo_method(document.set_object_rig.bind(object_id, undo_rig))
	_undo_redo.commit_action()
	changed.emit()


func set_animation_data(
	document: GMSDocument,
	object_id: String,
	new_data: GMSAnimationData,
	action_name: String = "Edit Animation",
	merge_ends: bool = false
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null:
		return
	var old_data: GMSAnimationData = (
		object.animation_data.duplicate_data() if object.animation_data != null else null
	)
	var do_data: GMSAnimationData = new_data.duplicate_data() if new_data != null else null
	_undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS if merge_ends else UndoRedo.MERGE_DISABLE
	)
	_undo_redo.add_do_method(document.set_object_animation_data.bind(object_id, do_data))
	_undo_redo.add_undo_method(document.set_object_animation_data.bind(object_id, old_data))
	_undo_redo.commit_action()
	changed.emit()


func set_attachment_states(
	document: GMSDocument,
	new_states: Array[Dictionary],
	action_name: String = "Change Bone Attachments"
) -> void:
	if document == null or new_states.is_empty():
		return
	var old_states: Array[Dictionary] = []
	var valid_new_states: Array[Dictionary] = []
	for state: Dictionary in new_states:
		var object_id: String = str(state.get("object_id", ""))
		var object: GMSModelObject = document.get_object(object_id)
		if object == null or object.locked:
			continue
		old_states.append({
			"object_id": object_id,
			"rig_object_id": object.attachment_rig_object_id,
			"bone_id": object.attachment_bone_id,
			"bone_name": object.attachment_bone_name,
			"offset": object.attachment_offset,
			"transform": object.transform,
		})
		valid_new_states.append(state)
	if valid_new_states.is_empty():
		return
	_undo_redo.create_action(action_name)
	for state: Dictionary in valid_new_states:
		_undo_redo.add_do_method(document.set_object_attachment_state.bind(
			str(state.get("object_id", "")),
			str(state.get("rig_object_id", "")),
			str(state.get("bone_id", "")),
			str(state.get("bone_name", "")),
			state.get("offset", Transform3D.IDENTITY),
			state.get("transform", Transform3D.IDENTITY)
		))
	for state: Dictionary in old_states:
		_undo_redo.add_undo_method(document.set_object_attachment_state.bind(
			str(state.get("object_id", "")),
			str(state.get("rig_object_id", "")),
			str(state.get("bone_id", "")),
			str(state.get("bone_name", "")),
			state.get("offset", Transform3D.IDENTITY),
			state.get("transform", Transform3D.IDENTITY)
		))
	_undo_redo.commit_action()
	changed.emit()


func set_material(
	document: GMSDocument,
	object_id: String,
	new_material: StandardMaterial3D
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_material == null:
		return
	var old_material: StandardMaterial3D = object.material

	_undo_redo.create_action("Change Material")
	_undo_redo.add_do_method(document.set_object_material.bind(object_id, new_material))
	_undo_redo.add_undo_method(document.set_object_material.bind(object_id, old_material))
	_undo_redo.commit_action()
	changed.emit()


func set_material_state(
	document: GMSDocument,
	object_id: String,
	new_materials: Array[StandardMaterial3D],
	new_active_index: int,
	new_mesh: GMSMeshData = null,
	action_name: String = "Change Materials"
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_materials.is_empty():
		return
	var old_materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(object.materials)
	var old_active_index: int = object.active_material_index
	var old_mesh: GMSMeshData = object.mesh_data
	var do_materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(new_materials)

	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(
		document.set_object_material_state.bind(object_id, do_materials, new_active_index, new_mesh)
	)
	_undo_redo.add_undo_method(
		document.set_object_material_state.bind(object_id, old_materials, old_active_index, old_mesh)
	)
	_undo_redo.commit_action()
	changed.emit()


func set_collision(
	document: GMSDocument,
	object_id: String,
	new_collision_type: int,
	new_collision_layer: int,
	new_collision_mask: int
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null:
		return
	if (
		object.collision_type == new_collision_type
		and object.collision_layer == new_collision_layer
		and object.collision_mask == new_collision_mask
	):
		return
	var old_collision_type: int = object.collision_type
	var old_collision_layer: int = object.collision_layer
	var old_collision_mask: int = object.collision_mask

	_undo_redo.create_action("Change Collision Settings")
	_undo_redo.add_do_method(
		document.set_object_collision.bind(
			object_id,
			new_collision_type,
			new_collision_layer,
			new_collision_mask
		)
	)
	_undo_redo.add_undo_method(
		document.set_object_collision.bind(
			object_id,
			old_collision_type,
			old_collision_layer,
			old_collision_mask
		)
	)
	_undo_redo.commit_action()
	changed.emit()


func set_modifiers(
	document: GMSDocument,
	object_id: String,
	new_modifiers: Array[GMSModifier],
	action_name: String = "Change Modifiers",
	merge_ends: bool = false
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null:
		return
	var old_modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var do_modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(new_modifiers)

	_undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS if merge_ends else UndoRedo.MERGE_DISABLE
	)
	_undo_redo.add_do_method(document.set_object_modifiers.bind(object_id, do_modifiers))
	_undo_redo.add_undo_method(document.set_object_modifiers.bind(object_id, old_modifiers))
	_undo_redo.commit_action()
	changed.emit()


func set_mesh_and_modifiers(
	document: GMSDocument,
	object_id: String,
	new_mesh: GMSMeshData,
	new_modifiers: Array[GMSModifier],
	action_name: String = "Apply Modifiers",
	preserved_array_mesh: ArrayMesh = null
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_mesh == null:
		return
	var old_mesh: GMSMeshData = object.mesh_data
	var old_modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(object.modifiers)
	var do_modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(new_modifiers)

	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(
		document.set_object_mesh_and_modifiers.bind(
			object_id, new_mesh, do_modifiers, preserved_array_mesh
		)
	)
	_undo_redo.add_undo_method(
		document.set_object_mesh_and_modifiers.bind(object_id, old_mesh, old_modifiers, null)
	)
	_undo_redo.commit_action()
	changed.emit()


func undo() -> void:
	if _undo_redo.has_undo():
		_undo_redo.undo()
		changed.emit()


func redo() -> void:
	if _undo_redo.has_redo():
		_undo_redo.redo()
		changed.emit()


func has_undo() -> bool:
	return _undo_redo.has_undo()


func has_redo() -> bool:
	return _undo_redo.has_redo()


func get_undo_name() -> String:
	if not has_undo():
		return ""
	return _undo_redo.get_current_action_name()


func clear() -> void:
	_undo_redo.clear_history()
	changed.emit()


func set_transforms(
	document: GMSDocument,
	object_ids: PackedStringArray,
	new_transforms: Array[Transform3D],
	action_name: String = "Transform Objects"
) -> void:
	var old_transforms: Array[Transform3D] = []
	var valid_ids: PackedStringArray = PackedStringArray()
	var valid_new: Array[Transform3D] = []
	for index: int in mini(object_ids.size(), new_transforms.size()):
		var object: GMSModelObject = document.get_object(object_ids[index])
		if object == null or object.locked:
			continue
		valid_ids.append(object.object_id)
		old_transforms.append(object.transform)
		valid_new.append(new_transforms[index])
	if valid_ids.is_empty():
		return
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(document.set_object_transforms.bind(valid_ids, valid_new))
	_undo_redo.add_undo_method(document.set_object_transforms.bind(valid_ids, old_transforms))
	_undo_redo.commit_action()
	changed.emit()


func set_mesh_and_transform(
	document: GMSDocument,
	object_id: String,
	new_mesh: GMSMeshData,
	new_transform: Transform3D,
	action_name: String
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_mesh == null:
		return
	var old_mesh: GMSMeshData = object.mesh_data
	var old_transform: Transform3D = object.transform
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(
		document.set_object_mesh_and_transform.bind(object_id, new_mesh, new_transform)
	)
	_undo_redo.add_undo_method(
		document.set_object_mesh_and_transform.bind(object_id, old_mesh, old_transform)
	)
	_undo_redo.commit_action()
	changed.emit()


func set_mesh_transform_and_rig(
	document: GMSDocument,
	object_id: String,
	new_mesh: GMSMeshData,
	new_transform: Transform3D,
	new_rig: GMSRigData,
	action_name: String
) -> void:
	var object: GMSModelObject = document.get_object(object_id)
	if object == null or new_mesh == null:
		return
	var old_mesh: GMSMeshData = object.mesh_data
	var old_transform: Transform3D = object.transform
	var old_rig: GMSRigData = object.rig_data.duplicate_rig() if object.rig_data != null else null
	var do_rig: GMSRigData = new_rig.duplicate_rig() if new_rig != null else null
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(
		document.set_object_mesh_transform_and_rig.bind(object_id, new_mesh, new_transform, do_rig)
	)
	_undo_redo.add_undo_method(
		document.set_object_mesh_transform_and_rig.bind(object_id, old_mesh, old_transform, old_rig)
	)
	_undo_redo.commit_action()
	changed.emit()


func separate_faces(
	document: GMSDocument,
	source_object_id: String,
	new_source_mesh: GMSMeshData,
	new_object: GMSModelObject
) -> void:
	var source: GMSModelObject = document.get_object(source_object_id)
	if source == null or new_source_mesh == null or new_object == null:
		return
	var old_mesh: GMSMeshData = source.mesh_data
	_undo_redo.create_action("Separate Selection")
	_undo_redo.add_do_method(
		document.apply_separate.bind(source_object_id, new_source_mesh, new_object)
	)
	_undo_redo.add_undo_method(
		document.restore_separate.bind(source_object_id, old_mesh, new_object.object_id)
	)
	_undo_redo.commit_action()
	changed.emit()


func join_objects(
	document: GMSDocument,
	active_object_id: String,
	joined_mesh: GMSMeshData,
	joined_materials: Array[StandardMaterial3D],
	joined_active_material_index: int,
	joined_modifiers: Array[GMSModifier],
	removed_object_ids: PackedStringArray
) -> void:
	var active: GMSModelObject = document.get_object(active_object_id)
	if active == null or joined_mesh == null or removed_object_ids.is_empty():
		return
	var old_mesh: GMSMeshData = active.mesh_data
	var old_materials: Array[StandardMaterial3D] = GMSModelObject.duplicate_materials(active.materials)
	var old_active_material_index: int = active.active_material_index
	var old_modifiers: Array[GMSModifier] = GMSModelObject.duplicate_modifiers(active.modifiers)
	var removed_objects: Array[GMSModelObject] = []
	var removed_indices: PackedInt32Array = PackedInt32Array()
	for object_id: String in removed_object_ids:
		var object: GMSModelObject = document.get_object(object_id)
		var object_index: int = document.get_object_index(object_id)
		if object == null or object_index < 0:
			continue
		removed_objects.append(object)
		removed_indices.append(object_index)
	if removed_objects.is_empty():
		return

	for first: int in removed_objects.size():
		for second: int in range(first + 1, removed_objects.size()):
			if removed_indices[second] < removed_indices[first]:
				var swap_index: int = removed_indices[first]
				removed_indices[first] = removed_indices[second]
				removed_indices[second] = swap_index
				var swap_object: GMSModelObject = removed_objects[first]
				removed_objects[first] = removed_objects[second]
				removed_objects[second] = swap_object
	_undo_redo.create_action("Join Objects")
	_undo_redo.add_do_method(
		document.apply_join.bind(
			active_object_id,
			joined_mesh,
			GMSModelObject.duplicate_materials(joined_materials),
			joined_active_material_index,
			GMSModelObject.duplicate_modifiers(joined_modifiers),
			removed_object_ids
		)
	)
	_undo_redo.add_undo_method(
		document.restore_join.bind(
			active_object_id,
			old_mesh,
			old_materials,
			old_active_material_index,
			old_modifiers,
			removed_objects,
			removed_indices
		)
	)
	_undo_redo.commit_action()
	changed.emit()
