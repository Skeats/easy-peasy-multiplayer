@abstract
class_name NetworkType
extends Node

var peer : MultiplayerPeer

var connector

## Creates a lobby using the provided [param connection_info]
@abstract func become_host(connection_info : Dictionary = {})

## Joins a game server using the [NetworkType]'s [member connector], or the [param connector_local], if passed
@abstract func join_as_client(connector_local = null)

## Lists discovered lobbies, if the current [NetworkType] has defined functionality for it
@abstract func list_lobbies()
