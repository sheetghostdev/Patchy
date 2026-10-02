class_name Layers
## Physics layer constants. Keep in sync with [layer_names] in project.godot
## and the table in README.md. Use these instead of raw bit numbers.

const WORLD := 1 << 0          ## 1  Static level geometry. Camera collides with this.
const PLAYER := 1 << 1         ## 2  Patchy's body.
const ENEMY := 1 << 2          ## 3  Enemy bodies and enemy hurtboxes.
const NPC := 1 << 3            ## 4  Friendly characters.
const INTERACTABLE := 1 << 4   ## 5  Things with can_interact()/interact().
const PROJECTILE := 1 << 5     ## 6  Cannonballs, bombs, thrown things.
const WATER := 1 << 6          ## 7  Swimmable water volumes.
const GRAPPLE_POINT := 1 << 7  ## 8  Hook rings, grapple anchors, zipline ends.
const TRIGGER := 1 << 8        ## 9  Checkpoints, camera zones, kill volumes, story triggers.
const COLLECTIBLE := 1 << 9    ## 10 Coins, gems, hearts.
const PROPS := 1 << 10         ## 11 Dynamic physics props (crates, barrels). Camera ignores.
const PLAYER_ATTACK := 1 << 11 ## 12 Patchy's attack hitboxes (swipe, dive, ground pound).
const ENEMY_ATTACK := 1 << 12  ## 13 Enemy hitboxes that damage Patchy.

## What Patchy's body collides with.
const PLAYER_BODY_MASK := WORLD | NPC | PROPS
## What the camera's collision probe treats as an obstruction.
const CAMERA_MASK := WORLD
## Things the player's ledge/wall probes may grab.
const GRABBABLE_MASK := WORLD
