NOTE: This currently is for Godot 4.2. There are some major changes to RenderingDevice coming in 4.3, so it might not work there.

This is a Godot 4 simulation of Boids using RenderingDevice for computing the paths of the boids and rendering them to the screen. I wasn't able to find any other open source example of using RenderingDevice to actually render stuff like triangles, so hopefully you'll find this helpful.

To make using compute shaders easier, this project uses my [Compute Shader Plus plugin.](https://github.com/DevPoodle/compute-shader-plus) I started seeing performance issues at around 40,000 boids, but there are also quite a few major optimizations I could make to this simulation, so I should be able to push it even higher soon.
