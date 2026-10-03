@tool
class_name GASEditorActionJob
extends RefCounted

const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")

const ACTION_NONE: int = 0
const ACTION_MODEL_TRIM: int = 1
const ACTION_MODEL_SILENCE: int = 2
const ACTION_MODEL_JOIN: int = 3
const ACTION_MODEL_SAMPLE_ZERO: int = 4
const ACTION_MODEL_SAMPLE_INTERPOLATE: int = 5
const ACTION_MODEL_SAMPLE_SMOOTH: int = 6
const ACTION_MODEL_SAMPLE_REPAIR: int = 7
const ACTION_MODEL_MERGE_DOWN: int = 8
const ACTION_MODEL_RENDER_NEW: int = 9
const ACTION_MODEL_MIX_MONO: int = 10
const ACTION_MODEL_MIX_STEREO: int = 11
const ACTION_MODEL_COPY: int = 12
const ACTION_MODEL_CUT: int = 13
const ACTION_EFFECT_PREVIEW: int = 20
const ACTION_EFFECT_APPLY_CLIPS: int = 21
const ACTION_EFFECT_APPLY_TRACKS: int = 22
const ACTION_RACK_RENDER_CLIPS: int = 23
const ACTION_RACK_RENDER_TRACK: int = 24

var task_id: int = -1
var action: int = ACTION_NONE
var snapshot: GASEditorModel
var model_revision: int = -1
var success: bool = false
var pcm_result: GASPCMData
var wav_result: AudioStreamWAV
var error_message: String = ""

var _effect: GASEffectData
var _effect_target: int = 0
var _selected_rack_index: int = -1
var _preview_stack: Array[GASEffectData] = []


func start_model_action(model_snapshot: GASEditorModel, action_id: int, revision: int) -> bool:
	if task_id >= 0 or model_snapshot == null:
		return false
	snapshot = model_snapshot
	action = action_id
	model_revision = revision
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_model_action"), false, "GAS editor action")
	return task_id >= 0


func start_effect_preview(
	model_snapshot: GASEditorModel,
	effect: GASEffectData,
	target: int,
	rack_index: int,
	stack: Array[GASEffectData],
	revision: int
) -> bool:
	if task_id >= 0 or model_snapshot == null or effect == null:
		return false
	snapshot = model_snapshot
	_effect = effect.duplicate_effect()
	_effect_target = target
	_selected_rack_index = rack_index
	_preview_stack.clear()
	for item: GASEffectData in stack:
		_preview_stack.append(item.duplicate_effect())
	action = ACTION_EFFECT_PREVIEW
	model_revision = revision
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_effect_preview"), false, "GAS effect preview")
	return task_id >= 0


func start_effect_apply(model_snapshot: GASEditorModel, effect: GASEffectData, target: int, revision: int) -> bool:
	if task_id >= 0 or model_snapshot == null or effect == null:
		return false
	snapshot = model_snapshot
	_effect = effect.duplicate_effect()
	_effect_target = target
	action = ACTION_EFFECT_APPLY_CLIPS if target == 0 else ACTION_EFFECT_APPLY_TRACKS
	model_revision = revision
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_effect_apply"), false, "GAS destructive effect")
	return task_id >= 0


func start_rack_render(model_snapshot: GASEditorModel, target: int, revision: int) -> bool:
	if task_id >= 0 or model_snapshot == null:
		return false
	snapshot = model_snapshot
	_effect_target = target
	action = ACTION_RACK_RENDER_CLIPS if target == 0 else ACTION_RACK_RENDER_TRACK
	model_revision = revision
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_rack_render"), false, "GAS rack render")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1


func _worker_model_action() -> void:
	if snapshot == null:
		return
	match action:
		ACTION_MODEL_TRIM:
			var before_trim: int = snapshot.change_revision
			snapshot.trim_to_selection()
			success = snapshot.change_revision != before_trim
		ACTION_MODEL_SILENCE:
			var before_silence: int = snapshot.change_revision
			snapshot.silence_selection()
			success = snapshot.change_revision != before_silence
		ACTION_MODEL_JOIN:
			success = snapshot.join_selected_clips()
		ACTION_MODEL_SAMPLE_ZERO:
			success = snapshot.sample_edit_selection("Zero")
		ACTION_MODEL_SAMPLE_INTERPOLATE:
			success = snapshot.sample_edit_selection("Interpolate")
		ACTION_MODEL_SAMPLE_SMOOTH:
			success = snapshot.sample_edit_selection("Smooth")
		ACTION_MODEL_SAMPLE_REPAIR:
			success = snapshot.sample_edit_selection("Repair")
		ACTION_MODEL_MERGE_DOWN:
			success = snapshot.merge_selected_track_down()
		ACTION_MODEL_RENDER_NEW:
			success = snapshot.render_selected_track_to_new_track()
		ACTION_MODEL_MIX_MONO:
			success = snapshot.mix_selected_track_to_mono()
		ACTION_MODEL_MIX_STEREO:
			success = snapshot.mix_selected_track_to_stereo()
		ACTION_MODEL_COPY:
			snapshot.copy_selection()
			success = snapshot.clipboard != null and snapshot.clipboard.frame_count() > 0
		ACTION_MODEL_CUT:
			var before_cut: int = snapshot.change_revision
			snapshot.cut_selection()
			success = snapshot.change_revision != before_cut


func _worker_effect_preview() -> void:
	if snapshot == null or _effect == null:
		return
	var base: GASPCMData = null
	if _selected_rack_index >= 0:
		var stack: Array[GASEffectData] = []
		for item: GASEffectData in _preview_stack:
			stack.append(item.duplicate_effect())
		if _selected_rack_index < stack.size():
			stack[_selected_rack_index] = _effect.duplicate_effect()
		match _effect_target:
			0:
				if not snapshot.selected_clip_ids.is_empty():
					var clip: GASEditorClip = snapshot.find_clip(snapshot.selected_clip_ids[0])
					if clip != null and clip.pcm != null:
						var raw_clip: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
						base = EffectEngine.process_stack(raw_clip, stack)
			1:
				var dry_track: GASPCMData = snapshot.render_track_dry(snapshot.selected_track)
				if dry_track != null:
					base = EffectEngine.process_stack(dry_track, stack)
			2:
				var dry_master: GASPCMData = snapshot.mixdown_without_master()
				if dry_master != null:
					base = EffectEngine.process_stack(dry_master, stack)
	else:
		match _effect_target:
			0:
				base = snapshot.preview_selected_clip_pcm()
			1:
				base = snapshot.render_track(snapshot.selected_track)
			2:
				base = snapshot.mixdown()
		if base != null:
			base = EffectEngine.process(base, _effect)
	if base != null and _effect_target == 1 and snapshot.has_selection():
		var start_frame: int = clampi(snapshot.selection_start, 0, base.frame_count())
		var end_frame: int = clampi(snapshot.selection_end, start_frame, base.frame_count())
		if end_frame > start_frame:
			base = base.slice_frames(start_frame, end_frame)
	pcm_result = base
	success = base != null and base.frame_count() > 0
	if success:
		wav_result = base.to_wav()


func _worker_effect_apply() -> void:
	if snapshot == null or _effect == null:
		return
	if _effect_target == 0:
		success = snapshot.apply_effect_to_selected_clips_destructive(_effect)
	else:
		success = snapshot.apply_effect_to_selected_tracks_destructive(_effect)


func _worker_rack_render() -> void:
	if snapshot == null:
		return
	if _effect_target == 0:
		var changed: bool = false
		for clip_id: int in snapshot.selected_clip_ids:
			var clip: GASEditorClip = snapshot.find_clip(clip_id)
			if clip == null or clip.pcm == null or clip.effect_stack.is_empty():
				continue
			var raw: GASPCMData = clip.pcm.slice_frames(clip.source_start_frame, clip.source_end())
			var rendered: GASPCMData = EffectEngine.process_stack(raw, clip.effect_stack)
			if rendered == null:
				continue
			clip.pcm = rendered
			clip.source_start_frame = 0
			clip.source_end_frame = rendered.frame_count()
			clip.source_path = "effect://rendered_stack"
			clip.effect_stack.clear()
			clip.rebuild_cache()
			changed = true
		if changed:
			snapshot.dirty = true
		success = changed
		return
	if snapshot.selected_track < 0 or snapshot.selected_track >= snapshot.tracks.size():
		return
	var track: GASEditorTrack = snapshot.tracks[snapshot.selected_track]
	if track.effect_stack.is_empty():
		return
	var rendered_track: GASPCMData = snapshot.render_track(snapshot.selected_track)
	if rendered_track == null:
		return
	var end_frame: int = track.end_frame()
	success = snapshot.replace_track_region_with_pcm(snapshot.selected_track, 0, end_frame, rendered_track, track.name + " Rendered", "Render Effect Stack")
	if success:
		snapshot.tracks[snapshot.selected_track].effect_stack.clear()
