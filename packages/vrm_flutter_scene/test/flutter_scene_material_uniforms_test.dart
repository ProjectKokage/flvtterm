import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gpu_shaders/environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/src/flutter_scene_material_corrections.dart';
import 'package:vector_math/vector_math.dart' as vm;

Uri _packageRoot(String name) {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
  final package = packages.cast<Map>().singleWhere(
    (entry) => entry['name'] == name,
  );
  return Directory.fromUri(
    config.absolute.uri.resolve(package['rootUri'] as String),
  ).uri;
}

void main() {
  for (final backend in ['opengl-es', 'metal-desktop', 'vulkan']) {
    test(
      'unlit uniforms match $backend reflection and retain every value',
      () async {
        final temp = Directory.systemTemp.createTempSync('vrm_unlit_uniforms_');
        try {
          final impellerc = await findImpellerC();
          final reflection = File.fromUri(temp.uri.resolve('reflection.json'));
          final result = await Process.run(impellerc.toFilePath(), [
            '--$backend',
            '--input-type=frag',
            '--input=${_packageRoot('flvtterm_flutter_scene').resolve('shaders/vrm_unlit.frag').toFilePath()}',
            '--sl=${temp.uri.resolve('unlit.sl').toFilePath()}',
            '--spirv=${temp.uri.resolve('unlit.spirv').toFilePath()}',
            '--reflection-json=${reflection.path}',
            '--include=${_packageRoot('flutter_scene').resolve('shaders/').toFilePath()}',
            '--include=${impellerc.resolve('./shader_lib').toFilePath()}',
            if (backend == 'opengl-es') '--gles-language-version=300',
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
          final reflected = jsonDecode(reflection.readAsStringSync()) as Map;
          final blocks = (reflected['struct_definitions'] as List).cast<Map>();
          final material = blocks.singleWhere(
            (block) => block['name'] == 'MaterialInfo',
          );
          final texture = blocks.singleWhere(
            (block) => block['name'] == 'TextureInfo',
          );
          expect(material['byte_length'], 48);
          expect(texture['byte_length'], 32);
          final offsets = <String, int>{
            for (final member in (material['members'] as List).cast<Map>())
              member['name'] as String: member['offset'] as int,
          };
          expect(offsets, {
            'color': 0,
            'vertex_color_weight': 16,
            'alpha_mode': 20,
            'alpha_cutoff': 24,
            'fade': 28,
            'texture_coord': 32,
            '_PADDING_': 36,
          });
          for (final mode in GltfAlphaMode.values) {
            final bytes = packFlutterSceneUnlitMaterialInfo(
              baseColorFactor: vm.Vector4(0.125, 0.25, 0.5, 0.75),
              vertexColorWeight: 0.5,
              alphaMode: mode,
              alphaCutoff: 0.25,
              lodFade: -0.5,
              textureCoord: 1,
            );
            expect(bytes.lengthInBytes, material['byte_length']);
            expect(
              [
                for (var component = 0; component < 4; component++)
                  bytes.getFloat32(
                    offsets['color']! + component * 4,
                    Endian.host,
                  ),
              ],
              [0.125, 0.25, 0.5, 0.75],
            );
            final expected = {
              'vertex_color_weight': 0.5,
              'alpha_mode': mode.index.toDouble(),
              'alpha_cutoff': 0.25,
              'fade': -0.5,
              'texture_coord': 1.0,
            };
            for (final entry in expected.entries) {
              expect(
                bytes.getFloat32(offsets[entry.key]!, Endian.host),
                entry.value,
                reason: '${entry.key} retains its reflected offset and value',
              );
            }
            expect(
              bytes.buffer.asUint8List(
                bytes.offsetInBytes + offsets['_PADDING_']!,
                12,
              ),
              everyElement(0),
            );
          }
        } finally {
          temp.deleteSync(recursive: true);
        }
      },
    );
  }
}
