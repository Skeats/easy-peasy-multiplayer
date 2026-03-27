@tool
extends EditorPlugin

const PLUGIN_NAME = "easy_peasy_multiplayer"
const AUTOLOADS = {
	"SteamInfo": "res://addons/%s/steam_info.gd" % PLUGIN_NAME,
	"Network": "res://addons/%s/networking/network.gd" % PLUGIN_NAME
}

const SETTINGS: Dictionary = {
	"general": {
		"verbose_network_logging": {
			"type": TYPE_BOOL,
			"default_value": false,
			"is_basic": true
		},
	},
	"steam": {
		"enable_steam": {
			"type": TYPE_BOOL,
			"default_value": false,
			"is_basic": true
		}
	}
}

func _enter_tree() -> void:
	ProjectSettings.settings_changed.connect(_on_settings_changed)
	
	# Registers autoloads
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload, AUTOLOADS[autoload])
	_add_project_settings()

func _disable_plugin() -> void:
	_remove_project_settings()

func _exit_tree() -> void:
	# Removes autoloads
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload)

func _add_project_settings() -> void:
	for section: String in SETTINGS:
		for setting: String in SETTINGS[section]:
			var setting_name: String = "%s/%s/%s" % [PLUGIN_NAME, section, setting]
			if not ProjectSettings.has_setting(setting_name):
				ProjectSettings.set_setting(setting_name, \
				SETTINGS[section][setting]["default_value"])

			ProjectSettings.set_initial_value(setting_name, SETTINGS[section][setting]["default_value"])
			ProjectSettings.set_as_basic(setting_name, SETTINGS[section][setting]["is_basic"])

			var error : int = ProjectSettings.save()
			if not error == OK:
				push_error("[EPMP] Error %s while saving project settings." % error_string(error))

func _remove_project_settings() -> void:
	for section : String in SETTINGS:
		for setting : String in SETTINGS[section]:
			var setting_name : String = "%s/%s/%s" % [PLUGIN_NAME, section, setting]
			if ProjectSettings.has_setting(setting_name):
				ProjectSettings.set_setting(setting_name, null)

			var error : int = ProjectSettings.save()
			if not error == OK:
				push_error("[EPMP] Error %s while saving project settings." % error_string(error))

func check_for_steam() -> void:
	if not ProjectSettings.get_setting("easy_peasy_multiplayer/steam/enable_steam", false): return
	
	var godotsteam_exists := DirAccess.dir_exists_absolute("res://addons/godotsteam/")

	if not godotsteam_exists:
		var dialog := AcceptDialog.new()
		dialog.title = "Missing Required Dependencies"
		dialog.dialog_text = "You are missing the following dependencies required for certain features of this addon to function: \n"
		if not godotsteam_exists:
			dialog.dialog_text += "GodotSteam"
		
		# Disable the plugin when the user presses OK
		dialog.confirmed.connect(
			func():
				ProjectSettings.set_setting("easy_peasy_multiplayer/steam/enable_steam", false)
		)

		EditorInterface.popup_dialog_centered(dialog)

func _on_settings_changed() -> void:
	check_for_steam()