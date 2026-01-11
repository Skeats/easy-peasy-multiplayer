# GdUnit generated TestSuite
class_name NetworkTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source: String = 'res://addons/easy_peasy_multiplayer/networking/network.gd'

func test_set_network_type_set_enet() -> void:
	Network.set_network_type(NetworkEnet)
	assert_bool(Network.active_network is NetworkEnet)

func test_set_network_type_set_steam() -> void:
	Network.set_network_type(NetworkSteam)
	assert_bool(Network.active_network is NetworkSteam)

func test_set_network_type_set_disabled() -> void:
	Network.set_network_type(NetworkDisabled)
	assert_bool(Network.active_network is NetworkDisabled)
