#include <metal_stdlib>
#include <metal_common>
#include <simd/simd.h>

//uniform float Amplitude = 0.1;

//constant float3 light_position = float3(-1.0, 1.0, -1.0);
//constant float4 light_color = float4(1.0, 1.0, 1.0, 1.0);
constant float teapotMin = -1000;//0.144000;
constant float teapotMax = 1000;//0.164622;
constant float scaleLength = teapotMax - teapotMin;
constant uint NOISE_DIM = 10000;
constant float NOISE_SIZE = 100;
////constant float3 darkBrown = float3(0.234f, 0.125f, 0.109f);
////constant float3 lightBrown = float3(0.168f, 0.133f, 0.043f);
////constant float numberOfRings = 84.0;
////constant float turbulence = 0.015;
////constant float PI = 3.14159;
////constant float materialShine = 50.0;

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
    //    value /= div;

    return value;
}

//[[patch(triangle, 3)]]
//vertex float4 my_post_tessellation_vertex_function() {
//    return float4(rand(1,2,3), rand(4,5,6), rand(7,8,9), 1.0);
//}

#pragma transparent
#pragma body

float offset = 0;
vec4 p = _geometry.position;
float noise = noise3D(p.x+offset, p.y+offset, p.z+offset);
float delta = 10000.0 + noise / 10.0;//rand(p.x, p.y, p.z);
vec4 n = normalize(p);// - vec4(-100.0, 0.0, 0.0, 0.0);
//vec4 s = vec4(n[0] * delta, n[1] * delta, n[2] * delta, n[3] * delta);
_geometry.position = vec4(n[0] * delta, n[1] * delta, n[2] * delta, 1.0);//vec4(0.0, 0.0, 0.0, 1.0);//rand(_geometry.position.x, _geometry.position.y, _geometry.position.z);//noise;
//_geometry.normal *= noise;
_geometry.color = float4(0.0, noise / 100.0, 1.0, 1.0);

//_geometry.position += vec4(_geometry.normal, 1.0) * (Amplitude*_geometry.position.y*_geometry.position.x) * sin(1.0 * u_time);