class_name CastawayLayout
## Where things are on Castaway Cay (tools/builders/build_castaway_cay.gd):
## the heights of its levels, its landmarks and the outlines of its main
## landforms. Shared by the island's builder, its far-off silhouette
## (HorizonCastaway), the world builder (where Patchy wakes, where his boat
## ties up) and the tests. x east, z south (north is -Z), sea level y 0,
## the island's middle near the origin. Outlines are Vector2(x, z).
##
##  - South-east: Wreck Shore, where Patchy washes up, his beached ship's
##    stern and the sea stack; the river runs out across the sand.
##  - South: the meadow (rolling hills, the waterfall pool, the river and
##    its footbridge), the south cove with the horn rock and the ring run.
##  - South-west: Barnacle Bay, the village climbing three terraces above
##    its harbor, the bluff with Tok's lookout tower, Gus's shipyard on the
##    east spit, Old Shellby's jetty on the west shore.
##  - West: the west beach and Gull Rock; the ravine under the rope bridge.
##  - North-west: the Whispering Woods on the highlands, the giant tree and
##    its treehouse, the dark cave.
##  - North-middle: Mount Patch: the shelf, the upper rocks and the summit,
##    the waterfall off the highlands' south lip and the alcove behind it.
##  - North: the north beach under the cliffs, its sea cave.
##  - North-east: across the gorge (the six-parrot log bridge), the old
##    fort's headland: ruins, the chained chest, King Claw's ring.
##  - East: the east downs, the grotto and the sea arch.

# --- Heights ----------------------------------------------------------------------
const SAND := 1.2
const QUAY := 1.6
## The meadow and the village plaza.
const LOW := 3.6
## The village's middle and top terraces, and Tok's bluff above them.
const MID := 8.4
const TERRACE := 12.8
const BLUFF := 16.4
## The highlands: the woods and Mount Patch's foot. The old fort's headland
## across the gorge is level with them (the log lies flat).
const HIGH := 19.0
const FORT := 19.0
const DOWNS := 8.0
## Mount Patch.
const SHELF := 30.0
const UPPER := 42.0
const SUMMIT := 54.0
## The waterfall pool and the river (water surfaces).
const POOL_WATER := 3.0
const RIVER_WATER := 2.2

# --- Landmarks --------------------------------------------------------------------
## Where Patchy wakes on Wreck Shore (the world puts him here).
const WASHED_UP := Vector3(86, 1.25, 100)
## Wreck Shore's wreck: the stern, the cabin, the mast and the sea stack
## are laid out from here.
const WRECK := Vector3(64, 0, 60)
## Patchy's boat ties up at the end of the pier.
const MOORING := Vector3(-96.6, 0, 87)
## The waterfall pool.
const POOL := Vector3(26, SAND, -19)
const POOL_R := 11.0
## Tok's lookout tower on the bluff.
const TOWER := Vector3(-104, BLUFF, -46)
## The giant tree in the woods.
const GIANT_TREE := Vector3(-128, HIGH, -92)
const GIANT_TREE_V2 := Vector2(-128, -92)
## The fort's courtyard and King Claw's ring.
const FORT_YARD := Vector3(124, FORT, -92)
const CLAW_RING := Vector3(142, FORT, -130)
## Driftwood Key, a short sail south-west of the harbor mouth.
const DRIFTWOOD := Vector3(-250, 0, 230)
## The island's own waters.
const WATERS_CENTER := Vector3(-5, 0, -10)
const WATERS_RADIUS := 245.0

# --- Landforms (Vector2(x, z)) ----------------------------------------------------
## The whole island's sandy coast, the bay cut into its south-west.
const COAST := [Vector2(-192, -70), Vector2(-180, -100), Vector2(-140, -125), Vector2(-90, -135), Vector2(-40, -142),
	Vector2(10, -145), Vector2(50, -142), Vector2(85, -145), Vector2(120, -150), Vector2(160, -135), Vector2(182, -105),
	Vector2(190, -65), Vector2(190, -25), Vector2(184, 15), Vector2(176, 50), Vector2(162, 80), Vector2(140, 102),
	Vector2(112, 116), Vector2(82, 120), Vector2(52, 114), Vector2(28, 102), Vector2(8, 92), Vector2(-14, 78),
	Vector2(-34, 68), Vector2(-40, 84), Vector2(-42, 100), Vector2(-50, 112), Vector2(-62, 110), Vector2(-66, 92),
	Vector2(-70, 76), Vector2(-85, 66), Vector2(-105, 64), Vector2(-125, 66), Vector2(-136, 74), Vector2(-140, 94),
	Vector2(-144, 112), Vector2(-152, 122), Vector2(-166, 120), Vector2(-176, 104), Vector2(-190, 80), Vector2(-200, 50),
	Vector2(-205, 15), Vector2(-202, -30)]
## The meadow and the village plaza, west of the river (and the ravine
## floor under the village's back).
const LOWLANDS_WEST := [Vector2(-174, -60), Vector2(-150, -66), Vector2(-110, -68), Vector2(-75, -66), Vector2(-55, -56),
	Vector2(-35, -40), Vector2(-10, -33), Vector2(14, -31), Vector2(15, -19), Vector2(18, -10), Vector2(23, -4),
	Vector2(28, 15), Vector2(34, 35), Vector2(38, 52), Vector2(40, 64), Vector2(30, 68), Vector2(12, 62), Vector2(-6, 54),
	Vector2(-24, 48), Vector2(-38, 46), Vector2(-52, 50), Vector2(-60, 56), Vector2(-75, 56), Vector2(-95, 54),
	Vector2(-115, 54), Vector2(-130, 56), Vector2(-148, 52), Vector2(-160, 40), Vector2(-168, 15), Vector2(-172, -20)]
## The meadow east of the river, and the gorge floor running north.
const LOWLANDS_EAST := [Vector2(37, -31), Vector2(58, -34), Vector2(60, -60), Vector2(58, -100), Vector2(60, -130),
	Vector2(70, -138), Vector2(80, -136), Vector2(80, -100), Vector2(78, -62), Vector2(88, -48), Vector2(100, -42),
	Vector2(100, -20), Vector2(112, 0), Vector2(116, 25), Vector2(108, 50), Vector2(88, 64), Vector2(66, 70),
	Vector2(51, 68), Vector2(48, 52), Vector2(44, 35), Vector2(38, 15), Vector2(33, -4), Vector2(35, -10), Vector2(37, -19)]
const EAST_DOWNS := [Vector2(96, -66), Vector2(130, -68), Vector2(165, -68), Vector2(186, -60), Vector2(188, -10),
	Vector2(180, 18), Vector2(168, 34), Vector2(140, 36), Vector2(118, 26), Vector2(108, 4), Vector2(100, -20)]
## The village's middle and top terraces, and the bluff.
const VILLAGE_MID := [Vector2(-162, 12), Vector2(-158, -10), Vector2(-130, -14), Vector2(-100, -14), Vector2(-78, -8),
	Vector2(-70, 6), Vector2(-78, 20), Vector2(-100, 24), Vector2(-130, 26), Vector2(-160, 24)]
const VILLAGE_TOP := [Vector2(-166, -22), Vector2(-160, -40), Vector2(-140, -46), Vector2(-110, -46), Vector2(-92, -40),
	Vector2(-86, -26), Vector2(-92, -12), Vector2(-120, -10), Vector2(-150, -10), Vector2(-164, -6)]
const BLUFF_TOP := [Vector2(-128, -56), Vector2(-100, -58), Vector2(-84, -52), Vector2(-82, -42), Vector2(-92, -36),
	Vector2(-112, -36), Vector2(-130, -44)]
## The highlands (the woods and Mount Patch's foot), notched where the
## waterfall drops into the pool.
const HIGHLANDS := [Vector2(-182, -75), Vector2(-176, -96), Vector2(-150, -112), Vector2(-110, -120), Vector2(-70, -118),
	Vector2(-30, -115), Vector2(10, -117), Vector2(40, -114), Vector2(58, -104), Vector2(62, -80), Vector2(62, -58),
	Vector2(56, -40), Vector2(44, -32), Vector2(33, -31), Vector2(32, -39), Vector2(20, -39), Vector2(19, -31),
	Vector2(0, -32), Vector2(-20, -35), Vector2(-40, -44), Vector2(-55, -56), Vector2(-75, -64), Vector2(-110, -66),
	Vector2(-150, -64), Vector2(-186, -62)]
const SHELF_TOP := [Vector2(-40, -60), Vector2(-22, -50), Vector2(0, -47), Vector2(24, -50), Vector2(42, -58),
	Vector2(52, -74), Vector2(48, -94), Vector2(26, -106), Vector2(-8, -106), Vector2(-32, -96), Vector2(-44, -80)]
const UPPER_TOP := [Vector2(-14, -64), Vector2(6, -58), Vector2(26, -64), Vector2(36, -78), Vector2(30, -94),
	Vector2(8, -100), Vector2(-12, -92), Vector2(-20, -78)]
const SUMMIT_TOP := [Vector2(2, -70), Vector2(16, -68), Vector2(24, -78), Vector2(20, -90), Vector2(6, -92), Vector2(-2, -82)]
## The old fort's headland across the gorge.
const HEADLAND := [Vector2(78, -60), Vector2(100, -62), Vector2(130, -64), Vector2(160, -62), Vector2(182, -75),
	Vector2(188, -105), Vector2(180, -134), Vector2(156, -150), Vector2(124, -152), Vector2(98, -142), Vector2(82, -122),
	Vector2(78, -95), Vector2(77, -75)]
## The river's course from the pool to the sea (centerline).
const RIVER := [Vector2(26, -8), Vector2(28, 2), Vector2(33, 15), Vector2(39, 35), Vector2(43, 52), Vector2(45, 66)]


static func v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)
