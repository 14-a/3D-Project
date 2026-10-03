@tool
class_name GASExtensionAPI
extends RefCounted

# Legacy low-level registries retained for compatibility with early GAS extension code.
static var _effects: Dictionary = {}
static var _analyzers: Dictionary = {}
static var _generators: Dictionary = {}

# API v1 registries store scripts rather than live component instances. Worker jobs
# create an isolated RefCounted component for each operation, avoiding shared DSP state.
static var _editor_effect_scripts: Dictionary[StringName, GDScript] = {}
static var _editor_effect_owners: Dictionary[StringName, StringName] = {}
static var _generator_scripts: Dictionary[StringName, GDScript] = {}
static var _generator_owners: Dictionary[StringName, StringName] = {}
static var _analyzer_scripts: Dictionary[StringName, GDScript] = {}
static var _analyzer_owners: Dictionary[StringName, StringName] = {}
static var _current_owner: StringName = &""
static var _revision: int = 0
static var _registry_mutex: Mutex = Mutex.new()


static func begin_extension_registration(owner_id: StringName) -> void:
	_registry_mutex.lock()
	_current_owner = owner_id
	_registry_mutex.unlock()


static func end_extension_registration() -> void:
	_registry_mutex.lock()
	_current_owner = &""
	_registry_mutex.unlock()


static func revision() -> int:
	_registry_mutex.lock()
	var value: int = _revision
	_registry_mutex.unlock()
	return value


static func register_editor_effect_owned(owner_id: StringName, script: GDScript) -> bool:
	return _register_editor_effect(owner_id, script)


static func register_editor_effect(script: GDScript) -> bool:
	_registry_mutex.lock()
	var owner_id: StringName = _current_owner
	_registry_mutex.unlock()
	return _register_editor_effect(owner_id, script)


static func _register_editor_effect(owner_id: StringName, script: GDScript) -> bool:
	if script == null or not script.can_instantiate():
		return false
	var created: Object = script.new()
	var component: GASEditorEffectExtension = created as GASEditorEffectExtension
	if component == null:
		return false
	var component_id: StringName = component.get_effect_id()
	if str(component_id).strip_edges().is_empty():
		return false
	_registry_mutex.lock()
	if _editor_effect_scripts.has(component_id):
		_registry_mutex.unlock()
		push_error("GAS extension effect id is already registered: %s" % str(component_id))
		return false
	_editor_effect_scripts[component_id] = script
	_editor_effect_owners[component_id] = owner_id
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_editor_effect(id: StringName) -> void:
	_registry_mutex.lock()
	if _editor_effect_scripts.erase(id):
		_editor_effect_owners.erase(id)
		_revision += 1
	_registry_mutex.unlock()


static func create_editor_effect(id: StringName) -> GASEditorEffectExtension:
	_registry_mutex.lock()
	var script: GDScript = _editor_effect_scripts.get(id) as GDScript
	_registry_mutex.unlock()
	if script == null or not script.can_instantiate():
		return null
	var created: Object = script.new()
	return created as GASEditorEffectExtension


static func editor_effect_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_typed_ids(_editor_effect_scripts)
	_registry_mutex.unlock()
	return output


static func register_generator_extension_owned(owner_id: StringName, script: GDScript) -> bool:
	return _register_generator_extension(owner_id, script)


static func register_generator_extension(script: GDScript) -> bool:
	_registry_mutex.lock()
	var owner_id: StringName = _current_owner
	_registry_mutex.unlock()
	return _register_generator_extension(owner_id, script)


static func _register_generator_extension(owner_id: StringName, script: GDScript) -> bool:
	if script == null or not script.can_instantiate():
		return false
	var created: Object = script.new()
	var component: GASGeneratorExtension = created as GASGeneratorExtension
	if component == null:
		return false
	var component_id: StringName = component.get_generator_id()
	if str(component_id).strip_edges().is_empty():
		return false
	_registry_mutex.lock()
	if _generator_scripts.has(component_id):
		_registry_mutex.unlock()
		push_error("GAS extension generator id is already registered: %s" % str(component_id))
		return false
	_generator_scripts[component_id] = script
	_generator_owners[component_id] = owner_id
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_generator_extension(id: StringName) -> void:
	_registry_mutex.lock()
	if _generator_scripts.erase(id):
		_generator_owners.erase(id)
		_revision += 1
	_registry_mutex.unlock()


static func create_generator_extension(id: StringName) -> GASGeneratorExtension:
	_registry_mutex.lock()
	var script: GDScript = _generator_scripts.get(id) as GDScript
	_registry_mutex.unlock()
	if script == null or not script.can_instantiate():
		return null
	var created: Object = script.new()
	return created as GASGeneratorExtension


static func generator_extension_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_typed_ids(_generator_scripts)
	_registry_mutex.unlock()
	return output


static func register_analyzer_extension_owned(owner_id: StringName, script: GDScript) -> bool:
	return _register_analyzer_extension(owner_id, script)


static func register_analyzer_extension(script: GDScript) -> bool:
	_registry_mutex.lock()
	var owner_id: StringName = _current_owner
	_registry_mutex.unlock()
	return _register_analyzer_extension(owner_id, script)


static func _register_analyzer_extension(owner_id: StringName, script: GDScript) -> bool:
	if script == null or not script.can_instantiate():
		return false
	var created: Object = script.new()
	var component: GASAnalyzerExtension = created as GASAnalyzerExtension
	if component == null:
		return false
	var component_id: StringName = component.get_analyzer_id()
	if str(component_id).strip_edges().is_empty():
		return false
	_registry_mutex.lock()
	if _analyzer_scripts.has(component_id):
		_registry_mutex.unlock()
		push_error("GAS extension analyzer id is already registered: %s" % str(component_id))
		return false
	_analyzer_scripts[component_id] = script
	_analyzer_owners[component_id] = owner_id
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_analyzer_extension(id: StringName) -> void:
	_registry_mutex.lock()
	if _analyzer_scripts.erase(id):
		_analyzer_owners.erase(id)
		_revision += 1
	_registry_mutex.unlock()


static func create_analyzer_extension(id: StringName) -> GASAnalyzerExtension:
	_registry_mutex.lock()
	var script: GDScript = _analyzer_scripts.get(id) as GDScript
	_registry_mutex.unlock()
	if script == null or not script.can_instantiate():
		return null
	var created: Object = script.new()
	return created as GASAnalyzerExtension


static func analyzer_extension_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_typed_ids(_analyzer_scripts)
	_registry_mutex.unlock()
	return output


static func editor_effect_ids_for_owner(owner_id: StringName) -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _ids_for_owner(_editor_effect_owners, owner_id)
	_registry_mutex.unlock()
	return output


static func generator_extension_ids_for_owner(owner_id: StringName) -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _ids_for_owner(_generator_owners, owner_id)
	_registry_mutex.unlock()
	return output


static func analyzer_extension_ids_for_owner(owner_id: StringName) -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _ids_for_owner(_analyzer_owners, owner_id)
	_registry_mutex.unlock()
	return output


static func unregister_owner(owner_id: StringName) -> void:
	if str(owner_id).is_empty():
		return
	_registry_mutex.lock()
	var removed_any: bool = false
	var effect_ids_to_remove: Array[StringName] = []
	for id: StringName in _editor_effect_owners:
		if _editor_effect_owners[id] == owner_id:
			effect_ids_to_remove.append(id)
	for id: StringName in effect_ids_to_remove:
		_editor_effect_scripts.erase(id)
		_editor_effect_owners.erase(id)
		removed_any = true
	var generator_ids_to_remove: Array[StringName] = []
	for id: StringName in _generator_owners:
		if _generator_owners[id] == owner_id:
			generator_ids_to_remove.append(id)
	for id: StringName in generator_ids_to_remove:
		_generator_scripts.erase(id)
		_generator_owners.erase(id)
		removed_any = true
	var analyzer_ids_to_remove: Array[StringName] = []
	for id: StringName in _analyzer_owners:
		if _analyzer_owners[id] == owner_id:
			analyzer_ids_to_remove.append(id)
	for id: StringName in analyzer_ids_to_remove:
		_analyzer_scripts.erase(id)
		_analyzer_owners.erase(id)
		removed_any = true
	if removed_any:
		_revision += 1
	_registry_mutex.unlock()


# -----------------------------------------------------------------------------
# Legacy API
# -----------------------------------------------------------------------------

static func register_effect(id: StringName, factory: Callable) -> bool:
	if str(id).is_empty() or not factory.is_valid():
		return false
	_registry_mutex.lock()
	_effects[id] = factory
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_effect(id: StringName) -> void:
	_registry_mutex.lock()
	if _effects.erase(id):
		_revision += 1
	_registry_mutex.unlock()


static func create_effect(id: StringName) -> GASOfflineEffect:
	_registry_mutex.lock()
	var factory_value: Variant = _effects.get(id, Callable())
	_registry_mutex.unlock()
	if not (factory_value is Callable):
		return null
	var factory: Callable = factory_value
	if not factory.is_valid():
		return null
	var created: Variant = factory.call()
	return created as GASOfflineEffect


static func effect_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_ids(_effects)
	_registry_mutex.unlock()
	return output


static func register_analyzer(id: StringName, analyzer: Callable) -> bool:
	if str(id).is_empty() or not analyzer.is_valid():
		return false
	_registry_mutex.lock()
	_analyzers[id] = analyzer
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_analyzer(id: StringName) -> void:
	_registry_mutex.lock()
	if _analyzers.erase(id):
		_revision += 1
	_registry_mutex.unlock()


static func analyze(id: StringName, pcm: GASPCMData, start_frame: int, end_frame: int) -> Variant:
	_registry_mutex.lock()
	var callable_value: Variant = _analyzers.get(id, Callable())
	_registry_mutex.unlock()
	if not (callable_value is Callable):
		return null
	var analyzer: Callable = callable_value
	return analyzer.call(pcm, start_frame, end_frame) if analyzer.is_valid() else null


static func analyzer_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_ids(_analyzers)
	_registry_mutex.unlock()
	return output


static func register_generator(id: StringName, generator: Callable) -> bool:
	if str(id).is_empty() or not generator.is_valid():
		return false
	_registry_mutex.lock()
	_generators[id] = generator
	_revision += 1
	_registry_mutex.unlock()
	return true


static func unregister_generator(id: StringName) -> void:
	_registry_mutex.lock()
	if _generators.erase(id):
		_revision += 1
	_registry_mutex.unlock()


static func generate(id: StringName, params: Dictionary) -> GASPCMData:
	_registry_mutex.lock()
	var callable_value: Variant = _generators.get(id, Callable())
	_registry_mutex.unlock()
	if not (callable_value is Callable):
		return null
	var generator: Callable = callable_value
	if not generator.is_valid():
		return null
	return generator.call(params) as GASPCMData


static func generator_ids() -> PackedStringArray:
	_registry_mutex.lock()
	var output: PackedStringArray = _sorted_ids(_generators)
	_registry_mutex.unlock()
	return output


static func _ids_for_owner(owner_map: Dictionary, owner_id: StringName) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	for key: Variant in owner_map.keys():
		var component_id: StringName = StringName(str(key))
		if owner_map.get(component_id, &"") == owner_id:
			output.append(str(component_id))
	output.sort()
	return output


static func _sorted_ids(registry: Dictionary) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	for key: Variant in registry.keys():
		output.append(str(key))
	output.sort()
	return output


static func _sorted_typed_ids(registry: Dictionary) -> PackedStringArray:
	var output: PackedStringArray = PackedStringArray()
	for key: Variant in registry.keys():
		output.append(str(key))
	output.sort()
	return output
