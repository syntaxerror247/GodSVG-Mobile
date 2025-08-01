extends Button

func _ready() -> void:
	Configs.active_tab_status_changed.connect(update_file_button)
	Configs.active_tab_changed.connect(update_file_button)
	pressed.connect(_on_file_button_pressed)
	update_file_button()

func _on_file_button_pressed() -> void:
	var btn_array: Array[Button] = []
	btn_array.append(ContextPopup.create_shortcut_button("save"))
	btn_array.append(ContextPopup.create_shortcut_button("save_as", false,
			Translator.translate("Save SVG as…")))
	btn_array.append(ContextPopup.create_shortcut_button("reset_svg",
			FileUtils.compare_svg_to_disk_contents() != FileUtils.FileState.DIFFERENT))
	btn_array.append(ContextPopup.create_shortcut_button("open_externally",
			not FileAccess.file_exists(Configs.savedata.get_active_tab().svg_file_path)))
	btn_array.append(ContextPopup.create_shortcut_button("open_in_folder",
			not FileAccess.file_exists(Configs.savedata.get_active_tab().svg_file_path)))
	
	var context_popup := ContextPopup.new()
	context_popup.setup(btn_array, true, size.x, -1, PackedInt32Array([2]))
	HandlerGUI.popup_under_rect_center(context_popup, get_global_rect(), get_viewport())

func update_file_button() -> void:
	var transient_tab_path := State.transient_tab_path
	text = transient_tab_path.get_file() if not transient_tab_path.is_empty() else\
			Configs.savedata.get_active_tab().presented_name
	Utils.set_max_text_width(self, 140.0, 12.0)
