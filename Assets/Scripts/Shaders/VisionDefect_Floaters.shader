Shader "Ocularis/Defects/Floaters"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _FloaterColor ("Kolor Metow", Color) = (0.08, 0.08, 0.09, 0.68)
        _InertiaOffset ("Przesuniecie Bezwladnosci (XY)", Vector) = (0, 0, 0, 0)
        _Density ("Gestosc i Liczba Metow", Range(0.5, 3.0)) = 1.4
        _FloaterSize ("Rozmiar Metow", Range(0.5, 2.5)) = 1.0
        _FloaterSize ("Rozmiar Metow", Range(0.3, 2.5)) = 1.0
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
            Name "FloatersOverlay"
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
                float4 _FloaterColor;
                float4 _InertiaOffset;
                float _Density;
                float _FloaterSize;
            CBUFFER_END

            float2 Hash22(float2 p)
            {
                float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.xx + p3.yz) * p3.zy);
            }

            // Odległość od zakrzywionego odcinka ("nitki / wstążki" kolagenowej w ciele szklistym)
            // z indywidualnym obrotem i powolnym falowaniem, aby męty nie ruszały się jak sztywna tapeta
            // Pomniejszone wymiary, aby męty były delikatne i realistyczne w goglach VR
            float WormFloater(float2 uv, float2 seed, float radius, float timePhase)
            {
                float2 randPos = Hash22(seed);
                float2 individualDrift = float2(
                    sin(timePhase * (0.6 + randPos.x * 0.5) + seed.x),
                    cos(timePhase * (0.5 + randPos.y * 0.5) + seed.y)
                ) * 0.022;
                ) * 0.015;

                float2 center = (randPos - 0.5) * 0.78 + individualDrift;
                float2 center = (randPos - 0.5) * 0.58 + individualDrift;
                float angle = Hash22(seed + 7.1).x * 6.28318 + sin(timePhase * 0.4 + seed.x) * 0.25;
                float2 dir = float2(cos(angle), sin(angle));
                float2 perp = float2(-dir.y, dir.x);

                float2 rel = uv - center;
                float along = dot(rel, dir);
                float across = dot(rel, perp);

                float len = lerp(0.025, 0.085, Hash22(seed + 13.7).y) * _FloaterSize;
                // ~3x krótsze i drobniejsze nitki kolagenowe
                float len = lerp(0.008, 0.026, Hash22(seed + 13.7).y) * _FloaterSize;
                float clampedAlong = clamp(along, -len, len);

                // Pofalowanie nitki zmieniające się delikatnie w czasie
                float wiggle = sin(clampedAlong * 85.0 + seed.x * 10.0 + timePhase * 1.2) * 0.008 * _FloaterSize;
                // Drobne pofalowanie nitki zmieniające się delikatnie w czasie
                float wiggle = sin(clampedAlong * 195.0 + seed.x * 10.0 + timePhase * 1.2) * 0.0024 * _FloaterSize;
                float dist = length(float2(along - clampedAlong, across - wiggle));

                // Charakterystyczny profil dyfrakcyjny mętu (ciemniejszy pierścień + półprzezroczyste wnętrze)
                float core = 1.0 - smoothstep(radius * 0.2, radius, dist);
                float ring = smoothstep(radius * 0.35, radius * 0.7, dist) * (1.0 - smoothstep(radius * 0.7, radius * 1.35, dist));
                return saturate(core * 0.65 + ring * 0.55);
            }

            // Pojedyncza kropka / pęcherzyk z własnym dryfem
            // Pojedyncza drobna kropka / pęcherzyk z własnym dryfem
            float DotFloater(float2 uv, float2 seed, float radius, float timePhase)
            {
                float2 randPos = Hash22(seed);
                float2 individualDrift = float2(
                    cos(timePhase * (0.5 + randPos.y * 0.4) + seed.y),
                    sin(timePhase * (0.6 + randPos.x * 0.4) + seed.x)
                ) * 0.018;
                ) * 0.014;

                float2 center = (randPos - 0.5) * 0.88 + individualDrift;
                float2 center = (randPos - 0.5) * 0.64 + individualDrift;
                float dist = length(uv - center);
                float core = 1.0 - smoothstep(radius * 0.3, radius * 1.1, dist);
                float halo = smoothstep(radius * 0.4, radius * 0.85, dist) * (1.0 - smoothstep(radius * 0.85, radius * 1.4, dist));
                return saturate(core * 0.55 + halo * 0.65);
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

                // Współrzędne sferyczne per-piksel na wewnętrznej ścianie sfery (brak zniekształceń płaskiego Quada)
                // Współrzędne sferyczne per-piksel na wewnętrznej ścianie sfery
                float3 viewDir = normalize(input.posVS);
                if (viewDir.z > 0.0)
                    return half4(0, 0, 0, 0);

                float2 baseP = float2(atan2(viewDir.x, -viewDir.z), asin(clamp(viewDir.y, -1.0, 1.0)));
                float stereoSign = (unity_StereoEyeIndex == 0) ? 1.0 : -1.0;
                float t = _Time.y;
                float totalMask = 0.0;

                // Warstwa 1 (bliżej siatkówki - wyraźniejsze nitki i wstążki, każdy męt na nieco innej głębokości)
                int wormCount = (int)lerp(3.0, 9.0, _Intensity * saturate(_Density * 0.5));
                // Warstwa 1 (bliżej siatkówki - drobne nitki i wstążki)
                int wormCount = (int)lerp(4.0, 11.0, _Intensity * saturate(_Density * 0.5));
                [loop]
                for (int w = 0; w < 9; w++)
                for (int w = 0; w < 11; w++)
                {
                    if (w >= wormCount) break;
                    float2 seed = float2(w * 3.17 + 1.2, w * 5.73 + 2.4);
                    float depthLayer = lerp(0.85, 1.45, Hash22(seed + 19.1).x);
                    // Subtelna paralaksa stereoskopowa i indywidualna bezwładność zależna od głębokości mętu
                    float2 stereoDisparity = float2(stereoSign * (depthLayer - 1.0) * 0.008, 0.0);
                    float2 stereoDisparity = float2(stereoSign * (depthLayer - 1.0) * 0.006, 0.0);
                    float2 p1 = baseP - _InertiaOffset.xy * depthLayer + stereoDisparity;
                    totalMask += WormFloater(p1, seed, (0.0055 + 0.002 * depthLayer) * _FloaterSize, t);
                    totalMask += WormFloater(p1, seed, (0.0018 + 0.0007 * depthLayer) * _FloaterSize, t);
                }

                // Warstwa 2 (głębiej w ciele szklistym - bardziej rozmyte kropki/muszki, wolniejszy dryf)
                int dotCount = (int)lerp(4.0, 12.0, _Intensity * saturate(_Density * 0.5));
                // Warstwa 2 (głębiej w ciele szklistym - drobne rozmyte kropki/muszki)
                int dotCount = (int)lerp(5.0, 14.0, _Intensity * saturate(_Density * 0.5));
                [loop]
                for (int d = 0; d < 12; d++)
                for (int d = 0; d < 14; d++)
                {
                    if (d >= dotCount) break;
                    float2 seed = float2(d * 7.13 + 10.5, d * 2.91 + 4.8);
                    float depthLayer = lerp(0.45, 0.90, Hash22(seed + 23.7).x);
                    float2 stereoDisparity = float2(stereoSign * (depthLayer - 0.7) * 0.006, 0.0);
                    float2 stereoDisparity = float2(stereoSign * (depthLayer - 0.7) * 0.005, 0.0);
                    float2 p2 = baseP - _InertiaOffset.xy * depthLayer + stereoDisparity;
                    totalMask += DotFloater(p2, seed, (0.007 + 0.003 * (1.0 - depthLayer)) * _FloaterSize, t);
                    totalMask += DotFloater(p2, seed, (0.0022 + 0.0010 * (1.0 - depthLayer)) * _FloaterSize, t);
                }

                float alpha = saturate(totalMask) * saturate(_Intensity * 1.4) * _FloaterColor.a;
                return half4(_FloaterColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
