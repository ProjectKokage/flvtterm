import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' as scene;

/// Compact labeled slider used by the viewer control surface.
final class ViewerControl extends StatelessWidget {
  /// Creates a viewer slider.
  const ViewerControl({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Short control label.
  final String label;

  /// Current slider value in `[0, 1]`.
  final double value;

  /// Called when the slider changes.
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Paints a Flutter Scene into the current Flutter canvas.
final class VrmScenePainter extends CustomPainter {
  /// Creates a scene painter.
  const VrmScenePainter(this.sceneRoot, this.camera, {required this.ready});

  /// Scene to render.
  final scene.Scene sceneRoot;

  /// Active scene camera.
  final scene.Camera camera;

  /// Whether scene resources are ready to render.
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    if (!ready || size.isEmpty) return;
    sceneRoot.render(camera, canvas, viewport: Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant VrmScenePainter oldDelegate) => true;
}
