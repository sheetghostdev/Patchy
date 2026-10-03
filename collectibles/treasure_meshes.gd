class_name TreasureMeshes
## Procedural meshes for collectibles, cached per kind. Chunky, glossy and
## readable at distance (spec §83): coins, gems, goblets, crowns, pearls,
## relics and hearts.

static var _cache: Dictionary = {}


static func get_mesh(kind: StringName, color: Color = Palette.GEM_RED) -> ArrayMesh:
	var key := "%s_%s" % [kind, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var metal := MeshBuilder.new()
	var glossy := MeshBuilder.new()
	var gold := Palette.GOLD
	match kind:
		&"coin":
			metal.cylinder(0.24, 0.24, 0.07, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3.ZERO), gold, 18)
			metal.torus(0.17, 0.24, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3.ZERO), gold.lightened(0.12), 18, 6)
			# Embossed anchor-ish cross on both faces.
			for z: float in [-0.04, 0.04]:
				metal.box(Vector3(0.05, 0.22, 0.03), Transform3D(Basis.IDENTITY, Vector3(0, 0, z)), gold.darkened(0.12))
				metal.box(Vector3(0.16, 0.05, 0.03), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, z)), gold.darkened(0.12))
		&"gem":
			glossy.sphere(0.24, Transform3D(Basis.from_scale(Vector3(0.85, 1.15, 0.85)), Vector3.ZERO), color, 3, 6)
			glossy.flat_shade()
		&"pearl":
			glossy.sphere(0.16, Transform3D.IDENTITY, Color("f6f1ea"), 8, 12)
			metal.torus(0.13, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), Color("e6c9a8"), 12, 6)
		&"goblet":
			metal.cylinder(0.2, 0.12, 0.26, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), gold, 14)
			metal.cylinder(0.035, 0.035, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), gold, 8)
			metal.cylinder(0.15, 0.17, 0.05, Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), gold, 14)
			glossy.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, -0.17)), Palette.GEM_RED, 3, 6)
		&"crown":
			metal.cylinder(0.24, 0.24, 0.14, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), gold, 16, false)
			for k in 5:
				var a := TAU * k / 5.0
				var p := Vector3(cos(a) * 0.23, 0.13, sin(a) * 0.23)
				metal.cylinder(0.0, 0.06, 0.16, Transform3D(Basis.IDENTITY, p), gold, 6)
				glossy.sphere(0.035, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.1, 0)), Palette.GEM_BLUE, 3, 6)
		&"relic":
			metal.rounded_box(Vector3(0.36, 0.26, 0.12), 0.04, Transform3D.IDENTITY, Color("c98f4a"), 2)
			glossy.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.07)), Palette.GEM_BLUE, 4, 8)
		&"teapot":
			# The Golden Teapot (Teacup Isle): round body, curved spout,
			# looped handle, a lid with a gem knob.
			metal.sphere(0.22, Transform3D(Basis.from_scale(Vector3(1.0, 0.82, 1.0)), Vector3.ZERO), gold, 8, 12)
			metal.cylinder(0.14, 0.17, 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.18, 0)), gold.lightened(0.1), 12)
			metal.cylinder(0.12, 0.12, 0.05, Transform3D(Basis.IDENTITY, Vector3(0, -0.19, 0)), gold.darkened(0.1), 12)
			metal.tube(PackedVector3Array([Vector3(0.18, -0.03, 0), Vector3(0.3, 0.04, 0), Vector3(0.36, 0.16, 0)]), PackedFloat32Array([0.05, 0.035, 0.025]), gold, 6)
			metal.torus(0.09, 0.12, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(-0.25, 0.02, 0)), gold, 12, 5)
			glossy.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0)), Palette.GEM_BLUE, 3, 6)
		&"heart":
			var red := Color("ff5470")
			glossy.sphere(0.14, Transform3D(Basis.IDENTITY, Vector3(-0.1, 0.06, 0)), red, 8, 12)
			glossy.sphere(0.14, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.06, 0)), red, 8, 12)
			glossy.cylinder(0.0, 0.2, 0.26, Transform3D(Basis.from_euler(Vector3(PI, 0, 0)).scaled(Vector3(1.0, 1.0, 0.6)), Vector3(0, -0.1, 0)), red, 12)
		_:
			glossy.sphere(0.2, Transform3D.IDENTITY, color, 6, 10)
	var mesh := ArrayMesh.new()
	if not metal.is_empty():
		metal.build(mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	if not glossy.is_empty():
		glossy.build(mesh, MaterialLibrary.toon(Color.WHITE, &"glossy"))
	_cache[key] = mesh
	return mesh
