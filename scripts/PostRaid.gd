extends Control

## Post-raid results screen — death or extraction outcome.

@onready var title_label: Label = %TitleLabel
@onready var run_label: Label = %RunLabel
@onready var stats_text: RichTextLabel = %StatsText
@onready var items_text: RichTextLabel = %ItemsText
@onready var xp_label: Label = %XPLabel
@onready var return_button: Button = %ReturnButton


func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)
	_display_results()


func _display_results() -> void:
	run_label.text = "RUN #%d" % GameData.run_count

	if GameData.is_dead:
		_show_death()
	else:
		_show_extraction()


func _show_death() -> void:
	title_label.text = "K I A"
	title_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

	var score := GameData.run_score
	var xp_earned := int(score * 0.2)

	stats_text.clear()
	stats_text.push_color(Color(0.7, 0.7, 0.7))
	stats_text.add_text("Turns survived: %d\n" % GameData.death_turn)
	stats_text.add_text("Items lost: %d\n" % GameData.inventory.size())
	stats_text.add_text("Loot value: %d\n" % score)
	stats_text.pop()
	stats_text.push_color(Color(1, 0.3, 0.3))
	stats_text.add_text("\nAll items lost.")
	stats_text.pop()

	items_text.clear()
	if GameData.inventory.size() > 0:
		items_text.push_color(Color(0.5, 0.5, 0.5))
		items_text.add_text("Lost:\n")
		for item in GameData.inventory:
			items_text.add_text("  x %s\n" % item["name"])
		items_text.pop()

	xp_label.text = "You keep: %d XP (20%% salvage)" % xp_earned


func _show_extraction() -> void:
	title_label.text = "E X T R A C T E D"
	title_label.add_theme_color_override("font_color", Color(0, 1, 0.25))

	var score := GameData.run_score

	stats_text.clear()
	stats_text.push_color(Color(0.7, 0.7, 0.7))
	stats_text.add_text("Turns used: %d / 30\n" % GameData.current_turn)
	stats_text.add_text("Items extracted: %d\n" % GameData.inventory.size())
	stats_text.add_text("Total value: %d\n" % score)
	stats_text.pop()

	items_text.clear()
	if GameData.inventory.size() > 0:
		items_text.push_color(Color(1, 0.702, 0.278))
		items_text.add_text("Secured:\n")
		for item in GameData.inventory:
			var extra := ""
			if item.get("type") == "weapon":
				extra = " [DMG:%d]" % item.get("damage", 0)
			items_text.add_text("  + %s (%dxp)%s\n" % [item["name"], item["value"], extra])
		items_text.pop()

	xp_label.text = "XP earned: %d" % score


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
