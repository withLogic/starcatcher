extends Node2D

var arrTextures:Array = [
	"res://resources/textures/nebulas/sprNebula1.png",
	"res://resources/textures/nebulas/sprNebula2.png",
	"res://resources/textures/nebulas/sprNebula3.png",
	"res://resources/textures/nebulas/sprNebula4.png",
	"res://resources/textures/nebulas/sprNebula5.png"
]
onready var nSprite:Sprite = $sprite

func _ready() -> void:
	nSprite.texture = load(arrTextures[randi() % arrTextures.size()])
