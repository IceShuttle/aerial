extends RigidBody3D

var P_GAIN_THRUST = 20
var I_GAIN_THRUST = .001
var D_GAIN_THRUST = 40
var armed = true;

@export var altitude:float = 10
@onready var mesh = $Sketchfab_Scene
var power_factor = 80
var max_power = 62
var min_power = 9
var integrated_err_altitude = 0
var last_err_altitude = 0
var vertical_force = 0

var P_GAIN_TILT = 30
var I_GAIN_TILT = .001
var D_GAIN_TILT = 20
var tilt_factor = .05
var max_torque = .01
var max_angle = 30
var front_target_angle = 0
var right_target_angle = 0
var integrated_err_forward = 0
var integrated_err_right = 0
var last_err_forward = 0
var last_err_right = 0

var P_GAIN_MOVE = 80
var I_GAIN_MOVE = .0001
var D_GAIN_MOVE = .1
var move_factor = .005
var integrated_err_north = 0
var integrated_err_east = 0
var last_err_north = 0
var last_err_east = 0
var max_speed = 10


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	

func _control():
	var up = Input.get_action_strength("up")-Input.get_action_strength("down");
	altitude+=up*.2;
	var right = Input.get_action_raw_strength("rotate_right")-Input.get_action_strength("rotate_left");
	apply_torque_impulse(-right*global_transform.basis.y*.02)
	front_target_angle = (Input.get_action_strength("strafe_forward")-Input.get_action_strength("strafe_back"))*max_angle;
	right_target_angle = (Input.get_action_strength("strafe_right")-Input.get_action_strength("strafe_left"))*max_angle;

func _listen():
	altitude+=clamp(TcpListener.throttle,-1,1)*.2
	apply_torque_impulse(clamp(TcpListener.yaw_rate,-1,1)*global_transform.basis.y*.02)
	front_target_angle=clamp(TcpListener.pitch,-1,1)*max_angle
	right_target_angle=clamp(TcpListener.yaw_rate,-1,1)*max_angle
	
func _physics_process(delta):
	_control()
	_listen()
	_thrust(delta)
	_movment(delta)
	
func _thrust(delta):
	#apply_central_impulse(global_transform.basis.y*Input.get_action_strength("up")*3.5)
	var err = altitude-global_position.y
	integrated_err_altitude+=err*delta
	var derivative = (err-last_err_altitude)/delta
	vertical_force = (err*P_GAIN_THRUST+integrated_err_altitude*I_GAIN_THRUST+derivative*D_GAIN_THRUST)*power_factor
	vertical_force = clamp(vertical_force,min_power,max_power)*global_transform.basis.y
	apply_central_force(vertical_force)
	last_err_altitude = err
	
func _movment(delta):
	var err = front_target_angle*max_speed - linear_velocity.dot(global_transform.basis.z)
	integrated_err_north+=err*delta
	var derivative = (err-last_err_north)/delta
	var north_force = (err*P_GAIN_MOVE+integrated_err_north*I_GAIN_MOVE+derivative*D_GAIN_MOVE)*move_factor
	north_force = clamp(north_force,-max_angle,max_angle)
	#print(north_force)
	last_err_north=err
	
	err = (-north_force) - global_rotation_degrees.x
	integrated_err_forward+=err*delta
	derivative = (err-last_err_forward)/delta
	var forward_force = (err*P_GAIN_TILT+integrated_err_forward*I_GAIN_TILT+derivative*D_GAIN_TILT)*tilt_factor
	forward_force = clamp(forward_force,-max_torque,max_torque)*global_transform.basis.x
	apply_torque_impulse(forward_force)
	last_err_forward=err
	
	
	err = right_target_angle*max_speed - linear_velocity.dot(global_transform.basis.x)
	integrated_err_east+=err*delta
	derivative = (err-last_err_east)/delta
	var east_force = (err*P_GAIN_MOVE+integrated_err_east*I_GAIN_MOVE+derivative*D_GAIN_MOVE)*move_factor
	east_force = clamp(east_force,-max_angle,max_angle)
	#print(east_force)
	last_err_east=err
	
	err = (-east_force) - global_rotation_degrees.z
	integrated_err_right+=err*delta
	var right_derivative = (err-last_err_right)/delta
	var right_force = (err*P_GAIN_TILT+integrated_err_right*I_GAIN_TILT+right_derivative*D_GAIN_TILT)*tilt_factor
	right_force = clamp(right_force,-max_torque,max_torque)*global_transform.basis.z
	apply_torque_impulse(right_force)
	last_err_right=err
	
