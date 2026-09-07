uniform MaterialInfo {
  vec4 color;
  float vertex_color_weight;
  float alpha_mode;
  float alpha_cutoff;
  float fade;
  float texture_coord;
}
material_info;

#include <lod_fade.glsl>

uniform TextureInfo {
  vec4 base_color_scale_offset;
  vec4 base_color_rotation;
}
texture_info;

uniform sampler2D base_color_texture;

#include <material_varyings.glsl>

const float kGamma = 2.2;
vec3 SRGBToLinear(vec3 color) { return pow(color, vec3(kGamma)); }

vec2 TransformUv(vec2 uv, vec4 scale_offset, vec4 rotation) {
  vec2 scaled = uv * scale_offset.xy;
  return scale_offset.zw +
         vec2(rotation.x * scaled.x - rotation.y * scaled.y,
              rotation.y * scaled.x + rotation.x * scaled.y);
}

void main() {
  ApplyLodFade(material_info.fade);
  vec4 vertex_color =
      mix(vec4(1), v_color, material_info.vertex_color_weight);
  vec2 uv = TransformUv(GetUV(int(material_info.texture_coord)),
                        texture_info.base_color_scale_offset,
                        texture_info.base_color_rotation);
  vec4 base = texture(base_color_texture, uv);
  vec3 rgb =
      SRGBToLinear(base.rgb) * vertex_color.rgb * material_info.color.rgb;
  float alpha = base.a * vertex_color.a * material_info.color.a;

  if (material_info.alpha_mode == 0.0) {
    alpha = 1.0;
  } else if (material_info.alpha_mode == 1.0) {
    if (alpha < material_info.alpha_cutoff) {
      discard;
    }
    alpha = 1.0;
  }

  frag_color = vec4(rgb, 1.0) * alpha;
}
