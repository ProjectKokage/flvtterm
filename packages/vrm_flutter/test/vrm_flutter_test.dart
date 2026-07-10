import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Endian;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm_flutter/vrm_flutter.dart';

void main() {
  test('vrm_flutter stays renderer-neutral', () {
    const bannedImports = [
      'dart:ui',
      'package:flutter_scene/',
      'package:flutter_gpu/',
    ];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            file
                .readAsLinesSync()
                .where((line) => line.trimLeft().startsWith('import '))
                .any((line) => bannedImports.any(line.contains)))
          file.path,
    ];

    expect(offenders, isEmpty);
  });

  test('VrmAssetLoader loads bytes without leaking ByteData padding', () async {
    final bundle = _FakeBundle(Uint8List.fromList([1, 2, 3]));
    final loader = VrmAssetLoader(bundle);

    final bytes = await loader.loadBytes('avatar.vrm');

    expect(bytes, [1, 2, 3]);
    expect(bundle.lastKey, 'avatar.vrm');
  });

  test(
    'VrmAssetLoader returns parse diagnostics for invalid VRM bytes',
    () async {
      final loader = VrmAssetLoader(_FakeBundle(Uint8List.fromList([1, 2, 3])));

      final result = await loader.tryLoadModel(
        'broken.vrm',
        validation: VrmValidationMode.permissive,
      );

      expect(result.asset, isNull);
      expect(
        result.validation.errors.map((d) => d.code),
        contains('glb.tooShort'),
      );
    },
  );

  test('VrmAssetLoader passes VRM external image resolver through', () async {
    final loader = VrmAssetLoader(_FakeBundle(_minimalVrmGlb(imageUri: true)));
    final pngBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    var requestedUri = '';

    final result = await loader.tryLoadModel(
      'avatar.vrm',
      uriResolver: (uri) {
        requestedUri = uri;
        return pngBytes;
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'texture.png');
    expect(result.asset!.gltf.images.single.data, pngBytes);
  });

  test('VrmAssetLoader loads generic glTF assets', () async {
    final loader = VrmAssetLoader(_FakeBundle(_minimalGltfJson()));
    var requestedUri = '';

    final result = await loader.tryLoadGltf(
      'motion.gltf',
      uriResolver: (uri) {
        requestedUri = uri;
        return Uint8List.fromList([1, 2, 3, 4]);
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'motion.bin');
    expect(result.asset!.buffers.single.data, [1, 2, 3, 4]);
  });

  test('VrmAssetLoader passes VRMA external buffer resolver through', () async {
    final loader = VrmAssetLoader(_FakeBundle(_minimalVrmaJson()));
    var requestedUri = '';

    final result = await loader.tryLoadAnimation(
      'wave.vrma',
      uriResolver: (uri) {
        requestedUri = uri;
        return Uint8List.fromList([7]);
      },
    );

    expect(result.validation.hasErrors, isFalse);
    expect(requestedUri, 'motion.bin');
    expect(result.asset!.gltf.buffers.single.data, [7]);
  });

  test('VrmRuntimeController binds and ticks the core runtime', () {
    final model = VrmModel.parseGlb(_minimalVrmGlb());
    final controller = VrmRuntimeController(model);
    final binding = _FakeBinding();
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(controller.model, same(model));
    expect(controller.isBound, isFalse);

    controller.bind(binding);
    controller.update(1 / 60);
    controller.unbind();
    controller.update(1 / 60);

    expect(controller.isBound, isFalse);
    expect(notifications, 4);
    expect(binding.began, 1);
    expect(binding.committed, 1);
    expect(binding.nodes.length, _nodeChildren.length);
  });

  test('VrmRuntimeController notifies for runtime mutations', () {
    final controller = VrmRuntimeController(
      VrmModel.parseGlb(_minimalVrmGlb()),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.mutate((runtime) {
      runtime.emotion.set(VrmEmotion.happy, 0.75);
    });

    expect(notifications, 1);
    expect(
      controller.runtime.expressions
          .evaluate()[VrmExpressionPreset.happy.specName],
      0.75,
    );
  });

  test('VrmRuntimeController detaches runtime when disposed', () {
    final controller = VrmRuntimeController(
      VrmModel.parseGlb(_minimalVrmGlb()),
    );
    final binding = _FakeBinding();

    controller.bind(binding);
    controller.dispose();
    controller.runtime.update(1 / 60);

    expect(controller.isBound, isFalse);
    expect(binding.began, 0);
    expect(binding.committed, 0);
  });
}

final class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.bytes);

  final Uint8List bytes;
  String? lastKey;

  @override
  Future<ByteData> load(String key) async {
    lastKey = key;
    final padded = Uint8List.fromList([0, ...bytes, 0]);
    return ByteData.sublistView(padded, 1, padded.length - 1);
  }
}

Uint8List _minimalGltfJson() {
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': 4, 'uri': 'motion.bin'},
        ],
      }),
    ),
  );
}

Uint8List _minimalVrmaJson() {
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'buffers': [
          {'byteLength': 1, 'uri': 'motion.bin'},
        ],
        'extensions': {
          'VRMC_vrm_animation': {'specVersion': '1.0'},
        },
      }),
    ),
  );
}

Uint8List _minimalVrmGlb({bool imageUri = false}) {
  final jsonBytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm'],
        'extensionsRequired': ['VRMC_vrm'],
        'scene': 0,
        'scenes': [
          {
            'nodes': [0],
          },
        ],
        'nodes': [
          for (var i = 0; i < _nodeChildren.length; i++)
            {
              'name': 'node$i',
              if (_nodeChildren[i].isNotEmpty) 'children': _nodeChildren[i],
            },
        ],
        'extensions': {
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
            'expressions': {
              'preset': {'happy': <String, Object?>{}},
            },
          },
        },
        if (imageUri)
          'images': [
            {'uri': 'texture.png', 'mimeType': 'image/png'},
          ],
      }),
    ),
  );
  final jsonLength = (jsonBytes.length + 3) & ~3;
  final bytes = Uint8List(20 + jsonLength);
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
  return bytes;
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

final class _FakeBinding implements VrmSceneBinding {
  final nodes = <int, _FakeNode>{};
  var began = 0;
  var committed = 0;

  @override
  void beginFrame() {
    began++;
  }

  @override
  void commitFrame() {
    committed++;
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) => _FakeMaterial();

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => null;

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) =>
      nodes.putIfAbsent(nodeIndex, _FakeNode.new);
}

final class _FakeNode implements VrmNodeBinding {
  @override
  String? debugName;

  @override
  VrmMatrix4 localTransform = VrmMatrix4.identity();

  @override
  VrmMatrix4 worldTransform = VrmMatrix4.identity();
}

final class _FakeMaterial implements VrmMaterialBinding {
  @override
  void setColor(String parameter, VrmVector4 value) {}

  @override
  void setTextureTransform({
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {}
}
