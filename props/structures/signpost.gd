@tool
class_name Signpost
extends PropBody
## Wooden signpost with one painted arrow board per entry in `texts`. Boards
## point along `directions` (yaw degrees, 0 = the node's forward -Z, positive
## turns counter-clockwise like rotation_degrees.y), stack down the post and
## grow to fit their text. Each board has a cream painted face with a colored
## tip and an unshaded Label3D on both sides (no billboarding, so it reads as
## painted lettering). Collision: the post only.

@export var texts: PackedStringArray = PackedStringArray(["Beach", "Lookout"]):
	set(v):
		texts = v
		_queue_rebuild()
@export var directions: PackedFloat32Array = PackedFloat32Array([90.0, -60.0]):
	set(v):
		directions = v
		_queue_rebuild()
@export_range(1.0, 4.0, 0.05) var post_height := 2.2:
	set(v):
		post_height = v
		_queue_rebuild()
## Lettering height (m).
@export_range(0.08, 0.4, 0.01) var text_size := 0.16:
	set(v):
		text_size = v
		_queue_rebuild()
@export var ink_color := PropPalette.SIGN_INK:
	set(v):
		ink_color = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const POST := 0.17
const BOARD_H := 0.3
const BOARD_T := 0.07


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 13)
	var mt := parts.matte
	# Post with a little pyramid cap, slightly sunk into the ground.
	mt.chamfer_box(Vector3(POST, post_height + 0.2, POST), 0.035, Transform3D(Basis.IDENTITY, Vector3.UP * (post_height - 0.2) * 0.5), PropPalette.WOOD_FRAME)
	var cap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(POST * 0.8, 0.0), Vector2(POST * 0.8, 0.05), Vector2(0.0, 0.17)])
	mt.lathe(cap, 4, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.UP * post_height), PropPalette.WOOD_DEEP.lightened(0.15), PackedColorArray(), true)
	var labels: Array[Array] = []
	for i in texts.size():
		var text := texts[i]
		var yaw := deg_to_rad(directions[i] if i < directions.size() else 0.0)
		var y := post_height - 0.32 - i * (BOARD_H + 0.1)
		var length := clampf(0.45 + text.length() * text_size * 0.68, 0.8, 3.0)
		var tip := BOARD_H * 0.55
		# Board in its own frame: arrow points along +X, faces +Z / -Z.
		var orient := Basis(Vector3.UP, yaw + PI * 0.5) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-2.5, 2.5)))
		var origin := Vector3.UP * y + orient * Vector3(-0.12, 0.0, 0.0) + (orient * Vector3(0, 0, 1)) * (POST * 0.5 + BOARD_T * 0.5) * (1.0 if i % 2 == 0 else -1.0)
		var xf := Transform3D(orient, origin)
		var outline := _arrow(length, BOARD_H, tip)
		mt.extrude(outline, BOARD_T, xf, PropKit.jitter(PropPalette.PLANK, rng, 0.04), 0.012)
		var face := _arrow(length - 0.07, BOARD_H - 0.07, tip - 0.03)
		var paint: Color = PropPalette.SIGN_PAINTS[(i + seed) % PropPalette.SIGN_PAINTS.size()]
		for sz: float in [1.0, -1.0]:
			var fxf := xf * Transform3D(Basis.IDENTITY, Vector3(0.035, 0.0, sz * (BOARD_T * 0.5 + 0.004)))
			parts.glossy.extrude(face, 0.008, fxf, PropPalette.SIGN_FACE)
			var tri := PackedVector2Array([Vector2(length - tip - 0.07, -(BOARD_H - 0.07) * 0.5), Vector2(length - 0.07, 0.0), Vector2(length - tip - 0.07, (BOARD_H - 0.07) * 0.5)])
			parts.glossy.extrude(tri, 0.012, fxf * Transform3D(Basis.IDENTITY, Vector3(0.035, 0, 0)), paint)
			# Lettering centered on the flat part of the face.
			var center := Vector3((length - tip) * 0.5 + 0.02, 0.0, sz * (BOARD_T * 0.5 + 0.012))
			labels.append([xf * Transform3D(Basis(Vector3.UP, 0.0 if sz > 0.0 else PI), center), text])
	add_mesh(parts.build(), "Sign")
	for l in labels:
		var label := Label3D.new()
		label.text = l[1]
		label.font_size = 64
		label.pixel_size = text_size / 64.0 * 1.15
		label.modulate = ink_color
		label.outline_size = 0
		label.double_sided = false
		label.shaded = false
		label.no_depth_test = false
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.transform = l[0]
		PropKit.add_generated(self, label, "Text")
	add_shape(PropKit.box_shape(Vector3(POST, post_height, POST)), Transform3D(Basis.IDENTITY, Vector3.UP * post_height * 0.5))


## Arrow outline pointing along +X, flat end at x = 0.
static func _arrow(length: float, height: float, tip: float) -> PackedVector2Array:
	var h := height * 0.5
	return PackedVector2Array([Vector2(0.0, -h), Vector2(length - tip, -h), Vector2(length, 0.0), Vector2(length - tip, h), Vector2(0.0, h)])
