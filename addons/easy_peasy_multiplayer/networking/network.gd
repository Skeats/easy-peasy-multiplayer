extends Node

# These signals can be connected to by a UI lobby scene or the game scene.
signal network_changed(network: NetworkType) ## Emitted when the [Network.active_network] is changed
signal player_connected(peer_id, player_info) ## Emitted when a new player connects to the local client
signal player_disconnected(peer_id) ## Emitted when a player disconnects from the local client
signal server_disconnected ## Emitted when the client is forcefully disconnected from the server
signal connection_fail ## Emitted when the local client fails to connect to the server
signal player_ready ## Emitted when a player has readied or unreadied
signal server_started ## Emitted when the server has been created
signal lobbies_fetched(lobbies) ## Emitted when [Network.list_lobbies] has a response
signal host_closed ## Emitted on the host when it closes the server

## The physical node for the active network, which is what makes using multiple networks so easy
var active_network : NetworkType

# General Variables
## The player info that the local client will send to other clients on connection to a server
var player_info = {
	"name": "Name"
}

## The number of players that can connect to the server.
var room_size: int = 4

## A [Dictionary] containing all of the currently connected players, their network ids, and any info defined in [Network.player_info]
var connected_players = {}

## An array containing network ids of all the players that are ready
var players_ready : Array[int]

## Whether the local client is the host of a server or not. This should not be changed by any script outside of the network manager
var is_host : bool

## Whether the network manager should print its actions to standard output
var _is_verbose: bool = false

func _ready():
	_update_settings()

	# So many signals :O
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Sets the default username to the users Steam name, or if that doesnt exist, the OS name
	if SteamInfo.steam_username:
		player_info["name"] = SteamInfo.steam_username
	elif OS.has_environment("USERNAME"):
		player_info["name"] = OS.get_environment("USERNAME")
	else:
		var desktop_path := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		player_info["name"] = desktop_path[desktop_path.size() - 2]
	set_network_type(NetworkDisabled)

# These are designed for my dev tools, but they should be usable in code and in other console plugins, you just might need to adjust the arguments.
#region Dev Commands
func dev_host_steam_lobby() -> void:
	set_network_type(NetworkSteam)
	active_network.become_host()

func dev_host_enet_lobby() -> void:
	set_network_type(NetworkEnet).become_host()

## Joins a lobby using the argument passed in as either a Steam lobbyID or an IP address, depending on the type of network used
func dev_join_lobby(connector: String) -> String:
	var str: String = "No active network built"
	if not active_network:
		print(str)
		return str
	if active_network is NetworkSteam:
		active_network.join_as_client(connector.to_int())
		str = "Starting Steam lobby"
	else:
		if connector:
			active_network.join_as_client(connector)
		else:
			active_network.join_as_client()
		str = "Starting Enet lobby"

	print(str)
	return str


## Disconnects from a lobby, if connected
func dev_disconnect():
	disconnect_from_server()
#endregion

## This is for updating the values from the [ProjectSettings]
func _update_settings() -> void:
	if ProjectSettings.has_setting("easy_peasy_multiplayer/general/verbose_network_logging"):
		_is_verbose = ProjectSettings.get_setting("easy_peasy_multiplayer/general/verbose_network_logging", false)

## Sets the active network to the [NetworkType] provided, if any
func set_network_type(new_network_type: Object = NetworkDisabled) -> NetworkType:
	if is_instance_valid(active_network):
		active_network.queue_free()
	active_network = new_network_type.new()
	add_child(active_network, true)
	if _is_verbose:
		print("Setting network type to %s" % active_network.get_network_name())
	network_changed.emit(active_network)
	return active_network

## Disconnects the current peer from any connected servers. A [enum Network.MultiplayerNetworkType] can optionally be passed to set the network type to use after disconnecting, which can be useful for instances like going back to the lobby browser after leaving a server.
func disconnect_from_server(network_type: Object = NetworkDisabled):
	# This expression may not be necessary
	if active_network is NetworkSteam and active_network.connector:
		SteamInfo.steam_api.leaveLobby(active_network.connector)

	if is_host:
		host_closed.emit()

	multiplayer.multiplayer_peer = null
	connected_players.clear()
	is_host = false
	set_network_type(network_type)

#region MultiplayerAPI Signals

## Callback function that runs whenever a new player connects to the local client (Not necessarily the server in general. This was a misconception I had which confused me). This function will send the new player the current client's information, so that the connecting player will be aware of the local client.
func _on_player_connected(id : int):
	_register_player.rpc_id(id, player_info)

## Callback function that runs whenever a player disconnects from the server. This updates the the player lists on all clients that are still connected.
func _on_player_disconnected(id : int):
	connected_players.erase(id)
	players_ready.erase(id)
	player_disconnected.emit(id)

## Callback function that runs when this client successfully connects to a server. Also emits the [signal player_connected] signal... I don't exactly get what this does
func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	connected_players[peer_id] = player_info
	if _is_verbose:
		print("[%s]: Joined server" % peer_id)
	player_connected.emit(peer_id, player_info)

## Callback function that runs on the local client when it fails to connect to a server.
func _on_connected_fail():
	disconnect_from_server()
	connection_fail.emit()

## Callback function that runs on the local client when it is disconnected from the server. This occurs when you are kicked, the server shuts down, or the local client is otherwise forcefully removed from the server.
func _on_server_disconnected():
	disconnect_from_server()
	server_disconnected.emit()
	if _is_verbose:
		print("Disconnected from server")
#endregion

#region Ready RPCs
## This rpc can be called on any client, and should be passed to the server to register that player's ready state. The local client's ready state should be passed into [param toggled_on] so that the server knows what ready state the client is on.
##
## [br][br]
##
## Example code to run on clients when they ready: [code] ready_state.rpc_id(1, is_ready) [/code]
@rpc("any_peer", "call_local", "reliable")
func ready_state(toggled_on : bool):
	if multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id() # This function is like magic to me but it's so convenient

		# Keeps track of who has readied so that people can only ready once (I wonder why this exists :P)
		if toggled_on and !players_ready.has(sender_id):
			players_ready.append(sender_id)
		elif !toggled_on:
			players_ready.erase(sender_id)

		propagate_ready_states.rpc(players_ready) # Updates the ready states on all clients

## This rpc should only be called on the host, sending the ready states to all of the players. This sort of rpc is server-authoratative, which is more secure than clients having authority, so long as the host is not malicious (it would be most secure when the server is hosted seperately from any of the players, but that also means having to maintain dedicated servers, which I most definitely do not have the money for, so I have not thought about implementing it).
##
## [br][br]
##
## Example code for the host sending ready states to clients: [code] propagate_ready_states.rpc(ready_states) [/code]
@rpc("authority", "call_local", "reliable")
func propagate_ready_states(server_ready_states : Array[int]):
	players_ready = server_ready_states
	player_ready.emit()
#endregion

## This rpc is called during [_on_player_connected] and is sent from local clients to a newly connected client, as well as vice versa. This essentially initiates a handshake between the player that just connected to the server and all other players.
@rpc("any_peer", "reliable")
func _register_player(new_player_info : Dictionary):
	var new_player_id = multiplayer.get_remote_sender_id()
	connected_players[new_player_id] = new_player_info
	if multiplayer.is_server():
		propagate_ready_states.rpc_id(new_player_id, players_ready)
	player_connected.emit(new_player_id, new_player_info)
