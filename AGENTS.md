# AGENTS.md

## Mission

Build a production-quality VRM library for Dart and Flutter. The library must load and validate VRM 1.0 `.vrm` models, expose a renderer-independent runtime for humanoid avatars, and support motion control, emotion/expression control, procedural LookAt/blink/lip-sync hooks, generic glTF animation playback, and VRM Animation `.vrma` retargeting.

The codebase must be designed so Flutter apps can integrate with `flutter_scene` easily, but the core package must not depend on `flutter_scene` directly. Only an optional adapter package, example app, or integration test may import `package:flutter_scene/...`.

## Canonical references

Consult the official specifications before implementing or changing behavior:

- VRM 1.0 overview and schema repository: `https://vrm.dev/en/vrm1/` and `https://github.com/vrm-c/vrm-specification/tree/master/specification`
- `VRMC_vrm-1.0`: `https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm-1.0`
- `VRMC_materials_mtoon-1.0`: `https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_materials_mtoon-1.0`
- `VRMC_springBone-1.0`: `https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_springBone-1.0`
- `VRMC_node_constraint-1.0`: `https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_node_constraint-1.0`
- `VRMC_vrm_animation-1.0`: `https://github.com/vrm-c/vrm-specification/tree/master/specification/VRMC_vrm_animation-1.0`
- glTF 2.0: `https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html`
- Flutter Scene docs: `https://pub.dev/documentation/flutter_scene/latest/`

If a source and this file disagree, follow the official spec and update this file in the same change.

## Non-negotiable architecture

Use a renderer-agnostic core. The core package must be pure Dart and must not import Flutter, `dart:ui`, `flutter_scene`, `flutter_gpu`, or platform-specific APIs.

Recommended package layout:

```text
packages/
  vrm/                         # pure Dart core: GLB/glTF parsing, VRM/VRMA schemas, runtime controllers
  vrm_flutter/                 # Flutter conveniences: asset loading, widgets/controllers that do not require a renderer
  vrm_flutter_scene/           # optional adapter; this is the only package allowed to depend on flutter_scene
example/
  flutter_scene_viewer/        # integration demo using vrm_flutter_scene
  runtime_console/             # pure Dart smoke tests for parser/runtime behavior
test_assets/                   # small generated fixtures and allowed-license sample references only
```

Allowed core dependencies should be minimal and portable: `collection`, `meta`, `typed_data`, and `vector_math` are acceptable. Avoid code generation unless it materially improves schema correctness and the generated files are deterministic.

The core must expose stable abstractions for scene binding rather than concrete renderer objects. A renderer adapter implements those abstractions for Flutter Scene, another renderer, or a test fake.

```dart
abstract interface class VrmSceneBinding {
  VrmNodeBinding nodeByGltfIndex(int nodeIndex);
  VrmMeshBinding? meshByNodeIndex(int nodeIndex);
  VrmMaterialBinding materialByGltfIndex(int materialIndex);
  void beginFrame();
  void commitFrame();
}

abstract interface class VrmNodeBinding {
  Matrix4 get localTransform;
  set localTransform(Matrix4 value);
  Matrix4 get worldTransform;
  String? get debugName;
}

abstract interface class VrmMeshBinding {
  void setMorphWeight({required int primitiveIndex, required int morphIndex, required double weight});
}

abstract interface class VrmMaterialBinding {
  void setColor(String parameter, Vector4 value);
  void setTextureTransform({required Vector2 scale, required Vector2 offset});
}
```

These names are illustrative; adapt them to the repository style. Preserve the separation.

## Public API goals

The target user experience should be close to this:

```dart
final vrmBytes = await loadAssetBytes('assets/avatar.vrm');
final model = VrmModel.parseGlb(vrmBytes, validation: VrmValidationMode.permissive);

final runtime = VrmRuntime(model);
runtime.bind(sceneBinding);

runtime.expressions.setPreset(VrmExpressionPreset.happy, 0.75);
runtime.expressions.setLipSync(VrmLipSyncPreset.aa, 0.4);
runtime.lookAt.lookAtWorld(targetPosition);

final vrma = VrmAnimationAsset.parse(bytes: await loadAssetBytes('assets/wave.vrma'));
runtime.motion.play(vrma, fadeIn: const Duration(milliseconds: 200), loop: true);

void tick(double dt) {
  runtime.update(dt);
}
```

For Flutter Scene integration, the optional package should support a flow close to this without leaking Flutter Scene types into the core package:

```dart
final bytes = await rootBundle.load('assets/avatar.vrm').then((b) => b.buffer.asUint8List());
final model = VrmModel.parseGlb(bytes);
final rootNode = await scene.Node.fromGlbBytes(bytes);
final binding = FlutterSceneVrmBinding.fromRootNode(rootNode, model: model);

final runtime = VrmRuntime(model)..bind(binding);
```

## VRM 1.0 model support

Implement VRM 1.0 first. Treat VRM 0.x as a separate compatibility layer or converter, not as a reason to weaken VRM 1.0 types.

A `.vrm` file is a GLB file using the `.vrm` extension. The parser must read the GLB container, parse the glTF 2.0 JSON and binary chunks, preserve glTF node/material/mesh/skin/accessor indices, and parse root-level `extensions.VRMC_vrm` with `specVersion == "1.0"`.

Parse and expose at least these extension families:

- `VRMC_vrm`: `meta`, `humanoid`, `firstPerson`, `expressions`, `lookAt`
- `VRMC_materials_mtoon`
- `VRMC_springBone`
- `VRMC_node_constraint`
- relevant glTF extensions used with VRM: `KHR_materials_unlit`, `KHR_texture_transform`, `KHR_materials_emissive_strength`

Do not discard unknown extensions. Preserve unknown `extensions` and `extras` so applications can inspect them or reserialize later. If `extensionsRequired` contains an unsupported required extension, parsing may succeed only in permissive mode and must produce a clear validation error.

Model-space and world-space must remain distinct. VRM model motion should move the root of the glTF scene or renderer root, not just the humanoid hips bone. Runtime code must never assume the avatar root is fixed at world origin.

## Validation requirements

Provide `VrmValidationResult` with warnings and errors. Support strict and permissive modes.

Validate at minimum:

- GLB header and chunk structure.
- glTF index references for nodes, meshes, skins, accessors, materials, textures, images, animations.
- `VRMC_vrm.specVersion == "1.0"`.
- Required `VRMC_vrm.meta` fields: `name`, `authors`, `licenseUrl`.
- Required humanoid bones and uniqueness of humanoid bone assignments.
- Positive non-zero scale components on humanoid bone transforms.
- Parent-child requirements for humanoid bones, allowing non-humanoid nodes between humanoid bones.
- Expression weights and bind indices.
- Constraint cycles and invalid self-source constraints.
- Spring chains with duplicated joints, invalid collider groups, invalid center nodes, and invalid joint ordering.
- VRMA constraints: no humanoid scale animation, no humanoid translation animation except hips, no `leftEye`/`rightEye` humanoid animation targets, no `lookUp`/`lookDown`/`lookLeft`/`lookRight` expression animation targets.

The parser must not crash on malformed user assets. Return structured diagnostics containing JSON paths or glTF index paths whenever possible.

## Humanoid implementation

Represent humanoid bones with a closed enum matching VRM 1.0 names. Include required and optional status in metadata.

Required humanoid bones in VRM 1.0 are:

- Torso/head: `hips`, `spine`, `head`
- Left leg: `leftUpperLeg`, `leftLowerLeg`, `leftFoot`
- Right leg: `rightUpperLeg`, `rightLowerLeg`, `rightFoot`
- Left arm: `leftUpperArm`, `leftLowerArm`, `leftHand`
- Right arm: `rightUpperArm`, `rightLowerArm`, `rightHand`

Important optional bones include `chest`, `upperChest`, `neck`, `leftShoulder`, `rightShoulder`, `leftToes`, `rightToes`, `leftEye`, `rightEye`, `jaw`, and finger bones.

Humanoid runtime state must distinguish:

- Raw glTF node local transform.
- Rest local transform.
- Current animation local transform.
- Procedural/constraint/spring modified transform.

Never accumulate animation by repeatedly mutating the previous frame’s local transform. Start each frame from a known rest or base animation pose, layer controllers, then commit to the scene binding. This avoids drift.

## Expression and emotion control

Expressions are a first-class runtime system. Implement all VRM 1.0 preset expression names:

- Emotions: `happy`, `angry`, `sad`, `relaxed`, `surprised`
- Lip sync: `aa`, `ih`, `ou`, `ee`, `oh`
- Blink: `blink`, `blinkLeft`, `blinkRight`
- Look: `lookUp`, `lookDown`, `lookLeft`, `lookRight`
- Compatibility: `neutral`

Also support arbitrary custom expressions under `expressions.custom`.

Expression weights are scalar values in `[0, 1]`; clamp application-provided values. If an expression is `isBinary`, output `1.0` when the input is greater than `0.5`, otherwise `0.0`.

Expression binds to support:

- `morphTargetBinds`: set morph target weights by target node and target morph index.
- `materialColorBinds`: interpolate material color-like parameters from their base values to target values.
- `textureTransformBinds`: interpolate texture UV scale and offset from base values.

Implement procedural overrides correctly:

- `overrideMouth` affects lip-sync expressions.
- `overrideBlink` affects blink expressions.
- `overrideLookAt` affects look expressions.
- Override modes are `none`, `block`, and `blend`.
- When an overriding expression is binary, use its binary output to affect the overridden expression.
- When a binary expression is overridden by another expression, suppress it completely if the received override effect is greater than zero.

Expose high-level convenience methods for common use, but keep the low-level expression API available:

```dart
runtime.emotion.set(VrmEmotion.happy, 0.8);
runtime.lipSync.setViseme(VrmViseme.aa, 0.3);
runtime.blink.setBoth(1.0);
runtime.expressions.setCustom('winkStrong', 0.6);
```

## LookAt and gaze control

Implement `VRMC_vrm.lookAt` for both target types:

- `bone`: apply yaw/pitch to humanoid `leftEye` and `rightEye` local rotations.
- `expression`: drive `lookUp`, `lookDown`, `lookLeft`, and `lookRight` expression weights.

Respect `offsetFromHeadBone` and the four range maps:

- `rangeMapHorizontalInner`
- `rangeMapHorizontalOuter`
- `rangeMapVerticalDown`
- `rangeMapVerticalUp`

The API must support gaze targets in model space and world space. Convert world-space targets through the current model root transform before evaluating model-space LookAt.

VRM LookAt assumes a shared line of sight for both eyes; do not try to represent independent cross-eyed targets in the core LookAt API. A renderer-specific extension may add this as non-standard behavior, but the default runtime must be spec-conformant.

For VRMA LookAt, the animation target is a glTF node whose local rotation represents gaze direction. Convert that quaternion into yaw/pitch using the VRMA-specified Extrinsic ZXY interpretation, where Y rotation is yaw and X rotation is pitch. The initial gaze direction is +Z in model space.

## First-person support

Parse `VRMC_vrm.firstPerson.meshAnnotations` and expose a renderer-neutral visibility policy:

- `thirdPersonOnly`
- `firstPersonOnly`
- `both`
- `auto`

When `firstPerson` or a mesh annotation is absent, treat missing annotations as `auto` for first-person features.

For `auto`, provide a utility that classifies primitives or triangles using skin weights connected to the head bone or descendants. If the renderer cannot split geometry at runtime, expose enough metadata so the adapter can hide whole meshes conservatively and report a warning.

## Node constraints

Implement `VRMC_node_constraint` after humanoid animation, LookAt, and expressions are evaluated, and before spring bones.

Support exactly the spec-defined constraint kinds:

- Roll constraint
- Aim constraint
- Rotation constraint

Each constraint has one source and one destination. The source must not be the destination, and constraints must not form cycles. Weight is in `[0, 1]`; use spherical interpolation from destination rest rotation to the constrained rotation.

Only one of `roll`, `aim`, or `rotation` may be present in a constraint object. Treat multiple kinds in one object as validation errors.

## Spring bone runtime

Implement `VRMC_springBone` as a deterministic procedural animation system independent of any physics engine.

Support:

- Springs, joints, joint parameters, and center space.
- Sphere and capsule colliders.
- Collider groups.
- Root-to-descendant update order.
- Reset/reinitialize when the model is teleported or when the binding changes.
- Optional fixed or semi-fixed timestep for stable behavior across frame rates.

Spring joint state should include previous tail position, current tail position, bone axis, bone length, initial local matrix, and initial local rotation. Use a Verlet-style update unless a better implementation is introduced with tests proving compatibility.

Do not allocate in the per-frame spring update loop. Pre-resolve node indices, collider groups, and chains when binding a model.

## MToon and materials

Parse all `VRMC_materials_mtoon` fields even if the first renderer adapter implements only a visual fallback.

Renderer behavior tiers:

1. Metadata-only parse: all MToon values available in Dart.
2. Fallback render: map to glTF PBR or unlit material as closely as possible.
3. Native MToon render: renderer adapter supplies shader/material support.

If `VRMC_materials_mtoon` and `KHR_materials_unlit` both exist, prefer MToon semantics. If a renderer cannot implement MToon, fall back to unlit or PBR and emit a capability warning.

Expression material binds must use the original base material values from the loaded model, not the previous frame’s already-mutated values.

## Generic glTF animations

Even though VRM 1.0 model assets do not rely on glTF `animations` as their avatar semantics, the library must support generic animation playback for real-world assets and integration scenarios.

Implement a generic glTF animation model that supports:

- Node translation, rotation, and scale channels.
- Morph target weight channels if present.
- `LINEAR`, `STEP`, and `CUBICSPLINE` interpolation.
- Multiple clips per asset.
- Clip duration, local time, looping, speed, pause/resume, events, and normalized progress.
- Layered playback and crossfade blending.

When the renderer already has an animation system, the adapter may delegate generic glTF animation playback to it. The core must still expose a renderer-independent animation representation and a fallback evaluator for tests and non-renderer use.

## VRMA support

VRM Animation `.vrma` support is mandatory.

A VRMA file is a glTF file whose root extension is `VRMC_vrm_animation`. It is intended to be a separate animation-only glTF file and is not expected to be embedded inside a VRM model’s `VRMC_vrm` extension.

Implement:

- Binary `.glb` and JSON `.gltf` VRMA parsing.
- Root-level `extensions.VRMC_vrm_animation.specVersion == "1.0"`.
- Humanoid bone mapping from animation glTF nodes to VRM humanoid bones.
- Expression mapping from animation glTF nodes to preset/custom expressions.
- LookAt mapping from animation glTF node to gaze direction.
- Default playback of the first glTF animation.
- Optional support for multiple animations in one VRMA file.

VRMA humanoid rules:

- Humanoid animation nodes must represent a VRM T-pose in rest pose.
- `leftEye` and `rightEye` must not have humanoid animation data; use LookAt.
- Humanoid animation must not include scale.
- Humanoid animation must not include translation except for `hips`.

VRMA expression rules:

- Expression weight is stored in the X component of the mapped node’s translation animation.
- Clamp expression weights to `[0, 1]`.
- `lookUp`, `lookDown`, `lookLeft`, and `lookRight` are not valid expression animation targets; use LookAt.
- Custom expression names must not collide with preset expression names.

Retargeting requirements:

- Start with a correct FK retargeter using source rest pose, destination rest pose, and humanoid bone mapping.
- Keep the retargeter isolated behind an interface so IK, humanoid normalization, or more advanced retargeting can be added later.
- Handle hips translation scale in a documented way. A simple initial policy may scale by avatar height or leg length, but it must be configurable and tested.
- Never write VRMA source node transforms directly to destination glTF node indices. Always retarget by humanoid semantic bone.

## Runtime evaluation order

Use this frame order unless a spec update requires otherwise:

1. Reset frame-local pose/material/expression accumulators to rest or current base animation state.
2. Evaluate generic glTF animation clips and user motion layers.
3. Evaluate VRMA clips and retarget humanoid pose, expression weights, and LookAt input.
4. Resolve humanoid bones.
5. Resolve LookAt after the head transform is known.
6. Compute expression input values from application state, emotion state, lip-sync, blink, LookAt, and VRMA.
7. Apply expression override rules.
8. Apply expression binds to morph targets, material colors, and texture transforms.
9. Resolve node constraints.
10. Resolve spring bones.
11. Commit node, morph, material, and visibility changes to the bound renderer.

Do not reorder constraints and spring bones casually. Tests must cover the order.

## Motion controller requirements

Provide a `VrmMotionController` that can play all supported animation sources through one API:

- Generic glTF animation clips embedded in a model.
- External generic glTF/GLB animation clips.
- VRMA clips.
- Programmatic poses.
- Procedural idle motions.

Required features:

- `play`, `stop`, `pause`, `resume`, `seek`, and `update`.
- Looping and clamp-to-end.
- Playback speed, including zero and reverse if feasible.
- Fade in/out and crossfade.
- Additive and override layers.
- Bone masks or humanoid masks for partial-body animation.
- Priority handling between procedural controllers and animation clips.

The default controller should make VRMA work for common avatars without custom setup.

## Flutter Scene integration strategy

The optional `vrm_flutter_scene` package may depend on `flutter_scene`. No other package may import it.

`flutter_scene` can load GLB assets into a `Node` graph and has `Node`, `Mesh`, `Skin`, parsed animations, `Animation`, `AnimationClip`, and `AnimationPlayer` concepts. Use those features where they fit, but do not design the core API around them.

Adapter tasks:

- Load a `.vrm` GLB into Flutter Scene using `Node.fromGlbBytes` or `Node.fromGlbAsset`.
- Parse the same bytes with `VrmModel.parseGlb` in the core package.
- Bind VRM glTF node indices to Flutter Scene `Node`s. Prefer an importer-provided index map or a deterministic traversal/index-path captured during import. Do not rely only on node names; glTF node names are optional and not guaranteed unique.
- Account for Flutter Scene importer coordinate-convention nodes, including any synthesized root transform used to adapt glTF handedness. Keep all model-space math in core conventions and convert only at the binding boundary.
- Bind morph targets and material parameters through adapter interfaces. If Flutter Scene does not expose a required primitive/morph/material mutator yet, implement a capability warning and a test fake so the core behavior remains testable.
- Use Flutter Scene’s generic `AnimationPlayer` for normal glTF animation playback when this produces correct results. Use the core VRMA retargeter for VRMA, because VRMA targets humanoid semantics, expressions, and LookAt, not just node-name animation channels.
- For MToon, begin with a fallback adapter to PBR/unlit. Add a custom shader/material path later if Flutter Scene’s shader material surface supports the needed parameters.
- Keep Flutter Scene API-touching code small. Flutter Scene is still evolving; isolate API breakage to the adapter package.

Recommended adapter API:

```dart
final class FlutterSceneVrmBinding implements VrmSceneBinding {
  FlutterSceneVrmBinding.fromRootNode(
    scene.Node root, {
    required VrmModel model,
    FlutterSceneVrmBindingOptions options = const FlutterSceneVrmBindingOptions(),
  });
}
```

## Flutter package behavior

`vrm_flutter` should provide Flutter conveniences that are renderer-neutral:

- `VrmAssetLoader` for `AssetBundle` bytes.
- `VrmRuntimeController` that can be owned by a widget but does not render by itself.
- `ChangeNotifier` or `ValueListenable` surfaces for UI controls if useful.
- No direct dependency on Flutter Scene.

The example app may demonstrate:

- Loading a `.vrm` asset with Flutter Scene.
- Emotion sliders.
- Lip-sync sliders or fake viseme input.
- Blink toggle/auto blink.
- LookAt target controlled by pointer or camera.
- VRMA file playback with play/pause/seek/speed.
- Generic glTF animation playback if the model contains clips.
- MToon fallback warnings displayed in developer UI.

## Error handling and diagnostics

Use typed exceptions only for truly exceptional programmer errors. For user asset problems, return diagnostics.

Recommended types:

```dart
sealed class VrmDiagnosticSeverity { const VrmDiagnosticSeverity(); }
final class VrmInfo extends VrmDiagnosticSeverity { const VrmInfo(); }
final class VrmWarning extends VrmDiagnosticSeverity { const VrmWarning(); }
final class VrmError extends VrmDiagnosticSeverity { const VrmError(); }

final class VrmDiagnostic {
  final VrmDiagnosticSeverity severity;
  final String code;
  final String message;
  final String? jsonPath;
  final int? gltfNodeIndex;
  final int? gltfMaterialIndex;
}
```

Do not log directly from core library code except through an injectable logger or diagnostics sink. Libraries should be quiet by default.

## Performance rules

Parsing may allocate; per-frame runtime must be allocation-conscious.

- Pre-resolve indices into runtime binding handles at bind time.
- Store numeric animation data in typed lists where practical.
- Avoid per-frame string lookups and map lookups in inner loops.
- Avoid constructing new `Matrix4`, `Vector3`, or `Quaternion` objects in hot paths when reusable scratch values are practical.
- Keep immutable spec data separate from mutable runtime data.
- Consider isolates for heavy parsing or validation in Flutter apps, but keep the core API usable synchronously for tests and server-side tools.
- Use fixed or semi-fixed stepping for spring bones where possible.

## Testing requirements

Every feature added must include tests. Do not rely only on visual inspection.

Core unit tests:

- GLB parsing fixtures with valid and invalid headers/chunks.
- VRM extension parsing and validation.
- Humanoid required bones, parent rules, uniqueness, positive scale validation.
- Expression clamp, binary threshold, override block/blend, morph/material/texture bind accumulation.
- LookAt yaw/pitch range maps and bone/expression output.
- Node constraint roll/aim/rotation and cycle detection.
- Spring bone deterministic update, sphere/capsule collision, center space, reset on teleport.
- VRMA parsing, first-animation default, multiple-animation optional behavior.
- VRMA retargeting from source humanoid rest pose to destination humanoid rest pose.
- Generic glTF animation interpolation: linear, step, cubic spline, rotation slerp.

Adapter tests:

- Use fake `VrmSceneBinding` for core runtime tests.
- In `vrm_flutter_scene`, add smoke tests that bind a small generated GLB/VRM fixture to Flutter Scene when the test environment supports it.
- Keep renderer-specific tests skippable when Flutter GPU/Impeller prerequisites are unavailable.

Golden/fixture policy:

- Prefer generated procedural fixtures for parser/runtime edge cases.
- Use official VRM sample models only if their license permits repository inclusion; otherwise, write tests that download or reference them outside normal CI.
- Do not commit third-party avatar assets without explicit redistribution permission.

## Documentation requirements

Each public class must have Dartdoc. The README must include:

- Supported VRM/VRMA versions.
- Supported and unsupported glTF extensions.
- Quick start for pure Dart parsing.
- Quick start for Flutter asset loading.
- Quick start for Flutter Scene integration through the optional adapter.
- Emotion/expression control example.
- VRMA playback example.
- Generic animation playback example.
- MToon support tier and fallback behavior.
- Limitations and planned work.

Document the exact update order and retargeting policy. Users must be able to understand why their animation, expression, LookAt, constraint, or spring bone wins when multiple systems affect the same avatar.

## Coding standards

Follow idiomatic Dart:

- Use sound null safety.
- Prefer immutable value types for parsed spec data.
- Prefer explicit enums/sealed classes over stringly typed public APIs.
- Keep string constants for raw spec names in one place.
- Use `final` by default.
- Avoid global mutable state.
- Keep public APIs small and cohesive.
- Use `Duration` for user-facing time values, but use seconds as `double` internally in animation hot paths if needed.
- Prefer composition over inheritance except for sealed data models.
- Include regression tests for every bug fix.

## Commands before completing a change

Run the repository’s actual tooling if it differs from this list. In a normal Dart/Flutter workspace, run:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

For Flutter packages/examples, also run:

```sh
flutter analyze
flutter test
```

If using a monorepo tool such as Melos, add equivalent workspace commands and keep this section updated.

## Dependency policy

Do not add dependencies casually. Before adding a package, check:

- It is actively maintained.
- It supports Dart/Flutter versions used by this repo.
- It works on mobile, desktop, and web if it is in shared code.
- Its license is compatible.
- It does not discard glTF extensions or reorder glTF indices in a way that breaks VRM binding.

Never add `flutter_scene` to the core `vrm` or renderer-neutral `vrm_flutter` package.

## Implementation milestones

Recommended sequence:

1. Pure Dart GLB/glTF parser that preserves indices and extensions.
2. VRM 1.0 schema parsing for `VRMC_vrm`, humanoid, meta, expressions, LookAt, firstPerson.
3. Validation system and generated/minimal fixtures.
4. Renderer-neutral binding interfaces and fake binding tests.
5. Expression runtime including morph/material/texture binds and override rules.
6. Humanoid pose runtime and generic glTF animation evaluator.
7. LookAt runtime.
8. Node constraints.
9. Spring bone runtime.
10. VRMA parser.
11. VRMA FK retargeter and motion controller integration.
12. Optional Flutter asset loader.
13. Optional Flutter Scene adapter and example viewer.
14. MToon fallback adapter, then native/custom MToon material support if feasible.
15. Documentation, examples, and CI hardening.

Do not start with a renderer-specific demo and then backfill the core. Start with spec-correct parsing and runtime behavior, then bind it to renderers.

## Definition of done

A feature is done only when:

- It is represented in renderer-neutral core types.
- It has parser support where applicable.
- It has validation diagnostics for malformed input.
- It has runtime behavior covered by tests.
- It does not introduce a direct Flutter Scene dependency outside the optional adapter/example.
- It has Dartdoc and README coverage if public.
- It runs through format, analyze, and tests.
