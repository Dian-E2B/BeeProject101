extends Node

# Emitted when game data is fetched from the server
signal game_data_loaded(data: Dictionary)
# Emitted when a save request finishes
signal save_completed(success: bool)

# Cached last received game data so late-joining scenes can read it
var last_game_data: Dictionary = {}

# Replace this with your actual Laravel API URL when ready (e.g. "https://api.yourgame.com" or "http://127.0.0.1:8000")
@export var api_base_url: String = "http://127.0.0.1:8000"

var auth_token: String = ""
var telegram_init_data: String = ""
var is_authenticated: bool = false

var http_auth: HTTPRequest
var http_save: HTTPRequest
var http_load: HTTPRequest
var auth_attempts := 0

func _ready() -> void:
	# DEBUG: confirm this build's NetworkManager is running
	if OS.has_feature("web"):
		JavaScriptBridge.eval("console.log('[NM] NetworkManager _ready v2 - build timestamp check')")
	# If running on the web, automatically use the current website origin (no hardcoded URL needed!)
	if OS.has_feature("web"):
		var origin_obj = JavaScriptBridge.eval("window.location.origin")
		if origin_obj != null and str(origin_obj) != "" and str(origin_obj) != "null":
			api_base_url = str(origin_obj)
			print("[NetworkManager] Dynamically set api_base_url to: ", api_base_url)

	http_auth = HTTPRequest.new()
	http_save = HTTPRequest.new()
	http_load = HTTPRequest.new()

	http_auth.accept_gzip = false
	http_save.accept_gzip = false
	http_load.accept_gzip = false

	add_child(http_auth)
	add_child(http_save)
	add_child(http_load)

	http_auth.request_completed.connect(_on_auth_completed)
	http_save.request_completed.connect(_on_save_completed)
	http_load.request_completed.connect(_on_load_completed)

	_detect_telegram_and_login()

func _detect_telegram_and_login() -> void:
	if OS.has_feature("web"):
		# Try Telegram.WebApp.initData first, fallback to parsing tgWebAppData from location.hash
		var js_code = """
		(function() {
			if (window.Telegram && window.Telegram.WebApp && window.Telegram.WebApp.initData) {
				return window.Telegram.WebApp.initData;
			}
			var hash = window.location.hash.slice(1);
			var params = new URLSearchParams(hash);
			if (params.has('tgWebAppData')) {
				return params.get('tgWebAppData');
			}
			return '';
		})()
		"""
		var raw_init_data = JavaScriptBridge.eval(js_code)
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
	var response_text = body.get_string_from_utf8()
	print("[NetworkManager] Auth completed. Code: %d, Response: %s" % [response_code, response_text])
	if response_code == 200:
		var json = JSON.parse_string(response_text)
		if json and json.has("token"):
			auth_token = str(json["token"])
			is_authenticated = true
			print("[NetworkManager] Authenticated successfully with Laravel!")
			# Auth response already includes save_data — use it directly to avoid
			# a second round-trip and sidestep any proxy header-stripping issues.
			if json.has("save_data") and json["save_data"] is Dictionary:
				print("[NetworkManager] Using save_data bundled in auth response.")
				last_game_data = json["save_data"]
				game_data_loaded.emit(json["save_data"])
			else:
				# Fallback: explicit load request (passes token via query param)
				load_game()
			return
	print("[NetworkManager] Auth failed (HTTP %d)." % response_code)
	auth_attempts += 1
	if auth_attempts < 5:
		await get_tree().create_timer(2.0 * auth_attempts).timeout
		authenticate()		
		
	else:
		# Alert on mobile screen so we can see the exact error code and message!
		JavaScriptBridge.eval("alert('Auth Code: %d\\nResponse: %s');" % [response_code, response_text.replace("'", "\\'")])
	print("[NetworkManager] Auth failed or server offline (HTTP %d). Using local/offline session." % response_code)

func save_game(save_dict: Dictionary) -> void:
	if not is_authenticated or auth_token == "":
		print("[NetworkManager] Cannot save to server: Not authenticated.")
		if OS.has_feature("web"):
			JavaScriptBridge.eval("alert('[NM] save_game called but NOT authenticated! auth_token empty: ' + (%s))" % str(auth_token == "").to_lower())
		save_completed.emit(false)
		return
	
	# Cancel any in-progress save before starting a new one (prevents ERR_IN_USE)
	if http_save.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		http_save.cancel_request()
		
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + auth_token
	]
	

	var payload = {
		"honey": save_dict.get("honey", 0),
		"nectar": save_dict.get("nectar", 0),
		"seeds": save_dict.get("seeds", {}),
		"plots": save_dict.get("plots", []),
		"token": auth_token # fallback so token is never lost
	}

	if save_dict.has("plots"):
		payload["plots"] = save_dict["plots"]

	var body = JSON.stringify(payload)
	print("[NetworkManager] Saving to server: ", api_base_url + "/api/game/save", " payload: ", body)
	var err = http_save.request(api_base_url + "/api/game/save", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("[NetworkManager] http_save.request() returned error: ", err)
		if OS.has_feature("web"):
			JavaScriptBridge.eval("alert('[NM] save request() error: %d')" % err)

func _on_save_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text = body.get_string_from_utf8()
	var success = (response_code == 200)
	print("[NetworkManager] Save response: %d, text: %s" % [response_code, response_text])
	if not success:
		JavaScriptBridge.eval("alert('Save Error: ' + " + str(response_code) + " + '\\n' + " + JSON.stringify(response_text) + ");")
	save_completed.emit(success)

func load_game() -> void:
	if not is_authenticated or auth_token == "":
		print("[NetworkManager] Cannot load from server: Not authenticated.")
		return
		
	var headers = [
		"Accept: application/json",
		"Authorization: Bearer " + auth_token
	]
	# Also pass token as query param ?token= so even if proxies strip the Authorization header, it works 100%!
	var url = api_base_url + "/api/game/load?token=" + auth_token
	http_load.request(url, headers, HTTPClient.METHOD_GET)

func _on_load_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var response_text = body.get_string_from_utf8()
	print("[NetworkManager] Load completed. Code: %d, Response: %s" % [response_code, response_text])
	if response_code == 200:
		var json = JSON.parse_string(response_text)
		if json is Dictionary:
			print("[NetworkManager] Game data loaded successfully from server!")
			last_game_data = json
			game_data_loaded.emit(json)
			return
	else:
		JavaScriptBridge.eval("alert('Load Code: %d\\nResponse: %s');" % [response_code, response_text.replace("'", "\\'")])
	print("[NetworkManager] Failed to load data from server (HTTP %d)." % response_code)
