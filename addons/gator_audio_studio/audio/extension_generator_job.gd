@tool
class_name GASExtensionGeneratorJob
extends RefCounted

const ExtensionAPI: GDScript = preload("res://addons/gator_audio_studio/audio/extension_api.gd")

var generator_id: StringName = &""
var params_list: Array[Dictionary] = []
var results: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()


func configure(id: StringName, params: Array[Dictionary]) -> bool:
	if str(id).is_empty() or params.is_empty():
		return false
	generator_id = id
	params_list.clear()
	for item: Dictionary in params:
		params_list.append(item.duplicate(true))
	results.clear()
	results.resize(params_list.size())
	return true


func render_index(index: int) -> void:
	if index < 0 or index >= params_list.size():
		return
	var generator: GASGeneratorExtension = ExtensionAPI.create_generator_extension(generator_id)
	if generator == null:
		return
	var params: Dictionary = params_list[index]
	var pcm: GASPCMData = generator.generate(params)
	if pcm == null or pcm.frame_count() <= 0:
		return
	var wav: AudioStreamWAV = pcm.to_wav()
	var samples: PackedFloat32Array = pcm.left.duplicate()
	var result: Dictionary = {
		"params": params.duplicate(true),
		"pcm": pcm,
		"stream": wav,
		"samples": samples,
	}
	_mutex.lock()
	results[index] = result
	_mutex.unlock()


func get_results() -> Array[Dictionary]:
	_mutex.lock()
	var output: Array[Dictionary] = []
	for item: Variant in results:
		if item is Dictionary:
			output.append((item as Dictionary).duplicate(false))
	_mutex.unlock()
	return output
