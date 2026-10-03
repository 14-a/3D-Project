@tool
class_name GASPlaybackPrefetcher
extends RefCounted

# Dedicated PCM producer for streamed editor playback. Mixing is intentionally
# kept off the editor thread; the main thread only drains ready chunks into
# AudioStreamGeneratorPlayback.

const CHUNK_FRAMES: int = 2048
const PREFETCH_SECONDS: float = 10.0
const IDLE_DELAY_MS: int = 2

var _thread: Thread
var _mutex: Mutex = Mutex.new()
var _streamer: GASPlaybackStreamer
var _queue: Array[PackedVector2Array] = []
var _queued_frames: int = 0
var _queue_read_index: int = 0
var _target_frames: int = 0
var _stop_requested: bool = false
var _finished: bool = false
var _thread_started: bool = false


func start(streamer: GASPlaybackStreamer, sample_rate: int) -> bool:
	stop()
	if streamer == null or streamer.remaining_frames() <= 0:
		return false
	_streamer = streamer
	_target_frames = maxi(CHUNK_FRAMES * 8, int(round(float(maxi(8000, sample_rate)) * PREFETCH_SECONDS)))
	_stop_requested = false
	_finished = false
	_queue.clear()
	_queue_read_index = 0
	_queued_frames = 0
	_thread = Thread.new()
	var error: Error = _thread.start(Callable(self, "_thread_main"))
	_thread_started = error == OK
	if not _thread_started:
		_thread = null
		_streamer = null
	return _thread_started


func request_stop() -> void:
	if not _thread_started:
		return
	_mutex.lock()
	_stop_requested = true
	_mutex.unlock()


func stop() -> void:
	if _thread_started and _thread != null:
		request_stop()
		_thread.wait_to_finish()
	_thread_started = false
	_thread = null
	_mutex.lock()
	_queue.clear()
	_queue_read_index = 0
	_queued_frames = 0
	_finished = true
	_mutex.unlock()
	_streamer = null


func pop_chunk_if_fits(max_frames: int) -> PackedVector2Array:
	var empty: PackedVector2Array = PackedVector2Array()
	if max_frames <= 0:
		return empty
	_mutex.lock()
	if _queue_read_index >= _queue.size():
		_mutex.unlock()
		return empty
	var first: PackedVector2Array = _queue[_queue_read_index]
	if first.size() > max_frames:
		_mutex.unlock()
		return empty
	_queue_read_index += 1
	_queued_frames = maxi(0, _queued_frames - first.size())
	if _queue_read_index >= 64 and _queue_read_index * 2 >= _queue.size():
		var compacted: Array[PackedVector2Array] = []
		for index: int in range(_queue_read_index, _queue.size()):
			compacted.append(_queue[index])
		_queue = compacted
		_queue_read_index = 0
	_mutex.unlock()
	return first


func queued_frames() -> int:
	_mutex.lock()
	var result: int = _queued_frames
	_mutex.unlock()
	return result


func is_finished() -> bool:
	_mutex.lock()
	var result: bool = _finished
	_mutex.unlock()
	return result


func is_drained() -> bool:
	_mutex.lock()
	var result: bool = _finished and _queue_read_index >= _queue.size()
	_mutex.unlock()
	return result


func _thread_main() -> void:
	while true:
		_mutex.lock()
		var should_stop: bool = _stop_requested
		var buffered: int = _queued_frames
		_mutex.unlock()
		if should_stop:
			break
		if buffered >= _target_frames:
			OS.delay_msec(IDLE_DELAY_MS)
			continue
		if _streamer == null or _streamer.remaining_frames() <= 0:
			_mutex.lock()
			_finished = true
			_mutex.unlock()
			break
		var frames: PackedVector2Array = _streamer.render_frames(CHUNK_FRAMES)
		if frames.is_empty():
			_mutex.lock()
			_finished = true
			_mutex.unlock()
			break
		_mutex.lock()
		if _stop_requested:
			_mutex.unlock()
			break
		_queue.append(frames)
		_queued_frames += frames.size()
		_mutex.unlock()
	_mutex.lock()
	_finished = true
	_mutex.unlock()
