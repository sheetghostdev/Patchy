# PATCHY audio

Every sound effect and music cue in this folder is synthesized from scratch by
`tools/audio/generate_audio.py`: oscillators, filtered noise, FM, modal
(struck-object) synthesis, Karplus-Strong plucks and a synthetic reverb. There
are no samples and no borrowed melodies. Don't hand-edit the generated files.
Change the script and regenerate instead.

## Regenerating

```bash
pip install numpy scipy soundfile          # one time (soundfile bundles libsndfile + Vorbis)
python3 tools/audio/generate_audio.py      # everything, ~30 s
python3 tools/audio/generate_audio.py --only coin    # just names containing "coin"
python3 tools/audio/generate_audio.py --no-music     # SFX only (or --no-sfx)
```

* Run it from the project root. It overwrites `audio/sfx`, `audio/music` and
  `audio/audio_manifest.json`. A partial run (`--only`, `--no-*`) keeps the
  other manifest entries.
* It is deterministic. Each sound's random seed comes from its name (and
  `MASTER_SEED`), so WAVs are bit-identical between runs and the music renders
  identically. Ogg files can still differ in a few header bytes, because the
  Ogg stream serial number is random.
* At the end it re-reads every file and prints a table with duration, channels,
  peak/RMS dBFS, onset time and loop-seam ratio. It exits non-zero if a check
  fails.

## Formats and levels

| Folder   | Format                                    | Level |
|----------|-------------------------------------------|-------|
| `sfx/`   | WAV, mono, 44.1 kHz, 16-bit PCM            | Most SFX peak at -1 dBFS. Footsteps, `crab_step` and `ui_move` peak at -3 dBFS, and `sparkle_loop`/`firefly_buzz_loop` at -6 dBFS. |
| `music/` | Ogg Vorbis (q 0.5), stereo, 44.1 kHz       | The explore and combat layers are scaled together, so their sum peaks at -1 dBFS. `cave_explore` sits about 3 dB below explore, `title_theme` about 1 dB above it, and stingers peak at -1 dBFS. |

One-shot SFX have their leading silence trimmed, so they become audible
within 5 ms of sample 0 (most within 1 ms; the slowest, `wood_creak`, at about
3 ms). They have 1-2 ms fade-ins, fade-outs at the tail, no DC
offset (20 Hz high-pass) and no clipping (soft-clip, then normalize).
`volume_db` in the manifest is a suggested starting mix level for an
`AudioStreamPlayer` (footsteps around -9 dB, explosions 0 dB).

## Manifest (`audio_manifest.json`)

* `sfx.<name>`: `file`, `duration`, `loop`, `bus` (`SFX`, `Ambience` or
  `UI`), `volume_db`.
* `music.<name>`: `file`, `duration`, `loop`, `bpm`, `bars`, an optional
  `layer_of`, plus `time_signature` and the exact `samples` count.
* `groups.<family>`: lists of numbered variations (`footstep_sand`,
  `footstep_grass`, `footstep_wood`, `footstep_stone`, `swim_stroke`,
  `shovel_dig`, `coin`, `parrot_chirp`, `seagull`). Pick one at random each
  time, for example with `AudioStreamRandomizer`.

## Loops

Loop files repeat seamlessly from sample 0 to the end, with no loop offset.

* **SFX loops** (`slide_loop`, `underwater_loop`, `grapple_reel_loop`,
  `firefly_buzz_loop`, `sparkle_loop`, `snail_fuse_loop`, `ocean_waves_loop`,
  `wind_loop`) are exactly periodic by construction. Their noise is generated
  and filtered in the frequency domain, so it is circular. Their modulators and
  tones complete whole cycles over the loop. Event layers (clicks, glints,
  bubbles) are rendered with their tails wrapped around to the start. In Godot,
  set the WAV import *Loop Mode* to **Forward**.
* **Music loops** (`castaway_explore`, `castaway_combat_layer`,
  `cave_explore`, `title_theme`) are rendered with notes and reverb ringing
  past the last bar. That overhang is then folded back onto the first bars, so
  the loop point is exactly what endless repetition sounds like. Enable
  `loop` on the imported `AudioStreamOggVorbis`. Because the head already holds
  the folded tail, the first sample isn't zero, so start loops with a short
  (around 50 ms) fade-in.
* The verification table reports a seam ratio for each loop: the jump across
  the wrap point relative to normal sample-to-sample steps. Every loop is below
  1, meaning the wrap is as smooth as any point inside the file.

## Music

Every cue is original and in G major, with a calypso / sea-shanty feel. The
synthesized band is a musette accordion (detuned reeds, bellows swell, delayed
vibrato), a Karplus-Strong ukulele using real re-entrant G-C-E-A voicings,
steel pan, marimba, vibes, pizzicato bass, additive brass, pads, and hand
percussion (shaker, woodblock, congas, clave, toms, tambourine, soft kick).

| Cue | Tempo / length | Notes |
|-----|----------------|-------|
| `castaway_explore` | 108 BPM, 4/4, 32 bars, 71.11 s, loop | Sections A (accordion hook), A' (adds marimba arpeggios and congas), B (steel-pan tune, bellows chords, son clave), A'' (pan harmony, turnaround into bar 1). |
| `castaway_combat_layer` | Identical length (3,136,000 samples) | Drums, toms, claps, tambourine and an octave-pumping drive bass, about 4 dB under the main mix. `layer_of: castaway_explore`. Start both on the same frame, for example with `AudioStreamSynchronized` (Godot 4.3+) or two players started together, then fade the layer's volume in and out. |
| `cave_explore` | 84 BPM, 16 bars, 45.71 s, loop | Sparse, Lydian-tinted take on the hook: vibes with echo, soft pads, harp arpeggios, cave drips. |
| `title_theme` | 112 BPM, 12 bars, 25.71 s, loop | Full-band, rousing statement of the theme with brass stabs. |
| `stinger_discovery` | 3.0 s | Harp sweep, a miniature of the hook, big G-major landing (island-name reveal). |
| `stinger_parrot` | 2.0 s | Marimba run, pan trill, happy landing chord, bird whistle. |
| `stinger_treasure` | 2.5 s | Brass fanfare (triplet pickup, then G-B-D) with sparkle. |

## Sound list

* **Movement**: `footstep_{sand,grass,wood,stone}_01..04`, `jump`,
  `jump_high`, `long_jump`, `land_soft`, `land_normal`, `land_heavy`, `dive`,
  `roll`, `skid`, `slide_loop`, `ground_pound_start`, `ground_pound_impact`,
  `ledge_grab`, `ledge_climb`, `wall_kick`, `hurt`, `fall_whoosh`,
  `respawn_poof`.
* **Water**: `swim_stroke_01..03`, `splash_small`, `splash_big`, `water_exit`,
  `underwater_loop`.
* **Hook and tools**: `hook_swipe`, `hook_hit`, `hook_latch`, `hook_release`,
  `rope_creak`, `attachment_clunk`, `grapple_fire`, `grapple_hit`,
  `grapple_reel_loop`, `cannon_fire`, `explosion`, `shovel_dig_01..03`,
  `shovel_find`, `lantern_on`, `firefly_buzz_loop`.
* **Collectibles**: `coin_01..03`, `gem`, `treasure_big`, `chest_open`,
  `sparkle_loop`, `heart_pickup`.
* **Parrots**: `parrot_chirp_01..04`, `parrot_squawk`, `cage_break`,
  `parrot_rescue`.
* **Enemies and world**: `crab_step`, `crab_pinch`, `crab_hit`,
  `crab_defeat`, `enemy_alert`, `snail_fuse_loop`, `crate_break`,
  `barrel_break`, `switch_click`, `door_open`, `bell_ring`, `sail_flap`,
  `wood_creak`, `seagull_01..02`, `ocean_waves_loop`, `wind_loop`,
  `boat_splash`.
* **UI**: `ui_move`, `ui_select`, `ui_back`, `ui_pause`, `ui_map`,
  `prompt_appear`, `checkpoint`.

There are 98 SFX and 7 music cues, about 11 MB in total. To add a sound, write
a small function in section 4 of the script, decorate it with `@sfx("name")`
or `@sfx_family("prefix", count)`, and rerun the script. The manifest and
groups update automatically.
