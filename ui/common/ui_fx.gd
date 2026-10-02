class_name UIFx
## Small tween helpers for UI juice. All of them animate the visual-only
## offset transform, so they never disturb container layout, and they kill
## any previous effect of the same kind on the same control.

const _META_PREFIX := "_uifx_"


static func prepare(c: Control) -> void:
	c.offset_transform_enabled = true
	c.offset_transform_visual_only = true
	c.offset_transform_pivot_ratio = Vector2(0.5, 0.5)


static func _take(c: Control, kind: String) -> Tween:
	var key := _META_PREFIX + kind
	if c.has_meta(key):
		var old: Tween = c.get_meta(key)
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	c.set_meta(key, tw)
	return tw


## Quick scale punch: grows by `amount` then settles with a bounce.
static func pop(c: Control, amount: float = 0.25, time: float = 0.35) -> Tween:
	prepare(c)
	var tw := _take(c, "scale")
	c.offset_transform_scale = Vector2.ONE
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE * (1.0 + amount), time * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE, time * 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Squash down then overshoot: a mechanical "clunk".
static func clunk(c: Control, time: float = 0.42) -> Tween:
	prepare(c)
	var tw := _take(c, "scale")
	tw.tween_property(c, "offset_transform_scale", Vector2(1.12, 0.78), time * 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_scale", Vector2(0.9, 1.15), time * 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_transform_scale", Vector2.ONE, time * 0.6) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


## Decaying horizontal shake.
static func shake(c: Control, strength: float = 10.0, time: float = 0.4, freq: float = 38.0) -> Tween:
	prepare(c)
	var tw := _take(c, "pos")
	tw.tween_method(func(t: float) -> void:
		c.offset_transform_position = Vector2(sin(t * freq) * strength * (1.0 - t / time) , 0.0),
		0.0, time, time)
	tw.tween_callback(func() -> void: c.offset_transform_position = Vector2.ZERO)
	return tw


## Gentle wiggle in rotation (parrot bob, attention cues).
static func wiggle(c: Control, degrees: float = 8.0, time: float = 0.6) -> Tween:
	prepare(c)
	var tw := _take(c, "rot")
	tw.tween_method(func(t: float) -> void:
		c.offset_transform_rotation = deg_to_rad(sin(t * 18.0) * degrees * (1.0 - t / time)),
		0.0, time, time)
	tw.tween_callback(func() -> void: c.offset_transform_rotation = 0.0)
	return tw


## Fades a CanvasItem's modulate alpha; hides it at 0 when `hide_at_zero`.
static func fade(c: CanvasItem, to: float, time: float = 0.25, hide_at_zero: bool = true) -> Tween:
	var key := _META_PREFIX + "fade"
	if c.has_meta(key):
		var old: Tween = c.get_meta(key)
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	c.set_meta(key, tw)
	if to > 0.0:
		c.visible = true
	tw.tween_property(c, "modulate:a", to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if to <= 0.0 and hide_at_zero:
		tw.tween_callback(func() -> void: c.visible = false)
	return tw


## Slides in from `from_offset` (visual offset) while fading in.
static func slide_in(c: Control, from_offset: Vector2, time: float = 0.3) -> Tween:
	prepare(c)
	var tw := _take(c, "pos")
	c.offset_transform_position = from_offset
	c.modulate.a = 0.0
	c.visible = true
	tw.set_parallel(true)
	tw.tween_property(c, "offset_transform_position", Vector2.ZERO, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, time * 0.7)
	return tw


## Slides out toward `to_offset` while fading, then hides.
static func slide_out(c: Control, to_offset: Vector2, time: float = 0.22) -> Tween:
	prepare(c)
	var tw := _take(c, "pos")
	tw.set_parallel(true)
	tw.tween_property(c, "offset_transform_position", to_offset, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, time)
	tw.chain().tween_callback(func() -> void:
		c.visible = false
		c.offset_transform_position = Vector2.ZERO)
	return tw


## Plays a UI sound if the AudioManager autoload knows it (never warns).
static func sound(id: StringName, volume_db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var am := tree.root.get_node_or_null(^"AudioManager")
	if am == null or not am.has_method(&"play_ui"):
		return
	if am.has_method(&"has_sound") and not am.call(&"has_sound", id):
		return
	am.call(&"play_ui", id, volume_db)
