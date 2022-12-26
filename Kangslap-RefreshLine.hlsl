// ! ///////////////////////
// !     //// KANGSLAP ////
// !    ///////////////////////

// * Data provided by Windows Terminal
Texture2D shaderTexture;
SamplerState samplerState;

// ? /////////////////////////
// ? ////// BEGIN CRT-FLAT

cbuffer PixelShaderSettings {
	// * The number of seconds since the pixel shader was enabled
	float  Time;
	// * UI Scale
	float  Scale;
	// * Resolution of the shaderTexture
	float2 Resolution;
	// * Background color as rgba
	float4 Background;
};

// * Settings
#define ENABLE_REFRESHLINE 1 // ? bool
#define ENABLE_NOISE 1 // ? bool
#define GRAIN_INTENSITY 0.02 // ? float4
#define TINT_COLOR float4(1, 0.7f, 0, 0)

// * Grain Lookup Table
#define a0  0.151015505647689
#define a1 -0.5303572634357367
#define a2  1.365020122861334
#define b0  0.132089632343748
#define b1 -0.7607324991323768

static const float4 tint = TINT_COLOR;

float permute(float x)
{
	x *= (34 * x + 1);
	return 289 * frac(x * 1 / 289.0f);
}

float rand(inout float state)
{
	state = permute(state);
	return frac(state / 41.0f);
}

float4 mainImage(float2 tex) : TARGET
{
	float2 xy = tex.xy;
		
	float4 color = shaderTexture.Sample(samplerState, xy);

	#if ENABLE_REFRESHLINE
	float timeOver = fmod(Time / 10, 1);
	float refreshLineColorTint = timeOver - xy.y;
	if(xy.y > timeOver && xy.y - 0.03f < timeOver ) color.rgb += (refreshLineColorTint * 2.0f);
	#endif

	#if ENABLE_GRAIN
	float3 m = float3(tex, Time % 5 / 5) + 1.;
	float state = permute(permute(m.x) + m.y) + m.z;

	float p = 0.95 * rand(state) + 0.025;
	float q = p - 0.5;
	float r2 = q * q;

	float grain = q * (a2 + (a1 * r2 + a0) / (r2 * r2 + b1 * r2 + b0));
	color.rgb += GRAIN_INTENSITY * grain;
	#endif

	return color;
}

// ? ////// END CRT-FLAT
// ? ///////////////////////

// ? ///////////////////////
// ? /// BEGIN RASTERING

// * A pixel shader is a program that given a texture coordinate (tex) produces a color.
// * tex is an x,y tuple that ranges from 0,0 (top left) to 1,1 (bottom right).
// * Just ignore the pos parameter.
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    // * Read the color value at the current texture coordinate (tex)
    // * float4 is tuple of 4 floats, rgba
    float4 color = shaderTexture.Sample(samplerState, tex);

    // * Read the color value at some offset, will be used as shadow
    float4 ocolor = shaderTexture.Sample(samplerState, tex+2.0*Scale*float2(-1.0, -1.0)/Resolution.y);

    // * Thickness of raster
	const float thickness = 5;

    float ny = floor(tex.y/thickness);
    float my = tex.y%thickness;
    const float pi = 3.141592654;

    // * ny is used to compute the rasterbar base color
    float cola = ny*2.0*pi;
    float3 col = 0.75+0.25*float3(sin(cola*0.111), sin(cola*0.222), sin(cola*0.333));

    float brightness = 0.1;

    float3 rasterColor = - col*brightness + mainImage(tex)*1.7;

    // * lerp(x, y, a) is another very useful function: https://en.wikipedia.org/wiki/Linear_interpolation
    float3 final = rasterColor;
    // * Create the drop shadow of the terminal graphics
    // *  .w is the alpha channel, 0 is fully transparent and 1 is fully opaque
    final = lerp(final, float(0.0), ocolor.w);
    // * Draw the terminal graphics
    final = lerp(final, color.xyz, color.w);

    // * Return the final color, set alpha to 0.5 (Set it to 1 for for opaque)
	final = - final + mainImage(tex)*2;
    return float4(final, 0.5);
}

// ? /// END RASTERING
// ? ////////////////////
