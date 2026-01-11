class_name NetworkDisabled
extends NetworkType

func become_host(connection_info : Dictionary = {}):
	pass

func join_as_client(connector_local = null):
	pass

func list_lobbies():
	pass

func get_class() -> String: return "NetworkDisabled"
