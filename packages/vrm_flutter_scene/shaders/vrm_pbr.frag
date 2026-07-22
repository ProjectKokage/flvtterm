#include <material_varyings.glsl>
#include <normals.glsl>
#include <pbr.glsl>
#include <texture.glsl>
#include <material_engine_lighting.glsl>
#include <material_inputs.glsl>
#include <material_lighting.glsl>

uniform TextureInfo {
  vec4 base_color_scale_offset;
  vec4 base_color_rotation;
  vec4 metallic_roughness_scale_offset;
  vec4 metallic_roughness_rotation;
  vec4 normal_scale_offset;
  vec4 normal_rotation;
  vec4 occlusion_scale_offset;
  vec4 occlusion_rotation;
  vec4 emissive_scale_offset;
  vec4 emissive_rotation;
}
texture_info;

uniform sampler2D base_color_texture;
uniform sampler2D emissive_texture;
uniform sampler2D metallic_roughness_texture;
uniform sampler2D normal_texture;
uniform sampler2D occlusion_texture;

vec2 TransformUv(vec2 uv, vec4 scale_offset, vec4 rotation) {
  vec2 scaled = uv * scale_offset.xy;
  return scale_offset.zw +
         vec2(rotation.x * scaled.x - rotation.y * scaled.y,
              rotation.y * scaled.x + rotation.x * scaled.y);
}

void Surface(inout MaterialInputs material) {
  vec4 vertex_color = mix(vec4(1), v_color, frag_info.vertex_color_weight);
  vec2 base_color_uv =
      TransformUv(v_texture_coords, texture_info.base_color_scale_offset,
                  texture_info.base_color_rotation);
  vec4 base_color_srgb = texture(base_color_texture, base_color_uv);
  vec3 albedo = SRGBToLinear(base_color_srgb.rgb) * vertex_color.rgb *
                frag_info.color.rgb;
  float alpha = base_color_srgb.a * vertex_color.a * frag_info.color.a;
  if (frag_info.alpha_mode == 1.0) {
    if (alpha < frag_info.alpha_cutoff) {
      discard;
    }
    alpha = 1.0;
  }
  material.base_color = vec4(albedo, alpha);

  vec3 normal = normalize(v_normal);
  if (frag_info.has_normal_map > 0.5) {
    vec2 normal_uv =
        TransformUv(v_texture_coords, texture_info.normal_scale_offset,
                    texture_info.normal_rotation);
    normal = PerturbNormal(normal_texture, normal, v_viewvector, normal_uv);
  }
  material.normal = normal;

  vec2 metallic_roughness_uv = TransformUv(
      v_texture_coords, texture_info.metallic_roughness_scale_offset,
      texture_info.metallic_roughness_rotation);
  vec4 metallic_roughness =
      texture(metallic_roughness_texture, metallic_roughness_uv);
  material.metallic = clamp(metallic_roughness.b * frag_info.metallic_factor,
                            0.0, 1.0);
  material.roughness =
      clamp(metallic_roughness.g * frag_info.roughness_factor, kMinRoughness,
            1.0);

  vec2 occlusion_uv =
      TransformUv(v_texture_coords, texture_info.occlusion_scale_offset,
                  texture_info.occlusion_rotation);
  float occlusion = texture(occlusion_texture, occlusion_uv).r;
  material.occlusion = 1.0 -
                       (1.0 - occlusion) * frag_info.occlusion_strength;

  vec2 emissive_uv =
      TransformUv(v_texture_coords, texture_info.emissive_scale_offset,
                  texture_info.emissive_rotation);
  material.emissive =
      SRGBToLinear(texture(emissive_texture, emissive_uv).rgb) *
      frag_info.emissive_factor.rgb;

  PrepareMaterial(material);
}

void main() {
  MaterialInputs material = InitMaterialInputs();
  Surface(material);
  frag_color = EvaluateLighting(material);
}
