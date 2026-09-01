extends Node

signal registration_completed(success: bool, message: String)
signal leaderboard_loaded(success: bool, entries: Array, message: String)
signal score_submitted(success: bool, message: String)

const CONFIG_PATH := "res://online/leaderboard_config.json"

var supabase_url := ""
var publishable_key := ""

func _ready() -> void:
	load_config()
	if is_configured() and SaveData.has_online_identity() and not SaveData.data.pending_online_score.is_empty():
		call_deferred("retry_pending_score")

func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		supabase_url = String(parsed.get("supabase_url", "")).strip_edges().trim_suffix("/")
		publishable_key = String(parsed.get("supabase_publishable_key", "")).strip_edges()

func is_configured() -> bool:
	return supabase_url.begins_with("https://") and "YOUR_PROJECT_REF" not in supabase_url and publishable_key.length() > 20 and "REPLACE_ME" not in publishable_key

func has_identity() -> bool:
	return SaveData.has_online_identity()

func current_username() -> String:
	return String(SaveData.data.online_username)

func register_username(username: String) -> void:
	var cleaned := username.strip_edges()
	if not is_configured():
		registration_completed.emit(false, "Classifica online non configurata.")
		return
	if cleaned.length() < 3 or cleaned.length() > 20:
		registration_completed.emit(false, "Usa un nome da 3 a 20 caratteri.")
		return
	var request := create_request()
	request.request_completed.connect(_on_registration_response.bind(request, cleaned))
	var payload := JSON.stringify({"p_username": cleaned})
	var error := request.request(rpc_url("register_player"), request_headers(), HTTPClient.METHOD_POST, payload)
	if error != OK:
		request.queue_free()
		registration_completed.emit(false, "Impossibile avviare la richiesta.")

func fetch_global_leaderboard() -> void:
	if not is_configured():
		leaderboard_loaded.emit(false, [], "Classifica online non configurata.")
		return
	var request := create_request()
	request.request_completed.connect(_on_leaderboard_response.bind(request))
	var error := request.request(rpc_url("get_global_leaderboard"), request_headers(), HTTPClient.METHOD_POST, "{}")
	if error != OK:
		request.queue_free()
		leaderboard_loaded.emit(false, [], "Impossibile avviare la richiesta.")

func submit_score(value: int, kills: int, zones: int, endless_seconds: int) -> void:
	if not is_configured() or not has_identity():
		return
	var run_data := {
		"p_player_id": String(SaveData.data.online_player_id),
		"p_score": maxi(0, value),
		"p_kills": maxi(0, kills),
		"p_zones": clampi(zones, 0, 5),
		"p_endless_seconds": maxi(0, endless_seconds),
	}
	var existing_pending: Dictionary = SaveData.data.pending_online_score
	if not existing_pending.is_empty() and int(existing_pending.get("p_score", 0)) > int(run_data.p_score):
		run_data = existing_pending.duplicate(true)
	SaveData.set_pending_online_score(run_data)
	send_score_request(run_data)

func retry_pending_score() -> void:
	var pending: Dictionary = SaveData.data.pending_online_score
	if pending.is_empty() or not is_configured() or not has_identity():
		return
	send_score_request(pending)

func send_score_request(run_data: Dictionary) -> void:
	var request := create_request()
	request.request_completed.connect(_on_score_response.bind(request))
	var error := request.request(rpc_url("submit_score"), request_headers(), HTTPClient.METHOD_POST, JSON.stringify(run_data))
	if error != OK:
		request.queue_free()
		score_submitted.emit(false, "Punteggio conservato per il prossimo tentativo.")

func create_request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = 12.0
	add_child(request)
	return request

func rpc_url(function_name: String) -> String:
	return "%s/rest/v1/rpc/%s" % [supabase_url, function_name]

func request_headers() -> PackedStringArray:
	var headers := PackedStringArray([
		"apikey: %s" % publishable_key,
		"Content-Type: application/json",
	])
	if not publishable_key.begins_with("sb_publishable_"):
		headers.append("Authorization: Bearer %s" % publishable_key)
	return headers

func response_error(result: int, response_code: int, body: PackedByteArray) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Connessione non disponibile."
	var text := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary and parsed.has("message"):
			return String(parsed.message)
		return "Errore server (%d)." % response_code
	return ""

func _on_registration_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, requested_name: String) -> void:
	request.queue_free()
	var error_message := response_error(result, response_code, body)
	if not error_message.is_empty():
		registration_completed.emit(false, error_message)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.has("player_id"):
		registration_completed.emit(false, "Risposta del server non valida.")
		return
	var server_name := String(parsed.get("username", requested_name))
	SaveData.set_online_identity(server_name, String(parsed.player_id))
	registration_completed.emit(true, "Bentornato, %s!" % server_name)
	retry_pending_score()

func _on_leaderboard_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	var error_message := response_error(result, response_code, body)
	if not error_message.is_empty():
		leaderboard_loaded.emit(false, [], error_message)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Array:
		leaderboard_loaded.emit(true, parsed, "")
	else:
		leaderboard_loaded.emit(false, [], "Risposta del server non valida.")

func _on_score_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	var error_message := response_error(result, response_code, body)
	if error_message.is_empty():
		SaveData.clear_pending_online_score()
		score_submitted.emit(true, "Punteggio online aggiornato.")
	else:
		score_submitted.emit(false, "Punteggio conservato: %s" % error_message)
