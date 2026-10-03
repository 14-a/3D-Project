class_name GatorSpritePlayer
extends AnimatedSprite2D

@export var sprite_document: GatorSpriteDocument

func _ready() -> void:
	if sprite_document != null:
		apply_document(sprite_document)

func apply_document(source_document: GatorSpriteDocument) -> void:
	sprite_document = source_document
	var source_animation: GatorSpriteAnimation = source_document.get_active_animation()
	var generated_frames: SpriteFrames = SpriteFrames.new()
	generated_frames.remove_animation(&"default")
	generated_frames.add_animation(StringName(source_animation.animation_title))
	generated_frames.set_animation_speed(StringName(source_animation.animation_title), source_animation.frames_per_second)
	generated_frames.set_animation_loop(StringName(source_animation.animation_title), source_animation.loop_mode != Animation.LOOP_NONE)
	for frame_index: int in range(source_animation.frame_count):
		var frame_image: Image = source_document.composite_frame(frame_index)
		generated_frames.add_frame(StringName(source_animation.animation_title), ImageTexture.create_from_image(frame_image))
	sprite_frames = generated_frames
	animation = StringName(source_animation.animation_title)
