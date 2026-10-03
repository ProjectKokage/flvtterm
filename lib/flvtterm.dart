/// Pure Dart VRM/VRMA parsing, validation, and renderer-neutral runtime APIs.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

part 'src/diagnostics.dart';
part 'src/image_dimensions.dart';
part 'src/json_values.dart';
part 'src/math_types.dart';
part 'src/matrix_math.dart';
part 'src/parser.dart';
part 'src/safe_list_index.dart';

part 'src/gltf/accessor_reader.dart';
part 'src/gltf/animation_math.dart';
part 'src/gltf/gltf_accessor_validation.dart';
part 'src/gltf/gltf_animation_parser.dart';
part 'src/gltf/gltf_animation_types.dart';
part 'src/gltf/gltf_animation_validation.dart';
part 'src/gltf/gltf_buffer_validation.dart';
part 'src/gltf/gltf_camera_types.dart';
part 'src/gltf/gltf_camera_validation.dart';
part 'src/gltf/gltf_material_types.dart';
part 'src/gltf/gltf_material_validation.dart';
part 'src/gltf/gltf_mesh_types.dart';
part 'src/gltf/gltf_mesh_validation.dart';
part 'src/gltf/gltf_node_constraint_types.dart';
part 'src/gltf/gltf_node_constraint_validation.dart';
part 'src/gltf/gltf_parser.dart';
part 'src/gltf/gltf_resource_types.dart';
part 'src/gltf/gltf_scene_types.dart';
part 'src/gltf/gltf_structure_validation.dart';
part 'src/gltf/gltf_texture_validation.dart';
part 'src/gltf/gltf_types.dart';
part 'src/gltf/gltf_validation.dart';
part 'src/gltf/material_parser.dart';

part 'src/runtime/constraint_math.dart';
part 'src/runtime/expression_controller.dart';
part 'src/runtime/expression_helpers.dart';
part 'src/runtime/look_at_controller.dart';
part 'src/runtime/look_at_math.dart';
part 'src/runtime/motion_arm_spacing.dart';
part 'src/runtime/motion_controller.dart';
part 'src/runtime/motion_retargeter.dart';
part 'src/runtime/motion_vrma_plan.dart';
part 'src/runtime/node_constraint_controller.dart';
part 'src/runtime/runtime.dart';
part 'src/runtime/runtime_transform_helpers.dart';
part 'src/runtime/scene_binding.dart';
part 'src/runtime/scene_binding_cache.dart';
part 'src/runtime/spring_bone_controller.dart';
part 'src/runtime/spring_bone_math.dart';

part 'src/vrm/first_person_analysis.dart';
part 'src/vrm/spring_bone_parser.dart';
part 'src/vrm/spring_bone_types.dart';
part 'src/vrm/vrm_assets.dart';
part 'src/vrm/vrm_enums.dart';
part 'src/vrm/vrm_expression_parser.dart';
part 'src/vrm/vrm_first_person_parser.dart';
part 'src/vrm/vrm_humanoid_parser.dart';
part 'src/vrm/vrm_look_at_parser.dart';
part 'src/vrm/vrm_meta_parser.dart';
part 'src/vrm/vrm_parser.dart';
part 'src/vrm/vrm_types.dart';

part 'src/vrm0/vrm0_converter.dart';
part 'src/vrm0/vrm0_parser.dart';
part 'src/vrm0/vrm0_types.dart';
part 'src/vrm0/vrm_coordinate_convention.dart';

part 'src/vrma/vrma_parser.dart';
part 'src/vrma/vrma_validation.dart';
