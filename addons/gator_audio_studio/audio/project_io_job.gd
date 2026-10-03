@tool
class_name GASProjectIOJob
extends RefCounted

const ProjectPersistence := preload("res://addons/gator_audio_studio/audio/project_persistence.gd")

const ACTION_NONE: int = 0
const ACTION_SAVE: int = 1
const ACTION_AUTOSAVE: int = 2
const ACTION_LOAD: int = 3

var task_id: int = -1
var action: int = ACTION_NONE
var result: Dictionary = {}
var path: String = ""
var source_project_path: String = ""
var project_name: String = ""
var recovery: bool = false
var model_revision: int = -1
var project_state_revision: int = -1

var _snapshot: GASEditorModel
var _project_settings: Dictionary = {}
var _editor_state: Dictionary = {}
var _generator_state: Dictionary = {}
var _workspace_state: Dictionary = {}


func start_save(
	project_path: String,
	snapshot: GASEditorModel,
	project_settings: Dictionary,
	editor_state: Dictionary,
	generator_state: Dictionary,
	workspace_state: Dictionary,
	source_path: String,
	is_autosave: bool,
	name: String,
	model_rev: int,
	state_rev: int
) -> bool:
	if task_id >= 0 or snapshot == null:
		return false
	path = ProjectPersistence.normalize_project_path(project_path)
	if path.is_empty():
		return false
	action = ACTION_AUTOSAVE if is_autosave else ACTION_SAVE
	_snapshot = snapshot
	_project_settings = project_settings.duplicate(true)
	_editor_state = editor_state.duplicate(true)
	_generator_state = generator_state.duplicate(true)
	_workspace_state = workspace_state.duplicate(true)
	source_project_path = source_path
	project_name = name
	model_revision = model_rev
	project_state_revision = state_rev
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_save"), false, "GAS project save")
	return task_id >= 0


func start_load(project_path: String, is_recovery: bool) -> bool:
	if task_id >= 0:
		return false
	path = ProjectPersistence.normalize_project_path(project_path)
	if path.is_empty():
		return false
	action = ACTION_LOAD
	recovery = is_recovery
	task_id = WorkerThreadPool.add_task(Callable(self, "_worker_load"), false, "GAS project load")
	return task_id >= 0


func is_complete() -> bool:
	return task_id >= 0 and WorkerThreadPool.is_task_completed(task_id)


func collect() -> void:
	if task_id < 0:
		return
	WorkerThreadPool.wait_for_task_completion(task_id)
	task_id = -1
	_snapshot = null


func _worker_save() -> void:
	result = ProjectPersistence.save_project(
		path,
		_snapshot,
		_project_settings,
		_editor_state,
		_generator_state,
		_workspace_state,
		source_project_path,
		action == ACTION_AUTOSAVE
	)
	if action == ACTION_AUTOSAVE and bool(result.get("ok", false)):
		ProjectPersistence.write_recovery_manifest(path, source_project_path, project_name)


func _worker_load() -> void:
	result = ProjectPersistence.load_project(path)
