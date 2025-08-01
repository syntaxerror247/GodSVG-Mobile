# An editor to be tied to a pathdata attribute.
extends VBoxContainer

var element: Element
const attribute_name = "d"  # Never propagates.

# So, about this editor. Most of this code is about implementing a huge optimization.
# All the path commands are a single node that draws fake-outs in order to prevent
# adding too many nodes to the scene tree. The real controls are only created when
# necessary, such as when hovered or focused.

const STRIP_HEIGHT = 22.0

signal focused

const MiniNumberFieldScene = preload("mini_number_field.tscn")
const FlagFieldScene = preload("flag_field.tscn")

const more_icon = preload("res://assets/icons/SmallMore.svg")
const plus_icon = preload("res://assets/icons/Plus.svg")

var mini_line_edit_stylebox := get_theme_stylebox("normal", "MiniLineEdit")
var mini_line_edit_font_size := get_theme_font_size("font_size", "MiniLineEdit")
var mini_line_edit_font_color := get_theme_color("font_color", "MiniLineEdit")

@onready var line_edit: LineEdit = $LineEdit
@onready var commands_container: Control = $Commands

# Variables around the big optimization.
# The idea is that when the mouse enters a strip, it's remembered as hovered.
# If a numfield is focused, its strip is remembered as focused.
# If a numfield is hovered and then focused, the controls aren't re-added,
# instead, the references are moved from the hovered to the focused fields array.
# If a focused field is hovered, no hovered fields are added.
var hovered_idx := -1
var focused_idx := -1
var hovered_strip: Control
var focused_strip: Control

var current_selections: Array[int] = []
var current_hovered := -1
@onready var ci := commands_container.get_canvas_item()
var add_move_button: Control


func set_value(new_value: String, save := false) -> void:
	element.set_attribute(attribute_name, new_value)
	sync()
	if save:
		State.queue_svg_save()


func setup() -> void:
	Configs.language_changed.connect(sync_localization)
	sync_localization()
	Configs.theme_changed.connect(sync_theming)
	sync_theming()
	sync()
	element.attribute_changed.connect(_on_element_attribute_changed)
	line_edit.tooltip_text = attribute_name
	line_edit.text_submitted.connect(set_value.bind(true))
	line_edit.text_changed.connect(setup_font)
	line_edit.text_change_canceled.connect(func() -> void: setup_font(line_edit.text))
	line_edit.text_change_canceled.connect(sync)
	line_edit.focus_entered.connect(_on_line_edit_focus_entered)
	commands_container.draw.connect(_commands_draw)
	commands_container.gui_input.connect(_on_commands_gui_input)
	commands_container.mouse_exited.connect(_on_commands_mouse_exited)
	State.hover_changed.connect(_on_selections_or_hover_changed)
	State.selection_changed.connect(_on_selections_or_hover_changed)
	# So, the reason we need this is quite complicated. We need to know
	# the current_selections and current_hovered at the time this widget is created.
	# This is because the widget can sometimes be created before they are cleared
	# from a past state of the SVG. So we trigger this method to update those.
	_on_selections_or_hover_changed()


func get_inner_rect(index: int) -> Rect2:
	return Rect2(commands_container.position + Vector2(0, STRIP_HEIGHT * index),
			Vector2(commands_container.size.x, STRIP_HEIGHT))


func _on_element_attribute_changed(attribute_changed: String) -> void:
	if attribute_name == attribute_changed:
		sync()

func sync_localization() -> void:
	line_edit.placeholder_text = Translator.translate("No path data")

func sync_theming() -> void:
	mini_line_edit_stylebox = get_theme_stylebox("normal", "MiniLineEdit")
	mini_line_edit_font_size = get_theme_font_size("font_size", "MiniLineEdit")
	mini_line_edit_font_color = get_theme_color("font_color", "MiniLineEdit")
	queue_redraw()

func _on_line_edit_focus_entered() -> void:
	focused.emit()

func setup_font(new_text: String) -> void:
	if new_text.is_empty():
		line_edit.add_theme_font_override("font", ThemeUtils.regular_font)
	else:
		line_edit.remove_theme_font_override("font")

var last_synced_value := " "  # Invalid initial string.

func sync() -> void:
	var new_value := element.get_attribute_value(attribute_name)
	if last_synced_value == new_value:
		return
	last_synced_value = new_value
	
	line_edit.text = new_value
	setup_font(new_value)
	# A plus button for adding a move command if empty.
	var cmd_count: int = element.get_attribute(attribute_name).get_command_count()
	if cmd_count == 0 and not is_instance_valid(add_move_button):
		add_move_button = Button.new()
		add_move_button.icon = plus_icon
		add_move_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add_move_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		add_move_button.focus_mode = Control.FOCUS_NONE
		add_move_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_move_button.theme_type_variation = "FlatButton"
		add_child(add_move_button)
		add_move_button.pressed.connect(_on_add_move_button_pressed)
	elif cmd_count != 0 and is_instance_valid(add_move_button):
		add_move_button.queue_free()
	# Rebuild the path commands.
	commands_container.custom_minimum_size.y = cmd_count * STRIP_HEIGHT
	if get_rect().has_point(get_local_mouse_position()):
		HandlerGUI.throw_mouse_motion_event()
	if hovered_idx >= cmd_count:
		activate_hovered(-1)
	reactivate_hovered()
	commands_container.queue_redraw()


func update_parameter(new_value: float, property: String, idx: int) -> void:
	element.get_attribute(attribute_name).set_command_property(idx, property, new_value)
	State.queue_svg_save()

func _on_relative_button_pressed() -> void:
	element.get_attribute(attribute_name).toggle_relative_command(hovered_idx)
	State.queue_svg_save()

func _on_add_move_button_pressed() -> void:
	element.get_attribute(attribute_name).insert_command(0, "M")
	State.queue_svg_save()


# Path commands editor orchestration.

func _on_selections_or_hover_changed() -> void:
	var new_selections: Array[int] = []
	if State.semi_selected_xid == element.xid:
		new_selections = State.inner_selections.duplicate()
	var new_hovered := -1
	if State.semi_hovered_xid == element.xid:
		new_hovered = State.inner_hovered
	# Only redraw if selections or hovered changed.
	if new_selections != current_selections:
		current_selections = new_selections
		commands_container.queue_redraw()
	if new_hovered != current_hovered:
		current_hovered = new_hovered
		commands_container.queue_redraw()

func _on_commands_mouse_exited() -> void:
	var cmd_idx := State.inner_hovered
	if State.semi_hovered_xid == element.xid:
		activate_hovered(-1)
	State.remove_hovered(element.xid, cmd_idx)


# Prevents buttons from selecting a whole subpath when double-clicked.
func _eat_double_clicks(event: InputEvent, button: Button) -> void:
	if hovered_idx >= 0 and event is InputEventMouseButton and event.double_click:
		button.accept_event()
		if event.is_pressed():
			if button.toggle_mode:
				button.toggled.emit(not button.button_pressed)
			else:
				button.pressed.emit()

func _on_commands_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	
	var cmd_idx := -1
	var event_pos: Vector2 = event.position
	if Rect2(Vector2.ZERO, commands_container.size).has_point(event_pos):
		cmd_idx = int(event_pos.y / STRIP_HEIGHT)
	
	if event is InputEventMouseMotion and event.button_mask == 0:
		if cmd_idx >= 0:
			State.set_hovered(element.xid, cmd_idx)
		else:
			State.remove_hovered(element.xid, cmd_idx)
		activate_hovered(cmd_idx)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if event.double_click:
					var subpath_range: Vector2i =\
							element.get_attribute(attribute_name).get_subpath(cmd_idx)
					State.normal_select(element.xid, subpath_range.x)
					State.shift_select(element.xid, subpath_range.y)
				elif event.is_command_or_control_pressed():
					State.ctrl_select(element.xid, cmd_idx)
				elif event.shift_pressed:
					State.shift_select(element.xid, cmd_idx)
				else:
					State.normal_select(element.xid, cmd_idx)
			elif event.is_released() and not event.shift_pressed and\
			not event.is_command_or_control_pressed() and not event.double_click and\
			State.inner_selections.size() > 1 and cmd_idx in State.inner_selections:
				State.normal_select(element.xid, cmd_idx)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
			if State.semi_selected_xid != element.xid or\
			not cmd_idx in State.inner_selections:
				State.normal_select(element.xid, cmd_idx)
			# Popup the actions.
			var viewport := get_viewport()
			var popup_pos := viewport.get_mouse_position()
			HandlerGUI.popup_under_pos(State.get_selection_context(
					HandlerGUI.popup_under_pos.bind(popup_pos, viewport),
					Utils.LayoutPart.INSPECTOR), popup_pos, viewport)


func _commands_draw() -> void:
	RenderingServer.canvas_item_clear(ci)
	for i: int in element.get_attribute(attribute_name).get_command_count():
		var v_offset := STRIP_HEIGHT * i
		# Draw the background hover or selection stylebox.
		var hovered := State.is_hovered(element.xid, i)
		var selected := State.is_selected(element.xid, i)
		if selected or hovered:
			var stylebox := StyleBoxFlat.new()
			stylebox.set_corner_radius_all(3)
			if hovered and selected:
				stylebox.bg_color = ThemeUtils.soft_hover_pressed_overlay_color
			elif selected:
				stylebox.bg_color = ThemeUtils.soft_pressed_overlay_color
			elif hovered:
				stylebox.bg_color = ThemeUtils.soft_hover_overlay_color
			stylebox.draw(ci, Rect2(Vector2(0, v_offset), Vector2(commands_container.size.x,
					STRIP_HEIGHT)))
		# Draw the child controls. They are going to be drawn, not added as a node unless
		# the mouse hovers them. This is a hack to significantly improve performance.
		if i == hovered_idx or i == focused_idx:
			continue
		
		var cmd: PathCommand = element.get_attribute(attribute_name).get_command(i)
		var cmd_char := cmd.command_char
		# Draw the action button.
		more_icon.draw_rect(ci, Rect2(Vector2(commands_container.size.x - 19, 4 + v_offset),
				Vector2(14, 14)), false, ThemeUtils.icon_normal_color)
		# Draw the relative/absolute button.
		var relative_stylebox := get_theme_stylebox("normal", "PathCommandAbsoluteButton") if\
				Utils.is_string_upper(cmd_char) else get_theme_stylebox("normal", "PathCommandRelativeButton")
		relative_stylebox.draw(ci, Rect2(Vector2(3, 2 + v_offset),
				Vector2(18, STRIP_HEIGHT - 4)))
		ThemeUtils.mono_font.draw_string(ci, Vector2(6, v_offset + STRIP_HEIGHT - 6),
				cmd_char, HORIZONTAL_ALIGNMENT_CENTER, 12, 13, ThemeUtils.text_color)
		# Draw the fields.
		var rect := Rect2(Vector2(25, 2 + v_offset), Vector2(44, 18))
		match cmd_char.to_upper():
			"A":
				# Because of the flag editors, the procedure is more complex.
				draw_numfield(rect, "rx", cmd)
				rect.position.x = rect.end.x + 3
				draw_numfield(rect, "ry", cmd)
				rect.position.x = rect.end.x + 4
				draw_numfield(rect, "rot", cmd)
				rect.position.x = rect.end.x + 4
				rect.size.x = 19
				var flag_field := FlagFieldScene.instantiate()
				var is_large_arc: bool = (cmd.large_arc_flag == 0)
				var is_sweep: bool = (cmd.sweep_flag == 0)
				flag_field.get_theme_stylebox("normal" if is_large_arc\
						else "pressed").draw(ci, rect)
				ThemeUtils.mono_font.draw_string(ci, rect.position + Vector2(5, 14),
						String.num_uint64(cmd.large_arc_flag), HORIZONTAL_ALIGNMENT_LEFT,
						rect.size.x, 14, flag_field.get_theme_color(
								"font_color" if is_large_arc else "font_pressed_color"))
				rect.position.x = rect.end.x + 4
				flag_field.get_theme_stylebox("normal" if is_sweep
						else "pressed").draw(ci, rect)
				ThemeUtils.mono_font.draw_string(ci, rect.position + Vector2(5, 14),
						String.num_uint64(cmd.sweep_flag), HORIZONTAL_ALIGNMENT_LEFT,
						rect.size.x, 14, flag_field.get_theme_color("font_color" if is_sweep\
						else "font_pressed_color"))
				flag_field.free()
				rect.position.x = rect.end.x + 4
				rect.size.x = 44
				draw_numfield(rect, "x", cmd)
				rect.position.x = rect.end.x + 3
				draw_numfield(rect, "y", cmd)
			"C": draw_numfield_arr(rect, [3, 4, 3, 4, 3], ["x1", "y1", "x2", "y2", "x", "y"],
					cmd)
			"Q": draw_numfield_arr(rect, [3, 4, 3], ["x1", "y1", "x", "y"], cmd)
			"S": draw_numfield_arr(rect, [3, 4, 3], ["x2", "y2", "x", "y"], cmd)
			"M", "L", "T": draw_numfield_arr(rect, [3], ["x", "y"], cmd)
			"H": draw_numfield(rect, "x", cmd)
			"V": draw_numfield(rect, "y", cmd)

func draw_numfield(rect: Rect2, property: String, path_command: PathCommand) -> void:
	mini_line_edit_stylebox.draw(ci, rect)
	ThemeUtils.mono_font.draw_string(ci, rect.position + Vector2(3, 13),
			NumstringParser.basic_num_to_text(path_command.get(property)),
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6,
			mini_line_edit_font_size, mini_line_edit_font_color)

func draw_numfield_arr(first_rect: Rect2, spacings: Array, names: PackedStringArray,
path_command: PathCommand) -> void:
	draw_numfield(first_rect, names[0], path_command)
	for i in spacings.size():
		first_rect.position.x = first_rect.end.x + spacings[i]
		draw_numfield(first_rect, names[i + 1], path_command)


func activate_hovered(idx: int) -> void:
	if idx != hovered_idx and\
	idx < element.get_attribute(attribute_name).get_command_count():
		activate_hovered_shared_logic(idx)

func reactivate_hovered() -> void:
	activate_hovered_shared_logic(hovered_idx)

func activate_hovered_shared_logic(idx: int) -> void:
	if is_instance_valid(hovered_strip):
		hovered_strip.queue_free()
	if focused_idx != idx:
		hovered_strip = setup_path_command_controls(idx)
	hovered_idx = idx
	commands_container.queue_redraw()

func activate_focused(idx: int) -> void:
	if idx == focused_idx:
		return
	
	if idx == -1:
		if focused_idx == hovered_idx:
			hovered_strip = focused_strip
			focused_strip = null
		else:
			focused_strip.queue_free()
	elif idx == hovered_idx:
		if focused_idx >= 0:
			focused_strip.queue_free()
		focused_strip = hovered_strip
		hovered_strip = null
	else:
		focused_strip = setup_path_command_controls(idx)
	
	focused_idx = idx
	commands_container.queue_redraw()

func check_focused() -> void:
	for child in focused_strip.get_children():
		if child.has_focus():
			return
	activate_focused(-1)

func setup_path_command_controls(idx: int) -> Control:
	if idx < 0:
		return null
	
	var cmd: PathCommand = element.get_attribute(attribute_name).get_command(idx)
	var cmd_char := cmd.command_char
	var is_absolute := Utils.is_string_upper(cmd_char)
	
	var container := Control.new()
	container.position.y = idx * STRIP_HEIGHT
	container.size = Vector2(commands_container.size.x, STRIP_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	commands_container.add_child(container)
	# Setup the relative button.
	var relative_button := Button.new()
	relative_button.focus_mode = Control.FOCUS_NONE
	relative_button.mouse_filter = Control.MOUSE_FILTER_PASS
	relative_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	relative_button.add_theme_font_override("font", ThemeUtils.mono_font)
	relative_button.theme_type_variation = "PathCommandAbsoluteButton" if is_absolute else\
			"PathCommandRelativeButton"
	relative_button.text = cmd_char
	relative_button.tooltip_text = TranslationUtils.get_path_command_description(cmd_char)
	container.add_child(relative_button)
	relative_button.pressed.connect(_on_relative_button_pressed)
	relative_button.gui_input.connect(_eat_double_clicks.bind(relative_button))
	relative_button.position = Vector2(3, 2)
	relative_button.size = Vector2(STRIP_HEIGHT - 4, STRIP_HEIGHT - 4)
	# Setup the action button.
	var action_button := Button.new()
	action_button.icon = more_icon
	action_button.theme_type_variation = "FlatButton"
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.mouse_filter = Control.MOUSE_FILTER_PASS
	action_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	container.add_child(action_button)
	action_button.pressed.connect(_on_action_button_pressed.bind(action_button))
	action_button.gui_input.connect(_eat_double_clicks.bind(action_button))
	action_button.position = Vector2(commands_container.size.x - 21, 2)
	action_button.size = Vector2(STRIP_HEIGHT - 4, STRIP_HEIGHT - 4)
	# Setup the fields.
	var fields: Array[Control] = []
	var spacings := PackedInt32Array()
	var property_names: PackedStringArray = []
	match cmd_char.to_upper():
		"A":
			var field_rx: BetterLineEdit = numfield(idx)
			var field_ry: BetterLineEdit = numfield(idx)
			var field_rot: BetterLineEdit = numfield(idx)
			field_rx.mode = field_rx.Mode.ONLY_POSITIVE
			field_ry.mode = field_ry.Mode.ONLY_POSITIVE
			field_rot.mode = field_rot.Mode.HALF_ANGLE
			var field_large_arc := FlagFieldScene.instantiate()
			var field_sweep := FlagFieldScene.instantiate()
			field_large_arc.gui_input.connect(_eat_double_clicks.bind(field_large_arc))
			field_sweep.gui_input.connect(_eat_double_clicks.bind(field_sweep))
			fields = [field_rx, field_ry, field_rot, field_large_arc, field_sweep,
					numfield(idx), numfield(idx)]
			spacings = PackedInt32Array([3, 4, 4, 4, 4, 3])
			property_names = PackedStringArray(
					["rx", "ry", "rot", "large_arc_flag", "sweep_flag", "x", "y"])
		"C":
			fields = [numfield(idx), numfield(idx), numfield(idx), numfield(idx),
					numfield(idx), numfield(idx)]
			spacings = PackedInt32Array([3, 4, 3, 4, 3])
			property_names = PackedStringArray(["x1", "y1", "x2", "y2", "x", "y"])
		"Q":
			fields = [numfield(idx), numfield(idx), numfield(idx), numfield(idx)]
			spacings = PackedInt32Array([3, 4, 3])
			property_names = PackedStringArray(["x1", "y1", "x", "y"])
		"S":
			fields = [numfield(idx), numfield(idx), numfield(idx), numfield(idx)]
			spacings = PackedInt32Array([3, 4, 3])
			property_names = PackedStringArray(["x2", "y2", "x", "y"])
		"M", "L", "T":
			fields = [numfield(idx), numfield(idx)]
			spacings = PackedInt32Array([3])
			property_names = PackedStringArray(["x", "y"])
		"H":
			fields = [numfield(idx)]
			property_names = PackedStringArray(["x"])
		"V":
			fields = [numfield(idx)]
			property_names = PackedStringArray(["y"])
	# Setup the fields.
	if not fields.is_empty():
		for i in fields.size():
			var field := fields[i]
			var property_name := property_names[i]
			field.set_value(cmd.get(property_name))
			field.tooltip_text = property_name
			field.value_changed.connect(update_parameter.bind(property_name, idx))
			field.focus_entered.connect(activate_focused.bind(idx))
			field.focus_exited.connect(check_focused, CONNECT_DEFERRED)
			container.add_child(field)
			field.position.y = 2
		fields[0].position.x = 25
		for i in fields.size() - 1:
			fields[i + 1].position.x = fields[i].get_end().x + spacings[i]
	return container


func numfield(cmd_idx: int) -> BetterLineEdit:
	var new_field := MiniNumberFieldScene.instantiate()
	new_field.focus_entered.connect(State.normal_select.bind(element.xid, cmd_idx))
	return new_field


func _on_action_button_pressed(action_button_ref: Button) -> void:
	# Update the selection immediately, since if this path command is
	# in a multi-selection, only the mouse button release would change the selection.
	State.normal_select(element.xid, hovered_idx)
	var viewport := get_viewport()
	var action_button_rect := action_button_ref.get_global_rect()
	HandlerGUI.popup_under_rect_center(State.get_selection_context(
			HandlerGUI.popup_under_rect_center.bind(action_button_rect, viewport),
			Utils.LayoutPart.INSPECTOR), action_button_rect, viewport)
