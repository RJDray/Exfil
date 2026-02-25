extends Control

## Home base — stash management, XP display, workbench, upgrades.

@onready var xp_label: Label = %XPLabel
@onready var stash_label: Label = %StashLabel
@onready var stash_list: RichTextLabel = %StashList
@onready var workbench_label: Label = %WorkbenchLabel
@onready var workbench_container: VBoxContainer = %WorkbenchContainer
@onready var unlock_label: Label = %UnlockLabel
@onready var ready_button: Button = %ReadyButton
@onready var status_label: Label = %StatusLabel

var selected_stash_index: int = -1


func _ready() -> void:
	ready_button.pressed.connect(_on_ready_pressed)
	_update_display()


func _update_display() -> void:
	xp_label.text = "TOTAL XP: %d" % GameData.total_xp
	stash_label.text = "STASH (%d / %d slots)" % [GameData.stash.size(), GameData.stash_slots]

	# Stash contents
	stash_list.clear()
	if GameData.stash.size() == 0:
		stash_list.push_color(Color(0.4, 0.4, 0.4))
		stash_list.add_text("Empty. Extract with loot to fill your stash.")
		stash_list.pop()
	else:
		for i in GameData.stash.size():
			var item: Dictionary = GameData.stash[i]
			var extra := ""
			if item.get("type") == "weapon":
				extra = " [DMG:%d]" % item.get("damage", 0)
			elif item.get("type") == "med":
				extra = " [HEAL:%d]" % item.get("heal", 0)
			stash_list.push_color(Color(1, 0.702, 0.278))
			stash_list.add_text(" %d. %s (%.1fkg, %dxp)%s" % [i + 1, item["name"], item["weight"], item["value"], extra])
			stash_list.pop()
			stash_list.newline()

	# Workbench — show breakdown buttons for stash items
	_update_workbench()

	# Unlock info
	var next_cost := GameData.get_next_slot_cost()
	if GameData.total_xp >= next_cost:
		unlock_label.text = "STASH UPGRADE AVAILABLE (%d XP)" % next_cost
		unlock_label.add_theme_color_override("font_color", Color(0, 1, 0.25))
	else:
		unlock_label.text = "Next stash slot: %d / %d XP" % [GameData.total_xp, next_cost]
		unlock_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	status_label.text = "Run #%d | Best: %d" % [GameData.run_count, GameData.best_score]


func _update_workbench() -> void:
	for child in workbench_container.get_children():
		child.queue_free()

	if GameData.stash.size() == 0:
		var lbl := Label.new()
		lbl.text = "No items to break down."
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		lbl.add_theme_font_size_override("font_size", 12)
		workbench_container.add_child(lbl)
		return

	for i in GameData.stash.size():
		var item: Dictionary = GameData.stash[i]
		# Don't show breakdown for basic components
		if item.get("type") == "component":
			continue
		var btn := Button.new()
		btn.text = "BREAK DOWN: %s" % item["name"]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_color_override("font_color", Color(1, 0.702, 0.278))
		btn.add_theme_font_size_override("font_size", 12)
		var idx := i
		btn.pressed.connect(func(): _break_down_item(idx))
		workbench_container.add_child(btn)


func _break_down_item(index: int) -> void:
	var item := GameData.remove_from_stash(index)
	if item.is_empty():
		return

	var components := ItemDatabase.break_down_item(item)
	for comp in components:
		GameData.add_to_stash(comp)

	var comp_names: Array = []
	for comp in components:
		comp_names.append(comp["name"])

	status_label.text = "Broke down %s → %s" % [item["name"], ", ".join(comp_names)]
	_update_display()


func _on_ready_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
