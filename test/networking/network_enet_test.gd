# GdUnit generated TestSuite
class_name NetworkEnetTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source: String = 'res://addons/easy_peasy_multiplayer/networking/network_enet.gd'

func before_test() -> void:
	Network.set_network_type(NetworkEnet)

func test_become_host_connected_players_includes_host() -> void:
	Network.active_network.become_host()
	await_signal_on(Network, "player_connected")
	assert_bool(Network.connected_players[1] == Network.player_info)

func test_become_host_is_host_on_signal() -> void:
	Network.active_network.become_host()
	await_signal_on(Network, "player_connected")
	assert_bool(Network.is_host)
