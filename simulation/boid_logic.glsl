#[compute]
#version 450

                
layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;


layout(set = 0, binding = 1, std430) readonly buffer InputDataBuffer {
    vec4 data[];
} in_buffer;

layout(set = 0, binding = 2, std430) writeonly buffer OutputDataBuffer {
    vec4 data[];
} out_buffer;


void move_boids();
float random(vec2 st);

const float PI = 3.1415926535897932384626433832795;
const ivec2 imgSize = ivec2(1028,1028);
const float interaction_scale = 0.25;

void main(){ 
    move_boids();
}

void move_boids() {

    uint id = gl_GlobalInvocationID.x;
    if (id >= in_buffer.data.length()) return; // Guard against out of bounds


    vec2 pos = in_buffer.data[id].xy;
    pos = mod(pos + vec2(imgSize), vec2(imgSize));

    vec2 vel = in_buffer.data[id].zw;


    int alignment_neighbors = 0;
    int cohesion_neighbors = 0;
    vec2 total_vel = vec2(0.0, 0.0);
    vec2 total_pos = vec2(0.0, 0.0);

    for (uint i = 0; i < in_buffer.data.length(); i++) {

        vec2 other_pos = in_buffer.data[i].xy;
        other_pos = mod(other_pos + vec2(imgSize), vec2(imgSize));

        vec2 other_vel = in_buffer.data[i].zw;
        vec2 diff = pos - other_pos;

        if (diff == vec2(0.0, 0.0)) {
            continue; 
        }

        float dist = length(diff);

        if (dist < 20.0 * interaction_scale && dist > 0.001) { // separation
            vec2 direction = normalize(diff);
            vel += (direction / dist) * 2.0;
        }

        if (dist < 60.0 * interaction_scale && dist > 0.001) { // alignment
            total_vel += other_vel;
            alignment_neighbors++;
        }

        if (dist < 70.0 * interaction_scale && dist > 0.001) { // cohesion
            total_pos += other_pos;
            cohesion_neighbors++;
        }

    }


    if (alignment_neighbors > 0) { // apply alignment
        vec2 average_vel = total_vel / alignment_neighbors;
        vel += (average_vel - vel) * 0.1;
    }

    if (cohesion_neighbors > 0) { // apply cohesion
        vec2 average_pos = total_pos / cohesion_neighbors;
        vec2 direction = normalize(average_pos - pos);
        vel += direction * 0.01;
    }

    if (length(vel) < 3.0) {
        vel = normalize(vel) * 3.0;
    }

    // randomize velocity slightly
    float angle = random(pos + vel) * 2.0 * PI;
    vel += vec2(cos(angle), sin(angle)) * 0.1;


    vel *= 0.99; // damping

    // move
    pos += vel; 
    pos = mod(pos + vec2(imgSize), vec2(imgSize));      

    out_buffer.data[id] = vec4(pos, vel);

}


float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

