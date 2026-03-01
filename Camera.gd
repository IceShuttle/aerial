extends Camera3D
@onready var parent = get_parent()
var offset

func _read():
	offset = transform.origin
	
func _process(delta: float) -> void:
	global_transform.origin = parent.global_transform.origin + offset
	

	
