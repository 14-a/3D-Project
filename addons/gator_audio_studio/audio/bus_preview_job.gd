@tool
class_name GASBusPreviewJob
extends RefCounted

var task_id: int = -1
var snapshot: GASEditorModel
var model_revision: int = -1
var start_frame: int = 0
var end_frame: int = -1
var track_indices: PackedInt32Array = PackedInt32Array()
var track_streams: Array[AudioStreamWAV] = []
var clock_stream: AudioStreamWAV
var success: bool = false


func start(model_snapshot: GASEditorModel, revision: int, from_frame: int, to_frame: int) -> bool:
	if task_id >= 0 or model_snapshot == null:
		return false
	snapshot = model_snapshot
	model_revision = revision
	start_frame = maxi(0, from_frame)
	end_frame = to_frame
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker"), false, "GAS bus preview render")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1


func _worker() -> void:
	if snapshot == null:
		return
	var has_solo: bool = false
	for track: GASEditorTrack in snapshot.tracks:
		if track.solo:
			has_solo = true
			break
	for track_index: int in range(snapshot.tracks.size()):
		var track: GASEditorTrack = snapshot.tracks[track_index]
		if track.mute or (has_solo and not track.solo):
			continue
		var rendered: GASPCMData = snapshot.render_track(track_index)
		if rendered == null or rendered.frame_count() <= 0:
			continue
		var stream: AudioStreamWAV = rendered.to_wav()
		if stream == null:
			continue
		track_indices.append(track_index)
		track_streams.append(stream)
	var mix: GASPCMData = snapshot.mixdown()
	if mix != null and mix.frame_count() > 0:
		clock_stream = mix.to_wav()
	success = not track_streams.is_empty()
