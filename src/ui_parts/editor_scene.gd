extends PanelContainer

const TopAppBar = preload("res://src/ui_parts/top_app_bar.tscn")
const CodeEditorScene = preload("res://src/ui_parts/code_editor.tscn")
const InspectorScene = preload("res://src/ui_parts/inspector.tscn")
const ViewportScene = preload("res://src/ui_parts/display.tscn")


var main_container: BoxContainer
var main_splitter: SplitContainer


func _ready() -> void:
	Configs.layout_changed.connect(update_layout)
	Configs.orientation_changed.connect(update_orientation)
	update_layout()
	var version = JavaClassWrapper.wrap("android.os.Build$VERSION")
	if version: Configs.current_sdk = version.SDK_INT

func update_orientation():
	if Configs.current_orientation == Configs.orientation.PORTRAIT:
		main_container.vertical = true
		main_splitter.vertical = true
	else:
		main_container.vertical = false
		main_splitter.vertical = false

func update_layout() -> void:
	for child in get_children():
		child.queue_free()
	
	var side_panel_top := Configs.savedata.get_layout_parts(SaveData.LayoutLocation.SIDE_PANEL_TOP)
	var side_panel_bottom := Configs.savedata.get_layout_parts(SaveData.LayoutLocation.SIDE_PANEL_BOTTOM)
	
	var root_container = VBoxContainer.new()
	add_child(root_container)
	
	# Setup the top bar.
	root_container.add_child(TopAppBar.instantiate())
	
	# Create main container, it would contain side panel, viewport, and shortcut panel.
	main_container = BoxContainer.new()
	main_container.vertical = true
	main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_container.add_child(main_container)
	
	# Set up the main splitter.
	main_splitter = SplitContainer.new()
	main_splitter.vertical = true
	main_splitter.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	main_splitter.touch_dragger_enabled = true
	main_splitter.split_offset = Configs.savedata.main_splitter_offset
	main_splitter.dragged.connect(_on_main_splitter_dragged)
	main_splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_child(main_splitter)
	
	var side_panel_margin_container := MarginContainer.new()
	side_panel_margin_container.begin_bulk_theme_override()
	side_panel_margin_container.add_theme_constant_override("margin_top", 6)
	side_panel_margin_container.add_theme_constant_override("margin_bottom", 3)
	side_panel_margin_container.add_theme_constant_override("margin_left", 6)
	side_panel_margin_container.add_theme_constant_override("margin_right", 6)
	side_panel_margin_container.end_bulk_theme_override()
	main_splitter.add_child(side_panel_margin_container)
	
	var main_view_margin_container := MarginContainer.new()
	main_view_margin_container.add_theme_constant_override("margin_top", 3)
	main_view_margin_container.add_child(create_layout_node(Utils.LayoutPart.VIEWPORT))
	main_splitter.add_child(main_view_margin_container)
	
	var side_panel_vbox := VBoxContainer.new()
	side_panel_vbox.add_theme_constant_override("separation", 6)
	side_panel_margin_container.add_child(side_panel_vbox)
	
	if not side_panel_top.is_empty() and not side_panel_bottom.is_empty():
		# Layout parts both on top and on the bottom.
		var side_panel_split_container := VSplitContainer.new()
		side_panel_split_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side_panel_split_container.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
		side_panel_split_container.touch_dragger_enabled = true
		side_panel_split_container.split_offset = Configs.savedata.side_panel_splitter_offset
		side_panel_split_container.dragged.connect(_on_side_panel_splitter_dragged)
		side_panel_split_container.add_child(create_layout_node(side_panel_top[0]))
		side_panel_split_container.add_child(create_layout_node(side_panel_bottom[0]))
		side_panel_vbox.add_child(side_panel_split_container)
	elif side_panel_top.size() == 2 or side_panel_bottom.size() == 2:
		# Tabs for the different layout parts.
		var layout_parts := side_panel_top if side_panel_bottom.is_empty() else side_panel_bottom
		var vbox := VBoxContainer.new()
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var buttons_hbox := HBoxContainer.new()
		buttons_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buttons_hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(buttons_hbox)
		
		var layout_nodes: Dictionary[Utils.LayoutPart, Node] = {}
		for part in layout_parts:
			var layout_node := create_layout_node(part)
			layout_nodes[part] = layout_node
			layout_node.hide()
			vbox.add_child(layout_node)
		
		var btn_group := ButtonGroup.new()
		for i in layout_parts.size():
			var part := layout_parts[i]
			var btn := Button.new()
			# Make the text update when the language changes.
			var set_btn_text_func := func() -> void:
					btn.text = TranslationUtils.get_layout_part_name(part)
			Configs.language_changed.connect(set_btn_text_func)
			set_btn_text_func.call()
			# Set up other button properties.
			btn.toggle_mode = true
			btn.icon = Utils.get_layout_part_icon(part)
			btn.theme_type_variation = "FlatButton"
			btn.focus_mode = Control.FOCUS_NONE
			btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
			btn.button_group = btn_group
			for node_part in layout_nodes:
				btn.toggled.connect(func(_toggled_on: bool) -> void:
						layout_nodes[node_part].visible = (node_part == part))
			if part == Utils.LayoutPart.INSPECTOR:
				State.requested_scroll_to_selection.connect(
						btn.set_pressed.bind(true).unbind(2))
			buttons_hbox.add_child(btn)
			if i == 0:
				btn.button_pressed = true
				layout_nodes[part].show()
		side_panel_vbox.add_child(vbox)
	else:
		# Layout parts disabled.
		if not side_panel_top.is_empty():
			side_panel_vbox.add_child(create_layout_node(side_panel_top[0]))
		elif not side_panel_bottom.is_empty():
			side_panel_vbox.add_child(create_layout_node(side_panel_bottom[0]))

func _on_main_splitter_dragged(offset: int) -> void:
	Configs.savedata.main_splitter_offset = offset

func _on_side_panel_splitter_dragged(offset: int) -> void:
	Configs.savedata.side_panel_splitter_offset = offset


func create_layout_node(layout_part: Utils.LayoutPart) -> Node:
	match layout_part:
		Utils.LayoutPart.CODE_EDITOR: return CodeEditorScene.instantiate()
		Utils.LayoutPart.INSPECTOR: return InspectorScene.instantiate()
		Utils.LayoutPart.VIEWPORT: return ViewportScene.instantiate()
		_: return Control.new()
