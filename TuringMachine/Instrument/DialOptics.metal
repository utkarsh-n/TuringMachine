#include <metal_stdlib>
using namespace metal;

namespace TuringDial {

// The scene is a fixed instrument substrate. Refraction changes the sampled
// position rather than translating the substrate or distorting readable labels.
float3 substrate(float2 p, float pixelWidth) {
    float radius = length(p);
    float2 gridCell = abs(fract(p * 4.0 + 0.5) - 0.5) / 4.0;
    float gridDistance = min(gridCell.x, gridCell.y);
    float grid = 1.0 - smoothstep(pixelWidth * 0.55, pixelWidth * 1.45, gridDistance);

    float ringDistance = abs(fract(radius * 4.0 + 0.16) - 0.5) / 4.0;
    float rings = 1.0 - smoothstep(pixelWidth * 0.55, pixelWidth * 1.35, ringDistance);
    float peripheral = smoothstep(0.35, 0.78, radius);
    float3 navy = float3(0.023, 0.057, 0.086);
    float3 cyan = float3(0.33, 0.74, 0.83);
    float3 amber = float3(0.73, 0.47, 0.20);
    float3 scene = navy + cyan * grid * (0.018 + 0.05 * peripheral);
    scene += cyan * rings * peripheral * 0.06;
    // Two fine registration fiducials expose bending when the phone is tilted.
    float fiducial = (1.0 - smoothstep(pixelWidth, pixelWidth * 2.4, abs(p.x + 0.63)))
        * (1.0 - smoothstep(0.10, 0.17, abs(p.y - 0.24)));
    scene += amber * fiducial * 0.15;
    return scene;
}

float2 throughGlass(float2 p, float3 viewDirection, float3 normal, float thickness, float index) {
    // Snell's law at the convex air/glass interface. The ray intersects a
    // virtual substrate behind the lens; material index is wavelength specific.
    float3 ray = refract(-viewDirection, normal, 1.0 / index);
    return p + ray.xy * thickness / max(0.15, -ray.z);
}

}

[[ stitchable ]] half4 turingDialOptics(float2 position, half4 color, float2 size, float2 tilt) {
    float lensRadius = min(size.x, size.y) * 0.5;
    float2 p = (position - size * 0.5) / max(1.0, lensRadius);
    float radius = length(p);
    if (radius > 1.0) { return half4(0.0); }
    float pixelWidth = 1.0 / max(1.0, lensRadius);

    // Spherical-cap normal and thickness form a convex optical volume.
    // A steep annular bevel gives the rim its grazing-angle Fresnel response.
    float capZ = sqrt(max(0.001, 1.0 - dot(p, p) * 0.6084));
    float bevel = smoothstep(0.88, 0.997, radius);
    float3 normal = normalize(float3(p * (0.78 + bevel * 0.35), capZ * (1.0 - bevel * 0.65)));
    float3 viewDirection = normalize(float3(-tilt.x * 0.24, tilt.y * 0.24, 1.0));
    float thickness = 0.045 + 0.36 * (capZ - 0.626) / 0.374;

    float2 greenRay = TuringDial::throughGlass(p, viewDirection, normal, thickness, 1.458);
    float3 transmitted = TuringDial::substrate(greenRay, pixelWidth);
    // Dispersion stays confined to the rim. The center remains visually calm.
    float dispersion = smoothstep(0.67, 0.98, radius);
    float2 redRay = TuringDial::throughGlass(p, viewDirection, normal, thickness, 1.447);
    float2 blueRay = TuringDial::throughGlass(p, viewDirection, normal, thickness, 1.472);
    transmitted.r = mix(transmitted.r, TuringDial::substrate(redRay, pixelWidth).r, dispersion);
    transmitted.b = mix(transmitted.b, TuringDial::substrate(blueRay, pixelWidth).b, dispersion);

    // Schlick's Fresnel approximation with n = 1.458 (F0 approximately 0.035).
    float incidence = clamp(dot(normal, viewDirection), 0.0, 1.0);
    float fresnel = 0.035 + 0.965 * pow(1.0 - incidence, 5.0);
    float3 reflectedRay = reflect(-viewDirection, normal);
    // The world-space softbox rotates opposite to the phone-relative view.
    // Moving both together would cancel much of the optical response.
    float2 softboxDirection = float2(-0.45 - tilt.x * 0.17, -0.65 + tilt.y * 0.17);
    float2 softboxDistance = (reflectedRay.xy - softboxDirection) / float2(0.15, 0.37);
    float softbox = exp(-dot(softboxDistance, softboxDistance) * 0.5);
    float calmCenter = mix(0.18, 1.0, smoothstep(0.35, 0.78, radius));
    float3 reflected = float3(0.17, 0.30, 0.35) + float3(0.82, 0.92, 1.0) * softbox * 2.2;
    float3 result = mix(transmitted, reflected, fresnel * calmCenter);
    result += float3(0.53, 0.69, 0.76) * softbox * 0.11 * calmCenter;

    // A thin edge caustic reveals the changing incidence without a neon halo.
    float caustic = exp(-pow((radius - 0.958) / 0.012, 2.0));
    float directional = pow(max(0.0, dot(normalize(p + 0.0001), normalize(softboxDirection))), 5.0);
    result += float3(0.19, 0.54, 0.61) * caustic * directional * 0.22;
    half alpha = color.a;
    return half4(half3(clamp(result, 0.0, 1.0)) * alpha, alpha);
}
