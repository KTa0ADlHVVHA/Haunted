shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);
    float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    col.rgb = mix(vec3(gray), col.rgb, saturation);
    COLOR = col;
}
