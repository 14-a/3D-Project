@tool
extends GMSExtension

const GEAR_GENERATOR: Script = preload("res://addons/gator_model_studio/extensions/installed/blackwater_gator.procedural_gear/gear_generator.gd")
const GEAR_ICON: Texture2D = preload("res://addons/gator_model_studio/extensions/installed/blackwater_gator.procedural_gear/gear_icon.svg")


func register_extension(api: GMSExtensionAPI) -> void:
	var tool_error: Error = api.register_modelling_tool({
		"id": "blackwater_gator.procedural_gear",
		"name": "Procedural Gear",
		"object_name": "Gear",
		"category": "Mechanical",
		"icon": GEAR_ICON,
		"tooltip": "Create an editable gear mesh from tooth count, radii, thickness, and bore settings.",
		"order": 10,
		"parameters": [
			{
				"id": "teeth",
				"label": "Teeth",
				"type": "int",
				"default": 16,
				"min": 3,
				"max": 128,
				"step": 1,
				"tooltip": "Number of gear teeth. Geometry uses four radial segments per tooth.",
			},
			{
				"id": "outer_radius",
				"label": "Outer Radius",
				"type": "float",
				"default": 1.0,
				"min": 0.05,
				"max": 1000.0,
				"step": 0.01,
			},
			{
				"id": "root_radius",
				"label": "Root Radius",
				"type": "float",
				"default": 0.78,
				"min": 0.01,
				"max": 1000.0,
				"step": 0.01,
				"tooltip": "Radius between teeth. Values at or above Outer Radius are clamped.",
			},
			{
				"id": "bore_radius",
				"label": "Bore Radius",
				"type": "float",
				"default": 0.3,
				"min": 0.0,
				"max": 999.0,
				"step": 0.01,
				"tooltip": "Radius of the centre hole.",
			},
			{
				"id": "thickness",
				"label": "Thickness",
				"type": "float",
				"default": 0.25,
				"min": 0.01,
				"max": 1000.0,
				"step": 0.01,
			},
		],
		"generate": GEAR_GENERATOR.create_gear,
	})
	if tool_error != OK:
		push_error("Procedural Gear could not register its modelling tool: %d" % tool_error)

	var modifier_error: Error = api.register_modifier({
		"id": "blackwater_gator.radial_scale",
		"name": "Radial Scale",
		"tooltip": "Scales vertices away from the local Y axis without changing their height. This small example demonstrates custom modifier registration.",
		"order": 100,
		"parameters": [
			{
				"id": "factor",
				"label": "Factor",
				"type": "float",
				"default": 1.1,
				"min": 0.0,
				"max": 10.0,
				"step": 0.01,
			},
		],
		"evaluate": GEAR_GENERATOR.apply_radial_scale,
	})
	if modifier_error != OK:
		push_error("Procedural Gear could not register its modifier: %d" % modifier_error)
