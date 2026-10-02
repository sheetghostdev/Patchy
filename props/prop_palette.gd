class_name PropPalette
## Extra color constants for the props & nature kit. Extends the shared
## Palette (systems/materials/palette.gd) without editing it: every prop pulls
## from here or from Palette so the kit stays cohesive with Patchy and the
## Castaway Cay terrain. Colors are authored in sRGB (vertex colors).

# --- Palm trees -----------------------------------------------------------------
const PALM_TRUNK := Color("a8703f")
const PALM_TRUNK_LIGHT := Color("d9a466")
const PALM_TRUNK_DARK := Color("7d5232")
const PALM_CROWN := Color("8a6a3a")
const FROND_BASE := Color("17603a")
const FROND_MID := Color("268f48")
const FROND_TIP := Color("58b84a")
const FROND_RIB := Color("a3c95f")
const FROND_DRY := Color("d8b25c")
const COCONUT := Color("7a4c2c")
const COCONUT_GREEN := Color("8fae3c")

# --- Rocks: [base, top, dark] ------------------------------------------------------
const ROCK_SAND := [Color("dba06a"), Color("efc58f"), Color("b07a4c")]
const ROCK_CLIFF := [Color("b59d86"), Color("d2bea2"), Color("86705e")]
const ROCK_DARK := [Color("6d7085"), Color("8b8ea3"), Color("4f5165")]
const ROCK_MOSSY := [Color("a59c88"), Color("c2b9a3"), Color("7b7262")]
const MOSS := Color("6fc046")
const MOSS_DARK := Color("4e9e39")

# --- Ground foliage -------------------------------------------------------------------
const BUSH := Color("4dab3f")
const BUSH_DARK := Color("2f7d38")
const BUSH_LIGHT := Color("86d356")
const GRASS_BASE := Color("3c8c32")
const GRASS_TIP := Color("8fd24f")
const FERN_BASE := Color("1a6a3b")
const FERN_TIP := Color("4fae4a")
const STEM := Color("4f9a3a")
const FLOWER_RED := Color("ff4f6d")
const FLOWER_PINK := Color("ff86c0")
const FLOWER_YELLOW := Color("ffd23f")
const FLOWER_WHITE := Color("fff6ea")
const FLOWER_ORANGE := Color("ff9a3c")
const FLOWER_PURPLE := Color("b48cff")
const FLOWER_CENTER := Color("ffcf4d")
const BERRY := Color("ff5a7a")

# --- Wood --------------------------------------------------------------------------------
## Warm plank tones (crates, docks, bridges) light -> dark.
const PLANK := Color("c98a4b")
const PLANK_LIGHT := Color("dda365")
const PLANK_DARK := Color("9a6136")
const WOOD_FRAME := Color("a5683a")
const WOOD_DEEP := Color("6e4128")
## Breakable crates read lighter and yellower (spec: readable breakables).
const CRATE_BREAKABLE := Color("e6a95e")
const CRATE_BREAKABLE_FRAME := Color("c98340")
const DRIFTWOOD := Color("c9b293")
const DRIFTWOOD_DARK := Color("9d8a72")
const BAMBOO := Color("c9ab55")
const BAMBOO_DARK := Color("8f7a32")

# --- Metal ------------------------------------------------------------------------------
const IRON := Color("5d6a80")
const IRON_DARK := Color("434c5e")
const IRON_LIGHT := Color("8592a8")
const BRONZE := Color("d18f45")
const GOLD_DEEP := Color("e3a32a")
const GOLD_LIGHT := Color("ffe07a")

# --- Cloth & rope -------------------------------------------------------------------------
const ROPE_DARK := Color("a8834f")
const ROPE_LIGHT := Color("e0c48c")
const SAIL := Color("f4e8cc")
const SAIL_SHADE := Color("e3d2ad")
const SAIL_STRIPE := Color("d9483b")

# --- Patchy's ship (wreck pieces) ------------------------------------------------------
const HULL := Color("b0703d")
const HULL_LIGHT := Color("c98a50")
const HULL_DARK := Color("85502c")
const HULL_PAINT := Color("c8372d")
const HULL_TRIM := Color("ffd166")
const HULL_INNER := Color("a36c41")

# --- Signs ------------------------------------------------------------------------------------
const SIGN_FACE := Color("f7e9c6")
const SIGN_INK := Color("4a2a1c")
const SIGN_PAINTS := [Color("4bb8a9"), Color("ef7f5a"), Color("ffd166"), Color("5aa3e6"), Color("ef7fa7")]

# --- Light & fire -----------------------------------------------------------------------------
const FLAME_CORE := Color("fff1a8")
const FLAME_EDGE := Color("ff7a24")
const FLAME_TIP := Color("ff4d2e")
const LAMP_GLOW := Color("ffd27a")
const TORCH_LIGHT := Color(1.0, 0.72, 0.4)

# --- Treasure ---------------------------------------------------------------------------------
const CHEST_WOOD := Color("a8642f")
const CHEST_WOOD_DARK := Color("7e4524")
const CHEST_BAND := Color("4f5a70")
const CHEST_GOLD := Color("efaa25")
const CHEST_GOLD_DARK := Color("c47f1c")
const CHEST_INSIDE := Color("6b2f3a")
const COIN := Color("f5b027")
const COIN_RIM := Color("ffd24a")
const GEM_GREEN := Color("4fe08a")
const GEM_PURPLE := Color("b57cff")
const GEM_YELLOW := Color("ffe04f")
const CAGE_BASE := Color("8c4a2e")
const CAGE_BASE_TRIM := Color("b56a3c")
const PERCH := Color("c98a4b")
