# The Archipelago

Island design for Patchy's sea: Super Mario Galaxy's compact toy-box
levels meet The Wind Waker's ocean. Every island is visible from the others
as a distinct silhouette on the horizon. Each one is built around a single
big gimmick, with its own puzzles, its own item or unlock, its own boss,
and things it lets you do back on islands you've already visited.

Gravity stays normal everywhere. The Galaxy influence is in structure, not
physics:

- Compact islands, each a hub with satellite islets.
- **Blast Barrels** (launch stars) fire Patchy between the islets.
- One clear gimmick per island.
- **Bounties** (stars): a short list of named goals per island.

Status:

- Castaway Cay (a big island in levels: Wreck Shore, the meadow and the
  waterfall, Barnacle Bay up its terraces, the bluff and the rope bridge,
  the woods and the giant tree, Mount Patch, the old fort across the
  gorge, the east downs and the sea arch; `CastawayLayout`), Driftwood Key
  and Gull Bar are playable. The opening plays the *Jolly Patch* sailing
  into the storm and going down; Esc skips it. Patchy's first boat is Gus's old dinghy, fixed up once
  he finds its sail and tiller.
- **One sea** (`world/sea/world.tscn`, `WorldDirector`): every island in a
  single world, joined by open water. Sail (or swim) from any island to any
  other: no invisible walls and no scene changes. Islands not built yet
  are wrapped in sea mist (`MistBank`); past the edge of the chart the fog
  turns a boat round (`SeaEdge`). See "The open sea" below
  (`tests/world_tests.gd`).
- Hat Rock is playable: the ledge, the gusts, the lookout, the Spyglass,
  the hoist and the feather (`tests/hat_rock_tests.gd`).
- Bell Atoll is playable: the bells, the song, the tide, the belfry and
  the dais (`tests/bell_atoll_tests.gd`).
- Pinwheel Isle is playable: the screw lifts, the nook, the summit and the
  crow's nest (`tests/pinwheel_isle_tests.gd`).
- Teacup Isle is playable: the spoon, the whirlpool, the grotto's vents and
  the way out under the handle (`tests/teacup_isle_tests.gd`).
- Every other island so far is a horizon silhouette (`world/horizon/`)
  placed by `Archipelago` (`world/horizon/archipelago.gd`).

Islands get built one at a time, each fully polished and tested before the
next.

## The sea at a glance

Bearings and distances are measured from Castaway Cay (world origin, north
is -Z). The silhouettes stand at these places, and the sea chart draws them
on the same bearings.

| Island | Bearing | Distance | Kind | Gimmick | Item / unlock | Ship part | Sea hazard round it |
|---|---|---|---|---|---|---|---|
| Castaway Cay | — | — | large | the whole moveset | hook, lantern, shovel, grapple, hand cannon | Compass, Ship's Wheel | — (start) |
| Driftwood Key | 227° | 340 m | small | raft tower, crab pen | — | — | — |
| Hat Rock | 345° | 480 m | tiny | a sea stack shaped like a pirate hat | **Spyglass** | — | — |
| Bell Atoll | 160° | 500 m | tiny | five bells and a song | **Shanty sheet** (song) | — | — |
| Pinwheel Isle | 300° | 500 m | tiny | giant pinwheels raise screw platforms | Heart Piece | — | — |
| Teacup Isle | 88° | 480 m | tiny | a whirlpool you ride down into | Golden Teapot | — | — |
| Crabby Coast | 215° | 640 m | large | **the tide**: ring a bell to flood or drain the island | **Spring Fist** | Anchor | — |
| Lantern Lagoon | 272° | 560 m | large | **light and dark**: beams, fireflies, glow-only bridges | **Harpoon** | Rudder | — |
| Shipwreck Shoals | 186° | 580 m | large | **bouncy sails** and a galleon you rotate | — | Sails | — |
| Turtleback | 132° | 560 m | medium | **the island is a turtle**: wake it and it swims | **Conch Shell** (call the turtle: fast travel) | — | —; Spring Fist to wake it |
| Skullcap Mountain | 10° | 650 m | large | **wind**: gusts, vanes, updrafts | **Parasol** (glide, ride updrafts) | Mast | — |
| Cannonball Cliffs | 70° | 580 m | large | **rhythm barrages**: cannons fire across every path | — | Cannon Deck | Brock's fort guns (Gus's **Bow Cannon** answers them) |
| Cinder Isle | 40° | 1000 m | large | **the lava tide** and steam vents | **Lodestone Magnet** | Iron Plating | the boiling sea (Gus's **Copper Bottom**) |
| Stormpeak | 104° | 1100 m | large | **lightning**: route it through rods; storm clouds you can stand on | — | Figurehead | the storm wall (Gus's **Iron Hull**) |
| Crocodile Crown | 316° | 1200 m | final | Brock's fortress | — | — | the reef maze (Gus's **Racing Rig** beats its currents); 50 parrots for the jaw gate |

Brock's barge rows off north-west after his cameo, the way his fortress
lies.

## Shared systems

- **Blast Barrels.** A powder keg on a swivel. Hop in and it swings to its
  target, then fires Patchy along a fixed arc marked by a coin trail. Land
  anywhere near the target and the camera keeps the landing in view. These
  are the launch stars: they make satellite islets, sky-high ledges and
  island-to-islet hops possible without new gravity.
- **Bounties.** Each island's dock has a bounty board listing five to
  seven named goals (Galaxy's stars). Examples: "Ring the Tide Bell",
  "Break the Crab Duke's Barricade", "The Pincer's Parrot". Each pays out
  in parrots, treasure, a map, an item or a ship part. They appear in the
  quest log and on the collection page.
- **Treasure maps link the islands.** Every island hides a map whose X
  lies on another island, as the Sunken Sloop's map leads to Beak Rock.
  You recognize the place from its silhouette on the horizon.
- **Backtracking payoffs.** Each new item opens something on islands
  you've already visited:
  - Spring Fist: barricades and clam buttons.
  - Harpoon: sunken caches, including at the Sunken Sloop.
  - Parasol: updrafts up to Castaway's sky ledges.
  - Magnet: iron crates and cables.
  - Spyglass: zooms on far islands and spots cages.
- **The open sea.** The whole archipelago is one world: every island in
  its true place on one ocean. Point the boat at any island you can see
  and sail there; nothing in between stops you.
  - Islands load as you near them and sleep when you're far off
    (`WorldDirector`), drawn as their silhouettes from afar. The
    silhouettes grow a little with distance (up to the "scale" in
    `Archipelago`) so a far island still reads, but never faster than
    the distance grows, so sailing in an island only looms larger.
  - Sailing into an island's waters (`SeaRegion`) announces it, makes it
    the current island and its landing the respawn point. In between are
    "Uncharted Waters".
  - The only limits are local and visible: hazards round four late
    islands (`SeaHazard`, Archipelago's "hazard"), each answered by one
    ship upgrade (the table's last column). Without it the hazard turns
    the boat gently back out and says what would do; with it she sails
    through, though it's rough going. They're drawn on the sea chart as a
    ring of red dashes. Everything else is open from the moment Patchy
    has a boat.
    - **The storm wall** (Stormpeak): black cloud piled high, curtains of
      rain, lightning and thunder. The Iron Hull rides it out.
    - **Brock's fort guns** (Cannonball Cliffs): six gun towers on rocks,
      swinging to follow the boat and lobbing near misses. With the Bow
      Cannon she sails in, and a hit silences a tower for good.
    - **The boiling sea** (Cinder Isle): scalding red water, boiling
      patches, steam and glowing lava rocks. The Copper Bottom takes the
      heat.
    - **The reef maze** (Crocodile Crown): three rings of coral, a gap or
      two in each, and currents pouring out. The Racing Rig beats the
      currents; then thread the gaps.
  - Islands not built yet hide in a bank of sea mist hugging their shore
    (`MistBank`) that turns the boat gently away. Far past the last island
    the fog at the edge of the chart turns a boat round (`SeaEdge`).
  - Swimming is free in an island's own waters. In the open sea Patchy's
    breath runs down (`SwimStamina`): six seconds, about 30 m, and he goes
    under, a heart down and back on the last safe ground. Even Driftwood
    Key, Castaway's nearest neighbor, is some 60 m of open sea away, so
    every island past the first is a boat ride.
- **Ship.** Patchy's ship (`ShipUpgrades`) has three things that matter
  at sea, and they belong to whichever boat he sails:
  - **Sail** (speed): Gus's patched sail, Betty's spare sail (Old
    Shellby's gift, ×1.3), then Gus's Racing Rig (×1.6, 160 gold).
  - **Hull** (toughness): Gus's Copper Bottom (120 gold), then his Iron
    Hull (220 gold), which also keeps her speed through knocks.
  - **Bow Cannon** (100 gold): fire it from the tiller.
  - **Looks**, free at the shipyard: six sail colors, five flags, five
    figureheads (or none).
  Gus sells the upgrades for gold at his shipyard (`UIShipyard`; talk to
  him once the dinghy's fixed), with the boat turning in a window and
  trying on whatever you point at. Each ship part appears on the wreck at
  Castaway Cay (spec §79). With the Anchor, Rudder and Sails back, the
  wreck floats as the *Jolly Patch* and replaces the tiny boat, upgrades
  and all.

## Story order

1. **Castaway Cay** (done). Patchy washes up with no boat; Gus the
   shipwright fixes up his old dinghy once Patchy finds its sail (up Tok's
   lookout tower) and its tiller (in the harbor), and from then on he can
   sail anywhere, and fits it out at his shipyard for gold. Ends with
   Brock's cameo. Old Shellby stitches Barnacle Betty's spare sail onto
   the tiny boat: the **spare sail**, a good deal faster. Every island without a hazard is open: the four tiny
   islands, Crabby Coast, Lantern Lagoon, Shipwreck Shoals, Turtleback and
   Skullcap Mountain, in any order.
2. **Ring one.** Anchor, Rudder and Sails return, and the *Jolly Patch*
   sails. The Spring Fist wakes Turtleback, which gives the Conch Shell.
3. **Ring two.** Skullcap Mountain (Mast, Parasol) and, past Brock's
   fort guns with a bow cannon, Cannonball Cliffs (Cannon Deck).
4. **Ring three.** Through the boiling sea with a copper bottom, Cinder
   Isle (Iron Plating, Magnet); through the storm wall with an iron hull,
   Stormpeak (Figurehead): the ship is whole.
5. **Crocodile Crown.** The racing rig beats the reef's currents; the
   full ship and 50 parrots raise the croc's jaw gate.

---

## Hat Rock — "A sea stack shaped exactly like a pirate's hat."

- **Horizon:** a black tricorne of rock with a white feather of chalk
  stone, sitting on the sea.
- **Toy:** a ledge spirals once round the crown from the brim to the flat
  top. Chalk tufts stick out of the feather, with hook rings between them.
- **Puzzles:**
  - Climb the spiral: jump its four gaps. On its three bare stretches,
    gusts off the open sea (`WindGust`) blow you over the edge. A pennant
    and a whistle warn first; crouch to brace until they pass.
  - Ground-pound the great gold buckle on the crown's top to open the
    lookout's door. It also frees the hoist (`LookoutHoist`), a basket
    between the brim and the top, so a fall doesn't cost the climb.
  - Walk the plank off the back and grapple the feather's iron ring, then
    swing ring to ring round the tufts to its shoulder and walk up the
    quill to the crest.
  - Up the curl of one corner of the brim, grapple the rosette pinned to
    its tip.
- **Reward:** the **Spyglass**, an old lookout's telescope. Hold its button
  (on foot or at the tiller) to zoom far out to sea and aim with the
  camera. Hold an island in the glass and it's pencilled onto the sea
  chart, shape and name, before you've landed (spec §194). Also a parrot
  at the feather's crest and a gem on the rosette.

## Bell Atoll — "A ring of reef where five bells play a sailor's song."

- **Horizon:** a ring of low rocks around a turquoise lagoon, with a
  little bell tower in the middle.
- **Toy:** five bells (`ReefBell`) on the five tall rocks of the reef ring,
  each a note of a pentatonic scale, its note painted on a plaque as a wave
  with that many crests. The song is carved on a stone by the belfry
  (`SongStone`) as a row of those waves.
- **Puzzles:**
  - Ring the bells in the carved order (`BellSong`) with the hook, the hand
    cannon or a ground pound. A wrong note makes the gulls (`ReefGull`)
    laugh and the song starts over.
  - The first right note brings the tide in (`Tide`, about a minute): the
    low reef between the bell rocks and the sand spit go under, so the
    last notes mean swimming. If the tide is in before the song is done,
    it's lost. From the islet the cannon reaches every bell.
  - Grapple up into the belfry: its great bell plays the song through the
    reef bells, lighting each in turn. A gem is up there, and another lies
    on the lagoon floor.
- **Reward:** a dais rises from the lagoon (`RisingDais`) with a chest (a
  Crown and the **Shanty Sheet**) and a parrot. The song opens the
  Skullcap's teeth (see below).

## Pinwheel Isle — "A tiny island bristling with giant spinning pinwheels."

- **Horizon:** a mossy knob in steep tiers crowded with striped pinwheels
  turning in the wind.
- **Toy:** each lift's pinwheel (`PinwheelLift`) drives a screw platform:
  while the wheel spins, the platform corkscrews up its striped pole; as
  the wheel runs down it sinks back.
- **Puzzles:**
  - Stand on a platform and spin the wheel above you: a cannonball, a yank
    of the grapple, or the hook where it reaches. Three lifts climb the
    tiers round the knob, each topping out at a landing deck.
  - Hop off the second lift as it passes a nook in the cliff for a gem.
  - The great pole on the summit is a long ride: keep its wheel spinning
    on the way up to the crow's nest under the biggest wheel.
  - Later, the Parasol rides the island's updraft to the top-most
    pinwheel's hub.
- **Reward:** a parrot on the summit, a gem, and a **Heart Piece** in the
  crow's nest (`HeartPiece`: four make a new heart container).

## Teacup Isle — "A round island with tea... a whirlpool... in the middle."

- **Horizon:** a great china teacup of white chalk banded with blue, on a
  sandy saucer, with a looping handle on one side. The tea turns inside.
- **Toy:** the whirlpool in the cup (`Whirlpool`). Swim in and the current
  carries Patchy round and in to the eye, which spins him down the drain
  into a grotto hollowed out of the cup's foot.
- **Puzzles:**
  - Climb the sugar-cube steps and walk up the giant spoon leaning on the
    cup to its rim, then jump into the tea.
  - In the grotto, three steam vents (`SteamVent`) are plugged with sugar
    cubes (`SugarPlug`). Yank them out with the grapple (or knock them loose
    with the cannon) and ride the steam up to the shelves above.
  - Blast the wall of sugar cubes across the tunnel and walk out under the
    handle arch.
  - A gem waits on the crest of the handle, another on a grotto shelf.
- **Reward:** the Golden Teapot treasure and a parrot. (Later, a map in the
  teapot's chest will lead to Crabby Coast.)

## Crabby Coast — "The coast where crabs built a kingdom, and you control the tide."

- **Horizon:** a long golden beach under red cliffs, a barricaded village,
  and the landmark: a colossal rock arch shaped like a crab's raised
  pincer.
- **Toy: the Tide Bell.** A huge bell in a tower on the point. Ring it and
  the whole island swaps between low and high tide over a few seconds.
  - Low tide drains the tide pools into paths, exposes crab burrows and
    sandbars to the satellite rocks, and grounds the boats.
  - High tide floods the burrows and floats crates, lily-pad clams and
    boats up into stairs.
- **Satellites:** Claw Rock, the pincer arch (a Blast Barrel from the
  point), and the sandbar islets reached at low tide.
- **Puzzles:**
  - Ring the tide to reach each part of the island. Some routes need both
    tides in turn.
  - The crab village is walled with crab-shell barricades: find the
    **Spring Fist** in the clam-diver's hut and punch them down.
  - Giant clam buttons need a Spring Fist punch to stay down.
  - Burrow Run: roll down the crab tunnels inside a hermit crab's old shell
    (a rolling-ball course).
  - Swing between the pincer's fingertips on hook rings to reach the
    parrot at the claw's tip.
- **Boss: Duke Pinchwick**, a pompous crab duke riding a hermit-shell
  tank. Change the tide mid-fight to beach him, then punch him over with
  the Spring Fist.
- **Rewards:** the Spring Fist; the Anchor (the crabs were using it as the
  Duke's throne); 7 parrots; a map to Lantern Lagoon.
- **Back home:** the Spring Fist breaks the barricaded crate cave on
  Castaway Cay.

## Lantern Lagoon — "A jungle ring hiding an enormous glowing lagoon."

- **Horizon:** a horseshoe of jungle cliffs around a lagoon, open to the
  sea through one gap. A great cave mouth in the back wall glows teal even
  by day.
- **Toy: light and dark.**
  - Glow-moss bridges are solid only while the lantern lights them.
  - Fireflies follow Patchy's lantern like a swarm.
  - Crystal prisms bend beams of sunlight.
- **Puzzles:**
  - Lead firefly swarms into dark alcoves to light their lamps.
  - Turn crystal prisms with the hook to carry the sunbeam from the
    lagoon mouth deep into the cave.
  - Cross glow-moss bridges in the lantern's light radius.
  - Under the lagoon, the **Harpoon**:
    - pull sunken gates open;
    - break coral walls;
    - latch onto a glowing manta ray and ride it through the current
      tunnels.
- **Boss: Grumbly the Anglerfish**, a big sleepy angler using the
  islanders' stolen lantern as its lure. Harpoon the lure to drag it up,
  then ground-pound its head when it surfaces.
- **Rewards:** the Harpoon; the Rudder; 7 parrots; a map to Hat Rock.
- **Back home:** the Harpoon opens the Sunken Sloop's locked hold off
  Castaway Cay.

## Shipwreck Shoals — "An island made of dozens of shipwrecks."

- **Horizon:** sandbars heaped with wrecks around a great galleon run
  aground. A thicket of masts carries tattered sails.
- **Toy: bouncy sails.**
  - Taut sails are trampolines.
  - Booms swing on the swell.
  - Masts are poles to climb and slide.
- **Satellites:** the wrecks, linked by rope lines, booms and Blast
  Barrels made from real powder kegs.
- **Puzzles:**
  - Cross the shoal sail to sail, timing the booms.
  - The galleon lies on its side. Its capstan turns the whole hull
    section, so floors become walls (Galaxy's rotating rooms on normal
    gravity).
  - Spring Fist the jammed capstan; harpoon an anchor chain to raise a
    sunken hull into a bridge.
- **Mini-boss: the Salvage Diver**, a croc in a brass diving suit fed by an
  air hose from Brock's barge. Hook the hose to yank him around.
- **Rewards:** the Sails; 6 parrots; a map to Teacup Isle.

## Turtleback — "The island is a giant sea turtle, fast asleep."

- **Horizon:** a domed jungle island on an olive shell with tan plates.
  The turtle's head rests on the waves with its eyes shut. It slowly rises
  and falls as it breathes.
- **Toy: the island moves.**
  - Asleep, it's a small jungle island with three shell gongs.
  - Punch all three gongs with the Spring Fist and Turtleback wakes, then
    swims a slow loop round the inner sea with Patchy aboard.
  - While it swims, the horizon wheels past and loose things slide when it
    banks.
- **Puzzles:**
  - Find the gongs (one is under the jungle, one is on a flipper at low
    swell, one is on the head).
  - Ride to the Shell Peak while it swims; a parrot cage only comes within
    reach on one stretch of its loop.
  - Feed it the giant kelp from Lantern Lagoon to make it dive and surface
    by a secret reef.
- **Rewards:** the **Conch Shell**: blow it at any known dock and
  Turtleback comes to ferry you to another (fast travel, spec §118).
  5 parrots.

## Skullcap Mountain — "A mountain that looks like a skull wearing a jungle cap."

- **Horizon:** a mossy massif whose pale summit is a skull. It has cave
  eyes, a grin of rock teeth in the surf, a waterfall from one eye and a
  jungle cap.
- **Toy: wind.**
  - Strong gusts sweep the cliffs. Wind vanes show which way they blow.
  - Turning a vane with the hook turns the gust.
  - Updrafts rise from the waterfall's spray.
- **Puzzles:**
  - Climb the face with the gusts behind you, then turn the vanes for the
    next stretch.
  - Get behind the waterfall to the eye caves. Each eye is a lookout over
    the sea and a way into the skull.
  - Find the **Parasol** in the left eye. Ride updrafts and glide down
    the wind tunnels.
  - Play Bell Atoll's shanty on the skull's teeth (stalactites like a
    xylophone) to open the jaw.
- **Boss: Commodore Gullet**, a giant pelican nesting on the skull's crown
  with the Mast as his perch. He dive-bombs in the wind. Glide above him
  and ground-pound his nest.
- **Rewards:** the Parasol; the Mast; 7 parrots.

## Cannonball Cliffs — "The island where cannons fire across every path."

- **Horizon:** sheer stacks of banded sandstone, with Brock's purple and
  gold fort on the tallest. A rope bridge sags between stacks, and cannon
  puffs go off every few seconds.
- **Toy: rhythm barrages.**
  - The fort's batteries fire in patterns along the cliff paths. Fuse
    sparks show which gun is next.
  - Duck behind the merlons, or hop slow mortar shells as moving
    platforms.
- **Puzzles:**
  - Climb the stacks between barrages.
  - Use Blast Barrels to cross between stacks.
  - Swing the fort's own guns round with the hook and blast its gates open.
  - Cross the rope bridge before it burns through.
- **Boss: General Snapjaw**, a croc general in a walking cannon tower.
  Spring Fist his cannonballs back at him.
- **Rewards:** the Cannon Deck. The *Jolly Patch* can now blast
  Brock's sea barricades and boulders. 6 parrots.

## Cinder Isle — "A volcano Brock is strip-mining."

- **Horizon:** a dark cone with glowing lava seams and a smoke plume, with
  the chimneys of a mining outpost at its foot.
- **Toy: the lava tide.**
  - Lava in the caldera rises and falls on a slow beat. Basalt columns
    stand clear at low lava.
  - Steam vents launch Patchy high, like Galaxy's springs.
- **Puzzles:**
  - Ride the mine carts and switch their rails.
  - Use the **Lodestone Magnet** to pull iron crates into vents, ride
    iron cable cars, and disarm Brock's drilling machines.
  - Cross the caldera between lava beats.
- **Boss: Foreman Grit**, a croc foreman in a drilling rig that bores up
  through the floor.
- **Rewards:** the Lodestone Magnet; the Iron Plating; 7 parrots.

## Stormpeak — "A needle of rock lost in a storm that never ends."

- **Horizon:** a tall spire under a permanent dark thundercloud, with
  lightning flashing inside it.
- **Toy: lightning.**
  - Bolts strike the highest metal around. Copper rods and chains
    (Magnet) carry the charge to doors, lifts and the lighthouse lamp.
  - Thunderclouds drift on fixed paths and you can stand on them, Galaxy
    style.
  - Rain makes ledges slick.
- **Puzzles:**
  - Route lightning to power the lighthouse lift.
  - Ride the drifting clouds up the spire.
  - Glide the wind with the Parasol.
- **Boss: the Storm Kite**, Brock's weather machine. A giant kite lures
  the lightning. Cut its lines one by one.
- **Rewards:** the Figurehead (a golden parrot). The ship is whole.
  6 parrots.

## Crocodile Crown — "Brock's fortress: a crocodile's head wearing a crown."

- **Horizon:** a dark rock shaped like a crocodile's head, its snout
  toward the sea, crowned with towers and purple-and-gold flags.
- **Gate:** the reef maze round it (the Racing Rig beats its currents),
  then the finished ship and 50 parrots to raise the jaw gate.
- **Inside:**
  - the docks;
  - the prison (the last caged parrots);
  - the treasury (Patchy's treasure, piled high);
  - mechanical defenses;
  - a final climb up the snout to the crown.
- **Boss: Brock the Croc.** First a sea battle against his flagship with
  the ship's cannons, then the throne room.

---

## Building order and technical plan

Each island gets the full Castaway Cay treatment before the next one
starts: a builder script, tests for its routes, puzzles and boss, renders
for review, and the README.

1. **Horizon pass** (now): every island's silhouette on every horizon,
   the sea chart on the same bearings, and fog long enough to see them.
2. **One sea** (done). Every island in one world (`world/sea/world.tscn`,
   `tools/builders/build_world.gd`), each built island a chunk at its
   world coordinates (`IslandBuilder`), far ones asleep behind their
   silhouettes (`WorldDirector`). Sailing between islands is just
   sailing. The helm's chart and the Conch Shell fast-travel within it.
3. **The spare sail** (done), **Hat Rock** and the Spyglass (done),
   **Bell Atoll** and the Shanty Sheet (done), **Pinwheel Isle** and the
   first Heart Piece (done), **Teacup Isle** and the Golden Teapot (done),
   then **Crabby Coast**:
   Blast Barrels, the Tide Bell, the Spring Fist and Duke Pinchwick.
4. Lantern Lagoon, Shipwreck Shoals, Turtleback, then the *Jolly Patch*.
5. Skullcap Mountain, Cannonball Cliffs, Cinder Isle, Stormpeak, Crocodile
   Crown.
