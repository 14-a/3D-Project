@tool
class_name GASBatchGenerator
extends RefCounted

const SynthEngine := preload("res://addons/gator_audio_studio/audio/synth_engine.gd")

var _params: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()


func configure(param_list: Array[Dictionary]) -> void:
	_params = param_list.duplicate(true)
	_results.clear()
	for _index: int in range(_params.size()):
		_results.append({})


func get_count() -> int:
	return _params.size()


func render_index(index: int) -> void:
	if index < 0 or index >= _params.size():
		return
	var rendered: Dictionary = SynthEngine.render(_params[index])
	_mutex.lock()
	_results[index] = rendered
	_mutex.unlock()


func get_results() -> Array[Dictionary]:
	_mutex.lock()
	var copy: Array[Dictionary] = _results.duplicate(false)
	_mutex.unlock()
	return copy
