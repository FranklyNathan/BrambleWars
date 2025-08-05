// greyscale.glsl
// A simple shader to convert a texture to greyscale.

extern number strength; // 0.0 for no effect, 1.0 for full greyscale

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    number average = (pixel.r + pixel.g + pixel.b) / 3.0;
    pixel.rgb = mix(pixel.rgb, vec3(average), strength);
    return pixel * color;
}