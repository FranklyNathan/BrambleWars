// The 'extern' keyword means this variable is passed from the Lua code.
extern vec4 solid_color; // The color to use for the effect

// This is the main function for the fragment shader.
// It receives the texture, texture coordinates, and vertex color from LÖVE.
// It must return a vec4 (R,G,B,A) which is the final color of the pixel.
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Get the color of the current pixel.
    vec4 original_color = Texel(texture, texture_coords);

    // If the current pixel is not transparent, draw it with the solid color.
    if (original_color.a > 0.0) {
        // Return the solid color, but use the original alpha multiplied by the solid color's alpha.
        // This allows for fading out the effect from Lua.
        return vec4(solid_color.rgb, original_color.a * solid_color.a);
    }

    // If we get here, the pixel is transparent.
    return vec4(0.0, 0.0, 0.0, 0.0);
}