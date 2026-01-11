extends Node2D

const PLAYER = preload("res://prefabs/player/player.tscn")


@onready var player_spawn: Marker2D = %PlayerSpawn
@onready var player_spawner: MultiplayerSpawner = %PlayerSpawner

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)
	Network.host_closed.connect(_on_host_closed)

	player_spawner.spawn_function = spawn_player

func spawn_player(player_id: int) -> Node2D:
	var player := PLAYER.instantiate()
	player.name = "Player%s" % player_id
	player.add_to_group("Players")
	player.global_transform = player_spawn.global_transform
	return player

func remove_player(player_id: int) -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.name.to_int() == player_id:
			player.queue_free()

func _on_player_connected(player_id: int, _player_info: Dictionary) -> void:
	if multiplayer.is_server() and not get_tree().current_scene.find_child("Player" + str(player_id)):
		player_spawner.spawn(player_id)

func _on_player_disconnected(player_id: int) -> void:
	if multiplayer.is_server():
		remove_player(player_id)

func _on_host_closed() -> void:
	for player in get_tree().get_nodes_in_group("Players"):
		if player.name.to_int() != 1:
			player.queue_free()
