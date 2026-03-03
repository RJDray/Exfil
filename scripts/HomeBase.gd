extends Control

## Home base — stash management, crafting, skill tree, XP display.

# Tab references
@onready var stash_tab_btn: Button = %StashTab
@onready var craft_tab_btn: Button = %CraftTab
@onready var skills_tab_btn: Button = %SkillsTab
@onready var stash_panel: VBoxContainer = %StashPanel
@onready var craft_panel: VBoxContainer = %CraftPanel
@onready var skills_panel: VBoxContainer = %SkillsPanel

# Shared
@onready var xp_label: Label = %XPLabel
@onready var ready_button: Button = %ReadyButton
@onready var status_label: Label = %StatusLabel

# Stash tab
@onready var stash_label: Label = %StashLabel
@onready var stash_list: RichTextLabel = %StashList
@onready var workbench_label: Label = %WorkbenchLabel
@onready var workbench_container: VBoxContainer = %WorkbenchContainer
@onready var unlock_label: Label = %UnlockLabel

# Craft tab
@onready var craft_container: VBoxContainer = %CraftContainer

# Skills tab
@onready var skills_container: VBoxContainer = %SkillsContainer

var current_tab: String = "stash"


func _ready() -> void:
	ready_button.pressed.connect(_on_ready_pressed)
	stash_tab_btn.pressed.connect(func(): _switch_tab("stash"))
	craft_tab_btn.pressed.connect(func(): _switch_tab("craft"))
	skills_tab_btn.pressed.connect(func(): _switch_tab("skills"))
	_switch_tab("stash")


func _switch_tab(tab_name: String) -> void:
	current_tab = tab_name
	stash_panel.visible = (tab_name == "stash")
	craft_panel.visible = (tab_name == "craft")
	skills_panel.visible = (tab_name == "skills")

	# Update tab button colors
	var active_color := Color(0, 1, 0.25)
	var inactive_color := Color(0.5, 0.5, 0.5)
	stash_tab_btn.add_theme_color_override("font_color", active_color if tab_name == "stash" else inactive_color)
	craft_tab_btn.add_theme_color_override("font_color", active_color if tab_name == "craft" else inactive_color)
	skills_tab_btn.add_theme_color_override("font_color", active_color if tab_name == "skills" else inactive_color)

	_update_display()


func _update_display() -> void:
	# XP / Level header
	var lvl := GameData.get_level()
	var to_next := GameData.get_xp_to_next_level()
	xp_label.text = "LVL %d | XP: %d | Next: %d XP | SP: %d" % [lvl, GameData.total_xp, to_next, GameData.skill_points]

	status_label.text = "Run #%d | Best: %d" % [GameData.run_count, GameData.best_score]

	match current_tab:
		"stash":
			_update_stash_display()
		"craft":
			_update_craft_display()
		"skills":
			_update_skills_display()


# --- STASH TAB ---

func _update_stash_display() -> void:
	stash_label.text = "STASH (%d / %d slots)" % [GameData.stash.size(), GameData.stash_slots]

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
			elif item.get("type") == "armor":
				extra = " [ARMOR: -%d%%]" % int(item.get("damage_reduction", 0.0) * 100)
			elif item.get("type") == "throwable":
				extra = " [DMG:%d]" % item.get("damage", 0)
			stash_list.push_color(Color(1, 0.702, 0.278))
			stash_list.add_text(" %d. %s (%.1fkg, %dxp)%s" % [i + 1, item["name"], item["weight"], item["value"], extra])
			stash_list.pop()
			stash_list.newline()

	_update_workbench()

	var next_cost := GameData.get_next_slot_cost()
	if GameData.total_xp >= next_cost:
		unlock_label.text = "STASH UPGRADE AVAILABLE (%d XP)" % next_cost
		unlock_label.add_theme_color_override("font_color", Color(0, 1, 0.25))
	else:
		unlock_label.text = "Next stash slot: %d / %d XP" % [GameData.total_xp, next_cost]
		unlock_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _update_workbench() -> void:
	for child in workbench_container.get_children():
		child.queue_free()

	if GameData.stash.size() == 0:
		var lbl := Label.new()
		lbl.text = "No items to break down."
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		lbl.add_theme_font_size_override("font_size", 11)
		workbench_container.add_child(lbl)
		return

	for i in GameData.stash.size():
		var item: Dictionary = GameData.stash[i]
		if item.get("type") == "component":
			continue
		var btn := Button.new()
		btn.text = "BREAK DOWN: %s" % item["name"]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_color_override("font_color", Color(1, 0.702, 0.278))
		btn.add_theme_font_size_override("font_size", 11)
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
	status_label.text = "Broke down %s -> %s" % [item["name"], ", ".join(comp_names)]
	_update_display()


# --- CRAFT TAB ---

func _update_craft_display() -> void:
	for child in craft_container.get_children():
		child.queue_free()

	for recipe_id in ItemDatabase.RECIPES:
		var recipe: Dictionary = ItemDatabase.RECIPES[recipe_id]
		var result_def: Dictionary = ItemDatabase.ITEMS.get(recipe["result"], {})
		var result_name: String = result_def.get("name", recipe["result"])
		var result_count: int = int(recipe.get("result_count", 1))
		var craftable := ItemDatabase.can_craft(recipe_id)

		# Recipe container
		var recipe_vbox := VBoxContainer.new()
		recipe_vbox.add_theme_constant_override("separation", 2)

		# Recipe name
		var name_lbl := Label.new()
		var count_text := "%dx " % result_count if result_count > 1 else ""
		name_lbl.text = "%s%s" % [count_text, result_name]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(1, 0.702, 0.278) if craftable else Color(0.5, 0.5, 0.5))
		recipe_vbox.add_child(name_lbl)

		# Ingredients
		var ingredients_text := ""
		for ingredient_id in recipe["ingredients"]:
			var needed: int = recipe["ingredients"][ingredient_id]
			var ingredient_def: Dictionary = ItemDatabase.ITEMS.get(ingredient_id, {})
			var ingredient_name: String = ingredient_def.get("name", ingredient_id)
			var have := ItemDatabase.count_in_stash(ingredient_name)
			var color := "#00ff41" if have >= needed else "#ff4444"
			if ingredients_text != "":
				ingredients_text += "  "
			ingredients_text += "[color=%s]%s: %d/%d[/color]" % [color, ingredient_name, have, needed]

		var ing_rtl := RichTextLabel.new()
		ing_rtl.bbcode_enabled = true
		ing_rtl.fit_content = true
		ing_rtl.scroll_active = false
		ing_rtl.custom_minimum_size = Vector2(0, 18)
		ing_rtl.add_theme_font_size_override("normal_font_size", 10)
		ing_rtl.text = ingredients_text
		recipe_vbox.add_child(ing_rtl)

		# Craft button
		var btn := Button.new()
		btn.text = "CRAFT" if craftable else "MISSING MATERIALS"
		btn.custom_minimum_size = Vector2(0, 30)
		btn.disabled = not craftable
		btn.add_theme_font_size_override("font_size", 11)
		if craftable:
			btn.add_theme_color_override("font_color", Color(0, 1, 0.25))
			var rid: String = recipe_id
			btn.pressed.connect(func(): _craft_item(rid))
		else:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		recipe_vbox.add_child(btn)

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_color_override("separator_color", Color(0, 1, 0.25, 0.1))
		recipe_vbox.add_child(sep)

		craft_container.add_child(recipe_vbox)


func _craft_item(recipe_id: String) -> void:
	if ItemDatabase.craft_item(recipe_id):
		var recipe: Dictionary = ItemDatabase.RECIPES[recipe_id]
		var result_def: Dictionary = ItemDatabase.ITEMS.get(recipe["result"], {})
		var result_name: String = result_def.get("name", recipe["result"])
		status_label.text = "Crafted: %s" % result_name
	else:
		status_label.text = "Craft failed — missing materials."
	_update_display()


# --- SKILLS TAB ---

func _update_skills_display() -> void:
	for child in skills_container.get_children():
		child.queue_free()

	# Skill points header
	var sp_lbl := Label.new()
	sp_lbl.text = "SKILL POINTS: %d" % GameData.skill_points
	sp_lbl.add_theme_font_size_override("font_size", 14)
	sp_lbl.add_theme_color_override("font_color", Color(1, 0.702, 0.278))
	sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skills_container.add_child(sp_lbl)

	# Group skills by category
	var categories := {"survival": "SURVIVAL", "combat": "COMBAT", "logistics": "LOGISTICS"}
	for cat_id in categories:
		var cat_name: String = categories[cat_id]

		# Category header
		var cat_lbl := Label.new()
		cat_lbl.text = "--- %s ---" % cat_name
		cat_lbl.add_theme_font_size_override("font_size", 12)
		cat_lbl.add_theme_color_override("font_color", Color(0, 1, 0.25, 0.7))
		cat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skills_container.add_child(cat_lbl)

		for skill_id in SkillTree.SKILLS:
			var skill: Dictionary = SkillTree.SKILLS[skill_id]
			if skill["category"] != cat_id:
				continue

			var current_rank := GameData.get_skill_rank(skill_id)
			var max_rank: int = int(skill["max_rank"])
			var cost: int = int(skill["cost"])
			var prereq: String = skill.get("prereq", "")
			var prereq_met := (prereq == "" or GameData.get_skill_rank(prereq) > 0)
			var can_upgrade := (current_rank < max_rank and GameData.skill_points >= cost and prereq_met)

			var skill_vbox := VBoxContainer.new()
			skill_vbox.add_theme_constant_override("separation", 1)

			# Skill name + rank
			var name_lbl := Label.new()
			var rank_bar := ""
			for r in max_rank:
				rank_bar += "[X]" if r < current_rank else "[ ]"
			name_lbl.text = "[%s] %s  %s" % [skill["icon"], skill["name"], rank_bar]
			name_lbl.add_theme_font_size_override("font_size", 12)
			name_lbl.add_theme_color_override("font_color", Color(1, 1, 1) if current_rank > 0 else Color(0.7, 0.7, 0.7))
			skill_vbox.add_child(name_lbl)

			# Description
			var desc_lbl := Label.new()
			var desc_text := skill["desc"]
			if prereq != "":
				var prereq_def: Dictionary = SkillTree.SKILLS.get(prereq, {})
				var prereq_name: String = prereq_def.get("name", prereq)
				desc_text += " (Requires: %s)" % prereq_name
			desc_lbl.text = desc_text
			desc_lbl.add_theme_font_size_override("font_size", 10)
			desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			skill_vbox.add_child(desc_lbl)

			# Upgrade button
			if current_rank < max_rank:
				var btn := Button.new()
				btn.custom_minimum_size = Vector2(0, 28)
				btn.add_theme_font_size_override("font_size", 11)
				if can_upgrade:
					btn.text = "UPGRADE (%d SP)" % cost
					btn.add_theme_color_override("font_color", Color(0, 1, 0.25))
					var sid: String = skill_id
					btn.pressed.connect(func(): _upgrade_skill(sid))
				else:
					if not prereq_met:
						btn.text = "LOCKED (need %s)" % SkillTree.SKILLS.get(prereq, {}).get("name", prereq)
					elif GameData.skill_points < cost:
						btn.text = "NEED %d SP" % cost
					else:
						btn.text = "MAXED"
					btn.disabled = true
					btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
				skill_vbox.add_child(btn)
			else:
				var maxed_lbl := Label.new()
				maxed_lbl.text = "MAXED"
				maxed_lbl.add_theme_font_size_override("font_size", 10)
				maxed_lbl.add_theme_color_override("font_color", Color(0, 1, 0.25, 0.6))
				skill_vbox.add_child(maxed_lbl)

			skills_container.add_child(skill_vbox)


func _upgrade_skill(skill_id: String) -> void:
	if GameData.upgrade_skill(skill_id):
		var skill_def: Dictionary = SkillTree.SKILLS.get(skill_id, {})
		status_label.text = "Upgraded: %s (Rank %d)" % [skill_def.get("name", skill_id), GameData.get_skill_rank(skill_id)]
	else:
		status_label.text = "Cannot upgrade skill."
	_update_display()


# --- Navigation ---

func _on_ready_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
