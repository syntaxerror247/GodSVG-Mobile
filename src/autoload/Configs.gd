# This singleton handles session data and settings.
extends Node

@warning_ignore("unused_signal")
signal highlighting_colors_changed
@warning_ignore("unused_signal")
signal snap_changed
@warning_ignore("unused_signal")
signal language_changed
@warning_ignore("unused_signal")
signal ui_scale_changed
@warning_ignore("unused_signal")
signal theme_changed
@warning_ignore("unused_signal")
signal shortcuts_changed
@warning_ignore("unused_signal")
signal basic_colors_changed
@warning_ignore("unused_signal")
signal handle_visuals_changed
@warning_ignore("unused_signal")
signal grid_color_changed
@warning_ignore("unused_signal")
signal shortcut_panel_changed
@warning_ignore("unused_signal")
signal active_tab_status_changed
@warning_ignore("unused_signal")
signal active_tab_reference_changed
@warning_ignore("unused_signal")
signal active_tab_changed
@warning_ignore("unused_signal")
signal tabs_changed
@warning_ignore("unused_signal")
signal tab_removed
@warning_ignore("unused_signal")
signal tab_selected(index: int)
@warning_ignore("unused_signal")
signal layout_changed
@warning_ignore("unused_signal")
signal orientation_changed

var current_sdk: int = -1

enum orientation {PORTRAIT, LANDSCAPE}
var current_orientation := orientation.PORTRAIT

func _ready() -> void:
	get_tree().root.size_changed.connect(check_orientation)

func check_orientation():
	var width = DisplayServer.window_get_size().x
	var height = DisplayServer.window_get_size().y

	var new_orientation: orientation
	if width > height:
		new_orientation = orientation.LANDSCAPE
	else:
		new_orientation = orientation.PORTRAIT

	if new_orientation != current_orientation:
		current_orientation = new_orientation
		orientation_changed.emit()


const savedata_path = "user://savedata.tres"
var savedata: SaveData:
	set(new_value):
		if savedata != new_value and is_instance_valid(new_value):
			savedata = new_value
			savedata.validate()
			savedata.changed_deferred.connect(save)


func save() -> void:
	ResourceSaver.save(savedata, savedata_path)


var default_shortcuts: Dictionary[String, Array] = {}

func _enter_tree() -> void:
	# Fill up the default shortcuts dictionary before the shortcuts are loaded.
	for action in ShortcutUtils.get_all_actions():
		if InputMap.has_action(action):
			default_shortcuts[action] = InputMap.action_get_events(action)
	load_config()
	ThemeUtils.generate_and_apply_theme()


func load_config() -> void:
	if not FileAccess.file_exists(savedata_path):
		reset_settings()
		return
	
	savedata = ResourceLoader.load(savedata_path)
	if not is_instance_valid(savedata):
		reset_settings()
		return
	
	post_load()


func reset_settings() -> void:
	savedata = SaveData.new()
	savedata.reset_to_default()
	savedata.language = "en"
	savedata.set_shortcut_panel_slots({ 0: "ui_undo", 1: "ui_redo", 2: "duplicate", 3: "save" })
	savedata.set_palettes([Palette.new("Pure", Palette.Preset.PURE)])
	save()
	post_load()

func post_load() -> void:
	savedata.get_active_tab().activate()
	sync_background_color()
	sync_locale()


func generate_highlighter() -> SVGHighlighter:
	var new_highlighter := SVGHighlighter.new()
	new_highlighter.symbol_color = Configs.savedata.highlighting_symbol_color
	new_highlighter.element_color = Configs.savedata.highlighting_element_color
	new_highlighter.attribute_color = Configs.savedata.highlighting_attribute_color
	new_highlighter.string_color = Configs.savedata.highlighting_string_color
	new_highlighter.comment_color = Configs.savedata.highlighting_comment_color
	new_highlighter.text_color = Configs.savedata.highlighting_text_color
	new_highlighter.cdata_color = Configs.savedata.highlighting_cdata_color
	new_highlighter.error_color = Configs.savedata.highlighting_error_color
	return new_highlighter


# Global effects from settings. Some of them should also be used on launch.

func sync_background_color() -> void:
	RenderingServer.set_default_clear_color(savedata.background_color)

func sync_locale() -> void:
	if not savedata.language in TranslationServer.get_loaded_locales():
		savedata.language = "en"
	else:
		TranslationServer.set_locale(savedata.language)
