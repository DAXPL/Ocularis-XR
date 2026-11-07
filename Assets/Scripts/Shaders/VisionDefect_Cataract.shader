Shader "Ocularis/Defects/Cataract"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _HazeColor ("Kolor Mgly (Mleczno-zolty)", Color) = (0.95, 0.89, 0.72, 0.78)
        _Cloudiness ("Niejednorodnosc (Brudna szyba)", Range(0, 1)) = 0.45
        _FrostScatter ("Rozproszenie swiatla (Ziarno)", Range(0, 0.25)) = 0.08
        _CloudScale ("Skala Zmetnienia", Float) = 3.5
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Overlay"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "CataractOverlay"
            Cull Off
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 eyeUV : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float _Intensity;
                float4 _HazeColor;
                float _Cloudiness;
                float _FrostScatter;
                float _CloudScale;
            CBUFFER_END

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float ValueNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);

                float a = Hash21(i);
                float b = Hash21(i + float2(1.0, 0.0));
                float c = Hash21(i + float2(0.0, 1.0));
                float d = Hash21(i + float2(1.0, 1.0));

                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            // Wielowarstwowy szum FBM imitujący nierównomierne zmętnienie soczewki ("brudna szyba")
            float LensCloudFBM(float2 uv)
            {
                float v = 0.0;
                float amp = 0.5;
                float2 p = uv * _CloudScale;
                for (int k = 0; k < 3; k++)
                {
                    v += amp * ValueNoise(p);
                    p = p * 2.03 + float2(1.7, 9.2);
                    amp *= 0.5;
                }
                return v;
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 posVS = TransformWorldToView(posWS);

                output.positionHCS = TransformWorldToHClip(posWS);
                // Współrzędne kątowe względem osi optycznej danego oka
                output.eyeUV = (posVS.xy / max(0.001, -posVS.z)) * 0.5 + 0.5;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                float2 uv = input.eyeUV;
                float clouds = LensCloudFBM(uv);
                float grain = (Hash21(uv * 950.0) - 0.5) * _FrostScatter * _Intensity;

                // Niejednorodna gęstość zmętnienia + silniejsze zamglenie przy wyższym Intensity
                float cloudFactor = lerp(1.0, lerp(0.65, 1.35, clouds), _Cloudiness);
                float alpha = saturate(_Intensity * _HazeColor.a * cloudFactor + grain);

                // Lekkie pożółknięcie / wyblaknięcie barwy
                float3 rgb = saturate(_HazeColor.rgb + grain * 0.6);

                return half4(rgb, alpha);
            }
            ENDHLSL
        }
    }
}
