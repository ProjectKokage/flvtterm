import 'package:flutter/foundation.dart';
import 'package:flvtterm/flvtterm.dart';

/// Widget-ownable controller for a renderer-neutral [VrmRuntime].
final class VrmRuntimeController extends ChangeNotifier {
  /// Creates a controller for [model].
  VrmRuntimeController(VrmModel model) : runtime = VrmRuntime(model);

  /// Runtime owned by this controller.
  final VrmRuntime runtime;

  VrmSceneBinding? _binding;

  /// Parsed model backing [runtime].
  VrmModel get model => runtime.model;

  /// Whether a renderer binding has been attached.
  bool get isBound => _binding != null;

  /// Runs a runtime mutation and notifies listeners once.
  void mutate(void Function(VrmRuntime runtime) change) {
    change(runtime);
    notifyListeners();
  }

  /// Binds the runtime to a renderer-neutral scene binding.
  void bind(VrmSceneBinding binding) {
    _binding = binding;
    runtime.bind(binding);
    notifyListeners();
  }

  /// Detaches the renderer binding from the runtime.
  void unbind() {
    _binding = null;
    runtime.unbind();
    notifyListeners();
  }

  /// Applies one runtime frame and notifies listeners.
  void update(double deltaSeconds) {
    runtime.update(deltaSeconds);
    notifyListeners();
  }

  @override
  void dispose() {
    _binding = null;
    runtime.unbind();
    super.dispose();
  }
}
