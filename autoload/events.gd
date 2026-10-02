extends Node
## Global signal bus. Systems emit and listen here instead of holding
## hard references to each other (spec §131).

# --- Player ---
signal player_spawned(player: Node3D)
signal player_damaged(amount: int, health: int)
signal player_healed(amount: int, health: int)
signal player_died
signal player_respawned(position: Vector3)
signal player_landed(impact_speed: float, tier: int)
signal player_ground_pounded(position: Vector3, radius: float)

# --- Progression ---
signal treasure_collected(treasure_id: StringName, kind: StringName, value: int)
signal parrot_rescued(parrot_id: StringName, total: int)
signal attachment_unlocked(attachment_id: StringName)
signal attachment_equipped(attachment_id: StringName)
signal ship_part_recovered(part_id: StringName)
signal treasure_map_found(map_id: StringName)
signal world_task_completed(task_id: StringName)
signal boss_defeated(boss_id: StringName)
signal island_discovered(island_id: StringName, display_name: String)
signal checkpoint_reached(checkpoint_id: StringName)
signal quest_updated(quest_id: StringName, stage: int)

# --- Presentation ---
signal camera_impulse(strength: float)
signal hud_message(text: String, duration: float)
signal interaction_prompt_changed(prompt: String, enabled: bool)
signal parrot_requirement_shown(required: int, have: int, visible: bool)
signal dialogue_started(speaker: String)
signal dialogue_finished
signal game_paused(paused: bool)
