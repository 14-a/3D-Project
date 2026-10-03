@tool
class_name GASPlaybackPrepareJob
extends RefCounted

var task_id: int = -1
var revision: int = -1
var sample_rate: int = 44100
var stereo: bool = false
var data: PackedByteArray = PackedByteArray()
var ok: bool = false


func start(snapshot: GASEditorModel, source_revision: int) -> bool:
	if task_id >= 0 or snapshot == null:
		return false
	revision = source_revision
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker").bind(snapshot), false, "GAS playback render")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func finish() -> void:
	if task_id < 0 or not WorkerThreadPool.is_task_completed(task_id):
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1


func _worker(snapshot: GASEditorModel) -> void:
	var mix: GASPCMData = snapshot.mixdown()
	if mix == null or mix.frame_count() <= 0:
		return
	stereo = mix.is_stereo()
	sample_rate = mix.sample_rate
	var stride: int = 4 if stereo else 2
	var frame_count: int = mix.frame_count()
	var output: PackedByteArray = PackedByteArray()
	output.resize(frame_count * stride)
	var left: PackedFloat32Array = mix.left
	var right: PackedFloat32Array = mix.right
	for frame_index: int in range(frame_count):
		var left_i: int = clampi(int(round(left[frame_index] * 32767.0)), -32768, 32767)
		output.encode_s16(frame_index * stride, left_i)
		if stereo:
			var right_i: int = clampi(int(round(right[frame_index] * 32767.0)), -32768, 32767)
			output.encode_s16(frame_index * stride + 2, right_i)
	data = output
	ok = not data.is_empty()
