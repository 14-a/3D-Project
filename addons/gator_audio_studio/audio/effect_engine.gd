@tool
class_name GASEffectEngine
extends RefCounted

const PCMData := preload("res://addons/gator_audio_studio/audio/pcm_data.gd")
const EffectData := preload("res://addons/gator_audio_studio/audio/effect_data.gd")
const ExtensionAPI: GDScript = preload("res://addons/gator_audio_studio/audio/extension_api.gd")

const EXTENSION_EFFECT_PREFIX: String = "@gasext:"

const EFFECT_TYPES: PackedStringArray = [
	"Amplify", "Normalize", "Loudness Normalize", "Fade In", "Fade Out", "Adjustable Fade", "Studio Fade", "Reverse", "Invert", "Remove DC Offset",
	"Low Pass", "High Pass", "Band Pass", "Band Limit", "Notch", "Low Shelf", "High Shelf", "Bass & Treble", "Graphic EQ", "Parametric EQ",
	"Compressor", "Limiter", "Noise Gate",
	"Distortion", "Bitcrusher",
	"Delay", "Ping Pong Delay", "Reverb", "Chorus", "Flanger", "Phaser", "Tremolo", "Vibrato", "Wah", "Ring Modulation",
	"Change Speed", "Change Pitch", "Change Tempo", "Sliding Stretch", "Repeat", "Truncate Silence",
	"Click Repair", "Pop Removal", "Clip Repair", "Interpolate Selection", "De-esser", "Hum Removal"
]

const STACK_SAFE_TYPES: PackedStringArray = [
	"Amplify", "Normalize", "Loudness Normalize", "Fade In", "Fade Out", "Adjustable Fade", "Studio Fade", "Reverse", "Invert", "Remove DC Offset",
	"Low Pass", "High Pass", "Band Pass", "Band Limit", "Notch", "Low Shelf", "High Shelf", "Bass & Treble", "Graphic EQ", "Parametric EQ",
	"Compressor", "Limiter", "Noise Gate", "Distortion", "Bitcrusher", "Delay", "Ping Pong Delay", "Reverb",
	"Chorus", "Flanger", "Phaser", "Tremolo", "Vibrato", "Wah", "Ring Modulation", "Change Pitch", "Click Repair", "Pop Removal", "Clip Repair", "De-esser", "Hum Removal"
]


static func available_effect_types() -> PackedStringArray:
	var output: PackedStringArray = EFFECT_TYPES.duplicate()
	for id_text: String in ExtensionAPI.editor_effect_ids():
		output.append(EXTENSION_EFFECT_PREFIX + id_text)
	return output


static func effect_display_name(effect_type: String) -> String:
	var extension_id: StringName = _extension_id(effect_type)
	if str(extension_id).is_empty():
		return effect_type
	var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
	return extension.get_display_name() if extension != null else "Missing Extension • %s" % str(extension_id)


static func effect_description(effect_type: String) -> String:
	var extension_id: StringName = _extension_id(effect_type)
	if str(extension_id).is_empty():
		return effect_type
	var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
	return extension.get_description() if extension != null else "The extension that provides this effect is missing or disabled."


static func is_extension_effect(effect_type: String) -> bool:
	return effect_type.begins_with(EXTENSION_EFFECT_PREFIX)


static func _extension_id(effect_type: String) -> StringName:
	if not is_extension_effect(effect_type):
		return &""
	return StringName(effect_type.substr(EXTENSION_EFFECT_PREFIX.length()))


static func create_default(effect_type: String) -> GASEffectData:
	var effect: GASEffectData = EffectData.new()
	effect.effect_type = effect_type
	effect.enabled = true
	effect.wet = 1.0
	effect.preset_name = "Default"
	var extension_id: StringName = _extension_id(effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		effect.params = extension.get_default_params() if extension != null else {}
	else:
		effect.params = _default_params(effect_type)
	return effect


static func is_stack_safe(effect_type: String) -> bool:
	var extension_id: StringName = _extension_id(effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		return extension != null and extension.is_stack_safe()
	return STACK_SAFE_TYPES.has(effect_type)


static func stack_outputs_stereo(stack: Array[GASEffectData]) -> bool:
	for effect: GASEffectData in stack:
		if effect == null or not effect.enabled:
			continue
		if effect.effect_type == "Ping Pong Delay":
			return true
		var extension_id: StringName = _extension_id(effect.effect_type)
		if not str(extension_id).is_empty():
			var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
			if extension != null and extension.outputs_stereo():
				return true
	return false


static func presets_for(effect_type: String) -> PackedStringArray:
	var extension_id: StringName = _extension_id(effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		return extension.get_presets() if extension != null else PackedStringArray(["Default"])
	match effect_type:
		"Amplify": return PackedStringArray(["Default", "+3 dB", "+6 dB", "-6 dB"])
		"Normalize": return PackedStringArray(["Default", "-1 dB Peak", "-3 dB Peak"])
		"Loudness Normalize": return PackedStringArray(["Default", "-18 dB RMS", "-14 dB RMS", "-12 dB RMS"])
		"Fade In": return PackedStringArray(["Linear", "Logarithmic", "Exponential", "S-Curve", "Equal Power"])
		"Fade Out": return PackedStringArray(["Linear", "Logarithmic", "Exponential", "S-Curve", "Equal Power"])
		"Adjustable Fade": return PackedStringArray(["Default", "Fade In", "Fade Out", "Equal Power In", "Equal Power Out"])
		"Studio Fade": return PackedStringArray(["Default"])
		"Low Pass": return PackedStringArray(["Default", "Telephone", "Muffled", "Sub Bass"])
		"High Pass": return PackedStringArray(["Default", "Remove Rumble", "Thin", "Radio"])
		"Band Pass": return PackedStringArray(["Default", "Telephone", "Walkie-Talkie", "Megaphone"])
		"Band Limit": return PackedStringArray(["Default", "Voice Band", "Remove Mid Band"])
		"Notch": return PackedStringArray(["Default", "50 Hz Hum", "60 Hz Hum"])
		"Low Shelf": return PackedStringArray(["Default", "Bass Boost", "Bass Cut"])
		"High Shelf": return PackedStringArray(["Default", "Air Boost", "Treble Cut"])
		"Bass & Treble": return PackedStringArray(["Default", "Bass Boost", "Treble Boost", "Dark", "Bright"])
		"Graphic EQ": return PackedStringArray(["Default", "Smile", "Voice", "Lo-Fi"])
		"Parametric EQ": return PackedStringArray(["Default", "Presence", "Boxy Cut", "Resonance"])
		"Compressor": return PackedStringArray(["Default", "Gentle", "Voice", "Punchy", "Heavy"])
		"Limiter": return PackedStringArray(["Default", "-1 dB Ceiling", "Aggressive"])
		"Noise Gate": return PackedStringArray(["Default", "Light", "Voice", "Hard"])
		"Distortion": return PackedStringArray(["Default", "Soft Saturation", "Overdrive", "Radio", "Damaged Speaker", "Intercom", "Walkie-Talkie", "Robot", "Telephone", "Retro Console", "Digital"])
		"Bitcrusher": return PackedStringArray(["Default", "12-bit", "8-bit", "4-bit", "Retro 11 kHz"])
		"Delay": return PackedStringArray(["Default", "Slapback", "Echo", "Long Echo"])
		"Ping Pong Delay": return PackedStringArray(["Default", "Short Ping Pong", "Wide Ping Pong"])
		"Reverb": return PackedStringArray(["Default", "Small Room", "Large Room", "Hall", "Tunnel", "Cavern"])
		"Chorus": return PackedStringArray(["Default", "Subtle", "Wide"])
		"Flanger": return PackedStringArray(["Default", "Jet", "Slow Sweep"])
		"Phaser": return PackedStringArray(["Default", "Subtle", "Deep"])
		"Tremolo": return PackedStringArray(["Default", "Slow", "Fast", "Chopper"])
		"Vibrato": return PackedStringArray(["Default", "Subtle", "Wide"])
		"Wah": return PackedStringArray(["Default", "Slow Wah", "Fast Wah"])
		"Ring Modulation": return PackedStringArray(["Default", "Robot", "Metallic"])
		"Change Speed": return PackedStringArray(["Default", "Half Speed", "Double Speed"])
		"Change Pitch": return PackedStringArray(["Default", "+12 Semitones", "+7 Semitones", "-12 Semitones"])
		"Change Tempo": return PackedStringArray(["Default", "75%", "125%", "150%"])
		"Sliding Stretch": return PackedStringArray(["Default", "Pitch Rise", "Pitch Fall", "Accelerate", "Decelerate"])
		"Repeat": return PackedStringArray(["Default", "x2", "x4"])
		"Truncate Silence": return PackedStringArray(["Default", "Tight", "Speech"])
		"Click Repair": return PackedStringArray(["Default", "Light", "Strong"])
		"Pop Removal": return PackedStringArray(["Default", "Light", "Strong"])
		"Clip Repair": return PackedStringArray(["Default", "Light", "Strong"])
		"Interpolate Selection": return PackedStringArray(["Default"])
		"De-esser": return PackedStringArray(["Default", "Voice", "Strong"])
		"Hum Removal": return PackedStringArray(["Default", "50 Hz", "60 Hz"])
		_: return PackedStringArray(["Default"])


static func apply_preset(effect: GASEffectData, preset_name: String) -> void:
	if effect == null:
		return
	var extension_id: StringName = _extension_id(effect.effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		if extension != null:
			effect.params = extension.apply_preset(effect.params, preset_name)
			effect.preset_name = preset_name
		return
	effect.params = _default_params(effect.effect_type)
	effect.preset_name = preset_name
	match effect.effect_type:
		"Amplify":
			match preset_name:
				"+3 dB": effect.params["gain_db"] = 3.0
				"+6 dB": effect.params["gain_db"] = 6.0
				"-6 dB": effect.params["gain_db"] = -6.0
		"Fade In", "Fade Out":
			match preset_name:
				"Logarithmic": effect.params["curve"] = 1
				"Exponential": effect.params["curve"] = 2
				"S-Curve": effect.params["curve"] = 3
				"Equal Power": effect.params["curve"] = 4
				_: effect.params["curve"] = 0
		"Adjustable Fade":
			match preset_name:
				"Fade In": effect.params.merge({"start_db": -80.0, "end_db": 0.0, "curve": 0}, true)
				"Fade Out": effect.params.merge({"start_db": 0.0, "end_db": -80.0, "curve": 0}, true)
				"Equal Power In": effect.params.merge({"start_db": -80.0, "end_db": 0.0, "curve": 4}, true)
				"Equal Power Out": effect.params.merge({"start_db": 0.0, "end_db": -80.0, "curve": 4}, true)
		"Normalize":
			if preset_name == "-3 dB Peak":
				effect.params["target_db"] = -3.0
			else:
				effect.params["target_db"] = -1.0
		"Loudness Normalize":
			match preset_name:
				"-18 dB RMS": effect.params["target_rms_db"] = -18.0
				"-14 dB RMS": effect.params["target_rms_db"] = -14.0
				"-12 dB RMS": effect.params["target_rms_db"] = -12.0
		"Low Pass":
			match preset_name:
				"Telephone": effect.params["cutoff_hz"] = 3400.0
				"Muffled": effect.params["cutoff_hz"] = 1600.0
				"Sub Bass": effect.params["cutoff_hz"] = 180.0
		"High Pass":
			match preset_name:
				"Remove Rumble": effect.params["cutoff_hz"] = 80.0
				"Thin": effect.params["cutoff_hz"] = 700.0
				"Radio": effect.params["cutoff_hz"] = 300.0
		"Band Pass":
			match preset_name:
				"Telephone": effect.params.merge({"low_hz": 300.0, "high_hz": 3400.0}, true)
				"Walkie-Talkie": effect.params.merge({"low_hz": 450.0, "high_hz": 2800.0}, true)
				"Megaphone": effect.params.merge({"low_hz": 550.0, "high_hz": 4200.0}, true)
		"Band Limit":
			match preset_name:
				"Voice Band": effect.params.merge({"low_hz": 120.0, "high_hz": 8000.0, "reject": 0}, true)
				"Remove Mid Band": effect.params.merge({"low_hz": 500.0, "high_hz": 3500.0, "reject": 1}, true)
		"Notch":
			match preset_name:
				"50 Hz Hum": effect.params["frequency_hz"] = 50.0
				"60 Hz Hum": effect.params["frequency_hz"] = 60.0
		"Low Shelf":
			match preset_name:
				"Bass Boost": effect.params.merge({"frequency_hz": 180.0, "gain_db": 6.0}, true)
				"Bass Cut": effect.params.merge({"frequency_hz": 180.0, "gain_db": -6.0}, true)
		"High Shelf":
			match preset_name:
				"Air Boost": effect.params.merge({"frequency_hz": 6000.0, "gain_db": 5.0}, true)
				"Treble Cut": effect.params.merge({"frequency_hz": 5000.0, "gain_db": -6.0}, true)
		"Bass & Treble":
			match preset_name:
				"Bass Boost": effect.params.merge({"bass_db": 6.0, "treble_db": 0.0}, true)
				"Treble Boost": effect.params.merge({"bass_db": 0.0, "treble_db": 6.0}, true)
				"Dark": effect.params.merge({"bass_db": 3.0, "treble_db": -6.0}, true)
				"Bright": effect.params.merge({"bass_db": -2.0, "treble_db": 5.0}, true)
		"Graphic EQ":
			match preset_name:
				"Smile": effect.params.merge({"low_db": 4.0, "mid_db": -3.0, "high_db": 4.0}, true)
				"Voice": effect.params.merge({"low_db": -3.0, "mid_db": 4.0, "high_db": 1.0}, true)
				"Lo-Fi": effect.params.merge({"low_db": 1.0, "mid_db": 2.0, "high_db": -8.0}, true)
		"Parametric EQ":
			match preset_name:
				"Presence": effect.params.merge({"frequency_hz": 3200.0, "gain_db": 4.0, "q": 1.0}, true)
				"Boxy Cut": effect.params.merge({"frequency_hz": 450.0, "gain_db": -5.0, "q": 1.4}, true)
				"Resonance": effect.params.merge({"frequency_hz": 1200.0, "gain_db": 8.0, "q": 5.0}, true)
		"Compressor":
			match preset_name:
				"Gentle": effect.params.merge({"threshold_db": -18.0, "ratio": 2.0, "attack_ms": 20.0, "release_ms": 150.0, "makeup_db": 2.0}, true)
				"Voice": effect.params.merge({"threshold_db": -20.0, "ratio": 3.5, "attack_ms": 8.0, "release_ms": 110.0, "makeup_db": 3.0}, true)
				"Punchy": effect.params.merge({"threshold_db": -14.0, "ratio": 4.0, "attack_ms": 25.0, "release_ms": 80.0, "makeup_db": 2.0}, true)
				"Heavy": effect.params.merge({"threshold_db": -28.0, "ratio": 8.0, "attack_ms": 3.0, "release_ms": 180.0, "makeup_db": 6.0}, true)
		"Limiter":
			if preset_name == "Aggressive":
				effect.params.merge({"ceiling_db": -0.5, "release_ms": 45.0, "input_gain_db": 8.0}, true)
			else:
				effect.params["ceiling_db"] = -1.0
		"Noise Gate":
			match preset_name:
				"Light": effect.params.merge({"threshold_db": -52.0, "attack_ms": 2.0, "release_ms": 90.0}, true)
				"Voice": effect.params.merge({"threshold_db": -42.0, "attack_ms": 4.0, "release_ms": 140.0}, true)
				"Hard": effect.params.merge({"threshold_db": -32.0, "attack_ms": 1.0, "release_ms": 45.0}, true)
		"Distortion":
			match preset_name:
				"Soft Saturation": effect.params.merge({"mode": "Saturation", "drive": 1.8}, true)
				"Overdrive": effect.params.merge({"mode": "Overdrive", "drive": 3.0}, true)
				"Radio": effect.params.merge({"mode": "Hard Clip", "drive": 2.4, "tone_hz": 4200.0}, true)
				"Damaged Speaker": effect.params.merge({"mode": "Foldback", "drive": 3.5, "tone_hz": 3200.0}, true)
				"Intercom": effect.params.merge({"mode": "Hard Clip", "drive": 1.9, "tone_hz": 4500.0}, true)
				"Walkie-Talkie": effect.params.merge({"mode": "Hard Clip", "drive": 2.3, "tone_hz": 3000.0}, true)
				"Robot": effect.params.merge({"mode": "Digital", "drive": 2.0, "tone_hz": 7000.0}, true)
				"Telephone": effect.params.merge({"mode": "Saturation", "drive": 1.7, "tone_hz": 3400.0}, true)
				"Retro Console": effect.params.merge({"mode": "Digital", "drive": 1.5, "tone_hz": 8500.0}, true)
				"Digital": effect.params.merge({"mode": "Digital", "drive": 2.2}, true)
		"Bitcrusher":
			match preset_name:
				"12-bit": effect.params["bits"] = 12
				"8-bit": effect.params["bits"] = 8
				"4-bit": effect.params["bits"] = 4
				"Retro 11 kHz": effect.params.merge({"bits": 8, "sample_rate_hz": 11025.0}, true)
		"Delay":
			match preset_name:
				"Slapback": effect.params.merge({"delay_ms": 90.0, "feedback": 0.18, "mix": 0.38}, true)
				"Echo": effect.params.merge({"delay_ms": 320.0, "feedback": 0.5, "mix": 0.55}, true)
				"Long Echo": effect.params.merge({"delay_ms": 560.0, "feedback": 0.6, "mix": 0.62}, true)
		"Ping Pong Delay":
			match preset_name:
				"Short Ping Pong": effect.params.merge({"delay_ms": 160.0, "feedback": 0.4, "mix": 0.5}, true)
				"Wide Ping Pong": effect.params.merge({"delay_ms": 380.0, "feedback": 0.56, "mix": 0.62}, true)
		"Reverb":
			match preset_name:
				"Small Room": effect.params.merge({"size": 0.36, "damping": 0.46, "predelay_ms": 20.0, "decay_s": 1.35, "spread": 0.50, "mix": 0.58}, true)
				"Large Room": effect.params.merge({"size": 0.72, "damping": 0.32, "predelay_ms": 38.0, "decay_s": 3.3, "spread": 0.82, "mix": 0.70}, true)
				"Hall": effect.params.merge({"size": 0.94, "damping": 0.24, "predelay_ms": 58.0, "decay_s": 5.2, "spread": 0.98, "mix": 0.78}, true)
				"Tunnel": effect.params.merge({"size": 0.82, "damping": 0.10, "predelay_ms": 96.0, "decay_s": 4.8, "spread": 0.38, "mix": 0.82}, true)
				"Cavern": effect.params.merge({"size": 1.0, "damping": 0.16, "predelay_ms": 118.0, "decay_s": 6.5, "spread": 0.92, "mix": 0.88}, true)
		"Chorus":
			match preset_name:
				"Subtle": effect.params.merge({"rate_hz": 0.7, "depth_ms": 5.0, "mix": 0.18}, true)
				"Wide": effect.params.merge({"rate_hz": 1.1, "depth_ms": 11.0, "mix": 0.38}, true)
		"Flanger":
			match preset_name:
				"Jet": effect.params.merge({"rate_hz": 0.28, "depth_ms": 3.2, "feedback": 0.55, "mix": 0.5}, true)
				"Slow Sweep": effect.params.merge({"rate_hz": 0.1, "depth_ms": 4.0, "feedback": 0.35, "mix": 0.4}, true)
		"Phaser":
			match preset_name:
				"Subtle": effect.params.merge({"rate_hz": 0.35, "depth": 0.35, "mix": 0.2}, true)
				"Deep": effect.params.merge({"rate_hz": 0.6, "depth": 0.85, "mix": 0.5}, true)
		"Tremolo":
			match preset_name:
				"Slow": effect.params.merge({"rate_hz": 2.0, "depth": 0.55}, true)
				"Fast": effect.params.merge({"rate_hz": 9.0, "depth": 0.6}, true)
				"Chopper": effect.params.merge({"rate_hz": 12.0, "depth": 1.0}, true)
		"Vibrato":
			match preset_name:
				"Subtle": effect.params.merge({"rate_hz": 5.0, "depth_ms": 2.0}, true)
				"Wide": effect.params.merge({"rate_hz": 6.0, "depth_ms": 8.0}, true)
		"Wah":
			match preset_name:
				"Slow Wah": effect.params.merge({"rate_hz": 0.7, "min_hz": 350.0, "max_hz": 2400.0, "resonance": 0.75}, true)
				"Fast Wah": effect.params.merge({"rate_hz": 3.5, "min_hz": 500.0, "max_hz": 3500.0, "resonance": 0.65}, true)
		"Ring Modulation":
			match preset_name:
				"Robot": effect.params.merge({"frequency_hz": 45.0, "mix": 0.8}, true)
				"Metallic": effect.params.merge({"frequency_hz": 220.0, "mix": 0.75}, true)
		"Change Speed":
			match preset_name:
				"Half Speed": effect.params["speed"] = 0.5
				"Double Speed": effect.params["speed"] = 2.0
		"Change Pitch":
			match preset_name:
				"+12 Semitones": effect.params["semitones"] = 12.0
				"+7 Semitones": effect.params["semitones"] = 7.0
				"-12 Semitones": effect.params["semitones"] = -12.0
		"Change Tempo":
			match preset_name:
				"75%": effect.params["tempo"] = 0.75
				"125%": effect.params["tempo"] = 1.25
				"150%": effect.params["tempo"] = 1.5
		"Sliding Stretch":
			match preset_name:
				"Pitch Rise": effect.params.merge({"start_pitch_semitones": -6.0, "end_pitch_semitones": 6.0}, true)
				"Pitch Fall": effect.params.merge({"start_pitch_semitones": 6.0, "end_pitch_semitones": -6.0}, true)
				"Accelerate": effect.params.merge({"start_tempo": 0.7, "end_tempo": 1.5}, true)
				"Decelerate": effect.params.merge({"start_tempo": 1.5, "end_tempo": 0.7}, true)
		"Repeat":
			match preset_name:
				"x2": effect.params["count"] = 2
				"x4": effect.params["count"] = 4
		"Truncate Silence":
			match preset_name:
				"Tight": effect.params.merge({"threshold_db": -42.0, "minimum_ms": 40.0, "target_ms": 5.0}, true)
				"Speech": effect.params.merge({"threshold_db": -48.0, "minimum_ms": 250.0, "target_ms": 80.0}, true)
		"Click Repair":
			match preset_name:
				"Light": effect.params.merge({"threshold": 0.65, "radius": 1}, true)
				"Strong": effect.params.merge({"threshold": 0.35, "radius": 3}, true)
		"Pop Removal":
			match preset_name:
				"Light": effect.params.merge({"threshold": 0.5, "radius": 2}, true)
				"Strong": effect.params.merge({"threshold": 0.28, "radius": 4}, true)
		"Clip Repair":
			match preset_name:
				"Light": effect.params["threshold"] = 0.995
				"Strong": effect.params["threshold"] = 0.97
		"De-esser":
			match preset_name:
				"Voice": effect.params.merge({"frequency_hz": 6500.0, "threshold_db": -24.0, "amount": 0.55}, true)
				"Strong": effect.params.merge({"frequency_hz": 5500.0, "threshold_db": -30.0, "amount": 0.75}, true)
		"Hum Removal":
			match preset_name:
				"50 Hz": effect.params["frequency_hz"] = 50.0
				"60 Hz": effect.params["frequency_hz"] = 60.0


static func parameter_specs(effect_type: String) -> Array[Dictionary]:
	var extension_id: StringName = _extension_id(effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		return extension.get_parameter_specs() if extension != null else []
	match effect_type:
		"Amplify": return [_spec("Gain dB", "gain_db", -48.0, 24.0, 0.1), _spec("Allow Clipping", "allow_clipping", 0.0, 1.0, 1.0)]
		"Normalize": return [_spec("Peak Target dB", "target_db", -12.0, 0.0, 0.1), _spec("Remove DC", "remove_dc", 0.0, 1.0, 1.0), _spec("Channels Together", "channels_together", 0.0, 1.0, 1.0)]
		"Loudness Normalize": return [_spec("Target RMS dB", "target_rms_db", -36.0, -6.0, 0.1)]
		"Low Pass": return [_spec("Cutoff Hz", "cutoff_hz", 20.0, 22000.0, 1.0), _spec("Resonance", "q", 0.1, 12.0, 0.1)]
		"High Pass": return [_spec("Cutoff Hz", "cutoff_hz", 20.0, 22000.0, 1.0), _spec("Resonance", "q", 0.1, 12.0, 0.1)]
		"Band Pass": return [_spec("Low Hz", "low_hz", 20.0, 20000.0, 1.0), _spec("High Hz", "high_hz", 40.0, 22000.0, 1.0)]
		"Band Limit": return [_spec("Low Hz", "low_hz", 20.0, 20000.0, 1.0), _spec("High Hz", "high_hz", 40.0, 22000.0, 1.0), _spec("Reject Band", "reject", 0.0, 1.0, 1.0)]
		"Notch": return [_spec("Frequency Hz", "frequency_hz", 20.0, 20000.0, 1.0), _spec("Q", "q", 0.2, 30.0, 0.1)]
		"Low Shelf": return [_spec("Frequency Hz", "frequency_hz", 20.0, 2000.0, 1.0), _spec("Gain dB", "gain_db", -18.0, 18.0, 0.1)]
		"High Shelf": return [_spec("Frequency Hz", "frequency_hz", 1000.0, 20000.0, 1.0), _spec("Gain dB", "gain_db", -18.0, 18.0, 0.1)]
		"Bass & Treble": return [_spec("Bass dB", "bass_db", -18.0, 18.0, 0.1), _spec("Treble dB", "treble_db", -18.0, 18.0, 0.1)]
		"Graphic EQ": return [_spec("Low dB", "low_db", -18.0, 18.0, 0.1), _spec("Mid dB", "mid_db", -18.0, 18.0, 0.1), _spec("High dB", "high_db", -18.0, 18.0, 0.1)]
		"Parametric EQ": return [_spec("Frequency Hz", "frequency_hz", 20.0, 20000.0, 1.0), _spec("Gain dB", "gain_db", -18.0, 18.0, 0.1), _spec("Q", "q", 0.1, 20.0, 0.1)]
		"Compressor": return [_spec("Threshold dB", "threshold_db", -60.0, 0.0, 0.1), _spec("Ratio", "ratio", 1.0, 20.0, 0.1), _spec("Attack ms", "attack_ms", 0.1, 200.0, 0.1), _spec("Release ms", "release_ms", 5.0, 1500.0, 1.0), _spec("Makeup dB", "makeup_db", -12.0, 24.0, 0.1)]
		"Limiter": return [_spec("Ceiling dB", "ceiling_db", -12.0, 0.0, 0.1), _spec("Input Gain dB", "input_gain_db", -12.0, 24.0, 0.1), _spec("Release ms", "release_ms", 5.0, 500.0, 1.0)]
		"Noise Gate": return [_spec("Threshold dB", "threshold_db", -80.0, -6.0, 0.1), _spec("Attack ms", "attack_ms", 0.1, 100.0, 0.1), _spec("Hold ms", "hold_ms", 0.0, 1000.0, 1.0), _spec("Release ms", "release_ms", 5.0, 1000.0, 1.0)]
		"Distortion": return [_spec("Drive", "drive", 0.1, 12.0, 0.1), _spec("Tone Hz", "tone_hz", 200.0, 22000.0, 10.0)]
		"Bitcrusher": return [_spec("Bits", "bits", 1.0, 16.0, 1.0), _spec("Sample Rate Hz", "sample_rate_hz", 500.0, 48000.0, 10.0)]
		"Delay": return [_spec("Delay ms", "delay_ms", 1.0, 2000.0, 1.0), _spec("Feedback", "feedback", 0.0, 0.9, 0.01), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Ping Pong Delay": return [_spec("Delay ms", "delay_ms", 1.0, 2000.0, 1.0), _spec("Feedback", "feedback", 0.0, 0.9, 0.01), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Reverb": return [_spec("Size", "size", 0.0, 1.0, 0.01), _spec("Damping", "damping", 0.0, 1.0, 0.01), _spec("Pre-delay ms", "predelay_ms", 0.0, 250.0, 1.0), _spec("Decay s", "decay_s", 0.15, 8.0, 0.05), _spec("Stereo Spread", "spread", 0.0, 1.0, 0.01), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Chorus": return [_spec("Rate Hz", "rate_hz", 0.05, 10.0, 0.01), _spec("Depth ms", "depth_ms", 0.1, 25.0, 0.1), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Flanger": return [_spec("Rate Hz", "rate_hz", 0.02, 10.0, 0.01), _spec("Depth ms", "depth_ms", 0.1, 10.0, 0.1), _spec("Feedback", "feedback", -0.9, 0.9, 0.01), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Phaser": return [_spec("Rate Hz", "rate_hz", 0.02, 10.0, 0.01), _spec("Depth", "depth", 0.0, 1.0, 0.01), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Tremolo": return [_spec("Rate Hz", "rate_hz", 0.05, 30.0, 0.01), _spec("Depth", "depth", 0.0, 1.0, 0.01)]
		"Vibrato": return [_spec("Rate Hz", "rate_hz", 0.05, 20.0, 0.01), _spec("Depth ms", "depth_ms", 0.1, 20.0, 0.1)]
		"Wah": return [_spec("Rate Hz", "rate_hz", 0.05, 10.0, 0.01), _spec("Min Hz", "min_hz", 50.0, 8000.0, 1.0), _spec("Max Hz", "max_hz", 100.0, 16000.0, 1.0), _spec("Resonance", "resonance", 0.0, 0.98, 0.01)]
		"Ring Modulation": return [_spec("Frequency Hz", "frequency_hz", 1.0, 5000.0, 1.0), _spec("Mix", "mix", 0.0, 1.0, 0.01)]
		"Change Speed": return [_spec("Speed", "speed", 0.25, 4.0, 0.01)]
		"Change Pitch": return [_spec("Semitones", "semitones", -24.0, 24.0, 0.1), _spec("Grain ms", "grain_ms", 12.0, 120.0, 1.0)]
		"Change Tempo": return [_spec("Tempo Ratio", "tempo", 0.25, 4.0, 0.01), _spec("Grain ms", "grain_ms", 12.0, 120.0, 1.0)]
		"Sliding Stretch": return [_spec("Start Pitch semitones", "start_pitch_semitones", -24.0, 24.0, 0.1), _spec("End Pitch semitones", "end_pitch_semitones", -24.0, 24.0, 0.1), _spec("Start Tempo", "start_tempo", 0.25, 4.0, 0.01), _spec("End Tempo", "end_tempo", 0.25, 4.0, 0.01), _spec("Segments", "segments", 4.0, 64.0, 1.0)]
		"Repeat": return [_spec("Count", "count", 2.0, 16.0, 1.0)]
		"Truncate Silence": return [_spec("Threshold dB", "threshold_db", -80.0, -6.0, 0.1), _spec("Minimum ms", "minimum_ms", 10.0, 5000.0, 1.0), _spec("Target ms", "target_ms", 0.0, 1000.0, 1.0)]
		"Click Repair": return [_spec("Threshold", "threshold", 0.05, 1.0, 0.01), _spec("Radius", "radius", 1.0, 8.0, 1.0)]
		"Pop Removal": return [_spec("Threshold", "threshold", 0.05, 1.0, 0.01), _spec("Radius", "radius", 1.0, 8.0, 1.0)]
		"Clip Repair": return [_spec("Clip Threshold", "threshold", 0.8, 1.0, 0.001)]
		"Interpolate Selection": return []
		"De-esser": return [_spec("Frequency Hz", "frequency_hz", 2000.0, 12000.0, 10.0), _spec("Threshold dB", "threshold_db", -60.0, 0.0, 0.1), _spec("Amount", "amount", 0.0, 1.0, 0.01)]
		"Hum Removal": return [_spec("Base Frequency Hz", "frequency_hz", 40.0, 120.0, 1.0), _spec("Harmonics", "harmonics", 1.0, 8.0, 1.0), _spec("Q", "q", 2.0, 30.0, 0.1)]
		_: return []


static func process(input: GASPCMData, effect: GASEffectData) -> GASPCMData:
	if input == null:
		return null
	if effect == null or not effect.enabled:
		return input.duplicate_pcm()
	var output: GASPCMData = input.duplicate_pcm()
	var dry: GASPCMData = input if effect.wet < 0.9999 else null
	output = _apply_effect_existing(output, effect)
	if dry != null:
		_mix_wet_dry(output, dry, effect.wet)
	return output


static func process_stack(input: GASPCMData, stack: Array[GASEffectData]) -> GASPCMData:
	if input == null:
		return null
	var current: GASPCMData = input.duplicate_pcm()
	if stack.is_empty():
		return current
	for effect: GASEffectData in stack:
		if effect == null or not effect.enabled:
			continue
		var dry: GASPCMData = current.duplicate_pcm() if effect.wet < 0.9999 else null
		current = _apply_effect_existing(current, effect)
		if dry != null:
			_mix_wet_dry(current, dry, effect.wet)
	return current


static func _apply_effect_existing(output: GASPCMData, effect: GASEffectData) -> GASPCMData:
	var extension_id: StringName = _extension_id(effect.effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		if extension == null:
			return output
		var processed: GASPCMData = extension.process(output, effect.params)
		return processed if processed != null else output
	match effect.effect_type:
		"Amplify": _amplify(output, float(effect.params.get("gain_db", 0.0)), int(effect.params.get("allow_clipping", 0)) != 0)
		"Normalize": _normalize(output, float(effect.params.get("target_db", -1.0)), int(effect.params.get("remove_dc", 1)) != 0, int(effect.params.get("channels_together", 1)) != 0)
		"Loudness Normalize": _loudness_normalize(output, float(effect.params.get("target_rms_db", -14.0)))
		"Fade In": _fade_curve(output, true, int(effect.params.get("curve", 0)))
		"Fade Out": _fade_curve(output, false, int(effect.params.get("curve", 0)))
		"Adjustable Fade": _adjustable_fade(output, float(effect.params.get("start_db", -80.0)), float(effect.params.get("end_db", 0.0)), int(effect.params.get("curve", 0)))
		"Studio Fade": _studio_fade(output)
		"Reverse": _reverse(output)
		"Invert": _invert(output)
		"Remove DC Offset": _remove_dc(output)
		"Low Pass": _filter_biquad(output, 0, float(effect.params.get("cutoff_hz", 6000.0)), float(effect.params.get("q", 0.707)))
		"High Pass": _filter_biquad(output, 1, float(effect.params.get("cutoff_hz", 80.0)), float(effect.params.get("q", 0.707)))
		"Band Pass": _band_pass(output, float(effect.params.get("low_hz", 300.0)), float(effect.params.get("high_hz", 3400.0)))
		"Band Limit": _band_limit(output, float(effect.params.get("low_hz", 300.0)), float(effect.params.get("high_hz", 3400.0)), bool(int(effect.params.get("reject", 0))))
		"Notch": _filter_biquad(output, 2, float(effect.params.get("frequency_hz", 60.0)), float(effect.params.get("q", 8.0)))
		"Low Shelf": _shelf(output, false, float(effect.params.get("frequency_hz", 180.0)), float(effect.params.get("gain_db", 0.0)))
		"High Shelf": _shelf(output, true, float(effect.params.get("frequency_hz", 6000.0)), float(effect.params.get("gain_db", 0.0)))
		"Bass & Treble": _bass_treble(output, float(effect.params.get("bass_db", 0.0)), float(effect.params.get("treble_db", 0.0)))
		"Graphic EQ": _graphic_eq(output, float(effect.params.get("low_db", 0.0)), float(effect.params.get("mid_db", 0.0)), float(effect.params.get("high_db", 0.0)))
		"Parametric EQ": _parametric_eq(output, float(effect.params.get("frequency_hz", 1000.0)), float(effect.params.get("gain_db", 0.0)), float(effect.params.get("q", 1.0)))
		"Compressor": _compressor(output, effect.params)
		"Limiter": _limiter(output, effect.params)
		"Noise Gate": _noise_gate(output, effect.params)
		"Distortion": _distortion(output, effect.params)
		"Bitcrusher": _bitcrusher(output, int(effect.params.get("bits", 8)), float(effect.params.get("sample_rate_hz", 11025.0)))
		"Delay": output = _delay(output, effect.params)
		"Ping Pong Delay": output = _ping_pong_delay(output, effect.params)
		"Reverb": output = _reverb(output, effect.params)
		"Chorus": _mod_delay(output, effect.params, 0)
		"Flanger": _mod_delay(output, effect.params, 1)
		"Phaser": _phaser(output, effect.params)
		"Tremolo": _tremolo(output, effect.params)
		"Vibrato": _vibrato(output, effect.params)
		"Wah": _wah(output, effect.params)
		"Ring Modulation": _ring_mod(output, effect.params)
		"Change Speed": output = _change_speed(output, float(effect.params.get("speed", 1.0)))
		"Change Pitch": output = _granular_pitch(output, float(effect.params.get("semitones", 0.0)), float(effect.params.get("grain_ms", 40.0)))
		"Change Tempo": output = _granular_tempo(output, float(effect.params.get("tempo", 1.0)), float(effect.params.get("grain_ms", 40.0)))
		"Sliding Stretch": output = _sliding_stretch(output, effect.params)
		"Repeat": output = _repeat_pcm(output, int(effect.params.get("count", 2)))
		"Truncate Silence": output = _truncate_silence(output, effect.params)
		"Click Repair": _click_repair(output, float(effect.params.get("threshold", 0.5)), int(effect.params.get("radius", 2)))
		"Pop Removal": _click_repair(output, float(effect.params.get("threshold", 0.35)), int(effect.params.get("radius", 3)))
		"Clip Repair": _clip_repair(output, float(effect.params.get("threshold", 0.985)))
		"Interpolate Selection": _interpolate_full(output)
		"De-esser": _deesser(output, effect.params)
		"Hum Removal": _hum_removal(output, effect.params)
		_: pass
	return output


static func _default_params(effect_type: String) -> Dictionary:
	match effect_type:
		"Amplify": return {"gain_db": 3.0, "allow_clipping": 0}
		"Normalize": return {"target_db": -1.0, "remove_dc": 1, "channels_together": 1}
		"Loudness Normalize": return {"target_rms_db": -14.0}
		"Fade In", "Fade Out": return {"curve": 0}
		"Adjustable Fade": return {"start_db": -80.0, "end_db": 0.0, "curve": 0}
		"Studio Fade": return {}
		"Low Pass": return {"cutoff_hz": 6000.0, "q": 0.707}
		"High Pass": return {"cutoff_hz": 80.0, "q": 0.707}
		"Band Pass": return {"low_hz": 300.0, "high_hz": 3400.0}
		"Band Limit": return {"low_hz": 300.0, "high_hz": 3400.0, "reject": 0}
		"Notch": return {"frequency_hz": 60.0, "q": 8.0}
		"Low Shelf": return {"frequency_hz": 180.0, "gain_db": 0.0}
		"High Shelf": return {"frequency_hz": 6000.0, "gain_db": 0.0}
		"Bass & Treble": return {"bass_db": 0.0, "treble_db": 0.0}
		"Graphic EQ": return {"low_db": 0.0, "mid_db": 0.0, "high_db": 0.0}
		"Parametric EQ": return {"frequency_hz": 1000.0, "gain_db": 0.0, "q": 1.0}
		"Compressor": return {"threshold_db": -18.0, "ratio": 3.0, "attack_ms": 10.0, "release_ms": 120.0, "makeup_db": 2.0}
		"Limiter": return {"ceiling_db": -1.0, "input_gain_db": 0.0, "release_ms": 60.0}
		"Noise Gate": return {"threshold_db": -45.0, "attack_ms": 2.0, "hold_ms": 20.0, "release_ms": 100.0}
		"Distortion": return {"mode": "Soft Clip", "drive": 2.0, "tone_hz": 18000.0}
		"Bitcrusher": return {"bits": 8, "sample_rate_hz": 11025.0}
		"Delay": return {"delay_ms": 320.0, "feedback": 0.46, "mix": 0.52}
		"Ping Pong Delay": return {"delay_ms": 300.0, "feedback": 0.50, "mix": 0.56}
		"Reverb": return {"size": 0.78, "damping": 0.30, "predelay_ms": 42.0, "decay_s": 3.2, "spread": 0.88, "mix": 0.72}
		"Chorus": return {"rate_hz": 0.8, "depth_ms": 8.5, "mix": 0.44}
		"Flanger": return {"rate_hz": 0.3, "depth_ms": 2.8, "feedback": 0.38, "mix": 0.46}
		"Phaser": return {"rate_hz": 0.45, "depth": 0.78, "mix": 0.50}
		"Tremolo": return {"rate_hz": 5.0, "depth": 0.5}
		"Vibrato": return {"rate_hz": 5.0, "depth_ms": 4.0}
		"Wah": return {"rate_hz": 1.5, "min_hz": 400.0, "max_hz": 2800.0, "resonance": 0.7}
		"Ring Modulation": return {"frequency_hz": 80.0, "mix": 0.7}
		"Change Speed": return {"speed": 1.0}
		"Change Pitch": return {"semitones": 0.0, "grain_ms": 40.0}
		"Change Tempo": return {"tempo": 1.0, "grain_ms": 40.0}
		"Sliding Stretch": return {"start_pitch_semitones": 0.0, "end_pitch_semitones": 0.0, "start_tempo": 1.0, "end_tempo": 1.0, "segments": 16}
		"Repeat": return {"count": 2}
		"Truncate Silence": return {"threshold_db": -50.0, "minimum_ms": 200.0, "target_ms": 50.0}
		"Click Repair": return {"threshold": 0.5, "radius": 2}
		"Pop Removal": return {"threshold": 0.35, "radius": 3}
		"Clip Repair": return {"threshold": 0.985}
		"Interpolate Selection": return {}
		"De-esser": return {"frequency_hz": 6500.0, "threshold_db": -24.0, "amount": 0.55}
		"Hum Removal": return {"frequency_hz": 60.0, "harmonics": 4, "q": 12.0}
		_: return {}


static func _spec(label: String, key: String, minimum: float, maximum: float, step: float) -> Dictionary:
	return {"label": label, "key": key, "min": minimum, "max": maximum, "step": step}


static func _amplify(pcm: GASPCMData, gain_db: float, allow_clipping: bool) -> void:
	var gain: float = db_to_linear(gain_db)
	_scale_channel_limit(pcm.left, gain, allow_clipping)
	if pcm.is_stereo():
		_scale_channel_limit(pcm.right, gain, allow_clipping)


static func _normalize(pcm: GASPCMData, target_db: float, remove_dc: bool, channels_together: bool) -> void:
	if remove_dc:
		_remove_dc(pcm)
	var target: float = db_to_linear(target_db)
	if pcm.is_stereo() and not channels_together:
		_normalize_channel(pcm.left, target)
		_normalize_channel(pcm.right, target)
		return
	var peak: float = 0.0
	for value: float in pcm.left:
		peak = maxf(peak, absf(value))
	if pcm.is_stereo():
		for value: float in pcm.right:
			peak = maxf(peak, absf(value))
	if peak <= 0.000001:
		return
	var gain: float = target / peak
	_scale_channel_limit(pcm.left, gain, false)
	if pcm.is_stereo():
		_scale_channel_limit(pcm.right, gain, false)


static func _normalize_channel(samples: PackedFloat32Array, target: float) -> void:
	var peak: float = 0.0
	for value: float in samples:
		peak = maxf(peak, absf(value))
	if peak <= 0.000001:
		return
	_scale_channel_limit(samples, target / peak, false)


static func _fade(pcm: GASPCMData, fade_in: bool) -> void:
	_fade_curve(pcm, fade_in, 0)


static func _curve_gain(u: float, curve: int) -> float:
	var t: float = clampf(u, 0.0, 1.0)
	match curve:
		1:
			return log(1.0 + 9.0 * t) / log(10.0)
		2:
			return t * t
		3:
			return t * t * (3.0 - 2.0 * t)
		4:
			return sin(t * PI * 0.5)
		_:
			return t


static func _fade_curve(pcm: GASPCMData, fade_in: bool, curve: int) -> void:
	var count: int = pcm.frame_count()
	if count <= 1:
		return
	var stereo: bool = pcm.is_stereo()
	for i: int in range(count):
		var u: float = float(i) / float(count - 1)
		var gain: float = _curve_gain(u if fade_in else 1.0 - u, curve)
		pcm.left[i] *= gain
		if stereo:
			pcm.right[i] *= gain


static func _adjustable_fade(pcm: GASPCMData, start_db: float, end_db: float, curve: int) -> void:
	var count: int = pcm.frame_count()
	if count <= 1:
		return
	var start_gain: float = db_to_linear(start_db)
	var end_gain: float = db_to_linear(end_db)
	var stereo: bool = pcm.is_stereo()
	for i: int in range(count):
		var u: float = float(i) / float(count - 1)
		var shaped: float = _curve_gain(u, curve)
		var gain: float = lerpf(start_gain, end_gain, shaped)
		pcm.left[i] *= gain
		if stereo:
			pcm.right[i] *= gain


static func _studio_fade(pcm: GASPCMData) -> void:
	# Audacity-style studio fade character: slow early decay followed by a smooth tail.
	var count: int = pcm.frame_count()
	if count <= 1:
		return
	var stereo: bool = pcm.is_stereo()
	for i: int in range(count):
		var u: float = float(i) / float(count - 1)
		var gain: float = pow(maxf(0.0, 1.0 - u), 1.55) * (1.0 - 0.12 * sin(PI * u))
		pcm.left[i] *= gain
		if stereo:
			pcm.right[i] *= gain


static func _reverse(pcm: GASPCMData) -> void:
	pcm.left.reverse()
	if pcm.is_stereo():
		pcm.right.reverse()


static func _invert(pcm: GASPCMData) -> void:
	for i: int in range(pcm.frame_count()):
		pcm.left[i] = -pcm.left[i]
		if pcm.is_stereo():
			pcm.right[i] = -pcm.right[i]


static func _remove_dc(pcm: GASPCMData) -> void:
	_remove_dc_channel(pcm.left)
	if pcm.is_stereo():
		_remove_dc_channel(pcm.right)


static func _remove_dc_channel(samples: PackedFloat32Array) -> void:
	if samples.is_empty():
		return
	var sum: float = 0.0
	for value: float in samples:
		sum += value
	var mean: float = sum / float(samples.size())
	for i: int in range(samples.size()):
		samples[i] -= mean


static func _band_limit(pcm: GASPCMData, low_hz: float, high_hz: float, reject_band: bool) -> void:
	if not reject_band:
		_band_pass(pcm, low_hz, high_hz)
		return
	var original_left: PackedFloat32Array = pcm.left.duplicate()
	var original_right: PackedFloat32Array = pcm.right.duplicate()
	var band: GASPCMData = pcm.duplicate_pcm()
	_band_pass(band, low_hz, high_hz)
	for i: int in range(pcm.frame_count()):
		pcm.left[i] = clampf(original_left[i] - band.left[i], -1.0, 1.0)
		if pcm.is_stereo():
			pcm.right[i] = clampf(original_right[i] - band.right[i], -1.0, 1.0)


static func _filter_biquad(pcm: GASPCMData, mode: int, frequency_hz: float, q: float) -> void:
	_process_biquad_channel(pcm.left, pcm.sample_rate, mode, frequency_hz, q)
	if pcm.is_stereo():
		_process_biquad_channel(pcm.right, pcm.sample_rate, mode, frequency_hz, q)


static func _process_biquad_channel(samples: PackedFloat32Array, sample_rate: int, mode: int, frequency_hz: float, q: float) -> void:
	var f: float = clampf(frequency_hz, 10.0, float(sample_rate) * 0.48)
	var qv: float = maxf(0.05, q)
	var omega: float = TAU * f / float(sample_rate)
	var cos_w: float = cos(omega)
	var sin_w: float = sin(omega)
	var alpha: float = sin_w / (2.0 * qv)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cos_w
	var a2: float = 1.0 - alpha
	if mode == 0:
		b0 = (1.0 - cos_w) * 0.5
		b1 = 1.0 - cos_w
		b2 = b0
	elif mode == 1:
		b0 = (1.0 + cos_w) * 0.5
		b1 = -(1.0 + cos_w)
		b2 = b0
	else:
		b0 = 1.0
		b1 = -2.0 * cos_w
		b2 = 1.0
	var ia0: float = 1.0 / a0
	b0 *= ia0; b1 *= ia0; b2 *= ia0; a1 *= ia0; a2 *= ia0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in range(samples.size()):
		var x0: float = samples[i]
		var y0: float = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		samples[i] = clampf(y0, -1.5, 1.5)
		x2 = x1; x1 = x0; y2 = y1; y1 = y0


static func _band_pass(pcm: GASPCMData, low_hz: float, high_hz: float) -> void:
	var lo: float = minf(low_hz, high_hz - 10.0)
	var hi: float = maxf(high_hz, lo + 10.0)
	_filter_biquad(pcm, 1, lo, 0.707)
	_filter_biquad(pcm, 0, hi, 0.707)


static func _bass_treble(pcm: GASPCMData, bass_db: float, treble_db: float) -> void:
	_bass_treble_channel(pcm.left, pcm.sample_rate, bass_db, treble_db)
	if pcm.is_stereo():
		_bass_treble_channel(pcm.right, pcm.sample_rate, bass_db, treble_db)


static func _bass_treble_channel(samples: PackedFloat32Array, sample_rate: int, bass_db: float, treble_db: float) -> void:
	var bass_gain: float = db_to_linear(bass_db) - 1.0
	var treble_gain: float = db_to_linear(treble_db) - 1.0
	var low_alpha: float = 1.0 - exp(-TAU * 250.0 / float(sample_rate))
	var high_alpha: float = 1.0 - exp(-TAU * 4000.0 / float(sample_rate))
	var low_state: float = 0.0
	var smooth_state: float = 0.0
	for i: int in range(samples.size()):
		var x: float = samples[i]
		low_state += (x - low_state) * low_alpha
		smooth_state += (x - smooth_state) * high_alpha
		var high: float = x - smooth_state
		samples[i] = clampf(x + low_state * bass_gain + high * treble_gain, -1.5, 1.5)


static func _graphic_eq(pcm: GASPCMData, low_db: float, mid_db: float, high_db: float) -> void:
	_graphic_eq_channel(pcm.left, pcm.sample_rate, low_db, mid_db, high_db)
	if pcm.is_stereo():
		_graphic_eq_channel(pcm.right, pcm.sample_rate, low_db, mid_db, high_db)


static func _graphic_eq_channel(samples: PackedFloat32Array, sample_rate: int, low_db: float, mid_db: float, high_db: float) -> void:
	var low_gain: float = db_to_linear(low_db)
	var mid_gain: float = db_to_linear(mid_db)
	var high_gain: float = db_to_linear(high_db)
	var low_alpha: float = 1.0 - exp(-TAU * 300.0 / float(sample_rate))
	var high_alpha: float = 1.0 - exp(-TAU * 3500.0 / float(sample_rate))
	var low_state: float = 0.0
	var high_smooth: float = 0.0
	for i: int in range(samples.size()):
		var x: float = samples[i]
		low_state += (x - low_state) * low_alpha
		high_smooth += (x - high_smooth) * high_alpha
		var low: float = low_state
		var high: float = x - high_smooth
		var mid: float = x - low - high
		samples[i] = clampf(low * low_gain + mid * mid_gain + high * high_gain, -1.5, 1.5)


static func _loudness_normalize(pcm: GASPCMData, target_rms_db: float) -> void:
	var sum_squares: float = 0.0
	var sample_count: int = pcm.frame_count() * pcm.channels
	if sample_count <= 0:
		return
	for value: float in pcm.left:
		sum_squares += value * value
	if pcm.is_stereo():
		for value: float in pcm.right:
			sum_squares += value * value
	var rms: float = sqrt(sum_squares / float(sample_count))
	if rms <= 0.000001:
		return
	var target: float = db_to_linear(target_rms_db)
	var gain: float = target / rms
	_scale_channel(pcm.left, gain)
	if pcm.is_stereo():
		_scale_channel(pcm.right, gain)


static func _shelf(pcm: GASPCMData, high_shelf: bool, frequency_hz: float, gain_db: float) -> void:
	_shelf_channel(pcm.left, pcm.sample_rate, high_shelf, frequency_hz, gain_db)
	if pcm.is_stereo():
		_shelf_channel(pcm.right, pcm.sample_rate, high_shelf, frequency_hz, gain_db)


static func _shelf_channel(samples: PackedFloat32Array, sample_rate: int, high_shelf: bool, frequency_hz: float, gain_db: float) -> void:
	var alpha: float = 1.0 - exp(-TAU * clampf(frequency_hz, 20.0, float(sample_rate) * 0.45) / float(sample_rate))
	var state: float = 0.0
	var gain_delta: float = db_to_linear(gain_db) - 1.0
	for i: int in range(samples.size()):
		var x: float = samples[i]
		state += (x - state) * alpha
		var band: float = x - state if high_shelf else state
		samples[i] = clampf(x + band * gain_delta, -1.5, 1.5)


static func _parametric_eq(pcm: GASPCMData, frequency_hz: float, gain_db: float, q: float) -> void:
	_parametric_eq_channel(pcm.left, pcm.sample_rate, frequency_hz, gain_db, q)
	if pcm.is_stereo():
		_parametric_eq_channel(pcm.right, pcm.sample_rate, frequency_hz, gain_db, q)


static func _parametric_eq_channel(samples: PackedFloat32Array, sample_rate: int, frequency_hz: float, gain_db: float, q: float) -> void:
	var frequency: float = clampf(frequency_hz, 20.0, float(sample_rate) * 0.48)
	var amplitude: float = pow(10.0, gain_db / 40.0)
	var omega: float = TAU * frequency / float(sample_rate)
	var alpha: float = sin(omega) / (2.0 * maxf(0.1, q))
	var cos_w: float = cos(omega)
	var b0: float = 1.0 + alpha * amplitude
	var b1: float = -2.0 * cos_w
	var b2: float = 1.0 - alpha * amplitude
	var a0: float = 1.0 + alpha / amplitude
	var a1: float = -2.0 * cos_w
	var a2: float = 1.0 - alpha / amplitude
	var inv_a0: float = 1.0 / a0
	b0 *= inv_a0
	b1 *= inv_a0
	b2 *= inv_a0
	a1 *= inv_a0
	a2 *= inv_a0
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	for i: int in range(samples.size()):
		var x0: float = samples[i]
		var y0: float = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		samples[i] = clampf(y0, -1.5, 1.5)
		x2 = x1
		x1 = x0
		y2 = y1
		y1 = y0


static func _compressor(pcm: GASPCMData, params: Dictionary) -> void:
	var threshold: float = db_to_linear(float(params.get("threshold_db", -18.0)))
	var ratio: float = maxf(1.0, float(params.get("ratio", 3.0)))
	var attack: float = _time_coefficient(float(params.get("attack_ms", 10.0)), pcm.sample_rate)
	var release: float = _time_coefficient(float(params.get("release_ms", 120.0)), pcm.sample_rate)
	var makeup: float = db_to_linear(float(params.get("makeup_db", 2.0)))
	_compressor_channel(pcm.left, threshold, ratio, attack, release, makeup)
	if pcm.is_stereo():
		_compressor_channel(pcm.right, threshold, ratio, attack, release, makeup)


static func _compressor_channel(samples: PackedFloat32Array, threshold: float, ratio: float, attack: float, release: float, makeup: float) -> void:
	var envelope: float = 0.0
	for i: int in range(samples.size()):
		var level: float = absf(samples[i])
		var coeff: float = attack if level > envelope else release
		envelope = level + coeff * (envelope - level)
		var gain: float = 1.0
		if envelope > threshold:
			var compressed: float = threshold + (envelope - threshold) / ratio
			gain = compressed / maxf(envelope, 0.000001)
		samples[i] = clampf(samples[i] * gain * makeup, -1.2, 1.2)


static func _limiter(pcm: GASPCMData, params: Dictionary) -> void:
	var ceiling: float = db_to_linear(float(params.get("ceiling_db", -1.0)))
	var input_gain: float = db_to_linear(float(params.get("input_gain_db", 0.0)))
	var release: float = _time_coefficient(float(params.get("release_ms", 60.0)), pcm.sample_rate)
	_limiter_channel(pcm.left, ceiling, input_gain, release)
	if pcm.is_stereo():
		_limiter_channel(pcm.right, ceiling, input_gain, release)


static func _limiter_channel(samples: PackedFloat32Array, ceiling: float, input_gain: float, release: float) -> void:
	var gain: float = 1.0
	for i: int in range(samples.size()):
		var x: float = samples[i] * input_gain
		var level: float = absf(x)
		var target_gain: float = minf(1.0, ceiling / maxf(level, 0.000001))
		if target_gain < gain:
			gain = target_gain
		else:
			gain = target_gain + release * (gain - target_gain)
		samples[i] = clampf(x * gain, -ceiling, ceiling)


static func _noise_gate(pcm: GASPCMData, params: Dictionary) -> void:
	var threshold: float = db_to_linear(float(params.get("threshold_db", -45.0)))
	var attack: float = _time_coefficient(float(params.get("attack_ms", 2.0)), pcm.sample_rate)
	var release: float = _time_coefficient(float(params.get("release_ms", 100.0)), pcm.sample_rate)
	var hold_frames: int = maxi(0, int(round(float(params.get("hold_ms", 20.0)) * 0.001 * float(pcm.sample_rate))))
	_gate_channel(pcm.left, threshold, attack, release, hold_frames)
	if pcm.is_stereo():
		_gate_channel(pcm.right, threshold, attack, release, hold_frames)


static func _gate_channel(samples: PackedFloat32Array, threshold: float, attack: float, release: float, hold_frames: int) -> void:
	var gain: float = 0.0
	var hold_counter: int = 0
	for i: int in range(samples.size()):
		var open_gate: bool = absf(samples[i]) >= threshold
		if open_gate:
			hold_counter = hold_frames
		elif hold_counter > 0:
			hold_counter -= 1
		var target: float = 1.0 if open_gate or hold_counter > 0 else 0.0
		var coeff: float = attack if target > gain else release
		gain = target + coeff * (gain - target)
		samples[i] *= gain


static func _distortion(pcm: GASPCMData, params: Dictionary) -> void:
	var mode: String = str(params.get("mode", "Soft Clip"))
	var drive: float = maxf(0.01, float(params.get("drive", 2.0)))
	var tone_hz: float = float(params.get("tone_hz", 18000.0))
	_distortion_channel(pcm.left, mode, drive)
	if pcm.is_stereo():
		_distortion_channel(pcm.right, mode, drive)
	if tone_hz < float(pcm.sample_rate) * 0.48:
		_filter_biquad(pcm, 0, tone_hz, 0.707)


static func _distortion_channel(samples: PackedFloat32Array, mode: String, drive: float) -> void:
	var normalizer: float = 1.0 / maxf(0.001, tanh(drive))
	for i: int in range(samples.size()):
		var x: float = samples[i]
		var y: float = x
		match mode:
			"Hard Clip": y = clampf(x * drive, -0.65, 0.65) / 0.65
			"Saturation": y = (2.0 / PI) * atan(x * drive * 2.0)
			"Overdrive": y = tanh(x * drive) * normalizer
			"Digital": y = round(clampf(x * drive, -1.0, 1.0) * 31.0) / 31.0
			"Rectifier": y = absf(x * drive) * 2.0 - 1.0
			"Foldback": y = absf(fposmod(x * drive + 1.0, 4.0) - 2.0) - 1.0
			_: y = tanh(x * drive) * normalizer
		samples[i] = clampf(y, -1.0, 1.0)


static func _bitcrusher(pcm: GASPCMData, bits: int, rate_hz: float) -> void:
	_bitcrusher_channel(pcm.left, pcm.sample_rate, bits, rate_hz)
	if pcm.is_stereo():
		_bitcrusher_channel(pcm.right, pcm.sample_rate, bits, rate_hz)


static func _bitcrusher_channel(samples: PackedFloat32Array, sample_rate: int, bits: int, rate_hz: float) -> void:
	var levels: float = float((1 << clampi(bits, 1, 16)) - 1)
	var hold_frames: int = maxi(1, int(round(float(sample_rate) / clampf(rate_hz, 1.0, float(sample_rate)))))
	var held: float = 0.0
	var counter: int = 0
	for i: int in range(samples.size()):
		if counter <= 0:
			var n: float = clampf(samples[i] * 0.5 + 0.5, 0.0, 1.0)
			held = (round(n * levels) / levels) * 2.0 - 1.0
			counter = hold_frames
		samples[i] = held
		counter -= 1


static func tail_frames(effect: GASEffectData, sample_rate: int) -> int:
	if effect == null or not effect.enabled or sample_rate <= 0:
		return 0
	var extension_id: StringName = _extension_id(effect.effect_type)
	if not str(extension_id).is_empty():
		var extension: GASEditorEffectExtension = ExtensionAPI.create_editor_effect(extension_id)
		return maxi(0, extension.get_tail_frames(effect.params, sample_rate)) if extension != null else 0
	match effect.effect_type:
		"Delay", "Ping Pong Delay":
			var delay_ms: float = maxf(1.0, float(effect.params.get("delay_ms", 320.0)))
			var feedback: float = clampf(float(effect.params.get("feedback", 0.46)), 0.0, 0.92)
			var repeats: int = 1
			var level: float = feedback
			while level > 0.015 and repeats < 18:
				repeats += 1
				level *= feedback
			var seconds: float = minf(8.0, delay_ms * 0.001 * float(repeats))
			return int(round(seconds * float(sample_rate)))
		"Reverb":
			var decay_s: float = clampf(float(effect.params.get("decay_s", 3.2)), 0.15, 8.0)
			var predelay_s: float = clampf(float(effect.params.get("predelay_ms", 42.0)), 0.0, 250.0) * 0.001
			return int(round((decay_s + predelay_s) * float(sample_rate)))
		_:
			return 0


static func stack_tail_frames(stack: Array[GASEffectData], sample_rate: int) -> int:
	var total: int = 0
	for effect: GASEffectData in stack:
		total += tail_frames(effect, sample_rate)
	return mini(total, sample_rate * 12)


static func _extend_pcm(pcm: GASPCMData, extra_frames: int) -> GASPCMData:
	if pcm == null or extra_frames <= 0:
		return pcm
	var out: GASPCMData = pcm.duplicate_pcm()
	var old_count: int = out.frame_count()
	var new_count: int = old_count + extra_frames
	out.left.resize(new_count)
	if out.is_stereo():
		out.right.resize(new_count)
	return out


static func _delay(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	var delay_frames: int = maxi(1, int(round(float(params.get("delay_ms", 320.0)) * 0.001 * float(pcm.sample_rate))))
	var feedback: float = clampf(float(params.get("feedback", 0.46)), 0.0, 0.92)
	var mix: float = clampf(float(params.get("mix", 0.52)), 0.0, 1.0)
	var temp: GASEffectData = EffectData.new()
	temp.effect_type = "Delay"
	temp.params = params
	var out: GASPCMData = _extend_pcm(pcm, tail_frames(temp, pcm.sample_rate))
	_delay_channel(out.left, pcm.frame_count(), delay_frames, feedback, mix)
	if out.is_stereo():
		_delay_channel(out.right, pcm.frame_count(), delay_frames, feedback, mix)
	return out


static func _delay_channel(samples: PackedFloat32Array, dry_count: int, delay_frames: int, feedback: float, mix: float) -> void:
	var dry: PackedFloat32Array = samples.duplicate()
	var wet: PackedFloat32Array = PackedFloat32Array()
	wet.resize(samples.size())
	for i: int in range(samples.size()):
		var source: float = dry[i] if i < dry_count else 0.0
		var delayed: float = wet[i - delay_frames] if i >= delay_frames else 0.0
		wet[i] = clampf(source + delayed * feedback, -1.4, 1.4)
		var dry_value: float = source
		var echo_only: float = wet[i] - source
		samples[i] = clampf(dry_value + echo_only * mix, -1.2, 1.2)


static func _ping_pong_delay(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	var delay_frames: int = maxi(1, int(round(float(params.get("delay_ms", 300.0)) * 0.001 * float(pcm.sample_rate))))
	var feedback: float = clampf(float(params.get("feedback", 0.50)), 0.0, 0.92)
	var mix: float = clampf(float(params.get("mix", 0.56)), 0.0, 1.0)
	var temp: GASEffectData = EffectData.new()
	temp.effect_type = "Ping Pong Delay"
	temp.params = params
	var out: GASPCMData = _extend_pcm(pcm, tail_frames(temp, pcm.sample_rate))
	if not out.is_stereo():
		out.channels = 2
		out.right = out.left.duplicate()
	var dry_count: int = pcm.frame_count()
	var dry_left: PackedFloat32Array = out.left.duplicate()
	var dry_right: PackedFloat32Array = out.right.duplicate()
	var wet_left: PackedFloat32Array = PackedFloat32Array()
	var wet_right: PackedFloat32Array = PackedFloat32Array()
	wet_left.resize(out.frame_count())
	wet_right.resize(out.frame_count())
	for i: int in range(out.frame_count()):
		var source_left: float = dry_left[i] if i < dry_count else 0.0
		var source_right: float = dry_right[i] if i < dry_count else 0.0
		var delayed_left: float = wet_right[i - delay_frames] if i >= delay_frames else 0.0
		var delayed_right: float = wet_left[i - delay_frames] if i >= delay_frames else 0.0
		wet_left[i] = clampf(source_left + delayed_left * feedback, -1.4, 1.4)
		wet_right[i] = clampf(source_right + delayed_right * feedback, -1.4, 1.4)
		out.left[i] = clampf(source_left + (wet_left[i] - source_left) * mix, -1.2, 1.2)
		out.right[i] = clampf(source_right + (wet_right[i] - source_right) * mix, -1.2, 1.2)
	return out


static func _reverb(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	var size: float = clampf(float(params.get("size", 0.78)), 0.0, 1.0)
	var damping: float = clampf(float(params.get("damping", 0.30)), 0.0, 1.0)
	var predelay_ms: float = clampf(float(params.get("predelay_ms", 42.0)), 0.0, 250.0)
	var decay_s: float = clampf(float(params.get("decay_s", 3.2)), 0.15, 8.0)
	var spread: float = clampf(float(params.get("spread", 0.88)), 0.0, 1.0)
	var mix: float = clampf(float(params.get("mix", 0.72)), 0.0, 1.0)
	var temp: GASEffectData = EffectData.new()
	temp.effect_type = "Reverb"
	temp.params = params
	var out: GASPCMData = _extend_pcm(pcm, tail_frames(temp, pcm.sample_rate))
	_reverb_channel(out.left, pcm.frame_count(), pcm.sample_rate, size, damping, predelay_ms, decay_s, mix, 0.0)
	if out.is_stereo():
		_reverb_channel(out.right, pcm.frame_count(), pcm.sample_rate, size, damping, predelay_ms, decay_s, mix, spread)
	return out


static func _reverb_channel(samples: PackedFloat32Array, dry_count: int, sample_rate: int, size: float, damping: float, predelay_ms: float, decay_s: float, mix: float, stereo_offset: float) -> void:
	var dry: PackedFloat32Array = samples.duplicate()
	var wet: PackedFloat32Array = PackedFloat32Array()
	wet.resize(samples.size())
	var predelay: int = maxi(0, int(round(predelay_ms * 0.001 * float(sample_rate))))
	var spread_scale: float = 1.0 + stereo_offset * 0.083
	var delays: PackedInt32Array = PackedInt32Array([
		maxi(1, int(round((0.0237 + size * 0.018) * spread_scale * float(sample_rate)))),
		maxi(1, int(round((0.0297 + size * 0.024) / spread_scale * float(sample_rate)))),
		maxi(1, int(round((0.0371 + size * 0.031) * spread_scale * float(sample_rate)))),
		maxi(1, int(round((0.0411 + size * 0.038) / spread_scale * float(sample_rate)))),
		maxi(1, int(round((0.0437 + size * 0.047) * spread_scale * float(sample_rate)))),
		maxi(1, int(round((0.0531 + size * 0.061) / spread_scale * float(sample_rate))))
	])
	# Precompute tap decay outside the sample loop. Reverb is one of the hottest offline DSP paths.
	var decay_per_second: float = pow(0.001, 1.0 / maxf(0.15, decay_s))
	var tap_decays: PackedFloat32Array = PackedFloat32Array()
	tap_decays.resize(delays.size())
	for tap: int in range(delays.size()):
		tap_decays[tap] = pow(decay_per_second, float(delays[tap]) / float(sample_rate))
	var damping_alpha: float = clampf(1.0 - damping * 0.86, 0.08, 0.98)
	var feedback_gain: float = 0.88 + size * 0.08
	var early_a: int = maxi(1, int(round((0.011 + size * 0.009) * spread_scale * float(sample_rate))))
	var early_b: int = maxi(1, int(round((0.017 + size * 0.013) / spread_scale * float(sample_rate))))
	var inverse_tap_counts: PackedFloat32Array = PackedFloat32Array([0.0, 1.0, 0.5, 0.33333333, 0.25, 0.2, 0.16666667])
	var low_state: float = 0.0
	for i: int in range(samples.size()):
		var source_index: int = i - predelay
		var input_sample: float = dry[source_index] if source_index >= 0 and source_index < dry_count else 0.0
		var early: float = 0.0
		var early_index_a: int = source_index - early_a
		var early_index_b: int = source_index - early_b
		if early_index_a >= 0 and early_index_a < dry_count:
			early += dry[early_index_a] * 0.34
		if early_index_b >= 0 and early_index_b < dry_count:
			early += dry[early_index_b] * 0.24
		var feedback_sum: float = 0.0
		var valid_taps: int = 0
		for tap: int in range(delays.size()):
			var read_index: int = i - delays[tap]
			if read_index >= 0:
				feedback_sum += wet[read_index] * tap_decays[tap]
				valid_taps += 1
		if valid_taps > 0:
			feedback_sum *= inverse_tap_counts[mini(valid_taps, 6)]
		var diffuse: float = input_sample + early + feedback_sum * feedback_gain
		low_state += (diffuse - low_state) * damping_alpha
		wet[i] = clampf(low_state, -1.5, 1.5)
		var dry_value: float = dry[i] if i < dry_count else 0.0
		samples[i] = clampf(lerpf(dry_value, wet[i], mix), -1.2, 1.2)


static func _mod_delay(pcm: GASPCMData, params: Dictionary, mode: int) -> void:
	var rate: float = float(params.get("rate_hz", 0.8))
	var depth_ms: float = float(params.get("depth_ms", 7.0 if mode == 0 else 2.5))
	var mix: float = clampf(float(params.get("mix", 0.28 if mode == 0 else 0.4)), 0.0, 1.0)
	var feedback: float = clampf(float(params.get("feedback", 0.0)), -0.9, 0.9)
	_mod_delay_channel(pcm.left, pcm.sample_rate, rate, depth_ms, mix, feedback, mode)
	if pcm.is_stereo():
		_mod_delay_channel(pcm.right, pcm.sample_rate, rate, depth_ms, mix, feedback, mode)


static func _mod_delay_channel(samples: PackedFloat32Array, sample_rate: int, rate: float, depth_ms: float, mix: float, feedback: float, mode: int) -> void:
	var dry: PackedFloat32Array = samples.duplicate()
	var base_ms: float = 16.0 if mode == 0 else 2.5
	var phase: float = 0.0
	var phase_step: float = TAU * rate / float(sample_rate)
	var previous_wet: float = 0.0
	for i: int in range(samples.size()):
		var delay_ms: float = base_ms + sin(phase) * depth_ms
		phase += phase_step
		if phase >= TAU:
			phase -= TAU
		var offset: int = maxi(1, int(round(delay_ms * 0.001 * sample_rate)))
		var source_index: int = i - offset
		if source_index >= 0:
			var wet: float = dry[source_index] + previous_wet * feedback
			previous_wet = wet
			samples[i] = lerpf(dry[i], clampf(dry[i] + wet * 0.7, -1.2, 1.2), mix)


static func _phaser(pcm: GASPCMData, params: Dictionary) -> void:
	_phaser_channel(pcm.left, pcm.sample_rate, float(params.get("rate_hz", 0.45)), float(params.get("depth", 0.65)), float(params.get("mix", 0.35)))
	if pcm.is_stereo():
		_phaser_channel(pcm.right, pcm.sample_rate, float(params.get("rate_hz", 0.45)), float(params.get("depth", 0.65)), float(params.get("mix", 0.35)))


static func _phaser_channel(samples: PackedFloat32Array, sample_rate: int, rate: float, depth: float, mix: float) -> void:
	var dry: PackedFloat32Array = samples.duplicate()
	var x1: float = 0.0
	var y1: float = 0.0
	var phase: float = 0.0
	var phase_step: float = TAU * rate / float(sample_rate)
	for i: int in range(samples.size()):
		var coefficient: float = clampf(0.05 + (0.5 + 0.5 * sin(phase)) * depth * 0.9, 0.01, 0.95)
		phase += phase_step
		if phase >= TAU:
			phase -= TAU
		var input_sample: float = dry[i]
		var filtered: float = -coefficient * input_sample + x1 + coefficient * y1
		x1 = input_sample; y1 = filtered
		samples[i] = lerpf(input_sample, clampf(input_sample + filtered * 0.7, -1.2, 1.2), mix)


static func _tremolo(pcm: GASPCMData, params: Dictionary) -> void:
	var rate: float = float(params.get("rate_hz", 5.0))
	var depth: float = clampf(float(params.get("depth", 0.5)), 0.0, 1.0)
	_tremolo_channel(pcm.left, pcm.sample_rate, rate, depth)
	if pcm.is_stereo():
		_tremolo_channel(pcm.right, pcm.sample_rate, rate, depth)


static func _tremolo_channel(samples: PackedFloat32Array, sample_rate: int, rate: float, depth: float) -> void:
	var phase: float = 0.0
	var step: float = TAU * rate / float(sample_rate)
	for i: int in range(samples.size()):
		var gain: float = 1.0 - depth * (0.5 + 0.5 * sin(phase))
		phase += step
		if phase >= TAU:
			phase -= TAU
		samples[i] *= gain


static func _vibrato(pcm: GASPCMData, params: Dictionary) -> void:
	var rate: float = float(params.get("rate_hz", 5.0))
	var depth_ms: float = float(params.get("depth_ms", 4.0))
	_vibrato_channel(pcm.left, pcm.sample_rate, rate, depth_ms)
	if pcm.is_stereo():
		_vibrato_channel(pcm.right, pcm.sample_rate, rate, depth_ms)


static func _vibrato_channel(samples: PackedFloat32Array, sample_rate: int, rate: float, depth_ms: float) -> void:
	var dry: PackedFloat32Array = samples.duplicate()
	var phase: float = 0.0
	var step: float = TAU * rate / float(sample_rate)
	var depth_frames: float = depth_ms * 0.001 * float(sample_rate)
	var base_delay: float = depth_frames + 2.0
	for i: int in range(samples.size()):
		var delay: float = base_delay + sin(phase) * depth_frames
		phase += step
		if phase >= TAU:
			phase -= TAU
		var read_pos: float = float(i) - delay
		if read_pos >= 0.0:
			samples[i] = _sample_linear(dry, read_pos)


static func _change_speed(pcm: GASPCMData, speed: float) -> GASPCMData:
	var ratio: float = clampf(speed, 0.25, 4.0)
	var new_count: int = maxi(1, int(round(float(pcm.frame_count()) / ratio)))
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	out.left = _resample_linear(pcm.left, new_count)
	if pcm.is_stereo():
		out.right = _resample_linear(pcm.right, new_count)
	return out


static func _granular_pitch(pcm: GASPCMData, semitones: float, grain_ms: float) -> GASPCMData:
	var ratio: float = pow(2.0, semitones / 12.0)
	if absf(ratio - 1.0) < 0.0001:
		return pcm.duplicate_pcm()
	var out: GASPCMData = pcm.duplicate_pcm()
	out.left = _ola_pitch_channel(pcm.left, pcm.sample_rate, ratio, grain_ms)
	if pcm.is_stereo():
		out.right = _ola_pitch_channel(pcm.right, pcm.sample_rate, ratio, grain_ms)
	return out


static func _granular_tempo(pcm: GASPCMData, tempo: float, grain_ms: float) -> GASPCMData:
	var ratio: float = clampf(tempo, 0.25, 4.0)
	if absf(ratio - 1.0) < 0.0001:
		return pcm.duplicate_pcm()
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	out.left = _ola_tempo_channel(pcm.left, pcm.sample_rate, ratio, grain_ms)
	if pcm.is_stereo():
		out.right = _ola_tempo_channel(pcm.right, pcm.sample_rate, ratio, grain_ms)
	return out


static func _ola_pitch_channel(input: PackedFloat32Array, sample_rate: int, pitch_ratio: float, grain_ms: float) -> PackedFloat32Array:
	var grain: int = clampi(int(round(grain_ms * 0.001 * sample_rate)), 128, maxi(128, input.size()))
	var hop_out: int = maxi(1, grain / 4)
	var hop_in: float = float(hop_out) * pitch_ratio
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(input.size())
	var weight: PackedFloat32Array = PackedFloat32Array()
	weight.resize(input.size())
	var in_pos: float = 0.0
	var out_pos: int = 0
	while out_pos < output.size() and in_pos < float(input.size() - 1):
		for j: int in range(grain):
			var dst: int = out_pos + j
			if dst >= output.size():
				break
			var src: float = in_pos + float(j) * pitch_ratio
			if src >= float(input.size() - 1):
				break
			var window: float = 0.5 - 0.5 * cos(TAU * float(j) / float(maxi(1, grain - 1)))
			output[dst] += _sample_linear(input, src) * window
			weight[dst] += window
		out_pos += hop_out
		in_pos += hop_in
	for i: int in range(output.size()):
		if weight[i] > 0.00001:
			output[i] /= weight[i]
	return output


static func _ola_tempo_channel(input: PackedFloat32Array, sample_rate: int, tempo: float, grain_ms: float) -> PackedFloat32Array:
	var grain: int = clampi(int(round(grain_ms * 0.001 * sample_rate)), 128, maxi(128, input.size()))
	var hop_in: int = maxi(1, grain / 4)
	var hop_out: int = maxi(1, int(round(float(hop_in) / tempo)))
	var output_count: int = maxi(1, int(round(float(input.size()) / tempo)))
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(output_count)
	var weight: PackedFloat32Array = PackedFloat32Array()
	weight.resize(output_count)
	var in_pos: int = 0
	var out_pos: int = 0
	while in_pos < input.size() and out_pos < output_count:
		for j: int in range(grain):
			var src: int = in_pos + j
			var dst: int = out_pos + j
			if src >= input.size() or dst >= output_count:
				break
			var window: float = 0.5 - 0.5 * cos(TAU * float(j) / float(maxi(1, grain - 1)))
			output[dst] += input[src] * window
			weight[dst] += window
		in_pos += hop_in
		out_pos += hop_out
	for i: int in range(output.size()):
		if weight[i] > 0.00001:
			output[i] /= weight[i]
	return output


static func _wah(pcm: GASPCMData, params: Dictionary) -> void:
	var rate_hz: float = float(params.get("rate_hz", 1.5))
	var min_hz: float = float(params.get("min_hz", 400.0))
	var max_hz: float = float(params.get("max_hz", 2800.0))
	var resonance: float = clampf(float(params.get("resonance", 0.7)), 0.0, 0.98)
	_wah_channel(pcm.left, pcm.sample_rate, rate_hz, min_hz, max_hz, resonance)
	if pcm.is_stereo():
		_wah_channel(pcm.right, pcm.sample_rate, rate_hz, min_hz, max_hz, resonance)


static func _wah_channel(samples: PackedFloat32Array, sample_rate: int, rate_hz: float, min_hz: float, max_hz: float, resonance: float) -> void:
	var low: float = 0.0
	var band: float = 0.0
	var phase: float = 0.0
	var phase_step: float = TAU * rate_hz / float(sample_rate)
	for i: int in range(samples.size()):
		var lfo: float = 0.5 + 0.5 * sin(phase)
		phase += phase_step
		if phase >= TAU:
			phase -= TAU
		var cutoff: float = lerpf(min_hz, max_hz, lfo)
		var f: float = 2.0 * sin(PI * clampf(cutoff, 20.0, float(sample_rate) * 0.24) / float(sample_rate))
		var high: float = samples[i] - low - (1.0 - resonance) * band
		band += f * high
		low += f * band
		samples[i] = clampf(band * 1.5, -1.2, 1.2)


static func _ring_mod(pcm: GASPCMData, params: Dictionary) -> void:
	var frequency_hz: float = float(params.get("frequency_hz", 80.0))
	var mix: float = clampf(float(params.get("mix", 0.7)), 0.0, 1.0)
	_ring_mod_channel(pcm.left, pcm.sample_rate, frequency_hz, mix)
	if pcm.is_stereo():
		_ring_mod_channel(pcm.right, pcm.sample_rate, frequency_hz, mix)


static func _ring_mod_channel(samples: PackedFloat32Array, sample_rate: int, frequency_hz: float, mix: float) -> void:
	var phase: float = 0.0
	var step: float = TAU * frequency_hz / float(sample_rate)
	for i: int in range(samples.size()):
		var dry: float = samples[i]
		var wet: float = dry * sin(phase)
		phase += step
		if phase >= TAU:
			phase -= TAU
		samples[i] = lerpf(dry, wet, mix)


static func _sliding_stretch(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	var segments: int = clampi(int(params.get("segments", 16)), 4, 64)
	var start_pitch: float = float(params.get("start_pitch_semitones", 0.0))
	var end_pitch: float = float(params.get("end_pitch_semitones", 0.0))
	var start_tempo: float = clampf(float(params.get("start_tempo", 1.0)), 0.25, 4.0)
	var end_tempo: float = clampf(float(params.get("end_tempo", 1.0)), 0.25, 4.0)
	var output: GASPCMData = PCMData.new() as GASPCMData
	output.sample_rate = pcm.sample_rate
	output.channels = pcm.channels
	for segment_index: int in range(segments):
		var a: int = int(round(float(pcm.frame_count()) * float(segment_index) / float(segments)))
		var b: int = int(round(float(pcm.frame_count()) * float(segment_index + 1) / float(segments)))
		if b <= a:
			continue
		var u: float = (float(segment_index) + 0.5) / float(segments)
		var chunk: GASPCMData = pcm.slice_frames(a, b)
		var tempo: float = lerpf(start_tempo, end_tempo, u)
		chunk = _granular_tempo(chunk, tempo, 36.0)
		var semitones: float = lerpf(start_pitch, end_pitch, u)
		if absf(semitones) > 0.001:
			chunk = _granular_pitch(chunk, semitones, 36.0)
		output.left.append_array(chunk.left)
		if pcm.is_stereo():
			output.right.append_array(chunk.right)
	return output


static func _repeat_pcm(pcm: GASPCMData, count: int) -> GASPCMData:
	var repeats: int = clampi(count, 2, 16)
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	var source_count: int = pcm.frame_count()
	out.left.resize(source_count * repeats)
	if pcm.is_stereo():
		out.right.resize(source_count * repeats)
	for repeat_index: int in range(repeats):
		var offset: int = repeat_index * source_count
		for i: int in range(source_count):
			out.left[offset + i] = pcm.left[i]
			if pcm.is_stereo():
				out.right[offset + i] = pcm.right[i]
	return out


static func _truncate_silence(pcm: GASPCMData, params: Dictionary) -> GASPCMData:
	var threshold: float = db_to_linear(float(params.get("threshold_db", -50.0)))
	var minimum_frames: int = maxi(1, int(round(float(params.get("minimum_ms", 200.0)) * 0.001 * float(pcm.sample_rate))))
	var target_frames: int = maxi(0, int(round(float(params.get("target_ms", 50.0)) * 0.001 * float(pcm.sample_rate))))
	var segments: Array[Vector2i] = []
	var output_count: int = 0
	var i: int = 0
	while i < pcm.frame_count():
		var run_start: int = i
		var run_silent: bool = absf(pcm.left[i]) < threshold
		if pcm.is_stereo():
			run_silent = run_silent and absf(pcm.right[i]) < threshold
		i += 1
		while i < pcm.frame_count():
			var current_silent: bool = absf(pcm.left[i]) < threshold
			if pcm.is_stereo():
				current_silent = current_silent and absf(pcm.right[i]) < threshold
			if current_silent != run_silent:
				break
			i += 1
		var run_length: int = i - run_start
		var keep_length: int = run_length
		if run_silent and run_length >= minimum_frames:
			keep_length = mini(run_length, target_frames)
		if keep_length > 0:
			segments.append(Vector2i(run_start, keep_length))
			output_count += keep_length
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = pcm.sample_rate
	out.channels = pcm.channels
	out.left.resize(output_count)
	if pcm.is_stereo():
		out.right.resize(output_count)
	var dst: int = 0
	for segment: Vector2i in segments:
		var source_start: int = segment.x
		var count: int = segment.y
		for offset: int in range(count):
			var src: int = source_start + offset
			out.left[dst] = pcm.left[src]
			if pcm.is_stereo():
				out.right[dst] = pcm.right[src]
			dst += 1
	return out


static func _clip_repair(pcm: GASPCMData, threshold: float) -> void:
	_clip_repair_channel(pcm.left, threshold)
	if pcm.is_stereo():
		_clip_repair_channel(pcm.right, threshold)


static func _clip_repair_channel(samples: PackedFloat32Array, threshold: float) -> void:
	var clip_threshold: float = clampf(threshold, 0.8, 1.0)
	var i: int = 0
	while i < samples.size():
		if absf(samples[i]) < clip_threshold:
			i += 1
			continue
		var start: int = i
		while i < samples.size() and absf(samples[i]) >= clip_threshold:
			i += 1
		var finish: int = i
		var left_index: int = maxi(0, start - 1)
		var right_index: int = mini(samples.size() - 1, finish)
		var left_value: float = samples[left_index]
		var right_value: float = samples[right_index]
		var span: int = maxi(1, right_index - left_index)
		for j: int in range(start, finish):
			samples[j] = lerpf(left_value, right_value, float(j - left_index) / float(span))


static func _interpolate_full(pcm: GASPCMData) -> void:
	if pcm.frame_count() <= 2:
		return
	_interpolate_channel(pcm.left)
	if pcm.is_stereo():
		_interpolate_channel(pcm.right)


static func _interpolate_channel(samples: PackedFloat32Array) -> void:
	if samples.size() <= 2:
		return
	var first: float = samples[0]
	var last: float = samples[samples.size() - 1]
	var denominator: float = float(samples.size() - 1)
	for i: int in range(samples.size()):
		samples[i] = lerpf(first, last, float(i) / denominator)


static func _deesser(pcm: GASPCMData, params: Dictionary) -> void:
	_deesser_channel(pcm.left, pcm.sample_rate, params)
	if pcm.is_stereo():
		_deesser_channel(pcm.right, pcm.sample_rate, params)


static func _deesser_channel(samples: PackedFloat32Array, sample_rate: int, params: Dictionary) -> void:
	var frequency: float = clampf(float(params.get("frequency_hz", 6500.0)), 1000.0, float(sample_rate) * 0.45)
	var threshold: float = db_to_linear(float(params.get("threshold_db", -24.0)))
	var amount: float = clampf(float(params.get("amount", 0.55)), 0.0, 1.0)
	var alpha: float = 1.0 - exp(-TAU * frequency / float(sample_rate))
	var smooth: float = 0.0
	for i: int in range(samples.size()):
		var x: float = samples[i]
		smooth += (x - smooth) * alpha
		var high: float = x - smooth
		var reduction: float = amount if absf(high) > threshold else 0.0
		samples[i] = clampf(x - high * reduction, -1.2, 1.2)


static func _hum_removal(pcm: GASPCMData, params: Dictionary) -> void:
	var base_frequency: float = float(params.get("frequency_hz", 60.0))
	var harmonics: int = clampi(int(params.get("harmonics", 4)), 1, 8)
	var q: float = float(params.get("q", 12.0))
	for harmonic: int in range(1, harmonics + 1):
		var frequency: float = base_frequency * float(harmonic)
		if frequency >= float(pcm.sample_rate) * 0.45:
			break
		_filter_biquad(pcm, 2, frequency, q)


static func _click_repair(pcm: GASPCMData, threshold: float, radius: int) -> void:
	_click_repair_channel(pcm.left, threshold, radius)
	if pcm.is_stereo():
		_click_repair_channel(pcm.right, threshold, radius)


static func _click_repair_channel(samples: PackedFloat32Array, threshold: float, radius: int) -> void:
	if samples.size() < 3:
		return
	var source: PackedFloat32Array = samples.duplicate()
	var r: int = clampi(radius, 1, 8)
	for i: int in range(1, samples.size() - 1):
		var expected: float = (source[i - 1] + source[i + 1]) * 0.5
		if absf(source[i] - expected) >= threshold:
			var start: int = maxi(0, i - r)
			var finish: int = mini(samples.size() - 1, i + r)
			var left_value: float = source[start]
			var right_value: float = source[finish]
			var span: int = maxi(1, finish - start)
			for j: int in range(start, finish + 1):
				samples[j] = lerpf(left_value, right_value, float(j - start) / float(span))


static func _mix_wet_dry(processed: GASPCMData, dry: GASPCMData, wet: float) -> void:
	var amount: float = clampf(wet, 0.0, 1.0)
	var dry_count: int = dry.frame_count()
	for i: int in range(processed.frame_count()):
		if i < dry_count:
			processed.left[i] = lerpf(dry.left[i], processed.left[i], amount)
			if processed.is_stereo():
				var dry_right: float = dry.right[i] if dry.is_stereo() else dry.left[i]
				processed.right[i] = lerpf(dry_right, processed.right[i], amount)
		else:
			processed.left[i] *= amount
			if processed.is_stereo():
				processed.right[i] *= amount


static func _scale_channel(samples: PackedFloat32Array, gain: float) -> void:
	for i: int in range(samples.size()):
		samples[i] = clampf(samples[i] * gain, -1.5, 1.5)


static func _scale_channel_limit(samples: PackedFloat32Array, gain: float, allow_clipping: bool) -> void:
	var limit: float = 1.5 if allow_clipping else 1.0
	for i: int in range(samples.size()):
		samples[i] = clampf(samples[i] * gain, -limit, limit)


static func _time_coefficient(milliseconds: float, sample_rate: int) -> float:
	var seconds: float = maxf(0.000001, milliseconds * 0.001)
	return exp(-1.0 / (seconds * float(sample_rate)))


static func _resample_linear(input: PackedFloat32Array, new_count: int) -> PackedFloat32Array:
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(new_count)
	if input.is_empty():
		return output
	if new_count == 1:
		output[0] = input[0]
		return output
	var scale: float = float(input.size() - 1) / float(new_count - 1)
	for i: int in range(new_count):
		output[i] = _sample_linear(input, float(i) * scale)
	return output


static func _sample_linear(samples: PackedFloat32Array, position: float) -> float:
	var i0: int = clampi(int(floor(position)), 0, samples.size() - 1)
	var i1: int = mini(samples.size() - 1, i0 + 1)
	var frac: float = position - float(i0)
	return lerpf(samples[i0], samples[i1], frac)
