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
