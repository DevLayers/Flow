#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float waveProgress;
    float waveStrength;
    float waveWidth;
    float waveLift;
    float lineCountValue;
    float firstLineSpan;
    float secondLineSpan;
    float waveDirection;
    float colorStrength;
    vec4 waveColor;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    bool hasSecondLine = lineCountValue > 1.5;
    bool isLowerLine = hasSecondLine && uv.y >= 0.5;

    float lineProgress = waveProgress;
    if (hasSecondLine)
        lineProgress = isLowerLine ? waveProgress * 2.0 - 1.0 : waveProgress * 2.0;
    if (waveDirection < 0.0)
        lineProgress = 1.0 - lineProgress;

    float safeWidth = max(0.001, waveWidth);
    float contentSpan = clamp(isLowerLine ? secondLineSpan : firstLineSpan,
        0.05, 1.0);
    float contentStart = 0.5 - contentSpan * 0.5;
    float contentEnd = 0.5 + contentSpan * 0.5;
    float travelMargin = safeWidth * 2.5;
    float waveCenter = mix(contentStart - travelMargin,
        contentEnd + travelMargin, lineProgress);
    float distanceToWave = (uv.x - waveCenter) / safeWidth;
    float envelope = exp(-0.5 * distanceToWave * distanceToWave);
    float localScale = 1.0 + waveStrength * envelope;

    float lineCenterY = hasSecondLine
        ? (isLowerLine ? 0.65 : 0.35)
        : 0.5;
    vec2 sampleUv;
    sampleUv.x = waveCenter + (uv.x - waveCenter) / localScale;
    sampleUv.y = lineCenterY + (uv.y - lineCenterY) / localScale;
    sampleUv.y += waveLift * envelope;
    sampleUv = clamp(sampleUv, vec2(0.0), vec2(1.0));

    vec4 sampled = texture(source, sampleUv);
    float tintAmount = colorStrength * envelope;
    sampled.rgb = mix(sampled.rgb, waveColor.rgb * sampled.a, tintAmount);
    fragColor = sampled * qt_Opacity;
}
