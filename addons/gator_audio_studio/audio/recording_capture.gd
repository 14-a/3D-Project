@tool
class_name GASRecordingCapture
extends RefCounted

var sample_rate: int = 44100
var stereo: bool = false
var total_frames: int = 0
var chunks: Array[PackedVector2Array] = []


func flatten() -> GASPCMData:
	if total_frames <= 0:
		return null
	var out: GASPCMData = GASPCMData.new()
	out.sample_rate = sample_rate
	out.channels = 2 if stereo else 1
	out.left.resize(total_frames)
	if stereo:
		out.right.resize(total_frames)
	var dst: int = 0
	for chunk: PackedVector2Array in chunks:
		for frame: Vector2 in chunk:
			if dst >= total_frames:
				break
			if stereo:
				out.left[dst] = frame.x
				out.right[dst] = frame.y
			else:
				out.left[dst] = (frame.x + frame.y) * 0.5
			dst += 1
	return out
