# Bundled screen shaders

GLSL fragment shaders shipped with the shell and offered by the **Screen filter**
quick toggle alongside whatever `hyprshade` finds.

Drop a `.glsl` (or `.frag`) file here and it shows up in the picker on the next
refresh — no code change needed. The file name minus its extension becomes the
shader's name.

Users who don't want to touch the shell can instead use any directory `hyprshade`
already scans:

1. `$HYPRSHADE_SHADERS_DIR`
2. `~/.config/hypr/shaders`
3. `~/.config/hyprshade/shaders`
4. `/usr/share/hyprshade/shaders`

…or point `screenShader.extraShaderDirs` in `~/.config/illogical-impulse/config.json`
at somewhere else entirely.

## Writing one

Hyprland renders these with GLES 3, so the header is fixed:

```glsl
#version 300 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    fragColor = pixColor;
}
```

A shader that samples the *whole* screen rather than just the current pixel
(like `anti-flashbang.glsl`) needs damage tracking relaxed, or only the redrawn
region gets the effect. Add its name to `fullDamageShaders` in
`services/ScreenShader.qml`.
