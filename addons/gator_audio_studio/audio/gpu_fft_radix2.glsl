#[compute]
#version 450

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer FFTBuffer {
	vec2 data[];
} fft_buffer;

layout(push_constant, std430) uniform Params {
	uint fft_size;
	uint stage_size;
	uint window_count;
	uint reserved;
} params;

void main() {
	uint id = gl_GlobalInvocationID.x;
	uint butterflies_per_window = params.fft_size >> 1;
	uint total = butterflies_per_window * params.window_count;
	if (id >= total || params.stage_size < 2u) {
		return;
	}
	uint window_index = id / butterflies_per_window;
	uint butterfly = id - window_index * butterflies_per_window;
	uint half_stage = params.stage_size >> 1;
	uint block = butterfly / half_stage;
	uint j = butterfly - block * half_stage;
	uint base = window_index * params.fft_size;
	uint i0 = base + block * params.stage_size + j;
	uint i1 = i0 + half_stage;
	if (i1 >= base + params.fft_size) {
		return;
	}
	float angle = -6.283185307179586 * float(j) / float(params.stage_size);
	vec2 w = vec2(cos(angle), sin(angle));
	vec2 even_value = fft_buffer.data[i0];
	vec2 odd_value = fft_buffer.data[i1];
	vec2 twiddled = vec2(
		odd_value.x * w.x - odd_value.y * w.y,
		odd_value.x * w.y + odd_value.y * w.x
	);
	fft_buffer.data[i0] = even_value + twiddled;
	fft_buffer.data[i1] = even_value - twiddled;
}
