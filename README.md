# desk_sdui

Server-driven UI for Flutter. Author screens as `@Screen` Dart-subset, ship layouts as data, render on device by composing registered native widgets.

This is a melos workspace with three packages:

- **`desk_sdui_annotation`** — `@Screen` annotation and IR types. Pure Dart.
- **`desk_sdui`** — runtime that renders IR into a Flutter widget tree.
- **`desk_sdui_generator`** — `build_runner` codegen + analyzer plugin.

Design spec: see `dart_desk/docs/superpowers/specs/2026-05-10-desk-sdui-design.md` in the sibling `dart_desk` repo.

## Status

Phase 1 of v1 — foundation only. The annotation package ships the IR types and JSON codec; the runtime and generator are empty skeletons.
