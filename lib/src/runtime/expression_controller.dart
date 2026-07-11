part of '../../flvtterm.dart';

const _lipSyncPresetNames = {'aa', 'ih', 'ou', 'ee', 'oh'};

/// Controls VRM expression input and application.
final class VrmExpressionController {
  /// Creates an expression controller for [model].
  VrmExpressionController(this.model);

  /// Parsed model backing this controller.
  final VrmModel model;

  final Map<String, double> _inputs = {};
  final Map<String, double> _motionInputs = {};
  final Map<String, double> _lookAtInputs = {};

  /// Sets a preset expression input weight.
  void setPreset(VrmExpressionPreset preset, double weight) {
    _inputs[preset.specName] = _clamp01(weight);
  }

  /// Sets a lip-sync expression input weight.
  void setLipSync(VrmLipSyncPreset preset, double weight) {
    final expression = VrmExpressionPreset.fromSpecName(preset.specName);
    if (expression != null) setPreset(expression, weight);
  }

  /// Sets a custom expression input weight.
  void setCustom(String name, double weight) {
    _inputs[_runtimeExpressionName(name)] = _clamp01(weight);
  }

  /// Clears application-set expression inputs.
  void clear() {
    _inputs.clear();
  }

  void _setLookAtInputs(Map<String, double> values) {
    _lookAtInputs
      ..clear()
      ..addAll(values.map((key, value) => MapEntry(key, _clamp01(value))));
  }

  void _setMotionInputs(Map<String, double> values) {
    _motionInputs.clear();
    for (final entry in values.entries) {
      final key = _runtimeExpressionName(entry.key);
      _motionInputs[key] = _clamp01((_motionInputs[key] ?? 0) + entry.value);
    }
  }

  String _runtimeExpressionName(String name) {
    if (model.sourceVersion != VrmSourceVersion.vrm0) return name;
    if (model.vrm.expressions.all.containsKey(name)) return name;
    final normalized = name.toUpperCase();
    for (final customName in model.vrm.expressions.custom.keys) {
      if (customName.toUpperCase() == normalized) return customName;
    }
    return name;
  }

  /// Evaluates clamping, binary output, and procedural override rules.
  Map<String, double> evaluate() {
    final definitions = model.vrm.expressions.all;
    final output = <String, double>{};

    for (final entry in definitions.entries) {
      final input = _clamp01(
        (_inputs[entry.key] ?? 0) +
            (_motionInputs[entry.key] ?? 0) +
            (_lookAtInputs[entry.key] ?? 0),
      );
      output[entry.key] = entry.value.isBinary ? (input > 0.5 ? 1 : 0) : input;
    }

    _applyOverrideGroup(
      definitions,
      output,
      VrmExpressionPreset.values
          .where((p) => _lipSyncPresetNames.contains(p.specName))
          .map((p) => p.specName),
      (expression) => expression.overrideMouth,
    );
    _applyOverrideGroup(definitions, output, const [
      'blink',
      'blinkLeft',
      'blinkRight',
    ], (expression) => expression.overrideBlink);
    _applyOverrideGroup(definitions, output, const [
      'lookUp',
      'lookDown',
      'lookLeft',
      'lookRight',
    ], (expression) => expression.overrideLookAt);

    return output;
  }

  /// Applies evaluated expression binds to [binding].
  void applyTo(VrmSceneBinding binding) {
    final weights = evaluate();
    final definitions = model.vrm.expressions.all;

    // ponytail: per-frame maps are fine until profiling says expressions are hot.
    final morphs = <_MorphKey, double>{};
    final colorBases = <int, Map<String, VrmVector4>>{};
    final colors = <_MaterialColorKey, VrmVector4>{};
    final textureTransforms = <int, _TextureTransformAccum>{};

    for (final expression in definitions.values) {
      for (final bind in expression.morphTargetBinds) {
        final meshIndex = model.gltf.nodes.elementAtOrNull(bind.node)?.mesh;
        if (meshIndex == null) continue;
        final mesh = model.gltf.meshes.elementAtOrNull(meshIndex);
        if (mesh == null) continue;
        for (
          var primitive = 0;
          primitive < mesh.primitives.length;
          primitive++
        ) {
          morphs.putIfAbsent((
            node: bind.node,
            primitive: primitive,
            morph: bind.index,
          ), () => 0);
        }
      }
      for (final bind in expression.materialColorBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        final bases = colorBases.putIfAbsent(bind.material, () => {});
        final base = bases.putIfAbsent(
          bind.type,
          () => _baseMaterialColorForModel(model, bind.material, bind.type),
        );
        colors.putIfAbsent((
          material: bind.material,
          type: bind.type,
        ), () => base);
      }
      for (final bind in expression.textureTransformBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        textureTransforms.putIfAbsent(
          bind.material,
          () => _baseTextureTransformForModel(model, bind.material),
        );
      }
    }

    for (final entry in weights.entries) {
      final weight = entry.value;
      if (weight == 0) continue;
      final expression = definitions[entry.key];
      if (expression == null) continue;

      for (final bind in expression.morphTargetBinds) {
        final meshIndex = model.gltf.nodes.elementAtOrNull(bind.node)?.mesh;
        if (meshIndex == null) continue;
        final mesh = model.gltf.meshes.elementAtOrNull(meshIndex);
        if (mesh == null) continue;
        for (
          var primitive = 0;
          primitive < mesh.primitives.length;
          primitive++
        ) {
          final key = (
            node: bind.node,
            primitive: primitive,
            morph: bind.index,
          );
          morphs[key] = (morphs[key] ?? 0) + bind.weight * weight;
        }
      }

      for (final bind in expression.materialColorBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        final bases = colorBases.putIfAbsent(bind.material, () => {});
        final base = bases.putIfAbsent(
          bind.type,
          () => _baseMaterialColorForModel(model, bind.material, bind.type),
        );
        final key = (material: bind.material, type: bind.type);
        final target = _materialColorTarget(bind.type, base, bind.targetValue);
        final current = colors[key] ?? base;
        colors[key] = current + (target - base) * weight;
      }

      for (final bind in expression.textureTransformBinds) {
        final material = model.gltf.materials.elementAtOrNull(bind.material);
        if (material == null) continue;
        final base = _baseTextureTransformForModel(model, bind.material);
        final accum = textureTransforms.putIfAbsent(bind.material, () => base);
        accum.scale = accum.scale + (bind.scale - base.scale) * weight;
        accum.offset = accum.offset + (bind.offset - base.offset) * weight;
      }
    }

    for (final entry in morphs.entries) {
      binding
          .meshByNodeIndex(entry.key.node)
          ?.setMorphWeight(
            primitiveIndex: entry.key.primitive,
            morphIndex: entry.key.morph,
            weight: _clamp01(entry.value),
          );
    }
    for (final entry in colors.entries) {
      binding
          .materialByGltfIndex(entry.key.material)
          .setColor(entry.key.type, entry.value);
    }
    for (final entry in textureTransforms.entries) {
      binding
          .materialByGltfIndex(entry.key)
          .setTextureTransform(
            scale: entry.value.scale,
            offset: entry.value.offset,
          );
    }
  }
}
