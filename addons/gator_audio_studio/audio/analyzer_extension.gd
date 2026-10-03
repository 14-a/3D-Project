@tool
class_name GASAnalyzerExtension
extends RefCounted


func get_analyzer_id() -> StringName:
	return &""


func get_display_name() -> String:
	return "Custom Analyzer"


func get_description() -> String:
	return ""


func analyze(_pcm: GASPCMData, _start_frame: int, _end_frame: int) -> Dictionary:
	return {}
