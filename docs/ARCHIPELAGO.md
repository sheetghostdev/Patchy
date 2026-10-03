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

- Castaway Cay, Driftwood Key and Gull Bar are playable.
- Sailing between island scenes works (`Voyage`).
- Hat Rock is playable: the ledge, the gusts, the lookout, the Spyglass,
  the hoist and the feather (`tests/hat_rock_tests.gd`).
- Every other island so far is a horizon silhouette (`world/horizon/`)
  placed by `Archipelago` (`world/horizon/archipelago.gd`).

Islands get built one at a time, each fully polished and tested before the
next.

## The sea at a glance

Bearings and distances are measured from Castaway Cay (world origin, north
is -Z). The silhouettes stand at these places, and the sea chart draws them
on the same bearings.

| Island | Bearing | Distance | Kind | Gimmick | Item / unlock | Ship part | Gate to reach it |
|---|---|---|---|---|---|---|---|
| Castaway Cay | — | — | large | the whole moveset | hook, lantern, shovel, grapple, hand cannon | Compass, Ship's Wheel | start |
| Driftwood Key | 223° | 190 m | small | raft tower, crab pen | — | — | tiny boat |
| Hat Rock | 345° | 480 m | tiny | a sea stack shaped like a pirate hat | **Spyglass** | — | spare sail |
| Bell Atoll | 160° | 500 m | tiny | five bells and a song | **Shanty sheet** (song) | — | spare sail |
| Pinwheel Isle | 300° | 500 m | tiny | giant pinwheels raise screw platforms | Heart Piece | — | spare sail |
| Teacup Isle | 88° | 480 m | tiny | a whirlpool you ride down into | Golden Teapot | — | spare sail |
| Crabby Coast | 215° | 640 m | large | **the tide**: ring a bell to flood or drain the island | **Spring Fist** | Anchor | spare sail |
| Lantern Lagoon | 272° | 560 m | large | **light and dark**: beams, fireflies, glow-only bridges | **Harpoon** | Rudder | spare sail |
| Shipwreck Shoals | 186° | 580 m | large | **bouncy sails** and a galleon you rotate | — | Sails | spare sail |
| Turtleback | 132° | 560 m | medium | **the island is a turtle**: wake it and it swims | **Conch Shell** (call the turtle: fast travel) | — | spare sail; Spring Fist to wake it |
| Skullcap Mountain | 10° | 650 m | large | **wind**: gusts, vanes, updrafts | **Parasol** (glide, ride updrafts) | Mast | the restored ship (the tiny boat can't beat the headwind) |
| Cannonball Cliffs | 70° | 580 m | large | **rhythm barrages**: cannons fire across every path | — | Ship's Cannons | the restored ship (its guns sink rowboats) |
| Cinder Isle | 40° | 1000 m | large | **the lava tide** and steam vents | **Lodestone Magnet** | Iron Hull | Ship's Cannons (blast the chain boom) |
| Stormpeak | 104° | 1100 m | large | **lightning**: route it through rods; storm clouds you can stand on | — | Figurehead | Iron Hull (survive the storm wall) |
| Crocodile Crown | 316° | 1200 m | final | Brock's fortress | — | — | the full ship and 50 parrots |

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
- **Sailing range.** Each gate is something you can see:
  - A headwind pushes the tiny boat back.
  - Cannon splashes rock the boat.
  - A chain boom bars a harbor.
  - A storm wall surrounds Stormpeak.
- **Ship.** Each ship part appears on the wreck at Castaway Cay (spec
  §79). With the Anchor, Rudder and Sails back, the wreck floats as the
  *Jolly Patch* and replaces the tiny boat for open-sea sailing.

## Story order

1. **Castaway Cay** (done). Ends with Brock's cameo. Old Shellby stitches
   Barnacle Betty's spare sail onto the tiny boat: the **spare sail**.
   Ring one opens: the four tiny islands, Crabby Coast, Lantern Lagoon,
   Shipwreck Shoals and Turtleback, in any order.
2. **Ring one.** Anchor, Rudder and Sails return, and the *Jolly Patch*
   sails. The Spring Fist wakes Turtleback, which gives the Conch Shell.
3. **Ring two.** Skullcap Mountain (Mast, Parasol) and Cannonball Cliffs
   (Ship's Cannons).
4. **Ring three.** Cinder Isle (Iron Hull, Magnet), then Stormpeak
   (Figurehead): the ship is whole.
5. **Crocodile Crown.** The full ship and 50 parrots raise the croc's jaw
   gate.

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
- **Toy:** five bells on posts around the ring, each a different note.
  The song is carved on the tower, as notes shaped like waves.
- **Puzzles:**
  - Ring the bells in the carved order by hitting them with the hook, the
    hand cannon or a ground pound. A wrong note makes the gulls laugh.
  - Rising water between the reef rocks means hopping on the bells' posts.
- **Reward:** a chest rises from the lagoon with a Crown, a parrot and the
  **Shanty sheet**. The song opens the Skullcap's teeth (see below).

## Pinwheel Isle — "A tiny island bristling with giant spinning pinwheels."

- **Horizon:** a rocky knob crowded with tall striped pinwheels turning in
  the wind.
- **Toy:** each pinwheel drives a screw platform: while it spins, the
  platform corkscrews up its post.
- **Puzzles:**
  - Get pinwheels spinning by pulling them round with the hook or blasting
    them with the cannon.
  - Ride the screws to higher pinwheels.
  - Later, the Parasol rides the island's updraft to the top-most
    pinwheel's hub.
- **Reward:** a parrot, a gem, and a **Heart Piece** (four make a new heart
  container).

## Teacup Isle — "A round island with tea... a whirlpool... in the middle."

- **Horizon:** a round cliff-walled islet with a handle-shaped rock arch
  on one side. Spray rises from the swirl inside.
- **Toy:** the whirlpool in the cup. Jump in and it spins Patchy down
  into a sunken grotto.
- **Puzzles:**
  - Time your jump to the whirlpool's current.
  - In the grotto, harpoon the sugar-cube boulders out of the vents.
  - Climb out through the handle arch.
- **Reward:** the Golden Teapot treasure and a parrot. Its map leads to
  Crabby Coast.

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
- **Rewards:** the Ship's Cannons. The *Jolly Patch* can now blast
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
- **Rewards:** the Lodestone Magnet; the Iron Hull; 7 parrots.

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
- **Gate:** reefs, currents and cannons. The finished ship and 50 parrots
  are needed to raise the jaw gate.
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
2. **Sailing between scenes** (done). Each island is its own scene at its
   world coordinates (`IslandBuilder` scaffolds them), showing the others
   on its horizon.
   - Sailing out of an island's waters toward another starts a short
     sailing transition (a fade under a sea shanty) into the next scene,
     with the boat arriving on the same heading. This is the masked
     loading of spec §180.
   - The helm and the Conch Shell use the same transition.
3. **The spare sail** (done), **Hat Rock** and the Spyglass (done), then
   the other tiny islands, then **Crabby Coast**:
   Blast Barrels, the Tide Bell, the Spring Fist and Duke Pinchwick.
4. Lantern Lagoon, Shipwreck Shoals, Turtleback, then the *Jolly Patch*.
5. Skullcap Mountain, Cannonball Cliffs, Cinder Isle, Stormpeak, Crocodile
   Crown.
