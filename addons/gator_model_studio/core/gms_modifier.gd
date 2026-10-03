@tool
class_name GMSModifier
extends Resource

enum Kind {
	MIRROR = 0,
	ARRAY = 1,
	SOLIDIFY = 2,
	SIMPLE_SUBDIVIDE = 3,
	SUBDIVISION_SURFACE = 4,
	BEVEL = 5,
	DECIMATE = 6,
	TRIANGULATE = 7,
	WEIGHTED_NORMAL = 8,
	DISPLACE = 9,
	BEND = 10,
	SMOOTH = 11,
}

enum Axis {
	X = 0,
	Y = 1,
	Z = 2,
	NORMAL = 3,
}

@export var modifier_name: String = "Modifier"
@export_enum("Mirror", "Array", "Solidify", "Simple Subdivide", "Subdivision Surface", "Bevel", "Decimate", "Triangulate", "Weighted Normal", "Displace", "Bend", "Smooth") var kind: int = Kind.MIRROR
@export var enabled: bool = true
@export var custom_id: String = ""
@export var custom_parameters: Dictionary = {}


@export var mirror_x: bool = true
@export var mirror_y: bool = false
@export var mirror_z: bool = false
@export var merge: bool = true
@export var clipping: bool = false
@export_range(0.000001, 10.0, 0.0001) var merge_distance: float = 0.001


@export_range(1, 1000, 1) var array_count: int = 2
@export var array_offset: Vector3 = Vector3(2.0, 0.0, 0.0)


@export_range(-1000.0, 1000.0, 0.01) var thickness: float = 0.1
@export_range(-1.0, 1.0, 0.01) var solidify_offset: float = 0.0


@export_range(1, 4, 1) var subdivision_levels: int = 1


@export_range(0.0001, 1000.0, 0.001) var bevel_width: float = 0.1
@export_range(1, 4, 1) var bevel_segments: int = 1


@export_range(0.01, 1.0, 0.01) var decimate_ratio: float = 0.5


@export_range(0.0, 1.0, 0.01) var weighted_normal_strength: float = 1.0
@export_range(0.0, 4.0, 0.1) var weighted_normal_power: float = 1.0
@export var weighted_normal_keep_sharp: bool = true


@export_range(-1000.0, 1000.0, 0.01) var displace_strength: float = 0.25
@export_range(0.001, 1000.0, 0.01) var displace_scale: float = 1.0
@export var displace_seed: int = 0
@export var displace_noise: bool = true
@export_enum("X", "Y", "Z", "Normal") var displace_direction: int = Axis.NORMAL


@export_range(-3600.0, 3600.0, 1.0) var bend_angle_degrees: float = 90.0
@export_enum("X", "Y", "Z") var bend_axis: int = Axis.Y


@export_range(0.0, 1.0, 0.01) var smooth_factor: float = 0.5
@export_range(1, 50, 1) var smooth_iterations: int = 1
@export var smooth_preserve_boundary: bool = true


func duplicate_modifier() -> GMSModifier:
	var copy: GMSModifier = GMSModifier.new()
	copy.modifier_name = modifier_name
	copy.kind = kind
	if copy.kind == Kind.SIMPLE_SUBDIVIDE and copy.modifier_name == "Subdivide":
		copy.modifier_name = "Simple Subdivide"
	copy.enabled = enabled
	copy.custom_id = custom_id
	copy.custom_parameters = custom_parameters.duplicate(true)
	copy.mirror_x = mirror_x
	copy.mirror_y = mirror_y
	copy.mirror_z = mirror_z
	copy.merge = merge
	copy.clipping = clipping
	copy.merge_distance = merge_distance
	copy.array_count = array_count
	copy.array_offset = array_offset
	copy.thickness = thickness
	copy.solidify_offset = solidify_offset
	copy.subdivision_levels = subdivision_levels
	copy.bevel_width = bevel_width
	copy.bevel_segments = bevel_segments
	copy.decimate_ratio = decimate_ratio
	copy.weighted_normal_strength = weighted_normal_strength
	copy.weighted_normal_power = weighted_normal_power
	copy.weighted_normal_keep_sharp = weighted_normal_keep_sharp
	copy.displace_strength = displace_strength
	copy.displace_scale = displace_scale
	copy.displace_seed = displace_seed
	copy.displace_noise = displace_noise
	copy.displace_direction = displace_direction
	copy.bend_angle_degrees = bend_angle_degrees
	copy.bend_axis = bend_axis
	copy.smooth_factor = smooth_factor
	copy.smooth_iterations = smooth_iterations
	copy.smooth_preserve_boundary = smooth_preserve_boundary
	return copy


func get_cache_signature() -> int:
	return hash([
		modifier_name, kind, enabled, custom_id, custom_parameters,
		mirror_x, mirror_y, mirror_z, merge, clipping, merge_distance,
		array_count, array_offset, thickness, solidify_offset, subdivision_levels,
		bevel_width, bevel_segments, decimate_ratio, weighted_normal_strength,
		weighted_normal_power, weighted_normal_keep_sharp, displace_strength,
		displace_scale, displace_seed, displace_noise, displace_direction,
		bend_angle_degrees, bend_axis, smooth_factor, smooth_iterations,
		smooth_preserve_boundary,
	])


func get_display_name() -> String:
	var fallback: String = "Custom Modifier" if is_custom() else kind_to_name(kind)
	var cleaned: String = modifier_name.strip_edges()
	if kind == Kind.SIMPLE_SUBDIVIDE and cleaned == "Subdivide":
		return "Simple Subdivide"
	return fallback if cleaned.is_empty() else cleaned


func is_custom() -> bool:
	return not custom_id.is_empty()


static func create_custom(new_custom_id: String, display_name: String, parameters: Dictionary) -> GMSModifier:
	var modifier: GMSModifier = GMSModifier.new()
	modifier.kind = Kind.MIRROR
	modifier.custom_id = new_custom_id.strip_edges().to_lower()
	modifier.custom_parameters = parameters.duplicate(true)
	modifier.modifier_name = display_name
	return modifier


static func create(new_kind: int) -> GMSModifier:
	var modifier: GMSModifier = GMSModifier.new()
	modifier.kind = new_kind
	modifier.modifier_name = kind_to_name(new_kind)
	match new_kind:
		Kind.ARRAY:
			modifier.array_count = 2
			modifier.array_offset = Vector3(2.0, 0.0, 0.0)
		Kind.SOLIDIFY:
			modifier.thickness = 0.1
			modifier.solidify_offset = 0.0
		Kind.SIMPLE_SUBDIVIDE, Kind.SUBDIVISION_SURFACE:
			modifier.subdivision_levels = 1
		Kind.BEVEL:
			modifier.bevel_width = 0.1
			modifier.bevel_segments = 1
		Kind.DECIMATE:
			modifier.decimate_ratio = 0.5
		Kind.WEIGHTED_NORMAL:
			modifier.weighted_normal_strength = 1.0
			modifier.weighted_normal_power = 1.0
			modifier.weighted_normal_keep_sharp = true
		Kind.DISPLACE:
			modifier.displace_strength = 0.25
			modifier.displace_scale = 1.0
			modifier.displace_noise = true
			modifier.displace_direction = Axis.NORMAL
		Kind.BEND:
			modifier.bend_angle_degrees = 90.0
			modifier.bend_axis = Axis.Y
		Kind.SMOOTH:
			modifier.smooth_factor = 0.5
			modifier.smooth_iterations = 1
			modifier.smooth_preserve_boundary = true
		_:
			modifier.mirror_x = true
			modifier.merge = true
	return modifier


static func kind_to_tooltip(value: int) -> String:
	match value:
		Kind.ARRAY:
			return "Creates repeated copies using an object-space offset.\nExample: make fence posts, columns, stairs, or repeated modular pieces."
		Kind.SOLIDIFY:
			return "Adds thickness and boundary walls to open surfaces.\nExample: turn a flat plane into a wall, panel, sheet-metal part, or clothing shell."
		Kind.SIMPLE_SUBDIVIDE:
			return "Splits faces into smaller quads without changing the visible shape.\nExample: apply it before detailed vertex editing, bending, or later deformation."
		Kind.SUBDIVISION_SURFACE:
			return "Smooths and rounds the mesh with Catmull-Clark subdivision while keeping the base cage editable.\nExample: turn a blocky prop, body, or creature base into a curved surface."
		Kind.BEVEL:
			return "Cuts flat or rounded chamfers along mesh edges.\nExample: soften the razor-sharp edges of crates, furniture, buildings, weapons, and other hard-surface props."
		Kind.DECIMATE:
			return "Reduces vertex and face density using spatial vertex clustering.\nExample: create a lower-detail game mesh or quick LOD from a dense model."
		Kind.TRIANGULATE:
			return "Converts every polygon face into triangles without changing the visible shape.\nExample: preview the exact triangle topology a game renderer will use before export."
		Kind.WEIGHTED_NORMAL:
			return "Rebalances shading normals toward larger faces while leaving geometry unchanged.\nExample: make bevelled hard-surface objects shade more cleanly without adding more polygons."
		Kind.DISPLACE:
			return "Moves vertices along an axis or their normals, optionally using procedural noise.\nExample: create rough terrain, damaged surfaces, waves, or inflated details from a subdivided mesh."
		Kind.BEND:
			return "Curves the mesh around a selected local axis.\nExample: bend pipes, arches, signs, tails, roads, or straight modular parts."
		Kind.SMOOTH:
			return "Relaxes vertices toward their neighbours without adding topology.\nExample: soften a lumpy mesh or remove sharp noise after displacement."
		_:
			return "Creates symmetrical geometry across selected local axes.\nExample: model one half of a character, vehicle, building, or prop and mirror the other half."


static func kind_to_name(value: int) -> String:
	match value:
		Kind.ARRAY:
			return "Array"
		Kind.SOLIDIFY:
			return "Solidify"
		Kind.SIMPLE_SUBDIVIDE:
			return "Simple Subdivide"
		Kind.SUBDIVISION_SURFACE:
			return "Subdivision Surface"
		Kind.BEVEL:
			return "Bevel"
		Kind.DECIMATE:
			return "Decimate"
		Kind.TRIANGULATE:
			return "Triangulate"
		Kind.WEIGHTED_NORMAL:
			return "Weighted Normal"
		Kind.DISPLACE:
			return "Displace"
		Kind.BEND:
			return "Bend"
		Kind.SMOOTH:
			return "Smooth"
		_:
			return "Mirror"
