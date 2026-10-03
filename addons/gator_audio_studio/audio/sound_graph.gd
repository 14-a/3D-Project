@tool
class_name GASSoundGraph
extends RefCounted

const NODE_TYPES: PackedStringArray = [
	"Oscillator", "Noise", "Envelope", "LFO", "FM", "AM", "Filter",
	"Distortion", "Delay", "Reverb", "Mixer", "Output"
]


static func new_graph() -> Dictionary:
	var nodes: Array[Dictionary] = [
		{"id": 1, "type": "Oscillator", "enabled": true, "params": {"wave": "Sine", "start_hz": 440.0, "end_hz": 440.0}},
		{"id": 2, "type": "Envelope", "enabled": true, "params": {"attack": 0.004, "decay": 0.08, "sustain": 0.35, "release": 0.08}},
		{"id": 3, "type": "Output", "enabled": true, "params": {"gain": 1.0}},
	]
	var connections: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 3)]
	return {"nodes": nodes, "connections": connections, "next_id": 4}


static func add_node(graph: Dictionary, type_name: String) -> int:
	var nodes: Array[Dictionary] = _nodes_from_graph(graph)
	var next_id: int = int(graph.get("next_id", 1))
	nodes.append({"id": next_id, "type": type_name, "enabled": true, "params": default_params(type_name)})
	graph["nodes"] = nodes
	graph["next_id"] = next_id + 1
	return next_id


static func remove_node(graph: Dictionary, node_id: int) -> void:
	var nodes: Array[Dictionary] = _nodes_from_graph(graph)
	for i: int in range(nodes.size() - 1, -1, -1):
		if int(nodes[i].get("id", -1)) == node_id:
			nodes.remove_at(i)
	var connections: Array[Vector2i] = _connections_from_graph(graph)
	for i: int in range(connections.size() - 1, -1, -1):
		var edge: Vector2i = connections[i]
		if edge.x == node_id or edge.y == node_id:
			connections.remove_at(i)
	graph["nodes"] = nodes
	graph["connections"] = connections


static func connect_nodes(graph: Dictionary, from_id: int, to_id: int) -> void:
	if from_id == to_id:
		return
	var connections: Array[Vector2i] = _connections_from_graph(graph)
	for edge: Vector2i in connections:
		if edge.x == from_id and edge.y == to_id:
			return
	connections.append(Vector2i(from_id, to_id))
	graph["connections"] = connections


static func default_params(type_name: String) -> Dictionary:
	match type_name:
		"Oscillator": return {"wave": "Sine", "start_hz": 440.0, "end_hz": 440.0}
		"Noise": return {"noise_mode": "white", "noise_mix": 1.0, "noise_frequency": 1000.0}
		"Envelope": return {"attack": 0.004, "decay": 0.08, "sustain": 0.35, "release": 0.08}
		"LFO": return {"vibrato_depth": 0.05, "vibrato_hz": 6.0, "tremolo_depth": 0.0}
		"FM": return {"fm_ratio": 2.0, "fm_index": 1.5, "feedback": 0.0}
		"AM": return {"am_depth": 0.5, "am_hz": 12.0}
		"Filter": return {"filter_mode": "Lowpass", "lowpass_hz": 8000.0, "highpass_hz": 0.0, "bandpass_hz": 1200.0, "resonance": 0.0}
		"Distortion": return {"distortion_mode": "Soft Clip", "drive": 1.5, "distortion_mix": 1.0}
		"Delay": return {"echo_mix": 0.2, "echo_delay": 0.12, "delay_feedback": 0.25, "delay_mode": "Mono"}
		"Reverb": return {"reverb_mix": 0.18, "reverb_size": 0.5, "reverb_damping": 0.4}
		"Mixer": return {"gain": 1.0, "pan": 0.0}
		"Output": return {"gain": 1.0}
		_: return {}


static func compile_to_params(graph: Dictionary, base_params: Dictionary) -> Dictionary:
	var out: Dictionary = base_params.duplicate(true)
	var layers: Array[Dictionary] = []
	var current: Dictionary = _base_layer(out)
	var nodes: Array[Dictionary] = _nodes_from_graph(graph)
	for node: Dictionary in nodes:
		if not bool(node.get("enabled", true)):
			continue
		var node_type: String = str(node.get("type", ""))
		var params_value: Variant = node.get("params", {})
		var node_params: Dictionary = {}
		if params_value is Dictionary:
			node_params = params_value as Dictionary
		match node_type:
			"Oscillator":
				if not current.is_empty() and not layers.is_empty():
					current = _base_layer(out)
				current.merge(node_params, true)
			"Noise", "Envelope", "LFO", "FM", "AM", "Filter", "Distortion", "Delay", "Reverb":
				current.merge(node_params, true)
			"Mixer":
				current.merge(node_params, true)
				if not current.is_empty():
					current["role"] = "Graph Voice %d" % (layers.size() + 1)
					layers.append(current.duplicate(true))
					current = _base_layer(out)
			"Output":
				current["gain"] = float(current.get("gain", 1.0)) * float(node_params.get("gain", 1.0))
	if not current.is_empty():
		current["role"] = "Graph Voice %d" % (layers.size() + 1)
		layers.append(current)
	out["layers"] = layers
	out["graph"] = graph.duplicate(true)
	out["category"] = "Procedural Graph"
	return out


static func _nodes_from_graph(graph: Dictionary) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var raw: Variant = graph.get("nodes", [])
	if raw is Array:
		var source: Array = raw as Array
		for value: Variant in source:
			if value is Dictionary:
				output.append(value as Dictionary)
	return output


static func _connections_from_graph(graph: Dictionary) -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	var raw: Variant = graph.get("connections", [])
	if raw is Array:
		var source: Array = raw as Array
		for value: Variant in source:
			if value is Vector2i:
				output.append(value as Vector2i)
			elif value is PackedInt32Array:
				var packed_edge: PackedInt32Array = value as PackedInt32Array
				if packed_edge.size() >= 2:
					output.append(Vector2i(packed_edge[0], packed_edge[1]))
			elif value is Array:
				var edge_array: Array = value as Array
				if edge_array.size() >= 2:
					output.append(Vector2i(int(edge_array[0]), int(edge_array[1])))
	return output


static func _base_layer(source: Dictionary) -> Dictionary:
	var layer: Dictionary = {}
	for key: String in [
		"duration", "wave", "start_hz", "end_hz", "attack", "decay", "sustain", "release",
		"duty", "vibrato_depth", "vibrato_hz", "tremolo_depth", "am_depth", "am_hz",
		"ring_mod_depth", "ring_mod_hz", "drive", "distortion_mode", "distortion_mix",
		"lowpass_hz", "highpass_hz", "bandpass_hz", "resonance", "filter_mode",
		"fm_ratio", "fm_index", "feedback", "echo_mix", "echo_delay", "delay_feedback",
		"delay_mode", "reverb_mix", "reverb_size", "reverb_damping", "bitcrush_hz",
		"quantize_bits", "noise_mode", "noise_mix", "noise_frequency", "output_gain",
		"wavetable", "fm_ops"
	]:
		if source.has(key):
			layer[key] = source[key]
	layer["gain"] = 1.0
	layer["delay"] = 0.0
	return layer
