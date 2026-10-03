@tool
class_name GASEditorTrack
extends RefCounted

const DISPLAY_WAVEFORM: int = 0
const DISPLAY_SPECTROGRAM: int = 1
const DISPLAY_COMBINED: int = 2

const WAVEFORM_SPLIT_STEREO: int = 0
const WAVEFORM_COMBINED_STEREO: int = 1

const AMPLITUDE_LINEAR: int = 0
const AMPLITUDE_DB: int = 1

const TYPE_AUDIO: int = 0
const TYPE_LABEL: int = 1
const TYPE_AUTOMATION: int = 2
const TYPE_GENERATED: int = 3
const TYPE_REFERENCE: int = 4

const CHANNEL_AUTO: int = 0
const CHANNEL_MONO: int = 1
const CHANNEL_STEREO: int = 2

var name: String = "Audio Track"
var track_type: int = TYPE_AUDIO
var color: Color = Color(0.20, 0.48, 0.78, 1.0)
var channel_mode: int = CHANNEL_AUTO
var collapsed: bool = false
var sync_group: int = 0
var automation_lanes: Dictionary = {}
var generated_settings: Dictionary = {}
var reference_read_only: bool = false
var clips: Array[GASEditorClip] = []
var gain_db: float = 0.0
var pan: float = 0.0
var mute: bool = false
var solo: bool = false
var locked: bool = false
var record_armed: bool = false
var output_bus: String = "Master"
var send_bus: String = ""
var send_db: float = -12.0
var effect_stack: Array[GASEffectData] = []
var display_mode: int = DISPLAY_WAVEFORM
var sample_rate: int = 44100
var waveform_stereo_mode: int = WAVEFORM_SPLIT_STEREO
var waveform_amplitude_mode: int = AMPLITUDE_LINEAR
var show_zero_line: bool = true
var show_clipping: bool = true


func duplicate_shallow() -> GASEditorTrack:
	var out: GASEditorTrack = GASEditorTrack.new()
	out.name = name
	out.track_type = track_type
	out.color = color
	out.channel_mode = channel_mode
	out.collapsed = collapsed
	out.sync_group = sync_group
	out.automation_lanes = automation_lanes.duplicate(true)
	out.generated_settings = generated_settings.duplicate(true)
	out.reference_read_only = reference_read_only
	out.gain_db = gain_db
	out.pan = pan
	out.mute = mute
	out.solo = solo
	out.locked = locked
	out.record_armed = record_armed
	out.output_bus = output_bus
	out.send_bus = send_bus
	out.send_db = send_db
	out.display_mode = display_mode
	out.sample_rate = sample_rate
	out.waveform_stereo_mode = waveform_stereo_mode
	out.waveform_amplitude_mode = waveform_amplitude_mode
	out.show_zero_line = show_zero_line
	out.show_clipping = show_clipping
	for effect: GASEffectData in effect_stack:
		out.effect_stack.append(effect.duplicate_effect())
	for clip: GASEditorClip in clips:
		out.clips.append(clip.duplicate_shallow())
	return out


func end_frame() -> int:
	var result: int = 0
	for clip: GASEditorClip in clips:
		result = maxi(result, clip.end_frame())
	return result
