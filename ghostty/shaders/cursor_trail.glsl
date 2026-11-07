// Cursor trail for Ghostty: a tapered smear from the old cursor position
// to the new one that shrinks into the cursor and fades out.
// Tweak DURATION (seconds) and OPACITY (0-1) to taste.
const float DURATION = 0.20;
const float OPACITY  = 0.65;

float sdBox(vec2 p, vec2 h) {
    vec2 d = abs(p) - h;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float easeOutCubic(float x) { return 1.0 - pow(1.0 - x, 3.0); }

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    float prog = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (prog >= 1.0 || iFocus == 0 || iPreviousCursor.z <= 0.0) return;

    // Cursor rects: .xy is the left/top corner (GL coords, y up), .zw is size.
    vec2 hCur  = iCurrentCursor.zw * 0.5;
    vec2 hPrev = iPreviousCursor.zw * 0.5;
    vec2 B = iCurrentCursor.xy  + vec2(hCur.x,  -hCur.y);
    vec2 A = iPreviousCursor.xy + vec2(hPrev.x, -hPrev.y);
    if (dot(B - A, B - A) < 1.0) return;

    float e = easeOutCubic(prog);
    vec2 tail = mix(A, B, e);              // the tail chases the cursor
    vec2 seg = B - tail;
    float t = clamp(dot(fragCoord - tail, seg) / max(dot(seg, seg), 1e-4), 0.0, 1.0);
    vec2 h = mix(hCur * 0.35, hCur, t);    // thin at the tail, full at the cursor
    float d = sdBox(fragCoord - (tail + seg * t), h);

    float a = (1.0 - smoothstep(-1.0, 1.0, d)) * OPACITY * (1.0 - e);
    a *= step(0.0, sdBox(fragCoord - B, hCur));   // leave the real cursor alone
    fragColor.rgb = mix(fragColor.rgb, iCurrentCursorColor.rgb, a);
}
