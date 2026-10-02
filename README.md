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
| Pirate Spade | The dark cave | Digs up sparkling mounds and a treasure map's X; scoops crabs over. |
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
npcs/               Parrots, NPCs (Old Shellby)
collectibles/       Coins, gems, treasure kinds, coin trails
world/              Terrain (Plateau); ocean (stylized Ocean, underwater effect,
                    sea regions, open-sea current); islands (Castaway Cay and
                    Driftwood Key, IslandInfo, IslandZone); hub (captain's
                    cabin); vehicles (TinyBoat); objects (cages, parrot tasks,
                    chests, dig spots, braziers, gates, targets, cracked rock,
                    doors...)
props/              Art kit: palms, rocks, foliage scatter, crates and barrels,
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
godot --headless --path . --fixed-fps 60 res://tests/run_gameplay_tests.tscn   # 64 checks
godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn     # 100 checks
godot --headless --path . --fixed-fps 60 res://ui/tests/ui_flow_test.tscn      # 76 checks
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
  - the cabin hub's displays.
- **Island**: Castaway Cay end to end:
  - the opening sequence;
  - key routes (beach to meadow jump, the ledge-grab ridge, the wreck climb
    and the long jump to the sea stack);
  - the dark-cave refusal, the six-parrot log bridge and the chained chest;
  - the crab burrow, Old Shellby's dialogue and checkpoints;
  - sailing to Driftwood Key and the open-sea current;
  - the attachment chain: lantern, braziers, shovel, treasure map and X,
    grapple, pillar, cannon, cracked rock and targets;
  - a full King Claw fight, including the hand-off to his theme and back;
  - a check that no pickup is buried or floating.

## Content

The game boots to the title screen. **New Game** plays the opening: a
storm at sea, then Patchy wakes on the beach as crabs make off with his
gold.

**Castaway Cay** is the opening island, a sunny cove strewn with wreckage:

- **Opening:** wake up on the beach while crabs make off with your gold.
- **Shipwreck:** climb the stern deck, the cabin and the crow's nest
  (parrot), then long-jump to the sea stack (parrot).
- **Outpost:** Old Shellby and a crab-guarded watchtower (parrot).
- **Ridge and hill:** a ledge-grab ridge, terraces and a wall-kick chimney
  to the summit, with the Ship's Compass and a parrot.
- **Dark cave:** Patchy refuses to go in without a light.
- **Headland:** across the six-parrot log bridge, with a chained-chest
  ground-pound puzzle and a grapple tease.
- **The dock:** Patchy's tiny boat.

**Driftwood Key** is a small islet one short sail away, with parrot 5 on a
driftwood tower, parrot 6 in a guarded crab pen, and the Storm Lantern.

More on Castaway Cay:

- **The cave chamber:** lantern, then braziers, then the gate, behind
  which are the shovel and a treasure map. Its X marks a relic on the
  meadow.
- **The headland:** across the six-parrot log bridge, the chained chest
  holds the Grappling Claw. Its iron ring on the sea pillar leads to the
  Hand Cannon, which opens a cracked-rock grotto and a two-target vault.
- **King Claw** waits in a ring of spires on the headland. Pound his
  stuck claw, stomp his belly three times, and he leaves the Ship's Wheel.
  His fight has its own theme: the island's hook turned minor.
- **The Captain's Cabin:** inside the wreck, the hub shows your gold,
  treasures, parrots, ship parts and attachments.
- Weather: every few minutes a tropical shower greys the sky, rains for
  a minute and roughens the sea, then the sun returns.
- Enemies: crabs (normal, armored, hermit, and cannon crabs that lob
  telegraphed shots), TNT snails, pelicans, and
  Brock's shield-bearing croc grunts on the headland.
