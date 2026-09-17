# VRM and VRMA runtime contract

This document owns the detailed parser, validation and runtime requirements
previously embedded in `AGENTS.md`. Read the sections relevant to the behavior
you change. These requirements do not establish that every feature is currently
implemented or qualified; [README](../README.md) owns current support and
limitations. [AGENTS.md](../AGENTS.md) owns contributor workflow.

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

For format semantics, follow the official specification and correct this contract in the same change. Preserve documented compatibility behavior and report any conflict before changing its public contract.

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
- Caller-sampled humanoid poses with an immutable source rest skeleton.
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

Sampled humanoid sources share VRMA's semantic binding and FK retargeting,
including omitted optional ancestors, legacy model orientation and separate
model-root motion. Samples contain finite unit body rotations and optional
absolute source hips translation; they cannot own eye bones, expressions,
gaze, scales or arbitrary destination nodes. The reference asset contributes
only rest metadata. Interpolation and sample availability belong to the caller.
An externally clocked stream uses speed zero and seeks only within available
coverage; the runtime does not extrapolate or retain a streaming queue. Source
replacement and stop use the same priority, fade and callback lifetime rules
as other motion sources. Additive sampled layers expose their own weighted
root translation independently of other layers.

Transition capture copies the current bound local TRS for explicitly selected
mapped humanoid bones and, when supported, the runtime-owned root translation.
It excludes application placement, unselected nodes, morphs and expression
inputs. Nonfinite, singular or sheared selected transforms fail capture rather
than being approximated. The caller removes contributions already captured
before replaying the snapshot, to avoid applying them twice. A programmatic
root translation is an explicit model-space displacement independent of node
masks; it shares the existing crossfade, release and additive root composition.
Override root inspection excludes additive roots and does not advance time.
Unblended inspection returns no target while releasing; blended inspection
uses the captured release snapshot without re-entering its source callback.

## Performance rules

Parsing may allocate; per-frame runtime must be allocation-conscious.

- Pre-resolve indices into runtime binding handles at bind time.
- Store numeric animation data in typed lists where practical.
- Avoid per-frame string lookups and map lookups in inner loops.
- Avoid constructing new `Matrix4`, `Vector3`, or `Quaternion` objects in hot paths when reusable scratch values are practical.
- Keep immutable spec data separate from mutable runtime data.
- Consider isolates for heavy parsing or validation in Flutter apps, but keep the core API usable synchronously for tests and server-side tools.
- Use fixed or semi-fixed stepping for spring bones where possible.
