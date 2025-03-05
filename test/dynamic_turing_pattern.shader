Shader "Custom/DynamicTuringPatternShader"
{
    Properties
    {
        // パターン生成パラメータ
        _Density ("Pattern Density", Range(1, 20)) = 5
        _ChangeSpeed ("Change Speed", Range(0.1, 5.0)) = 1.0
        
        // 色関連パラメータ
        _BaseColor ("Base Color", Color) = (0.2, 0.2, 0.2, 1)
        _BorderColor ("Border Color", Color) = (0.8, 0.8, 0.8, 1)
        _BorderWidth ("Border Width", Range(0.001, 0.1)) = 0.01
        _BorderBlur ("Border Blur", Range(0.0, 0.1)) = 0.02
        
        // ノイズと変化のパラメータ
        _PositionNoiseScale ("Position Noise Scale", Range(0.1, 10.0)) = 2.0
        _PositionChangeSpeed ("Position Change Speed", Range(0.1, 5.0)) = 1.0
        
        // 追加の色操作パラメータ
        _ColorVariation ("Color Variation", Range(0.0, 1.0)) = 0.2
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            
            // 入力構造体
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            // 出力構造体
            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            
            // プロパティ変数
            float _Density;
            float _ChangeSpeed;
            float4 _BaseColor;
            float4 _BorderColor;
            float _BorderWidth;
            float _BorderBlur;
            float _PositionNoiseScale;
            float _PositionChangeSpeed;
            float _ColorVariation;
            float _Metallic;
            float _Smoothness;
            
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
            
            // 時間変化を考慮した制御点計算
            float2 calculateControlPoint(float2 basePoint, float id)
            {
                float time = _Time.y * _PositionChangeSpeed;
                
                // ノイズベースの位置変化
                float2 noiseOffset = float2(
                    noise(basePoint * _PositionNoiseScale + time + id),
                    noise(basePoint * _PositionNoiseScale + time * 1.3 + id * 2.37)
                ) * 0.2;
                
                return frac(basePoint + noiseOffset);
            }
            
            // ボロノイ距離計算
            float voronoiDistance(float2 point, float2 cell, out float2 nearestCell)
            {
                float minDist = 10.0;
                nearestCell = cell;
                
                // 周囲のセル（9つ）をチェック
                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 neighborCell = cell + float2(x, y);
                        float2 controlPoint = calculateControlPoint(neighborCell / _Density, hash(neighborCell));
                        
                        float dist = distance(point, controlPoint);
                        
                        if (dist < minDist)
                        {
                            minDist = dist;
                            nearestCell = neighborCell;
                        }
                    }
                }
                
                return minDist;
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
                // 座標をパターン密度に合わせてスケール
                float2 scaledUV = i.uv * _Density;
                float2 cell = floor(scaledUV);
                float2 localUV = frac(scaledUV);
                
                // ボロノイ距離と最近傍セルを計算
                float2 nearestCell;
                float voronoiDist = voronoiDistance(localUV, cell, nearestCell);
                
                // セルIDからベースカラーを生成
                float cellHash = hash(nearestCell);
                float3 cellColor = lerp(
                    _BaseColor.rgb, 
                    _BaseColor.rgb * (1.0 + _ColorVariation * (cellHash * 2.0 - 1.0)), 
                    _ColorVariation
                );
                
                // 境界線の計算
                float borderMask = smoothstep(
                    _BorderWidth, 
                    _BorderWidth + _BorderBlur, 
                    voronoiDist
                );
                
                // 最終カラー
                float3 finalColor = lerp(
                    _BorderColor.rgb, 
                    cellColor, 
                    borderMask
                );
                
                // メタリックとスムースネスを追加
                float metallic = _Metallic;
                float smoothness = _Smoothness;
                
                return float4(finalColor, 1.0);
            }
            ENDCG
        }
    }
    
    FallBack "Diffuse"
}
