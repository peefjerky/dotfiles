#version 300 es
// vibrance.glsl - Enhances color saturation with subtle film grain
precision mediump float;
in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform mediump float time;

// Random function for grain generation
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec4 color = texture(tex, v_texcoord);
    
    // Increase vibrance/saturation
    float saturation = 1.30; // Adjust this value (1.0 is normal, >1.0 increases saturation)
    float gray = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 enhanced = mix(vec3(gray), color.rgb, saturation);
    
    // Add subtle film grain
    float grain_strength = 0.035; // Adjust for more/less visible grain (0.01-0.05 is subtle)
    vec2 grain_uv = v_texcoord * vec2(1.0);
    
    // Use time if available, otherwise use static grain
    // This makes the grain dynamic if time uniform is available
    float noise = rand(grain_uv + fract(time * 0.001));
    
    // Apply grain
    enhanced += (noise - 0.5) * grain_strength;
    
    fragColor = vec4(enhanced, color.a);
}
