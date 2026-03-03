extends Node

## Persistent game data singleton — autoloaded as GameData.
## Saves to user://gamedata.json.

const SAVE_PATH := "user://gamedata.json"
const XP_PER_STASH_SLOT := 100

# --- Persistent data (survives between runs) ---
var run_count: int = 0
var best_score: int = 0
var total_xp: int = 0
var stash: Array = []  # Array of item dictionaries
var stash_slots: int = 10
var level: int = 1
var skill_points: int = 0
var skills: Dictionary = {}  # e.g. {"stash_boost": 2, "survivor": 1}

# --- Current run data (reset each raid) ---
var current_turn: int = 0
var current_hp: int = 100
var max_hp: int = 100
var inventory: Array = []  # Array of item dictionaries
var current_weight: float = 0.0
var max_weight: float = 20.0
var player_pos: Vector2i = Vector2i(0, 0)
var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}
var is_dead: bool = false
var death_turn: int = 0
var extracted: bool = false
var run_score: int = 0


func _ready() -> void:
	load_data()
	_apply_skill_effects()


# --- Save / Load ---

func save_data() -> void:
	var data := {
		"run_count": run_count,
		"best_score": best_score,
		"total_xp": total_xp,
		"stash": stash,
		"stash_slots": stash_slots,
		"level": level,
		"skill_points": skill_points,
		"skills": skills,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return
	var data: Dictionary = json.data
	run_count = int(data.get("run_count", 0))
	best_score = int(data.get("best_score", 0))
	total_xp = int(data.get("total_xp", 0))
	stash = data.get("stash", [])
	stash_slots = int(data.get("stash_slots", 10))
	level = int(data.get("level", 1))
	skill_points = int(data.get("skill_points", 0))
	var loaded_skills = data.get("skills", {})
	if loaded_skills is Dictionary:
		skills = loaded_skills
	else:
		skills = {}


# --- Level System ---

func get_level() -> int:
	return 1 + int(sqrt(float(total_xp) / 100.0))


func get_xp_for_level(lvl: int) -> int:
	return (lvl - 1) * (lvl - 1) * 100


func get_xp_to_next_level() -> int:
	var next_lvl := get_level() + 1
	return get_xp_for_level(next_lvl) - total_xp


# --- XP & Progression ---

func add_xp(amount: int) -> void:
	var old_level := get_level()
	total_xp += amount
	var new_level := get_level()
	# Award skill points for level-ups
	if new_level > old_level:
		var levels_gained := new_level - old_level
		skill_points += levels_gained
	level = new_level
	# Auto-unlock stash slots at milestones
	_apply_skill_effects()
	save_data()


func get_next_slot_cost() -> int:
	var slots_earned := stash_slots - 10
	return (slots_earned + 1) * XP_PER_STASH_SLOT


# --- Skills ---

func get_skill_rank(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


func upgrade_skill(skill_id: String) -> bool:
	var def: Dictionary = SkillTree.SKILLS.get(skill_id, {})
	if def.is_empty():
		return false
	var current_rank := get_skill_rank(skill_id)
	if current_rank >= int(def.get("max_rank", 1)):
		return false
	var cost := int(def.get("cost", 1))
	if skill_points < cost:
		return false
	# Prereq check
	var prereq: String = def.get("prereq", "")
	if prereq != "" and get_skill_rank(prereq) == 0:
		return false
	skill_points -= cost
	skills[skill_id] = current_rank + 1
	_apply_skill_effects()
	save_data()
	return true


func _apply_skill_effects() -> void:
	# Stash slots: base from XP milestones + skill bonus
	var base_slots := 10 + (total_xp / XP_PER_STASH_SLOT)
	stash_slots = base_slots + get_skill_rank("stash_boost") * 3
	# Max HP
	max_hp = 100 + get_skill_rank("iron_body") * 10
	# Carry weight
	max_weight = 20.0 + get_skill_rank("carry_weight") * 5.0


# --- Skill Effect Getters ---

func get_flee_chance() -> float:
	return 0.60 + get_skill_rank("survivor") * 0.10


func get_damage_multiplier() -> float:
	return 1.0 + get_skill_rank("marksman") * 0.10


func get_crit_chance() -> float:
	return 0.20 + get_skill_rank("critical_eye") * 0.05


func get_crit_multiplier() -> float:
	return 2.0 + get_skill_rank("executioner") * 0.5


func get_player_damage() -> int:
	var base := 5
	if not equipped_weapon.is_empty():
		base = int(equipped_weapon.get("damage", 5))
	var mult := get_damage_multiplier()
	return int(float(base) * mult)


func get_armor_reduction() -> float:
	if equipped_armor.is_empty():
		return 0.0
	return float(equipped_armor.get("damage_reduction", 0.0))


# --- Stash ---

func add_to_stash(item: Dictionary) -> bool:
	if stash.size() >= stash_slots:
		return false
	stash.append(item.duplicate())
	save_data()
	return true


func remove_from_stash(index: int) -> Dictionary:
	if index < 0 or index >= stash.size():
		return {}
	var item: Dictionary = stash[index]
	stash.remove_at(index)
	save_data()
	return item


# --- Run State ---

func reset_run_state() -> void:
	current_turn = 0
	current_hp = max_hp
	inventory = []
	current_weight = 0.0
	player_pos = Vector2i(0, 0)
	equipped_weapon = {}
	equipped_armor = {}
	is_dead = false
	death_turn = 0
	extracted = false
	run_score = 0
	# Starting kit — always begin with a sidearm and basic heals
	var starter_pistol := {"name": "Basic Pistol", "type": "weapon", "damage": 15, "weight": 1.0, "value": 30}
	var bandage1 := {"name": "Bandage", "type": "med", "heal": 20, "weight": 0.5, "value": 20}
	var bandage2 := {"name": "Bandage", "type": "med", "heal": 20, "weight": 0.5, "value": 20}
	add_to_inventory(starter_pistol)
	add_to_inventory(bandage1)
	add_to_inventory(bandage2)


func start_new_run() -> void:
	run_count += 1
	reset_run_state()
	save_data()


func get_inventory_value() -> int:
	var total := 0
	for item in inventory:
		total += int(item.get("value", 0))
	return total


func add_to_inventory(item: Dictionary) -> bool:
	var item_weight: float = item.get("weight", 0.0)
	if current_weight + item_weight > max_weight:
		return false
	inventory.append(item.duplicate())
	current_weight += item_weight
	# Auto-equip weapon if better than current
	if item.get("type") == "weapon":
		if equipped_weapon.is_empty() or item.get("damage", 0) > equipped_weapon.get("damage", 0):
			equipped_weapon = item.duplicate()
	# Auto-equip armor if better than current
	if item.get("type") == "armor":
		if equipped_armor.is_empty() or item.get("damage_reduction", 0.0) > equipped_armor.get("damage_reduction", 0.0):
			equipped_armor = item.duplicate()
	return true


func use_med(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var item: Dictionary = inventory[index]
	if item.get("type") != "med":
		return 0
	var heal_amount: int = int(item.get("heal", 0))
	var old_hp := current_hp
	current_hp = mini(current_hp + heal_amount, max_hp)
	var actual_heal := current_hp - old_hp
	current_weight -= item.get("weight", 0.0)
	inventory.remove_at(index)
	return actual_heal


# --- End of Run ---

func record_death(score: int) -> void:
	is_dead = true
	death_turn = current_turn
	run_score = score
	# Keep 20% of loot XP on death
	var xp_earned := int(score * 0.2)
	add_xp(xp_earned)
	if score > best_score:
		best_score = score
	save_data()


func record_extraction(items: Array, score: int) -> void:
	extracted = true
	run_score = score
	# Full XP on successful extraction
	add_xp(score)
	if score > best_score:
		best_score = score
	# Move inventory items to stash (up to capacity)
	for item in items:
		if not add_to_stash(item):
			break  # Stash full
	save_data()
