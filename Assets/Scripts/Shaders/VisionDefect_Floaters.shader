Shader "Ocularis/Defects/Floaters"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _FloaterColor ("Kolor Metow", Color) = (0.08, 0.08, 0.09, 0.68)
        _InertiaOffset ("Przesuniecie Bezwladnosci (XY)", Vector) = (0, 0, 0, 0)
        _Density ("Gestosc i Liczba Metow", Range(0.5, 3.0)) = 1.4
        _FloaterSize ("Rozmiar Metow", Range(0.5, 2.5)) = 1.0
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 viewAngle : TEXCOORD0;
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
            float WormFloater(float2 uv, float2 seed, float radius)
            {
                float2 center = (Hash22(seed) - 0.5) * 0.55;
                float angle = Hash22(seed + 7.1).x * 6.28318;
                float2 dir = float2(cos(angle), sin(angle));
                float2 perp = float2(-dir.y, dir.x);

                float2 rel = uv - center;
                float along = dot(rel, dir);
                float across = dot(rel, perp);

                float len = lerp(0.025, 0.085, Hash22(seed + 13.7).y) * _FloaterSize;
                float clampedAlong = clamp(along, -len, len);

                // Pofalowanie nitki
                float wiggle = sin(clampedAlong * 85.0 + seed.x * 10.0) * 0.008 * _FloaterSize;
                float dist = length(float2(along - clampedAlong, across - wiggle));

                // Charakterystyczny profil dyfrakcyjny mętu (ciemniejszy pierścień + półprzezroczyste wnętrze)
                float core = 1.0 - smoothstep(radius * 0.2, radius, dist);
                float ring = smoothstep(radius * 0.35, radius * 0.7, dist) * (1.0 - smoothstep(radius * 0.7, radius * 1.35, dist));
                return saturate(core * 0.65 + ring * 0.55);
            }

            // Pojedyncza kropka / pęcherzyk
            float DotFloater(float2 uv, float2 seed, float radius)
            {
                float2 center = (Hash22(seed) - 0.5) * 0.65;
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
                float3 posVS = TransformWorldToView(posWS);

                output.positionHCS = TransformWorldToHClip(posWS);
                output.viewAngle = posVS.xy / max(0.001, -posVS.z);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                float2 baseP = input.viewAngle;
                float totalMask = 0.0;

                // Warstwa 1 (bliżej siatkówki - wyraźniejsze nitki i wstążki, większa bezwładność)
                float2 p1 = baseP - _InertiaOffset.xy * 1.15;
                int wormCount = (int)lerp(3.0, 9.0, _Intensity * saturate(_Density * 0.5));
                [loop]
                for (int w = 0; w < 9; w++)
                {
                    if (w >= wormCount) break;
                    totalMask += WormFloater(p1, float2(w * 3.17 + 1.2, w * 5.73 + 2.4), 0.0065 * _FloaterSize);
                }

                // Warstwa 2 (głębiej w ciele szklistym - bardziej rozmyte kropki/muszki, wolniejszy dryf)
                float2 p2 = baseP - _InertiaOffset.xy * 0.65;
                int dotCount = (int)lerp(4.0, 12.0, _Intensity * saturate(_Density * 0.5));
                [loop]
                for (int d = 0; d < 12; d++)
                {
                    if (d >= dotCount) break;
                    totalMask += DotFloater(p2, float2(d * 7.13 + 10.5, d * 2.91 + 4.8), 0.009 * _FloaterSize);
                }

                float alpha = saturate(totalMask) * saturate(_Intensity * 1.4) * _FloaterColor.a;
                return half4(_FloaterColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
