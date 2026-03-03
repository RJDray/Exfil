class_name SkillTree

## Static skill definitions for the skill tree system.

const SKILLS := {
	# --- SURVIVAL ---
	"iron_body": {
		"name": "Iron Body",
		"desc": "+10 max HP per rank",
		"icon": "HP",
		"max_rank": 3,
		"cost": 1,
		"prereq": "",
		"category": "survival",
	},
	"survivor": {
		"name": "Survivor",
		"desc": "+10% flee success chance per rank",
		"icon": "FL",
		"max_rank": 3,
		"cost": 1,
		"prereq": "",
		"category": "survival",
	},
	"carry_weight": {
		"name": "Pack Mule",
		"desc": "+5kg carry capacity per rank",
		"icon": "WT",
		"max_rank": 3,
		"cost": 1,
		"prereq": "",
		"category": "survival",
	},
	# --- COMBAT ---
	"marksman": {
		"name": "Marksman",
		"desc": "+10% weapon damage per rank",
		"icon": "DM",
		"max_rank": 3,
		"cost": 1,
		"prereq": "",
		"category": "combat",
	},
	"critical_eye": {
		"name": "Critical Eye",
		"desc": "+5% critical hit chance per rank",
		"icon": "CR",
		"max_rank": 3,
		"cost": 1,
		"prereq": "",
		"category": "combat",
	},
	"executioner": {
		"name": "Executioner",
		"desc": "+0.5x critical damage multiplier per rank",
		"icon": "EX",
		"max_rank": 2,
		"cost": 2,
		"prereq": "critical_eye",
		"category": "combat",
	},
	# --- LOGISTICS ---
	"stash_boost": {
		"name": "Hoarder",
		"desc": "+3 stash slots per rank",
		"icon": "ST",
		"max_rank": 5,
		"cost": 1,
		"prereq": "",
		"category": "logistics",
	},
	"scavenger": {
		"name": "Scavenger",
		"desc": "Better loot quality per rank",
		"icon": "LT",
		"max_rank": 2,
		"cost": 2,
		"prereq": "",
		"category": "logistics",
	},
}
