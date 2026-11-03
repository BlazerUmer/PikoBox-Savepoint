extends Node
#autoload
#
#Holds a random player ID (made once, saved, never shown) and the display name the player picked.
#The online leaderboard will use the ID to find a player's row and the name to show on the board.
#Saved to user://profile.cfg, separate from your other save files.

signal name_changed(new_name: String)

const SAVE_PATH := "user://profile.cfg"
const MIN_LEN := 3
const MAX_LEN := 12
var is_offline: bool = false  #session only, not saved, so every launch asks again
var player_id: String = ""
var display_name: String = ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		player_id = str(cfg.get_value("profile", "id", ""))
		display_name = str(cfg.get_value("profile", "name", ""))
	if player_id == "":
		player_id = _make_id()
		_save()


func has_name() -> bool:
	return display_name != ""

func set_offline() -> void:
	is_offline = true

func set_online() -> void:
	is_offline = false

#Trims the text and squashes repeated spaces ("  bob   x " -> "bob x").
func clean_name(raw: String) -> String:
	var s := raw.strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s


#returns "" if the name is fine, otherwise a message you can show the player.
func validate_name(raw: String) -> String:
	var s := clean_name(raw)
	if s.length() < MIN_LEN:
		return "Name must be at least %d characters." % MIN_LEN
	if s.length() > MAX_LEN:
		return "Name can be at most %d characters." % MAX_LEN
	var allowed := RegEx.new()
	allowed.compile("^[A-Za-z0-9 _-]+$")
	if allowed.search(s) == null:
		return "Use only letters, numbers, spaces, _ or -."
	return ""


#Saves the name if it's valid. Returns "" on success, or the error message.
func try_set_name(raw: String) -> String:
	var error := validate_name(raw)
	if error != "":
		return error
	display_name = clean_name(raw)
	_save()
	name_changed.emit(display_name)
	return ""


func _make_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi()]


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "id", player_id)
	cfg.set_value("profile", "name", display_name)
	cfg.save(SAVE_PATH)
