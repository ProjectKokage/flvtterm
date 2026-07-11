import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flvtterm/flvtterm.dart';
import 'package:test/test.dart';

part 'src/parser_tests.dart';
part 'src/vrm_first_person_tests.dart';
part 'src/expression_look_at_tests.dart';
part 'src/materials_constraints_spring_tests.dart';
part 'src/material_tests.dart';
part 'src/node_constraint_tests.dart';
part 'src/spring_bone_tests.dart';
part 'src/animation_motion_vrma_tests.dart';
part 'src/gltf_accessor_tests.dart';
part 'src/gltf_buffer_tests.dart';
part 'src/gltf_camera_tests.dart';
part 'src/gltf_mesh_tests.dart';
part 'src/gltf_skin_tests.dart';
part 'src/gltf_animation_tests.dart';
part 'src/runtime_tests.dart';
part 'src/motion_controller_tests.dart';
part 'src/vrma_motion_tests.dart';
part 'src/cli_tests.dart';
part 'src/vrm0_compatibility_tests.dart';
part 'src/test_fixtures.dart';

void main() {
  parserTests();
  vrmFirstPersonTests();
  expressionLookAtTests();
  materialsConstraintsSpringTests();
  gltfAccessorTests();
  gltfBufferTests();
  gltfCameraTests();
  gltfMeshTests();
  gltfSkinTests();
  animationMotionVrmaTests();
  runtimeTests();
  cliTests();
  vrm0CompatibilityTests();
}
