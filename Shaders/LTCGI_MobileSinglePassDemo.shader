Shader "LTCGI/Surface Mobile Single-Pass"
{
    Properties 
    { 
        [HideInInspector] shader_is_using_thry_editor("", Float)=0
        [HideInInspector] shader_master_label("LTCGI Mobile Single-Pass", Float) = 0

        [Helpbox] _("**** If you see this, import Poiyomi Toon (this shader uses Thry's editor) ****--{condition_show:false}", Float) = 0
        // or don't, I'm a helpbox, not a cop

        [Helpbox] _("If the shader has an error, disable some features in the LTCGI Controller, Quest platform is limited to 16 texture samplers.", Float) = 0

        [ThryWideEnum(Opaque, 0, Transparent (PBR), 1, Transparent (Fade), 2)] _Mode("Rendering Preset--{on_value_actions:[
            {value:0,actions:[{type:SET_PROPERTY,data:render_queue=2000}, {type:SET_PROPERTY,data:_SrcBlend=1}, {type:SET_PROPERTY,data:_DstBlend=0},  {type:SET_PROPERTY,data:_ZWrite=1}]},
            {value:1,actions:[{type:SET_PROPERTY,data:render_queue=3000}, {type:SET_PROPERTY,data:_SrcBlend=1}, {type:SET_PROPERTY,data:_DstBlend=10}, {type:SET_PROPERTY,data:_ZWrite=0}]},
            {value:2,actions:[{type:SET_PROPERTY,data:render_queue=3000}, {type:SET_PROPERTY,data:_SrcBlend=5}, {type:SET_PROPERTY,data:_DstBlend=10}, {type:SET_PROPERTY,data:_ZWrite=0}]},
        ]}", Int) = 0

        [HideInInspector] m_MainOptions("Main", Float) = 1
            [HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
            _MainTex ("Albedo (RGB)--{reference_property:_Color}", 2D) = "white" {}
            [Normal] [NoScaleOffset] _BumpMap ("Normal Map--{reference_property:_BumpScale}" , 2D) = "bump" {}
            [HideInInspector] _BumpScale ("Normal Scale", Range(0,1)) = 1.0
            [HideInInspector] _LightMap ("(for surface ST only)", 2D) = "white" {}

            [NoScaleOffset] _MetallicGlossMap ("Metallic Map", 2D) = "white" {}
            [NoScaleOffset] _SpecGlossMap ("Smoothness Map", 2D) = "white" {}
            
            [Space(20)] _Metallic ("Metallic", Range(0,1)) = 0.0
            _Glossiness ("Smoothness", Range(0,1)) = 0.5
            [Enum(Straight, 0, Inverted, 1)] _MapIsRoughness ("Smoothness Map Type", Float) = 0.0

        [HideInInspector] m_Emission("Emission--{reference_property:_EnableEmission}", Float) = 1
            [HideInInspector] [ToggleUI] _EnableEmission ("Enabled", Float) = 0.0
            [HDR] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
            [NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}

        [HideInInspector] m_LTCGI("LTCGI--{reference_property:_LTCGI}", Float) = 1
            [HideInInspector] [ToggleUI] _LTCGI ("LTCGI enabled", Float) = 1.0
            _LTCGI_DiffuseColor ("LTCGI Diffuse Color", Color) = (1,1,1,1)
            _LTCGI_SpecularColor ("LTCGI Specular Color", Color) = (1,1,1,1)
            [Toggle] _LTCGI_Specular ("Enable Specular", Float) = 1.0
            [Toggle] _LTCGI_Diffuse ("Enable Diffuse", Float) = 1.0
            [Helpbox] _("Fresnel options have an high performance cost on mobile, leave them off in most cases.", Float) = 0.0
            [KeywordEnum(None, R0 Only, Simple, Clamped)] _LTCGI_FresnelMode ("Fresnel Mode", int) = 2
        
        [HideInInspector] m_Blending("Blending Options", Float) = 0
            [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Culling Mode", Float) = 2
            [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source Blend", Int) = 1
            [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination Blend", Int) = 0
            [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Int) = 1
        [HideInInspector] m_RenderingOptions("Rendering Options", Float) = 0
            [HideInInspector] DSGI("", Float) = 0
            [HideInInspector] Instancing("", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "LTCGI"="_LTCGI" }
        LOD 200

        Blend [_SrcBlend] [_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        CGPROGRAM
        #pragma target 4.0

        #pragma shader_feature_local _LTCGI_FRESNELMODE_SIMPLE _LTCGI_FRESNELMODE_CLAMPED _LTCGI_FRESNELMODE_NONE _LTCGI_FRESNELMODE_R0_ONLY
        #pragma shader_feature_local _LTCGI_SPECULAR_ON
        #pragma shader_feature_local _LTCGI_DIFFUSE_ON
        
        // BRDF2 saves a texture slot
        #define UNITY_BRDF_PBS BRDF2_Unity_PBS
        #include "UnityPBSLighting.cginc"
        #include "UnityCG.cginc"
        #include "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc"
        
        #pragma surface surf Standard exclude_path:prepass nodynlightmap noshadow nolppv keepalpha interpolateview

        UNITY_DECLARE_TEX2D(_MainTex);
        UNITY_DECLARE_TEX2D(_BumpMap);
        UNITY_DECLARE_TEX2D(_MetallicGlossMap);
        UNITY_DECLARE_TEX2D(_SpecGlossMap);
        UNITY_DECLARE_TEX2D(_EmissionMap);
        
        fixed4 _Color;
        float _BumpScale;
        float _Metallic;
        float _Glossiness;
        bool _MapIsRoughness;
        bool _EnableEmission;
        half4 _EmissionColor;
        bool _LTCGI;
        fixed4 _LTCGI_DiffuseColor;
        fixed4 _LTCGI_SpecularColor;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv2_LightMap;
            float3 worldPos;
            float3 worldNormal;
            INTERNAL_DATA
        };
        
        // pow5 for fixed point numbers, probably faster than half or float
        fixed fixedpow5(fixed x) {
            return x * x * x * x * x;
        }
        
        // calculates schlick's approximation
        fixed3 fastFresnelTerm(fixed3 f0, fixed VdotN) {
            return f0 + (1.0 - f0) * fixedpow5((fixed)1.0 - VdotN);
        }


        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_MainTex;

            // very basic pbr stuff
            fixed4 albedo = UNITY_SAMPLE_TEX2D(_MainTex, uv) * _Color;
            fixed metallic = UNITY_SAMPLE_TEX2D(_MetallicGlossMap, uv) * _Metallic;
            fixed glossiness = UNITY_SAMPLE_TEX2D(_SpecGlossMap, uv);
            if (_MapIsRoughness) glossiness = 1.0 - glossiness;
            glossiness *= _Glossiness;

            
            o.Normal = UnpackScaleNormal(UNITY_SAMPLE_TEX2D(_BumpMap, uv), _BumpScale);
            
            half3 emission = 0;
            
            emission += UNITY_SAMPLE_TEX2D(_EmissionMap, uv).rgb * _EmissionColor.rgb * _EnableEmission;
            
            if (_LTCGI) {
                half3 ltc_diffuse = 0;
                half3 ltc_specular = 0;
                
                half3 viewDir = normalize(_WorldSpaceCameraPos - IN.worldPos);
                half3 worldNormal = normalize(WorldNormalVector(IN, o.Normal));
                half vdotn = dot(viewDir, worldNormal);
                
                LTCGI_Contribution(
                    IN.worldPos,
                    worldNormal,
                    viewDir,
                    1.0 - glossiness,
                    IN.uv2_LightMap,
                    ltc_diffuse,
                    ltc_specular
                );
                
                // the r0 term in schlick's approximation is either 0.04 or the albedo, depending on the metalness
                fixed3 r0 = lerp((fixed3)(unity_ColorSpaceDielectricSpec.rgb), albedo.rgb, metallic);
                
                fixed3 fresnel = fastFresnelTerm(r0, vdotn);

                // clamped to the glossiness value, can help with bright edges sometimes
                // non-glossy edges can sometimes end up getting a higher specular value than they probably should
                fixed3 clamped_fresnel = clamp(fresnel, r0, max(r0, glossiness.rrr));
                
                ltc_specular *= _LTCGI_SpecularColor.rgb;
                
                #if defined(_LTCGI_FRESNELMODE_SIMPLE)
                ltc_specular *= fresnel;
                #elif defined(_LTCGI_FRESNELMODE_CLAMPED)
                ltc_specular *= clamped_fresnel;
                #elif defined(_LTCGI_FRESNELMODE_R0_ONLY)
                ltc_specular *= r0;
                #endif
                
                // diffuse should be tinted by albedo and diffuse color, but should be zero for transparent areas
                ltc_diffuse *= albedo.rgb * _LTCGI_DiffuseColor.rgb * albedo.a;
                // metallic areas should not have diffuse lighting
                ltc_diffuse *= (1.0 - metallic);
                
                // variants without one of these should optimise the math away (should)

                #ifdef _LTCGI_SPECULAR_ON
                    emission += ltc_specular;
                #endif
                #ifdef _LTCGI_DIFFUSE_ON
                    emission += ltc_diffuse;
                #endif
            }

            o.Albedo = albedo.rgb;
            o.Metallic = metallic;
            o.Smoothness = glossiness;
            o.Emission = emission;
            o.Alpha = albedo.a;
        }
        ENDCG
    }
    
    FallBack "Diffuse"
    CustomEditor "Thry.ShaderEditor"
}
    