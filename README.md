# flvtterm

Pure Dart VRM/VRMA parser and renderer-neutral runtime work in progress.

## Support

Supported now:

- VRM 1.0 GLB assets with root `VRMC_vrm.specVersion == "1.0"`.
- VRMA 1.0 GLB or JSON glTF assets with root `VRMC_vrm_animation.specVersion == "1.0"`.
- glTF 2.0 GLB and JSON parsing with preserved indices, `extensions`, and `extras`.
- Embedded GLB BIN chunks, embedded `data:` URI buffers/images, bufferView images, and caller-resolved external buffers/images.
- Raw bufferView byte reading and numeric accessor reading, including sparse accessors and normalized integer components.
- glTF animation `translation`, `rotation`, `scale`, and `weights` channels with `STEP`, `LINEAR`, quaternion slerp, and `CUBICSPLINE`.
- VRM extensions: `VRMC_vrm`, `VRMC_materials_mtoon`, `VRMC_springBone`, and `VRMC_node_constraint`.
- glTF extensions used by VRM: `KHR_materials_unlit`, `KHR_materials_emissive_strength`, and `KHR_texture_transform`.
- First-person `auto` primitive/triangle classification with geometry split detection for renderer adapters.

Supported extension handling:

- `VRMC_vrm`: parses `meta`, `humanoid`, `firstPerson`, `expressions`, and `lookAt`.
- `VRMC_materials_mtoon`: parses metadata and exposes renderer fallback helpers.
- `VRMC_springBone`: parses and runs deterministic spring chains.
- `VRMC_node_constraint`: parses and runs roll, aim, and rotation constraints.
- `VRMC_vrm_animation`: parses VRMA humanoid, expression, and LookAt mappings.
- Unknown `extensions` and `extras` are preserved. Unsupported required glTF extensions are validation errors in strict mode and diagnostics in permissive mode.

Not shipped yet:

- VRM 0.x compatibility.
- Built-in file/network URI loading.
- Renderer geometry splitting for first-person `auto` meshes.
- IK-based VRMA retargeting and automatic body-proportion scaling.
- Native MToon rendering.

## Pure Dart Parsing

```dart
final result = VrmModel.tryParseGlb(
  bytes,
  validation: VrmValidationMode.permissive,
  uriResolver: (uri) => preloadedExternalResources[uri],
);

if (result.asset == null) {
  for (final diagnostic in result.validation.errors) {
    print(diagnostic);
  }
  return;
}

final model = result.asset!;
```

Use `VrmModel.parseGlb(bytes)` when validation errors should throw.

For JSON glTF or VRMA files that reference external buffers or images, keep
platform I/O outside the core package and provide bytes through `uriResolver`:

```dart
final animation = VrmAnimationAsset.parse(
  bytes: vrmaJsonBytes,
  uriResolver: (uri) => preloadedBuffers[uri],
);
```

## Validation

Parsing returns structured diagnostics and never logs from core code. Strict
mode drops the asset when errors are present; permissive mode keeps the parsed
asset and reports the same errors so tools can inspect malformed files.

```dart
final result = VrmAnimationAsset.tryParse(
  bytes: vrmaBytes,
  validation: VrmValidationMode.permissive,
);

for (final error in result.validation.errors) {
  print('${error.code} ${error.jsonPath ?? ''}');
}
```

Unsupported required glTF/VRM extensions are errors. Invalid VRM/VRMA semantic
references are reported and omitted from public runtime mappings where keeping
them would make renderer binding unsafe. VRMA humanoid rest-pose scale is
reported as a warning so tools can flag animation assets that should bake scale
out of the T-pose hierarchy before retargeting.

## Runtime

Bind the runtime to any renderer by implementing `VrmSceneBinding`,
`VrmNodeBinding`, `VrmMeshBinding`, and `VrmMaterialBinding`. Implement
`VrmModelRootBinding` too when the renderer exposes a parent/root object for
the loaded avatar; VRMA hips translation is written there as model root motion.
`VrmRuntime.bind` resolves runtime-used node, mesh, and expression-material
handles once; adapters must return stable handles for the binding lifetime.

```dart
final runtime = VrmRuntime(model)..bind(sceneBinding);

runtime.emotion.set(VrmEmotion.happy, 0.75);
runtime.lipSync.setViseme(VrmViseme.aa, 0.4);
runtime.blink.setBoth(0.0);
runtime.expressions.setCustom('winkStrong', 0.6);
runtime.lookAt.lookAtWorld(targetPosition, modelWorldTransform: avatarWorld);

runtime.update(1 / 60);
```

Lower-level expression control remains available through `runtime.expressions`.
Inputs are clamped to `[0, 1]`; binary expressions threshold at `> 0.5`;
VRM override rules are applied before morph, material color, and texture
transform binds are committed.
When a binding implements `VrmModelRootBinding`, world-space LookAt targets are
also converted through runtime root motion such as VRMA hips translation.

Call `runtime.resetSpringBones()` after teleporting or otherwise discontinuously
moving the avatar root.
Spring chains without a `center` retain inertia in runtime-world space. Chains
with a `center` retain inertia relative to that node. Runtime model-root motion
participates in both paths, while gravity and collider resolution remain in
runtime-world space. Resolved spring joints always execute root to descendant,
independent of the order of `springs` in the asset.
With `fixedTimeStepSeconds`, the last solved pose remains active between
substeps and whole-step backlog beyond `maxSubSteps` is discarded.

Frame evaluation order is:

1. `beginFrame()`.
2. Reset model-root motion, node transforms, morph weights, and expression-driven material values to rest/default values.
3. Advance the motion clock.
4. Evaluate embedded glTF, external glTF, VRMA, or programmatic motion.
5. Apply motion node poses, morph weights, model-root motion, motion expression inputs, and motion LookAt input.
6. Resolve LookAt against the current head pose, then write eye bones or look-expression inputs.
7. Evaluate expression inputs and override rules, then apply morph, material color, and texture transform binds.
8. Apply node constraints.
9. Apply spring bones.
10. Apply first-person mesh visibility.
11. `commitFrame()`.

## Motion

Generic glTF playback:

```dart
final externalGltf = GltfAsset.parse(bytes: animationBytes);
runtime.motion.playEmbeddedGltfAnimation(0, loop: true);
runtime.motion.play(
  externalGltf,
  animationIndex: 1,
  nodeMask: {3, 4, 5},
  humanoidMask: {VrmHumanoidBone.leftUpperArm, VrmHumanoidBone.leftLowerArm},
  fadeIn: const Duration(milliseconds: 200),
);
runtime.motion.pause();
runtime.motion.seek(const Duration(milliseconds: 500));
runtime.motion.speed = 0.5;
runtime.motion.resume();
```

Looping uses the duration of the whole animation. Samplers with shorter key
ranges hold their final value until the animation reaches that shared loop
boundary, as required by glTF.

The active `play*` source is the override layer for motion output. Play calls
accept `priority`; a lower-priority source cannot replace the active source.
Use `onCompleted` and `onLooped` for simple playback events.
Crossfades blend VRMA model-root motion as well as node, expression, morph, and
LookAt output, including transitions from VRMA back to non-root-motion sources.
Starting another motion during a crossfade captures the currently blended
output, so the replacement fade begins without a pose jump.
Use `setAdditiveProgrammaticPose` and `addAdditiveProgrammaticPose` for simple procedural additive layers over the active source.
Use `playProceduralMotion((time) => pose)` for simple idle or app-owned procedural motion.

Any supported motion source can also run as an independently timed additive
layer:

```dart
final layerId = runtime.motion.addAdditiveLayer(
  externalGltf,
  animationIndex: 0,
  loop: true,
  weight: 0.25,
  humanoidMask: {VrmHumanoidBone.spine, VrmHumanoidBone.chest},
);
runtime.motion.setAdditiveLayerWeight(layerId, 0.5);
runtime.motion.seekAdditiveLayer(layerId, const Duration(milliseconds: 300));
runtime.motion.removeAdditiveLayer(layerId);
```

Generic glTF layers are converted to deltas from their source asset rest pose.
VRMA layers are retargeted first and then converted from the destination rest
pose; hips translation remains model-root motion. Programmatic and procedural
layer poses are already interpreted as additive deltas.

VRMA playback:

```dart
final vrma = VrmAnimationAsset.parse(bytes: vrmaBytes);
runtime.motion.play(
  vrma,
  animationIndex: 1,
  loop: true,
  hipsTranslationScale: 1.0,
  fadeIn: const Duration(milliseconds: 200),
);
```

Omit `animationIndex` to play the first glTF animation in the VRMA asset.

Current VRMA retargeting uses `VrmFkHumanoidRetargeter` by default and can be replaced through `runtime.motion.vrmaRetargeter`. Source animation node indices are mapped to source humanoid bones, normalized through the source and destination world rest rotations, then applied to destination humanoid bones; source node indices are never written directly to destination glTF node indices. Rest-frame calculation includes non-humanoid intermediary nodes. When the source has an optional humanoid bone that the destination omits, its normalized rotation is composed into the nearest descendants shared by both humanoids. Hips translation uses the source rest-pose delta, multiplies that delta by `hipsTranslationScale`, and applies it as model root motion through `VrmModelRootBinding` when available. Bindings without `VrmModelRootBinding` fall back to composing that root motion onto the glTF scene root nodes. Non-hips humanoid translation and humanoid scale animation are validation errors.

## Flutter

The optional `packages/vrm_flutter` package provides renderer-neutral Flutter
helpers. It depends on Flutter, but the core package does not.

```dart
final loader = VrmAssetLoader(DefaultAssetBundle.of(context));
final model = await loader.loadModel('assets/avatar.vrm');
final motion = await loader.loadGltf('assets/wave.gltf');
final controller = VrmRuntimeController(model)..bind(sceneBinding);
```

Flutter Scene integration lives in the optional `packages/vrm_flutter_scene`
package. Flutter Scene types stay out of the core package and the
renderer-neutral Flutter helper package.

The intended adapter flow is:

```dart
final bytes = await rootBundle.load('assets/avatar.vrm').then(
  (data) => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
);
final model = VrmModel.parseGlb(bytes);

final rootNode = await scene.Node.fromGlbBytes(bytes);
final binding = FlutterSceneVrmBinding.fromRootNode(rootNode, model: model);

final runtime = VrmRuntime(model)..bind(binding);
runtime.update(1 / 60);
```

For the common case, `FlutterSceneVrmAsset.fromGlbBytes(bytes)` performs those
three steps and returns the parsed model, imported root node, and binding.

The adapter maps glTF node indices through explicit index paths when available,
or by pairing the imported node tree with the parsed default-scene hierarchy.
This preserves glTF node-array indices even when they differ from depth-first
order. World transforms are converted back through Flutter Scene's synthesized
import root before core constraints consume them. The adapter applies node
transforms, model-root motion, child-safe mesh visibility, base-color material
fallback, and MToon PBR/emissive fallback values. MToon
materials report unlit/PBR fallback diagnostics through
`binding.capabilityWarnings`, as do first-person `auto` meshes that would need
geometry splitting. Missing Flutter Scene mutators for imported morph target
weights and texture transforms are reported through
`binding.capabilityWarnings`.

Pure Dart smoke example: run `dart run bin/runtime_console.dart [avatar.vrm]`
from `examples/runtime_console`. With a path, the example reports permissive
validation diagnostics, binds the real model, and executes two runtime frames.
CLI validation smoke: `dart run flvtterm <asset.vrm|asset.vrma|asset.gltf|asset.glb>`.
Flutter Scene viewer: place a licensed VRM 1.0 asset at
`examples/flutter_scene_viewer/assets/avatar.vrm`, then run
`flutter run` from `examples/flutter_scene_viewer`.

## MToon

MToon support is metadata-only in this package. All parsed `VRMC_materials_mtoon` values are exposed, and expressions can drive material color and texture transform binds through renderer-neutral bindings. Use `GltfMaterial.preferredRenderMode(supportsMToon: false)` and `mtoonFallbackWarning()` when an adapter needs an unlit/PBR fallback instead of native MToon.

## Limitations and Planned Work

- First-person `auto` can classify head-influenced primitives, but runtime geometry splitting is left to renderer adapters.
- `runtime.firstPerson.geometrySplitWarnings()` flags meshes where whole-mesh
  visibility is only a conservative fallback.
- VRMA retargeting is FK with rest-frame rotation normalization and configurable hips translation scale; IK and automatic body-proportion scaling can be added behind `VrmHumanoidRetargeter`.
- Native MToon shader rendering is not shipped yet; the Flutter Scene adapter applies a PBR/emissive fallback.
