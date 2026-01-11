class_name NetworkEnet
extends NetworkType

## The port number to use for Enet servers
const DEFAULT_PORT = 7000

func _ready() -> void:
	peer = ENetMultiplayerPeer.new()

#region Network-Specific Functions
## Creates an ENet server using any information provided in [param connection_info]. For ENet, this consists of a [code]port[/code] which, unless specified, will default to the [member DEFAULT_PORT].
func become_host(connection_info : Dictionary = { "port" : DEFAULT_PORT }):
	var error = peer.create_server(connection_info.port, Network.room_size)
	if error:
		if Network._is_verbose:
			print("Error creating host: %s" % error_string(error))
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer

	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	Network.is_host = true
	if Network._is_verbose:
		print("ENet Server hosted on port %d" % connection_info.port)

func join_as_client(connector_local = null):
	if connector_local:
		connector = connector_local

	if not connector: return

	var ip = connector
	var port = DEFAULT_PORT

	# Check if the ip_address contains a port (e.g., "192.168.1.1:8080")
	# This snippet was written by https://github.com/SimonMcCallum. Thank you for forking my plugin, your project is so cool!
	if ":" in ip:
		var parts = ip.split(":")
		ip = parts[0]
		port = int(parts[1])

	var error = peer.create_client(ip, port)
	if error:
		if Network._is_verbose:
			print("ENet client failed to connect to server %s:%d with error: %s" % [ip, port, error_string(error)])
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer
	Network.is_host = false

	if Network._is_verbose:
		print("ENet client connecting to %s:%d" % [ip, port])
#endregion
