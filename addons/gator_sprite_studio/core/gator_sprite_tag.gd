@tool
class_name GatorSpriteTag
extends Resource

@export var tag_title: String = "loop"
@export var from_frame: int = 0
@export var to_frame: int = 0
@export var frame_indices: PackedInt32Array = PackedInt32Array()
@export var color: Color = Color(0.25, 0.72, 0.32, 1.0)

func get_frame_indices(frame_count: int = -1) -> Array[int]:
	var resolved_indices: Array[int] = []
	if frame_indices.is_empty():
		var range_start: int = mini(from_frame, to_frame)
		var range_end: int = maxi(from_frame, to_frame)
		if frame_count >= 0:
			if frame_count <= 0:
				return resolved_indices
			range_start = clampi(range_start, 0, frame_count - 1)
			range_end = clampi(range_end, range_start, frame_count - 1)
		for frame_index: int in range(range_start, range_end + 1):
			resolved_indices.append(frame_index)
		return resolved_indices

	for stored_frame_index: int in frame_indices:
		if stored_frame_index < 0:
			continue
		if frame_count >= 0 and stored_frame_index >= frame_count:
			continue
		if not resolved_indices.has(stored_frame_index):
			resolved_indices.append(stored_frame_index)
	resolved_indices.sort()
	return resolved_indices

func contains_frame(frame_index: int, frame_count: int = -1) -> bool:
	return get_frame_indices(frame_count).has(frame_index)

func set_frame_indices(requested_indices: Array[int], frame_count: int = -1) -> void:
	var resolved_indices: Array[int] = []
	for requested_frame_index: int in requested_indices:
		if requested_frame_index < 0:
			continue
		if frame_count >= 0 and requested_frame_index >= frame_count:
			continue
		if not resolved_indices.has(requested_frame_index):
			resolved_indices.append(requested_frame_index)
	resolved_indices.sort()
	frame_indices = PackedInt32Array(resolved_indices)
	if resolved_indices.is_empty():
		from_frame = 0
		to_frame = 0
		return
	from_frame = resolved_indices[0]
	to_frame = resolved_indices[resolved_indices.size() - 1]

func set_contiguous_range(range_start: int, range_end: int, frame_count: int = -1) -> void:
	var resolved_start: int = mini(range_start, range_end)
	var resolved_end: int = maxi(range_start, range_end)
	if frame_count >= 0:
		if frame_count <= 0:
			var empty_indices: Array[int] = []
			set_frame_indices(empty_indices)
			return
		resolved_start = clampi(resolved_start, 0, frame_count - 1)
		resolved_end = clampi(resolved_end, resolved_start, frame_count - 1)
	var contiguous_indices: Array[int] = []
	for frame_index: int in range(resolved_start, resolved_end + 1):
		contiguous_indices.append(frame_index)
	set_frame_indices(contiguous_indices, frame_count)
