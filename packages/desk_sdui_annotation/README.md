# desk_sdui_annotation

Annotations and IR types for [desk_sdui](../desk_sdui). Pure Dart, no Flutter dependency.

## What's here

- `@Screen('name')` — annotation marking a function as an SDUI screen.
- `IrNode` and subclasses — typed intermediate representation of a screen layout.
- `JsonIrCodec` — encode/decode `IrNode` to/from JSON.

This package is consumed by `desk_sdui` (runtime) and `desk_sdui_generator` (codegen).
