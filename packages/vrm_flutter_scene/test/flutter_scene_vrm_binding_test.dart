import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_scene/src/gpu/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/vrm_flutter_scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test('binding options copy explicit node index paths', () {
    final path = [0, 0];
    final paths = {0: path};
    final options = FlutterSceneVrmBindingOptions(nodeIndexPaths: paths);

    path[0] = 9;
    paths[1] = [1];

    expect(options.nodeIndexPaths, {
      0: [0, 0],
    });
    expect(() => options.nodeIndexPaths[0]!.add(1), throwsUnsupportedError);
    expect(() => options.nodeIndexPaths[1] = [1], throwsUnsupportedError);
  });

  test('binds Flutter Scene nodes by parsed glTF hierarchy', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'importRoot');
    final sceneNodes = [
      for (var i = 0; i < _nodeChildren.length; i++) scene.Node(name: 'node$i'),
    ];
    for (var i = 0; i < _nodeChildren.length; i++) {
      for (final child in _nodeChildren[i]) {
        sceneNodes[i].add(sceneNodes[child]);
      }
    }
    root.add(sceneNodes[0]);
    final binding = FlutterSceneVrmBinding.fromRootNode(root, model: model);
    final transform = VrmMatrix4([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      1,
      2,
      3,
      1,
    ]);

    binding.nodeByGltfIndex(0).localTransform = transform;
    binding.modelRootMotionTransform = transform;
    binding
        .materialByGltfIndex(0)
        .setTextureTransform(scale: VrmVector2.one, offset: VrmVector2.zero);

    expect(sceneNodes[0].localTransform.storage[12], 1);
    expect(sceneNodes[0].localTransform.storage[13], 2);
    expect(root.localTransform.storage[14], 3);
    for (var i = 0; i < sceneNodes.length; i++) {
      expect(binding.nodeByGltfIndex(i).debugName, 'node$i');
    }
    expect(
      binding.capabilityWarnings.map((d) => d.code),
      contains('flutterScene.unsupportedTextureTransform'),
    );
  });

  test('accepts explicit Flutter Scene node index paths', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root');
    final wrapper = scene.Node(name: 'wrapper');
    final hips = scene.Node(name: 'hips');
    root.add(wrapper);
    wrapper.add(hips);
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(
        nodeIndexPaths: {
          0: [0, 0],
        },
      ),
    );

    expect(binding.nodeByGltfIndex(0).debugName, 'hips');
  });

  test('warns and drops duplicate Flutter Scene node bindings', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root');
    final shared = scene.Node(name: 'shared');
    root.add(shared);

    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(
        nodeIndexPaths: {
          0: [0],
          1: [0],
        },
      ),
    );

    final warning = binding.capabilityWarnings.singleWhere(
      (diagnostic) => diagnostic.code == 'flutterScene.duplicateNodeBinding',
    );
    expect(warning.gltfNodeIndex, 1);
    expect(binding.nodeByGltfIndex(0).debugName, 'shared');
    expect(() => binding.nodeByGltfIndex(1), throwsRangeError);
  });

  test('warns for invalid explicit Flutter Scene node index paths', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root');
    root.add(scene.Node(name: 'fallbackHips'));
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(
        nodeIndexPaths: {
          -1: [0],
          0: [99],
          99: [0],
        },
      ),
    );

    final warnings = binding.capabilityWarnings
        .where(
          (diagnostic) =>
              diagnostic.code == 'flutterScene.invalidNodeIndexPath',
        )
        .toList();
    expect(warnings.map((diagnostic) => diagnostic.gltfNodeIndex), [-1, 0, 99]);
    expect(binding.nodeByGltfIndex(0).debugName, 'root');
    expect(() => binding.nodeByGltfIndex(-1), throwsRangeError);
    expect(() => binding.nodeByGltfIndex(99), throwsRangeError);
  });

  test('warns when Flutter Scene traversal does not cover every glTF node', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root');
    final binding = FlutterSceneVrmBinding.fromRootNode(root, model: model);

    final warnings = binding.capabilityWarnings
        .where((d) => d.code == 'flutterScene.missingNodeBinding')
        .toList();

    expect(warnings.map((d) => d.gltfNodeIndex), [
      for (var i = 1; i < model.gltf.nodes.length; i++) i,
    ]);
    expect(binding.nodeByGltfIndex(0).debugName, 'root');
    expect(() => binding.nodeByGltfIndex(1), throwsRangeError);
  });

  test('preserves imported root transform when applying root motion', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root')
      ..localTransform = vm.Matrix4.diagonal3Values(2, 1, 1);
    final binding = FlutterSceneVrmBinding.fromRootNode(root, model: model);

    binding.modelRootMotionTransform = VrmMatrix4([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      1,
      0,
      0,
      1,
    ]);

    expect(root.localTransform.storage[0], 2);
    expect(root.localTransform.storage[12], 2);
  });

  test('exposes outer application placement in model world space', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final parent = scene.Node(
      name: 'appParent',
      localTransform: vm.Matrix4.translationValues(3, 4, 5),
    );
    final root = scene.Node(name: 'node0');
    parent.add(root);
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: true),
    );

    expect(binding.modelWorldTransform.storage[12], closeTo(3, 0.000001));
    expect(binding.modelWorldTransform.storage[13], closeTo(4, 0.000001));
    expect(binding.modelWorldTransform.storage[14], closeTo(5, 0.000001));
  });

  test('composes VRM 0.x basis with an aliased glTF scene root', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb(legacy: true));
    final importTransform = vm.Matrix4.diagonal3Values(1, 1, -1);
    final sourceRootLocal = vm.Matrix4.translationValues(1, 0, 0);
    final root = scene.Node(
      name: 'node0',
      localTransform: importTransform.clone()..multiply(sourceRootLocal),
    );
    final sceneNodes = <scene.Node>[root];
    for (var i = 1; i < _legacyNodeChildren.length; i++) {
      sceneNodes.add(scene.Node(name: 'node$i'));
    }
    for (var i = 0; i < _legacyNodeChildren.length; i++) {
      for (final child in _legacyNodeChildren[i]) {
        sceneNodes[i].add(sceneNodes[child]);
      }
    }
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: true),
    );

    (VrmRuntime(model)..bind(binding)).update(0);

    expect(binding.nodeByGltfIndex(0).localTransform.storage[12], 1);
    expect(root.localTransform.storage[0], -1);
    expect(root.localTransform.storage[10], 1);
    expect(root.localTransform.storage[12], -1);
  });

  test('converts imported handedness out of core world transforms', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root')
      ..localTransform = vm.Matrix4.diagonal3Values(1, 1, -1);
    final node = scene.Node(name: 'node0')
      ..localTransform = vm.Matrix4.translationValues(0, 0, 2);
    root.add(node);
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    expect(binding.nodeByGltfIndex(0).worldTransform.storage[14], 2.0);

    binding.modelRootMotionTransform = VrmMatrix4([
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      3,
      1,
    ]);

    expect(binding.nodeByGltfIndex(0).worldTransform.storage[14], 5.0);
  });

  test('warns when the import root transform cannot be inverted', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final root = scene.Node(name: 'root')..localTransform = vm.Matrix4.zero();

    final binding = FlutterSceneVrmBinding.fromRootNode(root, model: model);

    expect(
      binding.capabilityWarnings.map((warning) => warning.code),
      contains('flutterScene.nonInvertibleImportRoot'),
    );
  });

  test('mesh visibility leaves child nodes visible', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(firstPersonSplit: true, meshMaterial: true),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final root = scene.Node(name: 'root');
    final parent = scene.Node(
      name: 'node0',
      mesh: scene.Mesh(_StubGeometry(), _StubMaterial()),
    );
    final child = scene.Node(
      name: 'child',
      mesh: scene.Mesh(_StubGeometry(), _StubMaterial()),
    );
    parent.add(child);
    root.add(parent);
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    binding.meshByNodeIndex(0)!.setVisible(false);
    binding.commitFrame();

    expect(parent.visible, isTrue);
    expect(parent.mesh, isNull);
    expect(child.mesh, isNotNull);

    binding.meshByNodeIndex(0)!.setVisible(true);
    binding.commitFrame();

    expect(parent.mesh, isNotNull);
    expect(child.mesh, isNotNull);
  });

  test('reports MToon fallback warnings', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb(mtoonMaterial: true));
    final binding = FlutterSceneVrmBinding.fromRootNode(
      scene.Node(name: 'root'),
      model: model,
    );

    final warning = binding.capabilityWarnings.singleWhere(
      (diagnostic) => diagnostic.code == 'mtoon.fallback',
    );
    expect(warning.gltfMaterialIndex, 0);
  });

  test('reports legacy MToon fallback warnings', () {
    final model = VrmModel.parseGlb(
      _minimalVrmGlb(legacy: true, mtoonMaterial: true),
    );
    final binding = FlutterSceneVrmBinding.fromRootNode(
      scene.Node(name: 'root'),
      model: model,
    );

    final warning = binding.capabilityWarnings.singleWhere(
      (diagnostic) => diagnostic.code == 'vrm0.mtoonFallback',
    );
    expect(warning.gltfMaterialIndex, 0);
  });

  test('applies MToon PBR fallback values to Flutter Scene materials', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(
        firstPersonSplit: true,
        meshMaterial: true,
        mtoonMaterial: true,
      ),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final material = _StubMaterial();
    final root = scene.Node(name: 'root');
    root.add(
      scene.Node(name: 'node0', mesh: scene.Mesh(_StubGeometry(), material)),
    );

    FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    expect(material.baseColorFactor, vm.Vector4(0.2, 0.3, 0.4, 0.5));
    expect(material.emissiveFactor, vm.Vector4(0.6, 0.7, 0.8, 1.0));
  });

  test('applies legacy MToon fallback values to Flutter Scene materials', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(
        legacy: true,
        firstPersonSplit: true,
        meshMaterial: true,
        mtoonMaterial: true,
      ),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final material = _StubMaterial();
    final root = scene.Node(name: 'root');
    root.add(
      scene.Node(name: 'node0', mesh: scene.Mesh(_StubGeometry(), material)),
    );

    FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    expect(material.baseColorFactor, vm.Vector4(0.2, 0.3, 0.4, 0.5));
    expect(material.emissiveFactor, vm.Vector4(0.6, 0.7, 0.8, 1.0));
  });

  test('maps color binds to Flutter Scene material fallback fields', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(firstPersonSplit: true, meshMaterial: true),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final material = _StubMaterial();
    final root = scene.Node(name: 'root');
    root.add(
      scene.Node(name: 'node0', mesh: scene.Mesh(_StubGeometry(), material)),
    );
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    binding
        .materialByGltfIndex(0)
        .setColor('color', VrmVector4(0.1, 0.2, 0.3, 0.4));
    binding
        .materialByGltfIndex(0)
        .setColor('emissionColor', VrmVector4(0.5, 0.6, 0.7, 1.0));

    expect(material.baseColorFactor, vm.Vector4(0.1, 0.2, 0.3, 0.4));
    expect(material.emissiveFactor, vm.Vector4(0.5, 0.6, 0.7, 1.0));
  });

  test('aligns materials after skipped non-triangle primitives', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(
        firstPersonSplit: true,
        meshMaterial: true,
        skippedPrimitiveBeforeMaterial: true,
      ),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final material = _StubMaterial();
    final root = scene.Node(name: 'root');
    root.add(
      scene.Node(name: 'node0', mesh: scene.Mesh(_StubGeometry(), material)),
    );
    final binding = FlutterSceneVrmBinding.fromRootNode(
      root,
      model: model,
      options: FlutterSceneVrmBindingOptions(includeRootAsGltfNode: false),
    );

    binding
        .materialByGltfIndex(1)
        .setColor('color', VrmVector4(0.1, 0.2, 0.3, 0.4));

    expect(material.baseColorFactor, vm.Vector4(0.1, 0.2, 0.3, 0.4));
  });

  test('warns when a Flutter Scene material cannot be located', () {
    final model = VrmModel.tryParseGlb(
      _minimalVrmGlb(firstPersonSplit: true, meshMaterial: true),
      validation: VrmValidationMode.permissive,
    ).asset!;
    final binding = FlutterSceneVrmBinding.fromRootNode(
      scene.Node(name: 'root'),
      model: model,
    );

    binding
        .materialByGltfIndex(0)
        .setColor('color', VrmVector4(0.1, 0.2, 0.3, 0.4));

    final warning = binding.capabilityWarnings.singleWhere(
      (diagnostic) => diagnostic.code == 'flutterScene.missingMaterial',
    );
    expect(warning.gltfMaterialIndex, 0);
  });

  test('reports first-person geometry split warnings', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb(firstPersonSplit: true));
    final binding = FlutterSceneVrmBinding.fromRootNode(
      scene.Node(name: 'root'),
      model: model,
    );

    final warning = binding.capabilityWarnings.singleWhere(
      (diagnostic) => diagnostic.code == 'vrm.firstPersonGeometrySplitRequired',
    );
    expect(warning.gltfNodeIndex, 0);
  });

  test(
    'loads a VRM GLB into Flutter Scene and core from the same bytes',
    () async {
      final asset = await FlutterSceneVrmAsset.fromGlbBytes(_minimalVrmGlb());

      expect(asset.model.vrm.meta.name, 'Avatar');
      for (var i = 0; i < asset.model.gltf.nodes.length; i++) {
        expect(asset.binding.nodeByGltfIndex(i).debugName, 'node$i');
      }
      expect(asset.rootNode.children, isNotEmpty);
    },
  );

  test('loads a VRM 0.x GLB through the Flutter Scene importer', () async {
    final asset = await FlutterSceneVrmAsset.fromGlbBytes(
      _minimalVrmGlb(legacy: true),
    );
    final runtime = VrmRuntime(asset.model)..bind(asset.binding);

    runtime.update(0);

    expect(asset.model.sourceVersion, VrmSourceVersion.vrm0);
    expect(asset.model.vrm0, isNotNull);
    for (var i = 0; i < asset.model.gltf.nodes.length; i++) {
      expect(asset.binding.nodeByGltfIndex(i).debugName, 'node$i');
    }
    expect(asset.binding.modelRootMotionTransform.storage[0], -1);
    expect(asset.binding.modelRootMotionTransform.storage[10], -1);
    expect(asset.rootNode.children, isNotEmpty);
  });
}

Uint8List _minimalVrmGlb({
  bool mtoonMaterial = false,
  bool firstPersonSplit = false,
  bool meshMaterial = false,
  bool skippedPrimitiveBeforeMaterial = false,
  bool legacy = false,
}) {
  final nodeChildren = legacy ? _legacyNodeChildren : _nodeChildren;
  final binaryChunk = firstPersonSplit ? _firstPersonSplitBinary() : null;
  final jsonBytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'asset': {'version': '2.0'},
        'extensionsUsed': [
          legacy ? 'VRM' : 'VRMC_vrm',
          if (mtoonMaterial && !legacy) ...[
            'VRMC_materials_mtoon',
            'KHR_materials_unlit',
          ],
        ],
        'extensionsRequired': [legacy ? 'VRM' : 'VRMC_vrm'],
        'scene': 0,
        'scenes': [
          {
            'nodes': [0],
          },
        ],
        'nodes': [
          for (var i = 0; i < nodeChildren.length; i++)
            {
              'name': 'node$i',
              if (legacy && i == 0) 'translation': [1.0, 0.0, 0.0],
              if (firstPersonSplit && (i == 0 || i == 3)) ...{
                'mesh': i == 0 ? 0 : 1,
                'skin': 0,
              },
              if (nodeChildren[i].isNotEmpty) 'children': nodeChildren[i],
            },
        ],
        if (firstPersonSplit)
          ..._firstPersonSplitGltfData(
            binaryChunk!,
            material: meshMaterial ? 0 : null,
            skippedPrimitiveBeforeMaterial: skippedPrimitiveBeforeMaterial,
          ),
        if (mtoonMaterial || meshMaterial)
          'materials': [
            {
              if (mtoonMaterial)
                'pbrMetallicRoughness': {
                  'baseColorFactor': [0.2, 0.3, 0.4, 0.5],
                },
              if (mtoonMaterial) 'emissiveFactor': [0.6, 0.7, 0.8],
              if (mtoonMaterial && !legacy)
                'extensions': {
                  'VRMC_materials_mtoon': {'specVersion': '1.0'},
                  'KHR_materials_unlit': {},
                },
            },
            if (skippedPrimitiveBeforeMaterial) {},
          ],
        'extensions': {
          if (legacy)
            'VRM': {
              'specVersion': '0.0',
              'meta': {'title': 'Legacy Avatar', 'author': 'Author'},
              'humanoid': {
                'humanBones': [
                  for (final entry in _boneNodes.entries)
                    {'bone': entry.key, 'node': entry.value},
                  {'bone': 'chest', 'node': 15},
                  {'bone': 'neck', 'node': 16},
                ],
              },
              'firstPerson': <String, Object?>{},
              'blendShapeMaster': {'blendShapeGroups': <Object?>[]},
              'secondaryAnimation': {
                'boneGroups': <Object?>[],
                'colliderGroups': <Object?>[],
              },
              'materialProperties': mtoonMaterial
                  ? [
                      {
                        'name': 'Face',
                        'shader': 'VRM/MToon',
                        'floatProperties': <String, Object?>{},
                        'vectorProperties': <String, Object?>{},
                        'textureProperties': <String, Object?>{},
                        'keywordMap': <String, Object?>{},
                        'tagMap': <String, Object?>{},
                      },
                    ]
                  : <Object?>[],
            }
          else
            'VRMC_vrm': {
              'specVersion': '1.0',
              'meta': {
                'name': 'Avatar',
                'authors': ['Author'],
                'licenseUrl': 'https://example.com/license',
              },
              'humanoid': {
                'humanBones': {
                  for (final entry in _boneNodes.entries)
                    entry.key: {'node': entry.value},
                },
              },
            },
        },
      }),
    ),
  );
  final jsonLength = (jsonBytes.length + 3) & ~3;
  final binLength = binaryChunk == null ? 0 : (binaryChunk.length + 3) & ~3;
  final bytes = Uint8List(
    20 + jsonLength + (binaryChunk == null ? 0 : 8 + binLength),
  );
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, bytes.length, Endian.little);
  data.setUint32(12, jsonLength, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
  for (var i = 20 + jsonBytes.length; i < bytes.length; i++) {
    bytes[i] = 0x20;
  }
  if (binaryChunk != null) {
    final binHeader = 20 + jsonLength;
    data.setUint32(binHeader, binLength, Endian.little);
    data.setUint32(binHeader + 4, 0x004e4942, Endian.little);
    bytes.setRange(
      binHeader + 8,
      binHeader + 8 + binaryChunk.length,
      binaryChunk,
    );
    for (
      var i = binHeader + 8 + binaryChunk.length;
      i < binHeader + 8 + binLength;
      i++
    ) {
      bytes[i] = 0;
    }
  }
  return bytes;
}

final class _StubGeometry extends scene.Geometry {
  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    vm.Matrix4 modelTransform,
    vm.Matrix4 cameraTransform,
    vm.Vector3 cameraPosition,
  ) {
    throw UnsupportedError('Stub geometry is not renderable');
  }
}

final class _StubMaterial extends scene.Material {
  var baseColorFactor = vm.Vector4.zero();
  var emissiveFactor = vm.Vector4.zero();

  @override
  void bind(
    gpu.RenderPass pass,
    gpu.HostBuffer transientsBuffer,
    scene.Lighting lighting,
  ) {
    throw UnsupportedError('Stub material is not renderable');
  }
}

Map<String, Object?> _firstPersonSplitGltfData(
  Uint8List binary, {
  int? material,
  bool skippedPrimitiveBeforeMaterial = false,
}) => {
  'meshes': [
    {
      'primitives': [
        {
          'mode': skippedPrimitiveBeforeMaterial ? 1 : 0,
          ..._materialEntry(material),
          'attributes': {'JOINTS_0': 0, 'WEIGHTS_0': 1},
        },
        {
          'mode': skippedPrimitiveBeforeMaterial ? 4 : 0,
          if (skippedPrimitiveBeforeMaterial) 'material': 1,
          'attributes': {'JOINTS_0': 2, 'WEIGHTS_0': 3},
        },
      ],
    },
    {
      'primitives': [
        {
          'mode': 0,
          'attributes': {'JOINTS_0': 2, 'WEIGHTS_0': 3},
        },
      ],
    },
  ],
  'buffers': [
    {'byteLength': binary.length},
  ],
  'bufferViews': [
    {'buffer': 0, 'byteOffset': 0, 'byteLength': 4},
    {'buffer': 0, 'byteOffset': 4, 'byteLength': 16},
    {'buffer': 0, 'byteOffset': 20, 'byteLength': 4},
    {'buffer': 0, 'byteOffset': 24, 'byteLength': 16},
  ],
  'accessors': [
    {'bufferView': 0, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
    {'bufferView': 1, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
    {'bufferView': 2, 'componentType': 5121, 'count': 1, 'type': 'VEC4'},
    {'bufferView': 3, 'componentType': 5126, 'count': 1, 'type': 'VEC4'},
  ],
  'skins': [
    {
      'joints': [2, 3],
    },
  ],
};

Map<String, Object?> _materialEntry(int? material) =>
    material == null ? const {} : {'material': material};

Uint8List _firstPersonSplitBinary() {
  final binary = Uint8List(40);
  final data = ByteData.sublistView(binary);
  binary[0] = 0;
  data.setFloat32(4, 1.0, Endian.little);
  binary[20] = 1;
  data.setFloat32(24, 1.0, Endian.little);
  return binary;
}

const _nodeChildren = <List<int>>[
  [1, 3, 6],
  [2, 9, 12],
  [],
  [4],
  [5],
  [],
  [7],
  [8],
  [],
  [10],
  [11],
  [],
  [13],
  [14],
  [],
];

const _legacyNodeChildren = <List<int>>[
  [1, 3, 6],
  [15],
  [],
  [4],
  [5],
  [],
  [7],
  [8],
  [],
  [10],
  [11],
  [],
  [13],
  [14],
  [],
  [16, 9, 12],
  [2],
];

const _boneNodes = <String, int>{
  'hips': 0,
  'spine': 1,
  'head': 2,
  'leftUpperLeg': 3,
  'leftLowerLeg': 4,
  'leftFoot': 5,
  'rightUpperLeg': 6,
  'rightLowerLeg': 7,
  'rightFoot': 8,
  'leftUpperArm': 9,
  'leftLowerArm': 10,
  'leftHand': 11,
  'rightUpperArm': 12,
  'rightLowerArm': 13,
  'rightHand': 14,
};
