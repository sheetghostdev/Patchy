class_name SceneBuilder
extends RefCounted
## Helpers for tool scripts that generate .tscn files from code. Every
## created node gets `owner = root` so it is saved; procedural children made
## by @tool scripts at runtime stay unsaved.

var root: Node3D


func _init(root_name: String) -> void:
	root = Node3D.new()
	root.name = root_name


func add(node: Node, parent: Node = null, node_name: String = "") -> Node:
	var p := parent if parent != null else root
	if node_name != "":
		node.name = node_name
	p.add_child(node, true)
	node.owner = root
	return node


func group(node_name: String, parent: Node = null) -> Node3D:
	return add(Node3D.new(), parent, node_name) as Node3D


func block(parent: Node, pos: Vector3, size: Vector3, surface: String = "lab", label: String = "", shape: LevelBlock.Shape = LevelBlock.Shape.BOX, rot_y_deg: float = 0.0, node_name: String = "") -> LevelBlock:
	var b := LevelBlock.new()
	b.shape = shape
	b.size = size
	b.surface = surface
	b.label = label
	b.position = pos
	b.rotation_degrees = Vector3(0, rot_y_deg, 0)
	add(b, parent, node_name if node_name != "" else "Block")
	return b


func label(parent: Node, pos: Vector3, text: String, font_size: int = 72, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = font_size
	l.pixel_size = 0.006
	l.outline_size = 16
	l.modulate = color
	l.outline_modulate = Color(0.12, 0.08, 0.2)
	add(l, parent, "Label")
	return l


func instance(path: String, parent: Node, pos: Vector3, rot_y_deg: float = 0.0, node_name: String = "") -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	add(n, parent, node_name)
	return n


func save(path: String) -> int:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed: %s" % error_string(err))
		return err
	err = ResourceSaver.save(ps, path)
	print("saved %s: %s" % [path, error_string(err)])
	root.free()
	return err
