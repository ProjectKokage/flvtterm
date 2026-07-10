import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flvtterm/flvtterm.dart';

void main(List<String> arguments) {
  if (arguments.length > 1) {
    stderr.writeln('usage: dart run bin/runtime_console.dart [avatar.vrm]');
    exitCode = 64;
    return;
  }

  final model = _loadModel(arguments);
  if (model == null) {
    exitCode = 1;
    return;
  }
  final binding = _ConsoleBinding(model);
  final runtime = VrmRuntime(model)..bind(binding);

  runtime.emotion.set(VrmEmotion.happy, 0.5);
  for (var frame = 0; frame < 2; frame++) {
    runtime.update(1 / 60);
  }

  print(
    'Parsed ${model.gltf.nodes.length} nodes; '
    '${binding.committedFrames} frames committed.',
  );
}

VrmModel? _loadModel(List<String> arguments) {
  if (arguments.isEmpty) return VrmModel.parseGlb(_minimalVrmGlb());
  final result = VrmModel.tryParseGlb(
    File(arguments.single).readAsBytesSync(),
    validation: VrmValidationMode.permissive,
  );
  for (final diagnostic in result.validation.diagnostics) {
    stderr.writeln(diagnostic);
  }
  return result.asset;
}

Uint8List _minimalVrmGlb() {
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
          for (var i = 0; i < 15; i++)
            {
              'name': 'node$i',
              if (i < 14) 'children': [i + 1],
            },
        ],
        'extensions': {
          'VRMC_vrm': {
            'specVersion': '1.0',
            'meta': {
              'name': 'Runtime Console Avatar',
              'authors': ['flvtterm'],
              'licenseUrl': 'https://example.com/license',
            },
            'humanoid': {
              'humanBones': {
                'hips': {'node': 0},
                'spine': {'node': 1},
                'head': {'node': 2},
                'leftUpperLeg': {'node': 3},
                'leftLowerLeg': {'node': 4},
                'leftFoot': {'node': 5},
                'rightUpperLeg': {'node': 6},
                'rightLowerLeg': {'node': 7},
                'rightFoot': {'node': 8},
                'leftUpperArm': {'node': 9},
                'leftLowerArm': {'node': 10},
                'leftHand': {'node': 11},
                'rightUpperArm': {'node': 12},
                'rightLowerArm': {'node': 13},
                'rightHand': {'node': 14},
              },
            },
          },
        },
      }),
    ),
  );
  final paddedJsonLength = (jsonBytes.length + 3) & ~3;
  final totalLength = 20 + paddedJsonLength;
  final bytes = Uint8List(totalLength);
  final data = ByteData.sublistView(bytes);
  data.setUint32(0, 0x46546c67, Endian.little);
  data.setUint32(4, 2, Endian.little);
  data.setUint32(8, totalLength, Endian.little);
  data.setUint32(12, paddedJsonLength, Endian.little);
  data.setUint32(16, 0x4e4f534a, Endian.little);
  bytes.setRange(20, 20 + jsonBytes.length, jsonBytes);
  for (var i = 20 + jsonBytes.length; i < totalLength; i++) {
    bytes[i] = 0x20;
  }
  return bytes;
}

final class _ConsoleBinding implements VrmSceneBinding {
  _ConsoleBinding(VrmModel model) {
    for (final node in model.gltf.nodes) {
      _nodes[node.index] = _ConsoleNode(node.name, node.restTransform);
      if (node.mesh != null) _meshes[node.index] = _ConsoleMesh();
    }
    for (final material in model.gltf.materials) {
      _materials[material.index] = _ConsoleMaterial();
    }
  }

  final _nodes = <int, _ConsoleNode>{};
  final _meshes = <int, _ConsoleMesh>{};
  final _materials = <int, _ConsoleMaterial>{};
  var committedFrames = 0;

  @override
  void beginFrame() {}

  @override
  void commitFrame() {
    committedFrames++;
  }

  @override
  VrmMaterialBinding materialByGltfIndex(int materialIndex) =>
      _materials.putIfAbsent(materialIndex, _ConsoleMaterial.new);

  @override
  VrmMeshBinding? meshByNodeIndex(int nodeIndex) => _meshes[nodeIndex];

  @override
  VrmNodeBinding nodeByGltfIndex(int nodeIndex) => _nodes.putIfAbsent(
    nodeIndex,
    () => _ConsoleNode(null, VrmMatrix4.identity()),
  );
}

final class _ConsoleNode implements VrmNodeBinding {
  _ConsoleNode(this.debugName, this.localTransform);

  @override
  final String? debugName;

  @override
  VrmMatrix4 localTransform;

  @override
  VrmMatrix4 get worldTransform => localTransform;
}

final class _ConsoleMesh implements VrmMeshBinding {
  @override
  void setMorphWeight({
    required int primitiveIndex,
    required int morphIndex,
    required double weight,
  }) {}

  @override
  void setVisible(bool visible) {}
}

final class _ConsoleMaterial implements VrmMaterialBinding {
  @override
  void setColor(String parameter, VrmVector4 value) {}

  @override
  void setTextureTransform({
    required VrmVector2 scale,
    required VrmVector2 offset,
  }) {}
}
