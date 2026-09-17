# Working in flvtterm

flvtterm is a renderer-neutral Dart VRM/VRMA parser and avatar runtime.
The core is in `lib/`, the optional Flutter Scene adapter is in
`packages/vrm_flutter_scene/`, and examples are in `example/`.

## Start here

Read [README](README.md) for current support and public usage. For parsing,
validation, animation or controller changes, read the relevant sections of the
[runtime contract](doc/runtime_contract.md) and its official specifications.
Inspect the current implementation before using an illustrative API or layout.

Inspect the working tree, preserve unrelated edits and unpublished commits,
and state scope and verification. Reuse existing code and keep changes focused.
Routine implementation choices within the task do not require another approval;
explain and obtain approval before expanding product scope.

## Essential contracts

- The core stays pure Dart: no Flutter, `dart:ui`, Flutter Scene, Flutter GPU
  or platform APIs. Renderer objects stay behind core-owned binding interfaces.
- Flutter Scene imports are allowed in the optional adapter and its Flutter
  examples/integration tests. Keep renderer-specific behavior out of the core;
  coordinate adapter and renderer versions when their internals change.
- Preserve glTF indices, unknown extensions/extras and VRM 0.x compatibility
  separately from VRM 1.0 semantics. Strict/permissive validation must produce
  clear diagnostics for malformed or unsupported assets.
- Treat GLB, JSON, accessors and imported assets as untrusted. Validate bounds,
  references, finite values and required extensions before allocating or using
  data. Preserve structured errors and diagnostics rather than crashing.
- Keep model/world space and rest/current pose distinct. Reset frame-local
  state before applying controllers; preserve the documented evaluation order
  and reset behavior on rebinding or teleportation.
- Retarget by humanoid semantics, never matching source/destination node indices
  or assuming names are unique. Preserve interpolation, quaternion continuity,
  expression overrides, gaze and spring-bone contracts.
- Pre-resolve bindings and reuse buffers in frame loops. Performance changes
  need measurement and behavior checks. Keep logging injectable and quiet.
- Use generated fixtures for ordinary tests. Third-party models need explicit
  redistribution rights; restricted assets remain outside Git and packages.
  Keep generated renderer outputs under their owning build tools.

## Verification

For core code changes, run focused tests, then from the repository root:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

For each affected Flutter package (`packages/vrm_flutter_scene` or
`example/flutter_scene_viewer`), run `flutter analyze` and `flutter test` in that
package. The pure Dart example runs with `dart run bin/runtime_console.dart`
from `example/runtime_console`. Resolve package dependencies first when needed;
[CI](.github/workflows/ci.yml) records the package/SDK matrix.

Add regression tests for changed behavior, including malformed input and
controller ordering. Renderer changes also need an applicable rendered check;
fakes do not establish pixel correctness. Report unavailable GPU checks as
missing evidence. For prose-only changes, check links, paths/commands and
`git diff --check` without rebuilding the renderer.

## Delivery

Use a task branch, review the diff, and commit only task files. Push or publish
only when requested; merge only with owner approval. Preserve existing features
and compatibility unless the user authorizes a change. Update Dartdoc and
README support/limitations when public behavior changes; keep detailed runtime
rules in the contract. Report checks and their actual scope.
