@tool
class_name GASAudioEditorWorkspace
extends Control

const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const CompressedAudioDecoder := preload("res://addons/gator_audio_studio/audio/compressed_audio_decoder.gd")
const CompressedDecodeSession := preload("res://addons/gator_audio_studio/audio/compressed_decode_session.gd")
const EditorModel := preload("res://addons/gator_audio_studio/audio/editor_model.gd")
const EditorTrack := preload("res://addons/gator_audio_studio/audio/editor_track.gd")
const WaveformView := preload("res://addons/gator_audio_studio/ui/audio_editor_waveform.gd")
const AudioDragItem := preload("res://addons/gator_audio_studio/ui/audio_drag_item.gd")
const EffectEngine := preload("res://addons/gator_audio_studio/audio/effect_engine.gd")
const EffectData := preload("res://addons/gator_audio_studio/audio/effect_data.gd")
const RecorderController := preload("res://addons/gator_audio_studio/audio/recorder_controller.gd")
const RecordingPanel := preload("res://addons/gator_audio_studio/ui/recording_panel.gd")
const MixerPanel := preload("res://addons/gator_audio_studio/ui/mixer_panel.gd")
const AnalyzerPanel := preload("res://addons/gator_audio_studio/ui/analyzer_panel.gd")
const ProjectPersistence := preload("res://addons/gator_audio_studio/audio/project_persistence.gd")
const ADVANCED_TOOLS_SCRIPT_PATH: String = "res://addons/gator_audio_studio/ui/advanced_tools_panel.gd"
const TrackDragPanel := preload("res://addons/gator_audio_studio/ui/track_drag_panel.gd")
const AutomationEngine := preload("res://addons/gator_audio_studio/audio/automation_engine.gd")
const EffectPresetStore := preload("res://addons/gator_audio_studio/audio/effect_preset_store.gd")
const PlaybackStreamer := preload("res://addons/gator_audio_studio/audio/playback_streamer.gd")
const PlaybackPrepareJob := preload("res://addons/gator_audio_studio/audio/playback_prepare_job.gd")
const PlaybackPrefetcher := preload("res://addons/gator_audio_studio/audio/playback_prefetcher.gd")
const RenderJob := preload("res://addons/gator_audio_studio/audio/render_job.gd")
const ProjectIOJob := preload("res://addons/gator_audio_studio/audio/project_io_job.gd")
const EditorActionJob := preload("res://addons/gator_audio_studio/audio/editor_action_job.gd")
const BusPreviewJob := preload("res://addons/gator_audio_studio/audio/bus_preview_job.gd")
const PCMIOJob := preload("res://addons/gator_audio_studio/audio/pcm_io_job.gd")
const ExtensionManager: GDScript = preload("res://addons/gator_audio_studio/audio/extension_manager.gd")

const MENU_FILE_NEW_PROJECT: int = 1
const MENU_FILE_OPEN_PROJECT: int = 2
const MENU_FILE_SAVE_PROJECT: int = 3
const MENU_FILE_SAVE_AS: int = 4
const MENU_FILE_IMPORT_WAV: int = 5
const MENU_FILE_RELINK: int = 6
const MENU_FILE_PROJECT_SETTINGS: int = 7
const MENU_FILE_RECOVER_AUTOSAVE: int = 8
const MENU_FILE_EXPORT: int = 9
const MENU_EDIT_UNDO: int = 10
const MENU_EDIT_REDO: int = 11
const MENU_EDIT_CUT: int = 12
const MENU_EDIT_COPY: int = 13
const MENU_EDIT_PASTE: int = 14
const MENU_EDIT_DELETE: int = 15
const MENU_EDIT_DUPLICATE_CLIPS: int = 16
const MENU_EDIT_SPLIT_DELETE: int = 17
const MENU_EDIT_SPLIT_CUT: int = 18
const MENU_EDIT_JOIN_CLIPS: int = 19
const MENU_EDIT_SPLIT_SELECTION: int = 23
const MENU_SELECT_ZERO: int = 20
const MENU_SELECT_ALL: int = 21
const MENU_SELECT_ZERO_PREVIOUS: int = 45
const MENU_SELECT_ZERO_NEXT: int = 46
const MENU_SELECT_ZERO_ENDPOINTS: int = 47
const MENU_TRACK_ADD: int = 30
const MENU_TRACK_REMOVE: int = 31
const MENU_TRACK_SEPARATE_CLIPS: int = 32
const MENU_SELECT_ADD_MARKER: int = 22
const MENU_EFFECT_RACK: int = 2000
const MENU_EFFECT_BASE: int = 2100
const MENU_ANALYZE_PANEL: int = 3000
const MENU_ANALYZE_SPECTRUM: int = 3001
const MENU_ANALYZE_SPECTROGRAM: int = 3002
const MENU_ANALYZE_BEATS: int = 3003
const MENU_ANALYZE_SPECTRAL_EDIT: int = 3004
const MENU_EDIT_SAMPLE_ZERO: int = 24
const MENU_EDIT_SAMPLE_INTERPOLATE: int = 25
const MENU_EDIT_SAMPLE_SMOOTH: int = 26
const MENU_EDIT_SAMPLE_REPAIR: int = 27
const MENU_TRACK_ADD_LABEL: int = 33
const MENU_TRACK_ADD_AUTOMATION: int = 34
const MENU_TRACK_ADD_GENERATED: int = 35
const MENU_TRACK_ADD_REFERENCE: int = 36
const MENU_TRACK_DUPLICATE: int = 37
const MENU_TRACK_UP: int = 38
const MENU_TRACK_DOWN: int = 39
const MENU_TRACK_SORT: int = 40
const MENU_TRACK_MERGE_DOWN: int = 41
const MENU_TRACK_RENDER_NEW: int = 42
const MENU_TRACK_MIX_MONO: int = 43
const MENU_TRACK_MIX_STEREO: int = 44
const MENU_TOOLS_AUTOMATION: int = 4000
const MENU_TOOLS_LABELS: int = 4001
const MENU_TOOLS_LOOP: int = 4002
const MENU_TOOLS_EXPORT: int = 4003
const MENU_TOOLS_MACROS: int = 4004
const MENU_TOOLS_OPTIMIZE: int = 4005
const MENU_TOOLS_HISTORY: int = 4006
const MENU_TOOLS_COMPARE: int = 4007
const MENU_TOOLS_METADATA: int = 4008
const MENU_TOOLS_GAME_PREVIEW: int = 4009
const MENU_TOOLS_PROJECT_AUDIO: int = 4010
const MENU_HELP_GUIDE: int = 5000
const MENU_HELP_DONATE: int = 5001
const SUPPORT_URL: String = "https://ko-fi.com/blackwatergatorstudios"
const MENU_VIEW_SHORTCUTS: int = 6000

const CTX_RENAME: int = 1001
const CTX_DUPLICATE: int = 1002
const CTX_CUT: int = 1003
const CTX_COPY: int = 1004
const CTX_DELETE: int = 1005
const CTX_SPLIT: int = 1006
const CTX_JOIN: int = 1007
const CTX_SEPARATE: int = 1008
const CTX_SPLIT_DELETE: int = 1009
const CTX_SPLIT_CUT: int = 1010
const CTX_ADD_MARKER: int = 1011
const CTX_EFFECTS: int = 1012
const CTX_SILENCE: int = 1013
const CTX_TRIM: int = 1014
const CTX_NORMALIZE: int = 1015
const CTX_FADE_IN: int = 1016
const CTX_FADE_OUT: int = 1017
const CTX_CROSSFADE: int = 1018
const CTX_REVERSE: int = 1019
const CTX_GENERATE: int = 1020
const CTX_ANALYZE: int = 1021
const CTX_EXPORT_SELECTION: int = 1022

const DEFAULT_SHORTCUTS: Dictionary = {
	"new_project": "Ctrl+N",
	"open_project": "Ctrl+O",
	"save_project": "Ctrl+S",
	"save_as": "Ctrl+Shift+S",
	"undo": "Ctrl+Z",
	"redo": "Ctrl+Y",
	"cut": "Ctrl+X",
	"copy": "Ctrl+C",
	"paste": "Ctrl+V",
	"duplicate": "Ctrl+D",
	"play_stop": "Space",
	"record": "R",
	"delete": "Delete",
	"split": "S",
	"loop": "L",
	"project_start": "Home",
	"project_end": "End",
	"zoom_in": "Equal",
	"zoom_out": "Minus",
}

var _model: GASEditorModel
var _waveform: GASAudioEditorWaveform
var _player: AudioStreamPlayer
var _track_list: VBoxContainer
var _track_panels: Array[Control] = []
var _track_layout_sync_queued: bool = false
var _left_scroll: ScrollContainer
var _wave_scroll: ScrollContainer
var _horizontal_scroll: HScrollBar
var _status: Label
var _selection_start_label: Label
var _selection_end_label: Label
var _selection_length_label: Label
var _selection_start_sample_label: Label
var _selection_end_sample_label: Label
var _frequency_range_label: Label
var _cursor_label: Label
var _format_label: Label
var _open_dialog: FileDialog
var _export_dialog: FileDialog
var _project_open_dialog: FileDialog
var _project_save_dialog: FileDialog
var _relink_dialog: FileDialog
var _missing_folder_dialog: FileDialog
var _missing_sources_dialog: AcceptDialog
var _missing_sources_list: ItemList
var _recovery_dialog: ConfirmationDialog
var _project_settings_dialog: ConfirmationDialog
var _help_dialog: AcceptDialog
var _project_name_edit: LineEdit
var _autosave_toggle: CheckButton
var _autosave_interval_spin: SpinBox
var _time_sig_num_spin: SpinBox
var _time_sig_den_spin: SpinBox
var _frame_rate_spin: SpinBox
var _ui_scale_spin: SpinBox
var _high_contrast_toggle: CheckButton
var _strong_focus_toggle: CheckButton
var _meter_text_toggle: CheckButton
var _shortcut_dialog: ConfirmationDialog
var _shortcut_edits: Dictionary = {}
var _unsaved_dialog: ConfirmationDialog
var _clip_context_menu: PopupMenu
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _context_clip_id: int = 0
var _generated_bin: HFlowContainer
var _generated_bin_entries: Array[Dictionary] = []
var _play_selection_end_frame: int = -1
var _play_loop_start_frame: int = -1
var _transport_loop_enabled: bool = false
var _spectral_low_hz: float = 0.0
var _spectral_high_hz: float = 0.0
var _syncing_scroll: bool = false
var _effects_panel: PanelContainer
var _effect_target_option: OptionButton
var _effect_type_option: OptionButton
var _effect_preset_option: OptionButton
var _effect_wet_slider: HSlider
var _effect_enabled_check: CheckButton
var _effect_parameter_grid: GridContainer
var _effect_parameter_controls: Dictionary = {}
var _effect_mode_option: OptionButton
var _effect_type_tokens: PackedStringArray = PackedStringArray()
var _effect_menu_popup: PopupMenu
var _extension_revision: int = -1
var _extensions_dialog: AcceptDialog
var _extensions_list: VBoxContainer
var _extensions_summary: Label
var _rack_list: ItemList
var _current_effect: GASEffectData
var _selected_rack_index: int = -1
var _effect_stack_clipboard: Array[GASEffectData] = []
var _effect_preset_entries: Array[Dictionary] = []
var _effect_preset_dialog: ConfirmationDialog
var _effect_preset_name_edit: LineEdit
var _effect_preset_save_scope: String = "User"
var _recording_panel: GASRecordingPanel
var _mixer_panel: GASMixerPanel
var _analyzer_panel: GASAnalyzerPanel
var _advanced_tools: Control
var _ui_root: VBoxContainer
var _sample_draw_toggle: CheckButton
var _scrub_toggle: CheckButton
var _loop_toggle: CheckButton
var _playback_speed_spin: SpinBox
var _bpm_spin: SpinBox
var _time_base_option: OptionButton
var _snap_option: OptionButton
var _scrub_enabled: bool = false
var _time_base_mode: String = "Seconds"
var _recorder: GASRecorderController
var _monitor_player: AudioStreamPlayer
var _record_pending: bool = false
var _record_countdown_end_ms: int = 0
var _record_device_name: String = "Default"
var _record_stereo: bool = false
var _record_mode: int = 0
var _record_timer_seconds: float = 0.0
var _record_compensation_ms: float = 0.0
var _record_start_frame: int = 0
var _record_target_track: int = -1
var _record_punch_end_frame: int = -1
var _record_monitor: bool = false
var _recording_serial: int = 1
var _bus_players: Array[AudioStreamPlayer] = []
var _bus_send_players: Array[AudioStreamPlayer] = []
var _bus_send_track_indices: PackedInt32Array = PackedInt32Array()
var _bus_preview_job: GASBusPreviewJob
var _temporary_bus_names: PackedStringArray = PackedStringArray()
var _compressed_decode_session: GASCompressedDecodeSession
var _compressed_decode_path: String = ""
var _compressed_decode_status_elapsed: float = 0.0
var _play_prepare_job: GASPlaybackPrepareJob
var _play_prepare_mutex: Mutex = Mutex.new()
var _play_prepare_result: Dictionary = {}
var _play_prepare_start_frame: int = 0
var _play_prepare_end_frame: int = -1
var _play_prepare_revision: int = 0
var _play_prepare_discard: bool = false
var _prepared_playback_revision: int = -1
var _audio_revision: int = 0
var _stream_generator: AudioStreamGenerator
var _stream_playback: AudioStreamGeneratorPlayback
var _stream_mixer: GASPlaybackStreamer
var _stream_prefetcher: GASPlaybackPrefetcher
var _streaming_playback: bool = false
var _stream_origin_frame: int = 0
var _stream_feed_finished: bool = false
var _stream_last_skip_count: int = 0
var _native_source_playback: bool = false
var _native_source_origin_frame: int = 0
var _native_source_seek_seconds: float = 0.0
var _native_source_previous_bus: StringName = &"Master"
const NATIVE_PREVIEW_BUS: String = "__GAS Native Preview"
const BACKGROUND_PLAYBACK_RENDER_SECONDS: float = 12.0
const STREAM_BUFFER_SECONDS: float = 12.0
const STREAM_INITIAL_PREFILL_FRAMES: int = 4096
var _meter_elapsed: float = 0.0
var _calibration_player: AudioStreamPlayer
var _calibration_active: bool = false
var _calibration_stop_ms: int = 0
var _current_project_path: String = ""
var _project_name: String = "Untitled"
var _autosave_enabled: bool = true
var _autosave_interval_seconds: float = 60.0
var _autosave_elapsed: float = 0.0
var _project_state_revision: int = 0
var _last_autosave_model_revision: int = -1
var _last_autosave_project_state_revision: int = -1
var _project_state_dirty: bool = false:
	set(value):
		if value:
			_project_state_revision += 1
		_project_state_dirty = value
var _last_export_path: String = ""
var _export_job: GASAudioRenderJob
var _export_job_last_progress_percent: int = -1
var _pending_editor_imports: PackedStringArray = PackedStringArray()
var _editor_import_flush_queued: bool = false
var _editor_import_in_progress: bool = false
var _editor_import_wait_frames: int = 0
var _project_io_job: GASProjectIOJob
var _editor_action_job: GASEditorActionJob
var _editor_action_status: String = ""
var _pcm_io_job: GASPCMIOJob
var _pcm_io_purpose: String = ""
var _pcm_io_context: Dictionary = {}
var _missing_sources: Array[Dictionary] = []
var _offline_clip_count: int = 0
var _relink_source_path: String = ""
var _pending_project_action: String = ""
var _pending_project_path: String = ""
var _save_then_continue: bool = false
var _recovery_autosave_path: String = ""
var _generator_state_getter: Callable
var _generator_state_setter: Callable
var _workspace_state_getter: Callable
var _workspace_state_setter: Callable
var _cached_generator_project_state: Dictionary = {}
var _cached_workspace_project_state: Dictionary = {}
const CALIBRATION_LEAD_SECONDS: float = 0.10
const CALIBRATION_CAPTURE_SECONDS: float = 1.25


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_model = GASEditorModel.new()
	_recorder = RecorderController.new()
	_build_ui()
	set_process(true)
	_refresh_all()
	call_deferred("_check_for_recovery")


func set_project_state_bridge(generator_getter: Callable, generator_setter: Callable, workspace_getter: Callable, workspace_setter: Callable) -> void:
	_generator_state_getter = generator_getter
	_generator_state_setter = generator_setter
	_workspace_state_getter = workspace_getter
	_workspace_state_setter = workspace_setter
	_cached_generator_project_state = _get_generator_project_state()
	_cached_workspace_project_state = _get_workspace_project_state()


func mark_project_settings_dirty() -> void:
	_project_state_dirty = true
	if _format_label != null:
		_update_selection_status()
	if _generator_state_getter.is_valid():
		var state_value: Variant = _generator_state_getter.call()
		if state_value is Dictionary:
			_cached_generator_project_state = (state_value as Dictionary).duplicate(true)


func add_generated_wav(wav: AudioStreamWAV, suggested_name: String, generator_state: Dictionary = {}) -> void:
	_add_generated_bin_entry(wav, suggested_name)
	var pcm: GASPCMData = PCMData.from_wav(wav)
	if pcm == null:
		_status.text = "Generated audio could not be converted to editable PCM."
		return
	if not _model.tracks.is_empty() and pcm.sample_rate != _model.sample_rate:
		pcm = pcm.resample_to_rate(_model.sample_rate)
	var target_track: int = -1
	if _model.selected_track >= 0 and _model.selected_track < _model.tracks.size():
		var selected: GASEditorTrack = _model.tracks[_model.selected_track]
		if selected.track_type == GASEditorTrack.TYPE_GENERATED and _model.is_track_editable(_model.selected_track):
			target_track = _model.add_pcm_to_track(pcm, suggested_name, "generated://" + suggested_name, _model.selected_track, _model.cursor_frame)
	if target_track < 0:
		target_track = _model.add_pcm_as_new_track_at(pcm, suggested_name, "generated://" + suggested_name, _model.cursor_frame, "Send Generated Audio")
	if target_track >= 0 and target_track < _model.tracks.size():
		var generated_track: GASEditorTrack = _model.tracks[target_track]
		generated_track.track_type = GASEditorTrack.TYPE_GENERATED
		generated_track.reference_read_only = false
		generated_track.generated_settings = generator_state.duplicate(true)
		_model.dirty = true
	_invalidate_audio()
	_refresh_all()
	_waveform.zoom_fit()
	_status.text = "Added generated sound: %s. Generator parameters are retained on the Generated track, and the sound remains in Generated Bin for drag/drop." % suggested_name


func _exit_tree() -> void:
	# Never synchronously wait on song-length save/export jobs during plugin disable.
	# Worker jobs are RefCounted and keep themselves alive until their Callable exits.
	if _model != null and (_model.dirty or _project_state_dirty) and _autosave_enabled and not _autosave_checkpoint_current():
		_start_detached_exit_autosave()
	if _compressed_decode_session != null and not _compressed_decode_session.finished:
		_compressed_decode_session.cancel()
	if _streaming_playback or _native_source_playback:
		_player.stop()
		_reset_streaming_state(false)
	# The legacy playback-prepare fallback still owns this workspace Callable. It is
	# normally bypassed by streaming; mark its result disposable before teardown.
	_play_prepare_discard = true
	_play_prepare_job = null
	_export_job = null
	_project_io_job = null
	_bus_preview_job = null
	_pcm_io_job = null
	_clear_bus_players()
	if _monitor_player != null:
		_monitor_player.stop()
	if _calibration_player != null:
		_calibration_player.stop()
	if _recorder != null:
		if _recorder.recording:
			_recorder.cancel_recording()
		else:
			_recorder.deactivate()
	_remove_temporary_buses()


func _start_detached_exit_autosave() -> void:
	if _model == null:
		return
	var autosave_path: String = ProjectPersistence.autosave_path(_current_project_path)
	var job: GASProjectIOJob = ProjectIOJob.new() as GASProjectIOJob
	if job == null:
		return
	job.start_save(
		autosave_path,
		_model.create_persistence_snapshot(),
		_project_settings_state(),
		_editor_project_state(),
		_get_generator_project_state(),
		_get_workspace_project_state(),
		_current_project_path,
		true,
		_project_name,
		_model.change_revision,
		_project_state_revision
	)


func _process(delta: float) -> void:
	if _extension_revision != ExtensionManager.revision():
		_extension_revision = ExtensionManager.revision()
		_refresh_extension_integrations()
	_process_editor_import_queue()
	_process_project_io_job()
	_process_editor_action_job()
	_process_bus_preview_job()
	_process_pcm_io_job()
	# A dependent editor panel can fail to instantiate during tool-script reload.
	# Avoid cascading per-frame Nil errors while Godot reports the actual compile error.
	if _model == null or _player == null:
		return
	_process_compressed_decode(delta)
	_process_playback_prepare()
	_process_streaming_playback()
	_process_export_job()
	if _autosave_enabled and (_model.dirty or _project_state_dirty) and not _record_pending and (_recorder == null or not _recorder.recording):
		_autosave_elapsed += delta
		if _autosave_elapsed >= _autosave_interval_seconds:
			_autosave_elapsed = 0.0
			_perform_autosave(false)
	else:
		_autosave_elapsed = minf(_autosave_elapsed, _autosave_interval_seconds)
	if _recorder != null and _recorder.input_active:
		_recorder.poll()
		if _recording_panel != null:
			_recording_panel.update_input_meter(_recorder.peak_left, _recorder.peak_right, _recorder.rms_left, _recorder.rms_right, _recorder.clipping)
			if _recorder.recording:
				_recording_panel.update_record_time(_recorder.duration_seconds())
	if _record_pending and Time.get_ticks_msec() >= _record_countdown_end_ms:
		_record_pending = false
		_begin_recording_now()
	elif _record_pending and _recording_panel != null:
		var remain_ms: int = maxi(0, _record_countdown_end_ms - Time.get_ticks_msec())
		_recording_panel.set_status("Recording starts in %.1f s" % (float(remain_ms) * 0.001))
	if _recorder != null and _recorder.recording and not _calibration_active:
		var automatic_limit: float = _record_timer_seconds
		if _record_mode == GASRecordingPanel.RecordMode.PUNCH_SELECTION and _record_punch_end_frame > _record_start_frame:
			automatic_limit = float(_record_punch_end_frame - _record_start_frame) / float(maxi(1, _model.sample_rate))
		if automatic_limit > 0.0 and _recorder.duration_seconds() >= automatic_limit:
			_finish_recording()
	if _calibration_active and Time.get_ticks_msec() >= _calibration_stop_ms:
		_finish_latency_calibration()
	if _player.playing and _play_selection_end_frame >= 0 and _model.sample_rate > 0:
		var current_frame: int = _current_playback_frame()
		if current_frame >= _play_selection_end_frame:
			if _transport_loop_enabled and _play_loop_start_frame >= 0 and _play_selection_end_frame > _play_loop_start_frame:
				_start_playback(_play_loop_start_frame, _play_selection_end_frame)
				_model.cursor_frame = _play_loop_start_frame
			else:
				_on_stop()
				_model.cursor_frame = mini(current_frame, _model.project_end_frame())
			_waveform.queue_redraw()
			_update_selection_status()
	_meter_elapsed += delta
	if _meter_elapsed >= 0.09:
		_meter_elapsed = 0.0
		_update_mixer_meters()
		_update_send_automation()
	if _analyzer_panel != null and _analyzer_panel.is_live_enabled() and _player.playing:
		# Build only a tiny bounded window around the playhead. The analyzer then
		# performs its FFT on a worker. Live analysis never requests a full mixdown.
		var analyzer_frame: int = _current_playback_frame()
		var live_window: GASPCMData = _build_live_analysis_window(analyzer_frame, 2048)
		if live_window != null:
			_analyzer_panel.update_realtime(live_window, live_window.frame_count() / 2, delta)


func _build_ui() -> void:
	_ui_root = VBoxContainer.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_theme_constant_override("separation", 4)
	add_child(_ui_root)
	var root: VBoxContainer = _ui_root

	var menu_bar: HBoxContainer = HBoxContainer.new()
	menu_bar.custom_minimum_size.y = 28.0
	root.add_child(menu_bar)
	_build_menu(menu_bar, "File", [["New Project", MENU_FILE_NEW_PROJECT], ["Open Project...", MENU_FILE_OPEN_PROJECT], ["Save Project", MENU_FILE_SAVE_PROJECT], ["Save Project As...", MENU_FILE_SAVE_AS], ["Import Audio...", MENU_FILE_IMPORT_WAV], ["Relink Missing Sources...", MENU_FILE_RELINK], ["Project Settings...", MENU_FILE_PROJECT_SETTINGS], ["Recover Autosave...", MENU_FILE_RECOVER_AUTOSAVE], ["Export Mixdown WAV...", MENU_FILE_EXPORT]], _on_file_menu)
	_build_menu(menu_bar, "Edit", [["Undo", MENU_EDIT_UNDO], ["Redo", MENU_EDIT_REDO], ["Cut", MENU_EDIT_CUT], ["Copy", MENU_EDIT_COPY], ["Paste", MENU_EDIT_PASTE], ["Delete", MENU_EDIT_DELETE], ["Duplicate Clips", MENU_EDIT_DUPLICATE_CLIPS], ["Split Delete", MENU_EDIT_SPLIT_DELETE], ["Split Cut", MENU_EDIT_SPLIT_CUT], ["Join Selected Clips", MENU_EDIT_JOIN_CLIPS], ["Split Clips at Selection Boundaries", MENU_EDIT_SPLIT_SELECTION], ["Sample: Zero Selection", MENU_EDIT_SAMPLE_ZERO], ["Sample: Interpolate Selection", MENU_EDIT_SAMPLE_INTERPOLATE], ["Sample: Smooth Selection", MENU_EDIT_SAMPLE_SMOOTH], ["Sample: Repair Selection", MENU_EDIT_SAMPLE_REPAIR]], _on_edit_menu)
	_build_menu(menu_bar, "Select", [["All", MENU_SELECT_ALL], ["Nearest Zero Crossing", MENU_SELECT_ZERO], ["Previous Zero Crossing", MENU_SELECT_ZERO_PREVIOUS], ["Next Zero Crossing", MENU_SELECT_ZERO_NEXT], ["Snap Selection Endpoints to Zero Crossings", MENU_SELECT_ZERO_ENDPOINTS], ["Add Marker at Cursor", MENU_SELECT_ADD_MARKER]], _on_select_menu)
	_build_menu(menu_bar, "Track", [["Add Audio Track", MENU_TRACK_ADD], ["Add Label Track", MENU_TRACK_ADD_LABEL], ["Add Automation Track", MENU_TRACK_ADD_AUTOMATION], ["Add Generated Track", MENU_TRACK_ADD_GENERATED], ["Add Reference Track", MENU_TRACK_ADD_REFERENCE], ["Duplicate Track", MENU_TRACK_DUPLICATE], ["Move Track Up", MENU_TRACK_UP], ["Move Track Down", MENU_TRACK_DOWN], ["Sort Tracks by Name", MENU_TRACK_SORT], ["Merge Selected Track Down", MENU_TRACK_MERGE_DOWN], ["Mix Selected Track to Mono", MENU_TRACK_MIX_MONO], ["Mix Selected Track to Stereo", MENU_TRACK_MIX_STEREO], ["Render Selected Track to New Track", MENU_TRACK_RENDER_NEW], ["Remove Selected Track", MENU_TRACK_REMOVE], ["Separate Selected Clips to New Tracks", MENU_TRACK_SEPARATE_CLIPS]], _on_track_menu)
	_build_menu(menu_bar, "Generate", [["Use Generator tab for procedural audio", 100]], _on_placeholder_menu)
	_build_effect_menu(menu_bar)
	_build_menu(menu_bar, "Analyze", [["Analyzer...", MENU_ANALYZE_PANEL], ["Plot Spectrum", MENU_ANALYZE_SPECTRUM], ["Spectrogram", MENU_ANALYZE_SPECTROGRAM], ["Detect Beats / Tempo", MENU_ANALYZE_BEATS], ["Spectral Editing...", MENU_ANALYZE_SPECTRAL_EDIT]], _on_analyze_menu)
	_build_menu(menu_bar, "Tools", [["Automation...", MENU_TOOLS_AUTOMATION], ["Labels & Regions...", MENU_TOOLS_LABELS], ["Loop Editor...", MENU_TOOLS_LOOP], ["Export...", MENU_TOOLS_EXPORT], ["Macros & Batch...", MENU_TOOLS_MACROS], ["Game Optimization...", MENU_TOOLS_OPTIMIZE], ["History...", MENU_TOOLS_HISTORY], ["A/B Compare...", MENU_TOOLS_COMPARE], ["Metadata...", MENU_TOOLS_METADATA], ["Project Audio Browser...", MENU_TOOLS_PROJECT_AUDIO], ["Game Audio Preview...", MENU_TOOLS_GAME_PREVIEW]], _on_tools_menu)
	_build_menu(menu_bar, "View", [["Shortcut Settings...", MENU_VIEW_SHORTCUTS]], _on_view_menu)
	_build_menu(menu_bar, "Help", [["Audio Editor Guide & Shortcuts", MENU_HELP_GUIDE], ["Donate / Support...", MENU_HELP_DONATE]], _on_help_menu)

	var transport: HFlowContainer = HFlowContainer.new()
	transport.add_theme_constant_override("h_separation", 4)
	transport.add_theme_constant_override("v_separation", 4)
	root.add_child(transport)
	_add_button(transport, "|<", "Skip to Start", _on_skip_start)
	_add_button(transport, "▶", "Play", _on_play)
	_add_button(transport, "Ⅱ", "Pause / Resume", _on_pause)
	_add_button(transport, "■", "Stop", _on_stop)
	_add_button(transport, "●", "Record / open Recording panel", _on_record_toolbar)
	_add_button(transport, ">|", "Skip to End", _on_skip_end)
	transport.add_child(VSeparator.new())
	_add_button(transport, "Play Selection", "Play selected time range", _on_play_selection)
	_add_button(transport, "Play To Selection", "Play from the cursor to the nearest forward selection boundary", _on_play_to_selection)
	_add_button(transport, "Split", "Split selected clips at cursor", _on_split)
	_add_button(transport, "Split Selection", "Split selected clips at both time-selection boundaries", _on_split_selection)
	_add_button(transport, "Duplicate", "Duplicate selected clips", _on_duplicate_clips)
	_add_button(transport, "Join", "Join selected clips on the same track", _on_join_clips)
	_add_button(transport, "Separate", "Move selected clips to separate tracks", _on_separate_clips)
	_add_button(transport, "Trim", "Keep only the time selection on selected track", _on_trim)
	_add_button(transport, "Silence", "Replace time selection with silence", _on_silence)
	_add_button(transport, "Split Delete", "Delete selected time without closing the gap", _on_split_delete)
	_add_button(transport, "Split Cut", "Cut selected time without closing the gap", _on_split_cut)
	transport.add_child(VSeparator.new())
	_add_button(transport, "−", "Zoom Out", _on_zoom_out)
	_add_button(transport, "+", "Zoom In", _on_zoom_in)
	_add_button(transport, "Fit", "Fit project to view", _on_zoom_fit)
	_add_button(transport, "Zero", "Snap cursor/selection start to nearest zero crossing", _on_zero_crossing)
	transport.add_child(VSeparator.new())
	_add_button(transport, "FX Rack", "Open realtime/destructive effects", _on_show_effects)
	_add_button(transport, "Recording", "Open microphone recording controls", _on_show_recording)
	_add_button(transport, "Mixer", "Open multitrack mixer", _on_show_mixer)
	_add_button(transport, "Analyzer", "Open spectrum, spectrogram, measurements and beat detection", _on_show_analyzer)
	_add_button(transport, "Spectral", "Open spectral time/frequency editing", _on_show_spectral)
	_add_button(transport, "Advanced", "Open automation, labels, loops, export, macros, optimization, history, comparison, metadata and game preview", _on_show_advanced)
	_sample_draw_toggle = CheckButton.new()
	_sample_draw_toggle.text = "Sample Draw"
	_sample_draw_toggle.tooltip_text = "At deep zoom, drag individual sample amplitudes directly."
	_sample_draw_toggle.toggled.connect(_on_sample_draw_toggled)
	transport.add_child(_sample_draw_toggle)
	_scrub_toggle = CheckButton.new()
	_scrub_toggle.text = "Scrub"
	_scrub_toggle.tooltip_text = "Audition a short slice whenever the cursor is moved."
	_scrub_toggle.toggled.connect(_on_scrub_toggled)
	transport.add_child(_scrub_toggle)
	_loop_toggle = CheckButton.new()
	_loop_toggle.text = "Loop"
	_loop_toggle.tooltip_text = "Loop the current time selection, Loop Editor range, or project playback. Shortcut: L."
	_loop_toggle.toggled.connect(_on_loop_toggled)
	transport.add_child(_loop_toggle)
	transport.add_child(VSeparator.new())
	var speed_label: Label = Label.new()
	speed_label.text = "Speed"
	transport.add_child(speed_label)
	_playback_speed_spin = SpinBox.new()
	_playback_speed_spin.min_value = 0.25
	_playback_speed_spin.max_value = 4.0
	_playback_speed_spin.step = 0.05
	_playback_speed_spin.value = 1.0
	_playback_speed_spin.suffix = "×"
	_playback_speed_spin.custom_minimum_size.x = 78.0
	_playback_speed_spin.value_changed.connect(_on_playback_speed_changed)
	transport.add_child(_playback_speed_spin)
	var bpm_label: Label = Label.new()
	bpm_label.text = "BPM"
	transport.add_child(bpm_label)
	_bpm_spin = SpinBox.new()
	_bpm_spin.min_value = 20.0
	_bpm_spin.max_value = 400.0
	_bpm_spin.step = 0.1
	_bpm_spin.value = 120.0
	_bpm_spin.custom_minimum_size.x = 82.0
	_bpm_spin.value_changed.connect(_on_bpm_changed)
	transport.add_child(_bpm_spin)
	_time_base_option = OptionButton.new()
	for time_base: String in PackedStringArray(["Seconds", "Milliseconds", "Samples", "Frames", "Beats"]):
		_time_base_option.add_item(time_base)
	_time_base_option.item_selected.connect(_on_time_base_changed)
	transport.add_child(_time_base_option)
	_snap_option = OptionButton.new()
	for snap_name: String in PackedStringArray(["Clips", "Samples", "Milliseconds", "Frames", "Beats", "Bars"]):
		_snap_option.add_item(snap_name)
	_snap_option.item_selected.connect(_on_snap_mode_changed)
	transport.add_child(_snap_option)

	_generated_bin = HFlowContainer.new()
	_generated_bin.add_theme_constant_override("h_separation", 4)
	_generated_bin.add_theme_constant_override("v_separation", 4)
	root.add_child(_generated_bin)
	var generated_label: Label = Label.new()
	generated_label.text = "Generated Bin:"
	generated_label.tooltip_text = "Recent generated sounds. Drag a button onto any Audio Editor track to place a copy there."
	_generated_bin.add_child(generated_label)

	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	_left_scroll = ScrollContainer.new()
	_left_scroll.custom_minimum_size.x = 190.0
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_left_scroll)
	_track_list = VBoxContainer.new()
	_track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_list.add_theme_constant_override("separation", 0)
	_left_scroll.add_child(_track_list)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_wave_scroll = ScrollContainer.new()
	_wave_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_wave_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_wave_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_wave_scroll)
	_waveform = WaveformView.new()
	_waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waveform.set_model(_model)
	_waveform.selection_changed.connect(_on_wave_selection_changed)
	_waveform.cursor_changed.connect(_on_wave_cursor_changed)
	_waveform.track_selected.connect(_on_wave_track_selected)
	_waveform.clip_selection_changed.connect(_on_wave_clip_selection_changed)
	_waveform.edit_committed.connect(_on_wave_edit_committed)
	_waveform.clip_context_requested.connect(_on_clip_context_requested)
	_waveform.clip_rename_requested.connect(_on_clip_rename_requested)
	_waveform.files_dropped.connect(_on_files_dropped)
	_waveform.generated_audio_dropped.connect(_on_generated_audio_dropped)
	_waveform.view_changed.connect(_on_wave_view_changed)
	_waveform.resized.connect(_on_waveform_resized)
	_wave_scroll.add_child(_waveform)
	_horizontal_scroll = HScrollBar.new()
	_horizontal_scroll.min_value = 0.0
	_horizontal_scroll.step = 1.0
	_horizontal_scroll.value_changed.connect(_on_horizontal_scroll_changed)
	right.add_child(_horizontal_scroll)

	_left_scroll.get_v_scroll_bar().value_changed.connect(_on_left_vertical_scroll)
	_wave_scroll.get_v_scroll_bar().value_changed.connect(_on_wave_vertical_scroll)

	_recording_panel = RecordingPanel.new()
	_recording_panel.visible = false
	_recording_panel.record_requested.connect(_on_record_requested)
	_recording_panel.stop_requested.connect(_on_record_stop_requested)
	_recording_panel.input_meter_toggled.connect(_on_input_meter_toggled)
	_recording_panel.monitor_toggled.connect(_on_monitor_toggled)
	_recording_panel.enable_input_setting_requested.connect(_on_enable_input_setting)
	_recording_panel.refresh_devices_requested.connect(_refresh_input_devices)
	_recording_panel.calibration_requested.connect(_on_calibration_requested)
	root.add_child(_recording_panel)

	_mixer_panel = MixerPanel.new()
	_mixer_panel.visible = false
	_mixer_panel.audio_changed.connect(_on_mixer_audio_changed)
	_mixer_panel.track_fx_requested.connect(_on_track_fx)
	_mixer_panel.master_fx_requested.connect(_on_master_fx)
	_mixer_panel.bus_preview_toggled.connect(_on_bus_preview_toggled)
	_mixer_panel.temporary_buses_requested.connect(_on_temporary_buses_requested)
	root.add_child(_mixer_panel)
	_mixer_panel.set_model(_model)

	_analyzer_panel = AnalyzerPanel.new()
	_analyzer_panel.visible = false
	_analyzer_panel.set_model(_model)
	_analyzer_panel.markers_requested.connect(_on_analyzer_markers_requested)
	_analyzer_panel.status_changed.connect(_on_analyzer_status_changed)
	root.add_child(_analyzer_panel)

	_build_effects_panel(root)

	var bottom: HFlowContainer = HFlowContainer.new()
	bottom.add_theme_constant_override("h_separation", 12)
	bottom.add_theme_constant_override("v_separation", 4)
	root.add_child(bottom)
	_cursor_label = _status_field(bottom, "Cursor", "0.000 s")
	_selection_start_label = _status_field(bottom, "Start", "0.000 s")
	_selection_end_label = _status_field(bottom, "End", "0.000 s")
	_selection_length_label = _status_field(bottom, "Length", "0.000 s")
	_selection_start_sample_label = _status_field(bottom, "Start Sample", "0")
	_selection_end_sample_label = _status_field(bottom, "End Sample", "0")
	_frequency_range_label = _status_field(bottom, "Frequency", "—")
	_format_label = _status_field(bottom, "Project", "44100 Hz")
	_status = Label.new()
	_status.text = "Open a WAV file to begin."
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status)

	_player = AudioStreamPlayer.new()
	_player.name = "GASAudioEditorPreview"
	add_child(_player)

	_monitor_player = AudioStreamPlayer.new()
	_monitor_player.name = "GASMicrophoneMonitor"
	_monitor_player.stream = AudioStreamMicrophone.new()
	_monitor_player.bus = "Master"
	add_child(_monitor_player)
	_calibration_player = AudioStreamPlayer.new()
	_calibration_player.name = "GASLatencyCalibration"
	_calibration_player.bus = "Master"
	add_child(_calibration_player)
	_refresh_input_devices()
	_refresh_latency_info()

	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.filters = PackedStringArray(["*.wav;WAV Audio;audio/wav", "*.mp3;MP3 Audio;audio/mpeg", "*.ogg;Ogg Vorbis Audio;audio/ogg"])
	_open_dialog.title = "Import Audio into Gator Audio Studio"
	_open_dialog.file_selected.connect(_on_open_wav_selected)
	add_child(_open_dialog)

	_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.filters = PackedStringArray(["*.wav;WAV Audio;audio/wav"])
	_export_dialog.title = "Export Audio Editor Mixdown"
	_export_dialog.file_selected.connect(_on_export_path_selected)
	add_child(_export_dialog)

	_project_open_dialog = FileDialog.new()
	_project_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_project_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_project_open_dialog.filters = PackedStringArray(["*.gasproj;Gator Audio Studio Project"])
	_project_open_dialog.title = "Open Gator Audio Studio Project"
	_project_open_dialog.file_selected.connect(_on_project_open_selected)
	add_child(_project_open_dialog)

	_project_save_dialog = FileDialog.new()
	_project_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_project_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_project_save_dialog.filters = PackedStringArray(["*.gasproj;Gator Audio Studio Project"])
	_project_save_dialog.title = "Save Gator Audio Studio Project"
	_project_save_dialog.file_selected.connect(_on_project_save_selected)
	_project_save_dialog.canceled.connect(_on_project_save_canceled)
	add_child(_project_save_dialog)

	_relink_dialog = FileDialog.new()
	_relink_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_relink_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_relink_dialog.filters = PackedStringArray(["*.wav;WAV Audio;audio/wav", "*.mp3;MP3 Audio;audio/mpeg", "*.ogg;Ogg Vorbis Audio;audio/ogg"])
	_relink_dialog.title = "Relink Missing Audio Source"
	_relink_dialog.file_selected.connect(_on_relink_file_selected)
	add_child(_relink_dialog)

	_missing_folder_dialog = FileDialog.new()
	_missing_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_missing_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_missing_folder_dialog.title = "Search Folder for Missing Audio Sources"
	_missing_folder_dialog.dir_selected.connect(_on_missing_folder_selected)
	add_child(_missing_folder_dialog)

	_missing_sources_dialog = AcceptDialog.new()
	_missing_sources_dialog.title = "Missing Audio Sources"
	_missing_sources_dialog.get_ok_button().text = "Close"
	_missing_sources_dialog.add_button("Relink Selected...", false, "relink")
	_missing_sources_dialog.add_button("Search Folder...", false, "search_folder")
	_missing_sources_dialog.custom_action.connect(_on_missing_sources_action)
	var missing_box: VBoxContainer = VBoxContainer.new()
	missing_box.custom_minimum_size = Vector2(620.0, 280.0)
	_missing_sources_dialog.add_child(missing_box)
	var missing_help: Label = Label.new()
	missing_help.text = "Missing source files are listed below. Cached project audio remains playable when available. Relinking updates the source reference without overwriting edited project audio. Keep the companion .gasdata folder beside the .gasproj file; it stores edited, recorded, and generated project audio."
	missing_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	missing_box.add_child(missing_help)
	_missing_sources_list = ItemList.new()
	_missing_sources_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	missing_box.add_child(_missing_sources_list)
	add_child(_missing_sources_dialog)

	_recovery_dialog = ConfirmationDialog.new()
	_recovery_dialog.title = "Recover Gator Audio Studio Project"
	_recovery_dialog.get_ok_button().text = "Recover"
	_recovery_dialog.add_button("Discard Recovery", false, "discard")
	_recovery_dialog.confirmed.connect(_on_recovery_confirmed)
	_recovery_dialog.custom_action.connect(_on_recovery_custom_action)
	add_child(_recovery_dialog)

	_project_settings_dialog = ConfirmationDialog.new()
	_project_settings_dialog.title = "Gator Audio Project Settings"
	_project_settings_dialog.get_ok_button().text = "Apply"
	_project_settings_dialog.confirmed.connect(_on_project_settings_confirmed)
	var settings_grid: GridContainer = GridContainer.new()
	settings_grid.columns = 2
	settings_grid.custom_minimum_size.x = 440.0
	_project_settings_dialog.add_child(settings_grid)
	settings_grid.add_child(_small_label("Project Name"))
	_project_name_edit = LineEdit.new()
	_project_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_grid.add_child(_project_name_edit)
	settings_grid.add_child(_small_label("Autosave"))
	_autosave_toggle = CheckButton.new()
	_autosave_toggle.text = "Enabled"
	settings_grid.add_child(_autosave_toggle)
	settings_grid.add_child(_small_label("Autosave Interval"))
	_autosave_interval_spin = SpinBox.new()
	_autosave_interval_spin.min_value = 15.0
	_autosave_interval_spin.max_value = 600.0
	_autosave_interval_spin.step = 5.0
	_autosave_interval_spin.suffix = " sec"
	settings_grid.add_child(_autosave_interval_spin)
	settings_grid.add_child(_small_label("Time Signature"))
	var signature_row: HBoxContainer = HBoxContainer.new()
	_time_sig_num_spin = SpinBox.new()
	_time_sig_num_spin.min_value = 1.0
	_time_sig_num_spin.max_value = 32.0
	_time_sig_num_spin.step = 1.0
	_time_sig_num_spin.value = 4.0
	signature_row.add_child(_time_sig_num_spin)
	signature_row.add_child(_small_label("/"))
	_time_sig_den_spin = SpinBox.new()
	_time_sig_den_spin.min_value = 1.0
	_time_sig_den_spin.max_value = 32.0
	_time_sig_den_spin.step = 1.0
	_time_sig_den_spin.value = 4.0
	signature_row.add_child(_time_sig_den_spin)
	settings_grid.add_child(signature_row)
	settings_grid.add_child(_small_label("Frame Rate"))
	_frame_rate_spin = SpinBox.new()
	_frame_rate_spin.min_value = 1.0
	_frame_rate_spin.max_value = 240.0
	_frame_rate_spin.step = 0.001
	_frame_rate_spin.value = 30.0
	_frame_rate_spin.suffix = " fps"
	settings_grid.add_child(_frame_rate_spin)
	settings_grid.add_child(_small_label("UI Scale"))
	_ui_scale_spin = SpinBox.new()
	_ui_scale_spin.min_value = 0.75
	_ui_scale_spin.max_value = 2.0
	_ui_scale_spin.step = 0.05
	_ui_scale_spin.value = 1.0
	settings_grid.add_child(_ui_scale_spin)
	settings_grid.add_child(_small_label("High Contrast"))
	_high_contrast_toggle = CheckButton.new(); _high_contrast_toggle.text = "Enhanced waveform contrast"
	settings_grid.add_child(_high_contrast_toggle)
	settings_grid.add_child(_small_label("Strong Focus"))
	_strong_focus_toggle = CheckButton.new(); _strong_focus_toggle.text = "Visible keyboard focus"; _strong_focus_toggle.button_pressed = true
	settings_grid.add_child(_strong_focus_toggle)
	settings_grid.add_child(_small_label("Meter Text"))
	_meter_text_toggle = CheckButton.new(); _meter_text_toggle.text = "Show numeric meter equivalents"; _meter_text_toggle.button_pressed = true
	settings_grid.add_child(_meter_text_toggle)
	add_child(_project_settings_dialog)

	_shortcut_dialog = ConfirmationDialog.new()
	_shortcut_dialog.title = "Gator Audio Studio Shortcuts"
	_shortcut_dialog.get_ok_button().text = "Apply"
	_shortcut_dialog.add_button("Reset Defaults", false, "reset")
	_shortcut_dialog.confirmed.connect(_on_shortcuts_confirmed)
	_shortcut_dialog.custom_action.connect(_on_shortcuts_custom_action)
	var shortcut_scroll: ScrollContainer = ScrollContainer.new()
	shortcut_scroll.custom_minimum_size = Vector2(520.0, 430.0)
	var shortcut_grid: GridContainer = GridContainer.new(); shortcut_grid.columns = 2
	shortcut_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shortcut_scroll.add_child(shortcut_grid)
	for action_value: Variant in DEFAULT_SHORTCUTS.keys():
		var action: String = str(action_value)
		shortcut_grid.add_child(_small_label(action.replace("_", " ").capitalize()))
		var edit: LineEdit = LineEdit.new()
		edit.placeholder_text = str(DEFAULT_SHORTCUTS[action])
		shortcut_grid.add_child(edit)
		_shortcut_edits[action] = edit
	_shortcut_dialog.add_child(shortcut_scroll)
	add_child(_shortcut_dialog)

	_help_dialog = AcceptDialog.new()
	_help_dialog.title = "Gator Audio Studio — Audio Editor Guide"
	var help_text: RichTextLabel = RichTextLabel.new()
	help_text.bbcode_enabled = true
	help_text.fit_content = false
	help_text.custom_minimum_size = Vector2(720.0, 460.0)
	help_text.text = (
		"[b]Core workflow[/b]\n"
		+ "Import or drag WAVs → arrange clips/tracks → add non-destructive FX or Apply Destructively → analyze/automate/loop → export. Save the whole Editor + Generator workspace as .gasproj.\n\n"
		+ "[b]Clip editing[/b]\n"
		+ "Click a clip to select it; Ctrl/Shift add to selection. Drag clips across time/tracks. Drag clip edges to trim. Double-click a clip to rename it. Right-click for clip actions. Sample Draw edits individual amplitudes at deep zoom.\n\n"
		+ "[b]Effects[/b]\n"
		+ "Add Non-Destructive FX builds a reorderable rack. Apply Destructively bakes the current effect into audio. Rack FX do not require a second Apply step.\n\n"
		+ "[b]Advanced tools[/b]\n"
		+ "Tools includes automation, labels/regions, loop editing, export, macros/batch, optimization, history, A/B comparison, metadata, project-audio browsing and game preview. Analyze includes spectrum, spectrogram, beat detection and spectral editing. Long spectral/restoration jobs run in the background and can be cancelled.\n\n"
		+ "[b]Main shortcuts[/b]\n"
		+ "Ctrl+N New Project • Ctrl+O Open Project • Ctrl+S Save • Ctrl+Shift+S Save As\n"
		+ "Space Play/Stop • L Loop • Ctrl+Z Undo • Ctrl+Y / Ctrl+Shift+Z Redo\n"
		+ "Ctrl+X Cut • Ctrl+C Copy • Ctrl+V Paste • Delete Delete • Ctrl+D Duplicate\n"
		+ "Ctrl+Wheel Zoom • Home/End project start/end\n\n"
		+ "[b]Project files[/b]\n"
		+ "Keep the .gasproj and its companion .gasdata folder together. Imported source audio files are never overwritten by project saving. Missing sources can be relinked; cached project audio is retained when available."
	)
	_help_dialog.add_child(help_text)
	add_child(_help_dialog)

	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Unsaved Gator Audio Project"
	_unsaved_dialog.dialog_text = "This project has unsaved changes. Save them before continuing?"
	_unsaved_dialog.get_ok_button().text = "Save"
	_unsaved_dialog.add_button("Discard", false, "discard")
	_unsaved_dialog.confirmed.connect(_on_unsaved_save_confirmed)
	_unsaved_dialog.custom_action.connect(_on_unsaved_custom_action)
	add_child(_unsaved_dialog)

	_clip_context_menu = PopupMenu.new()
	_clip_context_menu.add_item("Rename Clip...", CTX_RENAME)
	_clip_context_menu.add_item("Duplicate", CTX_DUPLICATE)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Cut Clips", CTX_CUT)
	_clip_context_menu.add_item("Copy Clips", CTX_COPY)
	_clip_context_menu.add_item("Delete Clips", CTX_DELETE)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Split at Cursor", CTX_SPLIT)
	_clip_context_menu.add_item("Join Selected Clips", CTX_JOIN)
	_clip_context_menu.add_item("Separate to New Tracks", CTX_SEPARATE)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Split Delete Time Selection", CTX_SPLIT_DELETE)
	_clip_context_menu.add_item("Split Cut Time Selection", CTX_SPLIT_CUT)
	_clip_context_menu.add_item("Silence Selection", CTX_SILENCE)
	_clip_context_menu.add_item("Trim to Selection", CTX_TRIM)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Normalize", CTX_NORMALIZE)
	_clip_context_menu.add_item("Fade In", CTX_FADE_IN)
	_clip_context_menu.add_item("Fade Out", CTX_FADE_OUT)
	_clip_context_menu.add_item("Crossfade Selected Clips", CTX_CROSSFADE)
	_clip_context_menu.add_item("Reverse", CTX_REVERSE)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Add Marker at Cursor", CTX_ADD_MARKER)
	_clip_context_menu.add_item("Generate...", CTX_GENERATE)
	_clip_context_menu.add_item("Analyze...", CTX_ANALYZE)
	_clip_context_menu.add_item("Export Selection...", CTX_EXPORT_SELECTION)
	_clip_context_menu.add_separator()
	_clip_context_menu.add_item("Effects...", CTX_EFFECTS)
	_clip_context_menu.id_pressed.connect(_on_clip_context_id)
	add_child(_clip_context_menu)

	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename Clip"
	_rename_dialog.confirmed.connect(_on_rename_confirmed)
	_rename_edit = LineEdit.new()
	_rename_edit.custom_minimum_size.x = 320.0
	_rename_edit.placeholder_text = "Clip name"
	_rename_dialog.add_child(_rename_edit)
	add_child(_rename_dialog)


func _build_menu(parent: HBoxContainer, title: String, items: Array, callback: Callable) -> void:
	var menu: MenuButton = MenuButton.new()
	menu.text = title
	menu.flat = true
	parent.add_child(menu)
	var popup: PopupMenu = menu.get_popup()
	for item: Variant in items:
		var pair: Array = item as Array
		popup.add_item(str(pair[0]), int(pair[1]))
	popup.id_pressed.connect(callback)



func _build_effect_menu(parent: HBoxContainer) -> void:
	var menu: MenuButton = MenuButton.new()
	menu.text = "Effect"
	menu.flat = true
	parent.add_child(menu)
	_effect_menu_popup = menu.get_popup()
	_rebuild_effect_menu_popup()
	_effect_menu_popup.id_pressed.connect(_on_effect_menu)


func _rebuild_effect_menu_popup() -> void:
	if _effect_menu_popup == null:
		return
	_effect_menu_popup.clear()
	_effect_menu_popup.add_item("Effects Rack...", MENU_EFFECT_RACK)
	_effect_menu_popup.add_separator()
	_effect_type_tokens = EffectEngine.available_effect_types()
	for index: int in range(_effect_type_tokens.size()):
		_effect_menu_popup.add_item(EffectEngine.effect_display_name(_effect_type_tokens[index]), MENU_EFFECT_BASE + index)


func _build_effects_panel(parent: VBoxContainer) -> void:
	_effects_panel = PanelContainer.new()
	_effects_panel.visible = false
	_effects_panel.custom_minimum_size.y = 225.0
	parent.add_child(_effects_panel)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	_effects_panel.add_child(root)

	var header: HFlowContainer = HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 6)
	header.add_theme_constant_override("v_separation", 4)
	root.add_child(header)
	var title: Label = Label.new()
	title.text = "EFFECTS"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	header.add_child(_small_label("Target"))
	_effect_target_option = OptionButton.new()
	_effect_target_option.add_item("Selected Clips")
	_effect_target_option.add_item("Selected Track")
	_effect_target_option.add_item("Master")
	_effect_target_option.item_selected.connect(_on_effect_target_changed)
	header.add_child(_effect_target_option)
	header.add_child(_small_label("Effect"))
	_effect_type_option = OptionButton.new()
	_effect_type_option.custom_minimum_size.x = 150.0
	_refresh_effect_type_options()
	_effect_type_option.item_selected.connect(_on_effect_type_changed)
	header.add_child(_effect_type_option)
	header.add_child(_small_label("Preset"))
	_effect_preset_option = OptionButton.new()
	_effect_preset_option.custom_minimum_size.x = 135.0
	_effect_preset_option.item_selected.connect(_on_effect_preset_changed)
	header.add_child(_effect_preset_option)
	_effect_enabled_check = CheckButton.new()
	_effect_enabled_check.text = "Enabled"
	_effect_enabled_check.button_pressed = true
	_effect_enabled_check.toggled.connect(_on_effect_enabled_changed)
	header.add_child(_effect_enabled_check)
	header.add_child(_small_label("Overall Wet"))
	_effect_wet_slider = HSlider.new()
	_effect_wet_slider.min_value = 0.0
	_effect_wet_slider.max_value = 1.0
	_effect_wet_slider.step = 0.01
	_effect_wet_slider.value = 1.0
	_effect_wet_slider.custom_minimum_size.x = 100.0
	_effect_wet_slider.value_changed.connect(_on_effect_wet_changed)
	header.add_child(_effect_wet_slider)
	_add_button(header, "Preview", "Audition the current effect or edited rack effect without changing audio", _on_effect_preview)
	_add_button(header, "Apply Destructively", "Bake this effect into selected clips or the selected track time range. You do not add it to the rack first.", _on_effect_apply)
	_add_button(header, "Add Non-Destructive FX", "Append this effect to the selected clip, track, or master rack. Multiple effects can be stacked and reordered; no destructive Apply step is required.", _on_effect_add_to_rack)
	_add_button(header, "Update Selected FX", "Replace the selected rack effect with the edited settings", _on_effect_update_rack)
	_add_button(header, "Save User Preset", "Save the current effect settings to the global GAS user preset bank.", _on_save_user_effect_preset)
	_add_button(header, "Save Project Preset", "Save the current effect settings inside this Godot project.", _on_save_project_effect_preset)
	_add_button(header, "Hide", "Hide the Effects panel", _on_hide_effects)

	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var params_scroll: ScrollContainer = ScrollContainer.new()
	params_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	params_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	params_scroll.custom_minimum_size.x = 430.0
	body.add_child(params_scroll)
	_effect_parameter_grid = GridContainer.new()
	_effect_parameter_grid.columns = 2
	_effect_parameter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	params_scroll.add_child(_effect_parameter_grid)

	var rack_box: VBoxContainer = VBoxContainer.new()
	rack_box.custom_minimum_size.x = 360.0
	body.add_child(rack_box)
	var rack_title: Label = Label.new()
	rack_title.text = "NON-DESTRUCTIVE FX RACK"
	rack_title.add_theme_font_size_override("font_size", 13)
	rack_box.add_child(rack_title)
	_rack_list = ItemList.new()
	_rack_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rack_list.select_mode = ItemList.SELECT_SINGLE
	_rack_list.item_selected.connect(_on_rack_selected)
	rack_box.add_child(_rack_list)
	var rack_actions: HFlowContainer = HFlowContainer.new()
	rack_box.add_child(rack_actions)
	_add_button(rack_actions, "Up", "Move selected effect earlier in the stack", _on_rack_up)
	_add_button(rack_actions, "Down", "Move selected effect later in the stack", _on_rack_down)
	_add_button(rack_actions, "Bypass", "Toggle selected effect bypass", _on_rack_bypass)
	_add_button(rack_actions, "Remove", "Remove selected effect", _on_rack_remove)
	_add_button(rack_actions, "Clear", "Clear the current effect stack", _on_rack_clear)
	_add_button(rack_actions, "Copy Stack", "Copy the entire current FX rack inside GAS.", _on_rack_copy)
	_add_button(rack_actions, "Paste Stack", "Replace the current target rack with the copied stack.", _on_rack_paste)
	_add_button(rack_actions, "Save Stack", "Save the current rack as a JSON stack preset under user://gator_audio_studio/effect_stacks/.", _on_rack_save)
	_add_button(rack_actions, "Render Stack", "Bake the current target rack into audio and clear the rack where applicable.", _on_rack_render)

	_effect_preset_dialog = ConfirmationDialog.new()
	_effect_preset_dialog.title = "Save Effect Preset"
	_effect_preset_dialog.confirmed.connect(_on_effect_preset_save_confirmed)
	_effect_preset_name_edit = LineEdit.new()
	_effect_preset_name_edit.custom_minimum_size.x = 360.0
	_effect_preset_name_edit.placeholder_text = "Preset name"
	_effect_preset_dialog.add_child(_effect_preset_name_edit)
	add_child(_effect_preset_dialog)

	if not _effect_type_tokens.is_empty():
		_current_effect = EffectEngine.create_default(_effect_type_tokens[0])
	_refresh_effect_presets()
	_rebuild_effect_parameters()
	_refresh_effect_rack()


func _on_effect_menu(id: int) -> void:
	if id == MENU_EFFECT_RACK:
		_on_show_effects()
		return
	var index: int = id - MENU_EFFECT_BASE
	if index < 0 or index >= _effect_type_tokens.size():
		return
	_on_show_effects()
	_effect_type_option.select(index)
	_on_effect_type_changed(index)


func _ensure_advanced_tools() -> Control:
	if _advanced_tools != null:
		return _advanced_tools
	if _ui_root == null:
		return null
	var loaded: Resource = load(ADVANCED_TOOLS_SCRIPT_PATH)
	var script: GDScript = loaded as GDScript
	if script == null:
		push_error("Gator Audio Studio: could not load Advanced Audio Tools.")
		return null
	if not script.can_instantiate():
		script.reload(true)
	if not script.can_instantiate():
		push_error("Gator Audio Studio: Advanced Audio Tools could not be instantiated.")
		return null
	var instance: Object = script.new()
	var panel: Control = instance as Control
	if panel == null:
		push_error("Gator Audio Studio: Advanced Audio Tools did not create a Control.")
		return null
	panel.visible = false
	Callable(panel, "set_model").call(_model)
	panel.connect("audio_changed", Callable(self, "_on_advanced_audio_changed"))
	panel.connect("status_changed", Callable(self, "_on_advanced_status_changed"))
	panel.connect("jump_requested", Callable(self, "_on_advanced_jump_requested"))
	panel.connect("spectral_selection_changed", Callable(self, "_on_spectral_selection_changed"))
	_ui_root.add_child(panel)
	if _effects_panel != null and _effects_panel.get_parent() == _ui_root:
		_ui_root.move_child(panel, _effects_panel.get_index())
	_advanced_tools = panel
	return _advanced_tools


func _show_aux_panel(panel: Control) -> void:
	if _effects_panel != null:
		_effects_panel.visible = panel == _effects_panel
	if _recording_panel != null:
		_recording_panel.visible = panel == _recording_panel
	if _mixer_panel != null:
		_mixer_panel.visible = panel == _mixer_panel
	if _analyzer_panel != null:
		_analyzer_panel.visible = panel == _analyzer_panel
	if _advanced_tools != null:
		_advanced_tools.visible = panel == _advanced_tools


func _on_show_spectral() -> void:
	var advanced: Control = _ensure_advanced_tools()
	if advanced == null:
		return
	_show_aux_panel(advanced)
	Callable(advanced, "show_tab").call("Spectral Edit")
	_status.text = "Spectral editor ready. Time selection + Low/High frequency defines the spectral rectangle."


func _on_show_advanced() -> void:
	var advanced: Control = _ensure_advanced_tools()
	if advanced == null:
		return
	_show_aux_panel(advanced)
	Callable(advanced, "refresh").call()
	_status.text = "Advanced audio tools opened."


func _on_tools_menu(id: int) -> void:
	var advanced: Control = _ensure_advanced_tools()
	if advanced == null:
		return
	var tab_name: String = ""
	match id:
		MENU_TOOLS_AUTOMATION:
			tab_name = "Automation"
		MENU_TOOLS_LABELS:
			tab_name = "Labels & Regions"
		MENU_TOOLS_LOOP:
			tab_name = "Loop Editor"
		MENU_TOOLS_EXPORT:
			tab_name = "Export"
		MENU_TOOLS_MACROS:
			tab_name = "Macros"
		MENU_TOOLS_OPTIMIZE:
			tab_name = "Game Optimization"
		MENU_TOOLS_HISTORY:
			tab_name = "History"
		MENU_TOOLS_COMPARE:
			tab_name = "A/B Compare"
		MENU_TOOLS_METADATA:
			tab_name = "Metadata"
		MENU_TOOLS_GAME_PREVIEW:
			tab_name = "Game Preview"
		MENU_TOOLS_PROJECT_AUDIO:
			tab_name = "Project Audio"
	if tab_name.is_empty():
		return
	_show_aux_panel(advanced)
	Callable(advanced, "show_tab").call(tab_name)


func _on_advanced_audio_changed() -> void:
	_invalidate_audio()
	_project_state_dirty = true
	_refresh_all()


func _on_advanced_status_changed(message: String) -> void:
	_status.text = message


func _on_advanced_jump_requested(frame: int) -> void:
	_model.cursor_frame = maxi(0, frame)
	_model.clear_time_selection()
	_waveform.ensure_frame_visible(_model.cursor_frame)
	_waveform.queue_redraw()
	_update_selection_status()


func _on_spectral_selection_changed(low_hz: float, high_hz: float) -> void:
	_spectral_low_hz = maxf(0.0, minf(low_hz, high_hz))
	_spectral_high_hz = maxf(_spectral_low_hz, maxf(low_hz, high_hz))
	if _waveform != null:
		_waveform.set_spectral_selection(_spectral_low_hz, _spectral_high_hz, true)
	_update_selection_status()


func _on_loop_toggled(enabled: bool) -> void:
	_transport_loop_enabled = enabled
	_project_state_dirty = true
	_status.text = "Loop playback enabled." if enabled else "Loop playback disabled."


func _on_sample_draw_toggled(enabled: bool) -> void:
	if _waveform != null:
		_waveform.set_sample_draw_mode(enabled)
	_status.text = "Sample Draw enabled. Zoom to sample level and drag waveform samples." if enabled else "Sample Draw disabled."


func _on_scrub_toggled(enabled: bool) -> void:
	_scrub_enabled = enabled
	_status.text = "Scrub enabled: moving the timeline cursor auditions a short slice." if enabled else "Scrub disabled."


func _on_playback_speed_changed(value: float) -> void:
	if _model == null:
		return
	_model.playback_speed = clampf(value, 0.25, 4.0)
	_model.dirty = true
	_project_state_dirty = true
	if _player != null:
		_player.pitch_scale = _model.playback_speed


func _on_bpm_changed(value: float) -> void:
	if _model == null:
		return
	_model.project_bpm = clampf(value, 20.0, 400.0)
	_model.dirty = true
	_project_state_dirty = true
	_waveform.queue_redraw()


func _on_time_base_changed(index: int) -> void:
	_time_base_mode = _time_base_option.get_item_text(index)
	_waveform.set_time_base(_time_base_mode)
	_project_state_dirty = true


func _on_snap_mode_changed(index: int) -> void:
	if _model == null:
		return
	_model.grid_snap_mode = _snap_option.get_item_text(index)
	_model.dirty = true
	_project_state_dirty = true


func _on_show_effects() -> void:
	_show_aux_panel(_effects_panel)
	if _model.selected_clip_ids.is_empty() and _model.selected_track >= 0:
		_effect_target_option.select(1)
	else:
		_effect_target_option.select(0)
	_selected_rack_index = -1
	_refresh_effect_rack()


func _on_show_effects_for_clips() -> void:
	_show_aux_panel(_effects_panel)
	_effect_target_option.select(0)
	_selected_rack_index = -1
	_refresh_effect_rack()


func _on_track_fx(index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.select_track(index, false, false)
	_show_aux_panel(_effects_panel)
	_effect_target_option.select(1)
	_selected_rack_index = -1
	_refresh_effect_rack()
	_refresh_track_controls()


func _on_master_fx() -> void:
	_show_aux_panel(_effects_panel)
	_effect_target_option.select(2)
	_selected_rack_index = -1
	_refresh_effect_rack()


func _on_show_recording() -> void:
	_show_aux_panel(_recording_panel)
	_refresh_input_devices()
	_refresh_latency_info()


func _on_show_mixer() -> void:
	_show_aux_panel(_mixer_panel)
	_mixer_panel.refresh()
	_update_mixer_meters()


func _on_hide_effects() -> void:
	_effects_panel.visible = false


func _on_effect_target_changed(_index: int) -> void:
	_selected_rack_index = -1
	_refresh_effect_rack()


func _on_effect_type_changed(index: int) -> void:
	if index < 0 or index >= _effect_type_tokens.size():
		return
	_current_effect = EffectEngine.create_default(_effect_type_tokens[index])
	_refresh_effect_presets()
	_rebuild_effect_parameters()


func _refresh_effect_presets() -> void:
	_effect_preset_option.clear()
	_effect_preset_entries.clear()
	if _current_effect == null:
		return
	var presets: PackedStringArray = EffectEngine.presets_for(_current_effect.effect_type)
	for preset: String in presets:
		_effect_preset_option.add_item("Built In • " + preset)
		_effect_preset_entries.append({"scope": "Built In", "name": preset})
	for entry: Dictionary in EffectPresetStore.list_presets(_current_effect.effect_type):
		var scope: String = str(entry.get("scope", "User"))
		var name: String = str(entry.get("name", "Preset"))
		_effect_preset_option.add_item("%s • %s" % [scope, name])
		_effect_preset_entries.append({"scope": scope, "name": name})
	_effect_preset_option.select(0)


func _on_effect_preset_changed(index: int) -> void:
	if _current_effect == null or index < 0 or index >= _effect_preset_entries.size():
		return
	var entry: Dictionary = _effect_preset_entries[index]
	var scope: String = str(entry.get("scope", "Built In"))
	var preset_name: String = str(entry.get("name", "Default"))
	if scope == "Built In":
		EffectEngine.apply_preset(_current_effect, preset_name)
	else:
		var loaded: GASEffectData = EffectPresetStore.load_effect(scope, _current_effect.effect_type, preset_name)
		if loaded != null:
			_current_effect = loaded
	_rebuild_effect_parameters()


func _rebuild_effect_parameters() -> void:
	for child: Node in _effect_parameter_grid.get_children():
		child.queue_free()
	_effect_parameter_controls.clear()
	_effect_mode_option = null
	if _current_effect == null:
		return
	if _current_effect.effect_type == "Distortion":
		_effect_parameter_grid.add_child(_small_label("Mode"))
		_effect_mode_option = OptionButton.new()
		for mode_name: String in ["Soft Clip", "Hard Clip", "Saturation", "Overdrive", "Digital", "Rectifier", "Foldback"]:
			_effect_mode_option.add_item(mode_name)
		var current_mode: String = str(_current_effect.params.get("mode", "Soft Clip"))
		for mode_index: int in range(_effect_mode_option.get_item_count()):
			if _effect_mode_option.get_item_text(mode_index) == current_mode:
				_effect_mode_option.select(mode_index)
				break
		_effect_mode_option.item_selected.connect(_on_effect_mode_changed)
		_effect_parameter_grid.add_child(_effect_mode_option)
	var specs: Array[Dictionary] = EffectEngine.parameter_specs(_current_effect.effect_type)
	for spec: Dictionary in specs:
		var key: String = str(spec.get("key", ""))
		if key.is_empty():
			continue
		_effect_parameter_grid.add_child(_small_label(str(spec.get("label", key))))
		var type_name: String = str(spec.get("type", "float"))
		if type_name == "bool":
			var check: CheckButton = CheckButton.new()
			check.set_pressed_no_signal(bool(_current_effect.params.get(key, false)))
			check.toggled.connect(_on_effect_bool_parameter_changed.bind(key))
			_effect_parameter_grid.add_child(check)
			_effect_parameter_controls[key] = check
		elif type_name == "enum":
			var option: OptionButton = OptionButton.new()
			var options_value: Variant = spec.get("options", PackedStringArray())
			var options: PackedStringArray = PackedStringArray()
			if options_value is PackedStringArray:
				options = options_value as PackedStringArray
			elif options_value is Array:
				options = PackedStringArray(options_value as Array)
			for option_text: String in options:
				option.add_item(option_text)
			var selected_text: String = str(_current_effect.params.get(key, options[0] if not options.is_empty() else ""))
			for option_index: int in range(option.get_item_count()):
				if option.get_item_text(option_index) == selected_text:
					option.select(option_index)
					break
			option.item_selected.connect(_on_effect_enum_parameter_changed.bind(key))
			_effect_parameter_grid.add_child(option)
			_effect_parameter_controls[key] = option
		else:
			var spin: SpinBox = SpinBox.new()
			spin.min_value = float(spec.get("min", 0.0))
			spin.max_value = float(spec.get("max", 1.0))
			spin.step = float(spec.get("step", 0.01))
			spin.allow_greater = false
			spin.allow_lesser = false
			spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spin.set_value_no_signal(float(_current_effect.params.get(key, spin.min_value)))
			spin.value_changed.connect(_on_effect_parameter_changed.bind(key, type_name == "int"))
			_effect_parameter_grid.add_child(spin)
			_effect_parameter_controls[key] = spin
	_effect_enabled_check.set_pressed_no_signal(_current_effect.enabled)
	_effect_wet_slider.set_value_no_signal(_current_effect.wet)



func _commit_effect_parameter_controls() -> void:
	if _current_effect == null:
		return
	var specs: Array[Dictionary] = EffectEngine.parameter_specs(_current_effect.effect_type)
	for key_variant: Variant in _effect_parameter_controls.keys():
		var key: String = str(key_variant)
		var control_value: Variant = _effect_parameter_controls.get(key, null)
		var spin: SpinBox = control_value as SpinBox
		if spin != null:
			# Commit any still-edited LineEdit text before the effect is snapshotted
			# and handed to WorkerThreadPool.
			spin.apply()
			var integer_value: bool = false
			for spec: Dictionary in specs:
				if str(spec.get("key", "")) == key:
					integer_value = str(spec.get("type", "float")) == "int"
					break
			_current_effect.params[key] = int(round(spin.value)) if integer_value else float(spin.value)
			continue
		var check: CheckButton = control_value as CheckButton
		if check != null:
			_current_effect.params[key] = check.button_pressed
			continue
		var option: OptionButton = control_value as OptionButton
		if option != null and option.selected >= 0 and option.selected < option.get_item_count():
			_current_effect.params[key] = option.get_item_text(option.selected)
	if _effect_mode_option != null and _current_effect.effect_type == "Distortion":
		var mode_index: int = _effect_mode_option.selected
		if mode_index >= 0 and mode_index < _effect_mode_option.get_item_count():
			_current_effect.params["mode"] = _effect_mode_option.get_item_text(mode_index)
	if _effect_enabled_check != null:
		_current_effect.enabled = _effect_enabled_check.button_pressed
	if _effect_wet_slider != null:
		_current_effect.wet = float(_effect_wet_slider.value)


func _on_effect_mode_changed(index: int) -> void:
	if _current_effect == null or _effect_mode_option == null or index < 0:
		return
	_current_effect.params["mode"] = _effect_mode_option.get_item_text(index)


func _on_effect_parameter_changed(value: float, key: String, integer: bool = false) -> void:
	if _current_effect == null:
		return
	_current_effect.params[key] = int(round(value)) if integer else value
	_current_effect.preset_name = "Custom"


func _on_effect_bool_parameter_changed(value: bool, key: String) -> void:
	if _current_effect == null:
		return
	_current_effect.params[key] = value
	_current_effect.preset_name = "Custom"


func _on_effect_enum_parameter_changed(index: int, key: String) -> void:
	if _current_effect == null:
		return
	var control_value: Variant = _effect_parameter_controls.get(key, null)
	var option: OptionButton = control_value as OptionButton
	if option == null or index < 0 or index >= option.get_item_count():
		return
	_current_effect.params[key] = option.get_item_text(index)
	_current_effect.preset_name = "Custom"


func _on_effect_enabled_changed(value: bool) -> void:
	if _current_effect != null:
		_current_effect.enabled = value


func _on_effect_wet_changed(value: float) -> void:
	if _current_effect != null:
		_current_effect.wet = value


func _start_editor_model_action(action: int, status_text: String) -> bool:
	if _editor_action_job != null and _editor_action_job.task_id >= 0:
		_status.text = "Another audio processing job is already running."
		return false
	var snapshot: GASEditorModel = _model.create_persistence_snapshot()
	var job: GASEditorActionJob = EditorActionJob.new() as GASEditorActionJob
	if job == null or not job.start_model_action(snapshot, action, _model.change_revision):
		_status.text = "Could not start background audio processing."
		return false
	_editor_action_job = job
	_editor_action_status = status_text
	_status.text = status_text + " in background…"
	return true


func _process_editor_action_job() -> void:
	if _editor_action_job == null or _editor_action_job.task_id < 0 or not _editor_action_job.is_complete():
		return
	var job: GASEditorActionJob = _editor_action_job
	job.collect()
	_editor_action_job = null
	if _model == null or _model.change_revision != job.model_revision:
		_status.text = "Background audio result discarded because the project changed."
		return
	if job.action == GASEditorActionJob.ACTION_EFFECT_PREVIEW:
		if not job.success or job.wav_result == null:
			_status.text = "Effect preview could not be rendered."
			return
		_on_stop()
		_player.volume_db = 0.0
		_player.stream = job.wav_result
		_player.play()
		_status.text = _editor_action_status
		return
	if job.action == GASEditorActionJob.ACTION_MODEL_COPY:
		if job.success and _model.commit_background_clipboard(job.snapshot):
			_status.text = "Copied time selection."
		else:
			_status.text = "Create a time selection on a track first."
		return
	if not job.success or job.snapshot == null:
		_status.text = _editor_action_status + " did not change audio."
		return
	var undo_label: String = _editor_action_undo_label(job.action)
	var copy_clipboard: bool = job.action == GASEditorActionJob.ACTION_MODEL_CUT
	if not _model.commit_background_snapshot(job.snapshot, undo_label, copy_clipboard):
		_status.text = "Could not commit background audio result."
		return
	_invalidate_audio()
	_refresh_all()
	_refresh_effect_rack()
	if _mixer_panel != null:
		_mixer_panel.refresh()
	_status.text = _editor_action_status


func _editor_action_undo_label(action: int) -> String:
	match action:
		GASEditorActionJob.ACTION_MODEL_TRIM: return "Trim"
		GASEditorActionJob.ACTION_MODEL_SILENCE: return "Silence"
		GASEditorActionJob.ACTION_MODEL_JOIN: return "Join Clips"
		GASEditorActionJob.ACTION_MODEL_SAMPLE_ZERO: return "Sample Zero"
		GASEditorActionJob.ACTION_MODEL_SAMPLE_INTERPOLATE: return "Sample Interpolate"
		GASEditorActionJob.ACTION_MODEL_SAMPLE_SMOOTH: return "Sample Smooth"
		GASEditorActionJob.ACTION_MODEL_SAMPLE_REPAIR: return "Sample Repair"
		GASEditorActionJob.ACTION_MODEL_MERGE_DOWN: return "Merge Tracks"
		GASEditorActionJob.ACTION_MODEL_RENDER_NEW: return "Render Track"
		GASEditorActionJob.ACTION_MODEL_MIX_MONO: return "Mix Track to Mono"
		GASEditorActionJob.ACTION_MODEL_MIX_STEREO: return "Mix Track to Stereo"
		GASEditorActionJob.ACTION_MODEL_CUT: return "Cut"
		GASEditorActionJob.ACTION_EFFECT_APPLY_CLIPS, GASEditorActionJob.ACTION_EFFECT_APPLY_TRACKS: return "Apply Effect"
		GASEditorActionJob.ACTION_RACK_RENDER_CLIPS, GASEditorActionJob.ACTION_RACK_RENDER_TRACK: return "Render Effect Stack"
	return "Audio Edit"


func _on_effect_preview() -> void:
	if _current_effect == null:
		return
	_commit_effect_parameter_controls()
	if _editor_action_job != null and _editor_action_job.task_id >= 0:
		_status.text = "Another audio processing job is already running."
		return
	var target: int = _effect_target_option.selected
	var snapshot: GASEditorModel = _model.create_persistence_snapshot()
	var stack: Array[GASEffectData] = _target_stack_copy()
	var job: GASEditorActionJob = EditorActionJob.new() as GASEditorActionJob
	if job == null or not job.start_effect_preview(snapshot, _current_effect, target, _selected_rack_index, stack, _model.change_revision):
		_status.text = "Could not start background effect preview."
		return
	_editor_action_job = job
	_editor_action_status = "Previewing %s." % _current_effect.effect_type
	_status.text = "Rendering %s preview in background…" % _current_effect.effect_type


func _on_effect_apply() -> void:
	if _current_effect == null:
		return
	_commit_effect_parameter_controls()
	var target: int = _effect_target_option.selected
	if target == 2:
		_status.text = "Master effects are non-destructive. Add them to the Master rack; Export Mixdown renders the rack into the exported WAV."
		return
	if target == 0 and _model.selected_clip_ids.is_empty():
		_status.text = "Select one or more clips first."
		return
	if target == 1 and not _model.has_selection():
		_status.text = "Create a time selection for the Track target first."
		return
	if _editor_action_job != null and _editor_action_job.task_id >= 0:
		_status.text = "Another audio processing job is already running."
		return
	var snapshot: GASEditorModel = _model.create_persistence_snapshot()
	var job: GASEditorActionJob = EditorActionJob.new() as GASEditorActionJob
	if job == null or not job.start_effect_apply(snapshot, _current_effect, target, _model.change_revision):
		_status.text = "Could not start background destructive effect."
		return
	_editor_action_job = job
	_editor_action_status = "Applied %s destructively." % _current_effect.effect_type
	_status.text = "Applying %s in background…" % _current_effect.effect_type


func _on_effect_add_to_rack() -> void:
	if _current_effect == null:
		return
	_commit_effect_parameter_controls()
	if not EffectEngine.is_stack_safe(_current_effect.effect_type):
		_status.text = "%s changes duration and is destructive-only." % _current_effect.effect_type
		return
	var changed: bool = false
	match _effect_target_option.selected:
		0:
			changed = _model.add_effect_to_selected_clips(_current_effect)
		1:
			changed = _model.add_effect_to_selected_track(_current_effect)
		2:
			changed = _model.add_effect_to_master(_current_effect)
	if changed:
		_invalidate_audio()
		_selected_rack_index = -1
		_refresh_effect_rack()
		_refresh_track_controls()
		if _mixer_panel != null:
			_mixer_panel.refresh()
		_status.text = "Added %s to non-destructive FX rack. Add more effects to build a chain; no destructive Apply step is required." % _current_effect.effect_type
	else:
		_status.text = "Select a clip or track first, or choose Master."


func _on_save_user_effect_preset() -> void:
	_open_effect_preset_save_dialog("User")


func _on_save_project_effect_preset() -> void:
	_open_effect_preset_save_dialog("Project")


func _open_effect_preset_save_dialog(scope: String) -> void:
	if _current_effect == null or _effect_preset_dialog == null:
		return
	_commit_effect_parameter_controls()
	_effect_preset_save_scope = scope
	_effect_preset_dialog.title = "Save %s Effect Preset" % scope
	_effect_preset_name_edit.text = _current_effect.effect_type + " Preset"
	_effect_preset_name_edit.select_all()
	_effect_preset_dialog.popup_centered(Vector2i(440, 130))
	_effect_preset_name_edit.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	_effect_preset_name_edit.focus_mode = Control.FOCUS_ALL
	if _effect_preset_name_edit.get_focus_mode_with_override() != Control.FOCUS_NONE:
		_effect_preset_name_edit.grab_focus()


func _on_effect_preset_save_confirmed() -> void:
	if _current_effect == null:
		return
	var preset_name: String = _effect_preset_name_edit.text.strip_edges()
	var error: Error = EffectPresetStore.save_user(_current_effect, preset_name) if _effect_preset_save_scope == "User" else EffectPresetStore.save_project(_current_effect, preset_name)
	if error != OK:
		_status.text = "Could not save effect preset: %s" % error_string(error)
		return
	_refresh_effect_presets()
	_status.text = "Saved %s effect preset '%s'." % [_effect_preset_save_scope, preset_name]


func _target_stack_copy() -> Array[GASEffectData]:
	var result: Array[GASEffectData] = []
	match _effect_target_option.selected:
		0:
			if _model.selected_clip_ids.is_empty():
				return result
			var clip: GASEditorClip = _model.find_clip(_model.selected_clip_ids[0])
			if clip == null:
				return result
			for effect: GASEffectData in clip.effect_stack:
				result.append(effect.duplicate_effect())
		1:
			if _model.selected_track >= 0 and _model.selected_track < _model.tracks.size():
				var track: GASEditorTrack = _model.tracks[_model.selected_track]
				for effect: GASEffectData in track.effect_stack:
					result.append(effect.duplicate_effect())
		2:
			for effect: GASEffectData in _model.master_effect_stack:
				result.append(effect.duplicate_effect())
	return result


func _write_target_stack(stack: Array[GASEffectData], undo_label: String) -> bool:
	match _effect_target_option.selected:
		0:
			return _model.replace_clip_effect_stack(_model.selected_clip_ids, stack, undo_label)
		1:
			return _model.replace_track_effect_stack(_model.selected_track, stack, undo_label)
		2:
			return _model.replace_master_effect_stack(stack, undo_label)
	return false


func _refresh_effect_rack() -> void:
	if _rack_list == null:
		return
	_rack_list.clear()
	var stack: Array[GASEffectData] = _target_stack_copy()
	for index: int in range(stack.size()):
		var effect: GASEffectData = stack[index]
		var marker: String = "●" if effect.enabled else "○"
		_rack_list.add_item("%s %d. %s  (%d%% wet)" % [marker, index + 1, EffectEngine.effect_display_name(effect.effect_type), int(round(effect.wet * 100.0))])
	if _selected_rack_index >= stack.size():
		_selected_rack_index = -1
	if _selected_rack_index >= 0:
		_rack_list.select(_selected_rack_index)


func _on_rack_selected(index: int) -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if index < 0 or index >= stack.size():
		return
	_selected_rack_index = index
	_current_effect = stack[index].duplicate_effect()
	for effect_index: int in range(_effect_type_tokens.size()):
		if _effect_type_tokens[effect_index] == _current_effect.effect_type:
			_effect_type_option.select(effect_index)
			break
	_refresh_effect_presets()
	_rebuild_effect_parameters()


func _on_effect_update_rack() -> void:
	if _current_effect == null or _selected_rack_index < 0:
		return
	_commit_effect_parameter_controls()
	if not EffectEngine.is_stack_safe(_current_effect.effect_type):
		_status.text = "%s cannot be used in the realtime rack." % _current_effect.effect_type
		return
	var stack: Array[GASEffectData] = _target_stack_copy()
	if _selected_rack_index >= stack.size():
		return
	stack[_selected_rack_index] = _current_effect.duplicate_effect()
	if _write_target_stack(stack, "Update Effect"):
		_invalidate_audio()
		_refresh_effect_rack()
		if _mixer_panel != null:
			_mixer_panel.refresh()
		_status.text = "Updated rack effect."


func _on_rack_up() -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if _selected_rack_index <= 0 or _selected_rack_index >= stack.size():
		return
	var swap: GASEffectData = stack[_selected_rack_index - 1]
	stack[_selected_rack_index - 1] = stack[_selected_rack_index]
	stack[_selected_rack_index] = swap
	_selected_rack_index -= 1
	if _write_target_stack(stack, "Move Effect"):
		_invalidate_audio()
		_refresh_effect_rack()
		if _mixer_panel != null:
			_mixer_panel.refresh()


func _on_rack_down() -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if _selected_rack_index < 0 or _selected_rack_index >= stack.size() - 1:
		return
	var swap: GASEffectData = stack[_selected_rack_index + 1]
	stack[_selected_rack_index + 1] = stack[_selected_rack_index]
	stack[_selected_rack_index] = swap
	_selected_rack_index += 1
	if _write_target_stack(stack, "Move Effect"):
		_invalidate_audio()
		_refresh_effect_rack()
		if _mixer_panel != null:
			_mixer_panel.refresh()


func _on_rack_bypass() -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if _selected_rack_index < 0 or _selected_rack_index >= stack.size():
		return
	stack[_selected_rack_index].enabled = not stack[_selected_rack_index].enabled
	if _write_target_stack(stack, "Bypass Effect"):
		_invalidate_audio()
		_refresh_effect_rack()
		if _mixer_panel != null:
			_mixer_panel.refresh()


func _on_rack_remove() -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if _selected_rack_index < 0 or _selected_rack_index >= stack.size():
		return
	stack.remove_at(_selected_rack_index)
	_selected_rack_index = mini(_selected_rack_index, stack.size() - 1)
	if _write_target_stack(stack, "Remove Effect"):
		_invalidate_audio()
		_refresh_effect_rack()
		_refresh_track_controls()
		if _mixer_panel != null:
			_mixer_panel.refresh()


func _on_rack_clear() -> void:
	var stack: Array[GASEffectData] = []
	_selected_rack_index = -1
	if _write_target_stack(stack, "Clear Effects"):
		_invalidate_audio()
		_refresh_effect_rack()
		_refresh_track_controls()
		if _mixer_panel != null:
			_mixer_panel.refresh()


func _on_rack_copy() -> void:
	_effect_stack_clipboard.clear()
	for effect: GASEffectData in _target_stack_copy():
		_effect_stack_clipboard.append(effect.duplicate_effect())
	_status.text = "Copied %d rack effect(s)." % _effect_stack_clipboard.size()


func _on_rack_paste() -> void:
	if _effect_stack_clipboard.is_empty():
		_status.text = "The GAS effect-stack clipboard is empty."
		return
	var stack: Array[GASEffectData] = []
	for effect: GASEffectData in _effect_stack_clipboard:
		stack.append(effect.duplicate_effect())
	if _write_target_stack(stack, "Paste Effect Stack"):
		_invalidate_audio()
		_refresh_effect_rack()
		_status.text = "Pasted %d rack effect(s)." % stack.size()


func _on_rack_save() -> void:
	var stack: Array[GASEffectData] = _target_stack_copy()
	if stack.is_empty():
		_status.text = "The current rack is empty."
		return
	var dir_path: String = ProjectSettings.globalize_path("user://gator_audio_studio/effect_stacks")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_error != OK:
		_status.text = "Could not create effect stack folder: %s" % error_string(dir_error)
		return
	var path: String = dir_path.path_join("stack_%d.gasfx.json" % int(Time.get_unix_time_from_system()))
	var serialized: Array[Dictionary] = []
	for effect: GASEffectData in stack:
		serialized.append({"type": effect.effect_type, "enabled": effect.enabled, "wet": effect.wet, "preset": effect.preset_name, "params": effect.params.duplicate(true)})
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_status.text = "Could not save effect stack."
		return
	file.store_string(JSON.stringify({"format": "GAS Effect Stack", "version": 1, "effects": serialized}, "\t"))
	file.close()
	_status.text = "Saved effect stack: %s" % path


func _on_rack_render() -> void:
	var target: int = _effect_target_option.selected
	var stack: Array[GASEffectData] = _target_stack_copy()
	if stack.is_empty():
		_status.text = "The current rack is empty."
		return
	if target == 2:
		_status.text = "Render Stack is available for clip and track racks. Master is rendered during mixdown/export."
		return
	if _editor_action_job != null and _editor_action_job.task_id >= 0:
		_status.text = "Another audio processing job is already running."
		return
	var snapshot: GASEditorModel = _model.create_persistence_snapshot()
	var job: GASEditorActionJob = EditorActionJob.new() as GASEditorActionJob
	if job == null or not job.start_rack_render(snapshot, target, _model.change_revision):
		_status.text = "Could not start background rack render."
		return
	_editor_action_job = job
	_editor_action_status = "Rendered the effect stack into audio."
	_status.text = "Rendering effect stack in background…"


func _add_button(parent: Container, text: String, tooltip: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)


func _status_field(parent: Container, caption: String, value: String) -> Label:
	var box: HBoxContainer = HBoxContainer.new()
	parent.add_child(box)
	var title: Label = Label.new()
	title.text = caption + ":"
	title.modulate = Color(0.68, 0.72, 0.78)
	box.add_child(title)
	var label: Label = Label.new()
	label.text = value
	label.custom_minimum_size.x = 78.0
	box.add_child(label)
	return label


func _add_generated_bin_entry(wav: AudioStreamWAV, suggested_name: String) -> void:
	if _generated_bin == null or wav == null:
		return
	var item: GASAudioDragItem = AudioDragItem.new()
	item.setup(wav, suggested_name)
	_generated_bin.add_child(item)
	_generated_bin_entries.append({"wav": wav, "name": suggested_name, "button": item})
	while _generated_bin_entries.size() > 12:
		var oldest: Dictionary = _generated_bin_entries.pop_front()
		var old_button: Control = oldest.get("button") as Control
		if old_button != null:
			old_button.queue_free()


func _refresh_all() -> void:
	_refresh_track_controls()
	_refresh_waveform_size()
	_update_selection_status()
	_update_horizontal_scroll()
	if _waveform != null:
		_waveform.queue_redraw()
	if _playback_speed_spin != null:
		_playback_speed_spin.set_value_no_signal(_model.playback_speed)
	if _bpm_spin != null:
		_bpm_spin.set_value_no_signal(_model.project_bpm)
	if _mixer_panel != null and _mixer_panel.visible:
		_mixer_panel.refresh()
	if _advanced_tools != null and _advanced_tools.visible:
		Callable(_advanced_tools, "refresh").call()


func _refresh_track_controls() -> void:
	for child: Node in _track_list.get_children():
		_track_list.remove_child(child)
		child.queue_free()
	_track_panels.clear()
	var timeline_spacer: Control = Control.new()
	timeline_spacer.custom_minimum_size.y = GASAudioEditorWaveform.TIMELINE_HEIGHT
	_track_list.add_child(timeline_spacer)
	for index: int in range(_model.tracks.size()):
		var track: GASEditorTrack = _model.tracks[index]
		var panel: GASTrackDragPanel = TrackDragPanel.new()
		panel.setup(index)
		panel.reorder_requested.connect(_on_track_reorder)
		panel.custom_minimum_size = Vector2(240.0, GASAudioEditorWaveform.COLLAPSED_TRACK_HEIGHT if track.collapsed else GASAudioEditorWaveform.TRACK_HEIGHT)
		panel.tooltip_text = "Drag this track panel to reorder tracks."
		_track_list.add_child(panel)
		_track_panels.append(panel)
		panel.resized.connect(_queue_track_height_sync)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		panel.add_child(box)
		var header: HBoxContainer = HBoxContainer.new()
		box.add_child(header)
		var collapse: Button = Button.new()
		collapse.text = "▸" if track.collapsed else "▾"
		collapse.tooltip_text = "Expand / collapse track controls"
		collapse.custom_minimum_size.x = 28.0
		collapse.pressed.connect(_on_track_collapsed.bind(index))
		header.add_child(collapse)
		var name_edit: LineEdit = LineEdit.new()
		name_edit.text = track.name
		name_edit.tooltip_text = "Track name"
		name_edit.editable = not track.reference_read_only
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_submitted.connect(_on_track_name_changed.bind(index))
		header.add_child(name_edit)
		var select_button: Button = Button.new()
		select_button.text = "●" if _model.is_track_selected(index) else "○"
		select_button.tooltip_text = "Select track. Ctrl-click toggles; Shift-click selects a range."
		select_button.disabled = false
		select_button.custom_minimum_size.x = 30.0
		select_button.gui_input.connect(_on_track_select_gui_input.bind(index))
		header.add_child(select_button)
		var delete_button: Button = Button.new()
		delete_button.text = "×"
		delete_button.tooltip_text = "Delete this track"
		delete_button.custom_minimum_size.x = 30.0
		delete_button.pressed.connect(_on_track_delete.bind(index))
		header.add_child(delete_button)
		if track.collapsed:
			continue
		var type_row: HFlowContainer = HFlowContainer.new()
		type_row.add_theme_constant_override("h_separation", 3)
		type_row.add_theme_constant_override("v_separation", 2)
		box.add_child(type_row)
		type_row.add_child(_small_label("Type"))
		var type_option: OptionButton = OptionButton.new()
		type_option.custom_minimum_size.x = 100.0
		type_option.add_item("Audio", GASEditorTrack.TYPE_AUDIO)
		type_option.add_item("Label", GASEditorTrack.TYPE_LABEL)
		type_option.add_item("Automation", GASEditorTrack.TYPE_AUTOMATION)
		type_option.add_item("Generated", GASEditorTrack.TYPE_GENERATED)
		type_option.add_item("Reference", GASEditorTrack.TYPE_REFERENCE)
		for item_index: int in range(type_option.item_count):
			if type_option.get_item_id(item_index) == track.track_type:
				type_option.select(item_index)
				break
		type_option.item_selected.connect(_on_track_type_changed.bind(index))
		type_row.add_child(type_option)
		var lock_button: CheckButton = CheckButton.new()
		lock_button.text = "Lock"
		lock_button.button_pressed = track.locked or track.reference_read_only
		lock_button.disabled = track.reference_read_only
		lock_button.tooltip_text = "Reference tracks are always read-only." if track.reference_read_only else "Prevent destructive edits and clip movement on this track."
		lock_button.toggled.connect(_on_track_locked.bind(index))
		type_row.add_child(lock_button)
		var color_button: ColorPickerButton = ColorPickerButton.new()
		color_button.color = track.color
		color_button.custom_minimum_size = Vector2(30.0, 24.0)
		color_button.tooltip_text = "Track color"
		color_button.color_changed.connect(_on_track_color_changed.bind(index))
		type_row.add_child(color_button)
		var display_row: HBoxContainer = HBoxContainer.new()
		box.add_child(display_row)
		display_row.add_child(_small_label("View"))
		var display_option: OptionButton = OptionButton.new()
		display_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		display_option.add_item("Waveform")
		display_option.add_item("Spectrogram")
		display_option.add_item("Combined")
		display_option.select(clampi(track.display_mode, 0, 2))
		display_option.tooltip_text = "Audacity-style track display: waveform, spectrogram, or both."
		display_option.item_selected.connect(_on_track_display_mode.bind(index))
		display_row.add_child(display_option)
		var channel_option: OptionButton = OptionButton.new()
		channel_option.tooltip_text = "Track render channel mode"
		channel_option.add_item("Auto", GASEditorTrack.CHANNEL_AUTO)
		channel_option.add_item("Mono", GASEditorTrack.CHANNEL_MONO)
		channel_option.add_item("Stereo", GASEditorTrack.CHANNEL_STEREO)
		for item_index: int in range(channel_option.item_count):
			if channel_option.get_item_id(item_index) == track.channel_mode:
				channel_option.select(item_index)
				break
		channel_option.item_selected.connect(_on_track_channel_mode_changed.bind(index))
		display_row.add_child(channel_option)
		var wave_row: HFlowContainer = HFlowContainer.new()
		wave_row.add_theme_constant_override("h_separation", 3)
		box.add_child(wave_row)
		wave_row.add_child(_small_label("Wave"))
		var stereo_view: OptionButton = OptionButton.new()
		stereo_view.add_item("Split L/R", GASEditorTrack.WAVEFORM_SPLIT_STEREO)
		stereo_view.add_item("Combined L/R", GASEditorTrack.WAVEFORM_COMBINED_STEREO)
		stereo_view.select(track.waveform_stereo_mode)
		stereo_view.tooltip_text = "Display stereo as split channels or overlaid in one waveform."
		stereo_view.item_selected.connect(_on_track_wave_stereo_mode.bind(index))
		wave_row.add_child(stereo_view)
		var amplitude_view: OptionButton = OptionButton.new()
		amplitude_view.add_item("Linear", GASEditorTrack.AMPLITUDE_LINEAR)
		amplitude_view.add_item("dB", GASEditorTrack.AMPLITUDE_DB)
		amplitude_view.select(track.waveform_amplitude_mode)
		amplitude_view.item_selected.connect(_on_track_wave_amplitude_mode.bind(index))
		wave_row.add_child(amplitude_view)
		var zero_check: CheckButton = CheckButton.new()
		zero_check.text = "0-line"
		zero_check.button_pressed = track.show_zero_line
		zero_check.toggled.connect(_on_track_zero_line_toggled.bind(index))
		wave_row.add_child(zero_check)
		var clip_check: CheckButton = CheckButton.new()
		clip_check.text = "Clip"
		clip_check.button_pressed = track.show_clipping
		clip_check.tooltip_text = "Show clipped-sample indicators on the waveform."
		clip_check.toggled.connect(_on_track_clipping_toggled.bind(index))
		wave_row.add_child(clip_check)
		var rate_spin: SpinBox = SpinBox.new()
		rate_spin.min_value = 4000.0
		rate_spin.max_value = 192000.0
		rate_spin.step = 1000.0
		rate_spin.value = track.sample_rate
		rate_spin.suffix = " Hz"
		rate_spin.custom_minimum_size.x = 95.0
		rate_spin.tooltip_text = "Per-track preferred processing/export sample rate. Timeline timing remains at the project rate."
		rate_spin.value_changed.connect(_on_track_sample_rate_changed.bind(index))
		wave_row.add_child(rate_spin)
		var buttons: HFlowContainer = HFlowContainer.new()
		buttons.add_theme_constant_override("h_separation", 3)
		box.add_child(buttons)
		var mute_button: CheckButton = CheckButton.new()
		mute_button.text = "M"
		mute_button.button_pressed = track.mute
		mute_button.toggled.connect(_on_track_mute.bind(index))
		buttons.add_child(mute_button)
		var solo_button: CheckButton = CheckButton.new()
		solo_button.text = "S"
		solo_button.button_pressed = track.solo
		solo_button.toggled.connect(_on_track_solo.bind(index))
		buttons.add_child(solo_button)
		var arm_button: CheckButton = CheckButton.new()
		arm_button.text = "R"
		arm_button.tooltip_text = "Record arm. Selected-track recording modes prefer an armed track."
		arm_button.button_pressed = track.record_armed
		arm_button.disabled = track.reference_read_only or track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION
		arm_button.toggled.connect(_on_track_arm.bind(index))
		buttons.add_child(arm_button)
		var fx_button: Button = Button.new()
		fx_button.text = "FX %d" % track.effect_stack.size()
		fx_button.tooltip_text = "Open this track's realtime effect stack"
		fx_button.disabled = track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION
		fx_button.pressed.connect(_on_track_fx.bind(index))
		buttons.add_child(fx_button)
		if track.track_type == GASEditorTrack.TYPE_GENERATED and not track.generated_settings.is_empty():
			var load_generator: Button = Button.new()
			load_generator.text = "Load Gen"
			load_generator.tooltip_text = "Restore the generator parameters retained by this Generated track and switch to Generator."
			load_generator.pressed.connect(_on_load_generated_track_settings.bind(index))
			buttons.add_child(load_generator)
		var sync_label: Label = Label.new()
		sync_label.text = "Sync"
		buttons.add_child(sync_label)
		var sync_spin: SpinBox = SpinBox.new()
		sync_spin.min_value = 0.0
		sync_spin.max_value = 32.0
		sync_spin.step = 1.0
		sync_spin.value = track.sync_group
		sync_spin.custom_minimum_size.x = 54.0
		sync_spin.tooltip_text = "Sync-Lock group. Tracks with the same non-zero group ripple together when duration changes."
		sync_spin.value_changed.connect(_on_track_sync_group_changed.bind(index))
		buttons.add_child(sync_spin)
		var gain_row: HBoxContainer = HBoxContainer.new()
		box.add_child(gain_row)
		gain_row.add_child(_small_label("Gain"))
		var gain: HSlider = HSlider.new()
		gain.min_value = -24.0
		gain.max_value = 12.0
		gain.step = 0.5
		gain.value = track.gain_db
		gain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gain.value_changed.connect(_on_track_gain.bind(index))
		gain_row.add_child(gain)
		var gain_reset: Button = Button.new()
		gain_reset.text = "↺"
		gain_reset.tooltip_text = "Reset Gain to 0 dB (unity)"
		gain_reset.custom_minimum_size.x = 28.0
		gain_reset.pressed.connect(_on_reset_track_gain.bind(index, gain))
		gain_row.add_child(gain_reset)
		var pan_row: HBoxContainer = HBoxContainer.new()
		box.add_child(pan_row)
		pan_row.add_child(_small_label("Pan"))
		var pan: HSlider = HSlider.new()
		pan.min_value = -1.0
		pan.max_value = 1.0
		pan.step = 0.05
		pan.value = track.pan
		pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pan.value_changed.connect(_on_track_pan.bind(index))
		pan_row.add_child(pan)
		var pan_reset: Button = Button.new()
		pan_reset.text = "↺"
		pan_reset.tooltip_text = "Reset Pan to center"
		pan_reset.custom_minimum_size.x = 28.0
		pan_reset.pressed.connect(_on_reset_track_pan.bind(index, pan))
		pan_row.add_child(pan_reset)
		var info: Label = Label.new()
		info.text = _track_info(track)
		info.modulate = Color(0.62, 0.68, 0.74)
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(info)
	_queue_track_height_sync()


func _queue_track_height_sync() -> void:
	if _track_layout_sync_queued:
		return
	_track_layout_sync_queued = true
	call_deferred("_sync_track_layout_heights")


func _sync_track_layout_heights() -> void:
	_track_layout_sync_queued = false
	if _waveform == null or _model == null:
		return
	var count: int = _model.tracks.size()
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(count)
	for index: int in range(count):
		var minimum_height: float = GASAudioEditorWaveform.COLLAPSED_TRACK_HEIGHT if _model.tracks[index].collapsed else GASAudioEditorWaveform.TRACK_HEIGHT
		var measured_height: float = minimum_height
		if index < _track_panels.size():
			var panel: Control = _track_panels[index]
			if panel != null and is_instance_valid(panel):
				measured_height = maxf(minimum_height, panel.size.y)
		heights[index] = measured_height
	_waveform.set_track_heights(heights)
	_refresh_waveform_size()
	_sync_vertical_scroll_positions()


func _sync_vertical_scroll_positions() -> void:
	if _left_scroll == null or _wave_scroll == null:
		return
	var left_bar: VScrollBar = _left_scroll.get_v_scroll_bar()
	var wave_bar: VScrollBar = _wave_scroll.get_v_scroll_bar()
	var target: float = minf(left_bar.value, wave_bar.value)
	_syncing_scroll = true
	left_bar.set_value_no_signal(target)
	wave_bar.set_value_no_signal(target)
	_syncing_scroll = false


func _small_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size.x = 34.0
	return label


func _track_info(track: GASEditorTrack) -> String:
	var type_name: String = _track_type_name(track.track_type)
	if track.track_type == GASEditorTrack.TYPE_LABEL:
		return "%s • %d labels/regions" % [type_name, _model.markers.size()]
	if track.track_type == GASEditorTrack.TYPE_AUTOMATION:
		return "%s • %d lanes" % [type_name, track.automation_lanes.size()]
	if track.clips.is_empty():
		return "%s • Empty" % type_name
	var channels: String = "Stereo" if EffectEngine.stack_outputs_stereo(track.effect_stack) else "Mono"
	for clip: GASEditorClip in track.clips:
		if clip.pcm != null and clip.pcm.is_stereo():
			channels = "Stereo"
			break
	var fx_text: String = "" if track.effect_stack.is_empty() else " • %d FX" % track.effect_stack.size()
	var missing_count: int = 0
	for clip: GASEditorClip in track.clips:
		if clip.source_missing:
			missing_count += 1
	var missing_text: String = "" if missing_count == 0 else " • %d missing" % missing_count
	var generated_text: String = " • Params saved" if track.track_type == GASEditorTrack.TYPE_GENERATED and not track.generated_settings.is_empty() else ""
	return "%s • %s • %d clips%s%s%s" % [type_name, channels, track.clips.size(), fx_text, missing_text, generated_text]


func _track_type_name(track_type: int) -> String:
	match track_type:
		GASEditorTrack.TYPE_LABEL:
			return "Label"
		GASEditorTrack.TYPE_AUTOMATION:
			return "Automation"
		GASEditorTrack.TYPE_GENERATED:
			return "Generated"
		GASEditorTrack.TYPE_REFERENCE:
			return "Reference"
		_:
			return "Audio"


func _refresh_waveform_size() -> void:
	var content_height: float = maxf(GASAudioEditorWaveform.TIMELINE_HEIGHT + GASAudioEditorWaveform.TRACK_HEIGHT, _waveform.content_height())
	_waveform.custom_minimum_size.y = content_height
	_track_list.custom_minimum_size.y = content_height


func _update_selection_status() -> void:
	if _model == null or _cursor_label == null or _selection_start_label == null or _selection_end_label == null or _selection_length_label == null or _selection_start_sample_label == null or _selection_end_sample_label == null or _frequency_range_label == null or _format_label == null:
		return
	var rate: float = float(maxi(1, _model.sample_rate))
	_cursor_label.text = "%.3f s" % (float(_model.cursor_frame) / rate)
	_selection_start_label.text = "%.3f s" % (float(_model.selection_start) / rate)
	_selection_end_label.text = "%.3f s" % (float(_model.selection_end) / rate)
	_selection_length_label.text = "%.3f s" % (float(_model.selection_length()) / rate)
	_selection_start_sample_label.text = str(_model.selection_start)
	_selection_end_sample_label.text = str(_model.selection_end)
	_frequency_range_label.text = "%.0f–%.0f Hz" % [_spectral_low_hz, _spectral_high_hz] if _spectral_high_hz > _spectral_low_hz else "—"
	var channel_text: String = ""
	if _model.selected_track >= 0 and _model.selected_track < _model.tracks.size():
		channel_text = " • " + _track_info(_model.tracks[_model.selected_track]).get_slice(" • ", 0)
	var clip_text: String = ""
	if _model.selected_clip_count() > 0:
		clip_text = " • %d clip%s selected" % [_model.selected_clip_count(), "" if _model.selected_clip_count() == 1 else "s"]
	var dirty_mark: String = "*" if _model.dirty or _project_state_dirty else ""
	_format_label.text = "%s%s • %d Hz%s%s" % [_project_name, dirty_mark, _model.sample_rate, channel_text, clip_text]
	_format_label.tooltip_text = _current_project_path if not _current_project_path.is_empty() else "Unsaved .gasproj project"


func _update_horizontal_scroll() -> void:
	var project_end: int = maxi(1, _model.project_end_frame())
	var page: int = mini(project_end, _waveform.visible_frame_count())
	_horizontal_scroll.max_value = float(project_end)
	_horizontal_scroll.page = float(page)
	_horizontal_scroll.set_value_no_signal(float(_waveform.view_start_frame))


func _invalidate_audio() -> void:
	_audio_revision += 1
	_prepared_playback_revision = -1
	if _streaming_playback or _native_source_playback:
		_player.stop()
		_reset_streaming_state()


func _begin_playback_prepare(start_frame: int, end_frame: int) -> bool:
	if _play_prepare_job != null:
		_status.text = "Playback is already being prepared…"
		return true
	_play_prepare_start_frame = start_frame
	_play_prepare_end_frame = end_frame
	_play_prepare_revision = _audio_revision
	_play_prepare_discard = false
	var playback_snapshot: GASEditorModel = _model.create_render_snapshot()
	var job: GASPlaybackPrepareJob = PlaybackPrepareJob.new() as GASPlaybackPrepareJob
	if job == null or not job.start(playback_snapshot, _play_prepare_revision):
		_status.text = "Could not start background playback preparation."
		return false
	_play_prepare_job = job
	_status.text = "Preparing effect-heavy playback in the background…"
	return true


func _process_playback_prepare() -> void:
	if _play_prepare_job == null or not _play_prepare_job.is_complete():
		return
	var completed: GASPlaybackPrepareJob = _play_prepare_job
	_play_prepare_job = null
	completed.finish()
	if _play_prepare_discard:
		_play_prepare_discard = false
		_status.text = "Playback preparation cancelled."
		return
	if not completed.ok:
		_status.text = "Could not prepare audio for playback."
		return
	if completed.revision != _audio_revision:
		_status.text = "Audio changed while playback was preparing; press Play again."
		return
	if completed.data.is_empty():
		_status.text = "Prepared playback contained no audio."
		return
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = completed.sample_rate
	wav.stereo = completed.stereo
	wav.data = completed.data
	_clear_bus_players()
	_player.stream = wav
	_prepared_playback_revision = _audio_revision
	_player.volume_db = 0.0
	_player.pitch_scale = _model.playback_speed
	_player.stream_paused = false
	_player.play(float(maxi(0, _play_prepare_start_frame)) / float(maxi(1, _model.sample_rate)))
	_play_selection_end_frame = _play_prepare_end_frame
	_play_loop_start_frame = maxi(0, _play_prepare_start_frame)
	_status.text = "Playing."


func _on_analyze_menu(id: int) -> void:
	match id:
		MENU_ANALYZE_PANEL:
			_on_show_analyzer()
		MENU_ANALYZE_SPECTRUM:
			_on_show_analyzer()
			_analyzer_panel.request_analysis(false)
		MENU_ANALYZE_SPECTROGRAM:
			_on_show_analyzer()
			_analyzer_panel.request_analysis(true)
		MENU_ANALYZE_BEATS:
			_on_show_analyzer()
			_analyzer_panel.request_beats()
		MENU_ANALYZE_SPECTRAL_EDIT:
			_on_show_spectral()


func _on_show_analyzer() -> void:
	if _analyzer_panel == null:
		return
	_show_aux_panel(_analyzer_panel)
	_status.text = "Analyzer ready. Analyze the selected track or mixdown; a time selection can limit the range."


func _on_analyzer_markers_requested(frames: PackedInt32Array, prefix: String) -> void:
	if frames.is_empty():
		return
	_model.add_markers_batch(frames, prefix)
	_refresh_all()
	_status.text = "Added %d %s markers." % [frames.size(), prefix.to_lower()]


func _on_analyzer_status_changed(message: String) -> void:
	_status.text = message


func _on_file_menu(id: int) -> void:
	match id:
		MENU_FILE_NEW_PROJECT:
			_guard_unsaved_project("new", "")
		MENU_FILE_OPEN_PROJECT:
			_project_open_dialog.popup_file_dialog()
		MENU_FILE_SAVE_PROJECT:
			_on_save_project()
		MENU_FILE_SAVE_AS:
			_on_save_project_as()
		MENU_FILE_IMPORT_WAV:
			_open_dialog.popup_file_dialog()
		MENU_FILE_RELINK:
			_show_missing_sources_dialog()
		MENU_FILE_PROJECT_SETTINGS:
			_show_project_settings()
		MENU_FILE_RECOVER_AUTOSAVE:
			_check_for_recovery(true)
		MENU_FILE_EXPORT:
			_export_dialog.current_file = "gas_mixdown.wav"
			if not _last_export_path.is_empty():
				_export_dialog.current_dir = _last_export_path.get_base_dir()
			_export_dialog.popup_file_dialog()


func _on_save_project() -> void:
	if _current_project_path.is_empty():
		_on_save_project_as()
		return
	_perform_project_save(_current_project_path)


func _on_save_project_as() -> void:
	var default_name: String = _project_name.strip_edges()
	if default_name.is_empty() or default_name == "Untitled":
		default_name = "audio_project"
	_project_save_dialog.current_file = default_name + ProjectPersistence.PROJECT_EXTENSION
	if not _current_project_path.is_empty():
		_project_save_dialog.current_dir = _current_project_path.get_base_dir()
	_project_save_dialog.popup_file_dialog()


func _on_project_open_selected(path: String) -> void:
	_guard_unsaved_project("open", path)


func _on_project_save_selected(path: String) -> void:
	_perform_project_save(path)


func _on_project_save_canceled() -> void:
	if _save_then_continue:
		_save_then_continue = false
		_pending_project_action = ""
		_pending_project_path = ""


func _perform_project_save(path: String) -> bool:
	if _project_io_job != null and _project_io_job.task_id >= 0:
		_status.text = "Project I/O is already running."
		return false
	var normalized: String = ProjectPersistence.normalize_project_path(path)
	if normalized.is_empty():
		_status.text = "Project save path is empty."
		return false
	if _project_name == "Untitled" or _project_name.strip_edges().is_empty():
		_project_name = normalized.get_file().get_basename()
	var job: GASProjectIOJob = ProjectIOJob.new() as GASProjectIOJob
	if job == null or not job.start_save(
		normalized,
		_model.create_persistence_snapshot(),
		_project_settings_state(),
		_editor_project_state(),
		_get_generator_project_state(),
		_get_workspace_project_state(),
		normalized,
		false,
		_project_name,
		_model.change_revision,
		_project_state_revision
	):
		_status.text = "Could not start background project save."
		return false
	_project_io_job = job
	_status.text = "Saving project in background…"
	return true


func _perform_autosave(on_exit: bool) -> void:
	if _model == null or (not _model.dirty and not _project_state_dirty) or not _autosave_enabled:
		return
	if _autosave_checkpoint_current() or (_project_io_job != null and _project_io_job.task_id >= 0):
		return
	var autosave_path: String = ProjectPersistence.autosave_path(_current_project_path)
	var job: GASProjectIOJob = ProjectIOJob.new() as GASProjectIOJob
	if job == null or not job.start_save(
		autosave_path,
		_model.create_persistence_snapshot(),
		_project_settings_state(),
		_editor_project_state(),
		_get_generator_project_state(),
		_get_workspace_project_state(),
		_current_project_path,
		true,
		_project_name,
		_model.change_revision,
		_project_state_revision
	):
		if not on_exit and _status != null:
			_status.text = "Could not start background autosave."
		return
	_project_io_job = job
	if not on_exit and _status != null:
		_status.text = "Autosaving recovery checkpoint in background…"


func _autosave_checkpoint_current() -> bool:
	if _model == null:
		return false
	return _last_autosave_model_revision == _model.change_revision and _last_autosave_project_state_revision == _project_state_revision


func _load_project_from_path(path: String, recovery: bool = false) -> bool:
	if _project_io_job != null and _project_io_job.task_id >= 0:
		_status.text = "Project I/O is already running."
		return false
	var job: GASProjectIOJob = ProjectIOJob.new() as GASProjectIOJob
	if job == null or not job.start_load(path, recovery):
		_status.text = "Could not start background project load."
		return false
	_project_io_job = job
	_status.text = "%s project in background…" % ("Recovering" if recovery else "Opening")
	return true


func _process_project_io_job() -> void:
	if _project_io_job == null or _project_io_job.task_id < 0 or not _project_io_job.is_complete():
		return
	var job: GASProjectIOJob = _project_io_job
	job.collect()
	_project_io_job = null
	if job.action == GASProjectIOJob.ACTION_LOAD:
		_commit_loaded_project(job.result, job.path, job.recovery)
		return
	if not bool(job.result.get("ok", false)):
		_status.text = "%s failed: %s" % ["Autosave" if job.action == GASProjectIOJob.ACTION_AUTOSAVE else "Project save", str(job.result.get("error", "Unknown error"))]
		if _save_then_continue:
			_save_then_continue = false
		return
	if job.action == GASProjectIOJob.ACTION_AUTOSAVE:
		_last_autosave_model_revision = job.model_revision
		_last_autosave_project_state_revision = job.project_state_revision
		_autosave_elapsed = 0.0
		_status.text = "Autosaved recovery checkpoint."
		return
	_current_project_path = str(job.result.get("path", job.path))
	var unchanged: bool = _model != null and _model.change_revision == job.model_revision and _project_state_revision == job.project_state_revision
	if unchanged:
		_model.dirty = false
		_project_state_dirty = false
	_last_autosave_model_revision = job.model_revision
	_last_autosave_project_state_revision = job.project_state_revision
	_autosave_elapsed = 0.0
	ProjectPersistence.clear_recovery()
	_update_selection_status()
	_status.text = "Saved project: %s%s" % [_current_project_path, "" if unchanged else " • project changed while saving"]
	if _save_then_continue:
		_save_then_continue = false
		if unchanged:
			_execute_pending_project_action()


func _commit_loaded_project(result: Dictionary, path: String, recovery: bool) -> bool:
	if not bool(result.get("ok", false)):
		_status.text = "Open project failed: %s" % str(result.get("error", "Unknown error"))
		return false
	_on_stop()
	var loaded_model: GASEditorModel = result.get("model") as GASEditorModel
	if loaded_model == null:
		_status.text = "Open project failed: project model could not be restored."
		return false
	_model = loaded_model
	_bind_model_to_editor_views()
	_apply_project_settings_state(_dictionary_from_variant(result.get("project_settings", {})))
	_apply_editor_project_state(_dictionary_from_variant(result.get("editor_state", {})))
	var generator_value: Variant = result.get("generator_state", {})
	if generator_value is Dictionary:
		_cached_generator_project_state = (generator_value as Dictionary).duplicate(true)
		if _generator_state_setter.is_valid():
			_generator_state_setter.call(generator_value as Dictionary)
	var workspace_value: Variant = result.get("workspace_state", {})
	if workspace_value is Dictionary:
		_cached_workspace_project_state = (workspace_value as Dictionary).duplicate(true)
		if _workspace_state_setter.is_valid():
			_workspace_state_setter.call(workspace_value as Dictionary)
	_missing_sources = _dictionary_array_from_variant(result.get("missing_sources", []))
	_offline_clip_count = int(result.get("offline_clip_count", 0))
	var migrated_from_version: int = int(result.get("migrated_from_version", 0))
	if recovery:
		_current_project_path = str(result.get("source_project_path", ""))
		_model.dirty = true
		_project_state_dirty = true
	else:
		_current_project_path = ProjectPersistence.normalize_project_path(path)
		_model.dirty = false
		_project_state_dirty = migrated_from_version > 0
	if _project_name.strip_edges().is_empty():
		_project_name = _current_project_path.get_file().get_basename() if not _current_project_path.is_empty() else "Recovered Project"
	_invalidate_audio()
	_refresh_all()
	_autosave_elapsed = 0.0
	if not _missing_sources.is_empty():
		_show_missing_sources_dialog()
	var recovery_note: String = "Recovered autosave" if recovery else "Opened project"
	var migration_note: String = " • upgraded from .gasproj v%d; save to commit v%d" % [migrated_from_version, ProjectPersistence.FORMAT_VERSION] if migrated_from_version > 0 else ""
	var missing_note: String = " • %d missing source%s" % [_missing_sources.size(), "" if _missing_sources.size() == 1 else "s"] if not _missing_sources.is_empty() else ""
	var offline_note: String = " • %d offline clip%s (restore the companion .gasdata folder or relink sources)" % [_offline_clip_count, "" if _offline_clip_count == 1 else "s"] if _offline_clip_count > 0 else ""
	_status.text = "%s: %s%s%s%s" % [recovery_note, _project_name, migration_note, missing_note, offline_note]
	return true


func _guard_unsaved_project(action: String, path: String) -> void:
	_pending_project_action = action
	_pending_project_path = path
	if _model != null and (_model.dirty or _project_state_dirty):
		_unsaved_dialog.popup_centered()
		return
	_execute_pending_project_action()


func _execute_pending_project_action() -> void:
	var action: String = _pending_project_action
	var path: String = _pending_project_path
	_pending_project_action = ""
	_pending_project_path = ""
	match action:
		"new":
			_create_new_project()
		"open":
			_load_project_from_path(path, false)
		"recover":
			_load_project_from_path(path, true)


func _on_unsaved_save_confirmed() -> void:
	if _current_project_path.is_empty():
		_save_then_continue = true
		_on_save_project_as()
		return
	_save_then_continue = true
	_perform_project_save(_current_project_path)


func _on_unsaved_custom_action(action: StringName) -> void:
	if str(action) != "discard":
		return
	_unsaved_dialog.hide()
	_execute_pending_project_action()


func _create_new_project() -> void:
	_on_stop()
	_model.clear()
	_model.sample_rate = 44100
	_model.finalize_project_load(1)
	_current_project_path = ""
	_project_name = "Untitled"
	_autosave_enabled = true
	_autosave_interval_seconds = 60.0
	_autosave_elapsed = 0.0
	_project_state_dirty = false
	_last_export_path = ""
	_missing_sources.clear()
	_offline_clip_count = 0
	ProjectPersistence.clear_recovery()
	_clear_generated_bin()
	_bind_model_to_editor_views()
	_waveform.set_view(0, 100.0)
	_invalidate_audio()
	_refresh_all()
	_status.text = "New Gator Audio project. Import audio, record, or send a generated sound to begin."


func _bind_model_to_editor_views() -> void:
	if _model == null:
		return
	_model.sanitize_track_selection()
	if _waveform != null:
		_waveform.set_model(_model)
	if _mixer_panel != null:
		_mixer_panel.set_model(_model)
	if _analyzer_panel != null:
		_analyzer_panel.set_model(_model)
	if _advanced_tools != null:
		Callable(_advanced_tools, "set_model").call(_model)


func _project_settings_state() -> Dictionary:
	return {
		"project_name": _project_name,
		"sample_rate": _model.sample_rate if _model != null else 44100,
		"autosave_enabled": _autosave_enabled,
		"autosave_interval_seconds": _autosave_interval_seconds,
		"shortcut_overrides": _model.shortcut_overrides.duplicate(true) if _model != null else {},
		"accessibility_settings": _model.accessibility_settings.duplicate(true) if _model != null else {},
	}


func _apply_project_settings_state(state: Dictionary) -> void:
	_project_name = str(state.get("project_name", "Untitled"))
	_autosave_enabled = bool(state.get("autosave_enabled", true))
	_autosave_interval_seconds = clampf(float(state.get("autosave_interval_seconds", 60.0)), 15.0, 600.0)
	if _model != null:
		_model.shortcut_overrides = (state.get("shortcut_overrides", {}) as Dictionary).duplicate(true)
		var accessibility_value: Variant = state.get("accessibility_settings", _model.accessibility_settings)
		if accessibility_value is Dictionary:
			_model.accessibility_settings = (accessibility_value as Dictionary).duplicate(true)
		_apply_accessibility_settings()


func _editor_project_state() -> Dictionary:
	var generated: Array[Dictionary] = []
	for entry: Dictionary in _generated_bin_entries:
		var wav: AudioStreamWAV = entry.get("wav") as AudioStreamWAV
		if wav != null:
			generated.append({"name": str(entry.get("name", "Generated")), "wav": wav})
	var aux_panel: String = ""
	if _effects_panel != null and _effects_panel.visible:
		aux_panel = "effects"
	elif _recording_panel != null and _recording_panel.visible:
		aux_panel = "recording"
	elif _mixer_panel != null and _mixer_panel.visible:
		aux_panel = "mixer"
	elif _analyzer_panel != null and _analyzer_panel.visible:
		aux_panel = "analyzer"
	elif _advanced_tools != null and _advanced_tools.visible:
		aux_panel = "advanced"
	return {
		"view_start_frame": _waveform.view_start_frame if _waveform != null else 0,
		"samples_per_pixel": _waveform.samples_per_pixel if _waveform != null else 100.0,
		"vertical_scroll": _wave_scroll.get_v_scroll_bar().value if _wave_scroll != null else 0.0,
		"aux_panel": aux_panel,
		"last_export_path": _last_export_path,
		"generated_bin": generated,
		"time_base_mode": _time_base_mode,
		"sample_draw": _sample_draw_toggle.button_pressed if _sample_draw_toggle != null else false,
		"scrub": _scrub_enabled,
		"transport_loop": _transport_loop_enabled,
		"spectral_low_hz": _spectral_low_hz,
		"spectral_high_hz": _spectral_high_hz,
	}


func _apply_editor_project_state(state: Dictionary) -> void:
	_last_export_path = str(state.get("last_export_path", ""))
	_clear_generated_bin()
	var generated_value: Variant = state.get("generated_bin", [])
	if generated_value is Array:
		var generated_array: Array = generated_value as Array
		for item: Variant in generated_array:
			if not (item is Dictionary):
				continue
			var entry: Dictionary = item as Dictionary
			var wav: AudioStreamWAV = entry.get("wav") as AudioStreamWAV
			if wav != null:
				_add_generated_bin_entry(wav, str(entry.get("name", "Generated")))
	var view_start: int = maxi(0, int(state.get("view_start_frame", 0)))
	var spp: float = clampf(float(state.get("samples_per_pixel", 100.0)), 0.02, 100000.0)
	_waveform.set_view(view_start, spp)
	_time_base_mode = str(state.get("time_base_mode", "Seconds"))
	if _time_base_option != null:
		for time_index: int in range(_time_base_option.item_count):
			if _time_base_option.get_item_text(time_index) == _time_base_mode:
				_time_base_option.select(time_index)
				break
	_waveform.set_time_base(_time_base_mode)
	var draw_enabled: bool = bool(state.get("sample_draw", false))
	if _sample_draw_toggle != null:
		_sample_draw_toggle.set_pressed_no_signal(draw_enabled)
	_waveform.set_sample_draw_mode(draw_enabled)
	_scrub_enabled = bool(state.get("scrub", false))
	if _scrub_toggle != null:
		_scrub_toggle.set_pressed_no_signal(_scrub_enabled)
	_transport_loop_enabled = bool(state.get("transport_loop", false))
	if _loop_toggle != null:
		_loop_toggle.set_pressed_no_signal(_transport_loop_enabled)
	_spectral_low_hz = maxf(0.0, float(state.get("spectral_low_hz", 0.0)))
	_spectral_high_hz = maxf(_spectral_low_hz, float(state.get("spectral_high_hz", 0.0)))
	if _waveform != null and _spectral_high_hz > _spectral_low_hz:
		_waveform.set_spectral_selection(_spectral_low_hz, _spectral_high_hz, true)
	if _playback_speed_spin != null:
		_playback_speed_spin.set_value_no_signal(_model.playback_speed)
	if _bpm_spin != null:
		_bpm_spin.set_value_no_signal(_model.project_bpm)
	if _snap_option != null:
		for snap_index: int in range(_snap_option.item_count):
			if _snap_option.get_item_text(snap_index) == _model.grid_snap_mode:
				_snap_option.select(snap_index)
				break
	var aux_panel: String = str(state.get("aux_panel", ""))
	match aux_panel:
		"effects": _show_aux_panel(_effects_panel)
		"recording": _show_aux_panel(_recording_panel)
		"mixer": _show_aux_panel(_mixer_panel)
		"analyzer": _show_aux_panel(_analyzer_panel)
		"advanced":
			var advanced: Control = _ensure_advanced_tools()
			_show_aux_panel(advanced)
		_: _show_aux_panel(null)
	call_deferred("_restore_project_scroll", float(state.get("vertical_scroll", 0.0)))


func _restore_project_scroll(value: float) -> void:
	if _left_scroll == null or _wave_scroll == null:
		return
	_left_scroll.get_v_scroll_bar().value = value
	_wave_scroll.get_v_scroll_bar().value = value


func _get_generator_project_state() -> Dictionary:
	if _generator_state_getter.is_valid():
		var value: Variant = _generator_state_getter.call()
		if value is Dictionary:
			_cached_generator_project_state = (value as Dictionary).duplicate(true)
	return _cached_generator_project_state.duplicate(true)


func _get_workspace_project_state() -> Dictionary:
	if _workspace_state_getter.is_valid():
		var value: Variant = _workspace_state_getter.call()
		if value is Dictionary:
			_cached_workspace_project_state = (value as Dictionary).duplicate(true)
	return _cached_workspace_project_state.duplicate(true)


func _show_project_settings() -> void:
	_project_name_edit.text = _project_name
	_autosave_toggle.button_pressed = _autosave_enabled
	_autosave_interval_spin.value = _autosave_interval_seconds
	_time_sig_num_spin.value = _model.time_signature_numerator
	_time_sig_den_spin.value = _model.time_signature_denominator
	_frame_rate_spin.value = _model.frame_rate
	_ui_scale_spin.value = float(_model.accessibility_settings.get("ui_scale", 1.0))
	_high_contrast_toggle.button_pressed = bool(_model.accessibility_settings.get("high_contrast", false))
	_strong_focus_toggle.button_pressed = bool(_model.accessibility_settings.get("strong_focus", true))
	_meter_text_toggle.button_pressed = bool(_model.accessibility_settings.get("meter_text", true))
	_project_settings_dialog.popup_centered()


func _on_project_settings_confirmed() -> void:
	var new_name: String = _project_name_edit.text.strip_edges()
	_project_name = new_name if not new_name.is_empty() else "Untitled"
	_autosave_enabled = _autosave_toggle.button_pressed
	_autosave_interval_seconds = clampf(float(_autosave_interval_spin.value), 15.0, 600.0)
	_model.time_signature_numerator = maxi(1, int(_time_sig_num_spin.value))
	_model.time_signature_denominator = maxi(1, int(_time_sig_den_spin.value))
	_model.frame_rate = maxf(1.0, float(_frame_rate_spin.value))
	_model.accessibility_settings = {
		"ui_scale": clampf(float(_ui_scale_spin.value), 0.75, 2.0),
		"high_contrast": _high_contrast_toggle.button_pressed,
		"strong_focus": _strong_focus_toggle.button_pressed,
		"meter_text": _meter_text_toggle.button_pressed,
	}
	_apply_accessibility_settings()
	_model.dirty = true
	_autosave_elapsed = 0.0
	_project_state_dirty = true
	_update_selection_status()
	_status.text = "Project settings updated."


func _check_for_recovery(force_show: bool = false) -> void:
	if _recovery_dialog == null:
		return
	var recovery: Dictionary = ProjectPersistence.read_recovery_manifest()
	if recovery.is_empty():
		if force_show and _status != null:
			_status.text = "No autosave recovery checkpoint is available."
		return
	_recovery_autosave_path = str(recovery.get("autosave_path", ""))
	var name: String = str(recovery.get("project_name", "Recovered Project"))
	var source: String = str(recovery.get("source_project_path", ""))
	var source_text: String = source if not source.is_empty() else "an unsaved project"
	_recovery_dialog.dialog_text = "A recovery checkpoint exists for %s.\n\nProject: %s\nSource: %s\n\nRecover it now?" % [name, name, source_text]
	_recovery_dialog.popup_centered()


func _on_recovery_confirmed() -> void:
	if _recovery_autosave_path.is_empty():
		return
	if _model != null and (_model.dirty or _project_state_dirty):
		_pending_project_action = "recover"
		_pending_project_path = _recovery_autosave_path
		_unsaved_dialog.popup_centered()
		return
	_load_project_from_path(_recovery_autosave_path, true)


func _on_recovery_custom_action(action: StringName) -> void:
	if str(action) != "discard":
		return
	_recovery_dialog.hide()
	ProjectPersistence.clear_recovery()
	_recovery_autosave_path = ""
	_status.text = "Recovery checkpoint discarded."


func _show_missing_sources_dialog() -> void:
	_missing_sources = ProjectPersistence.current_missing_sources(_model)
	_missing_sources_list.clear()
	for entry: Dictionary in _missing_sources:
		var path: String = str(entry.get("source_path", ""))
		var clip_count: int = int(entry.get("clip_count", 0))
		var item_index: int = _missing_sources_list.get_item_count()
		_missing_sources_list.add_item("%s  (%d clip%s)" % [path, clip_count, "" if clip_count == 1 else "s"])
		_missing_sources_list.set_item_metadata(item_index, path)
	if _missing_sources.is_empty():
		_missing_sources_dialog.hide()
		_status.text = "No missing source files."
		return
	_missing_sources_list.select(0)
	_missing_sources_dialog.popup_centered()


func _on_missing_sources_action(action: StringName) -> void:
	var action_text: String = str(action)
	if action_text == "search_folder":
		_missing_folder_dialog.popup_file_dialog()
		return
	if action_text != "relink":
		return
	var selected: PackedInt32Array = _missing_sources_list.get_selected_items()
	if selected.is_empty():
		return
	_relink_source_path = str(_missing_sources_list.get_item_metadata(selected[0]))
	_relink_dialog.current_file = _relink_source_path.get_file()
	_relink_dialog.popup_file_dialog()


func _on_relink_file_selected(path: String) -> void:
	if _relink_source_path.is_empty():
		return
	var result: Dictionary = ProjectPersistence.relink_source(_model, _relink_source_path, path)
	if bool(result.get("ok", false)):
		_status.text = "Relinked %d clip%s to %s." % [int(result.get("count", 0)), "" if int(result.get("count", 0)) == 1 else "s", str(result.get("path", path))]
		_relink_source_path = ""
		_invalidate_audio()
		_refresh_all()
		_show_missing_sources_dialog()
	else:
		_status.text = "Relink failed: %s" % str(result.get("error", "Unknown error"))


func _on_missing_folder_selected(folder: String) -> void:
	_missing_sources = ProjectPersistence.current_missing_sources(_model)
	var relinked_sources: int = 0
	var relinked_clips: int = 0
	for entry: Dictionary in _missing_sources:
		var old_path: String = str(entry.get("source_path", ""))
		var found: String = ProjectPersistence.search_for_filename(folder, old_path.get_file())
		if found.is_empty():
			continue
		var result: Dictionary = ProjectPersistence.relink_source(_model, old_path, found)
		if bool(result.get("ok", false)):
			relinked_sources += 1
			relinked_clips += int(result.get("count", 0))
	if relinked_sources > 0:
		_invalidate_audio()
		_refresh_all()
	_status.text = "Relink search found %d source%s for %d clip%s." % [relinked_sources, "" if relinked_sources == 1 else "s", relinked_clips, "" if relinked_clips == 1 else "s"]
	_show_missing_sources_dialog()


func _clear_generated_bin() -> void:
	if _generated_bin != null:
		for child: Node in _generated_bin.get_children():
			_generated_bin.remove_child(child)
			child.queue_free()
	_generated_bin_entries.clear()


func _dictionary_from_variant(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array_from_variant(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		var source_array: Array = value as Array
		for item: Variant in source_array:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


func _on_edit_menu(id: int) -> void:
	match id:
		MENU_EDIT_UNDO: _on_undo()
		MENU_EDIT_REDO: _on_redo()
		MENU_EDIT_CUT: _on_cut()
		MENU_EDIT_COPY: _on_copy()
		MENU_EDIT_PASTE: _on_paste()
		MENU_EDIT_DELETE: _on_delete()
		MENU_EDIT_DUPLICATE_CLIPS: _on_duplicate_clips()
		MENU_EDIT_SPLIT_DELETE: _on_split_delete()
		MENU_EDIT_SPLIT_CUT: _on_split_cut()
		MENU_EDIT_JOIN_CLIPS: _on_join_clips()
		MENU_EDIT_SPLIT_SELECTION: _on_split_selection()
		MENU_EDIT_SAMPLE_ZERO: _on_sample_edit_command("Zero")
		MENU_EDIT_SAMPLE_INTERPOLATE: _on_sample_edit_command("Interpolate")
		MENU_EDIT_SAMPLE_SMOOTH: _on_sample_edit_command("Smooth")
		MENU_EDIT_SAMPLE_REPAIR: _on_sample_edit_command("Repair")


func _on_sample_edit_command(mode: String) -> void:
	var action: int = GASEditorActionJob.ACTION_NONE
	match mode:
		"Zero": action = GASEditorActionJob.ACTION_MODEL_SAMPLE_ZERO
		"Interpolate": action = GASEditorActionJob.ACTION_MODEL_SAMPLE_INTERPOLATE
		"Smooth": action = GASEditorActionJob.ACTION_MODEL_SAMPLE_SMOOTH
		"Repair": action = GASEditorActionJob.ACTION_MODEL_SAMPLE_REPAIR
	if action == GASEditorActionJob.ACTION_NONE or _model.selected_clip_ids.is_empty() or not _model.has_selection():
		_status.text = "Select editable clip samples and a time range first."
		return
	_start_editor_model_action(action, "Sample-level %s applied." % mode.to_lower())


func _on_select_menu(id: int) -> void:
	match id:
		MENU_SELECT_ALL:
			_model.set_selection(0, _model.project_end_frame())
			_refresh_all()
		MENU_SELECT_ZERO:
			_on_zero_crossing()
		MENU_SELECT_ZERO_PREVIOUS:
			_on_zero_crossing_direction(-1)
		MENU_SELECT_ZERO_NEXT:
			_on_zero_crossing_direction(1)
		MENU_SELECT_ZERO_ENDPOINTS:
			_on_zero_crossing_endpoints()
		MENU_SELECT_ADD_MARKER:
			_on_add_marker()


func _on_track_menu(id: int) -> void:
	match id:
		MENU_TRACK_MERGE_DOWN:
			_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_MERGE_DOWN, "Merged selected track down.")
			return
		MENU_TRACK_RENDER_NEW:
			_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_RENDER_NEW, "Rendered selected track to a new track.")
			return
		MENU_TRACK_MIX_MONO:
			_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_MIX_MONO, "Mixed selected track to mono.")
			return
		MENU_TRACK_MIX_STEREO:
			_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_MIX_STEREO, "Mixed selected track to stereo.")
			return
		MENU_TRACK_ADD:
			_model.add_track("Audio Track %d" % (_model.tracks.size() + 1))
		MENU_TRACK_ADD_LABEL:
			_model.add_typed_track(GASEditorTrack.TYPE_LABEL, "Label Track")
		MENU_TRACK_ADD_AUTOMATION:
			_model.add_typed_track(GASEditorTrack.TYPE_AUTOMATION, "Automation Track")
		MENU_TRACK_ADD_GENERATED:
			_model.add_typed_track(GASEditorTrack.TYPE_GENERATED, "Generated Track")
		MENU_TRACK_ADD_REFERENCE:
			_model.add_typed_track(GASEditorTrack.TYPE_REFERENCE, "Reference Track")
		MENU_TRACK_DUPLICATE:
			_model.duplicate_selected_track()
		MENU_TRACK_UP:
			_model.move_selected_track(-1)
		MENU_TRACK_DOWN:
			_model.move_selected_track(1)
		MENU_TRACK_SORT:
			_model.sort_tracks_by_name()
		MENU_TRACK_REMOVE:
			_model.remove_selected_track()
		MENU_TRACK_SEPARATE_CLIPS:
			_on_separate_clips()
			return
	_invalidate_audio()
	_refresh_all()


func _on_placeholder_menu(_id: int) -> void:
	_status.text = "Use the dedicated GAS workspace/tool panel for this function."


func _on_view_menu(id: int) -> void:
	if id == MENU_VIEW_SHORTCUTS:
		_show_shortcut_settings()


func _show_shortcut_settings() -> void:
	for action_value: Variant in DEFAULT_SHORTCUTS.keys():
		var action: String = str(action_value)
		var edit: LineEdit = _shortcut_edits.get(action) as LineEdit
		if edit != null:
			edit.text = str(_model.shortcut_overrides.get(action, DEFAULT_SHORTCUTS[action]))
	_shortcut_dialog.popup_centered()


func _on_shortcuts_confirmed() -> void:
	var next: Dictionary = {}
	for action_value: Variant in DEFAULT_SHORTCUTS.keys():
		var action: String = str(action_value)
		var edit: LineEdit = _shortcut_edits.get(action) as LineEdit
		if edit == null:
			continue
		var text: String = edit.text.strip_edges()
		if text.is_empty():
			text = str(DEFAULT_SHORTCUTS[action])
		if int(OS.find_keycode_from_string(text)) == 0:
			_status.text = "Invalid shortcut: %s" % text
			return
		if text != str(DEFAULT_SHORTCUTS[action]):
			next[action] = text
	_model.shortcut_overrides = next
	_model.dirty = true; _project_state_dirty = true
	_status.text = "Shortcut settings updated."


func _on_shortcuts_custom_action(action: StringName) -> void:
	if str(action) != "reset":
		return
	_model.shortcut_overrides.clear()
	for action_value: Variant in DEFAULT_SHORTCUTS.keys():
		var key: String = str(action_value)
		var edit: LineEdit = _shortcut_edits.get(key) as LineEdit
		if edit != null:
			edit.text = str(DEFAULT_SHORTCUTS[key])
	_model.dirty = true; _project_state_dirty = true
	_status.text = "Shortcuts reset to defaults."


func _shortcut_matches(event: InputEventKey, action: String) -> bool:
	var spec: String = str(_model.shortcut_overrides.get(action, DEFAULT_SHORTCUTS.get(action, "")))
	var expected: int = int(OS.find_keycode_from_string(spec))
	return expected != 0 and int(event.get_keycode_with_modifiers()) == expected


func _apply_accessibility_settings() -> void:
	if _model == null:
		return
	var scale_value: float = clampf(float(_model.accessibility_settings.get("ui_scale", 1.0)), 0.75, 2.0)
	_apply_font_scale_recursive(self, maxi(9, int(round(13.0 * scale_value))))
	var strong_focus: bool = bool(_model.accessibility_settings.get("strong_focus", true))
	_apply_focus_recursive(self, strong_focus)
	var high_contrast: bool = bool(_model.accessibility_settings.get("high_contrast", false))
	_apply_contrast_recursive(self, high_contrast)
	if _waveform != null:
		_waveform.set_accessibility_high_contrast(high_contrast)
	if _mixer_panel != null:
		_mixer_panel.set_meter_text_enabled(bool(_model.accessibility_settings.get("meter_text", true)))


func _apply_font_scale_recursive(node: Node, size_value: int) -> void:
	if node is Label or node is Button or node is LineEdit or node is OptionButton or node is CheckButton or node is MenuButton:
		(node as Control).add_theme_font_size_override("font_size", size_value)
	elif node is RichTextLabel:
		(node as RichTextLabel).add_theme_font_size_override("normal_font_size", size_value)
	for child: Node in node.get_children():
		_apply_font_scale_recursive(child, size_value)


func _apply_focus_recursive(node: Node, enabled: bool) -> void:
	if node is BaseButton or node is LineEdit or node is SpinBox or node is OptionButton:
		(node as Control).focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_CLICK
	for child: Node in node.get_children():
		_apply_focus_recursive(child, enabled)


func _apply_contrast_recursive(node: Node, enabled: bool) -> void:
	if node is Label or node is BaseButton or node is LineEdit or node is OptionButton or node is CheckButton or node is MenuButton or node is ItemList or node is Tree:
		var control: Control = node as Control
		if enabled:
			control.add_theme_color_override("font_color", Color.WHITE)
			control.add_theme_color_override("font_focus_color", Color.WHITE)
		else:
			control.remove_theme_color_override("font_color")
			control.remove_theme_color_override("font_focus_color")
	elif node is RichTextLabel:
		var rich: RichTextLabel = node as RichTextLabel
		if enabled:
			rich.add_theme_color_override("default_color", Color.WHITE)
		else:
			rich.remove_theme_color_override("default_color")
	for child: Node in node.get_children():
		_apply_contrast_recursive(child, enabled)


func _refresh_effect_type_options() -> void:
	_effect_type_tokens = EffectEngine.available_effect_types()
	if _effect_type_option == null:
		return
	var current_type: String = _current_effect.effect_type if _current_effect != null else ""
	_effect_type_option.clear()
	var selected_index: int = 0
	for index: int in range(_effect_type_tokens.size()):
		var effect_type: String = _effect_type_tokens[index]
		_effect_type_option.add_item(EffectEngine.effect_display_name(effect_type))
		_effect_type_option.set_item_tooltip(index, EffectEngine.effect_description(effect_type))
		if effect_type == current_type:
			selected_index = index
	if not _effect_type_tokens.is_empty():
		_effect_type_option.select(selected_index)


func _refresh_extension_integrations() -> void:
	var previous_type: String = _current_effect.effect_type if _current_effect != null else ""
	_refresh_effect_type_options()
	_rebuild_effect_menu_popup()
	if _analyzer_panel != null and _analyzer_panel.has_method("refresh_extensions"):
		_analyzer_panel.refresh_extensions()
	if _advanced_tools != null and _advanced_tools.has_method("refresh_extensions"):
		_advanced_tools.call("refresh_extensions")
	if not previous_type.is_empty() and _effect_type_tokens.has(previous_type):
		return
	if not _effect_type_tokens.is_empty():
		_current_effect = EffectEngine.create_default(_effect_type_tokens[0])
		_refresh_effect_presets()
		_rebuild_effect_parameters()


func _show_extension_status() -> void:
	_ensure_extensions_dialog()
	_rebuild_extensions_dialog()
	var viewport_height: float = get_viewport_rect().size.y
	var dialog_height: int = int(clampf(viewport_height * 0.48, 300.0, 380.0))
	var dialog_size: Vector2i = Vector2i(760, dialog_height)
	# Do not show a freshly-created dialog in the same frame it is built.
	# Wait for one normal frame so its exact compact size can be applied before display.
	_extensions_dialog.hide()
	_extensions_dialog.size = dialog_size
	get_tree().process_frame.connect(
		_popup_extensions_dialog_exact.bind(dialog_size),
		CONNECT_ONE_SHOT
	)


func _popup_extensions_dialog_exact(dialog_size: Vector2i) -> void:
	if _extensions_dialog == null or not is_instance_valid(_extensions_dialog):
		return
	var parent_window: Window = get_window()
	var screen_index: int = DisplayServer.window_get_current_screen(parent_window.get_window_id())
	if screen_index == DisplayServer.INVALID_SCREEN:
		screen_index = DisplayServer.SCREEN_PRIMARY
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	var centered_offset: Vector2i = Vector2i(
		maxi(0, int((usable_rect.size.x - dialog_size.x) / 2.0)),
		maxi(0, int((usable_rect.size.y - dialog_size.y) / 2.0))
	)
	var dialog_position: Vector2i = usable_rect.position + centered_offset
	_extensions_dialog.size = dialog_size
	_extensions_dialog.popup(Rect2i(dialog_position, dialog_size))


func _ensure_extensions_dialog() -> void:
	if _extensions_dialog != null:
		return
	_extensions_dialog = AcceptDialog.new()
	_extensions_dialog.visible = false
	_extensions_dialog.force_native = true
	_extensions_dialog.wrap_controls = false
	_extensions_dialog.title = "Gator Audio Studio Extensions"
	_extensions_dialog.min_size = Vector2i(700, 280)
	_extensions_dialog.max_size = Vector2i(900, 520)
	_extensions_dialog.size = Vector2i(760, 360)
	_extensions_dialog.add_button("Reload", false, "reload")
	_extensions_dialog.add_button("Open Installed Folder", false, "open_folder")
	_extensions_dialog.custom_action.connect(_on_extensions_dialog_action)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	_extensions_dialog.add_child(root)
	_extensions_summary = Label.new()
	_extensions_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_extensions_summary)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660.0, 150.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_extensions_list = VBoxContainer.new()
	_extensions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extensions_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_extensions_list)
	var hint: Label = Label.new()
	hint.text = "Install packages under %s, then press Reload. Enable/disable changes apply immediately." % ExtensionManager.INSTALLED_ROOT
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.72, 0.75, 0.8)
	root.add_child(hint)
	add_child(_extensions_dialog)


func _rebuild_extensions_dialog() -> void:
	if _extensions_list == null or _extensions_summary == null:
		return
	for child: Node in _extensions_list.get_children():
		_extensions_list.remove_child(child)
		child.queue_free()
	var rows: Array[Dictionary] = ExtensionManager.extension_rows()
	_extensions_summary.text = "Extension API %d • %d installed • %d loaded • %d error(s)" % [ExtensionManager.API_VERSION, rows.size(), ExtensionManager.loaded_count(), ExtensionManager.load_errors().size()]
	if rows.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No GAS extensions are installed."
		empty_label.modulate = Color(0.75, 0.78, 0.82)
		_extensions_list.add_child(empty_label)
		return
	for row: Dictionary in rows:
		var panel: PanelContainer = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_extensions_list.add_child(panel)
		var content: VBoxContainer = VBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		panel.add_child(content)
		var header: HBoxContainer = HBoxContainer.new()
		content.add_child(header)
		var extension_id: StringName = StringName(str(row.get("id", "")))
		var enabled: CheckButton = CheckButton.new()
		enabled.text = str(row.get("name", extension_id))
		enabled.set_pressed_no_signal(bool(row.get("enabled", false)))
		enabled.disabled = str(extension_id).is_empty()
		enabled.tooltip_text = "Enable or disable this GAS extension package."
		enabled.toggled.connect(_on_extension_enabled_toggled.bind(extension_id))
		header.add_child(enabled)
		var spacer: Control = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		var version_label: Label = Label.new()
		version_label.text = "%s • %s" % [str(row.get("version", "")), str(row.get("status", "unknown"))]
		version_label.modulate = Color(0.72, 0.75, 0.8)
		header.add_child(version_label)
		var id_label: Label = Label.new()
		id_label.text = str(extension_id)
		id_label.modulate = Color(0.62, 0.66, 0.72)
		content.add_child(id_label)
		var description: String = str(row.get("description", ""))
		var error_text: String = str(row.get("error", ""))
		if not description.is_empty() or not error_text.is_empty():
			var detail: Label = Label.new()
			detail.text = error_text if not error_text.is_empty() else description
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.modulate = Color(0.95, 0.62, 0.58) if not error_text.is_empty() else Color(0.8, 0.82, 0.86)
			content.add_child(detail)


func _on_extension_enabled_toggled(enabled: bool, extension_id: StringName) -> void:
	if str(extension_id).is_empty():
		return
	ExtensionManager.set_extension_enabled(extension_id, enabled)
	_extension_revision = ExtensionManager.revision()
	_refresh_extension_integrations()
	_rebuild_extensions_dialog()
	_status.text = "%s extension '%s'." % ["Enabled" if enabled else "Disabled", str(extension_id)]


func _on_extensions_dialog_action(action: StringName) -> void:
	if action == &"reload":
		ExtensionManager.reload_all()
		_extension_revision = ExtensionManager.revision()
		_refresh_extension_integrations()
		_rebuild_extensions_dialog()
		_status.text = "Extensions reloaded: %d loaded, %d error(s)." % [ExtensionManager.loaded_count(), ExtensionManager.load_errors().size()]
	elif action == &"open_folder":
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(ExtensionManager.INSTALLED_ROOT))


func _on_help_menu(id: int) -> void:
	if id == MENU_HELP_GUIDE and _help_dialog != null:
		_help_dialog.popup_centered(Vector2i(760, 520))
	elif id == MENU_HELP_DONATE:
		OS.shell_open(SUPPORT_URL)


func show_extensions_manager() -> void:
	_show_extension_status()


func _start_wav_load_job(paths: PackedStringArray, purpose: String, context: Dictionary = {}) -> bool:
	if _pcm_io_job != null and _pcm_io_job.task_id >= 0:
		_status.text = "Audio file processing is already running."
		return false
	var job: GASPCMIOJob = PCMIOJob.new() as GASPCMIOJob
	if job == null or not job.start_load_wavs(paths, _model.sample_rate):
		_status.text = "Could not start background WAV import."
		return false
	_pcm_io_job = job
	_pcm_io_purpose = purpose
	_pcm_io_context = context.duplicate(true)
	_status.text = "Loading WAV audio in background…"
	return true


func _process_pcm_io_job() -> void:
	if _pcm_io_job == null or _pcm_io_job.task_id < 0 or not _pcm_io_job.is_complete():
		return
	var job: GASPCMIOJob = _pcm_io_job
	job.collect()
	_pcm_io_job = null
	var purpose: String = _pcm_io_purpose
	var context: Dictionary = _pcm_io_context
	_pcm_io_purpose = ""
	_pcm_io_context = {}
	if purpose == "recording":
		if not job.success or job.pcm_result == null:
			_status.text = "Recording captured audio, but background finalization failed."
			return
		_commit_finished_recording(job.pcm_result, bool(context.get("clipping", false)), context)
		return
	if not job.success:
		_status.text = "No compatible WAV PCM audio was loaded."
		return
	if purpose == "import":
		var path: String = job.loaded_paths[0] if not job.loaded_paths.is_empty() else ""
		var pcm: GASPCMData = job.pcm_results[0] if not job.pcm_results.is_empty() else null
		if pcm == null:
			return
		_model.add_pcm_as_track(pcm, path.get_file().get_basename(), path)
		_invalidate_audio()
		_refresh_all()
		_waveform.zoom_fit()
		_status.text = "Imported WAV: %s" % path.get_file()
		return
	if purpose == "drop":
		var insert_frame: int = int(context.get("frame", 0))
		var track_index: int = int(context.get("track", -1))
		var inserted: int = 0
		for index: int in range(job.pcm_results.size()):
			if index >= job.loaded_paths.size():
				break
			var pcm: GASPCMData = job.pcm_results[index]
			var path: String = job.loaded_paths[index]
			var target: int = _model.add_pcm_to_track(pcm, path.get_file().get_basename(), path, track_index, insert_frame)
			if target >= 0:
				inserted += 1
				insert_frame += pcm.frame_count()
		if inserted > 0:
			_invalidate_audio()
			_refresh_all()
		_status.text = "Dropped %d WAV file(s) onto track %d." % [inserted, track_index + 1]


func _on_open_wav_selected(path: String) -> void:
	var extension: String = path.get_extension().to_lower()
	if extension == "wav":
		_start_wav_load_job(PackedStringArray([path]), "import")
		return
	_begin_compressed_import(path)


func _begin_compressed_import(path: String) -> void:
	if _compressed_decode_session != null and not _compressed_decode_session.finished:
		_status.text = "A compressed audio import is already decoding."
		return
	var target_rate: int = _model.sample_rate
	var session: GASCompressedDecodeSession = CompressedAudioDecoder.begin_decode(path, target_rate)
	if session == null:
		_status.text = "Could not open compressed audio: %s" % path.get_file()
		return
	_compressed_decode_session = session
	_compressed_decode_path = path
	_compressed_decode_status_elapsed = 0.0
	_status.text = "Decoding %s… 0%%" % path.get_file()


func _process_compressed_decode(delta: float) -> void:
	if _compressed_decode_session == null:
		return
	if not _compressed_decode_session.finished:
		# AudioStreamPlayback decoding stays on the editor thread, but work is bounded
		# to a small time slice so long MP3/Ogg files cannot lock the editor.
		_compressed_decode_session.step(4500)
		_compressed_decode_status_elapsed += delta
		if _compressed_decode_status_elapsed >= 0.15:
			_compressed_decode_status_elapsed = 0.0
			_status.text = "Decoding %s… %d%%" % [_compressed_decode_path.get_file(), int(round(_compressed_decode_session.progress() * 100.0))]
	if not _compressed_decode_session.finished:
		return
	var session: GASCompressedDecodeSession = _compressed_decode_session
	var path: String = _compressed_decode_path
	_compressed_decode_session = null
	_compressed_decode_path = ""
	if session.failed:
		_status.text = "Could not decode compressed audio: %s%s" % [path.get_file(), " — " + session.error_message if not session.error_message.is_empty() else ""]
		return
	var pcm: GASPCMData = session.pcm_result()
	if pcm == null:
		_status.text = "Compressed audio produced no editable PCM: %s" % path.get_file()
		return
	var cache: GASWaveformCache = session.waveform_cache_result(pcm)
	_model.add_pcm_as_track(pcm, path.get_file().get_basename(), path, cache)
	_invalidate_audio()
	_refresh_all()
	_waveform.zoom_fit()
	_status.text = "Imported editable %s: %s" % [path.get_extension().to_upper(), path.get_file()]


func _load_compressed_stream(path: String) -> AudioStream:
	return CompressedAudioDecoder.load_stream(path)


func _on_export_path_selected(path: String) -> void:
	if _export_job != null and _export_job.task_id >= 0:
		_status.text = "An export is already running."
		return
	if _model == null or _model.project_end_frame() <= 0:
		_status.text = "Nothing to export."
		return
	var snapshot: GASEditorModel = _model.create_render_snapshot()
	var job: GASAudioRenderJob = RenderJob.new() as GASAudioRenderJob
	if not job.start_mix_to_file(snapshot, path):
		_status.text = "Could not start background export."
		return
	_export_job = job
	_export_job_last_progress_percent = -1
	_status.text = "Exporting mixdown in background… 0%"


func _process_export_job() -> void:
	if _export_job == null or _export_job.task_id < 0:
		return
	var progress_percent: int = clampi(int(round(_export_job.progress() * 100.0)), 0, 100)
	if progress_percent != _export_job_last_progress_percent:
		_export_job_last_progress_percent = progress_percent
		_status.text = "Rendering and exporting mixdown… %d%%" % progress_percent
	if not _export_job.is_complete():
		return
	var job: GASAudioRenderJob = _export_job
	job.collect()
	_export_job = null
	_export_job_last_progress_percent = -1
	if job.error != OK:
		_status.text = "Export failed: %s" % error_string(job.error)
		return
	_last_export_path = job.output_path
	_project_state_dirty = true
	_status.text = "Exported mixdown: %s" % job.output_path
	_update_editor_file(job.output_path)


func _update_editor_file(path: String) -> void:
	var localized: String = ProjectSettings.localize_path(path)
	if not localized.begins_with("res://") or not FileAccess.file_exists(localized):
		return
	if not _pending_editor_imports.has(localized):
		_pending_editor_imports.append(localized)
	# Never call EditorFileSystem.reimport_files() from call_deferred(). Godot's
	# import progress UI is not legal while the message queue is being flushed.
	# Queue the targeted import for a normal process frame instead.
	_editor_import_flush_queued = true
	_editor_import_wait_frames = maxi(_editor_import_wait_frames, 2)


func _process_editor_import_queue() -> void:
	if _editor_import_in_progress or not _editor_import_flush_queued:
		return
	if _editor_import_wait_frames > 0:
		_editor_import_wait_frames -= 1
		return
	if _pending_editor_imports.is_empty():
		_editor_import_flush_queued = false
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if filesystem == null:
		_pending_editor_imports.clear()
		_editor_import_flush_queued = false
		return
	if filesystem.is_scanning():
		return
	var import_paths: PackedStringArray = _pending_editor_imports.duplicate()
	_pending_editor_imports.clear()
	_editor_import_flush_queued = false
	var valid_paths: PackedStringArray = PackedStringArray()
	for localized: String in import_paths:
		if FileAccess.file_exists(localized):
			filesystem.update_file(localized)
			valid_paths.append(localized)
	if valid_paths.is_empty():
		return
	# reimport_files() is blocking and re-enters Node._process() while updating its
	# progress UI, so guard against recursively starting another import.
	_editor_import_in_progress = true
	filesystem.reimport_files(valid_paths)
	_editor_import_in_progress = false
	if not _pending_editor_imports.is_empty():
		_editor_import_flush_queued = true
		_editor_import_wait_frames = 2


func _on_play() -> void:
	var start_frame: int = clampi(_model.cursor_frame, 0, _model.project_end_frame())
	var end_frame: int = -1
	if _transport_loop_enabled:
		if _model.has_selection():
			start_frame = _model.selection_start
			end_frame = _model.selection_end
		elif _model.loop_end_frame > _model.loop_start_frame:
			start_frame = _model.loop_start_frame
			end_frame = _model.loop_end_frame
		else:
			end_frame = _model.project_end_frame()
	_start_playback(start_frame, end_frame)


func _on_play_selection() -> void:
	if not _model.has_selection():
		_on_play()
		return
	_start_playback(_model.selection_start, _model.selection_end)


func _on_play_to_selection() -> void:
	if not _model.has_selection():
		_on_play()
		return
	var start_frame: int = clampi(_model.cursor_frame, 0, _model.project_end_frame())
	var end_frame: int = _model.selection_end
	if start_frame < _model.selection_start:
		end_frame = _model.selection_start
	elif start_frame >= _model.selection_end:
		start_frame = _model.selection_start
		end_frame = _model.selection_end
	if end_frame <= start_frame:
		return
	_start_playback(start_frame, end_frame)


func _on_pause() -> void:
	if not _player.playing:
		return
	var paused: bool = not _player.stream_paused
	_player.stream_paused = paused
	for bus_player: AudioStreamPlayer in _bus_players:
		if is_instance_valid(bus_player):
			bus_player.stream_paused = paused
	for send_player: AudioStreamPlayer in _bus_send_players:
		if is_instance_valid(send_player):
			send_player.stream_paused = paused


func _on_stop() -> void:
	_bus_preview_job = null
	if _play_prepare_job != null:
		_play_prepare_discard = true
	_play_prepare_job = null
	_player.stop()
	_player.stream_paused = false
	_player.volume_db = 0.0
	_reset_streaming_state()
	_clear_bus_players()
	_play_selection_end_frame = -1
	_play_loop_start_frame = -1


func _on_skip_start() -> void:
	_model.cursor_frame = 0
	_model.selection_start = 0
	_model.selection_end = 0
	_update_selection_status()
	_waveform.queue_redraw()
	if _player.playing:
		if _streaming_playback or _native_source_playback:
			_start_playback(0, _play_selection_end_frame)
			return
		_player.seek(0.0)
		for bus_player: AudioStreamPlayer in _bus_players:
			if is_instance_valid(bus_player):
				bus_player.seek(0.0)
		for send_player: AudioStreamPlayer in _bus_send_players:
			if is_instance_valid(send_player):
				send_player.seek(0.0)


func _on_skip_end() -> void:
	_model.cursor_frame = _model.project_end_frame()
	_model.selection_start = _model.cursor_frame
	_model.selection_end = _model.cursor_frame
	_update_selection_status()
	_waveform.queue_redraw()


func _on_split() -> void:
	if _model.split_selected_at_cursor():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Split selected clips at cursor."
	else:
		_status.text = "Place the cursor inside a selected clip to split it."


func _on_split_selection() -> void:
	if _model.split_selected_at_selection():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Split selected clips at selection boundaries."
	else:
		_status.text = "Select clips and create a time selection first."


func _on_trim() -> void:
	if not _model.has_selection() or _model.selected_track < 0:
		_status.text = "Create a time selection on an editable track first."
		return
	_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_TRIM, "Trimmed selected track to selection.")


func _on_silence() -> void:
	if not _model.has_selection() or _model.selected_track < 0:
		_status.text = "Create a time selection on an editable track first."
		return
	_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_SILENCE, "Silenced selection.")


func _on_duplicate_clips() -> void:
	if _model.duplicate_selected_clips():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Duplicated selected clips."
	else:
		_status.text = "Select one or more clips first."


func _on_join_clips() -> void:
	if _model.selected_clip_ids.size() < 2:
		_status.text = "Join requires at least two selected clips on the same track."
		return
	_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_JOIN, "Joined selected clips. Overlaps were mixed into the joined clip.")


func _on_separate_clips() -> void:
	if _model.detach_selected_to_new_tracks():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Separated selected clips to new tracks."
	else:
		_status.text = "Select one or more clips first."


func _on_split_delete() -> void:
	if _model.split_delete_selection():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Split Delete: removed audio while preserving the timeline gap."
	else:
		_status.text = "Create a time selection on the selected track first."


func _on_split_cut() -> void:
	if _model.split_cut_selection():
		_invalidate_audio()
		_refresh_all()
		_status.text = "Split Cut: copied audio and preserved the timeline gap."
	else:
		_status.text = "Create a time selection on the selected track first."


func _on_add_marker() -> void:
	_model.add_marker(_model.cursor_frame, "Marker %d" % (_model.markers.size() + 1))
	_refresh_all()
	_status.text = "Added snap marker at cursor."


func _on_delete() -> void:
	if _model.selected_clip_count() > 0:
		if _model.delete_selected_clips():
			_invalidate_audio()
			_refresh_all()
			_status.text = "Deleted selected clips."
		return
	_model.delete_selection()
	_invalidate_audio()
	_refresh_all()
	_status.text = "Deleted time selection and closed the gap."


func _on_copy() -> void:
	if _model.selected_clip_count() > 0:
		if _model.copy_selected_clips():
			_status.text = "Copied selected clips."
		return
	if not _model.has_selection() or _model.selected_track < 0:
		_status.text = "Create a time selection on a track first."
		return
	_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_COPY, "Copied time selection.")


func _on_cut() -> void:
	if _model.selected_clip_count() > 0:
		if _model.cut_selected_clips():
			_invalidate_audio()
			_refresh_all()
			_status.text = "Cut selected clips."
		return
	if not _model.has_selection() or _model.selected_track < 0:
		_status.text = "Create a time selection on a track first."
		return
	_start_editor_model_action(GASEditorActionJob.ACTION_MODEL_CUT, "Cut time selection and closed the gap.")


func _on_paste() -> void:
	if not _model.clip_clipboard.is_empty():
		if _model.paste_clips_at_cursor():
			_invalidate_audio()
			_refresh_all()
			_status.text = "Pasted clips at cursor."
		return
	_model.paste_at_cursor()
	_invalidate_audio()
	_refresh_all()
	_status.text = "Pasted audio at cursor."


func _on_undo() -> void:
	var label: String = _model.undo()
	if not label.is_empty():
		_invalidate_audio()
		_refresh_all()
		if _effects_panel != null and _effects_panel.visible:
			_refresh_effect_rack()
		_status.text = "Undo: %s" % label


func _on_redo() -> void:
	var label: String = _model.redo()
	if not label.is_empty():
		_invalidate_audio()
		_refresh_all()
		if _effects_panel != null and _effects_panel.visible:
			_refresh_effect_rack()
		_status.text = "Redo: %s" % label


func _on_zero_crossing() -> void:
	var snapped: int = _model.nearest_zero_crossing(_model.cursor_frame)
	_model.cursor_frame = snapped
	if _model.has_selection():
		_model.selection_start = snapped
	else:
		_model.selection_start = snapped
		_model.selection_end = snapped
	_update_selection_status()
	_waveform.queue_redraw()
	_status.text = "Snapped to nearest zero crossing."


func _on_zero_crossing_direction(direction: int) -> void:
	var snapped: int = _model.zero_crossing(_model.cursor_frame, direction, 2048, true)
	_model.cursor_frame = snapped
	if _model.has_selection():
		_model.selection_start = snapped
	else:
		_model.selection_start = snapped; _model.selection_end = snapped
	_update_selection_status(); _waveform.queue_redraw()
	_status.text = "Snapped to %s zero crossing." % ("previous" if direction < 0 else "next")


func _on_zero_crossing_endpoints() -> void:
	if not _model.has_selection():
		_status.text = "Create a time selection first."
		return
	if _model.snap_selection_endpoints_to_zero_crossings(2048, true):
		_update_selection_status(); _waveform.queue_redraw()
		_status.text = "Snapped both selection endpoints to stereo-aware zero crossings."


func _on_zoom_in() -> void:
	_waveform.zoom_in(_model.cursor_frame)
	_update_horizontal_scroll()


func _on_zoom_out() -> void:
	_waveform.zoom_out(_model.cursor_frame)
	_update_horizontal_scroll()


func _on_zoom_fit() -> void:
	_waveform.zoom_fit()
	_update_horizontal_scroll()


func _on_wave_selection_changed(_start: int, _end: int) -> void:
	_update_selection_status()


func _on_wave_cursor_changed(frame: int) -> void:
	_model.cursor_frame = frame
	_update_selection_status()
	if _player.playing:
		if _streaming_playback or _native_source_playback:
			var streaming_end: int = _play_selection_end_frame if _play_selection_end_frame > frame else -1
			_start_playback(frame, streaming_end)
			return
		var seconds: float = float(frame) / float(maxi(1, _model.sample_rate))
		_player.seek(seconds)
		for bus_player: AudioStreamPlayer in _bus_players:
			if is_instance_valid(bus_player):
				bus_player.seek(seconds)
		for send_player: AudioStreamPlayer in _bus_send_players:
			if is_instance_valid(send_player):
				send_player.seek(seconds)
	elif _scrub_enabled and not _record_pending and (_recorder == null or not _recorder.recording):
		var scrub_frames: int = maxi(64, int(round(float(_model.sample_rate) * 0.075)))
		_start_playback(frame, mini(_model.project_end_frame(), frame + scrub_frames))


func _on_wave_track_selected(index: int) -> void:
	_model.select_track(index, false, false)
	_refresh_track_controls()
	_update_selection_status()
	_show_current_selection_message()
	if _effects_panel != null and _effects_panel.visible:
		_selected_rack_index = -1
		_refresh_effect_rack()


func _on_wave_clip_selection_changed() -> void:
	_refresh_track_controls()
	_update_selection_status()
	_show_current_selection_message()
	if _effects_panel != null and _effects_panel.visible:
		_selected_rack_index = -1
		_refresh_effect_rack()


func _on_wave_edit_committed(action: String) -> void:
	_invalidate_audio()
	_refresh_all()
	_status.text = action + ". Overlapping clips mix non-destructively during playback/export."


func _on_clip_context_requested(clip_id: int, screen_position: Vector2) -> void:
	_context_clip_id = clip_id
	_clip_context_menu.position = Vector2i(int(round(screen_position.x)), int(round(screen_position.y)))
	_clip_context_menu.popup()


func _on_clip_rename_requested(clip_id: int) -> void:
	_open_rename_dialog(clip_id)


func _on_clip_context_id(id: int) -> void:
	match id:
		CTX_RENAME:
			_open_rename_dialog(_context_clip_id)
		CTX_DUPLICATE:
			_on_duplicate_clips()
		CTX_CUT:
			_on_cut()
		CTX_COPY:
			_on_copy()
		CTX_DELETE:
			_on_delete()
		CTX_SPLIT:
			_on_split()
		CTX_JOIN:
			_on_join_clips()
		CTX_SEPARATE:
			_on_separate_clips()
		CTX_SPLIT_DELETE:
			_on_split_delete()
		CTX_SPLIT_CUT:
			_on_split_cut()
		CTX_SILENCE:
			_on_silence()
		CTX_TRIM:
			_on_trim()
		CTX_NORMALIZE:
			_apply_context_effect("Normalize")
		CTX_FADE_IN:
			_apply_context_effect("Fade In")
		CTX_FADE_OUT:
			_apply_context_effect("Fade Out")
		CTX_CROSSFADE:
			if _model.crossfade_selected_clips(50.0, 4):
				_invalidate_audio(); _refresh_all(); _status.text = "Applied equal-power crossfade to selected clips."
			else:
				_status.text = "Select exactly two clips to crossfade."
		CTX_REVERSE:
			_apply_context_effect("Reverse")
		CTX_GENERATE:
			if _workspace_state_setter.is_valid():
				_workspace_state_setter.call({"current_tab": 1})
		CTX_ANALYZE:
			_on_analyze_menu(MENU_ANALYZE_PANEL)
		CTX_EXPORT_SELECTION:
			var advanced: Control = _ensure_advanced_tools()
			if advanced != null:
				_show_aux_panel(advanced)
				Callable(advanced, "show_tab").call("Export")
		CTX_ADD_MARKER:
			_on_add_marker()
		CTX_EFFECTS:
			if not _model.is_clip_selected(_context_clip_id):
				_model.select_clip(_context_clip_id, false, false)
				_refresh_all()
			_on_show_effects_for_clips()


func _apply_context_effect(effect_type: String) -> void:
	if not _model.is_clip_selected(_context_clip_id):
		_model.select_clip(_context_clip_id, false, false)
	var effect: GASEffectData = EffectEngine.create_default(effect_type)
	if effect == null or _editor_action_job != null:
		return
	var snapshot: GASEditorModel = _model.create_persistence_snapshot()
	var job: GASEditorActionJob = EditorActionJob.new() as GASEditorActionJob
	if job == null or not job.start_effect_apply(snapshot, effect, 0, _model.change_revision):
		return
	_editor_action_job = job
	_editor_action_status = "%s applied." % effect_type
	_status.text = "Applying %s in background…" % effect_type


func _open_rename_dialog(clip_id: int) -> void:
	var clip: GASEditorClip = _model.find_clip(clip_id)
	if clip == null:
		return
	_context_clip_id = clip_id
	_rename_edit.text = clip.name
	_rename_edit.select_all()
	_rename_dialog.popup_centered(Vector2i(380, 120))
	_rename_edit.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	_rename_edit.focus_mode = Control.FOCUS_ALL
	if _rename_edit.get_focus_mode_with_override() != Control.FOCUS_NONE:
		_rename_edit.grab_focus()


func _on_rename_confirmed() -> void:
	if _model.rename_clip(_context_clip_id, _rename_edit.text):
		_refresh_all()
		_status.text = "Renamed clip."


func _on_files_dropped(paths: PackedStringArray, frame: int, track_index: int) -> void:
	var wav_paths: PackedStringArray = PackedStringArray()
	for path: String in paths:
		if path.get_extension().to_lower() == "wav":
			wav_paths.append(path)
	if wav_paths.is_empty():
		_status.text = "No compatible WAV files were dropped."
		return
	_start_wav_load_job(wav_paths, "drop", {"frame": frame, "track": track_index})


func _on_generated_audio_dropped(wav: AudioStreamWAV, suggested_name: String, frame: int, track_index: int) -> void:
	var pcm: GASPCMData = PCMData.from_wav(wav)
	if pcm == null:
		_status.text = "Generated audio could not be converted to editable PCM."
		return
	if not _model.tracks.is_empty() and pcm.sample_rate != _model.sample_rate:
		pcm = pcm.resample_to_rate(_model.sample_rate)
	if _model.add_pcm_to_track(pcm, suggested_name, "generated://" + suggested_name, track_index, frame) >= 0:
		_invalidate_audio()
		_refresh_all()
		_status.text = "Dropped generated sound '%s' onto track %d." % [suggested_name, track_index + 1]


func _on_wave_view_changed(start_frame: int, _spp: float) -> void:
	_horizontal_scroll.set_value_no_signal(float(start_frame))
	_update_horizontal_scroll()


func _on_waveform_resized() -> void:
	_update_horizontal_scroll()


func _on_horizontal_scroll_changed(value: float) -> void:
	_waveform.set_view(int(round(value)), _waveform.samples_per_pixel)


func _on_left_vertical_scroll(value: float) -> void:
	if _syncing_scroll:
		return
	_syncing_scroll = true
	_wave_scroll.get_v_scroll_bar().value = value
	_syncing_scroll = false


func _on_wave_vertical_scroll(value: float) -> void:
	if _syncing_scroll:
		return
	_syncing_scroll = true
	_left_scroll.get_v_scroll_bar().value = value
	_syncing_scroll = false


func _on_track_reorder(from_index: int, to_index: int) -> void:
	if _model.reorder_track(from_index, to_index):
		_invalidate_audio()
		_refresh_all()
		_status.text = "Track reordered."


func _on_track_delete(index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.select_track(index, false, false)
	_model.remove_selected_track()
	_invalidate_audio()
	_refresh_all()
	_status.text = "Track deleted."


func _on_track_collapsed(index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].collapsed = not _model.tracks[index].collapsed
	_model.dirty = true
	_refresh_all()


func _on_track_type_changed(item_index: int, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	var track: GASEditorTrack = _model.tracks[index]
	var new_type: int = clampi(item_index, GASEditorTrack.TYPE_AUDIO, GASEditorTrack.TYPE_REFERENCE)
	if track.track_type == new_type:
		return
	_model.push_undo("Change Track Type")
	track.track_type = new_type
	track.reference_read_only = new_type == GASEditorTrack.TYPE_REFERENCE
	if track.reference_read_only:
		track.locked = true
		track.record_armed = false
	elif track.locked and new_type != GASEditorTrack.TYPE_REFERENCE:
		track.locked = false
	_model.dirty = true
	_invalidate_audio()
	_refresh_all()


func _on_track_color_changed(color: Color, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].color = color
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_channel_mode_changed(item_index: int, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].channel_mode = clampi(item_index, GASEditorTrack.CHANNEL_AUTO, GASEditorTrack.CHANNEL_STEREO)
	_model.dirty = true
	_invalidate_audio()
	_waveform.queue_redraw()


func _on_track_locked(value: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	var track: GASEditorTrack = _model.tracks[index]
	if track.reference_read_only:
		track.locked = true
		return
	track.locked = value
	_model.dirty = true
	_refresh_track_controls()


func _on_track_sync_group_changed(value: float, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].sync_group = clampi(int(round(value)), 0, 32)
	_model.dirty = true


func _on_load_generated_track_settings(index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	var track: GASEditorTrack = _model.tracks[index]
	if track.track_type != GASEditorTrack.TYPE_GENERATED or track.generated_settings.is_empty():
		return
	if _generator_state_setter.is_valid():
		_generator_state_setter.call(track.generated_settings.duplicate(true))
	if _workspace_state_setter.is_valid():
		_workspace_state_setter.call({"current_tab": 1})
	_status.text = "Restored generator parameters from %s." % track.name


func _on_track_select_button(index: int) -> void:
	_model.select_track(index, false, false)
	_refresh_track_controls()
	_waveform.queue_redraw()
	_update_selection_status()
	_show_current_selection_message()


func _on_track_select_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
		return
	_model.select_track(index, mouse.ctrl_pressed, mouse.shift_pressed)
	_refresh_track_controls()
	_waveform.queue_redraw()
	_update_selection_status()
	_show_current_selection_message()


func _show_current_selection_message() -> void:
	if _status == null or _model == null:
		return
	var track_index: int = _model.primary_selected_track()
	if track_index < 0 or track_index >= _model.tracks.size():
		_status.text = "No track selected."
		return
	var track_name: String = _model.tracks[track_index].name
	var clip_count: int = _model.selected_clip_count()
	if clip_count > 0:
		_status.text = "Selected: %s • %d clip%s." % [track_name, clip_count, "" if clip_count == 1 else "s"]
	else:
		_status.text = "Selected track: %s." % track_name


func _on_track_wave_stereo_mode(mode: int, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].waveform_stereo_mode = clampi(mode, GASEditorTrack.WAVEFORM_SPLIT_STEREO, GASEditorTrack.WAVEFORM_COMBINED_STEREO)
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_wave_amplitude_mode(mode: int, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].waveform_amplitude_mode = clampi(mode, GASEditorTrack.AMPLITUDE_LINEAR, GASEditorTrack.AMPLITUDE_DB)
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_zero_line_toggled(enabled: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].show_zero_line = enabled
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_clipping_toggled(enabled: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].show_clipping = enabled
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_sample_rate_changed(value: float, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].sample_rate = clampi(int(round(value)), 4000, 192000)
	_model.dirty = true
	_project_state_dirty = true


func _on_track_display_mode(mode: int, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].display_mode = clampi(mode, GASEditorTrack.DISPLAY_WAVEFORM, GASEditorTrack.DISPLAY_COMBINED)
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_name_changed(text: String, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].name = text
	_model.dirty = true
	_waveform.queue_redraw()


func _on_track_mute(value: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].mute = value
	_model.dirty = true
	_invalidate_audio()


func _on_track_solo(value: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].solo = value
	_model.dirty = true
	_invalidate_audio()


func _on_track_gain(value: float, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].gain_db = value
	_model.dirty = true
	_invalidate_audio()


func _on_track_pan(value: float, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].pan = value
	_model.dirty = true
	_invalidate_audio()


func _on_reset_track_gain(index: int, slider: HSlider) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	slider.value = 0.0


func _on_reset_track_pan(index: int, slider: HSlider) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	slider.value = 0.0


func _on_record_toolbar() -> void:
	if _record_pending or (_recorder != null and _recorder.recording):
		_on_record_stop_requested()
		return
	if _recording_panel == null:
		return
	if _recording_panel.visible:
		_recording_panel.trigger_record()
	else:
		_on_show_recording()
		_status.text = "Recording panel opened. Configure the input/mode, then press Record; pressing the toolbar Record button again starts with those settings."


func _resolve_record_target_track() -> int:
	for index: int in range(_model.tracks.size()):
		if _model.tracks[index].record_armed:
			return index
	return _model.selected_track


func _on_record_requested(device_name: String, stereo: bool, mode: int, countdown_seconds: float, timer_seconds: float, compensation_ms: float, monitor: bool) -> void:
	if _recorder == null or _recording_panel == null:
		return
	if _calibration_active:
		_status.text = "Finish latency calibration before recording."
		return
	if not _recorder.audio_input_setting_enabled():
		_recording_panel.set_input_setting_enabled(false)
		_recording_panel.set_status("Audio input is disabled. Enable it, restart Godot, then record.")
		_status.text = "Audio input must be enabled in Project Settings before recording."
		return
	_record_device_name = device_name
	_record_stereo = stereo
	_record_mode = mode
	_record_timer_seconds = maxf(0.0, timer_seconds)
	_record_compensation_ms = compensation_ms
	_record_monitor = monitor
	_record_target_track = _resolve_record_target_track()
	_record_punch_end_frame = -1
	match _record_mode:
		GASRecordingPanel.RecordMode.NEW_TRACK, GASRecordingPanel.RecordMode.OVERDUB_NEW_TRACK:
			_record_start_frame = maxi(0, _model.cursor_frame)
		GASRecordingPanel.RecordMode.SELECTED_TRACK_AT_CURSOR:
			if _record_target_track < 0 or _record_target_track >= _model.tracks.size():
				_recording_panel.set_status("Select or arm a track first.")
				return
			_record_start_frame = maxi(0, _model.cursor_frame)
		GASRecordingPanel.RecordMode.APPEND_SELECTED_TRACK:
			if _record_target_track < 0 or _record_target_track >= _model.tracks.size():
				_recording_panel.set_status("Select or arm a track first.")
				return
			_record_start_frame = _model.tracks[_record_target_track].end_frame()
		GASRecordingPanel.RecordMode.PUNCH_SELECTION:
			if _record_target_track < 0 or _record_target_track >= _model.tracks.size() or not _model.has_selection():
				_recording_panel.set_status("Punch recording requires a selected/armed track and a time selection.")
				return
			_record_start_frame = _model.selection_start
			_record_punch_end_frame = _model.selection_end
		_:
			_record_start_frame = maxi(0, _model.cursor_frame)
	_record_pending = countdown_seconds > 0.0
	_recording_panel.set_recording_state(false, _record_pending)
	if _record_pending:
		_record_countdown_end_ms = Time.get_ticks_msec() + int(round(countdown_seconds * 1000.0))
		_recording_panel.set_status("Recording starts in %.1f s" % countdown_seconds)
	else:
		_begin_recording_now()


func _begin_recording_now() -> void:
	if _recorder == null or _recorder.recording:
		return
	var result: Error = _recorder.start_recording(_record_device_name, _record_stereo)
	if result != OK:
		if _recording_panel != null:
			_recording_panel.set_recording_state(false)
			_recording_panel.set_status("Could not activate audio input: %s" % error_string(result))
		_status.text = "Recording input error: %s" % error_string(result)
		return
	_record_pending = false
	if _recording_panel != null:
		_recording_panel.set_recording_state(true)
		_recording_panel.set_status("Recording %s at %d Hz..." % ["stereo" if _record_stereo else "mono", _recorder.sample_rate])
	if _record_monitor and _monitor_player != null and not _monitor_player.playing:
		_monitor_player.play()
	if _record_mode == GASRecordingPanel.RecordMode.OVERDUB_NEW_TRACK:
		_start_playback(_record_start_frame, -1)
	elif _record_mode == GASRecordingPanel.RecordMode.PUNCH_SELECTION:
		_start_playback(_record_start_frame, _record_punch_end_frame)
	_status.text = "Recording started."


func _on_record_stop_requested() -> void:
	if _record_pending:
		_record_pending = false
		if _recording_panel != null:
			_recording_panel.set_recording_state(false)
			_recording_panel.set_status("Countdown cancelled.")
		return
	if _calibration_active:
		_finish_latency_calibration()
		return
	_finish_recording()


func _finish_recording() -> void:
	if _recorder == null or not _recorder.recording:
		return
	if _pcm_io_job != null and _pcm_io_job.task_id >= 0:
		_status.text = "Another audio file-processing job is already running."
		return
	var keep_input: bool = _record_monitor
	if _recording_panel != null:
		keep_input = keep_input or _recording_panel.input_meter_enabled()
	var was_clipping: bool = _recorder.clipping
	var capture: GASRecordingCapture = _recorder.stop_recording_capture(keep_input)
	_on_stop()
	if _recording_panel != null:
		_recording_panel.set_recording_state(false)
		_recording_panel.update_record_time(0.0)
		_recording_panel.set_status("Finalizing recording in background…")
	if not _record_monitor and _monitor_player != null and _monitor_player.playing:
		_monitor_player.stop()
	if capture == null or capture.total_frames <= 0:
		if _recording_panel != null:
			_recording_panel.set_status("No input frames were captured.")
		_status.text = "Recording stopped, but no input frames were captured."
		return
	var target_rate: int = _model.sample_rate if not _model.tracks.is_empty() else capture.sample_rate
	var punch_target_frames: int = maxi(0, _record_punch_end_frame - _record_start_frame) if _record_mode == GASRecordingPanel.RecordMode.PUNCH_SELECTION else -1
	var job: GASPCMIOJob = PCMIOJob.new() as GASPCMIOJob
	if job == null or not job.start_recording_capture(capture, target_rate, _record_compensation_ms, punch_target_frames):
		_status.text = "Could not start background recording finalization."
		return
	_pcm_io_job = job
	_pcm_io_purpose = "recording"
	_pcm_io_context = {
		"clipping": was_clipping,
		"mode": _record_mode,
		"start_frame": _record_start_frame,
		"target_track": _record_target_track,
		"punch_end": _record_punch_end_frame,
		"compensation_ms": _record_compensation_ms,
	}
	_status.text = "Finalizing recording in background…"


func _commit_finished_recording(pcm: GASPCMData, was_clipping: bool, context: Dictionary) -> void:
	if pcm == null or pcm.frame_count() <= 0:
		_status.text = "Recording finalization produced no audio."
		return
	var rate: int = pcm.sample_rate
	var compensation_ms: float = float(context.get("compensation_ms", 0.0))
	var compensation_frames: int = int(round(compensation_ms * 0.001 * float(rate)))
	var clip_name: String = "Recording %02d" % _recording_serial
	_recording_serial += 1
	var mode: int = int(context.get("mode", GASRecordingPanel.RecordMode.NEW_TRACK))
	var start_frame: int = int(context.get("start_frame", 0))
	var target_track: int = int(context.get("target_track", -1))
	var punch_end: int = int(context.get("punch_end", -1))
	var changed: bool = false
	match mode:
		GASRecordingPanel.RecordMode.NEW_TRACK, GASRecordingPanel.RecordMode.OVERDUB_NEW_TRACK:
			var new_start: int = maxi(0, start_frame - compensation_frames)
			changed = _model.add_pcm_as_new_track_at(pcm, clip_name, "recording://%s" % clip_name, new_start, "Record Audio") >= 0
		GASRecordingPanel.RecordMode.SELECTED_TRACK_AT_CURSOR, GASRecordingPanel.RecordMode.APPEND_SELECTED_TRACK:
			var insert_start: int = maxi(0, start_frame - compensation_frames)
			changed = _model.add_pcm_to_track(pcm, clip_name, "recording://%s" % clip_name, target_track, insert_start) >= 0
		GASRecordingPanel.RecordMode.PUNCH_SELECTION:
			# Punch compensation/fit is already performed in GASPCMIOJob so a long
			# selection never triggers a second song-length copy on the editor thread.
			changed = _model.replace_track_region_with_pcm(target_track, start_frame, punch_end, pcm, clip_name, "Punch Record")
	if changed:
		_invalidate_audio()
		_refresh_all()
		if _mixer_panel != null:
			_mixer_panel.refresh()
		var clip_warning: String = " • INPUT CLIPPED" if was_clipping else ""
		var message: String = "Recorded %.2f s%s" % [pcm.duration_seconds(), clip_warning]
		if _recording_panel != null:
			_recording_panel.set_status(message)
		_status.text = message
	else:
		_status.text = "Recording captured audio, but it could not be inserted into the project."


func _refresh_input_devices() -> void:
	if _recorder == null or _recording_panel == null:
		return
	var devices: PackedStringArray = _recorder.input_devices()
	var selected: String = AudioServer.input_device
	_recording_panel.set_devices(devices, selected)
	_recording_panel.set_input_setting_enabled(_recorder.audio_input_setting_enabled())
	_refresh_latency_info()


func _refresh_latency_info() -> void:
	if _recording_panel == null:
		return
	var input_ms: float = 0.0
	if _recorder != null and _recorder.audio_input_setting_enabled():
		var rate: float = maxf(1.0, AudioServer.get_input_mix_rate())
		input_ms = float(AudioServer.get_input_buffer_length_frames()) * 1000.0 / rate
	var output_ms: float = AudioServer.get_output_latency() * 1000.0
	_recording_panel.set_latency_info(input_ms, output_ms)


func _on_enable_input_setting() -> void:
	if _recorder == null:
		return
	var result: Error = _recorder.enable_audio_input_setting()
	if result == OK:
		_recording_panel.set_input_setting_enabled(true)
		_recording_panel.set_status("Audio input setting enabled. Restart Godot once before using microphone input.")
		_status.text = "Enabled audio input in project.godot. Restart Godot once before recording."
	else:
		_recording_panel.set_status("Could not save Project Settings: %s" % error_string(result))


func _on_input_meter_toggled(enabled: bool) -> void:
	if _recorder == null:
		return
	if enabled:
		var result: Error = _recorder.activate(_recording_panel.current_device())
		if result != OK:
			_recording_panel.set_input_meter_enabled(false)
			_recording_panel.set_status("Could not activate input meter: %s" % error_string(result))
	else:
		if not _recorder.recording and not _recording_panel.monitor_enabled():
			_recorder.deactivate()


func _on_monitor_toggled(enabled: bool) -> void:
	if _recorder == null or _monitor_player == null:
		return
	if enabled:
		var result: Error = _recorder.activate(_recording_panel.current_device())
		if result != OK:
			_recording_panel.set_monitor_enabled(false)
			_recording_panel.set_status("Could not activate input monitoring: %s" % error_string(result))
			return
		_monitor_player.bus = "Master"
		if not _monitor_player.playing:
			_monitor_player.play()
	else:
		_monitor_player.stop()
		if not _recorder.recording and not _recording_panel.input_meter_enabled():
			_recorder.deactivate()


func _on_calibration_requested(device_name: String) -> void:
	if _recorder == null or _calibration_player == null or _calibration_active:
		return
	if _recorder.recording or _record_pending:
		_status.text = "Stop the current recording before latency calibration."
		return
	var result: Error = _recorder.start_recording(device_name, false)
	if result != OK:
		_recording_panel.set_status("Calibration input error: %s" % error_string(result))
		return
	var calibration_pcm: GASPCMData = _make_calibration_signal(_recorder.sample_rate)
	_calibration_player.stream = calibration_pcm.to_wav()
	_calibration_active = true
	_calibration_stop_ms = Time.get_ticks_msec() + int(round(CALIBRATION_CAPTURE_SECONDS * 1000.0))
	_recording_panel.set_recording_state(true)
	_recording_panel.set_status("Calibrating... route speaker output back to the selected input and keep the room quiet.")
	_calibration_player.play()


func _make_calibration_signal(sample_rate: int) -> GASPCMData:
	var rate: int = maxi(8000, sample_rate)
	var frames: int = int(round(0.45 * float(rate)))
	var lead: int = int(round(CALIBRATION_LEAD_SECONDS * float(rate)))
	var pulse_len: int = maxi(16, int(round(0.012 * float(rate))))
	var pcm: GASPCMData = PCMData.new()
	pcm.sample_rate = rate
	pcm.channels = 1
	pcm.left.resize(frames)
	for index: int in range(pulse_len):
		var envelope: float = 1.0 - float(index) / float(maxi(1, pulse_len))
		var phase: float = TAU * 1800.0 * float(index) / float(rate)
		var dst: int = lead + index
		if dst < frames:
			pcm.left[dst] = sin(phase) * envelope * 0.75
	return pcm


func _finish_latency_calibration() -> void:
	if not _calibration_active or _recorder == null:
		return
	_calibration_active = false
	_calibration_player.stop()
	var captured: GASPCMData = _recorder.stop_recording(_recording_panel.input_meter_enabled() or _recording_panel.monitor_enabled())
	_recording_panel.set_recording_state(false)
	if captured == null or captured.frame_count() == 0:
		_recording_panel.set_status("Calibration failed: no input was captured.")
		return
	var detected: int = _detect_calibration_pulse(captured)
	if detected < 0:
		_recording_panel.set_status("Calibration pulse was not detected. Increase speaker level or use a loopback path.")
		return
	var emitted_frame: int = int(round(CALIBRATION_LEAD_SECONDS * float(captured.sample_rate)))
	var round_trip_frames: int = maxi(0, detected - emitted_frame)
	var round_trip_ms: float = float(round_trip_frames) * 1000.0 / float(maxi(1, captured.sample_rate))
	_recording_panel.set_measured_round_trip(round_trip_ms)
	_recording_panel.set_status("Measured round-trip latency: %.1f ms. Press Use Measured to copy it to compensation." % round_trip_ms)
	_status.text = "Latency calibration measured %.1f ms round trip." % round_trip_ms


func _detect_calibration_pulse(pcm: GASPCMData) -> int:
	if pcm == null or pcm.frame_count() < 16:
		return -1
	var search_start: int = int(round(0.04 * float(pcm.sample_rate)))
	var window: int = maxi(8, int(round(0.004 * float(pcm.sample_rate))))
	var best_frame: int = -1
	var best_energy: float = 0.0
	var index: int = search_start
	while index + window < pcm.frame_count():
		var energy: float = 0.0
		for offset: int in range(window):
			var sample: float = pcm.left[index + offset]
			energy += sample * sample
		energy /= float(window)
		if energy > best_energy:
			best_energy = energy
			best_frame = index
		index += window
	if best_energy < 0.0004:
		return -1
	return best_frame


func _on_mixer_audio_changed() -> void:
	_invalidate_audio()
	_waveform.queue_redraw()


func _on_bus_preview_toggled(_enabled: bool) -> void:
	_on_stop()
	_invalidate_audio()
	_status.text = "Godot bus preview routes each track through its selected AudioServer bus and auditions configured sends. GAS master rack/limiter is used in normal preview/export, not bus-preview mode."


func _ensure_native_preview_bus() -> StringName:
	var bus_index: int = AudioServer.get_bus_index(NATIVE_PREVIEW_BUS)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, NATIVE_PREVIEW_BUS)
		AudioServer.set_bus_send(bus_index, StringName("Master"))
		_temporary_bus_names.append(NATIVE_PREVIEW_BUS)
	# This bus is plugin-owned. Keep exactly one inexpensive native limiter so
	# direct MP3/Ogg playback preserves the GAS master ceiling without returning
	# to per-sample GDScript mixing.
	while AudioServer.get_bus_effect_count(bus_index) > 0:
		AudioServer.remove_bus_effect(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1)
	var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
	limiter.ceiling_db = clampf(_model.master_limiter_ceiling_db, -20.0, -0.1)
	limiter.threshold_db = minf(0.0, limiter.ceiling_db + 1.0)
	AudioServer.add_bus_effect(bus_index, limiter)
	return StringName(NATIVE_PREVIEW_BUS)


func _on_temporary_buses_requested() -> void:
	var created: int = 0
	var desired: PackedStringArray = PackedStringArray(["GAS Preview", "GAS Send"])
	for bus_name: String in desired:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, StringName("Master"))
		_temporary_bus_names.append(bus_name)
		created += 1
	if _mixer_panel != null:
		_mixer_panel.refresh()
	if created > 0:
		_status.text = "Created %d temporary GAS bus(es). They are available in mixer routing for this editor session." % created
	else:
		_status.text = "Temporary GAS buses already exist."


func _remove_temporary_buses() -> void:
	for reverse_index: int in range(_temporary_bus_names.size() - 1, -1, -1):
		var bus_name: String = _temporary_bus_names[reverse_index]
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index > 0:
			AudioServer.remove_bus(bus_index)
	_temporary_bus_names = PackedStringArray()


func _is_valid_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


func _clear_bus_players() -> void:
	for player: AudioStreamPlayer in _bus_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_bus_players.clear()
	for player: AudioStreamPlayer in _bus_send_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_bus_send_players.clear()
	_bus_send_track_indices = PackedInt32Array()


func _has_solo_tracks() -> bool:
	for track: GASEditorTrack in _model.tracks:
		if track.solo:
			return true
	return false


func _start_bus_preview(start_frame: int, end_frame: int = -1) -> bool:
	_clear_bus_players()
	if _bus_preview_job != null and _bus_preview_job.task_id >= 0:
		_status.text = "Bus preview is already preparing."
		return true
	var snapshot: GASEditorModel = _model.create_render_snapshot()
	var job: GASBusPreviewJob = BusPreviewJob.new() as GASBusPreviewJob
	if job == null or not job.start(snapshot, _model.change_revision, start_frame, end_frame):
		_status.text = "Could not start background bus preview render."
		return false
	_bus_preview_job = job
	_status.text = "Preparing Godot bus preview in background…"
	return true


func _process_bus_preview_job() -> void:
	if _bus_preview_job == null or _bus_preview_job.task_id < 0 or not _bus_preview_job.is_complete():
		return
	var job: GASBusPreviewJob = _bus_preview_job
	job.collect()
	_bus_preview_job = null
	if _model == null or _model.change_revision != job.model_revision:
		_status.text = "Bus preview result discarded because the project changed."
		return
	if not job.success:
		_status.text = "Nothing to preview through project buses."
		return
	_clear_bus_players()
	var start_seconds: float = float(job.start_frame) / float(maxi(1, _model.sample_rate))
	for stream_index: int in range(job.track_streams.size()):
		if stream_index >= job.track_indices.size():
			break
		var track_index: int = job.track_indices[stream_index]
		if track_index < 0 or track_index >= _model.tracks.size():
			continue
		var track: GASEditorTrack = _model.tracks[track_index]
		var stream: AudioStreamWAV = job.track_streams[stream_index]
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = track.output_bus if _is_valid_bus(track.output_bus) else "Master"
		player.pitch_scale = _model.playback_speed
		add_child(player)
		_bus_players.append(player)
		player.play(start_seconds)
		if not track.send_bus.is_empty() and _is_valid_bus(track.send_bus):
			var send_player: AudioStreamPlayer = AudioStreamPlayer.new()
			send_player.stream = stream
			send_player.bus = track.send_bus
			var send_points: Array[Dictionary] = AutomationEngine.lane_points(track.automation_lanes, AutomationEngine.PARAM_SEND_DB)
			send_player.volume_db = AutomationEngine.value_at(send_points, job.start_frame, track.send_db) if not send_points.is_empty() else track.send_db
			send_player.pitch_scale = _model.playback_speed
			add_child(send_player)
			_bus_send_players.append(send_player)
			_bus_send_track_indices.append(track_index)
			send_player.play(start_seconds)
	if job.clock_stream != null:
		_player.stream = job.clock_stream
		_player.volume_db = -80.0
		_player.pitch_scale = _model.playback_speed
		_player.play(start_seconds)
	_play_selection_end_frame = job.end_frame
	_play_loop_start_frame = job.start_frame
	_status.text = "Playing through Godot project buses."


func _start_playback(start_frame: int, end_frame: int = -1) -> bool:
	var use_bus_preview: bool = _mixer_panel != null and _mixer_panel.bus_preview_enabled()
	if use_bus_preview:
		_reset_streaming_state()
		return _start_bus_preview(start_frame, end_frame)
	_clear_bus_players()
	# A single clean MP3/Ogg clip can be played by Godot's native compressed
	# stream decoder directly. This avoids GDScript PCM mixing entirely for the
	# common song-length editing case and cannot underrun due to editor-frame load.
	if _try_start_native_compressed_playback(start_frame, end_frame):
		return true
	# Edited/multitrack projects use worker-prefetched PCM streaming. Duration no
	# longer determines whether Play blocks or how much work the editor thread does.
	var streaming_candidate: GASPlaybackStreamer = PlaybackStreamer.new() as GASPlaybackStreamer
	if streaming_candidate != null and streaming_candidate.supports_model(_model):
		return _start_streaming_playback(streaming_candidate, start_frame, end_frame)
	_reset_streaming_state()
	# Stateful/offline effect graphs cannot use the real-time streamer. Never
	# render them synchronously: reuse a prepared stream or build it on a worker.
	if _prepared_playback_revision == _audio_revision and _player.stream != null:
		_player.volume_db = 0.0
		_player.pitch_scale = _model.playback_speed
		_player.stream_paused = false
		_player.play(float(maxi(0, start_frame)) / float(maxi(1, _model.sample_rate)))
		_play_selection_end_frame = end_frame
		_play_loop_start_frame = maxi(0, start_frame)
		return true
	return _begin_playback_prepare(start_frame, end_frame)


func _try_start_native_compressed_playback(start_frame: int, end_frame: int) -> bool:
	if _model == null or not _model.master_effect_stack.is_empty():
		return false
	var has_solo: bool = false
	for track: GASEditorTrack in _model.tracks:
		if track.solo:
			has_solo = true
			break
	var candidate_track: GASEditorTrack
	var candidate_clip: GASEditorClip
	var audible_clip_count: int = 0
	for track: GASEditorTrack in _model.tracks:
		if track.mute or (has_solo and not track.solo):
			continue
		if track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION:
			continue
		if not track.effect_stack.is_empty() or not track.automation_lanes.is_empty() or track.channel_mode != GASEditorTrack.CHANNEL_AUTO:
			return false
		for clip: GASEditorClip in track.clips:
			if clip.muted or clip.pcm == null or clip.frame_count() <= 0:
				continue
			audible_clip_count += 1
			if audible_clip_count > 1:
				return false
			candidate_track = track
			candidate_clip = clip
	if audible_clip_count != 1 or candidate_track == null or candidate_clip == null:
		return false
	if not CompressedAudioDecoder.is_compressed_path(candidate_clip.source_path):
		return false
	if not candidate_clip.effect_stack.is_empty() or candidate_clip.fade_in_samples > 0 or candidate_clip.fade_out_samples > 0:
		return false
	if absf(candidate_track.pan + candidate_clip.pan) > 0.0001:
		return false
	var clip_start: int = candidate_clip.timeline_start
	var clip_end: int = candidate_clip.end_frame()
	if start_frame < clip_start or start_frame >= clip_end:
		return false
	var requested_end: int = clip_end if end_frame < 0 else end_frame
	if requested_end > clip_end:
		return false
	var stream: AudioStream = CompressedAudioDecoder.load_stream(candidate_clip.source_path)
	if stream == null:
		return false
	_reset_streaming_state()
	var source_frame: int = candidate_clip.source_start_frame + (start_frame - clip_start)
	var seek_seconds: float = float(maxi(0, source_frame)) / float(maxi(1, _model.sample_rate))
	_player.stop()
	_native_source_previous_bus = _player.bus
	if _model.master_limiter_enabled:
		_player.bus = _ensure_native_preview_bus()
	_player.stream = stream
	_player.volume_db = _model.master_gain_db + candidate_track.gain_db + candidate_clip.gain_db
	_player.pitch_scale = _model.playback_speed
	_player.stream_paused = false
	_player.play(seek_seconds)
	_native_source_playback = true
	_native_source_origin_frame = start_frame
	_native_source_seek_seconds = seek_seconds
	_play_selection_end_frame = requested_end
	_play_loop_start_frame = start_frame
	_status.text = "Playing."
	return true


func _start_streaming_playback(streamer: GASPlaybackStreamer, start_frame: int, end_frame: int) -> bool:
	if _play_prepare_job != null:
		_play_prepare_discard = true
	_play_prepare_job = null
	_player.stop()
	_reset_streaming_state()
	streamer.configure(_model, start_frame, end_frame)
	if streamer.remaining_frames() <= 0:
		_status.text = "Nothing to play."
		return false
	# Render only a tiny startup block synchronously. Every subsequent chunk is
	# produced by a dedicated worker, so DSP cannot stall the editor/audio feeder.
	var initial_frames: PackedVector2Array = streamer.render_frames(STREAM_INITIAL_PREFILL_FRAMES)
	if initial_frames.is_empty():
		_status.text = "Nothing to play."
		return false
	_stream_prefetcher = PlaybackPrefetcher.new() as GASPlaybackPrefetcher
	if _stream_prefetcher == null or not _stream_prefetcher.start(streamer, _model.sample_rate):
		_stream_prefetcher = null
		_status.text = "Could not start playback prefetch worker."
		return false
	_stream_generator = AudioStreamGenerator.new()
	_stream_generator.mix_rate = float(maxi(8000, _model.sample_rate))
	_stream_generator.buffer_length = STREAM_BUFFER_SECONDS
	_player.stream = _stream_generator
	_player.volume_db = 0.0
	_player.pitch_scale = _model.playback_speed
	_player.stream_paused = false
	_player.play()
	_stream_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _stream_playback == null:
		_player.stop()
		_reset_streaming_state()
		return false
	_stream_playback.push_buffer(initial_frames)
	_stream_mixer = streamer
	_streaming_playback = true
	_stream_origin_frame = maxi(0, start_frame)
	_stream_feed_finished = false
	_stream_last_skip_count = _stream_playback.get_skips()
	_play_selection_end_frame = streamer.end_frame()
	_play_loop_start_frame = maxi(0, start_frame)
	_feed_streaming_playback()
	_status.text = "Playing."
	return true


func _process_streaming_playback() -> void:
	if not _streaming_playback or _stream_playback == null or _stream_prefetcher == null:
		return
	if not _player.playing or _player.stream_paused:
		return
	_feed_streaming_playback()
	var skips: int = _stream_playback.get_skips()
	if skips > _stream_last_skip_count:
		_stream_last_skip_count = skips
		_status.text = "Playback buffer recovered from %d underrun%s." % [skips, "" if skips == 1 else "s"]


func _feed_streaming_playback() -> void:
	if _stream_playback == null or _stream_prefetcher == null:
		return
	var available: int = _stream_playback.get_frames_available()
	while available > 0:
		var frames: PackedVector2Array = _stream_prefetcher.pop_chunk_if_fits(available)
		if frames.is_empty():
			break
		if not _stream_playback.push_buffer(frames):
			break
		available -= frames.size()
	if _stream_prefetcher.is_drained():
		_stream_feed_finished = true


func _reset_streaming_state(wait_for_worker: bool = true) -> void:
	if _stream_prefetcher != null:
		if wait_for_worker:
			_stream_prefetcher.stop()
		else:
			_stream_prefetcher.request_stop()
	_stream_prefetcher = null
	_streaming_playback = false
	_stream_playback = null
	_stream_generator = null
	_stream_mixer = null
	_stream_origin_frame = 0
	_stream_feed_finished = false
	_stream_last_skip_count = 0
	if _native_source_playback and _player != null:
		_player.bus = _native_source_previous_bus
	_native_source_playback = false
	_native_source_origin_frame = 0
	_native_source_seek_seconds = 0.0
	_native_source_previous_bus = &"Master"


func _current_playback_frame() -> int:
	if _player == null or _model == null:
		return 0
	var playback_seconds: float = _player.get_playback_position()
	if _native_source_playback:
		var elapsed_seconds: float = maxf(0.0, playback_seconds - _native_source_seek_seconds)
		return _native_source_origin_frame + int(round(elapsed_seconds * float(maxi(1, _model.sample_rate))))
	var relative_frame: int = int(round(playback_seconds * float(maxi(1, _model.sample_rate))))
	return _stream_origin_frame + relative_frame if _streaming_playback else relative_frame


func _build_live_analysis_window(center_frame: int, frame_count: int) -> GASPCMData:
	if _model == null or frame_count <= 0:
		return null
	var start_frame: int = maxi(0, center_frame - frame_count / 2)
	var output: GASPCMData = GASPCMData.new()
	output.sample_rate = _model.sample_rate
	output.channels = 2
	output.left.resize(frame_count)
	output.right.resize(frame_count)
	var has_solo: bool = false
	for track: GASEditorTrack in _model.tracks:
		if track.solo:
			has_solo = true
			break
	var out_left: PackedFloat32Array = output.left
	var out_right: PackedFloat32Array = output.right
	for track: GASEditorTrack in _model.tracks:
		if track.mute or (has_solo and not track.solo):
			continue
		if track.track_type == GASEditorTrack.TYPE_LABEL or track.track_type == GASEditorTrack.TYPE_AUTOMATION:
			continue
		var track_gain: float = db_to_linear(track.gain_db)
		for clip: GASEditorClip in track.clips:
			if clip.pcm == null or clip.muted:
				continue
			var overlap_start: int = maxi(start_frame, clip.timeline_start)
			var overlap_end: int = mini(start_frame + frame_count, clip.end_frame())
			if overlap_end <= overlap_start:
				continue
			var source_base: int = clip.source_start_frame + (overlap_start - clip.timeline_start)
			var destination_base: int = overlap_start - start_frame
			var pan_value: float = clampf(track.pan + clip.pan, -1.0, 1.0)
			var gain: float = track_gain * db_to_linear(clip.gain_db)
			var left_gain: float = gain * (1.0 if pan_value <= 0.0 else 1.0 - pan_value)
			var right_gain: float = gain * (1.0 if pan_value >= 0.0 else 1.0 + pan_value)
			var clip_left: PackedFloat32Array = clip.pcm.left
			var clip_right: PackedFloat32Array = clip.pcm.right
			var stereo: bool = clip.pcm.is_stereo()
			for offset: int in range(overlap_end - overlap_start):
				var source_index: int = source_base + offset
				if source_index < 0 or source_index >= clip_left.size():
					continue
				var destination: int = destination_base + offset
				var left_value: float = clip_left[source_index]
				var right_value: float = clip_right[source_index] if stereo and source_index < clip_right.size() else left_value
				out_left[destination] += left_value * left_gain
				out_right[destination] += right_value * right_gain
	return output


func _meter_db(value: float) -> float:
	if value <= 0.000001:
		return -60.0
	return maxf(-60.0, linear_to_db(value))


func _pcm_meter(pcm: GASPCMData, center_frame: int, window_frames: int = 2048) -> Vector4:
	if pcm == null or pcm.frame_count() == 0:
		return Vector4(-60.0, -60.0, -60.0, -60.0)
	var half: int = maxi(1, window_frames / 2)
	var start: int = clampi(center_frame - half, 0, pcm.frame_count())
	var finish: int = clampi(center_frame + half, start, pcm.frame_count())
	if finish <= start:
		start = maxi(0, pcm.frame_count() - mini(window_frames, pcm.frame_count()))
		finish = pcm.frame_count()
	var peak_l: float = 0.0
	var peak_r: float = 0.0
	var sum_l: float = 0.0
	var sum_r: float = 0.0
	var count: int = maxi(1, finish - start)
	for index: int in range(start, finish):
		var left_value: float = pcm.left[index]
		var right_value: float = pcm.right[index] if pcm.is_stereo() else left_value
		peak_l = maxf(peak_l, absf(left_value))
		peak_r = maxf(peak_r, absf(right_value))
		sum_l += left_value * left_value
		sum_r += right_value * right_value
	return Vector4(_meter_db(peak_l), _meter_db(peak_r), _meter_db(sqrt(sum_l / float(count))), _meter_db(sqrt(sum_r / float(count))))


func _update_send_automation() -> void:
	if not _player.playing or _bus_send_players.is_empty():
		return
	var frame: int = _current_playback_frame()
	var count: int = mini(_bus_send_players.size(), _bus_send_track_indices.size())
	for index: int in range(count):
		var player: AudioStreamPlayer = _bus_send_players[index]
		var track_index: int = _bus_send_track_indices[index]
		if not is_instance_valid(player) or track_index < 0 or track_index >= _model.tracks.size():
			continue
		var track: GASEditorTrack = _model.tracks[track_index]
		var points: Array[Dictionary] = AutomationEngine.lane_points(track.automation_lanes, AutomationEngine.PARAM_SEND_DB)
		if not points.is_empty():
			player.volume_db = AutomationEngine.value_at(points, frame, track.send_db)


func _update_mixer_meters() -> void:
	if _mixer_panel == null or not _mixer_panel.visible:
		return
	var frame: int = _model.cursor_frame
	if _player != null and _player.playing and _model.sample_rate > 0:
		frame = _current_playback_frame()
	# Metering must remain bounded regardless of project duration/effect state.
	# Never trigger a full-track render merely to refresh a meter.
	var track_meters: Array[Vector4] = []
	for track_index: int in range(_model.tracks.size()):
		track_meters.append(_fast_track_meter(track_index, frame))
	var master_meter: Vector4 = _combine_fast_meters(track_meters)
	var clipping: bool = master_meter.x >= -0.01 or master_meter.y >= -0.01
	_mixer_panel.update_meters(track_meters, master_meter, clipping)


func _fast_track_meter(track_index: int, center_frame: int, window_frames: int = 2048) -> Vector4:
	if track_index < 0 or track_index >= _model.tracks.size():
		return Vector4(-60.0, -60.0, -60.0, -60.0)
	var track: GASEditorTrack = _model.tracks[track_index]
	if track.mute:
		return Vector4(-60.0, -60.0, -60.0, -60.0)
	var half: int = maxi(1, window_frames / 2)
	var start_frame: int = maxi(0, center_frame - half)
	var end_frame: int = start_frame + window_frames
	var active_clips: Array[GASEditorClip] = []
	var gains: PackedFloat32Array = PackedFloat32Array()
	var left_pans: PackedFloat32Array = PackedFloat32Array()
	var right_pans: PackedFloat32Array = PackedFloat32Array()
	var track_gain: float = db_to_linear(track.gain_db)
	for clip: GASEditorClip in track.clips:
		if clip.pcm == null or clip.muted or clip.end_frame() <= start_frame or clip.timeline_start >= end_frame:
			continue
		active_clips.append(clip)
		var gain: float = track_gain * db_to_linear(clip.gain_db)
		var pan_value: float = clampf(track.pan + clip.pan, -1.0, 1.0)
		gains.append(gain)
		left_pans.append(1.0 if pan_value <= 0.0 else 1.0 - pan_value)
		right_pans.append(1.0 if pan_value >= 0.0 else 1.0 + pan_value)
	if active_clips.is_empty():
		return Vector4(-60.0, -60.0, -60.0, -60.0)
	var peak_l: float = 0.0
	var peak_r: float = 0.0
	var sum_l: float = 0.0
	var sum_r: float = 0.0
	var sample_count: int = 0
	for timeline_frame: int in range(start_frame, end_frame):
		var mixed_l: float = 0.0
		var mixed_r: float = 0.0
		for active_index: int in range(active_clips.size()):
			var clip: GASEditorClip = active_clips[active_index]
			if timeline_frame < clip.timeline_start or timeline_frame >= clip.end_frame():
				continue
			var source_index: int = clip.source_start_frame + (timeline_frame - clip.timeline_start)
			var clip_pcm: GASPCMData = clip.pcm
			if clip_pcm == null or source_index < 0 or source_index >= clip_pcm.left.size():
				continue
			var left_value: float = clip_pcm.left[source_index]
			var right_value: float = clip_pcm.right[source_index] if clip_pcm.is_stereo() and source_index < clip_pcm.right.size() else left_value
			var gain_value: float = gains[active_index]
			mixed_l += left_value * gain_value * left_pans[active_index]
			mixed_r += right_value * gain_value * right_pans[active_index]
		peak_l = maxf(peak_l, absf(mixed_l))
		peak_r = maxf(peak_r, absf(mixed_r))
		sum_l += mixed_l * mixed_l
		sum_r += mixed_r * mixed_r
		sample_count += 1
	var divisor: float = float(maxi(1, sample_count))
	return Vector4(_meter_db(peak_l), _meter_db(peak_r), _meter_db(sqrt(sum_l / divisor)), _meter_db(sqrt(sum_r / divisor)))


func _combine_fast_meters(track_meters: Array[Vector4]) -> Vector4:
	var peak_l: float = 0.0
	var peak_r: float = 0.0
	var rms_l_sq: float = 0.0
	var rms_r_sq: float = 0.0
	for meter: Vector4 in track_meters:
		peak_l = maxf(peak_l, db_to_linear(meter.x))
		peak_r = maxf(peak_r, db_to_linear(meter.y))
		var rms_l: float = db_to_linear(meter.z)
		var rms_r: float = db_to_linear(meter.w)
		rms_l_sq += rms_l * rms_l
		rms_r_sq += rms_r * rms_r
	return Vector4(_meter_db(peak_l), _meter_db(peak_r), _meter_db(sqrt(rms_l_sq)), _meter_db(sqrt(rms_r_sq)))


func _on_track_arm(value: bool, index: int) -> void:
	if index < 0 or index >= _model.tracks.size():
		return
	_model.tracks[index].record_armed = value
	if value:
		_model.select_track(index, false, false)
	_model.dirty = true
	if _mixer_panel != null and _mixer_panel.visible:
		_mixer_panel.refresh()




func _input(event: InputEvent) -> void:
	# Editor-level edit shortcuts such as Ctrl+C/Delete may be consumed by Godot before
	# _shortcut_input() is reached. Intercept only those early so normal focused-button
	# keyboard behavior (Space/Enter/etc.) remains untouched.
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var keycode: int = int(key_event.keycode)
	if not key_event.ctrl_pressed and not key_event.meta_pressed and keycode != KEY_DELETE:
		return
	_route_editor_shortcut(event)


func _shortcut_input(event: InputEvent) -> void:
	# Dedicated shortcut stage; kept in addition to _input() so pushed Shortcut events
	# and normal key events use the same command path.
	_route_editor_shortcut(event)


func _unhandled_key_input(event: InputEvent) -> void:
	# Fallback for platforms/input paths that reach the unhandled-key stage.
	_route_editor_shortcut(event)


func _route_editor_shortcut(event: InputEvent) -> bool:
	if not is_inside_tree() or not is_visible_in_tree() or not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var focus: Control = viewport.gui_get_focus_owner()
	# Never steal editing shortcuts from text/numeric entry controls.
	if focus is LineEdit or focus is TextEdit or focus is SpinBox or focus is RichTextLabel:
		return false
	var handled: bool = true
	if _shortcut_matches(key_event, "new_project"):
		_guard_unsaved_project("new", "")
	elif _shortcut_matches(key_event, "open_project"):
		_project_open_dialog.popup_file_dialog()
	elif _shortcut_matches(key_event, "save_as"):
		_on_save_project_as()
	elif _shortcut_matches(key_event, "save_project"):
		_on_save_project()
	elif _shortcut_matches(key_event, "undo"):
		_on_undo()
	elif _shortcut_matches(key_event, "redo"):
		_on_redo()
	elif _shortcut_matches(key_event, "cut"):
		_on_cut()
	elif _shortcut_matches(key_event, "copy"):
		_on_copy()
	elif _shortcut_matches(key_event, "paste"):
		_on_paste()
	elif _shortcut_matches(key_event, "duplicate"):
		_on_duplicate_clips()
	elif _shortcut_matches(key_event, "play_stop"):
		_on_stop() if _player.playing else _on_play()
	elif _shortcut_matches(key_event, "record"):
		_on_record_toolbar()
	elif _shortcut_matches(key_event, "delete"):
		_on_delete()
	elif _shortcut_matches(key_event, "split"):
		_on_split()
	elif _shortcut_matches(key_event, "loop"):
		_transport_loop_enabled = not _transport_loop_enabled
		if _loop_toggle != null:
			_loop_toggle.set_pressed_no_signal(_transport_loop_enabled)
		_project_state_dirty = true
		_status.text = "Loop playback enabled." if _transport_loop_enabled else "Loop playback disabled."
	elif _shortcut_matches(key_event, "project_start"):
		_on_skip_start()
	elif _shortcut_matches(key_event, "project_end"):
		_on_skip_end()
	elif _shortcut_matches(key_event, "zoom_in"):
		_on_zoom_in()
	elif _shortcut_matches(key_event, "zoom_out"):
		_on_zoom_out()
	else:
		handled = false
	if handled:
		viewport.set_input_as_handled()
	return handled

