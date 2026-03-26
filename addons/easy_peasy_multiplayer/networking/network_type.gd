## Base class for specifying a new networking implementation for Easy Peasy Multiplayer
@abstract
class_name NetworkType extends Node

## The [MultiplayerPeer] that the plugin will use. This should be set within [method Node._ready]
var peer : MultiplayerPeer

## The necessary information that this [NetworkType] needs to be able to connect to a server. This can contain anything from a connection id, to an ip address, or even a dictionary of multiple things. This is intentionally left open-ended to ensure that people have no problems integrating custom networking implementations.
var connector

## Creates a lobby using the provided [param connection_info]
@abstract func become_host(connection_info = null) -> void

## Joins a game server using the [NetworkType]'s [member connector], or the [param connector_local], if passed
@abstract func join_as_client(connector_local = null) -> void

@abstract func get_network_name() -> String

## Lists discovered lobbies, if the current [NetworkType] has defined functionality for it. If your [NetworkType] does not have any available lobby functionality, then there is no need to override this.
func list_lobbies() -> void:
	pass
