Shader "Ocularis/Defects/Glaucoma"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _VignetteColor ("Kolor Ubytku Pola", Color) = (0.01, 0.01, 0.01, 1.0)
        _MinRadius ("Min Promien (Widzenie lunetowe przy Intensity=1)", Range(0.02, 0.35)) = 0.055
        _MaxRadius ("Max Promien (Pelne pole przy Intensity=0)", Range(0.4, 1.2)) = 0.82
        _EdgeSoftness ("Miekkosc brzegu", Range(0.02, 0.4)) = 0.14
        _EdgeIrregularity ("Organiczna nieregularnosc brzegu", Range(0.0, 0.15)) = 0.045
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Overlay+1"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "GlaucomaOverlay"
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
                float4 _VignetteColor;
                float _MinRadius;
                float _MaxRadius;
                float _EdgeSoftness;
                float _EdgeIrregularity;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 posVS = TransformWorldToView(posWS);

                output.positionHCS = TransformWorldToHClip(posWS);
                // Czysty kąt widzenia (x, y) względem źrenicy aktualnie renderowanego oka (0,0 = idealnie na wprost)
                output.viewAngle = posVS.xy / max(0.001, -posVS.z);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                float2 p = input.viewAngle;
                float dist = length(p);

                // Lekka organiczna asymetria ubytku pola widzenia
                float angle = atan2(p.y, p.x);
                float organicWave = (sin(angle * 3.0 + 0.7) * 0.5 + cos(angle * 5.0 - 1.2) * 0.3 + sin(angle * 8.0) * 0.2) * _EdgeIrregularity;

                float targetRadius = lerp(_MaxRadius, _MinRadius, _Intensity);
                float softness = lerp(_EdgeSoftness, _EdgeSoftness * 0.45, _Intensity);

                float mask = smoothstep(
                    max(0.001, targetRadius + organicWave - softness * 0.5),
                    targetRadius + organicWave + softness,
                    dist
                );

                // Płynne wejście efektu od Intensity > 0
                float fadeIn = saturate(_Intensity * 4.0);
                float alpha = saturate(mask * fadeIn * _VignetteColor.a);

                return half4(_VignetteColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
