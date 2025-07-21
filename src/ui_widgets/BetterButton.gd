@icon("res://godot_only/icons/BetterButton.svg")
class_name BetterButton extends Button
## A regular Button with some helpers for hover + press theming situations and shortcuts.

const HIGHLIGHT_TIME = 0.1

var just_pressed := false
var timer: SceneTreeTimer

## A shortcut that corresponds to the same action that this button does.
@export var action := ""


func _ready() -> void:
	if not action.is_empty() and not toggle_mode:
		pressed.connect(_on_pressed)


func _on_pressed() -> void:
	just_pressed = true
	set_deferred("just_pressed", false)
	HandlerGUI.throw_action_event(action)

func _unhandled_input(event: InputEvent) -> void:
	if action.is_empty() or toggle_mode:
		return
	
	if not just_pressed and ShortcutUtils.is_action_pressed(event, action):
		add_theme_color_override("icon_normal_color", get_theme_color("icon_pressed_color"))
		add_theme_color_override("icon_hover_color", get_theme_color("icon_pressed_color"))
		add_theme_stylebox_override("normal", get_theme_stylebox("pressed"))
		if is_instance_valid(timer):
			timer.timeout.disconnect(end_highlight)
		timer = get_tree().create_timer(HIGHLIGHT_TIME)
		timer.timeout.connect(end_highlight)

func end_highlight() -> void:
	remove_theme_color_override("icon_normal_color")
	remove_theme_color_override("icon_hover_color")
	remove_theme_stylebox_override("normal")
	timer = null
