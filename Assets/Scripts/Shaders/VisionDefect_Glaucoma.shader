Shader "Ocularis/Defects/Glaucoma"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _Intensity2 ("Intensity2 (Miekkosc)", Range(0, 1)) = 0.5
        _VignetteColor ("Kolor Ubytku Pola", Color) = (0.01, 0.01, 0.01, 1.0)
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
                float _Intensity2;
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

                float3 viewDir = normalize(input.posVS);
                if (viewDir.z > 0.0)
                    return half4(0, 0, 0, 0);

                // Kąt sferyczny (w radianach) od środka pola widzenia (0 = sam środek, rośnie ku obwodowi)
                float dist = acos(clamp(-viewDir.z, 0.0, 1.0));

                // Subtelna, naturalna nieregularność brzegu winiety
                float angle = atan2(viewDir.y, viewDir.x);
                float organicWave = (sin(angle * 3.0 + 0.7) * 0.5 + cos(angle * 5.0 - 1.2) * 0.5) * _EdgeIrregularity;

                // Środek pola widzenia pozostaje w pełni przejrzysty; zaciemniane są wyłącznie obrzeża (winieta)
                float clearCenterRadius = max(0.18, lerp(_MaxRadius, _MinRadius, _Intensity));
                float innerEdge = max(0.12, clearCenterRadius + organicWave);
                float outerEdge = innerEdge + max(0.08, _EdgeSoftness);

                // mask = 0 w centrum, płynnie rośnie do 1 na obwodzie (klasyczna winieta tunelowa)
                float vignetteMask = smoothstep(innerEdge, outerEdge, dist);
                vignetteMask = pow(vignetteMask, 1.15);

                float fadeIn = saturate(_Intensity * 3.0);
                float alpha = saturate(vignetteMask * fadeIn * _VignetteColor.a);

                return half4(_VignetteColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
