extends Node

# Steam Variables
var steam_api: Object = null

var is_on_steam_deck: bool = false
var is_online: bool = false
var is_owned: bool = false
var is_family_shared: bool = false
var is_free_weekend: bool = false
var timed_trial_stats: Dictionary = {}
var app_owner: int = 0
var steam_id: int = 0
var steam_username: String = ""

## @deprecated: use GodotSteam's app_id property in [ProjectSettings]
var steam_app_id: int = 480

# User authentication variables [NOT IN USE]
var auth_ticket: Dictionary ## Your auth ticket
var client_auth_tickets: Array ## Array of tickets from other clients

func _init() -> void:
	# Im going to leave these here just in case, but otherwise the appID should be changed in [ProjectSettings]
	#OS.set_environment("SteamAppId", str(steam_app_id))
	#OS.set_environment("SteamGameId", str(steam_app_id))
	pass

func _ready() -> void:
	#SteamInfo.steam_api.get_auth_session_ticket_response.connect(_on_get_auth_session_ticket_response)
	#SteamInfo.steam_api.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)
	if ProjectSettings.get_setting("easy_peasy_multiplayer/steam/enable_steam", false):
		initialize_steam()

func _process(_delta: float) -> void:
	if steam_api:
		steam_api.run_callbacks()

func initialize_steam() -> void:
	if Engine.has_singleton("Steam"):
		steam_api = Engine.get_singleton("Steam")

		# Gather additional data
		is_on_steam_deck = steam_api.isSteamRunningOnSteamDeck()
		is_online = steam_api.loggedOn()
		is_owned = steam_api.isSubscribed()
		is_family_shared = steam_api.isSubscribedFromFamilySharing()
		is_free_weekend = steam_api.isSubscribedFromFreeWeekend()
		timed_trial_stats = steam_api.isTimedTrial()
		app_owner = steam_api.getAppOwner()
		steam_id = steam_api.getSteamID()
		steam_username = steam_api.getPersonaName()
		auth_ticket = steam_api.getAuthSessionTicket()

		if not is_owned or is_family_shared or is_free_weekend:
			print("User does not own this game")
			get_tree().quit()

#region User Authentication [WIP, NOT FUNCTIONING]
# https://godotsteam.com/tutorials/authentication/#__tabbed_1_2

# Callback from getting the auth ticket from Steam
func _on_get_auth_session_ticket_response(this_auth_ticket: int, result: int) -> void:
	print("Auth session result: %s" % result)
	print("Auth session ticket handle: %s" % this_auth_ticket)

# Callback from attempting to validate the auth ticket
func _on_validate_auth_ticket_response(auth_id: int, response: int, owner_id: int) -> void:
	print("Ticket Owner: %s" % auth_id)

	# Make the response more verbose, highly unnecessary but good for this example
	var verbose_response: String
	match response:
		0: verbose_response = "Steam has verified the user is online, the ticket is valid and ticket has not been reused."
		1: verbose_response = "The user in question is not connected to Steam."
		2: verbose_response = "The user doesn't have a license for this App ID or the ticket has expired."
		3: verbose_response = "The user is VAC banned for this game."
		4: verbose_response = "The user account has logged in elsewhere and the session containing the game instance has been disconnected."
		5: verbose_response = "VAC has been unable to perform anti-cheat checks on this user."
		6: verbose_response = "The ticket has been canceled by the issuer."
		7: verbose_response = "This ticket has already been used, it is not valid."
		8: verbose_response = "This ticket is not from a user instance currently connected to steam."
		9: verbose_response = "The user is banned for this game. The ban came via the Web API and not VAC."
	print("Auth response: %s" % verbose_response)
	print("Game owner ID: %s" % owner_id)

func validate_auth_session(ticket: Dictionary, steam_id: int) -> void:
	var auth_response: int = steam_api.beginAuthSession(ticket.buffer, ticket.size, steam_id)

	# Get a verbose response; unnecessary but useful in this example
	var verbose_response: String
	match auth_response:
		0: verbose_response = "Ticket is valid for this game and this Steam ID."
		1: verbose_response = "The ticket is invalid."
		2: verbose_response = "A ticket has already been submitted for this Steam ID."
		3: verbose_response = "Ticket is from an incompatible interface version."
		4: verbose_response = "Ticket is not for this game."
		5: verbose_response = "Ticket has expired."
	print("Auth verifcation response: %s" % verbose_response)

	if auth_response == 0:
		print("Validation successful, adding user to client_auth_tickets")
		client_auth_tickets.append({"id": steam_id, "ticket": ticket.id})

	# You can now add the client to the game
#endregion
