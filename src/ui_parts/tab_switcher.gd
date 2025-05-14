extends PanelContainer

const TabItem = preload("res://src/ui_widgets/tab_item.tscn")

@onready var tab_container: VBoxContainer = $VBoxContainer3/ScrollContainer/VBoxContainer

func animate_in() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position:x", 0, 0.3).from(-200)

func animate_out() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "position:x", -200, 0.3)
	await tween.finished
	get_parent().hide()


func _ready() -> void:
	get_parent().gui_input.connect(_on_parent_gui_input)
	Configs.tab_removed.connect(refresh_tabs)

func refresh_tabs() -> void:
	print("Refreshing tabs...")
	for i in tab_container.get_children():
		i.queue_free()

	var has_transient_tab := not State.transient_tab_path.is_empty()
	var total_tabs := Configs.savedata.get_tab_count()

	# If there's a transient tab, we want to draw one more
	if has_transient_tab:
		total_tabs += 1

	for tab_index in total_tabs:
		var is_transient := (has_transient_tab and tab_index == total_tabs)
		var tab_name := ""
		var svg_text := ""

		if is_transient:
			tab_name = State.transient_tab_path.get_file()
		else:
			var tab_data = Configs.savedata.get_tab(tab_index)
			tab_name = tab_data.presented_name
			svg_text = FileAccess.get_file_as_string(TabData.get_edited_file_path_for_id(tab_data.id))
			if tab_data.marked_unsaved:
				tab_name = "* " + tab_name

		var is_active := (
			(is_transient and has_transient_tab) or
			(not is_transient and tab_index == Configs.savedata.get_active_tab_index())
		)

		var tab = TabItem.instantiate()
		tab_container.add_child(tab)
		tab.call_deferred("setup", tab_name, svg_text, is_active)

func _on_new_tab_pressed() -> void:
	Configs.savedata.add_empty_tab()
	call_deferred("refresh_tabs")

func _on_tab_selected(index: int) -> void:
	print("Tab selected:", index)
	Configs.savedata.set_active_tab_index(index)
	refresh_tabs()

func _on_parent_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		animate_out()
