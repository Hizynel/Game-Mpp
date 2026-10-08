shader_type canvas_item;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float gradient = 1.0 - UV.y; // terang di atas, gelap di bawah
    vec3 color = mix(vec3(0.45, 0.45, 0.48), vec3(0.85, 0.85, 0.88), gradient);
    COLOR = vec4(color, tex.a);
}