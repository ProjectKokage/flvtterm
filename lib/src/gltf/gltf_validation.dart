part of '../../flvtterm.dart';

void _validateRequiredExtensions(
  GltfAsset gltf,
  _DiagnosticSink sink,
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
  _DiagnosticSink sink,
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

void _validateGltfReferences(GltfAsset gltf, _DiagnosticSink sink) {
  final vertexAttributeAccessors = _vertexAttributeAccessors(gltf);
  final primitiveIndexAccessors = _primitiveIndexAccessors(gltf);
  _validateGltfBuffers(gltf, sink);
  _validateGltfBufferViews(gltf, sink);

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
    _validateIndex(
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
      final nodePath = _scenePath(scene.index, '.nodes[$nodeIndex]');
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
      _validateIndex(
        node,
        gltf.nodes.length,
        sink,
        'gltf.invalidSceneNode',
        nodePath,
      );
    }
  }

  _validateNodeHierarchy(gltf, sink);

  final rawAccessors = _list(gltf.json['accessors']);
  for (final accessor in gltf.accessors) {
    final raw = _object(rawAccessors.elementAtOrNull(accessor.index));
    if (raw.containsKey('bufferView') && raw['bufferView'] is! int) {
      sink.error(
        'gltf.invalidAccessorBufferView',
        'Accessor bufferView must be an integer.',
        jsonPath: _accessorPath(accessor.index, '.bufferView'),
      );
    } else if (accessor.bufferView != null) {
      _validateIndex(
        accessor.bufferView!,
        gltf.bufferViews.length,
        sink,
        'gltf.invalidAccessorBufferView',
        _accessorPath(accessor.index, '.bufferView'),
      );
    } else if (raw.containsKey('byteOffset')) {
      sink.error(
        'gltf.accessorByteOffsetWithoutBufferView',
        'Accessor byteOffset must not be defined without bufferView.',
        jsonPath: _accessorPath(accessor.index, '.byteOffset'),
      );
    }
    if (raw['componentType'] is! int ||
        _componentByteSize(accessor.componentType) == null) {
      sink.error(
        'gltf.invalidAccessorComponentType',
        'Accessor componentType must be a glTF 2.0 component type.',
        jsonPath: _accessorPath(accessor.index, '.componentType'),
      );
    }
    if (raw['type'] is! String || accessor.componentCount == null) {
      sink.error(
        'gltf.invalidAccessorType',
        'Accessor type must be a glTF 2.0 accessor type.',
        jsonPath: _accessorPath(accessor.index, '.type'),
      );
    }
    if ((raw.containsKey('byteOffset') && raw['byteOffset'] is! int) ||
        accessor.byteOffset < 0 ||
        accessor.count == null ||
        accessor.count! <= 0) {
      sink.error(
        'gltf.invalidAccessorShape',
        'Accessor byteOffset must be non-negative and count must be positive.',
        jsonPath: _accessorPath(accessor.index, ''),
      );
    }
    if (raw.containsKey('normalized') && raw['normalized'] is! bool) {
      sink.error(
        'gltf.invalidAccessorNormalized',
        'Accessor normalized must be a boolean.',
        jsonPath: _accessorPath(accessor.index, '.normalized'),
      );
    } else if (accessor.normalized &&
        (accessor.componentType == 5125 || accessor.componentType == 5126)) {
      sink.error(
        'gltf.invalidAccessorNormalized',
        'Accessor normalized must not be true for FLOAT or UNSIGNED_INT components.',
        jsonPath: _accessorPath(accessor.index, '.normalized'),
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
    _validateRawAccessorSparse(accessor.index, raw, sink);
    _validateAccessorBounds(accessor, raw, sink);
    _validateAccessorBoundsMatchData(accessor, gltf, sink);
    _validateAccessorRange(
      accessor,
      gltf,
      sink,
      isVertexAttribute: vertexAttributeAccessors.contains(accessor.index),
    );
    _validateAccessorSparse(accessor, gltf, sink);
    _validateAccessorFiniteFloatValues(accessor, gltf, sink);
  }

  _validateGltfNodes(gltf, sink);

  _validateGltfCameras(gltf, sink);

  _validateGltfMeshes(gltf, sink);

  _validateGltfMaterials(gltf, sink);

  final rawSkins = _list(gltf.json['skins']);
  for (final skin in gltf.skins) {
    final raw = _object(rawSkins.elementAtOrNull(skin.index));
    if (skin.joints.isEmpty) {
      sink.error(
        'gltf.missingSkinJoints',
        'Skin joints are required.',
        jsonPath: _skinPath(skin.index, '.joints'),
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
          jsonPath: _skinPath(skin.index, '.joints[$jointIndex]'),
        );
      }
      _validateIndex(
        joint,
        gltf.nodes.length,
        sink,
        'gltf.invalidSkinJoint',
        _skinPath(skin.index, '.joints[$jointIndex]'),
      );
    }
    if (raw.containsKey('skeleton') && raw['skeleton'] is! int) {
      sink.error(
        'gltf.invalidSkinSkeleton',
        'Skin skeleton must be an integer.',
        jsonPath: _skinPath(skin.index, '.skeleton'),
      );
    } else if (skin.skeleton != null) {
      _validateIndex(
        skin.skeleton!,
        gltf.nodes.length,
        sink,
        'gltf.invalidSkinSkeleton',
        _skinPath(skin.index, '.skeleton'),
      );
      _validateSkinSkeletonRoot(skin, gltf, sink);
    }
    _validateSkinJointCommonRoot(skin, gltf, sink);
    if (raw.containsKey('inverseBindMatrices') &&
        raw['inverseBindMatrices'] is! int) {
      sink.error(
        'gltf.invalidSkinInverseBindMatrices',
        'Skin inverseBindMatrices must be an integer.',
        jsonPath: _skinPath(skin.index, '.inverseBindMatrices'),
      );
    } else if (skin.inverseBindMatrices != null) {
      _validateIndex(
        skin.inverseBindMatrices!,
        gltf.accessors.length,
        sink,
        'gltf.invalidSkinInverseBindMatrices',
        _skinPath(skin.index, '.inverseBindMatrices'),
      );
      _validateSkinInverseBindMatrices(skin, gltf, sink);
    }
  }

  _validateGltfTextureResources(gltf, sink);
  _validateGltfAnimations(gltf, sink);
}

String _skinPath(int skinIndex, String suffix) => '\$.skins[$skinIndex]$suffix';

String _scenePath(int sceneIndex, String suffix) =>
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
