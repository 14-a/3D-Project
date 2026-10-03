@tool
class_name GASWaveformCache
extends RefCounted

const MAX_FINE_LEVEL_BLOCKS: int = 262144
const MAX_BLOCK_SIZE: int = 65536

var pcm: GASPCMData
var levels: Array[Dictionary] = []


func build(source: GASPCMData) -> void:
	pcm = source
	levels.clear()
	if pcm == null or pcm.frame_count() == 0:
		return
	var first_block_size: int = 4
	while int(ceil(float(pcm.frame_count()) / float(first_block_size))) > MAX_FINE_LEVEL_BLOCKS:
		first_block_size *= 2
	var first: Dictionary = _build_raw_level(first_block_size)
	levels.append(first)
	var previous: Dictionary = first
	var previous_block_size: int = first_block_size
	while previous_block_size < pcm.frame_count() and previous_block_size < MAX_BLOCK_SIZE:
		var next_block_size: int = previous_block_size * 4
		var next_level: Dictionary = _aggregate_arrays(previous, next_block_size, pcm.is_stereo())
		levels.append(next_level)
		previous = next_level
		previous_block_size = next_block_size


func build_from_paged(store: GASPagedPCMStore) -> bool:
	pcm = null
	levels.clear()
	if store == null or store.total_frames <= 0:
		return false
	var block_size: int = 4
	while int(ceil(float(store.total_frames) / float(block_size))) > MAX_FINE_LEVEL_BLOCKS:
		block_size *= 2
	var blocks: int = int(ceil(float(store.total_frames) / float(block_size)))
	var min_left: PackedFloat32Array = PackedFloat32Array()
	var max_left: PackedFloat32Array = PackedFloat32Array()
	var min_right: PackedFloat32Array = PackedFloat32Array()
	var max_right: PackedFloat32Array = PackedFloat32Array()
	min_left.resize(blocks)
	max_left.resize(blocks)
	if store.channels == 2:
		min_right.resize(blocks)
		max_right.resize(blocks)
	for block: int in range(blocks):
		min_left[block] = 1.0
		max_left[block] = -1.0
		if store.channels == 2:
			min_right[block] = 1.0
			max_right[block] = -1.0
	var global_frame: int = 0
	for chunk_index: int in range(store.chunk_count()):
		var chunk: GASPCMData = store.read_chunk(chunk_index)
		if chunk == null:
			levels.clear()
			return false
		for local_frame: int in range(chunk.frame_count()):
			var block: int = int(global_frame / block_size)
			var left_value: float = chunk.left[local_frame]
			min_left[block] = minf(min_left[block], left_value)
			max_left[block] = maxf(max_left[block], left_value)
			if store.channels == 2:
				var right_value: float = chunk.right[local_frame]
				min_right[block] = minf(min_right[block], right_value)
				max_right[block] = maxf(max_right[block], right_value)
			global_frame += 1
	var first: Dictionary = {
		"block_size": block_size,
		"min_left": min_left,
		"max_left": max_left,
		"min_right": min_right,
		"max_right": max_right,
	}
	levels.append(first)
	var previous: Dictionary = first
	var previous_block_size: int = block_size
	while previous_block_size < store.total_frames and previous_block_size < MAX_BLOCK_SIZE:
		var next_block_size: int = previous_block_size * 4
		var next_level: Dictionary = _aggregate_arrays(previous, next_block_size, store.channels == 2)
		levels.append(next_level)
		previous = next_level
		previous_block_size = next_block_size
	return true


func build_from_summary(source: GASPCMData, block_size: int, min_left: PackedFloat32Array, max_left: PackedFloat32Array, min_right: PackedFloat32Array, max_right: PackedFloat32Array) -> void:
	pcm = source
	levels.clear()
	if pcm == null or pcm.frame_count() == 0 or min_left.is_empty() or min_left.size() != max_left.size():
		return
	var stereo: bool = pcm.is_stereo() and min_right.size() == min_left.size() and max_right.size() == min_left.size()
	var first: Dictionary = {
		"block_size": maxi(1, block_size),
		"min_left": min_left,
		"max_left": max_left,
		"min_right": min_right if stereo else PackedFloat32Array(),
		"max_right": max_right if stereo else PackedFloat32Array(),
	}
	levels.append(first)
	var previous: Dictionary = first
	var previous_block_size: int = maxi(1, block_size)
	while previous_block_size < pcm.frame_count() and previous_block_size < MAX_BLOCK_SIZE:
		var next_block_size: int = previous_block_size * 4
		var next_level: Dictionary = _aggregate_arrays(previous, next_block_size, stereo)
		levels.append(next_level)
		previous = next_level
		previous_block_size = next_block_size


func get_level(samples_per_pixel: float) -> Dictionary:
	if levels.is_empty():
		return {}
	var wanted: float = maxf(1.0, samples_per_pixel)
	var best: Dictionary = levels[0]
	for level: Dictionary in levels:
		var block_size: int = int(level["block_size"])
		if float(block_size) <= wanted * 2.0:
			best = level
		else:
			break
	return best


func _build_raw_level(block_size: int) -> Dictionary:
	var blocks: int = int(ceil(float(pcm.frame_count()) / float(block_size)))
	var min_left: PackedFloat32Array = PackedFloat32Array()
	var max_left: PackedFloat32Array = PackedFloat32Array()
	var min_right: PackedFloat32Array = PackedFloat32Array()
	var max_right: PackedFloat32Array = PackedFloat32Array()
	min_left.resize(blocks)
	max_left.resize(blocks)
	if pcm.is_stereo():
		min_right.resize(blocks)
		max_right.resize(blocks)
	for block: int in range(blocks):
		var start_frame: int = block * block_size
		var end_frame: int = mini(pcm.frame_count(), start_frame + block_size)
		var lo_l: float = 1.0
		var hi_l: float = -1.0
		var lo_r: float = 1.0
		var hi_r: float = -1.0
		for i: int in range(start_frame, end_frame):
			var lv: float = pcm.left[i]
			lo_l = minf(lo_l, lv)
			hi_l = maxf(hi_l, lv)
			if pcm.is_stereo():
				var rv: float = pcm.right[i]
				lo_r = minf(lo_r, rv)
				hi_r = maxf(hi_r, rv)
		min_left[block] = lo_l
		max_left[block] = hi_l
		if pcm.is_stereo():
			min_right[block] = lo_r
			max_right[block] = hi_r
	return {
		"block_size": block_size,
		"min_left": min_left,
		"max_left": max_left,
		"min_right": min_right,
		"max_right": max_right,
	}


func _aggregate_arrays(previous: Dictionary, new_block_size: int, stereo: bool) -> Dictionary:
	var prev_min_left: PackedFloat32Array = previous["min_left"] as PackedFloat32Array
	var prev_max_left: PackedFloat32Array = previous["max_left"] as PackedFloat32Array
	var prev_min_right: PackedFloat32Array = previous["min_right"] as PackedFloat32Array
	var prev_max_right: PackedFloat32Array = previous["max_right"] as PackedFloat32Array
	var blocks: int = int(ceil(float(prev_min_left.size()) / 4.0))
	var min_left: PackedFloat32Array = PackedFloat32Array()
	var max_left: PackedFloat32Array = PackedFloat32Array()
	var min_right: PackedFloat32Array = PackedFloat32Array()
	var max_right: PackedFloat32Array = PackedFloat32Array()
	min_left.resize(blocks)
	max_left.resize(blocks)
	if stereo:
		min_right.resize(blocks)
		max_right.resize(blocks)
	for block: int in range(blocks):
		var start: int = block * 4
		var finish: int = mini(prev_min_left.size(), start + 4)
		var lo_l: float = 1.0
		var hi_l: float = -1.0
		var lo_r: float = 1.0
		var hi_r: float = -1.0
		for i: int in range(start, finish):
			lo_l = minf(lo_l, prev_min_left[i])
			hi_l = maxf(hi_l, prev_max_left[i])
			if stereo:
				lo_r = minf(lo_r, prev_min_right[i])
				hi_r = maxf(hi_r, prev_max_right[i])
		min_left[block] = lo_l
		max_left[block] = hi_l
		if stereo:
			min_right[block] = lo_r
			max_right[block] = hi_r
	return {
		"block_size": new_block_size,
		"min_left": min_left,
		"max_left": max_left,
		"min_right": min_right,
		"max_right": max_right,
	}

