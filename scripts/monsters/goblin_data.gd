extends Node
## Data-driven definition of the Goblin tenant for the prototype.
## (A plain GDScript const dict stands in for the JSON file described in the
## design doc -- the MCP tooling available here can't write arbitrary text
## files, only .gd scripts. Swapping this for real JSON later is a one-line change
## in GameManager._load_monster.)
class_name GoblinData

const DATA: Dictionary = {
	"id": "goblin",
	"name": "Goblin",
	"rent": 120,
	"flavor": "\"I need a place to live.\"",
	"requirements": ["food", "bed", "storage"],
	"likes": ["food", "junk", "trap"],
	"hates": ["bright_light", "expensive"],
	"danger_note": "Goblins are clumsy.",
	"max_props": 10,
}
