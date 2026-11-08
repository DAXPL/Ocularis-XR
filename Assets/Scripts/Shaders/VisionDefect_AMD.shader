Shader "Ocularis/Defects/AMD"
{
    Properties
    {
        _Intensity ("Intensity", Range(0, 1)) = 0.0
        _ScotomaColor ("Kolor Mroczka Centralnego", Color) = (0.04, 0.04, 0.04, 0.96)
        _MaxRadius ("Max Promien Plamy Centralnej", Range(0.02, 0.45)) = 0.18
        _Softness ("Miekkosc Brzegu Plamy", Range(0.02, 0.3)) = 0.09
        _WaveAmplitude ("Sila Falowania Linii (Postac Wysiekowa)", Range(0.0, 0.08)) = 0.028
        _MaxRadius ("Max Promien Plamy Centralnej", Range(0.04, 0.35)) = 0.16
        _Softness ("Miekkosc Brzegu Plamy", Range(0.02, 0.25)) = 0.08
        _WaveAmplitude ("Sila Falowania Bokow (Postac Wysiekowa)", Range(0.0, 0.08)) = 0.035
        _WaveFrequency ("Czestotliwosc Falowania", Range(5.0, 40.0)) = 18.0
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
            Name "AMDOverlay"
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
                float4 _ScotomaColor;
                float _MaxRadius;
                float _Softness;
                float _WaveAmplitude;
                float _WaveFrequency;
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

                // Współrzędne sferyczne względem osi wzroku aktualnego oka (0, 0, -1)
                float3 viewDir = normalize(input.posVS);
                if (viewDir.z > 0.0)
                    return half4(0, 0, 0, 0);

                // Współrzędne sferyczne względem osi wzroku (0, 0, -1)
                float2 p = float2(atan2(viewDir.x, -viewDir.z), asin(clamp(viewDir.y, -1.0, 1.0)));
                float dist = acos(clamp(-viewDir.z, -1.0, 1.0));
                float dist = acos(clamp(-viewDir.z, 0.0, 1.0));

                // Nieregularny kształt plamki centralnej
                // Lekko organiczny, nieregularny kształt plamy na samym środku
                float angle = atan2(viewDir.y, viewDir.x);
                float irregularity = (sin(angle * 3.0) * 0.012 + cos(angle * 5.0) * 0.008) * _Intensity;
                float irregularity = (sin(angle * 3.0) * 0.010 + cos(angle * 5.0) * 0.007) * _Intensity;
                float effectiveDist = max(0.0, dist + irregularity);

                float currentRadius = lerp(0.0, _MaxRadius, _Intensity);
                float currentSoftness = lerp(0.02, _Softness, _Intensity);

                // 1. Centralny mroczek (ciemna/szara plama przysłaniająca centrum obrazu)
                // 1. CENTRALNA PLAMA (Mroczek centralny dokładnie na środku pola widzenia, obwód pozostaje odkryty)
                float scotomaMask = 1.0 - smoothstep(
                    max(0.0, currentRadius - currentSoftness * 0.5),
                    max(0.0, currentRadius - currentSoftness * 0.4),
                    currentRadius + currentSoftness,
                    effectiveDist
                );
                float scotomaAlpha = saturate(scotomaMask * saturate(_Intensity * 2.5) * _ScotomaColor.a);

                // 2. Strefa falowania (Metamorfopsja wokół mroczka w postaci wysiękowej AMD)
                //    Uwaga: Nie używamy SampleSceneColor (_CameraOpaqueTexture), ponieważ obraz Passthrough
                //    znajduje się w warstwie sprzętowej kompozytora (poza buforem Unity) i zwracałby czerń.
                float distortionZone = 1.0 - smoothstep(currentRadius * 0.5, currentRadius + currentSoftness * 2.6, dist);
                float2 waveOffset = float2(
                    sin(p.y * _WaveFrequency + p.x * 6.0),
                    cos(p.x * _WaveFrequency - p.y * 6.0)
                ) * _WaveAmplitude * _Intensity * distortionZone;
                // 2. FALUJĄCE BOKI (Metamorfopsja wokół plamy centralnej i po bokach pola widzenia)
                float sideStart = max(0.02, currentRadius * 0.65);
                float sideZone = smoothstep(sideStart, currentRadius + currentSoftness * 1.2, dist)
                               * (1.0 - smoothstep(0.42, 0.85, dist));

                // Subtelne pofalowane prążki refrakcyjne wokół mroczka widoczne na tle Passthrough
                float2 warpedP = p + waveOffset * 2.5;
                float wavePattern = sin(warpedP.x * 48.0) * cos(warpedP.y * 48.0);
                float3 perifocalHaze = float3(0.28, 0.26, 0.22) + wavePattern * 0.14;
                float perifocalAlpha = saturate(distortionZone * (1.0 - scotomaMask * 0.85) * (0.22 + abs(wavePattern) * 0.25) * _Intensity);
                float t = _Time.y * 1.6;
                float waveStrength = saturate(_WaveAmplitude * 35.0) * _Intensity;

                float3 finalRGB = lerp(perifocalHaze, _ScotomaColor.rgb, scotomaAlpha);
                float finalAlpha = saturate(scotomaAlpha + perifocalAlpha * (1.0 - scotomaAlpha));
                // Pofalowanie współrzędnych po bokach plamy (efekt falujących linii / pofalowanego szkła)
                float2 waveWarp = float2(
                    sin(p.y * _WaveFrequency + t + p.x * 4.0) + 0.5 * sin(p.y * (_WaveFrequency * 1.7) - t * 0.8),
                    cos(p.x * _WaveFrequency - t * 0.9 + p.y * 4.0) + 0.5 * cos(p.x * (_WaveFrequency * 1.7) + t * 0.7)
                ) * _WaveAmplitude * _Intensity;

                float2 warpedP = p + waveWarp * 2.2;
                float rippleX = sin(warpedP.x * (_WaveFrequency * 2.1) + sin(warpedP.y * 12.0 + t) * 2.2);
                float rippleY = sin(warpedP.y * (_WaveFrequency * 2.1) + cos(warpedP.x * 12.0 - t) * 2.2);
                float wavePattern = 0.5 + 0.5 * (rippleX * 0.6 + rippleY * 0.4);

                // Półprzezroczyste pofalowane prążki refrakcyjne po bokach (jaśniejsze i ciemniejsze grzbiety fal)
                float3 waveColor = lerp(float3(0.08, 0.08, 0.09), float3(0.78, 0.76, 0.70), wavePattern);
                float waveAlpha = sideZone * waveStrength * lerp(0.06, 0.34, abs(wavePattern - 0.5) * 2.0) * (1.0 - scotomaAlpha);

                float finalAlpha = saturate(scotomaAlpha + waveAlpha);
                float3 finalRGB = (finalAlpha > 0.001)
                    ? lerp(waveColor, _ScotomaColor.rgb, saturate(scotomaAlpha / finalAlpha))
                    : _ScotomaColor.rgb;

                return half4(finalRGB, finalAlpha);
            }
            ENDHLSL
        }
    }
}
