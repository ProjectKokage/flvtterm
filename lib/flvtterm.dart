/// Pure Dart VRM/VRMA parsing, validation, and renderer-neutral runtime APIs.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

part 'src/accessor_reader.dart';
part 'src/animation_math.dart';
part 'src/constraint_math.dart';
part 'src/diagnostics.dart';
part 'src/expression_controller.dart';
part 'src/expression_helpers.dart';
part 'src/first_person_analysis.dart';
part 'src/gltf_parser.dart';
part 'src/gltf_animation_parser.dart';
part 'src/gltf_accessor_validation.dart';
part 'src/gltf_animation_validation.dart';
part 'src/gltf_buffer_validation.dart';
part 'src/gltf_animation_types.dart';
part 'src/gltf_camera_types.dart';
part 'src/gltf_camera_validation.dart';
part 'src/gltf_material_types.dart';
part 'src/gltf_material_validation.dart';
part 'src/gltf_mesh_types.dart';
part 'src/gltf_mesh_validation.dart';
part 'src/gltf_node_constraint_types.dart';
part 'src/gltf_node_constraint_validation.dart';
part 'src/gltf_resource_types.dart';
part 'src/gltf_scene_types.dart';
part 'src/gltf_structure_validation.dart';
part 'src/gltf_texture_validation.dart';
part 'src/gltf_types.dart';
part 'src/gltf_validation.dart';
part 'src/image_dimensions.dart';
part 'src/internal_helpers.dart';
part 'src/look_at_controller.dart';
part 'src/look_at_math.dart';
part 'src/material_parser.dart';
part 'src/math_types.dart';
part 'src/matrix_math.dart';
part 'src/motion_apply.dart';
part 'src/motion_controller.dart';
part 'src/motion_layers.dart';
part 'src/motion_retargeter.dart';
part 'src/motion_snapshot.dart';
part 'src/motion_vrma.dart';
part 'src/node_constraint_controller.dart';
part 'src/parser.dart';
part 'src/runtime.dart';
part 'src/runtime_transform_helpers.dart';
part 'src/scene_binding.dart';
part 'src/spring_bone_controller.dart';
part 'src/spring_bone_math.dart';
part 'src/spring_bone_parser.dart';
part 'src/spring_bone_types.dart';
part 'src/vrm_assets.dart';
part 'src/vrm_enums.dart';
part 'src/vrm_expression_parser.dart';
part 'src/vrm_first_person_parser.dart';
part 'src/vrm_humanoid_parser.dart';
part 'src/vrm_look_at_parser.dart';
part 'src/vrm_meta_parser.dart';
part 'src/vrm_parser.dart';
part 'src/vrm_types.dart';
part 'src/vrma_parser.dart';
part 'src/vrma_validation.dart';

const _gltfArrayBufferTarget = 34962;
const _gltfElementArrayBufferTarget = 34963;

const _gltfImageMimeTypes = {'image/jpeg', 'image/png'};
const _gltfBufferMimeTypes = {
  'application/octet-stream',
  'application/gltf-buffer',
};
const _samplerMagFilters = {9728, 9729};
const _samplerMinFilters = {9728, 9729, 9984, 9985, 9986, 9987};
const _samplerWrapModes = {33071, 33648, 10497};
