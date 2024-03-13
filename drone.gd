extends RigidBody3D

var P_GAIN = 12
var I_GAIN = .001
var D_GAIN = 40

@export var altitude:float = 10
var power_factor = 20
var max_power = 12
var min_power = 9
var integrated_err = 0
var last_err = 0
var force = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
func _physics_process(delta):
	var err = altitude-global_position.y
	integrated_err+=err*delta
	var derivative = (err-last_err)/delta
	force = (err*P_GAIN+integrated_err*I_GAIN+derivative*D_GAIN)*power_factor
	force = clamp(force,min_power,max_power)*Vector3.UP
	apply_central_force(force)
	last_err = err

