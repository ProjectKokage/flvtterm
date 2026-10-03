import 'package:meta/meta.dart';

import '../diagnostics.dart';
import '../json_values.dart';
import '../safe_list_index.dart';
import 'accessor_reader.dart';
import 'gltf_accessor_validation.dart';
import 'gltf_animation_validation.dart';
import 'gltf_buffer_validation.dart';
import 'gltf_camera_validation.dart';
import 'gltf_material_validation.dart';
import 'gltf_mesh_validation.dart';
import 'gltf_node_constraint_validation.dart';
import 'gltf_structure_validation.dart';
import 'gltf_texture_validation.dart';
import 'gltf_types.dart';

@internal
void validateRequiredExtensions(
  GltfAsset gltf,
  DiagnosticSink sink,
  Set<String> supported,
) {
  _validateUniqueRootStrings(
    gltf.extensionsUsed,
    sink,
    'gltf.duplicateExtensionUsed',
    r'$.extensionsUsed',
  );
  _validateUniqueRootStrings(
    gltf.extensionsRequired,
    sink,
    'gltf.duplicateExtensionRequired',
    r'$.extensionsRequired',
  );
  final used = gltf.extensionsUsed.toSet();
  for (final entry in _declaredExtensionObjectPaths(gltf.json).entries) {
    final extension = entry.key;
    if (used.contains(extension)) continue;
    sink.error(
      'gltf.extensionNotUsed',
      'Extension "$extension" is used but not listed in extensionsUsed.',
      jsonPath: entry.value,
    );
  }
  for (var i = 0; i < gltf.extensionsRequired.length; i++) {
    final extension = gltf.extensionsRequired[i];
    final path = '\$.extensionsRequired[$i]';
    if (!used.contains(extension)) {
      sink.error(
        'gltf.requiredExtensionNotUsed',
        'Required extension "$extension" must also be listed in extensionsUsed.',
        jsonPath: path,
      );
    }
    if (!supported.contains(extension)) {
      sink.error(
        'gltf.unsupportedRequiredExtension',
        'Required extension "$extension" is not supported.',
        jsonPath: path,
      );
    }
  }
}

Map<String, String> _declaredExtensionObjectPaths(Object? value) {
  final result = <String, String>{};

  void visit(Object? item, String path) {
    if (item is Map) {
      final object = item.cast<String, Object?>();
      final extensions = object['extensions'];
      if (extensions is Map) {
        final extensionObject = extensions.cast<String, Object?>();
        for (final entry in extensionObject.entries) {
          final extensionPath = '$path.extensions.${entry.key}';
          result.putIfAbsent(entry.key, () => extensionPath);
          visit(entry.value, extensionPath);
        }
      }
      for (final entry in object.entries) {
        if (entry.key == 'extensions' || entry.key == 'extras') continue;
        visit(entry.value, '$path.${entry.key}');
      }
    } else if (item is List) {
      for (var i = 0; i < item.length; i++) {
        visit(item[i], '$path[$i]');
      }
    }
  }

  visit(value, r'$');
  return result;
}

void _validateUniqueRootStrings(
  List<String> values,
  DiagnosticSink sink,
  String code,
  String jsonPath,
) {
  final seen = <String>{};
  for (var i = 0; i < values.length; i++) {
    if (seen.add(values[i])) continue;
    sink.error(
      code,
      'Root extension list entries must be unique.',
      jsonPath: '$jsonPath[$i]',
    );
  }
}

@internal
void validateGltfReferences(GltfAsset gltf, DiagnosticSink sink) {
  final vertexAttributeAccessors = _vertexAttributeAccessors(gltf);
  final primitiveIndexAccessors = _primitiveIndexAccessors(gltf);
  validateGltfBuffers(gltf, sink);
  validateGltfBufferViews(gltf, sink);

  if (gltf.json.containsKey('scene') && gltf.json['scene'] is! int) {
    sink.error(
      'gltf.invalidDefaultScene',
      'Default scene must be an integer.',
      jsonPath: r'$.scene',
    );
  } else if (gltf.scene != null && !gltf.json.containsKey('scenes')) {
    sink.error(
      'gltf.defaultSceneWithoutScenes',
      'Default scene must not be defined when scenes is undefined.',
      jsonPath: r'$.scene',
    );
  } else if (gltf.scene != null) {
    validateIndex(
      gltf.scene!,
      gltf.scenes.length,
      sink,
      'gltf.invalidDefaultScene',
      r'$.scene',
    );
  }

  for (final scene in gltf.scenes) {
    final nodes = <int>{};
    var duplicateNodeReported = false;
    for (var nodeIndex = 0; nodeIndex < scene.nodes.length; nodeIndex++) {
      final node = scene.nodes[nodeIndex];
      final nodePath = scenePath(scene.index, '.nodes[$nodeIndex]');
      if (!nodes.add(node)) {
        if (!duplicateNodeReported) {
          sink.error(
            'gltf.duplicateSceneNode',
            'Scene nodes must not contain duplicate root node indices.',
            jsonPath: nodePath,
          );
          duplicateNodeReported = true;
        }
        continue;
      }
      validateIndex(
        node,
        gltf.nodes.length,
        sink,
        'gltf.invalidSceneNode',
        nodePath,
      );
    }
  }

  validateNodeHierarchy(gltf, sink);

  final rawAccessors = jsonList(gltf.json['accessors']);
  for (final accessor in gltf.accessors) {
    final raw = jsonObject(rawAccessors.elementAtOrNull(accessor.index));
    if (raw.containsKey('bufferView') && raw['bufferView'] is! int) {
      sink.error(
        'gltf.invalidAccessorBufferView',
        'Accessor bufferView must be an integer.',
        jsonPath: accessorPath(accessor.index, '.bufferView'),
      );
    } else if (accessor.bufferView != null) {
      validateIndex(
        accessor.bufferView!,
        gltf.bufferViews.length,
        sink,
        'gltf.invalidAccessorBufferView',
        accessorPath(accessor.index, '.bufferView'),
      );
    } else if (raw.containsKey('byteOffset')) {
      sink.error(
        'gltf.accessorByteOffsetWithoutBufferView',
        'Accessor byteOffset must not be defined without bufferView.',
        jsonPath: accessorPath(accessor.index, '.byteOffset'),
      );
    }
    if (raw['componentType'] is! int ||
        componentByteSize(accessor.componentType) == null) {
      sink.error(
        'gltf.invalidAccessorComponentType',
        'Accessor componentType must be a glTF 2.0 component type.',
        jsonPath: accessorPath(accessor.index, '.componentType'),
      );
    }
    if (raw['type'] is! String || accessor.componentCount == null) {
      sink.error(
        'gltf.invalidAccessorType',
        'Accessor type must be a glTF 2.0 accessor type.',
        jsonPath: accessorPath(accessor.index, '.type'),
      );
    }
    if ((raw.containsKey('byteOffset') && raw['byteOffset'] is! int) ||
        accessor.byteOffset < 0 ||
        accessor.count == null ||
        accessor.count! <= 0) {
      sink.error(
        'gltf.invalidAccessorShape',
        'Accessor byteOffset must be non-negative and count must be positive.',
        jsonPath: accessorPath(accessor.index, ''),
      );
    }
    if (raw.containsKey('normalized') && raw['normalized'] is! bool) {
      sink.error(
        'gltf.invalidAccessorNormalized',
        'Accessor normalized must be a boolean.',
        jsonPath: accessorPath(accessor.index, '.normalized'),
      );
    } else if (accessor.normalized &&
        (accessor.componentType == 5125 || accessor.componentType == 5126)) {
      sink.error(
        'gltf.invalidAccessorNormalized',
        'Accessor normalized must not be true for FLOAT or UNSIGNED_INT components.',
        jsonPath: accessorPath(accessor.index, '.normalized'),
      );
    }
    if (accessor.componentType == 5125 &&
        !primitiveIndexAccessors.contains(accessor.index)) {
      sink.error(
        'gltf.invalidAccessorUnsignedIntUse',
        'UNSIGNED_INT accessors may only be used for mesh primitive indices.',
        jsonPath: '\$.accessors[${accessor.index}].componentType',
      );
    }
    validateRawAccessorSparse(accessor.index, raw, sink);
    validateAccessorBounds(accessor, raw, sink);
    validateAccessorBoundsMatchData(accessor, gltf, sink);
    validateAccessorRange(
      accessor,
      gltf,
      sink,
      isVertexAttribute: vertexAttributeAccessors.contains(accessor.index),
    );
    validateAccessorSparse(accessor, gltf, sink);
    validateAccessorFiniteFloatValues(accessor, gltf, sink);
  }

  validateGltfNodes(gltf, sink);

  validateGltfCameras(gltf, sink);

  validateGltfMeshes(gltf, sink);

  validateGltfMaterials(gltf, sink);

  final rawSkins = jsonList(gltf.json['skins']);
  for (final skin in gltf.skins) {
    final raw = jsonObject(rawSkins.elementAtOrNull(skin.index));
    if (skin.joints.isEmpty) {
      sink.error(
        'gltf.missingSkinJoints',
        'Skin joints are required.',
        jsonPath: skinPath(skin.index, '.joints'),
      );
    }
    final joints = <int>{};
    var duplicateJointReported = false;
    for (var jointIndex = 0; jointIndex < skin.joints.length; jointIndex++) {
      final joint = skin.joints[jointIndex];
      if (!joints.add(joint) && !duplicateJointReported) {
        duplicateJointReported = true;
        sink.error(
          'gltf.duplicateSkinJoint',
          'Skin joints must not contain duplicate node indices.',
          jsonPath: skinPath(skin.index, '.joints[$jointIndex]'),
        );
      }
      validateIndex(
        joint,
        gltf.nodes.length,
        sink,
        'gltf.invalidSkinJoint',
        skinPath(skin.index, '.joints[$jointIndex]'),
      );
    }
    if (raw.containsKey('skeleton') && raw['skeleton'] is! int) {
      sink.error(
        'gltf.invalidSkinSkeleton',
        'Skin skeleton must be an integer.',
        jsonPath: skinPath(skin.index, '.skeleton'),
      );
    } else if (skin.skeleton != null) {
      validateIndex(
        skin.skeleton!,
        gltf.nodes.length,
        sink,
        'gltf.invalidSkinSkeleton',
        skinPath(skin.index, '.skeleton'),
      );
      validateSkinSkeletonRoot(skin, gltf, sink);
    }
    validateSkinJointCommonRoot(skin, gltf, sink);
    if (raw.containsKey('inverseBindMatrices') &&
        raw['inverseBindMatrices'] is! int) {
      sink.error(
        'gltf.invalidSkinInverseBindMatrices',
        'Skin inverseBindMatrices must be an integer.',
        jsonPath: skinPath(skin.index, '.inverseBindMatrices'),
      );
    } else if (skin.inverseBindMatrices != null) {
      validateIndex(
        skin.inverseBindMatrices!,
        gltf.accessors.length,
        sink,
        'gltf.invalidSkinInverseBindMatrices',
        skinPath(skin.index, '.inverseBindMatrices'),
      );
      validateSkinInverseBindMatrices(skin, gltf, sink);
    }
  }

  validateGltfTextureResources(gltf, sink);
  validateGltfAnimations(gltf, sink);
}

@internal
String skinPath(int skinIndex, String suffix) => '\$.skins[$skinIndex]$suffix';

@internal
String scenePath(int sceneIndex, String suffix) =>
    '\$.scenes[$sceneIndex]$suffix';

Set<int> _primitiveIndexAccessors(GltfAsset gltf) {
  final accessors = <int>{};
  for (final mesh in gltf.meshes) {
    for (final primitive in mesh.primitives) {
      final indices = primitive.indices;
      if (indices != null) accessors.add(indices);
    }
  }
  return accessors;
}

Set<int> _vertexAttributeAccessors(GltfAsset gltf) {
  final accessors = <int>{};
  for (final mesh in gltf.meshes) {
    for (final primitive in mesh.primitives) {
      accessors.addAll(primitive.attributes.values);
      for (final target in primitive.targets) {
        accessors.addAll(target.values);
      }
    }
  }
  return accessors;
}
