shader_type canvas_item;

uniform float radius = 30.0;

void fragment() {
    vec2 uv = UV;
    vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;

    vec2 p = uv * size;
    vec2 b = size;

    float r = radius;

    vec2 q = abs(p - b * 0.5) - (b * 0.5 - r);

    float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;

    if (dist > 0.0) {
        discard;
    }

    COLOR = texture(TEXTURE, uv);
}