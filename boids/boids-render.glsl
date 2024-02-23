#[vertex]
#version 450

layout (location = 0) in vec2 position;
layout (location = 1) in vec2 uv_r;
layout (location = 2) smooth out vec2 uv;

void main() {
	uv = uv_r;
    gl_Position = vec4(position, 0.0, 1.0);
}

#[fragment]
#version 450

layout (location = 0) out vec4 color;
layout (location = 2) smooth in vec2 uv;

layout (set = 0, binding = 0) uniform sampler2D boid_texture;

void main()
{
	color = texture(boid_texture, uv);
}