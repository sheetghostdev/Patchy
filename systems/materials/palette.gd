class_name Palette
## Shared color language (spec §7). Every material pulls from here so islands
## keep a coherent, readable palette. Castaway Cay: turquoise water, pale
## sand, vibrant greens, warm wood, blue sky.

# Patchy
const SKIN := Color("f2b48a")
const COAT := Color("c8372d")
const COAT_TRIM := Color("ffd166")
const SHIRT := Color("f6eedb")
const PANTS := Color("3a4a7a")
const BOOTS := Color("5a3424")
const BELT := Color("2b2135")
const HAT := Color("2e2445")
const HAT_BAND := Color("e2a03f")
const GLOVE := Color("f4efe6")
const HOOK_METAL := Color("cfd8e3")
const BRASS := Color("e0a842")
const EYE_WHITE := Color("fffdf7")
const PUPIL := Color("1b1726")
const BROW := Color("4a2a1c")
const BEARD := Color("6b3a22")

# Castaway Cay
const GRASS := Color("6cbd45")
const GRASS_DARK := Color("4f9c34")
const DIRT := Color("b9804b")
const DIRT_DARK := Color("86573a")
const SAND := Color("f3dfa6")
const SAND_DARK := Color("d9bb7c")
const ROCK := Color("bda48a")
const ROCK_DARK := Color("85725f")
const WOOD := Color("b97a40")
const WOOD_DARK := Color("7c4b2a")
const STONE := Color("c4bcae")
const STONE_DARK := Color("8f877c")
const METAL := Color("8d97a3")
const ROPE := Color("c9a46c")
const LEAF := Color("5fbf3f")
const LEAF_DARK := Color("3d8f35")
const TRUNK := Color("a8784d")
const WATER_SHALLOW := Color("45ded3")
const WATER_DEEP := Color("1679b9")
const SKY_TOP := Color("3f8fe0")
const SKY_HORIZON := Color("bfe8ff")
const SUN := Color("fff2d6")

# Gameplay readability accents
const GOLD := Color("ffc93c")
const GEM_RED := Color("ff4f6d")
const GEM_BLUE := Color("4fc3ff")
const INTERACT := Color("ffe27a")
const HAZARD := Color("e8553f")
const CRAB := Color("ef6a3a")
const CRAB_DARK := Color("b8432a")
const PARROT_RED := Color("ef3e36")
const PARROT_BLUE := Color("2f8fe8")
const PARROT_YELLOW := Color("ffd23f")

# Test-lab colors: warm, friendly blockout instead of gray boxes (spec §187)
const LAB_FLOOR := Color("d8ccb0")
const LAB_FLOOR_SIDE := Color("c7b28e")
const LAB_ORANGE := Color("f29e4c")
const LAB_TEAL := Color("4bb8a9")
const LAB_PURPLE := Color("9b7fd1")
const LAB_PINK := Color("ef7fa7")
const LAB_BLUE := Color("5aa3e6")

## Terrain presets: surface id -> [top, side, side_dark].
const TERRAIN := {
	&"grass": [GRASS, DIRT, DIRT_DARK],
	&"sand": [SAND, SAND_DARK, Color("c4a066")],
	&"rock": [Color("cdbca3"), ROCK, ROCK_DARK],
	&"cliff": [GRASS, ROCK, ROCK_DARK],
	# Warm banded sandstone under a grass cap (Castaway Cay's hills and
	# Mount Patch), and grey sea-cliff stone (the old fort's headland).
	&"cliff_warm": [GRASS, Color("cf9a62"), Color("8f5c3a")],
	&"cliff_grey": [Color("7cbf52"), Color("aba69c"), Color("6d6862")],
	&"wood": [WOOD, WOOD_DARK, Color("5e3820")],
	&"wood_dark": [WOOD_DARK, Color("5e3820"), Color("472a17")],
	&"thatch": [Color("e8c66e"), Color("cfa94f"), Color("a8843a")],
	&"roof_red": [Color("d9483b"), Color("b8372d"), Color("8f2a22")],
	&"roof_blue": [Color("3f8fd9"), Color("2f72b3"), Color("24578a")],
	&"stone": [STONE, STONE_DARK, Color("6f685f")],
	&"dirt": [DIRT, DIRT_DARK, Color("6a4430")],
	&"metal": [METAL, Color("6c7682"), Color("4d5560")],
	&"lab": [LAB_FLOOR, LAB_FLOOR_SIDE, Color("a8926e")],
	&"lab_orange": [LAB_ORANGE, Color("d9803a"), Color("b9672b")],
	&"lab_teal": [LAB_TEAL, Color("379b8e"), Color("2a7d72")],
	&"lab_purple": [LAB_PURPLE, Color("7f63b8"), Color("654c99")],
	&"lab_pink": [LAB_PINK, Color("d9668e"), Color("b84f73")],
	&"lab_blue": [LAB_BLUE, Color("4486c7"), Color("356ca3")],
}
