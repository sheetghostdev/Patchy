class_name AttachmentData
extends Resource
## Data for one hand attachment (spec §132). The behaviour lives in the
## scene's AttachmentBase script; this is what menus and saves refer to.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
## Scene whose root extends AttachmentBase.
@export var scene: PackedScene
## Short ability tags shown in the attachments menu.
@export var abilities: PackedStringArray = PackedStringArray()
## Accent color for UI.
@export var color := Color.WHITE
## Order in the cycling wheel.
@export var order := 0
