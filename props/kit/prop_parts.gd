class_name PropParts
extends RefCounted
## Per-finish PropBuilder buckets for one prop mesh. build() commits them
## into a single ArrayMesh with one surface per non-empty finish, each using
## a shared material (MaterialLibrary toon finishes, the swaying foliage
## material, or an emissive glow), so hundreds of props share a handful of
## materials and vertex colors carry the palette.

var matte := PropBuilder.new()    ## wood, rope, cloth, stone
var soft := PropBuilder.new()     ## rounded organic forms (coconuts, bushes)
var glossy := PropBuilder.new()   ## painted wood, glass, gilding
var metal := PropBuilder.new()    ## iron, brass, gold
var foliage := PropBuilder.new()  ## double-sided, sways (see foliage_profile)
var glow := PropBuilder.new()     ## emissive (lamp glass, embers)
var gem := PropBuilder.new()      ## faceted gems (PropKit.gem_material)

## PropKit.foliage_material() profile for the foliage bucket.
var foliage_profile: StringName = &"leaves"
## Emission color for the glow bucket.
var glow_color: Color = PropPalette.LAMP_GLOW


func triangle_count() -> int:
	var n := 0
	for b: PropBuilder in [matte, soft, glossy, metal, foliage, glow, gem]:
		n += b.triangle_count()
	return n


func is_empty() -> bool:
	for b: PropBuilder in [matte, soft, glossy, metal, foliage, glow, gem]:
		if not b.is_empty():
			return false
	return true


## Points of every bucket (for convex collision).
func unique_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for b: PropBuilder in [matte, soft, glossy, metal, foliage, glow, gem]:
		out.append_array(b.unique_points())
	return out


func aabb() -> AABB:
	var box := AABB()
	var first := true
	for b: PropBuilder in [matte, soft, glossy, metal, foliage, glow, gem]:
		if b.is_empty():
			continue
		box = b.aabb() if first else box.merge(b.aabb())
		first = false
	return box


func build(mesh: ArrayMesh = null) -> ArrayMesh:
	var m := mesh if mesh != null else ArrayMesh.new()
	if not matte.is_empty():
		matte.build(m, MaterialLibrary.toon(Color.WHITE, &"matte"))
	if not soft.is_empty():
		soft.build(m, MaterialLibrary.toon(Color.WHITE, &"soft"))
	if not glossy.is_empty():
		glossy.build(m, MaterialLibrary.toon(Color.WHITE, &"glossy"))
	if not metal.is_empty():
		metal.build(m, MaterialLibrary.toon(Color.WHITE, &"metal"))
	if not foliage.is_empty():
		foliage.build(m, PropKit.foliage_material(foliage_profile))
	if not glow.is_empty():
		glow.build(m, MaterialLibrary.toon(glow_color, &"emissive"))
	if not gem.is_empty():
		gem.build(m, PropKit.gem_material())
	return m
