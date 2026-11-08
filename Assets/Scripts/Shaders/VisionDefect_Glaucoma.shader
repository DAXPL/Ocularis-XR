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
        _MinRadius ("Min Promien (Widzenie lunetowe przy Intensity=1)", Range(0.08, 0.45)) = 0.26
        _MaxRadius ("Max Promien (Pelne pole przy Intensity=0)", Range(0.5, 1.2)) = 0.85
        _EdgeSoftness ("Miekkosc brzegu winiety", Range(0.05, 0.45)) = 0.22
        _EdgeIrregularity ("Organiczna nieregularnosc brzegu", Range(0.0, 0.08)) = 0.015
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
                output.posVS = TransformWorldToView(posWS);
                output.positionHCS = TransformWorldToHClip(posWS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                // Prawdziwy kąt sferyczny (w radianach) od osi optycznej aktualnie renderowanego oka (0, 0, -1)
                float3 viewDir = normalize(input.posVS);
                float dist = acos(clamp(-viewDir.z, -1.0, 1.0));
                if (viewDir.z > 0.0)
                    return half4(0, 0, 0, 0);

                // Lekka organiczna asymetria ubytku pola widzenia wokół osi patrzenia
                // Kąt sferyczny (w radianach) od środka pola widzenia (0 = sam środek, rośnie ku obwodowi)
                float dist = acos(clamp(-viewDir.z, 0.0, 1.0));

                // Subtelna, naturalna nieregularność brzegu winiety
                float angle = atan2(viewDir.y, viewDir.x);
                float organicWave = (sin(angle * 3.0 + 0.7) * 0.5 + cos(angle * 5.0 - 1.2) * 0.3 + sin(angle * 8.0) * 0.2) * _EdgeIrregularity;
                float organicWave = (sin(angle * 3.0 + 0.7) * 0.5 + cos(angle * 5.0 - 1.2) * 0.5) * _EdgeIrregularity;

                float targetRadius = lerp(_MaxRadius, _MinRadius, _Intensity);
                float softness = lerp(_EdgeSoftness, _EdgeSoftness * 0.45, _Intensity);
                // Środek pola widzenia pozostaje w pełni przejrzysty; zaciemniane są wyłącznie obrzeża (winieta)
                float clearCenterRadius = max(0.18, lerp(_MaxRadius, _MinRadius, _Intensity));
                float innerEdge = max(0.12, clearCenterRadius + organicWave);
                float outerEdge = innerEdge + max(0.08, _EdgeSoftness);

                float mask = smoothstep(
                    max(0.001, targetRadius + organicWave - softness * 0.5),
                    targetRadius + organicWave + softness,
                    dist
                );
                // mask = 0 w centrum, płynnie rośnie do 1 na obwodzie (klasyczna winieta tunelowa)
                float vignetteMask = smoothstep(innerEdge, outerEdge, dist);
                vignetteMask = pow(vignetteMask, 1.15);

                // Płynne wejście efektu od Intensity > 0
                float fadeIn = saturate(_Intensity * 4.0);
                float alpha = saturate(mask * fadeIn * _VignetteColor.a);
                float fadeIn = saturate(_Intensity * 3.0);
                float alpha = saturate(vignetteMask * fadeIn * _VignetteColor.a);

                return half4(_VignetteColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
