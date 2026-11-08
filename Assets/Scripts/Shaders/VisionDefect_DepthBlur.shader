Shader "Ocularis/Defects/DepthBlur"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        [Toggle] _InvertDepth ("Tryb Nadwzrocznosci (1 = Blisko rozmyte, 0 = Daleko rozmyte)", Float) = 0.0
        _FocusNear ("Poczatek strefy przejscia (m)", Range(0.1, 3.0)) = 0.55
        _FocusFar ("Koniec strefy przejscia (m)", Range(0.3, 6.0)) = 1.40
        _BlurTint ("Odcien rozproszenia (Frosted Blur)", Color) = (0.88, 0.90, 0.92, 0.72)
        _BlurRadius ("Promien rozmycia (Ghosting / Defocus)", Range(0.0, 0.035)) = 0.014
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
            Name "DepthBlurOverlay"
            Cull Front
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // Integracja z Meta XR Environment Depth API (z [BuildingBlock] Occlusion obecnego na scenie)
            TEXTURE2D_X_FLOAT(_EnvironmentDepthTexture);
            SAMPLER(sampler_EnvironmentDepthTexture);
            uniform float4x4 _EnvironmentDepthReprojectionMatrices[2];
            uniform float4 _EnvironmentDepthZBufferParams;

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 posVS : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
                float _Intensity;
                float _InvertDepth;
                float _FocusNear;
                float _FocusFar;
                float4 _BlurTint;
                float _BlurRadius;
            CBUFFER_END

            float Hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float GetEnvironmentLinearDepth(float3 worldPos)
            {
                if (abs(_EnvironmentDepthZBufferParams.x) < 0.0001)
                    return 10000.0;

                float4 depthSpace = mul(_EnvironmentDepthReprojectionMatrices[unity_StereoEyeIndex], float4(worldPos, 1.0));
                float2 uvCoords = (depthSpace.xy / depthSpace.w + 1.0) * 0.5;
                float inputDepthEye = SAMPLE_TEXTURE2D_X(_EnvironmentDepthTexture, sampler_EnvironmentDepthTexture, uvCoords).r;
                float inputDepthNdc = inputDepthEye * 2.0 - 1.0;

                if (inputDepthNdc >= 0.9999)
                    return 10000.0;

                float denom = inputDepthNdc + _EnvironmentDepthZBufferParams.y;
                if (abs(denom) < 0.0001)
                    return 10000.0;

                return max(0.05, (1.0 / denom) * _EnvironmentDepthZBufferParams.x);
            }

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float3 posWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionHCS = TransformWorldToHClip(posWS);
                output.positionWS = posWS;
                output.posVS = TransformWorldToView(posWS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                if (_Intensity <= 0.001)
                    return half4(0, 0, 0, 0);

                float3 viewDir = normalize(input.posVS);
                float2 p = float2(atan2(viewDir.x, -viewDir.z), asin(clamp(viewDir.y, -1.0, 1.0)));

                // 1. Głębia rzeczywistego pokoju oraz dłoni z Meta Depth API ([BuildingBlock] Occlusion).
                //    Nie używamy _CameraDepthTexture ani _CameraOpaqueTexture, ponieważ wymuszają one
                //    kopiowanie bufora w URP, co nadpisuje kanał alfa = 1.0 i powoduje czarny Passthrough.
                float distanceMeters = GetEnvironmentLinearDepth(input.positionWS);

                // 2. Wyznaczenie stopnia nieostrości (0 = ostro, 1 = pełne rozmycie)
                float farBlurFactor = smoothstep(_FocusNear, _FocusFar, distanceMeters);
                float defocusFactor = (_InvertDepth > 0.5) ? (1.0 - farBlurFactor) : farBlurFactor;

                // Gdy Depth API nie zwraca jeszcze danych (np. w edytorze bez gogli), pokaż delikatną demonstrację na obrzeżach
                if (distanceMeters >= 9999.0 && _InvertDepth > 0.5)
                {
                    defocusFactor = smoothstep(0.35, 0.05, acos(clamp(-viewDir.z, -1.0, 1.0)));
                }

                float activeBlur = defocusFactor * _Intensity;
                if (activeBlur <= 0.005)
                    return half4(0, 0, 0, 0);

                // 3. Matowe rozproszenie soczewkowe (Frosted / Defocus scatter) zachowujące przezroczystość Passthrough
                float fineGrain = (Hash21(p * 650.0) - 0.5) * 0.10 * activeBlur;
                float softWave = (sin(p.x * 90.0) * cos(p.y * 90.0)) * _BlurRadius * 1.8 * activeBlur;

                float3 finalRGB = saturate(_BlurTint.rgb + fineGrain + softWave);
                float finalAlpha = saturate(activeBlur * _BlurTint.a);

                return half4(finalRGB, finalAlpha);
            }
            ENDHLSL
        }
    }
}
