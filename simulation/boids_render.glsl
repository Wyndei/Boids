#[compute]
#version 450

                
layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;


layout(set = 0, binding = 0, rgba8) uniform image2D Image;


layout(set = 0, binding = 2, std430) readonly buffer DataBuffer {
    vec4 data[];
}
data_buffer;




void draw_triangles();
void draw_triangle(vec2 pos, vec2 vel, float angle);
vec3 get_color(vec2 velocity);
float edgeFunction(vec2 a, vec2 b, vec2 p);

const float PI = 3.1415926535897932384626433832795;
const float tri_scale = 0.25;

void main() {
    draw_triangles();
}



void draw_triangles(){
    vec2 position = data_buffer.data[gl_GlobalInvocationID.x].xy;
    vec2 velocity = data_buffer.data[gl_GlobalInvocationID.x].zw;

    // ivec2 pixelCoords = ivec2(position);

    float angle = atan(velocity.y, velocity.x) + PI/2.0;

    vec3 color = get_color(velocity);
    // imageStore(Image, pixelCoords, vec4(color, 1.0));
    
    draw_triangle(position, velocity, angle);
}

void draw_triangle(vec2 pos, vec2 vel, float angle){

    vec2 v0 = vec2(0,-15)* tri_scale;  // Top
    vec2 v1 = vec2(-10,10)* tri_scale;  // Bottom Left
    vec2 v2 = vec2(10,10)* tri_scale;  // Bottom Right

    float cosa = cos(angle);
    float sina = sin(angle);

    v0 = pos + vec2(v0.x*cosa - v0.y*sina, v0.x*sina + v0.y*cosa);
    v1 = pos + vec2(v1.x*cosa - v1.y*sina, v1.x*sina + v1.y*cosa);
    v2 = pos + vec2(v2.x*cosa - v2.y*sina, v2.x*sina + v2.y*cosa);

    //aabb
    vec2 min = vec2(min(v0.x, min(v1.x, v2.x)), min(v0.y, min(v1.y, v2.y)));
    vec2 max = vec2(max(v0.x, max(v1.x, v2.x)), max(v0.y, max(v1.y, v2.y)));

    for (int x = int(min.x); x <= int(max.x); x++) { //loop through pixels only inside bounding box
        for (int y = int(min.y); y <= int(max.y); y++) {
            vec2 p = vec2(x, y);
            float w0 = edgeFunction(v1, v2, p);
            float w1 = edgeFunction(v2, v0, p);
            float w2 = edgeFunction(v0, v1, p);

            bool isInside = (w0 >= 0.0 && w1 >= 0.0 && w2 >= 0.0);

            if (isInside) {
                vec3 color = get_color(vel);
                ivec2 pixelCoords = ivec2(p);
                
                imageStore(Image, pixelCoords, vec4(color, 1.0));
            }
        }
    }
}

float edgeFunction(vec2 a, vec2 b, vec2 p) {
    return (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x);
}

vec3 get_color(vec2 velocity) {
    float speed = length(velocity);
    float normalized_speed = clamp(speed / 10.0, 0.0, 1.0); // Assuming max speed is 10.0
    return mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), normalized_speed); // Blue to Red
}