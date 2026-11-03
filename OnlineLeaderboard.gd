extends Node
#Talks to your Supabase leaderboard. Add as an Autoload named "OnlineLeaderboard":
#Needs the PlayerProfile and GameState autoloads.
#
#every function below is async. Call it with await and you get a Dictionary back:
#var result: Dictionary = await OnlineLeaderboard.fetch_top(10)
#if result["ok"]: ... result["rows"] ...

const SUPABASE_URL := "https://yacwvkfaswlfathvqzze.supabase.co"
#The publishable key is meant to be public (it ships inside the web build).
#NEVER put the secret / service_role key here.
const SUPABASE_KEY := "sb_publishable_zToJr0Dv66_nxJHmb-820w_6-aMvEgC"
const TIMEOUT_SECONDS := 10.0
const OFFLINE_MESSAGE := "Offline mode. Leaderboard unavailable."

var auto_submit: bool = true     #send your new total automatically every time you finish a level


func _ready() -> void:
	_connect_signals.call_deferred()      #deferred so GameState exists even if it's listed below us


func _connect_signals() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and not gs.level_finished.is_connected(_on_level_finished):
		gs.level_finished.connect(_on_level_finished)


#True when the player chose "Continue Offline" this session.
func is_offline() -> bool:
	var profile := get_node_or_null("/root/PlayerProfile")
	return profile != null and "is_offline" in profile and profile.is_offline


func _on_level_finished(_summary: Dictionary) -> void:
	if not auto_submit or is_offline():
		return
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile and profile.has_name():
		submit_total_score()          #runs in the background; if it fails, the next submit catches up


#Sends this player's total score. The server only keeps it if it's higher than their old one.
#Returns { ok: bool, message: String }
func submit_total_score() -> Dictionary:
	if is_offline():
		return {"ok": false, "message": OFFLINE_MESSAGE}
	var profile := get_node_or_null("/root/PlayerProfile")
	var gs := get_node_or_null("/root/GameState")
	if profile == null or gs == null:
		return {"ok": false, "message": "PlayerProfile or GameState autoload is missing."}
	if not profile.has_name():
		return {"ok": false, "message": "Pick a name first."}

	var body := {
		"p_id": profile.player_id,
		"p_name": profile.display_name,
		"p_score": gs.get_total_score(),
	}
	var res: Dictionary = await _call_api(HTTPClient.METHOD_POST, "/rest/v1/rpc/submit_score", body)
	return {"ok": res["ok"], "message": "" if res["ok"] else res["error"]}


#The best players, highest first. Returns { ok, message, rows } where each row is
#{ "name": String, "total_score": int }
func fetch_top(limit: int = 10) -> Dictionary:
	if is_offline():
		return {"ok": false, "message": OFFLINE_MESSAGE, "rows": []}
	var path := "/rest/v1/scores?select=name,total_score&order=total_score.desc&limit=%d" % limit
	var res: Dictionary = await _call_api(HTTPClient.METHOD_GET, path)
	var rows: Array = []
	if res["ok"] and res["data"] is Array:
		rows = res["data"]
	return {"ok": res["ok"], "message": "" if res["ok"] else res["error"], "rows": rows}
	
#Is this name free for this player? Returns { ok, message, available }
#If the check itself fails (no internet), available stays true so the login isn't blocked.
func name_available(p_name: String) -> Dictionary:
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile == null:
		return {"ok": false, "message": "PlayerProfile autoload is missing.", "available": true}
	var res: Dictionary = await _call_api(
		HTTPClient.METHOD_POST, "/rest/v1/rpc/name_available",
		{"p_id": profile.player_id, "p_name": p_name})
	var free: bool = true
	if res["ok"] and res["data"] != null:
		free = bool(res["data"])
	return {"ok": res["ok"], "message": "" if res["ok"] else res["error"], "available": free}


#This player's place on the board (1 = best). rank is 0 if they aren't on the board yet.
#Returns { ok, message, rank }
func fetch_my_rank() -> Dictionary:
	if is_offline():
		return {"ok": false, "message": OFFLINE_MESSAGE, "rank": 0}
	var profile := get_node_or_null("/root/PlayerProfile")
	if profile == null:
		return {"ok": false, "message": "PlayerProfile autoload is missing.", "rank": 0}
	var res: Dictionary = await _call_api(
		HTTPClient.METHOD_POST, "/rest/v1/rpc/get_rank", {"p_id": profile.player_id})
	var rank: int = 0
	if res["ok"] and res["data"] != null:
		rank = int(res["data"])
	return {"ok": res["ok"], "message": "" if res["ok"] else res["error"], "rank": rank}


#one HTTP call to Supabase. Returns { ok, code, data, error }.
func _call_api(method: int, path: String, body: Variant = null) -> Dictionary:
	#Safety net: nothing leaves the game in offline mode, whatever called us.
	if is_offline():
		return {"ok": false, "code": 0, "data": null, "error": OFFLINE_MESSAGE}

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)

	#Per Supabase: the publishable key goes in the "apikey" header (not in Authorization: Bearer).
	var headers := PackedStringArray([
		"apikey: " + SUPABASE_KEY,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var payload: String = "" if body == null else JSON.stringify(body)

	var start_error: int = http.request(SUPABASE_URL + path, headers, method, payload)
	if start_error != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null, "error": "Couldn't start the request (error %d)." % start_error}

	var result: Array = await http.request_completed
	http.queue_free()

	var net_result: int = result[0]
	var code: int = result[1]
	var raw: PackedByteArray = result[3]
	var text: String = raw.get_string_from_utf8()
	var parsed: Variant = null
	if text != "":
		parsed = JSON.parse_string(text)

	var ok: bool = net_result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	var error_text: String = ""
	if not ok:
		if net_result != HTTPRequest.RESULT_SUCCESS:
			error_text = "Network problem (code %d). Check your connection." % net_result
		elif parsed is Dictionary and parsed.has("message"):
			error_text = str(parsed["message"])
		else:
			error_text = "Server said %d." % code
	return {"ok": ok, "code": code, "data": parsed, "error": error_text}
