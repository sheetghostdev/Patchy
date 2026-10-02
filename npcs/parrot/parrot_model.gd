@tool
class_name ParrotModel
extends Node3D
## A small, round, expressive parrot (spec §63–67): big curved beak, bright
## plumage variants so the flock looks varied, flapping wing pivots and a
## head pivot for curious looks.

enum Plumage { SCARLET, AZURE, SUNNY, LIME, ROSE }

const COLORS := {
	Plumage.SCARLET: [Palette.PARROT_RED, Palette.PARROT_YELLOW, Palette.PARROT_BLUE],
	Plumage.AZURE: [Palette.PARROT_BLUE, Palette.PARROT_YELLOW, Color("2a5fb8")],
	Plumage.SUNNY: [Palette.PARROT_YELLOW, Color("ff8a2b"), Color("3aa856")],
	Plumage.LIME: [Color("62c94a"), Palette.PARROT_RED, Color("2f8fe8")],
	Plumage.ROSE: [Color("ff7fb0"), Color("ffffff"), Color("8a5cd6")],
}

@export var plumage := Plumage.SCARLET:
	set(v):
		plumage = v
		_build()

var body: Node3D
var head: Node3D
var wing_l: Node3D
var wing_r: Node3D
var tail: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"parrot_generated", false):
			c.free()
	var cols: Array = COLORS[plumage]
	var main: Color = cols[0]
	var accent: Color = cols[1]
	var wingtip: Color = cols[2]
	body = Node3D.new()
	body.set_meta(&"parrot_generated", true)
	body.name = "Body"
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	_part(body, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.13, 0.16, 0.14), Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), Vector3(0, 0.0, 0.02)), main, 8, 12)
		mb.ellipsoid(Vector3(0.09, 0.11, 0.06), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.1)), accent.lerp(Color.WHITE, 0.3), 6, 10)
		# Feet.
		mb.cylinder(0.012, 0.012, 0.08, Transform3D(Basis.IDENTITY, Vector3(-0.04, -0.17, 0.0)), Color("e09a3a"), 5)
		mb.cylinder(0.012, 0.012, 0.08, Transform3D(Basis.IDENTITY, Vector3(0.04, -0.17, 0.0)), Color("e09a3a"), 5)
	)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.15, -0.05)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		mb.sphere(0.11, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), main, 8, 12)
		# Big curved beak (two stacked cones).
		mb.cylinder(0.0, 0.055, 0.12, Transform3D(Basis.from_euler(Vector3(-PI * 0.5 - 0.5, 0, 0)), Vector3(0, 0.03, -0.12)), Color("ffd27a"), 8)
		mb.cylinder(0.0, 0.04, 0.07, Transform3D(Basis.from_euler(Vector3(-PI * 0.5 + 0.3, 0, 0)), Vector3(0, -0.005, -0.1)), Color("3b3240"), 8)
		for side: float in [-1.0, 1.0]:
			mb.sphere(0.045, Transform3D(Basis.IDENTITY, Vector3(side * 0.06, 0.08, -0.07)), Color.WHITE, 6, 8)
			mb.sphere(0.024, Transform3D(Basis.IDENTITY, Vector3(side * 0.068, 0.082, -0.105)), Palette.PUPIL, 4, 6)
		# Crest.
		mb.ellipsoid(Vector3(0.025, 0.07, 0.04), Transform3D(Basis.from_euler(Vector3(-0.5, 0, 0)), Vector3(0, 0.17, 0.02)), accent, 4, 6)
	)
	wing_l = _wing(-1.0, main, wingtip)
	wing_r = _wing(1.0, main, wingtip)
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, -0.08, 0.12)
	body.add_child(tail)
	_part(tail, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.05, 0.02, 0.17), Transform3D(Basis.from_euler(Vector3(0.6, 0, 0)), Vector3(0, -0.04, 0.12)), wingtip, 4, 8)
		mb.ellipsoid(Vector3(0.035, 0.018, 0.12), Transform3D(Basis.from_euler(Vector3(0.6, 0.25, 0)), Vector3(0.04, -0.03, 0.09)), accent, 4, 6)
	)


func _wing(side: float, main: Color, tip: Color) -> Node3D:
	var w := Node3D.new()
	w.name = "WingL" if side < 0.0 else "WingR"
	w.position = Vector3(side * 0.11, 0.06, 0.0)
	body.add_child(w)
	_part(w, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.14, 0.025, 0.09), Transform3D(Basis.IDENTITY, Vector3(side * 0.12, 0, 0.02)), main, 4, 10)
		mb.ellipsoid(Vector3(0.08, 0.02, 0.06), Transform3D(Basis.IDENTITY, Vector3(side * 0.23, 0, 0.05)), tip, 4, 8)
	)
	return w


func _part(parent: Node3D, fill: Callable) -> void:
	var mb := MeshBuilder.new()
	fill.call(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	parent.add_child(mi)


## Wing pose: 0 = folded, 1 = up, -1 = down. Called every frame by actors.
func set_flap(amount: float) -> void:
	if wing_l == null:
		return
	wing_l.rotation = Vector3(0, 0, amount * 1.1)
	wing_r.rotation = Vector3(0, 0, -amount * 1.1)


func set_folded() -> void:
	if wing_l == null:
		return
	wing_l.rotation = Vector3(0.2, 0.9, 1.2)
	wing_r.rotation = Vector3(0.2, -0.9, -1.2)
