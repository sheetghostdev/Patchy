class_name LedgeProbe
extends RefCounted
## Forgiving ledge detection (spec §24). Patchy grabs when a near miss leaves
## a walkable lip within reach of his hands, but refuses geometry that would
## look wrong: slopes, overhangs, lips with no room to stand, or anything in
## the "no_ledge_grab" group.
##
## Steps:
##  1. forward rays at chest/head/hand height find a near-vertical wall;
##  2. a downward ray just behind the wall face finds a walkable top;
##  3. the top must sit in the grabbable height band above the feet and the
##     current rise must not already carry Patchy over it;
##  4. the wall face must reach the lip (no sloped tops or gaps);
##  5. capsule clearance tests at the hang spot and the stand-up spot.

static var _shape: CapsuleShape3D


static func find(p: Player) -> Dictionary:
	var dirs: Array[Vector3] = []
	var hv := Player.flat(p.velocity)
	var stick := Player.flat(p.input.move_dir)
	if hv.length() > 0.8:
		dirs.append(hv.normalized())
	if stick.length() > 0.3:
		dirs.append(stick.normalized())
	dirs.append(p.facing)
	for d in dirs:
		var r := probe(p, d, p.global_position)
		if not r.is_empty():
			return r
	return {}


static func probe(p: Player, dir: Vector3, pos: Vector3, check_rise: bool = true) -> Dictionary:
	var s := p.settings
	var reach := Player.CAPSULE_RADIUS + s.ledge_reach

	var wall := {}
	for h: float in [1.05, 1.4, 1.75]:
		var from := pos + Vector3.UP * h
		var hit := p.raycast(from, from + dir * reach, Layers.GRABBABLE_MASK)
		if not hit.is_empty() and absf(hit.normal.y) < 0.4:
			wall = hit
			break
	if wall.is_empty():
		return {}
	var n := Player.flat(wall.normal).normalized()
	if dir.dot(-n) < 0.45:
		return {}

	var inner: Vector3 = wall.position - n * 0.12
	var top_from := Vector3(inner.x, pos.y + s.ledge_max_height + 0.35, inner.z)
	var top_to := Vector3(inner.x, pos.y + s.ledge_min_height - 0.1, inner.z)
	var top := p.raycast(top_from, top_to, Layers.GRABBABLE_MASK)
	if top.is_empty() or top.normal.y < 0.75:
		return {}
	var ledge_y: float = top.position.y
	var rel := ledge_y - pos.y
	if rel < s.ledge_min_height or rel > s.ledge_max_height:
		return {}
	var collider: Object = top.collider
	if collider is Node and (collider as Node).is_in_group(&"no_ledge_grab"):
		return {}

	if check_rise and p.velocity.y > 0.0:
		var rise := p.velocity.y * p.velocity.y / (2.0 * s.get_jump_gravity())
		if pos.y + rise > ledge_y + 0.05:
			return {}

	var lip_from := Vector3(pos.x, ledge_y - 0.1, pos.z)
	var lip := p.raycast(lip_from, lip_from + dir * (reach + 0.35), Layers.GRABBABLE_MASK)
	if lip.is_empty() or absf(lip.normal.y) > 0.5:
		return {}
	var lip_n := Player.flat(lip.normal).normalized()
	var lip_point := Vector3(lip.position.x, ledge_y, lip.position.z)

	var stand := lip_point - lip_n * (Player.CAPSULE_RADIUS + 0.15) + Vector3.UP * 0.05
	if not has_room(p, stand):
		return {}
	var hang := lip_point + lip_n * (Player.CAPSULE_RADIUS + 0.03)
	hang.y = ledge_y - s.hang_depth
	if not has_room(p, hang):
		return {}
	return {"point": lip_point, "normal": lip_n, "collider": collider, "hang": hang, "stand": stand}


## True if Patchy's capsule (slightly shrunk) fits with its feet at `feet`.
static func has_room(p: Player, feet: Vector3) -> bool:
	if _shape == null:
		_shape = CapsuleShape3D.new()
		_shape.radius = Player.CAPSULE_RADIUS - 0.05
		_shape.height = Player.CAPSULE_HEIGHT - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (Player.CAPSULE_HEIGHT * 0.5))
	q.collision_mask = Layers.PLAYER_BODY_MASK
	q.exclude = [p.get_rid()]
	return p.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
