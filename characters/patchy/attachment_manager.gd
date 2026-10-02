class_name AttachmentManager
extends Node
## Owns Patchy's hand attachments (spec §53–54): instantiates unlocked ones
## from their AttachmentData, mounts the equipped one in the arm socket,
## cycles with tool_next / tool_previous (quick swap with a satisfying
## CLUNK), and forwards tool_primary / tool_secondary to it.

signal equipped_changed(id: StringName)

const DATA_DIR := "res://resources/attachments/"

var equipped: AttachmentBase
var equipped_id: StringName = &""
var _instances: Dictionary = {}   # id -> AttachmentBase
var _data: Dictionary = {}        # id -> AttachmentData
var _p: Player
var _swap_t := 0.0


func _ready() -> void:
	_p = get_parent() as Player
	_load_data()
	if not _p.is_node_ready():
		await _p.ready
	InventoryManager.attachments_changed.connect(_sync)
	_sync()
	equip(InventoryManager.equipped_attachment, false)


func _load_data() -> void:
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		var path := DATA_DIR + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var d := load(path) as AttachmentData
		if d != null and d.id != &"":
			_data[d.id] = d


func get_data(id: StringName) -> AttachmentData:
	return _data.get(id, null)


## Unlocked attachment ids in wheel order.
func get_cycle() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in InventoryManager.get_attachments():
		if _data.has(id):
			ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return (_data[a] as AttachmentData).order < (_data[b] as AttachmentData).order)
	return ids


func _sync() -> void:
	for id in get_cycle():
		if not _instances.has(id):
			var d: AttachmentData = _data[id]
			if d.scene == null:
				continue
			var inst := d.scene.instantiate() as AttachmentBase
			inst.data = d
			inst.visible = false
			_socket().add_child(inst)
			_instances[id] = inst


func _socket() -> Node3D:
	var m := _p.get_node_or_null("Visual/PatchyModel") as PatchyModel
	if m != null and m.hook_socket != null:
		return m.hook_socket
	return _p


func equip(id: StringName, with_fx: bool = true) -> void:
	if not _instances.has(id) or id == equipped_id:
		return
	if equipped != null:
		equipped.unequip()
	equipped = _instances[id]
	equipped_id = id
	equipped.equip(_p)
	InventoryManager.equipped_attachment = id
	equipped_changed.emit(id)
	Events.attachment_equipped.emit(id)
	if with_fx:
		_swap_t = 0.25
		AudioManager.play(&"attachment_clunk", _p.global_position + Vector3.UP)


func cycle(step: int) -> void:
	var ids := get_cycle()
	if ids.size() < 2:
		return
	var i := ids.find(equipped_id)
	equip(ids[(i + step + ids.size()) % ids.size()])


func update(delta: float) -> void:
	var inp := _p.input
	if inp.is_buffered(&"tool_next", 0.1):
		inp.consume(&"tool_next")
		cycle(1)
	elif inp.is_buffered(&"tool_previous", 0.1):
		inp.consume(&"tool_previous")
		cycle(-1)
	# The socket pops on swap: a quick scale bounce reads as a mechanical clunk.
	if _swap_t > 0.0:
		_swap_t = maxf(_swap_t - delta, 0.0)
		var k := _swap_t / 0.25
		_socket().scale = Vector3.ONE * (1.0 - 0.6 * sin(k * PI))
	if equipped == null:
		return
	equipped.physics_update(delta)
	var ground_ok := _p.state_id in [&"ground", &"swim"] or (_p.state_id == &"air" and equipped.allows_air_action())
	if ground_ok and inp.is_buffered(&"tool_primary", 0.1):
		inp.consume(&"tool_primary")
		equipped.primary_action()
	if inp.is_buffered(&"tool_secondary", 0.1):
		inp.consume(&"tool_secondary")
		equipped.secondary_action()


func get_instance(id: StringName) -> AttachmentBase:
	return _instances.get(id, null)


## Switches to the hook for ring swings when allowed (spec §54 flow). The
## grapple's own button fires the grapple instead (it zips to rings).
func ensure_hook_for_rings(via_tool_button: bool = false) -> bool:
	if equipped_id == &"hook":
		return true
	if equipped_id == &"grapple" and via_tool_button:
		return false
	if not Settings.auto_equip_hook_for_rings or not _instances.has(&"hook"):
		return false
	equip(&"hook")
	return true
