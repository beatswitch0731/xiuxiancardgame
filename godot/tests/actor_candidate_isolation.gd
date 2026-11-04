extends SceneTree

# A saved FrameRonin clip is not an approved actor bundle. Old action frames
# must not be copied into its SpriteFrames, regardless of clip count.
func _initialize() -> void:
	var target := ""
	var clip := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--resource="):
			target = arg.trim_prefix("--resource=")
		elif arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
	var frames := load(target) as SpriteFrames
	if frames == null or not frames.has_animation(clip) \
			or frames.get_animation_names().size() != 1 \
			or bool(frames.get_meta("candidate_approved_for_runtime", true)) \
			or frames.get_frame_count(clip) != 32:
		push_error("Reviewed clip leaked old source animations or was marked runtime approved")
		quit(1)
		return
	print("ACTOR_CANDIDATE_ISOLATION_PASS clip=", clip, " frames=32 source_mix=false")
	quit(0)
