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

# --- Current run data (reset each raid) ---
var current_turn: int = 0
var current_hp: int = 100
var max_hp: int = 100
var inventory: Array = []  # Array of item dictionaries
var current_weight: float = 0.0
var max_weight: float = 20.0
var player_pos: Vector2i = Vector2i(0, 0)
var equipped_weapon: Dictionary = {}
var is_dead: bool = false
var death_turn: int = 0
var extracted: bool = false
var run_score: int = 0


func _ready() -> void:
	load_data()


# --- Save / Load ---

func save_data() -> void:
	var data := {
		"run_count": run_count,
		"best_score": best_score,
		"total_xp": total_xp,
		"stash": stash,
		"stash_slots": stash_slots,
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


# --- XP & Progression ---

func add_xp(amount: int) -> void:
	total_xp += amount
	# Auto-unlock stash slots at milestones
	var expected_slots := 10 + (total_xp / XP_PER_STASH_SLOT)
	if expected_slots > stash_slots:
		stash_slots = expected_slots
	save_data()


func get_next_slot_cost() -> int:
	var slots_earned := stash_slots - 10
	return (slots_earned + 1) * XP_PER_STASH_SLOT


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
	is_dead = false
	death_turn = 0
	extracted = false
	run_score = 0


func start_new_run() -> void:
	run_count += 1
	reset_run_state()
	save_data()


func get_inventory_value() -> int:
	var total := 0
	for item in inventory:
		total += int(item.get("value", 0))
	return total


func get_player_damage() -> int:
	if equipped_weapon.is_empty():
		return 5  # Unarmed
	return int(equipped_weapon.get("damage", 5))


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
