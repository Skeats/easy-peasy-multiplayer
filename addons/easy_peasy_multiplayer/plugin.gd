@tool
extends EditorPlugin

const PLUGIN_NAME = "easy_peasy_multiplayer"
const AUTOLOADS = {
	"SteamInfo" : "res://addons/%s/steam_info.gd" % PLUGIN_NAME,
	"Network" : "res://addons/%s/networking/network.gd" % PLUGIN_NAME
}

const SETTINGS: Dictionary = {
	"general" : {
		"verbose_network_logging" : {
			"type" : TYPE_BOOL,
			"default_value" : false
		},
	}
}

func _enter_tree() -> void:
	var godotsteam_exists := DirAccess.dir_exists_absolute("res://addons/godotsteam/")
	var multiplayer_peer_exists := DirAccess.dir_exists_absolute("res://addons/steam-multiplayer-peer")

	if godotsteam_exists and multiplayer_peer_exists:
		# Registers autoloads
		for autoload in AUTOLOADS:
			add_autoload_singleton(autoload, AUTOLOADS[autoload])
		_add_project_settings()
	else:
		var dialog := AcceptDialog.new()
		dialog.title = "Missing Required Dependencies"
		dialog.dialog_text = "You are missing the following dependencies required for this addon to function: \n"
		if not godotsteam_exists:
			dialog.dialog_text += "GodotSteam"
		if not multiplayer_peer_exists:
			dialog.dialog_text += "Steam Multiplayer Peer"

		EditorInterface.popup_dialog_centered(dialog)

func _disable_plugin() -> void:
	_remove_project_settings()

func _exit_tree() -> void:
	# Removes autoloads
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload)

func _add_project_settings() -> void:
	for section : String in SETTINGS:
		for setting : String in SETTINGS[section]:
			var setting_name : String = "%s/%s/%s" % [PLUGIN_NAME, section, setting]
			if not ProjectSettings.has_setting(setting_name):
				ProjectSettings.set_setting(setting_name, \
				SETTINGS[section][setting]["default_value"])

			ProjectSettings.set_initial_value(setting_name, SETTINGS[section][setting]["default_value"])
			ProjectSettings.set_as_basic(setting_name, true)

			var error : int = ProjectSettings.save()
			if not error == OK:
				push_error("Dev Tools - error %s while saving project settings." % error_string(error))


func _remove_project_settings() -> void:
	for section : String in SETTINGS:
		for setting : String in SETTINGS[section]:
			var setting_name : String = "%s/%s/%s" % [PLUGIN_NAME, section, setting]
			if ProjectSettings.has_setting(setting_name):
				ProjectSettings.set_setting(setting_name, null)

			var error : int = ProjectSettings.save()
			if not error == OK:
				push_error("Dev Tools - error %s while saving project settings." % error_string(error))
