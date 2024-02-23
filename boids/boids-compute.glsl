#[compute]
#version 450

const vec2 resolution = vec2(1280.0, 720.0);
const float size = 8.0;
const float half_pi = 1.5708;
const float three_fourths_pi = 2.3562;

struct Boid {
	vec2 position;
	vec2 velocity;
};

struct BoidMesh {
	vec4[4] vertices;
};

layout(set = 0, binding = 0, std430) readonly buffer custom_parameters {
	float delta;
	float num_of_boids;
}
parameters;

layout(set = 0, binding = 1, std430) readonly buffer boid_read_array {
	Boid[] array;
}
boids_r;

layout(set = 0, binding = 2, std430) writeonly buffer boid_write_array {
	Boid[] array;
}
boids_w;

layout(set = 0, binding = 3, std430) writeonly buffer boid_meshes {
	BoidMesh[] array;
}
meshes;

vec2 safe_normalize(vec2 vector) {
	if (vector == vec2(0.0))
		return vec2(0.0);
	return normalize(vector);
}

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
void main() {
	uint id = gl_GlobalInvocationID.x;
	Boid self = boids_r.array[id];
	float delta = parameters.delta;
	int num_of_boids = int(parameters.num_of_boids);

	float num_of_visible_boids = 1.0;

	vec2 center = self.position;
	vec2 avg_velocity = self.velocity;
	vec2 total_away_direction = vec2(0.0);

	for (int n = 0; n < num_of_boids; n++) {
		if (n == id)
			continue;
		Boid boid = boids_r.array[n];
		float dist = distance(self.position, boid.position);
		if (dist < 64.0) { // visible
			center += boid.position;
			avg_velocity += boid.velocity;
			num_of_visible_boids += 1.0;
			if (dist < 14.0) // too close
				total_away_direction -= (boid.position - self.position);
		}
	}
	
	center /= num_of_visible_boids;
	avg_velocity /= num_of_visible_boids;

	self.velocity += delta * 64.0 * (
		safe_normalize(center - self.position) * 1.0 +
		safe_normalize(total_away_direction) * 2.5 +
		safe_normalize(avg_velocity) * 0.8
	);

	if (length(self.velocity) > 64.0)
		self.velocity = normalize(self.velocity) * 64.0;
	if (length(self.velocity) < 8.0)
		self.velocity = safe_normalize(self.velocity) * 8.0;

	self.position += self.velocity * delta;
	vec2 clamped_position = clamp(self.position, vec2(0.0), resolution);
	if (self.position != clamped_position) {
		self.position = clamped_position;
		self.velocity *= -1.0;
	}
	boids_w.array[id] = self;

	float angle = atan(self.velocity.y, self.velocity.x) - three_fourths_pi;
	for (int n = 0; n < 4; n++) {
		meshes.array[id].vertices[n].xy = (self.position + size * vec2(cos(n * half_pi + angle), sin(n * half_pi + angle))) / resolution * 2.0 - vec2(1.0);
	}
}