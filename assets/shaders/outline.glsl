// The 'extern' keyword means this variable is passed from the Lua code.
extern vec4 outline_color; // The color of the outline (e.g., white)
extern vec2 texture_size;  // The width and height of the full texture/spritesheet
extern bool outline_only;  // If true, only the outline is drawn, the sprite itself is transparent.

// This is the main function for the fragment shader.
// It receives the texture, texture coordinates, and vertex color from LÖVE.
// It must return a vec4 (R,G,B,A) which is the final color of the pixel.
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    // Get the color of the current pixel.
    vec4 original_color = Texel(texture, texture_coords);

    // If the current pixel is not transparent...
    if (original_color.a > 0.0) {
        // ...and we are in outline_only mode, make it transparent.
        if (outline_only) {
            return vec4(0.0, 0.0, 0.0, 0.0);
        }
        // ...otherwise, just return its original color.
        return original_color;
    }

    // Calculate the size of one pixel in texture coordinates.
    float dx = 1.0 / texture_size.x;
    float dy = 1.0 / texture_size.y;

    // Check neighbors. If any neighbor is opaque, this pixel is part of the outline.
    if (Texel(texture, texture_coords + vec2(dx, 0.0)).a > 0.0 ||   // Right
        Texel(texture, texture_coords + vec2(-dx, 0.0)).a > 0.0 ||  // Left
        Texel(texture, texture_coords + vec2(0.0, dy)).a > 0.0 ||   // Down
        Texel(texture, texture_coords + vec2(0.0, -dy)).a > 0.0) {  // Up
        return outline_color;
    }

    // If we get here, the pixel and its neighbors are all transparent.
    return original_color;
}