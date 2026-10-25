// On a cursor jump, a short fading smear from where it was to where it is.
const float DURATION = 0.12;
const float OPACITY = 0.5;

// whether p is in the box of half-size hs swept from a to a + d
bool swept(vec2 p, vec2 a, vec2 d, vec2 hs) {
    float lo = 0.0, hi = 1.0;
    for (int i = 0; i < 2; i++) {
        float off = p[i] - a[i];
        if (abs(d[i]) < 1e-3) {
            if (abs(off) > hs[i])
                return false;
        } else {
            float s0 = (off - hs[i]) / d[i], s1 = (off + hs[i]) / d[i];
            lo = max(lo, min(s0, s1));
            hi = min(hi, max(s0, s1));
        }
    }
    return lo <= hi;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    float t = (iTime - iTimeCursorChange) / DURATION;
    if (t >= 1.0 || iPreviousCursor.z <= 0.0)
        return;

    // xy is the top-left corner, with y up
    vec2 hs = iCurrentCursor.zw * 0.5;
    vec2 head = iCurrentCursor.xy + vec2(hs.x, -hs.y);
    vec2 prev = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;
    if (distance(head, prev) < iCurrentCursor.w * 1.5)
        return;

    vec2 tail = mix(prev, head, 1.0 - pow(1.0 - t, 3.0));
    float cover = swept(fragCoord, tail, head - tail, hs - 0.5) ? 1.0
        : swept(fragCoord, tail, head - tail, hs + 0.5) ? 0.5 : 0.0;
    float a = cover * OPACITY * (1.0 - t);
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, a);
    fragColor.a = max(fragColor.a, a);
}
