class_name NetworkSteam
extends NetworkType

## This is a network module for connecting to lobbies using Steam. It utilizes GodotSteam lobbies and SteamMultiplayerPeer for interfacing with the MultiplayerAPI

## I have no idea what this does I won't lie
const PACKET_READ_LIMIT: int = 32

static var lobby_data: Dictionary = {
	"name": "Easy Peasy Multiplayer Game",
	"game": "DEFAULTSCENE"
}

func _ready() -> void:
	if ClassDB.class_exists("SteamMultiplayerPeer") and SteamInfo.steam_api:
		peer = ClassDB.instantiate("SteamMultiplayerPeer")
	else:
		Network.disconnect_from_server()
		return

	SteamInfo.steam_api.lobby_created.connect(_on_lobby_created)
	SteamInfo.steam_api.lobby_joined.connect(_on_lobby_joined)
	SteamInfo.steam_api.join_requested.connect(_on_lobby_join_requested) # I don't remember what this was for...
	SteamInfo.steam_api.lobby_match_list.connect(_on_lobby_match_list)

#region Main Network Function
## Creates a Steam lobby using the information provided in [param connection_info]. For Steam, this should be set to a [enum Steam.LobbyType], otherwise it will default to [constant Steam.LobbyType.LOBBY_TYPE_PUBLIC].
func become_host(connection_info = SteamInfo.steam_api.LOBBY_TYPE_PUBLIC):
	if not connector: # Prevents you from creating a lobby if you are currently connected to a different lobby
		SteamInfo.steam_api.createLobby(connection_info, Network.room_size)

func join_as_client(connection_info = connector):
	if not connection_info: return

	SteamInfo.steam_api.joinLobby(connection_info)

## Lists lobbies using the [Steam] addRequestLobby... functions as filters. Call any of  before calling this function to refine the lobby search
func list_lobbies():
	# SteamInfo.steam_api.addRequestLobbyListDistanceFilter(SteamInfo.steam_api.LOBBY_DISTANCE_FILTER_WORLDWIDE)

	if ProjectSettings.get_setting("steam/initialization/app_id", 0) == 480:
		SteamInfo.steam_api.addRequestLobbyListStringFilter("name", lobby_data["name"], SteamInfo.steam_api.LOBBY_COMPARISON_EQUAL)
	SteamInfo.steam_api.requestLobbyList()
#endregion

#region Steam Functions

## Checks for command line args that would tell the game to connect to a specific server on startup [br][br]
## [color=yellow]NOTE:[/color] This function is still Work-In-Progress. I have not had a chance to test this
## with an actual game as I do not have a Steam AppID of my own.
## @experimental
func check_command_line() -> void:
	var command_args: Array = OS.get_cmdline_args()

	# There are arguments to process
	if command_args.size() > 0:

		# A Steam connection argument exists
		if command_args[0] == "+connect_lobby":

			# Lobby invite exists so try to connect to it
			if int(command_args[1]) > 0:

				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				if Network._is_verbose:
					print("Command line lobby ID: %d" % command_args[1])
				connector = int(command_args[1])
				Network.is_host = false

#region Lobby/Host Startup

# Callback that runs when the [Steam] API finishes creating a lobby
func _on_lobby_created(response : int, new_lobby_id : int):
	if response == SteamInfo.steam_api.CHAT_ROOM_ENTER_RESPONSE_SUCCESS: # On connected OK
		connector = new_lobby_id
		print("Created lobby: %d" % connector)

		SteamInfo.steam_api.setLobbyJoinable(connector, true)

		for entry in lobby_data:
			SteamInfo.steam_api.setLobbyData(connector, entry, lobby_data[entry])

		_create_host()
	else:
		print("Error creating lobby: %s" % response)

# Creates a host, I guess. idk im tired I just finished documenting all of the [Network] class and this is a private function so I can come back to this later.
func _create_host():
	var error = peer.create_host(0)
	if error != OK:
		if Network._is_verbose:
			print("Error creating host: %s" % error_string(error))
		return error

	multiplayer.multiplayer_peer = peer
	Network.is_host = true
	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	if Network._is_verbose:
		print("Steam lobby hosted with id %d" % connector)

# Callback function that runs when Steam responds to a [Network.list_lobbies] query with... a list of lobbies :O
func _on_lobby_match_list(lobbies: Array) -> void:
	Network.lobbies_fetched.emit(lobbies)
#endregion

#region Lobby Joining
# I am not entirely clear on what this does, something to do with friend invites, but I can't test it because I don't have a Steam AppID
func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = SteamInfo.steam_api.getFriendPersonaName(friend_id)

	print("Joining %s's lobby..." % owner_name)

	# Attempt to join the lobby
	join_as_client(this_lobby_id)

# Callback function that runs once Steam tells the client that it has either connected or failed to connect
# to the lobby
func _on_lobby_joined(lobby_id : int, _permissions : int, _locked : bool, response : int):
	if response == SteamInfo.steam_api.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var id = SteamInfo.steam_api.getLobbyOwner(lobby_id)

		if id != SteamInfo.steam_api.getSteamID():
			_connect_socket(id)
			if Network._is_verbose:
				print("Connecting client to socket...")
	else:
		# Get the failure reason
		var FAIL_REASON : String
		match response:
			2:  FAIL_REASON = "This lobby no longer exists."
			3:  FAIL_REASON = "You don't have permission to join this lobby."
			4:  FAIL_REASON = "The lobby is now full."
			5:  FAIL_REASON = "Uh... something unexpected happened!"
			6:  FAIL_REASON = "You are banned from this lobby."
			7:  FAIL_REASON = "You cannot join due to having a limited account."
			8:  FAIL_REASON = "This lobby is locked or disabled."
			9:  FAIL_REASON = "This lobby is community locked."
			10: FAIL_REASON = "A user in the lobby has blocked you from joining."
			11: FAIL_REASON = "A user you have blocked is in the lobby."
		if FAIL_REASON:
			if Network._is_verbose:
				print("Steam lobby connection failed with error: %s" % FAIL_REASON)

# Creates a SteamMultiplayerPeer client
func _connect_socket(steam_id : int):
	var error = peer.create_client(steam_id, 0)
	if error:
		if Network._is_verbose:
			print("Error creating client: %s" % error_string(error))
		return error

	if Network._is_verbose:
		print("Connecting peer to host...")
	multiplayer.multiplayer_peer = peer
	Network.is_host = false
#endregion
#endregion

func get_network_name(): return "NetworkSteam"
