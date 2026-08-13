## 0.2.5

- Promote the well-known VRM 0.x custom expression name "Surprised"
  (case-insensitive, `presetName: unknown`) to the `surprised` preset during
  legacy normalization, with a `vrm0.wellKnownCustomExpressionPromoted`
  diagnostic. Presets declared through `presetName` keep precedence.

## 0.2.4

- Cache immutable first-person mesh classification and decoded animation
  accessors instead of rebuilding them during every runtime update.
- Find animation keyframes with a binary search rather than a linear scan.
- Reuse Flutter Scene node-transform conversions until the scene replaces the
  backing matrix, removing recurring SpringBone allocation churn.
- Skip unchanged rest-pose and model-root writes during runtime frames.

## 0.2.3

- Preserve glTF and VRM material semantics in the Flutter Scene import path,
  including straight-alpha textures, alpha modes, double-sided rendering,
  sampler settings, and independent texture UV transforms.
- Preserve per-texture UV transform bases when applying expression binds and
  expose an optional renderer-neutral per-texture material binding.
- Correct MToon texture semantics and classify VRM 0.x transparent Z-write
  materials as unlit, with adapter capability diagnostics for remaining
  Flutter Scene limitations.

## 0.2.2

- Add visible POSITION/NORMAL morph-target composition to the pinned Flutter
  Scene 0.17.0 adapter, using one reusable vertex buffer per supported
  primitive and one upload per dirty frame.
- Rotate VRMA hips translation from its source-parent rest frame into model
  space before publishing model-root motion.
- Add regression coverage for blended/reset morph geometry and rotated-parent
  VRMA hips translation.

## 0.2.1

- Reorganize core sources by subsystem and reduce parser/runtime duplication
  without changing the public API.
- Preserve strict data-URI diagnostics and exception-frame material resets with
  regression coverage.
- Remove library lockfile noise and streamline examples and tests.

## 0.2.0

- Add VRM 0.x parsing, validation, typed legacy metadata, normalized runtime
  expressions/LookAt/first-person/SpringBone support, coordinate compatibility,
  and legacy MToon fallback metadata.

## 0.1.0

- Initial version.
