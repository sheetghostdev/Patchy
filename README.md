# PATCHY

A cheerful third-person 3D platformer about a small pirate with a big hook,
made in **Godot 4.7 (GDScript, Forward+, Jolt Physics)**.

The ship *Patchy* is wrecked and Brock the Croc's crab minions have scattered
his treasure. Patchy recovers it across a tropical archipelago, freeing caged
parrots and swapping hook-hand attachments as he goes.

Design priorities, in order:
1. Patchy must feel amazing to control.
2. The camera must feel amazing.
3. Content comes after that. We cut content before we cut movement quality.

Gameplay always drives animation, and animation never delays control.

The world plan, island by island (Super Mario Galaxy's toy-box islands
meet The Wind Waker's sea), is in [docs/ARCHIPELAGO.md](docs/ARCHIPELAGO.md).

## Running

```bash
godot --path .                          # title screen -> New Game / Continue
godot --path . res://world/sea/world.tscn                           # jump straight in
godot --path . res://tests/scenes/movement_test.tscn                # movement lab
godot --path . res://tests/scenes/camera_test.tscn                  # camera lab
godot --path . res://props/prop_gallery.tscn                        # props kit
godot --path . res://world/ocean/ocean_test.tscn                    # ocean lab
```

Debug keys:

| Key | Action |
|---|---|
| F1 | Debug menu (debug builds): teleports, parrots, treasure, attachments, invincibility, checkpoints, debug draws, time scale |
| F3 | Movement HUD |
| F4 | Camera debug draw |
| F5 | Quick save |
| F9 | Quick load |

## Controls

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows (Alt = walk) | Left stick (analog walk ↔ run) |
| Camera | Mouse, or J L I K | Right stick |
| Recenter camera | C / middle mouse | R3 |
| Jump | Space | A |
| Crouch / ground pound (in air) | Shift | LT |
| Dive | Ctrl or F | B |
| Hook swipe | Left mouse | X |
| Interact / talk / board | E | Y |
| Attachment action | Right mouse | RT |
| Attachment secondary | R | D-pad down |
| Cycle attachments | Mouse wheel or Z / X | LB / RB |
| Pause | Esc or P | Start |
| Map | M | Back |
| Spyglass (once found, hold) | V | D-pad up |

### Moves

| Move | How |
|---|---|
| Variable jump | Tap for a short hop, hold for a full jump (2.4 m). |
| Long jump | Run, then crouch + jump (9+ m). |
| High flip | Crouch while standing, then jump (3.4 m). |
| Dive | Dive in the air or while running, then jump to roll out. |
| Ground pound | Crouch in the air. Jump right after landing for the 3.8 m pound jump. |
| Ledge grab | Forgiving catch on near misses. Up or jump climbs; sideways shimmies. |
| Wall kick | Jump while sliding down a wall. You can't kick the same wall twice in a row. |
| Hook swing | Jump at a glowing ring with the hook equipped. Pump with the stick; jump to release. |
| Swimming | Surface paddle or dive under. |
| Boat | Board Patchy's dinghy with E and steer with the stick. Jump hops out near shore. With Gus's bow cannon fitted, right mouse or RT (or attack) fires it. Once an island is discovered, the pause-menu sea chart offers "Sail to ..." fast travel. |
| Brace | Crouch on the ground and gusts of wind can't blow you over. |
| Spyglass | Hold V (or D-pad up), on foot or at the tiller, and aim with the camera. Hold a far island in the middle of the glass and it's pencilled onto the sea chart. |

### Hand attachments

Cycle attachments with the mouse wheel, Z / X or LB / RB. Use the equipped
one with right mouse or RT.

| Attachment | Where | Uses |
|---|---|---|
| Pirate Hook | Patchy's own | Swipe; catch golden rings to swing; pull handles. |
| Storm Lantern | Driftwood Key | Dark caves become explorable; lights braziers; its flash topples crabs. |
| Pirate Spade | The dark cave | Digs up sparkling mounds and the spots treasure maps sketch; scoops crabs over. |
| Grappling Claw | Headland chest | Zips to rings and dark iron points up to 22 m away, even mid-air; yanks crabs. |
| Hand Cannon | Grapple pillar | Ranged shots ring targets and crumble cracked rock; a mid-air shot gives a cannon hop. |

## Project layout

```
autoload/           Global singletons: Events bus, Settings, WorldState, ParrotManager,
                    InventoryManager, GameManager, SaveManager, AudioManager,
                    SceneTransition (+ UI, see ui/)
characters/patchy/  Player controller, states/, input buffer, ledge probe, health,
                    combat, interaction, attachment manager, procedural model + animator
systems/            Camera rig, settings, zones and focus zones; collision layers;
                    toon materials; procedural MeshBuilder; interaction base;
                    triggers; quest log
attachments/        Hand attachments: hook, lantern, shovel, grapple, cannon
                    (AttachmentBase plus one folder each)
resources/          Data resources (AttachmentData .tres, movement and camera settings)
enemies/            Crabs (normal, armored, hermit, cannon), TNT snail, pelican, croc grunt,
                    King Claw boss plus arena
npcs/               Parrots; islanders (NPC base, FavorNPC quest givers, LookoutNPC,
                    ShipwrightNPC) and their models (turtle, monkey, otter, walrus,
                    octopus, Brock the Croc)
collectibles/       Coins, gems, treasure kinds, coin trails
world/              Terrain (Plateau); ocean (stylized Ocean, underwater effect,
                    sea regions, tide); sea/ (the one world: WorldDirector,
                    sea mist, the chart's edge; bell buoy, floating
                    barrels, dolphins, fish schools); islands (Castaway Cay and
                    Driftwood Key, IslandInfo, IslandZone); horizon/ (the
                    Archipelago registry and far-island silhouettes); hub (captain's
                    cabin); vehicles (TinyBoat); objects (cages, parrot tasks,
                    chests, dig spots, braziers, gates, targets, cracked rock,
                    doors, Shellby's fishing boat, drag marks...)
props/              Art kit: palms, broadleaf trees, rocks, foliage scatter, coral, kelp,
                    crates and barrels, docks, rope bridges, wreck pieces, signs,
                    torches, Beak Rock; the village kit (houses, market stalls,
                    the well, string lines of laundry, bunting and lanterns, net
                    racks); plus level blocks
ui/                 HUD, dialogue, pause menu (map, treasure, attachments, quests,
                    settings), title screen, sea chart, debug menu, input glyphs
effects/            VFX helpers (dust, rings, splashes, sparkles)
audio/              Original synthesized SFX + music (generated by tools/audio)
tests/              Headless test suites + lab scenes
tools/              Scene builders, photo tool, project setup, audio generator
```

## Architecture notes

- **Player controller** (`characters/patchy/player.gd`): a `CharacterBody3D`
  driven by small state objects in `states/` (ground, air, dive, roll,
  belly slide, ground pound, ledge, slide, swim, swing, hurt, locked, boat).
  - Shared physics helpers live on Player: gravity phases, air steering,
    step-up, ceiling slip and edge detection.
  - Each takeoff (normal, long, high flip, wall kick, ...) has a
    `JumpProfile`.
  - Input is buffered with press ages: coyote time, jump buffer and the
    long-jump crouch window.
  - Every tunable lives in `PlayerMovementSettings`
    (`resources/settings/`). Derived gravities come from height and
    time-to-apex.
- **Camera** (`systems/camera/camera_rig.gd`): rig, then yaw pivot, then
  pitch pivot, then arm, then camera.
  - Collision: a custom sphere cast. The camera moves in instantly and eases
    back out after a delay, so it never snaps.
  - Vertical: a dead zone, so jumps don't bob the view.
  - Assists: speed look-ahead, gentle lateral auto-align and recenter.
  - Modes: swing, swim, underwater and boat framing.
  - `CameraZone` areas blend distance, pitch, height, FOV and yaw hints.
  - Trauma shake is scaled by the accessibility setting.
  - Tunables live in `CameraSettings`. F4 draws the debug view.
- **Attachments**: `AttachmentData` (.tres) points at a scene whose root
  extends `AttachmentBase`. `AttachmentManager` mounts the equipped one in
  the hook socket, cycles with a clunk, and forwards the tool buttons.
- **Progression** is three tracks:
  - Treasure: `InventoryManager`.
  - Parrots: `ParrotManager`. Parrots are never consumed; a `ParrotTask`
    checks flock strength.
  - Attachments and ship parts: `InventoryManager`.

  Every persistent thing has a stable string id (cages, gems, chests,
  crabs, tasks, the boat). `WorldState` stores world changes.
- **Saving** (`SaveManager`): versioned JSON slots, written to a temp file
  and then renamed.
  - Autosaves are debounced and run only in a real play session (title
    screen: New Game or Continue).
  - Continue returns Patchy to his last checkpoint on the right island.
- **UI** (`ui/ui_root.tscn`, autoload `UI`): HUD (hearts, treasure, parrots,
  equipped attachment, prompts, toasts, island banner), dialogue
  (`await UI.show_dialogue(...)`), pause menu, sea chart, settings with
  rebinding, Gus's shipyard (`await UI.open_shipyard()`), title screen and
  debug menu.
  - Gameplay talks to it mostly through `Events` signals.
  - `QuestLog` derives the quest page from progress.
- **The archipelago** (`world/horizon/`, `world/sea/`, docs/ARCHIPELAGO.md):
  - One world, `world/sea/world.tscn` (`tools/builders/build_world.gd`):
    the sky, one ocean over the whole chart, Patchy, his camera and his
    boat, and every island in its true place. No walls between islands and
    no scene changes: sail (or swim) from any island to any other.
  - `Archipelago` says where every island lies, how it faces and how far
    its waters reach.
  - Each built island is a chunk: its own scene, built in place by a
    `tools/builders/build_*.gd` on `IslandBuilder` (just the island, its
    waters, mooring and seabed), instanced into the world.
  - `WorldDirector` places Patchy on load (checkpoint, spawn point or the
    beach), wakes the islands near him and puts far ones to sleep (no
    processing, no physics, hidden) behind their `HorizonIsland`
    silhouettes, which grow a little with distance so far islands still
    read. It tracks the waters he's in (`SeaRegion`): the current island,
    the discovery banner, the music and the landing as respawn point.
  - Islands not built yet are wrapped in sea mist (`MistBank`), and past
    the edge of the chart the fog turns a boat round (`SeaEdge`).
  - Four late islands are ringed by a sea hazard (`SeaHazard`, placed from
    `Archipelago`'s "hazard"): Stormpeak's storm wall, Brock's fort guns
    round Cannonball Cliffs, Cinder Isle's boiling sea and Crocodile
    Crown's reef maze. Each turns the boat back until Patchy's ship has the
    upgrade that answers it.
  - Patchy's ship (`systems/ship/ShipUpgrades`, saved in `WorldState`):
    sail, hull and cannon upgrades (Betty's spare sail from Shellby; the
    rest bought for gold at Gus's shipyard, `UIShipyard`), plus free looks
    (sail colors, a flag, a figurehead). `BoatModel` draws the boat from
    them, the same in the sea and in the shipyard's window.
  - Swimming is free in an island's own waters; out in the open sea
    Patchy's breath runs down (`SwimStamina`, a ring by him on the HUD)
    and after six seconds he goes under, a heart down and back on the last
    safe ground (`PlayerHealth.go_under`). The islands are a sail apart,
    not a swim.
  - Hat Rock's silhouette, with `playable` set, is also its real rock (the
    same goes for the other built islands).
- **Treasure maps and ship parts** are registries
  (`systems/treasure/`): `TreasureMaps` holds each map's island, title,
  riddle, dig spot and sketch (landmark doodles in the island's own x/z
  coordinates, drawn by `UITreasureMapView`); `ShipParts` names the parts
  and their islands. The Treasure page counts both per island.
- **Islanders** (`npcs/npc.gd`): an `NPC` turns to face Patchy and talks
  through the dialogue box. What it says comes from `get_lines()`, and
  `_after_talk()` runs before control returns.
  - `FavorNPC` asks a favor, nudges while it's open, and pays out (a
    treasure map, or a unique treasure tossed to Patchy) once a WorldState
    id is set.
  - `LookoutNPC` ends every chat with a tip about the first cage on its
    list that is still locked.
  - Unique treasure that only appears later (dig spots, rewards) counts
    toward an island's totals through the `treasure_source` group.
- **Islands**: a chunk scene with an `IslandInfo` node at its root. It
  registers parrot and treasure totals; in the world the `WorldDirector`
  does the rest from it (music, the discovery banner). A scene on its own
  (the captain's cabin) places Patchy (saved checkpoint or spawn point),
  then announces itself and starts its music after any opening sequence.
  - Smaller islands in the same chunk use `IslandZone`.
  - `SeaRegion` circles are an island's own waters: the current island,
    where Patchy can hop out of the boat, and where a stray boat washes
    up. The sea beyond them is open.
- **Audio** (`AudioManager`, driven by `audio/audio_manifest.json`): pooled
  SFX, cross-faded music and stingers.
  - A track's layers (`layer_of` in the manifest) play sample-locked to
    it. Enemies call `report_threat()` while they fight Patchy, which fades
    the combat layer in. It drops after four calm seconds.
  - Bosses swap in their own theme and end on a fanfare (`play_finale`),
    then the island's music returns.
  - Every sound and cue is synthesized by `tools/audio/generate_audio.py`,
    which is seeded, so reruns give identical files.

### Collision layers

| Bit | Value | Name | Used by |
|---|---|---|---|
| 1 | 1 | World | Terrain, blocks, buildings (camera collides with this only) |
| 2 | 2 | Player | Patchy |
| 3 | 4 | Enemy | Crabs and other enemies |
| 4 | 8 | NPC | Solid NPC bodies |
| 5 | 16 | Interactable | Interaction areas (cages, NPCs, chests, boats) |
| 6 | 32 | Projectile | Cannonballs and thrown things |
| 7 | 64 | Water | Water volumes |
| 8 | 128 | GrapplePoint | Hook rings and grapple targets |
| 9 | 256 | Trigger | Checkpoints, kill zones, darkness, island zones |
| 10 | 512 | Collectible | Coins, gems, ship parts |
| 11 | 1024 | Props | Boats, crates and other solid props (no camera collision) |
| 12 | 2048 | PlayerAttack | Swipe, dive and ground-pound hitboxes |
| 13 | 4096 | EnemyAttack | Pinches and other enemy hitboxes |

Patchy collides with World, NPC and Props. Constants live in
`systems/layers.gd`.

## Tuning guide

| What | Where |
|---|---|
| Movement feel (speeds, gravity phases, jump heights, coyote/buffer windows, ledge band, swim, swing) | `PlayerMovementSettings` |
| Camera (distance, pitch, dead zone, look-ahead, auto-align, collision, FOV, shake) | `CameraSettings` |
| Per-area camera framing | `CameraZone` nodes |
| Enemy feel (sight, speeds, windup and lunge timings) | `@export`s on `enemies/crab/crab.gd` |
| Boat handling | `@export`s on `world/vehicles/tiny_boat.gd` |
| Boss pacing (telegraphs, stuck time, phases) | `enemies/boss/king_claw.gd` |
| Ocean waves and colors | `@export`s on the `Ocean` node and `world/ocean/ocean.gdshader` |

The movement lab (`tests/scenes/movement_test.tscn`) has labeled distances
and heights for checking any change by feel.

## Tools

```bash
# Regenerate procedural scenes (labs, islands, hub) from code:
# (the islands first: the world instances them)
tools/builders/build.sh movement_lab camera_lab castaway_cay captains_cabin hat_rock bell_atoll pinwheel_isle teacup_isle world

# Render screenshots on a headless machine (xvfb + Vulkan). flags= marks
# WorldState ids, progress=demo fakes mid-game progress, hud=0 hides the HUD:
# player= puts Patchy somewhere else in the world (its islands wake round him):
tools/photo/shoot.sh scene=res://world/sea/world.tscn \
    flags=castaway_intro_seen out=/tmp/shot_%d.png "cams=0,120,160>0,0,0;30,10,62>50,3,42"

# UI states (pause pages, a treasure map unrolled at zoom 1.5):
tools/photo/shoot.sh scene=res://ui/tests/ui_preview.tscn size=1600x900 state=treasure_map map=castaway_map_2 zoom=1.5

# Props on their own (sets: palms, rocks, foliage, crates, dock, wreck,
# treasure, misc, landmarks):
tools/photo/shoot.sh scene=res://props/tests/prop_viewer.tscn show=landmarks "cams=-7,3.2,-1>0,2.4,-0.8"

# One far-off island over the real ocean and sky (an Archipelago id), or
# island=archipelago for all of them as seen from Castaway Cay:
tools/photo/shoot.sh scene=res://world/horizon/tests/horizon_viewer.tscn island=skullcap_mountain "cams=0,30,-380>0,50,0"

# The islanders (and Patchy for scale) lined up for a close look:
tools/photo/shoot.sh scene=res://tests/npc_gallery.tscn hud=0 "cams=-0.6,1.3,3.6>-0.6,0.65,0"

# Regenerate the original sound effects and music:
python3 tools/audio/generate_audio.py

# CPU cost of a level (logic + physics, headless). The whole world: about
# 3.7 ms per frame on Castaway Cay and a 2.4 s load:
godot --headless --path . --fixed-fps 60 res://tools/perf_probe.tscn -- scene=res://world/sea/world.tscn
```

## Tests

Every suite runs headless at a fixed 60 fps and exits non-zero on failure.
An optional argument after `--` filters test names.

```bash
godot --headless --path . --fixed-fps 60 res://tests/run_movement_tests.tscn   # 53 checks
godot --headless --path . --fixed-fps 60 res://tests/run_camera_tests.tscn     # 21 checks
godot --headless --path . --fixed-fps 60 res://tests/run_gameplay_tests.tscn   # 68 checks
godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn     # 187 checks
godot --headless --path . --fixed-fps 60 res://tests/run_world_tests.tscn      # 82 checks
godot --headless --path . --fixed-fps 60 res://tests/run_hat_rock_tests.tscn   # 43 checks
godot --headless --path . --fixed-fps 60 res://tests/run_bell_atoll_tests.tscn # 35 checks
godot --headless --path . --fixed-fps 60 res://tests/run_pinwheel_isle_tests.tscn # 23 checks
godot --headless --path . --fixed-fps 60 res://tests/run_teacup_isle_tests.tscn # 20 checks
godot --headless --path . --fixed-fps 60 res://ui/tests/ui_flow_test.tscn      # 96 checks
godot --headless --path . --fixed-fps 60 res://props/tests/prop_tests.tscn     # 74 checks
godot --headless --path . --fixed-fps 60 res://world/ocean/tests/ocean_swim_check.tscn
godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn -- sail
```

What each suite covers:

- **Movement**: measured jump heights and distances, acceleration, stopping,
  coyote time and jump buffer, long jump, flips, dive and roll, ground
  pound, ledge grab, wall kicks, slopes, steps, moving platforms and
  swimming.
- **Camera**: zero frames inside walls across corridors, pinch points,
  tunnels and rooms; no snapping; the jump dead zone; and recentering.
- **Gameplay**:
  - crabs (flip, stomp, steal and burrow), TNT snails, pelicans and croc
    shields;
  - treasure persistence, interaction prompts, cages and parrot tasks;
  - every attachment's combat use, the grapple zip into a swing and the
    cannon hop;
  - the combat music layer coming in and dropping out;
  - Crackers joining after the first rescue, his warnings and his nose
    for secrets;
  - the cabin hub's displays.
- **World**: the one sea. Every built island in its place with a
  silhouette for far off; far islands asleep and near ones awake; sailing
  the little patched boat from Castaway Cay to Hat Rock with no scene
  change (discovery, the current island, the landing as respawn point,
  uncharted waters in between) and straight in to Bell Atoll, Pinwheel
  Isle and Teacup Isle; no current holding a swimmer back and no limit on
  the boat; the mist round an island not built yet; the fog at the
  chart's edge turning the boat round; Bell Atoll's tide going straight
  back out when you sail off; free swimming in island waters, the open sea
  taking Patchy's breath (a heart down, back ashore) and no swimming to
  Driftwood Key; fast travel, Continue onto Hat Rock and the captain's
  cabin and back; the four sea hazards in their places, each turning the
  little boat back until its own upgrade carries her through (the storm
  even with every other upgrade fitted); Brock's guns firing on the boat
  and the bow cannon silencing one for good; buying upgrades at Gus's
  (gold, the order they come in, a faster and bigger-sailed boat) and
  changing her looks; and Gus opening his shipyard.
- **Hat Rock**: played through on the real island: up the boulders to the
  brim, the whole spiral ledge (jumping its gaps, bracing through the
  gusts), a gust blowing Patchy off when he doesn't brace, the buckle
  opening the lookout and starting the hoist, the Spyglass inside and
  sighting Bell Atoll with it (and using it at the tiller, where the boat
  drifts to a stop), the hoist ride back up, the grapple from the
  plank, three ring swings round the feather, the quill to the parrot, and
  the rosette's gem.
- **Bell Atoll**: the reef walked from the landing (a gap to jump, the spit
  and its step), a wrong note setting the gulls laughing, the whole song by
  hook with the tide coming in and going out again, the dais rising with
  the chest (a crown, the Shanty Sheet) and the parrot, the tide turning a
  slow song back (and Patchy swimming over the drowned reef), a cannonball
  from the islet ringing a bell, and the great bell's hint up in the
  belfry.
- **Pinwheel Isle**: riding the first lift up after a cannonball spins its
  wheel and stepping off onto the tier, the grapple yanking the second
  wheel round, a little spin running down and the platform sinking back,
  hopping off onto the gem nook, the summit's parrot, keeping the great
  wheel spinning all the way up to the crow's nest and its Heart Piece, and
  four pieces making a new heart container.
- **Teacup Isle**: up the sugar-cube steps and the spoon to the rim, the
  whirlpool carrying Patchy round and down the drain into the grotto, the
  grapple yanking a sugar plug out of a vent and the steam lifting him to
  the parrot's shelf, the teapot's shelf and its chest, and the cannon
  cracking the sugar wall to walk out under the handle.
- **Island**: Castaway Cay end to end:
  - the opening sequence;
  - key routes (beach to meadow jump, the ledge grab up the bluff, the
    village stairs, the rope bridge, the north beach stair, the wreck climb
    and the long jump to the sea stack);
  - Barnacle Bay and its folk, walking into the Soggy Biscuit and talking
    to Auntie Ink;
  - the dinghy quest: no boat at first, Gus's ask, climbing Tok's lookout
    tower landing by landing for the sail, diving for the tiller, and the
    dinghy fixed and moored at the pier;
  - the dark-cave refusal, the six-parrot log bridge and the chained chest;
  - the crab burrow, Old Shellby's dialogue and checkpoints;
  - the Barnacle Betty side quest (drag marks, the ramp and ledge grab up
    Gull Rock, the three-parrot lift, Shellby's chart and its X), Tok's
    parrot tips and Pip's clam;
  - sailing to Driftwood Key;
  - the crossing: ramming a barrel for coins, the dolphin escort and
    hopping out at Gull Bar;
  - the attachment chain: lantern, braziers, shovel, the treasure map's spot,
    grapple, pillar, cannon, cracked rock and targets;
  - a full King Claw fight, including the hand-off to his theme and back;
  - recovered ship parts appearing on the wreck, and the helm's sea chart;
  - Brock's cameo after King Claw, and Old Shellby rigging Betty's spare
    sail;
  - a crab lighting a TNT snail that blows open the grotto;
  - diving to the Sunken Sloop and opening its chest underwater;
  - the sloop's map of Beak Rock: the sketch matches the world, the X lies
    where the stone beak points, and digging there turns up a crown;
  - a check that no pickup is buried or floating.

## Content

**The archipelago.** Every island stands where it lies on one open sea,
distinct even a kilometer off (docs/ARCHIPELAGO.md):

- Hat Rock, a sea stack shaped like a pirate's hat.
- Skullcap Mountain, a skull wearing a jungle cap, with a waterfall
  spilling from one eye.
- Cinder Isle, a smoking volcano with glowing lava seams.
- Cannonball Cliffs, striped sandstone stacks under Brock's fort, its
  cannons puffing.
- Teacup Isle, a china-banded cup with a whirlpool inside.
- Stormpeak, a needle under a thundercloud full of lightning.
- Turtleback, a jungle island on a sleeping turtle that slowly breathes.
- Bell Atoll, a reef ring of swaying bells.
- Shipwreck Shoals, a thicket of masts.
- Crabby Coast, with its giant pincer arch.
- Lantern Lagoon, whose cave glows teal.
- Pinwheel Isle, with its spinning pinwheels.
- Crocodile Crown, Brock's fortress, a crowned crocodile's head far to the
  north-west.

The sea chart draws them all on the same bearings; undiscovered ones are
dashed outlines with a "?". The haze is long and light, so their shapes
read from Castaway Cay's summit, and a rain shower hides them.

The game boots to the title screen. **New Game** plays the opening: a
storm at sea, then Patchy wakes on the beach as crabs make off with his
gold.

**Castaway Cay** is the opening island, Patchy's Outset: a pirate fishing
village on an island cut in two by a sea channel.

- **Opening:** wake up on the cove's beach after the storm while crabs make
  off with your gold.
- **Wreck Beach:** Patchy's beached stern (the captain's cabin). Climb the
  deck, the cabin and the crow's nest (parrot), then long-jump to the sea
  stack (parrot).
- **Barnacle Bay**, the village round its harbor: the quay and the pier, a
  plaza with a well, market stalls and bunting, houses up two terraces,
  and the **Soggy Biscuit**, a tavern you can walk into, kept by Auntie
  Ink the octopus. Old Shellby fishes off his jetty, Marlo off the pier.
- **The old dinghy:** there's no boat at first. Gus the walrus shipwright
  will fix up his old dinghy if Patchy fetches its sail (up Tok's lookout
  tower, climbed landing by landing round the outside, with a parrot caged
  at the top) and its tiller (sunk in the harbor). Then it's Patchy's, at
  the end of the pier, and the whole sea is open.
- **Gus's shipyard:** talk to Gus again and he'll fit the boat out for
  gold: a racing rig (the fastest sail), a copper bottom, an iron hull and
  a bow cannon. Sail colors, flags and figureheads are free to change.
  The boat turns in a window as you shop, trying on whatever you point at.
- **The bluff and the rope bridge:** a ledge grab (or the stairs) up from
  the village, then a sagging rope bridge across the channel.
- **The forest:** round trees and palms, the summit (terraces or a
  wall-kick chimney) with the Ship's Compass and a parrot, and the dark
  cave Patchy won't enter without a light. Under the cliffs, the north
  beach and a long stair.
- **The headland:** across the gorge by the six-parrot log bridge, with a
  chained-chest ground-pound puzzle, Brock's crocs, a grapple tease and
  King Claw's ring.

**Driftwood Key** is a small islet one short sail away, with parrot 5 on a
driftwood tower, parrot 6 in a guarded crab pen, and the Storm Lantern.
Beside the tower stands Beak Rock, a stack of weathered stone that looks
for all the world like a parrot's head, peering down at the sand.

**The Sunken Sloop** (spec §114) lies on the seabed off the cove: a broken
hull, its bow and a tattered mast among coral, kelp and schools of reef
fish. A trail of coins leads down from the shallows to a chest in its
lee. Packed in with its goblet is a soggy map of an island that isn't
Castaway Cay (spec §194): a stone parrot, a dotted line from its beak and
an X. It's Beak Rock on Driftwood Key, sailed past on the way to the tower
parrot, and the crown is buried where the beak points. Dive with the dive or crouch button and rise with jump; chests and
chats work underwater too.

**Sailing the archipelago.** The islands are all on one sea. Point the
little boat at any island you can see and sail: no loading, no walls,
and the island comes up out of the sea as you near it, its name on a
banner as you reach its waters. Once Brock has rowed off, Old Shellby
rigs Betty's spare sail on the boat: bigger, red-striped and a good deal
faster. Swim out past an island's waters, though, and Patchy soon runs
out of breath: a ring by him empties, and he goes under and comes back
ashore a heart down. Islands still being built hide in a bank of sea mist that turns
the boat gently away, and out past the edge of the chart the fog turns
you round.

**Sea hazards.** Everything is open from the start but four late islands,
each ringed by something the little boat can't face yet, marked on the sea
chart with red dashes:

| Island | Hazard | Answered by (at Gus's) |
|---|---|---|
| Stormpeak | a wall of black storm cloud, rain and lightning | the Iron Hull |
| Cannonball Cliffs | Brock's gun towers, lobbing shot at you | the Bow Cannon (shoot back to silence them) |
| Cinder Isle | the boiling sea: scalding water, steam, lava rocks | the Copper Bottom |
| Crocodile Crown | three rings of coral with currents pouring out | the Racing Rig, then thread the maze |

Sail in without the right upgrade and the hazard turns you gently back out
and says what would do.

**Hat Rock**, the giant tricorne north of Castaway Cay, is the first port
of call. From the jetty, boulders lead up to the brim, and a ledge spirals
once round the crown to the top. Its gaps have to be jumped, and on its
bare stretches gusts off the open sea blow you over the edge: a pennant
lifts and the wind whistles first, so crouch and brace until they pass.
On top, pound the great gold buckle to open the lookout. Inside is the
**Spyglass**: hold its button on foot or at the tiller to zoom far out to
sea, and any island you hold in the glass is pencilled onto the sea chart,
shape and name, before you ever land there. The buckle also frees the
lookout's hoist, a basket that shuttles between the brim and the top, so a
fall never costs the whole climb. Off the back, walk the plank and grapple
the iron ring on the feather, swing ring to ring round its tufts to the
shoulder, and walk up the quill to a parrot at the crest. A gem waits on
the rosette pinned to one corner of the brim, reached by grapple from up
the brim's curl.

**Bell Atoll**, south-east of Castaway Cay, is a ring of reef rocks round
a turquoise lagoon. Five brass bells stand on the tall rocks, each with
its note painted on a plaque as a wave with that many crests. By the
belfry on the islet in the middle, a stone carves the sailor's song as a
row of those waves. Ring the bells in that order (swipe them, cannon them
or ground-pound beside them) and a dais rises from the lagoon with a chest
holding a crown and the **Shanty Sheet**, and a parrot. Play a wrong note
and the gulls loafing on the reef throw back their heads and laugh. The
first right note brings the tide in: within a minute the low reef and the
sand spit are under water, and if the song isn't finished by high tide
it's lost. Standing on the islet, the cannon reaches every bell. Grapple
up into the belfry and swipe the great bell: it plays the song through the
reef bells, lighting each one in turn.

**Pinwheel Isle**, north-west of Castaway Cay, is a mossy knob in steep
tiers bristling with pinwheels. Three of them drive screw lifts up the
cliffs between the tiers: stand on a lift's platform, blast its pinwheel
with the cannon or yank it round with the grapple, and the platform
corkscrews up the striped pole while the wheel spins, sinking back as it
runs down. One lift passes a nook in the cliff with a gem on it. A parrot
waits on the summit. The great pole there climbs to a crow's nest under
the biggest wheel of all, a long ride that needs the wheel kept spinning,
and in the nest is the first **Heart Piece**. Four make a new heart
container.

**Teacup Isle**, east of Castaway Cay, is a great china teacup on a sandy
saucer. Hop up a stack of sugar cubes and walk up the giant silver spoon
leaning on the cup to its grassy rim. Inside, the tea turns in a
whirlpool: jump in and the current carries Patchy round and round and down
the drain, into a grotto hollowed out of the cup's foot. Three steam vents
there are plugged with sugar cubes. Yank one out with the grapple and the
steam carries Patchy up to a shelf: one has a parrot, one a gem, and one
the chest with the **Golden Teapot**. The way out is a tunnel under the
handle, walled up with sugar cubes, which the cannon cracks. Another gem
sits on the crest of the handle.

**The crossing** between them is never empty water (spec §117). A bell
buoy clangs midway to steer by, and floating barrels burst into coins
when rammed. A coin trail rides the swell, and a pod of dolphins races
the boat, leaping in turn. Gull Bar, a sandbar islet just off the route,
hides a crate and a gem.

More on Castaway Cay:

- **The cave chamber:** lantern, then braziers, then the gate, behind
  which are the shovel and a treasure map. The map sketches the place
  where a relic is buried.
- **Treasure maps** (spec §86–87) are parchment sketches of landmarks (a
  stump under the ridge, a cairn on the north sand, a parrot made of
  stone) with a riddle, never a marker in the world. Unroll them under Pause > Treasure to zoom, turn
  and inspect them. Dig a few steps off and Patchy can tell something is
  buried close by.
- **The headland:** across the six-parrot log bridge, the chained chest
  holds the Grappling Claw. Its iron ring on the sea pillar leads to the
  Hand Cannon, which opens a cracked-rock grotto and a two-target vault.
- **King Claw** waits in a ring of spires on the headland. Pound his
  stuck claw, stomp his belly three times, and he leaves the Ship's Wheel.
  His fight has its own theme: the island's hook turned minor.
- **Brock the Croc** (spec §100) rows in under the headland on his royal
  barge once King Claw falls and the Ship's Wheel is Patchy's. The
  Admiral of the Archipelago, Baron of Bananas and Keeper of Everyone
  Else's Treasure gloats that the rest of the ship is scattered across
  "his" islands, then is rowed off by two put-upon crabs: the adventure
  continues.
- **Side quest, the Barnacle Betty:** Old Shellby stands on his jetty on
  the west beach, staring at the empty water. Crabs dragged his fishing
  boat up the beach; the drag marks lead to Gull Rock. Climb the crabs'
  plank ramp, grab the ledge to the top, and call three parrots to fly
  her home. Shellby pays with his old chart: a second treasure map.
- **Crackers** (spec §67), the first parrot Patchy frees, flies down to
  ride on his left shoulder from then on. He flaps for balance in the
  air, squawks a warning when something nearby winds up an attack, and
  cocks his head with a soft chirp at a secret close by. He is rarely
  heard and never in the way.
- **Islanders:** Tok, the outpost's lookout monkey, always knows where the
  next locked cage is. On Driftwood Key, Pip the otter wants her lucky
  clam back from the pelican.
- **The wreck comes back together** (spec §79): each recovered ship part
  appears on deck. The compass sits in its binnacle on the quarterdeck,
  and once the Ship's Wheel is back at the helm, Patchy can take it to
  open the sea chart and sail for any known dock.
- **The Captain's Cabin:** inside the wreck, the hub shows your gold,
  treasures, parrots, ship parts and attachments.
- Weather: every few minutes a tropical shower greys the sky, rains for
  a minute and roughens the sea, then the sun returns.
- Enemies: crabs (normal, armored, hermit, and cannon crabs that lob
  telegraphed shots), TNT snails, pelicans, and
  Brock's shield-bearing croc grunts on the headland.
- Emergent mischief (spec §173–174): a crab that blunders into a TNT
  snail lights its barrel and freezes in horror. The blast launches the
  crab and can crack open the grotto by accident.
