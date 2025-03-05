Shader "Custom/Random2BitShapeShader"
{
    Properties
    {
        // メインテクスチャ（2bitの画像）
        _ShapeTex ("Shape Texture", 2D) = "white" {}
        
        // 形状生成のパラメータ
        _ShapeDensity ("Shape Density", Range(1, 50)) = 10
        _MinShapeSize ("Minimum Shape Size", Range(0.01, 0.5)) = 0.1
        _MaxShapeSize ("Maximum Shape Size", Range(0.1, 1.0)) = 0.3
        
        // 動きと変化のパラメータ
        _MoveSpeed ("Movement Speed", Range(0.1, 5.0)) = 1.0
        _RotationSpeed ("Rotation Speed", Range(0.0, 5.0)) = 1.0
        
        // 色とブレンドのパラメータ
        _ShapeColor ("Shape Color", Color) = (0,0,0,1)
        _BackgroundColor ("Background Color", Color) = (1,1,1,1)
        _ColorVariation ("Color Variation", Range(0.0, 1.0)) = 0.2
        
        // エフェクトパラメータ
        _Opacity ("Opacity", Range(0.0, 1.0)) = 1.0
        _EdgeSoftness ("Edge Softness", Range(0.0, 0.1)) = 0.02
        _Distortion ("Shape Distortion", Range(0.0, 0.2)) = 0.05
        
        // ライフタイムパラメータ
        _MinLifetime ("Minimum Lifetime", Range(1.0, 10.0)) = 3.0
        _MaxLifetime ("Maximum Lifetime", Range(2.0, 15.0)) = 6.0
        _AppearSpeed ("Appear Speed", Range(0.1, 5.0)) = 1.0
        _DisappearSpeed ("Disappear Speed", Range(0.1, 5.0)) = 1.0
        
        // アニメーションパラメータ
        _PulseIntensity ("Pulse Intensity", Range(0.0, 1.0)) = 0.0
        _PulseSpeed ("Pulse Speed", Range(0.0, 5.0)) = 1.0
        
        // エミッション
        _EmissionIntensity ("Emission Intensity", Range(0.0, 5.0)) = 0.0
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            
            // プロパティ変数
            sampler2D _ShapeTex;
            float _ShapeDensity;
            float _MinShapeSize;
            float _MaxShapeSize;
            float _MoveSpeed;
            float _RotationSpeed;
            float4 _ShapeColor;
            float4 _BackgroundColor;
            float _ColorVariation;
            float _Opacity;
            float _EdgeSoftness;
            float _Distortion;
            
            // ライフタイム関連パラメータ
            float _MinLifetime;
            float _MaxLifetime;
            float _AppearSpeed;
            float _DisappearSpeed;
            
            float _PulseIntensity;
            float _PulseSpeed;
            float _EmissionIntensity;
            float4 _EmissionColor;
            
            // ハッシュ関数
            float hash(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }
            
            // 2Dノイズ関数
            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                
                float a = hash(i);
                float b = hash(i + float2(1.0, 0.0));
                float c = hash(i + float2(0.0, 1.0));
                float d = hash(i + float2(1.0, 1.0));
                
                float2 u = f * f * (3.0 - 2.0 * f);
                
                return lerp(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
            }
            
            // 回転行列
            float2 rotate(float2 v, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(v.x * c - v.y * s, v.x * s + v.y * c);
            }
            
            // ライフタイムの計算
            float calculateLifetimeProgress(float cellID, float time)
            {
                // 各セルごとに異なるライフタイムサイクルを生成
                float lifetime = lerp(_MinLifetime, _MaxLifetime, hash(float2(cellID, 42.0)));
                float offset = hash(float2(cellID, 24.0)) * lifetime;
                
                // サイクリックな進行度を計算
                float progress = frac((time + offset) / lifetime);
                
                return progress;
            }
            
            // ライフタイムに基づく不透明度計算
            float calculateLifetimeOpacity(float progress)
            {
                // 出現と消滅時のイージング
                float appearFactor = smoothstep(0.0, 0.2, progress);
                float disappearFactor = 1.0 - smoothstep(0.8, 1.0, progress);
                
                return appearFactor * disappearFactor;
            }
            
            // シェイプの位置と変形を計算
            float2 transformShape(float2 uv, float id, float time)
            {
                // ランダムな移動
                float2 moveOffset = float2(
                    noise(float2(id, time * 0.3)) * 2.0 - 1.0,
                    noise(float2(id * 1.5, time * 0.4)) * 2.0 - 1.0
                ) * 0.2;
                
                // 回転
                float rotation = time * _RotationSpeed * (hash(float2(id, 42.0)) * 2.0 - 1.0);
                
                // UVを中心に移動、回転、戻す
                uv = uv - 0.5;
                uv = rotate(uv, rotation);
                uv += moveOffset;
                uv += 0.5;
                
                return uv;
            }
            
            // 頂点シェーダー
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            // フラグメントシェーダー
            float4 frag (v2f i) : SV_Target
            {
                float time = _Time.y;
                
                // シェイプの密度に基づいてUVをスケール
                float2 scaledUV = i.uv * _ShapeDensity;
                float2 cell = floor(scaledUV);
                float2 localUV = frac(scaledUV);
                
                // 各セルのシェイプ情報を計算
                float cellID = hash(cell);
                float size = lerp(_MinShapeSize, _MaxShapeSize, cellID);
                
                // ライフタイムの進行度を計算
                float lifetimeProgress = calculateLifetimeProgress(cellID, time);
                
                // ライフタイム不透明度を計算
                float lifetimeOpacity = calculateLifetimeOpacity(lifetimeProgress);
                
                // UVを変形
                float2 transformedUV = transformShape((localUV - 0.5) / size + 0.5, cellID, time);
                
                // 形状テクスチャからサンプリング
                float4 shapeSample = tex2D(_ShapeTex, transformedUV);
                
                // エッジのソフトネス
                float edgeMask = smoothstep(0.0, _EdgeSoftness, min(transformedUV.x, transformedUV.y)) *
                                  smoothstep(0.0, _EdgeSoftness, 1.0 - max(transformedUV.x, transformedUV.y));
                
                // 色のバリエーション
                float3 shapeColor = lerp(
                    _ShapeColor.rgb, 
                    _ShapeColor.rgb * (1.0 + _ColorVariation * (cellID * 2.0 - 1.0)), 
                    _ColorVariation
                );
                
                // パルスエフェクト
                float pulse = lerp(1.0, 1.0 + sin(_Time.y * _PulseSpeed) * _PulseIntensity, _PulseIntensity);
                
                // 最終カラー
                float4 finalColor;
                finalColor.rgb = lerp(_BackgroundColor.rgb, shapeColor * pulse, 
                    shapeSample.r * edgeMask * _Opacity * lifetimeOpacity);
                finalColor.a = shapeSample.r * edgeMask * _Opacity * lifetimeOpacity;
                
                // エミッション追加
                finalColor.rgb += _EmissionColor.rgb * _EmissionIntensity * finalColor.a;
                
                return finalColor;
            }
            ENDCG
        }
    }
    
    FallBack "Transparent/Diffuse"
}