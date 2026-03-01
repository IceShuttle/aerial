extends Node

# --- Global Variables (Accessible via ControlServer.variable_name) ---
var throttle: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var yaw_rate: float = 0.0

# --- Network Configuration ---
const PORT: int = 8080
const BIND_ADDRESS: String = "0.0.0.0"

# --- Internal Networking State ---
var _server: TCPServer = TCPServer.new()
var _client: StreamPeerTCP = null
var _buffer: PackedByteArray = PackedByteArray()
var _is_listening: bool = false

func _ready() -> void:
	var err = _server.listen(PORT, BIND_ADDRESS)
	if err == OK:
		print("[ControlServer] Listening on %s:%d" % [BIND_ADDRESS, PORT])
		_is_listening = true
	else:
		push_error("[ControlServer] Failed to start server. Error: %d" % err)
		_is_listening = false

func _process(_delta: float) -> void:
	if not _is_listening:
		return

	if _client == null:
		if _server.is_connection_available():
			_client = _server.take_connection()
			_buffer = PackedByteArray()
			_client.set_no_delay(true)
	else:
		_poll_client()

func _poll_client() -> void:
	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_client = null
		return

	var available = _client.get_available_bytes()
	if available > 0:
		var chunk = _client.get_data(available)
		if chunk[0] == OK:
			_buffer += chunk[1]
			_check_request_complete()

func _find_byte_sequence(buffer: PackedByteArray, sequence: PackedByteArray) -> int:
	if buffer.size() < sequence.size():
		return -1
	
	for i in range(buffer.size() - sequence.size() + 1):
		var found = true
		for j in range(sequence.size()):
			if buffer[i + j] != sequence[j]:
				found = false
				break
		if found:
			return i
	return -1

func _check_request_complete() -> void:
	var header_end_marker: PackedByteArray = PackedByteArray([0x0D, 0x0A, 0x0D, 0x0A])
	var header_end_index: int = _find_byte_sequence(_buffer, header_end_marker)

	if header_end_index != -1:
		var header_bytes: PackedByteArray = _buffer.slice(0, header_end_index)
		var body_start_index: int = header_end_index + 4
		var body_bytes: PackedByteArray = _buffer.slice(body_start_index)
		
		_handle_http_request(header_bytes, body_bytes)
		
		_buffer = PackedByteArray()
		_client.disconnect_from_host()
		_client = null

func _handle_http_request(headers: PackedByteArray, body: PackedByteArray) -> void:
	var header_string: String = headers.get_string_from_ascii()
	
	if not header_string.begins_with("POST"):
		_send_response(405, "Method Not Allowed")
		return

	var body_string: String = body.get_string_from_utf8().strip_edges()
	
	if body_string.is_empty():
		_send_response(400, "Empty Body")
		return

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(body_string)
	
	if parse_error != OK:
		print("[ControlServer] JSON Parse Error: ", json.get_error_message())
		_send_response(400, "Invalid JSON")
		return

	var data = json.data
	if not data is Dictionary:
		_send_response(400, "JSON must be an object")
		return

	_update_globals(data)
	_send_response(200, "OK")
	print("[ControlServer] FLOAT DATA - Throttle: %.4f, Pitch: %.4f, Roll: %.4f, Yaw: %.4f" % [throttle, pitch, roll, yaw_rate])

# --- Explicit Float Conversion ---
func _update_globals(data: Dictionary) -> void:
	# Ensure all values are converted to float explicitly
	if data.has("throttle"):
		throttle = _to_float(data["throttle"])
	
	if data.has("pitch"):
		pitch = _to_float(data["pitch"])
	
	if data.has("roll"):
		roll = _to_float(data["roll"])
	
	if data.has("yaw_rate"):
		yaw_rate = _to_float(data["yaw_rate"])
	elif data.has(" yaw_rate"):  # Handle key with leading space
		yaw_rate = _to_float(data[" yaw_rate"])

func _to_float(value) -> float:
	# Handle different input types and convert to float
	if value is float:
		return value
	elif value is int:
		return float(value)
	elif value is String:
		return value.to_float()
	else:
		return 0.0

func _send_response(code: int, message: String) -> void:
	if _client == null or _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
		
	var response: String = "HTTP/1.1 %d %s\r\n" % [code, message]
	response += "Content-Type: application/json\r\n"
	response += "Connection: close\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "\r\n"
	response += "{\"status\": \"received\"}"
	
	_client.put_data(response.to_ascii_buffer())
