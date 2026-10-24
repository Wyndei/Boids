extends TextureRect
class_name BoidsRect

@export var count : int = 100
@export_range(0.0,1.0) var separation : float = 0.5
@export_range(0.0,1.0) var alignment : float = 0.5
@export_range(0.0,1.0)  var cohesion : float = 0.5

var positions : Array[Vector2]
var velocities : Array[Vector2]

var rd: RenderingDevice
var texture_rd : Texture2DRD

var logic_shader : RID
var render_shader : RID

var texture_rid: RID
#var data_rid: RID

var texture_uniform : RDUniform


var data_rid_a : RID
var data_rid_b : RID

var ping_state: bool = false

var data : PackedByteArray

var logic_set_ping : RID
var render_set_ping : RID
var logic_set_pong : RID
var render_set_pong : RID

var logic_pipeline : RID
var render_pipeline : RID

var running : bool = false

func _ready() -> void:
	start_boids()

func start_boids():
	
	
	var vectors : PackedVector4Array
	
	for n in count: #array of random position
		positions.append(Vector2(randi_range(0,1028),randi_range(0,1028)))
		velocities.append(Vector2(randf_range(-5.0,5.0),randf_range(-5.0,5.0)))
		
		vectors.append(Vector4(positions[n].x,positions[n].y,velocities[n].x,velocities[n].y))
		
	
	data = vectors.to_byte_array()
	
	#var push_constants : PackedByteArray = [
		#separation,
		#alignment,
		#cohesion
	#]
	
	rd = RenderingServer.get_rendering_device()
	
	var texture_format := RDTextureFormat.new()
	texture_format.width = 1028
	texture_format.height = 1028
	texture_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	texture_format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | 
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	
	var texture_view := RDTextureView.new()
	texture_rid = rd.texture_create(texture_format, texture_view, [])
	#data_rid = rd.storage_buffer_create(data.size(), data)
	
	data_rid_a = rd.storage_buffer_create(data.size(), data)
	data_rid_b = rd.storage_buffer_create(data.size(), data)
	
	texture_uniform = RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0 
	texture_uniform.add_id(texture_rid)
	
	
	texture_rd = Texture2DRD.new()
	texture = texture_rd
	texture_rd.texture_rd_rid = texture_rid
	
	#boids logic shader shit
	var logic := load("res://Boids/boid_logic.glsl")
	var logic_spirv: RDShaderSPIRV = logic.get_spirv()
	logic_shader = rd.shader_create_from_spirv(logic_spirv)
	logic_pipeline = rd.compute_pipeline_create(logic_shader)
	
	#boids render shader shit
	var render := load("res://Boids/boids_render.glsl")
	var render_spirv: RDShaderSPIRV = render.get_spirv()
	render_shader = rd.shader_create_from_spirv(render_spirv)
	render_pipeline = rd.compute_pipeline_create(render_shader)
	
	var uniform_in_a : RDUniform = RDUniform.new()
	uniform_in_a.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_in_a.binding = 1
	uniform_in_a.add_id(data_rid_a)
	
	var uniform_out_b : RDUniform = RDUniform.new()
	uniform_out_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_out_b.binding = 2
	uniform_out_b.add_id(data_rid_b)
	
	logic_set_ping = rd.uniform_set_create([uniform_in_a, uniform_out_b], logic_shader, 0)
	render_set_ping = rd.uniform_set_create([texture_uniform,uniform_out_b], render_shader, 0)
	
	var uniform_in_b : RDUniform = RDUniform.new()
	uniform_in_b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_in_b.binding = 1
	uniform_in_b.add_id(data_rid_b)
	
	var uniform_out_a : RDUniform = RDUniform.new()
	uniform_out_a.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_out_a.binding = 2
	uniform_out_a.add_id(data_rid_a)
	
	logic_set_pong = rd.uniform_set_create([uniform_in_b, uniform_out_a], logic_shader, 0)
	render_set_pong = rd.uniform_set_create([texture_uniform,uniform_out_a], render_shader, 0)
	
	running = true
	

func dispatch(current_state : bool):
	
	var active_logic_set : RID = logic_set_ping if not current_state else logic_set_pong
	var active_render_set : RID = render_set_ping if not current_state else render_set_pong
	
	rd.texture_clear(texture_rid,Color(0.1,0.1,0.1,1.0),0,1,0,1)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, logic_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, active_logic_set, 0)
	rd.compute_list_dispatch(compute_list, 128,1,1)
	
	rd.compute_list_add_barrier(compute_list)
	
	rd.compute_list_bind_compute_pipeline(compute_list, render_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, active_render_set, 0)
	rd.compute_list_dispatch(compute_list, 128,1,1)
	rd.compute_list_end()
	

func _process(_delta: float) -> void:
	if !running:
		return
	
	var current_state : bool = ping_state
	ping_state = !ping_state
	
	RenderingServer.call_on_render_thread(func(): dispatch(current_state),)
	
	
