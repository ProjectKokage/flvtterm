import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:flvtterm/flvtterm.dart';
import 'package:flvtterm_flutter_scene/vrm_flutter_scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'viewer_widgets.dart';

const _assetPath = String.fromEnvironment(
  'VRM_ASSET',
  defaultValue: 'assets/avatar.vrm',
);

/// Interactive Flutter Scene viewer for the configured VRM asset.
final class ViewerScreen extends StatefulWidget {
  /// Creates the viewer screen.
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

final class _ViewerScreenState extends State<ViewerScreen>
    with SingleTickerProviderStateMixin {
  final scene.Scene _scene = scene.Scene();
  final scene.PerspectiveCamera _camera = scene.PerspectiveCamera(
    position: vm.Vector3(0, 1.4, -4),
    target: vm.Vector3(0, 1.1, 0),
  );

  late final Ticker _ticker;
  VrmRuntime? _runtime;
  FlutterSceneVrmAsset? _asset;
  Duration? _lastTick;
  Object? _loadError;
  var _happy = 0.0;
  var _visemeAa = 0.0;
  var _blink = 0.0;
  var _lookX = 0.0;
  var _lookY = 1.2;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await scene.Scene.initializeStaticResources();
      final asset = await FlutterSceneVrmAsset.fromGlbAsset(
        _assetPath,
        validation: VrmValidationMode.permissive,
      );
      final runtime = VrmRuntime(asset.model)..bind(asset.binding);
      _scene.add(asset.rootNode);
      if (!mounted) return;
      setState(() {
        _asset = asset;
        _runtime = runtime;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    final runtime = _runtime;
    if (last == null || runtime == null) return;
    final delta =
        (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    runtime.update(delta);
    if (mounted) setState(() {});
  }

  void _setHappy(double value) {
    setState(() {
      _happy = value;
      _runtime?.emotion.set(VrmEmotion.happy, value);
    });
  }

  void _setVisemeAa(double value) {
    setState(() {
      _visemeAa = value;
      _runtime?.lipSync.setViseme(VrmViseme.aa, value);
    });
  }

  void _setBlink(double value) {
    setState(() {
      _blink = value;
      _runtime?.blink.setBoth(value);
    });
  }

  void _setLookX(double value) {
    setState(() {
      _lookX = value;
      _applyLookAt();
    });
  }

  void _setLookY(double value) {
    setState(() {
      _lookY = value;
      _applyLookAt();
    });
  }

  void _applyLookAt() {
    _runtime?.lookAt.lookAtModel(VrmVector3(_lookX, _lookY, 2));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _runtime?.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warnings =
        _asset?.binding.capabilityWarnings ?? const <VrmDiagnostic>[];
    return Scaffold(
      backgroundColor: const Color(0xff161718),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: VrmScenePainter(_scene, _camera, ready: _asset != null),
            ),
          ),
          if (_asset == null)
            Center(
              child: Text(
                _loadError == null
                    ? 'Loading $_assetPath'
                    : 'Could not load $_assetPath',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if (warnings.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ColoredBox(
                    color: const Color(0xdd2a241c),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Adapter warnings',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          for (final warning in warnings.take(3))
                            Text(
                              warning.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: const Color(0xcc202224),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      ViewerControl(
                        label: 'Happy',
                        value: _happy,
                        onChanged: _setHappy,
                      ),
                      ViewerControl(
                        label: 'AA',
                        value: _visemeAa,
                        onChanged: _setVisemeAa,
                      ),
                      ViewerControl(
                        label: 'Blink',
                        value: _blink,
                        onChanged: _setBlink,
                      ),
                      ViewerControl(
                        label: 'Look X',
                        value: (_lookX + 1) / 2,
                        onChanged: (value) => _setLookX(value * 2 - 1),
                      ),
                      ViewerControl(
                        label: 'Look Y',
                        value: _lookY / 2,
                        onChanged: (value) => _setLookY(value * 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
