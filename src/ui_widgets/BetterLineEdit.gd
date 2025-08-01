@icon("res://godot_only/icons/BetterLineEdit.svg")
class_name BetterLineEdit extends LineEdit
## A LineEdit with a few tweaks to make it nicer to use.

var original_selection_color: Color

## Emitted when Esc is pressed to cancel the current text change.
signal text_change_canceled

var _hovered := false

## When turned on, uses the mono font for the tooltip.
@export var mono_font_tooltip := false

func _set(property: StringName, value: Variant) -> bool:
	if property == &"editable" and editable != value:
		editable = value
		sync_theming()
		return true
	return false

func _init() -> void:
	# Solves an issue where Ctrl+S would type an "s" and handle the input.
	# We want anything with Ctrl to not be handled, but other keys to still be handled.
	set_process_unhandled_key_input(false)
	
	context_menu_enabled = false
	caret_blink = true
	caret_blink_interval = 0.6
	focus_entered.connect(_on_base_class_focus_entered)
	focus_exited.connect(_on_base_class_focus_exited)
	mouse_exited.connect(_on_base_class_mouse_exited)
	text_submitted.connect(release_focus.unbind(1))
	original_selection_color = get_theme_color("selection_color")
	Configs.theme_changed.connect(sync_theming)
	sync_theming()

func sync_theming() -> void:
	if editable:
		add_theme_color_override("selection_color", original_selection_color)
	else:
		add_theme_color_override("selection_color", get_theme_color("disabled_selection_color"))

var first_click := false
var text_before_focus := ""
var popup_level := -1  # Set when focused, as it can't be focused unless it's top level.

func _on_base_class_focus_entered() -> void:
	# Hack to check if focus entered was from a mouse click.
	if get_global_rect().has_point(get_viewport().get_mouse_position()) and\
	Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		first_click = true
	else:
		select_all()
	text_before_focus = text
	popup_level = HandlerGUI.popup_stack.size()

func _on_base_class_focus_exited() -> void:
	first_click = false
	deselect()
	if Input.is_action_pressed("ui_cancel"):
		text = text_before_focus
		text_change_canceled.emit()
	elif not Input.is_action_pressed("ui_accept"):
		# If ui_accept is pressed, text_submitted gets emitted anyway.
		text_submitted.emit(text)

func _on_base_class_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _draw() -> void:
	if _hovered and editable and has_theme_stylebox("hover"):
		draw_style_box(get_theme_stylebox("hover"), Rect2(Vector2.ZERO, size))

func _make_custom_tooltip(for_text: String) -> Object:
	if mono_font_tooltip:
		var label := Label.new()
		label.add_theme_font_override("font", ThemeUtils.mono_font)
		label.text = for_text
		return label
	else:
		return null


func _input(event: InputEvent) -> void:
	if not has_focus():
		return
	
	if event is InputEventMouseButton and (event.button_index in [MOUSE_BUTTON_LEFT,
	MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]):
		if event.is_pressed() and not get_global_rect().has_point(event.position) and\
		popup_level == HandlerGUI.popup_stack.size():
			release_focus()
		elif event.is_released() and first_click and not has_selection():
			first_click = false
			select_all()
	if first_click:
		first_click = false
		select_all()

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_all"):
		menu_option(MENU_SELECT_ALL)
		accept_event()
		return
	
	if event.is_action_pressed("ui_cancel"):
		release_focus()
		accept_event()
		return
	
	mouse_filter = Utils.mouse_filter_pass_non_drag_events(event)
	
	if event is InputEventMouseMotion and event.button_mask == 0:
		_hovered = true
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and\
	event.is_pressed():
		grab_focus()
		var btn_arr: Array[Button] = []
		var separator_arr: Array[int] = []
		
		var is_text_empty := text.is_empty()
		
		if editable:
			btn_arr.append(ContextPopup.create_shortcut_button("ui_undo", not has_undo()))
			btn_arr.append(ContextPopup.create_shortcut_button("ui_redo", not has_redo()))
			if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
				separator_arr = [2]
				btn_arr.append(ContextPopup.create_shortcut_button("ui_cut", is_text_empty))
				btn_arr.append(ContextPopup.create_shortcut_button("ui_copy", is_text_empty))
				btn_arr.append(ContextPopup.create_shortcut_button("ui_paste",
						not Utils.has_clipboard_web_safe()))
		else:
			btn_arr.append(ContextPopup.create_shortcut_button("ui_copy", is_text_empty))
		
		var vp := get_viewport()
		var context_popup := ContextPopup.new()
		context_popup.setup(btn_arr, true, -1, -1, separator_arr)
		HandlerGUI.popup_under_pos(context_popup, vp.get_mouse_position(), vp)
		accept_event()
		# Wow, no way to find out the column of a given click? Okay...
		# TODO Make it so LineEdit caret automatically moves to the clicked position
		# to finish the right-click logic.
