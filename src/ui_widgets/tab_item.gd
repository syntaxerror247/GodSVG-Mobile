extends PanelContainer

const PreviewRectScene = preload("res://src/ui_widgets/preview_rect.tscn")

@onready var title: Label = $VBoxContainer/HBoxContainer/title
@onready var path = $VBoxContainer/path
@onready var close_button: Button = $VBoxContainer/HBoxContainer/close

func setup(tab_title: String, svg_text: String, is_active: bool = false) -> void:
	await get_tree().process_frame
	title.text = tab_title
	highlight_active(is_active)
	var preview_rect := PreviewRectScene.instantiate()
	$VBoxContainer/HBoxContainer.add_sibling(preview_rect)
	preview_rect.custom_minimum_size = Vector2(96, 96)
	preview_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_rect.setup_svg_without_dimensions(svg_text)

func highlight_active(is_active: bool) -> void:
	pass

func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.is_pressed() and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		Configs.savedata.set_active_tab_index(get_index())
		print("tab selected: ", get_index())
	

func _on_close_pressed() -> void:
	FileUtils.close_tabs(get_index())
	
