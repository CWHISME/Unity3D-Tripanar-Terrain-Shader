
//2016.12.15 by cwhisme
//在FirstPass，即前一份代码基础上，处理超出四张地形贴图

Shader "Hidden/TerrainEngine/Splatmap/TriplanarTerrain-AddPass"
{
	Properties{
		// set by terrain engine
		[HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
		[HideInInspector] _Splat3("Layer 3 (A)", 2D) = "white" {}
		[HideInInspector] _Splat2("Layer 2 (B)", 2D) = "white" {}
		[HideInInspector] _Splat1("Layer 1 (G)", 2D) = "white" {}
		[HideInInspector] _Splat0("Layer 0 (R)", 2D) = "white" {}
		[HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
		[HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
		[HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
		[HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
		[HideInInspector][Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
		[HideInInspector][Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
		[HideInInspector][Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
		[HideInInspector][Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
		[HideInInspector] _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 1.0
		[HideInInspector] _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 1.0
		[HideInInspector] _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 1.0
		[HideInInspector] _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 1.0

	}

	SubShader{
			Tags{
			"Queue" = "Geometry-99"
			"IgnoreProjector" = "True"
			"RenderType" = "Opaque"
		}

		CGPROGRAM
		#pragma surface surf Standard decal:add vertex:vert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer fullforwardshadows
		#pragma multi_compile_fog
		#pragma target 3.0
		// needs more than 8 texcoords
		#pragma exclude_renderers gles
		#include "UnityPBSLighting.cginc"

		#pragma multi_compile __ _TERRAIN_NORMAL_MAP

		#define TERRAIN_SPLAT_ADDPASS
		#define TERRAIN_SURFACE_OUTPUT SurfaceOutputStandard

		sampler2D _Control;
		float4 _Control_ST;
		sampler2D _Splat0, _Splat1, _Splat2, _Splat3;
		half4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
		#ifdef _TERRAIN_NORMAL_MAP
		sampler2D _Normal0, _Normal1, _Normal2, _Normal3;
		#endif

		half _Metallic0;
		half _Metallic1;
		half _Metallic2;
		half _Metallic3;

		half _Smoothness0;
		half _Smoothness1;
		half _Smoothness2;
		half _Smoothness3;

		float _TriplanarBlendSharpness;
		float _TextureScale;

		struct Input
		{
			float2 tc_Control : TEXCOORD4;
			float3 wNormal;
			float3 worldPos;
			UNITY_FOG_COORDS(5)
		};

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.tc_Control = TRANSFORM_TEX(v.texcoord, _Control);
			float4 pos = mul(UNITY_MATRIX_MVP, v.vertex);
			UNITY_TRANSFER_FOG(o, pos);

			o.wNormal =normalize(mul(unity_ObjectToWorld, fixed4(v.normal, 0)).xyz);

			#ifdef _TERRAIN_NORMAL_MAP
			v.tangent.xyz = cross(v.normal, float3(0, 0, 1));
			v.tangent.w = -1;
			#endif
		}

		void surf(Input IN, inout SurfaceOutputStandard o) {
			half4 splat_control;
			half weight;
			fixed4 mixedDiffuse=0;
			half4 defaultSmoothness = half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);

			//Custom begin=================================================<<<<<<<<<<<<<<<<<<<<<<<<<<<
			splat_control = tex2D(_Control, IN.tc_Control);
			weight = dot(splat_control, half4(1, 1, 1, 1));

			#if !defined(SHADER_API_MOBILE) && defined(TERRAIN_SPLAT_ADDPASS)
				clip(weight == 0.0f ? -1 : 1);
			#endif

			splat_control /= (weight + 1e-3f);

			//triplanar---------------<<<<<<<<<<<<
			//计算权重
			float3 N =normalize( IN.wNormal);
			//N -= 0.4f;
			half3 blendWeights = pow(abs(IN.wNormal), _TriplanarBlendSharpness);
			blendWeights /= dot(blendWeights, 1.0);
			half2 xUV = IN.worldPos.zy;// / _TextureScale;
			half2 yUV = IN.worldPos.xz;// / _TextureScale;
			half2 zUV = IN.worldPos.xy;// / _TextureScale;

			//通常 Triplanar实现，只是多了三张贴图处理
			fixed4 tex0X =  tex2D(_Splat0, (xUV*_Splat0_ST.xy + _Splat0_ST.zw)/ _TextureScale);
			fixed4 tex0Y = tex2D(_Splat0, (yUV*_Splat0_ST.xy + _Splat0_ST.zw) / _TextureScale);
			fixed4 tex0Z = tex2D(_Splat0, (zUV*_Splat0_ST.xy + _Splat0_ST.zw) / _TextureScale);

			fixed4 tex1X = tex2D(_Splat1, (xUV*_Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);
			fixed4 tex1Y = tex2D(_Splat1, (yUV*_Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);
			fixed4 tex1Z =  tex2D(_Splat1, (zUV*_Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);

			fixed4 tex2X = tex2D(_Splat2, (xUV*_Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);
			fixed4 tex2Y = tex2D(_Splat2, (yUV*_Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);
			fixed4 tex2Z = tex2D(_Splat2, (zUV*_Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);

			fixed4 tex3X = tex2D(_Splat3, (xUV*_Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);
			fixed4 tex3Y = tex2D(_Splat3, (yUV*_Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);
			fixed4 tex3Z = tex2D(_Splat3, (zUV*_Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);

			fixed4 tex0 = tex0X*blendWeights.x + tex0Y * blendWeights.y + tex0Z * blendWeights.z;
			fixed4 tex1 =  tex1X*blendWeights.x + tex1Y * blendWeights.y + tex1Z * blendWeights.z;
			fixed4 tex2 = tex2X*blendWeights.x + tex2Y * blendWeights.y + tex2Z * blendWeights.z;
			fixed4 tex3 = tex3X*blendWeights.x + tex3Y * blendWeights.y + tex3Z * blendWeights.z;

			//融合权重，添加高光
			tex0 *= splat_control.r *half4(1.0, 1.0, 1.0, defaultSmoothness.r);
			tex1 *= splat_control.g *half4(1.0, 1.0, 1.0, defaultSmoothness.g);
			tex2 *= splat_control.b *half4(1.0, 1.0, 1.0, defaultSmoothness.b);
			tex3 *= splat_control.a *half4(1.0, 1.0, 1.0, defaultSmoothness.a);

			mixedDiffuse = tex0 + tex1 + tex2 + tex3;

			//---------法线---------<<<<<<<<<<<<<<<<<<<<<<<<<<<<
			#ifdef _TERRAIN_NORMAL_MAP
			fixed4 nrm = 0.0f;

			fixed4 nm0X = tex2D(_Normal0, (xUV* _Splat0_ST.xy + _Splat0_ST.zw)/ _TextureScale);
			fixed4 nm0Y = tex2D(_Normal0, (yUV* _Splat0_ST.xy + _Splat0_ST.zw) / _TextureScale);
			fixed4 nm0Z = tex2D(_Normal0, (zUV* _Splat0_ST.xy + _Splat0_ST.zw) / _TextureScale);
											
			fixed4 nm1X = tex2D(_Normal1, (xUV* _Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);
			fixed4 nm1Y = tex2D(_Normal1, (yUV* _Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);
			fixed4 nm1Z = tex2D(_Normal1, (zUV* _Splat1_ST.xy + _Splat1_ST.zw) / _TextureScale);
													  
			fixed4 nm2X = tex2D(_Normal2, (xUV* _Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);
			fixed4 nm2Y = tex2D(_Normal2, (yUV* _Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);
			fixed4 nm2Z = tex2D(_Normal2, (zUV* _Splat2_ST.xy + _Splat2_ST.zw)/ _TextureScale);
						 								
			fixed4 nm3X = tex2D(_Normal3, (xUV* _Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);
			fixed4 nm3Y = tex2D(_Normal3, (yUV* _Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);
			fixed4 nm3Z = tex2D(_Normal3, (zUV* _Splat3_ST.xy + _Splat3_ST.zw)/ _TextureScale);

			fixed4 nm0 = nm0X*blendWeights.x +nm0Y * blendWeights.y + nm0Z * blendWeights.z;
			fixed4 nm1 =  nm1X*blendWeights.x + nm1Y * blendWeights.y + nm1Z * blendWeights.z;
			fixed4 nm2 = nm2X*blendWeights.x + nm2Y * blendWeights.y + nm2Z * blendWeights.z;
			fixed4 nm3 = nm3X*blendWeights.x + nm3Y * blendWeights.y + nm3Z * blendWeights.z;

			nm0 *= splat_control.r;
			nm1 *= splat_control.g;
			nm2 *= splat_control.b;
			nm3 *= splat_control.a;

			nrm = nm0 + nm1 + nm2 + nm3;
			o.Normal = UnpackNormal(nrm);
			#endif
			//End Custom=================================================<<<<<<<<<<<<<<<<<<<<<<<<<<<

			o.Albedo = mixedDiffuse.rgb;//max(fixed3(0.001, 0.001, 0.001), mixedDiffuse.rgb); 
			o.Alpha = weight;
			o.Smoothness = mixedDiffuse.a;
			o.Metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
		}

		void SplatmapFinalColor(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 color)
		{
			color *= o.Alpha;
			#ifdef TERRAIN_SPLAT_ADDPASS
			UNITY_APPLY_FOG_COLOR(IN.fogCoord, color, fixed4(0, 0, 0, 0));
			#else
			UNITY_APPLY_FOG(IN.fogCoord, color);
			#endif
		}

		void SplatmapFinalPrepass(Input IN, TERRAIN_SURFACE_OUTPUT o, inout fixed4 normalSpec)
		{
			normalSpec *= o.Alpha;
		}

		void SplatmapFinalGBuffer(Input IN, TERRAIN_SURFACE_OUTPUT o, inout half4 outGBuffer0, inout half4 outGBuffer1, inout half4 outGBuffer2, inout half4 emission)
		{
			UnityStandardDataApplyWeightToGbuffer(outGBuffer0, outGBuffer1, outGBuffer2, o.Alpha);
			emission *= o.Alpha;
		}

		ENDCG
	}

	Fallback "Hidden/TerrainEngine/Splatmap/Diffuse-AddPass"
}