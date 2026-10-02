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

## Running

```bash
godot --path .                          # title screen -> New Game / Continue
godot --path . res://world/islands/castaway_cay/castaway_cay.tscn   # jump straight in
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
| Boat | Board Patchy's dinghy with E and steer with the stick. Jump hops out near shore. Once an island is discovered, the pause-menu sea chart offers "Sail to ..." fast travel. |

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
npcs/               Parrots; islanders (NPC base, FavorNPC quest givers, LookoutNPC)
                    and their models (turtle, monkey, otter, Brock the Croc)
collectibles/       Coins, gems, treasure kinds, coin trails
world/              Terrain (Plateau); ocean (stylized Ocean, underwater effect,
                    sea regions, open-sea current); sea/ (bell buoy, floating
                    barrels, dolphins, fish schools); islands (Castaway Cay and
                    Driftwood Key, IslandInfo, IslandZone); hub (captain's
                    cabin); vehicles (TinyBoat); objects (cages, parrot tasks,
                    chests, dig spots, braziers, gates, targets, cracked rock,
                    doors, Shellby's fishing boat, drag marks...)
props/              Art kit: palms, rocks, foliage scatter, coral, kelp, crates and barrels,
                    docks, rope bridges, wreck pieces, signs, torches; plus
                    level blocks
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
  rebinding, title screen and debug menu.
  - Gameplay talks to it mostly through `Events` signals.
  - `QuestLog` derives the quest page from progress.
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
- **Islands**: a scene with an `IslandInfo` node. It registers parrot and
  treasure totals, places Patchy (saved checkpoint, arrival point or
  default spawn), then announces the island and starts its music after
  any opening sequence.
  - Smaller islands in the same scene use `IslandZone`.
  - `SeaRegion` circles define swimmable water. Beyond them, `OpenSea`
    pushes swimmers back, so the boat is needed.
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
tools/builders/build.sh movement_lab camera_lab castaway_cay captains_cabin

# Render screenshots on a headless machine (xvfb + Vulkan). flags= marks
# WorldState ids, progress=demo fakes mid-game progress, hud=0 hides the HUD:
tools/photo/shoot.sh scene=res://world/islands/castaway_cay/castaway_cay.tscn \
    flags=castaway_intro_seen out=/tmp/shot_%d.png "cams=0,120,160>0,0,0;30,10,62>50,3,42"

# UI states (pause pages, a treasure map unrolled at zoom 1.5):
tools/photo/shoot.sh scene=res://ui/tests/ui_preview.tscn size=1600x900 state=treasure_map map=castaway_map_2 zoom=1.5

# The islanders (and Patchy for scale) lined up for a close look:
tools/photo/shoot.sh scene=res://tests/npc_gallery.tscn hud=0 "cams=-0.6,1.3,3.6>-0.6,0.65,0"

# Regenerate the original sound effects and music:
python3 tools/audio/generate_audio.py

# CPU cost of a level (logic + physics, headless). Castaway Cay: about 2 ms
# per frame and a 1.6 s load:
godot --headless --path . --fixed-fps 60 res://tools/perf_probe.tscn -- scene=res://world/hub/captains_cabin.tscn
```

## Tests

Every suite runs headless at a fixed 60 fps and exits non-zero on failure.
An optional argument after `--` filters test names.

```bash
godot --headless --path . --fixed-fps 60 res://tests/run_movement_tests.tscn   # 53 checks
godot --headless --path . --fixed-fps 60 res://tests/run_camera_tests.tscn     # 21 checks
godot --headless --path . --fixed-fps 60 res://tests/run_gameplay_tests.tscn   # 68 checks
godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn     # 143 checks
godot --headless --path . --fixed-fps 60 res://ui/tests/ui_flow_test.tscn      # 84 checks
godot --headless --path . --fixed-fps 60 res://props/tests/prop_tests.tscn     # 70 checks
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
- **Island**: Castaway Cay end to end:
  - the opening sequence;
  - key routes (beach to meadow jump, the ledge-grab ridge, the wreck climb
    and the long jump to the sea stack);
  - the dark-cave refusal, the six-parrot log bridge and the chained chest;
  - the crab burrow, Old Shellby's dialogue and checkpoints;
  - the Barnacle Betty side quest (drag marks, the ramp and ledge grab up
    Gull Rock, the three-parrot lift, Shellby's chart and its X), Tok's
    parrot tips and Pip's clam;
  - sailing to Driftwood Key and the open-sea current;
  - the crossing: ramming a barrel for coins, the dolphin escort and
    hopping out at Gull Bar;
  - the attachment chain: lantern, braziers, shovel, the treasure map's spot,
    grapple, pillar, cannon, cracked rock and targets;
  - a full King Claw fight, including the hand-off to his theme and back;
  - recovered ship parts appearing on the wreck, and the helm's sea chart;
  - Brock's cameo after King Claw;
  - a crab lighting a TNT snail that blows open the grotto;
  - diving to the Sunken Sloop and opening its chest underwater;
  - a check that no pickup is buried or floating.

## Content

The game boots to the title screen. **New Game** plays the opening: a
storm at sea, then Patchy wakes on the beach as crabs make off with his
gold.

**Castaway Cay** is the opening island, a sunny cove strewn with wreckage:

- **Opening:** wake up on the beach while crabs make off with your gold.
- **Shipwreck:** climb the stern deck, the cabin and the crow's nest
  (parrot), then long-jump to the sea stack (parrot).
- **Outpost:** Tok the lookout monkey and a crab-guarded watchtower
  (parrot).
- **Ridge and hill:** a ledge-grab ridge, terraces and a wall-kick chimney
  to the summit, with the Ship's Compass and a parrot.
- **Dark cave:** Patchy refuses to go in without a light.
- **Headland:** across the six-parrot log bridge, with a chained-chest
  ground-pound puzzle and a grapple tease.
- **The dock:** Patchy's tiny boat.

**Driftwood Key** is a small islet one short sail away, with parrot 5 on a
driftwood tower, parrot 6 in a guarded crab pen, and the Storm Lantern.

**The Sunken Sloop** (spec §114) lies on the seabed off the cove: a broken
hull, its bow and a tattered mast among coral, kelp and schools of reef
fish. A trail of coins leads down from the shallows to a chest in its
lee. Dive with the dive or crouch button and rise with jump; chests and
chats work underwater too.

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
  stump under the ridge, a cairn on the north sand) with a riddle, never
  a marker in the world. Unroll them under Pause > Treasure to zoom, turn
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
