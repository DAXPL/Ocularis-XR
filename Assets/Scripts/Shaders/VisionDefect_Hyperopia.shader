Shader "Ocularis/Defects/Hyperopia"
{
    Properties
    {
        _Intensity ("Intensity (Glebokosc rozmycia)", Range(0, 1)) = 0.0
        _Intensity2 ("Intensity2 (Dystans ostrosci)", Range(0, 1)) = 0.5
        _FocusNear ("Poczatek strefy przejscia (m)", Float) = 0.25
        _FocusFar ("Koniec strefy przejscia (m)", Float) = 0.85
        _BlurTint ("Odcien dyfuzji soczewkowej (Optical Tint)", Color) = (0.97, 0.98, 1.0, 0.75)
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
            Name "HyperopiaOverlay"
            Cull Front
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                float _Intensity2;
                float _FocusNear;
                float _FocusFar;
                float4 _BlurTint;
            CBUFFER_END

            // 9-punktowy filtr Gaussa dla bufora glebi (usuwa wszelka pikseloze i schodki z sensora)
            static const float2 GAUSS_OFFSETS[9] = {
                float2( 0.0,  0.0),
                float2(-1.0,  0.0),
                float2( 1.0,  0.0),
                float2( 0.0, -1.0),
                float2( 0.0,  1.0),
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };

            static const float GAUSS_WEIGHTS[9] = {
                0.2500,
                0.1250,
                0.1250,
                0.1250,
                0.1250,
                0.0625,
                0.0625,
                0.0625,
                0.0625
            };

            float RawEyeDepthToMeters(float rawDepthEye)
            {
                float inputDepthNdc = rawDepthEye * 2.0 - 1.0;
                if (inputDepthNdc >= 0.9999) return 10000.0;
                float denom = inputDepthNdc + _EnvironmentDepthZBufferParams.y;
                if (abs(denom) < 0.0001) return 10000.0;
                return max(0.05, (1.0 / denom) * _EnvironmentDepthZBufferParams.x);
            }

            // Pobiera idealnie wygladzona, ciagla glebie ze srodowiska Meta Quest (brak pikselozy)
            float GetGaussianSmoothDepth(float2 uvCoords)
            {
                if (abs(_EnvironmentDepthZBufferParams.x) < 0.0001) return 10000.0;

                float2 texelSize = float2(1.0 / 320.0, 1.0 / 240.0) * 1.5;
                float depthAcc = 0.0;
                float weightAcc = 0.0;

                [unroll]
                for (int i = 0; i < 9; i++)
                {
                    float2 tapUV = clamp(uvCoords + GAUSS_OFFSETS[i] * texelSize, 0.001, 0.999);
                    float rawD = SAMPLE_TEXTURE2D_X(_EnvironmentDepthTexture, sampler_EnvironmentDepthTexture, tapUV).r;
                    float d = RawEyeDepthToMeters(rawD);

                    if (d < 9999.0)
                    {
                        float w = GAUSS_WEIGHTS[i];
                        depthAcc += d * w;
                        weightAcc += w;
                    }
                }

                return (weightAcc > 0.01) ? (depthAcc / weightAcc) : 10000.0;
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

                // Projekcja promienia wzroku na wspolrzedne bufora glebi
                float4 depthSpace = mul(_EnvironmentDepthReprojectionMatrices[unity_StereoEyeIndex], float4(input.positionWS, 1.0));
                float2 uvCoords = (depthSpace.xy / depthSpace.w + 1.0) * 0.5;

                // Pobranie zfiltrowanej, idealnie gladkiej glebi bez schodkow
                float smoothDepth = GetGaussianSmoothDepth(saturate(uvCoords));

                #if defined(UNITY_EDITOR)
                if (abs(_EnvironmentDepthZBufferParams.x) < 0.0001)
                {
                    float3 viewDir = normalize(input.posVS);
                    smoothDepth = lerp(0.3, 2.5, saturate(-viewDir.y * 1.5 + 0.5));
                }
                #endif

                // Nadwzrocznosc (Hyperopia):
                // Daleko (>= _FocusFar) -> w 100% ostre (brak rozmycia, pelna przezroczystosc).
                // Blisko (< _FocusFar) -> plynny wzrost rozmycia Gaussa w miare zblizania sie obiektow do twarzy (np. rece, ksiazka).
                // Brak obrysow, brak pikselozy na krawedziach.
                float defocus = 0.0;
                if (smoothDepth >= 9999.0)
                {
                    defocus = 0.0; // Dal jest calkowicie ostra
                }
                else if (smoothDepth < _FocusFar)
                {
                    float delta = _FocusFar - smoothDepth;
                    float sigma = max(0.15, (_FocusFar - _FocusNear) * 0.75);
                    defocus = 1.0 - exp(-0.5 * (delta * delta) / (sigma * sigma));
                }

                float activeBlur = defocus * _Intensity;
                if (activeBlur <= 0.001)
                    return half4(0, 0, 0, 0);

                // Dyskretna mikro-dyfuzja niszczaca ostrosc krawedzi bez widocznego ziarna
                float microScatter = frac(sin(dot(input.positionHCS.xy, float2(12.9898, 78.233))) * 43758.5453);
                float subtleScatter = (microScatter - 0.5) * 0.02 * activeBlur;

                float3 finalRGB = saturate(_BlurTint.rgb + subtleScatter);
                float finalAlpha = saturate(activeBlur * _BlurTint.a);

                return half4(finalRGB, finalAlpha);
            }
            ENDHLSL
        }
    }
}
