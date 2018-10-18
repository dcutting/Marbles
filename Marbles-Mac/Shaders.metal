#include <metal_common>
#include <simd/simd.h>

//constant float3 light_position = float3(-1.0, 1.0, -1.0);
//constant float4 light_color = float4(1.0, 1.0, 1.0, 1.0);
constant float teapotMin = -0.144000;
constant float teapotMax = 0.164622;
constant float scaleLength = teapotMax - teapotMin;
constant uint NOISE_DIM = 512;
constant float NOISE_SIZE = 1;
//constant float3 darkBrown = float3(0.234f, 0.125f, 0.109f);
//constant float3 lightBrown = float3(0.168f, 0.133f, 0.043f);
//constant float numberOfRings = 84.0;
//constant float turbulence = 0.015;
//constant float PI = 3.14159;
//constant float materialShine = 50.0;

#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct MyNodeBuffer {
    float4x4 modelTransform;
    float4x4 modelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
};

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
} MyVertexInput;

struct SimpleVertex
{
    float4 position [[position]];
    float height;
};


// Generate a random float in the range [0.0f, 1.0f] using x, y, and z (based on the xor128 algorithm)
float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

// Return the interpolated noise for the given x, y, and z values. This is done by finding the whole
// number before and after the given position in each dimension. Using these values we can get 6 vertices
// that represent a cube that surrounds the position. We get each of the vertices noise values, and using the
// given position, interpolate between the noise values of the vertices to get the smooth noise.
float smoothNoise(float x, float y, float z)
{
    // Get the truncated x, y, and z values
    int intX = x;
    int intY = y;
    int intZ = z;

    // Get the fractional reaminder of x, y, and z
    float fractX = x - intX;
    float fractY = y - intY;
    float fractZ = z - intZ;

    // Get first whole number before
    int x1 = (intX + NOISE_DIM) % NOISE_DIM;
    int y1 = (intY + NOISE_DIM) % NOISE_DIM;
    int z1 = (intZ + NOISE_DIM) % NOISE_DIM;

    // Get the number after
    int x2 = (x1 + NOISE_DIM - 1) % NOISE_DIM;
    int y2 = (y1 + NOISE_DIM - 1) % NOISE_DIM;
    int z2 = (z1 + NOISE_DIM - 1) % NOISE_DIM;

    // Tri-linearly interpolate the noise
    float sumY1Z1 = mix(rand(x2,y1,z1), rand(x1,y1,z1), fractX);
    float sumY1Z2 = mix(rand(x2,y1,z2), rand(x1,y1,z2), fractX);
    float sumY2Z1 = mix(rand(x2,y2,z1), rand(x1,y2,z1), fractX);
    float sumY2Z2 = mix(rand(x2,y2,z2), rand(x1,y2,z2), fractX);

    float sumZ1 = mix(sumY2Z1, sumY1Z1, fractY);
    float sumZ2 = mix(sumY2Z2, sumY1Z2, fractY);

    float value = mix(sumZ2, sumZ1, fractZ);

    return value;
}

// Generate perlin noise for the given input values. This is done by generating smooth noise at mutiple
// different sizes and adding them together.
float noise3D(float unscaledX, float unscaledY, float unscaledZ)
{
    // Scale the values to force them in the range [0, NOISE_DIM]
    float x = ((unscaledX - teapotMin) / scaleLength) * NOISE_DIM;
    float y = ((unscaledY - teapotMin) / scaleLength) * NOISE_DIM;
    float z = ((unscaledZ - teapotMin) / scaleLength) * NOISE_DIM;

    float value = 0.0f, size = NOISE_SIZE, div = 0.0;

    //Add together smooth noise of increasingly smaller size.
    while(size >= 1.0f)
    {
        value += smoothNoise(x / size, y / size, z / size) * size;
        div += size;
        size /= 2.0f;
    }
    value /= div;

    return value;
}

//#pragma transparent
//#pragma body

//float noise = noise3D(_geometry.position.x+10000, _geometry.position.y+10000, _geometry.position.z+10000);
//_geometry.position += noise;
//_geometry.normal *= noise;

[[ patch(triangle, 3) ]]
vertex SimpleVertex myVertex(MyVertexInput in [[ stage_in ]],
                             constant SCNSceneBuffer& scn_frame [[buffer(0)]],
                             constant MyNodeBuffer& scn_node [[buffer(1)]])
{
    SimpleVertex vert;
    vert.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    float noise = noise3D(in.position.x+10000, in.position.y+10000, in.position.z+10000);
    vert.height = noise;

    return vert;
}

fragment half4 myFragment(SimpleVertex in [[stage_in]])
{
    half4 color;
    float r = in.height;
    color = half4(0.0, r, 0.0, 1.0);

    return color;
}
