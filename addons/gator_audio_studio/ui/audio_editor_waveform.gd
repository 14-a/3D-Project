@tool
class_name GASAudioEditorWaveform
extends Control

signal selection_changed(start_frame: int, end_frame: int)
signal cursor_changed(frame: int)
signal track_selected(index: int)
signal clip_selection_changed()
signal edit_committed(action: String)
signal clip_context_requested(clip_id: int, screen_position: Vector2)
signal clip_rename_requested(clip_id: int)
signal files_dropped(paths: PackedStringArray, frame: int, track_index: int)
signal generated_audio_dropped(wav: AudioStreamWAV, suggested_name: String, frame: int, track_index: int)
signal view_changed(start_frame: int, samples_per_pixel: float)

const ClipVisualJob := preload("res://addons/gator_audio_studio/audio/clip_visual_job.gd")

const TIMELINE_HEIGHT: float = 32.0
const TRACK_HEIGHT: float = 232.0
const COLLAPSED_TRACK_HEIGHT: float = 48.0
const CLIP_MARGIN: float = 5.0
const HANDLE_WIDTH: float = 7.0
const DRAG_THRESHOLD: float = 3.0
const DRAG_NONE: int = 0
const DRAG_TIME_SELECTION: int = 1
const DRAG_MOVE_CLIPS: int = 2
const DRAG_TRIM_LEFT: int = 3
const DRAG_TRIM_RIGHT: int = 4

var model: GASEditorModel
var view_start_frame: int = 0
var samples_per_pixel: float = 100.0
var sample_draw_mode: bool = false
var time_base_mode: String = "Seconds"
var spectral_selection_low_hz: float = 0.0
var spectral_selection_high_hz: float = 0.0
var spectral_selection_active: bool = false
var _sample_draw_started: bool = false
var _sample_draw_changed: bool = false
var _sample_draw_clip_id: int = 0

var _drag_mode: int = DRAG_NONE
var _drag_started: bool = false
var _drag_press_position: Vector2 = Vector2.ZERO
var _drag_press_frame: int = 0
var _drag_press_track: int = -1
var _drag_clip_id: int = 0
var _drag_anchor_frame: int = 0
var _drag_original_locations: Dictionary = {}
var _preview_delta_frames: int = 0
var _preview_track_delta: int = 0
var _preview_trim_frame: int = 0

var _bg: Color = Color(0.07, 0.075, 0.088)
var _timeline_bg: Color = Color(0.105, 0.11, 0.125)
var _track_bg_a: Color = Color(0.09, 0.095, 0.11)
var _track_bg_b: Color = Color(0.075, 0.08, 0.095)
var _clip_bg: Color = Color(0.11, 0.19, 0.22, 0.86)
var _clip_selected_bg: Color = Color(0.14, 0.29, 0.36, 0.92)
var _wave_color: Color = Color(0.35, 0.82, 0.67)
var _wave_right_color: Color = Color(0.33, 0.68, 0.86)
var _selection_color: Color = Color(0.25, 0.55, 0.9, 0.22)
var _cursor_color: Color = Color(0.95, 0.83, 0.35)
var _grid_color: Color = Color(0.22, 0.24, 0.28, 0.65)
var _selected_border: Color = Color(0.95, 0.76, 0.28)
var _ghost_color: Color = Color(0.95, 0.76, 0.28, 0.35)
var _marker_color: Color = Color(0.85, 0.35, 0.8, 0.9)
var _waveform_cache_jobs: Dictionary = {}
var _spectrogram_jobs: Dictionary = {}
var _track_height_overrides: PackedFloat32Array = PackedFloat32Array()


func _process(_delta: float) -> void:
	_process_visual_jobs(_waveform_cache_jobs, false)
	_process_visual_jobs(_spectrogram_jobs, true)


func _process_visual_jobs(jobs: Dictionary, spectrogram: bool) -> void:
	if jobs.is_empty():
		return
	var completed_ids: PackedInt32Array = PackedInt32Array()
	for key_value: Variant in jobs.keys():
		var clip_id: int = int(key_value)
		var job: GASClipVisualJob = jobs.get(clip_id) as GASClipVisualJob
		if job == null or not job.is_complete():
			continue
		job.collect()
		completed_ids.append(clip_id)
		if job.failed or model == null:
			continue
		var clip: GASEditorClip = model.find_clip(clip_id)
		if clip == null or clip.pcm == null or clip.pcm != job.source_pcm:
			continue
		if spectrogram:
			if clip.source_start_frame != job.source_start_frame or clip.source_end() != job.source_end_frame:
				continue
			if job.spectrogram_columns <= 0 or job.spectrogram_rows <= 0 or job.spectrogram_bytes.is_empty():
				continue
			var image: Image = Image.create_from_data(job.spectrogram_columns, job.spectrogram_rows, false, Image.FORMAT_RGBA8, job.spectrogram_bytes)
			clip.spectrogram_texture = ImageTexture.create_from_image(image)
			clip.spectrogram_source_start = job.source_start_frame
			clip.spectrogram_source_end = job.source_end_frame
		else:
			if job.cache_result == null:
				continue
			clip.cache = job.cache_result
			clip.paged_store = job.paged_store_result
			clip.paged_cache_path = job.paged_cache_path_result
	if not completed_ids.is_empty():
		for clip_id: int in completed_ids:
			jobs.erase(clip_id)
		queue_redraw()


func _request_waveform_cache(clip: GASEditorClip) -> void:
	if clip == null or clip.pcm == null or clip.cache != null or _waveform_cache_jobs.has(clip.clip_id):
		return
	var job: GASClipVisualJob = ClipVisualJob.new() as GASClipVisualJob
	if job != null and job.start_waveform_cache(clip.clip_id, clip.pcm, clip.source_path):
		_waveform_cache_jobs[clip.clip_id] = job


func _request_spectrogram(clip: GASEditorClip) -> void:
	if clip == null or clip.pcm == null or clip.get_spectrogram_texture() != null or _spectrogram_jobs.has(clip.clip_id):
		return
	var job: GASClipVisualJob = ClipVisualJob.new() as GASClipVisualJob
	if job != null and job.start_spectrogram(clip.clip_id, clip.pcm, clip.source_start_frame, clip.source_end()):
		_spectrogram_jobs[clip.clip_id] = job


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The Godot editor can disable focus recursively on ancestor controls.
	# GAS needs the waveform to own keyboard focus after a timeline click so
	# editor-level shortcuts cannot steal clip/edit commands.
	focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(420.0, 300.0)
	clip_contents = true


func set_accessibility_high_contrast(enabled: bool) -> void:
	if enabled:
		_bg = Color(0.025, 0.025, 0.03)
		_timeline_bg = Color(0.055, 0.055, 0.065)
		_track_bg_a = Color(0.035, 0.04, 0.05)
		_track_bg_b = Color(0.02, 0.025, 0.035)
		_clip_bg = Color(0.08, 0.20, 0.24, 0.95)
		_clip_selected_bg = Color(0.10, 0.34, 0.43, 1.0)
		_wave_color = Color(0.35, 1.0, 0.70)
		_wave_right_color = Color(0.30, 0.78, 1.0)
		_grid_color = Color(0.42, 0.44, 0.48, 0.78)
		_selected_border = Color(1.0, 0.80, 0.20)
	else:
		_bg = Color(0.07, 0.075, 0.088)
		_timeline_bg = Color(0.105, 0.11, 0.125)
		_track_bg_a = Color(0.09, 0.095, 0.11)
		_track_bg_b = Color(0.075, 0.08, 0.095)
		_clip_bg = Color(0.11, 0.19, 0.22, 0.86)
		_clip_selected_bg = Color(0.14, 0.29, 0.36, 0.92)
		_wave_color = Color(0.35, 0.82, 0.67)
		_wave_right_color = Color(0.33, 0.68, 0.86)
		_grid_color = Color(0.22, 0.24, 0.28, 0.65)
		_selected_border = Color(0.95, 0.76, 0.28)
	queue_redraw()


func set_model(value: GASEditorModel) -> void:
	model = value
	_waveform_cache_jobs.clear()
	_spectrogram_jobs.clear()
	_track_height_overrides = PackedFloat32Array()
	queue_redraw()


func set_track_heights(heights: PackedFloat32Array) -> void:
	_track_height_overrides = heights.duplicate()
	queue_redraw()


func set_sample_draw_mode(enabled: bool) -> void:
	sample_draw_mode = enabled
	mouse_default_cursor_shape = Control.CURSOR_CROSS if enabled else Control.CURSOR_ARROW


func set_time_base(mode: String) -> void:
	time_base_mode = mode
	queue_redraw()


func set_spectral_selection(low_hz: float, high_hz: float, active: bool = true) -> void:
	spectral_selection_low_hz = maxf(0.0, minf(low_hz, high_hz))
	spectral_selection_high_hz = maxf(spectral_selection_low_hz, maxf(low_hz, high_hz))
	spectral_selection_active = active
	queue_redraw()

func set_view(start_frame: int, spp: float) -> void:
	view_start_frame = maxi(0, start_frame)
	samples_per_pixel = clampf(spp, 0.02, 100000.0)
	queue_redraw()
	view_changed.emit(view_start_frame, samples_per_pixel)


func zoom_in(anchor_frame: int = -1) -> void:
	_zoom_by(0.5, anchor_frame)


func zoom_out(anchor_frame: int = -1) -> void:
	_zoom_by(2.0, anchor_frame)


func zoom_fit() -> void:
	if model == null or model.project_end_frame() <= 0 or size.x <= 10.0:
		return
	view_start_frame = 0
	samples_per_pixel = maxf(0.02, float(model.project_end_frame()) / maxf(1.0, size.x - 4.0))
	queue_redraw()
	view_changed.emit(view_start_frame, samples_per_pixel)


func visible_frame_count() -> int:
	return maxi(1, int(ceil(size.x * samples_per_pixel)))


func scroll_frames(delta_frames: int) -> void:
	var max_start: int = 0
	if model != null:
		max_start = maxi(0, model.project_end_frame() - visible_frame_count())
	view_start_frame = clampi(view_start_frame + delta_frames, 0, max_start)
	queue_redraw()
	view_changed.emit(view_start_frame, samples_per_pixel)


func _grab_waveform_focus() -> void:
	# get_focus_mode_with_override() includes focus_behavior_recursive from
	# ancestors. Never call grab_focus() unless Godot says this control can
	# actually receive it; this avoids Control::grab_focus warnings.
	if focus_behavior_recursive != Control.FOCUS_BEHAVIOR_ENABLED:
		focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	if focus_mode != Control.FOCUS_ALL:
		focus_mode = Control.FOCUS_ALL
	if get_focus_mode_with_override() != Control.FOCUS_NONE:
		grab_focus()


func _gui_input(event: InputEvent) -> void:
	if model == null:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_grab_waveform_focus()
			if sample_draw_mode:
				if mouse_button.pressed:
					_sample_draw_started = true
					_sample_draw_changed = false
					_sample_draw_clip_id = 0
					_sample_draw_at(mouse_button.position, true)
				else:
					_finish_sample_draw()
			elif mouse_button.pressed:
				_begin_left_press(mouse_button)
			else:
				_end_left_drag(mouse_button.position)
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT and mouse_button.pressed:
			_handle_right_press(mouse_button)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			if mouse_button.ctrl_pressed:
				_zoom_by(0.72, _frame_from_x(mouse_button.position.x))
			else:
				scroll_frames(-int(float(visible_frame_count()) * 0.12))
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			if mouse_button.ctrl_pressed:
				_zoom_by(1.38, _frame_from_x(mouse_button.position.x))
			else:
				scroll_frames(int(float(visible_frame_count()) * 0.12))
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if sample_draw_mode and _sample_draw_started and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_sample_draw_at(motion.position, not _sample_draw_changed)
		elif _drag_mode != DRAG_NONE:
			_update_drag(motion.position)
		else:
			_update_cursor_shape(motion.position)


func _sample_draw_at(position: Vector2, record_undo: bool) -> void:
	if model == null or samples_per_pixel > 2.0:
		return
	var hit: Dictionary = _hit_test_clip(position)
	if hit.is_empty():
		return
	var clip_id: int = int(hit.get("clip_id", 0))
	var track_index: int = int(hit.get("track", -1))
	var clip: GASEditorClip = model.find_clip(clip_id)
	if clip == null or clip.pcm == null or track_index < 0:
		return
	if model.tracks[track_index].reference_read_only or model.tracks[track_index].locked:
		return
	var track: GASEditorTrack = model.tracks[track_index]
	var track_y: float = _track_y(track_index)
	var rect: Rect2 = _clip_rect(clip, track_y, _track_height(track_index))
	var wave_top: float = rect.position.y + 18.0
	var wave_height: float = rect.size.y - 22.0
	if wave_height <= 4.0:
		return
	var stereo: bool = clip.pcm.is_stereo()
	var combined_stereo: bool = stereo and track.waveform_stereo_mode == GASEditorTrack.WAVEFORM_COMBINED_STEREO
	var channel_height: float = wave_height * (0.5 if stereo and not combined_stereo else 1.0)
	var channel: int = 0
	var channel_top: float = wave_top
	if stereo and position.y >= wave_top + channel_height:
		channel = 1
		channel_top += channel_height
	var mid: float = channel_top + channel_height * 0.5
	var amplitude: float = clampf((mid - position.y) / maxf(1.0, channel_height * 0.45), -1.0, 1.0)
	var global_frame: int = clampi(_frame_from_x(position.x), clip.timeline_start, clip.end_frame() - 1)
	var local_frame: int = global_frame - clip.timeline_start
	if model.sample_edit_set(clip_id, local_frame, amplitude, channel, record_undo, false):
		_sample_draw_changed = true
		_sample_draw_clip_id = clip_id
		model.select_track(track_index, false, false)
		model.select_clip(clip_id, false, false)
		queue_redraw()


func _finish_sample_draw() -> void:
	if _sample_draw_changed and _sample_draw_clip_id > 0:
		model.finalize_sample_edit(_sample_draw_clip_id)
		edit_committed.emit("Drew waveform samples")
	_sample_draw_started = false
	_sample_draw_changed = false
	_sample_draw_clip_id = 0
	queue_redraw()


func _begin_left_press(event: InputEventMouseButton) -> void:
	_drag_press_position = event.position
	_drag_press_frame = _frame_from_x(event.position.x)
	_drag_press_track = _track_from_y(event.position.y)
	_drag_started = false
	_preview_delta_frames = 0
	_preview_track_delta = 0
	_preview_trim_frame = _drag_press_frame
	var hit: Dictionary = _hit_test_clip(event.position)
	if not hit.is_empty():
		var clip_id: int = int(hit.get("clip_id", 0))
		var track_index: int = int(hit.get("track", -1))
		var edge: String = str(hit.get("edge", ""))
		model.select_track(track_index, event.ctrl_pressed, event.shift_pressed)
		track_selected.emit(track_index)
		if event.ctrl_pressed:
			model.select_clip(clip_id, true, true)
		elif event.shift_pressed:
			model.select_clip(clip_id, true, false)
		elif not model.is_clip_selected(clip_id):
			model.select_clip(clip_id, false, false)
		clip_selection_changed.emit()
		_drag_clip_id = clip_id
		if event.double_click:
			clip_rename_requested.emit(clip_id)
			_drag_mode = DRAG_NONE
			queue_redraw()
			return
		model.cursor_frame = _drag_press_frame
		model.clear_time_selection()
		cursor_changed.emit(_drag_press_frame)
		selection_changed.emit(model.selection_start, model.selection_end)
		if model.is_clip_selected(clip_id):
			if edge == "left":
				_drag_mode = DRAG_TRIM_LEFT
			elif edge == "right":
				_drag_mode = DRAG_TRIM_RIGHT
			else:
				_drag_mode = DRAG_MOVE_CLIPS
				_drag_original_locations = model.selected_clip_locations()
		queue_redraw()
		return
	if not event.ctrl_pressed and not event.shift_pressed:
		model.clear_clip_selection()
		clip_selection_changed.emit()
	if _drag_press_track >= 0:
		model.select_track(_drag_press_track, event.ctrl_pressed, event.shift_pressed)
		track_selected.emit(_drag_press_track)
	_drag_mode = DRAG_TIME_SELECTION
	_drag_anchor_frame = _drag_press_frame
	model.cursor_frame = _drag_press_frame
	model.selection_start = _drag_press_frame
	model.selection_end = _drag_press_frame
	cursor_changed.emit(_drag_press_frame)
	selection_changed.emit(_drag_press_frame, _drag_press_frame)
	queue_redraw()


func _update_drag(position: Vector2) -> void:
	if _drag_mode == DRAG_TIME_SELECTION:
		var current_frame: int = _frame_from_x(position.x)
		model.set_selection(_drag_anchor_frame, current_frame)
		selection_changed.emit(model.selection_start, model.selection_end)
		queue_redraw()
		return
	if not _drag_started and position.distance_to(_drag_press_position) < DRAG_THRESHOLD:
		return
	_drag_started = true
	if _drag_mode == DRAG_MOVE_CLIPS:
		var current_frame: int = _frame_from_x(position.x)
		_preview_delta_frames = current_frame - _drag_press_frame
		var current_track: int = _track_from_y_clamped(position.y)
		_preview_track_delta = current_track - _drag_press_track
		_preview_delta_frames = _preview_snapped_move_delta(_preview_delta_frames, _preview_track_delta)
	elif _drag_mode == DRAG_TRIM_LEFT or _drag_mode == DRAG_TRIM_RIGHT:
		var target_track: int = _track_from_y_clamped(position.y)
		var raw_frame: int = _frame_from_x(position.x)
		var tolerance: int = maxi(1, int(round(samples_per_pixel * 8.0)))
		_preview_trim_frame = model.snap_frame(raw_frame, target_track, PackedInt32Array([_drag_clip_id]), tolerance, false)
	queue_redraw()


func _end_left_drag(_position: Vector2) -> void:
	var action: String = ""
	if _drag_mode == DRAG_MOVE_CLIPS and _drag_started:
		var tolerance: int = maxi(1, int(round(samples_per_pixel * 8.0)))
		if model.move_selected_clips(_drag_original_locations, _preview_delta_frames, _preview_track_delta, true, tolerance):
			action = "Moved clips"
	elif (_drag_mode == DRAG_TRIM_LEFT or _drag_mode == DRAG_TRIM_RIGHT) and _drag_started:
		var edge: String = "left" if _drag_mode == DRAG_TRIM_LEFT else "right"
		var tolerance: int = maxi(1, int(round(samples_per_pixel * 8.0)))
		if model.trim_clip_edge(_drag_clip_id, edge, _preview_trim_frame, true, tolerance):
			action = "Trimmed clip edge"
	_reset_drag_state()
	if not action.is_empty():
		edit_committed.emit(action)
	queue_redraw()


func _handle_right_press(event: InputEventMouseButton) -> void:
	var hit: Dictionary = _hit_test_clip(event.position)
	if hit.is_empty():
		return
	var clip_id: int = int(hit.get("clip_id", 0))
	var track_index: int = int(hit.get("track", -1))
	if not model.is_clip_selected(clip_id):
		model.select_clip(clip_id, false, false)
	model.select_track(track_index, false, false)
	model.cursor_frame = _frame_from_x(event.position.x)
	clip_selection_changed.emit()
	track_selected.emit(track_index)
	cursor_changed.emit(model.cursor_frame)
	queue_redraw()
	clip_context_requested.emit(clip_id, get_screen_position() + event.position)


func _update_cursor_shape(position: Vector2) -> void:
	var hit: Dictionary = _hit_test_clip(position)
	if hit.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_IBEAM
		return
	var edge: String = str(hit.get("edge", ""))
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if not edge.is_empty() else Control.CURSOR_MOVE


func _preview_snapped_move_delta(delta_frames: int, track_delta: int) -> int:
	if model.selected_clip_ids.is_empty() or _drag_original_locations.is_empty():
		return delta_frames
	var primary_id: int = model.selected_clip_ids[0]
	if not _drag_original_locations.has(primary_id):
		return delta_frames
	var info: Dictionary = _drag_original_locations[primary_id] as Dictionary
	var clip: GASEditorClip = model.find_clip(primary_id)
	if clip == null:
		return delta_frames
	var target_track: int = clampi(int(info.get("track", 0)) + track_delta, 0, model.tracks.size() - 1)
	var candidate_start: int = maxi(0, int(info.get("start", 0)) + delta_frames)
	var tolerance: int = maxi(1, int(round(samples_per_pixel * 8.0)))
	var snapped_start: int = model.snap_frame(candidate_start, target_track, model.selected_clip_ids, tolerance, false)
	var start_adjust: int = snapped_start - candidate_start
	var candidate_end: int = candidate_start + clip.frame_count()
	var snapped_end: int = model.snap_frame(candidate_end, target_track, model.selected_clip_ids, tolerance, false)
	var end_adjust: int = snapped_end - candidate_end
	var adjust: int = start_adjust if abs(start_adjust) <= abs(end_adjust) else end_adjust
	return delta_frames + adjust


func _reset_drag_state() -> void:
	_drag_mode = DRAG_NONE
	_drag_started = false
	_drag_clip_id = 0
	_drag_original_locations.clear()
	_preview_delta_frames = 0
	_preview_track_delta = 0
	_preview_trim_frame = 0


func _zoom_by(factor: float, anchor_frame: int) -> void:
	if size.x <= 1.0:
		return
	var anchor: int = anchor_frame
	if anchor < 0:
		anchor = view_start_frame + visible_frame_count() / 2
	var old_spp: float = samples_per_pixel
	var new_spp: float = clampf(old_spp * factor, 0.02, 100000.0)
	var anchor_x: float = float(anchor - view_start_frame) / old_spp
	samples_per_pixel = new_spp
	view_start_frame = maxi(0, int(round(float(anchor) - anchor_x * new_spp)))
	queue_redraw()
	view_changed.emit(view_start_frame, samples_per_pixel)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg, true)
	_draw_timeline()
	if model == null:
		return
	for track_index: int in range(model.tracks.size()):
		_draw_track(track_index, model.tracks[track_index])
	_draw_spectral_selection()
	_draw_selection_and_cursor()
	_draw_drag_preview()


func _draw_timeline() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, TIMELINE_HEIGHT), _timeline_bg, true)
	if model == null or model.sample_rate <= 0:
		return
	var visible_seconds: float = float(visible_frame_count()) / float(model.sample_rate)
	if time_base_mode == "Beats":
		_draw_beat_timeline()
	else:
		var major_step: float = _choose_time_step(visible_seconds)
		var start_seconds: float = float(view_start_frame) / float(model.sample_rate)
		var end_seconds: float = float(view_start_frame + visible_frame_count()) / float(model.sample_rate)
		var first_tick: float = floor(start_seconds / major_step) * major_step
		var tick: float = first_tick
		while tick <= end_seconds + major_step:
			var frame: int = int(round(tick * float(model.sample_rate)))
			var x: float = _x_from_frame(frame)
			if x >= 0.0 and x <= size.x:
				draw_line(Vector2(x, 18.0), Vector2(x, size.y), _grid_color, 1.0)
				var tick_label: String = _format_time_base_label(tick, frame)
				draw_string(get_theme_default_font(), Vector2(x + 3.0, 14.0), tick_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.78, 0.8, 0.84))
			tick += major_step
	for marker: Dictionary in model.markers:
		var marker_frame: int = int(marker.get("frame", 0))
		var marker_end: int = int(marker.get("end_frame", marker_frame))
		var marker_x: float = _x_from_frame(marker_frame)
		var marker_color: Color = Color.from_string(str(marker.get("color", "d959cc")), _marker_color)
		if marker_end > marker_frame:
			var end_x: float = _x_from_frame(marker_end)
			var left_x: float = maxf(0.0, marker_x)
			var right_x: float = minf(size.x, end_x)
			if right_x > left_x:
				draw_rect(Rect2(left_x, TIMELINE_HEIGHT, right_x - left_x, maxf(0.0, size.y - TIMELINE_HEIGHT)), Color(marker_color.r, marker_color.g, marker_color.b, 0.08), true)
		if marker_x < 0.0 or marker_x > size.x:
			continue
		draw_line(Vector2(marker_x, 0.0), Vector2(marker_x, size.y), marker_color, 1.0)
		draw_string(get_theme_default_font(), Vector2(marker_x + 3.0, 27.0), str(marker.get("name", "Marker")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, marker_color)


func _draw_beat_timeline() -> void:
	if model == null:
		return
	var bpm: float = maxf(1.0, model.project_bpm)
	var beat_frames: float = float(model.sample_rate) * 60.0 / bpm
	var beats_per_bar: int = maxi(1, model.time_signature_numerator)
	var first_beat: int = maxi(0, int(floor(float(view_start_frame) / beat_frames)))
	var last_beat: int = int(ceil(float(view_start_frame + visible_frame_count()) / beat_frames)) + 1
	for beat_index: int in range(first_beat, last_beat):
		var frame: int = int(round(float(beat_index) * beat_frames))
		var x: float = _x_from_frame(frame)
		if x < 0.0 or x > size.x:
			continue
		var in_bar: int = beat_index % beats_per_bar
		var bar: int = int(beat_index / beats_per_bar) + 1
		var beat: int = in_bar + 1
		var line_color: Color = _grid_color.lightened(0.12) if in_bar == 0 else _grid_color
		draw_line(Vector2(x, 18.0), Vector2(x, size.y), line_color, 1.0)
		draw_string(get_theme_default_font(), Vector2(x + 3.0, 14.0), "%d.%d" % [bar, beat], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(0.78, 0.8, 0.84))


func _draw_track(track_index: int, track: GASEditorTrack) -> void:
	var y: float = _track_y(track_index)
	var track_height: float = _track_height(track_index)
	if y >= size.y:
		return
	var rect: Rect2 = Rect2(0.0, y, size.x, track_height - 1.0)
	var color: Color = _track_bg_a if track_index % 2 == 0 else _track_bg_b
	color = color.lerp(track.color.darkened(0.60), 0.14)
	if model.is_track_selected(track_index):
		color = color.lightened(0.05)
	draw_rect(rect, color, true)
	draw_line(Vector2(0.0, y + track_height - 1.0), Vector2(size.x, y + track_height - 1.0), _grid_color, 1.0)
	for clip: GASEditorClip in track.clips:
		if not model.is_clip_selected(clip.clip_id):
			_draw_clip(clip, y, track, track_height)
	for clip: GASEditorClip in track.clips:
		if model.is_clip_selected(clip.clip_id):
			_draw_clip(clip, y, track, track_height)


func _draw_clip(clip: GASEditorClip, track_y: float, track: GASEditorTrack, track_height: float) -> void:
	var display_mode: int = track.display_mode
	if clip.frame_count() <= 0:
		return
	var visible_start: int = view_start_frame
	var visible_end: int = view_start_frame + visible_frame_count()
	if clip.end_frame() <= visible_start or clip.timeline_start >= visible_end:
		return
	var clip_rect: Rect2 = _clip_rect(clip, track_y, track_height)
	var selected: bool = model.is_clip_selected(clip.clip_id)
	draw_rect(clip_rect, _clip_selected_bg if selected else _clip_bg, true)
	var border: Color = _selected_border if selected else Color(0.2, 0.42, 0.47)
	draw_rect(clip_rect, border, false, 2.0 if selected else 1.0)
	var display_name: String = clip.name if clip.effect_stack.is_empty() else "%s  [FX %d]" % [clip.name, clip.effect_stack.size()]
	if clip.source_missing:
		display_name += "  [MISSING SOURCE]"
	draw_string(get_theme_default_font(), Vector2(clip_rect.position.x + 5.0, clip_rect.position.y + 14.0), display_name, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, clip_rect.size.x - 38.0), 11, Color(0.85, 0.9, 0.92))
	if selected:
		draw_rect(Rect2(clip_rect.position.x, clip_rect.position.y, HANDLE_WIDTH, clip_rect.size.y), _selected_border, true)
		draw_rect(Rect2(clip_rect.end.x - HANDLE_WIDTH, clip_rect.position.y, HANDLE_WIDTH, clip_rect.size.y), _selected_border, true)
	if clip.pcm == null:
		var missing_color: Color = Color(0.72, 0.25, 0.25, 0.72)
		draw_line(clip_rect.position + Vector2(4.0, 20.0), clip_rect.end - Vector2(4.0, 4.0), missing_color, 2.0)
		draw_line(Vector2(clip_rect.end.x - 4.0, clip_rect.position.y + 20.0), Vector2(clip_rect.position.x + 4.0, clip_rect.end.y - 4.0), missing_color, 2.0)
		draw_string(get_theme_default_font(), Vector2(clip_rect.position.x + 8.0, clip_rect.position.y + 36.0), "Audio unavailable — relink source / restore .gasdata", HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, clip_rect.size.x - 16.0), 11, Color(0.95, 0.58, 0.58))
		return
	var wave_top: float = clip_rect.position.y + 18.0
	var wave_height: float = clip_rect.size.y - 22.0
	if wave_height <= 4.0:
		return
	if display_mode == GASEditorTrack.DISPLAY_SPECTROGRAM or display_mode == GASEditorTrack.DISPLAY_COMBINED:
		var spectrogram: ImageTexture = clip.get_spectrogram_texture()
		if spectrogram != null:
			draw_texture_rect(spectrogram, Rect2(clip_rect.position.x + 1.0, wave_top, maxf(1.0, clip_rect.size.x - 2.0), wave_height), false)
		else:
			_request_spectrogram(clip)
			draw_string(get_theme_default_font(), Vector2(clip_rect.position.x + 8.0, wave_top + 18.0), "Building spectrogram…", HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, clip_rect.size.x - 16.0), 10, Color(0.68, 0.72, 0.78))
	if display_mode == GASEditorTrack.DISPLAY_WAVEFORM or display_mode == GASEditorTrack.DISPLAY_COMBINED:
		if clip.cache == null:
			_request_waveform_cache(clip)
		_draw_waveform_guides(clip_rect, wave_top, wave_height, track)
		if samples_per_pixel <= 1.0:
			_draw_raw_samples(clip, clip_rect, wave_top, wave_height, track)
		else:
			_draw_cached_samples(clip, clip_rect, wave_top, wave_height, track)


func _draw_raw_samples(clip: GASEditorClip, clip_rect: Rect2, wave_top: float, wave_height: float, track: GASEditorTrack) -> void:
	var start_global: int = maxi(view_start_frame, clip.timeline_start)
	var end_global: int = mini(view_start_frame + visible_frame_count(), clip.end_frame())
	if end_global <= start_global:
		return
	var stereo: bool = clip.pcm.is_stereo()
	var combined_stereo: bool = stereo and track.waveform_stereo_mode == GASEditorTrack.WAVEFORM_COMBINED_STEREO
	var channel_height: float = wave_height * (0.5 if stereo and not combined_stereo else 1.0)
	var source_start: int = clip.source_start_frame
	var previous_left: Vector2 = Vector2.ZERO
	var previous_right: Vector2 = Vector2.ZERO
	var has_previous: bool = false
	for global_frame: int in range(start_global, end_global):
		var local: int = global_frame - clip.timeline_start
		var source_index: int = source_start + local
		var x: float = _x_from_frame(global_frame)
		if x < clip_rect.position.x or x > clip_rect.end.x:
			continue
		var left_mid: float = wave_top + channel_height * 0.5
		var left_amp: float = _display_amplitude(clip.pcm.left[source_index], track.waveform_amplitude_mode)
		var left_y: float = left_mid - left_amp * channel_height * 0.45
		var left_point: Vector2 = Vector2(x, left_y)
		if has_previous:
			draw_line(previous_left, left_point, _wave_color, 1.0)
		if samples_per_pixel <= 0.5:
			draw_circle(left_point, 2.0, _wave_color)
		if track.show_clipping and absf(clip.pcm.left[source_index]) >= 0.999:
			draw_circle(left_point, 2.6, Color(1.0, 0.25, 0.20))
		previous_left = left_point
		if stereo:
			var right_mid: float = left_mid if combined_stereo else wave_top + channel_height + channel_height * 0.5
			var right_amp: float = _display_amplitude(clip.pcm.right[source_index], track.waveform_amplitude_mode)
			var right_y: float = right_mid - right_amp * channel_height * 0.45
			var right_point: Vector2 = Vector2(x, right_y)
			if has_previous:
				draw_line(previous_right, right_point, _wave_right_color, 1.0)
			if samples_per_pixel <= 0.5:
				draw_circle(right_point, 2.0, _wave_right_color)
			if track.show_clipping and absf(clip.pcm.right[source_index]) >= 0.999:
				draw_circle(right_point, 2.6, Color(1.0, 0.25, 0.20))
			previous_right = right_point
		has_previous = true


func _draw_cached_samples(clip: GASEditorClip, clip_rect: Rect2, wave_top: float, wave_height: float, track: GASEditorTrack) -> void:
	if clip.cache == null:
		return
	var level: Dictionary = clip.cache.get_level(samples_per_pixel)
	if level.is_empty():
		return
	var block_size: int = int(level["block_size"])
	var min_left: PackedFloat32Array = level["min_left"] as PackedFloat32Array
	var max_left: PackedFloat32Array = level["max_left"] as PackedFloat32Array
	var min_right: PackedFloat32Array = level["min_right"] as PackedFloat32Array
	var max_right: PackedFloat32Array = level["max_right"] as PackedFloat32Array
	if min_left.is_empty():
		return
	var local_visible_start: int = maxi(0, view_start_frame - clip.timeline_start)
	var local_visible_end: int = mini(clip.frame_count(), view_start_frame + visible_frame_count() - clip.timeline_start)
	var source_visible_start: int = clip.source_start_frame + local_visible_start
	var source_visible_end: int = clip.source_start_frame + local_visible_end
	var first_block: int = clampi(int(source_visible_start / block_size), 0, min_left.size() - 1)
	var last_block: int = clampi(int(ceil(float(source_visible_end) / float(block_size))), first_block, min_left.size())
	var combined_stereo: bool = clip.pcm.is_stereo() and track.waveform_stereo_mode == GASEditorTrack.WAVEFORM_COMBINED_STEREO
	var channel_height: float = wave_height * (0.5 if clip.pcm.is_stereo() and not combined_stereo else 1.0)
	for block: int in range(first_block, last_block):
		var source_frame: int = block * block_size
		var local_frame: int = source_frame - clip.source_start_frame
		var global_frame: int = clip.timeline_start + local_frame
		var x: float = clampf(_x_from_frame(global_frame), clip_rect.position.x, clip_rect.end.x)
		var left_mid: float = wave_top + channel_height * 0.5
		var y1: float = left_mid - _display_amplitude(max_left[block], track.waveform_amplitude_mode) * channel_height * 0.45
		var y2: float = left_mid - _display_amplitude(min_left[block], track.waveform_amplitude_mode) * channel_height * 0.45
		draw_line(Vector2(x, y1), Vector2(x, y2), _wave_color, 1.0)
		if track.show_clipping and (absf(max_left[block]) >= 0.999 or absf(min_left[block]) >= 0.999):
			draw_line(Vector2(x, wave_top + 1.0), Vector2(x, wave_top + 7.0), Color(1.0, 0.25, 0.20), 2.0)
		if clip.pcm.is_stereo() and block < min_right.size():
			var right_mid: float = left_mid if combined_stereo else wave_top + channel_height + channel_height * 0.5
			var ry1: float = right_mid - _display_amplitude(max_right[block], track.waveform_amplitude_mode) * channel_height * 0.45
			var ry2: float = right_mid - _display_amplitude(min_right[block], track.waveform_amplitude_mode) * channel_height * 0.45
			draw_line(Vector2(x, ry1), Vector2(x, ry2), _wave_right_color, 1.0)
			if track.show_clipping and (absf(max_right[block]) >= 0.999 or absf(min_right[block]) >= 0.999):
				draw_line(Vector2(x, wave_top + wave_height - 7.0), Vector2(x, wave_top + wave_height - 1.0), Color(1.0, 0.25, 0.20), 2.0)


func _display_amplitude(value: float, amplitude_mode: int) -> float:
	if amplitude_mode != GASEditorTrack.AMPLITUDE_DB:
		return clampf(value, -1.0, 1.0)
	var sign_value: float = -1.0 if value < 0.0 else 1.0
	var magnitude: float = absf(value)
	if magnitude <= 0.000001:
		return 0.0
	var db: float = clampf(linear_to_db(magnitude), -60.0, 0.0)
	return sign_value * (1.0 - (-db / 60.0))


func _draw_waveform_guides(clip_rect: Rect2, wave_top: float, wave_height: float, track: GASEditorTrack) -> void:
	if not track.show_zero_line:
		return
	var stereo: bool = track.waveform_stereo_mode == GASEditorTrack.WAVEFORM_SPLIT_STEREO and wave_height > 12.0
	if stereo:
		draw_line(Vector2(clip_rect.position.x + 1.0, wave_top + wave_height * 0.25), Vector2(clip_rect.end.x - 1.0, wave_top + wave_height * 0.25), Color(0.50, 0.54, 0.58, 0.35), 1.0)
		draw_line(Vector2(clip_rect.position.x + 1.0, wave_top + wave_height * 0.75), Vector2(clip_rect.end.x - 1.0, wave_top + wave_height * 0.75), Color(0.50, 0.54, 0.58, 0.35), 1.0)
	else:
		draw_line(Vector2(clip_rect.position.x + 1.0, wave_top + wave_height * 0.5), Vector2(clip_rect.end.x - 1.0, wave_top + wave_height * 0.5), Color(0.50, 0.54, 0.58, 0.35), 1.0)


func _draw_spectral_selection() -> void:
	if not spectral_selection_active or model == null or not model.has_selection() or model.selected_track < 0 or model.selected_track >= model.tracks.size():
		return
	var nyquist: float = float(maxi(1, model.sample_rate)) * 0.5
	var low: float = clampf(spectral_selection_low_hz, 0.0, nyquist)
	var high: float = clampf(spectral_selection_high_hz, low, nyquist)
	if high <= low:
		return
	var track_y: float = _track_y(model.selected_track)
	var track_height: float = _track_height(model.selected_track)
	var content_top: float = track_y + 18.0
	var content_height: float = maxf(4.0, track_height - 22.0)
	var y_top: float = content_top + (1.0 - high / nyquist) * content_height
	var y_bottom: float = content_top + (1.0 - low / nyquist) * content_height
	var x1: float = _x_from_frame(model.selection_start)
	var x2: float = _x_from_frame(model.selection_end)
	var left: float = maxf(0.0, minf(x1, x2))
	var right: float = minf(size.x, maxf(x1, x2))
	if right <= left:
		return
	var rect: Rect2 = Rect2(left, y_top, right - left, maxf(2.0, y_bottom - y_top))
	draw_rect(rect, Color(0.95, 0.55, 0.15, 0.16), true)
	draw_rect(rect, Color(0.98, 0.68, 0.25, 0.90), false, 2.0)


func _draw_selection_and_cursor() -> void:
	if model == null:
		return
	if model.selection_end > model.selection_start:
		var x1: float = _x_from_frame(model.selection_start)
		var x2: float = _x_from_frame(model.selection_end)
		draw_rect(Rect2(x1, TIMELINE_HEIGHT, x2 - x1, maxf(0.0, size.y - TIMELINE_HEIGHT)), _selection_color, true)
	var cursor_x: float = _x_from_frame(model.cursor_frame)
	if cursor_x >= 0.0 and cursor_x <= size.x:
		draw_line(Vector2(cursor_x, TIMELINE_HEIGHT), Vector2(cursor_x, size.y), _cursor_color, 1.0)


func _draw_drag_preview() -> void:
	if not _drag_started or model == null:
		return
	if _drag_mode == DRAG_MOVE_CLIPS:
		for clip_id: int in model.selected_clip_ids:
			if not _drag_original_locations.has(clip_id):
				continue
			var info: Dictionary = _drag_original_locations[clip_id] as Dictionary
			var clip: GASEditorClip = model.find_clip(clip_id)
			if clip == null:
				continue
			var target_track: int = clampi(int(info.get("track", 0)) + _preview_track_delta, 0, model.tracks.size() - 1)
			var target_start: int = maxi(0, int(info.get("start", 0)) + _preview_delta_frames)
			var x1: float = _x_from_frame(target_start)
			var x2: float = _x_from_frame(target_start + clip.frame_count())
			var target_height: float = _track_height(target_track)
			var y: float = _track_y(target_track) + CLIP_MARGIN
			draw_rect(Rect2(x1, y, maxf(2.0, x2 - x1), target_height - CLIP_MARGIN * 2.0), _ghost_color, false, 2.0)
	elif _drag_mode == DRAG_TRIM_LEFT or _drag_mode == DRAG_TRIM_RIGHT:
		var x: float = _x_from_frame(_preview_trim_frame)
		draw_line(Vector2(x, TIMELINE_HEIGHT), Vector2(x, size.y), _selected_border, 2.0)


func _hit_test_clip(position: Vector2) -> Dictionary:
	var track_index: int = _track_from_y(position.y)
	if track_index < 0 or model == null:
		return {}
	var track: GASEditorTrack = model.tracks[track_index]
	for index: int in range(track.clips.size() - 1, -1, -1):
		var clip: GASEditorClip = track.clips[index]
		if clip.frame_count() <= 0:
			continue
		var rect: Rect2 = _clip_rect(clip, _track_y(track_index), _track_height(track_index))
		if not rect.has_point(position):
			continue
		var edge: String = ""
		if absf(position.x - rect.position.x) <= HANDLE_WIDTH + 2.0:
			edge = "left"
		elif absf(position.x - rect.end.x) <= HANDLE_WIDTH + 2.0:
			edge = "right"
		return {"clip_id": clip.clip_id, "track": track_index, "edge": edge}
	return {}


func _clip_rect(clip: GASEditorClip, track_y: float, track_height: float) -> Rect2:
	var clip_x1: float = _x_from_frame(clip.timeline_start)
	var clip_x2: float = _x_from_frame(clip.end_frame())
	return Rect2(clip_x1, track_y + CLIP_MARGIN, maxf(2.0, clip_x2 - clip_x1), maxf(8.0, track_height - CLIP_MARGIN * 2.0))



func _frame_from_x(x: float) -> int:
	return maxi(0, view_start_frame + int(round(x * samples_per_pixel)))


func _x_from_frame(frame: int) -> float:
	return float(frame - view_start_frame) / samples_per_pixel


func _track_height(track_index: int) -> float:
	if model == null or track_index < 0 or track_index >= model.tracks.size():
		return TRACK_HEIGHT
	if track_index < _track_height_overrides.size():
		var override_height: float = _track_height_overrides[track_index]
		if override_height > 0.0:
			return override_height
	return COLLAPSED_TRACK_HEIGHT if model.tracks[track_index].collapsed else TRACK_HEIGHT


func _track_y(track_index: int) -> float:
	var y: float = TIMELINE_HEIGHT
	if model == null:
		return y
	for index: int in range(clampi(track_index, 0, model.tracks.size())):
		y += _track_height(index)
	return y


func content_height() -> float:
	var total: float = TIMELINE_HEIGHT
	if model != null:
		for index: int in range(model.tracks.size()):
			total += _track_height(index)
	return total


func ensure_frame_visible(frame: int) -> void:
	var visible: int = visible_frame_count()
	if frame < view_start_frame:
		set_view(maxi(0, frame - int(float(visible) * 0.1)), samples_per_pixel)
	elif frame >= view_start_frame + visible:
		set_view(maxi(0, frame - int(float(visible) * 0.9)), samples_per_pixel)


func _track_from_y(y: float) -> int:
	if y < TIMELINE_HEIGHT or model == null:
		return -1
	var current_y: float = TIMELINE_HEIGHT
	for index: int in range(model.tracks.size()):
		var height: float = _track_height(index)
		if y >= current_y and y < current_y + height:
			return index
		current_y += height
	return -1


func _track_from_y_clamped(y: float) -> int:
	if model == null or model.tracks.is_empty():
		return -1
	var exact: int = _track_from_y(y)
	if exact >= 0:
		return exact
	return 0 if y < TIMELINE_HEIGHT else model.tracks.size() - 1


func _choose_time_step(visible_seconds: float) -> float:
	if visible_seconds <= 0.1:
		return 0.01
	if visible_seconds <= 0.5:
		return 0.05
	if visible_seconds <= 2.0:
		return 0.1
	if visible_seconds <= 5.0:
		return 0.5
	if visible_seconds <= 20.0:
		return 1.0
	if visible_seconds <= 60.0:
		return 5.0
	if visible_seconds <= 300.0:
		return 15.0
	if visible_seconds <= 900.0:
		return 60.0
	return 300.0


func _format_time_base_label(seconds: float, sample_frame: int) -> String:
	match time_base_mode:
		"Milliseconds":
			return "%d ms" % int(round(seconds * 1000.0))
		"Samples":
			return str(sample_frame)
		"Frames":
			var fps: float = maxf(1.0, model.frame_rate if model != null else 30.0)
			return "%df" % int(round(seconds * fps))
		_:
			return _format_time(seconds)


func _format_time(seconds: float) -> String:
	if seconds < 60.0:
		return "%.2f" % seconds
	var total_seconds: int = int(floor(seconds))
	var minutes: int = int(total_seconds / 60)
	var secs: int = total_seconds % 60
	return "%d:%02d" % [minutes, secs]


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _track_from_y(at_position.y) < 0:
		return false
	if data is Dictionary:
		var dictionary: Dictionary = data as Dictionary
		if str(dictionary.get("type", "")) == "gas_generated_audio" and dictionary.get("wav") is AudioStreamWAV:
			return true
	var paths: PackedStringArray = _extract_drop_files(data)
	for path: String in paths:
		if path.get_extension().to_lower() == "wav":
			return true
	return false


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var track_index: int = _track_from_y(at_position.y)
	var frame: int = _frame_from_x(at_position.x)
	if data is Dictionary:
		var dictionary: Dictionary = data as Dictionary
		if str(dictionary.get("type", "")) == "gas_generated_audio":
			var wav_value: Variant = dictionary.get("wav")
			if wav_value is AudioStreamWAV:
				generated_audio_dropped.emit(wav_value as AudioStreamWAV, str(dictionary.get("name", "Generated")), frame, track_index)
				return
	var paths: PackedStringArray = _extract_drop_files(data)
	var wav_paths: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if path.get_extension().to_lower() == "wav":
			wav_paths.append(path)
	if wav_paths.is_empty():
		return
	files_dropped.emit(wav_paths, frame, track_index)


func _extract_drop_files(data: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not (data is Dictionary):
		return result
	var dictionary: Dictionary = data as Dictionary
	if not dictionary.has("files"):
		return result
	var files_value: Variant = dictionary["files"]
	if files_value is PackedStringArray:
		return PackedStringArray(files_value)
	if files_value is Array:
		var files_array: Array = files_value as Array
		for item: Variant in files_array:
			result.append(str(item))
	return result
