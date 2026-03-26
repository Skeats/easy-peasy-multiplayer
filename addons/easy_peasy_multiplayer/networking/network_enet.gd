class_name NetworkEnet
extends NetworkType

const LOCALHOST = "127.0.0.1"

## The port number to use for Enet servers
const DEFAULT_PORT = 7000

func _ready() -> void:
	peer = ENetMultiplayerPeer.new()
	connector = LOCALHOST

#region Network-Specific Functions
## Creates an ENet server using any information provided in [param connection_info]. For ENet, this consists of a port which, unless specified, will default to the [member DEFAULT_PORT].
func become_host(connection_info = DEFAULT_PORT):
	var error = peer.create_server(connection_info, Network.room_size)
	if error:
		if Network._is_verbose:
			print("Error creating host: %s" % error_string(error))
		return error
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.multiplayer_peer = peer

	Network.is_host = true
	Network.connected_players[1] = Network.player_info
	Network.server_started.emit()
	Network.player_connected.emit(1, Network.player_info)
	set_connector(get_local_ip(), connection_info)
	if Network._is_verbose:
		print("ENet Server hosted on port %d" % connection_info)

func join_as_client(connection_info = connector):
	var ip = connection_info
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
	set_connector(ip, port)

	if Network._is_verbose:
		print("ENet client connecting to %s:%d" % [ip, port])
#endregion

func get_network_name(): return "NetworkEnet"

func set_connector(ip: String, port: int) -> void:
	connector = "%s:%d" % [ip, port]

static func get_local_ip() -> String:
	var local_ip = ""
	for address in IP.get_local_addresses():
		# Filter out loopback and APIPA addresses, focusing on common private IP ranges
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			# Check for common private IP ranges (e.g., 192.168.x.x, 10.x.x.x, 172.16-31.x.x)
			if address.begins_with("192.168.") or address.begins_with("10.") or \
				(address.begins_with("172.") and int(address.split(".")[1]) >= 16 and int(address.split(".")[1]) <= 31):
				local_ip = address
				break # Found a suitable local IP, exit loop
	return local_ip
