extends Node

# Emitted when game data is fetched from the server
signal game_data_loaded(data: Dictionary)
# Emitted when a save request finishes
signal save_completed(success: bool)

# Replace this with your actual Laravel API URL when ready (e.g. "https://api.yourgame.com" or "http://127.0.0.1:8000")
@export var api_base_url: String = "http://127.0.0.1:8000"

var auth_token: String = ""
var telegram_init_data: String = ""
var is_authenticated: bool = false

var http_auth: HTTPRequest
var http_save: HTTPRequest
var http_load: HTTPRequest

func _ready() -> void:
	# If running on the web, automatically use the current website origin (no hardcoded URL needed!)
	if OS.has_feature("web"):
		var origin_obj = JavaScriptBridge.eval("window.location.origin")
		if origin_obj != null and str(origin_obj) != "" and str(origin_obj) != "null":
			api_base_url = str(origin_obj)
			print("[NetworkManager] Dynamically set api_base_url to: ", api_base_url)

	http_auth = HTTPRequest.new()
	http_save = HTTPRequest.new()
	http_load = HTTPRequest.new()
	
	add_child(http_auth)
	add_child(http_save)
	add_child(http_load)

	http_auth.request_completed.connect(_on_auth_completed)
	http_save.request_completed.connect(_on_save_completed)
	http_load.request_completed.connect(_on_load_completed)

	_detect_telegram_and_login()

func _detect_telegram_and_login() -> void:
	if OS.has_feature("web"):
		# In Godot 4, use JavaScriptBridge.eval to safely read window.Telegram.WebApp
		var raw_init_data = JavaScriptBridge.eval("window.Telegram && window.Telegram.WebApp ? window.Telegram.WebApp.initData : ''")
		if raw_init_data != null and str(raw_init_data) != "" and str(raw_init_data) != "null":
			telegram_init_data = str(raw_init_data)
			print("[NetworkManager] Successfully grabbed Telegram initData!")
			JavaScriptBridge.eval("if (window.Telegram && window.Telegram.WebApp) { window.Telegram.WebApp.ready(); window.Telegram.WebApp.expand(); }")
		else:
			print("[NetworkManager] Web environment detected, but outside Telegram or initData empty.")
	else:
		print("[NetworkManager] Running locally in Godot Editor / Desktop.")

	authenticate()

func authenticate() -> void:
	var headers = ["Content-Type: application/json"]
	var payload = {
		"init_data": telegram_init_data,
		"is_dev": telegram_init_data == "" # fallback for local testing
	}
	var body = JSON.stringify(payload)
	var url = api_base_url + "/api/telegram/auth"
	print("[NetworkManager] Authenticating with: ", url)
	http_auth.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_auth_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("token"):
			auth_token = str(json["token"])
			is_authenticated = true
			print("[NetworkManager] Authenticated successfully with Laravel!")
			load_game()
			return
	print("[NetworkManager] Auth failed or server offline (HTTP %d). Using local/offline session." % response_code)

func save_game(save_dict: Dictionary) -> void:
	if not is_authenticated or auth_token == "":
		print("[NetworkManager] Cannot save to server: Not authenticated.")
		save_completed.emit(false)
		return
		
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + auth_token
	]
	var body = JSON.stringify(save_dict)
	http_save.request(api_base_url + "/api/game/save", headers, HTTPClient.METHOD_POST, body)

func _on_save_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var success = (response_code == 200)
	print("[NetworkManager] Save response: %d (Success: %s)" % [response_code, str(success)])
	save_completed.emit(success)

func load_game() -> void:
	if not is_authenticated or auth_token == "":
		print("[NetworkManager] Cannot load from server: Not authenticated.")
		return
		
	var headers = [
		"Authorization: Bearer " + auth_token
	]
	http_load.request(api_base_url + "/api/game/load", headers, HTTPClient.METHOD_GET)

func _on_load_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json is Dictionary:
			print("[NetworkManager] Game data loaded successfully from server!")
			game_data_loaded.emit(json)
			return
	print("[NetworkManager] Failed to load data from server (HTTP %d)." % response_code)

