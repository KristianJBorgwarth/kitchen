#version 440
// Sharp downscaling for window previews (LiveWorkspace). Mipmaps alone blend two box-filtered
// levels, which smears text. Instead: the mip level that's still at least the output size (an
// exact power-of-two box shrink), then Lanczos-2 across what's left (under 2x), so at most
// 8x8 taps per pixel.
// Rebuild after editing: /usr/lib/qt6/bin/qsb --qt6 -o downsample.frag.qsb downsample.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 srcSize;  // the source texture, in texels
    vec2 dstSize;  // this item, in pixels
};

layout(binding = 1) uniform sampler2D source;

const float PI = 3.14159265;

float lanczos2(float x) {
    x = abs(x);
    if (x < 1e-4)
        return 1.0;
    if (x >= 2.0)
        return 0.0;
    float px = PI * x;
    return 2.0 * sin(px) * sin(px * 0.5) / (px * px);
}

void main() {
    vec2 ratio = max(srcSize / max(dstSize, vec2(1.0)), vec2(1.0));
    float lod = floor(log2(min(ratio.x, ratio.y)));
    vec2 level = max(floor(srcSize / exp2(lod)), vec2(1.0));
    // what's left to shrink after the mip level, 1 to 2; the kernel widens by it
    vec2 r = max(level / max(dstSize, vec2(1.0)), vec2(1.0));
    vec2 radius = 2.0 * r;

    vec2 p = qt_TexCoord0 * level;
    vec2 first = floor(p - radius + 0.5);
    ivec2 n = min(ivec2(ceil(2.0 * radius)) + 1, ivec2(8));

    vec4 acc = vec4(0.0);
    float wsum = 0.0;
    for (int j = 0; j < 8; ++j) {
        if (j >= n.y)
            break;
        float ty = first.y + float(j) + 0.5;
        float wy = lanczos2((ty - p.y) / r.y);
        for (int i = 0; i < 8; ++i) {
            if (i >= n.x)
                break;
            float tx = first.x + float(i) + 0.5;
            float w = lanczos2((tx - p.x) / r.x) * wy;
            acc += w * textureLod(source, vec2(tx, ty) / level, lod);
            wsum += w;
        }
    }
    // Lanczos' negative lobes can overshoot at hard edges
    fragColor = clamp(acc / max(wsum, 1e-4), 0.0, 1.0) * qt_Opacity;
}
