@tool
class_name GASEditorClip
extends RefCounted

const SYNC_CACHE_THRESHOLD_FRAMES: int = 32768

var clip_id: int = 0
var name: String = "Clip"
var source_path: String = ""
var timeline_start: int = 0
var pcm: GASPCMData
var cache: GASWaveformCache
var paged_store: GASPagedPCMStore
var paged_cache_path: String = ""
var source_start_frame: int = 0
var source_end_frame: int = -1
var offline_frame_count: int = 0
var source_missing: bool = false
var gain_db: float = 0.0
var pan: float = 0.0
var muted: bool = false
var fade_in_samples: int = 0
var fade_out_samples: int = 0
var fade_curve: int = 0
var effect_stack: Array[GASEffectData] = []
var spectrogram_texture: ImageTexture
var spectrogram_source_start: int = -1
var spectrogram_source_end: int = -1


func frame_count() -> int:
	if pcm == null:
		return maxi(0, offline_frame_count)
	var end_source: int = source_end_frame
	if end_source < 0:
		end_source = pcm.frame_count()
	return maxi(0, clampi(end_source, 0, pcm.frame_count()) - clampi(source_start_frame, 0, pcm.frame_count()))


func end_frame() -> int:
	return timeline_start + frame_count()


func source_end() -> int:
	if pcm == null:
		return source_end_frame if source_end_frame >= 0 else source_start_frame + maxi(0, offline_frame_count)
	return pcm.frame_count() if source_end_frame < 0 else clampi(source_end_frame, 0, pcm.frame_count())


func source_index(local_frame: int) -> int:
	return source_start_frame + local_frame


func duplicate_shallow() -> GASEditorClip:
	var out: GASEditorClip = GASEditorClip.new()
	out.clip_id = clip_id
	out.name = name
	out.source_path = source_path
	out.timeline_start = timeline_start
	out.pcm = pcm
	out.cache = cache
	out.paged_store = paged_store
	out.paged_cache_path = paged_cache_path
	out.source_start_frame = source_start_frame
	out.source_end_frame = source_end_frame
	out.offline_frame_count = offline_frame_count
	out.source_missing = source_missing
	out.gain_db = gain_db
	out.pan = pan
	out.muted = muted
	out.fade_in_samples = fade_in_samples
	out.fade_out_samples = fade_out_samples
	out.fade_curve = fade_curve
	out.spectrogram_texture = spectrogram_texture
	out.spectrogram_source_start = spectrogram_source_start
	out.spectrogram_source_end = spectrogram_source_end
	for effect: GASEffectData in effect_stack:
		out.effect_stack.append(effect.duplicate_effect())
	return out


func duplicate_with_new_id(new_id: int) -> GASEditorClip:
	var out: GASEditorClip = duplicate_shallow()
	out.clip_id = new_id
	return out


func rebuild_cache() -> void:
	spectrogram_texture = null
	spectrogram_source_start = -1
	spectrogram_source_end = -1
	paged_store = null
	paged_cache_path = ""
	if pcm == null:
		cache = null
		return
	offline_frame_count = frame_count()
	# Short SFX are cheap enough to cache immediately. Song-length clips are left
	# uncached here and the waveform view builds their cache on WorkerThreadPool.
	# This keeps every edit/import/load path from accidentally doing millions of
	# sample iterations on the editor thread.
	if pcm.frame_count() > SYNC_CACHE_THRESHOLD_FRAMES:
		cache = null
		return
	cache = GASWaveformCache.new()
	cache.build(pcm)


func invalidate_visual_cache() -> void:
	cache = null
	paged_store = null
	paged_cache_path = ""
	spectrogram_texture = null
	spectrogram_source_start = -1
	spectrogram_source_end = -1


func read_source_frames(start_frame: int, end_frame: int) -> GASPCMData:
	if paged_store != null:
		return paged_store.read_frames(start_frame, end_frame)
	if pcm == null:
		return null
	return pcm.slice_frames(start_frame, end_frame)


func _can_use_paged_cache() -> bool:
	return not source_path.begins_with("generated://") and not source_path.begins_with("effect://") and not source_path.begins_with("clipboard://")


func get_spectrogram_texture() -> ImageTexture:
	if pcm == null or frame_count() <= 0:
		return null
	var current_end: int = source_end()
	if spectrogram_texture != null and spectrogram_source_start == source_start_frame and spectrogram_source_end == current_end:
		return spectrogram_texture
	# Spectrogram generation is intentionally never performed here. This method is
	# called from Control._draw(), so any FFT work here would freeze the editor.
	return null


func _spectral_color(t: float) -> Color:
	var value: float = clampf(t, 0.0, 1.0)
	if value < 0.33:
		var segment_a: float = value / 0.33
		return Color(0.03, 0.04 + segment_a * 0.12, 0.10 + segment_a * 0.38, 0.96)
	if value < 0.66:
		var segment_b: float = (value - 0.33) / 0.33
		return Color(0.03 + segment_b * 0.45, 0.16 + segment_b * 0.48, 0.48 + segment_b * 0.10, 0.96)
	var segment_c: float = (value - 0.66) / 0.34
	return Color(0.48 + segment_c * 0.48, 0.64 + segment_c * 0.28, 0.58 - segment_c * 0.42, 0.96)
