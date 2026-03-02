extends Node
class_name RigidBodyTCPPublisher

@export var port: int = 8081
@export var enabled: bool = true
@export var use_degrees: bool = true

var server: TCPServer = TCPServer.new()
var clients: Array[StreamPeerTCP] = []
var body: RigidBody3D = null

func _ready():
	body = get_parent()
	
	if not body is RigidBody3D:
		push_error("RigidBodyTCPPublisher must be a child of a RigidBody3D!")
		enabled = false
		return

	if enabled:
		var err = server.listen(port)
		if err != OK:
			push_error("Failed to start TCP server on port %d. Error: %d" % [port, err])
			enabled = false
		else:
			print_rich("[color=green]TCP Server LISTENING on port %d[/color]" % port)

func _physics_process(_delta):
	if not enabled or not is_instance_valid(body):
		return

	# 1. Check for new connections
	if server.is_connection_available():
		var client: StreamPeerTCP = server.take_connection()
		if client:
			clients.append(client)
			print_rich("[color=yellow]CLIENT CONNECTED! Total clients: %d[/color]" % clients.size())

	# 2. Only send if we have clients
	if clients.is_empty():
		return

	# 3. Prepare Data
	var pos = body.global_position
	var rot = get_roll_pitch_yaw(body.global_transform.basis)
	var vel = Vector3(body.global_basis.x.dot(body.linear_velocity),body.global_basis.y.dot(body.linear_velocity),body.global_basis.z.dot(body.linear_velocity))

	if use_degrees:
		rot = Vector3(rad_to_deg(rot.x), rad_to_deg(rot.y), rad_to_deg(rot.z))

	var data = {
		"name": body.name,
		"position": [pos.x, pos.y, pos.z],
		"rotation": [rot.x, rot.y, rot.z],
		"velocity": [vel.x, vel.y, vel.z]
	}
	
	var json_string = JSON.stringify(data) + "\n"
	var packet = json_string.to_utf8_buffer()

	# 4. Send to clients
	for i in range(clients.size() - 1, -1, -1):
		var client = clients[i]
		var status = client.get_status()
		
		# Status: 0=Connecting, 1=Connected, 2=Disconnected
		if status != StreamPeerTCP.STATUS_CONNECTED:
			print_rich("[color=orange]Client %d disconnected (Status: %d)[/color]" % [i, status])
			_cleanup_client(i)
			continue

		# GODOT 4: Use put_data() instead of put_packet()
		var err = client.put_data(packet)
		
		if err != OK:
			print_rich("[color=red]Send failed to client %d. Error: %d[/color]" % [i, err])
			_cleanup_client(i)

func get_roll_pitch_yaw(basis: Basis) -> Vector3:
	"""
	Extract Roll, Pitch, Yaw from Basis using YXZ rotation order (aerospace convention)
	Returns: Vector3(roll, pitch, yaw) in radians
	"""
	var m00 = basis.x.x
	var m01 = basis.y.x
	var m02 = basis.z.x
	var m10 = basis.x.y
	var m11 = basis.y.y
	var m12 = basis.z.y
	var m20 = basis.x.z
	var m21 = basis.y.z
	var m22 = basis.z.z
	
	var pitch = asin(clamp(-m02, -1.0, 1.0))
	
	if abs(pitch) > PI / 2 - 0.0001:
		var roll = 0.0
		var yaw = atan2(-m10, m11)
		if pitch > 0:
			yaw = -yaw
		return Vector3(roll, pitch, yaw)
	else:
		var roll = atan2(m12, m22)
		var yaw = atan2(m01, m00)
		return Vector3(roll, pitch, yaw)

func _cleanup_client(index: int):
	var client = clients[index]
	if client:
		client.disconnect_from_host()
	clients.remove_at(index)
	print_rich("[color=yellow]Client removed. Remaining: %d[/color]" % clients.size())

func _exit_tree():
	for i in range(clients.size() - 1, -1, -1):
		_cleanup_client(i)
	server.stop()
	print_rich("[color=red]TCP Server stopped[/color]")
