Shader "Custom/XR/VisionDefectOverlay"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [Header(Glowny Suwak (sterowany z C#))]
        _Intensity ("Master Intensity", Range(0, 1)) = 0.0

        [Header(1. Jaskra i Odwarstwienie (Winieta obwodowa))]
        _VignetteUsage ("Aktywuj Winiete (0 lub 1)", Range(0, 1)) = 0.0
        _VignetteColor ("Kolor Winiety", Color) = (0, 0, 0, 1)
        _VignetteMinRadius ("Min Promien (przy Intensity = 1)", Range(0.01, 0.5)) = 0.05
        _VignetteMaxRadius ("Max Promien (przy Intensity = 0)", Range(0.3, 1.0)) = 0.70
        _VignetteSoftness ("Miekkosc brzegu winiety", Range(0.01, 0.5)) = 0.12
        _VignetteCenter ("Srodek Winiety (UV)", Vector) = (0.5, 0.5, 0, 0)

        [Header(2. AMD (Mroczek centralny i falowanie))]
        _ScotomaUsage ("Aktywuj Mroczek AMD (0 lub 1)", Range(0, 1)) = 0.0
        _ScotomaColor ("Kolor Mroczka", Color) = (0.05, 0.05, 0.05, 0.98)
        _ScotomaMaxRadius ("Max Promien Plamy", Range(0.01, 0.4)) = 0.16
        _ScotomaSoftness ("Miekkosc brzegu plamy", Range(0.01, 0.3)) = 0.08

        [Header(3. Zacma (Mgla brudna szyba i zolty filtr))]
        _HazeUsage ("Aktywuj Mgle Zacmy (0 lub 1)", Range(0, 1)) = 0.0
        _HazeColor ("Kolor Mgly (Mleczno-zolty)", Color) = (0.96, 0.91, 0.76, 0.82)
        _NoiseTex ("Tekstura Brudnej Szyby / Chmur (R)", 2D) = "white" {}
        _FrostGrain ("Szum matowego szkla (Dithering)", Range(0, 0.3)) = 0.08

        [Header(4. Mety Retinopatia i Kurtyna (Maska tekstur))]
        _MaskUsage ("Aktywuj Maske Tekstury (0 lub 1)", Range(0, 1)) = 0.0
        _MaskTex ("Tekstura Plam / Metow (RGBA)", 2D) = "black" {}
        _MaskColor ("Kolor Plam / Metow", Color) = (0.02, 0.02, 0.02, 0.85)
        _MaskOffset ("Przesuniecie UV (dla plywania metow)", Vector) = (0, 0, 0, 0)
        _MaskScale ("Skala Tekstury Maski", Float) = 1.0
    }

    SubShader
    {
        Tags 
        { 
            "Queue" = "Overlay" 
            "RenderType" = "Transparent" 
            "IgnoreProjector" = "True" 
        }

        Pass
        {
            Cull Off
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float _Intensity;

            // Jaskra
            float _VignetteUsage;
            float4 _VignetteColor;
            float _VignetteMinRadius;
            float _VignetteMaxRadius;
            float _VignetteSoftness;
            float4 _VignetteCenter;

            // AMD
            float _ScotomaUsage;
            float4 _ScotomaColor;
            float _ScotomaMaxRadius;
            float _ScotomaSoftness;

            // Zaćma
            float _HazeUsage;
            float4 _HazeColor;
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            float _FrostGrain;

            // Męty / Retinopatia
            float _MaskUsage;
            sampler2D _MaskTex;
            float4 _MaskColor;
            float4 _MaskOffset;
            float _MaskScale;

            // Szybki szum proceduralny imitujący rozproszenie światła na zmętniałej soczewce
            float HashNoise(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            v2f vert(appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                if (_Intensity <= 0.001)
                    return fixed4(0, 0, 0, 0);

                float3 finalRGB = float3(0, 0, 0);
                float finalAlpha = 0.0;

                // ---------------------------------------------------------
                // 1. ZAĆMA (Mleczno-żółta mgła + tekstura brudnej szyby + ziarno)
                // ---------------------------------------------------------
                if (_HazeUsage > 0.01)
                {
                    float2 noiseUV = TRANSFORM_TEX(i.uv, _NoiseTex);
                    float dirtyGlass = tex2D(_NoiseTex, noiseUV).r;
                    float grain = (HashNoise(i.uv * 800.0) - 0.5) * _FrostGrain;

                    float hazeAlpha = saturate(_Intensity * _HazeUsage * _HazeColor.a * lerp(0.65, 1.1, dirtyGlass) + grain);
                    finalRGB = _HazeColor.rgb + grain;
                    finalAlpha = hazeAlpha;
                }

                // ---------------------------------------------------------
                // 2. MĘTY / RETINOPATIA / ODWARSTWIENIE (Tekstura z offsetem UV)
                // ---------------------------------------------------------
                if (_MaskUsage > 0.01)
                {
                    float2 centeredMaskUV = (i.uv - 0.5) * _MaskScale + 0.5 + _MaskOffset.xy;
                    float4 maskSample = tex2D(_MaskTex, saturate(centeredMaskUV));
                    
                    // Obsługa tekstury z kanałem Alpha lub w skali szarości (R)
                    float maskVal = max(maskSample.a, maskSample.r);
                    float maskAlpha = saturate(maskVal * _Intensity * _MaskUsage * _MaskColor.a);

                    finalRGB = lerp(finalRGB, _MaskColor.rgb, maskAlpha);
                    finalAlpha = saturate(finalAlpha + maskAlpha * (1.0 - finalAlpha));
                }

                // ---------------------------------------------------------
                // 3. AMD (Mroczek centralny - ciemna plama w centrum)
                // ---------------------------------------------------------
                if (_ScotomaUsage > 0.01)
                {
                    float distFromCenter = length(i.uv - float2(0.5, 0.5));
                    float currentRadius = lerp(0.0, _ScotomaMaxRadius, _Intensity);
                    
                    float scotomaMask = 1.0 - smoothstep(
                        max(0.0, currentRadius - _ScotomaSoftness), 
                        currentRadius + _ScotomaSoftness, 
                        distFromCenter
                    );

                    // Płynne pojawianie się od Intensity > 0
                    float scotomaAlpha = scotomaMask * saturate(_Intensity * 2.0) * _ScotomaUsage * _ScotomaColor.a;

                    finalRGB = lerp(finalRGB, _ScotomaColor.rgb, scotomaAlpha);
                    finalAlpha = saturate(finalAlpha + scotomaAlpha * (1.0 - finalAlpha));
                }

                // ---------------------------------------------------------
                // 4. JASKRA (Winieta obwodowa - zawężanie pola widzenia)
                // ---------------------------------------------------------
                if (_VignetteUsage > 0.01)
                {
                    float distFromVigCenter = length(i.uv - _VignetteCenter.xy);
                    float currentVigRadius = lerp(_VignetteMaxRadius, _VignetteMinRadius, _Intensity);

                    float vigMask = smoothstep(
                        currentVigRadius, 
                        currentVigRadius + _VignetteSoftness, 
                        distFromVigCenter
                    );

                    float vigAlpha = vigMask * saturate(_Intensity * 2.5) * _VignetteUsage * _VignetteColor.a;

                    finalRGB = lerp(finalRGB, _VignetteColor.rgb, vigAlpha);
                    finalAlpha = saturate(finalAlpha + vigAlpha * (1.0 - finalAlpha));
                }

                return fixed4(finalRGB, finalAlpha);
            }
            ENDCG
        }
    }
}