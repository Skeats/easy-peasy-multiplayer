extends Control

# Misc
@onready var ip: LineEdit = $EnetConnectTab/IP
@onready var steam_lobby_list: VBoxContainer = %SteamLobbyList

# Lobby Info
@onready var network_id: Label = %NetworkID
@onready var lobby_id: Label = %LobbyID
@onready var connected_players: Label = %ConnectedPlayers

# Tabs
@onready var network_tab: HFlowContainer = %NetworkTab
@onready var enet_connect_tab: HFlowContainer = %EnetConnectTab
@onready var steam_lobby_browser: HFlowContainer = %SteamLobbyBrowser
@onready var lobby_tab: HFlowContainer = %LobbyTab

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Network.lobbies_fetched.connect(create_steam_lobby_list)
	Network.player_connected.connect(_update_lobby_info)
	Network.player_disconnected.connect(_update_lobby_info)
	Network.server_disconnected.connect(_on_back_to_main_pressed)
	_on_back_to_main_pressed()

# Main Network Buttons
func _on_enet_pressed() -> void:
	Network.set_network_type(NetworkEnet)
	network_tab.visible = false
	enet_connect_tab.visible = true

func _on_steam_pressed() -> void:
	Network.set_network_type(NetworkSteam)
	network_tab.visible = false
	steam_lobby_browser.visible = true
	for child in steam_lobby_list.get_children():
		child.queue_free()
	Network.active_network.list_lobbies()

# General callback functions
func _on_host_pressed() -> void:
	Network.active_network.become_host()
	steam_lobby_browser.visible = false
	enet_connect_tab.visible = false
	lobby_tab.visible = true

func _on_back_to_main_pressed() -> void:
	# Set the main network tab as the only visible tab
	network_tab.visible = true
	enet_connect_tab.visible = false
	steam_lobby_browser.visible = false
	lobby_tab.visible = false

	Network.disconnect_from_server(NetworkDisabled)

# Enet Connection
func _on_ip_text_submitted(new_text: String) -> void:
	if new_text:
		Network.active_network.join_as_client(new_text)
	else:
		Network.active_network.join_as_client()

	enet_connect_tab.visible = false
	lobby_tab.visible = true

func _on_join_enet_pressed() -> void:
	_on_ip_text_submitted(ip.text)

# Steam lobby
func create_steam_lobby_list(lobbies: Array) -> void:
	for lobby in lobbies:
		var lobby_name: String = Steam.getLobbyData(lobby, "name")
		var lobby_num_members: int = Steam.getNumLobbyMembers(lobby)

		var button := Button.new()
		button.text = "Lobby Name: %s | Players: %s/4" % [lobby_name, lobby_num_members]
		button.pressed.connect(func():
			Network.active_network.join_as_client(lobby)
		)
		steam_lobby_list.add_child(button)

func _update_lobby_info(_opt_peer_id: int = 0, _opt_player_info: Dictionary = {}) -> void:
	network_id.text = "Network ID: %s" % multiplayer.get_unique_id()
	lobby_id.text = "Lobby ID: %s" % Network.active_network.connector
	connected_players.text = "Connected players:"
	for player in Network.connected_players:
		connected_players.text += "\n%s : %s" % [player, Network.connected_players[player].name]
