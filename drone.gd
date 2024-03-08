extends RigidBody3D

@export var altitude = 20
var power_factor = 200
var max_power = 12
var total_err = 0
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
	total_err+=err
	var derivative = err-last_err
	force = (total_err*.001+err+derivative*10)*delta*power_factor
	force = clamp(force,0,max_power)*Vector3.UP
	apply_central_force(force)
	last_err = err

