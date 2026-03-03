class_name ItemDatabase

## Static item definitions, loot generation, and crafting.

# Item types: "weapon", "med", "component", "valuable", "armor", "throwable"

const ITEMS := {
	# --- Weapons ---
	"pistol": {
		"name": "Pistol",
		"type": "weapon",
		"weight": 3.0,
		"damage": 15,
		"value": 50,
		"desc": "9mm sidearm. Reliable.",
	},
	"shotgun": {
		"name": "Shotgun",
		"type": "weapon",
		"weight": 5.0,
		"damage": 30,
		"value": 80,
		"desc": "Pump-action. Devastating at close range.",
	},
	"combat_knife": {
		"name": "Combat Knife",
		"type": "weapon",
		"weight": 1.0,
		"damage": 10,
		"value": 30,
		"desc": "Military-grade blade. Silent.",
	},
	"smg": {
		"name": "SMG",
		"type": "weapon",
		"weight": 3.5,
		"damage": 20,
		"value": 65,
		"desc": "Compact submachine gun. Fast.",
	},

	# --- Meds ---
	"bandage": {
		"name": "Bandage",
		"type": "med",
		"weight": 0.5,
		"heal": 20,
		"value": 20,
		"desc": "Basic wound dressing.",
	},
	"medkit": {
		"name": "Medkit",
		"type": "med",
		"weight": 1.0,
		"heal": 50,
		"value": 60,
		"desc": "Field medical kit. Thorough treatment.",
	},
	"painkillers": {
		"name": "Painkillers",
		"type": "med",
		"weight": 0.2,
		"heal": 10,
		"value": 15,
		"desc": "Take the edge off.",
	},
	"stim_injector": {
		"name": "Stim Injector",
		"type": "med",
		"weight": 0.3,
		"heal": 30,
		"value": 50,
		"desc": "Military stim. Heals 30 HP instantly.",
	},

	# --- Components ---
	"copper_wire": {
		"name": "Copper Wire",
		"type": "component",
		"weight": 0.2,
		"value": 15,
		"desc": "Spool of electrical wire.",
	},
	"circuit_board": {
		"name": "Circuit Board",
		"type": "component",
		"weight": 0.3,
		"value": 40,
		"desc": "Intact PCB. Useful for crafting.",
	},
	"gunpowder": {
		"name": "Gunpowder",
		"type": "component",
		"weight": 0.5,
		"value": 25,
		"desc": "Smokeless powder. Handle with care.",
	},
	"scrap_metal": {
		"name": "Scrap Metal",
		"type": "component",
		"weight": 1.0,
		"value": 10,
		"desc": "Bent sheet metal. Salvageable.",
	},
	"duct_tape": {
		"name": "Duct Tape",
		"type": "component",
		"weight": 0.3,
		"value": 12,
		"desc": "Fixes everything. Almost.",
	},
	"metal_scrap": {
		"name": "Metal Scrap",
		"type": "component",
		"weight": 0.4,
		"value": 10,
		"desc": "Bent metal fragments.",
	},
	"gun_parts": {
		"name": "Gun Parts",
		"type": "component",
		"weight": 0.5,
		"value": 25,
		"desc": "Mechanical components.",
	},
	"cloth_strips": {
		"name": "Cloth Strips",
		"type": "component",
		"weight": 0.1,
		"value": 5,
		"desc": "Torn fabric.",
	},
	"rubber_seal": {
		"name": "Rubber Seal",
		"type": "component",
		"weight": 0.1,
		"value": 8,
		"desc": "Rubber gasket.",
	},
	"adhesive": {
		"name": "Adhesive",
		"type": "component",
		"weight": 0.1,
		"value": 5,
		"desc": "Industrial glue.",
	},

	# --- Armor ---
	"light_armor": {
		"name": "Light Armor",
		"type": "armor",
		"weight": 2.0,
		"value": 60,
		"damage_reduction": 0.15,
		"desc": "Reduces damage taken by 15%.",
	},
	"ballistic_vest": {
		"name": "Ballistic Vest",
		"type": "armor",
		"weight": 4.0,
		"value": 120,
		"damage_reduction": 0.30,
		"desc": "Reduces damage taken by 30%.",
	},

	# --- Throwables ---
	"molotov": {
		"name": "Molotov Cocktail",
		"type": "throwable",
		"weight": 0.8,
		"value": 40,
		"damage": 45,
		"desc": "Burns everything. Use in combat.",
	},

	# --- Valuables ---
	"gold_watch": {
		"name": "Gold Watch",
		"type": "valuable",
		"weight": 0.1,
		"value": 100,
		"desc": "Luxury timepiece. Worth a fortune.",
	},
	"usb_drive": {
		"name": "USB Drive",
		"type": "valuable",
		"weight": 0.1,
		"value": 75,
		"desc": "Encrypted data. Someone wants this.",
	},
	"laptop": {
		"name": "Laptop",
		"type": "valuable",
		"weight": 2.0,
		"value": 150,
		"desc": "Military-grade laptop. Heavy but valuable.",
	},
	"dog_tags": {
		"name": "Dog Tags",
		"type": "valuable",
		"weight": 0.05,
		"value": 35,
		"desc": "Someone didn't make it out.",
	},
}

# Crafting recipes
const RECIPES := {
	# --- MEDS ---
	"bandage_craft": {
		"result": "bandage",
		"result_count": 2,
		"ingredients": {"cloth_strips": 3},
		"desc": "3x Cloth Strips -> 2x Bandage",
	},
	"medkit_craft": {
		"result": "medkit",
		"result_count": 1,
		"ingredients": {"bandage": 3},
		"desc": "3x Bandage -> Medkit",
	},
	"stim_craft": {
		"result": "stim_injector",
		"result_count": 1,
		"ingredients": {"painkillers": 1, "copper_wire": 1, "adhesive": 1},
		"desc": "Painkillers + Wire + Adhesive -> Stim Injector",
	},
	# --- ARMOR ---
	"light_armor_craft": {
		"result": "light_armor",
		"result_count": 1,
		"ingredients": {"rubber_seal": 2, "metal_scrap": 2, "cloth_strips": 2},
		"desc": "Rubber + Metal + Cloth -> Light Armor",
	},
	"ballistic_vest_craft": {
		"result": "ballistic_vest",
		"result_count": 1,
		"ingredients": {"metal_scrap": 4, "cloth_strips": 4, "rubber_seal": 2},
		"desc": "Metal + Cloth + Rubber -> Ballistic Vest",
	},
	# --- WEAPONS ---
	"pistol_craft": {
		"result": "pistol",
		"result_count": 1,
		"ingredients": {"gun_parts": 3, "copper_wire": 1},
		"desc": "Gun Parts + Wire -> Pistol",
	},
	"smg_craft": {
		"result": "smg",
		"result_count": 1,
		"ingredients": {"gun_parts": 5, "copper_wire": 2, "metal_scrap": 2},
		"desc": "Gun Parts + Wire + Metal -> SMG",
	},
	# --- THROWABLES ---
	"molotov_craft": {
		"result": "molotov",
		"result_count": 1,
		"ingredients": {"rubber_seal": 1, "adhesive": 2},
		"desc": "Rubber + Adhesive -> Molotov",
	},
}

# Loot tables by room type — maps room type to array of item keys
const LOOT_TABLES := {
	"storage": ["scrap_metal", "duct_tape", "copper_wire", "bandage", "combat_knife", "gunpowder", "metal_scrap", "cloth_strips", "rubber_seal"],
	"corridor": ["bandage", "painkillers", "scrap_metal", "dog_tags", "cloth_strips", "adhesive"],
	"labs": ["circuit_board", "usb_drive", "laptop", "medkit", "copper_wire", "smg", "adhesive", "rubber_seal"],
	"office": ["usb_drive", "laptop", "gold_watch", "circuit_board", "pistol", "dog_tags", "cloth_strips"],
	"barracks": ["pistol", "shotgun", "smg", "combat_knife", "medkit", "bandage", "gunpowder", "dog_tags", "gun_parts", "metal_scrap"],
	"medbay": ["medkit", "bandage", "painkillers", "circuit_board", "cloth_strips", "adhesive"],
	"armory": ["pistol", "shotgun", "smg", "combat_knife", "gunpowder", "gun_parts", "metal_scrap"],
	"extraction": ["bandage", "painkillers", "scrap_metal", "cloth_strips"],
	"default": ["scrap_metal", "bandage", "copper_wire", "dog_tags", "painkillers", "cloth_strips", "metal_scrap"],
}


static func get_item(item_key: String) -> Dictionary:
	if ITEMS.has(item_key):
		var item: Dictionary = ITEMS[item_key].duplicate()
		item["key"] = item_key
		return item
	return {}


static func get_random_loot(room_type: String, scavenger_rank: int = 0) -> Array:
	var table_key := room_type.to_lower()
	if not LOOT_TABLES.has(table_key):
		table_key = "default"
	var table: Array = LOOT_TABLES[table_key]

	var item_count := randi_range(0, 3)
	# Scavenger bonus: +1 item per rank
	if scavenger_rank > 0:
		item_count += scavenger_rank
	var result: Array = []
	var used_keys: Array = []

	for i in item_count:
		if table.is_empty():
			break
		var attempts := 0
		while attempts < 10:
			var key: String = table[randi() % table.size()]
			if key not in used_keys:
				used_keys.append(key)
				result.append(get_item(key))
				break
			attempts += 1

	return result


static func get_item_by_name(item_name: String) -> Dictionary:
	for key in ITEMS:
		if ITEMS[key]["name"] == item_name:
			var item: Dictionary = ITEMS[key].duplicate()
			item["key"] = key
			return item
	return {}


static func get_all_item_keys() -> Array:
	return ITEMS.keys()


static func break_down_item(item: Dictionary) -> Array:
	## Break an item into components. Returns array of component items.
	var item_type: String = item.get("type", "")
	var value: int = item.get("value", 10)
	var components: Array = []

	# Every item breaks into scrap + maybe something else
	components.append(get_item("scrap_metal"))
	if value >= 40:
		components.append(get_item("copper_wire"))
	if value >= 80:
		components.append(get_item("circuit_board"))

	# Type-specific bonus components
	match item_type:
		"weapon":
			components.append(get_item("gun_parts"))
			if value >= 50:
				components.append(get_item("metal_scrap"))
		"armor":
			components.append(get_item("cloth_strips"))
			components.append(get_item("metal_scrap"))
			if value >= 80:
				components.append(get_item("rubber_seal"))
		"med":
			if randf() < 0.5:
				components.append(get_item("cloth_strips"))
		_:
			if randf() < 0.3:
				components.append(get_item("metal_scrap"))

	return components


# --- Crafting ---

static func count_in_stash(item_name: String) -> int:
	var count := 0
	for item in GameData.stash:
		if item.get("name") == item_name:
			count += 1
	return count


static func can_craft(recipe_id: String) -> bool:
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return false
	for ingredient_id in recipe["ingredients"]:
		var needed: int = recipe["ingredients"][ingredient_id]
		var ingredient_def: Dictionary = ITEMS.get(ingredient_id, {})
		var ingredient_name: String = ingredient_def.get("name", "")
		if count_in_stash(ingredient_name) < needed:
			return false
	return true


static func craft_item(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	# Remove ingredients
	for ingredient_id in recipe["ingredients"]:
		var needed: int = recipe["ingredients"][ingredient_id]
		var ingredient_def: Dictionary = ITEMS.get(ingredient_id, {})
		var ingredient_name: String = ingredient_def.get("name", "")
		var removed := 0
		var i := GameData.stash.size() - 1
		while i >= 0 and removed < needed:
			if GameData.stash[i].get("name") == ingredient_name:
				GameData.stash.remove_at(i)
				removed += 1
			i -= 1
	# Add result(s)
	var result_item: Dictionary = ITEMS.get(recipe["result"], {}).duplicate()
	if result_item.is_empty():
		return false
	for _n in range(int(recipe.get("result_count", 1))):
		GameData.add_to_stash(result_item.duplicate())
	GameData.save_data()
	return true
