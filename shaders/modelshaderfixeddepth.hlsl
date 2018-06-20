float4x4 g_WorldViewProj : register(c24);

struct VS_INPUT
{
    float4 vPosition : POSITION;
};

struct VS_OUTPUT
{
    float4 vPosition : POSITION;
};

VS_OUTPUT VS(const VS_INPUT v)
{
  VS_OUTPUT outv;
  float4 c = { 1.0f, 0.0f, 0.0f, 0.0f };
  float4 tmp;
  tmp = v.vPosition.xyzx * c.xxxy + c.yyyx;
  outv.vPosition = mul( tmp, g_WorldViewProj );
  return outv;
}

struct PS_OUTPUT
{
    float4 Color : COLOR0;
};

PS_OUTPUT PS(void)
{
  PS_OUTPUT outp;
  float4 c = { 1.0f, 0.0f, 0.0f, 0.0f };
  outp.Color = c.x;
  return outp;
}
