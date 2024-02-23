extends Node2D

const screen_size := Vector2i(1280, 720)
const num_of_boids := 10192
const shader_groups := Vector3i(num_of_boids / 64.0, 1, 1)
const boid_size := 1.0

var boids_shader : ComputeHelper
var shader_parameters_buffer : StorageBufferUniform
var shader_boids_buffer_1 : StorageBufferUniform
var shader_boids_buffer_2 : StorageBufferUniform

var rd := RenderingServer.get_rendering_device()
var render_shader : RID
var output_texture : RID
var framebuffer : RID
var framebuffer_format : int
var index_array : RID
var vertex_array : RID
var render_pipeline : RID
var vertex_format : int
var uniform_set : RID
var uniforms : Array[RDUniform]
var vertex_storage_buffer : VertexBufferUniform
var sampler_uniform : SamplerUniform

func _ready() -> void:
	var boids := PackedFloat32Array()
	var vertices := PackedFloat32Array()
	var indices := PackedInt32Array()
	
	for boid in num_of_boids:
		var boid_position := Vector2(randf_range(0.0, screen_size.x), randf_range(0.0, screen_size.y))
		var boid_velocity := Vector2.from_angle(randf_range(0, TAU)) * 32.0
		boids.append_array([boid_position.x, boid_position.y])
		boids.append_array([boid_velocity.x, boid_velocity.y])
		
		vertices.append((boid_position.x - boid_size) / 1280.0)
		vertices.append((boid_position.y - boid_size) / 720.0)
		vertices.append_array([0.0, 0.0])
		
		vertices.append((boid_position.x - boid_size) / 1280.0)
		vertices.append((boid_position.y + boid_size) / 720.0)
		vertices.append_array([1.0, 0.0])
		
		vertices.append((boid_position.x + boid_size) / 1280.0)
		vertices.append((boid_position.y + boid_size) / 720.0)
		vertices.append_array([1.0, 1.0])
		
		vertices.append((boid_position.x + boid_size) / 1280.0)
		vertices.append((boid_position.y - boid_size) / 720.0)
		vertices.append_array([0.0, 1.0])
		
		indices.append_array([
			4 * boid,
			4 * boid + 2,
			4 * boid + 1,
			4 * boid,
			4 * boid + 2,
			4 * boid + 3,
		])
	
	boids_shader = ComputeHelper.create("res://boids/boids-compute.glsl")
	shader_parameters_buffer = StorageBufferUniform.create(PackedFloat32Array([0.1, num_of_boids]).to_byte_array())
	shader_boids_buffer_1 = StorageBufferUniform.create(boids.to_byte_array())
	shader_boids_buffer_2 = StorageBufferUniform.create(boids.to_byte_array())
	boids_shader.add_uniform_array([shader_parameters_buffer, shader_boids_buffer_1, shader_boids_buffer_2])
	
	var shader_file := preload("res://boids/boids-render.glsl")
	var shader_spirv := shader_file.get_spirv()
	render_shader = rd.shader_create_from_spirv(shader_spirv)
	
	var tex_format := RDTextureFormat.new()
	tex_format.height = 720
	tex_format.width = 1280
	tex_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	tex_format.usage_bits = (RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT)
	output_texture = rd.texture_create(tex_format, ComputeHelper.view)
	$CanvasLayer/RenderTarget.texture.texture_rd_rid = output_texture
	
	var attachment := RDAttachmentFormat.new()
	attachment.usage_flags = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	framebuffer_format = rd.framebuffer_format_create([attachment])
	
	framebuffer = rd.framebuffer_create([output_texture])
	
	var raster_state := RDPipelineRasterizationState.new()
	var multisample_state := RDPipelineMultisampleState.new()
	var stencil_state := RDPipelineDepthStencilState.new()
	var color_blend_state := RDPipelineColorBlendState.new()
	var color_blend_attachment = RDPipelineColorBlendStateAttachment.new()
	color_blend_attachment.set_as_mix()
	color_blend_state.attachments = [color_blend_attachment]
	
	var vertex_attrs : Array[RDVertexAttribute] = [RDVertexAttribute.new(), RDVertexAttribute.new()]
	vertex_attrs[0].format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	vertex_attrs[0].stride = 4 * 2 * 2
	vertex_attrs[1].format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	vertex_attrs[1].location = 1
	vertex_attrs[1].stride = 4 * 2 * 2
	vertex_attrs[1].offset = 4 * 2
	vertex_format = rd.vertex_format_create(vertex_attrs)
	render_pipeline = rd.render_pipeline_create(render_shader, framebuffer_format, vertex_format, RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster_state, multisample_state, stencil_state, color_blend_state)
	
	vertex_storage_buffer = VertexBufferUniform.create(vertices.to_byte_array())
	vertex_array = rd.vertex_array_create(num_of_boids * 4, vertex_format, [vertex_storage_buffer.vertex_buffer, vertex_storage_buffer.vertex_buffer])
	boids_shader.add_uniform(vertex_storage_buffer)
	
	var index_buffer := rd.index_buffer_create(num_of_boids * 6, RenderingDevice.INDEX_BUFFER_FORMAT_UINT32, indices.to_byte_array())
	index_array = rd.index_array_create(index_buffer, 0, num_of_boids * 6)
	
	var image := preload("res://boids/res/whale.png")
	image.convert(Image.FORMAT_RGBAF) #The original format RGBA8 doesn't work for some reason (probably something to do with Vulkan shaders)
	sampler_uniform = SamplerUniform.create(image)
	uniforms = [sampler_uniform.get_rd_uniform(0)]
	uniform_set = rd.uniform_set_create(uniforms, render_shader, 0)

func _physics_process(delta: float) -> void:
	shader_parameters_buffer.update_data(PackedFloat32Array([delta, num_of_boids]).to_byte_array())
	boids_shader.run(shader_groups)
	ComputeHelper.sync()
	StorageBufferUniform.swap_buffers(shader_boids_buffer_1, shader_boids_buffer_2)
	
	var draw_list = rd.draw_list_begin(framebuffer, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_READ, RenderingDevice.INITIAL_ACTION_CLEAR, RenderingDevice.FINAL_ACTION_CONTINUE, [Color.TRANSPARENT])
	
	rd.draw_list_bind_render_pipeline(draw_list, render_pipeline)
	rd.draw_list_bind_vertex_array(draw_list, vertex_array)
	rd.draw_list_bind_index_array(draw_list, index_array)
	rd.draw_list_bind_uniform_set(draw_list, uniform_set, 0)
	
	rd.draw_list_draw(draw_list, true, 1)
	rd.draw_list_end()

func _exit_tree() -> void:
	rd.free_rid(index_array)
	rd.free_rid(vertex_array)
	rd.free_rid(uniform_set)
