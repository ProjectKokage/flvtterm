part of '../flvtterm_test.dart';

void cliTests() {
  test('CLI help exits successfully', () async {
    final result = await _runCli(['--help']);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('usage: dart run flvtterm'));
    expect(result.stderr, isEmpty);
  });

  test('CLI validates glTF with a relative external buffer', () async {
    final result = await _runCli([
      'example/runtime_console/minimal_external.gltf',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('glTF: 0 errors, 0 warnings'));
  });

  test('CLI rejects external buffer traversal', () async {
    final directory = await _temporaryDirectory();
    final assetDirectory = Directory('${directory.path}/asset')..createSync();
    File('${directory.path}/outside.bin').writeAsBytesSync([1, 2, 3, 4]);
    final file = File('${assetDirectory.path}/model.gltf');
    await file.writeAsString(
      jsonEncode({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': 4, 'uri': '../outside.bin'},
        ],
      }),
    );

    final result = await _runCli([file.path]);

    expect(result.exitCode, 1);
    expect(result.stdout, contains('gltf.unresolvedExternalBufferUri'));
  });

  test('CLI rejects external buffer symlink escape', () async {
    final directory = await _temporaryDirectory();
    final assetDirectory = Directory('${directory.path}/asset')..createSync();
    final outside = File('${directory.path}/outside.bin')
      ..writeAsBytesSync([1, 2, 3, 4]);
    try {
      Link('${assetDirectory.path}/linked.bin').createSync(outside.path);
    } on FileSystemException {
      markTestSkipped('Symbolic links are unavailable in this environment.');
      return;
    }
    final file = File('${assetDirectory.path}/model.gltf');
    await file.writeAsString(
      jsonEncode({
        'asset': {'version': '2.0'},
        'buffers': [
          {'byteLength': 4, 'uri': 'linked.bin'},
        ],
      }),
    );

    final result = await _runCli([file.path]);

    expect(result.exitCode, 1);
    expect(result.stdout, contains('gltf.unresolvedExternalBufferUri'));
  });

  test('CLI validates VRMA files by extension', () async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/idle.vrma');
    await file.writeAsString(
      jsonEncode({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'extensions': {
          'VRMC_vrm_animation': {'specVersion': '1.0'},
        },
      }),
    );

    final result = await _runCli([file.path]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VRMA: 0 errors, 0 warnings'));
  });

  test('CLI detects VRMA JSON glTF by root extension', () async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/idle.gltf');
    await file.writeAsString(
      jsonEncode({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'extensions': {
          'VRMC_vrm_animation': {'specVersion': '1.0'},
        },
      }),
    );

    final result = await _runCli([file.path]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VRMA: 0 errors, 0 warnings'));
  });

  test('CLI detects VRMA GLB by root extension', () async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/idle.glb');
    await file.writeAsBytes(
      _glb({
        'asset': {'version': '2.0'},
        'extensionsUsed': ['VRMC_vrm_animation'],
        'extensions': {
          'VRMC_vrm_animation': {'specVersion': '1.0'},
        },
      }),
    );

    final result = await _runCli([file.path]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VRMA: 0 errors, 0 warnings'));
  });

  test('CLI detects VRM GLB by root extension', () async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/avatar.glb');
    await file.writeAsBytes(_glb(_minimalVrmJson()));

    final result = await _runCli([file.path]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VRM: 0 errors, 0 warnings'));
  });

  test('CLI detects legacy VRM 0.x GLB by root extension', () async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/legacy-avatar.glb');
    await file.writeAsBytes(_glb(_minimalVrm0Json()));

    final result = await _runCli([file.path]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('VRM: 0 errors, 0 warnings'));
  });
}

Future<ProcessResult> _runCli(List<String> arguments) {
  return Process.run(Platform.resolvedExecutable, [
    'bin/flvtterm.dart',
    ...arguments,
  ]);
}

Future<Directory> _temporaryDirectory() async {
  final directory = await Directory.systemTemp.createTemp('flvtterm_cli_');
  addTearDown(() => directory.delete(recursive: true));
  return directory;
}
