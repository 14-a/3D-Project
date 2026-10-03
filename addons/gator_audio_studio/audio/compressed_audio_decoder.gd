@tool
class_name GASCompressedAudioDecoder
extends RefCounted

const DecodeSession := preload("res://addons/gator_audio_studio/audio/compressed_decode_session.gd")
const FALLBACK_MIX_RATE: int = 48000


static func load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	var load_path: String = _global_audio_path(path)
	match path.get_extension().to_lower():
		"mp3":
			var mp3: AudioStreamMP3 = AudioStreamMP3.load_from_file(load_path)
			if mp3 != null:
				mp3.loop = false
			return mp3
		"ogg":
			var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(load_path)
			if ogg != null:
				ogg.loop = false
			return ogg
	return null


static func begin_decode(path: String, target_rate: int = 0) -> GASCompressedDecodeSession:
	var stream: AudioStream = load_stream(path)
	if stream == null:
		return null
	return begin_decode_stream(stream, path, target_rate)


static func begin_decode_stream(stream: AudioStream, source_path: String = "", target_rate: int = 0) -> GASCompressedDecodeSession:
	if stream == null:
		return null
	var mix_rate: int = int(round(AudioServer.get_mix_rate()))
	if mix_rate <= 0:
		mix_rate = FALLBACK_MIX_RATE
	var output_rate: int = target_rate if target_rate > 0 else mix_rate
	var session: GASCompressedDecodeSession = DecodeSession.new() as GASCompressedDecodeSession
	if not session.setup(stream, source_path, output_rate, mix_rate):
		return null
	return session


static func decode_file(path: String, target_rate: int = 0) -> GASPCMData:
	var session: GASCompressedDecodeSession = begin_decode(path, target_rate)
	if session == null:
		return null
	# Compatibility path for non-interactive callers such as project recovery.
	# Interactive editor imports use begin_decode() and advance incrementally.
	while not session.finished:
		session.step(250000)
	return session.pcm_result()


static func decode_stream(stream: AudioStream, target_rate: int = 0) -> GASPCMData:
	var session: GASCompressedDecodeSession = begin_decode_stream(stream, "", target_rate)
	if session == null:
		return null
	while not session.finished:
		session.step(250000)
	return session.pcm_result()


static func is_compressed_path(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return extension == "mp3" or extension == "ogg"


static func _global_audio_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path
