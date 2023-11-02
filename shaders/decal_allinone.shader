

    Shader "Error.mdl/Decals/All-in-one Decal"
    {
        Properties
        {
			
			_Texture("Texture", 2D) = "white" {}
			_scale("scale", float) = 1.0
			[HDR] _color("Color", color) = (1, 1, 1, 1)
			[HDR] _fcolor("Fade out color", color) = (1, 1, 1, 0)
			_minRange("Fade out min radius", float) = 1.0
			_maxRange("Fade out max radius", float) = 2.0
			[IntRange] _MaxOverlap ("Max overlapping decals", range(0,16)) = 8
			[Toggle(_)] _Lighting ("Enable Lighting", int) = 0
			[Header(Sprite Sheet Parameters. Columns (X)   Rows (Y)   Total Frames (Z))]
			[Space(8)]
			_Params("Parameters", Vector) = (1,1,1,0)
			//_scale("scale", float) = 1.0
			
			[HideInInspector] _Blend("Blend Mode", Float) = 0 
			[HideInInspector] _SrcBlend("SrcBlend", Float) = 5 //"One"
			[HideInInspector] _DstBlend("DestBlend", Float) = 10 //"Zero"
        }
        SubShader
        {
            Tags {
                "Queue"="Alphatest+50"
                "RenderType"="Transparent"
				"IgnoreProjectors"="True"
            }
            Blend [_SrcBlend] [_DstBlend]
			Cull Front ZWrite Off ZTest GEqual
            LOD 100
     
            Pass
            {
			Tags {"LightMode"="ForwardBase"}
				Stencil {
					Ref [_MaxOverlap]
					Comp GEqual
					Pass IncrSat
				}
				
                CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
                #pragma vertex vert
                #pragma fragment frag
				#pragma target 5.0

				#pragma multi_compile_instancing
				#pragma instancing_options procedural:vertInstancingSetup
				#define UNITY_PARTICLE_INSTANCE_DATA instanceData

				struct instanceData
				{
					float3x4 transform;
					uint color;
				    float3 center;
					float3 size;
					float animFrame;
				};

                #include "UnityCG.cginc"
				#include "AutoLight.cginc"
				#include "Lighting.cginc"
				#include "UnityStandardParticleInstancing.cginc"


     
                struct VertIn
                {
                    float4 vertex : POSITION;
					float4 color : COLOR;
					#if !defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                    float4 center_xyz_size_x : TEXCOORD0;
					float3 size_yz_frame_x : TEXCOORD1;
					#endif
					UNITY_VERTEX_INPUT_INSTANCE_ID
                };
				
                struct VertOut
                {
                    float4 vertex : SV_POSITION;
                    float4 uv : TEXCOORD0;
                    float3 posWorld : TEXCOORD1;
                    float3 ray : TEXCOORD2;
					float3 size : TEXCOORD3;
					float4 uvParams : TEXCOORD4;
					float4 color : COLOR;
					UNITY_VERTEX_OUTPUT_STEREO
                };

				Texture2D _CameraDepthTexture;
				SamplerState sampler_CameraDepthTexture;
                Texture2D _Texture;
				SamplerState sampler_Texture;

				float4 _Texture_ST;
				half _minRange;
				half _maxRange;
				half _scale;
				float4 _color;
				float4 _fcolor;
				float4 _Params;
				int _Lighting;
     
				float3 get_lighting(float3 normal)
				{
					float3 light_color;
	
					// Real-time Directional light
					half nl = saturate(dot(_WorldSpaceLightPos0.xyz, normal));
					float3 dir_light = nl * _LightColor0.rgb;
	
					//Baked lighting
					float3 baked_light = ShadeSH9(float4(normal,1));
	
	
					//Choose the direction of the light based on which is stronger
					light_color = dir_light + baked_light;
	

					return light_color;
				}
     
				float4 sprite_sheet_params(float4 Params, float manualFrame)
				{
					//From the frame number, get the row and column of the frame on the sprite sheet.
					uint3 dim = floor(Params.xyz);
					uint frame_num = floor(fmod(manualFrame, Params.z));
					int2 frame = int2(frame_num % dim.x, frame_num / dim.x);
					float4 uv_scaleOffset = float4(1.0 / Params.x, frame[0] / Params.x, 1.0 / Params.y, (- frame[1] + Params.y - 1.0) / Params.y);
					return uv_scaleOffset;
				}

                VertOut vert(VertIn v)
                {
                    VertOut o;
					UNITY_SETUP_INSTANCE_ID(v);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                    o.vertex = UnityObjectToClipPos(v.vertex);
                    float4 screenPos = ComputeGrabScreenPos(o.vertex);
                    o.uv = screenPos;
					o.color = v.color;
					vertInstancingColor(o.color);

					float3 center;
					#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
						UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
						center = data.center;
						o.size.xyz = data.size*_scale;
						o.uvParams = sprite_sheet_params(_Params, data.animFrame);
					#else
						center = v.center_xyz_size_x.xyz;
						o.size.xyz = float3(v.center_xyz_size_x.w, v.size_yz_frame_x.xy)*_scale;
						o.uvParams = sprite_sheet_params(_Params, v.size_yz_frame_x.z);
					#endif

					o.posWorld = center;

					float3 wpos = mul((float3x4)unity_ObjectToWorld, float4(v.vertex.xyz, 1));

                    o.ray = mul((float3x4)UNITY_MATRIX_V, float4(wpos, 1)).xyz * float3(-1,-1,1);
                    return o;
                }
     
               
                
     
                float4 frag (VertOut i) : SV_Target
                {
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                    float rawDepth = _CameraDepthTexture.SampleLevel(sampler_CameraDepthTexture, i.uv.xy/i.uv.w, 0);
                    float linearDepth = Linear01Depth(rawDepth);
                    half4 scannerCol = half4(0, 0, 0, 0);
                    i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
                    float4 vpos = float4(i.ray * linearDepth, 1);
                    float3 wpos = mul(unity_CameraToWorld, vpos).xyz;
					float3 wposx = ddx(wpos);
					float3 wposy = ddy(wpos);
					float3 normal = normalize(cross(wposy,wposx));

					float2 coords1 = ((wpos.zy - i.posWorld.zy) / (i.size.zy * _Texture_ST.xy) + float2(0.5, 0.5));
					float2 coords2 = ((wpos.xz - i.posWorld.xz) / (i.size.xz * _Texture_ST.xy) + float2(0.5, 0.5));
					float2 coords3 = ((wpos.xy - i.posWorld.xy) / (i.size.xy * _Texture_ST.xy) + float2(0.5, 0.5));
					
					coords1.x = normal.x >= 0.0 ? coords1.x : 1.0 - coords1.x;
					coords2.x = normal.y >= 0.0 ? coords2.x : 1.0 - coords2.x;
					coords3.x = normal.z <= 0.0 ? coords3.x : 1.0 - coords3.x;
					

					float2 coords = (abs(normal.y) <= abs(normal.x))*(abs(normal.z) <= abs(normal.x))*coords1
								   +(abs(normal.x) <= abs(normal.y))*(abs(normal.z) <= abs(normal.y))*coords2
								   +(abs(normal.x) <= abs(normal.z))*(abs(normal.y) <= abs(normal.z))*coords3;
					
					if (coords1.x < 0.0 || coords1.x > 1.0 || coords2.x < 0.0 || coords2.x > 1.0 || coords3.y < 0.0 || coords3.y > 1.0)
					{
						discard;
					}

					coords = float2(mad(coords.x, i.uvParams.x, i.uvParams.y), mad(coords.y, i.uvParams.z, i.uvParams.w));


					float4 finalColor = _Texture.Sample(sampler_Texture, coords);

					float3 lighting = _Lighting ? get_lighting(normal) : float3(1,1,1);

					finalColor.rgb *= lighting;

					return finalColor * i.color;
                }
                ENDCG
            }
        }
		CustomEditor "ErrorMdl.Decals.DecalShaderGUI"
    }

