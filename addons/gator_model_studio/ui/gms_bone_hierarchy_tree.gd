@tool
class_name GMSBoneHierarchyTree
extends Tree

signal bone_reparent_requested(bone_index: int, new_parent_index: int)

const DRAG_TYPE: StringName = &"gms_bone_hierarchy_item"


func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = get_item_at_position(at_position)
	if item == null:
		return null
	var bone_index: int = int(item.get_metadata(0))
	if bone_index < 0:
		return null
	item.select(0)
	var preview: Label = Label.new()
	preview.text = " Reparent %s " % item.get_text(0)
	set_drag_preview(preview)
	return {
		"type": DRAG_TYPE,
		"bone_index": bone_index,
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	set_drop_mode_flags(Tree.DROP_MODE_DISABLED)
	if not data is Dictionary:
		return false
	var drag_data: Dictionary = data as Dictionary
	if StringName(drag_data.get("type", &"")) != DRAG_TYPE:
		return false
	var source_index: int = int(drag_data.get("bone_index", -1))
	if source_index < 0:
		return false
	var target_item: TreeItem = get_item_at_position(at_position)
	if target_item == null:
		return true
	var target_index: int = int(target_item.get_metadata(0))
	if target_index < 0 or target_index == source_index:
		return false
	var source_item: TreeItem = _find_item_by_bone_index(source_index)
	if source_item == null or _item_is_descendant_of(target_item, source_item):
		return false
	set_drop_mode_flags(Tree.DROP_MODE_ON_ITEM)
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	var drag_data: Dictionary = data as Dictionary
	var source_index: int = int(drag_data.get("bone_index", -1))
	if source_index < 0:
		return
	var target_item: TreeItem = get_item_at_position(at_position)
	var target_index: int = -1
	if target_item != null:
		target_index = int(target_item.get_metadata(0))
	bone_reparent_requested.emit(source_index, target_index)


func _find_item_by_bone_index(bone_index: int) -> TreeItem:
	var root: TreeItem = get_root()
	if root == null:
		return null
	return _find_item_recursive(root, bone_index)


func _find_item_recursive(item: TreeItem, bone_index: int) -> TreeItem:
	if int(item.get_metadata(0)) == bone_index:
		return item
	var child: TreeItem = item.get_first_child()
	while child != null:
		var match_item: TreeItem = _find_item_recursive(child, bone_index)
		if match_item != null:
			return match_item
		child = child.get_next()
	return null


func _item_is_descendant_of(item: TreeItem, possible_ancestor: TreeItem) -> bool:
	var cursor: TreeItem = item
	while cursor != null:
		if cursor == possible_ancestor:
			return true
		cursor = cursor.get_parent()
	return false
