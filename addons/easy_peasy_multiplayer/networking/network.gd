extends Node

# These signals can be connected to by a UI lobby scene or the game scene.
signal network_type_changed(network_type) ## Emitted when the [Network.active_network_type] is changed
signal player_connected(peer_id, player_info) ## Emitted when a new player connects to the local client
signal player_disconnected(peer_id) ## Emitted when a player disconnects from the local client
signal server_disconnected ## Emitted when the client is forcefully disconnected from the server
signal connection_fail ## Emitted when the local client fails to connect to the server
signal player_ready ## Emitted when a player has readied or unreadied
signal server_started ## Emitted when the server has been created
signal lobbies_fetched(lobbies) ## Emitted when [Network.list_lobbies] has a response

## An enum for the network types that can be used
enum MultiplayerNetworkType { DISABLED, ENET, STEAM }

## The currently active network type
var active_network_type : MultiplayerNetworkType = MultiplayerNetworkType.DISABLED :
	set(value):
		active_network_type = value
		network_type_changed.emit(active_network_type)

## The physical node for the active network, which is what makes using multiple networks so easy
var active_network : NetworkType

# General Variables
## The player info that the local client will send to other clients on connection to a server
var player_info = {
	"name": "Name"
}

## The number of players that can connect to the server.
var room_size: int = 4

## Whether the local client is the host of a server or not.
var is_host : bool

## A [Dictionary] containing all of the currently connected players, their network ids, and any info defined in [Network.player_info]
var connected_players = {}

## An array containing network ids of all the players that are ready
var players_ready : Array[int]

## The ip address that the network manager should use to try and connect to a server. Used for Enet only by default
var ip_address : String = "127.0.0.1" # IPv4 localhost

# Steam Variables
## The lobby data that a Steam lobby should be created with.
var steam_lobby_data = {
	"name": "MOVEMENTSHOOTER_TEST_LOBBY",
	"game": "DEFAULTSCENE"
}

## The lobby id of the Steam lobby
var steam_lobby_id: int = 0

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

	# This is specifically for interfacing with my custom dev tools, which can be found here: https://godotengine.org/asset-library/asset/4028)
	#DevTools.create_command("set_network", dev_set_network, "Sets the network type. Call without arguments to list available networks")
	#DevTools.create_command("host_lobby", dev_host_lobby, "Hosts a lobby using the current adtive network")
	#DevTools.create_command("connect", dev_join_lobby, "Connects to the given lobby")
	#DevTools.create_command("disconnect", dev_disconnect, "Disconnnects from the current lobby")

## These are designed for my dev tools, but they should be usable in code and in other console plugins, you just might need to adjust the arguments.
#region Dev Commands
## Sets the current network
func dev_set_network(network: String):
	if network:
		match network:
			"Steam":
				active_network_type = MultiplayerNetworkType.STEAM
			"Enet":
				active_network_type = MultiplayerNetworkType.ENET
			"None":
				active_network_type = MultiplayerNetworkType.DISABLED
			_:
				return "[color=red]ERROR: No network type named " + network + "[/color]"

		_build_multiplayer_network(true)
		return "Network type changed to " + network
	else:
		return "Available Arguments: [color=green]\nSteam\nEnet\nNone[/color]"

## Hosts a lobby using the currently selected network type
func dev_host_lobby():
	become_host()

## Joins a lobby using the argument passed in as either a Steam lobbyID or an IP address, depending on the type of network used
func dev_join_lobby(connector: String):
	if active_network_type == MultiplayerNetworkType.STEAM:
		steam_lobby_id = connector.to_int()
	else:
		if connector:
			ip_address =connector

	join_as_client()

## Disconnects from a lobby, if connected
func dev_disconnect():
	disconnect_from_server()
#endregion

## This is for updating the values from the [ProjectSettings]
func _update_settings() -> void:
	if ProjectSettings.has_setting("easy_peasy_multiplayer/general/verbose_network_logging"):
		_is_verbose = ProjectSettings.get_setting("easy_peasy_multiplayer/general/verbose_network_logging", false)

#region Private Network Setup Functions
## Sets the active network to the active network type
func _build_multiplayer_network(destroy_previous_network : bool = false):
	if not active_network or destroy_previous_network:
		match active_network_type:
			MultiplayerNetworkType.ENET:
				if _is_verbose:
					print("Setting network type to ENet")
				_set_active_network(NetworkEnet)
			MultiplayerNetworkType.STEAM:
				if _is_verbose:
					print("Setting network type to Steam")
				_set_active_network(NetworkSteam)
			MultiplayerNetworkType.DISABLED:
				if _is_verbose:
					print("Disabled networking")
				_remove_active_network()
			_:
				push_warning("No match for network type")

## Builds a network scene based on the passed parameters
func _set_active_network(new_network_type : Object):
	_remove_active_network()
	active_network = new_network_type.new()
	add_child(active_network, true)

## Removes the current active network, if one exists
func _remove_active_network():
	if is_instance_valid(active_network):
		active_network.queue_free()
#endregion

#region Network-Specific Functions

## Creates a new server using the currently selected [Steam.active_network_type]. Additional information regarding the connection can be passed through [param connection_info]. For [Network.MultiplayerNetworkType.STEAM]
func become_host(connection_info : Dictionary = {
	"steam_lobby_type" : Steam.LobbyType.LOBBY_TYPE_PUBLIC,
	"port" : NetworkEnet.DEFAULT_PORT
}):
	_build_multiplayer_network()
	if active_network_type != MultiplayerNetworkType.DISABLED:
		active_network.become_host(connection_info)


## Joins a lobby as a client using either the [Network.ip_address] or [Network.steam_lobby_id], depending on the current [Network.active_network_type]
func join_as_client():
	_build_multiplayer_network()
	if active_network_type != MultiplayerNetworkType.DISABLED:
		active_network.join_as_client()

## Disconnects the current peer from any connected servers. A [enum Network.MultiplayerNetworkType] can optionally be passed to set the network type to use after disconnecting, which can be useful for instances like going back to the lobby browser after leaving a server.
func disconnect_from_server(network_type : MultiplayerNetworkType = MultiplayerNetworkType.DISABLED):
	# This expression may not be necessary
	if steam_lobby_id != 0:
		Steam.leaveLobby(steam_lobby_id)

	active_network_type = network_type
	multiplayer.multiplayer_peer = null
	connected_players.clear()
	steam_lobby_id = 0
	is_host = false
	_build_multiplayer_network(true)

## Lists any lobbies that the current [Network.active_network_type] can find. NOTE: This function does nothing when using Enet as the network type, as there is no lobby system when using Enet.
func list_lobbies():
	_build_multiplayer_network()
	if active_network_type != MultiplayerNetworkType.DISABLED:
		active_network.list_lobbies()
#endregion

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
