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
            Cull Front
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 posVS : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float _Intensity;
                float4 _HazeColor;
                float _Cloudiness;
                float _FrostScatter;
                float _CloudScale;
            CBUFFER_END

            // Losowy wektor jednostkowy 2D dla szumu gradientowego (Perlin-style) - brak kwadratowych bloków
            float2 Hash22Grad(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yzx + 33.33);
                float2 h = frac((p3.xx + p3.yz) * p3.zy) * 6.2831853;
                return float2(cos(h.x), sin(h.x));
            }

            // Gładki szum gradientowy C2 (interpolacja wielomianem 5. stopnia) bez widocznych przejść siatki
            float GradientNoise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

                float n00 = dot(Hash22Grad(i + float2(0.0, 0.0)), f - float2(0.0, 0.0));
                float n10 = dot(Hash22Grad(i + float2(1.0, 0.0)), f - float2(1.0, 0.0));
                float n01 = dot(Hash22Grad(i + float2(0.0, 1.0)), f - float2(0.0, 1.0));
                float n11 = dot(Hash22Grad(i + float2(1.0, 1.0)), f - float2(1.0, 1.0));

                return lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y) * 0.5 + 0.5;
            }

            // Wielowarstwowy szum FBM z rotacją każdej oktawy (eliminuje prostopadłe/kwadratowe artefakty)
            float LensCloudFBM(float2 p)
            {
                float v = 0.0;
                float amp = 0.55;
                float2 pos = p * _CloudScale;
                const float2x2 rot = float2x2(0.80, -0.60, 0.60, 0.80);

                for (int k = 0; k < 4; k++)
                {
                    v += amp * GradientNoise(pos);
                    pos = mul(rot, pos) * 2.02 + float2(3.17, 7.83);
                    amp *= 0.5;
                }
                return saturate(v);
            }

            // Szum ziarnisty liczony po całkowitych współrzędnych piksela ekranu (brak kwadratowych kafelków UV)
            float ScreenSpaceGrain(float2 pixelCoord)
            {
                float2 p = floor(pixelCoord);
                return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                output.posVS = TransformWorldToView(posWS);
                output.positionHCS = TransformWorldToHClip(posWS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                float3 viewDir = normalize(input.posVS);
                if (viewDir.z > 0.0)
                    return half4(0, 0, 0, 0);

                // Gładkie mapowanie kierunku wzroku bez szwów
                float2 dirCoords = viewDir.xy / (1.0 + abs(viewDir.z));

                float clouds = LensCloudFBM(dirCoords * 1.6);
                float grain = (ScreenSpaceGrain(input.positionHCS.xy) - 0.5) * _FrostScatter * _Intensity;

                // Niejednorodna gęstość zmętnienia + silniejsze zamglenie przy wyższym Intensity
                float cloudFactor = lerp(1.0, lerp(0.72, 1.28, clouds), _Cloudiness);
                float alpha = saturate(_Intensity * _HazeColor.a * cloudFactor + grain * 0.5);

                // Lekkie pożółknięcie / wyblaknięcie barwy
                float3 rgb = saturate(_HazeColor.rgb + (clouds - 0.5) * 0.06 + grain * 0.35);

                return half4(rgb, alpha);
            }
            ENDHLSL
        }
    }
}
