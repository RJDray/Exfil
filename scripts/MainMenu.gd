extends Control

@onready var title_label: Label = %TitleLabel
@onready var run_label: Label = %RunLabel
@onready var score_label: Label = %ScoreLabel
@onready var begin_button: Button = %BeginButton
@onready var stash_button: Button = %StashButton
@onready var footer_label: Label = %FooterLabel


func _ready() -> void:
	_update_display()
	begin_button.pressed.connect(_on_begin_pressed)
	stash_button.pressed.connect(_on_stash_pressed)


func _update_display() -> void:
	run_label.text = "RUN #%d" % (GameData.run_count + 1)
	if GameData.best_score > 0:
		score_label.text = "BEST SCORE: %d" % GameData.best_score
		score_label.visible = true
	else:
		score_label.visible = false


func _on_begin_pressed() -> void:
	GameData.start_new_run()
	get_tree().change_scene_to_file("res://scenes/Raid.tscn")


func _on_stash_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/HomeBase.tscn")
